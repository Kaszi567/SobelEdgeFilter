using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;
using System.Runtime.InteropServices;

namespace SobelEdgeFilter
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    

    public partial class MainWindow : Window
    {
        [DllImport("SobelLibAsm.dll")]
        private static extern int TestAdd(int a, int b);

        public MainWindow()
        {
            InitializeComponent();
            MessageBox.Show($"ASM: 2 + 3 = {TestAdd(2, 3)}");
        }
    }
}