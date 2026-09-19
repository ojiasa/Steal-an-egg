-- ═══════════════════════════════════════════════════════════════
-- modules/eggplace.lua — Auto Place Egg (module export)
-- ═══════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local P  = Players.LocalPlayer
local RS = ReplicatedStorage
local W  = Workspace

-- ─────────────── NETWORKING ───────────────
local NET = nil
do
    local pk = RS:FindFirstChild("Packages")
    if pk then NET = pk:FindFirstChild("Networking") end
end

local function findRemote(pathName)
    -- pathName dạng: "RF/EggWorld/AskPlaceEgg"
    if not NET then return nil end
    -- Cách 1: trực tiếp tên đầy đủ
    local direct = NET:FindFirstChild(pathName)
    if direct then return direct end
    -- Cách 2: tách theo "/" và duyệt
    local parts = {}
    for p in pathName:gmatch("[^/]+") do table.insert(parts, p) end
    local cur = NET
    for _, p in ipairs(parts) do
        if not cur then return nil end
        cur = cur:FindFirstChild(p)
    end
    return cur
end

local askPlaceEgg       = findRemote("RF/EggWorld/AskPlaceEgg")
local askWearTool       = findRemote("RF/EggWorld/AskWearTool")
local askSnapshot       = findRemote("RF/EggWorld/AskLiveSnapshot")
local homesteadAskState = findRemote("RF/Homestead/AskState")

-- ─────────────── STATE ───────────────
local State = {
    isRunning    = false,
    thread       = nil,
    ok           = 0,
    fail         = 0,
    myBasePos    = nil,
    myBaseModel  = nil,
    onLogCallback = nil,
    walkTimeout  = 90,
    retryLimit   = 3,
}

local function log(msg)
    warn("[EggPlace] " .. tostring(msg))
    if State.onLogCallback then pcall(State.onLogCallback, tostring(msg)) end
end

local function onLog(cb)
    State.onLogCallback = cb
end

-- ─────────────── HELPERS ───────────────
local function HRP()
    local c = P.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function HUM()
    local c = P.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function D(a, b)
    return (Vector3.new(a.X, a.Y, a.Z) - Vector3.new(b.X, b.Y, b.Z)).Magnitude
end

-- ─────────────── FETCH EGGS CẦN PLACE ───────────────
local function fetchEggs()
    if not askSnapshot then return {} end
    local ok, r = pcall(function() return askSnapshot:InvokeServer() end)
    if not ok or type(r) ~= "table" then return {} end

    for _, e in ipairs(r) do
        if type(e) == "table" and e.OwnerUserId == P.UserId then
            local list = {}
            for uid, rec in pairs(e.Records or {}) do
                if type(rec) == "table" and not rec.Placement then
                    table.insert(list, { uid = uid })
                end
            end
            return list
        end
    end
    return {}
end

-- ─────────────── TÌM TOOL THEO UID ───────────────
local function findTool(uid)
    local char = P.Character
    local bp   = P:FindFirstChild("Backpack")
    for _, cont in ipairs({char, bp}) do
        if cont then
            for _, t in ipairs(cont:GetChildren()) do
                if t:IsA("Tool") then
                    for _, v in pairs(t:GetAttributes()) do
                        if tostring(v) == tostring(uid) then
                            return t, cont.Name
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

-- ─────────────── TÌM BASE CỦA MÌNH ───────────────
local function findBase()
    if not homesteadAskState then return nil end
    local ok, state = pcall(function() return homesteadAskState:InvokeServer() end)
    if not ok or type(state) ~= "table" then return nil end

    local owners = state.OwnersBySlot
    if not owners then return nil end

    local mySlot
    for slot, id in pairs(owners) do
        if tostring(id) == tostring(P.UserId) then mySlot = slot; break end
    end
    if not mySlot then return nil end

    local plots = W:FindFirstChild("Plots")
    if not plots then return nil end

    local n = tostring(mySlot)
    for _, obj in ipairs(plots:GetChildren()) do
        if obj.Name == n or obj.Name:find(n, 1, true) then
            local cp = obj:FindFirstChild("CenterPoint", true)
            if cp then
                State.myBaseModel = obj
                return cp.Position
            end
        end
    end
    return nil
end

-- ─────────────── ĐI BỘ TỚI BASE ───────────────
local function walkToBase()
    if not State.myBasePos then return false end
    local hum = HUM(); local hrp = HRP()
    if not hum or not hrp then return false end

    if D(hrp.Position, State.myBasePos) < 12 then
        hum:MoveTo(hrp.Position)
        return true
    end

    local t0 = os.clock()
    while os.clock() - t0 < State.walkTimeout and State.isRunning do
        local h, h2 = HUM(), HRP()
        if not h or not h2 then return false end
        if D(h2.Position, State.myBasePos) < 12 then
            h:MoveTo(h2.Position)
            return true
        end
        h:MoveTo(State.myBasePos)
        task.wait(0.1)
    end
    return false
