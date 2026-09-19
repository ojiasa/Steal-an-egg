-- ═══════════════════════════════════════════════════════════════
-- modules/EggCore.lua — v4.0 (CHỈ AUTO HATCH)
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
    finishDelay      = 0.5,  -- chờ giữa AskHatch và AskFinishHatch
    batchSize        = 1,    -- hatch song song mỗi batch
    betweenEggDelay  = 0.5,  -- delay giữa các egg trong batch
    finishRetries    = 2,    -- retry finish nếu fail
    finishRetryDelay = 0.3,  -- delay giữa retry
}

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
    autoHatch         = false,
    autoHatchInterval = 5,
    totalHatched      = 0,
    hatchThread       = nil,
    onLogCallback     = nil,
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

-- ─────────────── HATCH 1 EGG ───────────────
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
                return true
            end

            if attempt < CONFIG.finishRetries then
                task.wait(CONFIG.finishRetryDelay)
            end
        end
        return true
    end

    return true
end

-- ─────────────── HATCH BATCH ───────────────
local function hatchBatch(eggs, hatchR, finishR)
    if #eggs == 0 then return 0 end

    local threads = {}
    local results = {}

    for i, e in ipairs(eggs) do
        local idx = i
        threads[idx] = task.spawn(function()
            results[idx] = hatchOne(e.uid, hatchR, finishR)
        end)
        if i < #eggs then
            task.wait(CONFIG.betweenEggDelay)
        end
    end

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

-- ─────────────── STATUS ───────────────
local function getStatus()
    local eggs = getBaseEggs()
    return {
        autoHatch    = State.autoHatch,
        baseEggs     = #eggs,
        totalHatched = State.totalHatched,
        hasHatchRemote  = getRemote("AskHatch") ~= nil,
        hasFinishRemote = getRemote("AskFinishHatch") ~= nil,
        config = getConfig(),
    }
end

-- ─────────────── EXPORT ───────────────
return {
    startAutoHatch  = startAutoHatch,
    stopAutoHatch   = stopAutoHatch,
    isAutoHatchOn   = isAutoHatchOn,
    hatchAll        = hatchAll,
    hatchOnce       = hatchOnce,

    getStatus       = getStatus,
    getBaseEggs     = getBaseEggs,
    SetConfig       = setConfig,
    GetConfig       = getConfig,
    OnLog           = onLog,
}
