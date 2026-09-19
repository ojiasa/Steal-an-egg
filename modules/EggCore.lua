-- ═══════════════════════════════════════════════════════════════
-- modules/EggCore.lua — v3.5 (Hatch có delay finish đúng)
-- ═══════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- ─────────────── NETWORKING ───────────────
local NET = nil
do
    local pk = ReplicatedStorage:FindFirstChild("Packages")
    if pk then NET = pk:FindFirstChild("Networking") end
end

local function getRemote(name)
    if not NET then return nil end
    for _, c in ipairs(NET:GetDescendants()) do
        if c.Name == name then return c end
    end
    local suffix = "/" .. name
    for _, c in ipairs(NET:GetDescendants()) do
        if c.Name:sub(-#suffix) == suffix then return c end
    end
    return nil
end

-- ─────────────── CONFIG ───────────────
local CONFIG = {
    -- ⏳ Thời gian chờ giữa AskHatch và AskFinishHatch (giây)
    -- Game Steal An Egg thường mất 5-8s để animation hatch chạy xong
    finishDelay = 6,

    -- Số egg hatch song song mỗi batch
    batchSize = 3,

    -- Delay giữa các egg trong cùng batch (tránh spam remote)
    betweenEggDelay = 0.15,

    -- Số lần retry finish nếu fail
    finishRetries = 3,

    -- Delay giữa mỗi lần retry finish
    finishRetryDelay = 1.5,
}

-- Cho phép chỉnh từ ngoài: EggCore.SetConfig({finishDelay = 8})
local function setConfig(tbl)
    if type(tbl) ~= "table" then return end
    for k, v in pairs(tbl) do
        if CONFIG[k] ~= nil then CONFIG[k] = v end
    end
end

local function getConfig()
    return table.clone(CONFIG)
end

-- ─────────────── STATE ───────────────
local State = {
    autoHatch     = false,
    autoHatchInterval = 5,

    autoPlace     = false,
    autoPlaceInterval = 5,
    autoPlaceAmount   = 300,

    totalHatched  = 0,
    totalPlaced   = 0,

    hatchThread   = nil,
    placeThread   = nil,

    onLogCallback = nil,  -- callback(msg) để UI hiển thị
}

local function log(msg)
    warn("[EggCore] " .. tostring(msg))
    if State.onLogCallback then
        pcall(State.onLogCallback, tostring(msg))
    end
end

local function onLog(cb)
    State.onLogCallback = cb
end

-- ─────────────── LẤY EGG Ở BASE ───────────────
local function getBaseEggs()
    local res = {}
    local per = Workspace:FindFirstChild("PlacedEggRenders")
    if not per then return res end

    local key = tostring(LocalPlayer.UserId) .. "_"
    for _, obj in ipairs(per:GetChildren()) do
        if obj.Name:sub(1, #key) == key then
            local uid = obj.Name:sub(#key + 1)
            table.insert(res, { uid = uid, obj = obj })
        end
    end
    return res
end

-- ─────────────── HATCH 1 EGG (có delay + retry) ───────────────
-- Cơ chế: AskHatch(uid) → chờ finishDelay giây → AskFinishHatch(uid) → retry nếu fail
local function hatchOne(uid, hatchR, finishR)
    if not hatchR then return false end

    -- B1: Bắt đầu hatch
    local ok, res = pcall(function()
        return hatchR:InvokeServer(uid)
    end)

    if not ok or res ~= true then
        return false
    end

    -- B2: Đợi animation hatch chạy xong
    task.wait(CONFIG.finishDelay)

    -- B3: Finish + retry
    if finishR then
        for attempt = 1, CONFIG.finishRetries do
            local fok, fres = pcall(function()
                return finishR:InvokeServer(uid)
            end)

            if fok and (fres == true or fres == nil) then
                -- Thành công (nil cũng coi như ok vì 1 số remote không return)
                return true
            end

            if attempt < CONFIG.finishRetries then
                task.wait(CONFIG.finishRetryDelay)
            end
        end
        return true  -- Vẫn coi là đã hatch kể cả finish fail hết
    end

    return true
end

-- ─────────────── HATCH BATCH (song song nhiều egg) ───────────────
-- Chia eggs thành nhiều batch, mỗi batch chạy song song để tiết kiệm thời gian
local function hatchBatch(eggs, hatchR, finishR)
    if #eggs == 0 then return 0 end

    local threads = {}
    local results = {}

    for i, e in ipairs(eggs) do
        local idx = i
        threads[idx] = task.spawn(function()
            results[idx] = hatchOne(e.uid, hatchR, finishR)
        end)
        -- Delay nhỏ giữa các egg để không spam remote 1 lúc
        if i < #eggs then
            task.wait(CONFIG.betweenEggDelay)
        end
    end

    -- Chờ tất cả xong
    for _, th in ipairs(threads) do
        pcall(task.wait, th)
    end

    local count = 0
    for _, ok in ipairs(results) do
        if ok then count = count + 1 end
    end
    return count
end

-- ─────────────── HATCH ALL ───────────────
local function hatchAll(maxSeconds)
    maxSeconds = maxSeconds or 60

    local hatchR  = getRemote("AskHatch")
    local finishR = getRemote("AskFinishHatch")
    if not hatchR then
        log("❌ Không tìm thấy AskHatch remote")
        return 0
    end

    local eggs = getBaseEggs()
    if #eggs == 0 then return 0 end

    local startTime = os.clock()
    local totalCount = 0

    -- Chia batch
    for i = 1, #eggs, CONFIG.batchSize do
        if os.clock() - startTime > maxSeconds then break end

        local batch = {}
        for j = i, math.min(i + CONFIG.batchSize - 1, #eggs) do
            table.insert(batch, eggs[j])
        end

        local n = hatchBatch(batch, hatchR, finishR)
        totalCount = totalCount + n
        State.totalHatched = State.totalHatched + n

        if n > 0 then
            log(("🔥 Batch: +%d egg (tổng %d)"):format(n, State.totalHatched))
        end

        task.wait(0.3)
    end

    return totalCount
end

local function hatchOnce()
    return hatchAll(120)
end

-- ─────────────── PLACE ───────────────
local function placeOne(eggId, placeR)
    if not placeR then return false end
    local ok, res = pcall(function()
        if eggId then return placeR:InvokeServer(eggId)
        else return placeR:InvokeServer() end
    end)
    return ok and res == true
end

local function getOwnedEggIds()
    local list = {}
    local candidates = {
        LocalPlayer:FindFirstChild("Eggs"),
        LocalPlayer:FindFirstChild("Inventory") and LocalPlayer.Inventory:FindFirstChild("Eggs"),
        ReplicatedStorage:FindFirstChild("EggTemplates"),
    }
    for _, folder in ipairs(candidates) do
        if folder then
            for _, e in ipairs(folder:GetChildren()) do
                table.insert(list, e.Name)
            end
            if #list > 0 then break end
        end
    end
    return list
end

local function placeAll(maxSeconds)
    maxSeconds = maxSeconds or 5

    local placeR = getRemote("AskPlaceEgg") or getRemote("AskPlace")
    if not placeR then
        log("❌ Không tìm thấy AskPlaceEgg remote")
        return 0
    end

    local eggs = getOwnedEggIds()
    if #eggs == 0 then return 0 end

    local startTime = os.clock()
    local count = 0
    local limit = math.min(#eggs, State.autoPlaceAmount)

    for i = 1, limit do
        if os.clock() - startTime > maxSeconds then break end
        if placeOne(eggs[i], placeR) then
            count = count + 1
            State.totalPlaced = State.totalPlaced + 1
        end
        task.wait(0.1)
    end
    return count
end

local function placeOnce(sec)
    return placeAll(sec or 5) > 0
end

-- ─────────────── AUTO HATCH LOOP ───────────────
local function startAutoHatch(interval)
    if State.autoHatch then return true end

    State.autoHatch = true
    State.autoHatchInterval = interval or 5

    State.hatchThread = task.spawn(function()
        while State.autoHatch do
            task.wait(State.autoHatchInterval)
            if not State.autoHatch then break end

            pcall(function()
                local n = hatchAll(State.autoHatchInterval * 4)
                if n > 0 then
                    log(("Auto-hatch: +%d (tổng %d)"):format(n, State.totalHatched))
                end
            end)
        end
    end)

    log("✅ Auto Hatch BẬT (delay finish=" .. CONFIG.finishDelay .. "s)")
    return true
end

local function stopAutoHatch()
    State.autoHatch = false
    State.hatchThread = nil
    log("⛔ Auto Hatch TẮT")
    return true
end

local function isAutoHatchOn() return State.autoHatch end

-- ─────────────── AUTO PLACE LOOP ───────────────
local function startAutoPlace(amount, interval)
    if State.autoPlace then return true end

    State.autoPlace = true
    State.autoPlaceAmount   = amount or 300
    State.autoPlaceInterval = interval or 5

    State.placeThread = task.spawn(function()
        while State.autoPlace do
            task.wait(State.autoPlaceInterval)
            if not State.autoPlace then break end

            pcall(function()
                local n = placeAll(State.autoPlaceInterval)
                if n > 0 then
                    log(("Auto-place: +%d (tổng %d)"):format(n, State.totalPlaced))
                end
            end)
        end
    end)

    log("✅ Auto Place BẬT")
    return true
end

local function stopAutoPlace()
    State.autoPlace = false
    State.placeThread = nil
    log("⛔ Auto Place TẮT")
    return true
end

local function isAutoPlaceOn() return State.autoPlace end

-- ─────────────── STATUS ───────────────
local function getStatus()
    local eggs = getBaseEggs()
    return {
        autoHatch    = State.autoHatch,
        autoPlace    = State.autoPlace,
        baseEggs     = #eggs,
        totalHatched = State.totalHatched,
        totalPlaced  = State.totalPlaced,
        hasHatchRemote  = getRemote("AskHatch") ~= nil,
        hasFinishRemote = getRemote("AskFinishHatch") ~= nil,
        hasPlaceRemote  = (getRemote("AskPlaceEgg") or getRemote("AskPlace")) ~= nil,
        config = getConfig(),
    }
end

-- ─────────────── EXPORT ───────────────
return {
    -- Hatch
    startAutoHatch  = startAutoHatch,
    stopAutoHatch   = stopAutoHatch,
    isAutoHatchOn   = isAutoHatchOn,
    hatchAll        = hatchAll,
    hatchOnce       = hatchOnce,

    -- Place
    startAutoPlace  = startAutoPlace,
    stopAutoPlace   = stopAutoPlace,
    isAutoPlaceOn   = isAutoPlaceOn,
    placeAll        = placeAll,
    placeOnce       = placeOnce,

    -- Status / config
    getStatus       = getStatus,
    getBaseEggs     = getBaseEggs,
    SetConfig       = setConfig,
    GetConfig       = getConfig,
    OnLog           = onLog,
}
