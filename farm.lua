--[[
Auto Farm + Auto Crate - MM2 | FINAL BUILD v4 (Halloween '26)
- Скорость 20 studs/sec (постоянная)
- АВТО-КЕЙСЫ: отдельный поток, ремоуты ищутся лениво (не блокируют скрипт)
    🎃 НОВОЕ: Halloween2026Box — 600 Candies2026 ИЛИ 1 HalloweenKey2026
    (имена подтверждены дампом игры: Remotes.Shop.OpenCrate [RemoteFunction],
     Remotes.Shop.BoxController [BindableEvent])
- РЕСПАВН: Health=0 + ChangeState(Dead) + защита от цикла смертей (bagBelowLimit)
- ПУТЬ К МОНЕТАМ: MainGUI.Lobby.Dock.CoinBags... (конфеты: MainGUI.Game.CoinBags.Container.Candy)
- NoClip ULTIMATE + Антигравитация (сила считается от workspace.Gravity)
- РЕКОННЕКТ при ошибке 279 (+ 277/268/267) с ретраями каждые 5 сек
- Watchdog: перезаход, если раунда нет N минут (чисто по времени — фикс залипания)
- v4: хеллоуин-кейс + фиксы из код-ревью (fallback, watchdog, цикл смертей,
  лог ошибок, восстановление noclip, таймауты WaitForChild, GuiInset и др.)
- v4.1 (DELTA X FIX): теперь работает и на телефонах:
    • ждёт загрузку игры и LocalPlayer (Delta X часто выполняет авто-execute
      ещё ДО входа в игру — раньше всё падало с "attempt to index nil")
    • ВСЕ необязательные сервисы (VirtualUser/VirtualInputManager) — через pcall
    • клик по GUI кроссплатформенный: getconnections → VIM → VirtualUser
      (на Delta X тачскрин и VIM-клики не работают — стреляем обработчики напрямую)
    • анти-АФК: проверка VirtualUser + хук LocalPlayer.Idled
    • очередь телепорта: + getgenv().queue_on_teleport
    • печать информации об экзекьюторе (для диагностики на телефоне)
]]

-- ================= 🛠️ СЕРВИСЫ (Xeno / Delta X / мобильные) =================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

-- ФИКС DELTA: ВСЕ необязательные сервисы — только через pcall.
-- На мобильных экзекьюторах VirtualUser/VirtualInputManager могут отсутствовать
-- или быть заблокированы, и обычный GetService уронил бы ВЕСЬ скрипт на 1-й строке.
local VirtualUser
pcall(function() VirtualUser = game:GetService("VirtualUser") end)
local VirtualInputManager
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

-- ФИКС DELTA (авто-execute): на телефонах скрипт часто запускается ещё ДО входа
-- в игру. Без ожидания LocalPlayer всё падало с "attempt to index nil".
if not game:IsLoaded() then
    print("⏳ [MM2] Жду загрузку игры...")
    local loaded = false
    local conn
    pcall(function()
        conn = game.Loaded:Connect(function() loaded = true end)
    end)
    local t0 = os.clock()
    while not loaded and os.clock() - t0 < 120 do task.wait(0.5) end
    if conn then pcall(function() conn:Disconnect() end) end
end

local LocalPlayer = Players.LocalPlayer
local lpT0 = os.clock()
while not LocalPlayer and os.clock() - lpT0 < 30 do
    task.wait(0.25)
    LocalPlayer = Players.LocalPlayer
end
if not LocalPlayer then
    error("[MM2] LocalPlayer не найден — зайди в игру и запусти скрипт ещё раз")
end

-- Инфо об экзекьюторе — видно в консоли, что доступно на телефоне
local EXECUTOR = "unknown"
pcall(function()
    if type(identifyexecutor) == "function" then EXECUTOR = tostring(identifyexecutor()) end
end)
print("📟 [MM2] Экзекьютор: " .. EXECUTOR
    .. " | getconnections: " .. tostring(type(getconnections) == "function")
    .. " | VIM: " .. tostring(VirtualInputManager ~= nil)
    .. " | VirtualUser: " .. tostring(VirtualUser ~= nil))

-- ================= ⚙️ НАСТРОЙКИ =================
local SETTINGS = {
    Enabled = true,
    MoveSpeed = 20,
    CollectionRadius = 4.0,
    LoopDelay = 0.1,
    MaxBagCoins = 40,
    AutoRespawn = true,
    SpawnWaitTime = 3.0,
    YOffset = -2,
    ReconnectDelay = 2,        -- пауза перед первой попыткой перезахода
    ReconnectRetry = 5,        -- ретрай телепорта каждые 5 сек (как было)
    IdleReconnectMinutes = 15, -- перезаход, если раунда нет N минут (0 = выкл)

    -- 🎃 ХЕЛЛОУИН 2026 (по дампу игры):
    -- Halloween2026Box: Price = { Candies2026 = 600, HalloweenKey2026 = 1 }
    AutoOpenHalloween = true,  -- открывать хеллоуин-кейс вместе с обычными
    HalloweenCurrencies = { "Candies2026", "HalloweenKey2026" },
    -- ^ порядок траты: СНАЧАЛА конфеты (их фармится много), потом ключ (их мало).
    --   Поменяй местами, если хочешь сначала тратить ключи.
}

-- ❗ ВПИШИ ссылку на скрипт, иначе после перезахода запускать вручную
local SCRIPT_URL = "" -- например "https://raw.githubusercontent.com/.../farm.lua"

-- Коды ошибок, при которых перезаходим
local RECONNECT_CODES = {
    ["279"] = true, -- Connection attempt failed
    ["277"] = true, -- Disconnected unexpectedly
    ["268"] = true, -- Kicked
    ["267"] = true, -- Kicked from game
}

local MAX_IGNORED = 10
local IGNORE_DUR = 3.0
local isReconnecting = false
local isRespawning = false

-- ================= 🔄 СОСТОЯНИЕ =================
local isRoundActive = false
local collectedCoins = {}
local currentTween = nil
local isMoving = false
local noclipActive = false
local antiGravForce = nil
local collisionGroupReady = false
local bagBelowLimit = false -- ФИКС цикла смертей: true, когда видели мешок НИЖЕ лимита
local coinCounter = 0
local lastTarget = nil
local lastRoundTime = os.clock()
local noMapSince = nil      -- ФИКС: с какого момента рядом нет карты (детект лобби)
local savedPartStates = {}  -- ФИКС: исходные свойства частей для отката noclip

-- ================= 🔌 РЕКОННЕКТ (в т.ч. ошибка 279) =================
local function getQueueFn()
    if type(queue_on_teleport) == "function" then return queue_on_teleport end
    if syn and type(syn.queue_on_teleport) == "function" then return syn.queue_on_teleport end
    if fluxus and type(fluxus.queue_on_teleport) == "function" then return fluxus.queue_on_teleport end
    if Delta and type(Delta.queue_on_teleport) == "function" then return Delta.queue_on_teleport end
    -- ФИКС DELTA: у некоторых сборок функция живёт только в getgenv()
    if type(getgenv) == "function" then
        local ok, g = pcall(getgenv)
        if ok and g and type(g.queue_on_teleport) == "function" then return g.queue_on_teleport end
    end
    return nil
end

local function forceReconnect(reason)
    if isReconnecting then return end -- дебаунс: 279 + PlayerRemoving часто срабатывают вместе
    isReconnecting = true
    print("🔌 Reconnecting: " .. tostring(reason))

    if SCRIPT_URL ~= "" then
        local q = getQueueFn()
        if q then
            pcall(q, 'loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
            print("✅ Скрипт поставлен в очередь на перезаход")
        else
            warn("⚠️ queue_on_teleport не поддерживается — после перезахода запусти скрипт вручную")
        end
    else
        warn("⚠️ SCRIPT_URL пуст — после перезахода запусти скрипт вручную")
    end

    task.spawn(function()
        task.wait(SETTINGS.ReconnectDelay)
        -- Ретраи каждые 5 сек, пока сессия жива.
        -- После успешного телепорта место выгрузится и цикл умрёт сам.
        while true do
            local ok = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
            if not ok then
                pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
            end
            task.wait(SETTINGS.ReconnectRetry)
        end
    end)
end

-- Отладка: печатаем ЛЮБОЕ сообщение об ошибке (видно реальные коды)
GuiService.ErrorMessageChanged:Connect(function(errorMessage)
    if errorMessage and errorMessage ~= "" then
        print("⚠️ [ERROR MSG] " .. tostring(errorMessage))
        for code in pairs(RECONNECT_CODES) do
            if tostring(errorMessage):find(code, 1, true) then
                forceReconnect("Error " .. code)
                break
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then forceReconnect("PlayerRemoving") end
end)

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
        if player == LocalPlayer then
            print("🚫 [TELEPORT FAILED] " .. teleportResult.Name .. " | " .. tostring(errorMessage))
            forceReconnect("TeleportInitFailed")
        end
    end)
end)

