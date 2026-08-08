using System;
using System.Collections.Generic;
using SkiaSharp;
using SkiaSharp.HarfBuzz;

namespace CafePrinter;

// Shared text measurement, wrapping and drawing for both renderers.
//
// Exists because ReceiptRenderer and KotRenderer each carried their own copy of
// a broken MeasureText that returned `fontSize * 1.2f` - a HEIGHT - as the WIDTH
// of any Arabic string. Every Arabic name therefore measured ~34px wide no matter
// how long it was, so wrapping never triggered and the name ran under the Qty and
// Price columns.
internal static class TextLayout
{
    public static SKPaint MakePaint(string text, float fontSize, bool bold)
    {
        return new SKPaint
        {
            Typeface    = FontManager.GetTypeface(text, bold),
            TextSize    = fontSize,
            Color       = SKColors.Black,
            IsAntialias = true,
            TextAlign   = SKTextAlign.Left
        };
    }

    // ── Directional runs ─────────────────────────────────────────────────────
    //
    // SKShaper.Shape calls HarfBuzz's GuessSegmentProperties, which picks ONE
    // direction for the whole string from its first strong character. So in
    // "chicken فرخة - Medium" the leading Latin makes the entire string LTR and
    // the Arabic comes out reversed and disconnected.
    //
    // Splitting into single-script runs and shaping each on its own means every
    // Arabic run is guessed RTL - the case that already renders correctly today
    // (the pure-Arabic footer proves it) - without hand-writing UAX #9.

    static bool IsRtlChar(char c) =>
        (c >= 0x0600 && c <= 0x06FF) ||   // Arabic
        (c >= 0x0750 && c <= 0x077F) ||   // Arabic Supplement
        (c >= 0x08A0 && c <= 0x08FF) ||   // Arabic Extended-A
        (c >= 0xFB50 && c <= 0xFDFF) ||   // Arabic Presentation Forms-A
        (c >= 0xFE70 && c <= 0xFEFF) ||   // Arabic Presentation Forms-B
        (c >= 0x0590 && c <= 0x05FF);     // Hebrew

    static bool IsLtrChar(char c) => char.IsLetter(c) && !IsRtlChar(c);

    public readonly struct Run
    {
        public readonly string Text;
        public readonly bool   IsRtl;
        public Run(string text, bool isRtl) { Text = text; IsRtl = isRtl; }
    }

    // Base paragraph direction: the first strong character wins (UAX #9 P2/P3).
    public static bool IsRtlBase(string text)
    {
        foreach (var c in text)
        {
            if (IsRtlChar(c)) return true;
            if (IsLtrChar(c)) return false;
        }
        return false;
    }

    // Neutrals (spaces, punctuation, digits) are held aside until the next strong
    // character decides where they belong. At a direction boundary they resolve
    // to the BASE direction (UAX #9 N1/N2).
    //
    // This matters: naively appending them to the run in progress put the " - " of
    // "chicken فرخة - Medium" inside the Arabic run, so it flipped to the left of
    // فرخة and printed as "chicken  - فرخةMedium".
    public static List<Run> SplitRuns(string text)
    {
        var runs = new List<Run>();
        if (string.IsNullOrEmpty(text)) return runs;

        bool baseRtl = IsRtlBase(text);

        var current  = new System.Text.StringBuilder();
        var pending  = new System.Text.StringBuilder();   // neutrals awaiting a home
        bool curRtl  = baseRtl;
        bool started = false;

        foreach (var c in text)
        {
            if (!(IsRtlChar(c) || IsLtrChar(c)))
            {
                pending.Append(c);
                continue;
            }

            bool rtl = IsRtlChar(c);

            if (!started)
            {
                curRtl  = rtl;
                started = true;
                current.Append(pending);   // leading neutrals lead the first run
                pending.Clear();
            }
            else if (rtl != curRtl)
            {
                // Boundary: the neutrals go to whichever side matches the base
                // direction - the current run if it matches, otherwise they lead
                // the next one.
                if (curRtl == baseRtl)
                {
                    current.Append(pending);
                    pending.Clear();
                }

                if (current.Length > 0) runs.Add(new Run(current.ToString(), curRtl));
                current.Clear();

                current.Append(pending);   // empty unless carried across
                pending.Clear();
                curRtl = rtl;
            }
            else
            {
                current.Append(pending);
                pending.Clear();
            }

            current.Append(c);
        }

        current.Append(pending);           // trailing neutrals stay with the last run
        if (current.Length > 0) runs.Add(new Run(current.ToString(), curRtl));
        if (runs.Count == 0) runs.Add(new Run(text, baseRtl));
        return runs;
    }

    static SKPaint MakeRunPaint(Run run, float fontSize, bool bold) => new SKPaint
    {
        // Per-run typeface: Cairo carries the Arabic, OpenSans the Latin.
        Typeface    = run.IsRtl
                        ? (bold ? FontManager.CairoBold : FontManager.CairoRegular)
                        : (bold ? FontManager.OpenSansBold : FontManager.OpenSansRegular),
        TextSize    = fontSize,
        Color       = SKColors.Black,
        IsAntialias = true,
        TextAlign   = SKTextAlign.Left
    };

