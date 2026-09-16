-- ═══════════════════════════════════════════════════════════════
-- STEAL MODULE v10.6.4 — Full Code Locked Target State Flow
-- ═══════════════════════════════════════════════════════════════

local P                  = game:GetService("Players").LocalPlayer
local RS                 = game:GetService("ReplicatedStorage")
local W                  = workspace
local ProximityPromptSvc = game:GetService("ProximityPromptService")

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
    HOME_POS       = Vector3.new(465.2, 67.1, -364.1),
    FOREST_POS     = Vector3.new(599.9, 67.6, -363.9),
    TARGETS        = { { name = "Snow", pos = Vector3.new(1405.1, 68.0, -363.8) } },
    PREFER_FAR     = true,
    PRIORITY_INCOME    = false,
    PRIORITY_THRESHOLD = 1000000,
    BIG_EGG_MODE       = false,
    HOME_FLY_ABSOLUTE_Y = 100,
    FLY_HOME_SPEED      = 350,
    DROP_SPEED          = 250,
    RECOVERY_RADIUS     = 500,
    MAX_RECOVERY        = 3,
    RECOVERY_WAIT       = 0.3,
    FOREST_RADIUS       = 300,
    CARRY_WAIT_MAX      = 5,
    PROMPT_NEAR_DIST    = 12,
    PROMPT_SKIP_DIST    = 15,
    SPEED          = 1500,
    SPEED_CAP      = 350,
    SLOW_SPEED     = 1000,
    FIRST_CYCLE_SPEED = 400,
    MAP_RADIUS     = 800,
    ARRIVE_DIST    = 10,
    BAIT_TIMEOUT   = 12,
    KB_HEALTH_DROP = 0.5,
    MAX_FIRES      = 8,
    MAX_RETRY      = 3,
    STEAL_VERIFY_WAIT = 0.25,
    CHAT_WAIT      = 0.5,
    WARMUP_TIME    = 3,
}

local isRunning = false
local stolenPrompts = {}
local deliveryFailed = false
local logCallbacks = {}
local lastEggCount = -1
local lastTargetPos = nil
local lastTargetMap = nil
local consecutiveFails = 0
local cycleStartTime = 0
local lastClearTime = 0
local lastMoveCheck = 0
local lastMovePos = nil
local replacedThisCycle = false
local isFirstCycle = true

-- 🔒 LOCKED TARGET STATE
local currentTarget = nil -- Struct: { prompt = ..., pos = ..., scale = ..., map = ... }

local function log(s)
    for _, cb in ipairs(logCallbacks) do pcall(cb, s) end
    print("[Steal] " .. tostring(s))
end

function M.onLog(cb) if type(cb) == "function" then table.insert(logCallbacks, cb) end end

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

local function forceTeleHome()
    local r = getHRP()
    if r then pcall(function()
        r.CFrame = CFrame.new(config.HOME_POS)
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end) end
end

local function forceRunningState()
    local hum = getHum()
    if hum then pcall(function()
        hum.PlatformStand = false
        hum.Sit = false
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Physics
            or state == Enum.HumanoidStateType.PlatformStanding
            or state == Enum.HumanoidStateType.FallingDown then
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end) end
end

-- ══════════ INCOME MODULES ══════════
local AssetEarnings, EggState
local incomeCache = {}

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

local function isCarryingEgg()
    if not EggState then return false, nil end
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then
        return false, nil
    end
    for uid, eggData in pairs(fd.Records) do
        local state = tostring(eggData.State or ""):lower()
        if state == "carried" or state == "carry" or state == "carrying" then
            return true, eggData
        end
    end
    return false, nil
end

local function isOtherHolder(state)
    state = tostring(state or ""):lower()
    return state == "carried" or state == "carry" or state == "carrying"
        or state == "nest" or state == "returned"
end

