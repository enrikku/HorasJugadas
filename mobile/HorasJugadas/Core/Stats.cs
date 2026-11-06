using System.Globalization;

namespace HorasJugadas.Core;

/// <summary>Cálculo de rankings y formatos, portado de web/index.html.</summary>
public static class Stats
{
    public const int DayCount = 30;

    private static readonly CultureInfo Spanish = CultureInfo.GetCultureInfo("es-ES");

    public static readonly IReadOnlyList<(Mode Mode, string Label)> Modes =
    [
        (Mode.Today, "Hoy"),
        (Mode.Week, "7 días"),
        (Mode.Month, "30 días"),
        (Mode.Total, "Total /played"),
        (Mode.Deaths, "Muertes"),
    ];

    private static readonly Dictionary<string, (string Color, string Name)> Classes = new()
    {
        ["DEATHKNIGHT"] = ("#C41E3A", "Caballero de la Muerte"),
        ["DEMONHUNTER"] = ("#A330C9", "Cazador de demonios"),
        ["DRUID"] = ("#FF7C0A", "Druida"),
        ["EVOKER"] = ("#33937F", "Evocador"),
        ["HUNTER"] = ("#AAD372", "Cazador"),
        ["MAGE"] = ("#3FC7EB", "Mago"),
        ["MONK"] = ("#00FF98", "Monje"),
        ["PALADIN"] = ("#F48CBA", "Paladín"),
        ["PRIEST"] = ("#FFFFFF", "Sacerdote"),
        ["ROGUE"] = ("#FFF468", "Pícaro"),
        ["SHAMAN"] = ("#0070DD", "Chamán"),
        ["WARLOCK"] = ("#8788EE", "Brujo"),
        ["WARRIOR"] = ("#C69B6D", "Guerrero"),
    };

    public static string ClassColor(string? c) =>
        c is not null && Classes.TryGetValue(c, out var v) ? v.Color : "#C9CCD6";

    public static string ClassName(string? c) =>
        c is not null && Classes.TryGetValue(c, out var v) ? v.Name : string.IsNullOrEmpty(c) ? "?" : c;

    /// <summary>Fecha local "AAAA-MM-DD" de hace <paramref name="offset"/> días.</summary>
    public static string DayKey(int offset, DateTime now) =>
        now.AddDays(-offset).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    /// <summary>Los últimos <paramref name="n"/> días, del más antiguo a hoy.</summary>
    public static string[] LastDays(int n, DateTime now) =>
        Enumerable.Range(0, n).Select(i => DayKey(n - 1 - i, now)).ToArray();

    /// <summary>"2026-11-06" -> "06/11"</summary>
    public static string ShortDate(string day) => $"{day[8..]}/{day[5..7]}";

    public static string Fmt(long seconds)
    {
        long h = seconds / 3600, m = seconds % 3600 / 60;
        return h != 0 ? $"{h}h {m:00}m" : $"{m}m";
    }

    public static string FmtCount(long n) => n.ToString("N0", Spanish);

    public static string FmtValue(Mode mode, long value) =>
        mode == Mode.Deaths ? FmtCount(value) : Fmt(value);

    public static string Ago(DateTimeOffset when, DateTimeOffset now)
    {
        var min = Math.Round((now - when).TotalMinutes, MidpointRounding.AwayFromZero);
        if (min < 1) return "ahora";
        if (min < 60) return $"hace {min} min";
        if (min < 1440) return $"hace {Math.Round(min / 60, MidpointRounding.AwayFromZero)} h";
        return $"hace {Math.Round(min / 1440, MidpointRounding.AwayFromZero)} d";
    }

    public static Dictionary<string, PlayerStats> Build(Dataset data, DateTime now)
    {
        var today = DayKey(0, now);
        var week = DayKey(6, now);
        var map = data.Players.ToDictionary(
            p => p.Nick,
            p => new PlayerStats { Nick = p.Nick, Updated = p.UpdatedAt });

        foreach (var d in data.Days)
        {
            if (!map.TryGetValue(d.Nick, out var s)) continue;
            s.Days[d.Day] = d.Seconds;
            s.Month += d.Seconds;
            if (string.CompareOrdinal(d.Day, week) >= 0) s.Week += d.Seconds;
            if (d.Day == today) s.Today += d.Seconds;
        }
        foreach (var c in data.Chars)
        {
            if (!map.TryGetValue(c.Nick, out var s)) continue;
            s.Chars.Add(c);
            s.Total += c.PlayedSeconds;
            s.Deaths += c.Deaths;
        }
        foreach (var s in map.Values)
        {
            s.Chars.Sort((a, b) => b.PlayedSeconds.CompareTo(a.PlayedSeconds));
            s.MainClass = s.Chars.Count > 0 ? s.Chars[0].Class : null;
        }
        return map;
    }

    public static List<PlayerStats> Ranking(IEnumerable<PlayerStats> stats, Mode mode) =>
        stats.OrderByDescending(s => s.Value(mode))
             .ThenBy(s => s.Nick, StringComparer.Create(Spanish, ignoreCase: false))
             .ToList();

    /// <summary>Opacidad de una casilla de actividad: 6 h o más = color pleno.</summary>
    public static float HeatOpacity(int seconds) =>
        seconds > 0 ? 0.2f + 0.8f * Math.Min(1f, seconds / (6f * 3600)) : 0f;
}
