using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Threading;
using CafePrinter;
using SkiaSharp;

// ── PInvoke declarations ──────────────────────────────────────────────────────

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
internal struct DOC_INFO_1
{
    public string pDocName;
    public string? pOutputFile;
    public string pDatatype;
}

// Declared as a real struct rather than read via hardcoded byte offsets.
// The previous code read Status at offset 60 - the 32-bit layout - which on x64
// lands inside the pDevMode pointer, so it tested the high half of a heap
// address against status bits and reported almost every printer as offline.
// Letting the marshaller compute the layout keeps this correct on any bitness.
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
internal struct PRINTER_INFO_2
{
    public IntPtr pServerName;
    public IntPtr pPrinterName;
    public IntPtr pShareName;
    public IntPtr pPortName;
    public IntPtr pDriverName;
    public IntPtr pComment;
    public IntPtr pLocation;
    public IntPtr pDevMode;
    public IntPtr pSepFile;
    public IntPtr pPrintProcessor;
    public IntPtr pDatatype;
    public IntPtr pParameters;
    public IntPtr pSecurityDescriptor;
    public uint   Attributes;
    public uint   Priority;
    public uint   DefaultPriority;
    public uint   StartTime;
    public uint   UntilTime;
    public uint   Status;
    public uint   cJobs;
    public uint   AveragePPM;
}

[StructLayout(LayoutKind.Sequential)]
internal struct SYSTEMTIME
{
    public ushort wYear, wMonth, wDayOfWeek, wDay, wHour, wMinute, wSecond, wMilliseconds;
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
internal struct JOB_INFO_1
{
    public uint       JobId;
    public IntPtr     pPrinterName;
    public IntPtr     pMachineName;
    public IntPtr     pUserName;
    public IntPtr     pDocument;
    public IntPtr     pDatatype;
    public IntPtr     pStatus;
    public uint       Status;
    public uint       Priority;
    public uint       Position;
    public uint       TotalPages;
    public uint       PagesPrinted;
    public SYSTEMTIME Submitted;   // UTC
}

internal static class PrinterStatus
{
    public const uint Paused       = 0x00000001;
    public const uint Error        = 0x00000002;
    public const uint PaperOut     = 0x00000010;
    public const uint Offline      = 0x00000080;
    public const uint NotAvailable = 0x00001000;
    public const uint NoToner      = 0x00040000;
    public const uint UserIntervention = 0x00100000;
    public const uint DoorOpen     = 0x00400000;

    // States where jobs will pile up instead of printing. Paused is included
    // deliberately: a paused queue accumulates exactly like a disconnected one
    // and dumps the backlog when resumed, which is the behaviour being fixed.
    public const uint CannotPrint =
        Paused | Error | Offline | PaperOut | NotAvailable | UserIntervention | DoorOpen;
}

internal static class JobStatus
{
    public const uint Paused           = 0x00000001;
    public const uint Error            = 0x00000002;
    public const uint Spooling         = 0x00000008;
    public const uint Printing         = 0x00000010;
    public const uint Offline          = 0x00000020;
    public const uint PaperOut         = 0x00000040;
    public const uint Printed          = 0x00000080;
    public const uint BlockedDevQ      = 0x00000200;
    public const uint UserIntervention = 0x00000400;
    public const uint Complete         = 0x00001000;

