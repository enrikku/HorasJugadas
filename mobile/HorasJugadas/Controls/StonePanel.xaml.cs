namespace HorasJugadas.Controls;

/// <summary>Ventana con marco de piedra, remaches en las esquinas y placa de título.</summary>
public partial class StonePanel : ContentView
{
    public static readonly BindableProperty TitleProperty =
        BindableProperty.Create(nameof(Title), typeof(string), typeof(StonePanel), "");

    public StonePanel() => InitializeComponent();

    public string Title
    {
        get => (string)GetValue(TitleProperty);
        set => SetValue(TitleProperty, value);
    }
}
