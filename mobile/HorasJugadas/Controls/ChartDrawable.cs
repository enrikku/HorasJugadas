namespace HorasJugadas.Controls;

/// <summary>Gráfica de barras de los últimos 30 días de un jugador.</summary>
public sealed class ChartDrawable : IDrawable
{
    private const float ChartHeight = 170, TopPadding = 18, SidePadding = 4, BarGap = 3, GridStep = 38;

    public const double TotalHeight = ChartHeight + 22;

    public string[] Days { get; set; } = [];
    public IReadOnlyDictionary<string, int> Seconds { get; set; } = new Dictionary<string, int>();
    public Color Color { get; set; } = Colors.White;
    public string Today { get; set; } = "";

    public void Draw(ICanvas canvas, RectF rect)
    {
        canvas.FillColor = Color.FromArgb("#0C0A07");
        canvas.FillRoundedRectangle(0, 0, rect.Width, ChartHeight, 3);

        canvas.StrokeSize = 1;
        canvas.StrokeColor = Color.FromRgba(255, 255, 255, 13);
        for (var y = ChartHeight - 1; y > TopPadding; y -= GridStep)
            canvas.DrawLine(0, y, rect.Width, y);

        canvas.StrokeColor = Color.FromArgb("#3B362C");
        canvas.DrawRoundedRectangle(.5f, .5f, rect.Width - 1, ChartHeight - 1, 3);

        if (Days.Length == 0) return;
        var max = Math.Max(1, Days.Max(d => Seconds.GetValueOrDefault(d)));
        var slot = (rect.Width - 2 * SidePadding + BarGap) / Days.Length;
        var barArea = ChartHeight - TopPadding - 1;

        canvas.Font = new Microsoft.Maui.Graphics.Font("AlegreyaRegular");
        canvas.FontSize = 12;
        canvas.FontColor = Color.FromArgb("#AEA48D");

        for (var i = 0; i < Days.Length; i++)
        {
            var x = SidePadding + i * slot;
            var height = Math.Max(1, barArea * Seconds.GetValueOrDefault(Days[i]) / max);
            canvas.FillColor = Color.WithAlpha(Days[i] == Today ? 1f : 0.7f);
            canvas.FillRectangle(x, ChartHeight - 1 - height, slot - BarGap, height);

            if (i % 5 == 4)
                canvas.DrawString(Days[i][8..], x - 10, ChartHeight + 2, slot - BarGap + 20, 18, HorizontalAlignment.Center, VerticalAlignment.Center);
        }
    }

    public string? HitTest(Point p, double width)
    {
        if (Days.Length == 0) return null;
        var slot = (width - 2 * SidePadding + BarGap) / Days.Length;
        var i = (int)((p.X - SidePadding) / slot);
        return p.X >= SidePadding && i < Days.Length ? Days[i] : null;
    }
}