    // A job in any of these states is not going to print on its own - the
    // device is unreachable or needs attention. Detected immediately, no
    // waiting for the job to age out.
    public const uint Stuck = Error | Offline | PaperOut | BlockedDevQ | UserIntervention | Paused;
}

internal static class Winspool
{
    [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool OpenPrinter(string pPrinterName, out IntPtr phPrinter, IntPtr pDefault);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool GetPrinter(IntPtr hPrinter, uint dwLevel,
        IntPtr pPrinter, uint cbBuf, out uint pcbNeeded);

    [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int StartDocPrinter(IntPtr hPrinter, uint level, ref DOC_INFO_1 pDocInfo);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.drv", SetLastError = true)]
    public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBuf,
        uint cbBuf, out uint pcWritten);

    [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool EnumJobs(IntPtr hPrinter, uint FirstJob, uint NoJobs,
        uint Level, IntPtr pJob, uint cbBuf, out uint pcbNeeded, out uint pcReturned);

    [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SetJob(IntPtr hPrinter, uint JobId, uint Level,
        IntPtr pJob, uint Command);

    public const uint JOB_CONTROL_DELETE = 5;
}

// ── Entry point ───────────────────────────────────────────────────────────────

static class Program
{
    static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
        // Ids have arrived as both numbers and strings depending on the code path
        // that produced them; accept either rather than failing the whole print.
        NumberHandling = System.Text.Json.Serialization.JsonNumberHandling.AllowReadingFromString
    };

    static int Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("Usage:");
            Console.Error.WriteLine("  CafePrinter check <printer_name>");
            Console.Error.WriteLine("  CafePrinter status <printer_name>    (diagnostic)");
            Console.Error.WriteLine("  CafePrinter purge <printer_name>     (drop stale queued jobs)");
            Console.Error.WriteLine("  CafePrinter print <printer_name> <bytes_file>");
            Console.Error.WriteLine("  CafePrinter print-receipt <json_file>");
            Console.Error.WriteLine("  CafePrinter print-kot <json_file>");
            Console.Error.WriteLine("  CafePrinter warmup <printer_name>         (preload Skia, no I/O)");
            Console.Error.WriteLine("  CafePrinter clear-cooldown <printer_name>");
            Console.Error.WriteLine("Exit codes: 0 = ok, 1 = error, 2 = printer unavailable");
            return 1;
        }

        string command = args[0].ToLowerInvariant();

        return command switch
        {
            "check"         => CheckPrinter(args[1]),
            "status"        => ShowStatus(args[1]),
            "purge"         => PurgeCommand(args[1]),
            "print" when args.Length >= 3 => PrintRawBytes(args[1], args[2]),
            "print-receipt" => WithTimings(() => PrintReceipt(args[1])),
            "print-kot"     => WithTimings(() => PrintKot(args[1])),
            "render-receipt" when args.Length >= 3 => RenderToPng(args[1], args[2], isKot: false),
            "render-kot"     when args.Length >= 3 => RenderToPng(args[1], args[2], isKot: true),
            "warmup"         => Warmup(args[1]),
            "clear-cooldown" => ClearCooldownCommand(args[1]),
            _ => LogError($"Unknown command: {command}", 1)
        };
    }

    // Exit codes: 0 = ok, 1 = error, 2 = printer unavailable (powered off /
    // disconnected). Flutter treats any non-zero as failure, which surfaces the
    // existing "Printer Not Available - save as PDF?" dialog; the distinct code
    // just makes the logs unambiguous.
    const int ExitUnavailable = 2;

    // Fallback for a job that is silently going nowhere without reporting an
    // error state. Jobs actively printing are exempt (see IsJobStuck), so this
    // can be short without risking a long receipt being killed mid-print.
    static readonly TimeSpan StaleJobAge = TimeSpan.FromSeconds(25);

    // Post-submit verification timings. The spooler accepts bytes for a
    // powered-off printer and reports success, so the only honest verdict comes
    // from watching what happens to the job afterwards.
    //
    // Measured against a physically disconnected printer: the job reports
    // ERROR|PRINTING after ~245ms and never leaves the queue. These values are
    // set from that measurement, not guessed.
    static readonly TimeSpan VerifyPoll    = TimeSpan.FromMilliseconds(100);
    static readonly TimeSpan VerifySettle  = TimeSpan.FromMilliseconds(700);  // > 245ms, with margin
    static readonly TimeSpan VerifyTimeout = TimeSpan.FromSeconds(3);

    // After a verified failure, refuse this printer outright for a short while
    // so repeat orders during an outage fail instantly instead of each paying
    // the render + submit + verify cost. Short and self-clearing so a
    // reconnected printer resumes almost immediately.
    static readonly TimeSpan UnavailableCooldown = TimeSpan.FromSeconds(20);

    // ── stage timing ──────────────────────────────────────────────────────────
    // One machine-readable stdout line per print, folded into the app's trace.
    //
    // Why it has to live here: from Dart, Process.run is a single opaque await,
    // so the app can see that a receipt took 1330ms but not whether that was
    // launching this exe or actually printing. Those have completely different
    // fixes - a warm-up versus a spooler change - so guessing is expensive.
    //
    // stdout, not stderr, because stderr already carries progress and error
    // text that the app scrapes for failure reasons.
    static class Timings
    {
        static readonly Stopwatch Sw = Stopwatch.StartNew();
        static readonly List<string> Stages = new();
        static long _last;

