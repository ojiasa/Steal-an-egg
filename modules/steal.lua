-- ═══════════════════════════════════════════════════════════════
-- STEAL MODULE v5 — Steal xong chạy về ngay
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
    SPEED          = 1500,
    SPEED_CAP      = 500,
    BAIT_TIMEOUT   = 15,
    MAX_RETRY      = 5,
    CHAT_WAIT      = 2.0,
    MAP_RADIUS     = 800,
    ARRIVE_DIST    = 10,
    STEAL_VERIFY_WAIT = 0.35,
    MAX_FIRES      = 8,
    KB_HEALTH_DROP = 0.5,
    HOME_TIMEOUT   = 25,
    RE_TELE_MAX    = 3,
    RUN_HOME_DELAY = 0.15,   -- ⭐ delay trước khi chạy về
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

-- ⭐⭐⭐ RESTORE HUMANOID — sau steal, cho chạy bình thường
local function restoreHumanoid()
    local c = P.Character
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return end

    pcall(function()
        h.WalkSpeed = 60
        h.PlatformStand = false
        h.AutoRotate = true
    end)
    pcall(function()
        h:ChangeState(Enum.HumanoidStateType.Running)
    end)
    pcall(function()
        h:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        h:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
        h:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
        h:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        h:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end)

    -- Restart Animate script
    task.spawn(function()
        task.wait(0.05)
        local old = c:FindFirstChild("Animate")
        if old then old:Destroy() end
        task.wait(0.05)
        local starter = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts")
        if starter then
            local tpl = starter:FindFirstChild("Animate")
            if tpl then
                local new = tpl:Clone()
                new.Parent = c
                new.Disabled = false
            end
        end
    end)
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

local function findEggInTargets()
    local best, bestPos, bestDist, bestMap = nil, nil, 99999, nil
    local hrp = getHRP()
    if not hrp then return nil, nil, nil, nil end

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
                    for _, tgt in ipairs(config.TARGETS) do
                        local dToMap = dist(ppos, tgt.pos)
                        if dToMap < 500 then
                            local dFromPlayer = dist(ppos, hrp.Position)
                            local score
                            if config.PREFER_FAR then
                                score = -dist(tgt.pos, config.HOME_POS) + dFromPlayer * 0.001
                            else
                                score = dFromPlayer
                            end
                            if score < bestDist then
                                best, bestPos, bestDist, bestMap = v, ppos, score, tgt
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    return best, bestPos, bestDist, bestMap
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

-- ⭐ ANIMATION restore
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
            "rbxassetid://180393478",
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

-- ⭐ REPLACE — chỉ dùng cho TELE (không dùng khi chạy về)
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

-- ⭐ CHẠY VELOCITY tới vị trí
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

-- ⭐ TELE 1 phát
local function teleToPos(targetPos)
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

-- ⭐⭐⭐ CHẠY VỀ HOME bằng VELOCITY (restore humanoid trước)
local function runHome()
    log("🏃 Chạy velocity về home...")

    -- ⭐ RESTORE HUMANOID trước khi chạy
    restoreHumanoid()
    task.wait(config.RUN_HOME_DELAY)

    local t0 = os.clock()
    local lastPos = nil
    local stuckTime = os.clock()
    local lastLog = t0

    while os.clock() - t0 < config.HOME_TIMEOUT and isRunning do
        local hum, r = getHum(), getHRP()
        if not hum or not r then task.wait(0.05); continue end
        keepHealth()

        local curPos = r.Position
        local d = dist(curPos, config.HOME_POS)

        if d < config.ARRIVE_DIST then
            pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)
            log(string.format("✅ Về home (%.1fs)", os.clock() - t0))
            return true
        end

        pcall(function()
            local dir = config.HOME_POS - curPos
            if dir.Magnitude > 0 then
                local nrm = dir.Unit
                local ramp = math.min((os.clock() - t0) / 0.5, 1)
                r.AssemblyLinearVelocity = nrm * math.min(config.SPEED / 2.5, config.SPEED_CAP) * ramp
                -- Nudge nhẹ
                if d > 30 then
                    local nudge = math.min(d, 80) * 0.06
                    r.CFrame = CFrame.new(curPos + nrm * nudge)
                end
            end
        end)

        -- Log mỗi 5s
        if os.clock() - lastLog > 5 then
            log(string.format("⏳ Còn %.0f studs", d))
            lastLog = os.clock()
        end

        -- Chống kẹt
        if lastPos then
            local moved = dist(curPos, lastPos)
            if moved < 0.5 then
                if os.clock() - stuckTime > 0.4 then
                    pcall(function() hum.Jump = true end)
                    stuckTime = os.clock()
                end
            else
                stuckTime = os.clock()
            end
        end
        lastPos = curPos
        task.wait(0.02)
    end

    -- Timeout → tele về home
    log("⚠ Timeout → tele về home")
    local r = getHRP()
    if r then
        pcall(function()
            r.CFrame = CFrame.new(config.HOME_POS)
            r.AssemblyLinearVelocity = Vector3.zero
        end)
        task.wait(0.2)
    end
    return true
