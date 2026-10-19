--[[ ════════════════════════════════════════════════════════════════════
  AUTO FARM + AUTO TIER BUY + AUTO KEY OPEN — Halloween Event v2.1
══════════════════════════════════════════════════════════════════════
  НОВОЕ В v2:
   🎃 AUTO TIER BUY  — покупка тиров за конфеты (1 тир = 600), по 1
                       с проверкой; если конфет нет — ждёт фарма
   🗝️ AUTO KEY OPEN  — ключи из тиров сразу открывают Halloween Box
   🔒 CURRENCY GUARD — конфеты (Candy) физически НЕ могут уйти в кейсы
   📦 LEGACY CRATES  — старый опеннер обычных боксов за Coins/Gems (вкл.)
   🔍 SCOUT MODE     — SETTINGS.SCOUT_ONLY = true → дамп ремоутов/GUI/
                       объектов карты в консоль (для заполнения конфига)

  ИСПРАВЛЕННЫЕ БАГИ v1 (полный отчёт — в чате):
   1. OnTeleport(Started) больше не вызывает реконнект (был цикл
      лишних телепортов: каждый нормальный телепорт считался ошибкой)
   2. Антигравитация пересоздаётся после респавна (раньше навсегда
      умирала: ссылка на Destroy-инстанс блокировала пересоздание)
   3. Парсинг "17,400" → 17400 (раньше парсилось как 17)
   4. WaitForChild("Shop") больше не вешает весь скрипт (раньше при
      отсутствии ремоутов не запускались респавн/анти-АФК/фарм)
   5. task.spawn/task.wait вместо spawn/wait (spawn троттлится ~30 Гц)
   6. Ошибки главного цикла печатаются в консоль (раньше pcall глотал)
   7. Ноклип восстанавливается после респавна без гонки потоков
   8. hum.Died вешается сразу при спавне (раньше через wait(1))
   9. Убран двойной wait после респавна
  10. DeviceSelect с таймаутами, без блокировки старта скрипта
  11. Ноклип-пак применяется при смене персонажа/раз в 0.5с, а не
      каждый кадр (была большая нагрузка + риск рассинхрона физики)

  ⚠️ ПЕРЕД ЗАПУСКОМ: заполни секции «ДАННЫЕ ОТ ПОЛЬЗОВАТЕЛЯ» ниже
     (TIER_BUY.RemotePath, KEY_OPEN.BoxId, пути к GUI).
     Не знаешь значений? Поставь SETTINGS.SCOUT_ONLY = true, запусти,
     скопируй ВЕСЬ вывод консоли и пришли его — значения впишем точно.
════════════════════════════════════════════════════════════════════ ]]

