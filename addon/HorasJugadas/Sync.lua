-- Horas Jugadas - Sincronización entre amigos
--
-- Canales usados:
--   * Amigos de Battle.net conectados a WoW (BNSendGameData): funciona entre reinos y facciones.
--   * Hermandad y grupo/banda (C_ChatInfo.SendAddonMessage).
--   * Susurro a un personaje concreto (/hj sync Pj-Reino).
--
-- Mensajes (separados por ';'):
--   C;apodo;Pj-Reino;played;CLASE;nivel;ultimaVez;muertes -> un personaje
--   D;apodo;20261102=3600,20261101=5400,...          -> segundos por día (últimos 30 días)
--   R;apodo                                          -> "envíame tus datos"

local _, ns = ...
local HJ = ns.HJ

local PREFIX = "HorasJug"
local MAX_LEN = 250
local SEND_INTERVAL = 0.3
local BROADCAST_EVERY = 600 -- segundos

local queue = {}
local sending = false
local replied = {}

---------------------------------------------------------------------------
-- Cola de envío (evita el límite de mensajes del servidor)
---------------------------------------------------------------------------
local function InLockdown()
    return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

local function ProcessQueue()
    if #queue == 0 then
        sending = false
        return
    end
    if InLockdown() then
        C_Timer.After(5, ProcessQueue)
        return
    end
    local m = table.remove(queue, 1)
    if m.bnet then
        pcall(BNSendGameData, m.target, PREFIX, m.text)
    else
        pcall(C_ChatInfo.SendAddonMessage, PREFIX, m.text, m.channel, m.target)
    end
    C_Timer.After(SEND_INTERVAL, ProcessQueue)
end

local function Enqueue(text, channel, target, bnet)
    queue[#queue + 1] = { text = text, channel = channel, target = target, bnet = bnet }
    if not sending then
        sending = true
        C_Timer.After(0, ProcessQueue)
    end
end

local function EnqueueAll(msgs, channel, target, bnet)
    for _, text in ipairs(msgs) do Enqueue(text, channel, target, bnet) end
end

---------------------------------------------------------------------------
-- Construcción de mensajes
---------------------------------------------------------------------------
function HJ:BuildMessages()
    local nick = self.db.nick
    local me = self:GetMe()
    local msgs = {}

    for key, c in pairs(me.chars) do
        msgs[#msgs + 1] = table.concat({
            "C", nick, key, math.floor(c.played or 0), c.class or "", c.level or 0, c.last or 0,
            math.floor(c.deaths or 0),
        }, ";")
    end

    local header = "D;" .. nick .. ";"
    local cur = header
    for i = 0, 29 do
        local d = self:DayKey(i)
        local v = me.days[d]
        if v and v > 0 then
            local entry = d:gsub("-", "") .. "=" .. math.floor(v)
            if #cur + #entry + 1 > MAX_LEN then
                msgs[#msgs + 1] = cur
                cur = header
            end
            cur = cur .. (cur == header and "" or ",") .. entry
        end
    end
    if cur ~= header then msgs[#msgs + 1] = cur end

    return msgs
end

local function ForEachBNetWoWFriend(fn)
    local num = BNGetNumFriends() or 0
    for i = 1, num do
        local n = C_BattleNet.GetFriendNumGameAccounts(i) or 0
        for j = 1, n do
            local ga = C_BattleNet.GetFriendGameAccountInfo(i, j)
            if ga and ga.isOnline and ga.clientProgram == BNET_CLIENT_WOW
                and ga.wowProjectID == WOW_PROJECT_ID and ga.gameAccountID then
                fn(ga.gameAccountID)
            end
        end
    end
end

-- Envía tus datos a todos los canales. Si `request` es true, pide a los demás que respondan.
function HJ:Broadcast(request)
    if not self.db then return end
    local msgs = self:BuildMessages()
    if request then table.insert(msgs, 1, "R;" .. self.db.nick) end

    if IsInGuild() then EnqueueAll(msgs, "GUILD") end

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        EnqueueAll(msgs, "INSTANCE_CHAT")
    elseif IsInRaid() then
        EnqueueAll(msgs, "RAID")
    elseif IsInGroup() then
        EnqueueAll(msgs, "PARTY")
    end

    ForEachBNetWoWFriend(function(gameAccountID)
        EnqueueAll(msgs, nil, gameAccountID, true)
    end)

    self.lastSync = time()
end

function HJ:SyncWith(target)
    local msgs = self:BuildMessages()
    table.insert(msgs, 1, "R;" .. self.db.nick)
    EnqueueAll(msgs, "WHISPER", target)
end

---------------------------------------------------------------------------
-- Recepción
---------------------------------------------------------------------------
local function Split(s, sep)
    local t = {}
    for part in (s .. sep):gmatch("(.-)" .. sep) do t[#t + 1] = part end
    return t
end

local refreshPending = false
local function RefreshSoon()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.5, function()
        refreshPending = false
        if HJ.UI then HJ.UI:Refresh() end
    end)
end

function HJ:HandleMessage(text, reply)
    local f = Split(text, ";")
    local kind, nick = f[1], f[2]
    if not nick or nick == "" or nick == self.db.nick then return end

    if kind == "C" then
        local key, played = f[3], tonumber(f[4])
        if key and key ~= "" and played then
            local p = self:GetPlayer(nick, true)
            local previous = p.chars[key]
            p.chars[key] = {
                played = played,
                class = (f[5] ~= "" and f[5]) or nil,
                level = tonumber(f[6]),
                last = tonumber(f[7]),
                -- Los clientes 1.0 no envían este campo; conservar el dato que
                -- ya hubiera en lugar de borrarlo mantiene compatibilidad.
                deaths = tonumber(f[8]) or (previous and previous.deaths) or 0,
            }
            p.updated = time()
            RefreshSoon()
        end

    elseif kind == "D" then
        local p = self:GetPlayer(nick, true)
        for y, m, d, sec in (f[3] or ""):gmatch("(%d%d%d%d)(%d%d)(%d%d)=(%d+)") do
            p.days[y .. "-" .. m .. "-" .. d] = tonumber(sec)
        end
        p.updated = time()
        RefreshSoon()

    elseif kind == "R" then
        -- Responder como mucho una vez cada 60 s a cada jugador
        local now = GetTime()
        if not replied[nick] or now - replied[nick] > 60 then
            replied[nick] = now
            reply(self:BuildMessages())
        end
    end
end

function HJ:OnSyncEvent(event, prefix, text, channel, sender)
    if not self.db then return end

    -- Al unirse a un grupo, intercambiar datos con el grupo.
    if event == "GROUP_JOINED" then
        C_Timer.After(3, function() self:Broadcast(true) end)
        return
    end

    if prefix ~= PREFIX then return end

    if event == "CHAT_MSG_ADDON" then
        self:HandleMessage(text, function(msgs)
            EnqueueAll(msgs, "WHISPER", sender)
        end)
    elseif event == "BN_CHAT_MSG_ADDON" then
        local senderID = sender -- en BN_CHAT_MSG_ADDON el 4º argumento es el gameAccountID
        self:HandleMessage(text, function(msgs)
            EnqueueAll(msgs, nil, senderID, true)
        end)
    end
end

function HJ:InitSync()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("BN_CHAT_MSG_ADDON")
    self:RegisterEvent("GROUP_JOINED")

    -- Al entrar: enviar y pedir datos; después, envío periódico.
    C_Timer.After(15, function() self:Broadcast(true) end)
    C_Timer.NewTicker(BROADCAST_EVERY, function() self:Broadcast(false) end)
end