        /// Time from process creation to reaching Main: single-file extraction,
        /// runtime init, ReadyToRun page-in. This is "launch cost", and it is
        /// the number the startup warm-up exists to move off the receipt path.
        public static long BootMs;

        public static void Mark(string stage)
        {
            long now = Sw.ElapsedMilliseconds;
            Stages.Add($"{stage}={now - _last}");
            _last = now;
        }

        public static void Emit()
        {
            var parts = new List<string> { $"boot={BootMs}" };
            parts.AddRange(Stages);
            parts.Add($"exe={Sw.ElapsedMilliseconds}");
            Console.WriteLine($"[timing] {string.Join(" ", parts)}");
        }
    }

    // Emits the timing line however the command exits, including on an error
    // path - a failed print's breakdown is the one you most want to read.
    static int WithTimings(Func<int> action)
    {
        try
        {
            Timings.BootMs =
                (long)(DateTime.Now - Process.GetCurrentProcess().StartTime).TotalMilliseconds;
        }
        catch { Timings.BootMs = -1; }

        try { return action(); }
        finally { Timings.Emit(); }
    }

    static int LogError(string msg, int code)
    {
        Console.Error.WriteLine(msg);
        return code;
    }

    // ── shared: read PRINTER_INFO_2 ───────────────────────────────────────────
    static bool TryGetPrinterInfo(IntPtr hPrinter, out PRINTER_INFO_2 info)
    {
        info = default;
        Winspool.GetPrinter(hPrinter, 2, IntPtr.Zero, 0, out uint needed);
        if (needed == 0) return false;

        IntPtr buf = Marshal.AllocHGlobal((int)needed);
        try
        {
            if (!Winspool.GetPrinter(hPrinter, 2, buf, needed, out _)) return false;
            info = Marshal.PtrToStructure<PRINTER_INFO_2>(buf);
            return true;
        }
        finally { Marshal.FreeHGlobal(buf); }
    }

    static string DecodeStatus(uint status)
    {
        if (status == 0) return "READY";
        var flags = new List<string>();
        if ((status & PrinterStatus.Paused)           != 0) flags.Add("PAUSED");
        if ((status & PrinterStatus.Error)            != 0) flags.Add("ERROR");
        if ((status & PrinterStatus.Offline)          != 0) flags.Add("OFFLINE");
        if ((status & PrinterStatus.PaperOut)         != 0) flags.Add("PAPER_OUT");
        if ((status & PrinterStatus.NotAvailable)     != 0) flags.Add("NOT_AVAILABLE");
        if ((status & PrinterStatus.NoToner)          != 0) flags.Add("NO_TONER");
        if ((status & PrinterStatus.UserIntervention) != 0) flags.Add("USER_INTERVENTION");
        if ((status & PrinterStatus.DoorOpen)         != 0) flags.Add("DOOR_OPEN");
        return flags.Count > 0 ? string.Join("|", flags) : $"OTHER(0x{status:X})";
    }

    static string DecodeJobStatus(uint status)
    {
        if (status == 0) return "QUEUED";
        var flags = new List<string>();
        if ((status & JobStatus.Paused)           != 0) flags.Add("PAUSED");
        if ((status & JobStatus.Error)            != 0) flags.Add("ERROR");
        if ((status & JobStatus.Spooling)         != 0) flags.Add("SPOOLING");
        if ((status & JobStatus.Printing)         != 0) flags.Add("PRINTING");
        if ((status & JobStatus.Offline)          != 0) flags.Add("OFFLINE");
        if ((status & JobStatus.PaperOut)         != 0) flags.Add("PAPER_OUT");
        if ((status & JobStatus.Printed)          != 0) flags.Add("PRINTED");
        if ((status & JobStatus.BlockedDevQ)      != 0) flags.Add("BLOCKED_DEVQ");
        if ((status & JobStatus.UserIntervention) != 0) flags.Add("USER_INTERVENTION");
        return flags.Count > 0 ? string.Join("|", flags) : $"OTHER(0x{status:X})";
    }

