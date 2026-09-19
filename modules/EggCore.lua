-- ═══════════════════════════════════════════════════════════════
-- modules/EggCore.lua — v3.3 (Hatch + Place cho Steal An Egg)
-- ═══════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- ─────────────── NETWORKING ───────────────
local NET = nil
do
    local pk = ReplicatedStorage:FindFirstChild("Packages")
    if pk then
        NET = pk:FindFirstChild("Networking")
    end
end

-- Tìm RemoteFunction/RemoteEvent theo tên (khớp chính xác hoặc theo đuôi "/Name")
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

-- ─────────────── STATE ───────────────
local State = {
    autoHatch     = false,
    autoHatchInterval = 5,

    autoPlace     = false,
    autoPlaceInterval = 5,   -- giây giữa mỗi lần đặt
    autoPlaceAmount   = 300, -- số egg tối đa đặt mỗi đợt

    totalHatched  = 0,
    totalPlaced   = 0,

    hatchThread   = nil,
    placeThread   = nil,
}

local function log(msg)
    warn("[EggCore] " .. tostring(msg))
end

-- ─────────────── LẤY EGG ĐÃ ĐẶT Ở BASE ───────────────
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

    local ok, res = pcall(function()
        return hatchR:InvokeServer(uid)
    end)

    if ok and res == true then
        if finishR then
            task.wait(0.2)
            pcall(function() finishR:InvokeServer(uid) end)
        end
        return true
    end
    return false
end

-- ─────────────── HATCH ALL ───────────────
local function hatchAll(maxSeconds)
    maxSeconds = maxSeconds or 30

    local hatchR  = getRemote("AskHatch")
    local finishR = getRemote("AskFinishHatch")
    if not hatchR then
        log("Không tìm thấy AskHatch remote")
        return 0
    end

    local eggs = getBaseEggs()
    if #eggs == 0 then return 0 end

    local startTime = os.clock()
    local count = 0

    for _, e in ipairs(eggs) do
        if os.clock() - startTime > maxSeconds then break end

        local ok = hatchOne(e.uid, hatchR, finishR)
        if ok then
            count = count + 1
            State.totalHatched = State.totalHatched + 1
        end
        task.wait(0.35)
    end

    return count
end

-- ─────────────── HATCH ONCE (1 lần toàn bộ) ───────────────
local function hatchOnce()
    return hatchAll(60)
end

-- ─────────────── PLACE 1 EGG ───────────────
-- Hỗ trợ 2 kiểu remote phổ biến: AskPlaceEgg(eggId) hoặc AskPlaceEgg()
local function placeOne(eggId, placeR)
    if not placeR then return false end
    local ok, res = pcall(function()
        if eggId then
            return placeR:InvokeServer(eggId)
        else
            return placeR:InvokeServer()
        end
    end)
    return ok and res == true
end

-- Tìm egg template trong Inventory / Backpack (tuỳ game)
local function getOwnedEggIds()
    local list = {}
    -- Thử nhiều folder phổ biến
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

-- ─────────────── PLACE ALL ───────────────
local function placeAll(maxSeconds)
    maxSeconds = maxSeconds or 5

    local placeR = getRemote("AskPlaceEgg") or getRemote("AskPlace")
    if not placeR then
        log("Không tìm thấy AskPlaceEgg remote")
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

-- ─────────────── PLACE ONCE ───────────────
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
                local n = hatchAll(State.autoHatchInterval)
                if n > 0 then
                    log(("Auto-hatch: +%d (tổng %d)"):format(n, State.totalHatched))
                end
            end)
        end
    end)

    log("Auto Hatch BẬT (interval=" .. State.autoHatchInterval .. "s)")
    return true
end

local function stopAutoHatch()
    State.autoHatch = false
    State.hatchThread = nil
    log("Auto Hatch TẮT")
    return true
end

local function isAutoHatchOn()
    return State.autoHatch
end

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

    log("Auto Place BẬT (amount=" .. State.autoPlaceAmount .. ", interval=" .. State.autoPlaceInterval .. "s)")
    return true
end

local function stopAutoPlace()
    State.autoPlace = false
    State.placeThread = nil
    log("Auto Place TẮT")
    return true
end

local function isAutoPlaceOn()
    return State.autoPlace
end

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

    -- Status
    getStatus       = getStatus,
    getBaseEggs     = getBaseEggs,
}
