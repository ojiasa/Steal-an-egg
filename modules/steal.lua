-- ═══════════════════════════════════════════════════════════════
-- STEAL MODULE v8 — Priority Income + Threshold 1M/s [FIXED]
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

    -- ⭐ Priority Income
    PRIORITY_INCOME    = false,
    PRIORITY_THRESHOLD = 1000000,   -- 1M/s

    -- Core
    SPEED          = 1500,
    SPEED_CAP      = 500,
    MAP_RADIUS     = 800,
    ARRIVE_DIST    = 10,
    BAIT_TIMEOUT   = 15,
    KB_HEALTH_DROP = 0.5,
    MAX_FIRES      = 8,
    MAX_RETRY      = 3,
    STEAL_VERIFY_WAIT = 0.35,
    CHAT_WAIT      = 2.0,
}

local isRunning      = false
local stolenPrompts  = {}
local deliveryFailed = false
local logCallbacks   = {}

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

-- ═══════════════════════════════════════════════════════════════
-- ✅ FIX: Hàm verify map thực tế của egg
-- ═══════════════════════════════════════════════════════════════
local function getEggRealMap(eggPos)
    local closestMap, closestDist = nil, 999999
    for _, m in ipairs(ALL_MAPS) do
        local d = dist(eggPos, m.pos)
        if d < closestDist then
            closestMap = m
            closestDist = d
        end
    end
    return closestMap
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

local function getEggIncomeByUid(uid)
    if not AssetEarnings or not EggState or not uid then return 0 end
    if incomeCache[uid] ~= nil then return incomeCache[uid] end

    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then
        return 0
    end

    for _, eggData in pairs(fd.Records) do
        if eggData.Uid == uid then
            local input = {
                Category = eggData.AssetCategory,
                Scale = eggData.AssetScale or 1,
                Mutations = eggData.Mutations or {},
            }
            local r
            local ok2, val = pcall(AssetEarnings.LiveRatePerSecond, input)
            if ok2 and type(val) == "number" and val > 0 then r = val end
            if not r then
                ok2, val = pcall(AssetEarnings.RatePerSecond, input)
                if ok2 and type(val) == "number" and val > 0 then r = val end
            end
            incomeCache[uid] = r or 0
            return r or 0
        end
    end
    return 0
end

local function getEggUidFromPrompt(prompt)
    local part = prompt.Parent
    if part and part:IsA("Attachment") then part = part.Parent end
    if not part or not part:IsA("BasePart") then return nil end

    local ppos = part.Position
    local slots = W:FindFirstChild("AreaEggSlotsClient")
    if not slots then return nil end

    local closestSlot, closestDist = nil, 10
    for _, slot in ipairs(slots:GetChildren()) do
        local hitbox = slot:FindFirstChild("Hitbox")
        if hitbox and hitbox:IsA("BasePart") then
            local d = (hitbox.Position - ppos).Magnitude
            if d < closestDist then
                closestSlot, closestDist = slot, d
            end
        end
    end
    return closestSlot and closestSlot.Name or nil
end