    // ── shared: enumerate queued jobs ─────────────────────────────────────────
    static List<JOB_INFO_1> GetJobs(IntPtr hPrinter)
    {
        var jobs = new List<JOB_INFO_1>();
        Winspool.EnumJobs(hPrinter, 0, 256, 1, IntPtr.Zero, 0, out uint needed, out _);
        if (needed == 0) return jobs;

        IntPtr buf = Marshal.AllocHGlobal((int)needed);
        try
        {
            if (!Winspool.EnumJobs(hPrinter, 0, 256, 1, buf, needed, out _, out uint returned))
                return jobs;

            int size = Marshal.SizeOf<JOB_INFO_1>();
            for (int i = 0; i < returned; i++)
                jobs.Add(Marshal.PtrToStructure<JOB_INFO_1>(buf + (i * size)));
        }
        finally { Marshal.FreeHGlobal(buf); }
        return jobs;
    }

    static DateTime? SubmittedUtc(SYSTEMTIME st)
    {
        try
        {
            // Submitted is UTC per the Win32 docs.
            return new DateTime(st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute,
                                st.wSecond, st.wMilliseconds, DateTimeKind.Utc);
        }
        catch { return null; }   // guard against a driver reporting a bogus time
    }

    // Single definition of "this job is going nowhere", shared by the gate and
    // the purge so the two can never disagree about which jobs are stuck.
    static bool IsJobStuck(JOB_INFO_1 job, DateTime nowUtc, out string why)
    {
        why = "";

        // Explicit failure states first. A job against a disconnected printer
        // reports ERROR|PRINTING - Windows still calls it the active job while
        // the port errors - so this MUST be tested before the PRINTING
        // exemption below, or a dead job is shielded from purging forever.
        if ((job.Status & JobStatus.Stuck) != 0)
        {
            why = $"job {job.JobId} status=0x{job.Status:X} ({DecodeJobStatus(job.Status)})";
            return true;
        }

        // Actively printing and not erroring: never stuck, however long it
        // takes. Protects a slow but legitimate print.
        if ((job.Status & JobStatus.Printing) != 0) return false;

        // Fallback: spooled but going nowhere quietly.
        var submitted = SubmittedUtc(job.Submitted);
        if (submitted != null && nowUtc - submitted.Value >= StaleJobAge)
        {
            why = $"job {job.JobId} queued {(nowUtc - submitted.Value).TotalSeconds:F0}s with no progress";
            return true;
        }

        return false;
    }

    // Delete jobs that IsJobStuck considers dead. Returns how many were removed.
    // In-flight and recently-submitted jobs are left alone.
    static int PurgeStaleJobs(IntPtr hPrinter)
    {
        int purged = 0;
        var now = DateTime.UtcNow;

        foreach (var job in GetJobs(hPrinter))
        {
            if (!IsJobStuck(job, now, out string why)) continue;

            if (Winspool.SetJob(hPrinter, job.JobId, 0, IntPtr.Zero, Winspool.JOB_CONTROL_DELETE))
            {
                purged++;
                Console.Error.WriteLine($"[purge] deleted {why}");
            }
        }
        return purged;
    }

    // ── cooldown marker ───────────────────────────────────────────────────────
    // Records that a printer was just proven unavailable, so subsequent orders
    // can be refused without repeating the whole render/submit/verify cycle.

    static string MarkerPath(string printerName)
    {
        var safe = new string(printerName.Select(c =>
            Path.GetInvalidFileNameChars().Contains(c) ? '_' : c).ToArray());
        return Path.Combine(Path.GetTempPath(), "CafePrinter", safe + ".unavailable");
    }

    static void MarkUnavailable(string printerName)
    {
        try
        {
            string path = MarkerPath(printerName);
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllText(path, DateTime.UtcNow.ToString("o"));
        }
        catch { /* cooldown is an optimisation; never fail a print over it */ }
    }

    static void ClearUnavailable(string printerName)
    {
        try
        {
            string path = MarkerPath(printerName);
            if (File.Exists(path)) File.Delete(path);
        }
        catch { }
    }

    static bool InCooldown(string printerName, out TimeSpan age)
    {
        age = TimeSpan.Zero;
        try
        {
            string path = MarkerPath(printerName);
            if (!File.Exists(path)) return false;
            age = DateTime.UtcNow - File.GetLastWriteTimeUtc(path);
            // A clock change can make this negative; treat that as expired.
            return age >= TimeSpan.Zero && age < UnavailableCooldown;
        }
        catch { return false; }
    }

