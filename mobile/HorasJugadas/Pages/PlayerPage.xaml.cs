using HorasJugadas.Controls;
using HorasJugadas.Core;
using HorasJugadas.ViewModels;

namespace HorasJugadas.Pages;

public partial class PlayerPage : ContentPage
{
    private readonly MainViewModel _main;
    private readonly string _nick;
    private readonly ChartDrawable _chart = new();

    public PlayerPage(MainViewModel main, string nick)
    {
        InitializeComponent();
        _main = main;
        _nick = nick;
        ChartView.Drawable = _chart;
        ChartView.HeightRequest = ChartDrawable.TotalHeight;
        Refresh();
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();
        _main.DataChanged += Refresh;
    }

    protected override void OnDisappearing()
    {
        base.OnDisappearing();
        _main.DataChanged -= Refresh;
    }

    private void Refresh()
    {
        if (_main.Find(_nick) is not { } stats) return;
        var vm = new PlayerViewModel(stats, DateTimeOffset.Now);
        BindingContext = vm;
        _chart.Days = Stats.LastDays(Stats.DayCount, DateTime.Now);
        _chart.Today = _chart.Days[^1];
        _chart.Seconds = stats.Days;
        _chart.Color = vm.Color;
        ChartView.Invalidate();
    }

    private async void OnCloseClicked(object? sender, EventArgs e) => await Navigation.PopAsync();

    private void OnChartTapped(object? sender, TappedEventArgs e)
    {
        if (e.GetPosition(ChartView) is not { } p || e.GetPosition(Root) is not { } at) return;
        if (_chart.HitTest(p, ChartView.Width) is not { } day) return;
        Tip.Show(Stats.ShortDate(day), Stats.Fmt(_chart.Seconds.GetValueOrDefault(day)), at, Root.Width);
    }

    private void OnScrolled(object? sender, ScrolledEventArgs e) => Tip.Hide();
}
