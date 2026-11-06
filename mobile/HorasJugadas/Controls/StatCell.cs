namespace HorasJugadas.Controls;

/// <summary>Casilla hundida con una etiqueta dorada y un valor.</summary>
public sealed class StatCell : Border
{
    public static readonly BindableProperty LabelProperty = BindableProperty.Create(
        nameof(Label), typeof(string), typeof(StatCell), "",
        propertyChanged: (b, _, v) => ((StatCell)b)._label.Text = (string)v);

    public static readonly BindableProperty ValueProperty = BindableProperty.Create(
        nameof(Value), typeof(string), typeof(StatCell), "",
        propertyChanged: (b, _, v) => ((StatCell)b)._value.Text = (string)v);

    private readonly Microsoft.Maui.Controls.Label _label = new() { TextColor = Color.FromArgb("#FFD100") };
    private readonly Microsoft.Maui.Controls.Label _value = new() { FontFamily = "AlegreyaBold", FontSize = 21 };

    public StatCell()
    {
        Style = (Style)Application.Current!.Resources["Sunken"];
        Padding = new Thickness(12, 8);
        Content = new VerticalStackLayout { Children = { _label, _value } };
    }

    public string Label
    {
        get => (string)GetValue(LabelProperty);
        set => SetValue(LabelProperty, value);
    }

    public string Value
    {
        get => (string)GetValue(ValueProperty);
        set => SetValue(ValueProperty, value);
    }
}