-- ⭐⭐⭐ FIND EGG INCOME CAO NHẤT
local function findHighestIncomeEgg()
    local hrp = getHRP()
    if not hrp then return nil, nil, nil, nil end

    local best = nil
    local bestIncome = config.PRIORITY_THRESHOLD or 0

    for _, v in ipairs(W:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg"
                    and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEgg then
                local part = v.Parent
                local ppos
                if part and part:IsA("BasePart") then ppos = part.Position
                elseif part and part:IsA("Attachment") then ppos = part.WorldPosition
                elseif part and part.Parent and part.Parent:IsA("BasePart") then
                    ppos = part.Parent.Position end

                if ppos and dist(ppos, config.HOME_POS) > 150 then
                    local uid = getEggUidFromPrompt(v)
                    if uid then
                        local income = getEggIncomeByUid(uid)
                        if income > bestIncome then
                            local nearestMap, nearestDist = nil, 99999
                            for _, m in ipairs(ALL_MAPS) do
                                local d = dist(ppos, m.pos)
                                if d < nearestDist then
                                    nearestMap = m
                                    nearestDist = d
                                end
                            end
                            if nearestMap then
                                bestIncome = income
                                best = {
                                    prompt = v,
                                    pos = ppos,
                                    map = nearestMap,
                                    income = income,
                                    uid = uid,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    if best then
        log(string.format("🎯 Best income: %s @ %s = $%.2f/s",
            best.uid:sub(1, 20), best.map.name, best.income))
        return best.prompt, best.pos, best.income, best.map
    end
    return nil, nil, nil, nil
end

-- ═══════════════════════════════════════════════════════════════
-- ✅ FIX: FIND EGG TRONG TARGET MAPS (multi-map) - VERIFIED
-- ═══════════════════════════════════════════════════════════════
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
                local part = v.Parent
                local ppos
                if part and part:IsA("BasePart") then ppos = part.Position
                elseif part and part:IsA("Attachment") then ppos = part.WorldPosition
                elseif part and part.Parent and part.Parent:IsA("BasePart") then
                    ppos = part.Parent.Position end
                
                if ppos then
                    -- ✅ GET REAL MAP của egg này (verify)
                    local realMap = getEggRealMap(ppos)
                    
                    if realMap then
                        -- ✅ Check if this REAL MAP is in targets
                        for _, tgt in ipairs(config.TARGETS) do
                            if tgt.name == realMap.name then
                                table.insert(candidates, {
                                    prompt = v,
                                    pos = ppos,
                                    map = realMap,  -- ✅ Dùng MAP THỰC TẾ, không phải tgt
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

    -- ⭐ Sort theo mode
    if config.PRIORITY_INCOME then
        for _, c in ipairs(candidates) do
            local uid = getEggUidFromPrompt(c.prompt)
            c.income = uid and getEggIncomeByUid(uid) or 0
        end
        table.sort(candidates, function(a, b)
            return a.income > b.income
        end)
    elseif config.PREFER_FAR then
        table.sort(candidates, function(a, b)
            return a.dFromHome > b.dFromHome
        end)
    else
        table.sort(candidates, function(a, b)
            return a.dFromPlayer < b.dFromPlayer
        end)
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
                local part = v.Parent
                local ppos
                if part and part:IsA("BasePart") then ppos = part.Position
                elseif part and part:IsA("Attachment") then ppos = part.WorldPosition
                elseif part and part.Parent and part.Parent:IsA("BasePart") then
                    ppos = part.Parent.Position end
                if ppos then
                    local d = dist(ppos, pos)
                    if d < bestDist then best, bestDist = v, d end
                end
            end
        end
    end
    return best, bestDist
end

-- ══════════ ANIMATION (từ v60.3.2) ══════════
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
            "rbxassetid://507766666","rbxassetid://507766951",
            "rbxassetid://507777826","rbxassetid://507767714",
            "rbxassetid://507765000","rbxassetid://507767968",
            "rbxassetid://507765644","rbxassetid://507784897",
            "rbxassetid://507785072",
        } or {
            "rbxassetid://180435571","rbxassetid://180435792",
            "rbxassetid://180426354","rbxassetid://125750702",
            "rbxassetid://180436148","rbxassetid://180436334",
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
        local ps = P:FindFirstChild("PlayerScripts")
        if ps then
            local tpl = ps:FindFirstChild("Animate")
            if tpl then
                local new = tpl:Clone()
                new.Parent = c
                new.Disabled = false
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
    local savedSlope = old.MaxSlopeAngle or 89
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
            local a = Instance.new("Animator")
            a.Parent = new
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

local function teleToMap(targetPos)
    local hrp = getHRP()
    if hrp then pcall(function()
        hrp.CFrame = CFrame.new(targetPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end) end
    replaceHumanoidDirect()
    for i = 1, 6 do
        local r2 = getHRP()
        if r2 then pcall(function()
            r2.CFrame = CFrame.new(targetPos)
            r2.AssemblyLinearVelocity = Vector3.zero
            r2.AssemblyAngularVelocity = Vector3.zero
        end) end
        task.wait(0.01)
    end
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
    pcall(function() local r = getHRP(); if r then r.AssemblyLinearVelocity = Vector3.zero end end)
    return false
end

local function goHomeFast()
    log("🏃 CHẠY VỀ HOME")
    local startTime = os.clock()
    local t0 = startTime
    local lastPos = nil
    local stuckTime = os.clock()
    while os.clock() - t0 < 30 do
        local hum, r = getHum(), getHRP()
        if not hum or not r then break end
        keepHealth()
        local d = dist(r.Position, config.HOME_POS)
        if d < config.ARRIVE_DIST then
            pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)
            log(string.format("✅ Về home (%.2fs)", os.clock() - startTime))
            return true
        end
        pcall(function()
            local dir = config.HOME_POS - r.Position
            if dir.Magnitude > 0 then
                local nrm = dir.Unit
                local ramp = math.min((os.clock() - t0) / 0.3, 1)
                r.AssemblyLinearVelocity = nrm * math.min(config.SPEED / 2.5, config.SPEED_CAP) * ramp
                if d > 30 then
                    local nudge = math.min(d, 150) * 0.08
                    r.CFrame = CFrame.new(r.Position + nrm * nudge)
                end
            end
        end)
        if lastPos then
            local moved = dist(r.Position, lastPos)
            if moved < 0.5 then
                if os.clock() - stuckTime > 0.4 then
                    pcall(function() hum.Jump = true end)
                    stuckTime = os.clock()
                end
            else
                stuckTime = os.clock()
            end
        end
        lastPos = r.Position
        task.wait()
    end
    return false
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
            log(string.format("💥 PHYSICS speed=%.1f", speed)); return true
        end
        if speed > 60 and vel.Y > 10 then
            log(string.format("💥 VELOCITY speed=%.1f", speed)); return true
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
    log("═══════")
    log("STEAL TẠI " .. label)
    task.wait(0.05)
    local hrp = getHRP()
    if not hrp or dist(hrp.Position, targetPos) > 50 then
        teleToMap(targetPos)
        task.wait(0.05)
    end
    local prompt = findPromptSteal(targetPos, 150)
    if not prompt then log("⚠ Không có prompt"); return false end
    local slotsBefore, countBefore = getSlotSet()
    log("📊 Global slots trước: " .. countBefore)
    for i = 1, config.MAX_FIRES do
        if not isRunning then return false end
        local h2 = getHRP()
        if h2 then
            local p2 = findPromptSteal(h2.Position, 150)
            if p2 then firePromptOnce(p2) end
        end
        task.wait(config.STEAL_VERIFY_WAIT)
        local _, countNow = getSlotSet()
        local stolen, slotName = hasStolenSlot(slotsBefore)
        if stolen then
            log("🎒 SLOT MẤT: " .. slotName)
            log(string.format("📊 Slots: %d → %d", countBefore, countNow))
            log("✅ ĐÃ STEAL")
            return true
        end
    end
    log("⚠ Fire " .. config.MAX_FIRES .. " lần không giảm slot")
    return false
end

-- ══════════ MAIN LOOP ══════════
local function mainLoop()
    while isRunning do
        log("═══════════════════════")
        log("PHASE 1: Bay tới Forest")

        if not velocityMoveTo(config.FOREST_POS, 30) then
            if not isRunning then break end
            log("❌ Không tới Forest")
            task.wait(0.5)
        else
            log("✅ Tới Forest")
            local hrp = getHRP()
            local prompt = hrp and findPromptSteal(hrp.Position, config.MAP_RADIUS)

            if prompt then
                local part = prompt.Parent
                local ppos
                if part:IsA("BasePart") then ppos = part.Position
                elseif part:IsA("Attachment") then ppos = part.WorldPosition
                elseif part.Parent and part.Parent:IsA("BasePart") then ppos = part.Parent.Position end

                if ppos then
                    if dist(hrp.Position, ppos) > config.ARRIVE_DIST then
                        velocityMoveTo(ppos, 20)
                    end

                    local forestBefore, forestCount = getSlotSet()
                    log("📊 Forest global slots: " .. forestCount)

                    log("⚡ Steal Forest")
                    for i = 1, 5 do
                        if not isRunning then break end
                        local h2 = getHRP()
                        if h2 then
                            local p2 = findPromptSteal(h2.Position, 150)
                            if p2 then firePromptOnce(p2) end
                        end
                        task.wait(0.3)
                        local stolen, slotName = hasStolenSlot(forestBefore)
                        if stolen then
                            log("🎒 Forest OK: " .. slotName)
                            break
                        end
                    end
                    stolenPrompts[prompt] = true
                    task.wait(0.1)

                    log("PHASE 3: Bait boss Forest")
                    local gotKnockback = baitBoss(config.BAIT_TIMEOUT)

                    if gotKnockback then
                        -- ⭐ KIỂM TRA MODE
                        local eggPrompt, eggPos, eggDist, eggMap

                        if config.PRIORITY_INCOME then
                            log("💰 Mode: ƯU TIÊN TIỀN CAO (min $" ..
                                (config.PRIORITY_THRESHOLD / 1e6) .. "M/s)")
                            eggPrompt, eggPos, eggDist, eggMap = findHighestIncomeEgg()

                            -- ⭐ Nếu không có egg nào > ngưỡng → DỪNG
                            if not eggPos then
                                log("⚠ Không có egg nào đạt ngưỡng $" ..
                                    (config.PRIORITY_THRESHOLD / 1e6) .. "M/s → DỪNG")
                                isRunning = false
                                break
                            end
                        else
                            log("PHASE 4: Tìm egg trong " .. #config.TARGETS .. " map")
                            eggPrompt, eggPos, eggDist, eggMap = findEggInTargets()
                        end

                        if eggPos and eggMap then
                            log(string.format("🎯 Map: %s @ %.1f,%.1f,%.1f",
                                eggMap.name, eggPos.X, eggPos.Y, eggPos.Z))

                            local targetPos = eggPos + Vector3.new(0, 3, 0)
                            local success = false
                            for attempt = 1, config.MAX_RETRY do
                                if not isRunning then break end
                                log("═══════════════════════")
                                log(string.format("🔄 ATTEMPT %d/%d", attempt, config.MAX_RETRY))
                                deliveryFailed = false

                                teleToMap(targetPos)
                                task.wait(0.05)

                                local stolen = stealAtPos(eggPos, eggMap.name)
                                if stolen then
                                    goHomeFast()
                                    task.wait(config.CHAT_WAIT)
                                    if deliveryFailed then
                                        log("❌ Chat báo fail — RETRY")
                                        task.wait(0.2)
                                    else
                                        log("🎉 THÀNH CÔNG")
                                        success = true
                                        break
                                    end
                                else
                                    log("⚠ Steal fail — retry")
                                    task.wait(0.2)
                                end
                            end

                            if success then
                                deliveryFailed = false
                                log("🎉 HOÀN THÀNH")
                            else
                                log("❌ Hết " .. config.MAX_RETRY .. " lần retry")
                            end
                        else
                            log("⚠ Không tìm thấy prompt target")
                        end
                    end
                end
            else
                log("⚠ Không có prompt Forest")
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
                or msg:find("egg was returned", 1, true)
            then
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
    deliveryFailed = false
    incomeCache = {}
    isRunning = true
    log("▶ START — " .. #config.TARGETS .. " map(s)")
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
    log("🎯 Target: " .. name)
end

-- ⭐ Priority Income API
function M.setPriorityIncome(enabled)
    config.PRIORITY_INCOME = enabled and true or false
    log("💰 Ưu tiên tiền cao: " .. (enabled and "BẬT" or "TẮT"))
    return config.PRIORITY_INCOME
end

function M.isPriorityIncome()
    return config.PRIORITY_INCOME
end

function M.togglePriorityIncome()
    return M.setPriorityIncome(not config.PRIORITY_INCOME)
end

function M.setPriorityThreshold(amount)
    config.PRIORITY_THRESHOLD = amount or 1000000
    log("💰 Ngưỡng: $" .. (config.PRIORITY_THRESHOLD / 1e6) .. "M/s")
end

function M.getPriorityThreshold()
    return config.PRIORITY_THRESHOLD
end

function M.clearIncomeCache()
    incomeCache = {}
    log("🔄 Income cache cleared")
end

function M.getAllMaps() return ALL_MAPS end
function M.setHome(p) if p then config.HOME_POS = p; log("📍 Home") end end
function M.setForest(p) if p then config.FOREST_POS = p; log("📍 Forest") end end
function M.getConfig() return config end

return M

