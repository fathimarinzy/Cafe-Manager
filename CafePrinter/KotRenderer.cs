using System;
using System.Collections.Generic;
using System.Linq;
using SkiaSharp;
using SkiaSharp.HarfBuzz;

namespace CafePrinter;

// Replicates _generateKotImage() from thermal_printer_service.dart exactly.
// Canvas: 512px wide × dynamic height, white background. No logo.
public static class KotRenderer
{
    const float Width     = 512f;
    const float Padding   = 12f;
    const float FontSize  = 32f;
    const float SmallFont = 38f;
    const float LargeFont = 52f;

    public static SKBitmap Render(KotPrintData d)
    {
        float height = MeasureHeight(d);
        var bitmap = new SKBitmap((int)Width, (int)height, SKColorType.Bgra8888, SKAlphaType.Premul);
        using var canvas = new SKCanvas(bitmap);
        canvas.Clear(SKColors.White);

        float y = Padding;
        Draw(canvas, d, ref y);
        return bitmap;
    }

    static float MeasureHeight(KotPrintData d)
    {
        float y = Padding;
        Draw(null, d, ref y);
        y += Padding;
        return y;
    }

    static void Draw(SKCanvas? canvas, KotPrintData d, ref float y)
    {
        // KITCHEN ORDER header
        float h = DrawCenteredText(canvas, "KITCHEN ORDER", LargeFont - 6f, bold: true, y: y);
        y += h + 8f;

        // EDITED box (if edited)
        if (d.IsEdited)
        {
            float editedH = DrawCenteredText(null, "EDITED", FontSize - 2f, bold: true, y: y);
            float editedW = MeasureText("EDITED", FontSize - 2f, true);
            float editedX = (Width - editedW) / 2f;
            if (canvas != null)
            {
                using var borderPaint = new SKPaint { Color = SKColors.Black, StrokeWidth = 1f, IsStroke = true };
                canvas.DrawRect(editedX - 10f, y - 5f, editedW + 20f, editedH + 10f, borderPaint);
                DrawCenteredText(canvas, "EDITED", FontSize - 2f, bold: true, y: y);
            }
            y += editedH + 8f;
        }

        // ORDER #
        string orderNum = string.IsNullOrEmpty(d.OrderNumber)
            ? (DateTime.Now.Ticks % 10000).ToString()
            : d.OrderNumber;
        y += DrawCenteredText(canvas, $"ORDER #{orderNum}", FontSize, bold: true, y: y) + 8f;

        // Date/time
        var now = DateTime.Now;
        string dateStr = $"{now.Day:D2}-{now.Month:D2}-{now.Year} at {now.Hour:D2}:{now.Minute:D2}";
        y += DrawCenteredText(canvas, dateStr, FontSize - 4f, bold: false, y: y) + 8f;

        // Service type
        y += DrawCenteredText(canvas, $"Service: {d.ServiceType}", FontSize, bold: true, y: y) + 8f;

        // Divider
        y += 10f;
        DrawLine(canvas, y, 4f);
        y += 4f + 8f;

        // KOT header: Item (left) | Qty (right)
        float headerH = MeasureTextHeight("Item", SmallFont, true);
        if (canvas != null)
        {
            DrawLeftText(canvas, "Item", SmallFont, true, Padding, y);
            float qtyW = MeasureText("Qty", SmallFont, true);
            DrawLeftText(canvas, "Qty", SmallFont, true, Width - Padding - qtyW, y);
        }
        y += headerH + 8f;

        DrawLine(canvas, y, 4f);
        y += 4f + 8f;

        // Items
        if (!d.IsEdited || d.OriginalItems == null)
        {
            foreach (var item in d.Items)
                y = DrawKotItem(canvas, item.Name, item.Quantity, item.KitchenNote, y, boxed: false);
        }
        else
        {
            // Compute diff — matches Dart logic exactly
            var cancelled = d.OriginalItems
                .Where(orig => !d.Items.Any(cur =>
                    cur.Id == orig.Id.ToString() && cur.Quantity >= orig.Quantity))
                .ToList();

            var newItems = d.Items
                .Where(cur => !d.OriginalItems.Any(orig => orig.Id.ToString() == cur.Id))
                .ToList();

            var increased = d.Items
                .Where(cur =>
                {
                    var orig = d.OriginalItems.FirstOrDefault(o => o.Id.ToString() == cur.Id);
                    return orig != null && cur.Quantity > orig.Quantity;
                })
                .Select(cur =>
                {
                    var orig = d.OriginalItems.First(o => o.Id.ToString() == cur.Id);
                    return cur with { Quantity = cur.Quantity - orig.Quantity };
                })
                .ToList();

            // Cancelled items section
            if (cancelled.Count > 0)
            {
                float lh = DrawLeftText(canvas, "CANCELLED:", FontSize - 2f, true, Padding, y);
                y += lh + 8f;
                foreach (var orig in cancelled)
                {
                    // Prefer the live item, then the name carried on the original
                    // item, and only fall back to the raw id if neither is present.
                    var match = d.Items.FirstOrDefault(i => i.Id == orig.Id.ToString());
                    string name = match?.Name
                                  ?? (string.IsNullOrWhiteSpace(orig.Name) ? $"#{orig.Id}" : orig.Name);
                    y = DrawKotItem(canvas, name, orig.Quantity, "", y, boxed: true);
                }
                y += 10f;
            }

            // New / increased items section
            var addedItems = newItems.Concat(increased).ToList();
            if (addedItems.Count > 0)
            {
                float lh = DrawLeftText(canvas, "NEW ITEMS:", FontSize - 2f, true, Padding, y);
                y += lh + 8f;
                foreach (var item in addedItems)
                    y = DrawKotItem(canvas, item.Name, item.Quantity, item.KitchenNote, y, boxed: false);
            }
        }

        // Final closing line (drawn directly, no spacing after)
        if (canvas != null)
        {
            using var paint = new SKPaint { Color = SKColors.Black, StrokeWidth = 4f, IsStroke = true };
            canvas.DrawLine(Padding, y, Width - Padding, y, paint);
        }
    }

