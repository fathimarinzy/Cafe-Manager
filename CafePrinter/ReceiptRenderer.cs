using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SkiaSharp;
using SkiaSharp.HarfBuzz;

namespace CafePrinter;

// Replicates _generateReceiptImage() from thermal_printer_service.dart exactly.
// Canvas: 512px wide × dynamic height, white background.
public static class ReceiptRenderer
{
    const float Width     = 512f;
    const float Padding   = 12f;
    const float FontSize  = 32f;   // _fontSize
    const float SmallFont = 38f;   // _smallFontSize
    const float LargeFont = 52f;   // _largeFontSize

    public static SKBitmap Render(ReceiptPrintData d)
    {
        // Pass 1: calculate total height
        float height = MeasureHeight(d);

        // Pass 2: draw onto bitmap
        var bitmap = new SKBitmap((int)Width, (int)height, SKColorType.Bgra8888, SKAlphaType.Premul);
        using var canvas = new SKCanvas(bitmap);
        canvas.Clear(SKColors.White);

        float y = Padding;
        Draw(canvas, d, ref y);

        return bitmap;
    }

    // ── height measurement ───────────────────────────────────────────────────

    static float MeasureHeight(ReceiptPrintData d)
    {
        float y = Padding;
        Draw(null, d, ref y);   // null canvas = measure-only mode
        y += Padding;
        return y;
    }

    // ── unified draw/measure pass ────────────────────────────────────────────

