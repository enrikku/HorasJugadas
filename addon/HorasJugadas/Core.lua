-- Horas Jugadas - Core
-- Registro de tiempo jugado, base de datos y comandos.

local ADDON_NAME, ns = ...

local HJ = CreateFrame("Frame")
ns.HJ = HJ
HorasJugadas = HJ

HJ.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "1.0.0"
HJ.TICK_SECONDS = 60     -- cada cuánto se suma tiempo
HJ.KEEP_DAYS = 120       -- días de historial que se guardan

local floor, max = math.floor, math.max

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
function HJ:Print(...)
    print("|cff33ccffHorasJugadas|r:", ...)
end

-- Fecha "YYYY-MM-DD" de hace `offset` días (hora local).
function HJ:DayKey(offset)
    local t = date("*t")
    return date("%Y-%m-%d", time({ year = t.year, month = t.month, day = t.day - (offset or 0), hour = 12 }))
end

function HJ:LastDays(n)
    local keys = {}
    for i = 0, n - 1 do keys[i] = self:DayKey(i) end
    return keys
end

function HJ:FormatTime(sec)
    sec = floor(sec or 0)
    local h = floor(sec / 3600)
    local m = floor((sec % 3600) / 60)
    if h == 0 then return format("%dm", m) end
    return format("%dh %02dm", h, m)
end

function HJ:CharKey()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName() or GetRealmName() or ""
    return name .. "-" .. realm
end

