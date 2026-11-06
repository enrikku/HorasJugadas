using System.Net.Http.Json;
using System.Text.Json.Serialization.Metadata;

namespace HorasJugadas.Core;

public sealed class SupabaseClient
{
    // Mismos datos públicos que web/config.js (Supabase > Project Settings > API).
    // La clave "publishable" es pública por diseño: solo permite leer.
    public const string Url = "https://sehlxqhxfnnjiskoemnv.supabase.co";
    public const string Key = "sb_publishable_yPbQdZnvKj9kAASrUnNqsA_4fTCAKBD";

    private readonly HttpClient _http;

    public SupabaseClient(HttpClient http)
    {
        _http = http;
        _http.BaseAddress = new Uri($"{Url}/rest/v1/");
        _http.Timeout = TimeSpan.FromSeconds(15);
        _http.DefaultRequestHeaders.Add("apikey", Key);
    }

    public async Task<Dataset> FetchAsync(DateTime now)
    {
        var since = Stats.DayKey(Stats.DayCount - 1, now);
        var players = Get("players?select=nick,updated_at", SupabaseJson.Default.ListPlayer);
        var days = Get($"play_days?select=nick,day,seconds&day=gte.{since}", SupabaseJson.Default.ListPlayDay);
        var chars = Get("characters?select=nick,char_key,class,level,played_seconds,deaths", SupabaseJson.Default.ListCharacter);
        await Task.WhenAll(players, days, chars);
        return new Dataset(players.Result, days.Result, chars.Result);
    }

    private async Task<List<T>> Get<T>(string path, JsonTypeInfo<List<T>> type)
    {
        using var res = await _http.GetAsync(path);
        if (!res.IsSuccessStatusCode)
            throw new HttpRequestException($"{(int)res.StatusCode} {await res.Content.ReadAsStringAsync()}");
        return await res.Content.ReadFromJsonAsync(type) ?? [];
    }
}
