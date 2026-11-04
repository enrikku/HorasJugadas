-- Horas Jugadas - Interfaz
-- Ventana con ranking, detalle por jugador (gráfico de 14 días), exportación y botón de minimapa.

local _, ns = ...
local HJ = ns.HJ

local UI = { mode = "week", offset = 0 }
HJ.UI = UI

local WIDTH, HEIGHT = 520, 430
local INNER_W = WIDTH - 24
local ROWS, ROW_H = 12, 22
local CHART_DAYS = 14

local MODES = {
    { key = "today", label = "Hoy" },
    { key = "week",  label = "7 días" },
    { key = "month", label = "30 días" },
    { key = "total", label = "Total /played" },
    { key = "deaths", label = "Muertes" },
}

local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b, c.colorStr end
    return 0.8, 0.8, 0.8, "ffcccccc"
end

local function MakeWindow(name, w, h, titleText)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()
    tinsert(UISpecialFrames, name) -- se cierra con ESC

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -12)
    f.title:SetText(titleText)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    return f
end

---------------------------------------------------------------------------
-- Ventana principal
---------------------------------------------------------------------------
function UI:Create()
    if self.frame then return end
    local f = MakeWindow("HorasJugadasFrame", WIDTH, HEIGHT, "Horas Jugadas")
    f:SetScript("OnShow", function() UI:Refresh() end)
    self.frame = f

    -- Vista de ranking ------------------------------------------------------
    local list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", 12, -40)
    list:SetPoint("BOTTOMRIGHT", -12, 44)
    f.list = list

    list.modeButtons = {}
    local modeGap = 6
    local modeWidth = (INNER_W - (#MODES - 1) * modeGap) / #MODES
    for i, m in ipairs(MODES) do
        local b = CreateFrame("Button", nil, list, "UIPanelButtonTemplate")
        b:SetSize(modeWidth, 22)
        b:SetPoint("TOPLEFT", (i - 1) * (modeWidth + modeGap), 0)
        b:SetText(m.label)
        b:SetScript("OnClick", function()
            UI.mode = m.key
            UI.offset = 0
            UI:Refresh()
        end)
        list.modeButtons[m.key] = b
    end

    list.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, list)
        r:SetSize(INNER_W, ROW_H)
        r:SetPoint("TOPLEFT", 0, -30 - (i - 1) * (ROW_H + 2))

        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.06)

        r.bar = r:CreateTexture(nil, "BORDER")
        r.bar:SetPoint("TOPLEFT")
        r.bar:SetPoint("BOTTOMLEFT")
        r.bar:SetWidth(1)

        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(1, 1, 1, 0.1)

        r.rank = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.rank:SetPoint("LEFT", 4, 0)
        r.rank:SetWidth(26)
        r.rank:SetJustifyH("RIGHT")

        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.name:SetPoint("LEFT", r.rank, "RIGHT", 10, 0)
        r.name:SetWidth(300)
        r.name:SetJustifyH("LEFT")

        r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.value:SetPoint("RIGHT", -8, 0)

        r:SetScript("OnClick", function(self)
            if self.nick then UI:ShowDetail(self.nick) end
        end)
        list.rows[i] = r
    end

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        UI.offset = math.max(0, math.min(UI.offset - delta, UI.maxOffset or 0))
        UI:Refresh()
    end)

    list.empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    list.empty:SetPoint("CENTER", 0, -10)
    list.empty:SetText("Aún no hay datos.\nJuega un rato o pulsa \"Sincronizar\".")

    -- Vista de detalle -----------------------------------------------------
    local d = CreateFrame("Frame", nil, f)
    d:SetAllPoints(list)
    d:Hide()
    f.detail = d

    local back = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    back:SetSize(90, 22)
    back:SetPoint("TOPLEFT")
    back:SetText("< Volver")
    back:SetScript("OnClick", function() UI:ShowList() end)

    d.forget = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    d.forget:SetSize(90, 22)
    d.forget:SetPoint("TOPRIGHT")
    d.forget:SetText("Olvidar")
    d.forget:SetScript("OnClick", function()
        StaticPopup_Show("HORASJUGADAS_FORGET", UI.detailNick, nil, UI.detailNick)
    end)

    d.name = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    d.name:SetPoint("TOP", 0, -4)

    d.summary = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d.summary:SetPoint("TOP", 0, -34)
    d.summary:SetJustifyH("CENTER")

    local chartLabel = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chartLabel:SetPoint("TOPLEFT", 0, -78)
    chartLabel:SetText("Últimos " .. CHART_DAYS .. " días")

    local chart = CreateFrame("Frame", nil, d)
    chart:SetPoint("TOPLEFT", 0, -94)
    chart:SetSize(INNER_W, 100)
    local cbg = chart:CreateTexture(nil, "BACKGROUND")
    cbg:SetAllPoints()
    cbg:SetColorTexture(1, 1, 1, 0.04)
    d.chart = chart

    local slot = INNER_W / CHART_DAYS
    chart.bars = {}
    for i = 1, CHART_DAYS do
        local x = (i - 1) * slot
        local bar = chart:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("BOTTOMLEFT", x + 5, 0)
        bar:SetSize(slot - 10, 1)

        bar.val = chart:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bar.val:SetPoint("BOTTOM", bar, "TOP", 0, 2)

        bar.day = chart:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        bar.day:SetPoint("TOP", chart, "BOTTOMLEFT", x + slot / 2, -3)

        chart.bars[i] = bar
    end

    local charsLabel = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    charsLabel:SetPoint("TOPLEFT", 0, -222)
    charsLabel:SetText("Personajes (/played)")

    d.chars = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d.chars:SetPoint("TOPLEFT", 0, -238)
    d.chars:SetWidth(INNER_W)
    d.chars:SetJustifyH("LEFT")
    d.chars:SetSpacing(2)

    -- Pie --------------------------------------------------------------------
    local sync = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    sync:SetSize(110, 24)
    sync:SetPoint("BOTTOMLEFT", 12, 12)
    sync:SetText("Sincronizar")
    sync:SetScript("OnClick", function()
        HJ:Broadcast(true)
        HJ:Print("sincronizando...")
    end)

    local export = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    export:SetSize(110, 24)
    export:SetPoint("LEFT", sync, "RIGHT", 6, 0)
    export:SetText("Exportar")
    export:SetScript("OnClick", function() UI:ShowExport() end)

    f.footer = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.footer:SetPoint("BOTTOMRIGHT", -14, 18)
    f.footer:SetJustifyH("RIGHT")
