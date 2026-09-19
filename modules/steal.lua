-- ═══════════════════════════════════════════════════════════════
-- STEAL MODULE v13.0 — Detect reset → Place+Hatch 5s
-- Yêu cầu: modules/EggCore.lua load trước
-- ═══════════════════════════════════════════════════════════════

local P  = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local W  = workspace
local ProximityPromptSvc = game:GetService("ProximityPromptService")
local StarterPlayer      = game:GetService("StarterPlayer")

-- ⭐ LẤY EGG CORE
local EggCore
do
    if _G.EggCore then
        EggCore = _G.EggCore
    else
        local ok, mod = pcall(function()
            return require(script.Parent:WaitForChild("EggCore", 5))
        end)
        if ok then EggCore = mod end
    end
end
if not EggCore then
    warn("[Steal] ❌ Không tìm được EggCore — cần load modules/EggCore.lua trước")
    return nil
end

local M = {}

local ALL_MAPS = {
    { name = "Forest",         pos = Vector3.new( 599.9, 67.6, -363.9) },
    { name = "Lake",           pos = Vector3.new( 722.5, 67.7, -363.9) },
    { name = "Desert",         pos = Vector3.new( 930.8, 67.5, -320.6) },
    { name = "Jungle",         pos = Vector3.new(1124.7, 67.5, -363.9) },
    { name = "Snow",           pos = Vector3.new(1405.1, 68.0, -363.8) },
    { name = "Volcano",        pos = Vector3.new(1863.1, 68.0, -399.5) },
    { name = "Abyss Ocean",    pos = Vector3.new(2166.1, 67.6, -363.9) },
    { name = "Prehistoric",    pos = Vector3.new(2634.4, 67.6, -363.9) },
    { name = "Cosmic",         pos = Vector3.new(3376.8, 68.4, -322.7) },
    { name = "Cherry Blossom", pos = Vector3.new(3928.0, 67.6, -363.8) },
    { name = "Titan Temple",   pos = Vector3.new(4698.0, 67.6, -363.8) },
    { name = "Light Dark",     pos = Vector3.new(5563.0, 67.6, -363.8) },
}

local config = {
    HOME_POS       = Vector3.new(541.19, 70.59, -378.05),
    FOREST_POS     = Vector3.new(599.9, 67.6, -363.9),
    TARGETS        = { { name = "Snow", pos = Vector3.new(1405.1, 68.0, -363.8) } },
    PREFER_FAR     = true,
    PRIORITY_INCOME    = false,
    PRIORITY_THRESHOLD = 1000000,
    BIG_EGG_MODE       = false,
    DUAL_MIN_INCOME = 30000000,
    DUAL_MIN_SIZE   = 4.0,
    HOME_FLY_ABSOLUTE_Y = 100,
    FLY_HOME_SPEED      = 500,
    DROP_SPEED          = 250,
    FOREST_RUN_SPEED    = 250,
    FOREST_RUN_TIMEOUT  = 60,
    FOREST_RADIUS       = 300,
    FOREST_WARMUP       = 0.3,
    BAIT_WARMUP         = 0.3,
    TELE_HOLD           = 0.3,
    TELE_STABILIZE      = 0.2,
    BAIT_TIMEOUT   = 15,
    KB_HEALTH_DROP = 0.1,
    BIG_EGG_MIN_SIZE  = 0,
    BIG_EGG_MIN_SCALE = 0,
    SPEED          = 1500,
    SPEED_CAP      = 800,
    MAP_RADIUS     = 800,
    ARRIVE_DIST    = 10,
    PROMPT_NEAR    = 12,
    MAX_FIRES      = 8,
    STEAL_TIMEOUT  = 1.5,
    CHAT_WAIT      = 1.0,
    EGG_VERIFY_R   = 40,
    WAIT_BETWEEN   = 0.7,
    KB_SPEED_PHYSICS  = 50,
    KB_SPEED_VELOCITY = 80,
    KB_VELY_MIN       = 20,
    KB_SHIFT_MIN      = 30,
    KB_ROTATE_MIN     = 90,
    FOREST_HIT_SPEED  = 60,
    FOREST_HIT_VELY   = 15,

    -- ⭐ RESET DETECTION
    RESET_POLL_INTERVAL    = 15,
    RESET_GROWTH_MIN_ABS   = 30,
    RESET_GROWTH_MIN_RATIO = 1.3,
    RESET_CONFIRM_TICKS    = 2,
    MAINTENANCE_MIN_GAP    = 60,
    MAINTENANCE_DURATION   = 5,      -- ⭐ 5s
    MAX_MAINTENANCE_WAIT   = 600,
}

local isRunning      = false
local stolenPrompts  = {}
local stolenEggUids  = {}
local lastStolenUid  = nil
local lastStolenPos  = nil
local mainThread     = nil
local maintenancePending = false
local lastMaintenanceTime = 0

-- ⭐ Toggle global (menu set qua API)
_G.__eggToggles = _G.__eggToggles or { hatch = true, place = true }

-- ══════════ LOG ══════════
local logs = {}
local function log(t)
    local s = tostring(t)
    table.insert(logs, {text = s, time = os.clock()})
    if #logs > 150 then table.remove(logs, 1) end
    print("[Steal] " .. s)
    if M.onLog then pcall(M.onLog, s) end
end
_G.__stealLog = log

EggCore.onLog = function(msg)
    if _G.__stealLog then pcall(_G.__stealLog, "[Core] " .. msg) end
end

local function getHRP() local c = P.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = P.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function dist(a, b) return (Vector3.new(a.X,a.Y,a.Z) - Vector3.new(b.X,b.Y,b.Z)).Magnitude end

-- ══════════ EGG STATE ══════════
local AssetEarnings, EggState
pcall(function()
    local s = RS:WaitForChild("Shared", 5)
    local u = s and s:FindFirstChild("Util", 5)
    local mod = u and u:FindFirstChild("AssetEarnings", 5)
    if mod then AssetEarnings = require(mod) end
end)
pcall(function()
    local c = RS:WaitForChild("Client", 5)
    if c then
        local mod = c:WaitForChild("EggState", 5)
        if mod then EggState = require(mod) end
    end
end)

-- ══════════ RESET DETECTOR ══════════
local Reset = {
    lastCount      = 0,
    baselineSet    = false,
    consecutiveUp  = 0,
    pending        = false,
    lastDetectTime = 0,
    lastResetCount = 0,
}

local function countServerEggs()
    if not EggState then return -1 end
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then return -1 end
    local c = 0
    for _ in pairs(fd.Records) do c = c + 1 end
    return c
end

