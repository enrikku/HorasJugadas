using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using HorasJugadas.Core;
using Microsoft.Maui.Controls.Shapes;

namespace HorasJugadas.ViewModels;

public sealed record RankRow(
    string Nick,
    int Position,
    string Value,
    Color Color,
    GridLength BarWidth,
    GridLength BarRest,
    Brush? MedalBrush,
    Color PositionColor)
{
    public bool HasMedal => MedalBrush is not null;
    public string Description => $"{Position}. {Nick}: {Value}";
}

public sealed record HeatRow(string Nick, Color Color, IReadOnlyDictionary<string, int> Days);

public partial class MainViewModel : ObservableObject
{
    private static readonly TimeSpan RefreshInterval = TimeSpan.FromMinutes(2); // como la web

    // Podio en monedas de oro, plata y cobre
    private static readonly Brush[] Medals =
    [
        Coin("#FFF1A8", "#E8B923", "#93700F"),
        Coin("#FFFFFF", "#BFC4CC", "#6F747C"),
        Coin("#F6C49A", "#C47A3F", "#6F3F18"),
    ];

    private readonly SupabaseClient _api;
    private IDispatcherTimer? _timer;
    private Dictionary<string, PlayerStats> _stats = [];
    private int _lastRequest;

    public MainViewModel(SupabaseClient api) => _api = api;

    /// <summary>Se dispara cada vez que llegan datos nuevos.</summary>
    public event Action? DataChanged;

    [ObservableProperty] public partial string Meta { get; set; } = "Cargando…";
    [ObservableProperty] public partial bool HasData { get; set; }
    [ObservableProperty] public partial bool IsLoading { get; set; } = true;
    [ObservableProperty] public partial bool IsRefreshing { get; set; }
    [ObservableProperty] public partial bool IsEmpty { get; set; }
    [ObservableProperty] public partial bool ShowOfflineBanner { get; set; }
    [ObservableProperty] public partial string? FatalError { get; set; }
    [ObservableProperty] public partial bool HasFatalError { get; set; }
    [ObservableProperty] public partial Mode SelectedMode { get; set; } = Mode.Week;
    [ObservableProperty] public partial IReadOnlyList<RankRow> Rows { get; set; } = [];
    [ObservableProperty] public partial IReadOnlyList<HeatRow> HeatRows { get; set; } = [];

    public PlayerStats? Find(string nick) => _stats.GetValueOrDefault(nick);

    /// <summary>Carga los datos y refresca periódicamente. Se llama al abrir o volver a la app.</summary>
    public void Start()
    {
        _ = LoadAsync();
        var dispatcher = Application.Current?.Dispatcher;
        if (dispatcher is null) return;
        _timer ??= CreateTimer(dispatcher);
        _timer.Stop();
        _timer.Start();
    }

    public void Stop() => _timer?.Stop();

    private IDispatcherTimer CreateTimer(IDispatcher dispatcher)
    {
        var timer = dispatcher.CreateTimer();
        timer.Interval = RefreshInterval;
        timer.Tick += (_, _) => _ = LoadAsync();
        return timer;
    }

    [RelayCommand]
    private async Task RefreshAsync()
    {
        await LoadAsync();
        IsRefreshing = false;
    }

    [RelayCommand]
    private async Task RetryAsync()
    {
        HasFatalError = false;
        IsLoading = true;
        await LoadAsync();
    }

    partial void OnSelectedModeChanged(Mode value) => RebuildRows();

    private async Task LoadAsync()
    {
        var id = ++_lastRequest;
        try
        {
            var data = await _api.FetchAsync(DateTime.Now);
            if (id != _lastRequest) return; // ya hay una petición más nueva
            Apply(data);
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException or System.Text.Json.JsonException)
        {
            if (id != _lastRequest) return;
            if (HasData)
            {
                ShowOfflineBanner = true;
            }
            else
            {
                FatalError = $"No se pudieron cargar los datos: {e.Message}";
                HasFatalError = true;
                Meta = "";
            }
        }
        finally
        {
            if (id == _lastRequest) IsLoading = false;
        }
    }

    private void Apply(Dataset data)
    {
        _stats = Stats.Build(data, DateTime.Now);
        var latest = data.Players.Count > 0 ? Stats.Ago(data.Players.Max(p => p.UpdatedAt), DateTimeOffset.Now) : "—";
        Meta = $"{data.Players.Count} jugadores · última subida {latest}";
        HasData = true;
        HasFatalError = false;
        ShowOfflineBanner = false;
        IsEmpty = data.Players.Count == 0;
        RebuildRows();
        HeatRows = _stats.Values
            .OrderByDescending(s => s.Month)
            .ThenBy(s => s.Nick, StringComparer.Ordinal)
            .Select(s => new HeatRow(s.Nick, Color.FromArgb(Stats.ClassColor(s.MainClass)), s.Days))
            .ToList();
        DataChanged?.Invoke();
    }

    private void RebuildRows()
    {
        var list = Stats.Ranking(_stats.Values, SelectedMode);
        var max = Math.Max(1, list.Count > 0 ? list.Max(s => s.Value(SelectedMode)) : 0);
        var muted = (Color)Application.Current!.Resources["Muted"];
        Rows = list.Select((s, i) =>
        {
            var share = (double)s.Value(SelectedMode) / max;
            var medal = i < Medals.Length ? Medals[i] : null;
            return new RankRow(
                s.Nick, i + 1, Stats.FmtValue(SelectedMode, s.Value(SelectedMode)),
                Color.FromArgb(Stats.ClassColor(s.MainClass)),
                new GridLength(share, GridUnitType.Star), new GridLength(1 - share, GridUnitType.Star),
                medal, medal is null ? muted : Color.FromArgb("#1C1405"));
        }).ToList();
    }

    private static RadialGradientBrush Coin(string light, string mid, string dark) => new()
    {
        Center = new Point(0.35, 0.3),
        Radius = 0.75,
        GradientStops =
        {
            new GradientStop(Color.FromArgb(light), 0f),
            new GradientStop(Color.FromArgb(mid), 0.55f),
            new GradientStop(Color.FromArgb(dark), 1f),
        },
    };
}