    static void Draw(SKCanvas? canvas, ReceiptPrintData d, ref float y)
    {
        bool hasArabic = DetectArabic(d);

        // Logo
        if (!string.IsNullOrEmpty(d.LogoPath) && File.Exists(d.LogoPath))
        {
            using var logoData = SKData.Create(d.LogoPath);
            using var logoBmp  = SKBitmap.Decode(logoData);
            if (logoBmp != null)
            {
                float scale  = 180f / logoBmp.Width;
                int   lw     = 180;
                int   lh     = (int)(logoBmp.Height * scale);
                using var resized = logoBmp.Resize(new SKImageInfo(lw, lh), SKFilterQuality.High);
                if (resized != null)
                {
                    float logoX = (Width - lw) / 2f;
                    canvas?.DrawBitmap(resized, logoX, y);
                    y += lh + 12f;
                }
            }
        }

        // Business name
        y += DrawCenteredText(canvas, d.BusinessName, SmallFont, bold: true, y: y) + 8f - 5f;

        // Second name
        if (!string.IsNullOrEmpty(d.SecondBusinessName))
            y += DrawCenteredText(canvas, d.SecondBusinessName, FontSize, bold: true, y: y) + 8f - 5f;

        // Address
        if (!string.IsNullOrEmpty(d.BusinessAddress))
            y += DrawCenteredText(canvas, d.BusinessAddress, FontSize - 4f, bold: false, y: y) + 8f - 6f;

        // Phone
        if (!string.IsNullOrEmpty(d.BusinessPhone))
            y += DrawCenteredText(canvas, d.BusinessPhone, FontSize - 4f, bold: false, y: y) + 8f;

        // Title
        if (!string.IsNullOrEmpty(d.Title))
            y += DrawCenteredText(canvas, d.Title, FontSize, bold: true, y: y) + 8f;

        // Order number
        string orderNum = string.IsNullOrEmpty(d.OrderNumber)
            ? (DateTime.Now.Ticks % 10000).ToString()
            : d.OrderNumber;
        y += DrawCenteredText(canvas, $"ORDER #{orderNum}", FontSize - 4f, bold: false, y: y) + 8f - 6f;

        // Date/time — matches Dart: DD-MM-YYYY at HH:MM
        var now = DateTime.Now;
        string dateStr = $"{now.Day:D2}-{now.Month:D2}-{now.Year} at {now.Hour:D2}:{now.Minute:D2}";
        y += DrawCenteredText(canvas, dateStr, FontSize - 4f, bold: false, y: y) + 8f - 6f;

        // Service type
        y += DrawCenteredText(canvas, $"Service: {d.ServiceType}", FontSize - 4f, bold: true, y: y) + 8f;

        // Customer name
        if (!string.IsNullOrEmpty(d.PersonName))
            y += DrawCenteredText(canvas, $"Customer: {d.PersonName}", SmallFont - 4f, bold: false, y: y) + 8f;

        // Divider
        y += 10f;
        DrawLine(canvas, y, 4f);
        y += 4f + 8f;

        // Items header
        y = DrawItemsHeader(canvas, y);

        DrawLine(canvas, y, 4f);
        y += 4f + 8f;

        // Item rows
        foreach (var item in d.Items)
        {
            y = DrawItemRow(canvas, item, y);
            y += 5f;
        }

        DrawLine(canvas, y, 4f);
        y += 4f + 8f;

        // Subtotal
        y = DrawTotalRow(canvas, "Subtotal:", d.Subtotal.ToString("F3"), isTotal: false, y: y);

        // Tax
        string taxLabel = d.TaxRate > 0 ? $"Tax ({d.TaxRate:F1}%):" : "Tax:";
        y = DrawTotalRow(canvas, taxLabel, d.Tax.ToString("F3"), isTotal: false, y: y);

        // Delivery fee
        if (d.DeliveryCharge > 0)
            y = DrawTotalRow(canvas, "Delivery Fee:", d.DeliveryCharge.ToString("F3"), isTotal: false, y: y);

        // Discount
        if (d.Discount > 0)
            y = DrawTotalRow(canvas, "Discount:", d.Discount.ToString("F3"), isTotal: false, y: y);

        DrawLine(canvas, y, 4f);
        y += 4f + 8f;

        // TOTAL
        y = DrawTotalRow(canvas, "TOTAL:", d.Total.ToString("F3"), isTotal: true, y: y);

        // Deposit section
        if (d.DepositAmount > 0)
        {
            y += 5f;
            DrawLine(canvas, y, 2f);
            y += 2f + 8f;
            y = DrawTotalRow(canvas, "Advance Paid:", d.DepositAmount.ToString("F3"), isTotal: false, y: y);
            double balance = d.Total - d.DepositAmount;
            y = DrawTotalRow(canvas, "Balance Due:", balance.ToString("F3"), isTotal: true, y: y);
        }

        y += 10f;

        // Footer
        y += DrawCenteredText(canvas, "Thank you for your visit!", SmallFont - 8f, bold: false, y: y) + 8f - 5f;
        y += DrawCenteredText(canvas, "Please come again", SmallFont - 8f, bold: false, y: y) + 8f;

        // Arabic footer (if any Arabic content detected)
        if (hasArabic)
        {
            y += 4f;
            y += DrawCenteredText(canvas, "شكراً لزيارتكم!", SmallFont - 8f, bold: false, y: y) + 8f - 6f;
            y += DrawCenteredText(canvas, "نتطلع لزيارتكم مرة أخرى", SmallFont - 8f, bold: false, y: y) + 8f;
        }
    }

    // ── drawing helpers ──────────────────────────────────────────────────────

    // Returns the text height (not including the +8 spacing — caller adds that).
    static float DrawCenteredText(SKCanvas? canvas, string text, float fontSize, bool bold, float y,
                                   float maxWidth = Width)
    {
        if (string.IsNullOrEmpty(text)) return 0f;

        // Routed through TextLayout so mixed Latin+Arabic strings are split into
        // directional runs; shaping the whole string at once reversed the Arabic.
        using var paint = TextLayout.MakePaint(text, fontSize, bold);
        float textWidth  = TextLayout.MeasureWidth(text, paint);
        float textHeight = TextLayout.TextHeight(text, fontSize, bold);
        float drawX      = (Width - textWidth) / 2f;

        if (canvas != null)
            TextLayout.DrawLine(canvas, text, paint, drawX, y + textHeight);

        return textHeight;
    }

