--═══════════════════════════════════════════════════════════════════
--  v2.9 = вход в дом ПЕРЕПИСАН. Дамп 2026-10-28 доказал: трио ремоутов
--   (дверь+Subscribe+SetLocation) персонажа НЕ двигает — физический вход
--   в дом делает КЛИЕНТ. Теперь после трио скрипт сам телепортируется
--   к точке внутри дома (мебель → данные дома → точка респавна → origin),
--   ресет-фолбэк юзера — последний рубеж. Маяки доставки (первый/последний
--   print) и компактная упаковка (без отступов/комментариев) — в силе.
--═══════════════════════════════════════════════════════════════════
print("[AdoptFarm] v2.9: ВСТАВКА ПОЛУЧЕНА, код начал исполняться")
--═══════════════════════════════════════════════════════════════════════
--  🐾 AdoptFarm v2.9 — авто-выполнение заданий (ailments) в Adopt Me
--  Экзекьютор: Delta X (Android) | PlaceId 920587237 | роли: бэби + пет
--═══════════════════════════════════════════════════════════════════════
--  БАЗА ЗНАНИЙ: пакет adopt_me_handoff_all (00_HANDOFF_README.txt) —
--  сигнатуры всех ремоутов, имена мебели, тайминги чужого скрипта.
--  При любых правках сверяться с README, аргументы не выдумывать.
--
--  ★★★ НОВОЕ В v2.9 (по фидбэку после v2.4) ★★★
--  1) ВОЗВРАТ/ЗАХОД В ДОМ С ПОДТВЕРЖДЕНИЕМ: SetLocation мог молча не
--     сработать — выглядело как «скрипт не может телепортироваться в
--     дом». Теперь каждая смена локации подтверждается фактическим
--     прыжком позиции персонажа; молчание → один автоматический повтор.
--  2) ПЕТ ЕСТ/ПЬЁТ ТОЛЬКО ИЗ МИСКИ: убран фолбэк на тулзу — тулзой ест
--     ДЕРЖАТЕЛЬ (бэби!), поэтому выглядело как «скрипт решил, что пить
--     хочет бэби, а не пет», и «не может покормить пета бутылкой».
--     Нет миски → честный скип с подсказкой в статусе/HUD.
--  3) WALK: с петом на руках теперь РЕАЛЬНО гуляем (клиентский
--     Humanoid:MoveTo по точкам вокруг, без ремоутов) — раньше стоял
--     на месте все 31с.
--  4) ПЛЯЖНАЯ ВЕЧЕРИНКА (beach_party) и ПИЦЦЕРИЯ (pizza_party):
--     аилменты теперь выполняются поездками. Точный id локации пляжа в
--     хэндоффе НЕ засниффан (чужой скрипт его не выполнял) — НЕ выдумываем:
--     пробуем кандидатов (Beach/BeachParty/Beach2024) по эталонному
--     шаблону дверь+SetLocation, телепорт подтверждаем прыжком позиции;
--     запасной план — MainMap!Beach. Пиццерия — PizzaShop (есть в логе).
--  5) АНТИПРОВАЛ ПОД КАРТУ ПЕРЕПИСАН: в v2.4 «пик» высоты замерялся
--     через 0.4с после смены локации, когда персонаж УЖЕ падал — пик
--     оказывался под картой и «спасение» поднимало всего на 12 стадов
--     (школа: «тепнулся слишком низко, улетел под карту»). Теперь точка
--     прибытия ловится по телепорт-прыжку, и пока под ногами НЕТ пола
--     (стриминг), персонаж приклеен к точке прибытия; пол появился —
--     отпустили, доземливается сам.
--
--  ★★★ НОВОЕ В v2.4 (по фидбэку после v2.3) ★★★
--  1) КОРМЛЕНИЕ/ПОИТЬ БЭБИ: тулза для hungry/thirsty выбирается по
--     БЕЛОМУ СПИСКУ съедобных из handoff [4]/[7] (apple, water и пр.,
--     сверяем kind/id, приманки-наживки отфильтрованы) — «приманка»
--     больше не надевается; если съедобного нет — докупаем apple/water
--     (ShopAPI/BuyItem), как эталонный фермер.
--  2) АНТИПРОВАЛ ПОД КАРТУ: после смены локации (кемпинг/школа/больница/
--     дом) 8с следим за высотой персонажа; карта не прогрузилась и он
--     провалился — поднимаем на точку прибытия (до 5 спасений).
--     Резкий скачок Y (сама телепортация игры) переякоривает пик.
--  3) ВЫХОД ИЗ КРОВАТИ/МЕБЕЛИ БЫСТРЕЕ: вместе с каждым ExitSeatStates
--     локально снимаем сиденье (Sit=false + Jump), пауза между попытками
--     0.6с → 0.4с.
--
--  ★★★ ИСПРАВЛЕНО В v2.2 — «СКРИПТ ВООБЩЕ НЕ ЗАПУСКАЕТСЯ» ★★★
--  Причина: флаг _G.ADOPTFARM_ACTIVE ставился в самом начале загрузки
--  и сбрасывался ТОЛЬКО по кнопке СТОП или при ошибке внутри pcall(boot).
--  Если прошлый запуск (ещё со времён v2.0) падал где-то в потоках — флаг
--  оставался true навсегда, и ВСЕ следующие запуски молча выходили на
--  проверке флага: warn об этом виден только в консоли F9, со стороны
--  это выглядит как «вообще не запускается».
--  Что сделано:
--    1) УМНЫЙ ГАРД: если флаг стоит, но плашки AdoptFarmHUD нет ни в
--       CoreGui, ни в PlayerGui — флаг считается мусором от сбойного
--       запуска, сбрасывается, скрипт СТАРТУЕТ;
--    2) если плашка живая (скрипт реально работает) — теперь при повторном
--       запуске видно Roblox-УВЕДОМЛЕНИЕ «уже запущен», а не только warn в F9;
--    3) подключение каждого события защищено pcall — битый ремоут больше
--       не убивает поток загрузки ДО основного цикла (раньше это выглядело
--       как «загрузился, но молчит»);
--    4) весь подготовительный этап (самотест ремоутов, initState,
--       калибровка) тоже под pcall;
--    5) breadcrumbs в F9 на каждом этапе загрузки — при любой проблеме
--       в консоли видно, ГДЕ именно она произошла.
--
--  ЧТО ИЗМЕНИЛОСЬ В v2.1 (фиксы аудита v2.0 + сверка с логом сессии-3):
--
--  ★ ГЛАВНОЕ: БЭБИ БОЛЬШЕ НЕ ЗАСТРЁВАЕТ В КРОВАТИ/ДУШЕ/ТУАЛЕТЕ.
--    Из лога 04 видно: пета сервер вынимает из мебели САМ (occupied={}
--    приходит сразу после PetAilmentCompleted), а БЭБИ — НЕТ: мебель
--    освобождается только после AdoptAPI/ExitSeatStates, причём чужой
--    скрипт зовёт его СРАЗУ после события выполнения и ПОВТОРНО через
--    ~1с (лог 04:28:44 → 04:28:45 → 04:28:46). В v2.0 был ОДИН вызов
--    после медленного DataChanged — если он терялся/приходил рано,
--    бэби оставался в сиденье и больше ничего не делал. Теперь:
--      - BabyAilmentCompleted/PetAilmentCompleted мгновенно чистят кэш
--        аилментов (раньше ждали DataChanged — протухало до 90с);
--      - после каждой активации мебели ExitSeatStates шлётся НАСТОЙЧИВО:
--        до 4 раз с проверкой occupied из DataPartiallyChanged;
--      - вахдог-антизастревание: раз в 3с проверяет occupied НАШЕЙ
--        мебели: занято нами без активной задачи (или задача висит
--        дольше нормы) → принудительный выход (счётчик "вых" в плашке);
--      - ExitSeatStates шлётся и ДО телепорта (из сиденья телепорт
--        нередко блокируется), и по кнопке СТОП.
--
--  ★ ДВЕРЬ ВЫХОДА ИЗ ДОМА: "Neighborhood/MainDoor" (лог 04:27:02).
--    В v2.0 слался "MainDoor" — выход в MainMap мог не срабатывать,
--    из-за чего кемпинг мог не засчитываться.
--
--  ★ waitAilGone: "продление ожидания по прогрессу" теперь работает
--    по-настоящему (в v2.0 дедлайн был неподвижным — комментарий врал),
--    с жёстким потолком 3x таймаута, чтобы не ждать вечно.
--
--  ★ КАЛИБРОВКА: якорь — позиция МОДЕЛИ мебели (GetPivot), а не кнопки
--    (в v2.0 кандидат origin был смещён на локальный офсет кнопки
--    Seat1/UseBlock); дистанционный фильтр 120 стадов — мебель ЧУЖИХ
--    плотов больше не участвует; ORIGIN сбрасывается после 2 неудач
--    мебели подряд и ревалиднируется раз в 10 минут (в v2.0 считался
--    один раз навсегда, даже если был мусорным).
--
--  ★ ФИД: если fid части противоречит данным (cache.furn) — не верим;
--    hint-матч ("f-1" и т.п.) сверяется с данными.
--
--  ★ MYSTERY: опции ищутся и на верхнем уровне components, и внутри
--    непустых массивов-обёрток (в v2.0 scan в них не рекурсировал);
--    выбор school/camping/sick отдаётся поездкам без ложного
--    "НЕ выполнилось".
--
--  ★ ПОЕЗДКИ (sick/school/camping) возвращают честный результат и
--    скипаются на 120с при неудаче (в v2.0 — вечный пинг-понг).
--
--  ★ Прочее: matchModel без опасного фолбэка "единственная модель";
--    мёртвый код FIX_BORED удалён (bored не обрабатывается — как и у
--    чужого скрипта, ремоута нет, см. handoff [9]); телепорт проверяет
--    дистанцию ДО цели; СТОП отключает события и удаляет HUD; ошибка
--    при загрузке больше не блокирует перезапуск (pcall(boot)).
--═══════════════════════════════════════════════════════════════════════

print("[AdoptFarm] v2.9: начало загрузки (если что-то пойдёт не так — смотри F9)")

local RS      = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player  = Players.LocalPlayer
local WG      = game:GetService("Workspace")

if not player then
    warn("[AdoptFarm] LocalPlayer = nil — запускай скрипт ВНУТРИ Adopt Me")
    return
end

-- v2.2: УМНЫЙ ГАРД запуска (главный фикс «вообще не запускается»).
if _G.ADOPTFARM_ACTIVE then
    local liveHud = false
    pcall(function()
        local cg = game:GetService("CoreGui")
        if cg and cg:FindFirstChild("AdoptFarmHUD") then liveHud = true return end
        local pg = player:FindFirstChildOfClass("PlayerGui")
        if pg and pg:FindFirstChild("AdoptFarmHUD") then liveHud = true end
    end)
    if liveHud then
        -- скрипт действительно работает: сообщаем ВИДИМО, а не только в F9
        warn("[AdoptFarm] Уже запущен! Нажми СТОП у старой плашки или перезайди.")
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "AdoptFarm v2.9",
                Text  = "Скрипт УЖЕ работает: жми СТОП на старой плашке или перезайди в игру",
                Duration = 8 })
        end)
        return
    end
    print("[AdoptFarm] найден залипший флаг от сбойного запуска — сбрасываю и стартую")
    _G.ADOPTFARM_ACTIVE = false
end
_G.ADOPTFARM_ACTIVE = true
print("[AdoptFarm] v2.9: флаг получен, инициализация ремоутов...")

--────────────────────────── НАСТРОЙКИ ──────────────────────────
local CFG = {
    TELEPORT      = true,  -- телепорт к мебели перед активацией
    AUTO_BUY      = true,  -- докупать воду/яблоко, если инвентарь пуст
    DRINK_HOLD    = 1.2,   -- сек удержания между START и END
    DRINK_MAX     = 20,    -- макс. циклов еды/питья на задание
    FURN_WAIT     = 18,    -- ждать завершения мебели после активации, сек
    FURN_RETRY    = 3,     -- попыток активации одной мебели
    TRIP_WAIT     = 55,    -- ждать на локации (школа/кемпинг), сек
    RIDE_TIME     = 33,    -- катание на струллере (ride), сек
    WALK_TIME     = 31,    -- носить пета на руках (walk), сек
    LOOP_DELAY    = 1.5,   -- пауза основного цикла
    SKIP_TIME     = 120,   -- сек паузы задания, которое не выполнилось
    COLLECT_EVERY = 240,   -- раз в N сек забирать зарплату
    CAMP_LOCATION = "Halloween", -- ивентовая локация кемпинга (из лога)
    CAL_TOLERANCE = 5,     -- допуск кластера калибровки, стадов
    CAL_MAX_DIST  = 120,   -- дальше этого ЯКОРИ не берём (чужие плоты)
    RESOLVE_MAX_DIST = 200, -- дальше этой мебели не активируем
    ENTER_COOLDOWN= 45,    -- мин. пауза между авто-заходами домой, сек
    ORIGIN_REVAL  = 600,   -- ревалидация origin раз в N сек
    WATCHDOG_EVERY= 3,     -- период вахдога антизастревания, сек
    STAB_TIME     = 8,     -- антипровал у точки прибытия после телепорта, сек
}

