# Horas Jugadas para móvil

App para iOS y Android con las mismas funciones que la [web](../web/index.html): ranking, actividad de los últimos 30 días y ficha de cada jugador. Está hecha con .NET MAUI (.NET 10) y lee los datos de Supabase con la misma clave pública que la web.

## Requisitos

- SDK de .NET 10 con las cargas de trabajo: `dotnet workload install maui`
- Android: el SDK de Android y un JDK (vienen con Visual Studio).
- iOS: un Mac con Xcode para generar y firmar la app. Desde Windows, el código compila, pero para instalarla hace falta emparejar un Mac. Publicar requiere una cuenta de Apple Developer (99 $/año).

## Ejecutar

Abre `HorasJugadas.slnx` en Visual Studio, o desde la carpeta `HorasJugadas/`:

```bash
dotnet build -t:Run -f net10.0-android                # en el móvil conectado por USB
dotnet build -t:Run -f net10.0-windows10.0.19041.0    # vista rápida en el PC
```

## Generar la app instalable

```bash
# Android: genera un .apk para instalar directamente y un .aab para Google Play
dotnet publish -f net10.0-android -c Release

# iOS: desde un Mac
dotnet publish -f net10.0-ios -c Release
```

El APK aparece en `HorasJugadas/bin/Release/net10.0-android/publish/`. Para actualizar la app en los móviles o publicarla en Google Play hay que firmarla siempre con la misma clave ([instrucciones](https://learn.microsoft.com/dotnet/maui/android/deployment/publish-cli)).

## Tests

```bash
dotnet test HorasJugadas.Tests
```

Prueban la lógica de `Core/`, que no depende de MAUI.

## Estructura

| Carpeta | Contenido |
|---|---|
| `HorasJugadas/Core/` | Modelos, cálculo de rankings y formatos (portados de la web) y cliente de Supabase |
| `HorasJugadas/ViewModels/` | Estado de las pantallas y refresco cada 2 minutos en primer plano |
| `HorasJugadas/Pages/` | Pantalla principal y ficha de jugador |
| `HorasJugadas/Controls/` | Marco de piedra, tooltip, actividad y gráfica |
| `HorasJugadas.Tests/` | Tests de la lógica |

Si cambia la lógica de la web, hay que cambiar también `Core/Stats.cs`.
