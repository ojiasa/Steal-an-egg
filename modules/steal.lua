-- ═══════════════════════════════════════════════════════════════
-- STEAL MODULE v10.6.1 — FIX STUCK RECOVERY
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
    FLY_HOME_SPEED      = 350,      -- ⭐ v10.6.1: Giảm từ 500
    DROP_SPEED          = 250,
    RECOVERY_RADIUS     = 500,
    MAX_RECOVERY        = 3,
    RECOVERY_WAIT       = 0.3,
    FOREST_RADIUS       = 300,
    CARRY_WAIT_MAX      = 5,
    PROMPT_NEAR_DIST    = 12,
    PROMPT_SKIP_DIST    = 15,
    SPEED          = 1500,
    SPEED_CAP      = 350,           -- ⭐ v10.6.1: Giảm từ 500
    SLOW_SPEED     = 1000,
    MAP_RADIUS     = 800,
    ARRIVE_DIST    = 10,
    BAIT_TIMEOUT   = 12,            -- ⭐ v10.6.1: Giảm từ 15
    KB_HEALTH_DROP = 0.5,
    MAX_FIRES      = 8,
    MAX_RETRY      = 3,
    STEAL_VERIFY_WAIT = 0.25,       -- ⭐ v10.6.1: Giảm từ 0.35
    CHAT_WAIT      = 2.0,
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
local carryingEggFlag = false
local replacedThisCycle = false

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

local function forceVisible()
    local c = P.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if hrp then pcall(function()
        hrp.Transparency = 1
        hrp.LocalTransparencyModifier = 0
    end) end
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            pcall(function()
                part.Transparency = 0
                part.LocalTransparencyModifier = 0
            end)
        end
        if part:IsA("Decal") then
            pcall(function() part.Transparency = 0 end)
        end
    end
    local animate = c:FindFirstChild("Animate")
    if animate and animate:IsA("BaseScript") then
        pcall(function() animate.Disabled = false end)
    end
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

local function getEggInfoAtPos(eggPos, radius)
    radius = radius or 30
    if not AssetEarnings or not EggState then return 0, 0, nil, nil end
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then
        return 0, 0, nil, nil
    end
    local best, bestDist = nil, radius
    for uid, eggData in pairs(fd.Records) do
        local cf = eggData.BoundsCFrame
        if cf then
            local d = (cf.Position - eggPos).Magnitude
            if d < bestDist then best, bestDist = eggData, d end
        end
    end
    if not best then return 0, 0, nil, nil end
    local input = { Category = best.AssetCategory, Scale = best.AssetScale or 1, Mutations = best.Mutations or {} }
    local income = 0
    local ok2, val = pcall(AssetEarnings.LiveRatePerSecond, input)
    if ok2 and type(val) == "number" and val > 0 then income = val end
    if income == 0 then
        ok2, val = pcall(AssetEarnings.RatePerSecond, input)
        if ok2 and type(val) == "number" and val > 0 then income = val end
    end
    return income, best.AssetScale or 1, best.BaseMutation, best.Uid or best.UID
end