--────────────────────── МЕБЕЛЬ: ИМЕНА ИЗ ДАМПА ───────────────────────
-- (handoff README, раздел [6]; имена реальные, из house_interior)
local FURN = {
    bed      = { names = { "basicbed", "bed", "normalcrib" },
                 buttons = { "Seat1", "UseBlock" }, hint = "f-1" },
    bathtub  = { names = { "cheap_pet_bathtub_tutorial", "bathtub", "pet_bathtub" },
                 buttons = { "UseBlock", "Seat1" },   hint = "f-10" },
    shower   = { names = { "modernshower", "shower" },
                 buttons = { "UseBlock", "Seat1" },   hint = "f-19" },
    bowl     = { names = { "pet_water_bowl", "water_bowl", "waterbowl" },
                 buttons = { "UseBlock" },            hint = "f-26" },
    foodbowl = { names = { "pet_food_bowl", "food_bowl", "foodbowl" },
                 buttons = { "UseBlock" },            hint = "f-27" },
    toilet   = { names = { "toilet", "potty", "litter" },
                 buttons = { "Seat1", "UseBlock" },   hint = "f-29" },
}

-- Локальные (плот-относительные) CF мебели — фолбэк-якоря калибровки,
-- если события DataPartiallyChanged ещё не пришли.
-- ВНИМАНИЕ: это раскладка ЧУЖОГО дома из сессии-3; приоритет всегда у
-- данных (cache.furn). Ключи "почищены" через cleanName.
local HOUSE_LOCAL = {
    basicbed                  = Vector3.new(12.0, 0.0, -30.0),
    cheappetbathtubtutorial   = Vector3.new(39.5, 0.0, -8.5),
    modernshower              = Vector3.new(38.5, 0.0, -3.5),
    petwaterbowl              = Vector3.new(23.0, 0.1, -21.0),
    toilet                    = Vector3.new(39.0, 0.0, -12.5),
}

-- Больница: интерьерная койка f-14 "UseBlock" (мировой CF из лога — фолбэк)
local HOSPITAL_FID = "f-14"
local HOSPITAL_CF  = CFrame.new(-2980.2, 4012.4, 5696.0)

--────────────────────────── СЛУЖЕБНОЕ ──────────────────────────
local STOP   = false
local STATS  = { pets = 0, baby = 0, bucks = 0 }
local STATUS = "запуск..."
local cache  = { baby = {}, petAil = {}, inv = {}, furn = {} }
local lastDataT, REM_OK = 0, 0
local function setStatus(s) STATUS = tostring(s) end
local function stopRequested() return STOP end

--────────────────────── ФОРВАРДЫ (v2.1) ──────────────────────
local CONNS = {}           -- соединения OnClientEvent (чистим по СТОП)
local ACTIVE_USE = nil     -- активное использование мебели {fid=..., t0=...}
local RESCUES = 0          -- сколько раз вахдог вытащил из мебели
local markCompleted        -- форвард: мгновенная чистка кэша по событию
local exitSeatsRelentless  -- форвард: настойчивый выход из мебели

local function notify(title, text)
    print("[AdoptFarm] " .. tostring(title) .. ": " .. tostring(text))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = text, Duration = 5 })
    end)
end

local function isInst(v)
    local ok, t = pcall(function() return typeof(v) end)
    return ok and t == "Instance"
end

-- вызов ремоута: сам понимает RemoteEvent / RemoteFunction
local function call(r, ...)
    if not r then return nil end
    local args = table.pack(...)
    local res = table.pack(pcall(function()
        if r:IsA("RemoteFunction") then
            return r:InvokeServer(table.unpack(args, 1, args.n))
        end
        r:FireServer(table.unpack(args, 1, args.n))
        return nil
    end))
    if not res[1] then return nil end
    return table.unpack(res, 2, res.n)
end

-- v2.1: мгновенная чистка кэша по событию выполнения.
-- Паттерн из лога: BabyAilmentCompleted и DataChanged приходят В ОДНУ
-- секунду, но полагаться на DataChanged больше не будем — событие
-- выполнения само по себе авторитетный сигнал "задание закрыто".
markCompleted = function(role, kind, unique)
    if role == "baby" then
        if type(kind) == "string" then cache.baby[kind] = nil end
    else
        local p = unique and cache.petAil and cache.petAil[unique]
        if type(p) == "table" and type(kind) == "string" then p[kind] = nil end
    end
    lastDataT = os.clock()
end

--────────────────────────── РЕМОУТЫ ──────────────────────────
-- Имена ремоутов СОДЕРЖАТ слэш и лежат ПЛОСКО в RS.API (handoff [3]):
--   ReplicatedStorage.API."DataAPI/DataChanged" — ОДИН инстанс.
local REM, REMC, REMT = {}, {}, {}
local function R(path)
    local hit = REMC[path]
    if hit ~= nil then
        if hit then return hit end
        if os.clock() - (REMT[path] or 0) < 8 then return nil end -- недавний промах
    end
    local r
    local api = RS:FindFirstChild("API")
    if api then
        r = api:FindFirstChild(path)                   -- точное имя со слэшем
        if not r then r = api:FindFirstChild(path, true) end
        if not r then                                  -- запасной: папка/ребёнок
            local a, b = path:match("^(.-)/(.+)$")
            local folder = a and api:FindFirstChild(a)
            r = folder and folder:FindFirstChild(b) or nil
        end
    end
    if not r then r = RS:FindFirstChild(path, true) end
    REMC[path] = r or false
    REMT[path] = os.clock()
    REM[path:gsub("%W", "_")] = r or nil
    return r
end

local REMOTE_LIST = {
    "ToolAPI/Equip", "ToolAPI/ServerUseTool", "ToolAPI/Unequip",
    "ShopAPI/BuyItem",
    "HousingAPI/ActivateFurniture", "HousingAPI/ActivateInteriorFurniture",
    "HousingAPI/SubscribeToHouse", "HousingAPI/UnsubscribeFromHouse",
    "AdoptAPI/FocusPet", "AdoptAPI/UnfocusPet", "AdoptAPI/HoldBaby",
    "AdoptAPI/EjectBaby", "AdoptAPI/UseStroller", "AdoptAPI/UnequipStroller",
    "AdoptAPI/ExitSeatStates", "AdoptAPI/SendPassiveDoorEnter",
    "AilmentsAPI/ProgressPetMeAilment", "AilmentsAPI/ChooseMysteryAilment",
    "AilmentsAPI/PetAilmentCompleted", "AilmentsAPI/BabyAilmentCompleted",
    "PetAPI/PetPetted", "LocationAPI/SetLocation", "PayAPI/Collect",
    "DataAPI/GetAllServerData", "DataAPI/DataChanged", "DataAPI/DataPartiallyChanged",
}
for _, p in ipairs(REMOTE_LIST) do R(p) end

