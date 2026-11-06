using HorasJugadas.Pages;
using HorasJugadas.ViewModels;

namespace HorasJugadas;

public partial class App : Application
{
    private readonly IServiceProvider _services;
    private readonly MainViewModel _vm;

    public App(IServiceProvider services, MainViewModel vm)
    {
        InitializeComponent();
        UserAppTheme = AppTheme.Dark;
        _services = services;
        _vm = vm;
    }

    protected override Window CreateWindow(IActivationState? activationState)
    {
        // Android puede pedir una ventana nueva si recrea la actividad: la página no se reutiliza.
        var nav = new NavigationPage(_services.GetRequiredService<MainPage>());
        var window = new Window(nav) { Title = "Horas Jugadas" };
        window.Resumed += (_, _) => _vm.Start();
        window.Stopped += (_, _) => _vm.Stop();
        _vm.Start();
        return window;
    }
}
