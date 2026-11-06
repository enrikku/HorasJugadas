using HorasJugadas.Core;
using HorasJugadas.ViewModels;

namespace HorasJugadas.Controls;

/// <summary>Rejilla de casillas de bolsa, dibujada de una vez: 30 días por jugador serían muchas vistas.</summary>
public sealed class HeatmapDrawable : IDrawable
{
    public const float Cell = 20, Gap = 3, Header = 21;

    public IReadOnlyList<HeatRow> Rows { get; set; } = [];
    public string[] Days { get; set; } = [];

    public double ContentWidth => Days.Length * (Cell + Gap) - Gap;
    public double ContentHeight => Header + Rows.Count * (Cell + Gap);

    public void Draw(ICanvas canvas, RectF dirtyRect)
    {
        canvas.Font = new Microsoft.Maui.Graphics.Font("AlegreyaRegular");
        canvas.FontSize = 12;
        canvas.FontColor = Color.FromArgb("#AEA48D");
        for (var d = 0; d < Days.Length; d++)
        {
            if (d % 5 == 4 || d == Days.Length - 1)
                canvas.DrawString(Days[d][8..], X(d) - 4, 0, Cell + 8, Header - 3, HorizontalAlignment.Center, VerticalAlignment.Center);
        }

        for (var r = 0; r < Rows.Count; r++)
        {
            var y = Header + r * (Cell + Gap);
            for (var d = 0; d < Days.Length; d++)
            {
                var x = X(d);
                canvas.FillColor = Color.FromArgb("#050403");
                canvas.FillRoundedRectangle(x, y, Cell, Cell, 2);
                canvas.StrokeSize = 1;
                canvas.StrokeColor = Color.FromArgb("#3B362C");
                canvas.DrawRoundedRectangle(x + .5f, y + .5f, Cell - 1, Cell - 1, 2);

                var seconds = Rows[r].Days.GetValueOrDefault(Days[d]);
                if (seconds > 0)
                {
                    canvas.FillColor = Rows[r].Color.WithAlpha(Stats.HeatOpacity(seconds));
                    canvas.FillRoundedRectangle(x + 2, y + 2, Cell - 4, Cell - 4, 1);
                }
            }
        }
    }

    public (HeatRow Row, string Day)? HitTest(Point p)
    {
        var r = (int)((p.Y - Header) / (Cell + Gap));
        var d = (int)(p.X / (Cell + Gap));
        if (p.Y < Header || r >= Rows.Count || d < 0 || d >= Days.Length) return null;
        return (Rows[r], Days[d]);
    }

    private static float X(int day) => day * (Cell + Gap);
}