    static float DrawLeftText(SKCanvas? canvas, string text, float fontSize, bool bold, float x, float y,
                               float maxWidth = Width)
    {
        if (string.IsNullOrEmpty(text)) return 0f;

        using var paint = TextLayout.MakePaint(text, fontSize, bold);
        float h = TextLayout.TextHeight(text, fontSize, bold);

        if (canvas != null)
            TextLayout.DrawLine(canvas, text, paint, x, y + h);

        return h;
    }

    // Delegates to the shared helper. The previous local version returned
    // fontSize * 1.2f - a height - as the width of any Arabic string, so long
    // Arabic names measured ~34px wide and never wrapped.
    static float MeasureText(string text, float fontSize, bool bold)
        => TextLayout.MeasureWidth(text, fontSize, bold);

    static float MeasureTextHeight(string text, float fontSize, bool bold)
        => TextLayout.TextHeight(text, fontSize, bold);

    static void DrawLine(SKCanvas? canvas, float y, float thickness)
    {
        if (canvas == null) return;
        using var paint = new SKPaint
        {
            Color       = SKColors.Black,
            StrokeWidth = thickness,
            IsStroke    = true,
            IsAntialias = false
        };
        canvas.DrawLine(Padding, y, Width - Padding, y, paint);
    }

    // Items header: Item | Qty | Price | Total
    static float DrawItemsHeader(SKCanvas? canvas, float y)
    {
        float h = MeasureTextHeight("Item", FontSize - 4f, true);
        if (canvas != null)
        {
            DrawLeftText(canvas, "Item",  FontSize - 4f, true, Padding,        y);
            DrawLeftText(canvas, "Qty",   FontSize - 4f, true, Width * 0.40f,  y);
            DrawLeftText(canvas, "Price", FontSize - 4f, true, Width * 0.60f,  y);
            DrawLeftText(canvas, "Total", FontSize - 4f, true, Width - 85f,    y);
        }
        return y + h + 10f;
    }

    // Single item row — matches Dart's _drawItemRow() pixel-for-pixel
    static float DrawItemRow(SKCanvas? canvas, PrintItem item, float y)
    {
        float fs = FontSize - 4f;
        // Name column runs up to the Qty band, less a small gap. The old value
        // subtracted an arbitrary 32px; 20px is enough to keep clear of Qty and
        // buys a little width back, which means fewer names wrap.
        float nameMaxWidth = Width * 0.40f - Padding - 8f;

        // Real wrapped lines, measured with proper shaped widths for Arabic.
        var   nameLines = TextLayout.WrapLines(item.Name, fs, false, nameMaxWidth);
        string qtyStr   = item.Quantity.ToString();
        string priceStr = item.Price.ToString("F3");
        string totalStr = (item.Price * item.Quantity).ToString("F3");

        // ONE baseline for the whole row. Previously the name and the numbers each
        // computed their own - Arabic at y + fontSize*1.2, digits at y + tight
        // bounds height - which left the qty/price sitting visibly above an Arabic
        // item name.
        string firstLine = nameLines.Count > 0 ? nameLines[0] : "";
        float baseline  = MathF.Max(
            MathF.Max(TextLayout.TextHeight(firstLine, fs, false),
                      TextLayout.TextHeight(qtyStr, fs, true)),
            MathF.Max(TextLayout.TextHeight(priceStr, fs, false),
                      TextLayout.TextHeight(totalStr, fs, true)));
        baseline = MathF.Max(baseline, fs);

        float lineStep = baseline + 2f;

        if (canvas != null)
        {
            using var namePaint  = TextLayout.MakePaint(item.Name, fs, false);
            using var qtyPaint   = TextLayout.MakePaint(qtyStr,   fs, true);
            using var pricePaint = TextLayout.MakePaint(priceStr, fs, false);
            using var totalPaint = TextLayout.MakePaint(totalStr, fs, true);

            // Name, wrapped, left column
            float lineY = y + baseline;
            foreach (var line in nameLines)
            {
                TextLayout.DrawLine(canvas, line, namePaint, Padding, lineY);
                lineY += lineStep;
            }

            // Qty / Price / Total all sit on the first line's baseline
            float qtyX   = Width * 0.40f + (Width * 0.12f - TextLayout.MeasureWidth(qtyStr, qtyPaint)) / 2f;
            float priceX = Width * 0.60f + (Width * 0.20f - 30f - TextLayout.MeasureWidth(priceStr, pricePaint));
            float totalX = Width - 90f;

            TextLayout.DrawLine(canvas, qtyStr,   qtyPaint,   qtyX,   y + baseline);
            TextLayout.DrawLine(canvas, priceStr, pricePaint, priceX, y + baseline);
            TextLayout.DrawLine(canvas, totalStr, totalPaint, totalX, y + baseline);
        }

        // Height follows the actual line count instead of guessing "two lines".
        float nameH = baseline + (MathF.Max(nameLines.Count, 1) - 1) * lineStep;
        return y + nameH + 8f;
    }

