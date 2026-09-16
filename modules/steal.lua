-- ═══════════════════════════════════════════════════════════════
-- STEAL MODULE v10.3
-- Flow: Home → Forest (velocity) → Bait boss → Knockback → TELE tới egg
--       → Steal → Về home → Check egg còn trên map?
-- v10.3: Fix tele sớm về home, warmup bait, giữ im sau tele
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

    FOREST_RUN_SPEED    = 150,
    FOREST_RUN_TIMEOUT  = 60,
    FOREST_RADIUS       = 300,

    -- ⭐ v10.3: Warmup times
    FOREST_WARMUP       = 1.0,    -- đứng yên tại forest trước khi steal/bait
    BAIT_WARMUP         = 1.0,    -- đứng yên trước khi detect knockback
    TELE_HOLD           = 0.8,    -- giữ im sau tele
    TELE_STABILIZE      = 0.5,    -- chờ thêm sau tele

    BAIT_TIMEOUT   = 15,
    KB_HEALTH_DROP = 0.1,

    SPEED          = 1500,
    SPEED_CAP      = 500,
    MAP_RADIUS     = 800,
    ARRIVE_DIST    = 10,
    PROMPT_NEAR    = 12,
    MAX_FIRES      = 8,
    MAX_RETRY      = 3,
    STEAL_VERIFY_WAIT = 0.35,
    STEAL_TIMEOUT  = 1.5,
    CHAT_WAIT      = 1.5,          -- ⭐ v10.3: 1.5s theo yêu cầu
    EGG_VERIFY_R   = 40,

    CYCLE_TIMEOUT  = 120,
    WAIT_BETWEEN   = 1.0,
}

local isRunning      = false
local stolenPrompts  = {}
local stolenEggUids  = {}
local deliveryFailed = false
local logCallbacks   = {}
local lastEggCount   = -1
local cycleStartTime = 0
local lastStolenUid  = nil
local lastStolenPos  = nil

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

local function forceRunningState()
    local hum = getHum()
    if hum then pcall(function()
        hum.PlatformStand = false
        hum.Sit = false
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Physics
            or state == Enum.HumanoidStateType.PlatformStanding
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Ragdoll then
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end) end
end