-- идемпотентное подключение событий: флаг на ремоут, повтор безопасен.
-- Вызывается при старте И повторно из remoteReport().
local EV_CONNECTED = {}
local function connectEvents()
    -- DataChanged(pname, manager, payload, timestamp)
    local dc = R"DataAPI/DataChanged"
    if dc and not EV_CONNECTED[dc] then
        -- v2.2: pcall вокруг каждого Connect — битый/чужой инстанс больше
        -- не убивает поток загрузки; флаг ставится только при успехе,
        -- чтобы неудачная попытка повторилась позже
        local okC, c = pcall(function()
            return dc.OnClientEvent:Connect(function(pname, manager, payload)
                if pname ~= player.Name then return end
                if manager == "ailments_manager" and type(payload) == "table" then
                    if type(payload.baby_ailments) == "table" then cache.baby = payload.baby_ailments end
                    if type(payload.ailments)       == "table" then cache.petAil = payload.ailments end
                    lastDataT = os.clock()
                end
            end)
        end)
        if okC and c then
            EV_CONNECTED[dc] = true
            CONNS[#CONNS + 1] = c
        end
    end
    -- DataPartiallyChanged(pname, { {replicated_key_path, serialized_partial_value}, ... })
    local dpc = R"DataAPI/DataPartiallyChanged"
    if dpc and not EV_CONNECTED[dpc] then
        -- v2.2: pcall вокруг Connect (см. комментарий к DataChanged)
        local okC, c = pcall(function()
            return dpc.OnClientEvent:Connect(function(pname, changes)
                if pname ~= player.Name then return end
                lastDataT = os.clock()
                for _, ch in ipairs(changes or {}) do
                    local path, val = ch.replicated_key_path, ch.serialized_partial_value
                    if type(path) == "table" then
                        if path[1] == "inventory" and type(path[2]) == "string"
                           and type(path[3]) == "string" then
                            cache.inv[path[2]] = cache.inv[path[2]] or {}
                            cache.inv[path[2]][path[3]] = (type(val) == "table") and val or nil
                        elseif path[1] == "house_interior" and path[2] == "furniture"
                               and type(path[3]) == "string" then
                            -- v2.1: храним и occupied — по нему работает вахдог
                            -- антизастревания и проверка выхода из мебели
                            if type(val) == "table" and typeof(val.cframe) == "CFrame" then
                                local prev = cache.furn[path[3]]
                                cache.furn[path[3]] = {
                                    id = val.id, cf = val.cframe,
                                    occ = (type(val.occupied) == "table") and val.occupied
                                          or (prev and prev.occ or nil),
                                    occT = os.clock(),
                                }
                            else
                                cache.furn[path[3]] = nil -- мебель убрали/не валидна
                            end
                        end
                    end
                end
            end)
        end)
        if okC and c then
            EV_CONNECTED[dpc] = true
            CONNS[#CONNS + 1] = c
        end
    end
    -- награды пета: PetAilmentCompleted(petId, kind, rewards)
    local pac = R"AilmentsAPI/PetAilmentCompleted"
    if pac and not EV_CONNECTED[pac] then
        -- v2.2: pcall вокруг Connect (см. комментарий к DataChanged)
        local okC, c = pcall(function()
            return pac.OnClientEvent:Connect(function(unique, kind, rewards)
                STATS.pets = STATS.pets + 1
                if type(rewards) == "table" and type(rewards.bucks) == "number" then
                    STATS.bucks = STATS.bucks + rewards.bucks
                end
                notify("Задание пета ✓", tostring(kind) .. " | +" .. tostring(rewards and rewards.bucks or "?") .. "$")
                markCompleted("pet", kind, unique) -- v2.1: кэш сразу, не ждём DataChanged
            end)
        end)
        if okC and c then
            EV_CONNECTED[pac] = true
            CONNS[#CONNS + 1] = c
        end
    end
    -- награды бэби: BabyAilmentCompleted(player, kind, rewards)
    local bac = R"AilmentsAPI/BabyAilmentCompleted"
    if bac and not EV_CONNECTED[bac] then
        -- v2.2: pcall вокруг Connect (см. комментарий к DataChanged)
        local okC, c = pcall(function()
            return bac.OnClientEvent:Connect(function(plr, kind, rewards)
                if plr ~= nil and plr ~= player then return end -- v2.1: только наши
                STATS.baby = STATS.baby + 1
                if type(rewards) == "table" and type(rewards.bucks) == "number" then
                    STATS.bucks = STATS.bucks + rewards.bucks
                end
                notify("Задание бэби ✓", tostring(kind) .. " | +" .. tostring(rewards and rewards.bucks or "?") .. "$")
                markCompleted("baby", kind, nil) -- v2.1: кэш сразу
            end)
        end)
        if okC and c then
            EV_CONNECTED[bac] = true
            CONNS[#CONNS + 1] = c
        end
    end
end

-- самотест: сколько ремоутов реально найдено (плашка + F9)
local function remoteReport()
    local ok, miss = 0, {}
    for _, p in ipairs(REMOTE_LIST) do
        if R(p) then ok = ok + 1 else miss[#miss + 1] = p end
    end
    REM_OK = ok
    connectEvents() -- до-подключаем всё, что нашлось только что
    return ok, miss
end

--────────────────────── ИНИЦИАЛИЗАЦИЯ ДАННЫХ ───────────────────────
local function findOwner(t, key, depth)
    if depth <= 0 or type(t) ~= "table" then return nil end
    if type(t[key]) == "table" then return t end
    for _, v in pairs(t) do
        if type(v) == "table" then
            local r = findOwner(v, key, depth - 1)
            if r then return r end
        end
    end
    return nil
end

local function ownSub(gd)
    for _, k in ipairs({ tostring(player.Name), tostring(player.UserId) }) do
        local sub = gd[k]
        if type(sub) == "table" then return sub end
    end
    return gd
end

local function initState()
    local rf = R"DataAPI/GetAllServerData"
    if not rf then
        setStatus("ремоут GetAllServerData не найден!")
        return false
    end
    setStatus("снимаю снимок данных (до ~15с)...")
    local ok, gd = pcall(function() return call(rf) end)
    if not ok or type(gd) ~= "table" then
        setStatus("GetAllServerData не ответил")
        return false
    end
    local sub = ownSub(gd)
    local got = false
    pcall(function()
        local mgr = findOwner(sub, "baby_ailments", 6)
        if mgr then
            if type(mgr.baby_ailments) == "table" then cache.baby = mgr.baby_ailments end
            if type(mgr.ailments) == "table" then cache.petAil = mgr.ailments end
            got = true
        end
    end)
    pcall(function()
        local invO = findOwner(sub, "inventory", 6)
        if invO and type(invO.inventory) == "table" then cache.inv = invO.inventory end
    end)
    pcall(function()
        local hiO = findOwner(sub, "house_interior", 6)
        local hi = hiO and hiO.house_interior
        if type(hi) == "table" and type(hi.furniture) == "table" then
            for fid, info in pairs(hi.furniture) do
                if type(info) == "table" and typeof(info.cframe) == "CFrame" then
                    cache.furn[fid] = {
                        id = info.id, cf = info.cframe,
                        occ = (type(info.occupied) == "table") and info.occupied or nil,
                        occT = os.clock(),
                    }
                end
            end
        end
    end)
    if got then
        lastDataT = os.clock()
        return true
    end
    local keys = {}
    for k, v in pairs(gd) do
        keys[#keys + 1] = tostring(k) .. "(" .. type(v) .. ")"
        if #keys >= 12 then break end
    end
    warn("[AdoptFarm] GetAllServerData: ailments не найдены. Ключи: " .. table.concat(keys, ", "))
    return false
end

--────────────────────── ДОСТУП К ДАННЫМ ──────────────────────
local function babyAil(kind)
    local b = cache.baby
    return b and b[kind] or nil
end
local function petAil(unique, kind)
    local p = cache.petAil and cache.petAil[unique]
    return p and p[kind] or nil
end
local function anyPetAil(kind)
    for u in pairs(cache.petAil or {}) do
        if petAil(u, kind) then return true end
    end
    return false
end
local function anyHas(kind)
    if babyAil(kind) then return true end
    return anyPetAil(kind)
end

local skipUntil = {}
local function skipped(key) return (skipUntil[key] or 0) > os.clock() end
local function setSkip(key) skipUntil[key] = os.clock() + CFG.SKIP_TIME end

-- проверка выполнения: ждём исчезновения аилмента; РОСТ progress теперь
-- РЕАЛЬНО продлевает дедлайн (в v2.0 комментарий не соответствовал коду).
-- Потолок 3x таймаута — чтобы задание с "вечным" прогрессом не ждало бесконечно.
local function waitAilGone(getter, timeout)
    local t0 = os.clock()
    local deadline = t0 + timeout
    local hardCap = t0 + timeout * 3
    local baseP = (getter() and getter().progress) or 0
    while os.clock() < deadline do
        if stopRequested() then return false end
        local a = getter()
        if a == nil then return true end
        local p = a.progress or 0
        if p > baseP + 0.02 then
            baseP = p -- прогресс идёт — терпим дальше (реально продлеваем)
            deadline = math.min(hardCap, math.max(deadline, os.clock() + 8))
        end
        task.wait(0.5)
    end
    return getter() == nil
end

--────────────────────── ПЕТЫ: МОДЕЛИ ───────────────────────
local function cleanName(s)
    return (tostring(s):lower():gsub("[^%w]", ""))
end
-- сопоставление имён: равенство, или подстрока в обе стороны ТОЛЬКО при
-- длине >= 4 ("dog" не матчится с "hot_dog")
local function nameHit(a, b)
    if a == "" or b == "" then return false end
    if a == b then return true end
    if #a >= 4 and b:find(a, 1, true) then return true end
    if #b >= 4 and a:find(b, 1, true) then return true end
    return false
end

local function petModels()
    local f = WG:FindFirstChild("Pets")
    return f and f:GetChildren() or {}
end
local function matchModel(unique)
    local item = cache.inv.pets and cache.inv.pets[unique]
    local cid = cleanName(item and item.id or "")
    local models = petModels()
    -- проход 1: точное совпадение имени
    if cid ~= "" then
        for _, m in ipairs(models) do
            if cleanName(m.Name) == cid then return m end
        end
        -- проход 2: подстрока (надёжная)
        for _, m in ipairs(models) do
            if nameHit(cleanName(m.Name), cid) then return m end
        end
    end
    -- запасной: ТОЛЬКО если пет в мире действительно один и в инвентаре один.
    -- v2.1: убран опасный фолбэк "#models == 1 и cid ~= ''" — он брал чужую/
    -- непрогруженную модель и гладил не того пета.
    local uniques = 0
    for _ in pairs(cache.inv.pets or {}) do uniques = uniques + 1 end
    if #models == 1 and uniques <= 1 then return models[1] end
    return nil
end
local function charModel()
    return player.Character
end

--────────────────────── ВЫХОД ИЗ МЕБЕЛИ (v2.1 ГЛАВНЫЙ ФИКС) ──────────────────────
-- Бэби НЕ вынимается из мебели сервером сам (в отличие от пета):
-- мебель освобождается только после AdoptAPI/ExitSeatStates. Чужой скрипт
-- зовёт его дважды: сразу после события выполнения и через ~1с.
local function whoIsOurs(streamId)
    if type(streamId) ~= "string" then return false end
    -- бэби: "StreamingId_<ник игрока>_<hex>"; пет: "StreamingId_<имя модели>_<hex>"
    if streamId:find("StreamingId_" .. tostring(player.Name) .. "_", 1, true) then return true end
    for _, m in ipairs(petModels()) do
        if streamId:find("StreamingId_" .. tostring(m.Name) .. "_", 1, true) then return true end
    end
    return false
end

-- настойчивый выход: до 4 вызовов, каждый раз сверяемся с occupied из данных;
-- без fid (по СТОП) — просто 2 вызова с паузой, как у чужого скрипта.
exitSeatsRelentless = function(fid, reason)
    for attempt = 1, 4 do
        call(REM.AdoptAPI_ExitSeatStates)
        -- v2.4: физический выход ЛОКАЛЬНО — вставание видно сразу,
        -- не дожидаясь, пока сервер обработает ExitSeatStates
        pcall(function()
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.Sit = false
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
        task.wait(0.4)
        if not fid then
            if attempt >= 2 then return true end
        else
            local still = false
            local info = cache.furn[fid]
            if info and type(info.occ) == "table" then
                for _, who in pairs(info.occ) do
                    if whoIsOurs(who) then still = true break end
                end
            end
            if not still then
                if attempt > 1 then
                    print("[AdoptFarm] выход из мебели: сиденье освобождено (попытка " .. attempt .. ")")
                end
                return true
            end
        end
    end
    print("[AdoptFarm] выход из мебели: occupied не очистился (" ..
        tostring(fid) .. ", " .. tostring(reason) .. ") — ExitSeatStates x4, вахдог добьёт")
    return false
end

--══════════════════ КАЛИБРОВКА ПЛОТА (ГОЛОСОВАНИЕ) ══════════════════
-- Идея та же, что в v2.0: мебель в доме стоит по ЛОКАЛЬНЫМ координатам
-- (DataPartiallyChanged: cframe=CF(12,0,-30)), в мире — на лоте со своим
-- origin. v2.1-правки:
--   1) якорь = позиция МОДЕЛИ мебели (GetPivot), а не кнопки Seat1/UseBlock —
--      в v2.0 кандидат был систематически смещён на офсет кнопки в модели;
--   2) дистанционный фильтр CAL_MAX_DIST: мебель чужих плотов (видна в том
--      же сервере!) больше не становится якорем;
--   3) ORIGIN можно сбросить и перекалибровать (см. resetOrigin).

local BUTTON_NAMES = { UseBlock = true, Seat1 = true, Seat2 = true, Seat = true }

local FURN_NAME_LOOKUP = {}
for fkey, entry in pairs(FURN) do
    for _, nm in ipairs(entry.names) do
        FURN_NAME_LOOKUP[cleanName(nm)] = fkey
    end
end

local furnScanT, furnScanList = 0, {}
local function bumpFurnScan() furnScanT = 0 end

-- один проход по Workspace: собираем кнопки UseBlock/Seat1/Seat2 и их
-- предков-моделей; распознаём fid ("f-29") и канонический ключ мебели.
-- v2.1: запоминаем refModel — модель, на которой определился fid (для
-- калибровки и для полного CF с поворотом при активации).
local function scanFurniture(force)
    local now = os.clock()
    if not force and now - furnScanT < 8 and furnScanList then return furnScanList end
    furnScanT = now
    local list = {}
    for _, d in ipairs(WG:GetDescendants()) do
        if d:IsA("BasePart") and BUTTON_NAMES[d.Name] then
            local fid, key, label, refModel
            pcall(function()
                for _, an in ipairs({ "FurnitureId", "TemplateId", "Id", "id" }) do
                    local av = d:GetAttribute(an)
                    if type(av) == "string" and av:match("^f%-%d+$") then
                        fid = av
                        refModel = d:FindFirstAncestorOfClass("Model") or d
                        break
                    end
                end
            end)
            local node, steps = d, 0
            while node and steps < 5 do
                node = node:FindFirstAncestorOfClass("Model")
                if not node then break end
                steps = steps + 1
                local nm = node.Name
                if not fid then
                    local f = nm:match("^f%-(%d+)$")
                    if f then fid = "f-" .. f; refModel = node end
                end
                if not fid and node.GetAttribute then
                    for _, an in ipairs({ "FurnitureId", "TemplateId", "Id", "id" }) do
                        local av = node:GetAttribute(an)
                        if type(av) == "string" and av:match("^f%-%d+$") then
                            fid = av; refModel = node
                            break
                        end
                    end
                end
                if not key then
                    local lk = FURN_NAME_LOOKUP[cleanName(nm)]
                    if lk then key = lk end
                end
                if not label then label = nm end
            end
            if fid or key then
                list[#list + 1] = { part = d, model = refModel, fid = fid, key = key,
                                    label = label or d.Name }
                if #list >= 60 then break end
            end
        end
    end
    furnScanList = list
    return list
end

-- позиция модели мебели в мире (для якорей калибровки)
local function modelWorldPos(a)
    local m = a.model
    if m then
        local okp, pv = pcall(function() return m:GetPivot().Position end)
        if okp and typeof(pv) == "Vector3" then return pv end
        local pp = m.PrimaryPart
        if pp then return pp.Position end
    end
    return a.part.Position
end

-- диагностика в F9, если мебель не нашли: что вообще есть вокруг
local function dumpFurnDiagnostics()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position
    local n = 0
    print("[AdoptFarm] ДИАГНОСТИКА мебели: части UseBlock/Seat вокруг:")
    for _, d in ipairs(WG:GetDescendants()) do
        if d:IsA("BasePart") and BUTTON_NAMES[d.Name] then
            local model = d:FindFirstAncestorOfClass("Model")
            local path = model and model:GetFullName() or d:GetFullName()
            local dist = (myPos and (d.Position - myPos).Magnitude) or -1
            print(string.format("[AdoptFarm]   %s | кнопка %s | %.0f стадов", path, d.Name, dist))
            n = n + 1
            if n >= 12 then break end
        end
    end
    if n == 0 then
        print("[AdoptFarm]   ни одной кнопки UseBlock/Seat в Workspace — мебель не прогружена (стриминг). Скрипт попробует зайти домой.")
    end
    local cf = 0
    for _ in pairs(cache.furn) do cf = cf + 1 end
    print(("[AdoptFarm] кэш локальных CF мебели из данных: %d шт."):format(cf))
end

local ORIGIN, ORIGIN_VOTES, ORIGIN_T = nil, 0, 0
local FURN_FAIL_STREAK = 0

local function resetOrigin(reason)
    if ORIGIN then
        print("[AdoptFarm] origin СБРОШЕН (" .. tostring(reason) .. ") — перекалибрую")
    end
    ORIGIN, ORIGIN_VOTES, ORIGIN_T = nil, 0, 0
end

local function calibrateOrigin()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position
    local scan = scanFurniture(true)
    local anchors = {}
    for _, a in ipairs(scan) do
        local lp = nil
        local info = a.fid and cache.furn[a.fid]
        if info and typeof(info.cf) == "CFrame" then lp = info.cf.Position end
        if not lp then
            -- по каноническому ключу берём ЛЮБОЕ известное имя записи FURN
            local entry = a.key and FURN[a.key]
            if entry then
                for _, nm in ipairs(entry.names) do
                    if HOUSE_LOCAL[cleanName(nm)] then
                        lp = HOUSE_LOCAL[cleanName(nm)] break
                    end
                end
            end
        end
        -- только "домовые" якоря (локальный Y≈0) и только БЛИЗНИЕ (v2.1):
        -- чужие плоты в том же сервере ломали голосование
        if lp and lp.Y < 5 then
            local w = modelWorldPos(a)
            local dist = myPos and (w - myPos).Magnitude or 0
            if dist <= CFG.CAL_MAX_DIST then
                anchors[#anchors + 1] = {
                    w = w, l = lp,
                    label = ("%s [%s]"):format(a.label, a.fid or a.key or "?"),
                }
            end
        end
    end
    if #anchors == 0 then
        print("[AdoptFarm] калибровка: якорей нет (мебель не прогружена и данных нет)")
        return false
    end
    -- голосование: кластеры кандидатов origin
    local best = nil
    for i = 1, #anchors do
        local cluster = { anchors[i] }
        local ci = anchors[i].w - anchors[i].l
        for j = 1, #anchors do
            if j ~= i then
                local cj = anchors[j].w - anchors[j].l
                if (cj - ci).Magnitude <= CFG.CAL_TOLERANCE then
                    cluster[#cluster + 1] = anchors[j]
                end
            end
        end
        if not best or #cluster > #best then best = cluster end
    end
    if best and (#best >= 2 or #anchors == 1) then
        local s = Vector3.new()
        for _, a in ipairs(best) do s = s + (a.w - a.l) end
        ORIGIN = s / #best
        ORIGIN_VOTES = #best
        ORIGIN_T = os.clock()
        print(string.format("[AdoptFarm] origin плота откалиброван: (%.1f, %.1f, %.1f) | голосов: %d",
            ORIGIN.X, ORIGIN.Y, ORIGIN.Z, #best))
        for _, a in ipairs(best) do
            print("[AdoptFarm]   голос: " .. a.label)
        end
        return true
    end
    print(("[AdoptFarm] калибровка: %d якорей, но голоса разошлись — нужен заход домой"):format(#anchors))
    return false
end

--────────────────────── ЗАХОД/ВЫХОД ИЗ ДОМА ───────────────────────
-- v2.9: антипровал ПЕРЕПИСАН. В v2.4 «пик» высоты замерялся через 0.4с
-- после смены локации — если персонаж УЖЕ падал (карта не успела
-- стримиться), пик оказывался под картой и «спасение» поднимало его
-- всего на 12 стадов от точки падения (школа: «тепнулся слишком низко,
-- улетел под карту»; дом: «не может телепортироваться»). Теперь:
--   фаза 1 — ловим телепорт-прыжок (>50 стадов от позиции ДО вызова
--            ремоутов) — это и есть точка прибытия;
--   фаза 2 — пока под персонажем НЕТ пола (стриминг), приклеиваем его
--            к точке прибытия (скорость 0 + CFrame каждые 0.3с); пол
--            появился — отпускаем, доземливается сам;
--   если телепорта не было вовсе — следим за падением в бездну.
-- Возвращает true, если прибытие увидено (подтверждение смены локации).
local function countFurniture()
    local n = 0
    for _ in ipairs(scanFurniture(true)) do n = n + 1 end
    return n
end

local DOWN = Vector3.new(0, -90, 0)
local function stabilizeAfterLocation(sec, pre, homeCheck)
    sec = sec or (CFG.STAB_TIME or 8)
    -- Без pre фаза-1 не нужна (прыжок не с чем сравнивать): точка прибытия
    -- = текущая позиция, сразу переходим к наблюдению за падением.
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local spawnPos = hrp and hrp.Position or nil
    local sawArrival = false
    if pre then
        -- фаза 1: прибытие (телепорт-прыжок относительно позиции ДО вызова)
        local t0 = os.clock()
        while os.clock() - t0 < 6 do
            if stopRequested() then return false end
            task.wait(0.25)
            char = player.Character
            hrp = char and char:FindFirstChild("HumanoidRootPart")
            local p = hrp and hrp.Position
            if p then
                if (p - pre).Magnitude > 50 then
                    spawnPos, sawArrival = p, true
                    break
                end
                spawnPos = spawnPos or p -- «уже там»: точка прибытия = текущая
            end
        end
    end
    if homeCheck and not sawArrival and countFurniture() >= 2 then
        return true -- телепорта не было, но мы уже дома (мебель видна)
    end
    if not spawnPos then return false end
    -- v2.9: прибытие СЛОМАНО (игра тепнула под карту, Y сильно ниже любой
    -- локации) — false заставит travelTo повторить дверь+SetLocation
    if sawArrival and spawnPos.Y < -20 then
        print(string.format("[AdoptFarm] прибытие подозрительно низкое (Y=%.0f) — повторяю телепорт", spawnPos.Y))
        return false
    end
    -- фаза 2: антипровал у точки прибытия
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local t1 = os.clock()
    local lastY
    while os.clock() - t1 < sec do
        if stopRequested() then return sawArrival end
        task.wait(0.3)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local p = hrp.Position
            if lastY and math.abs(p.Y - lastY) > 150 then
                spawnPos = p -- легальный двойной телепорт игры — новая точка
            end
            lastY = p.Y
            rayParams.FilterDescendantsInstances = { char }
            local okR, hit = pcall(function()
                return WG:Raycast(p, DOWN, rayParams)
            end)
            local floorY = (okR and hit) and hit.Position.Y or nil
            local falling = (p.Y < spawnPos.Y - 30) or (p.Y < -60)
            local noFloor = (not floorY) or floorY < (spawnPos.Y - 60)
            if p.Y < -150 then
                -- провалились глубже любой карты (пин не спас / точка была
                -- под картой) — отдаём управление travelTo на повтор
                print(string.format("[AdoptFarm] провал под карту (Y=%.0f) — повтор телепорта", p.Y))
                return false
            end
            if falling and noFloor then
                pcall(function()
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.CFrame = CFrame.new(spawnPos + Vector3.new(0, 3, 0))
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum:ChangeState(Enum.HumanoidStateType.Freefall) end
                end)
            end
        end
    end
    return sawArrival
end

-- v2.9: единая смена локации с ПОДТВЕРЖДЕНИЕМ и одним повтором.
-- В v2.4 SetLocation мог молча не сработать (персонаж оставался на
-- месте) — выглядело как «скрипт не может телепортироваться в дом/в
-- школу». Теперь: дверь → mid-колбэк (Subscribe/Unsubscribe) →
-- SetLocation → ждём прыжок позиции; нет прыжка — один повтор.
local function travelTo(loc, subloc, doorOpts, mid)
    local door = (loc == "MainMap") and "Neighborhood/MainDoor" or "MainDoor"
    local function fire()
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local pre = hrp and hrp.Position
        call(REM.AdoptAPI_SendPassiveDoorEnter, loc, door, doorOpts or {})
        if mid then pcall(mid) end
        task.wait(0.7)
        if subloc then
            call(REM.LocationAPI_SetLocation, loc, nil, subloc)
        elseif loc == "housing" then
            -- v2.9 ГЛАВНЫЙ ФИКС ДОМА: по KB [5] домой =
            -- SetLocation("housing", <Player>) — второй аргумент ИГРОК.
            -- В v2.1–v2.7 звали SetLocation("housing") БЕЗ игрока —
            -- сервер молча не телепортировал (проверка прибытия это
            -- честно видела, но повтор был тем же сломанным вызовом).
            call(REM.LocationAPI_SetLocation, loc, player)
        else
            call(REM.LocationAPI_SetLocation, loc)
        end
        return pre
    end
    local pre = fire()
    local arrived = stabilizeAfterLocation((CFG.STAB_TIME or 8) + 4, pre)
    if not arrived and not stopRequested() then
        print("[AdoptFarm] телепорт в " .. tostring(loc) .. " не подтвердился — повторяю")
        task.wait(1.5)
        pre = fire()
        arrived = stabilizeAfterLocation(CFG.STAB_TIME or 8, pre)
    end
    return arrived
end

-- -math.huge: самый ПЕРВЫЙ авто-заход (при старте) не блокируется кулдауном
local lastEnterT = -math.huge

--────────────── v2.9: ЭКИПИРОВКА ПЕТА И РЕСЕТ-ФОЛБЭК «ДОМ» ──────────────
-- Пет в Adopt Me — ТУЛ. Экипировка = ToolAPI/Equip(petUnique, opts)
-- (лог сессии-1: вызван сразу после спавна, уника «2_…» — формат пета).
-- README [4]: Equip вернул false, когда тул УЖЕ в руках — ЭТО НЕ ОШИБКА,
-- значит вызов безопасен как «ensure equipped»: false = уже в руках,
-- true = только что надели.
-- После ресета/смерти игра НЕ экипирует пета сама (подтверждено юзером).
local FURN_KINDS = { sleep = true, bath = true, hungry = true,
                     thirsty = true, dirty = true }
local function petBusyInFurniture()
    for _, kinds in pairs(cache.petAil) do
        if type(kinds) == "table" then
            for kind in pairs(kinds) do
                if FURN_KINDS[tostring(kind)] then return true end
            end
        end
    end
    return false
end

local function getPetUnique()
    local any
    for unique, kinds in pairs(cache.petAil) do
        if type(kinds) == "table" and next(kinds) then return unique end
        any = any or unique
    end
    return any
end

local function ensurePetEquipped(reason)
    local unique = getPetUnique()
    if not unique then
        print("[AdoptFarm] экипировка: уника пета ещё нет в данных — пропускаю")
        return false
    end
    if petBusyInFurniture() then
        -- пет спит/моется/ест из миски — НЕ выдираем его Equip-ом
        print("[AdoptFarm] экипировка отложена: пет занят мебелью (сон/ванна/миска)")
        return false
    end
    local ok, res = pcall(function()
        return call(REM.ToolAPI_Equip, unique,
                    { equip_as_last = false, use_sound_delay = true })
    end)
    if ok and res ~= nil then
        print("[AdoptFarm] пет экипирован (" .. tostring(reason) ..
              "), Equip → " .. tostring(res) .. " (false = уже был в руках)")
        setStatus("пет экипирован")
        return true
    end
    if ok then
        print("[AdoptFarm] Equip не ответил (" .. tostring(reason) .. ") — попробую позже")
        return false
    end
    warn("[AdoptFarm] экипировка пета не удалась: " .. tostring(res))
    return false
end

-- мы сейчас дома? мебель видна ИЛИ рядом с якорем плота (ORIGIN)
local function atHomeNow()
    if countFurniture() >= 2 then return true end
    if ORIGIN then
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - ORIGIN).Magnitude < 150 then return true end
    end
    return false
end

--──── v2.9: ФИЗИЧЕСКИЙ ВХОД В ДОМ (главный фикс по дампу) ────
-- ДАМП 2026-10-28 (сервер юзера): трио ремоутов дома уходит ПРАВИЛЬНО
-- (дверь+Subscribe+SetLocation("housing",player) — все аргументы как в
-- KB [5] и сессии-3), но позиция персонажа НЕ меняется (pos START ==
-- pos END). Вывод: сам по себе трио никого не телепортирует — физический
-- вход в дом делает КЛИЕНТ (в сессии-3 фермер после трио уже через 4-5с
-- звал ActivateFurniture с мировой CF миски — он клиентски тепнулся к
-- мебели, сниффер движение не видит). Поэтому v2.8 ждала «прыжок
-- позиции» после трио, его НЕ БЫЛО → «не подтвердился» → ресет-луп.
local SPAWN_HOME = nil -- точка, куда игра ставит после ресета (плот/дом)

-- точка «внутри дома», по приоритету доказательств (без выдумок):
local function pickEntryTarget()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position
    -- 1) видимая кнопка домашней мебели (UseBlock/Seat) — это интерьер;
    --    лимит 120 стадов = CAL_MAX_DIST (отсекаем чужие плоты)
    local best, bestD
    for _, a in ipairs(scanFurniture(true)) do
        local dist = myPos and (a.part.Position - myPos).Magnitude or 0
        if dist <= CFG.CAL_MAX_DIST and dist < (bestD or math.huge) then
            best, bestD = a.part.Position, dist
        end
    end
    if best then return best, "мебель" end
    -- 2) данные дома (GetAllServerData/DataPartiallyChanged): локальная CF
    --    мебели + origin плота; домовой кластер лежит в ~80 стадах от origin
    --    (фильтр отсекает дальние предметы типа кемпинг-тента)
    if ORIGIN then
        local b2, d2
        for _, info in pairs(cache.furn) do
            if info and typeof(info.cf) == "CFrame" and info.cf.Position.Y < 5 then
                local wp = ORIGIN + info.cf.Position
                local dist = (wp - ORIGIN).Magnitude
                if dist <= 80 and dist < (d2 or math.huge) then b2, d2 = wp, dist end
            end
        end
        if b2 then return b2, "данные дома" end
    end
    -- 3) точка респавна после ресета (юзер: «если ресетнутся — появишься
    --    дома»; захватываем в resetToHome)
    if SPAWN_HOME then return SPAWN_HOME, "точка респавна" end
    -- 4) сам origin плота (центр плота, дом рядом)
    return ORIGIN, "origin"
end

-- трио ремоутов дома — ровно то, что игра делает при проходе двери
-- (сессия-3 04:28:01-02). НЕ телепортирует (доказано дампом), но
-- подписывает дом: после него прилетают данные мебели (cache.furn)
-- и начинает стримиться интерьер.
local function fireHousingTrio()
    call(REM.AdoptAPI_SendPassiveDoorEnter, "housing", "MainDoor", { house_owner = player })
    call(REM.HousingAPI_SubscribeToHouse, player)
    task.wait(0.7)
    call(REM.LocationAPI_SetLocation, "housing", player)
end

-- v2.9: РЕСЕТ-ФОЛБЭК «домой» (подсказка юзера): после респавна игра сама
-- ставит персонажа В ДОМ. Никаких новых ремоутов — клиентский
-- Humanoid.Health = 0 (то же, что Reset Character в меню). Применяется
-- ТОЛЬКО когда дверь+SetLocation housing не подтвердились и мы НЕ дома.
local function resetToHome(reason)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    setStatus("ресет → дом (" .. tostring(reason) .. ")")
    print("[AdoptFarm] РЕСЕТ-ФОЛБЭК: дверь+SetLocation не подтвердились — респавню персонажа, игра поставит в дом")
    hum.Health = 0
    local t0 = os.clock()
    local respawned = false
    while os.clock() - t0 < 20 do
        if stopRequested() then return false end
        task.wait(0.5)
        local c = player.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if c and h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") then
            respawned = true
            break
        end
    end
    if not respawned then
        setStatus("нет респавна — сбросься вручную (ESC)")
        warn("[AdoptFarm] ресет: респавн не дождались за 20с — сбросься вручную")
        return false
    end
    task.wait(3) -- прогрузка дома
    ACTIVE_USE = nil
    pcall(function() bumpFurnScan() end)
    stabilizeAfterLocation(6)
    -- v2.9: запоминаем, куда игра поставила после ресета — это точка
    -- «у дома» (подсказка юзера), цель физического входа
    pcall(function()
        local c2 = player.Character
        local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
        if h2 then SPAWN_HOME = h2.Position end
    end)
    -- после смерти пет слетает с рук — вернём (если не занят мебелью)
    pcall(function() ensurePetEquipped("после ресета") end)
    print("[AdoptFarm] ресет-фолбэк: возрождение в доме выполнено")
    return true
end

-- v2.9 ЯДРО ВХОДА: трио (как игра при проходе двери) → КЛИЕНТСКИЙ
-- телепорт к точке внутри дома → ждём стриминг мебели → проверка.
-- Две попытки, дальше — ресет-фолбэк юзера.
local function enterHouseCore()
    for attempt = 1, 2 do
        if stopRequested() then return false end
        fireHousingTrio()
        task.wait(2.5) -- подписка: данные дома (cache.furn) + стриминг
        bumpFurnScan()
        local target, src = pickEntryTarget()
        if target then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                print(string.format("[AdoptFarm] вход: цель #%d (%.0f, %.0f, %.0f) [%s]",
                    attempt, target.X, target.Y, target.Z, tostring(src)))
                pcall(function() hrp.CFrame = CFrame.new(target + Vector3.new(0, 4, 0)) end)
                stabilizeAfterLocation(6)
            end
        else
            print("[AdoptFarm] вход: целей нет (нет мебели/данных/origin) — попытка " .. attempt)
        end
        -- ждём прогрузку мебели (стриминг): до 8с, скан раз в 2с
        local t0 = os.clock()
        while os.clock() - t0 < 8 do
            if stopRequested() then return false end
            if countFurniture() >= 2 then break end
            task.wait(2)
        end
        bumpFurnScan()
        if atHomeNow() then
            print("[AdoptFarm] мы дома ✓ (попытка " .. attempt .. ")")
            task.wait(1)
            stabilizeAfterLocation(4)
            return true
        end
        print("[AdoptFarm] дом не подтверждён (попытка " .. attempt .. "/2)")
        task.wait(1.5)
    end
    -- обе физические попытки мимо — фолбэк юзера: ресет ставит домой
    if not atHomeNow() then
        resetToHome("вход в дом")
    end
    return atHomeNow()
end

local function enterHouse()
    if os.clock() - lastEnterT < CFG.ENTER_COOLDOWN then return false end
    lastEnterT = os.clock()
    setStatus("захожу домой...")
    return enterHouseCore()
end

local function leaveHouseTo(loc, subloc)
    setStatus("выхожу: " .. tostring(loc))
    -- v2.1: дверь выхода в MainMap — "Neighborhood/MainDoor" (лог 04:27:02).
    -- v2.9: порядок и подтверждение — внутри travelTo
    travelTo(loc, subloc, nil, function()
        call(REM.HousingAPI_UnsubscribeFromHouse, player)
    end)
end

local function goHome()
    setStatus("возвращаюсь домой")
    -- v2.9: тот же физический вход (трио никого не возит — дамп 2026-10-28)
    enterHouseCore()
    -- после возврата мебель могла переехать в стриминге — пересканируем
    bumpFurnScan()
end

-- guarantee: origin есть; иначе полная калибровка; иначе заход домой и снова
local function ensureOrigin()
    if ORIGIN then return true end
    if calibrateOrigin() then return true end
    if enterHouse() then
        if calibrateOrigin() then return true end
    end
    return false
end

--────────────────────── ТЕЛЕПОРТ ───────────────────────
-- v2.1: проверяется ДИСТАНЦИЯ ДО ЦЕЛИ (а не "сдвинулся ли с места"):
-- в v2.0 стоящий рядом с целью персонаж считался "не телепортировавшимся".
local function tpNear(pos)
    if not pos then return false end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    if (hrp.Position - pos).Magnitude <= 6 then return true end -- уже рядом
    if not CFG.TELEPORT then return false end
    pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) end)
    task.wait(0.25)
    local ok = (hrp.Position - pos).Magnitude <= 12
    if not ok then
        pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, 7, 0)) end)
        task.wait(0.25)
        ok = (hrp.Position - pos).Magnitude <= 12
    end
    return ok
