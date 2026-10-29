namespace SobelTests;
using SobelLibCs;
using System.Linq;

public class SobelCsTests
{
    [Fact]
    public void PionowaKrawedz_DajeBialaLinie()
    {
        // lewe 2 kolumny czarne, prawe 3 białe
        byte[] src =
        {
            0, 0, 255, 255, 255,
            0, 0, 255, 255, 255,
            0, 0, 255, 255, 255,
            0, 0, 255, 255, 255,
            0, 0, 255, 255, 255,
        };
        byte[] expected =
        {
            0,   0,   0, 0, 0,   // ramka
            0, 255, 255, 0, 0,   // krawędź w kolumnach 1 i 2
            0, 255, 255, 0, 0,
            0, 255, 255, 0, 0,
            0,   0,   0, 0, 0,   // ramka
        };
        var dst = new byte[25];

        SobelCs.Apply(src, dst, 5, 5, 100);

        Assert.Equal(expected, dst);
    }

    [Fact]
    public void JednolityObraz_DajeSameZera()
    {
        var src = Enumerable.Repeat((byte)128, 25).ToArray();
        var dst = new byte[25];

        SobelCs.Apply(src, dst, 5, 5, 1);

        Assert.All(dst, v => Assert.Equal(0, v));
    }
}
