-- ═══════════════════════════════════════════════════════════════
-- STEAL MODULE v10.7.0
-- Flow: Home → Forest → Steal forest → (Boss đánh?) → REBUILD
--       → TELE egg (đứng yên trên cao) → Steal → Về home (đứng yên) → 0.5s → Lặp
-- v10.7.0 FIX:
--   - TELE: chỉ set velocity=0 mỗi frame, KHÔNG set CFrame liên tục → không dựt
--   - VỀ HOME: set CFrame 1 lần, giữ velocity=0 → đứng yên, không rớt
--   - HOME_REST_TIME = 0.5s (thay vì 1s)
--   - Steal Forest check boss INLINE, tele NGAY
--   - Fire prompt burst x5 cực nhanh
-- ═══════════════════════════════════════════════════════════════

local P                  = game:GetService("Players").LocalPlayer
local RS                 = game:GetService("ReplicatedStorage")
local W                  = workspace
local ProximityPromptSvc = game:GetService("ProximityPromptService")
local StarterPlayer      = game:GetService("StarterPlayer")

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
    HOME_TIMEOUT        = 30,

    -- ⭐ v10.7.0: 0.5s nghỉ tại home
    HOME_REST_TIME      = 0.5,

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
    MAX_RETRY      = 3,
    STEAL_VERIFY_WAIT = 0.35,
    STEAL_TIMEOUT  = 1.5,
    CHAT_WAIT      = 1.0,
    EGG_VERIFY_R   = 40,

    STEAL_BURST_COUNT = 5,
    STEAL_BURST_DELAY = 0.01,

    CYCLE_TIMEOUT  = 120,
    WAIT_BETWEEN   = 0.7,

    KB_SPEED_PHYSICS  = 50,
    KB_SPEED_VELOCITY = 80,
    KB_VELY_MIN       = 20,
    KB_SHIFT_MIN      = 30,
    KB_ROTATE_MIN     = 90,

    FOREST_HIT_SPEED  = 20,
    FOREST_HIT_VELY   = 5,
    FOREST_HP_DROP    = 0.01,
}

local isRunning      = false
local stolenPrompts  = {}
local stolenEggUids  = {}
local deliveryFailed = false
local lastEggCount   = -1
local cycleStartTime = 0
local lastStolenUid  = nil
local lastStolenPos  = nil
local mainThread     = nil

local function log(s) end

-- ══════════ HELPERS ══════════
local function getHRP() local c = P.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = P.Character; return c and c:FindFirstChildOfClass("Humanoid") end

local function dist(a, b)
    local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

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
            or state == Enum.HumanoidStateType.Ragdoll then
            return
        end
        hum.PlatformStand = false
        hum.Sit = false
        if state == Enum.HumanoidStateType.PlatformStanding
            or state == Enum.HumanoidStateType.FallingDown then
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end) end
end

-- ⭐ Chỉ dừng velocity, KHÔNG set CFrame
local function hardStop()
    local r = getHRP()
    if r then pcall(function()
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end) end
end

-- ⭐ Giữ velocity = 0 trong N giây (KHÔNG set CFrame → không dựt)
local function holdStill(duration)
    duration = duration or 0.5
    local t0 = os.clock()
    while os.clock() - t0 < duration do
        if not isRunning then return end
        keepHealth()
        hardStop()
        task.wait(0.01)
    end
end

-- ⭐ Freeze vị trí bằng CFrame 1 lần + giữ velocity 0
local function snapTo(pos, holdTime)
    holdTime = holdTime or 0.3
    hardStop()
    task.wait(0.05)

    local r = getHRP()
    if r then pcall(function()
        r.CFrame = CFrame.new(pos)
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end) end

    holdStill(holdTime)
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

-- ══════════ INCOME MODULES ══════════
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
                    if ppos then
                        table.insert(promptCache.data, { prompt = v, pos = ppos })
                    end
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
                    local d = (cf.Position - eggPos).Magnitude
                    if d < radius and not stolenEggUids[uid] then return true end
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
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then
        return false
    end
    for _, eggData in pairs(fd.Records) do
        local state = tostring(eggData.State or ""):lower()
        if state == "carried" or state == "carry" or state == "carrying"
            or state == "held" or state == "picked" then
            return true
        end
    end
    return false
end

