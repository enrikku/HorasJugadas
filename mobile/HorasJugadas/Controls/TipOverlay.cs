namespace HorasJugadas.Controls;

/// <summary>Tooltip del juego: aparece al tocar y se oculta solo o al hacer scroll.</summary>
public sealed class TipOverlay : Border
{
    private const double TipWidth = 190, TipHeight = 62, Gap = 14;
    private static readonly TimeSpan Visible = TimeSpan.FromSeconds(2.5);

    private readonly Label _title = new() { FontFamily = "AlegreyaBold", FontSize = 15, TextColor = Colors.White, LineBreakMode = LineBreakMode.TailTruncation };
    private readonly Label _text = new() { FontSize = 14, TextColor = Color.FromArgb("#FFD100"), LineBreakMode = LineBreakMode.TailTruncation };
    private IDispatcherTimer? _timer;

    public TipOverlay()
    {
        HorizontalOptions = LayoutOptions.Start;
        VerticalOptions = LayoutOptions.Start;
        WidthRequest = TipWidth;
        HeightRequest = TipHeight;
        Padding = new Thickness(10, 6);
        BackgroundColor = Color.FromRgba(6, 9, 28, 240);
        Stroke = Color.FromArgb("#8D93A8");
        StrokeThickness = 2;
        StrokeShape = new Microsoft.Maui.Controls.Shapes.RoundRectangle { CornerRadius = 5 };
        InputTransparent = true;
        IsVisible = false;
        ZIndex = 10;
        Content = new VerticalStackLayout { Children = { _title, _text } };
    }

    /// <param name="at">Punto tocado, relativo al contenedor del tooltip.</param>
    public void Show(string title, string text, Point at, double containerWidth)
    {
        _title.Text = title;
        _text.Text = text;
        TranslationX = Math.Max(4, Math.Min(at.X - TipWidth / 2, containerWidth - TipWidth - 4));
        var above = at.Y - TipHeight - Gap;
        TranslationY = above < 4 ? at.Y + Gap : above;
        IsVisible = true;

        _timer ??= CreateTimer();
        _timer.Stop();
        _timer.Start();
    }

    public void Hide() => IsVisible = false;

    private IDispatcherTimer CreateTimer()
    {
        var timer = Dispatcher.CreateTimer();
        timer.Interval = Visible;
        timer.IsRepeating = false;
        timer.Tick += (_, _) => Hide();
        return timer;
    }
}