local consecutiveFailures = 0
RunService.Heartbeat:Connect(function()
    if isReconnecting then return end
    if not LocalPlayer or not LocalPlayer.Parent then
        consecutiveFailures = consecutiveFailures + 1
        if consecutiveFailures >= 3 then forceReconnect("Heartbeat: LocalPlayer lost") end
    else
        consecutiveFailures = 0
    end
end)

-- Watchdog: перезаход, если долго висим без раунда
-- ФИКС: раньше условие "not isRoundActive" залипало в true после конца раунда
-- (isRoundActive сбрасывался только при смерти/респавне) и watchdog никогда
-- не срабатывал именно тогда, когда был нужен. Теперь смотрим ТОЛЬКО время
-- с последнего RoundStart/конца раунда.
task.spawn(function()
    if (SETTINGS.IdleReconnectMinutes or 0) <= 0 then return end
    while not isReconnecting do
        task.wait(10)
        if (os.clock() - lastRoundTime) > SETTINGS.IdleReconnectMinutes * 60 then
            forceReconnect("Idle: раунда нет дольше " .. SETTINGS.IdleReconnectMinutes .. " мин")
        end
    end
end)
-- ================= 🖱️ ВЫБОР УСТРОЙСТВА (кросс-платформенно) =================
-- ФИКС DELTA: раньше клик делался ТОЛЬКО через VirtualInputManager, которого
-- на телефонах нет (или его клики не работают). Из-за этого окно выбора
-- устройства оставалось неоткрытым/неотвеченным на Delta X.
-- Кросс-платформенный клик по кнопке GUI (по порядку):
--   1) getconnections — стреляем обработчики напрямую (работает и на Xeno, и на Delta X)
--   2) VirtualInputManager — обычный клик по координатам (только PC)
--   3) VirtualUser — запасной вариант
local function clickGuiButton(button)
    if not button or not button:IsA("GuiButton") then return false end

    if type(getconnections) == "function" then
        local fired = false
        pcall(function()
            for _, sig in ipairs({ button.Activated, button.MouseButton1Click, button.MouseButton1Down }) do
                local okC, conns = pcall(getconnections, sig)
                if okC and type(conns) == "table" then
                    for _, conn in ipairs(conns) do
                        if pcall(function() conn:Fire() end) then fired = true end
                    end
                end
            end
        end)
        if fired then return true end
    end

    if VirtualInputManager then
        local ok = pcall(function()
            local bp, bs = button.AbsolutePosition, button.AbsoluteSize
            -- ФИКС: AbsolutePosition не включает GuiInset (топбар ~36px),
            -- из-за этого клик мог уходить выше кнопки
            local inset = GuiService:GetGuiInset()
            local x = bp.X + bs.X / 2 + inset.X
            local y = bp.Y + bs.Y / 2 + inset.Y
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(0.1)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
        if ok then return true end
    end

    if VirtualUser then
        local ok = pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new())
        end)
        if ok then return true end
    end

    warn("⚠️ [CLICK] Клик по GUI не удался — нет доступных способов")
    return false
