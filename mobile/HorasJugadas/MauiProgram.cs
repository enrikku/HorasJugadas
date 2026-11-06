using HorasJugadas.Core;
using HorasJugadas.Pages;
using HorasJugadas.ViewModels;
using Microsoft.Maui.Handlers;

namespace HorasJugadas;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("Cinzel_600SemiBold.ttf", "CinzelSemi");
                fonts.AddFont("Cinzel_700Bold.ttf", "CinzelBold");
                fonts.AddFont("AlegreyaSans_400Regular.ttf", "AlegreyaRegular");
                fonts.AddFont("AlegreyaSans_500Medium.ttf", "AlegreyaMedium");
                fonts.AddFont("AlegreyaSans_700Bold.ttf", "AlegreyaBold");
            });

        UseLiningNumbers();

        builder.Services.AddSingleton(new SupabaseClient(new HttpClient()));
        builder.Services.AddSingleton<MainViewModel>();
        builder.Services.AddTransient<MainPage>();

        return builder.Build();
    }

    // Alegreya Sans usa cifras elzevirianas por defecto; la web activa las alineadas
    // (font-variant: lining-nums), pero MAUI no tiene una propiedad para ello.
    // En Core Text, "UpperCaseNumbers" es el selector de las cifras alineadas.
    private static void UseLiningNumbers()
    {
#if ANDROID
        LabelHandler.Mapper.AppendToMapping("Font", (h, _) => h.PlatformView.FontFeatureSettings = "lnum");
        ButtonHandler.Mapper.AppendToMapping("Font", (h, _) => h.PlatformView.FontFeatureSettings = "lnum");
#elif IOS
        static UIKit.UIFont Lining(UIKit.UIFont font)
        {
            var feature = new UIKit.UIFontFeature(CoreText.CTFontFeatureNumberCase.Selector.UpperCaseNumbers);
            var attributes = new UIKit.UIFontAttributes(feature);
            return UIKit.UIFont.FromDescriptor(font.FontDescriptor.CreateWithAttributes(attributes), 0) ?? font;
        }
        LabelHandler.Mapper.AppendToMapping("Font", (h, _) => h.PlatformView.Font = Lining(h.PlatformView.Font));
        ButtonHandler.Mapper.AppendToMapping("Font", (h, _) =>
        {
            if (h.PlatformView.TitleLabel is { } label) label.Font = Lining(label.Font);
        });
#endif
    }
}
