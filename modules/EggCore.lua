-- ═══════════════════════════════════════════════════════════════
-- EGG CORE MODULE v2.0
-- Hatch (độc lập, no lock) + Place (cần lock, 5 phút/lần)
-- ═══════════════════════════════════════════════════════════════

local P  = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local W  = workspace

local NET = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
local function getRemote(n)
    if not NET then return nil end
    for _, c in ipairs(NET:GetDescendants()) do
        if c.Name == n then return c end
    end
    local s = "/" .. n
    for _, c in ipairs(NET:GetDescendants()) do
        if c.Name:sub(-#s) == s then return c end
    end
end

local askPlaceEgg       = getRemote("AskPlaceEgg")
local askWearTool       = getRemote("AskWearTool")
local askSnapshot       = getRemote("AskLiveSnapshot")
local homesteadAskState = getRemote("AskState")
local askHatch          = getRemote("AskHatch")
local askFinishHatch    = getRemote("AskFinishHatch")

local M = {}
M.totalPlaced  = 0
M.totalHatched = 0
M.basePos      = nil
M.baseModel    = nil
M.busy         = false
M.onLog        = nil

local function log(t)
    local s = tostring(t)
    print("[Core] " .. s)
    if M.onLog then pcall(M.onLog, s) end
end

local function getHRP() local c = P.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = P.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function dist(a, b) return (Vector3.new(a.X,a.Y,a.Z) - Vector3.new(b.X,b.Y,b.Z)).Magnitude end

-- ══════════ MUTEX ══════════
_G.__eggMutex = _G.__eggMutex or { owner = nil, since = 0 }

function M.acquireLock(owner, timeout)
    owner = owner or "core"
    timeout = timeout or 60
    local t0 = os.clock()
    while _G.__eggMutex.owner and _G.__eggMutex.owner ~= owner do
        if os.clock() - t0 > timeout then
            log("⏰ acquireLock timeout (owner=" .. tostring(_G.__eggMutex.owner) .. ")")
            return false
        end
        task.wait(0.2)
    end
    _G.__eggMutex.owner = owner
    _G.__eggMutex.since = os.clock()
    log("🔒 Lock acquired by " .. owner)
    return true
end

function M.releaseLock(owner)
    if _G.__eggMutex.owner == owner then
        _G.__eggMutex.owner = nil
        log("🔓 Lock released by " .. owner)
    end
end

function M.isLocked() return _G.__eggMutex.owner ~= nil end
function M.lockOwner() return _G.__eggMutex.owner end

-- ══════════ HATCH v13 (ĐỘC LẬP — KHÔNG LOCK) ══════════
function M.getBaseEggsRendered()
    local res = {}
    local per = W:FindFirstChild("PlacedEggRenders")
    if per then
        local key = tostring(P.UserId) .. "_"
        for _, obj in ipairs(per:GetChildren()) do
            if obj.Name:sub(1, #key) == key then
                local uid = obj.Name:sub(#key + 1)
                table.insert(res, {uid = uid})
            end
        end
    end
    return res
end

function M.hatchAll(maxTime)
    maxTime = maxTime or 30
    local t0 = os.clock()

    local eggs = M.getBaseEggsRendered()
    if #eggs == 0 then
        log("🥚 Không có egg trên base")
        return 0
    end

    if not askHatch then
        log("❌ Không có AskHatch")
        return 0
    end

    local hatched = 0

    for _, e in ipairs(eggs) do
        if os.clock() - t0 > maxTime then
            break
        end

        local ok, res = pcall(function()
            return askHatch:InvokeServer(e.uid)
        end)

        if ok and res == true then
            hatched = hatched + 1
            M.totalHatched = M.totalHatched + 1

            log("🔥 Hatched #" .. M.totalHatched .. " | " .. tostring(e.uid):sub(1, 12))

            if askFinishHatch then
                task.wait(0.15)
                pcall(function()
                    askFinishHatch:InvokeServer(e.uid)
                end)
            end
        end

        task.wait(0.2)
    end

    return hatched
end

-- ══════════ PLACE (CẦN LOCK) ══════════
function M.fetchUnplaced()
    if not askSnapshot then return {} end
    local ok, r = pcall(function() return askSnapshot:InvokeServer() end)
    if not ok or type(r) ~= "table" then return {} end
    for _, e in ipairs(r) do
        if type(e) == "table" and e.OwnerUserId == P.UserId then
            local list = {}
            for uid, rec in pairs(e.Records or {}) do
                if type(rec) == "table" and not rec.Placement then
                    table.insert(list, {uid = uid})
                end
            end
            return list
        end
    end
    return {}
end

function M.findTool(uid)
    local char = P.Character
    local bp = P:FindFirstChild("Backpack")
    for _, cont in ipairs({char, bp}) do
        if cont then
            for _, t in ipairs(cont:GetChildren()) do
                if t:IsA("Tool") then
                    for _, v in pairs(t:GetAttributes()) do
                        if tostring(v) == tostring(uid) then return t, cont.Name end
                    end
                end
            end
        end
    end
    return nil, nil
end

function M.findBase()
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
            if cp then M.baseModel = obj; return cp.Position end
        end
    end
    return nil
end

function M.firePlace(egg)
    local hrp = getHRP()
    if not hrp or not M.baseModel or not askPlaceEgg then return false end
    local playerCF = M.baseModel:GetPivot():Inverse() * hrp.CFrame
    local radii = {0, 3, 8, 15, 25, 35}
    local startIdx = math.random(1, #radii)
    for step = 0, #radii - 1 do
        local r = radii[((startIdx + step - 1) % #radii) + 1]
        local ang = math.random() * math.pi * 2
        local x, z = 0, 0
        if r > 0 then x = math.cos(ang) * r; z = math.sin(ang) * r end
        pcall(function()
            askPlaceEgg:InvokeServer({LocalCFrame = playerCF * CFrame.new(x, 0, z), Uid = egg.uid})
        end)
        task.wait(0.01)
        if not M.findTool(egg.uid) then return true end
    end
    return false
end

function M.placeAll(maxTime)
    maxTime = maxTime or 5
    local t0 = os.clock()
    if not M.basePos then M.basePos = M.findBase() end
    if not M.basePos then log("❌ Không tìm base"); return 0 end

    local hrp = getHRP()
    if hrp and dist(hrp.Position, M.basePos) > 12 then
        local hum = getHum()
        if hum then
            local t0w = os.clock()
            while os.clock() - t0w < 10 do
                local h, h2 = getHum(), getHRP()
                if not h or not h2 then break end
                if dist(h2.Position, M.basePos) < 12 then h:MoveTo(h2.Position); break end
                h:MoveTo(M.basePos)
                task.wait(0.1)
            end
        end
    end

    local placed = 0
    while os.clock() - t0 < maxTime do
        local eggs = M.fetchUnplaced()
        if #eggs == 0 then break end
        local egg = eggs[1]
        local sok, sres = pcall(function() return askWearTool:InvokeServer(egg.uid) end)
        if sok and sres == true then
            local tool, loc
            for _ = 1, 3 do
                task.wait(0.05)
                tool, loc = M.findTool(egg.uid)
                if tool then break end
            end
            if tool then
                if loc ~= "Character" then
                    local h = getHum()
                    if h then pcall(function() h:EquipTool(tool) end); task.wait(0.05) end
                end
                if M.firePlace(egg) then
                    placed = placed + 1
                    M.totalPlaced = M.totalPlaced + 1
                    log("📦 Placed #" .. M.totalPlaced .. " | " .. tostring(egg.uid):sub(1, 12))
                end
            end
        end
        task.wait(0.03)
    end
    return placed
end

-- ══════════ AUTO HATCH LOOP ══════════
local _hatchLoop = nil

function M.startAutoHatch(intervalSec)
    if _hatchLoop then return end

    _G.__eggHatchEnabled = true
    intervalSec = intervalSec or 5

    log("🔥 Auto Hatch ON (poll " .. intervalSec .. "s)")

    _hatchLoop = task.spawn(function()
        while _G.__eggHatchEnabled do
            task.wait(intervalSec)

            if not _G.__eggHatchEnabled then
                break
            end

            pcall(function()
                local eggs = M.getBaseEggsRendered()

                if #eggs > 0 then
                    log("🥚 Có " .. #eggs .. " egg trên base → hatch")
                    M.hatchAll(30)
                end
            end)
        end

        _hatchLoop = nil
        log("🔥 Auto Hatch OFF")
    end)
end

function M.stopAutoHatch()
    _G.__eggHatchEnabled = false
end

function M.isAutoHatchOn()
    return _G.__eggHatchEnabled == true
end

-- ══════════ AUTO PLACE LOOP (5 phút) ══════════
local _placeLoop = nil

function M.startAutoPlace(intervalSec, durationSec)
    if _placeLoop then return end
    _G.__eggPlaceEnabled = true
    intervalSec = intervalSec or 300
    durationSec = durationSec or 5
    log(string.format("📦 Auto Place ON (mỗi %ds, chạy %ds)", intervalSec, durationSec))
    _placeLoop = task.spawn(function()
        local first = true
        while _G.__eggPlaceEnabled do
            if first then
                first = false
            else
                -- Đếm ngược từng giây để user biết còn bao lâu
                local elapsed = 0
                while _G.__eggPlaceEnabled and elapsed < intervalSec do
                    task.wait(1)
                    elapsed = elapsed + 1
                end
                if not _G.__eggPlaceEnabled then break end
            end
            if not _G.__eggPlaceEnabled then break end

            -- Báo hiệu cho steal nhường
            _G.__eggPlacePending = true
            log("📦 Đến lúc place → xin lock")

            if M.acquireLock("place", 120) then
                M.busy = true
                pcall(function() M.placeAll(durationSec) end)
                M.busy = false
                M.releaseLock("place")
            else
                log("❌ Không lấy được lock place")
            end
            _G.__eggPlacePending = false
        end
        _placeLoop = nil
        log("📦 Auto Place OFF")
    end)
end

function M.stopAutoPlace()
    _G.__eggPlaceEnabled = false
end

function M.isAutoPlaceOn()
    return _G.__eggPlaceEnabled == true
end

function M.getNextPlaceIn()
    if not _placeLoop or not _G.__eggPlaceEnabled then return nil end
    return 0  -- placeholder
end

-- ══════════ FORCE ONCE ══════════
function M.placeOnce(durationSec)
    if M.busy then return false end
    task.spawn(function()
        _G.__eggPlacePending = true
        if M.acquireLock("place", 120) then
            M.busy = true
            pcall(function() M.placeAll(durationSec or 5) end)
            M.busy = false
            M.releaseLock("place")
        end
        _G.__eggPlacePending = false
    end)
    return true
end

function M.hatchOnce()
    return M.hatchAll(30)
end

-- ══════════ STATUS ══════════
function M.getStatus()
    return {
        totalHatched = M.totalHatched,
        totalPlaced  = M.totalPlaced,
        unplaced     = #M.fetchUnplaced(),
        onBase       = #M.getBaseEggsRendered(),
        busy         = M.busy,
        lockOwner    = M.lockOwner(),
        autoHatch    = M.isAutoHatchOn(),
        autoPlace    = M.isAutoPlaceOn(),
    }
end

-- ══════════ INIT ══════════
_G.__eggHatchEnabled = _G.__eggHatchEnabled or false
_G.__eggPlaceEnabled = _G.__eggPlaceEnabled or false
_G.__eggPlacePending = _G.__eggPlacePending or false

_G.EggCore = M
warn("[EggCore v2.0] Loaded")
return M
