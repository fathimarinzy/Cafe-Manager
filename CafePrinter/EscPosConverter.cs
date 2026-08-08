using System.Collections.Generic;
using SkiaSharp;

namespace CafePrinter;

public static class EscPosConverter
{
    // Converts a SkiaSharp bitmap to a list of ESC/POS raw bytes.
    // Matches the logic in the Dart convertImageOnIsolate() function.
    public static List<byte> ToEscPos(SKBitmap source, bool openDrawer, bool isKot)
    {
        var bytes = new List<byte>();

        // ESC @ — reset printer
        bytes.AddRange(new byte[] { 0x1B, 0x40 });

        // Ensure width is exactly 512px (same as Dart's copyResize step)
        SKBitmap bitmap = source;
        if (source.Width != 512)
        {
            var info = new SKImageInfo(512, source.Height * 512 / source.Width);
            bitmap = source.Resize(info, SKFilterQuality.High)
                     ?? throw new InvalidOperationException("Bitmap resize failed");
        }

        // Convert to grayscale (matches Dart's img.grayscale())
        var grayInfo = new SKImageInfo(bitmap.Width, bitmap.Height, SKColorType.Gray8, SKAlphaType.Opaque);
        using var grayBitmap = new SKBitmap(grayInfo);
        using (var canvas = new SKCanvas(grayBitmap))
        {
            using var paint = new SKPaint();
            paint.ColorFilter = SKColorFilter.CreateColorMatrix(new float[]
            {
                0.299f, 0.587f, 0.114f, 0, 0,
                0.299f, 0.587f, 0.114f, 0, 0,
                0.299f, 0.587f, 0.114f, 0, 0,
                0,      0,      0,      1, 0
            });
            canvas.DrawBitmap(bitmap, 0, 0, paint);
        }

        // GS v 0 — raster bit image command
        int widthBytes = (grayBitmap.Width + 7) / 8;
        int height     = grayBitmap.Height;
        bytes.AddRange(new byte[]
        {
            0x1D, 0x76, 0x30, 0x00,
            (byte)(widthBytes & 0xFF), (byte)(widthBytes >> 8),
            (byte)(height & 0xFF),     (byte)(height >> 8)
        });

        // Pack pixels: 1=black, 0=white, MSB first, threshold at 128
        for (int y = 0; y < height; y++)
        {
            for (int bx = 0; bx < widthBytes; bx++)
            {
                byte b = 0;
                for (int bit = 0; bit < 8; bit++)
                {
                    int px = bx * 8 + bit;
                    if (px < grayBitmap.Width)
                    {
                        var color = grayBitmap.GetPixel(px, y);
                        // Gray8: red channel holds the gray value
                        if (color.Red < 128)
                            b |= (byte)(0x80 >> bit);
                    }
                }
                bytes.Add(b);
            }
        }

        // GS V B 0 — full cut
        bytes.AddRange(new byte[] { 0x1D, 0x56, 0x42, 0x00 });

        // ESC p — open cash drawer (port 0, pulse 25ms on / 250ms off)
        if (openDrawer && !isKot)
            bytes.AddRange(new byte[] { 0x1B, 0x70, 0x00, 0x19, 0xFA });

        if (bitmap != source)
            bitmap.Dispose();

        return bytes;
    }
}