    // Lets the app clear a stale marker on demand. Without this, a Test Print
    // taken within UnavailableCooldown of a failure is refused by the gate with
    // no way for the user to say "I just plugged it back in".
    static int ClearCooldownCommand(string printerName)
    {
        ClearUnavailable(printerName);
        Console.WriteLine($"[cooldown] cleared for '{printerName}'");
        return 0;
    }

    // ── warm-up ───────────────────────────────────────────────────────────────
    // Pays the expensive one-time costs of a launch - single-file extraction,
    // ReadyToRun page-in, loading libSkiaSharp/libHarfBuzzSharp, decoding four
    // embedded fonts - at a moment nobody is waiting, so the first receipt of a
    // shift does not.
    //
    // Deliberately touches the spooler not at all: it opens no printer, submits
    // no job, and reads no cooldown marker. It therefore cannot print anything,
    // cannot mark a printer unavailable, and cannot fail a real print. The
    // printer name is accepted only so the caller can pass one uniformly; it is
    // used for nothing but the log line.
    //
    // Always returns 0. A warm-up that fails is a missed optimisation, not an
    // error, and must never be reported as one.
    static int Warmup(string printerName)
    {
        var sw = Stopwatch.StartNew();
        try
        {
            // Forces FontManager's static initialiser: native Skia load + four
            // SKTypeface.FromStream decodes.
            var typeface = FontManager.GetTypeface("warmup", bold: false);

            // A one-pixel raster so the draw path is JITted too. Font decoding
            // alone leaves the measure/shape/draw code cold.
            using var bitmap = new SKBitmap(8, 8);
            using var canvas = new SKCanvas(bitmap);
            using var paint = new SKPaint
            {
                Typeface = typeface,
                TextSize = 8,
                IsAntialias = true,
                Color = SKColors.Black
            };
            canvas.Clear(SKColors.White);
            canvas.DrawText("0", 0, 8, paint);

            Console.WriteLine($"[warmup] ok in {sw.ElapsedMilliseconds}ms ('{printerName}')");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[warmup] skipped: {ex.Message}");
        }
        return 0;
    }

    // ── post-submit verification ──────────────────────────────────────────────
    // Watches a submitted job to find out whether it actually printed. This is
    // the only reliable signal: OpenPrinter/WritePrinter both succeed against a
    // powered-off printer.
    static bool VerifyJobPrinted(IntPtr hPrinter, uint jobId, out string reason)
    {
        reason = "";
        var sw = Stopwatch.StartNew();
        bool sawPrinting = false;

        while (sw.Elapsed < VerifyTimeout)
        {
            var job = GetJobs(hPrinter).FirstOrDefault(j => j.JobId == jobId);

            // Gone from the queue: it finished and the spooler dropped it.
            if (job.JobId != jobId)
                return true;

            if ((job.Status & (JobStatus.Printed | JobStatus.Complete)) != 0)
                return true;

            // Error flags are checked before the PRINTING exemption on purpose:
            // a dead port reports ERROR|PRINTING together (~245ms, measured).
            if ((job.Status & JobStatus.Stuck) != 0)
            {
                reason = $"job {jobId} {DecodeJobStatus(job.Status)}";
                return false;
            }

            if ((job.Status & JobStatus.Printing) != 0)
            {
                sawPrinting = true;
                // Printing cleanly for longer than an error would have taken to
                // appear: accept it rather than waiting out a long receipt.
                if (sw.Elapsed >= VerifySettle) return true;
            }

            Thread.Sleep(VerifyPoll);
        }

        // Timed out. Still printing and never errored - assume a slow but
        // legitimate print; killing it here would be far worse than a late one.
        if (sawPrinting) return true;

        reason = $"job {jobId} never started printing within {VerifyTimeout.TotalSeconds:F0}s";
        return false;
    }

    // ── shared: availability gate ─────────────────────────────────────────────
    // Called before rendering so an unavailable printer costs nothing.
    static bool IsPrinterAvailable(IntPtr hPrinter, out string reason)
    {
        reason = "";

        // Signal 1: driver-reported status. Trustworthy only now that the struct
        // layout is correct - but still driver-dependent, hence signal 2.
        if (TryGetPrinterInfo(hPrinter, out var info))
        {
            if ((info.Status & PrinterStatus.CannotPrint) != 0)
            {
                reason = $"status={DecodeStatus(info.Status)}";
                return false;
            }
        }

        // Signal 2: behavioural, and independent of what the driver claims.
        // This is the one that actually does the work - Windows reports READY
        // for a USB printer whose hardware is absent, so the queue is the only
        // honest evidence that jobs are not reaching the device.
        var now = DateTime.UtcNow;
        foreach (var job in GetJobs(hPrinter))
        {
            if (IsJobStuck(job, now, out string why))
            {
                reason = $"queue not draining ({why})";
                return false;
            }
        }

        return true;
    }

