using System.Text.Json;
using HorasJugadas.Core;
using Xunit;

namespace HorasJugadas.Tests;

public class StatsTests
{
    private static readonly DateTime Now = new(2026, 11, 6, 12, 0, 0);
    private static readonly DateTimeOffset T = new(2026, 11, 6, 10, 0, 0, TimeSpan.Zero);

    private static Character Char(string nick, string key, string cls, long played, long deaths = 0) =>
        new(nick, key, cls, 80, played, deaths);

    private static readonly Dataset Data = new(
        [new("Ana", T), new("Bea", T), new("Cris", T)],
        [
            new("Ana", "2026-11-06", 3600),
            new("Ana", "2026-10-31", 1800), // límite de los 7 días: cuenta
            new("Ana", "2026-10-30", 900),  // fuera de los 7 días
            new("Bea", "2026-11-05", 7200),
            new("Fantasma", "2026-11-06", 60), // sin jugador: se ignora
        ],
        [
            Char("Ana", "Aa-Reino", "MAGE", 100, 3),
            Char("Ana", "Ab-Reino", "PRIEST", 500, 4),
            Char("Bea", "Ba-Reino", "ROGUE", 50, 10),
        ]);

    [Fact]
    public void Build_agrega_por_periodo_y_personaje()
    {
        var ana = Stats.Build(Data, Now)["Ana"];
        Assert.Equal(3600, ana.Today);
        Assert.Equal(5400, ana.Week);
        Assert.Equal(6300, ana.Month);
        Assert.Equal(600, ana.Total);
        Assert.Equal(7, ana.Deaths);
    }

    [Fact]
    public void La_clase_principal_es_la_del_personaje_con_mas_played()
    {
        var stats = Stats.Build(Data, Now);
        Assert.Equal("PRIEST", stats["Ana"].MainClass);
        Assert.Equal(["Ab-Reino", "Aa-Reino"], stats["Ana"].Chars.Select(c => c.CharKey));
        Assert.Null(stats["Cris"].MainClass);
    }

    [Fact]
    public void Build_ignora_jugadores_desconocidos() =>
        Assert.False(Stats.Build(Data, Now).ContainsKey("Fantasma"));

    [Theory]
    [InlineData(Mode.Deaths, "Bea,Ana,Cris")]
    [InlineData(Mode.Week, "Bea,Ana,Cris")]
    [InlineData(Mode.Today, "Ana,Bea,Cris")]
    public void Ranking_ordena_y_desempata_por_apodo(Mode mode, string expected)
    {
        var nicks = Stats.Ranking(Stats.Build(Data, Now).Values, mode).Select(s => s.Nick);
        Assert.Equal(expected, string.Join(",", nicks));
    }

    [Fact]
    public void Las_fechas_cruzan_meses_y_acaban_en_hoy()
    {
        Assert.Equal("2026-11-06", Stats.DayKey(0, Now));
        Assert.Equal("2026-10-31", Stats.DayKey(6, Now));
        var days = Stats.LastDays(30, Now);
        Assert.Equal(30, days.Length);
        Assert.Equal("2026-10-08", days[0]);
        Assert.Equal("2026-11-06", days[29]);
        Assert.Equal("06/11", Stats.ShortDate("2026-11-06"));
    }

    [Fact]
    public void Formatos()
    {
        Assert.Equal("0m", Stats.Fmt(0));
        Assert.Equal("59m", Stats.Fmt(59 * 60));
        Assert.Equal("1h 05m", Stats.Fmt(3600 + 5 * 60));
        Assert.Equal("1h 00m", Stats.FmtValue(Mode.Week, 3600));
        Assert.Equal("42", Stats.FmtValue(Mode.Deaths, 42));
    }

    [Theory]
    [InlineData(0, "ahora")]
    [InlineData(5, "hace 5 min")]
    [InlineData(120, "hace 2 h")]
    [InlineData(2880, "hace 2 d")]
    public void Ago(int minutes, string expected) =>
        Assert.Equal(expected, Stats.Ago(T.AddMinutes(-minutes), T));

    [Fact]
    public void HeatOpacity_satura_a_las_6_horas()
    {
        Assert.Equal(0f, Stats.HeatOpacity(0));
        Assert.Equal(1f, Stats.HeatOpacity(6 * 3600));
        Assert.Equal(1f, Stats.HeatOpacity(12 * 3600));
    }

    [Fact]
    public void Clases_desconocidas_o_vacias()
    {
        Assert.Equal("#3FC7EB", Stats.ClassColor("MAGE"));
        Assert.Equal("#C9CCD6", Stats.ClassColor(null));
        Assert.Equal("Mago", Stats.ClassName("MAGE"));
        Assert.Equal("NUEVA", Stats.ClassName("NUEVA"));
        Assert.Equal("?", Stats.ClassName(null));
    }

    [Fact]
    public void Lee_el_json_de_supabase()
    {
        var players = JsonSerializer.Deserialize(
            """[{"nick":"Ana","updated_at":"2026-11-06T10:00:00.123456+00:00"}]""",
            SupabaseJson.Default.ListPlayer)!;
        Assert.Equal("Ana", players[0].Nick);
        Assert.Equal(2026, players[0].UpdatedAt.Year);

        var chars = JsonSerializer.Deserialize(
            """[{"nick":"Ana","char_key":"Pj-Reino","class":null,"level":null,"played_seconds":123456,"deaths":42}]""",
            SupabaseJson.Default.ListCharacter)!;
        Assert.Equal("Pj-Reino", chars[0].CharKey);
        Assert.Null(chars[0].Class);
        Assert.Null(chars[0].Level);
        Assert.Equal(123456, chars[0].PlayedSeconds);
        Assert.Equal(42, chars[0].Deaths);

        var days = JsonSerializer.Deserialize(
            """[{"nick":"Ana","day":"2026-11-06","seconds":3600}]""",
            SupabaseJson.Default.ListPlayDay)!;
        Assert.Equal("2026-11-06", days[0].Day);
        Assert.Equal(3600, days[0].Seconds);
    }
}