-- ⭐ v10.3: Giữ nhân vật im hoàn toàn (velocity + angular = 0, CFrame giữ nguyên)
local function freezeAt(position, duration)
    duration = duration or 0.5
    local t0 = os.clock()
    while os.clock() - t0 < duration do
        if not isRunning then return end
        local hum, hrp = getHum(), getHRP()
        if not hum or not hrp then return end
        keepHealth()
        forceRunningState()
        pcall(function()
            if position then
                hrp.CFrame = CFrame.new(position)
            end
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        pcall(function() hum:MoveTo(hrp.Position) end)
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

-- ⭐ v10.3: Chỉ dùng EggState (chặt, không false positive)
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
    -- Fallback: prompt Drop
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
                log("   ↳ Không có trong Records → ĐÃ STEAL OK")
                return false, "not-in-records"
            end

            local state = tostring(eggData.State or ""):lower()
            log("   ↳ Egg state: " .. state)

            if state == "collected" or state == "stored" or state == "owned"
                or state == "sold" then
                return false, "collected"
            end

            if eggData.BoundsCFrame then
                local pos = eggData.BoundsCFrame.Position
                if originalPos then
                    local d = (pos - originalPos).Magnitude
                    log(string.format("   ↳ Vị trí: %.1f,%.1f,%.1f (cách gốc %.1f)",
                        pos.X, pos.Y, pos.Z, d))
                end
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
                            log(string.format("   ↳ Prompt Steal gần vị trí gốc (%.1f)", d))
                            return true, "prompt-near"
                        end
                    end
                end
            end
        end
    end

    log("   ↳ Không tìm thấy dấu vết → coi như đã steal")
    return false, "not-found"
end

local function getEggInfoAtPos(eggPos, radius)
    radius = radius or 30
    if not AssetEarnings or not EggState then return 0, 0 end
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then return 0, 0 end
    local best, bestDist = nil, radius
    for _, ed in pairs(fd.Records) do
        local cf = ed.BoundsCFrame
        if cf then
            local d = (cf.Position - eggPos).Magnitude
            if d < bestDist then best, bestDist = ed, d end
        end
    end
    if not best then return 0, 0 end
    local input = { Category = best.AssetCategory, Scale = best.AssetScale or 1, Mutations = best.Mutations or {} }
    local income = 0
    local ok2, val = pcall(AssetEarnings.LiveRatePerSecond, input)
    if ok2 and type(val) == "number" and val > 0 then income = val end
    if income == 0 then
        ok2, val = pcall(AssetEarnings.RatePerSecond, input)
        if ok2 and type(val) == "number" and val > 0 then income = val end
    end
    return income, best.AssetScale or 1
end

local function findBiggestEgg()
    if not EggState then return nil, nil, nil, nil, nil end
    local candidates = {}
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if ok and type(fd) == "table" and type(fd.Records) == "table" then
        for uid, eggData in pairs(fd.Records) do
            if not stolenEggUids[uid] then
                local cf = eggData.BoundsCFrame
                if cf then
                    local pos = cf.Position
                    if dist(pos, config.HOME_POS) > 100 then
                        local st = tostring(eggData.State or ""):lower()
                        if st ~= "carried" and st ~= "carry" and st ~= "carrying"
                            and st ~= "held" and st ~= "picked" then
                            local bs = eggData.BoundsSize
                            local avgSize = bs and ((bs.X + bs.Y + bs.Z) / 3)
                                or (3.5 * (eggData.AssetScale or 1))
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
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    if #candidates == 0 then
        log("⚠ Không có egg nào trong Records")
        return nil, nil, nil, nil, nil
    end
    table.sort(candidates, function(a, b)
        if a.avgSize ~= b.avgSize then return a.avgSize > b.avgSize end
        return a.scale > b.scale
    end)
    log(string.format("🥚 TOP %d egg (toàn map):", math.min(5, #candidates)))
    for i = 1, math.min(5, #candidates) do
        local c = candidates[i]
        local mut = c.mutation and (" [" .. c.mutation .. "]") or ""
        log(string.format("  [%d] %s%s @ %s = bounds %.2f (kg %.2f)",
            i, c.category, mut, c.map.name, c.avgSize, c.scale))
    end
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
            log(string.format("✅ Chọn #%d: %s @ %s (bounds %.2f)",
                i, c.category, c.map.name, c.avgSize))
            return prompt, c.pos, c.scale, c.map, c.uid
        else
            if c.uid then stolenEggUids[c.uid] = true end
            log(string.format("⏭ #%d không tồn tại → skip", i))
        end
    end
    log("❌ Không còn egg nào tồn tại")
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
            log(string.format("✅ Chọn: %s = $%.2f/s", c.category, c.income))
            return prompt, c.pos, c.income, c.map, c.uid
        else
            if c.uid then stolenEggUids[c.uid] = true end
        end
    end
    return nil, nil, nil, nil, nil
end

local function findEggInTargets()
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
    if #candidates == 0 then return nil, nil, nil, nil, nil end
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

-- ══════════ ANIMATION ══════════
local function restoreAnimations()
    local c = P.Character; if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid"); if not hum then return end
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
    local c = P.Character; if not c then return end
    pcall(function()
        local old = c:FindFirstChild("Animate")
        if old then old:Destroy() end
        task.wait(0.1)
        local starter = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts")
        if starter then
            local tpl = starter:FindFirstChild("Animate")
            if tpl then
                local new = tpl:Clone(); new.Parent = c; new.Disabled = false; return
            end
        end
        local ps = P:FindFirstChild("PlayerScripts")
        if ps then
            local tpl = ps:FindFirstChild("Animate")
            if tpl then
                local new = tpl:Clone(); new.Parent = c; new.Disabled = false
            end
        end
    end)
end

local function replaceHumanoidDirect()
    local c = P.Character; if not c then return false end
    local old = c:FindFirstChildOfClass("Humanoid"); if not old then return false end
    local savedHip = old.HipHeight or 2
    local savedJump = old.JumpPower or 50
    local savedMax = old.MaxHealth or 100
    local savedHP = old.Health or 100
    local savedRig = old.RigType or Enum.HumanoidRigType.R15
    local savedSlope = old.MaxSlopeAngle or 89
    pcall(function() old:Destroy() end)
    local new = Instance.new("Humanoid"); new.Parent = c
    pcall(function()
        new.HipHeight = savedHip
        new.JumpPower = savedJump
        new.MaxHealth = savedMax
        new.Health = savedHP
        new.WalkSpeed = 60
        new.RigType = savedRig
        new.MaxSlopeAngle = savedSlope
        new.AutoRotate = true
        new:SetStateEnabled(Enum.HumanoidStateType.Dying, false)
        new:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        new:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        new:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
        new:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
        new:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        new:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end)
    pcall(function()
        if not c:FindFirstChildOfClass("Animator") then
            local a = Instance.new("Animator"); a.Parent = new
        end
    end)
    task.spawn(restoreAnimations)
    task.spawn(function()
        task.wait(0.1)
        resetAnimateScript()
        task.wait(0.2)
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end) end
    end)
    return true
end

-- ⭐⭐⭐ v10.3: TELE + GIỮ IM (chống hất tung)
local function teleToMapStable(targetPos)
    log("📍 TELE + giữ im (chống hất tung)")
    local hrp = getHRP()
    if hrp then pcall(function()
        hrp.CFrame = CFrame.new(targetPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end) end

    replaceHumanoidDirect()

    -- ⭐ v10.3: Giữ im 0.8s (set CFrame+velocity=0 liên tục)
    freezeAt(targetPos, config.TELE_HOLD or 0.8)

    log("   ✅ Humanoid ổn định")
end

local function firePromptOnce(prompt)
    if not prompt or not prompt.Parent then return false end
    forceRunningState()
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

-- ⭐ v10.3: runToForest + đứng yên sau khi tới
local function runToForest()
    log(string.format("🏃 CHẠY RA FOREST (velocity %d)", config.FOREST_RUN_SPEED))
    local t0 = os.clock()
    local lastPos = nil
    local stuckCount = 0
    local arrived = false

    while isRunning and os.clock() - t0 < config.FOREST_RUN_TIMEOUT do
        local hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth(); forceRunningState()

        local d = dist(hrp.Position, config.FOREST_POS)
        if d < config.ARRIVE_DIST + 20 then
            log(string.format("✅ Đã tới Forest (còn %.1f studs, %.1fs)",
                d, os.clock() - t0))
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            arrived = true
            break
        end

        pcall(function()
            local dir = config.FOREST_POS - hrp.Position
            if dir.Magnitude > 0 then
                local nrm = dir.Unit
                hrp.AssemblyLinearVelocity = Vector3.new(
                    nrm.X * config.FOREST_RUN_SPEED,
                    hrp.AssemblyLinearVelocity.Y,
                    nrm.Z * config.FOREST_RUN_SPEED
                )
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

    -- ⭐ v10.3: Đứng yên 1s để humanoid ổn định (tránh momentum)
    log(string.format("   ⏸ Đứng yên %.1fs cho humanoid ổn định...", config.FOREST_WARMUP or 1.0))
    freezeAt(nil, config.FOREST_WARMUP or 1.0)

    return true
end

local function goHome()
    log("🏃 BAY VỀ HOME")
    local startTime = os.clock()
    local flyY = config.HOME_FLY_ABSOLUTE_Y or 100

    local t1 = os.clock()
    while os.clock() - t1 < 20 do
        if not isRunning then return false end
        local hum, r = getHum(), getHRP()
        if not hum or not r then break end
        keepHealth(); forceRunningState()

        if r.Position.Y < 10 then
            log("🚨 Y < 10 → force tele home")
            forceTeleHome()
            break
        end

        local dx = config.HOME_POS.X - r.Position.X
        local dz = config.HOME_POS.Z - r.Position.Z
        local hd = math.sqrt(dx*dx + dz*dz)
        if hd < 30 then
            log("📍 Đến gần home → rớt xuống")
            break
        end

        pcall(function()
            local targetAir = Vector3.new(config.HOME_POS.X, flyY, config.HOME_POS.Z)
            local dir = targetAir - r.Position
            if dir.Magnitude > 0 then
                r.AssemblyLinearVelocity = dir.Unit * (config.FLY_HOME_SPEED or 500)
            end
        end)
        task.wait(0.01)
    end

    log("⬇ Rớt xuống home")
    velocityFlyTo(config.HOME_POS, 8, config.DROP_SPEED or 250)

    -- ⭐ v10.3: Đứng yên tại home 0.5s
    freezeAt(config.HOME_POS, 0.5)

    local rEnd = getHRP()
    if rEnd then pcall(function()
        rEnd.AssemblyLinearVelocity = Vector3.zero
        rEnd.AssemblyAngularVelocity = Vector3.zero
    end) end
    forceRunningState()

    log(string.format("✅ Về home (%.2fs)", os.clock() - startTime))
    return true
end

-- ⭐⭐⭐ v10.3: BAIT BOSS với WARMUP
local function baitBoss(timeout)
    timeout = timeout or config.BAIT_TIMEOUT
    log("🎯 Bait boss...")

    -- ⭐ v10.3: Warmup — đứng yên 1s, KHÔNG detect
    log(string.format("   ⏸ Warmup %.1fs (đứng yên, chưa detect)...", config.BAIT_WARMUP or 1.0))
    freezeAt(nil, config.BAIT_WARMUP or 1.0)

    log("   ⏳ Bắt đầu detect knockback")

    local t0 = os.clock()
    local hum0, hrp0 = getHum(), getHRP()
    local startHealth = hum0 and hum0.Health or 100
    local startPos = hrp0 and hrp0.Position or Vector3.zero
    local startCFrame = hrp0 and hrp0.CFrame or CFrame.new()

    while isRunning and os.clock() - t0 < timeout do
        local hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth()
        local vel = hrp.AssemblyLinearVelocity
        local speed = vel.Magnitude
        local state = hum:GetState()

        if state == Enum.HumanoidStateType.Physics and speed > 30 then
            log(string.format("💥 PHYSICS speed=%.1f", speed)); return true
        end
        if speed > 60 and vel.Y > 10 then
            log(string.format("💥 VELOCITY speed=%.1f", speed)); return true
        end
        if state == Enum.HumanoidStateType.PlatformStanding
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Ragdoll then
            log(string.format("💥 STATE xấu: %s", tostring(state))); return true
        end
        if startHealth and hum.Health < startHealth - (config.KB_HEALTH_DROP or 0.1) then
            log(string.format("💥 HEALTH %.1f→%.1f", startHealth, hum.Health)); return true
        end
        if startPos then
            local pd = (hrp.Position - startPos).Magnitude
            if pd > 15 then  -- ⭐ v10.3: tăng 10 → 15
                log(string.format("💥 SHIFT %.1f", pd)); return true
            end
        end
        if startCFrame then
            local dot = math.clamp(startCFrame.LookVector:Dot(hrp.CFrame.LookVector), -1, 1)
            local angleDiff = math.deg(math.acos(dot))
            if angleDiff > 60 then  -- ⭐ v10.3: tăng 45° → 60°
                log(string.format("💥 ROTATE %.1f°", angleDiff)); return true
            end
        end

        pcall(function() hum:MoveTo(hrp.Position) end)
        task.wait(0.01)
    end
    log("⚠ Hết " .. timeout .. "s — không detect knockback")
    return false
end

-- ⭐⭐⭐ v10.3: stealAtPos — BỎ check carry đầu hàm
local function stealAtPos(targetPos, label, eggUid)
    log("═══════")
    log("STEAL TẠI " .. label)
    task.wait(0.05)

    local hrp = getHRP()
    if not hrp then return false end

    local d = dist(hrp.Position, targetPos)
    if d > config.ARRIVE_DIST and d < config.MAP_RADIUS then
        velocityMoveTo(targetPos, 10)
    end

    local slotsBefore, countBefore = getSlotSet()
    log("📊 Slots trước: " .. countBefore)

    for i = 1, config.MAX_FIRES do
        if not isRunning then return false end
        forceRunningState()

        local h2 = getHRP()
        if not h2 then break end

        local p2 = findPromptSteal(h2.Position, 150)
        if not p2 then
            log("⚠ Không có prompt gần")
            break
        end

        local p2pos = getPromptPos(p2)
        if not p2pos then break end
        local dToPrompt = dist(h2.Position, p2pos)
        if dToPrompt > config.PROMPT_NEAR then
            log(string.format("🏃 Move tới prompt (%.1f)", dToPrompt))
            velocityMoveTo(p2pos, 3, nil, true)
            p2 = findPromptSteal(h2.Position, 150)
            if not p2 then break end
        end

        firePromptOnce(p2)

        local verifyStart = os.clock()
        local stolen = false
        local stolenName = nil
        while os.clock() - verifyStart < config.STEAL_TIMEOUT do
            task.wait(0.15)
            local s, sn = hasStolenSlot(slotsBefore)
            if s then stolen = true; stolenName = sn; break end
            if isCarryingEggStrict() then
                task.wait(0.2)
                if isCarryingEggStrict() then stolen = true; stolenName = "carry"; break end
            end
        end

        if stolen then
            log(string.format("✅ ĐÃ STEAL (fire %d, %s)", i, stolenName))
            if eggUid then
                lastStolenUid = eggUid
            end
            lastStolenPos = targetPos
            return true
        end
    end

    log("⚠ Không steal được")
    return false
end

local function stealAtForest()
    local prompt, ppos = findForestEggOnly()
    if not prompt or not ppos then
        log("⚠ Không có Forest egg")
        return false
    end

    log(string.format("🎯 Forest egg @ %.1f,%.1f,%.1f", ppos.X, ppos.Y, ppos.Z))

    local hrp = getHRP()
    if hrp and dist(hrp.Position, ppos) > config.ARRIVE_DIST then
        velocityMoveTo(ppos, 15)
    end

    local forestBefore = getSlotSet()
    log("⚡ Steal Forest")

    for i = 1, 5 do
        if not isRunning then break end
        forceRunningState()
        local h2 = getHRP()
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
        local stolen, slotName = hasStolenSlot(forestBefore)
        if stolen then
            log("🎒 Forest OK (slot): " .. slotName)
            stolenPrompts[prompt] = true
            return true
        end
    end

    task.wait(1)
    if isCarryingEggStrict() then
        log("🎒 Forest OK (carry verify)")
        stolenPrompts[prompt] = true
        return true
    end

    log("❌ Forest FAIL")
    return false
end

local function pickNextEgg()
    if config.PRIORITY_INCOME and config.BIG_EGG_MODE then
        log("🎯🎯 DUAL MODE")

        local minIncome = config.DUAL_MIN_INCOME or 30000000
        local minSize = config.DUAL_MIN_SIZE or 4.0
        log(string.format("   Điều kiện: income >= $%.0fM/s VÀ size >= %.1f",
            minIncome / 1e6, minSize))

        if not EggState or not AssetEarnings then
            log("   ⚠ EggState/AssetEarnings nil → fallback big egg")
        else
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
                    log(string.format("✅ DUAL: %s @ %s = $%.2fM/s, size %.2f",
                        best.category, best.map.name, best.income / 1e6, best.size))

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
                else
                    log(string.format("   ⚠ Không egg nào đạt → fallback big egg"))
                end
            end
        end

        log("🥚 Fallback: BIG EGG")
        return findBiggestEgg()
    end

    if config.BIG_EGG_MODE then
        log("🥚 Mode: BIG EGG")
        return findBiggestEgg()
    elseif config.PRIORITY_INCOME then
        log("💰 Mode: PRIORITY INCOME")
        return findHighestIncomeEgg()
    else
        log("🎯 Mode: TARGETS")
        return findEggInTargets()
    end
end

-- ⭐⭐⭐ v10.3: MAIN LOOP với tele stable
local function mainLoop()
    while isRunning do
        log("═══════════════════════════════")
        log("🔄 CYCLE MỚI (từ Home)")

        local okForest = runToForest()
        if not okForest then
            log("❌ Không tới Forest → chờ 2s")
            task.wait(2)
        else
            local forestOk = stealAtForest()
            if not forestOk then
                log("⚠ Forest fail → về home, cycle mới")
                goHome()
                task.wait(config.WAIT_BETWEEN)
            else
                local gotKB = baitBoss(config.BAIT_TIMEOUT)

                if not gotKB then
                    log("⚠ Không bị knockback → về home, cycle mới")
                    goHome()
                    task.wait(config.WAIT_BETWEEN)
                else
                    local eggPrompt, eggPos, eggData, eggMap, eggUid = pickNextEgg()

                    if not eggPos then
                        log("⚠ Không có egg → về home")
                        goHome()
                        task.wait(config.WAIT_BETWEEN)
                    else
                        log(string.format("🎯 Egg: %s @ %s",
                            eggMap and eggMap.name or "?", tostring(eggUid)))

                        local targetPos = eggPos + Vector3.new(0, 3, 0)

                        -- ⭐ v10.3: TELE + giữ im 0.8s
                        teleToMapStable(targetPos)

                        -- ⭐ v10.3: Chờ thêm 0.5s cho ổn định
                        task.wait(config.TELE_STABILIZE or 0.5)

                        -- ⭐ v10.3: Steal (không check carry sớm)
                        local stolen = stealAtPos(eggPos, eggMap.name, eggUid)

                        if stolen then
                            log("✅ Steal OK → về home thả")
                            deliveryFailed = false

                            goHome()
                            task.wait(config.CHAT_WAIT)

                            if lastStolenUid then
                                log("🔍 Check egg có còn trên map không...")
                                local stillOnMap, reason = isEggStillOnMap(lastStolenUid, lastStolenPos)

                                if stillOnMap then
                                    log("🔄 Egg CÒN trên map → KHÔNG đánh dấu")
                                else
                                    log("✅ Egg KHÔNG còn trên map → đánh dấu đã steal")
                                    stolenEggUids[lastStolenUid] = true
                                end

                                lastStolenUid = nil
                                lastStolenPos = nil
                            end

                            if deliveryFailed then
                                log("❌ Delivery FAIL (chat)")
                                deliveryFailed = false
                            else
                                log("🎉 CYCLE XONG")
                            end
                        else
                            log("⚠ Steal FAIL → về home, cycle mới")
                            goHome()
                        end

                        -- ⭐ v10.3: Chờ 1.5s rồi tiếp (theo yêu cầu)
                        task.wait(config.CHAT_WAIT)
                    end
                end
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
                log("❌ Chat: Delivery failed")
            end
        end)
    end)
end)

-- ══════════ API ══════════
function M.start()
    if isRunning then return end
    installBypass()
    stolenPrompts = {}
    stolenEggUids = {}
    deliveryFailed = false
    lastEggCount = -1
    cycleStartTime = os.clock()
    lastStolenUid = nil
    lastStolenPos = nil
    isRunning = true
    log("▶ START v10.3")
    log(string.format("   Home: %.2f,%.2f,%.2f", config.HOME_POS.X, config.HOME_POS.Y, config.HOME_POS.Z))
    log(string.format("   Forest speed: %d | Forest warmup: %.1fs | Bait warmup: %.1fs | Tele hold: %.1fs",
        config.FOREST_RUN_SPEED, config.FOREST_WARMUP, config.BAIT_WARMUP, config.TELE_HOLD))
    log(string.format("   Big Egg: %s | Priority Income: %s",
        config.BIG_EGG_MODE and "ON" or "OFF",
        config.PRIORITY_INCOME and "ON" or "OFF"))
    task.spawn(mainLoop)
end

function M.stop() isRunning = false; log("■ STOP") end
function M.isRunning() return isRunning end

function M.setTargets(list)
    if type(list) ~= "table" then return end
    config.TARGETS = list
end

function M.setTarget(name, pos)
    config.TARGETS = { { name = name, pos = pos } }
end

function M.setPriorityIncome(enabled)
    config.PRIORITY_INCOME = enabled and true or false
    log("💰 Priority Income: " .. (config.PRIORITY_INCOME and "BẬT" or "TẮT"))
    log("   Big Egg: " .. (config.BIG_EGG_MODE and "BẬT" or "TẮT"))
    return config.PRIORITY_INCOME
end

function M.setBigEggMode(enabled)
    config.BIG_EGG_MODE = enabled and true or false
    log("🥚 Big Egg mode: " .. (config.BIG_EGG_MODE and "BẬT" or "TẮT"))
    log("   Priority Income: " .. (config.PRIORITY_INCOME and "BẬT" or "TẮT"))
    return config.BIG_EGG_MODE
end

function M.setPriorityThreshold(amount)
    config.PRIORITY_THRESHOLD = amount or 1000000
    log("💰 Threshold: $" .. (config.PRIORITY_THRESHOLD / 1e6) .. "M/s")
end

function M.setHome(p) if p then config.HOME_POS = p end end
function M.setForest(p) if p then config.FOREST_POS = p end end

function M.setForestRunSpeed(n)
    config.FOREST_RUN_SPEED = n or 150
    log("🏃 Forest run speed: " .. config.FOREST_RUN_SPEED)
end

function M.setBaitTimeout(n)
    config.BAIT_TIMEOUT = n or 15
    log("🎯 Bait timeout: " .. config.BAIT_TIMEOUT)
end

-- ⭐ v10.3: Set warmup times
function M.setForestWarmup(n)
    config.FOREST_WARMUP = n or 1.0
    log("⏸ Forest warmup: " .. config.FOREST_WARMUP .. "s")
end

function M.setBaitWarmup(n)
    config.BAIT_WARMUP = n or 1.0
    log("⏸ Bait warmup: " .. config.BAIT_WARMUP .. "s")
end

function M.setTeleHold(n)
    config.TELE_HOLD = n or 0.8
    log("🔒 Tele hold: " .. config.TELE_HOLD .. "s")
end

function M.getConfig() return config end
function M.getAllMaps() return ALL_MAPS end
function M.isCarrying() return isCarryingEgg() end
function M.clearStolenUids() stolenEggUids = {}; log("🔄 Clear UIDs") end
function M.isEggStillOnMap(uid, pos) return isEggStillOnMap(uid, pos) end

function M.isPriorityIncome() return config.PRIORITY_INCOME end

function M.togglePriorityIncome()
    config.PRIORITY_INCOME = not config.PRIORITY_INCOME
    log("💰 Priority Income: " .. (config.PRIORITY_INCOME and "BẬT" or "TẮT"))
    log("   Big Egg: " .. (config.BIG_EGG_MODE and "BẬT" or "TẮT"))
    return config.PRIORITY_INCOME
end

function M.isBigEggMode() return config.BIG_EGG_MODE end

function M.toggleBigEggMode()
    config.BIG_EGG_MODE = not config.BIG_EGG_MODE
    log("🥚 Big Egg mode: " .. (config.BIG_EGG_MODE and "BẬT" or "TẮT"))
    log("   Priority Income: " .. (config.PRIORITY_INCOME and "BẬT" or "TẮT"))
    return config.BIG_EGG_MODE
end

function M.getPriorityThreshold() return config.PRIORITY_THRESHOLD end
function M.clearIncomeCache() log("🔄 Income cache cleared") end

function M.setHomeFlyY(n)
    config.HOME_FLY_ABSOLUTE_Y = n or 100
    log("📏 Home fly Y: " .. config.HOME_FLY_ABSOLUTE_Y)
end

function M.setFlyHomeSpeed(n)
    config.FLY_HOME_SPEED = n or 500
    log("🏃 Fly home speed: " .. config.FLY_HOME_SPEED)
end

function M.setRecoveryRadius(n) log("📍 Không dùng v10.3") end
function M.setMaxRecovery(n) log("📍 Không dùng v10.3") end

function M.setHomeTimeout(n)
    config.HOME_TIMEOUT = n or 30
    log("⏱ Home timeout: " .. config.HOME_TIMEOUT .. "s")
end

function M.setPromptNear(n)
    config.PROMPT_NEAR = n or 12
    log("📏 Prompt near: " .. config.PROMPT_NEAR .. " studs")
end

function M.setSlowSpeed(n)
    config.FOREST_RUN_SPEED = n or 150
    log("🐢 Forest run speed: " .. config.FOREST_RUN_SPEED)
end

function M.setWarmupTime(n) log("⏱ Không dùng v10.3") end

function M.setChatWait(n)
    config.CHAT_WAIT = n or 1.5
    log("💬 Chat wait: " .. config.CHAT_WAIT .. "s")
end

function M.setCycleWait(n)
    config.WAIT_BETWEEN = n or 1.0
    log("⏱ Cycle wait: " .. config.WAIT_BETWEEN .. "s")
end

function M.setMaxEggsPerCycle(n) log("📊 Không dùng v10.3") end
function M.setTeleToForest(enabled) log("ℹ Không dùng v10.3") end

function M.setMaxRetry(n)
    config.MAX_RETRY = n or 3
    log("🔄 Max retry: " .. config.MAX_RETRY)
end

function M.setDualMinIncome(n)
    config.DUAL_MIN_INCOME = n or 30000000
    log(string.format("💰 Dual min income: $%.0fM/s", config.DUAL_MIN_INCOME / 1e6))
end

function M.setDualMinSize(n)
    config.DUAL_MIN_SIZE = n or 4.0
    log(string.format("📏 Dual min size: %.2f", config.DUAL_MIN_SIZE))
end

function M.setDualMode(minIncome, minSize)
    config.DUAL_MIN_INCOME = minIncome or 30000000
    config.DUAL_MIN_SIZE = minSize or 4.0
    log(string.format("🎯🎯 Dual: $%.0fM/s + size %.1f",
        config.DUAL_MIN_INCOME / 1e6, config.DUAL_MIN_SIZE))
end

function M.isDualMode()
    return config.PRIORITY_INCOME and config.BIG_EGG_MODE
end

function M.getCurrentTarget()
    return lastStolenUid and { uid = lastStolenUid, pos = lastStolenPos } or nil
end

function M.clearCurrentTarget()
    lastStolenUid = nil
    lastStolenPos = nil
    log("🔓 Clear current target")
end

function M.setAutoStart(enabled) log("ℹ Auto start: " .. (enabled and "BẬT" or "TẮT")) end

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
    }
end

return M