end

-- ФИКС: top-level task.wait(10) УДАЛЁН — он 10 секунд блокировал старт всего
-- скрипта (CharacterAdded, раунды, кейсы). Поток и так сам ждёт GUI до 60 сек.
task.spawn(function()
    local deadline = os.clock() + 60
    while os.clock() < deadline do
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local gui = pg and pg:FindFirstChild("DeviceSelect")
        if gui then
            pcall(function()
                local container = gui:WaitForChild("Container", 5)
                local phone = container and container:WaitForChild("Phone", 5)
                local button = phone and phone:WaitForChild("Button", 5)
                if button then
                    if clickGuiButton(button) then
                        print("🖱️ Устройство выбрано (Phone)")
                    end
                end
            end)
            break
        end
        task.wait(0.25)
    end
end)

-- ================= 🚫 NOCLIP ULTIMATE + АНТИГРАВИТАЦИЯ =================
local STATES_TO_BLOCK = {
    Enum.HumanoidStateType.GettingUp, Enum.HumanoidStateType.FallingDown,
    Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Freefall,
    Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Landed,
    Enum.HumanoidStateType.Running, Enum.HumanoidStateType.RunningNoPhysics,
    Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.Swimming,
}

local function setupAntiGravity(hrp)
    if antiGravForce then pcall(function() antiGravForce:Destroy() end) end
    local att = hrp:FindFirstChild("AntiGravAttachment")
    if not att then
        att = Instance.new("Attachment")
        att.Name = "AntiGravAttachment"
        att.Parent = hrp
    end
    local vf = Instance.new("VectorForce")
    vf.Name = "AntiGravity"
    vf.Attachment0 = att
    -- ФИКС: сила от workspace.Gravity, а не хардкод 196.2 (в игре может быть другая гравитация)
    vf.Force = Vector3.new(0, hrp.AssemblyMass * workspace.Gravity, 0)
    vf.RelativeTo = Enum.ActuatorRelativeTo.World
    vf.ApplyAtCenterOfMass = true
    vf.Parent = hrp
    antiGravForce = vf