local function findBiggestEgg()
    local hrp = getHRP()
    if not hrp then return nil, nil, nil, nil end
    if not EggState then
        log("❌ EggState nil")
        return nil, nil, nil, nil
    end

    local candidates = {}
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if ok and type(fd) == "table" and type(fd.Records) == "table" then
        for uid, eggData in pairs(fd.Records) do
            local cf = eggData.BoundsCFrame
            if cf then
                local pos = cf.Position
                if dist(pos, config.HOME_POS) > 150 then
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
    end

    if #candidates == 0 then
        log("⚠ Records trống → scan prompt workspace")
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
        if #candidates == 0 then
            log("⚠ Không có prompt egg nào")
            return nil, nil, nil, nil
        end
        local myPos = hrp.Position
        table.sort(candidates, function(a, b)
            return dist(a.pos, myPos) < dist(b.pos, myPos)
        end)
        local best = candidates[1]
        return best.prompt, best.pos, best.scale, best.map
    end

    table.sort(candidates, function(a, b)
        if a.avgSize ~= b.avgSize then return a.avgSize > b.avgSize end
        return a.scale > b.scale
    end)

    log("🥚 TOP egg size:")
    for i = 1, math.min(5, #candidates) do
        local c = candidates[i]
        local mut = c.mutation and (" [" .. c.mutation .. "]") or ""
        log(string.format("  [%d] %s%s @ %s = bounds %.2f (state=%s)",
            i, c.category, mut, c.map.name, c.avgSize, c.rawState))
    end

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
        if isOtherHolder(cand.rawState) then
            log(string.format("⏭ Skip %s — state='%s'", cand.category, cand.rawState))
        else
            local uidMatch = nil
            for _, p in ipairs(allPrompts) do
                local pUID = p.prompt:GetAttribute("EggUid") 
                    or p.prompt:GetAttribute("EggUID")
                    or p.prompt:GetAttribute("Uid")
                if not pUID and p.prompt.Parent then
                    pUID = p.prompt.Parent:GetAttribute("EggUid")
                        or p.prompt.Parent:GetAttribute("EggUID")
                end
                if pUID and pUID == cand.uid then
                    uidMatch = p
                    log(string.format("✅ Match UID: %s @ %s", cand.category, cand.map.name))
                    break
                end
            end
            
            if not uidMatch then
                for _, p in ipairs(allPrompts) do
                    local d = dist(p.pos, cand.pos)
                    if d < 5 then
                        uidMatch = p
                        log(string.format("✅ Match POS: %s (%.1f studs)", cand.category, d))
                        break
                    end
                end
            end
            
            if uidMatch then
                matchedPrompt = uidMatch
                matchedPos = cand.pos
                matchedCand = cand
                break
            else
                log(string.format("⚠ Không match %s", cand.category))
            end
        end
    end

    if not matchedPrompt then
        log("❌ Không match prompt → clear")
        stolenPrompts = {}
        return nil, nil, nil, nil
    end

    log(string.format("🎯 CHỌN BIG: %s @ %s = bounds %.2f",
        matchedCand.category, matchedCand.map.name, matchedCand.avgSize))

    return matchedPrompt, matchedPos, matchedCand.scale, matchedCand.map
end

local function findHighestIncomeEgg()
    local hrp = getHRP()
    if not hrp then return nil, nil, nil, nil end
    if not EggState or not AssetEarnings then return nil, nil, nil, nil end
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then
        return nil, nil, nil, nil
    end
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
                            category = eggData.AssetCategory,
                            scale = eggData.AssetScale or 1,
                            mutation = eggData.BaseMutation,
                            rawState = tostring(eggData.State or "slot"):lower(),
                        })
                    end
                end
            end
        end
    end
    if #candidates == 0 then
        log("⚠ Không có egg >= ngưỡng")
        return nil, nil, nil, nil
    end
    table.sort(candidates, function(a, b)
        if a.income ~= b.income then return a.income > b.income end
        return a.scale > b.scale
    end)
    log("💰 TOP income:")
    for i = 1, math.min(5, #candidates) do
        local c = candidates[i]
        log(string.format("  [%d] %s @ %s = $%.2f/s", i, c.category, c.map.name, c.income))
    end
    local best = candidates[1]
    local bestPrompt = nil
    local bestPromptDist = 5
    for _, v in ipairs(W:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg"
                    and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEgg then
                local ppos = getPromptPos(v)
                if ppos then
                    local d = (ppos - best.pos).Magnitude
                    if d < bestPromptDist then bestPrompt = v; bestPromptDist = d end
                end
            end
        end
    end
    if not bestPrompt then
        stolenPrompts = {}
        return nil, nil, nil, nil
    end
    log(string.format("🎯 CHỌN: %s = $%.2f/s", best.category, best.income))
    return bestPrompt, best.pos, best.income, best.map
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

local function findEggInTargets()
    local hrp = getHRP()
    if not hrp then return nil, nil, nil, nil end
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
    if #candidates == 0 then return nil, nil, nil, nil end
    if config.PREFER_FAR then
        table.sort(candidates, function(a, b) return a.dFromHome > b.dFromHome end)
    else
        table.sort(candidates, function(a, b) return a.dFromPlayer < b.dFromPlayer end)
    end
    local best = candidates[1]
    return best.prompt, best.pos, best.dFromPlayer, best.map
end

local function findPromptSteal(pos, radius)
    radius = radius or config.MAP_RADIUS
    local best, bestDist = nil, radius
    for _, v in ipairs(W:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg"
                    and (v.ActionText or ""):lower():find("steal", 1, true))
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

-- ══════════ ANIMATION ══════════
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
                local a = Instance.new("Animation")
                a.AnimationId = id
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
                local new = tpl:Clone()
                new.Parent = c
                new.Disabled = false
                return
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
        forceVisible()
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
    else
        log("⏭ Skip replace (đã replace cycle này)")
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
        local d = dist(hrp.Position, ppos)
        if d > config.PROMPT_SKIP_DIST then return false end
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
        local moved = dist(hrp.Position, lastPos)
        if moved < 0.3 then
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

local function velocityMoveSlow(targetPos, timeout)
    timeout = timeout or 40
    local hum, hrp = getHum(), getHRP()
    if not hum or not hrp then return false end
    keepHealth()
    
    local t0 = os.clock()
    local lastPos = hrp.Position
    local stuckTime = os.clock()
    local slowSpeed = config.SLOW_SPEED or 1000
    
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
        
        local moved = dist(hrp.Position, lastPos)
        if moved < 0.3 then
            if os.clock() - stuckTime > 0.8 then
                pcall(function() hum.Jump = true end)
                stuckTime = os.clock()
            end
        else
            lastPos = hrp.Position
            stuckTime = os.clock()
        end
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
            if dir.Magnitude > 0 then
                hrp.AssemblyLinearVelocity = dir.Unit * speed
            end
        end)
        task.wait(0.01)
    end
    return false
end

local function goHomeWithRecovery()
    log("🏃 BAY VỀ HOME")
    local startTime = os.clock()
    local lastHealth = nil
    local recoveryAttempts = 0
    local MAX_RECOVERY = config.MAX_RECOVERY or 3
    local restartCount = 0
    local MAX_RESTART = 5
    local flyY = config.HOME_FLY_ABSOLUTE_Y or 100

    forceRunningState()

    local t1 = os.clock()
    while os.clock() - t1 < 40 do
        if not isRunning then return false end
        if os.clock() - startTime > 60 then
            log("🚨 TIMEOUT → FORCE TELE")
            forceTeleHome()
            break
        end
        if restartCount >= MAX_RESTART then
            forceTeleHome()
            break
        end
        local hum, r = getHum(), getHRP()
        if not hum or not r then break end
        keepHealth()
        if r.Position.Y < 10 then
            forceTeleHome()
            break
        end

        local vel = r.AssemblyLinearVelocity
        local speed = vel.Magnitude
        local state = hum:GetState()
        local hpNow = hum.Health

        if state == Enum.HumanoidStateType.Physics 
            or state == Enum.HumanoidStateType.PlatformStanding
            or state == Enum.HumanoidStateType.FallingDown then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
        end

        local gotHit = false
        if state == Enum.HumanoidStateType.Physics and speed > 30 then
            gotHit = true
        elseif lastHealth and math.abs(hpNow - lastHealth) > 0.5 then
            gotHit = true
        end
        lastHealth = hpNow

        if gotHit and recoveryAttempts < MAX_RECOVERY then
            recoveryAttempts = recoveryAttempts + 1
            restartCount = restartCount + 1
            log(string.format("💥 KNOCKBACK (%d/%d)", recoveryAttempts, MAX_RECOVERY))
            task.wait(config.RECOVERY_WAIT or 0.3)

            local r2 = getHRP()
            if r2 then
                stolenPrompts = {}
                local searchPos = lastTargetPos or r2.Position

                local nearestPrompt, nearestPos, nearestScore = nil, nil, 999999
                for _, v in ipairs(W:GetDescendants()) do
                    if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                        local isEgg = v.Name == "CarryAreaEgg"
                            or ((v.ObjectText or "") == "Egg"
                                and (v.ActionText or ""):lower():find("steal", 1, true))
                        if isEgg then
                            local ppos = getPromptPos(v)
                            if ppos then
                                local dTarget = dist(ppos, searchPos)
                                local dPlayer = dist(ppos, r2.Position)
                                local score = dTarget * 0.7 + dPlayer * 0.3
                                if score < nearestScore then
                                    nearestPrompt, nearestPos, nearestScore = v, ppos, score
                                end
                            end
                        end
                    end
                end

                if nearestPrompt and nearestPos then
                    local stillDropped = true
                    if EggState then
                        local found = false
                        pcall(function()
                            local fd = EggState.ReadFieldEggs()
                            if fd and fd.Records then
                                for uid, ed in pairs(fd.Records) do
                                    local cf = ed.BoundsCFrame
                                    if cf and dist(cf.Position, nearestPos) < 15 then
                                        found = true
                                        local st = tostring(ed.State or ""):lower()
                                        if st == "dropped" then
                                            stillDropped = true
                                        elseif isOtherHolder(st) then
                                            stillDropped = false
                                            log(string.format("⏭ Egg bị giữ (state='%s') → BỎ", st))
                                        end
                                        break
                                    end
                                end
                            end
                        end)
                        if not found then stillDropped = true end
                    end

                    if stillDropped then
                        log(string.format("🎯 Egg rớt → LƯỢM (cách %.0f)", 
                            dist(nearestPos, searchPos)))

                        local dToEgg = dist(r2.Position, nearestPos)
                        if dToEgg > 500 then
                            log("📍 Xa > 500 → tele KHÔNG replace")
                            teleToMap(nearestPos, false)
                        else
                            -- ⭐ v10.6.1: FIX - Timeout 12, speed 350 (thay vì 20, SPEED_CAP)
                            velocityFlyTo(nearestPos, 12, 350)
                        end
                        task.wait(0.4)
                        
                        local slotsBefore = getSlotSet()
                        local pickupSuccess = false
                        -- ⭐ v10.6.1: FIX - Fire 3 lần (thay vì MAX_FIRES = 8)
                        for i = 1, 3 do
                            if not isRunning then break end
                            forceRunningState()
                            local h3 = getHRP()
                            if h3 then
                                -- ⭐ v10.6.1: FIX - Radius 120 (thay vì 200)
                                local p3 = findPromptSteal(h3.Position, 120)
                                if p3 then
                                    local p3pos = getPromptPos(p3)
                                    if p3pos and dist(h3.Position, p3pos) > 8 then
                                        velocityMoveTo(p3pos, 2, true)
                                    end
                                    firePromptOnce(p3)
                                    pickupSuccess = true
                                else
                                    break
                                end
                            end
                            task.wait(0.2)
                            local ok, _ = hasStolenSlot(slotsBefore)
                            if ok then 
                                log("✅ Lượm OK")
                                pickupSuccess = true
                                break 
                            end
                        end
                        
                        if not pickupSuccess then
                            log("⚠ Lượm không được → SKIP")
                            stolenPrompts = {}
                        end
                        lastTargetPos = nearestPos
                    else
                        log("⏭ Egg không còn dropped → tiếp tục về")
                    end

                    lastHealth = nil
                    recoveryAttempts = 0
                    -- ⭐ v10.6.1: CRITICAL FIX - Reset t1 để thoát loop
                    t1 = os.clock()
                end
            end
        end

        local dx = config.HOME_POS.X - r.Position.X
        local dz = config.HOME_POS.Z - r.Position.Z
        local hd = math.sqrt(dx*dx + dz*dz)
        if hd < 30 then break end

        pcall(function()
            local targetAir = Vector3.new(config.HOME_POS.X, flyY, config.HOME_POS.Z)
            local dir = targetAir - r.Position
            if dir.Magnitude > 0 then
                r.AssemblyLinearVelocity = dir.Unit * 350
            end
        end)
        task.wait(0.01)
    end

    velocityFlyTo(config.HOME_POS, 5, config.DROP_SPEED or 250)
    local rEnd = getHRP()
    if rEnd then pcall(function()
        rEnd.AssemblyLinearVelocity = Vector3.zero
        rEnd.AssemblyAngularVelocity = Vector3.zero
    end) end
    forceVisible()
    forceRunningState()
    log(string.format("✅ Về home (%.2fs)", os.clock() - startTime))
    return true
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
        local speed = vel.Magnitude
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Physics and speed > 30 then
            log(string.format("💥 PHYSICS %.1f", speed)); return true
        end
        if speed > 60 and vel.Y > 10 then
            log(string.format("💥 VELOCITY")); return true
        end
        if startHealth and hum.Health < startHealth - config.KB_HEALTH_DROP then
            log(string.format("💥 HEALTH")); return true
        end
        if startPos then
            local pd = (hrp.Position - startPos).Magnitude
            if pd > 15 and speed > 30 then
                log(string.format("💥 SHIFT")); return true
            end
        end
        pcall(function() hum:MoveTo(hrp.Position) end)
        task.wait(0.01)
    end
    log("⚠ Hết " .. timeout .. "s")
    return false
end

local function stealAtPos(targetPos, label)
    log("═══ STEAL " .. label)
    task.wait(0.05)

    local hrp = getHRP()
    if not hrp then return false end

    local d = dist(hrp.Position, targetPos)
    if d > config.ARRIVE_DIST then
        if d > config.MAP_RADIUS then
            log(string.format("📍 Xa %.0f → TELE", d))
            teleToMap(targetPos, false)
            task.wait(0.6)
        else
            log(string.format("🏃 Cách %.0f → VELOCITY", d))
            velocityMoveTo(targetPos, 25)
        end
    end

    local carrying = isCarryingEgg()
    if carrying then
        log("⚠ Đang carry → chờ drop")
        local waitStart = os.clock()
        while os.clock() - waitStart < config.CARRY_WAIT_MAX do
            if not isRunning then return false end
            task.wait(0.3)
            if not isCarryingEgg() then break end
        end
    end

    local prompt = findPromptSteal(targetPos, 200)
    if not prompt then 
        log("⚠ Không có prompt")
        return false 
    end

    local slotsBefore, countBefore = getSlotSet()
    log("📊 Slots trước: " .. countBefore)

    for i = 1, config.MAX_FIRES do
        if not isRunning then return false end
        forceRunningState()
        
        local h2 = getHRP()
        if h2 then
            local p2 = findPromptSteal(h2.Position, 200)
            if not p2 then
                log("⚠ Prompt biến mất → return")
                return false
            end
            local p2pos = getPromptPos(p2)
            if p2pos and dist(h2.Position, p2pos) > config.PROMPT_NEAR_DIST then
                velocityMoveTo(p2pos, 3, true)
            end
            firePromptOnce(p2)
        end
        task.wait(config.STEAL_VERIFY_WAIT)
        local _, countNow = getSlotSet()
        local stolen, slotName = hasStolenSlot(slotsBefore)
        if stolen then
            log("✅ ĐÃ STEAL — slot " .. slotName)
            return true
        end
        if i == 3 then
            local t0 = os.clock()
            while os.clock() - t0 < 1.5 do
                forceRunningState()
                task.wait(0.05)
            end
        end
    end
    log("⚠ Fire " .. config.MAX_FIRES .. " lần không giảm")
    return false
end

local function checkEggReset()
    local _, count = getSlotSet()
    if lastEggCount >= 0 and count > lastEggCount + 10 then
        log("🔄 Egg reset!")
        stolenPrompts = {}
        return true
    end
    lastEggCount = count
    return false
end

local function startWatchdog()
    task.spawn(function()
        lastMoveCheck = os.clock()
        lastMovePos = nil
        local tick = 0
        while isRunning do
            task.wait(0.5)
            if not isRunning then break end
            tick = tick + 1
            forceRunningState()
            local c = P.Character
            if c then
                local hrpC = c:FindFirstChild("HumanoidRootPart")
                if hrpC and hrpC.Transparency > 0.1 then
                    forceVisible()
                end
            end
            if tick % 4 == 0 then
                local hrp = getHRP()
                if hrp then
                    if lastMovePos then
                        if dist(hrp.Position, lastMovePos) < 5 then
                            if os.clock() - lastMoveCheck > 15 then
                                log("🚨 Đứng yên >15s → TELE HOME")
                                forceTeleHome()
                                lastMoveCheck = os.clock()
                                lastMovePos = nil
                            end
                        else
                            lastMovePos = hrp.Position
                            lastMoveCheck = os.clock()
                        end
                    else
                        lastMovePos = hrp.Position
                        lastMoveCheck = os.clock()
                    end
                end
            end
        end
    end)
end

-- ══════════ MAIN LOOP ══════════
local function mainLoop()
    while isRunning do
        if cycleStartTime > 0 and os.clock() - cycleStartTime > 90 then
            log("🚨 90s → RESET")
            stolenPrompts = {}
            consecutiveFails = 0
            forceTeleHome()
            task.wait(1)
            cycleStartTime = os.clock()
        end
        if cycleStartTime == 0 then cycleStartTime = os.clock() end
        if os.clock() - lastClearTime > 120 then
            lastClearTime = os.clock()
            stolenPrompts = {}
        end

        log("═══════════════════════")
        pcall(checkEggReset)
        consecutiveFails = 0
        replacedThisCycle = false
        log("PHASE 1: VELOCITY SLOW tới Forest")

        if not velocityMoveSlow(config.FOREST_POS, 40) then
            if not isRunning then break end
            log("❌ Không tới Forest → thử lại")
            task.wait(1)
        else
            log("✅ Tới Forest (velocity 1000)")
            task.wait(0.3)
            local prompt, ppos = findForestEggOnly()

            if prompt and ppos then
                log(string.format("🎯 Forest egg @ %.1f,%.1f,%.1f", ppos.X, ppos.Y, ppos.Z))
                local hrp = getHRP()
                if hrp and dist(hrp.Position, ppos) > config.ARRIVE_DIST then
                    velocityMoveTo(ppos, 20)
                end
                local forestBefore = getSlotSet()
                log("⚡ Steal Forest")
                for i = 1, 5 do
                    if not isRunning then break end
                    forceRunningState()
                    local h2 = getHRP()
                    if h2 then
                        local p2 = findPromptSteal(h2.Position, config.FOREST_RADIUS)
                        if p2 then firePromptOnce(p2) end
                    end
                    task.wait(0.3)
                    local stolen = hasStolenSlot(forestBefore)
                    if stolen then log("🎒 Forest OK"); break end
                end
                stolenPrompts[prompt] = true
                task.wait(0.1)

                log("PHASE 3: Bait boss")
                local gotKnockback = baitBoss(config.BAIT_TIMEOUT)

                if gotKnockback then
                    local eggPrompt, eggPos, eggDist, eggMap

                    if config.BIG_EGG_MODE then
                        log("🥚 BIG EGG mode")
                        eggPrompt, eggPos, eggDist, eggMap = findBiggestEgg()
                    end

                    if not eggPos and config.PRIORITY_INCOME then
                        log("💰 PRIORITY INCOME")
                        eggPrompt, eggPos, eggDist, eggMap = findHighestIncomeEgg()
                    end

                    if not eggPos then
                        log("PHASE 4: Egg trong " .. #config.TARGETS .. " map")
                        eggPrompt, eggPos, eggDist, eggMap = findEggInTargets()
                    end

                    if not eggPos then
                        log("⚠ Không tìm egg → clear + về Forest 1.5s")
                        stolenPrompts = {}
                        consecutiveFails = 0
                        task.wait(1.5)
                    else
                        log(string.format("🎯 Map: %s @ %.1f,%.1f,%.1f",
                            eggMap.name, eggPos.X, eggPos.Y, eggPos.Z))
                        lastTargetPos = eggPos
                        lastTargetMap = eggMap

                        local targetPos = eggPos + Vector3.new(0, 3, 0)
                        local success = false
                        for attempt = 1, config.MAX_RETRY do
                            if not isRunning then break end
                            if consecutiveFails >= 5 then
                                log("🚨 FAIL 5 LẦN → về Forest")
                                stolenPrompts = {}
                                consecutiveFails = 0
                                lastTargetPos = nil
                                forceTeleHome()
                                task.wait(1)
                                break
                            end

                            log(string.format("🔄 ATTEMPT %d/%d (fails: %d)",
                                attempt, config.MAX_RETRY, consecutiveFails))
                            deliveryFailed = false

                            local stealPos = eggPos
                            local stealMap = eggMap
                            local stealTarget = targetPos

                            if attempt > 1 and lastTargetPos then
                                log("🔄 Retry: clear stolenPrompts")
                                stolenPrompts = {}
                                local p, ppos, pd = nil, nil, 500
                                for _, v in ipairs(W:GetDescendants()) do
                                    if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                                        local isEgg = v.Name == "CarryAreaEgg"
                                            or ((v.ObjectText or "") == "Egg"
                                                and (v.ActionText or ""):lower():find("steal", 1, true))
                                        if isEgg then
                                            local pp = getPromptPos(v)
                                            if pp then
                                                local d = (pp - lastTargetPos).Magnitude
                                                if d < pd then p, ppos, pd = v, pp, d end
                                            end
                                        end
                                    end
                                end
                                if p and ppos then
                                    log(string.format("🔄 Retry: egg cũ cách %.0f", pd))
                                    stealPos = ppos
                                    stealMap = getEggRealMap(ppos) or eggMap
                                    stealTarget = ppos + Vector3.new(0, 3, 0)
                                else
                                    log("⚠ Không có egg cũ → tìm mới")
                                    local np, npos, nd, nm
                                    if config.BIG_EGG_MODE then
                                        np, npos, nd, nm = findBiggestEgg()
                                    elseif config.PRIORITY_INCOME then
                                        np, npos, nd, nm = findHighestIncomeEgg()
                                    else
                                        np, npos, nd, nm = findEggInTargets()
                                    end
                                    if npos and nm then
                                        stealPos, stealMap = npos, nm
                                        stealTarget = npos + Vector3.new(0, 3, 0)
                                    else
                                        break
                                    end
                                end
                            end

                            if attempt == 1 then
                                log("📍 Tele + replace từ Forest → map")
                            end
                            teleToMap(stealTarget, attempt == 1)
                            task.wait(0.05)

                            local stolen = stealAtPos(stealPos, stealMap.name)
                            if stolen then
                                consecutiveFails = 0
                                goHomeWithRecovery()
                                task.wait(config.CHAT_WAIT)
                                if deliveryFailed then
                                    consecutiveFails = consecutiveFails + 1
                                    log(string.format("❌ Delivery fail (%d)", consecutiveFails))
                                    task.wait(1)
                                else
                                    log("🎉 THÀNH CÔNG")
                                    success = true
                                    lastTargetPos = nil
                                    lastTargetMap = nil
                                    consecutiveFails = 0
                                    cycleStartTime = os.clock()
                                    replacedThisCycle = false
                                    break
                                end
                            else
                                consecutiveFails = consecutiveFails + 1
                                log(string.format("⚠ Steal fail (%d)", consecutiveFails))
                                if attempt >= 2 then
                                    stolenPrompts = {}
                                    local np, npos, nd, nm
                                    if config.BIG_EGG_MODE then
                                        np, npos, nd, nm = findBiggestEgg()
                                    elseif config.PRIORITY_INCOME then
                                        np, npos, nd, nm = findHighestIncomeEgg()
                                    else
                                        np, npos, nd, nm = findEggInTargets()
                                    end
                                    if npos and nm and npos ~= stealPos then
                                        stealPos, stealMap = npos, nm
                                        stealTarget = npos + Vector3.new(0, 3, 0)
                                        lastTargetPos = npos
                                    end
                                end
                                task.wait(0.5)
                            end
                        end

                        if success then
                            deliveryFailed = false
                            log("🎉 HOÀN THÀNH")
                        else
                            log("❌ Hết retry")
                            lastTargetPos = nil
                        end
                    end
                end
            else
                log("⚠ Không có Forest egg")
            end
        end
        if not isRunning then break end
        task.wait(0.5)
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
        local chatEvents = RS:WaitForChild("DefaultChatSystemChatEvents", 5)
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
                log("❌ Delivery failed")
            elseif msg:find("already carrying", 1, true)
                or msg:find("carry denied", 1, true) then
                log("⚠ Already carrying")
            elseif msg:find("get closer", 1, true)
                or msg:find("knocked down", 1, true)
                or msg:find("cannot carry", 1, true) then
                log("⚠ Get closer/knocked down")
                task.spawn(function()
                    local t0 = os.clock()
                    while os.clock() - t0 < 1.5 do
                        forceRunningState()
                        task.wait(0.05)
                    end
                end)
            end
        end)
    end)