end

-- ⭐⭐⭐ STEAL — tự check vị trí + re-tele
local function stealAtPos(eggPos, label)
    log("═══════")
    log("STEAL: " .. label)

    task.wait(0.05)

    -- Tele tới egg nếu xa
    local hrp = getHRP()
    if not hrp or dist(hrp.Position, eggPos) > 50 then
        teleToPos(eggPos + Vector3.new(0, 3, 0))
        task.wait(0.1)
    end

    local prompt = findPromptSteal(eggPos, 150)
    if not prompt then
        log("⚠ Không prompt")
        return false
    end

    local slotsBefore, countBefore = getSlotSet()
    log("📊 Slots: " .. countBefore)

    for i = 1, config.MAX_FIRES do
        if not isRunning then return false end

        -- ⭐ Check bị văng khỏi egg
        local h2 = getHRP()
        if h2 then
            local dEgg = dist(h2.Position, eggPos)
            if dEgg > 30 then
                log(string.format("💥 Văng %.0f studs — re-tele", dEgg))
                teleToPos(eggPos + Vector3.new(0, 3, 0))
                task.wait(0.1)
            end

            local p2 = findPromptSteal(h2.Position, 150)
            if p2 then firePromptOnce(p2) end
        end

        task.wait(config.STEAL_VERIFY_WAIT)

        local stolen, name = hasStolenSlot(slotsBefore)
        if stolen then
            log("🎒 OK: " .. name)
            return true
        end
    end

    log("⚠ Fail fire")
    return false
end

local function baitBoss(timeout)
    timeout = timeout or config.BAIT_TIMEOUT
    log("🎯 Bait boss Forest...")
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
        if hum:GetState() == Enum.HumanoidStateType.Physics and speed > 30 then
            log("💥 PHYSICS"); return true
        end
        if speed > 60 and vel.Y > 10 then log("💥 VELOCITY"); return true end
        if hum.Health < startHealth - config.KB_HEALTH_DROP then log("💥 HP"); return true end
        if (hrp.Position - startPos).Magnitude > 15 and speed > 30 then log("💥 SHIFT"); return true end
        pcall(function() hum:MoveTo(hrp.Position) end)
        task.wait(0.01)
    end
    log("⚠ Hết " .. timeout .. "s")
    return false
end

local function mainLoop()
    while isRunning do
        log("═══════════════════════")
        log("PHASE 1: Forest")

        if not velocityMoveTo(config.FOREST_POS, 30) then
            if not isRunning then break end
            task.wait(0.5)
        else
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
                    for i = 1, 5 do
                        if not isRunning then break end
                        local h2 = getHRP()
                        if h2 then
                            local p2 = findPromptSteal(h2.Position, 150)
                            if p2 then firePromptOnce(p2) end
                        end
                        task.wait(0.3)
                        local stolen = hasStolenSlot(fb)
                        if stolen then break end
                    end
                    stolenPrompts[prompt] = true
                    task.wait(0.1)

                    log("PHASE 3: Bait boss")
                    if baitBoss(config.BAIT_TIMEOUT) then
                        log("PHASE 4: Tìm egg target")
                        local eggPrompt, eggPos, _, eggMap = findEggInTargets()

                        if eggPos and eggMap then
                            log(string.format("🎯 Map: %s", eggMap.name))
                            local targetPos = eggPos + Vector3.new(0, 3, 0)

                            local success = false
                            for attempt = 1, config.MAX_RETRY do
                                if not isRunning then break end
                                log("🔄 ATTEMPT " .. attempt)
                                deliveryFailed = false

                                teleToPos(targetPos)
                                task.wait(0.1)

                                local stolen = stealAtPos(eggPos, eggMap.name)

                                if stolen then
                                    -- ⭐⭐⭐ STEAL XONG → CHẠY VỀ NGAY
                                    local ok = runHome()
                                    if ok then
                                        task.wait(config.CHAT_WAIT)
                                        if deliveryFailed then
                                            log("❌ Chat fail")
                                            task.wait(0.2)
                                        else
                                            log("🎉 SUCCESS")
                                            success = true
                                            break
                                        end
                                    end
                                else
                                    log("⚠ Steal fail — retry")
                                    task.wait(0.3)
                                end
                            end

                            if not success then log("❌ Hết retry") end
                        else
                            log("⚠ Không tìm thấy egg target")
                        end
                    end
                end
            else
                log("⚠ Không prompt Forest")
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
    isRunning = true
    log("▶ START — " .. #config.TARGETS .. " maps")
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

function M.getAllMaps() return ALL_MAPS end
function M.setHome(p) if p then config.HOME_POS = p; log("📍 Home") end end
function M.setForest(p) if p then config.FOREST_POS = p; log("📍 Forest") end end
function M.getConfig() return config end

return M