    // Draw one KOT item row. boxed=true draws a stroke box around the name (cancelled item).
    static float DrawKotItem(SKCanvas? canvas, string name, int qty, string? note, float y, bool boxed)
    {
        float nameH    = MeasureTextHeight(name, SmallFont, false);
        float qtyStr_W = MeasureText(qty.ToString(), SmallFont, true);
        float qtyX     = Width - Padding - qtyStr_W;

        if (canvas != null)
        {
            if (boxed)
            {
                float nameW = MeasureText(name, SmallFont, false);
                using var borderPaint = new SKPaint { Color = SKColors.Black, StrokeWidth = 1f, IsStroke = true };
                canvas.DrawRect(Padding - 5f, y - 3f, (Width - 24f) + 10f, nameH + 6f, borderPaint);
            }
            DrawLeftText(canvas, name, SmallFont, false, Padding, y);
            DrawLeftText(canvas, qty.ToString(), SmallFont, true, qtyX, y);
        }

        y += nameH + 8f;

        if (!string.IsNullOrEmpty(note))
        {
            float noteH = DrawCenteredText(canvas, $"NOTE: {note}", SmallFont - 2f, bold: true, y: y,
                                           x: Padding * 1.5f, align: SKTextAlign.Left);
            y += noteH + 8f;
        }

        y += 10f;
        return y;
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    static float DrawCenteredText(SKCanvas? canvas, string text, float fontSize, bool bold, float y,
                                   float x = 0, SKTextAlign align = SKTextAlign.Center)
    {
        if (string.IsNullOrEmpty(text)) return 0f;

        // Routed through TextLayout so mixed Latin+Arabic strings are split into
        // directional runs; shaping the whole string at once reversed the Arabic.
        using var paint = TextLayout.MakePaint(text, fontSize, bold);
        float tw = TextLayout.MeasureWidth(text, paint);
        float th = TextLayout.TextHeight(text, fontSize, bold);
        float dx = align == SKTextAlign.Center ? (Width - tw) / 2f : x;

        if (canvas != null)
            TextLayout.DrawLine(canvas, text, paint, dx, y + th);

        return th;
    }

    static float DrawLeftText(SKCanvas? canvas, string text, float fontSize, bool bold, float x, float y)
    {
        if (string.IsNullOrEmpty(text)) return 0f;

        using var paint = TextLayout.MakePaint(text, fontSize, bold);
        float h = TextLayout.TextHeight(text, fontSize, bold);

        if (canvas != null)
            TextLayout.DrawLine(canvas, text, paint, x, y + h);

        return h;
    }

    // Delegates to the shared helper - the old local version returned
    // fontSize * 1.2f (a height) as the width of any Arabic string.
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

    static SKPaint MakePaint(string text, float fontSize, bool bold) => new SKPaint
    {
        Typeface    = FontManager.GetTypeface(text, bold),
        TextSize    = fontSize,
        Color       = SKColors.Black,
        IsAntialias = true,
        TextAlign   = SKTextAlign.Left
    };
}
