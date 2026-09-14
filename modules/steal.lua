-- ═══════════════════════════════════════════════════════════════
-- STEAL MODULE — Auto steal logic (không UI)
-- Repo: https://github.com/ojiasa/Steal-an-egg
-- ═══════════════════════════════════════════════════════════════

local P                  = game:GetService("Players").LocalPlayer
local RS                 = game:GetService("ReplicatedStorage")
local W                  = workspace
local ProximityPromptSvc = game:GetService("ProximityPromptService")

local M = {}

-- ══════════ STATE ══════════
local config = {
    HOME_POS       = Vector3.new(465.2, 67.1, -364.1),
    FOREST_POS     = Vector3.new(599.9, 67.6, -363.9),
    TARGET_MAP     = { name = "Snow", pos = Vector3.new(1405.1, 68.0, -363.8) },
    SPEED          = 1500,
    SPEED_CAP      = 500,
    BAIT_TIMEOUT   = 15,
    MAX_RETRY      = 3,
    CHAT_WAIT      = 2.0,
    MAP_RADIUS     = 800,
    ARRIVE_DIST    = 10,
    STEAL_VERIFY_WAIT = 0.35,
    MAX_FIRES      = 8,
    KB_HEALTH_DROP = 0.5,
}

local isRunning      = false
local stolenPrompts  = {}
local deliveryFailed = false
local logCallbacks   = {}

-- ══════════ LOG ══════════
local function log(s)
    for _, cb in ipairs(logCallbacks) do
        pcall(cb, s)
    end
    print("[Steal] " .. tostring(s))
end

function M.onLog(cb)
    if type(cb) == "function" then
        table.insert(logCallbacks, cb)
    end
end

-- ══════════ HELPERS ══════════
local function getHRP()
    local c = P.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = P.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function dist(a, b)
    local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function keepHealth()
    local h = getHum()
    if h then
        pcall(function()
            h.MaxHealth = 99999
            if h.Health < 50000 then h.Health = 99999 end
            h:SetStateEnabled(Enum.HumanoidStateType.Dying, false)
        end)
    end
end

-- ══════════ SLOT SET ══════════
local function getSlotSet()
    local set, count = {}, 0
    local folder = W:FindFirstChild("AreaEggSlotsClient")
    if folder then
        for _, d in ipairs(folder:GetChildren()) do
            set[d.Name] = true
            count = count + 1
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

-- ══════════ FIND PROMPTS ══════════
local function findTargetEggPrompt()
    local best, bestPos, bestDist = nil, nil, 99999
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
                    local d = dist(ppos, config.TARGET_MAP.pos)
                    if d < 800 and d < bestDist then
                        best, bestPos, bestDist = v, ppos, d
                    end
                end
            end
        end
    end
    return best, bestPos, bestDist
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

-- ══════════ ANIMATION FIX ══════════
local function restoreAnimations()
    local c = P.Character
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    pcall(function()
        local rig = hum.RigType
        local isR15 = (rig == Enum.HumanoidRigType.R15)
        local anim = hum:FindFirstChildOfClass("Animator")
        if not anim then
            anim = Instance.new("Animator")
            anim.Parent = hum
        end
        task.wait(0.1)

        local ids
        if isR15 then
            ids = {
                "rbxassetid://507766666","rbxassetid://507766951",
                "rbxassetid://507777826","rbxassetid://507767714",
                "rbxassetid://507765000","rbxassetid://507767968",
                "rbxassetid://507765644","rbxassetid://507784897",
                "rbxassetid://507785072",
            }
        else
            ids = {
                "rbxassetid://180435571","rbxassetid://180435792",
                "rbxassetid://180426354","rbxassetid://125750702",
                "rbxassetid://180436148","rbxassetid://180436334",
                "rbxassetid://182393478",
            }
        end
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
        local oldAnimate = c:FindFirstChild("Animate")
        if oldAnimate then oldAnimate:Destroy() end
        task.wait(0.1)

        local starter = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts")
        if starter then
            local template = starter:FindFirstChild("Animate")
            if template then
                local newAnimate = template:Clone()
                newAnimate.Parent = c
                newAnimate.Disabled = false
                return
            end
        end
        local ps = P:FindFirstChild("PlayerScripts")
        if ps then
            local template = ps:FindFirstChild("Animate")
            if template then
                local newAnimate = template:Clone()
                newAnimate.Parent = c
                newAnimate.Disabled = false
            end
        end
    end)
