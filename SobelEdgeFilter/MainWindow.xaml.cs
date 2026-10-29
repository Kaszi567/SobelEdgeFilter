// ============================================================
// Temat:      Wykrywanie krawędzi filtrem Sobela (C# vs ASM x64 AVX2)
// Opis:       Okno główne aplikacji WPF. Wczytuje obraz z dysku,
//             konwertuje go do skali szarości (1 bajt na piksel)
//             i wyświetla oryginał oraz wynik przetwarzania.
//             Algorytm: dla każdego piksela liczone są gradienty
//             Gx i Gy maskami Sobela 3x3, G = |Gx| + |Gy|,
//             wynik = 255 gdy G >= próg, inaczej 0.
// Autor:      Dawid Kasza
// Rok/sem.:   2026, semestr 5
// Data:       23-28.10.2026
// Wersje:
//   v0.1  23.10.2026  Dawid  szkielet, test wywołania DLL ASM
//   v0.2  29.10.2026  Dawid  wczytywanie obrazu, konwersja Gray8
// ============================================================

using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;

namespace SobelEdgeFilter
{
    /// <summary>
    /// Okno główne: wczytywanie obrazu, konwersja do skali szarości
    /// i wyświetlanie oryginału obok wyniku.
    /// </summary>
    public partial class MainWindow : Window
    {
        /// <summary>Obraz w skali szarości, width*height bajtów (0..255), wiersz po wierszu. Null, gdy nic nie wczytano.</summary>
        private byte[]? _gray;

        /// <summary>Szerokość wczytanego obrazu w pikselach (1..16384).</summary>
        private int _w;

        /// <summary>Wysokość wczytanego obrazu w pikselach (1..16384).</summary>
        private int _h;

        /// <summary>Konstruktor okna: inicjalizuje kontrolki zdefiniowane w XAML.</summary>
        public MainWindow()
        {
            InitializeComponent();
        }

        /// <summary>
        /// Konwertuje obraz do skali szarości: 1 bajt na piksel, układ y*width + x.
        /// </summary>
        /// <param name="img">Obraz wejściowy w dowolnym formacie pikseli.</param>
        /// <param name="w">Wyjście: szerokość obrazu w pikselach.</param>
        /// <param name="h">Wyjście: wysokość obrazu w pikselach.</param>
        /// <returns>Tablica w*h bajtów, wartości 0 (czarny) .. 255 (biały).</returns>
        private static byte[] ToGray(BitmapSource img, out int w, out int h)
        {
            // WPF sam przelicza kolory na odcienie szarości przy konwersji do Gray8
            var gray = new FormatConvertedBitmap(img, PixelFormats.Gray8, null, 0);
            w = gray.PixelWidth;
            h = gray.PixelHeight;

            var data = new byte[w * h];
            gray.CopyPixels(data, w, 0);   // stride = w, bo 1 bajt na piksel
            return data;
        }

        /// <summary>
        /// Tworzy obraz do wyświetlenia z tablicy bajtów w skali szarości.
        /// </summary>
        /// <param name="data">Piksele, w*h bajtów, wartości 0..255.</param>
        /// <param name="w">Szerokość w pikselach, 1..16384.</param>
        /// <param name="h">Wysokość w pikselach, 1..16384.</param>
        /// <returns>Obraz w formacie Gray8 gotowy do przypisania do kontrolki Image.</returns>
        private static BitmapSource FromGray(byte[] data, int w, int h)
        {
            return BitmapSource.Create(w, h, 96, 96, PixelFormats.Gray8, null, data, w);
        }

        /// <summary>
        /// Obsługa przycisku „Wczytaj obraz”: wybór pliku, wczytanie, konwersja i wyświetlenie.
        /// Błędny plik nie przerywa działania programu, tylko pokazuje komunikat.
        /// </summary>
        private void BtnLoad_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog { Filter = "Obrazy|*.png;*.jpg;*.jpeg;*.bmp" };
            if (dlg.ShowDialog() != true) return;   // użytkownik anulował wybór

            try
            {
                var bmp = new BitmapImage();
                bmp.BeginInit();
                bmp.CacheOption = BitmapCacheOption.OnLoad;   // wczytaj od razu i zwolnij plik
                bmp.UriSource = new Uri(dlg.FileName);
                bmp.EndInit();

                ImgSource.Source = bmp;
                _gray = ToGray(bmp, out _w, out _h);
                ImgResult.Source = FromGray(_gray, _w, _h);
                TxtStatus.Text = $"Wczytano: {System.IO.Path.GetFileName(dlg.FileName)} ({_w} × {_h} px)";
            }
            catch (Exception ex)
            {
                // walidacja wejścia: uszkodzony plik albo plik, który nie jest obrazem
                MessageBox.Show("Nie udało się wczytać obrazu:\n" + ex.Message,
                                "Błąd", MessageBoxButton.OK, MessageBoxImage.Error);
                TxtStatus.Text = "Błąd wczytywania obrazu";
            }
        }
    }
}