-- ================= 🛠️ СЕРВИСЫ =================
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser         = game:GetService("VirtualUser")
local Players             = game:GetService("Players")
local TweenService        = game:GetService("TweenService")
local TeleportService     = game:GetService("TeleportService")
local GuiService          = game:GetService("GuiService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local PhysicsService      = game:GetService("PhysicsService")
local RunService          = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local unpack = table.unpack or unpack

-- ================= ⚙️ НАСТРОЙКИ =================
local SETTINGS = {
    Enabled          = true,
    MoveSpeed        = 20,     -- studs/sec (постоянная)
    CollectionRadius = 4.0,
    LoopDelay        = 0.1,
    MaxBagCoins      = 50,     -- ✅ лимит мешка 50 (по твоим данным)
    AutoRespawn      = true,
    SpawnWaitTime    = 3.0,
    YOffset          = -2,
    ReconnectDelay   = 2,
    SCOUT_ONLY       = false,  -- 🔍 true = только дамп данных, без фарма/покупок
}

-- ══════════ 🎃 ПОКУПКА ТИРОВ — ДАННЫЕ ОТ ПОЛЬЗОВАТЕЛЯ ══════════
local TIER_BUY = {
    Enabled         = true,
    MaxTier         = 30,     -- всего тиров в пассе
    PricePerTier    = 600,    -- конфет за 1 тир
    BuyAmount       = 1,      -- покупаем по 1 с проверкой (твоё решение)
    WaitWhenNoCandy = 30,     -- сек между проверками, если конфет < 600
    VerifyAfterBuy  = true,   -- после покупки проверять, что тир вырос
    MaxFails        = 5,      -- неудач подряд → байер остановится (защита конфет)
    -- ⚠️ ЗАПОЛНИ (или оставь nil → автопоиск + подсказки в консоль):
    RemotePath   = nil,  -- напр. {"Remotes", "Halloween2026", "BuyTier"}
    CandyGuiPath = nil,  -- напр. {"MainGUI", "HalloweenEvent", "CandyFrame", "Amount"}
    TierGuiPath  = nil,  -- напр. {"MainGUI", "HalloweenEvent", "TierLabel"}
}

-- ══════════ 🗝️ ОТКРЫТИЕ КЛЮЧЕЙ — ДАННЫЕ ОТ ПОЛЬЗОВАТЕЛЯ ══════════
local KEY_OPEN = {
    Enabled    = true,
    BoxId      = nil,     -- ⚠️ ЗАПОЛНИ: id Halloween-кейса, напр. "HalloweenBox26"
    Currency   = "Key",   -- что передаём в OpenCrate как валюту ключа
    OpenDelay  = 3,       -- пауза после успешного открытия
    RetryDelay = 10,      -- пауза между попытками, если ключа ещё нет
}

-- ══════════ 📦 СТАРЫЙ ОПЕННЕР (обычные боксы за Coins/Gems) ══════════
local LEGACY_CRATES = {
    Enabled    = true,      -- ✅ оставлен включённым (твоё решение)
    Boxes      = { "KnifeBox1", "KnifeBox2", "KnifeBox3", "KnifeBox4",
                   "KnifeBox5", "GunBox1", "GunBox3" },
    Currencies = { "Coins", "Gems" },  -- 🔒 "Key" УБРАН: ключи теперь идут
                                       -- только в Halloween Box
}

-- ================= 🔒 CURRENCY GUARD =================
-- Конфеты НЕЛЬЗЯ тратить на кейсы — только на тиры.
local FORBIDDEN_CRATE_CURRENCY = {
    Candy = true, Candies = true, CandyCorn = true, EventCandy = true,
    PurpleCandy = true, HalloweenCandy = true, Candy2026 = true,
}

-- ================= 🔄 СОСТОЯНИЕ =================
local isReconnecting  = false
local isRespawning    = false
local currentTween    = nil
local isMoving        = false
local isRoundActive   = false
local keyNudge        = false      -- сигнал «попробуй открыть ключ прямо сейчас»
local lastKnownTier   = nil
local candyLabelCache = nil
local tierLabelCache  = nil

-- ================= 🔌 РЕКОННЕКТ (FIX #1: без лишних телепортов) =================
local function forceReconnect(reason)
    if isReconnecting then return end
    isReconnecting = true
    print("🔌 Reconnecting: " .. tostring(reason))
    task.spawn(function()
        task.wait(SETTINGS.ReconnectDelay)
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end)
    -- Ждём фактического ухода с сервера (телепорт сам убьёт скрипт)
    while true do
        task.wait(1)
        if not LocalPlayer or not LocalPlayer.Parent then break end
    end
end

GuiService.ErrorMessageChanged:Connect(function(msg)
    if msg and msg ~= "" then forceReconnect("Error: " .. msg) end
end)

Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then forceReconnect("PlayerRemoving") end
end)

-- ✅ FIX #1: раньше Started тоже дёргал forceReconnect → каждый нормальный
-- телепорт порождал лишний Teleport. Реагируем только на Failed.
LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Failed then
        forceReconnect("OnTeleport: Failed")
    end
end)

local consecutiveFailures = 0
RunService.Heartbeat:Connect(function()
    if not LocalPlayer or not LocalPlayer.Parent then
        consecutiveFailures = consecutiveFailures + 1
        if consecutiveFailures >= 3 and not isReconnecting then
            forceReconnect("Heartbeat: LocalPlayer потерян")
        end
    else
        consecutiveFailures = 0
    end
end)

-- ================= 🖱️ ВЫБОР УСТРОЙСТВА (FIX #10: таймауты, без блокировки) =================
task.spawn(function()
    local pg = LocalPlayer:WaitForChild("PlayerGui", 30)
    if not pg then return end
    local gui = pg:WaitForChild("DeviceSelect", 30)
    if not gui then
        print("🖥️ [DEVICE] DeviceSelect не появился — пропускаю выбор устройства")
        return
    end
    local container = gui:WaitForChild("Container", 10)
    local phone     = container and container:WaitForChild("Phone", 10)
    local button    = phone and phone:WaitForChild("Button", 10)
    if not button then return end
    task.wait(0.5)
    local bp, bs = button.AbsolutePosition, button.AbsoluteSize
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(bp.X + bs.X / 2, bp.Y + bs.Y / 2, 0, true,  game, 1)
        task.wait(0.15)
        VirtualInputManager:SendMouseButtonEvent(bp.X + bs.X / 2, bp.Y + bs.Y / 2, 0, false, game, 1)
    end)
    print("🖥️ [DEVICE] Phone выбран")
end)

-- ================= 🛠️ УТИЛИТЫ =================
-- ✅ FIX #3: "17,400" → 17400 (раньше tonumber брал "17")
local function parseCount(text)
    if type(text) ~= "string" or text == "" then return nil end
    local digits = text:gsub("[^%d]", "")
    if digits == "" then return nil end
    return tonumber(digits)
end

local function guiFromPath(path)
    if type(path) ~= "table" then return nil end
    local cur = LocalPlayer:FindFirstChild("PlayerGui")
    for _, name in ipairs(path) do
        if not cur then return nil end
        cur = cur:FindFirstChild(name)
    end
    return cur
end

local function labelToNumber(label)
    if label and label:IsA("TextLabel") and label.Visible then
        return parseCount(label.Text)
    end
    return nil
end