end

local function waitPetNear(model, pos, timeout)
    local t0 = os.clock()
    while os.clock() - t0 < (timeout or 3) do
        local pp = model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))
        if pp and pos and (pp.Position - pos).Magnitude < 30 then return true end
        task.wait(0.4)
    end
    return false
end

--────────────────────── РЕЗОЛВ МЕБЕЛИ ───────────────────────
local function nameInEntry(id, entry)
    local iid = cleanName(id)
    if iid == "" then return false end
    for _, nm in ipairs(entry.names) do
        if nameHit(iid, cleanName(nm)) then return true end
    end
    return false
end

-- возвращает fid, buttonName, cframe (мировой) — либо nil
local function resolveFurniture(fkey)
    local entry = FURN[fkey]
    if not entry then return nil end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position
    -- 1) реальная часть в Workspace (приоритет — ближайшая к персонажу)
    local best, bestD
    for _, a in ipairs(scanFurniture(false)) do
        local dist = myPos and (a.part.Position - myPos).Magnitude or 0
        if dist <= CFG.RESOLVE_MAX_DIST then
            local hit = false
            if a.key == fkey then hit = true end
            if not hit and a.fid then
                local info = cache.furn[a.fid]
                if info and nameInEntry(tostring(info.id), entry) then hit = true end
                if not hit and entry.hint and a.fid == entry.hint then
                    -- v2.1: hint принимаем, только если данные НЕ противоречат
                    if not info or nameInEntry(tostring(info.id), entry) then hit = true end
                end
            end
            if hit then
                -- v2.1: fid, противоречащий данным (сматчились по имени модели),
                -- не используем — активация чужого/другого фида бесполезна
                local useFid = a.fid
                if useFid and cache.furn[useFid]
                   and not nameInEntry(tostring(cache.furn[useFid].id), entry) then
                    useFid = nil
                end
                if dist < (bestD or math.huge) then
                    best = { part = a.part, model = a.model, fid = useFid }
                    bestD = dist
                end
            end
        end
    end
    if best then
        local fid = best.fid
        if not fid then
            for f, info in pairs(cache.furn) do
                if info and nameInEntry(tostring(info.id), entry) then fid = f break end
            end
        end
        if not fid then
            local hf = entry.hint
            local hinfo = hf and cache.furn[hf]
            if hinfo and not nameInEntry(tostring(hinfo.id), entry) then hf = nil end
            fid = hf
        end
        -- v2.1: полный CF модели (с поворотом), если доступен
        local cf
        if best.model then
            local okc, pvcf = pcall(function() return best.model:GetPivot() end)
            if okc and typeof(pvcf) == "CFrame" then cf = pvcf end
        end
        if not cf then cf = best.part.CFrame end
        return fid, best.part.Name, cf
    end
    -- 2) фолбэк: локальный CF из данных + откалиброванный origin
    for f, info in pairs(cache.furn) do
        if info and typeof(info.cf) == "CFrame"
           and info.cf.Position.Y < 5
           and nameInEntry(tostring(info.id), entry) then
            if ORIGIN or ensureOrigin() then
                return f, entry.buttons[1], CFrame.new(ORIGIN + info.cf.Position)
            end
            return nil
        end
    end
    return nil