local function isCarryingEgg()
    if isCarryingEggStrict() then return true end
    for _, v in ipairs(W:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled then
            local isEggPrompt = v.Name == "CarryAreaEgg" or v.Name == "DropEgg"
            if isEggPrompt then
                local action = tostring(v.ActionText or ""):lower()
                if action == "drop" or action == "thả"
                    or action:find("drop egg", 1, true)
                    or action:find("thả egg", 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

local function isEggStillOnMap(uid, originalPos)
    if not uid then return false, "no-uid" end

    if EggState then
        local ok, fd = pcall(EggState.ReadFieldEggs)
        if ok and type(fd) == "table" and type(fd.Records) == "table" then
            local eggData = fd.Records[uid]
            if not eggData then
                return false, "not-in-records"
            end
            local state = tostring(eggData.State or ""):lower()
            if state == "collected" or state == "stored" or state == "owned"
                or state == "sold" then
                return false, "collected"
            end
            if eggData.BoundsCFrame then
                return true, "in-records"
            end
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
                    if ppos then
                        local d = (ppos - originalPos).Magnitude
                        if d < 100 then
                            return true, "prompt-near"
                        end
                    end
                end
            end
        end
    end
    return false, "not-found"
end

local function findBiggestEgg()
    if not EggState then return nil, nil, nil, nil, nil end
    local candidates = {}
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then
        return nil, nil, nil, nil, nil
    end

    for uid, eggData in pairs(fd.Records) do
        if not stolenEggUids[uid] then
            local cf = eggData.BoundsCFrame
            if cf then
                local pos = cf.Position
                local dHome = dist(pos, config.HOME_POS)
                if dHome > 100 then
                    local st = tostring(eggData.State or ""):lower()
                    local isCarry = st == "carried" or st == "carry" or st == "carrying"
                        or st == "held" or st == "picked" or st == "pickedup"
                        or st == "inventory" or st == "stored"
                    if not isCarry then
                        local bs = eggData.BoundsSize
                        local avgSize = bs and ((bs.X + bs.Y + bs.Z) / 3)
                            or (3.5 * (eggData.AssetScale or 1))
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
                                    uid = uid, pos = pos, scale = scale,
                                    avgSize = avgSize, map = nearestMap,
                                    category = eggData.AssetCategory,
                                    mutation = eggData.BaseMutation,
                                    dFromHome = dHome,
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
        if math.abs(a.avgSize - b.avgSize) > 0.5 then
            return a.avgSize > b.avgSize
        end
        if math.abs(a.scale - b.scale) > 0.1 then
            return a.scale > b.scale
        end
        return a.dFromHome < b.dFromHome
    end)

    for i = 1, #candidates do
        local c = candidates[i]
        if verifyEggExists(c.pos, 80) then
            local prompt = nil
            local bestDist = 30
            for _, v in ipairs(W:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                    local isEgg = v.Name == "CarryAreaEgg"
                        or ((v.ObjectText or "") == "Egg"
                            and (v.ActionText or ""):lower():find("steal", 1, true))
                    if isEgg then
                        local ppos = getPromptPos(v)
                        if ppos then
                            local d = (ppos - c.pos).Magnitude
                            if d < bestDist then prompt = v; bestDist = d end
                        end
                    end
                end
            end
            if prompt then
                return prompt, c.pos, c.scale, c.map, c.uid
            end
        else
            if c.uid then stolenEggUids[c.uid] = true end
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
                                table.insert(candidates, {
                                    uid = uid, pos = pos, income = income, map = nearestMap,
                                    category = eggData.AssetCategory, scale = eggData.AssetScale or 1,
                                })
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
            local prompt = nil
            local bestDist = 20
            for _, v in ipairs(W:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                    local isEgg = v.Name == "CarryAreaEgg"
                        or ((v.ObjectText or "") == "Egg"
                            and (v.ActionText or ""):lower():find("steal", 1, true))
                    if isEgg then
                        local ppos = getPromptPos(v)
                        if ppos then
                            local d = (ppos - c.pos).Magnitude
                            if d < bestDist then prompt = v; bestDist = d end
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
    if not config.TARGETS or #config.TARGETS == 0 then
        return findBiggestEgg()
    end
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
                                table.insert(candidates, {
                                    prompt = v, pos = ppos, map = realMap,
                                    dFromPlayer = dist(ppos, hrp.Position),
                                    dFromHome = dist(realMap.pos, config.HOME_POS),
                                })
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    if #candidates == 0 then
        return findBiggestEgg()
    end
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
    local savedHipHeight, savedJumpPower = 2, 50
    local savedMaxHealth, savedHealth = 100, 100
    local savedRigType = Enum.HumanoidRigType.R15

    if oldHum then
        savedHipHeight = oldHum.HipHeight
        savedJumpPower = oldHum.JumpPower
        savedMaxHealth = oldHum.MaxHealth
        savedHealth = oldHum.Health
        savedRigType = oldHum.RigType
        pcall(function() oldHum:Destroy() end)
    end

    local newHum = Instance.new("Humanoid")
    newHum.Parent = c
    pcall(function()
        newHum.HipHeight = savedHipHeight
        newHum.JumpPower = savedJumpPower
        newHum.MaxHealth = savedMaxHealth
        newHum.Health = savedHealth
        newHum.WalkSpeed = 60
        newHum.RigType = savedRigType
        newHum.MaxSlopeAngle = 89
        newHum.AutoRotate = true
        newHum.BreakJointsOnDeath = false
        newHum:SetStateEnabled(Enum.HumanoidStateType.Dying, false)
        newHum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        newHum:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        newHum:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
        newHum:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
        newHum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        newHum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end)

    pcall(function()
        local oldAnim = newHum:FindFirstChildOfClass("Animator")
        if oldAnim then oldAnim:Destroy() end
        local anim = Instance.new("Animator")
        anim.Parent = newHum
    end)

    pcall(function()
        local old = c:FindFirstChild("Animate")
        if old then old:Destroy() end
        task.wait(0.05)
        local starter = StarterPlayer:FindFirstChild("StarterCharacterScripts")
        if starter then
            local tpl = starter:FindFirstChild("Animate")
            if tpl then
                local new = tpl:Clone()
                new.Parent = c
                new.Disabled = false
                return
            end
        end
    end)

    task.wait(0.1)
    local camera = W.CurrentCamera
    if camera then
        pcall(function()
            camera.CameraSubject = newHum
            camera.CameraType = Enum.CameraType.Custom
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
    pcall(function()
        newHum:ChangeState(Enum.HumanoidStateType.Running)
    end)

    return true
end

-- ⭐ v10.7.0: TELE đứng yên trên cao (KHÔNG dựt)
local function teleToMapStable(targetPos)
    log("📍 TELE (đứng yên trên cao)")

    local airPos = targetPos + Vector3.new(0, 15, 0)

    for attempt = 1, 4 do
        hardStop()
        task.wait(0.05)

        -- Set CFrame 1 LẦN DUY NHẤT
        local r = getHRP()
        if r then pcall(function()
            r.CFrame = CFrame.new(airPos)
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end) end

        -- Chỉ set velocity = 0 mỗi frame, KHÔNG set CFrame → không dựt
        local t0 = os.clock()
        while os.clock() - t0 < 0.8 do
            if not isRunning then return false end
            keepHealth()
            hardStop()
            task.wait(0.01)
        end

        local rCheck = getHRP()
        if rCheck then
            local dCheck = dist(rCheck.Position, airPos)
            local dY = math.abs(rCheck.Position.Y - airPos.Y)
            log(string.format("   [tele #%d] d=%.1f dY=%.1f Y=%.1f",
                attempt, dCheck, dY, rCheck.Position.Y))

            if dCheck < 20 and dY < 10 then
                log("   ✅ Đứng yên trên cao")
                return true
            else
                log("   🚨 Rớt → thử lại")
                task.wait(0.2)
            end
        end
    end

    log("   ❌ Tele fail")
    return false
end

-- ⭐ Fire prompt burst x5 cực nhanh
local function firePromptBurst(prompt, count, delay)
    count = count or 5
    delay = delay or 0.01
    if not prompt or not prompt.Parent then return false end

    pcall(function()
        prompt.Enabled = true
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 999
        prompt.RequiresLineOfSight = false
    end)

    for i = 1, count do
        if not isRunning then break end
        pcall(function()
            if type(fireproximityprompt) == "function" then
                fireproximityprompt(prompt)
            end
        end)
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(0.005)
            prompt:InputHoldEnd()
        end)
        pcall(function()
            prompt.PromptButtonHoldBegan:Fire()
            task.wait(0.005)
            prompt.PromptButtonHoldEnded:Fire()
            prompt.Triggered:Fire(P)
        end)
        task.wait(delay)
    end
    return true
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

-- ══════════ MOVEMENT ══════════
local function velocityMoveTo(targetPos, timeout, speed, manual)
    timeout = timeout or 20
    speed = speed or math.min(config.SPEED / 2.5, config.SPEED_CAP)
    local hum, hrp = getHum(), getHRP()
    if not hum or not hrp then return false end
    keepHealth()
    local function shouldStop()
        if manual then return false end
        return not isRunning
    end
    local t0 = os.clock()
    local lastPos = hrp.Position
    local stuckTime = os.clock()
    while not shouldStop() and os.clock() - t0 < timeout do
        hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth(); forceRunningState()
        local d = dist(hrp.Position, targetPos)
        if d < config.ARRIVE_DIST then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            return true
        end
        pcall(function()
            local dir = targetPos - hrp.Position
            if dir.Magnitude > 0 then
                local nrm = dir.Unit
                hrp.AssemblyLinearVelocity = Vector3.new(
                    nrm.X * speed,
                    hrp.AssemblyLinearVelocity.Y,
                    nrm.Z * speed
                )
            end
        end)
        local moved = dist(hrp.Position, lastPos)
        if moved < 0.3 then
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
    timeout = timeout or 20    speed = speed or config.FLY_HOME_SPEED or 500
    local hum, hrp = getHum(), getHRP()
    if not hum or not hrp then return false end
    keepHealth()
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth(); forceRunningState()
        local d = dist(hrp.Position, targetPos)
        if d < config.ARRIVE_DIST then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            return true
        end
        pcall(function()
            local dir = targetPos - hrp.Position
            if dir.Magnitude > 0 then hrp.AssemblyLinearVelocity = dir.Unit * speed end
        end)
        task.wait(0.01)
    end
    pcall(function() local r = getHRP(); if r then r.AssemblyLinearVelocity = Vector3.zero end end)
    return false
end

local function runToForest()
    log(string.format("🏃 CHẠY RA FOREST (velocity %d)", config.FOREST_RUN_SPEED))
    local t0 = os.clock()
    local lastPos = nil
    local stuckCount = 0
    local arrived = false
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
            log(string.format("✅ Đã tới Forest (còn %.1f studs, %.1fs)", d, os.clock() - t0))
            arrived = true
            break
        end

        local speed = config.FOREST_RUN_SPEED
        if d < 60 then
            speed = math.max(20, config.FOREST_RUN_SPEED * (d / 60))
        end

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
            else
                stuckCount = 0
            end
        end
        lastPos = hrp.Position
        task.wait(0.01)
    end

    if not arrived then
        log("⚠ Timeout chạy ra Forest")
        return false
    end

    log(string.format("   ⏸ Đứng yên %.1fs...", config.FOREST_WARMUP or 0.3))
    holdStill(config.FOREST_WARMUP or 0.3)
    return true
end

-- ⭐ v10.7.0: Về home, đứng yên (KHÔNG dựt)
local function goHome()
    log("🏃 VỀ HOME (đứng yên)")
    local startTime = os.clock()

    -- Bay velocity tới gần home
    local t1 = os.clock()
    while os.clock() - t1 < 25 do
        if not isRunning then return false end
        local hum, r = getHum(), getHRP()
        if not hum or not r then break end
        keepHealth(); forceRunningState()

        local d3 = dist(r.Position, config.HOME_POS)
        if d3 < 15 then
            log(string.format("📍 Đến gần home (d=%.1f)", d3))
            break
        end

        pcall(function()
            local dir = config.HOME_POS - r.Position
            if dir.Magnitude > 0 then
                r.AssemblyLinearVelocity = dir.Unit * (config.FLY_HOME_SPEED or 500)
            end
        end)
        task.wait(0.01)
    end

    -- ⭐ Set CFrame 1 lần về home + giữ velocity = 0 (KHÔNG set CFrame liên tục)
    log("📍 Snap về home")
    hardStop()
    task.wait(0.1)

    local r1 = getHRP()
    if r1 then pcall(function()
        r1.CFrame = CFrame.new(config.HOME_POS)
        r1.AssemblyLinearVelocity = Vector3.zero
        r1.AssemblyAngularVelocity = Vector3.zero
    end) end

    -- Giữ velocity = 0 mỗi frame (KHÔNG set CFrame) 0.4s
    holdStill(0.4)

    log("🔨 Rebuild...")
    rebuildCharacterFull()
    task.wait(0.2)

    -- Sau rebuild: set CFrame 1 lần + giữ velocity 0
    local r3 = getHRP()
    if r3 then pcall(function()
        r3.CFrame = CFrame.new(config.HOME_POS)
        r3.AssemblyLinearVelocity = Vector3.zero
        r3.AssemblyAngularVelocity = Vector3.zero
    end) end

    holdStill(0.4)

    log(string.format("✅ Về home + đứng yên (%.2fs)", os.clock() - startTime))
    return true
end

local function baitBoss(timeout)
    timeout = timeout or config.BAIT_TIMEOUT
    log("🎯 Bait boss...")

    holdStill(config.BAIT_WARMUP or 0.3)
    forceRunningState()
    task.wait(0.3)

    local hum0, hrp0 = getHum(), getHRP()
    if not hum0 or not hrp0 then return false end
    local startHealth = hum0.Health
    local startPos = hrp0.Position

    local t0 = os.clock()
    while isRunning and os.clock() - t0 < timeout do
        local hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth()

        local vel = hrp.AssemblyLinearVelocity
        local speed = vel.Magnitude
        local state = hum:GetState()

        if state == Enum.HumanoidStateType.Physics and speed > (config.KB_SPEED_PHYSICS or 50) then
            return true
        end
        if speed > (config.KB_SPEED_VELOCITY or 80) and vel.Y > (config.KB_VELY_MIN or 20) then
            return true
        end
        if state == Enum.HumanoidStateType.PlatformStanding
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Ragdoll then
            return true
        end
        if hum.Health < startHealth - (config.KB_HEALTH_DROP or 0.1) then
            return true
        end
        local pd = (hrp.Position - startPos).Magnitude
        if pd > (config.KB_SHIFT_MIN or 30) then return true end

        hardStop()
        task.wait(0.01)
    end
    return false
end

-- ⭐ Steal Forest — check boss INLINE, tele NGAY
local function stealAtForest()
    local prompt, ppos = findForestEggOnly()
    if not prompt or not ppos then
        log("⚠ Không có Forest egg")
        return false, "no-egg"
    end

    log(string.format("🎯 Forest egg @ %.1f,%.1f,%.1f", ppos.X, ppos.Y, ppos.Z))

    local hrp = getHRP()
    if hrp and dist(hrp.Position, ppos) > config.ARRIVE_DIST then
        velocityMoveTo(ppos, 15)
    end

    hardStop()
    task.wait(0.2)

    local forestBefore = getSlotSet()
    log("⚡ Steal Forest (check INLINE)")

    local loopStart = os.clock()

    for i = 1, 8 do
        if not isRunning then break end

        -- CHECK BOSS ĐÁNH (trước khi fire)
        local hum = getHum()
        local hCheck = getHRP()
        if hum and hCheck then
            local vel = hCheck.AssemblyLinearVelocity
            local speed = vel.Magnitude
            local velY = vel.Y
            local state = hum:GetState()

            if os.clock() - loopStart > 0.15 then
                if speed > (config.FOREST_HIT_SPEED or 20)
                    or velY > (config.FOREST_HIT_VELY or 5)
                    or state == Enum.HumanoidStateType.Physics
                    or state == Enum.HumanoidStateType.Ragdoll
                    or state == Enum.HumanoidStateType.PlatformStanding
                    or state == Enum.HumanoidStateType.FallingDown then
                    log(string.format("💥 Boss đánh NGAY (speed=%.1f Y=%.1f state=%s) → TELE",
                        speed, velY, tostring(state):gsub("Enum.HumanoidStateType%.", "")))
                    return false, "hit-by-boss"
                end
            end
        end

        -- Fire prompt
        forceRunningState()
        local h2 = getHRP()
        if h2 then
            local p2 = findPromptSteal(h2.Position, config.FOREST_RADIUS)
            if p2 then
                local p2pos = getPromptPos(p2)
                if p2pos and dist(h2.Position, p2pos) > config.PROMPT_NEAR then
                    pcall(function()
                        h2.CFrame = CFrame.new(p2pos + Vector3.new(0, 3, 0))
                        h2.AssemblyLinearVelocity = Vector3.zero
                        h2.AssemblyAngularVelocity = Vector3.zero
                    end)
                    task.wait(0.05)
                end
                firePromptBurst(p2, config.STEAL_BURST_COUNT or 5, config.STEAL_BURST_DELAY or 0.01)
            end
        end

        task.wait()

        -- CHECK LẠI SAU FIRE
        local hum2 = getHum()
        local hCheck2 = getHRP()
        if hum2 and hCheck2 then
            local speed2 = hCheck2.AssemblyLinearVelocity.Magnitude
            local velY2 = hCheck2.AssemblyLinearVelocity.Y
            local state2 = hum2:GetState()
            if os.clock() - loopStart > 0.15 then
                if speed2 > (config.FOREST_HIT_SPEED or 20)
                    or velY2 > (config.FOREST_HIT_VELY or 5)
                    or state2 == Enum.HumanoidStateType.Physics
                    or state2 == Enum.HumanoidStateType.Ragdoll
                    or state2 == Enum.HumanoidStateType.PlatformStanding
                    or state2 == Enum.HumanoidStateType.FallingDown then
                    log(string.format("💥 Boss đánh SAU FIRE (speed=%.1f Y=%.1f) → TELE NGAY",
                        speed2, velY2))
                    return false, "hit-by-boss"
                end
            end
        end

        local stolen, slotName = hasStolenSlot(forestBefore)
        if stolen then
            log("🎒 Forest OK (slot): " .. slotName)
            stolenPrompts[prompt] = true
            return true, "stolen"
        end

        task.wait(0.1)
    end

    task.wait(0.5)
    if isCarryingEggStrict() then
        log("🎒 Forest OK (carry verify)")
        stolenPrompts[prompt] = true
        return true, "stolen"
    end

    log("❌ Forest FAIL")
    return false, "no-steal"
end

-- ⭐ v10.7.0: Steal đứng yên trên cao (KHÔNG dựt)
local function stealAtPos(targetPos, label, eggUid)
    log("═══════")
    log("STEAL TẠI " .. label)

    local hrp = getHRP()
    if not hrp then return false end

    local d = dist(hrp.Position, targetPos)
    if d > 200 then
        local ok = teleToMapStable(targetPos)
        if not ok then return false end
        hrp = getHRP()
        if not hrp then return false end
    end

    -- Bay ngang tới gần egg (giữ Y hiện tại)
    local holdY = hrp.Position.Y
    local airTarget = Vector3.new(targetPos.X, holdY, targetPos.Z)
    if dist(hrp.Position, airTarget) > config.PROMPT_NEAR then
        velocityFlyTo(airTarget, 3, 600)
        holdStill(0.15)
    end

    local slotsBefore, countBefore = getSlotSet()
    log("📊 Slots trước: " .. countBefore)

    for i = 1, config.MAX_FIRES do
        if not isRunning then return false end
        forceRunningState()

        local h2 = getHRP()
        if not h2 then break end

        -- ⭐ Đứng yên tại chỗ (KHÔNG dựt): chỉ set velocity = 0
        holdY = h2.Position.Y
        hardStop()
        task.wait(0.05)

        local p2 = findPromptSteal(h2.Position, 150)
        if not p2 then
            log("⚠ Không có prompt gần")
            break
        end

        local p2pos = getPromptPos(p2)
        if not p2pos then break end
        local dToPrompt = dist(h2.Position, p2pos)
        if dToPrompt > config.PROMPT_NEAR then
            -- Bay ngang giữ Y
            local airP = Vector3.new(p2pos.X, holdY, p2pos.Z)
            velocityFlyTo(airP, 2, 600)
            holdStill(0.1)
            p2 = findPromptSteal(getHRP() and getHRP().Position or Vector3.zero, 150)
            if not p2 then break end
        end

        firePromptBurst(p2, config.STEAL_BURST_COUNT or 5, config.STEAL_BURST_DELAY or 0.01)

        -- Verify + giữ đứng yên
        local verifyStart = os.clock()
        local stolen = false
        local stolenName = nil
        while os.clock() - verifyStart < config.STEAL_TIMEOUT do
            hardStop()
            task.wait(0.05)
            local s, sn = hasStolenSlot(slotsBefore)
            if s then stolen = true; stolenName = sn; break end
            if isCarryingEggStrict() then
                task.wait(0.15)
                if isCarryingEggStrict() then stolen = true; stolenName = "carry"; break end
            end
        end

        if stolen then
            log(string.format("✅ ĐÃ STEAL (vòng %d, %s) — Y=%.1f", i, stolenName, holdY))
            if eggUid then lastStolenUid = eggUid end
            lastStolenPos = targetPos
            return true
        end
    end

    log("⚠ Không steal được")
    return false
end

local function pickNextEgg()
    if config.PRIORITY_INCOME and not AssetEarnings then
        return findEggInTargets()
    end
    if config.BIG_EGG_MODE and not EggState then
        return findEggInTargets()
    end

    if config.PRIORITY_INCOME and config.BIG_EGG_MODE then
        if not EggState or not AssetEarnings then
            return findEggInTargets()
        end
        local minIncome = config.DUAL_MIN_INCOME or 30000000
        local minSize = config.DUAL_MIN_SIZE or 4.0
        local ok, fd = pcall(EggState.ReadFieldEggs)
        if ok and type(fd) == "table" and type(fd.Records) == "table" then
            local best = nil
            for uid, eggData in pairs(fd.Records) do
                if not stolenEggUids[uid] then
                    local cf = eggData.BoundsCFrame
                    if cf then
                        local pos = cf.Position
                        if dist(pos, config.HOME_POS) > 100 then
                            local st = tostring(eggData.State or ""):lower()
                            if st ~= "carried" and st ~= "carry" and st ~= "carrying"
                                and st ~= "held" and st ~= "picked" then
                                local input = { Category = eggData.AssetCategory, Scale = eggData.AssetScale or 1, Mutations = eggData.Mutations or {} }
                                local income = 0
                                local ok2, val = pcall(AssetEarnings.LiveRatePerSecond, input)
                                if ok2 and type(val) == "number" and val > 0 then income = val end
                                if income == 0 then
                                    ok2, val = pcall(AssetEarnings.RatePerSecond, input)
                                    if ok2 and type(val) == "number" and val > 0 then income = val end
                                end
                                if income >= minIncome then
                                    local bs = eggData.BoundsSize
                                    local size = bs and ((bs.X + bs.Y + bs.Z) / 3) or 0
                                    if size >= minSize then
                                        if not best or income > best.income then
                                            local nearestMap, nearestDist = nil, 99999
                                            for _, m in ipairs(ALL_MAPS) do
                                                local dd = dist(pos, m.pos)
                                                if dd < nearestDist then nearestMap = m; nearestDist = dd end
                                            end
                                            if nearestMap then
                                                best = {
                                                    uid = uid, pos = pos, income = income,
                                                    size = size, map = nearestMap,
                                                    category = eggData.AssetCategory,
                                                }
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
                local prompt = nil
                local bestDist = 20
                for _, v in ipairs(W:GetDescendants()) do
                    if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                        local isEgg = v.Name == "CarryAreaEgg"
                            or ((v.ObjectText or "") == "Egg"
                                and (v.ActionText or ""):lower():find("steal", 1, true))
                        if isEgg then
                            local ppos = getPromptPos(v)
                            if ppos then
                                local dd = (ppos - best.pos).Magnitude
                                if dd < bestDist then prompt = v; bestDist = dd end
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
        local p, pos, s, m, u = findBiggestEgg()
        if not pos then return findEggInTargets() end
        return p, pos, s, m, u
    end

    if config.BIG_EGG_MODE then
        local p, pos, s, m, u = findBiggestEgg()
        if not pos then return findEggInTargets() end
        return p, pos, s, m, u
    elseif config.PRIORITY_INCOME then
        local p, pos, s, m, u = findHighestIncomeEgg()
        if not pos then return findEggInTargets() end
        return p, pos, s, m, u
    else
        return findEggInTargets()
    end
end

-- ⭐⭐⭐ MAIN LOOP v10.7.0
local function mainLoop()
    while isRunning do
        local cycleT0 = os.clock()
        log("═══════════════════════════════")
        log("🔄 CYCLE MỚI")

        local gotKB = false
        local skipCycle = false

        -- BƯỚC 1: FOREST
        log("▶ [1/6] Chạy ra Forest...")
        local okForest = runToForest()
        if not okForest then
            task.wait(2)
            skipCycle = true
        end

        -- BƯỚC 2: STEAL FOREST
        if not skipCycle then
            log("▶ [2/6] Steal Forest egg...")
            local forestOk, forestReason = stealAtForest()

            if forestReason == "hit-by-boss" then
                log("💥 Boss đánh ở Forest → REBUILD ngay")
                gotKB = true
            elseif not forestOk then
                log("⚠ Forest fail → về home")
                goHome()
                task.wait(config.HOME_REST_TIME or 0.5)
                skipCycle = true
            else
                log("▶ [3/6] Bait boss...")
                gotKB = baitBoss(config.BAIT_TIMEOUT)
                if not gotKB then
                    log("⚠ Không bị knockback → về home")
                    goHome()
                    task.wait(config.HOME_REST_TIME or 0.5)
                    skipCycle = true
                end
            end
        end

        -- BƯỚC 4-6
        if not skipCycle and gotKB then
            log("▶ [4/6] REBUILD...")
            rebuildCharacterFull()
            task.wait(0.2)

            hardStop()

            -- BƯỚC 5: PICK + TELE + STEAL
            log("▶ [5/6] Pick egg + tele + steal...")
            local eggPrompt, eggPos, eggData, eggMap, eggUid = pickNextEgg()

            if not eggPos then
                log("⚠ Không có egg → về home")
                goHome()
                task.wait(config.HOME_REST_TIME or 0.5)
            else
                local targetPos = eggPos + Vector3.new(0, 3, 0)

                log("   🚀 Tele...")
                local teleOk = teleToMapStable(targetPos)

                if not teleOk then
                    log("   🔄 Retry tele...")
                    task.wait(0.5)
                    teleOk = teleToMapStable(targetPos)
                end

                task.wait(config.TELE_STABILIZE or 0.2)

                local beforeSteal = getHRP() and getHRP().Position
                if beforeSteal then
                    local dEgg = dist(beforeSteal, eggPos)
                    if dEgg > 300 then
                        teleToMapStable(targetPos)
                        task.wait(0.3)
                    end
                end

                log("   🎒 Steal (burst x5)...")
                local stolen = stealAtPos(eggPos, eggMap.name, eggUid)

                if stolen then
                    log("▶ [6/6] Steal OK → về home...")
                    deliveryFailed = false
                    goHome()
                    task.wait(config.HOME_REST_TIME or 0.5)
                    task.wait(config.CHAT_WAIT)

                    if lastStolenUid then
                        local stillOnMap = isEggStillOnMap(lastStolenUid, lastStolenPos)
                        if not stillOnMap then
                            stolenEggUids[lastStolenUid] = true
                        end
                        lastStolenUid = nil
                        lastStolenPos = nil
                    end
                else
                    log("▶ [6/6] Steal FAIL → retry...")
                    task.wait(0.3)

                    local hrpCheck = getHRP()
                    if hrpCheck and dist(hrpCheck.Position, eggPos) < 200 then
                        stolen = stealAtPos(eggPos, eggMap.name, eggUid)
                    else
                        teleToMapStable(targetPos)
                        task.wait(0.3)
                        stolen = stealAtPos(eggPos, eggMap.name, eggUid)
                    end

                    goHome()
                    task.wait(config.HOME_REST_TIME or 0.5)
                end
                task.wait(config.CHAT_WAIT)
            end
        end

        log(string.format("⏱ Cycle tổng: %.2fs", os.clock() - cycleT0))
        if not isRunning then break end
        task.wait(config.HOME_REST_TIME or 0.5)
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

task.spawn(function()
    pcall(function()
        local chatEvents = RS:WaitForChild("DefaultSystemChatEvents", 5)
            or RS:WaitForChild("DefaultChatSystemChatEvents", 5)
        if not chatEvents then return end
        local onMsg = chatEvents:WaitForChild("OnMessageDoneFiltering", 5)
        if not onMsg then return end
        onMsg.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then return end
            local msg = string.lower(tostring(data.Message or ""))
            if msg:find("delivery failed", 1, true)
                or msg:find("returned to its nest", 1, true)
                or msg:find("egg was returned", 1, true) then
                deliveryFailed = true
            end
        end)
    end)
end)

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
    stolenPrompts = {}
    stolenEggUids = {}
    deliveryFailed = false
    lastEggCount = -1
    cycleStartTime = os.clock()
    lastStolenUid = nil
    lastStolenPos = nil

    pcall(function()
        hardStop()
        forceRunningState()
    end)
    task.wait(0.2)

    isRunning = true
    log("▶ START v10.7.0")
    log(string.format("   Home rest time: %.1fs", config.HOME_REST_TIME or 0.5))
    log(string.format("   Steal burst: x%d @ %.3fs",
        config.STEAL_BURST_COUNT, config.STEAL_BURST_DELAY))

    mainThread = task.spawn(mainLoop)
end

function M.stop()
    isRunning = false
    if mainThread then
        pcall(function() task.cancel(mainThread) end)
        mainThread = nil
    end
    hardStop()
    log("■ STOP")
end

function M.isRunning() return isRunning end
function M.setTargets(list) if type(list) == "table" then config.TARGETS = list end end
function M.setTarget(name, pos) config.TARGETS = { { name = name, pos = pos } } end

function M.setPriorityIncome(enabled)
    config.PRIORITY_INCOME = enabled and true or false
    if not config.PRIORITY_INCOME then
        stolenEggUids = {}; stolenPrompts = {}
    end
    return config.PRIORITY_INCOME
end

function M.setBigEggMode(enabled)
    config.BIG_EGG_MODE = enabled and true or false
    if not config.BIG_EGG_MODE then
        stolenEggUids = {}; stolenPrompts = {}
    end
    return config.BIG_EGG_MODE
end

function M.setPriorityThreshold(amount) config.PRIORITY_THRESHOLD = amount or 1000000 end
function M.setHome(p) if p then config.HOME_POS = p end end
function M.setForest(p) if p then config.FOREST_POS = p end end
function M.setForestRunSpeed(n) config.FOREST_RUN_SPEED = n or 250 end
function M.setBaitTimeout(n) config.BAIT_TIMEOUT = n or 15 end
function M.setForestWarmup(n) config.FOREST_WARMUP = n or 0.3 end
function M.setBaitWarmup(n) config.BAIT_WARMUP = n or 0.3 end
function M.setTeleHold(n) config.TELE_HOLD = n or 0.3 end

function M.setHomeRestTime(n)
    config.HOME_REST_TIME = n or 0.5
    log("⏸ Home rest time: " .. config.HOME_REST_TIME .. "s")
end

function M.getConfig() return config end
function M.getAllMaps() return ALL_MAPS end
function M.isCarrying() return isCarryingEgg() end
function M.clearStolenUids() stolenEggUids = {}; stolenPrompts = {} end
function M.isEggStillOnMap(uid, pos) return isEggStillOnMap(uid, pos) end
function M.isPriorityIncome() return config.PRIORITY_INCOME end

function M.togglePriorityIncome()
    config.PRIORITY_INCOME = not config.PRIORITY_INCOME
    if not config.PRIORITY_INCOME then
        stolenEggUids = {}; stolenPrompts = {}
    end
    return config.PRIORITY_INCOME
end

function M.isBigEggMode() return config.BIG_EGG_MODE end

function M.toggleBigEggMode()
    config.BIG_EGG_MODE = not config.BIG_EGG_MODE
    if not config.BIG_EGG_MODE then
        stolenEggUids = {}; stolenPrompts = {}
    end
    return config.BIG_EGG_MODE
end

function M.getPriorityThreshold() return config.PRIORITY_THRESHOLD end
function M.clearIncomeCache() end
function M.setHomeFlyY(n) config.HOME_FLY_ABSOLUTE_Y = n or 100 end
function M.setFlyHomeSpeed(n) config.FLY_HOME_SPEED = n or 500 end
function M.setHomeTimeout(n) config.HOME_TIMEOUT = n or 30 end
function M.setPromptNear(n) config.PROMPT_NEAR = n or 12 end
function M.setSlowSpeed(n) config.FOREST_RUN_SPEED = n or 150 end
function M.setChatWait(n) config.CHAT_WAIT = n or 1.0 end
function M.setCycleWait(n) config.WAIT_BETWEEN = n or 0.7 end
function M.setMaxRetry(n) config.MAX_RETRY = n or 3 end

function M.setDualMinIncome(n) config.DUAL_MIN_INCOME = n or 30000000 end
function M.setDualMinSize(n) config.DUAL_MIN_SIZE = n or 4.0 end

function M.setDualMode(minIncome, minSize)
    config.DUAL_MIN_INCOME = minIncome or 30000000
    config.DUAL_MIN_SIZE = minSize or 4.0
end

function M.isDualMode() return config.PRIORITY_INCOME and config.BIG_EGG_MODE end
function M.getCurrentTarget() return lastStolenUid and { uid = lastStolenUid, pos = lastStolenPos } or nil end

function M.clearCurrentTarget()
    lastStolenUid = nil
    lastStolenPos = nil
end

function M.getStolenCount()
    local c = 0
    for _ in pairs(stolenEggUids) do c = c + 1 end
    return c
end

function M.getStolenUids() return stolenEggUids end

function M.getStatus()
    return {
        isRunning = isRunning,
        bigEggMode = config.BIG_EGG_MODE,
        priorityIncome = config.PRIORITY_INCOME,
        priorityThreshold = config.PRIORITY_THRESHOLD,
        dualMode = config.PRIORITY_INCOME and config.BIG_EGG_MODE,
        targets = config.TARGETS,
        stolenCount = M.getStolenCount(),
        lastStolenUid = lastStolenUid,
        forestRunSpeed = config.FOREST_RUN_SPEED,
        homeRestTime = config.HOME_REST_TIME,
    }
end

function M.setBigEggMinSize(n) config.BIG_EGG_MIN_SIZE = n or 0 end
function M.setBigEggMinScale(n) config.BIG_EGG_MIN_SCALE = n or 0 end
function M.getBigEggThresholds() return { minSize = config.BIG_EGG_MIN_SIZE or 0, minScale = config.BIG_EGG_MIN_SCALE or 0 } end
function M.setForestHitSpeed(n) config.FOREST_HIT_SPEED = n or 20 end
function M.setForestHitVely(n) config.FOREST_HIT_VELY = n or 5 end
function M.setForestHpDrop(n) config.FOREST_HP_DROP = n or 0.01 end

function M.setStealBurst(count, delay)
    config.STEAL_BURST_COUNT = count or 5
    config.STEAL_BURST_DELAY = delay or 0.01
end

return M