end

local function replaceHumanoidDirect()
    local c = P.Character
    if not c then return false end
    local old = c:FindFirstChildOfClass("Humanoid")
    if not old then return false end

    local savedHip   = old.HipHeight or 2
    local savedJump  = old.JumpPower or 50
    local savedMax   = old.MaxHealth or 100
    local savedHP    = old.Health or 100
    local savedRig   = old.RigType or Enum.HumanoidRigType.R15
    local savedSlope = old.MaxSlopeAngle or 89

    pcall(function() old:Destroy() end)

    local new = Instance.new("Humanoid")
    new.Parent = c

    pcall(function()
        new.HipHeight     = savedHip
        new.JumpPower     = savedJump
        new.MaxHealth     = savedMax
        new.Health        = savedHP
        new.WalkSpeed     = 60
        new.RigType       = savedRig
        new.MaxSlopeAngle = savedSlope
        new.AutoRotate    = true
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
            local animator = Instance.new("Animator")
            animator.Parent = new
        end
    end)

    task.spawn(restoreAnimations)
    task.spawn(function()
        task.wait(0.1)
        resetAnimateScript()
        task.wait(0.2)
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then
            pcall(function()
                h:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
    end)

    return true
end

-- ══════════ FIRE PROMPT ══════════
local function firePromptOnce(prompt)
    if not prompt or not prompt.Parent then return false end
    pcall(function()
        prompt.Enabled                = true
        prompt.HoldDuration           = 0
        prompt.MaxActivationDistance  = 999
        prompt.RequiresLineOfSight    = false
    end)

    if type(fireproximityprompt) == "function" then
        pcall(fireproximityprompt, prompt)
    end

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
local function velocityMoveTo(targetPos, timeout)
    timeout = timeout or 20
    local hum, hrp = getHum(), getHRP()
    if not hum or not hrp then return false end
    keepHealth()

    local t0 = os.clock()
    local lastPos = hrp.Position
    local stuckTime = os.clock()

    while isRunning and os.clock() - t0 < timeout do
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
    return false
end

local function teleToMap(targetPos)
    local hrp = getHRP()
    if hrp then
        pcall(function()
            hrp.CFrame = CFrame.new(targetPos)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    replaceHumanoidDirect()
    for i = 1, 6 do
        local r2 = getHRP()
        if r2 then
            pcall(function()
                r2.CFrame = CFrame.new(targetPos)
                r2.AssemblyLinearVelocity = Vector3.zero
                r2.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        task.wait(0.01)
    end
end

local function goHomeFast()
    log("🏃 CHẠY VỀ HOME")
    local t0 = os.clock()
    local lastPos, stuckTime = nil, os.clock()

    while os.clock() - t0 < 30 and isRunning do
        local hum, r = getHum(), getHRP()
        if not hum or not r then break end
        keepHealth()

        local d = dist(r.Position, config.HOME_POS)
        if d < config.ARRIVE_DIST then
            pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)
            log("✅ Về home")
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
        if hum.Health < startHealth - config.KB_HEALTH_DROP then
            log(string.format("💥 HEALTH %.1f→%.1f", startHealth, hum.Health)); return true
        end
        if (hrp.Position - startPos).Magnitude > 15 and speed > 30 then
            log("💥 SHIFT"); return true
        end

        pcall(function() hum:MoveTo(hrp.Position) end)
        task.wait(0.01)
    end
    log("⚠ Hết " .. timeout .. "s")
    return false
end

local function stealAtPos(targetPos, label)
    log("═══════════════════════")
    log("STEAL TẠI " .. label)

    task.wait(0.05)
    local hrp = getHRP()
    if not hrp or dist(hrp.Position, targetPos) > 50 then
        teleToMap(targetPos)
        task.wait(0.05)
    end

    local prompt = findPromptSteal(targetPos, 150)
    if not prompt then
        log("⚠ Không có prompt"); return false
    end

    local slotsBefore, countBefore = getSlotSet()
    log("📊 Slots: " .. countBefore)

    for i = 1, config.MAX_FIRES do
        if not isRunning then return false end
        local h2 = getHRP()
        if h2 then
            local p2 = findPromptSteal(h2.Position, 150)
            if p2 then firePromptOnce(p2) end
        end
        task.wait(config.STEAL_VERIFY_WAIT)

        local stolen, name = hasStolenSlot(slotsBefore)
        if stolen then
            log("🎒 OK: " .. name); return true
        end
    end
    log("⚠ Fail"); return false
end

-- ══════════ MAIN LOOP ══════════
local function mainLoop()
    while isRunning do
        log("═══════════════════════")
        log("PHASE 1: Forest")

        if not velocityMoveTo(config.FOREST_POS, 30) then
            if not isRunning then break end
            log("❌ Không tới Forest")
            task.wait(0.5)
        else
            log("✅ Forest")
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

                    local fb, fc = getSlotSet()
                    log("📊 Forest slots: " .. fc)

                    for i = 1, 5 do
                        if not isRunning then break end
                        local h2 = getHRP()
                        if h2 then
                            local p2 = findPromptSteal(h2.Position, 150)
                            if p2 then firePromptOnce(p2) end
                        end
                        task.wait(0.3)
                        local stolen, name = hasStolenSlot(fb)
                        if stolen then log("🎒 Forest OK: " .. name); break end
                    end
                    stolenPrompts[prompt] = true
                    task.wait(0.1)

                    log("PHASE 3: Bait boss")
                    if baitBoss(config.BAIT_TIMEOUT) then
                        log("PHASE 4: Tìm prompt " .. config.TARGET_MAP.name)
                        local eggPrompt, eggPos = findTargetEggPrompt()

                        if eggPos then
                            log(string.format("🎯 %.1f,%.1f,%.1f", eggPos.X, eggPos.Y, eggPos.Z))
                            local targetPos = eggPos + Vector3.new(0, 3, 0)
                            local success = false

                            for attempt = 1, config.MAX_RETRY do
                                if not isRunning then break end
                                log("")
                                log(string.format("🔄 ATTEMPT %d/%d", attempt, config.MAX_RETRY))
                                deliveryFailed = false

                                teleToMap(targetPos)
                                task.wait(0.05)

                                local stolen = stealAtPos(eggPos, config.TARGET_MAP.name)
                                if stolen then
                                    goHomeFast()
                                    task.wait(config.CHAT_WAIT)
                                    if deliveryFailed then
                                        log("❌ Chat fail — retry"); task.wait(0.2)
                                    else
                                        log("🎉 SUCCESS"); success = true; break
                                    end
                                else
                                    log("⚠ Fail — retry"); task.wait(0.2)
                                end
                            end

                            if success then
                                deliveryFailed = false
                                log("🎉 HOÀN THÀNH")
                            else
                                log("❌ Hết retry")
                            end
                        else
                            log("⚠ Không tìm thấy egg target")
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

-- ══════════ INSTALL BYPASS ══════════
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

-- ══════════ CHAT HOOK ══════════
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
    isRunning = true
    log("▶ START — Forest → " .. config.TARGET_MAP.name)
    task.spawn(mainLoop)
end

function M.stop()
    isRunning = false
    log("■ STOP")
end

function M.isRunning()
    return isRunning
end

function M.setTarget(name, pos)
    if name and pos then
        config.TARGET_MAP = { name = name, pos = pos }
        log("🎯 Target: " .. name)
    end
end

function M.setHome(pos)
    if pos then
        config.HOME_POS = pos
        log("📍 Home set")
    end
end

function M.setForest(pos)
    if pos then
        config.FOREST_POS = pos
        log("📍 Forest set")
    end
end

function M.getConfig()
    return config
end

return M