end

-- активация домовой мебели + ПОЛНАЯ проверка выполнения + настойчивый выход
local function doFurniture(fkey, target, getter, waitS)
    local entry = FURN[fkey]
    if not entry then return false end
    if getter() == nil then return true end -- уже выполнено (честная проверка)
    for attempt = 1, CFG.FURN_RETRY do
        if stopRequested() then return false end -- v2.1: честный false, не true
        if getter() == nil then return true end
        local fid, button, cf = resolveFurniture(fkey)
        if not cf then
            setStatus("мебель не найдена — калибрую origin плота...")
            if attempt == 1 then dumpFurnDiagnostics() end
            bumpFurnScan()
            if not ensureOrigin() then task.wait(2) end
        else
            button = button or entry.buttons[1]
            setStatus(("%s: %s «%s» попытка %d/%d"):format(
                fkey, tostring(fid), tostring(button), attempt, CFG.FURN_RETRY))
            print(string.format("[AdoptFarm] мебель: %s | кнопка %s | cf (%.1f, %.1f, %.1f) | цель: %s",
                tostring(fid), tostring(button), cf.X, cf.Y, cf.Z,
                target and target.Name or "player"))
            -- v2.1: СНАЧАЛА выходим из возможного сиденья (из него телепорт
            -- нередко блокируется), затем телепорт
            call(REM.AdoptAPI_ExitSeatStates)
            task.wait(0.2)
            tpNear(cf.Position)
            if target and target ~= player.Character then
                waitPetNear(target, cf.Position, 3)
            end
            -- v2.1: если телепорт не сработал и мы далеко — не активируем вслепую
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local d = hrp and (hrp.Position - cf.Position).Magnitude or 999
            if d > CFG.RESOLVE_MAX_DIST then
                print(string.format("[AdoptFarm] телепорт не удался (дист. %.0f стадов) — попытка отменена", d))
            else
                ACTIVE_USE = { fid = fid, t0 = os.clock() }
                call(REM.HousingAPI_ActivateFurniture, player, fid, button, { cframe = cf }, target)
                if waitAilGone(getter, waitS or CFG.FURN_WAIT) then
                    FURN_FAIL_STREAK = 0
                    -- v2.1: ГЛАВНЫЙ ФИКС застревания — настойчивый выход сразу
                    -- после закрытия задания (как чужой скрипт: 2 вызова)
                    exitSeatsRelentless(fid, "задача выполнена")
                    ACTIVE_USE = nil
                    bumpFurnScan()
                    return true
                end
                -- v2.1: выходим и при неудаче — бэби мог успеть сесть
                exitSeatsRelentless(fid, "таймаут попытки")
                ACTIVE_USE = nil
                bumpFurnScan()
            end
        end
        task.wait(1)
    end
    -- v2.1: мебель не активируется 2 задачи подряд → origin под подозрением
    FURN_FAIL_STREAK = FURN_FAIL_STREAK + 1
    if FURN_FAIL_STREAK >= 2 then
        resetOrigin("мебель не активируется 2 задачи подряд")
        FURN_FAIL_STREAK = 0
    end
    return false