-- Мешок монет (путь как в v1, но с исправленным парсингом)
local function getBagCoins()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return 0 end
    local function sf(p, n) return p and p:FindFirstChild(n) end
    local obj = sf(sf(sf(sf(sf(sf(sf(sf(
        playerGui, "MainGUI"), "Lobby"), "Dock"), "CoinBags"),
        "Container"), "Coin"), "CurrencyFrame"), "Icon")
    if not obj then return 0 end
    obj = obj:FindFirstChild("Coins")
    if not obj or not obj:IsA("TextLabel") then return 0 end
    return parseCount(obj.Text) or 0
end

-- Баланс конфет: явный путь из конфига → кэш → автопоиск по имени "candy"
local function getCandies()
    local lbl = guiFromPath(TIER_BUY.CandyGuiPath)
    if lbl then
        candyLabelCache = lbl
        return labelToNumber(lbl)
    end
    if candyLabelCache and candyLabelCache.Parent and candyLabelCache:IsA("TextLabel") then
        return labelToNumber(candyLabelCache)
    end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextLabel") then
            local n  = d.Name:lower()
            local pn = d.Parent and d.Parent.Name:lower() or ""
            -- исключаем ярлыки ЦЕНЫ (иначе можно принять 600 за баланс и слить конфеты)
            local isPrice = n:find("cost", 1, true) or n:find("price", 1, true)
                or pn:find("cost", 1, true) or pn:find("price", 1, true)
            if not isPrice and (n:find("candy", 1, true) or pn:find("candy", 1, true))
               and parseCount(d.Text) then
                candyLabelCache = d
                print("🍬 [CANDY] Счётчик конфет найден автоматически: " .. d:GetFullName())
                print("🍬 [CANDY] ⚠️ Проверь, что это именно БАЛАНС, а не цена тира! Если нет — задай TIER_BUY.CandyGuiPath вручную.")
                return parseCount(d.Text)
            end
        end
    end
    return nil
end

-- "Your Tier: 7/30" → 7, 30
local function parseTierText(txt)
    if type(txt) ~= "string" then return nil end
    local a, b = txt:match("[Tt]ier%s*:?%s*(%d+)%s*/%s*(%d+)")
    if a then return tonumber(a), tonumber(b) end
    return nil
end

local function getCurrentTier()
    local lbl = guiFromPath(TIER_BUY.TierGuiPath)
    if lbl and lbl:IsA("TextLabel") then
        tierLabelCache = lbl
        local a, b = parseTierText(lbl.Text)
        if not a then a = parseCount(lbl.Text) end
        return a, b
    end
    if tierLabelCache and tierLabelCache.Parent and tierLabelCache:IsA("TextLabel") then
        local a, b = parseTierText(tierLabelCache.Text)
        if not a then a = parseCount(tierLabelCache.Text) end
        return a, b
    end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextLabel") and d.Visible then
            local a, b = parseTierText(d.Text)
            if a then
                tierLabelCache = d
                print("🎃 [TIER] Метка тира найдена автоматически: " .. d:GetFullName())
                return a, b
            end
        end
    end
    return nil
end

-- ================= 🔍 SCOUT: дамп данных для конфига =================
local function runScout()
    print("════════════ 🔍 SCOUT DUMP — скопируй и пришли этот вывод целиком ════════════")

    print("\n--- 1) Дерево ReplicatedStorage.Remotes ---")
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local function walkTree(obj, indent, depth)
        if depth > 4 then return end
        for _, c in ipairs(obj:GetChildren()) do
            print(indent .. c.Name .. " (" .. c.ClassName .. ")")
            walkTree(c, indent .. "    ", depth + 1)
        end
    end
    if remotes then
        walkTree(remotes, "  ", 0)
    else
        print("  ReplicatedStorage.Remotes НЕ найден! Дети ReplicatedStorage:")
        for _, c in ipairs(ReplicatedStorage:GetChildren()) do
            print("  " .. c.Name .. " (" .. c.ClassName .. ")")
        end
    end

    print("\n--- 2) PlayerGui: всё с event/halloween/candy/tier/pass/buy ---")
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        local function walkGui(obj, path, depth)
            if depth > 7 then return end
            for _, c in ipairs(obj:GetChildren()) do
                local p = path .. "." .. c.Name
                local text = c:IsA("TextLabel") and (c.Text or "") or ""
                local ln = (c.Name .. " " .. text):lower()
                if ln:find("event", 1, true) or ln:find("halloween", 1, true)
                   or ln:find("candy", 1, true) or ln:find("tier", 1, true)
                   or ln:find("pass", 1, true) or ln:find("buy", 1, true) then
                    local extra = c:IsA("TextLabel") and ("  Text='" .. tostring(c.Text) .. "'") or ""
                    print("  " .. p .. " (" .. c.ClassName .. ")" .. extra)
                end
                walkGui(c, p, depth + 1)
            end
        end
        walkGui(pg, "PlayerGui", 0)
    else
        print("  PlayerGui не найден")
    end

    print("\n--- 3) Workspace: карта и контейнеры сборных объектов ---")
    for _, obj in ipairs(workspace:GetChildren()) do
        local cc = obj:FindFirstChild("CoinContainer")
        if cc then
            print("  КАРТА: " .. obj.Name)
            local counts = {}
            for _, p in ipairs(cc:GetChildren()) do
                counts[p.Name] = (counts[p.Name] or 0) + 1
            end
            for n, cnt in pairs(counts) do
                print("    CoinContainer → " .. n .. " x" .. cnt)
            end
        end
    end

    print("\n--- 4) Кандидаты-ремоуты на покупку тира (весь ReplicatedStorage) ---")
    local function scanRemotes(obj, path, depth)
        if depth > 4 then return end
        for _, c in ipairs(obj:GetChildren()) do
            local ln = c.Name:lower()
            if (c:IsA("RemoteEvent") or c:IsA("RemoteFunction")) and
               (ln:find("tier", 1, true) or ln:find("pass", 1, true) or
                ln:find("candy", 1, true) or ln:find("event", 1, true) or
                ln:find("buy", 1, true) or ln:find("halloween", 1, true)) then
                print("  " .. path .. "." .. c.Name .. " (" .. c.ClassName .. ")")
            end
            scanRemotes(c, path .. "." .. c.Name, depth + 1)
        end
    end
    scanRemotes(ReplicatedStorage, "ReplicatedStorage", 0)

    print("\n════════════ КОНЕЦ SCOUT DUMP ════════════")