end

-- ─────────────── GỬI REMOTE PLACE ───────────────
local function fire(egg)
    local hrp = HRP()
    if not hrp or not State.myBaseModel then return false end
    if not askPlaceEgg then return false end

    local playerCF = State.myBaseModel:GetPivot():Inverse() * hrp.CFrame
    local radii = {0, 3, 8, 15, 25, 35}
    local startIdx = math.random(1, #radii)

    for step = 0, #radii - 1 do
        local r = radii[((startIdx + step - 1) % #radii) + 1]
        local ang = math.random() * math.pi * 2
        local x, z = 0, 0
        if r > 0 then
            x = math.cos(ang) * r
            z = math.sin(ang) * r
        end

        local cf = playerCF * CFrame.new(x, 0, z)
        pcall(function()
            return askPlaceEgg:InvokeServer({
                LocalCFrame = cf,
                Uid = egg.uid,
            })
        end)
        task.wait(0.01)

        if not findTool(egg.uid) then
            return true  -- Đã place xong
        end
    end
    return false
end

-- ─────────────── MAIN LOOP ───────────────
local function runLoop()
    State.ok = 0
    State.fail = 0

    State.myBasePos = findBase()
    if not State.myBasePos then
        log("❌ Không tìm được base")
        State.isRunning = false
        return
    end
    log("✅ Base: " .. tostring(State.myBasePos))

    local hrp = HRP()
    if hrp and D(hrp.Position, State.myBasePos) > 12 then
        walkToBase()
    end

    local hum = HUM(); local h0 = HRP()
    if hum and h0 then hum:MoveTo(h0.Position) end

    while State.isRunning do
        local eggs = fetchEggs()
        if #eggs == 0 then
            log(("✅ DONE — OK=%d Fail=%d"):format(State.ok, State.fail))
            break
        end

        local egg = eggs[1]

        local sok, sres = pcall(function()
            return askWearTool:InvokeServer(egg.uid)
        end)

        if sok and sres == true then
            local tool, loc
            for i = 1, State.retryLimit do
                task.wait(0.05)
                tool, loc = findTool(egg.uid)
                if tool then break end
            end

            if tool then
                if loc ~= "Character" then
                    local h = HUM()
                    if h then
                        pcall(function() h:EquipTool(tool) end)
                        task.wait(0.05)
                    end
                end
                if fire(egg) then
                    State.ok = State.ok + 1
                else
                    State.fail = State.fail + 1
                end
            else
                State.fail = State.fail + 1
            end
        else
            State.fail = State.fail + 1
        end

        task.wait(0.01)
    end

    State.isRunning = false
    State.thread = nil
end

-- ─────────────── PUBLIC API ───────────────
local function start()
    if State.isRunning then return true end
    State.isRunning = true
    State.thread = task.spawn(runLoop)
    log("🚀 Auto Place BẮT ĐẦU")
    return true
end

local function stop()
    if not State.isRunning then return true end
    State.isRunning = false
    State.thread = nil
    log("⛔ Auto Place DỪNG")
    return true
end

local function isRunning()
    return State.isRunning
end

local function getStats()
    return {
        isRunning = State.isRunning,
        ok        = State.ok,
        fail      = State.fail,
        basePos   = State.myBasePos,
        baseModel = State.myBaseModel,
        hasAskPlaceEgg  = askPlaceEgg ~= nil,
        hasAskWearTool  = askWearTool ~= nil,
        hasAskSnapshot  = askSnapshot ~= nil,
        hasAskState     = homesteadAskState ~= nil,
    }
end

-- Tự log trạng thái remote khi load
task.spawn(function()
    task.wait(1)
    if not askPlaceEgg then      log("⚠️ Không tìm thấy RF/EggWorld/AskPlaceEgg") end
    if not askWearTool then      log("⚠️ Không tìm thấy RF/EggWorld/AskWearTool") end
    if not askSnapshot then      log("⚠️ Không tìm thấy RF/EggWorld/AskLiveSnapshot") end
    if not homesteadAskState then log("⚠️ Không tìm thấy RF/Homestead/AskState") end
    if askPlaceEgg and askWearTool and askSnapshot and homesteadAskState then
        log("✅ Đủ 4 remote — sẵn sàng")
    end
end)

-- ─────────────── EXPORT ───────────────
return {
    start     = start,
    stop      = stop,
    isRunning = isRunning,
    getStats  = getStats,
    fetchEggs = fetchEggs,
    OnLog     = onLog,
}