end

--────────────────────── ЕДА / ПИТЬЁ (ТУЛЗА) ───────────────────────
-- v2.4: БЕЛЫЙ СПИСОК съедобного (handoff README [4]/[7]). Раньше брался
-- ПЕРВЫЙ предмет из inventory.food — туда попадает рыболовная приманка,
-- и скрипт пытался её «съесть». Теперь сверяем kind/id со списком;
-- приоритет: hungry → apple (потом прочая еда), thirsty → water (потом
-- прочие напитки). Нет съедобного → ensureItem докупает apple/water.
local FOOD_BAD = { "bait", "lure", "worm" } -- наживки/приманки — НЕ еда
local FOOD_LIST = { -- {чистое_имя, класс}; порядок важен для подстрок
    { "water", "drink" }, { "milk", "drink" }, { "juice", "drink" },
    { "orangejuice", "drink" }, { "lemonade", "drink" },
    { "hotchocolate", "drink" }, { "smoothie", "drink" },
    { "tea", "drink" }, { "coffee", "drink" }, { "soda", "drink" },
    { "apple", "food" }, { "banana", "food" }, { "pizza", "food" },
    { "sandwich", "food" }, { "hotdog", "food" }, { "cheese", "food" },
    { "sushi", "food" }, { "cake", "food" }, { "donut", "food" },
    { "doughnut", "food" }, { "popcorn", "food" }, { "watermelon", "food" },
    { "grapes", "food" }, { "carrot", "food" }, { "bread", "food" },
    { "cookie", "food" }, { "icecream", "food" }, { "pancakes", "food" },
    { "burrito", "food" }, { "taco", "food" }, { "fries", "food" },
    { "burger", "food" }, { "cheeseburger", "food" }, { "chicken", "food" },
    { "noodles", "food" }, { "ramen", "food" }, { "soup", "food" },
    { "salad", "food" }, { "toast", "food" }, { "cereal", "food" },
    { "candy", "food" }, { "chocolate", "food" }, { "lollipop", "food" },
    { "cupcake", "food" }, { "muffin", "food" }, { "pie", "food" },
    { "brownie", "food" }, { "waffle", "food" }, { "pretzel", "food" },
    { "cottoncandy", "food" },
}
local function foodClassOf(raw)
    local k = cleanName(tostring(raw or ""))
    if k == "" then return nil end
    for _, b in ipairs(FOOD_BAD) do
        if k:find(b, 1, true) then return nil end -- приманка/наживка
    end
    local bestLen, bestCls = 0, nil
    for _, e in ipairs(FOOD_LIST) do
        if k == e[1] then return e[2] end -- точное совпадение — сразу
        if #e[1] >= 5 and #e[1] > bestLen and k:find(e[1], 1, true) then
            bestLen, bestCls = #e[1], e[2]
        end
    end
    return bestCls
end

local function pickFoodItem(kind)
    local food = cache.inv and cache.inv.food
    if type(food) ~= "table" then return nil end
    local want = (kind == "thirsty") and "drink" or "food"
    local alt  = (kind == "thirsty") and "food"  or "drink"
    local bestU, bestP      -- основной класс (water/apple = приоритет 2)
    local altU, altP        -- запасной класс
    for u, item in pairs(food) do
        if type(item) == "table" then
            local uses = item.properties and item.properties.uses_left
            if type(uses) ~= "number" or uses > 0 then
                local cls = foodClassOf(item.kind) or foodClassOf(item.id)
                if cls then
                    local kn = cleanName(tostring(item.kind or item.id or ""))
                    local pr = ((kind == "thirsty" and kn == "water")
                             or (kind == "hungry"  and kn == "apple")) and 2 or 1
                    if cls == want then
                        if pr > (bestP or -1) then bestP, bestU = pr, u end
                    elseif cls == alt then
                        if pr > (altP or -1) then altP, altU = pr, u end
                    end
                end
            end
        end
    end
    if bestU then return bestU end
    return altU
end

local function ensureItem(kind, uniq)
    if uniq and cache.inv.food and cache.inv.food[uniq] then return uniq end
    uniq = pickFoodItem(kind)
    if uniq or not CFG.AUTO_BUY then return uniq end
    -- thirsty → вода, hungry → яблоко (id из дампа)
    local itemId = (kind == "thirsty") and "water" or "apple"
    setStatus("покупаю " .. itemId .. "...")
    call(REM.ShopAPI_BuyItem, "food", itemId, {})
    local t0 = os.clock()
    while os.clock() - t0 < 5 and not pickFoodItem(kind) do task.wait(0.5) end
    return pickFoodItem(kind)
end

local function fixConsume(kind, getter)
    local uniq = ensureItem(kind, nil)
    if not uniq then
        setStatus("нет еды/питья и не купилось")
        return false
    end
    local baseP = (getter() and getter().progress) or 0
    local noProg = 0
    for cycle = 1, CFG.DRINK_MAX do
        if stopRequested() or getter() == nil then break end
        uniq = ensureItem(kind, uniq)
        if not uniq then break end
        setStatus(("%s: цикл %d/%d"):format(kind, cycle, CFG.DRINK_MAX))
        call(REM.ToolAPI_Equip, uniq, { equip_as_last = false, use_sound_delay = true })
        task.wait(0.3)
        call(REM.ToolAPI_ServerUseTool, uniq, "START")
        task.wait(CFG.DRINK_HOLD)
        call(REM.ToolAPI_ServerUseTool, uniq, "END")
        task.wait(0.8)
        local a = getter()
        if a == nil then break end
        if (a.progress or 0) <= baseP + 0.001 then
            noProg = noProg + 1
            if noProg >= 4 then break end -- прогресса нет — тулза не работает
        else
            noProg = 0
            baseP = a.progress or 0
        end
    end
    if uniq then -- v2.1: не слать Unequip(nil, ...)
        call(REM.ToolAPI_Unequip, uniq, {})
    end
    return getter() == nil -- честный результат
end

--────────────────────── ОБРАБОТЧИКИ ЗАДАНИЙ ───────────────────────
local function fixPetMe(unique, model)
    if not model then return false end
    for i = 1, 3 do
        if stopRequested() then return false end
        setStatus("глажу пета (" .. i .. ")")
        call(REM.AdoptAPI_FocusPet, model)
        task.wait(0.5)
        call(REM.PetAPI_PetPetted, unique, player)
        task.wait(0.3)
        call(REM.AilmentsAPI_ProgressPetMeAilment, unique)
        if waitAilGone(function() return petAil(unique, "pet_me") end, 6) then
            call(REM.AdoptAPI_UnfocusPet, model)
            return true
        end
        task.wait(1)
    end
    call(REM.AdoptAPI_UnfocusPet, model)
    return false
end

-- Примечание v2.1: по логу сессии-3 walk/ride закрываются ПРОСТОЕМ
-- (HoldBaby 31с / UseStroller ~32с, никаких перемещений чужой скрипт
-- не делал). v2.9: по фидбеку юзера персонаж просто СТОЯЛ все 31с —
-- теперь ЕЩЁ и реально гуляем: клиентский Humanoid:MoveTo по точкам
-- вокруг (без ремоутов, аргументы не трогаем), надёжнее закрывает
-- аилмент и выглядит естественно.
local function fixWalk(unique, model)
    if not model then return false end
    setStatus("ношу пета на руках и гуляю (walk) ~" .. CFG.WALK_TIME .. "с")
    local held = call(REM.AdoptAPI_HoldBaby, model)
    if held == false then -- RF вернул false: не взял — повтор через секунду
        task.wait(1)
        call(REM.AdoptAPI_HoldBaby, model)
    end
    local t0 = os.clock()
    local nextWp = 0
    local lastChar, lastHum
    while os.clock() - t0 < CFG.WALK_TIME + 5 do
        if stopRequested() then break end
        if petAil(unique, "walk") == nil then break end
        -- каждые ~4с — новая точка в 12-22 стадах от текущей позиции
        if os.clock() - nextWp > 4 then
            nextWp = os.clock()
            lastChar = player.Character
            lastHum = lastChar and lastChar:FindFirstChildOfClass("Humanoid")
            local hrp = lastChar and lastChar:FindFirstChild("HumanoidRootPart")
            if lastHum and hrp then
                local ang = math.rad(math.random(0, 359))
                local r = 12 + math.random(0, 10)
                pcall(function()
                    lastHum:MoveTo(hrp.Position + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r))
                end)
            end
        end
        task.wait(0.5)
    end
    if lastHum then
        local hrp = lastChar and lastChar:FindFirstChild("HumanoidRootPart")
        if hrp then pcall(function() lastHum:MoveTo(hrp.Position) end) end
    end
    call(REM.AdoptAPI_EjectBaby, model)
    return petAil(unique, "walk") == nil
end

local function findStrollerUnique()
    for _, items in pairs(cache.inv or {}) do
        if type(items) == "table" then
            for u, item in pairs(items) do
                if type(item) == "table" and cleanName(item.id):find("stroller", 1, true) then
                    return u
                end
            end
        end
    end
    return nil
end

local function fixRide(unique, model)
    if not model then return false end
    local su = findStrollerUnique()
    if not su then
        setStatus("нет струллера для ride")
        return false
    end
    setStatus("катаю пета на струллере (ride)")
    local res = table.pack(call(REM.ToolAPI_Equip, su, { equip_as_last = false, use_sound_delay = true }))
    local tool
    for i = 2, res.n do
        if isInst(res[i]) then tool = res[i] break end
    end
    if not tool then
        task.wait(0.6)
        local char = player.Character
        tool = char and char:FindFirstChild("StrollerTool")
    end
    if not tool then
        call(REM.ToolAPI_Unequip, su, {})
        return false
    end
    -- путь части из снифф-лога: StrollerTool.ModelHandle.TouchToSits.TouchToSit
    local part = tool:FindFirstChild("ModelHandle")
    part = part and part:FindFirstChild("TouchToSits")
    part = part and part:FindFirstChildWhichIsA("BasePart")
    if not part then
        part = tool:FindFirstChildWhichIsA("BasePart", true)
    end
    call(REM.AdoptAPI_UseStroller, player, model, part)
    local t0 = os.clock()
    while os.clock() - t0 < CFG.RIDE_TIME do
        if stopRequested() then break end
        if petAil(unique, "ride") == nil then break end
        task.wait(1)
    end
    call(REM.ToolAPI_Unequip, su, {})
    call(REM.AdoptAPI_UnequipStroller)
    return petAil(unique, "ride") == nil
end

local KNOWN_KEYS = {
    thirsty = true, hungry = true, sleepy = true, dirty = true, toilet = true,
    pet_me = true, walk = true, ride = true, camping = true, school = true,
    sick = true, bored = true,
    -- v2.9: поездки-«вечеринки» — иначе mystery с такими опциями не парсился
    beach_party = true, pizza_party = true,
}
local PREFER = { "thirsty", "hungry", "sleepy", "dirty", "toilet", "walk", "ride" }

local dispatchFix -- forward declaration (mystery вызывает диспетчер)

-- массив целиком состоит из известных ключей-опций?
local function tryOptsArray(t)
    if type(t) ~= "table" or #t == 0 then return false end
    for _, s in ipairs(t) do
        if type(s) ~= "string" or not KNOWN_KEYS[s] then return false end
    end
    return true
end