    // Opens the printer and applies the gate.
    //
    // Deliberately does NOT purge here. An earlier version did, and emptying the
    // queue made Windows flip the printer back to READY - so the next order
    // passed the gate, queued silently, and showed no "printer not available"
    // dialog. Failed jobs are now deleted by the verification step that proved
    // them dead, which keeps the queue clean without erasing the evidence.
    static bool EnsureAvailable(string printerName, out int exitCode)
    {
        exitCode = 0;

        // Recently proven unavailable: refuse without touching the spooler.
        if (InCooldown(printerName, out TimeSpan age))
        {
            Console.Error.WriteLine(
                $"[gate] '{printerName}' unavailable (verified {age.TotalSeconds:F0}s ago)");
            exitCode = ExitUnavailable;
            return false;
        }

        if (!Winspool.OpenPrinter(printerName, out IntPtr hPrinter, IntPtr.Zero))
        {
            Console.Error.WriteLine(
                $"[gate] cannot open printer '{printerName}': {Marshal.GetLastWin32Error()}");
            exitCode = ExitUnavailable;
            return false;
        }

        try
        {
            if (IsPrinterAvailable(hPrinter, out string reason)) return true;

            Console.Error.WriteLine($"[gate] '{printerName}' unavailable: {reason}");
            MarkUnavailable(printerName);
            exitCode = ExitUnavailable;
            return false;
        }
        finally { Winspool.ClosePrinter(hPrinter); }
    }

    // ── check ─────────────────────────────────────────────────────────────────
    static int CheckPrinter(string printerName)
    {
        if (!EnsureAvailable(printerName, out int code)) return code;
        Console.Error.WriteLine($"[check] '{printerName}' available");
        return 0;
    }

    // ── status (diagnostic) ───────────────────────────────────────────────────
    static int ShowStatus(string printerName)
    {
        if (!Winspool.OpenPrinter(printerName, out IntPtr hPrinter, IntPtr.Zero))
            return LogError($"Cannot open printer '{printerName}': {Marshal.GetLastWin32Error()}", 1);

        try
        {
            if (!TryGetPrinterInfo(hPrinter, out var info))
                return LogError($"GetPrinter failed: {Marshal.GetLastWin32Error()}", 1);

            Console.WriteLine($"printer     = {printerName}");
            Console.WriteLine($"Attributes  = 0x{info.Attributes:X8}");
            Console.WriteLine($"Status      = 0x{info.Status:X8}  ({DecodeStatus(info.Status)})");
            Console.WriteLine($"cJobs       = {info.cJobs}");

            var jobs = GetJobs(hPrinter);
            Console.WriteLine($"queued jobs = {jobs.Count}");
            var now = DateTime.UtcNow;
            foreach (var job in jobs)
            {
                var submitted = SubmittedUtc(job.Submitted);
                string age = submitted == null
                    ? "unknown"
                    : $"{(now - submitted.Value).TotalSeconds:F0}s";
                bool stuck = IsJobStuck(job, now, out _);
                Console.WriteLine($"  job {job.JobId}: status=0x{job.Status:X} " +
                                  $"({DecodeJobStatus(job.Status)}) age={age} stuck={stuck}");
            }

            bool ok = IsPrinterAvailable(hPrinter, out string reason);
            Console.WriteLine($"available   = {ok}{(ok ? "" : $"  ({reason})")}");
            return 0;
        }
        finally { Winspool.ClosePrinter(hPrinter); }
    }

    // ── purge (manual recovery) ───────────────────────────────────────────────
    static int PurgeCommand(string printerName)
    {
        if (!Winspool.OpenPrinter(printerName, out IntPtr hPrinter, IntPtr.Zero))
            return LogError($"Cannot open printer '{printerName}': {Marshal.GetLastWin32Error()}", 1);

        try
        {
            int purged = PurgeStaleJobs(hPrinter);
            Console.WriteLine($"purged {purged} stale job(s) from '{printerName}'");
            return 0;
        }
        finally { Winspool.ClosePrinter(hPrinter); }
    }

