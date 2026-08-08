using System.Linq;
using System.Reflection;
using SkiaSharp;

namespace CafePrinter;

public static class FontManager
{
    public static readonly SKTypeface OpenSansRegular = LoadFont("open-sans.regular.ttf");
    public static readonly SKTypeface OpenSansBold    = LoadFont("open-sans.bold.ttf");
    public static readonly SKTypeface CairoRegular    = LoadFont("cairo-regular.ttf");
    public static readonly SKTypeface CairoBold       = LoadFont("cairo-bold.ttf");

    static SKTypeface LoadFont(string fileName)
    {
        var asm = Assembly.GetExecutingAssembly();
        var resourceName = $"CafePrinter.fonts.{fileName}";
        using var stream = asm.GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException($"Embedded font not found: {resourceName}");
        return SKTypeface.FromStream(stream);
    }

    public static bool IsArabic(string text) =>
        text.Any(c => c >= 0x0600 && c <= 0x06FF);

    public static bool HasArabic(params string?[] texts) =>
        texts.Any(t => t != null && IsArabic(t));

    public static SKTypeface GetTypeface(string text, bool bold) =>
        IsArabic(text)
            ? (bold ? CairoBold : CairoRegular)
            : (bold ? OpenSansBold : OpenSansRegular);
}