local function fixMystery(unique, model)
    local ail = petAil(unique, "mystery")
    if not ail then return true end
    -- v2.1: рекурсивный поиск массива опций — теперь и сам t может быть
    -- массивом опций, и в НЕПУСТЫЕ массивы-обёртки рекурсируем
    -- (в v2.0 ветка "#v > 0" съедала таблицы и не рекурсировала в них)
    local opts
    local function scan(t, depth)
        if opts or depth <= 0 or type(t) ~= "table" then return end
        if tryOptsArray(t) then opts = t return end
        for _, v in pairs(t) do
            if type(v) == "table" then
                if tryOptsArray(v) then opts = v return end
                scan(v, depth - 1)
            end
        end
    end
    scan(ail.components or {}, 8)
    if not opts then
        setStatus("mystery: опции не распознаны, пропуск")
        return false
    end
    local key, idx
    for _, pref in ipairs(PREFER) do
        for i, o in ipairs(opts) do
            if o == pref then key, idx = o, i break end
        end
        if key then break end
    end
    if not key then
        for i, o in ipairs(opts) do
            if o ~= "bored" then key, idx = o, i break end -- bored не умеем (нет ремоута)
        end
    end
    if key == "ride" and not findStrollerUnique() then
        key, idx = nil
        for i, o in ipairs(opts) do
            if o ~= "ride" and o ~= "bored" then key, idx = o, i break end
        end
    end
    if not key then
        setStatus("mystery: нет подходящей опции")
        return false
    end
    setStatus("mystery → " .. key)
    -- реальная сигнатура из логов: (petId, "mystery", idx, key)
    call(REM.AilmentsAPI_ChooseMysteryAilment, unique, "mystery", idx, key)
    -- ждём ПОДТВЕРЖДЕНИЕ выбора (mystery исчез), иначе провал
    local ok = waitAilGone(function() return petAil(unique, "mystery") end, 5)
    if not ok then
        setStatus("mystery: выбор не подтверждён сервером")
        return false
    end
    -- v2.1: trip-ветки выполняются поездками (tripPassOnce) — это УСПЕХ,
    -- а не провал (в v2.0 dispatchFix возвращал false и писал "НЕ выполнилось")
    if key == "school" or key == "camping" or key == "sick"
       or key == "beach_party" or key == "pizza_party" then
        print("[AdoptFarm] mystery → " .. key .. " (поездка — выполнит tripPass)")
        return true
    end
    -- ждём появления нового задания (до 5с), чтобы диспетчер не счесть успехом
    local t0 = os.clock()
    while os.clock() - t0 < 5 do
        if stopRequested() then return false end
        if petAil(unique, key) then break end
        task.wait(0.5)
    end
    return dispatchFix("pet", unique, key, model)
end

-- диспетчер: выполнить фикс одного задания (возвращает ЧЕСТНЫЙ результат)
dispatchFix = function(role, unique, kind, model)
    local getter
    if role == "baby" then
        getter = function() return babyAil(kind) end
    else
        getter = function() return petAil(unique, kind) end
    end
    if getter() == nil then return true end

    -- задания, которым обязательна модель пета
    local needModel = { pet_me = true, walk = true, ride = true,
        dirty = true, sleepy = true, toilet = true, mystery = true }
    if role == "pet" and not model and needModel[kind] then
        setStatus("пет-модель не найдена для " .. kind)
        return false
    end

    if kind == "pet_me"  then return fixPetMe(unique, model) end
    if kind == "walk"    then return fixWalk(unique, model) end
    if kind == "ride"    then return fixRide(unique, model) end
    if kind == "mystery" then return fixMystery(unique, model) end

    -- цель для мебели: у бэби всегда свой персонаж
    local target = (role == "baby") and charModel() or model

    if kind == "thirsty" or kind == "hungry" then
        if role == "baby" then
            return fixConsume(kind, getter)
        end
        -- v2.9: пет ест/пьёт ТОЛЬКО из миски (handoff README [4]: «у пета
        -- кормление ИДЁТ ЧЕРЕЗ МЕБЕЛЬ, не через тул»). В v2.4 при неудаче
        -- миски срабатывал фолбэк на тулзу — а тулзой ест/пьёт ДЕРЖАТЕЛЬ
        -- (бэби!), поэтому выглядело как «скрипт решил, что пить хочет
        -- бэби, а не пет» / «не может покормить пета бутылкой».
        local fkey = (kind == "thirsty") and "bowl" or "foodbowl"
        if doFurniture(fkey, target, getter) then
            return true
        end
        setStatus("пету нужна " .. (kind == "thirsty" and "миска с ВОДОЙ" or "миска с ЕДОЙ")
            .. " — поставьте её в доме")
        print("[AdoptFarm] ПЕТ " .. kind .. ": миска недоступна, тулзой пета кормить НЕЛЬЗЯ — откладываю")
        return false
    end

    if kind == "dirty" then
        if role == "baby" then
            return doFurniture("shower", target, getter)
        end
        return doFurniture("bathtub", target, getter)
    end

    if kind == "sleepy" then
        return doFurniture("bed", target, getter)
    end

    if kind == "toilet" then
        return doFurniture("toilet", target, getter)
    end

    return false
end

--────────────────────── ПОЕЗДКИ ───────────────────────
local function fixHospital()
    leaveHouseTo("Hospital")
    -- геттер возвращает ТАБЛИЦУ аилмента (нужно для waitAilGone/progress)
    local getter = function()
        local b = babyAil("sick")
        if b then return b end
        for u in pairs(cache.petAil or {}) do
            local a = petAil(u, "sick")
            if a then return a end
        end
        return nil
    end
    for attempt = 1, 2 do
        if stopRequested() or getter() == nil then break end
        setStatus("лечусь в больнице (" .. attempt .. ")")
        -- v2.1: cf и fid должны принадлежать ОДНОМУ объекту — приоритет у
        -- части с fid == "f-14"; запаска — ближайшая кнопка (<40 стадов);
        -- в v2.0 брали cframe ЛЮБОЙ кровати (в т.ч. домовой в стриминге),
        -- а активировали всегда f-14 — сервер мог отвергнуть
        local cf = HOSPITAL_CF
        local best, bestPri, bestD
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local myPos = hrp and hrp.Position
        for _, a in ipairs(scanFurniture(true)) do
            local dist = myPos and (a.part.Position - myPos).Magnitude or 0
            local pri
            if a.fid == HOSPITAL_FID then
                pri = 0
            elseif dist < 40 then
                pri = 1
            end
            if pri and dist < CFG.RESOLVE_MAX_DIST then
                if not best or pri < bestPri or (pri == bestPri and dist < (bestD or math.huge)) then
                    best, bestPri, bestD = a, pri, dist
                end
            end
        end
        if best then
            local okc, pvcf = pcall(function()
                return best.model and best.model:GetPivot() or best.part.CFrame
            end)
            cf = (okc and typeof(pvcf) == "CFrame") and pvcf or best.part.CFrame
        end
        tpNear(cf.Position)
        task.wait(0.5)
        call(REM.AdoptAPI_ExitSeatStates)
        -- интерьерная мебель: БЕЗ аргумента player (сигнатура из лога)
        call(REM.HousingAPI_ActivateInteriorFurniture,
            HOSPITAL_FID, "UseBlock", { cframe = cf }, charModel())
        if waitAilGone(getter, 12) then break end
        task.wait(1)
    end
    local ok = getter() == nil -- v2.1: честный результат (в v2.0 всегда true)
    goHome()
    return ok
end

local function waitTripDone(kinds, extraWait)
    local t0 = os.clock()
    while os.clock() - t0 < CFG.TRIP_WAIT + (extraWait or 20) do
        if stopRequested() then return false end
        local done = true
        for _, k in ipairs(kinds) do
            if babyAil(k) or anyPetAil(k) then done = false break end
        end
        if done then return true end
        task.wait(1)
    end
    return false
end

local function fixSchool()
    leaveHouseTo("School")
    setStatus("в школе, жду ~50с (school)")
    local ok = waitTripDone({ "school" }) -- v2.1: честный результат
    goHome()
    if not ok then print("[AdoptFarm] school: не завершилось на локации") end
    return ok
end

local function fixCamping()
    leaveHouseTo("MainMap", CFG.CAMP_LOCATION)
    setStatus("на улице, жду кемпинг ~50с")
    local ok = waitTripDone({ "camping" }, 25) -- v2.1: честный результат
    goHome()
    if not ok then print("[AdoptFarm] camping: не завершилось на локации") end
    return ok
end

-- v2.9: пляжная вечеринка (beach_party). Точный id локации в хэндоффе
-- НЕ засниффан (чужой скрипт этот аилмент не выполнял — проверено по
-- 02/03/04), поэтому имя НЕ выдумываем «на веру»: пробуем кандидатов
-- по эталонному шаблону из логов (дверь+SetLocation, как PizzaShop/
-- Circus/Hospital) и подтверждаем телепорт ФАКТИЧЕСКИМ прыжком
-- позиции; где телепорт случился — там и стоим до закрытия аилмента.
-- Ни один не сработал — запасной план: зона пляжа на общей карте
-- (MainMap!Beach — по аналогии с кемпингом MainMap!Halloween).
local BEACH_CANDIDATES = { "Beach", "BeachParty", "Beach2024" }
local function probeLocation(loc)
    -- без повтора: true только если игра реально телепортировала
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local pre = hrp and hrp.Position
    call(REM.AdoptAPI_SendPassiveDoorEnter, loc, "MainDoor", {})
    task.wait(0.7)
    call(REM.LocationAPI_SetLocation, loc)
    return stabilizeAfterLocation(6, pre)
end

local function fixBeach()
    setStatus("ищу пляжную вечеринку (beach_party)...")
    for _, loc in ipairs(BEACH_CANDIDATES) do
        if stopRequested() then return false end
        setStatus("пробую локацию " .. loc .. " (beach_party)")
        if probeLocation(loc) then
            print("[AdoptFarm] beach_party: телепорт в " .. loc .. " подтверждён — жду закрытия аилмента")
            setStatus("на " .. loc .. ", жду ~50с (beach_party)")
            local ok = waitTripDone({ "beach_party" }, 10)
            goHome()
            if not ok then print("[AdoptFarm] beach_party: " .. loc .. " не закрыл аилмент") end
            return ok
        end
    end
    print("[AdoptFarm] beach_party: интерьеры не подтвердились — пробую MainMap!Beach")
    leaveHouseTo("MainMap", "Beach")
    local ok = waitTripDone({ "beach_party" }, 10)
    goHome()
    if not ok then print("[AdoptFarm] beach_party: не завершилось ни на одной локации — пришлите лог F9") end
    return ok
end

-- v2.9: пиццерия — сигнатура из лога s2 (04:01:52): дверь + SetLocation
local function fixPizza()
    leaveHouseTo("PizzaShop")
    setStatus("в пиццерии, жду ~50с (pizza_party)")
    local ok = waitTripDone({ "pizza_party" }, 10)
    goHome()
    if not ok then print("[AdoptFarm] pizza_party: не завершилось на локации") end
    return ok
end

--────────────────────── ГЛАВНЫЙ ЦИКЛ ───────────────────────
-- Домашние задания. "bored" здесь НЕТ намеренно: у него нет ремоута,
-- чужой скрипт-фермер его тоже игнорирует (handoff README [9]).
local HOUSE_KINDS = { "pet_me", "thirsty", "hungry", "toilet", "dirty", "sleepy", "mystery", "walk", "ride" }

local function housePassOnce()
    -- задания бэби (pet_me/walk/mystery/ride существуют только у петов)
    for _, kind in ipairs(HOUSE_KINDS) do
        if kind ~= "pet_me" and kind ~= "walk" and kind ~= "mystery" and kind ~= "ride"
           and babyAil(kind) then
            local key = "baby:" .. kind
            if not skipped(key) then
                setStatus("БЭБИ: " .. kind)
                local ok = dispatchFix("baby", nil, kind, nil)
                if not ok then
                    setSkip(key)
                    print("[AdoptFarm] БЭБИ " .. kind .. ": НЕ выполнилось, откладываю на " .. CFG.SKIP_TIME .. "с")
                else
                    print("[AdoptFarm] БЭБИ " .. kind .. ": выполнено ✓")
                end
                return true
            end
        end
    end
    -- задания петов
    for unique in pairs(cache.petAil or {}) do
        for _, kind in ipairs(HOUSE_KINDS) do
            if petAil(unique, kind) then
                local key = tostring(unique) .. ":" .. kind
                if not skipped(key) then
                    setStatus("ПЕТ: " .. kind)
                    local model = matchModel(unique)
                    local ok = dispatchFix("pet", unique, kind, model)
                    if not ok then
                        setSkip(key)
                        print("[AdoptFarm] ПЕТ " .. kind .. ": НЕ выполнилось, откладываю на " .. CFG.SKIP_TIME .. "с")
                    else
                        print("[AdoptFarm] ПЕТ " .. kind .. ": выполнено ✓")
                    end
                    return true
                end
            end
        end
    end
    return false