end

if SETTINGS.SCOUT_ONLY then
    print("🔍 SCOUT MODE: через 5 сек выведу дамп. Фарм/покупки отключены.")
    task.delay(5, runScout)
    return
end

-- ================= 🚫 NOCLIP ULTIMATE + АНТИГРАВИТАЦИЯ (FIX #2, #7, #11) =================
local noclipActive   = false
local noclipChar     = nil   -- персонаж, к которому применён полный noclip-пак
local lastFullApply  = 0
local antiGravForce  = nil

local HUMANOID_STATES_OFF = {
    Enum.HumanoidStateType.GettingUp, Enum.HumanoidStateType.FallingDown,
    Enum.HumanoidStateType.Ragdoll,   Enum.HumanoidStateType.Freefall,
    Enum.HumanoidStateType.Jumping,   Enum.HumanoidStateType.Landed,
    Enum.HumanoidStateType.Running,   Enum.HumanoidStateType.RunningNoPhysics,
    Enum.HumanoidStateType.Seated,    Enum.HumanoidStateType.Swimming,
}

-- ✅ FIX #2: раньше после респавна глобальная ссылка указывала на Destroy-инстанс,
-- условие "if not antiGravForce" было ложно и антигравитация никогда не
-- пересоздавалась. Теперь проверяем живучесть и родителя.
local function ensureAntiGravity(hrp)
    local alive = antiGravForce
        and antiGravForce.Parent ~= nil
        and antiGravForce.Parent == hrp
        and antiGravForce.Attachment0 ~= nil
        and antiGravForce.Attachment0.Parent ~= nil
    if alive then return antiGravForce end
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
    vf.Force = Vector3.new(0, hrp.AssemblyMass * 196.2, 0)
    vf.RelativeTo = Enum.ActuatorRelativeTo.World
    vf.ApplyAtCenterOfMass = true
    vf.Parent = hrp
    antiGravForce = vf
    return vf
end

local function removeAntiGravity()
    if antiGravForce then
        pcall(function() antiGravForce:Destroy() end)
        antiGravForce = nil
    end
end

local function applyNoClipPack(character)
    pcall(function()
        PhysicsService:RegisterCollisionGroup("UltimateNC")
        PhysicsService:CollisionGroupSetCollidable("UltimateNC", "Default", false)
    end)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = true
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
        for _, state in ipairs(HUMANOID_STATES_OFF) do
            pcall(function() hum:SetStateEnabled(state, false) end)
        end
    end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.Massless = true
            pcall(function() part.CollisionGroup = "UltimateNC" end)
        end
    end
end

local function enableNoClip()
    if noclipActive then return end
    noclipActive = true
    noclipChar = nil        -- форсируем полный пакет на следующем тике
    lastFullApply = 0
end

local function disableNoClip()
    if not noclipActive then return end
    noclipActive = false
    noclipChar = nil
    if currentTween then pcall(function() currentTween:Cancel() end); currentTween = nil end
    isMoving = false
    removeAntiGravity()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        for _, state in ipairs(HUMANOID_STATES_OFF) do
            pcall(function() hum:SetStateEnabled(state, true) end)
        end
    end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            -- ✅ FIX: аксессуарам возвращаем CanCollide=false, а не true
            local parent = part.Parent
            if parent and parent:IsA("Accessory") then
                part.CanCollide = false
            else
                part.CanCollide = true
            end
            part.Massless = false
            pcall(function() part.CollisionGroup = "Default" end)
        end
    end
end

-- ✅ FIX #11: полный пакет применяем при смене персонажа и далее раз в 0.5с
-- (раньше ChangeState + обход всех descendants шли КАЖДЫЙ кадр)
RunService.Heartbeat:Connect(function()
    if not noclipActive then return end
    local char = LocalPlayer.Character
    if not char then return end
    local now = os.clock()
    if noclipChar ~= char or (now - lastFullApply) > 0.5 then
        noclipChar = char
        lastFullApply = now
        pcall(applyNoClipPack, char)
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local vf = ensureAntiGravity(hrp)
        if vf then
            pcall(function()
                vf.Force = Vector3.new(0, hrp.AssemblyMass * 196.2, 0)
            end)
        end
    end
end)

-- ================= 📡 ОБНАРУЖЕНИЕ РАУНДА =================
local function setupRoundDetection()
    local remotes    = ReplicatedStorage:FindFirstChild("Remotes")
    local gameplay   = remotes and remotes:FindFirstChild("Gameplay")
    local roundStart = gameplay and gameplay:FindFirstChild("RoundStart")
    if roundStart and roundStart:IsA("RemoteEvent") then
        roundStart.OnClientEvent:Connect(function()
            isRoundActive = true
            enableNoClip()
        end)
        print("📡 [ROUND] RoundStart подключён")
    else
        print("📡 [ROUND] RoundStart не найден — fallback через 3 сек")
        task.delay(3, function()
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                isRoundActive = true
                enableNoClip()
            end
        end)
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    -- ✅ FIX #7: Died вешаем СРАЗУ (раньше через wait(1) — смерть в первую
    -- секунду пропускалась). isRoundActive сбрасываем только по факту смерти.
    disableNoClip()
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        hum.Died:Connect(function()
            isRoundActive = false
            disableNoClip()
        end)
    end
    -- ✅ FIX #7b: после респавна ноклип включаем с гарантией (раньше была
    -- гонка: CharacterAdded.disableNoClip vs forceRespawn.enableNoClip)
    task.spawn(function()
        if char:WaitForChild("HumanoidRootPart", 10) then
            task.wait(0.5)
            enableNoClip()
        end
    end)