    // ── render to PNG (diagnostic) ────────────────────────────────────────────
    // Renders exactly what would be printed, to a file, so layout can be checked
    // without a printer or paper.
    static int RenderToPng(string jsonFile, string outPng, bool isKot)
    {
        if (!File.Exists(jsonFile))
            return LogError($"[render] JSON file not found: {jsonFile}", 1);

        try
        {
            string json = File.ReadAllText(jsonFile);
            using SKBitmap bitmap = isKot
                ? KotRenderer.Render(JsonSerializer.Deserialize<KotPrintData>(json, JsonOpts)!)
                : ReceiptRenderer.Render(JsonSerializer.Deserialize<ReceiptPrintData>(json, JsonOpts)!);

            using var image = SKImage.FromBitmap(bitmap);
            using var data  = image.Encode(SKEncodedImageFormat.Png, 100);
            using var fs    = File.OpenWrite(outPng);
            data.SaveTo(fs);

            Console.WriteLine($"rendered {bitmap.Width}x{bitmap.Height}px -> {outPng}");
            return 0;
        }
        catch (Exception ex)
        {
            return LogError($"[render] {ex.Message}\n{ex.StackTrace}", 1);
        }
    }

    // ── print (raw bytes file) ────────────────────────────────────────────────
    static int PrintRawBytes(string printerName, string bytesFilePath)
    {
        if (!File.Exists(bytesFilePath))
            return LogError($"[print] File not found: {bytesFilePath}", 1);

        byte[] data;
        try { data = File.ReadAllBytes(bytesFilePath); }
        catch (Exception ex) { return LogError($"[print] Cannot read file: {ex.Message}", 1); }

        if (!EnsureAvailable(printerName, out int gate)) return gate;

        return SendBytesToPrinter(printerName, data, "Sims Cafe Print Job");
    }

    // ── print-receipt ─────────────────────────────────────────────────────────
    static int PrintReceipt(string jsonFile)
    {
        if (!File.Exists(jsonFile))
            return LogError($"[print-receipt] JSON file not found: {jsonFile}", 1);

        ReceiptPrintData? data;
        try
        {
            string json = File.ReadAllText(jsonFile);
            data = JsonSerializer.Deserialize<ReceiptPrintData>(json, JsonOpts);
        }
        catch (Exception ex)
        {
            return LogError($"[print-receipt] Failed to parse JSON: {ex.Message}", 1);
        }

        if (data == null)
            return LogError("[print-receipt] JSON parsed to null", 1);

        Timings.Mark("json");

        // Gate before rendering - an unavailable printer costs nothing.
        // Marked before the early return so a refused print still reports what
        // the gate cost; that is precisely the case worth inspecting.
        bool available = EnsureAvailable(data.PrinterName, out int gate);
        Timings.Mark("gate");
        if (!available) return gate;

        try
        {
            Console.Error.WriteLine($"[print-receipt] Rendering receipt for '{data.PrinterName}'...");
            using var bitmap  = ReceiptRenderer.Render(data);
            var escBytes = EscPosConverter.ToEscPos(bitmap, data.OpenDrawer, isKot: false);
            Console.Error.WriteLine($"[print-receipt] Rendered {bitmap.Width}x{bitmap.Height}px, {escBytes.Count} ESC/POS bytes");
            Timings.Mark("render");
            return SendBytesToPrinter(data.PrinterName, escBytes.ToArray(), "Sims Cafe Receipt");
        }
        catch (Exception ex)
        {
            return LogError($"[print-receipt] Render error: {ex.Message}\n{ex.StackTrace}", 1);
        }
    }