    static float RunWidth(Run run, SKPaint paint)
    {
        if (run.IsRtl)
        {
            using var shaper = new SKShaper(paint.Typeface!);
            return shaper.Shape(run.Text, paint).Width;
        }
        return paint.MeasureText(run.Text);
    }

    // True width of the text as it will actually be drawn. Arabic must go through
    // the shaper: ligatures and contextual forms make the shaped run a different
    // width from the raw character sequence.
    public static float MeasureWidth(string text, float fontSize, bool bold)
    {
        if (string.IsNullOrEmpty(text)) return 0f;
        using var paint = MakePaint(text, fontSize, bold);
        return MeasureWidth(text, paint);
    }

    // Sum of the runs, so mixed-script strings measure as they actually draw.
    // Wrapping and right-alignment both depend on this being right.
    public static float MeasureWidth(string text, SKPaint paint)
    {
        if (string.IsNullOrEmpty(text)) return 0f;

        float fontSize = paint.TextSize;
        bool  bold     = paint.Typeface == FontManager.CairoBold
                      || paint.Typeface == FontManager.OpenSansBold;

        float total = 0f;
        foreach (var run in SplitRuns(text))
        {
            using var runPaint = MakeRunPaint(run, fontSize, bold);
            total += RunWidth(run, runPaint);
        }
        return total;
    }

    // Height used for row spacing. Kept as the tight glyph height for Latin and
    // the conventional 1.2x line height for Arabic, matching what the renderers
    // already produced, so this change does not lengthen existing receipts.
    public static float TextHeight(string text, float fontSize, bool bold)
    {
        if (string.IsNullOrEmpty(text)) return 0f;
        if (FontManager.IsArabic(text)) return fontSize * 1.2f;

        using var paint = MakePaint(text, fontSize, bold);
        var bounds = new SKRect();
        paint.MeasureText(text, ref bounds);
        return bounds.Height;
    }

    // Splits text into lines that each fit maxWidth. Works for Arabic and Latin
    // alike because it measures with MeasureWidth above.
    public static List<string> WrapLines(string text, float fontSize, bool bold, float maxWidth)
    {
        var lines = new List<string>();
        if (string.IsNullOrEmpty(text)) return lines;

        using var paint = MakePaint(text, fontSize, bold);

        if (maxWidth <= 0f || MeasureWidth(text, paint) <= maxWidth)
        {
            lines.Add(text);
            return lines;
        }

        var current = "";
        foreach (var word in text.Split(' '))
        {
            if (word.Length == 0) continue;

            var candidate = current.Length == 0 ? word : current + " " + word;
            if (MeasureWidth(candidate, paint) <= maxWidth)
            {
                current = candidate;
                continue;
            }

            if (current.Length > 0)
            {
                lines.Add(current);
                current = "";
            }

            // A single word wider than the column would otherwise loop forever;
            // break it by character so the wrapper always makes progress.
            if (MeasureWidth(word, paint) > maxWidth)
            {
                var chunk = "";
                foreach (var ch in word)
                {
                    var next = chunk + ch;
                    if (chunk.Length > 0 && MeasureWidth(next, paint) > maxWidth)
                    {
                        lines.Add(chunk);
                        chunk = ch.ToString();
                    }
                    else
                    {
                        chunk = next;
                    }
                }
                current = chunk;
            }
            else
            {
                current = word;
            }
        }

        if (current.Length > 0) lines.Add(current);
        if (lines.Count == 0) lines.Add(text);
        return lines;
    }

    // Draws one already-wrapped line. baselineY is the baseline, so every call in
    // a row can share it and the text lines up regardless of script - which is
    // what was previously broken: Arabic drew at y + fontSize*1.2 while Latin
    // drew at y + tightBounds.Height, leaving the numbers visibly raised above
    // an Arabic item name.
    public static void DrawLine(SKCanvas canvas, string text, SKPaint paint, float x, float baselineY)
    {
        if (string.IsNullOrEmpty(text)) return;

        float fontSize = paint.TextSize;
        bool  bold     = paint.Typeface == FontManager.CairoBold
                      || paint.Typeface == FontManager.OpenSansBold;

        var runs = SplitRuns(text);

        // Visual order. For an LTR paragraph the runs sit left-to-right in
        // logical order; for an RTL one the first logical run goes rightmost.
        if (IsRtlBase(text)) runs.Reverse();

        float cursor = x;
        foreach (var run in runs)
        {
            using var runPaint = MakeRunPaint(run, fontSize, bold);

            if (run.IsRtl)
            {
                // Shaped alone, so HarfBuzz infers RTL for this run and orders
                // and joins the glyphs correctly.
                using var shaper = new SKShaper(runPaint.Typeface!);
                canvas.DrawShapedText(shaper, run.Text, cursor, baselineY, runPaint);
            }
            else
            {
                canvas.DrawText(run.Text, cursor, baselineY, runPaint);
            }

            cursor += RunWidth(run, runPaint);
        }
    }
}