end)

-- ================= 🛠️ ФАРМ-УТИЛИТЫ =================
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function findMap()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:FindFirstChild("CoinContainer") then return obj end
    end
    return nil
end

-- 🪙 Игнор монет
local MAX_IGNORED = 10
local IGNORE_DUR  = 3.0
local collectedCoins = {}
local coinCounter    = 0
local lastTarget     = nil

local function isCollected(coin)
    local now = os.clock()
    for _, d in ipairs(collectedCoins) do
        if d.coin == coin and now < d.time + IGNORE_DUR then return true end
    end
    return false
end

local function markCollected(coin)
    table.insert(collectedCoins, { coin = coin, time = os.clock() })
    if #collectedCoins > MAX_IGNORED then table.remove(collectedCoins, 1) end
end

-- Конфеты = те же монеты (твоё решение), но фильтр имён расширен на всякий случай
local PICKUP_NAME_HINTS = { "coin", "candy", "pickup", "drop", "gift" }

local function isPickupName(name)
    local n = name:lower()
    for _, h in ipairs(PICKUP_NAME_HINTS) do
        if n:find(h, 1, true) then return true end
    end
    return false
end

local function getNearestPickup(map, hrp)
    if not map or not hrp then return nil, math.huge end
    local container = map:FindFirstChild("CoinContainer")
    if not container then return nil, math.huge end
    local target, minDist = nil, math.huge
    for _, part in ipairs(container:GetChildren()) do
        if part:IsA("BasePart") and isPickupName(part.Name) and not isCollected(part) then
            local dist = (part.Position - hrp.Position).Magnitude
            if dist < minDist then
                minDist = dist
                target = part
            end
        end
    end
    return target, minDist
end

local function tweenToTarget(hrp, targetPos)
    if currentTween then pcall(function() currentTween:Cancel() end) end
    local dist = (targetPos - hrp.Position).Magnitude
    local moveTime = math.max(dist / SETTINGS.MoveSpeed, 0.1)
    currentTween = TweenService:Create(
        hrp,
        TweenInfo.new(moveTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = CFrame.new(targetPos) }
    )
    isMoving = true
    currentTween.Completed:Connect(function()
        isMoving = false
        currentTween = nil
    end)
    currentTween:Play()
end

-- ================= 💀 РЕСПАВН =================
local function forceRespawn()
    if isRespawning then
        print("💀 [RESPAWN] Уже идёт...")
        return
    end
    isRespawning = true
    print("💀 [RESPAWN] Запуск...")

    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum then
        warn("❌ [RESPAWN] Нет персонажа/Humanoid")
        isRespawning = false
        return
    end

    if currentTween then pcall(function() currentTween:Cancel() end); currentTween = nil end
    isMoving = false

    print("💀 [RESPAWN] ChangeState(Dead) + Health=0")
    pcall(function()
        hum:ChangeState(Enum.HumanoidStateType.Dead)
        hum.Health = 0
    end)

    print("⏳ [RESPAWN] Ожидание " .. SETTINGS.SpawnWaitTime .. " сек...")
    task.wait(SETTINGS.SpawnWaitTime)

    local newChar = LocalPlayer.Character
    if newChar and newChar ~= char then
        print("✅ [RESPAWN] Новый персонаж появился")
        if newChar:WaitForChild("HumanoidRootPart", 5) then
            enableNoClip()
        end
    else
        print("⚠️ [RESPAWN] Персонаж не сменился, пробую Destroy...")
        pcall(function() char:Destroy() end)
        task.wait(2)
        local retryChar = LocalPlayer.Character
        if retryChar and retryChar:WaitForChild("HumanoidRootPart", 5) then
            enableNoClip()
        end
    end

    isRespawning = false
    print("✅ [RESPAWN] Завершён")