    // ── print-kot ────────────────────────────────────────────────────────────
    static int PrintKot(string jsonFile)
    {
        if (!File.Exists(jsonFile))
            return LogError($"[print-kot] JSON file not found: {jsonFile}", 1);

        KotPrintData? data;
        try
        {
            string json = File.ReadAllText(jsonFile);
            data = JsonSerializer.Deserialize<KotPrintData>(json, JsonOpts);
        }
        catch (Exception ex)
        {
            return LogError($"[print-kot] Failed to parse JSON: {ex.Message}", 1);
        }

        if (data == null)
            return LogError("[print-kot] JSON parsed to null", 1);

        Timings.Mark("json");

        // Gate before rendering - an unavailable printer costs nothing.
        // Marked before the early return so a refused print still reports what
        // the gate cost; that is precisely the case worth inspecting.
        bool available = EnsureAvailable(data.PrinterName, out int gate);
        Timings.Mark("gate");
        if (!available) return gate;

        try
        {
            Console.Error.WriteLine($"[print-kot] Rendering KOT for '{data.PrinterName}'...");
            using var bitmap  = KotRenderer.Render(data);
            var escBytes = EscPosConverter.ToEscPos(bitmap, openDrawer: false, isKot: true);
            Console.Error.WriteLine($"[print-kot] Rendered {bitmap.Width}x{bitmap.Height}px, {escBytes.Count} ESC/POS bytes");
            Timings.Mark("render");
            return SendBytesToPrinter(data.PrinterName, escBytes.ToArray(), "Sims Cafe KOT");
        }
        catch (Exception ex)
        {
            return LogError($"[print-kot] Render error: {ex.Message}\n{ex.StackTrace}", 1);
        }
    }

    // ── shared: send byte array to Windows printer spooler ───────────────────
    static int SendBytesToPrinter(string printerName, byte[] data, string jobName)
    {
        if (!Winspool.OpenPrinter(printerName, out IntPtr hPrinter, IntPtr.Zero))
            return LogError($"Cannot open printer '{printerName}': {Marshal.GetLastWin32Error()}", 1);

        try
        {
            var docInfo = new DOC_INFO_1
            {
                pDocName    = jobName,
                pOutputFile = null,
                pDatatype   = "RAW"
            };

            // StartDocPrinter returns the spooler's job id, which is what makes
            // post-submit verification possible.
            int jobId = Winspool.StartDocPrinter(hPrinter, 1, ref docInfo);
            if (jobId == 0)
            {
                Console.Error.WriteLine($"StartDocPrinter failed: {Marshal.GetLastWin32Error()}");
                return 1;
            }

            if (!Winspool.StartPagePrinter(hPrinter))
            {
                Console.Error.WriteLine($"StartPagePrinter failed: {Marshal.GetLastWin32Error()}");
                Winspool.EndDocPrinter(hPrinter);
                return 1;
            }

            IntPtr buf = Marshal.AllocHGlobal(data.Length);
            try
            {
                Marshal.Copy(data, 0, buf, data.Length);
                bool wrote = Winspool.WritePrinter(hPrinter, buf, (uint)data.Length, out uint written);
                if (!wrote || written != (uint)data.Length)
                {
                    Console.Error.WriteLine(
                        $"WritePrinter: ok={wrote} wrote={written}/{data.Length} err={Marshal.GetLastWin32Error()}");
                    Winspool.EndPagePrinter(hPrinter);
                    Winspool.EndDocPrinter(hPrinter);
                    return 1;
                }
            }
            finally { Marshal.FreeHGlobal(buf); }

            Winspool.EndPagePrinter(hPrinter);
            Winspool.EndDocPrinter(hPrinter);

            // Split from verify deliberately: submit is when the paper starts
            // moving, verify is only us waiting to confirm it. If verify
            // dominates, the receipt is already printed and the cost is ours.
            Timings.Mark("submit");

            // The spooler accepting the bytes proves nothing - it accepts them
            // for a powered-off printer too. Watch the job to get a real verdict.
            var sw = Stopwatch.StartNew();
            if (!VerifyJobPrinted(hPrinter, (uint)jobId, out string why))
            {
                // Delete it so it cannot print later when the printer reappears.
                Winspool.SetJob(hPrinter, (uint)jobId, 0, IntPtr.Zero, Winspool.JOB_CONTROL_DELETE);
                MarkUnavailable(printerName);
                Timings.Mark("verify");
                Console.Error.WriteLine(
                    $"[verify] '{printerName}' did not print: {why} ({sw.ElapsedMilliseconds}ms); job deleted");
                return ExitUnavailable;
            }

            ClearUnavailable(printerName);
            Timings.Mark("verify");
            Console.Error.WriteLine(
                $"Sent {data.Length} bytes to '{printerName}' (verified in {sw.ElapsedMilliseconds}ms)");
            return 0;
        }
        finally { Winspool.ClosePrinter(hPrinter); }
    }
}
