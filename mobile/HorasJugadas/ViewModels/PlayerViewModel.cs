using HorasJugadas.Core;

namespace HorasJugadas.ViewModels;

public sealed record CharRow(string Name, Color Color, string Info, string Played, string Deaths);

/// <summary>Instantánea de la ficha de un jugador; se recrea al llegar datos nuevos.</summary>
public sealed class PlayerViewModel(PlayerStats s, DateTimeOffset now)
{
    public string Nick { get; } = s.Nick;
    public Color Color { get; } = Color.FromArgb(Stats.ClassColor(s.MainClass));
    public string Today { get; } = Stats.FmtValue(Mode.Today, s.Today);
    public string Week { get; } = Stats.FmtValue(Mode.Week, s.Week);
    public string Month { get; } = Stats.FmtValue(Mode.Month, s.Month);
    public string Total { get; } = Stats.FmtValue(Mode.Total, s.Total);
    public string Deaths { get; } = Stats.FmtValue(Mode.Deaths, s.Deaths);
    public string Updated { get; } = $"Última subida {Stats.Ago(s.Updated, now)}";

    public IReadOnlyList<CharRow> Chars { get; } = s.Chars.Select(c => new CharRow(
        c.CharKey,
        Color.FromArgb(Stats.ClassColor(c.Class)),
        $"{Stats.ClassName(c.Class)} · Nivel {c.Level?.ToString() ?? "?"}",
        Stats.Fmt(c.PlayedSeconds),
        $"{Stats.FmtCount(c.Deaths)} {(c.Deaths == 1 ? "muerte" : "muertes")}")).ToList();
}
