using System.ComponentModel;
using HorasJugadas.Controls;
using HorasJugadas.Core;
using HorasJugadas.ViewModels;

namespace HorasJugadas.Pages;

public partial class MainPage : ContentPage
{
    private static readonly LinearGradientBrush TabBrush = Vertical("#2A241B", "#14110C");
    private static readonly LinearGradientBrush ActiveTabBrush = Vertical("#4A3F2B", "#1D1810");

    private readonly MainViewModel _vm;
    private readonly HeatmapDrawable _heat = new();
    private readonly List<(Button Button, Mode Mode)> _tabs = [];
    private bool _scrolledHeat;

    public MainPage(MainViewModel vm)
    {
        InitializeComponent();
        BindingContext = _vm = vm;
        HeatView.Drawable = _heat;

        var buttons = Tabs.Children.OfType<Button>().ToList();
        for (var i = 0; i < buttons.Count; i++)
        {
            var (mode, label) = Stats.Modes[i];
            buttons[i].Text = label;
            buttons[i].FontSize = 15;
            buttons[i].Padding = new Thickness(4, 0);
            buttons[i].CornerRadius = 4;
            buttons[i].BorderWidth = 2;
            _tabs.Add((buttons[i], mode));
        }
        UpdateTabs();
        UpdateHeat();
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();
        _vm.PropertyChanged += OnViewModelChanged;
        // Si al volver de la ficha la actividad quedó al principio, se recoloca en los días recientes.
        _scrolledHeat = HeatScroll.ScrollX > 0;
        UpdateTabs();
        UpdateHeat();
    }

    protected override void OnDisappearing()
    {
        base.OnDisappearing();
        _vm.PropertyChanged -= OnViewModelChanged;
    }

    private void OnViewModelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(MainViewModel.SelectedMode)) UpdateTabs();
        else if (e.PropertyName == nameof(MainViewModel.HeatRows)) UpdateHeat();
    }

    private void UpdateTabs()
    {
        var gold = (Color)Application.Current!.Resources["Gold"];
        var goldDim = (Color)Application.Current.Resources["GoldDim"];
        var stoneLo = (Color)Application.Current.Resources["StoneLo"];
        foreach (var (button, mode) in _tabs)
        {
            var active = mode == _vm.SelectedMode;
            button.Background = active ? ActiveTabBrush : TabBrush;
            button.BorderColor = active ? goldDim : stoneLo;
            button.TextColor = active ? gold : goldDim;
            button.FontFamily = active ? "AlegreyaBold" : "AlegreyaMedium";
        }
    }

    private void UpdateHeat()
    {
        _heat.Rows = _vm.HeatRows;
        _heat.Days = Stats.LastDays(Stats.DayCount, DateTime.Now);
        HeatView.WidthRequest = _heat.ContentWidth;
        HeatView.HeightRequest = _heat.ContentHeight;
        HeatView.Invalidate();

        // La primera vez arranca mostrando los días más recientes.
        ScrollHeatToEnd();
    }

    private void ScrollHeatToEnd()
    {
        if (_scrolledHeat || _vm.HeatRows.Count == 0 || HeatScroll.Width <= 0) return;
        _scrolledHeat = true;
        var x = Math.Max(0, _heat.ContentWidth - HeatScroll.Width);
        Dispatcher.DispatchDelayed(TimeSpan.FromMilliseconds(100), () => _ = HeatScroll.ScrollToAsync(x, 0, false));
    }

    private void OnHeatScrollSizeChanged(object? sender, EventArgs e) => ScrollHeatToEnd();

    private void OnTabClicked(object? sender, EventArgs e)
    {
        Tip.Hide();
        _vm.SelectedMode = _tabs.First(t => t.Button == sender).Mode;
    }

    private async void OnRowTapped(object? sender, TappedEventArgs e)
    {
        // Evita abrir dos fichas con un doble toque.
        if (Navigation.NavigationStack.Count > 1) return;
        if (sender is BindableObject { BindingContext: RankRow row })
            await Navigation.PushAsync(new PlayerPage(_vm, row.Nick));
    }

    private void OnHeatTapped(object? sender, TappedEventArgs e)
    {
        if (e.GetPosition(HeatView) is not { } p || e.GetPosition(Root) is not { } at) return;
        if (_heat.HitTest(p) is not { } hit) return;
        var seconds = hit.Row.Days.GetValueOrDefault(hit.Day);
        Tip.Show(hit.Row.Nick, $"{Stats.ShortDate(hit.Day)} · {Stats.Fmt(seconds)}", at, Root.Width);
    }

    private void OnScrolled(object? sender, ScrolledEventArgs e) => Tip.Hide();

    private static LinearGradientBrush Vertical(string top, string bottom) => new()
    {
        StartPoint = new Point(0, 0),
        EndPoint = new Point(0, 1),
        GradientStops =
        {
            new GradientStop(Color.FromArgb(top), 0f),
            new GradientStop(Color.FromArgb(bottom), 1f),
        },
    };
}
