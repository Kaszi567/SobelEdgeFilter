// ============================================================
// Temat:      Wykrywanie krawędzi filtrem Sobela (C# vs ASM x64 AVX2)
// Opis:       Referencyjna implementacja filtru Sobela w C#.
//             Przetwarza obraz Gray8 na binarną mapę krawędzi.
// Wersje:
//   v0.1 28.10.2026
// ============================================================

using System;

namespace SobelLibCs
{
    /// <summary>
    /// Referencyjna implementacja filtru Sobela w C#.
    /// </summary>
    public static class SobelCs
    {
        /// <summary>
        /// Wykrywa krawędzie za pomocą filtru Sobela.
        /// Wynik binarny (0 lub 255) zapisuje do dst.
        /// Ramka obrazu ma zawsze wartość 0.
        /// </summary>
        /// <param name="src">
        /// Obraz wejściowy Gray8, width * height bajtów (0..255).
        /// </param>
        /// <param name="dst">
        /// Osobna tablica wyjściowa, width * height bajtów.
        /// </param>
        /// <param name="width">Szerokość: 3..16384.</param>
        /// <param name="height">Wysokość: 3..16384.</param>
        /// <param name="threshold">Próg: 0..2040.</param>
        public static void Apply(
            byte[] src,
            byte[] dst,
            int width,
            int height,
            int threshold)
        {
            // Walidacja tablic
            ArgumentNullException.ThrowIfNull(src);
            ArgumentNullException.ThrowIfNull(dst);

            // Walidacja wymiarów
            if (width < 3 || width > 16384 ||
                height < 3 || height > 16384)
            {
                throw new ArgumentOutOfRangeException(
                    nameof(width),
                    "Wymiary obrazu muszą być w zakresie 3..16384.");
            }

            // Walidacja progu
            if (threshold < 0 || threshold > 2040)
            {
                throw new ArgumentOutOfRangeException(
                    nameof(threshold),
                    "Próg musi być w zakresie 0..2040.");
            }

            int pixelCount = width * height;

            // Sprawdzenie rozmiaru tablic
            if (src.Length < pixelCount ||
                dst.Length < pixelCount)
            {
                throw new ArgumentException(
                    "Tablice są za małe dla podanych wymiarów.");
            }

            // Wejście i wyjście muszą być osobnymi tablicami
            if (ReferenceEquals(src, dst))
            {
                throw new ArgumentException(
                    "src i dst muszą być osobnymi tablicami.");
            }

            // Wyzerowanie wyniku, w tym ramki obrazu
            Array.Clear(dst, 0, pixelCount);

            // Przetwarzanie pikseli wewnętrznych
            for (int y = 1; y < height - 1; y++)
            {
                for (int x = 1; x < width - 1; x++)
                {
                    int i = y * width + x;

                    // Odczyt 8 sąsiadów
                    int tl = src[i - width - 1];
                    int t = src[i - width];
                    int tr = src[i - width + 1];

                    int l = src[i - 1];
                    int r = src[i + 1];

                    int bl = src[i + width - 1];
                    int b = src[i + width];
                    int br = src[i + width + 1];

                    // Gradient poziomy
                    int gx = (tr + 2 * r + br)
                           - (tl + 2 * l + bl);

                    // Gradient pionowy
                    int gy = (bl + 2 * b + br)
                           - (tl + 2 * t + tr);

                    // Uproszczona wartość gradientu
                    int g = Math.Abs(gx) + Math.Abs(gy);

                    // Binaryzacja wyniku
                    dst[i] = g >= threshold
                        ? (byte)255
                        : (byte)0;
                }
            }
        }
    }
}