    static void DrawWrappedText(SKCanvas canvas, string text, float fontSize, bool bold,
                                 float x, float y, float maxWidth)
    {
        using var paint = MakePaint(text, fontSize, bold);
        if (FontManager.IsArabic(text))
        {
            using var shaper = new SKShaper(paint.Typeface!);
            canvas.DrawShapedText(shaper, text, x, y + fontSize * 1.2f, paint);
            return;
        }

        // Simple word-wrap
        var words = text.Split(' ');
        var line  = new System.Text.StringBuilder();
        float lineY = y + MeasureTextHeight(text, fontSize, bold);
        foreach (var word in words)
        {
            string candidate = line.Length == 0 ? word : line + " " + word;
            if (MeasureText(candidate, fontSize, bold) <= maxWidth)
            {
                line.Clear();
                line.Append(candidate);
            }
            else
            {
                if (line.Length > 0)
                {
                    canvas.DrawText(line.ToString(), x, lineY, paint);
                    lineY += MeasureTextHeight(line.ToString(), fontSize, bold) + 2f;
                    line.Clear();
                }
                line.Append(word);
            }
        }
        if (line.Length > 0)
            canvas.DrawText(line.ToString(), x, lineY, paint);
    }

    // Total / subtotal row — matches Dart's _drawTotalRow()
    static float DrawTotalRow(SKCanvas? canvas, string label, string value, bool isTotal, float y)
    {
        float fontSize = isTotal ? FontSize - 2f : SmallFont - 6f;
        bool  bold     = isTotal;

        float labelW  = MeasureText(label, fontSize, bold);
        float valueW  = MeasureText(value, fontSize, bold);
        float textH   = MeasureTextHeight(label, fontSize, bold);
        float labelX  = Width * 0.60f - labelW;
        float valueX  = Width - Padding - valueW;

        if (canvas != null)
        {
            DrawLeftText(canvas, label, fontSize, bold, labelX, y);
            DrawLeftText(canvas, value, fontSize, bold, valueX, y);
        }

        return y + textH + 10f;
    }

    static SKPaint MakePaint(string text, float fontSize, bool bold)
    {
        var tf = FontManager.GetTypeface(text, bold);
        return new SKPaint
        {
            Typeface    = tf,
            TextSize    = fontSize,
            Color       = SKColors.Black,
            IsAntialias = true,
            TextAlign   = SKTextAlign.Left
        };
    }

    // ── Arabic detection ─────────────────────────────────────────────────────

    static bool DetectArabic(ReceiptPrintData d)
    {
        if (FontManager.IsArabic(d.BusinessName))       return true;
        if (FontManager.IsArabic(d.SecondBusinessName)) return true;
        if (FontManager.IsArabic(d.ServiceType))        return true;
        if (!string.IsNullOrEmpty(d.PersonName) && FontManager.IsArabic(d.PersonName)) return true;
        foreach (var item in d.Items)
        {
            if (FontManager.IsArabic(item.Name))        return true;
            if (FontManager.IsArabic(item.KitchenNote)) return true;
        }
        return false;
    }
}
