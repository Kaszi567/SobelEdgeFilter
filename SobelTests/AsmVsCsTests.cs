
// ============================================================
// Temat:      Porownanie filtru Sobela w C# i ASM
// Opis:       Test zgodnosci wyniku obu bibliotek bajt po bajcie.
// Autor:      Julia Pleszewska
// Rok/sem.:   2026/2027, semestr zimowy
// Data:       22.11.2026
// Wersje:
//   v0.1 22.11.2026 Julia P - testy zgodnosci C# i ASM
// ============================================================

using System;
using System.Runtime.InteropServices;
using SobelLibCs;
using Xunit;

namespace SobelTests;

/// <summary>
/// Porownuje wyniki SobelAsm i SobelCs.Apply bajt po bajcie.
/// </summary>
public class AsmVsCsTests
{
    /// <summary>
    /// Funkcja ASM: src, dst, szerokosc, wysokosc, prog (0..2040).
    /// </summary>
    [DllImport("SobelLibAsm.dll")]
    private static extern void SobelAsm(
        byte[] src, [In, Out] byte[] dst,
        int width, int height, int threshold);

    /// <summary>Tworzy losowy obraz Gray8 o ustalonym ziarnie.</summary>
    private static byte[] RandomImage(int w, int h, int seed)
    {
        var img = new byte[w * h];
        new Random(seed).NextBytes(img);
        return img;
    }

    /// <summary>Tworzy obraz z pionowymi i poziomymi pasami.</summary>
    private static byte[] StripesImage(int w, int h)
    {
        var img = new byte[w * h];

        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
                img[y * w + x] =
                    (byte)(((x / 7) + (y / 5)) % 2 == 0 ? 30 : 220);

        return img;
    }

    // Male i duze szerokosci sprawdzaja petle skalarna i AVX2.
    [Theory]
    [InlineData(3, 3)]
    [InlineData(4, 5)]
    [InlineData(17, 5)]
    [InlineData(18, 7)]
    [InlineData(19, 4)]
    [InlineData(33, 10)]
    [InlineData(100, 13)]
    [InlineData(641, 480)]
    [InlineData(1920, 1080)]
    public void WynikAsmTakiSamJakCs(int w, int h)
    {
        int[] thresholds =
            { 0, 1, 100, 200, 1020, 2039, 2040 };

        byte[][] images =
        {
            RandomImage(w, h, 42),
            StripesImage(w, h)
        };

        foreach (byte[] src in images)
        {
            foreach (int t in thresholds)
            {
                var expected = new byte[w * h];
                var actual = new byte[w * h];

                // Kontrola zerowania ramki w ASM.
                Array.Fill(actual, (byte)0xAB);

                SobelCs.Apply(src, expected, w, h, t);
                SobelAsm(src, actual, w, h, t);

                Assert.True(
                    expected.AsSpan().SequenceEqual(actual),
                    $"Roznica dla {w}x{h}, prog {t}");
            }
        }
    }
}