end)

-- ══════════ API ══════════
function M.start()
    if isRunning then return end
    installBypass()
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
    isRunning = true
    log("▶ START v10.6.1 - FIX STUCK RECOVERY")
    startWatchdog()
    task.spawn(mainLoop)
end

function M.stop() isRunning = false; log("■ STOP") end
function M.isRunning() return isRunning end

function M.setTargets(targetList)
    if type(targetList) ~= "table" then return end
    config.TARGETS = targetList
    local names = {}
    for _, t in ipairs(targetList) do table.insert(names, t.name) end
    log("🎯 Targets: " .. table.concat(names, ", "))
end

function M.setTarget(name, pos)
    config.TARGETS = { { name = name, pos = pos } }
end

function M.setPriorityIncome(enabled)
    config.PRIORITY_INCOME = enabled and true or false
    return config.PRIORITY_INCOME
end

function M.isPriorityIncome() return config.PRIORITY_INCOME end
function M.togglePriorityIncome() return M.setPriorityIncome(not config.PRIORITY_INCOME) end

function M.setPriorityThreshold(amount)
    config.PRIORITY_THRESHOLD = amount or 1000000
end

function M.getPriorityThreshold() return config.PRIORITY_THRESHOLD end
function M.clearIncomeCache() incomeCache = {} end

function M.setBigEggMode(enabled)
    config.BIG_EGG_MODE = enabled and true or false
    return config.BIG_EGG_MODE
end

function M.isBigEggMode() return config.BIG_EGG_MODE end
function M.toggleBigEggMode() return M.setBigEggMode(not config.BIG_EGG_MODE) end

function M.setHomeFlyY(n) config.HOME_FLY_ABSOLUTE_Y = n or 100 end
function M.setForestRadius(n) config.FOREST_RADIUS = n or 300 end
function M.setFlyHomeSpeed(n) config.FLY_HOME_SPEED = n or 350 end
function M.setRecoveryRadius(n) config.RECOVERY_RADIUS = n or 500 end
function M.setMaxRecovery(n) config.MAX_RECOVERY = n or 3 end
function M.setSlowSpeed(n) config.SLOW_SPEED = n or 1000 end

function M.getAllMaps() return ALL_MAPS end
function M.setHome(p) if p then config.HOME_POS = p end end
function M.setForest(p) if p then config.FOREST_POS = p end end
function M.getConfig() return config end

return M