local function detectLoop()
    task.wait(3)
    while isRunning do
        task.wait(config.RESET_POLL_INTERVAL)
        if not isRunning then break end

        local c = countServerEggs()
        if c < 0 then goto continue end

        if not Reset.baselineSet then
            Reset.lastCount = c
            Reset.baselineSet = true
            log(string.format("📊 Baseline egg: %d", c))
        else
            local prev = Reset.lastCount
            local delta = c - prev
            local ratio = prev > 0 and (c / prev) or 0

            local grew = delta >= config.RESET_GROWTH_MIN_ABS
                       or ratio >= config.RESET_GROWTH_MIN_RATIO

            if grew then
                Reset.consecutiveUp = Reset.consecutiveUp + 1
                log(string.format("📈 Egg tăng %d→%d (x%.2f) [%d/%d]",
                    prev, c, ratio, Reset.consecutiveUp, config.RESET_CONFIRM_TICKS))

                if Reset.consecutiveUp >= config.RESET_CONFIRM_TICKS then
                    Reset.pending = true
                    Reset.lastDetectTime = os.clock()
                    Reset.lastResetCount = c
                    Reset.consecutiveUp = 0
                    stolenEggUids = {}
                    stolenPrompts = {}
                    maintenancePending = true
                    log(string.format("🌍 SERVER RESET CONFIRMED (%d egg) → queue maintenance", c))
                end
            else
                if Reset.consecutiveUp > 0 then
                    log("↘ Egg không còn tăng → cancel pending")
                end
                Reset.consecutiveUp = 0
            end

            Reset.lastCount = c
        end

        ::continue::
    end
end

-- ══════════ HELPERS ══════════
local function keepHealth()
    local h = getHum()
    if h then pcall(function()
        h.MaxHealth = 99999
        if h.Health < 50000 then h.Health = 99999 end
        h:SetStateEnabled(Enum.HumanoidStateType.Dying, false)
    end) end
end

local function forceRunningState()
    local hum = getHum()
    if hum then pcall(function()
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Physics
            or state == Enum.HumanoidStateType.Ragdoll then return end
        hum.PlatformStand = false
        hum.Sit = false
        if state == Enum.HumanoidStateType.PlatformStanding
            or state == Enum.HumanoidStateType.FallingDown then
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end) end
end

local function freezeAt(position, duration)
    duration = duration or 0.5
    local t0 = os.clock()
    while os.clock() - t0 < duration do
        if not isRunning then return end
        local hum, hrp = getHum(), getHRP()
        if not hum or not hrp then return end
        keepHealth(); forceRunningState()
        pcall(function()
            if position then hrp.CFrame = CFrame.new(position) end
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.02)
    end
end

local function forceTeleHome()
    local r = getHRP()
    if r then pcall(function()
        r.CFrame = CFrame.new(config.HOME_POS)
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end) end
end

local function getSlotSet()
    local set, count = {}, 0
    local folder = W:FindFirstChild("AreaEggSlotsClient")
    if folder then
        for _, d in ipairs(folder:GetChildren()) do
            set[d.Name] = true; count = count + 1
        end
    end
    return set, count
end

local function hasStolenSlot(beforeSet)
    if not beforeSet then return false, nil end
    local now = getSlotSet()
    for name in pairs(beforeSet) do
        if not now[name] then return true, name end
    end
    return false, nil
end

local function getEggRealMap(eggPos)
    local closestMap, closestDist = nil, 999999
    for _, m in ipairs(ALL_MAPS) do
        local d = dist(eggPos, m.pos)
        if d < closestDist then closestMap = m; closestDist = d end
    end
    return closestMap
end

local function getPromptPos(prompt)
    if not prompt or not prompt.Parent then return nil end
    local part = prompt.Parent
    if part:IsA("BasePart") then return part.Position
    elseif part:IsA("Attachment") then return part.WorldPosition
    elseif part.Parent and part.Parent:IsA("BasePart") then return part.Parent.Position end
    return nil
end

local promptCache = { time = 0, data = {} }
local function findPromptSteal(pos, radius)
    radius = radius or config.MAP_RADIUS
    local now = os.clock()
    if now - promptCache.time > 0.5 then
        promptCache.time = now
        promptCache.data = {}
        for _, v in ipairs(W:GetDescendants()) do
            if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                local isEgg = v.Name == "CarryAreaEgg"
                    or ((v.ObjectText or "") == "Egg"
                        and (v.ActionText or ""):lower():find("steal", 1, true))
                if isEgg then
                    local ppos = getPromptPos(v)
                    if ppos then table.insert(promptCache.data, { prompt = v, pos = ppos }) end
                end
            end
        end
    end
    local best, bestDist = nil, radius
    for _, entry in ipairs(promptCache.data) do
        local d = dist(entry.pos, pos)
        if d < bestDist then best, bestDist = entry.prompt, d end
    end
    return best, bestDist
end

local function verifyEggExists(eggPos, radius)
    radius = radius or config.EGG_VERIFY_R or 40
    if EggState then
        local ok, fd = pcall(EggState.ReadFieldEggs)
        if ok and type(fd) == "table" and type(fd.Records) == "table" then
            for uid, ed in pairs(fd.Records) do
                local cf = ed.BoundsCFrame
                if cf then
                    if (cf.Position - eggPos).Magnitude < radius and not stolenEggUids[uid] then
                        return true
                    end
                end
            end
        end
    end
    if findPromptSteal(eggPos, radius) then return true end
    return false
end

local function isCarryingEggStrict()
    if not EggState then return false end
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then return false end
    for _, eggData in pairs(fd.Records) do
        local state = tostring(eggData.State or ""):lower()
        if state == "carried" or state == "carry" or state == "carrying"
            or state == "held" or state == "picked" then return true end
    end
    return false
end

local function isEggStillOnMap(uid, originalPos)
    if not uid then return false, "no-uid" end
    if EggState then
        local ok, fd = pcall(EggState.ReadFieldEggs)
        if ok and type(fd) == "table" and type(fd.Records) == "table" then
            local eggData = fd.Records[uid]
            if not eggData then return false, "not-in-records" end
            local state = tostring(eggData.State or ""):lower()
            if state == "collected" or state == "stored" or state == "owned"
                or state == "sold" then return false, "collected" end
            if eggData.BoundsCFrame then return true, "in-records" end
        end
    end
    if originalPos then
        for _, v in ipairs(W:GetDescendants()) do
            if v:IsA("ProximityPrompt") and v.Enabled then
                local isEggSteal = v.Name == "CarryAreaEgg"
                    or ((v.ObjectText or "") == "Egg"
                        and (v.ActionText or ""):lower():find("steal", 1, true))
                if isEggSteal then
                    local ppos = getPromptPos(v)
                    if ppos and (ppos - originalPos).Magnitude < 100 then
                        return true, "prompt-near"
                    end
                end
            end
        end
    end
    return false, "not-found"