end

local function removeAntiGravity()
    if antiGravForce then
        pcall(function() antiGravForce:Destroy() end)
        antiGravForce = nil
    end
end

local function isGroupRegistered(name)
    local ok, res = pcall(function()
        return PhysicsService:CollisionGroupIsRegistered(name)
    end)
    return ok and res == true
end

local function ensureCollisionGroup() -- регистрация ОДИН раз (раньше — каждый Heartbeat)
    if collisionGroupReady then return end
    pcall(function()
        -- ФИКС: если группа уже зарегистрирована, повторный RegisterCollisionGroup
        -- кинул бы ошибку и collisionGroupReady никогда не ставился в true
        if not isGroupRegistered("UltimateNC") then
            PhysicsService:RegisterCollisionGroup("UltimateNC")
        end
        PhysicsService:CollisionGroupSetCollidable("UltimateNC", "Default", false)
        collisionGroupReady = true
    end)
end

local function applyUltimateNoClip(character)
    if not character then return end
    ensureCollisionGroup()
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = true
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
        for _, state in ipairs(STATES_TO_BLOCK) do
            pcall(function() hum:SetStateEnabled(state, false) end)
        end
    end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            -- ФИКС: запоминаем ИСХОДНЫЕ свойства, чтобы disableNoClip
            -- возвращал их, а не ставил всем CanCollide=true / Massless=false
            if not savedPartStates[part] then
                savedPartStates[part] = {
                    cc = part.CanCollide,
                    m = part.Massless,
                    cg = part.CollisionGroup,
                }
            end
            part.CanCollide = false
            part.Massless = true
            pcall(function() part.CollisionGroup = "UltimateNC" end)
        end
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp and not antiGravForce then setupAntiGravity(hrp) end
end

local function enableNoClip()
    if noclipActive then return end
    noclipActive = true
    if LocalPlayer.Character then applyUltimateNoClip(LocalPlayer.Character) end
end

local function disableNoClip()
    if not noclipActive then return end
    noclipActive = false
    if currentTween then pcall(function() currentTween:Cancel() end); currentTween = nil end
    isMoving = false
    removeAntiGravity()
    local char = LocalPlayer.Character
    if not char then
        savedPartStates = {}
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        -- ФИКС: сначала разблокируем стейты, ПОТОМ ChangeState(GettingUp) —
        -- раньше GettingUp был ещё заблокирован и ChangeState игнорировался
        for _, state in ipairs(STATES_TO_BLOCK) do
            pcall(function() hum:SetStateEnabled(state, true) end)
        end
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end
    -- ФИКС: восстановление исходных свойств частей (включая CollisionGroup)
    for part, st in pairs(savedPartStates) do
        if part and part.Parent then
            part.CanCollide = st.cc
            part.Massless = st.m
            pcall(function() part.CollisionGroup = st.cg end)
        end
    end
    savedPartStates = {}
end

-- Лёгкий per-frame цикл: только удержание состояния
RunService.Heartbeat:Connect(function()
    if not noclipActive then return end
    local char = LocalPlayer.Character
    if not char then return end
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and not hum.PlatformStand then
            hum.PlatformStand = true
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
        end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                if not savedPartStates[part] then
                    savedPartStates[part] = { cc = true, m = part.Massless, cg = part.CollisionGroup }
                end
                part.CanCollide = false
                pcall(function() part.CollisionGroup = "UltimateNC" end)
            end
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            if not antiGravForce or antiGravForce.Parent ~= hrp then
                setupAntiGravity(hrp)
            end
            if antiGravForce then
                antiGravForce.Force = Vector3.new(0, hrp.AssemblyMass * workspace.Gravity, 0)
            end
        end
    end)
end)