local function findBiggestEgg()
    -- 🔒 Nếu đang có target khóa hoặc đang carry egg -> Trả về target cũ lập tức
    if currentTarget ~= nil then
        return currentTarget.prompt, currentTarget.pos, currentTarget.scale, currentTarget.map
    end
    if isCarryingEgg() then return nil, nil, nil, nil end

    local hrp = getHRP()
    if not hrp or not EggState then return nil, nil, nil, nil end

    local candidates = {}
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if ok and type(fd) == "table" and type(fd.Records) == "table" then
        for uid, eggData in pairs(fd.Records) do
            local cf = eggData.BoundsCFrame
            if cf then
                local pos = cf.Position
                local st = tostring(eggData.State or "slot"):lower()
                local bs = eggData.BoundsSize
                local avgSize = bs and ((bs.X + bs.Y + bs.Z) / 3) or (3.5 * (eggData.AssetScale or 1))
                local nearestMap, nearestDist = nil, 99999
                for _, m in ipairs(ALL_MAPS) do
                    local d = dist(pos, m.pos)
                    if d < nearestDist then nearestMap = m; nearestDist = d end
                end
                if nearestMap then
                    table.insert(candidates, {
                        uid = uid, pos = pos, scale = eggData.AssetScale or 1,
                        avgSize = avgSize, map = nearestMap,
                        category = eggData.AssetCategory,
                        mutation = eggData.BaseMutation,
                        rawState = st,
                    })
                end
            end
        end
    end

    if #candidates == 0 then
        for _, v in ipairs(W:GetDescendants()) do
            if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                local isEgg = v.Name == "CarryAreaEgg"
                    or ((v.ObjectText or "") == "Egg"
                        and (v.ActionText or ""):lower():find("steal", 1, true))
                if isEgg then
                    local ppos = getPromptPos(v)
                    if ppos and dist(ppos, config.HOME_POS) > 150 then
                        local nearestMap, nearestDist = nil, 99999
                        for _, m in ipairs(ALL_MAPS) do
                            local d = dist(ppos, m.pos)
                            if d < nearestDist then nearestMap = m; nearestDist = d end
                        end
                        if nearestMap then
                            table.insert(candidates, {
                                prompt = v, pos = ppos, scale = 0, avgSize = 0,
                                map = nearestMap, category = "Egg (dropped)",
                                mutation = nil, rawState = "dropped",
                            })
                        end
                    end
                end
            end
        end
        if #candidates == 0 then return nil, nil, nil, nil end
        local myPos = hrp.Position
        table.sort(candidates, function(a, b) return dist(a.pos, myPos) < dist(b.pos, myPos) end)
        local best = candidates[1]
        currentTarget = { prompt = best.prompt, pos = best.pos, scale = best.scale, map = best.map }
        return best.prompt, best.pos, best.scale, best.map
    end

    table.sort(candidates, function(a, b)
        if a.avgSize ~= b.avgSize then return a.avgSize > b.avgSize end
        return a.scale > b.scale
    end)

    local allPrompts = {}
    for _, v in ipairs(W:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg"
                    and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEgg then
                local ppos = getPromptPos(v)
                if ppos then table.insert(allPrompts, { prompt = v, pos = ppos }) end
            end
        end
    end

    local matchedPrompt, matchedPos, matchedCand = nil, nil, nil
    for _, cand in ipairs(candidates) do
        if not isOtherHolder(cand.rawState) then
            local uidMatch = nil
            for _, p in ipairs(allPrompts) do
                local pUID = p.prompt:GetAttribute("EggUid") or p.prompt:GetAttribute("EggUID") or p.prompt:GetAttribute("Uid")
                if not pUID and p.prompt.Parent then
                    pUID = p.prompt.Parent:GetAttribute("EggUid") or p.prompt.Parent:GetAttribute("EggUID")
                end
                if pUID and pUID == cand.uid then
                    uidMatch = p; break
                end
            end
            if not uidMatch then
                for _, p in ipairs(allPrompts) do
                    if dist(p.pos, cand.pos) < 5 then uidMatch = p; break end
                end
            end
            if uidMatch then
                matchedPrompt = uidMatch; matchedPos = cand.pos; matchedCand = cand
                break
            end
        end
    end

    if not matchedPrompt then return nil, nil, nil, nil end

    currentTarget = { prompt = matchedPrompt.prompt, pos = matchedPos, scale = matchedCand.scale, map = matchedCand.map }
    return matchedPrompt.prompt, matchedPos, matchedCand.scale, matchedCand.map
end

local function findHighestIncomeEgg()
    -- 🔒 Lock Target Check
    if currentTarget ~= nil then
        return currentTarget.prompt, currentTarget.pos, currentTarget.scale, currentTarget.map
    end
    if isCarryingEgg() then return nil, nil, nil, nil end

    local hrp = getHRP()
    if not hrp or not EggState or not AssetEarnings then return nil, nil, nil, nil end
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then return nil, nil, nil, nil end
    
    local candidates = {}
    local threshold = config.PRIORITY_THRESHOLD or 0
    for uid, eggData in pairs(fd.Records) do
        local cf = eggData.BoundsCFrame
        if cf then
            local pos = cf.Position
            if dist(pos, config.HOME_POS) > 150 then
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
    if #candidates == 0 then return nil, nil, nil, nil end
    table.sort(candidates, function(a, b) return a.income > b.income end)
    local best = candidates[1]
    local bestPrompt = nil
    local bestPromptDist = 5
    for _, v in ipairs(W:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg" and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEgg then
                local ppos = getPromptPos(v)
                if ppos and dist(ppos, best.pos) < bestPromptDist then
                    bestPrompt = v; bestPromptDist = dist(ppos, best.pos)
                end
            end
        end
    end
    if not bestPrompt then return nil, nil, nil, nil end

    currentTarget = { prompt = bestPrompt, pos = best.pos, scale = best.income, map = best.map }
    return bestPrompt, best.pos, best.income, best.map
end

local function findEggInTargets()
    -- 🔒 Lock Target Check
    if currentTarget ~= nil then
        return currentTarget.prompt, currentTarget.pos, currentTarget.scale or 1, currentTarget.map
    end
    if isCarryingEgg() then return nil, nil, nil, nil end

    local hrp = getHRP()
    if not hrp then return nil, nil, nil, nil end
    local candidates = {}
    for _, v in ipairs(W:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg" and (v.ActionText or ""):lower():find("steal", 1, true))
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
    if #candidates == 0 then return nil, nil, nil, nil end
    if config.PREFER_FAR then
        table.sort(candidates, function(a, b) return a.dFromHome > b.dFromHome end)
    else
        table.sort(candidates, function(a, b) return a.dFromPlayer < b.dFromPlayer end)
    end
    local best = candidates[1]

    currentTarget = { prompt = best.prompt, pos = best.pos, scale = 1, map = best.map }
    return best.prompt, best.pos, best.dFromPlayer, best.map
end

local function findPromptSteal(pos, radius)
    radius = radius or config.MAP_RADIUS
    local best, bestDist = nil, radius
    for _, v in ipairs(W:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg" and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEgg then
                local ppos = getPromptPos(v)
                if ppos then
                    local d = dist(ppos, pos)
                    if d < bestDist then best, bestDist = v, d end
                end
            end
        end
    end
    return best, bestDist
end

-- ══════════ ANIMATION & HUMANOID ══════════
local function restoreAnimations()
    local c = P.Character
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        local isR15 = (hum.RigType == Enum.HumanoidRigType.R15)
        local anim = hum:FindFirstChildOfClass("Animator")
        if not anim then anim = Instance.new("Animator"); anim.Parent = hum end
        task.wait(0.1)
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
end

local function resetAnimateScript()
    local c = P.Character
    if not c then return end
    pcall(function()
        local old = c:FindFirstChild("Animate")
        if old then old:Destroy() end
        task.wait(0.1)
        local starter = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts")
        if starter then
            local tpl = starter:FindFirstChild("Animate")
            if tpl then
                local new = tpl:Clone(); new.Parent = c; new.Disabled = false
            end
        end
    end)
end

local function replaceHumanoidDirect()
    local c = P.Character
    if not c then return false end
    local old = c:FindFirstChildOfClass("Humanoid")
    if not old then return false end
    local savedHip = old.HipHeight or 2
    local savedJump = old.JumpPower or 50
    local savedMax = old.MaxHealth or 100
    local savedHP = old.Health or 100
    local savedRig = old.RigType or Enum.HumanoidRigType.R15
    pcall(function() old:Destroy() end)
    local new = Instance.new("Humanoid")
    new.Parent = c
    pcall(function()
        new.HipHeight = savedHip
        new.JumpPower = savedJump
        new.MaxHealth = savedMax
        new.Health = savedHP
        new.WalkSpeed = 60
        new.RigType = savedRig
        new.MaxSlopeAngle = 89
        new.AutoRotate = true
        new:SetStateEnabled(Enum.HumanoidStateType.Dying, false)
        new:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        new:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        new:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
    end)
    pcall(function()
        if not c:FindFirstChildOfClass("Animator") then
            local a = Instance.new("Animator")
            a.Parent = new
        end
    end)
    task.spawn(restoreAnimations)
    task.spawn(function()
        task.wait(0.2)
        resetAnimateScript()
        task.wait(0.2)
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end) end
    end)
    return true
end

local function teleToMap(targetPos, forceReplace)
    local hrp = getHRP()
    if hrp then pcall(function()
        hrp.CFrame = CFrame.new(targetPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end) end
    
    if forceReplace or not replacedThisCycle then
        replaceHumanoidDirect()
        replacedThisCycle = true
        log("🔧 Replace humanoid")
    end
    
    for i = 1, 6 do
        local r2 = getHRP()
        if r2 then pcall(function()
            r2.CFrame = CFrame.new(targetPos)
            r2.AssemblyLinearVelocity = Vector3.zero
            r2.AssemblyAngularVelocity = Vector3.zero
        end) end
        task.wait(0.01)
    end
    
    task.spawn(function()
        local t0 = os.clock()
        while os.clock() - t0 < 0.6 do
            forceRunningState()
            task.wait(0.03)
        end
    end)
end

local function firePromptOnce(prompt)
    if not prompt or not prompt.Parent then return false end
    local hrp = getHRP()
    local ppos = getPromptPos(prompt)
    if hrp and ppos then
        if dist(hrp.Position, ppos) > config.PROMPT_SKIP_DIST then return false end
    end
    forceRunningState()
    pcall(function()
        prompt.Enabled = true
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 999
        prompt.RequiresLineOfSight = false
    end)
    if type(fireproximityprompt) == "function" then pcall(fireproximityprompt, prompt) end
    pcall(function()
        prompt:InputHoldBegin()
        task.wait(0.02)
        prompt:InputHoldEnd()
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
local function velocityMoveTo(targetPos, timeout, manual)
    timeout = timeout or 20
    local hum, hrp = getHum(), getHRP()
    if not hum or not hrp then return false end
    keepHealth()
    local t0 = os.clock()
    local lastPos = hrp.Position
    local stuckTime = os.clock()
    while (manual or isRunning) and os.clock() - t0 < timeout do
        hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth()
        forceRunningState()
        local d = dist(hrp.Position, targetPos)
        if d < config.ARRIVE_DIST then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            return true
        end
        pcall(function()
            local dir = targetPos - hrp.Position
            if dir.Magnitude > 0 then
                local nrm = dir.Unit
                hrp.AssemblyLinearVelocity = nrm * math.min(config.SPEED / 2.5, config.SPEED_CAP)
                if d > 50 then
                    local nudge = math.min(d, 100) * 0.05
                    hrp.CFrame = CFrame.new(hrp.Position + nrm * nudge)
                end
            end
        end)
        if dist(hrp.Position, lastPos) < 0.3 then
            if os.clock() - stuckTime > 0.5 then
                pcall(function() hum.Jump = true end)
                stuckTime = os.clock()
            end
        else
            lastPos = hrp.Position
            stuckTime = os.clock()
        end
        task.wait(0.01)
    end
    return false
end

local function velocityMoveSlow(targetPos, timeout, speedOverride)
    timeout = timeout or 40
    local hum, hrp = getHum(), getHRP()
    if not hum or not hrp then return false end
    keepHealth()
    local t0 = os.clock()
    local slowSpeed = speedOverride or config.SLOW_SPEED or 1000
    while isRunning and os.clock() - t0 < timeout do
        hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth()
        forceRunningState()
        local d = dist(hrp.Position, targetPos)
        if d < config.ARRIVE_DIST then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            return true
        end
        pcall(function()
            local dir = targetPos - hrp.Position
            if dir.Magnitude > 0 then
                local nrm = dir.Unit
                hrp.AssemblyLinearVelocity = Vector3.new(nrm.X * slowSpeed, hrp.AssemblyLinearVelocity.Y, nrm.Z * slowSpeed)
            end
        end)
        task.wait(0.01)
    end
    pcall(function() local r = getHRP(); if r then r.AssemblyLinearVelocity = Vector3.zero end end)
    return false
end

local function velocityFlyTo(targetPos, timeout, speed)
    timeout = timeout or 20
    speed = speed or config.FLY_HOME_SPEED or 350
    local hum, hrp = getHum(), getHRP()
    if not hum or not hrp then return false end
    keepHealth()
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        if not isRunning then return false end
        hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth()
        forceRunningState()
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
    return false
end

local function flyHomeVelocityOnly()
    log("🏃 BAY VỀ HOME (Velocity State)")
    local arrived = false
    for try = 1, 8 do
        if not isRunning then break end
        forceRunningState()
        velocityFlyTo(config.HOME_POS, 5, 350)
        local rNow = getHRP()
        if rNow and dist(rNow.Position, config.HOME_POS) < 40 then
            arrived = true
            log(string.format("✅ VỀ HOME THÀNH CÔNG (try %d)", try))
            break
        end
        task.wait(0.3)
    end
    local rEnd = getHRP()
    if rEnd then pcall(function()
        rEnd.AssemblyLinearVelocity = Vector3.zero
        rEnd.AssemblyAngularVelocity = Vector3.zero
    end) end
    forceRunningState()
    return arrived
end

local function goHomeWithRecovery()
    log("🏃 BẮT ĐẦU VẬN CHUYỂN EGG VỀ BASE")
    local startTime = os.clock()
    local recoveryAttempts = 0
    local MAX_RECOVERY = config.MAX_RECOVERY or 3

    forceRunningState()

    local t1 = os.clock()
    while os.clock() - t1 < 40 do
        if not isRunning then return false end
        local hum, r = getHum(), getHRP()
        if not hum or not r then break end
        keepHealth()

        -- Nếu bị đánh rơi trứng trong lúc di chuyển về
        if not isCarryingEgg() and recoveryAttempts < MAX_RECOVERY then
            recoveryAttempts = recoveryAttempts + 1
            log(string.format("💥 BỊ RỚT EGG TRÊN ĐƯỜNG! Lượm lại (%d/%d)", recoveryAttempts, MAX_RECOVERY))
            task.wait(config.RECOVERY_WAIT or 0.3)

            local r2 = getHRP()
            if r2 then
                local nearestPrompt, nearestPos = nil, nil
                if currentTarget and currentTarget.pos then
                    nearestPos = currentTarget.pos
                    nearestPrompt = currentTarget.prompt
                else
                    nearestPrompt, nearestPos = findPromptSteal(r2.Position, 300)
                end

                if nearestPos then
                    velocityFlyTo(nearestPos, 12, 350)
                    task.wait(0.2)
                    
                    for i = 1, 4 do
                        firePromptOnce(nearestPrompt)
                        task.wait(0.2)
                        if isCarryingEgg() then break end
                    end

                    if isCarryingEgg() then
                        log("✅ Lượm lại Egg thành công! Tiếp tục về Base...")
                        t1 = os.clock()
                    else
                        log("❌ Lượm lại thất bại -> Hủy Target.")
                        currentTarget = nil
                        return false
                    end
                end
            end
        end

        local hd = dist(Vector3.new(r.Position.X, 0, r.Position.Z), Vector3.new(config.HOME_POS.X, 0, config.HOME_POS.Z))
        if hd < 30 then break end

        pcall(function()
            local targetAir = Vector3.new(config.HOME_POS.X, config.HOME_FLY_ABSOLUTE_Y or 100, config.HOME_POS.Z)
            local dir = targetAir - r.Position
            if dir.Magnitude > 0 then r.AssemblyLinearVelocity = dir.Unit * 350 end
        end)
        task.wait(0.01)
    end

    flyHomeVelocityOnly()
    
    -- Chờ Drop Egg
    local dropWait = 0
    while dropWait < 5 and isCarryingEgg() do
        task.wait(0.2)
        dropWait = dropWait + 0.2
    end

    if not isCarryingEgg() then
        log("🎉 HOÀN TẤT MANG EGG VỀ BASE!")
        if currentTarget and currentTarget.prompt then stolenPrompts[currentTarget.prompt] = true end
        currentTarget = nil -- 🔓 BỎ KHÓA MỤC TIÊU
        return true
    else
        log("❌ Không thể Drop Egg tại Home.")
        currentTarget = nil
        return false
    end
end

local function baitBoss(timeout)
    timeout = timeout or config.BAIT_TIMEOUT
    log("🎯 Bait boss...")
    local t0 = os.clock()
    local hum0, hrp0 = getHum(), getHRP()
    local startHealth = hum0 and hum0.Health or 100
    local startPos = hrp0 and hrp0.Position or Vector3.zero
    while isRunning and os.clock() - t0 < timeout do
        local hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth()
        local vel = hrp.AssemblyLinearVelocity
        if hum:GetState() == Enum.HumanoidStateType.Physics and vel.Magnitude > 30 then return true end
        if vel.Magnitude > 60 and vel.Y > 10 then return true end
        if hum.Health < startHealth - config.KB_HEALTH_DROP then return true end
        if (hrp.Position - startPos).Magnitude > 15 and vel.Magnitude > 30 then return true end
        pcall(function() hum:MoveTo(hrp.Position) end)
        task.wait(0.01)
    end
    return false
end

local function stealAtPos(targetPos, label)
    log("═══ STEAL " .. label)
    local hrp = getHRP()
    if not hrp then return false end

    local d = dist(hrp.Position, targetPos)
    if d > config.ARRIVE_DIST then
        if d > config.MAP_RADIUS then
            teleToMap(targetPos, false)
            task.wait(0.6)
        else
            velocityMoveTo(targetPos, 25)
        end
    end

    local prompt = (currentTarget and currentTarget.prompt) or findPromptSteal(targetPos, 200)
    if not prompt then return false end

    for i = 1, config.MAX_FIRES do
        if not isRunning then return false end
        forceRunningState()
        
        local h2 = getHRP()
        if h2 then
            local p2pos = getPromptPos(prompt)
            if p2pos and dist(h2.Position, p2pos) > config.PROMPT_NEAR_DIST then
                velocityMoveTo(p2pos, 3, true)
            end
            firePromptOnce(prompt)
        end
        task.wait(config.STEAL_VERIFY_WAIT)
        
        if isCarryingEgg() then
            log("✅ STEAL THÀNH CÔNG -> ĐANG CẦM EGG!")
            return true
        end
    end
    return false
end

-- ══════════ MAIN LOOP ══════════
local function mainLoop()
    while isRunning do
        -- Kiểm tra an toàn: Nếu script crash hoặc khởi động lại mà đã cầm Egg -> Đưa về ngay
        if isCarryingEgg() then
            log("🎒 Phát hiện đang cầm Egg sẵn → Đưa trực tiếp về Base!")
            goHomeWithRecovery()
        else
            if cycleStartTime == 0 then cycleStartTime = os.clock() end
            if os.clock() - lastClearTime > 120 then
                lastClearTime = os.clock()
                stolenPrompts = {}
            end

            log("═══════════════════════")
            consecutiveFails = 0
            replacedThisCycle = false
            
            local useSpeed = isFirstCycle and (config.FIRST_CYCLE_SPEED or 400) or config.SLOW_SPEED
            
            log("PHASE 1: VELOCITY SLOW tới Forest")
            local okMove = velocityMoveSlow(config.FOREST_POS, 40, useSpeed)
            
            if okMove then
                isFirstCycle = false
                task.wait(0.3)
                
                -- PHASE 2: Bait boss
                log("PHASE 2: Bait boss")
                local gotKnockback = baitBoss(config.BAIT_TIMEOUT)

                if gotKnockback then
                    local eggPrompt, eggPos, eggScale, eggMap

                    -- BƯỚC 1: Dò tìm Egg Drop theo Cấu Hình (Nếu chưa có Target Locked)
                    if config.BIG_EGG_MODE then
                        eggPrompt, eggPos, eggScale, eggMap = findBiggestEgg()
                    elseif config.PRIORITY_INCOME then
                        eggPrompt, eggPos, eggScale, eggMap = findHighestIncomeEgg()
                    else
                        eggPrompt, eggPos, eggScale, eggMap = findEggInTargets()
                    end

                    if not eggPos then
                        log("⚠ Không tìm thấy Egg Drop phù hợp.")
                        stolenPrompts = {}
                        currentTarget = nil
                        task.wait(1.5)
                    else
                        -- BƯỚC 2: Khóa Target & Thực Hiện Quá Trình Nhặt -> Mang Về
                        log(string.format("🎯 KHÓA TARGET: %s @ %s", tostring(eggPrompt), eggMap.name))
                        
                        teleToMap(eggPos + Vector3.new(0, 3, 0), true)
                        task.wait(0.05)

                        local stolen = stealAtPos(eggPos, eggMap.name)
                        if stolen then
                            -- BƯỚC 3 & 4: Cầm Egg & Vận chuyển tuyệt đối về Home
                            goHomeWithRecovery()
                        else
                            log("❌ Steal thất bại. Bỏ khóa Target để thử lại.")
                            if eggPrompt then stolenPrompts[eggPrompt] = true end
                            currentTarget = nil
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end

-- ══════════ API ══════════
function M.start()
    if isRunning then return end
    stolenPrompts = {}
    deliveryFailed = false
    incomeCache = {}
    lastEggCount = -1
    lastTargetPos = nil
    lastTargetMap = nil
    consecutiveFails = 0
    cycleStartTime = 0
    lastClearTime = os.clock()
    replacedThisCycle = false
    isFirstCycle = true
    currentTarget = nil
    
    task.spawn(function()
        log(string.format("⏳ Warmup %ds...", config.WARMUP_TIME))
        task.wait(config.WARMUP_TIME)
        isRunning = true
        log("▶ START v10.6.4 (State Locked Flow)")
        task.spawn(mainLoop)
    end)
end

function M.stop() 
    isRunning = false
    currentTarget = nil
    log("■ STOP") 
end

function M.isRunning() return isRunning end
function M.setTargets(targetList) config.TARGETS = targetList end
function M.setPriorityIncome(enabled) config.PRIORITY_INCOME = enabled end
function M.setBigEggMode(enabled) config.BIG_EGG_MODE = enabled end

return M