end

-- ══════════ PICK EGG ══════════
local function findBiggestEgg()
    if not EggState then return nil, nil, nil, nil, nil end
    local candidates = {}
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then return nil, nil, nil, nil, nil end
    for uid, eggData in pairs(fd.Records) do
        if not stolenEggUids[uid] then
            local cf = eggData.BoundsCFrame
            if cf then
                local pos = cf.Position
                if dist(pos, config.HOME_POS) > 100 then
                    local st = tostring(eggData.State or ""):lower()
                    local isCarry = st == "carried" or st == "carry" or st == "carrying"
                        or st == "held" or st == "picked" or st == "pickedup"
                        or st == "inventory" or st == "stored"
                    if not isCarry then
                        local bs = eggData.BoundsSize
                        local avgSize = bs and ((bs.X + bs.Y + bs.Z) / 3) or (3.5 * (eggData.AssetScale or 1))
                        local scale = eggData.AssetScale or 1
                        if avgSize >= (config.BIG_EGG_MIN_SIZE or 0)
                            and scale >= (config.BIG_EGG_MIN_SCALE or 0) then
                            local nearestMap, nearestDist = nil, 99999
                            for _, m in ipairs(ALL_MAPS) do
                                local d = dist(pos, m.pos)
                                if d < nearestDist then nearestMap = m; nearestDist = d end
                            end
                            if nearestMap then
                                table.insert(candidates, {
                                    uid = uid, pos = pos, scale = scale, avgSize = avgSize,
                                    map = nearestMap, category = eggData.AssetCategory,
                                    dFromHome = dist(pos, config.HOME_POS),
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    if #candidates == 0 then return nil, nil, nil, nil, nil end
    table.sort(candidates, function(a, b)
        if math.abs(a.avgSize - b.avgSize) > 0.5 then return a.avgSize > b.avgSize end
        if math.abs(a.scale - b.scale) > 0.1 then return a.scale > b.scale end
        return a.dFromHome < b.dFromHome
    end)
    for i = 1, #candidates do
        local c = candidates[i]
        if verifyEggExists(c.pos, 80) then
            local prompt, bestDist = nil, 30
            for _, v in ipairs(W:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                    local isEgg = v.Name == "CarryAreaEgg"
                        or ((v.ObjectText or "") == "Egg"
                            and (v.ActionText or ""):lower():find("steal", 1, true))
                    if isEgg then
                        local ppos = getPromptPos(v)
                        if ppos and (ppos - c.pos).Magnitude < bestDist then
                            prompt = v; bestDist = (ppos - c.pos).Magnitude
                        end
                    end
                end
            end
            if prompt then return prompt, c.pos, c.scale, c.map, c.uid end
        end
    end
    return nil, nil, nil, nil, nil
end

local function findHighestIncomeEgg()
    if not EggState or not AssetEarnings then return nil, nil, nil, nil, nil end
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then return nil, nil, nil, nil, nil end
    local candidates = {}
    local threshold = config.PRIORITY_THRESHOLD or 0
    for uid, eggData in pairs(fd.Records) do
        if not stolenEggUids[uid] then
            local cf = eggData.BoundsCFrame
            if cf then
                local pos = cf.Position
                if dist(pos, config.HOME_POS) > 100 then
                    local st = tostring(eggData.State or ""):lower()
                    if st ~= "carried" and st ~= "carry" and st ~= "carrying" then
                        local input = { Category = eggData.AssetCategory, Scale = eggData.AssetScale or 1, Mutations = eggData.Mutations or {} }
                        local income = 0
                        local ok2, val = pcall(AssetEarnings.LiveRatePerSecond, input)
                        if ok2 and type(val) == "number" and val > 0 then income = val end
                        if income == 0 then
                            ok2, val = pcall(AssetEarnings.RatePerSecond, input)
                            if ok2 and type(val) == "number" and val > 0 then income = val end
                        end
                        if income >= threshold then
                            local nearestMap, nearestDist = nil, 99999
                            for _, m in ipairs(ALL_MAPS) do
                                local d = dist(pos, m.pos)
                                if d < nearestDist then nearestMap = m; nearestDist = d end
                            end
                            if nearestMap then
                                table.insert(candidates, { uid = uid, pos = pos, income = income, map = nearestMap, category = eggData.AssetCategory })
                            end
                        end
                    end
                end
            end
        end
    end
    if #candidates == 0 then return nil, nil, nil, nil, nil end
    table.sort(candidates, function(a, b) return a.income > b.income end)
    for i = 1, #candidates do
        local c = candidates[i]
        if verifyEggExists(c.pos, config.EGG_VERIFY_R or 40) then
            local prompt, bestDist = nil, 20
            for _, v in ipairs(W:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                    local isEgg = v.Name == "CarryAreaEgg"
                        or ((v.ObjectText or "") == "Egg"
                            and (v.ActionText or ""):lower():find("steal", 1, true))
                    if isEgg then
                        local ppos = getPromptPos(v)
                        if ppos and (ppos - c.pos).Magnitude < bestDist then
                            prompt = v; bestDist = (ppos - c.pos).Magnitude
                        end
                    end
                end
            end
            return prompt, c.pos, c.income, c.map, c.uid
        else
            if c.uid then stolenEggUids[c.uid] = true end
        end
    end
    return nil, nil, nil, nil, nil
end

local function findEggInTargets()
    if not config.TARGETS or #config.TARGETS == 0 then return findBiggestEgg() end
    local hrp = getHRP()
    if not hrp then return nil, nil, nil, nil, nil end
    local candidates = {}
    for _, v in ipairs(W:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg"
                    and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEgg then
                local ppos = getPromptPos(v)
                if ppos then
                    local realMap = getEggRealMap(ppos)
                    if realMap then
                        for _, tgt in ipairs(config.TARGETS) do
                            if tgt.name == realMap.name then
                                table.insert(candidates, { prompt = v, pos = ppos, map = realMap,
                                    dFromPlayer = dist(ppos, hrp.Position),
                                    dFromHome = dist(realMap.pos, config.HOME_POS) })
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    if #candidates == 0 then return findBiggestEgg() end
    if config.PREFER_FAR then
        table.sort(candidates, function(a, b) return a.dFromHome > b.dFromHome end)
    else
        table.sort(candidates, function(a, b) return a.dFromPlayer < b.dFromPlayer end)
    end
    local best = candidates[1]
    return best.prompt, best.pos, 1, best.map, nil
end

local function findForestEggOnly()
    local forestMap = nil
    for _, m in ipairs(ALL_MAPS) do
        if m.name == "Forest" then forestMap = m; break end
    end
    if not forestMap then return nil, nil end
    local best, bestPos, bestDist = nil, nil, config.FOREST_RADIUS
    for _, v in ipairs(W:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg"
                    and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEgg then
                local ppos = getPromptPos(v)
                if ppos then
                    local dToForest = dist(ppos, forestMap.pos)
                    if dToForest < config.FOREST_RADIUS and dToForest < bestDist then
                        best, bestPos, bestDist = v, ppos, dToForest
                    end
                end
            end
        end
    end
    return best, bestPos
end

-- ══════════ REBUILD ══════════
local function rebuildCharacterFull()
    local c = P.Character
    if not c then return false end
    local oldHum = c:FindFirstChildOfClass("Humanoid")
    local sHH, sJP = 2, 50
    local sMH, sH = 100, 100
    local sRig = Enum.HumanoidRigType.R15
    if oldHum then
        sHH = oldHum.HipHeight; sJP = oldHum.JumpPower
        sMH = oldHum.MaxHealth; sH = oldHum.Health
        sRig = oldHum.RigType
        pcall(function() oldHum:Destroy() end)
    end
    local nh = Instance.new("Humanoid")
    nh.Parent = c
    pcall(function()
        nh.HipHeight = sHH; nh.JumpPower = sJP
        nh.MaxHealth = sMH; nh.Health = sH
        nh.WalkSpeed = 60; nh.RigType = sRig
        nh.MaxSlopeAngle = 89; nh.AutoRotate = true
        nh.BreakJointsOnDeath = false
        nh:SetStateEnabled(Enum.HumanoidStateType.Dying, false)
        nh:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        nh:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        nh:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
        nh:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
        nh:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        nh:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end)
    pcall(function()
        local oa = nh:FindFirstChildOfClass("Animator")
        if oa then oa:Destroy() end
        local a = Instance.new("Animator"); a.Parent = nh
    end)
    pcall(function()
        local isR15 = (nh.RigType == Enum.HumanoidRigType.R15)
        local anim = nh:FindFirstChildOfClass("Animator")
        if not anim then return end
        local ids = isR15 and {
            "rbxassetid://507766666","rbxassetid://507766951","rbxassetid://507777826",
            "rbxassetid://507767714","rbxassetid://507765000","rbxassetid://507767968",
            "rbxassetid://507765644","rbxassetid://507784897","rbxassetid://507785072",
        } or {
            "rbxassetid://180435571","rbxassetid://180435792","rbxassetid://180426354",
            "rbxassetid://125750702","rbxassetid://180436148","rbxassetid://180436334",
            "rbxassetid://182393478",
        }
        for _, id in ipairs(ids) do
            pcall(function()
                local a = Instance.new("Animation"); a.AnimationId = id
                anim:LoadAnimation(a)
            end)
        end
    end)
    pcall(function()
        local old = c:FindFirstChild("Animate")
        if old then old:Destroy() end
        task.wait(0.05)
        local st = StarterPlayer:FindFirstChild("StarterCharacterScripts")
        if st then
            local tpl = st:FindFirstChild("Animate")
            if tpl then
                local new = tpl:Clone(); new.Parent = c; new.Disabled = false
                return
            end
        end
    end)
    task.wait(0.1)
    local cam = W.CurrentCamera
    if cam then
        pcall(function()
            cam.CameraSubject = nh
            cam.CameraType = Enum.CameraType.Custom
        end)
    end
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.LocalTransparencyModifier = 0 end)
        elseif part:IsA("Decal") or part:IsA("Texture") then
            pcall(function() part.Transparency = 0 end)
        end
    end
    task.wait(0.1)
    pcall(function() nh:ChangeState(Enum.HumanoidStateType.Running) end)
    return true
end

-- ══════════ MOVEMENT ══════════
local function teleToMapStable(targetPos)
    for attempt = 1, 3 do
        local hrp = getHRP()
        if hrp then pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end) end
        task.wait(0.05)
        local safePos = targetPos + Vector3.new(0, 8, 0)
        for i = 1, 6 do
            if not isRunning then return false end
            local r = getHRP()
            if r then pcall(function()
                r.CFrame = CFrame.new(safePos)
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
            end) end
            task.wait(0.03)
        end
        freezeAt(safePos, 0.3)
        local rCheck = getHRP()
        if rCheck then
            if dist(rCheck.Position, safePos) > 50 then
                task.wait(0.2)
            else
                local t0 = os.clock()
                while os.clock() - t0 < 2.5 do
                    if not isRunning then return false end
                    local h, r = getHum(), getHRP()
                    if not h or not r then break end
                    keepHealth(); forceRunningState()
                    if dist(r.Position, targetPos) < 5 then break end
                    pcall(function()
                        local dir = targetPos - r.Position
                        local horiz = Vector3.new(dir.X, 0, dir.Z)
                        if horiz.Magnitude > 0.1 then
                            local nrm = horiz.Unit
                            r.AssemblyLinearVelocity = Vector3.new(
                                nrm.X * math.min(50, horiz.Magnitude * 3), -40,
                                nrm.Z * math.min(50, horiz.Magnitude * 3))
                        else
                            r.AssemblyLinearVelocity = Vector3.new(0, -40, 0)
                        end
                    end)
                    task.wait(0.02)
                end
                freezeAt(targetPos, config.TELE_HOLD or 0.3)
                local rF = getHRP()
                if rF and dist(rF.Position, targetPos) < 100 then return true end
                task.wait(0.3)
            end
        end
    end
    return false
end

local function firePromptOnce(prompt)
    if not prompt or not prompt.Parent then return false end
    pcall(function()
        prompt.Enabled = true
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 999
        prompt.RequiresLineOfSight = false
    end)
    if type(fireproximityprompt) == "function" then pcall(fireproximityprompt, prompt) end
    pcall(function()
        prompt:InputHoldBegin(); task.wait(0.02); prompt:InputHoldEnd()
    end)
    pcall(function()
        prompt.PromptButtonHoldBegan:Fire()
        task.wait(0.02)
        prompt.PromptButtonHoldEnded:Fire()
        prompt.Triggered:Fire(P)
    end)
    return true
end

local function velocityMoveTo(targetPos, timeout, speed, manual)
    timeout = timeout or 20
    speed = speed or math.min(config.SPEED / 2.5, config.SPEED_CAP)
    local hum, hrp = getHum(), getHRP()
    if not hum or not hrp then return false end
    keepHealth()
    local t0 = os.clock()
    local lastPos = hrp.Position
    local stuckTime = os.clock()
    while os.clock() - t0 < timeout do
        if not manual and not isRunning then break end
        hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth(); forceRunningState()
        if dist(hrp.Position, targetPos) < config.ARRIVE_DIST then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            return true
        end
        pcall(function()
            local dir = targetPos - hrp.Position
            if dir.Magnitude > 0 then
                local nrm = dir.Unit
                hrp.AssemblyLinearVelocity = Vector3.new(nrm.X * speed, hrp.AssemblyLinearVelocity.Y, nrm.Z * speed)
            end
        end)
        if dist(hrp.Position, lastPos) < 0.3 then
            if os.clock() - stuckTime > 0.8 then
                pcall(function() hum.Jump = true end)
                stuckTime = os.clock()
            end
        else
            lastPos = hrp.Position; stuckTime = os.clock()
        end
        task.wait(0.01)
    end
    pcall(function() local r = getHRP(); if r then r.AssemblyLinearVelocity = Vector3.zero end end)
    return false
end

local function velocityFlyTo(targetPos, timeout, speed)
    timeout = timeout or 20
    speed = speed or config.FLY_HOME_SPEED or 500
    local hum, hrp = getHum(), getHRP()
    if not hum or not hrp then return false end
    keepHealth()
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth(); forceRunningState()
        if dist(hrp.Position, targetPos) < config.ARRIVE_DIST then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            return true
        end
        pcall(function()
            local dir = targetPos - hrp.Position
            if dir.Magnitude > 0 then hrp.AssemblyLinearVelocity = dir.Unit * speed end
        end)
        task.wait(0.01)
    end
    return false
end

local function runToForest()
    log("🏃 Chạy ra Forest")
    local t0 = os.clock()
    local lastPos, stuckCount, arrived = nil, 0, false
    local ARRIVE = config.ARRIVE_DIST + 15
    while isRunning and os.clock() - t0 < config.FOREST_RUN_TIMEOUT do
        local hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth(); forceRunningState()
        local d = dist(hrp.Position, config.FOREST_POS)
        if d < ARRIVE then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
            arrived = true; break
        end
        local speed = config.FOREST_RUN_SPEED
        if d < 60 then speed = math.max(20, config.FOREST_RUN_SPEED * (d / 60)) end
        pcall(function()
            local dir = config.FOREST_POS - hrp.Position
            if dir.Magnitude > 0.1 then
                local nrm = dir.Unit
                hrp.AssemblyLinearVelocity = Vector3.new(nrm.X * speed, 0, nrm.Z * speed)
            end
        end)
        if lastPos then
            if dist(hrp.Position, lastPos) < 1 then
                stuckCount = stuckCount + 1
                if stuckCount > 20 then
                    pcall(function() hum.Jump = true end)
                    stuckCount = 0
                end
            else stuckCount = 0 end
        end
        lastPos = hrp.Position
        task.wait(0.01)
    end
    if not arrived then log("⚠ Timeout Forest"); return false end
    freezeAt(nil, config.FOREST_WARMUP or 0.3)
    return true
end

local function goHome()
    log("🏃 Bay về home")
    local flyY = config.HOME_FLY_ABSOLUTE_Y or 100
    local t1 = os.clock()
    while os.clock() - t1 < 20 do
        if not isRunning then return false end
        local hum, r = getHum(), getHRP()
        if not hum or not r then break end
        keepHealth(); forceRunningState()
        if r.Position.Y < 10 then forceTeleHome(); break end
        local dx = config.HOME_POS.X - r.Position.X
        local dz = config.HOME_POS.Z - r.Position.Z
        if math.sqrt(dx*dx + dz*dz) < 30 then break end
        pcall(function()
            local tgt = Vector3.new(config.HOME_POS.X, flyY, config.HOME_POS.Z)
            local dir = tgt - r.Position
            if dir.Magnitude > 0 then
                r.AssemblyLinearVelocity = dir.Unit * (config.FLY_HOME_SPEED or 500)
            end
        end)
        task.wait(0.01)
    end
    velocityFlyTo(config.HOME_POS, 8, config.DROP_SPEED or 250)
    freezeAt(config.HOME_POS, 0.4)
    rebuildCharacterFull()
    freezeAt(config.HOME_POS, 0.3)
    local rE = getHRP()
    if rE then pcall(function()
        rE.AssemblyLinearVelocity = Vector3.zero
        rE.AssemblyAngularVelocity = Vector3.zero
    end) end
    forceRunningState()
    return true
end

local function baitBoss(timeout)
    timeout = timeout or config.BAIT_TIMEOUT
    log("🎯 Bait boss...")
    freezeAt(nil, config.BAIT_WARMUP or 0.3)
    forceRunningState()
    task.wait(0.3)
    local h0, r0 = getHum(), getHRP()
    if not h0 or not r0 then return false end
    local sh = h0.Health
    local sp = r0.Position
    local sc = r0.CFrame
    local t0 = os.clock()
    while isRunning and os.clock() - t0 < timeout do
        local hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth()
        local vel = hrp.AssemblyLinearVelocity
        local speed = vel.Magnitude
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Physics and speed > (config.KB_SPEED_PHYSICS or 50) then
            log("💥 KB (physics)"); return true end
        if speed > (config.KB_SPEED_VELOCITY or 80) and vel.Y > (config.KB_VELY_MIN or 20) then
            log("💥 KB (velocity)"); return true end
        if state == Enum.HumanoidStateType.PlatformStanding
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Ragdoll then
            log("💥 KB (state)"); return true end
        if hum.Health < sh - (config.KB_HEALTH_DROP or 0.1) then
            log("💥 KB (health)"); return true end
        if (hrp.Position - sp).Magnitude > (config.KB_SHIFT_MIN or 30) then
            log("💥 KB (shift)"); return true end
        local dot = math.clamp(sc.LookVector:Dot(hrp.CFrame.LookVector), -1, 1)
        if math.deg(math.acos(dot)) > (config.KB_ROTATE_MIN or 90) then
            log("💥 KB (rotate)"); return true end
        pcall(function() hum:MoveTo(hrp.Position) end)
        task.wait(0.01)
    end
    return false
end

local function stealAtPos(targetPos, label, eggUid)
    log("STEAL TẠI " .. label)
    local hrp = getHRP()
    if not hrp then return false end
    local d = dist(hrp.Position, targetPos)
    if d > 200 then
        if not teleToMapStable(targetPos) then return false end
        hrp = getHRP()
        if not hrp or dist(hrp.Position, targetPos) > 200 then return false end
    end
    if dist(hrp.Position, targetPos) > config.ARRIVE_DIST then
        velocityFlyTo(targetPos, 3, 600)
    end
    local slotsBefore, _ = getSlotSet()
    for i = 1, config.MAX_FIRES do
        if not isRunning then return false end
        forceRunningState()
        local h2 = getHRP()
        if not h2 then break end
        local p2 = findPromptSteal(h2.Position, 150)
        if not p2 then break end
        local p2pos = getPromptPos(p2)
        if not p2pos then break end
        if dist(h2.Position, p2pos) > config.PROMPT_NEAR then
            velocityMoveTo(p2pos, 3, nil, true)
            p2 = findPromptSteal(h2.Position, 150)
            if not p2 then break end
        end
        firePromptOnce(p2)
        local vS = os.clock()
        local stolen, sN = false, nil
        while os.clock() - vS < config.STEAL_TIMEOUT do
            task.wait(0.15)
            local s, sn = hasStolenSlot(slotsBefore)
            if s then stolen = true; sN = sn; break end
            if isCarryingEggStrict() then
                task.wait(0.2)
                if isCarryingEggStrict() then stolen = true; sN = "carry"; break end
            end
        end
        if stolen then
            log("✅ Steal OK (" .. tostring(sN) .. ")")
            if eggUid then lastStolenUid = eggUid end
            lastStolenPos = targetPos
            return true
        end
    end
    log("⚠ Steal fail")
    return false
end

local function stealAtForest()
    local prompt, ppos = findForestEggOnly()
    if not prompt or not ppos then return false, "no-egg" end
    log(string.format("🎯 Forest @ %.1f,%.1f,%.1f", ppos.X, ppos.Y, ppos.Z))

    local hrp = getHRP()
    if hrp and dist(hrp.Position, ppos) > config.ARRIVE_DIST then
        velocityMoveTo(ppos, 15)
    end

    local fBefore = getSlotSet()
    for i = 1, 5 do
        if not isRunning then break end
        local hum = getHum()
        local h2 = getHRP()
        if hum and h2 then
            local state = hum:GetState()
            local speed = h2.AssemblyLinearVelocity.Magnitude
            local velY = h2.AssemblyLinearVelocity.Y
            if state == Enum.HumanoidStateType.Physics
                or state == Enum.HumanoidStateType.Ragdoll
                or state == Enum.HumanoidStateType.PlatformStanding
                or state == Enum.HumanoidStateType.FallingDown then
                log("💥 Boss đánh (state)"); return false, "hit-by-boss"
            end
            if speed > (config.FOREST_HIT_SPEED or 60) or velY > (config.FOREST_HIT_VELY or 15) then
                log("💥 Boss đánh (velocity)"); return false, "hit-by-boss"
            end
        end
        forceRunningState()
        h2 = getHRP()
        if h2 then
            local p2 = findPromptSteal(h2.Position, config.FOREST_RADIUS)
            if p2 then
                local p2pos = getPromptPos(p2)
                if p2pos and dist(h2.Position, p2pos) > config.PROMPT_NEAR then
                    velocityMoveTo(p2pos, 3, nil, true)
                end
                firePromptOnce(p2)
            end
        end
        task.wait(0.5)
        local st, sN = hasStolenSlot(fBefore)
        if st then
            log("🎒 Forest OK (" .. sN .. ")")
            stolenPrompts[prompt] = true
            return true, "stolen"
        end
    end
    task.wait(1)
    if isCarryingEggStrict() then
        log("🎒 Forest OK (carry)")
        stolenPrompts[prompt] = true
        return true, "stolen"
    end
    return false, "no-steal"
end

local function pickNextEgg()
    if config.PRIORITY_INCOME and config.BIG_EGG_MODE then
        log("🎯 Dual mode")
        local minInc = config.DUAL_MIN_INCOME or 30000000
        local minSize = config.DUAL_MIN_SIZE or 4.0
        if not EggState or not AssetEarnings then return findEggInTargets() end
        local ok, fd = pcall(EggState.ReadFieldEggs)
        if ok and type(fd) == "table" and type(fd.Records) == "table" then
            local best = nil
            for uid, ed in pairs(fd.Records) do
                if not stolenEggUids[uid] then
                    local cf = ed.BoundsCFrame
                    if cf then
                        local pos = cf.Position
                        if dist(pos, config.HOME_POS) > 100 then
                            local st = tostring(ed.State or ""):lower()
                            if st ~= "carried" and st ~= "carry" and st ~= "carrying" then
                                local input = { Category = ed.AssetCategory, Scale = ed.AssetScale or 1, Mutations = ed.Mutations or {} }
                                local inc = 0
                                local ok2, val = pcall(AssetEarnings.LiveRatePerSecond, input)
                                if ok2 and type(val) == "number" and val > 0 then inc = val end
                                if inc == 0 then
                                    ok2, val = pcall(AssetEarnings.RatePerSecond, input)
                                    if ok2 and type(val) == "number" and val > 0 then inc = val end
                                end
                                if inc >= minInc then
                                    local bs = ed.BoundsSize
                                    local size = bs and ((bs.X + bs.Y + bs.Z) / 3) or 0
                                    if size >= minSize then
                                        if not best or inc > best.income then
                                            local nm, nd = nil, 99999
                                            for _, m in ipairs(ALL_MAPS) do
                                                local dd = dist(pos, m.pos)
                                                if dd < nd then nm = m; nd = dd end
                                            end
                                            if nm then
                                                best = { uid = uid, pos = pos, income = inc, size = size, map = nm, category = ed.AssetCategory }
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if best then
                log(string.format("✅ Dual: %s @ %s", best.category, best.map.name))
                local prompt, bd = nil, 20
                for _, v in ipairs(W:GetDescendants()) do
                    if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                        local isEgg = v.Name == "CarryAreaEgg"
                            or ((v.ObjectText or "") == "Egg"
                                and (v.ActionText or ""):lower():find("steal", 1, true))
                        if isEgg then
                            local pp = getPromptPos(v)
                            if pp and (pp - best.pos).Magnitude < bd then
                                prompt = v; bd = (pp - best.pos).Magnitude
                            end
                        end
                    end
                end
                if verifyEggExists(best.pos, config.EGG_VERIFY_R or 40) then
                    return prompt, best.pos, best.income, best.map, best.uid
                else
                    if best.uid then stolenEggUids[best.uid] = true end
                end
            end
        end
        return findEggInTargets()
    end
    if config.BIG_EGG_MODE then
        log("🥚 Big Egg")
        local p, pos, s, m, u = findBiggestEgg()
        if not pos then return findEggInTargets() end
        return p, pos, s, m, u
    elseif config.PRIORITY_INCOME then
        log("💰 Priority Income")
        local p, pos, s, m, u = findHighestIncomeEgg()
        if not pos then return findEggInTargets() end
        return p, pos, s, m, u
    else
        log("🎯 Target mode")
        return findEggInTargets()
    end
end

-- ══════════ MAINTENANCE ══════════
local function doMaintenance()
    -- Skip nếu cả 2 toggle tắt
    local tg = _G.__eggToggles or { hatch = true, place = true }
    if not tg.hatch and not tg.place then
        log("⏭ Cả Hatch và Place đều OFF → skip maintenance")
        maintenancePending = false
        lastMaintenanceTime = os.clock()
        return
    end

    if EggCore.busy then return end
    log("🛠️ MAINTENANCE (server reset)")
    maintenancePending = false
    lastMaintenanceTime = os.clock()

    local hrp = getHRP()
    if hrp and dist(hrp.Position, config.HOME_POS) > 100 then
        forceTeleHome()
        freezeAt(config.HOME_POS, 0.5)
    end
    freezeAt(config.HOME_POS, 0.3)

    EggCore.maintain(config.MAINTENANCE_DURATION)
end

-- ══════════ MAIN LOOP ══════════
local function mainLoop()
    task.spawn(detectLoop)

    Reset.baselineSet = false
    Reset.consecutiveUp = 0
    Reset.pending = false
    lastMaintenanceTime = os.clock()

    task.wait(2)
    if isRunning then
        -- Skip nếu vừa maintain < 30s
        local sinceLast = os.clock() - (_G.__eggLastMaintain or 0)
        if sinceLast > 30 then
            log("▶ Maintenance đầu phiên")
            doMaintenance()
        else
            log(string.format("⏭ Skip maintenance đầu (vừa chạy %.0fs trước)", sinceLast))
            lastMaintenanceTime = os.clock()
        end
    end

    while isRunning do
        -- Check pending maintenance
        if maintenancePending then
            local gap = os.clock() - lastMaintenanceTime
            if gap >= config.MAINTENANCE_MIN_GAP then
                doMaintenance()
                if not isRunning then break end
                task.wait(0.5)
            else
                log(string.format("⏳ Chờ %.1fs nữa", config.MAINTENANCE_MIN_GAP - gap))
                maintenancePending = false
            end
        end

        -- Safety timer
        if os.clock() - lastMaintenanceTime > config.MAX_MAINTENANCE_WAIT then
            log("⏰ Safety timer → force maintenance")
            doMaintenance()
            if not isRunning then break end
        end

        local cycleT0 = os.clock()
        log("═══════════════════")
        log("🔄 CYCLE MỚI")

        -- ACQUIRE LOCK
        if not EggCore.acquireLock("steal", 60) then
            log("❌ Không lấy được lock steal — chờ 2s")
            task.wait(2)
            goto continue_loop
        end

        local gotKB, skipCycle = false, false

        log("▶ [1/6] Ra Forest...")
        if not runToForest() then
            task.wait(2); skipCycle = true
        end

        if not skipCycle then
            log("▶ [2/6] Steal Forest...")
            local fOk, fRea = stealAtForest()
            if fRea == "hit-by-boss" then
                gotKB = true
            elseif not fOk then
                goHome(); task.wait(config.WAIT_BETWEEN); skipCycle = true
            else
                log("▶ [3/6] Bait boss...")
                gotKB = baitBoss(config.BAIT_TIMEOUT)
                if not gotKB then
                    goHome(); task.wait(config.WAIT_BETWEEN); skipCycle = true
                end
            end
        end

        if not skipCycle and gotKB then
            log("▶ [4/6] Rebuild...")
            rebuildCharacterFull()
            task.wait(0.2)
            pcall(function()
                local r = getHRP()
                if r then
                    r.AssemblyLinearVelocity = Vector3.zero
                    r.AssemblyAngularVelocity = Vector3.zero
                end
            end)

            -- Check maintenance giữa cycle
            if maintenancePending and (os.clock() - lastMaintenanceTime >= config.MAINTENANCE_MIN_GAP) then
                EggCore.releaseLock("steal")
                doMaintenance()
                if not isRunning then break end
                EggCore.acquireLock("steal", 60)
            end

            log("▶ [5/6] Pick + tele + steal...")
            local eP, ePos, eD, eMap, eUid = pickNextEgg()
            if not ePos then
                goHome(); task.wait(config.WAIT_BETWEEN)
            else
                log(string.format("   🎯 %s @ %s", eMap and eMap.name or "?", tostring(eUid)))
                local tPos = ePos + Vector3.new(0, 3, 0)
                teleToMapStable(tPos)
                task.wait(config.TELE_STABILIZE or 0.2)
                local st = stealAtPos(ePos, eMap and eMap.name or "?", eUid)

                if st then
                    log("▶ [6/6] Về home...")
                    goHome()
                    task.wait(config.CHAT_WAIT)
                    if lastStolenUid then
                        local stillOn, _ = isEggStillOnMap(lastStolenUid, lastStolenPos)
                        if not stillOn then stolenEggUids[lastStolenUid] = true end
                        lastStolenUid = nil; lastStolenPos = nil
                    end
                    log("🎉 CYCLE XONG")
                else
                    task.wait(0.3)
                    local hc = getHRP()
                    if hc and dist(hc.Position, ePos) < 200 then
                        stealAtPos(ePos, eMap and eMap.name or "?", eUid)
                    else
                        teleToMapStable(tPos); task.wait(0.3)
                        stealAtPos(ePos, eMap and eMap.name or "?", eUid)
                    end
                    goHome(); task.wait(config.CHAT_WAIT)
                end
            end
        end

        -- RELEASE LOCK
        EggCore.releaseLock("steal")

        log(string.format("⏱ Cycle: %.1fs", os.clock() - cycleT0))
        if not isRunning then break end
        task.wait(0.3)

        ::continue_loop::
    end
end

-- ══════════ BYPASS ══════════
local bypassInstalled = false
local function installBypass()
    if bypassInstalled then return end
    bypassInstalled = true
    pcall(function()
        ProximityPromptSvc.PromptShown:Connect(function(prompt)
            pcall(function() prompt.HoldDuration = 0 end)
        end)
    end)
end

-- ══════════ API ══════════
function M.start()
    if mainThread then
        pcall(function() task.cancel(mainThread) end)
        mainThread = nil
    end
    if isRunning then
        isRunning = false
        task.wait(0.5)
    end
    installBypass()
    stolenPrompts = {}; stolenEggUids = {}
    lastStolenUid = nil; lastStolenPos = nil
    maintenancePending = false
    pcall(function()
        local hrp = getHRP()
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        forceRunningState()
    end)
    task.wait(0.2)
    isRunning = true
    log("▶ START v13.0 (detect reset → place+hatch 5s)")
    log(string.format("   Poll: %ds | Maintenance: %ds | Place trước → Hatch sau",
        config.RESET_POLL_INTERVAL, config.MAINTENANCE_DURATION))
    log(string.format("   Toggle: Hatch=%s | Place=%s",
        _G.__eggToggles.hatch and "ON" or "OFF",
        _G.__eggToggles.place and "ON" or "OFF"))
    mainThread = task.spawn(mainLoop)
end

function M.stop()
    isRunning = false
    maintenancePending = false
    if mainThread then
        pcall(function() task.cancel(mainThread) end)
        mainThread = nil
    end
    pcall(function()
        local hrp = getHRP()
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    if EggCore and EggCore.releaseLock then
        pcall(function() EggCore.releaseLock("steal") end)
    end
    log("■ STOP")
end

function M.isRunning() return isRunning end
function M.setTargets(list) if type(list) == "table" then config.TARGETS = list end end
function M.setTarget(name, pos) config.TARGETS = { { name = name, pos = pos } } end
function M.setPriorityIncome(e)
    config.PRIORITY_INCOME = e and true or false
    log("💰 Priority: " .. (config.PRIORITY_INCOME and "ON" or "OFF"))
    if not config.PRIORITY_INCOME then stolenEggUids = {}; stolenPrompts = {} end
    return config.PRIORITY_INCOME
end
function M.setBigEggMode(e)
    config.BIG_EGG_MODE = e and true or false
    log("🥚 BigEgg: " .. (config.BIG_EGG_MODE and "ON" or "OFF"))
    if not config.BIG_EGG_MODE then stolenEggUids = {}; stolenPrompts = {} end
    return config.BIG_EGG_MODE
end
function M.setPriorityThreshold(a) config.PRIORITY_THRESHOLD = a or 1000000 end
function M.setHome(p) if p then config.HOME_POS = p end end
function M.setForest(p) if p then config.FOREST_POS = p end end
function M.setForestRunSpeed(n) config.FOREST_RUN_SPEED = n or 250 end
function M.setBaitTimeout(n) config.BAIT_TIMEOUT = n or 15 end
function M.setForestWarmup(n) config.FOREST_WARMUP = n or 0.3 end
function M.setBaitWarmup(n) config.BAIT_WARMUP = n or 0.3 end
function M.setTeleHold(n) config.TELE_HOLD = n or 0.3 end
function M.getConfig() return config end
function M.getAllMaps() return ALL_MAPS end
function M.clearStolenUids() stolenEggUids = {}; stolenPrompts = {}; log("🔄 Clear UIDs") end
function M.getStolenCount() local c = 0; for _ in pairs(stolenEggUids) do c = c + 1 end; return c end
function M.getStolenUids() return stolenEggUids end
function M.togglePriorityIncome() return M.setPriorityIncome(not config.PRIORITY_INCOME) end
function M.toggleBigEggMode() return M.setBigEggMode(not config.BIG_EGG_MODE) end
function M.isPriorityIncome() return config.PRIORITY_INCOME end
function M.isBigEggMode() return config.BIG_EGG_MODE end
function M.isDualMode() return config.PRIORITY_INCOME and config.BIG_EGG_MODE end

-- ⭐ Toggle API cho menu
function M.setAutoHatch(enabled)
    _G.__eggToggles.hatch = enabled and true or false
    log("🔥 Auto Hatch: " .. (_G.__eggToggles.hatch and "ON" or "OFF"))
    return _G.__eggToggles.hatch
end

function M.setAutoPlace(enabled)
    _G.__eggToggles.place = enabled and true or false
    log("📦 Auto Place: " .. (_G.__eggToggles.place and "ON" or "OFF"))
    return _G.__eggToggles.place
end

function M.toggleAutoHatch() return M.setAutoHatch(not _G.__eggToggles.hatch) end
function M.toggleAutoPlace() return M.setAutoPlace(not _G.__eggToggles.place) end
function M.isAutoHatchOn() return _G.__eggToggles.hatch end
function M.isAutoPlaceOn()  return _G.__eggToggles.place end
function M.getToggles()
    return {
        hatch = _G.__eggToggles.hatch,
        place = _G.__eggToggles.place,
    }
end

function M.setResetPollInterval(s) config.RESET_POLL_INTERVAL = math.max(5, tonumber(s) or 15) end
function M.setResetGrowthMinAbs(n) config.RESET_GROWTH_MIN_ABS = tonumber(n) or 30 end
function M.setResetGrowthRatio(r) config.RESET_GROWTH_MIN_RATIO = tonumber(r) or 1.3 end
function M.setMaintenanceDuration(s) config.MAINTENANCE_DURATION = math.max(2, tonumber(s) or 5) end
function M.setMaintenanceMinGap(s) config.MAINTENANCE_MIN_GAP = math.max(0, tonumber(s) or 60) end
function M.forceMaintenance() maintenancePending = true end

function M.getNextMaintenanceIn()
    return math.max(0, config.MAX_MAINTENANCE_WAIT - (os.clock() - lastMaintenanceTime))
end

function M.getServerResetInfo()
    return {
        lastCount      = Reset.lastCount,
        baselineSet    = Reset.baselineSet,
        consecutiveUp  = Reset.consecutiveUp,
        pending        = Reset.pending,
        lastDetectTime = Reset.lastDetectTime,
    }
end

function M.hatchAll() return EggCore.hatchAll(30) end
function M.placeAll() return EggCore.placeAll(30) end
function M.requestMaintain(sec) return EggCore.requestMaintain(sec or config.MAINTENANCE_DURATION) end

function M.getStatus()
    return {
        isRunning          = isRunning,
        maintenancePending = maintenancePending,
        nextSafetyIn       = M.getNextMaintenanceIn(),
        serverEggs         = Reset.lastCount,
        consecutiveUp      = Reset.consecutiveUp,
        stolenCount        = M.getStolenCount(),
        bigEggMode         = config.BIG_EGG_MODE,
        priorityIncome     = config.PRIORITY_INCOME,
        dualMode           = config.PRIORITY_INCOME and config.BIG_EGG_MODE,
        autoHatch          = _G.__eggToggles.hatch,
        autoPlace          = _G.__eggToggles.place,
        lockOwner          = EggCore.lockOwner and EggCore.lockOwner() or nil,
        coreStatus         = EggCore.getStatus and EggCore.getStatus() or nil,
    }
end

function M.getLogs()
    local out = {}
    for _, l in ipairs(logs) do
        table.insert(out, string.format("[%.0fs] %s", l.time, l.text))
    end
    return out
end
function M.getLogText() return table.concat(M.getLogs(), "\n") end
function M.clearLogs() logs = {} end

_G.EggSteal = M
warn("[Steal v13.0] Loaded — _G.EggSteal.start()")
return M