end

-- ================= 📦 КЕЙСЫ: ЯДРО + CURRENCY GUARD (FIX #4) =================
-- Ремоуты берём лениво через FindFirstChild: отсутствие Remotes.Shop больше
-- НЕ вешает весь скрипт (раньше WaitForChild на верхнем уровне убивал загрузку)
local function getShopRemote(name)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local shop    = remotes and remotes:FindFirstChild("Shop")
    return shop and shop:FindFirstChild(name) or nil
end

local warnedNoOpenCrate = false
local function openCrateGuarded(boxId, currency)
    if not boxId or not currency then return false end

    -- 🔒 ГЛАВНЫЙ ЗАПРЕТ: конфеты — только на тиры, никогда на кейсы
    if FORBIDDEN_CRATE_CURRENCY[currency] then
        warn("🔒 [GUARD] Валюта '" .. tostring(currency) .. "' запрещена для кейсов! Конфеты идут только на тиры.")
        return false
    end

    local openCrate = getShopRemote("OpenCrate")
    if not openCrate then
        if not warnedNoOpenCrate then
            warnedNoOpenCrate = true
            warn("📦 [CRATE] OpenCrate не найден в ReplicatedStorage.Remotes.Shop (предупреждаю один раз)")
        end
        return false
    end

    local ok, result = pcall(function()
        return openCrate:InvokeServer(boxId, "MysteryBox", currency)
    end)

    if ok and result then
        local boxCtrl = getShopRemote("BoxController")
        if boxCtrl then
            pcall(function()
                boxCtrl:Fire({ { MysteryBoxId = boxId, RewardedItemId = result } })
            end)
        end
        print("✅ [CRATE] " .. tostring(boxId) .. " | " .. tostring(currency) .. " | выпало: " .. tostring(result))
        return true
    end
    return false
end

-- ================= 🎃 AUTO TIER BUY (по 1 с проверкой) =================
local TIER_ACTION_HINTS = { "buytier", "purchasetier", "buy", "purchase", "claim", "unlock", "rankup" }
local TIER_SCOPE_HINTS  = { "tier", "pass", "event", "halloween", "candy", "battlepass", "season" }

local function scanTierRemotes()
    local found = {}
    local function scan(obj, depth)
        if depth > 5 then return end
        for _, c in ipairs(obj:GetChildren()) do
            if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") then
                local n = c.Name:lower()
                local action, scope = false, false
                for _, h in ipairs(TIER_ACTION_HINTS) do
                    if n:find(h, 1, true) then action = true; break end
                end
                for _, h in ipairs(TIER_SCOPE_HINTS) do
                    if n:find(h, 1, true) then scope = true; break end
                end
                if action and scope then table.insert(found, c) end
            end
            scan(c, depth + 1)
        end
    end
    scan(ReplicatedStorage, 0)
    return found
end

local function resolveTierRemote()
    if TIER_BUY.RemotePath then
        local obj = ReplicatedStorage
        for _, name in ipairs(TIER_BUY.RemotePath) do
            obj = obj and obj:FindFirstChild(name)
        end
        if obj and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
            return obj
        end
        warn("🎃 [TIER] TIER_BUY.RemotePath задан, но не найден — включаю автопоиск")
    end
    local cands = scanTierRemotes()
    if #cands == 1 then
        print("🎃 [TIER] Ремоут покупки найден (автопоиск): " .. cands[1]:GetFullName())
        return cands[1]
    end
    if #cands > 1 then
        warn("🎃 [TIER] Найдено НЕСКОЛЬКО кандидатов — укажи точный путь в TIER_BUY.RemotePath:")
        for _, r in ipairs(cands) do warn("    ? " .. r:GetFullName()) end
    end
    return nil
end

local function invokeBuy(remote, args)
    if remote:IsA("RemoteFunction") then
        local ok, res = pcall(function()
            return remote:InvokeServer(unpack(args, 1, #args))
        end)
        return ok, res
    else
        local ok, res = pcall(function()
            remote:FireServer(unpack(args, 1, #args))
            return true
        end)
        return ok, res
    end
end

task.spawn(function()
    if not TIER_BUY.Enabled then return end
    task.wait(8) -- прогрузка GUI и ремоутов

    local remote = resolveTierRemote()
    if not remote then
        warn("🎃 [TIER] Ремоут покупки тиров НЕ найден → покупка отключена (конфеты в безопасности).")
        warn("🎃 [TIER] Запусти скрипт с SETTINGS.SCOUT_ONLY = true, пришли мне дамп — впишем RemotePath.")
        return
    end

    local maxTier    = TIER_BUY.MaxTier
    local amount     = math.max(1, TIER_BUY.BuyAmount or 1)
    local failStreak = 0
    local patternIdx = 1

    print(("🎃 [TIER] Байер запущен: цель %d тиров, покупка по %d, цена %d конфет/тир"):format(maxTier, amount, TIER_BUY.PricePerTier))

    while SETTINGS.Enabled do
        local tier, tierMax = getCurrentTier()
        if tierMax then maxTier = math.min(maxTier, tierMax) end
        if tier and tierMax and tier > tierMax then
            tier = nil -- мусорный парсинг (в метке не тир)
        end
        if tier then
            lastKnownTier = tier
        else
            tier = lastKnownTier
        end

        if tier and tier >= maxTier then
            print(("🎃 [TIER] Все %d тиров куплены — байер завершён ✅"):format(maxTier))
            break
        end

        local need  = TIER_BUY.PricePerTier * amount
        local candy = getCandies()

        if not candy then
            -- Баланс неизвестен → слепо тратить НЕЛЬЗЯ (защита конфет)
            warn("🎃 [TIER] Баланс конфет неизвестен (CandyGuiPath не задан/не найден) — ожидаю.")
            warn("🎃 [TIER] Запусти SCOUT, найди путь счётчика и впиши в TIER_BUY.CandyGuiPath.")
            task.wait(60)
        elseif candy < need then
            -- ✅ твоё решение: ждём фарма, опрашиваем раз в WaitWhenNoCandy сек
            task.wait(TIER_BUY.WaitWhenNoCandy)
        else
            -- Аргументы-кандидаты: скрипт сам найдёт рабочий вариант и залочится на нём
            local patterns = {
                function(t) return { amount } end,         -- BuyTier(кол-во)
                function(t) return { 1 } end,              -- BuyTier(1)
                function(t) return { (t or 0) + 1 } end,   -- BuyTier(индексТира)
                function(t) return { amount, false } end,  -- BuyTier(кол-во, флаг)
                function(t) return { "Tier", amount } end, -- BuyTier("Tier", кол-во)
            }
            local pat  = patterns[patternIdx]
            local args = pat and pat(tier) or { amount }

            print(("🎃 [TIER] Покупаю тир... конфет: %d (шаблон аргументов #%d)"):format(candy, patternIdx))
            local ok, res = invokeBuy(remote, args)

            if not ok then
                warn("🎃 [TIER] Ошибка вызова: " .. tostring(res))
                failStreak = failStreak + 1
                patternIdx = patternIdx + 1
                if patternIdx > #patterns then patternIdx = 1 end
            elseif res == false then
                -- сервер явно отказал (вернул false) — шаблон неверный
                warn("🎃 [TIER] Сервер вернул false — покупка не принята, меняю шаблон аргументов")
                failStreak = failStreak + 1
                patternIdx = patternIdx + 1
                if patternIdx > #patterns then patternIdx = 1 end
            else
                task.wait(1.5) -- ждём обновления GUI
                local newTier = getCurrentTier() or lastKnownTier
                if TIER_BUY.VerifyAfterBuy and tier and newTier and newTier <= tier then
                    warn(("🎃 [TIER] Тир не вырос (%s → %s) — шаблон аргументов неверен"):format(tostring(tier), tostring(newTier)))
                    failStreak = failStreak + 1
                    patternIdx = patternIdx + 1
                    if patternIdx > #patterns then patternIdx = 1 end
                else
                    print(("🎃 [TIER] Успех! Тир: %s → %s | ответ сервера: %s"):format(tostring(tier), tostring(newTier), tostring(res)))
                    failStreak = 0
                    keyNudge = true -- возможно выпал ключ → опеннер подхватит сразу
                end
            end

            if failStreak >= TIER_BUY.MaxFails then
                warn("🎃 [TIER] " .. failStreak .. " неудач подряд — байер ОСТАНОВЛЕН (защита конфет).")
                warn("🎃 [TIER] Сними аргументы RemoteSpy'ем при ручной покупке 1 тира и пришли мне.")
                break
            end

            task.wait(1)
        end
    end
end)

-- ================= 🗝️ AUTO KEY OPEN (сразу после тира) =================
task.spawn(function()
    if not KEY_OPEN.Enabled then return end
    task.wait(6)

    if not KEY_OPEN.BoxId then
        warn("🗝️ [KEY] KEY_OPEN.BoxId не задан → авто-открытие ключей выключено.")
        warn("🗝️ [KEY] Узнай id Halloween-кейса (SCOUT/шоп) и впиши его в KEY_OPEN.BoxId.")
        return
    end

    print("🗝️ [KEY] Опеннер запущен: " .. KEY_OPEN.BoxId .. " за " .. KEY_OPEN.Currency)
    while SETTINGS.Enabled do
        local ok = openCrateGuarded(KEY_OPEN.BoxId, KEY_OPEN.Currency)
        if ok then
            task.wait(KEY_OPEN.OpenDelay)
        else
            -- «проверка по факту»: ключа нет → сервер откажет → ждём.
            -- Если байер тира дёрнул keyNudge — просыпаемся сразу.
            local t = 0
            while t < KEY_OPEN.RetryDelay and not keyNudge and SETTINGS.Enabled do
                task.wait(0.5)
                t = t + 0.5
            end
            keyNudge = false
        end
    end
end)

-- ================= 📦 LEGACY CRATES (обычные боксы за Coins/Gems) =================
task.spawn(function()
    if not LEGACY_CRATES.Enabled then return end
    print("📦 [LEGACY] Старый опеннер активен: обычные боксы за Coins/Gems")
    while SETTINGS.Enabled do
        local done = false
        for _, boxId in ipairs(LEGACY_CRATES.Boxes) do
            for _, cur in ipairs(LEGACY_CRATES.Currencies) do
                if openCrateGuarded(boxId, cur) then
                    done = true
                    break
                end
            end
            if done then break end
        end
        -- при полном фиаско ждём дольше: 14 неудачных InvokeServer за 5 сек —
        -- лишний спам на сервер и риск анти-чита
        task.wait(done and 2.5 or 10)
    end
end)

-- ================= 🛡️ ANTI-AFK =================
task.spawn(function()
    while task.wait(120) do
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(math.random(100, 800), math.random(100, 600)))
        end)
    end
end)

-- ================= 🚜 ГЛАВНЫЙ ЦИКЛ ФАРМА =================
setupRoundDetection()

task.spawn(function()
    print("✅ AUTO FARM + TIER BUY + KEY OPEN ACTIVE")
    print("   Speed: " .. SETTINGS.MoveSpeed .. " | YOffset: " .. SETTINGS.YOffset .. " | Лимит мешка: " .. SETTINGS.MaxBagCoins)
    print("   🎃 Тиры: " .. (TIER_BUY.Enabled and ("до " .. TIER_BUY.MaxTier) or "выкл") ..
          " | 🗝️ Ключи: " .. (KEY_OPEN.Enabled and "вкл" or "выкл") ..
          " | 📦 Обычные кейсы: " .. (LEGACY_CRATES.Enabled and "вкл" or "выкл"))
    print("   🔒 Конфеты только на тиры (GUARD активен)")

    -- ✅ FIX #6: шаг вынесен в отдельную функцию, ошибки ПЕЧАТАЮТСЯ, а не глотаются
    local function farmStep()
        if not isRoundActive then task.wait(1); return end

        local hrp = getHRP()
        if not hrp then task.wait(1); return end

        -- Падение под карту → подъём
        if hrp.Position.Y < -50 then
            if currentTween then pcall(function() currentTween:Cancel() end); currentTween = nil end
            isMoving = false
            hrp.CFrame = CFrame.new(hrp.Position.X, 50, hrp.Position.Z)
            task.wait(2)
            return
        end

        -- Мешок полон (лимит 50) → респавн
        -- ✅ FIX #9: forceRespawn сам ждёт SpawnWaitTime — двойного ожидания больше нет
        local bag = getBagCoins()
        if bag >= SETTINGS.MaxBagCoins then
            print("🪙 [FARM] МЕШОК ПОЛНЫЙ: " .. bag .. "/" .. SETTINGS.MaxBagCoins)
            if currentTween then pcall(function() currentTween:Cancel() end); currentTween = nil end
            isMoving = false
            if SETTINGS.AutoRespawn and not isRespawning then
                forceRespawn()
            end
            return
        end

        local map = findMap()
        if not map then task.wait(SETTINGS.LoopDelay); return end

        local coin, dist = getNearestPickup(map, hrp)
        if not coin then
            lastTarget = nil
            task.wait(SETTINGS.LoopDelay)
            return
        end

        local targetPos = Vector3.new(
            coin.Position.X,
            coin.Position.Y + SETTINGS.YOffset,
            coin.Position.Z
        )

        if dist <= SETTINGS.CollectionRadius then
            -- ✅ FIX: раньше монета в радиусе помечалась собранной БЕЗ фактического
            -- подбора (монета оставалась висеть). Теперь: 1) летим вплотную,
            -- 2) если после прилёта монета всё ещё рядом — помечаем и идём дальше.
            if lastTarget ~= coin then
                lastTarget = coin
                tweenToTarget(hrp, targetPos)
            elseif not isMoving then
                markCollected(coin)
                coinCounter = coinCounter + 1
                lastTarget = nil
                if coinCounter % 10 == 0 then
                    print(("💰 [FARM] Собрано: %d | Мешок: %d/%d"):format(coinCounter, bag, SETTINGS.MaxBagCoins))
                end
            end
            return
        end

        if not isMoving or lastTarget ~= coin then
            lastTarget = coin
            tweenToTarget(hrp, targetPos)
        end
    end

    while SETTINGS.Enabled do
        local ok, err = pcall(farmStep)
        if not ok then
            warn("⚠️ [FARM] Ошибка шага: " .. tostring(err))
        end
        task.wait(SETTINGS.LoopDelay)
    end
end)

print("🚀 v2.1 загружен: фарм + тиры + ключи. Если чего-то не хватает — SCOUT_ONLY=true подскажет.")
