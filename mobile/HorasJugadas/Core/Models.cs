using System.Text.Json.Serialization;

namespace HorasJugadas.Core;

public sealed record Player(string Nick, DateTimeOffset UpdatedAt);

public sealed record PlayDay(string Nick, string Day, int Seconds);

public sealed record Character(
    string Nick,
    string CharKey,
    string? Class,
    int? Level,
    long PlayedSeconds,
    long Deaths);

public sealed record Dataset(
    IReadOnlyList<Player> Players,
    IReadOnlyList<PlayDay> Days,
    IReadOnlyList<Character> Chars);

public enum Mode { Today, Week, Month, Total, Deaths }

public sealed class PlayerStats
{
    public required string Nick { get; init; }
    public required DateTimeOffset Updated { get; init; }
    public long Today { get; set; }
    public long Week { get; set; }
    public long Month { get; set; }
    public long Total { get; set; }
    public long Deaths { get; set; }
    public Dictionary<string, int> Days { get; } = [];
    public List<Character> Chars { get; } = [];
    public string? MainClass { get; set; }

    public long Value(Mode mode) => mode switch
    {
        Mode.Today => Today,
        Mode.Week => Week,
        Mode.Month => Month,
        Mode.Total => Total,
        Mode.Deaths => Deaths,
        _ => throw new ArgumentOutOfRangeException(nameof(mode)),
    };
}

// Generado en compilación: la reflexión de JSON no es fiable con el recorte de código de iOS y Android.
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.SnakeCaseLower)]
[JsonSerializable(typeof(List<Player>))]
[JsonSerializable(typeof(List<PlayDay>))]
[JsonSerializable(typeof(List<Character>))]
public sealed partial class SupabaseJson : JsonSerializerContext;