-- ================= 📡 ОБНАРУЖЕНИЕ РАУНДА =================
local function setupRoundDetection()
    task.spawn(function()
        local gameplay, roundStart
        for _ = 1, 10 do -- до ~30 сек попыток (по дампу: Remotes.Gameplay.RoundStart)
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            gameplay = remotes and remotes:FindFirstChild("Gameplay")
            roundStart = gameplay and gameplay:FindFirstChild("RoundStart")
            if roundStart and roundStart:IsA("RemoteEvent") then break end
            task.wait(3)
        end

        if roundStart and roundStart:IsA("RemoteEvent") then
            roundStart.OnClientEvent:Connect(function()
                isRoundActive = true
                lastRoundTime = os.clock() -- для idle-watchdog
                bagBelowLimit = false      -- ФИКС цикла смертей: реарм на новом раунде
                lastTarget = nil
                collectedCoins = {}
                noMapSince = nil
                enableNoClip()
            end)
            print("✅ [ROUND] RoundStart подключён")

            -- ФИКС: конец раунда — гасим noclip. Раньше isRoundActive оставался
            -- true в лобби и персонаж не мог ходить (PlatformStand + антиграв)
            local roundEndFade = gameplay:FindFirstChild("RoundEndFade")
            if roundEndFade and roundEndFade:IsA("RemoteEvent") then
                roundEndFade.OnClientEvent:Connect(function()
                    isRoundActive = false
                    lastRoundTime = os.clock()
                    disableNoClip()
                end)
                print("✅ [ROUND] RoundEndFade подключён")
            end
        else
            -- ФИКС: fallback больше НЕ одноразовый. Раньше после первой смерти
            -- цикл завершался и фарм умирал навсегда (до перезахода)
            print("⚠️ [ROUND] RoundStart не найден — fallback-режим (с переактивацией)")
            while true do
                task.wait(3)
                if isRoundActive then continue end
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if char and char:FindFirstChild("HumanoidRootPart") and hum and hum.Health > 0 then
                    isRoundActive = true
                    lastRoundTime = os.clock()
                    enableNoClip()
                end
            end
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    isRoundActive = false
    noMapSince = nil
    lastTarget = nil
    disableNoClip() -- также восстанавливает и чистит savedPartStates
    -- Died подключаем СРАЗУ (раньше — через wait(1), смерть терялась)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        hum.Died:Connect(function()
            isRoundActive = false
            disableNoClip()
        end)
    end
end)

-- ФИКС: подключаем Died и к персонажу, который УЖЕ существует на момент запуска
-- (CharacterAdded на него не срабатывает — смерть первого персонажа терялась)
do
    local ch0 = LocalPlayer.Character
    local hum0 = ch0 and ch0:FindFirstChildOfClass("Humanoid")
    if hum0 then
        hum0.Died:Connect(function()
            isRoundActive = false
            disableNoClip()
        end)
    end
end

-- ================= 🛠️ ВСПОМОГАТЕЛЬНЫЕ =================
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getBagCoins()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return 0 end
    local function sf(p, n) return p and p:FindFirstChild(n) end
    local obj = sf(sf(sf(sf(sf(sf(sf(sf(
        playerGui, "MainGUI"),
        "Lobby"), "Dock"), "CoinBags"), "Container"), "Coin"), "CurrencyFrame"), "Icon")
    if obj then obj = obj:FindFirstChild("Coins") end
    if not obj then return 0 end
    local text = obj:IsA("TextLabel") and obj.Text or ""
    text = text:gsub("[,%s]", "") -- ФИКС: "1,234" раньше читалось как 1
    return tonumber(text:match("%d+")) or 0
end

-- 🍬 Конфеты (Halloween 2026): CurrencyName = "Candies2026"
-- Дамп показывает мешок: MainGUI.Game.CoinBags.Container.Candy [Frame]
-- (BagName = "Coin Bag"). Добавлен и Lobby-путь как запасной.
local function getCandies()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return 0 end
    local function sf(p, n) return p and p:FindFirstChild(n) end
    local paths = {
        { "MainGUI", "Game",  "CoinBags", "Container", "Candy" },
        { "MainGUI", "Lobby", "Dock", "CoinBags", "Container", "Candy" },
    }
    for _, path in ipairs(paths) do
        local node = playerGui
        for _, name in ipairs(path) do
            node = sf(node, name)
        end
        local frame = node and node:FindFirstChild("CurrencyFrame")
        if frame then
            -- сначала точная структура (как у монет: CurrencyFrame.Icon.<TextLabel>),
            -- затем — любой TextLabel с цифрами внутри CurrencyFrame
            local labels = {}
            local icon = frame:FindFirstChild("Icon")
            if icon then
                for _, d in ipairs(icon:GetChildren()) do
                    if d:IsA("TextLabel") then table.insert(labels, d) end
                end
            end
            if #labels == 0 then
                for _, d in ipairs(frame:GetDescendants()) do
                    if d:IsA("TextLabel") then table.insert(labels, d) end
                end
            end
            for _, label in ipairs(labels) do
                local text = (label.Text or ""):gsub("[,%s]", "")
                local num = tonumber(text:match("%d+"))
                if num then return num end
            end
        end
    end
    return 0