end

local function tripPassOnce()
    -- v2.1: поездки честно возвращают результат и скипаются при неудаче
    -- (в v2.0 неудачная поездка превращалась в вечный пинг-понг)
    local trips = {
        { kind = "sick",        f = fixHospital, title = "Больница (sick)" },
        { kind = "school",      f = fixSchool,   title = "Школа (school)" },
        { kind = "camping",     f = fixCamping,  title = "Кемпинг (camping)" },
        -- v2.9: вечеринки
        { kind = "beach_party", f = fixBeach,    title = "Пляжная вечеринка (beach_party)" },
        { kind = "pizza_party", f = fixPizza,    title = "Пиццерия (pizza_party)" },
    }
    for _, t in ipairs(trips) do
        local key = "trip:" .. t.kind
        if anyHas(t.kind) then
            if skipped(key) then return false end
            setStatus(t.title)
            local ok = t.f()
            if not ok then
                setSkip(key)
                print("[AdoptFarm] " .. t.kind .. ": поездка НЕ выполнилась, откладываю на " .. CFG.SKIP_TIME .. "с")
            end
            return true
        end
    end
    return false
end

--────────────────────── HUD И ЗАПУСК ───────────────────────
-- v2.1: весь запуск обёрнут в pcall(boot) — если при загрузке что-то
-- упадёт, флаг _G.ADOPTFARM_ACTIVE сбросится и перезапуск не потребует
-- перезахода в Roblox (в v2.0 флаг залипал навсегда).
local function boot()
    print("[AdoptFarm] boot: создаю HUD...")
    local hud = Instance.new("ScreenGui")
    hud.Name = "AdoptFarmHUD"
    hud.ResetOnSpawn = false
    local hudOk = pcall(function() hud.Parent = game:GetService("CoreGui") end)
    if not hudOk or not hud.Parent then
        local pg = player:FindFirstChildOfClass("PlayerGui")
        if pg then hud.Parent = pg end
    end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 148)
    frame.Position = UDim2.new(0, 8, 0, 8)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = hud

    local function mkLabel(y, sizeY, txt, sz, col)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -12, 0, sizeY)
        l.Position = UDim2.new(0, 6, 0, y)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold
        l.TextSize = sz or 14
        l.TextColor3 = col or Color3.fromRGB(240, 240, 245)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = txt
        l.Parent = frame
        return l
    end
    mkLabel(4, 18, "🐾 AdoptFarm v2.9", 15, Color3.fromRGB(120, 220, 140))
    local statusLbl = mkLabel(24, 30, "статус: запуск...", 12, Color3.fromRGB(200, 210, 230))
    statusLbl.TextWrapped = true
    local statsLbl  = mkLabel(56, 16, "🐾 0 | 👶 0 | 💰 +0", 13, Color3.fromRGB(255, 220, 120))
    local diagLbl   = mkLabel(74, 16, "⚙ ... | задач: - | данн.: - | вых: 0", 11, Color3.fromRGB(150, 190, 255))
    local originLbl = mkLabel(92, 16, "origin: калибрую...", 11, Color3.fromRGB(255, 170, 120))

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -12, 0, 30)
    btn.Position = UDim2.new(0, 6, 0, 110)
    btn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 15
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = "⏹ СТОП"
    btn.Parent = frame
    btn.MouseButton1Click:Connect(function()
        STOP = true
        statusLbl.Text = "статус: ОСТАНОВЛЕНО"
        _G.ADOPTFARM_ACTIVE = false
        print("[AdoptFarm] Остановлено кнопкой СТОП.")
        -- v2.1: аккуратная зачистка — вытащить из мебели, отключить
        -- события, удалить HUD (в v2.0 всё оставалось висеть)
        task.spawn(function()
            pcall(function() exitSeatsRelentless(nil, "СТОП") end)
            for _, c in ipairs(CONNS) do
                pcall(function() c:Disconnect() end)
            end
            task.wait(2.5)
            pcall(function() hud:Destroy() end)
            print("[AdoptFarm] СТОП завершён: события отключены, HUD удалён.")
        end)
    end)

    task.spawn(function()
        while not STOP and hud.Parent do
            statusLbl.Text = "статус: " .. STATUS
            statsLbl.Text = ("🐾 %d | 👶 %d | 💰 +%d"):format(STATS.pets, STATS.baby, STATS.bucks)
            local nb, np = 0, 0
            for _ in pairs(cache.baby) do nb = nb + 1 end
            for _, list in pairs(cache.petAil) do
                for _ in pairs(list) do np = np + 1 end
            end
            local dAge = (lastDataT == 0) and "—" or string.format("%dс", os.clock() - lastDataT)
            diagLbl.Text = string.format("⚙ %d/%d | задач: %d | данн.: %s | вых: %d",
                REM_OK, #REMOTE_LIST, nb + np, dAge, RESCUES)
            if ORIGIN then
                originLbl.Text = string.format("origin: ✓ (%.0f, %.0f, %.0f) гол.: %d",
                    ORIGIN.X, ORIGIN.Y, ORIGIN.Z, ORIGIN_VOTES)
            else
                originLbl.Text = "origin: не найден"
            end
            task.wait(0.4)
        end
    end)

    --────────────────── ВАХДОГ АНТИЗАСТРЕВАНИЯ (v2.1) ──────────────────
    -- Раз в CFG.WATCHDOG_EVERY сек проверяем occupied НАШЕЙ мебели:
    -- если мебель занята нами БЕЗ активной задачи (скрипт упал, выход
    -- потерялся, был СТОП) или задача висит дольше нормы — принудительно
    -- снимаем сиденье. Гарантия, что бэби/пет никогда не застрянут.
    -- Троттлинг 10с/мебель: если occupied протух (DPC не пришёл),
    -- не спамим ExitSeatStates каждые 3с.
    local RESCUE_CD = {}
    task.spawn(function()
        while not STOP do
            task.wait(CFG.WATCHDOG_EVERY)
            local now = os.clock()
            for fid, info in pairs(cache.furn) do
                if type(info.occ) == "table" and now - (info.occT or 0) > 3 then
                    local ours = false
                    for _, who in pairs(info.occ) do
                        if whoIsOurs(who) then ours = true break end
                    end
                    if ours then
                        local active = ACTIVE_USE and ACTIVE_USE.fid == fid
                        local hung = active and (now - ACTIVE_USE.t0 > CFG.FURN_WAIT + 15)
                        if (not active) or hung then
                            if now - (RESCUE_CD[fid] or 0) > 10 then
                                RESCUE_CD[fid] = now
                                RESCUES = RESCUES + 1
                                print("[AdoptFarm] АНТИЗАСТРЕВАНИЕ №" .. RESCUES .. ": " ..
                                    tostring(fid) .. " занят нами — принудительный выход")
                                exitSeatsRelentless(fid, "вахдог")
                            end
                        end
                    end
                end
            end
        end
    end)

    --────────────────── РЕСПАВН-ХУК (v2.9) ──────────────────
    -- После ЛЮБОГО респавна (наш ресет-фолбэк, ручной ресет, смерть):
    -- активное использование мебели сбрасываем, пета возвращаем в руки
    -- (если он не спит/не моется/не ест из миски).
    pcall(function()
        player.CharacterAdded:Connect(function()
            ACTIVE_USE = nil
            task.wait(3)
            if stopRequested() then return end
            pcall(function() bumpFurnScan() end)
            pcall(function() ensurePetEquipped("после респавна") end)
        end)
    end)

    --────────────────── ОСНОВНОЙ ЦИКЛ ──────────────────
    task.spawn(function()
        -- v2.2: ВЕСЬ подготовительный этап под pcall — раньше ошибка здесь
        -- (например, в remoteReport/connectEvents) убивала поток ДО основного
        -- цикла: HUD висел с «ждём загрузку данных...», а скрипт молчал
        local okPre, errPre = pcall(function()
            setStatus("ждём загрузку данных...")
            task.wait(6)
            local okR, miss = remoteReport()
            print(("[AdoptFarm] самотест ремоутов: %d/%d найдено"):format(okR, #REMOTE_LIST))
            if #miss > 0 then
                warn("[AdoptFarm] НЕ НАЙДЕНЫ: " .. table.concat(miss, ", "))
            end
            notify("AdoptFarm v2.9", ("ремоуты: %d/%d"):format(okR, #REMOTE_LIST))
            for _ = 1, 4 do
                if stopRequested() then return end
                if initState() then break end
                task.wait(7)
            end
            -- v2.9: стартовая экипировка пета (игра после перезахода/
            -- ресета пета сама НЕ надевает; false от Equip = уже в руках)
            pcall(function() ensurePetEquipped("старт") end)
            -- ПЕРВАЯ КАЛИБРОВКА: по мебели вокруг; не вышло — заходим домой сами
            setStatus("калибрую origin плота...")
            if not calibrateOrigin() then
                if enterHouse() then calibrateOrigin() end
            end
            if ORIGIN then
                notify("AdoptFarm", "origin плота откалиброван ✓")
            else
                notify("AdoptFarm", "origin не откалиброван — попробую позже")
            end
            notify("AdoptFarm", "запущен, слежу за заданиями")
        end)
        if not okPre then
            warn("[AdoptFarm] ошибка подготовительного этапа (продолжаю): " .. tostring(errPre))
        end
        local lastCollect = os.clock() - CFG.COLLECT_EVERY + 30
        local lastInit = os.clock()
        local lastRCheck = os.clock()
        local lastCalTry = os.clock()
        while not STOP do
            local ok, err = pcall(function()
                if os.clock() - lastRCheck > 30 then
                    lastRCheck = os.clock()
                    remoteReport() -- доищем ремоуты + переподключим события
                end
                if os.clock() - lastCollect > CFG.COLLECT_EVERY then
                    setStatus("забираю зарплату")
                    call(REM.PayAPI_Collect)
                    lastCollect = os.clock()
                end
                -- докалибровка раз в 60с, пока origin нет
                if not ORIGIN and os.clock() - lastCalTry > 60 then
                    lastCalTry = os.clock()
                    if not calibrateOrigin() then enterHouse() end
                end
                -- v2.1: ревалидация origin раз в 10 минут (в v2.0 считался
                -- один раз и жил навсегда, даже если был мусорным)
                if ORIGIN and os.clock() - (ORIGIN_T or 0) > CFG.ORIGIN_REVAL then
                    local old, oldV = ORIGIN, ORIGIN_VOTES
                    ORIGIN, ORIGIN_VOTES = nil, 0
                    if not calibrateOrigin() then
                        ORIGIN, ORIGIN_VOTES = old, oldV
                        ORIGIN_T = os.clock()
                    end
                end
                if housePassOnce() then return end
                if tripPassOnce() then return end
                -- пока задач нет — полный опрос раз в 20с, потом раз в 90с
                local nb, np = 0, 0
                for _ in pairs(cache.baby) do nb = nb + 1 end
                for _, list in pairs(cache.petAil) do
                    for _ in pairs(list) do np = np + 1 end
                end
                if (nb + np == 0 and os.clock() - lastInit > 20)
                    or os.clock() - lastInit > 90 then
                    lastInit = os.clock()
                    pcall(initState)
                end
                setStatus(("жду задания (задач: %d, данные %dс назад)"):format(
                    nb + np, lastDataT == 0 and -1 or math.floor(os.clock() - lastDataT)))
                task.wait(CFG.LOOP_DELAY)
            end)
            if not ok then
                warn("[AdoptFarm] ошибка цикла: " .. tostring(err))
                setStatus("ошибка (смотри F9), продолжаю")
                task.wait(2)
            end
            task.wait(0.2)
        end
    end)

    print("[AdoptFarm] v2.9 загружен. Плашка слева сверху; СТОП — кнопка.")
    print("[AdoptFarm] v2.9: вход в дом = трио ремоутов + КЛИЕНТСКИЙ телепорт внутрь (дамп: ремоуты никого не возят); ресет-фолбэк и автоэкип пета в силе.")
    notify("AdoptFarm v2.9", "загружен ✓")
end

local okBoot, errBoot = pcall(boot)
if not okBoot then
    _G.ADOPTFARM_ACTIVE = false
    warn("[AdoptFarm] ошибка запуска: " .. tostring(errBoot) .. " — флаг сброшен, скрипт можно перезапустить")
end

print("[AdoptFarm] v2.9: ФАЙЛ ДОСТАВЛЕН ЦЕЛИКОМ (конец дошел, ничего не обрезано)")