end

function UI:Toggle()
    self:Create()
    self.frame:SetShown(not self.frame:IsShown())
end

function UI:ShowList()
    self.detailNick = nil
    self.frame.detail:Hide()
    self.frame.list:Show()
    self:Refresh()
end

function UI:ShowDetail(nick)
    self.detailNick = nick
    self.frame.list:Hide()
    self.frame.detail:Show()
    self:Refresh()
end

function UI:Refresh()
    local f = self.frame
    if not f or not f:IsShown() or not HJ.db then return end

    local footer = "Tú: |cffffff00" .. HJ.db.nick .. "|r"
    if HJ.lastSync then footer = footer .. "  ·  última sync " .. date("%H:%M", HJ.lastSync) end
    f.footer:SetText(footer)

    if self.detailNick then
        if HJ.db.players[self.detailNick] then
            self:RefreshDetail()
        else
            self:ShowList()
        end
        return
    end

    for key, b in pairs(f.list.modeButtons) do
        if key == self.mode then b:LockHighlight() else b:UnlockHighlight() end
    end

    local data = HJ:GetRanking(self.mode)
    local maxV = (data[1] and data[1].value) or 0
    self.maxOffset = math.max(0, #data - ROWS)
    self.offset = math.min(self.offset, self.maxOffset)

    for i, r in ipairs(f.list.rows) do
        local idx = i + self.offset
        local e = data[idx]
        if e then
            local cr, cg, cb = ClassColor(e.class)
            r.nick = e.nick
            r.rank:SetText(tostring(idx) .. ".")
            r.name:SetText(e.nick .. (e.isMe and " |cff888888(tú)|r" or ""))
            r.name:SetTextColor(cr, cg, cb)
            r.value:SetText(HJ:FormatStat(self.mode, e.value))
            r.bar:SetColorTexture(cr, cg, cb, 0.25)
            r.bar:SetWidth(math.max(1, maxV > 0 and (e.value / maxV) * INNER_W or 0))
            r:Show()
        else
            r.nick = nil
            r:Hide()
        end
    end
    f.list.empty:SetShown(#data == 0)
end

function UI:RefreshDetail()
    local d = self.frame.detail
    local nick = self.detailNick
    local p = HJ.db.players[nick]
    local s = HJ:Stats(p)
    local cr, cg, cb = ClassColor(s.mainClass)

    d.name:SetText(nick)
    d.name:SetTextColor(cr, cg, cb)
    d.forget:SetShown(nick ~= HJ.db.nick)
    d.summary:SetText(format(
        "Total /played: |cffffffff%s|r  ·  Muertes: |cffffffff%d|r  ·  %d personaje(s)\nHoy: |cffffffff%s|r  ·  7 días: |cffffffff%s|r  ·  30 días: |cffffffff%s|r",
        HJ:FormatTime(s.total), s.deaths, s.chars, HJ:FormatTime(s.today), HJ:FormatTime(s.week), HJ:FormatTime(s.month)))

    -- Gráfico (de más antiguo a hoy)
    local values, maxV = {}, 0
    for i = 1, CHART_DAYS do
        local v = p.days[HJ:DayKey(CHART_DAYS - i)] or 0
        values[i] = v
        if v > maxV then maxV = v end
    end
    local chartH = d.chart:GetHeight() - 16
    for i, bar in ipairs(d.chart.bars) do
        local v = values[i]
        local key = HJ:DayKey(CHART_DAYS - i)
        bar:SetHeight(math.max(1, maxV > 0 and (v / maxV) * chartH or 0))
        bar:SetColorTexture(cr, cg, cb, (i == CHART_DAYS) and 0.95 or 0.6)
        bar.val:SetText(v >= 60 and format("%.1fh", v / 3600) or "")
        bar.day:SetText(key:sub(9, 10) .. "/" .. key:sub(6, 7))
    end

    -- Lista de personajes
    local chars = {}
    for key, c in pairs(p.chars) do chars[#chars + 1] = { key = key, c = c } end
    table.sort(chars, function(a, b) return (a.c.played or 0) > (b.c.played or 0) end)
    local lines, MAX_LINES = {}, 7
    for i, e in ipairs(chars) do
        if i > MAX_LINES then
            lines[#lines + 1] = format("|cff888888... y %d más|r", #chars - MAX_LINES)
            break
        end
        local _, _, _, colorStr = ClassColor(e.c.class)
        lines[#lines + 1] = format("|c%s%s|r  |cff888888nv %s|r   %s  ·  %d muertes",
            colorStr, e.key, e.c.level or "?", HJ:FormatTime(e.c.played), math.floor(e.c.deaths or 0))
    end
    d.chars:SetText(#lines > 0 and table.concat(lines, "\n") or "|cff888888Sin personajes todavía.|r")
end

StaticPopupDialogs["HORASJUGADAS_FORGET"] = {
    text = "¿Borrar todos los datos de %s?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, nick)
        if nick and nick ~= HJ.db.nick then
            HJ.db.players[nick] = nil
            UI:ShowList()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

---------------------------------------------------------------------------
-- Exportar
---------------------------------------------------------------------------
function UI:ShowExport()
    if not self.export then
        local e = MakeWindow("HorasJugadasExport", 520, 360, "Exportar CSV  (Ctrl+A, Ctrl+C)")
        local sf = CreateFrame("ScrollFrame", nil, e, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 14, -40)
        sf:SetPoint("BOTTOMRIGHT", -34, 14)

        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(460)
        eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() e:Hide() end)
        sf:SetScrollChild(eb)

        e.eb = eb
        self.export = e
    end
    self.export.eb:SetText(HJ:ExportCSV())
    self.export:Show()
    self.export.eb:SetFocus()
    self.export.eb:HighlightText()
end

---------------------------------------------------------------------------
-- Botón del minimapa
---------------------------------------------------------------------------
function UI:UpdateMinimapButton()
    local b = self.minimapButton
    if not b then return end
    local db = HJ.db.minimap
    b:SetShown(not db.hide)
    local a = math.rad(db.angle or 220)
    local r = (Minimap:GetWidth() / 2) + 10
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function UI:CreateMinimapButton()
    local b = CreateFrame("Button", "HorasJugadasMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
    icon:SetPoint("TOPLEFT", 7, -6)

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    b:SetScript("OnClick", function() UI:Toggle() end)

    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            HJ.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            UI:UpdateMinimapButton()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Horas Jugadas")
        local s = HJ:Stats(HJ:GetMe())
        GameTooltip:AddDoubleLine("Hoy", HJ:FormatTime(s.today), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("7 días", HJ:FormatTime(s.week), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddLine("Clic: abrir  ·  Arrastrar: mover", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.minimapButton = b
    self:UpdateMinimapButton()
end

function UI:Init()
    self:Create()
    self:CreateMinimapButton()
end