end

-- ================= 💀 РЕСПАВН =================
local function forceRespawn()
    if isRespawning then return end
    isRespawning = true
    print("💀 Запуск респавна...")

    -- ФИКС: тело в pcall — раньше любая ошибка здесь оставляла
    -- isRespawning = true навсегда и респавн больше никогда не срабатывал
    local ok, err = pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum then
            print("❌ Нет персонажа/Humanoid!")
            return
        end

        if currentTween then pcall(function() currentTween:Cancel() end); currentTween = nil end
        isMoving = false
        lastTarget = nil

        pcall(function() hum.Health = 0 end)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)

        print("⏳ Ожидание респавна (" .. tostring(SETTINGS.SpawnWaitTime) .. " сек)...")
        task.wait(SETTINGS.SpawnWaitTime)

        local newChar = LocalPlayer.Character
        if newChar and newChar ~= char then
            print("✅ Новый персонаж появился!")
            if newChar:WaitForChild("HumanoidRootPart", 5) then
                enableNoClip()
            end
        else
            print("⚠️ Персонаж не изменился, пробую Destroy...")
            pcall(function() char:Destroy() end)
            task.wait(2)
            local retryChar = LocalPlayer.Character
            if retryChar and retryChar:WaitForChild("HumanoidRootPart", 5) then
                enableNoClip()
            end
        end
    end)
    if not ok then
        warn("⚠️ [RESPAWN] Ошибка: " .. tostring(err))
    end

    isRespawning = false
    print("✅ Респавн завершён")
end
-- ================= 🪙 ИГНОР МОНЕТ =================
local function isCollected(coin)
    local now = tick()
    for _, d in ipairs(collectedCoins) do
        if d.coin == coin and now < d.time + IGNORE_DUR then return true end
    end
    return false
end

local function markCollected(coin)
    table.insert(collectedCoins, {coin = coin, time = tick()})
    if #collectedCoins > MAX_IGNORED then table.remove(collectedCoins, 1) end
end

local function getNearestCoin(map, hrp)
    if not map or not hrp then return nil, math.huge end
    local container = map:FindFirstChild("CoinContainer")
    if not container then return nil, math.huge end
    local target, minDist = nil, math.huge
    for _, part in ipairs(container:GetChildren()) do
        if not part:IsA("BasePart") then continue end
        if not part.Name:lower():find("coin") then continue end
        if isCollected(part) then continue end
        local dist = (part.Position - hrp.Position).Magnitude
        if dist < minDist then minDist = dist; target = part end
    end
    return target, minDist
end

-- ================= TWEEN =================
local function tweenToTarget(hrp, targetPos)
    if currentTween then pcall(function() currentTween:Cancel() end) end
    local dist = (targetPos - hrp.Position).Magnitude
    local moveTime = math.max(dist / SETTINGS.MoveSpeed, 0.1)
    local tweenInfo = TweenInfo.new(moveTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(targetPos)})
    currentTween = tween
    isMoving = true
    -- фикс гонки: старый твин не обнулит ссылку на новый
    tween.Completed:Connect(function()
        if currentTween == tween then
            isMoving = false
            currentTween = nil
        end
    end)
    tween:Play()
end