function HJ:CleanNick(n)
    n = tostring(n or ""):gsub("[;,=|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return n:sub(1, 24)
end

function HJ:DefaultNick()
    local _, battleTag = BNGetInfo()
    if battleTag and battleTag ~= "" then
        return (battleTag:gsub("#%d+$", ""))
    end
    return UnitName("player")
end

---------------------------------------------------------------------------
-- Base de datos
-- HorasJugadasDB = {
--   nick = "Apodo",
--   players = {
--     [apodo] = {
--       chars = { ["Pj-Reino"] = { played = seg, class = "MAGE", level = 80, last = ts } },
--       days  = { ["2026-11-02"] = seg },
--       updated = ts,
--     },
--   },
--   minimap = { angle = 220, hide = false },
-- }
---------------------------------------------------------------------------
function HJ:InitDB()
    HorasJugadasDB = HorasJugadasDB or {}
    local db = HorasJugadasDB
    db.players = db.players or {}
    db.minimap = db.minimap or { angle = 220, hide = false }
    if not db.nick or db.nick == "" then
        db.nick = self:CleanNick(self:DefaultNick())
    end
    self.db = db
end

function HJ:GetPlayer(nick, create)
    local p = self.db.players[nick]
    if not p and create then
        p = { chars = {}, days = {}, updated = 0 }
        self.db.players[nick] = p
    end
    return p
end

function HJ:GetMe()
    return self:GetPlayer(self.db.nick, true)
end

function HJ:GetMyChar()
    local me = self:GetMe()
    local key = self:CharKey()
    local c = me.chars[key]
    if not c then
        c = { played = 0 }
        me.chars[key] = c
    end
    return c
end

function HJ:UpdateCharInfo()
    local c = self:GetMyChar()
    local _, class = UnitClass("player")
    c.class = class
    c.level = UnitLevel("player")
    c.last = time()
end

function HJ:SetNick(new)
    new = self:CleanNick(new)
    if new == "" then return false, "El apodo no puede estar vacío." end
    local old = self.db.nick
    if old == new then return true end
    if self.db.players[new] then
        return false, "Ya existe un jugador con ese apodo. Usa /hj borrar " .. new .. " primero si es un error."
    end
    self.db.players[new] = self.db.players[old]
    self.db.players[old] = nil
    self.db.nick = new
    return true
end

function HJ:Prune()
    local cutoff = self:DayKey(self.KEEP_DAYS)
    for _, p in pairs(self.db.players) do
        for day in pairs(p.days) do
            if day < cutoff then p.days[day] = nil end
        end
    end
end

---------------------------------------------------------------------------
-- Estadísticas
---------------------------------------------------------------------------
function HJ:Stats(p, keys)
    keys = keys or self:LastDays(30)
    local s = { total = 0, today = 0, week = 0, month = 0, chars = 0 }
    local best = -1
    for _, c in pairs(p.chars) do
        local played = c.played or 0
        s.total = s.total + played
        s.chars = s.chars + 1
        if played > best then best, s.mainClass = played, c.class end
    end
    for i = 0, 29 do
        local v = p.days[keys[i]] or 0
        if i == 0 then s.today = v end
        if i < 7 then s.week = s.week + v end
        s.month = s.month + v
    end
    return s
end

-- mode: "today" | "week" | "month" | "total"
function HJ:GetRanking(mode)
    local keys = self:LastDays(30)
    local out = {}
    for nick, p in pairs(self.db.players) do
        local s = self:Stats(p, keys)
        out[#out + 1] = { nick = nick, value = s[mode] or 0, class = s.mainClass, isMe = (nick == self.db.nick) }
    end
    table.sort(out, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.nick < b.nick
    end)
    return out
end

function HJ:ExportCSV()
    local lines = { "# Dias", "jugador,fecha,segundos,horas" }
    local nicks = {}
    for nick in pairs(self.db.players) do nicks[#nicks + 1] = nick end
    table.sort(nicks)
    for _, nick in ipairs(nicks) do
        local p = self.db.players[nick]
        local days = {}
        for d in pairs(p.days) do days[#days + 1] = d end
        table.sort(days)
        for _, d in ipairs(days) do
            local s = floor(p.days[d])
            lines[#lines + 1] = format("%s,%s,%d,%.2f", nick, d, s, s / 3600)
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "# Personajes"
    lines[#lines + 1] = "jugador,personaje,clase,nivel,played_segundos,played_horas"
    for _, nick in ipairs(nicks) do
        for key, c in pairs(self.db.players[nick].chars) do
            local s = floor(c.played or 0)
            lines[#lines + 1] = format("%s,%s,%s,%d,%d,%.2f", nick, key, c.class or "", c.level or 0, s, s / 3600)
        end
    end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Seguimiento del tiempo
---------------------------------------------------------------------------
function HJ:Tick()
    local now = GetTime()
    local delta = now - (self.lastTick or now)
    self.lastTick = now
    if delta <= 0 then return end
    if delta > 300 then delta = self.TICK_SECONDS end -- protección ante saltos raros

    local me = self:GetMe()
    local day = self:DayKey(0)
    me.days[day] = (me.days[day] or 0) + delta

    local c = self:GetMyChar()
    c.played = (c.played or 0) + delta
    c.last = time()
    me.updated = time()

    if self.UI then self.UI:Refresh() end
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
HJ:RegisterEvent("PLAYER_LOGIN")
HJ:RegisterEvent("PLAYER_LOGOUT")
HJ:RegisterEvent("TIME_PLAYED_MSG")
HJ:RegisterEvent("PLAYER_LEVEL_UP")

HJ:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        self:InitDB()
        self:UpdateCharInfo()
        self:Prune()
        self.lastTick = GetTime()
        C_Timer.NewTicker(self.TICK_SECONDS, function() self:Tick() end)
        -- /played real del personaje (sobrescribe la estimación)
        C_Timer.After(5, function() RequestTimePlayed() end)
        if self.InitSync then self:InitSync() end
        if self.UI then self.UI:Init() end
        self:Print("cargado. Apodo: |cffffff00" .. self.db.nick .. "|r  ·  /hj para abrir")

    elseif event == "PLAYER_LOGOUT" then
        if self.db then self:Tick() end

    elseif event == "TIME_PLAYED_MSG" then
        local total = ...
        if self.db and total then
            local c = self:GetMyChar()
            c.played = total
            c.last = time()
            if self.UI then self.UI:Refresh() end
        end

    elseif event == "PLAYER_LEVEL_UP" then
        local level = ...
        if self.db then self:GetMyChar().level = level end

    elseif self.OnSyncEvent then
        self:OnSyncEvent(event, ...)
    end
end)

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
local function Help()
    HJ:Print("comandos:")
    print("  /hj  - abrir/cerrar la ventana")
    print("  /hj nombre <apodo>  - cambiar tu apodo (agrupa todos tus personajes)")
    print("  /hj sync  - enviar tus datos y pedir los de los demás")
    print("  /hj sync <Pj-Reino>  - sincronizar con un jugador concreto")
    print("  /hj export  - exportar todo a CSV")
    print("  /hj borrar <apodo>  - borrar los datos de un jugador")
    print("  /hj minimapa  - mostrar/ocultar el botón del minimapa")
end

SLASH_HORASJUGADAS1 = "/hj"
SLASH_HORASJUGADAS2 = "/horas"
SlashCmdList.HORASJUGADAS = function(msg)
    if not HJ.db then return end
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()

    if cmd == "" then
        HJ.UI:Toggle()
    elseif cmd == "nombre" or cmd == "apodo" then
        if rest == "" then
            HJ:Print("tu apodo es |cffffff00" .. HJ.db.nick .. "|r")
        else
            local ok, err = HJ:SetNick(rest)
            if ok then
                HJ:Print("apodo cambiado a |cffffff00" .. HJ.db.nick .. "|r")
                HJ:Broadcast(false)
                HJ.UI:Refresh()
            else
                HJ:Print(err)
            end
        end
    elseif cmd == "sync" then
        if rest ~= "" then HJ:SyncWith(rest) else HJ:Broadcast(true) end
        HJ:Print("sincronizando...")
    elseif cmd == "export" or cmd == "exportar" then
        HJ.UI:ShowExport()
    elseif cmd == "borrar" then
        if HJ.db.players[rest] and rest ~= HJ.db.nick then
            HJ.db.players[rest] = nil
            HJ:Print("datos de " .. rest .. " borrados.")
            HJ.UI:Refresh()
        else
            HJ:Print("no encuentro a '" .. rest .. "' (no puedes borrarte a ti mismo).")
        end
    elseif cmd == "minimapa" then
        HJ.db.minimap.hide = not HJ.db.minimap.hide
        HJ.UI:UpdateMinimapButton()
    else
        Help()
    end
end
