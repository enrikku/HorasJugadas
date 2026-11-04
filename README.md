# ⏱️ Horas Jugadas

Sistema para que un grupo de amigos sepa **cuántas horas juega y cuántas veces ha muerto cada uno en World of Warcraft** y lo vea en una web con rankings y gráficas.

🌐 **Web:** <https://horas-jugadas.vercel.app>

Tiene tres piezas que trabajan juntas:

| Pieza | Qué es | Dónde se ejecuta |
|---|---|---|
| **Addon** | Registra tu tiempo de juego y tus muertes dentro de WoW | En el juego, en el PC de cada amigo |
| **Uploader** | Programa que sube tus horas y muertes a internet | En el PC de cada amigo, en segundo plano |
| **Web** | Página con el ranking y las gráficas de todos | En internet (Vercel) + base de datos (Supabase) |

---

## Índice

1. [Cómo funciona](#1-cómo-funciona)
2. [Instalación para jugadores](#2-instalación-para-jugadores)
3. [Uso diario](#3-uso-diario)
4. [Instalación para el administrador](#4-instalación-para-el-administrador)
5. [Detalles técnicos](#5-detalles-técnicos)
6. [Seguridad y privacidad](#6-seguridad-y-privacidad)
7. [Solución de problemas](#7-solución-de-problemas)
8. [Desarrollo](#8-desarrollo)
9. [Limitaciones conocidas](#9-limitaciones-conocidas)

---

## 1. Cómo funciona

### El problema

Un addon de WoW **no puede conectarse a internet**. Blizzard no permite que los addons hagan peticiones web, abran conexiones ni escriban archivos donde quieran. Lo único que puede hacer un addon es guardar sus datos en un archivo de WoW llamado *SavedVariables*.

### La solución

Un programa externo lee ese archivo y lo sube a internet. Así funcionan también el cliente de Raider.IO y el uploader de Warcraft Logs.

```
 PC de cada amigo                                          Internet
┌───────────────────────────────────────────┐
│  World of Warcraft + addon HorasJugadas   │
│    • suma tiempo y registra cada muerte   │
│    • guarda el /played de cada personaje  │
│               │                           │
│               │ al salir del juego,       │
│               │ cambiar de pj o /reload   │
│               ▼                           │
│  WTF\Account\<CUENTA>\SavedVariables\     │
│        HorasJugadas.lua                   │
│               │                           │
│               │ lo lee cuando cambia      │
│               ▼                           │         ┌────────────┐        ┌───────────┐
│  HorasJugadasUploader.exe  ───────────────┼────────►│  Supabase  │◄───────│  Web      │
│    (oculto, arranca con Windows)          │  HTTPS  │ (base de   │  lee   │ (Vercel)  │
└───────────────────────────────────────────┘         │   datos)   │        └───────────┘
                                                      └────────────┘              ▲
                                                                                  │
                                                                     tus amigos la abren
                                                                     desde el navegador
```

### Paso a paso

1. **Juegas.** El addon suma 60 segundos al día de hoy cada minuto y registra las muertes del personaje. Al entrar, también pide al juego el `/played` real y su estadística histórica de muertes.
2. **Sales del juego.** También vale cambiar de personaje o escribir `/reload`. En ese momento WoW escribe los datos del addon en el archivo `HorasJugadas.lua`.
3. **El uploader detecta el cambio.** Revisa el archivo cada 30 segundos. Si ha cambiado, lo lee y sube **tus** datos a Supabase.
4. **La web se actualiza.** Lee los datos de Supabase cuando la abres y cada 2 minutos mientras la tienes abierta.

> ⚠️ **Importante:** WoW **solo escribe el archivo al salir del juego, cambiar de personaje o hacer `/reload`**. Por eso la web no se actualiza minuto a minuto: tus horas aparecen cuando terminas la sesión. Si quieres que se suban antes, escribe `/reload` en el juego.

### Persona, no personaje

Las horas se agrupan por **persona**: todos tus personajes, de cualquier reino, cuentan bajo un mismo **apodo**. Por defecto el apodo es tu BattleTag sin el `#1234`. Lo puedes cambiar con `/hj nombre TuApodo`.

---

## 2. Instalación para jugadores

Necesitas el zip que te pase el administrador. Contiene la carpeta del addon, el programa `HorasJugadasUploader.exe` y su `config.json`.

### Paso 1: Instalar el addon

1. Busca la carpeta de WoW. En Battle.net, pulsa la rueda dentada junto a **Jugar** y luego **Mostrar en el explorador**.
2. Entra en `_retail_\Interface\AddOns\`. Si no existe la carpeta `AddOns`, créala.
3. Copia dentro la carpeta `HorasJugadas`. Debe quedar así:
   ```
   World of Warcraft\_retail_\Interface\AddOns\HorasJugadas\HorasJugadas.toc
   ```
4. Abre WoW. En la pantalla de personajes, pulsa **AddOns** y comprueba que **Horas Jugadas** está activado.

### Paso 2: Instalar el uploader

1. Copia la carpeta del uploader (`HorasJugadasUploader.exe` + `config.json`) en un sitio fijo, por ejemplo `Documentos\HorasJugadas\`.
   **Mantén los dos archivos juntos** y no la muevas después de instalar el paso 3.
2. Haz doble clic en `HorasJugadasUploader.exe`. Se abrirá una ventana negra.
   - Si Windows muestra **"Windows protegió su PC"**, pulsa **Más información → Ejecutar de todas formas**. Sale porque el programa no está firmado digitalmente.
   - Si sale `vigilando cambios cada 30s`, funciona. Cierra la ventana.
   - Si sale `No encuentro World of Warcraft`, mira [Solución de problemas](#7-solución-de-problemas).
3. Para que arranque solo y oculto cada vez que enciendes el PC, abre una terminal en esa carpeta y ejecuta:
   ```
   HorasJugadasUploader.exe --instalar-inicio
   ```
   Para hacerlo al momento sin reiniciar, ejecuta `HorasJugadasUploader.exe` una vez más.

### Paso 3: Ponerte tu apodo

En el juego escribe:

```
/hj nombre TuApodo
```

Usa un nombre que tus amigos reconozcan. Ese nombre es el que aparecerá en la web.

> ⚠️ Elige el apodo **antes de la primera subida**. La primera vez que se sube un apodo, queda reservado para tu PC. Si luego lo cambias, aparecerás como un jugador nuevo y el antiguo se quedará en la web hasta que el administrador lo borre.

¡Listo! Juega con normalidad. Cuando salgas del juego tus horas aparecerán en la web.

---

## 3. Uso diario

### En el juego

Escribe `/hj`, o pulsa el **reloj del minimapa**, para abrir la ventana:

- **Ranking** de hoy, 7 días, 30 días, `/played` total y muertes totales.
- Al hacer **clic en un jugador**: un gráfico de sus últimos 14 días y sus personajes.
- **Sincronizar:** intercambia datos con amigos conectados en ese momento.
- **Exportar:** muestra todos los datos en CSV para copiarlos a Excel o Google Sheets.

Dentro del juego, el addon intercambia datos con tus amigos de **Battle.net** que estén en WoW, aunque estén en otro reino o facción, con tu **hermandad** y con tu **grupo o banda**. Lo hace al entrar, al unirte a un grupo y cada 10 minutos. Esto permite ver a tus amigos con `/hj` sin salir del juego. La web es independiente y siempre muestra a todos.

| Comando | Qué hace |
|---|---|
| `/hj` o `/horas` | Abre o cierra la ventana |
| `/hj nombre` | Muestra tu apodo actual |
| `/hj nombre <apodo>` | Cambia tu apodo |
| `/hj sync` | Envía tus datos y pide los de los demás |
| `/hj sync <Personaje-Reino>` | Sincroniza con un personaje concreto por susurro |
| `/hj export` | Exporta todo a CSV |
| `/hj borrar <apodo>` | Borra los datos de otro jugador **solo en tu juego** |
| `/hj minimapa` | Muestra u oculta el botón del minimapa |
| `/hj ayuda` | Lista de comandos |

### En la web

- **Ranking:** cambia entre *Hoy*, *7 días*, *30 días*, *Total /played* y *Muertes*.
- **Actividad de los últimos 30 días:** cuanto más intenso el color, más horas jugó ese día. El color es el de la clase de su personaje principal. Pasa el ratón por encima para ver las horas exactas.
- **Detalle:** al pulsar un jugador ves sus totales, un gráfico diario de 30 días y todos sus personajes con clase, nivel, `/played` y muertes.

### El uploader

| Opción | Qué hace |
|---|---|
| *(sin opciones)* | Vigila el archivo y sube cuando cambia |
| `--once` | Sube una vez y se cierra |
| `--dry-run` | Muestra lo que subiría, **sin subir nada** |
| `--force` | Sube aunque no haya cambios |
| `--instalar-inicio` | Arranca oculto al encender Windows |
| `--quitar-inicio` | Deja de arrancar con Windows |
| `--ayuda` | Ayuda y rutas de sus archivos |

El uploader guarda sus archivos en `%APPDATA%\HorasJugadas\`:
- `estado.json`: tu **token personal** y la última subida. **No lo compartas ni lo borres.**
- `uploader.log`: registro de lo que ha hecho. Míralo si algo falla.

---

## 4. Instalación para el administrador

Solo hace falta hacerlo una vez para todo el grupo.

### Requisitos

- [Node.js](https://nodejs.org) 20 o superior, solo para generar el `.exe`. Tus amigos no lo necesitan.
- Una cuenta gratuita en [Supabase](https://supabase.com) y otra en [Vercel](https://vercel.com).

### 4.1 Base de datos (Supabase)

1. Crea un proyecto en Supabase.
2. Ve a **SQL Editor → New query**, pega **todo** el contenido de [`supabase/schema.sql`](supabase/schema.sql) y pulsa **Run**.
3. Comprueba en **Table Editor** que existen `players`, `play_days`, `characters` y `player_tokens`.
4. En **Project Settings** copia:
   - **Project URL**, por ejemplo `https://abcdefgh.supabase.co`;
   - **API Keys → Publishable key** (`sb_publishable_...`). Si tu proyecto es antiguo, usa la clave **anon / public**.

   > ⛔ **Nunca** uses la clave `secret` / `service_role`. Da control total sobre la base de datos.

**Datos de demo (opcional):** para ver cómo queda la web antes de que nadie juegue, ejecuta [`supabase/demo.sql`](supabase/demo.sql) en el SQL Editor. Crea 6 jugadores ficticios, todos con apodos que terminan en ` (demo)`, con unos 45 días de actividad y varios personajes. Las fechas son relativas al día de hoy. Para quitarlos, ejecuta [`supabase/demo-borrar.sql`](supabase/demo-borrar.sql). Solo borra los apodos ` (demo)`; los jugadores reales no se tocan.

### 4.2 Configurar

Pon la URL y la clave en dos archivos:

**`uploader/config.json`** (cópialo de `config.example.json`; este archivo no se sube a git):

```json
{
  "supabaseUrl": "https://abcdefgh.supabase.co",
  "supabaseKey": "sb_publishable_xxxxxxxx",
  "wowPath": ""
}
```

**`web/config.js`:**

```js
window.HJ_CONFIG = {
  supabaseUrl: "https://abcdefgh.supabase.co",
  supabaseKey: "sb_publishable_xxxxxxxx",
};
```

### 4.3 Generar el programa

```powershell
cd uploader
node test.js            # comprueba que el lector del archivo funciona
node build-exe.js       # genera dist\HorasJugadasUploader.exe con tu config.json
```

### 4.4 Publicar la web (Vercel)

1. En Vercel: **Add New → Project**, importa el repositorio de GitHub.
2. En **Root Directory** elige **`web`**. Es importante: si se deja la raíz, la web da 404.
3. **Deploy.**

A partir de ahí, **cada `git push` a `main` publica la web automáticamente**.

Para publicar a mano desde la raíz del repositorio: `npx vercel --prod`.

> Este repositorio ya está conectado al proyecto `horas-jugadas` de Vercel, con Root Directory `web`, y se publica solo con cada push.

### 4.5 Repartir a los amigos

Prepara un zip con:

```
HorasJugadas.zip
├── HorasJugadas\            ← copia de addon\HorasJugadas
└── Uploader\
    ├── HorasJugadasUploader.exe
    └── config.json
```

Envíaselo junto con la dirección de la web y el enlace a la [sección 2](#2-instalación-para-jugadores) de este README.

### 4.6 Tareas de mantenimiento

Todas se hacen en el **SQL Editor** de Supabase.

```sql
-- Ver quién ha subido datos y cuándo
select nick, updated_at from players order by updated_at desc;

-- Liberar un apodo (alguien perdió su token al reinstalar Windows)
delete from player_tokens where nick = 'Apodo';

-- Borrar por completo a un jugador (sus días y personajes se borran solos)
delete from players where nick = 'Apodo';
```

> **Cambiar el apodo de alguien:** el jugador escribe `/hj nombre NuevoApodo` en el juego y sale para que se suba. Después, el administrador borra el apodo viejo con el último comando de arriba. Sus días se conservan, porque el addon los guarda en local y los vuelve a subir con el nuevo nombre.

---

## 5. Detalles técnicos

### Estructura del repositorio

```
HorasJugadas/
├── addon/HorasJugadas/
│   ├── HorasJugadas.toc        metadatos del addon (versión de WoW, archivos, SavedVariables)
│   ├── Core.lua                base de datos, registro del tiempo, estadísticas, comandos
│   ├── Sync.lua                intercambio de datos dentro del juego
│   └── UI.lua                  ventana, gráfico, exportación CSV, botón del minimapa
├── uploader/
│   ├── horasjugadas-uploader.js  el programa (Node.js, sin dependencias)
│   ├── build-exe.js            genera el .exe
│   ├── test.js                 pruebas del lector de SavedVariables
│   ├── config.example.json     plantilla de configuración
│   └── package.json
├── supabase/
│   └── schema.sql              tablas, permisos (RLS) y función de subida
└── web/
    ├── index.html              la web (HTML + CSS + JS, sin dependencias)
    └── config.js               URL y clave pública de Supabase
```

### Addon

**Registro del tiempo:**
- Cada 60 s suma el tiempo transcurrido a `days["AAAA-MM-DD"]` y al `played` del personaje actual.
- Al entrar llama a `RequestTimePlayed()`. Cuando llega `TIME_PLAYED_MSG`, sustituye la estimación por el `/played` real.
- Al salir (`PLAYER_LOGOUT`) suma los segundos que faltan.
- El historial diario se conserva durante 120 días.

**Registro de muertes:**
- Al entrar, lee la estadística histórica `Total deaths` que WoW conserva para el personaje.
- Mientras juegas, el evento `PLAYER_DEAD` incrementa el contador inmediatamente.
- El total de una persona es la suma de las muertes de todos sus personajes conocidos.

**Datos guardados** (`HorasJugadasDB`, uno por cuenta de WoW):

```lua
HorasJugadasDB = {
  nick = "Enric",                       -- tu apodo
  players = {
    ["Enric"] = {                       -- tus datos
      chars = {
        ["Thrall-Sanguino"] = { played = 1234567, deaths = 42, class = "SHAMAN", level = 80, last = 1793612345 },
      },
      days = { ["2026-11-02"] = 3600, ["2026-11-01"] = 5400 },
      updated = 1793612345,
    },
    ["Amigo"] = { ... },                -- datos recibidos dentro del juego
  },
  minimap = { angle = 220, hide = false },
}
```

**Sincronización dentro del juego:** usa el prefijo `HorasJug`, por `BNSendGameData` para amigos de Battle.net y por `C_ChatInfo.SendAddonMessage` para hermandad, grupo y susurros. Los mensajes se separan con `;` y se envían en cola, uno cada 0,3 s:

| Mensaje | Significado |
|---|---|
| `C;apodo;Pj-Reino;played;CLASE;nivel;ts;muertes` | Datos de un personaje |
| `D;apodo;20261102=3600,20261101=5400,...` | Segundos por día de los últimos 30 días, en trozos de 250 caracteres como máximo |
| `R;apodo` | "Envíame tus datos" (se responde una vez por minuto como máximo a cada jugador) |

### Uploader

1. Busca WoW, en este orden:
   - `wowPath` de `config.json`;
   - el registro de Windows (`HKLM\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft`);
   - rutas habituales de las unidades C: a H:.
2. Busca `WTF\Account\*\SavedVariables\HorasJugadas.lua`. Puede haber varias cuentas de WoW.
3. Lee el archivo con un **lector propio de Lua**, porque el formato de SavedVariables es un trozo de código Lua.
4. Se queda solo con `players[nick]`, es decir, **tus** datos, nunca los recibidos de otros. Si tienes varias cuentas de WoW con el mismo apodo, suma sus días.
5. Si los datos han cambiado desde la última subida, llama a la función `upload_play_data` de Supabase con tu token.
6. Si WoW está escribiendo el archivo en ese momento, espera 3 segundos y reintenta en la siguiente comprobación.

Las variables de entorno `HJ_SUPABASE_URL`, `HJ_SUPABASE_KEY` y `HJ_WOW_PATH` sustituyen a los valores de `config.json`.

### Base de datos

| Tabla | Contenido | Lectura pública |
|---|---|---|
| `players` | `nick`, `created_at`, `updated_at` | ✅ |
| `play_days` | `nick`, `day`, `seconds` (máximo 86 400 por día) | ✅ |
| `characters` | `nick`, `char_key`, `class`, `level`, `played_seconds`, `deaths`, `last_seen` | ✅ |
| `player_tokens` | `nick`, `token_hash` (SHA-256) | ❌ privada |

Nadie puede escribir directamente en las tablas. Todo pasa por la función `upload_play_data(p_nick, p_token, p_days, p_chars)`:

1. Comprueba que el apodo y el token son válidos.
2. Si el apodo es nuevo, lo crea y guarda el hash del token. Si ya existe, exige que el token coincida.
3. Inserta o actualiza los días y los personajes. Los datos que se suben siempre mandan.

### Web

Es una página estática sin frameworks ni dependencias. Consulta la API REST de Supabase con la clave pública:
- `players`;
- `play_days` de los últimos 30 días;
- `characters`, incluyendo el total histórico de muertes de cada personaje.

Calcula los rankings en el navegador y se actualiza cada 2 minutos.

---

## 6. Seguridad y privacidad

- **Qué se sube:** tu apodo, segundos jugados por día, y nombre, reino, clase, nivel, `/played` y muertes de tus personajes. **Nada más:** ni nombre de cuenta, ni email, ni nada del PC.
- **Quién puede verlo:** cualquiera que tenga la dirección de la web. Los datos son de lectura pública.
- **La clave de `config.js` y `config.json` es pública a propósito.** Solo permite leer y llamar a la función de subida. No da acceso de administrador.
- **Tu token** (`%APPDATA%\HorasJugadas\estado.json`) es lo que demuestra que un apodo es tuyo. Se genera la primera vez, es aleatorio (256 bits) y en la base de datos solo se guarda su hash.
- **Abuso:** alguien con la clave pública podría crear apodos falsos, pero nunca modificar los de otros. Si pasara, se borran desde el SQL Editor.

---

## 7. Solución de problemas

| Problema | Solución |
|---|---|
| **"No encuentro World of Warcraft"** | Abre `config.json` junto al `.exe` y pon la carpeta de WoW con barras dobles: `"wowPath": "D:\\Juegos\\World of Warcraft"` |
| **"No hay datos todavía"** | Entra al juego con el addon activado y luego **sal del juego** o haz `/reload`. WoW solo escribe el archivo en ese momento. |
| **Mis horas no aparecen en la web** | ¿Has salido del juego o hecho `/reload`? ¿Está el uploader abierto? Mira `%APPDATA%\HorasJugadas\uploader.log`. Puedes forzar la subida con `HorasJugadasUploader.exe --once --force`. |
| **"El apodo X ya pertenece a otra persona"** | Ese apodo ya lo reservó otro PC. Elige otro con `/hj nombre`. Si es tuyo y reinstalaste Windows, pide al administrador que lo libere ([4.6](#46-tareas-de-mantenimiento)). |
| **Aparezco dos veces en la web** | Cambiaste de apodo después de subir datos. Pide al administrador que borre el antiguo. |
| **El addon sale como "desactualizado"** | En el juego escribe `/dump select(4, GetBuildInfo())` y pon ese número en `## Interface:` de `HorasJugadas.toc`. O marca "Cargar addons desactualizados". |
| **Windows bloquea el `.exe`** | **Más información → Ejecutar de todas formas.** Pasa porque no está firmado digitalmente. |
| **El antivirus lo borra** | Es un falso positivo habitual con ejecutables generados con Node. Añade una excepción para la carpeta. |
| **Quiero ver qué se va a subir** | `HorasJugadasUploader.exe --dry-run` lo muestra sin subir nada. |
| **Cambié de PC** | Copia `%APPDATA%\HorasJugadas\estado.json` del PC viejo al nuevo para conservar tu token. Si no puedes, pide al administrador que libere tu apodo. |

---

## 8. Desarrollo

```powershell
# Pruebas del lector de SavedVariables
cd uploader
node test.js

# Ver lo que subiría sin subir nada
node horasjugadas-uploader.js --dry-run

# Probar la web en local
npx serve web
```

**Probar el addon sin copiarlo cada vez:** crea un enlace desde la carpeta de AddOns al repositorio (PowerShell como administrador):

```powershell
New-Item -ItemType Junction `
  -Path   "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\HorasJugadas" `
  -Target "C:\Users\<tu-usuario>\Documents\GitHub\HorasJugadas\addon\HorasJugadas"
```

Después de cambiar el Lua, escribe `/reload` en el juego. Si cambias el `.toc` hay que reiniciar WoW.

**Cambiar el esquema de la base de datos:** `schema.sql` se puede ejecutar varias veces sin romper nada. Usa `if not exists`, `create or replace` y `drop policy if exists`.

---

## 9. Limitaciones conocidas

- **No es en tiempo real:** los datos se suben al salir del juego o hacer `/reload`.
- **Cuenta el tiempo AFK**, igual que `/played`.
- **Solo se registran los días desde que instalas el addon.** El `/played` de cada personaje sí incluye todo su historial.
- **Las muertes sí incluyen el historial anterior a la instalación** siempre que WoW devuelva la estadística `Total deaths` para ese personaje. Se actualiza cuando entras con él.
- Tras instalar esta versión, hay que **entrar una vez con cada personaje** para importar sus muertes históricas; hasta entonces ese personaje contará como cero.
- **Si el juego se cierra de golpe** (por un crash o al matar el proceso), WoW no guarda el archivo y se pierde esa sesión en el historial diario. El `/played` se recupera en la siguiente entrada.
- **Los días se calculan con la hora local** de cada jugador.
- **Solo Windows** para el `.exe`. En Mac se puede ejecutar el uploader con Node: `node horasjugadas-uploader.js`.
- Dentro de **encuentros de banda o partidas competitivas**, el juego puede bloquear los mensajes entre addons. Se reintentan más tarde. A la web no le afecta.