-- ================= 📦 АВТО-КЕЙСЫ (отдельный поток, ремоуты лениво) =================
task.spawn(function()
    print("🔥 [CRATE] Auto Opener запущен (жду Remotes.Shop...)")
    math.randomseed(math.floor(tick() * 1000) % 2147483647)

    -- ФИКС: таймауты у WaitForChild — если путей нет, поток выйдет с warn'ом,
    -- а не зависнет молча навсегда (как в v3)
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 120)
    if not remotes then
        warn("⚠️ [CRATE] ReplicatedStorage.Remotes не найден — автокейсы отключены")
        return
    end
    local Shop = remotes:WaitForChild("Shop", 120)
    if not Shop then
        warn("⚠️ [CRATE] Remotes.Shop не найден — автокейсы отключены")
        return
    end
    local OpenCrate = Shop:WaitForChild("OpenCrate", 120)
    local BoxController = Shop:WaitForChild("BoxController", 120)
    if not OpenCrate or not BoxController then
        warn("⚠️ [CRATE] OpenCrate/BoxController не найдены — автокейсы отключены")
        return
    end

    if not OpenCrate:IsA("RemoteFunction") then
        warn("⚠️ [CRATE] OpenCrate — это " .. OpenCrate.ClassName .. ", InvokeServer может не работать!")
    end

    -- Каждый бокс — со своим списком валют (порядок = приоритет траты)
    local boxes = {
        { id = "KnifeBox1", currencies = { "Coins", "Gems", "Key" } },
        { id = "KnifeBox2", currencies = { "Coins", "Gems", "Key" } },
        { id = "KnifeBox3", currencies = { "Coins", "Gems", "Key" } },
        { id = "KnifeBox4", currencies = { "Coins", "Gems", "Key" } },
        { id = "KnifeBox5", currencies = { "Coins", "Gems", "Key" } },
        { id = "GunBox1",   currencies = { "Coins", "Gems", "Key" } },
        { id = "GunBox3",   currencies = { "Coins", "Gems", "Key" } },
    }

    -- 🎃 ХЕЛЛОУИН 2026 (из дампа игры):
    -- ReplicatedStorage.Remotes.Events.Halloween2026Remotes / GetEvents:
    --   Items.MysteryBox.Halloween2026Box:
    --     Type = "MysteryBox"  (тот же тип, что и у обычных боксов!)
    --     Price = { Candies2026 = 600, HalloweenKey2026 = 1 }
    --     Contents: 10 предметов, Godly = "Embersickle"
    if SETTINGS.AutoOpenHalloween then
        table.insert(boxes, { id = "Halloween2026Box", currencies = SETTINGS.HalloweenCurrencies })
        print("🎃 [CRATE] Halloween2026Box в ротации (валюты: "
            .. table.concat(SETTINGS.HalloweenCurrencies, " → ") .. ")")
    end

    local function fireBoxController(data)
        -- Дамп подтвердил: BoxController — BindableEvent → нужен ЛОКАЛЬНЫЙ :Fire()
        -- (он запускает анимацию вскрытия ReplicatedStorage.Modules.BoxModule.Unboxing)
        if BoxController:IsA("RemoteEvent") then
            BoxController:FireServer(data)
        elseif BoxController:IsA("RemoteFunction") then
            BoxController:InvokeServer(data)
        else
            BoxController:Fire(data)
        end
    end

    local function openBox(box)
        for _, currency in ipairs(box.currencies) do
            local ok, result = pcall(function()
                return OpenCrate:InvokeServer(box.id, "MysteryBox", currency)
            end)
            -- print("[CRATE DEBUG]", box.id, currency, ok, result) -- раскомментируй для отладки
            if ok and result then
                pcall(function()
                    fireBoxController({ { MysteryBoxId = box.id, RewardedItemId = result } })
                end)
                print("✅ [CRATE]", box.id, "|", currency, "| Выпало:", tostring(result))
                return true
            end
        end
        return false
    end

    local openedCount, failedCount, waitingForMoney = 0, 0, false
    while SETTINGS.Enabled do
        local box = boxes[math.random(1, #boxes)]
        if openBox(box) then
            if waitingForMoney then
                print("💰 [CRATE] Деньги появились!")
                waitingForMoney = false
            end
            openedCount = openedCount + 1
            print("📦 [CRATE] Открыто: " .. openedCount .. " | Ошибок: " .. failedCount)
            task.wait(2.5)
        else
            if not waitingForMoney then
                print("⏳ [CRATE] Не хватает валюты (конфет: " .. getCandies() .. "). Ожидаю...")
                waitingForMoney = true
            end
            failedCount = failedCount + 1
            task.wait(5)
        end
    end
end)

-- ================= 🛡️ ANTI-AFK =================
-- ФИКС DELTA: VirtualUser на некоторых экзекьюторах недоступен — раньше
-- pcall молча глотал ошибку каждые 120 сек. Теперь плюс ко всему
-- подключаем LocalPlayer.Idled (надёжный анти-АФК на мобильных).
if VirtualUser then
    pcall(function()
        LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(math.random(100, 800), math.random(100, 600)))
            end)
        end)
    end)
    task.spawn(function()
        while task.wait(120) do
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(math.random(100, 800), math.random(100, 600)))
            end)
        end
    end)
else
    warn("⚠️ [AFK] VirtualUser недоступен — анти-АФК отключён")
end

-- ================= ГЛАВНЫЙ ЦИКЛ =================
setupRoundDetection()

task.spawn(function()
    local codes = {}
    for k in pairs(RECONNECT_CODES) do table.insert(codes, k) end
    print("✅ AUTO FARM + AUTO CRATE ACTIVE")
    print("   Speed: " .. SETTINGS.MoveSpeed .. " | YOffset: " .. SETTINGS.YOffset)
    print("   💀 Респавн: при " .. SETTINGS.MaxBagCoins .. " монетах")
    if SETTINGS.AutoOpenHalloween then
        print("   🎃 Хеллоуин-кейс: Halloween2026Box (валюты: "
            .. table.concat(SETTINGS.HalloweenCurrencies, " → ") .. ")")
    end
    print("   🔌 Реконнект при ошибках: " .. table.concat(codes, ", ") .. " | ретрай: " .. SETTINGS.ReconnectRetry .. " сек")
    print("")

    while SETTINGS.Enabled do
        -- ФИКС: ошибки больше не глотаются молча — иначе фарм умирает без диагностики
        local okLoop, errLoop = pcall(function()
            if not isRoundActive then task.wait(1) return end

            local hrp = getHRP()
            if not hrp then task.wait(1) return end

            if hrp.Position.Y < -50 then
                if currentTween then pcall(function() currentTween:Cancel() end); currentTween = nil end
                isMoving = false
                hrp.CFrame = CFrame.new(hrp.Position.X, 50, hrp.Position.Z)
                task.wait(2)
                return
            end

            local currentBag = getBagCoins()

            if currentBag >= SETTINGS.MaxBagCoins then
                -- ФИКС цикла смертей: респавн только если мешок был НИЖЕ лимита.
                -- Раньше bagHandled сбрасывался в CharacterAdded/RoundStart, и если
                -- мешок не сбрасывался — смерти шли по кругу каждый раунд
                if bagBelowLimit and SETTINGS.AutoRespawn and not isRespawning then
                    print(" [FARM] МЕШОК ПОЛНЫЙ: " .. currentBag .. "/" .. SETTINGS.MaxBagCoins)
                    if currentTween then pcall(function() currentTween:Cancel() end); currentTween = nil end
                    isMoving = false
                    bagBelowLimit = false
                    forceRespawn()
                end
                task.wait(1)
                return
            else
                bagBelowLimit = true
            end

            local map
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:FindFirstChild("CoinContainer") then map = obj; break end
            end

            if not map then
                -- ФИКС: карты нет > 25 сек = раунд кончился (лобби).
                -- Иначе isRoundActive залипал в true и noclip не выключался
                if isRoundActive then
                    if not noMapSince then noMapSince = os.clock() end
                    if os.clock() - noMapSince > 25 then
                        isRoundActive = false
                        noMapSince = nil
                        lastRoundTime = os.clock()
                        disableNoClip()
                        print("🏁 [FARM] Раунд закончился (карта пропала) — noclip выключен")
                    end
                else
                    noMapSince = nil
                end
                task.wait(SETTINGS.LoopDelay)
                return
            end
            noMapSince = nil

            local coin, dist = getNearestCoin(map, hrp)
            if not coin then lastTarget = nil; task.wait(SETTINGS.LoopDelay) return end

            local targetPos = Vector3.new(coin.Position.X, coin.Position.Y + SETTINGS.YOffset, coin.Position.Z)

            if dist <= SETTINGS.CollectionRadius then
                -- ФИКС зависания над монетой: если остановились в радиусе, но не
                -- вплотную — дотягиваемся точно до монеты, иначе Touched может
                -- не сработать и скрипт вечно "маркировал" одну и ту же монету
                if dist > 1.5 then
                    tweenToTarget(hrp, coin.Position)
                end
                markCollected(coin)
                lastTarget = nil
                coinCounter = coinCounter + 1
                if coinCounter % 10 == 0 then
                    print("💰 [FARM] Собрано: " .. coinCounter .. " | Мешок: " .. currentBag .. "/" .. SETTINGS.MaxBagCoins)
                end
                return
            end

            if not isMoving or lastTarget ~= coin then
                lastTarget = coin
                tweenToTarget(hrp, targetPos)
            end
        end)
        if not okLoop then
            warn("⚠️ [FARM LOOP] " .. tostring(errLoop))
        end

        task.wait(SETTINGS.LoopDelay)
    end
end)
