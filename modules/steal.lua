-- ═══════════════════════════════════════════════════════════════
-- v60.3.2 — GLOBAL SLOT SET + FIX ANIMATION (R6/R15)
-- Replace + reset Animate script → không T-pose, chân chạy bình thường
-- ═══════════════════════════════════════════════════════════════

local P                  = game:GetService("Players").LocalPlayer
local UIS                = game:GetService("UserInputService")
local RS                 = game:GetService("RunService")
local ProximityPromptSvc = game:GetService("ProximityPromptService")
local W                  = workspace

-- ══════════ LOG ══════════
local lines       = {}
local currentText = ""
local logOutput
local logScroll

local function add(s)
    s = tostring(s or "")
    table.insert(lines, s)
    if #lines > 80 then table.remove(lines, 1) end
    currentText = table.concat(lines, "\n")
    if logOutput then
        pcall(function()
            logOutput.Text = currentText
            if logScroll then logScroll.CanvasPosition = Vector2.new(0, 999999) end
        end)
    end
    print("[v60.3.2] " .. s)
end

local function clear()
    lines = {}
    currentText = ""
    if logOutput then pcall(function() logOutput.Text = "" end) end
end

-- ══════════ CONFIG ══════════
local HOME_POS          = Vector3.new(465.2, 67.1, -364.1)
local FOREST_POS        = Vector3.new(599.9, 67.6, -363.9)
local SPEED             = 1500
local SPEED_CAP         = 500
local MAP_RADIUS        = 800
local TARGET_RADIUS     = 2000
local ARRIVE_DIST       = 10
local BAIT_TIMEOUT      = 15
local SAFE_WAIT         = 0.5
local KB_SPEED          = 50
local KB_Y              = 15
local KB_HEALTH_DROP    = 0.5
local MAX_FIRES         = 8
local MAX_RETRY         = 3
local STEAL_VERIFY_WAIT = 0.35
local CHAT_WAIT         = 2.0

local TARGET_MAP = {
    name = "Snow",
    pos  = Vector3.new(1405.1, 68.0, -363.8),
}

local isRunning      = false
local stolenPrompts  = {}
local deliveryFailed = false

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
        local chatEvents = game:GetService("ReplicatedStorage"):WaitForChild("DefaultChatSystemChatEvents", 5)
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
                add("❌ Chat: Delivery failed")
            end
        end)
    end)
end)

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

-- ⭐ GLOBAL SLOT SET
local function getSlotSet()
    local set = {}
    local count = 0
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
        if not now[name] then
            return true, name
        end
    end
    return false, nil
end

-- ⭐ TÌM PROMPT TRỨNG
local function findTargetEggPrompt()
    local best, bestPos, bestDist = nil, nil, 99999
    for _, v in ipairs(W:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEggPrompt = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg"
                    and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEggPrompt then
                local part = v.Parent
                local ppos
                if part and part:IsA("BasePart") then ppos = part.Position
                elseif part and part:IsA("Attachment") then ppos = part.WorldPosition
                elseif part and part.Parent and part.Parent:IsA("BasePart") then
                    ppos = part.Parent.Position end
                if ppos then
                    local dToTarget = dist(ppos, TARGET_MAP.pos)
                    if dToTarget < 800 then
                        if dToTarget < bestDist then
                            best, bestPos, bestDist = v, ppos, dToTarget
                        end
                    end
                end
            end
        end
    end
    return best, bestPos, bestDist
end

-- ⭐ KHÔI PHỤC ANIMATION — auto detect R6/R15
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

        local animIds
        if isR15 then
            animIds = {
                "rbxassetid://507766666",   -- idle1
                "rbxassetid://507766951",   -- idle2
                "rbxassetid://507777826",   -- walk
                "rbxassetid://507767714",   -- run
                "rbxassetid://507765000",   -- jump
                "rbxassetid://507767968",   -- fall
                "rbxassetid://507765644",   -- climb
                "rbxassetid://507784897",   -- swim
                "rbxassetid://507785072",   -- swimidle
            }
        else
            animIds = {
                "rbxassetid://180435571",   -- idle1
                "rbxassetid://180435792",   -- idle2
                "rbxassetid://180426354",   -- walk
                "rbxassetid://125750702",   -- jump
                "rbxassetid://180436148",   -- fall
                "rbxassetid://180436334",   -- climb
                "rbxassetid://182393478",   -- toolnone
            }
        end

        for _, id in ipairs(animIds) do
            pcall(function()
                local a = Instance.new("Animation")
                a.AnimationId = id
                anim:LoadAnimation(a)
            end)
        end
    end)
end

-- ⭐ RESET ANIMATE SCRIPT — chuẩn nhất
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

-- ⭐ REPLACE HUMANOID
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

    -- ⭐ KHÔI PHỤC ANIMATION — 2 LỚP
    task.spawn(restoreAnimations)
    task.spawn(function()
        task.wait(0.1)
        resetAnimateScript()
        task.wait(0.2)
        -- Force state running
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then
            pcall(function()
                h:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
    end)

    return true
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

local function findPromptSteal(pos, radius)
    radius = radius or MAP_RADIUS
    local best, bestDist = nil, radius
    for _, v in ipairs(W:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEggPrompt = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg"
                    and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEggPrompt then
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
local function velocityMoveTo(targetPos, timeout, manual)
    timeout = timeout or 20
    local hum, hrp = getHum(), getHRP()
    if not hum or not hrp then return false end
    keepHealth()

    local function shouldStop()
        if manual then return false end
        return not isRunning
    end

    local t0        = os.clock()
    local lastPos   = hrp.Position
    local stuckTime = os.clock()

    while not shouldStop() and os.clock() - t0 < timeout do
        hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth()

        local d = dist(hrp.Position, targetPos)
        if d < ARRIVE_DIST then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            return true
        end

        pcall(function()
            local dir = targetPos - hrp.Position
            if dir.Magnitude > 0 then
                local nrm = dir.Unit
                hrp.AssemblyLinearVelocity = nrm * math.min(SPEED / 2.5, SPEED_CAP)
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
            lastPos   = hrp.Position
            stuckTime = os.clock()
        end
        task.wait(0.01)
    end
    pcall(function() local r = getHRP(); if r then r.AssemblyLinearVelocity = Vector3.zero end end)
    return false
end

local function goHomeFast()
    add("🏃 CHẠY VỀ HOME")

    local startTime = os.clock()
    local t0 = startTime
    local lastPos = nil
    local stuckTime = os.clock()

    while os.clock() - t0 < 30 do
        local hum, r = getHum(), getHRP()
        if not hum or not r then break end
        keepHealth()

        local d = dist(r.Position, HOME_POS)
        if d < ARRIVE_DIST then
            pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)
            add(string.format("✅ Về home (%.2fs)", os.clock() - startTime))
            return true
        end

        pcall(function()
            local dir = HOME_POS - r.Position
            if dir.Magnitude > 0 then
                local nrm = dir.Unit
                local ramp = math.min((os.clock() - t0) / 0.3, 1)
                r.AssemblyLinearVelocity = nrm * math.min(SPEED / 2.5, SPEED_CAP) * ramp
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
    timeout = timeout or BAIT_TIMEOUT
    add("🎯 Bait boss...")

    local t0 = os.clock()
    local startHealth = nil
    local startPos = nil
    local hum0 = getHum()
    local hrp0 = getHRP()
    if hum0 then startHealth = hum0.Health end
    if hrp0 then startPos = hrp0.Position end

    while isRunning and os.clock() - t0 < timeout do
        local hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth()

        local vel = hrp.AssemblyLinearVelocity
        local speed = vel.Magnitude
        local state = hum:GetState()

        if state == Enum.HumanoidStateType.Physics and speed > 30 then
            add(string.format("💥 [1] PHYSICS! speed=%.1f Y=%.1f", speed, vel.Y))
            return true
        end

        if speed > 60 and vel.Y > 10 then
            add(string.format("💥 [2] VELOCITY! speed=%.1f Y=%.1f", speed, vel.Y))
            return true
        end

        if startHealth and hum.Health < startHealth - KB_HEALTH_DROP then
            add(string.format("💥 [3] HEALTH! %.1f → %.1f", startHealth, hum.Health))
            return true
        end

        if startPos then
            local pd = (hrp.Position - startPos).Magnitude
            if pd > 15 and speed > 30 then
                add(string.format("💥 [4] SHIFT! %.1f studs", pd))
                return true
            end
        end

        pcall(function() hum:MoveTo(hrp.Position) end)
        task.wait(0.01)
    end

    add("⚠ Hết " .. timeout .. "s")
    return false
end

-- ⭐ STEAL
local function stealAtPos(targetPos, label)
    add("═══════════════════════")
    add("STEAL TẠI " .. label)

    task.wait(0.05)

    local hrp = getHRP()
    if not hrp or dist(hrp.Position, targetPos) > 50 then
        teleToMap(targetPos)
        task.wait(0.05)
    end

    local prompt = findPromptSteal(targetPos, 150)
    if not prompt then
        add("⚠ Không có prompt")
        return false
    end

    local slotsBefore, countBefore = getSlotSet()
    add("📊 Global slots trước: " .. countBefore)

    for i = 1, MAX_FIRES do
        if not isRunning then return false end

        local h2 = getHRP()
        if h2 then
            local p2 = findPromptSteal(h2.Position, 150)
            if p2 then
                firePromptOnce(p2)
            end
        end

        task.wait(STEAL_VERIFY_WAIT)

        local _, countNow = getSlotSet()
        local stolen, slotName = hasStolenSlot(slotsBefore)

        if stolen then
            add("🎒 SLOT MẤT: " .. slotName)
            add(string.format("📊 Slots: %d → %d", countBefore, countNow))
            add("✅ ĐÃ STEAL — CHẠY VỀ NGAY")
            return true
        end
    end

    add("⚠ Fire " .. MAX_FIRES .. " lần không giảm slot")
    return false
end

-- ══════════ MAIN CYCLE ══════════
local function mainLoop()
    while isRunning do
        add("═══════════════════════")
        add("PHASE 1: Bay tới Forest")

        if not velocityMoveTo(FOREST_POS, 30) then
            if not isRunning then break end
            add("❌ Không tới Forest")
            task.wait(0.5)
        else
            add("✅ Tới Forest")

            local hrp = getHRP()
            local prompt = hrp and findPromptSteal(hrp.Position, MAP_RADIUS)

            if prompt then
                local part = prompt.Parent
                local ppos
                if part:IsA("BasePart") then ppos = part.Position
                elseif part:IsA("Attachment") then ppos = part.WorldPosition
                elseif part.Parent and part.Parent:IsA("BasePart") then ppos = part.Parent.Position end

                if ppos then
                    if dist(hrp.Position, ppos) > ARRIVE_DIST then
                        velocityMoveTo(ppos, 20)
                    end

                    local forestBefore, forestCount = getSlotSet()
                    add("📊 Forest global slots: " .. forestCount)

                    add("⚡ Steal Forest")
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
                            add("🎒 Forest OK: " .. slotName)
                            break
                        end
                    end
                    stolenPrompts[prompt] = true
                    task.wait(0.1)

                    add("PHASE 3: Bait boss Forest")
                    local gotKnockback = baitBoss(BAIT_TIMEOUT)

                    if gotKnockback then
                        add("═══════════════════════")
                        add("PHASE 4: Tìm prompt " .. TARGET_MAP.name)

                        local eggPrompt, eggPos, eggDist = findTargetEggPrompt()

                        if eggPos then
                            add(string.format("🎯 Prompt: %.1f,%.1f,%.1f",
                                eggPos.X, eggPos.Y, eggPos.Z))

                            local targetPos = eggPos + Vector3.new(0, 3, 0)

                            local success = false
                            for attempt = 1, MAX_RETRY do
                                if not isRunning then break end

                                add("")
                                add("═══════════════════════")
                                add(string.format("🔄 ATTEMPT %d/%d", attempt, MAX_RETRY))

                                deliveryFailed = false

                                teleToMap(targetPos)
                                task.wait(0.05)

                                local stolen = stealAtPos(eggPos, TARGET_MAP.name)
                                if stolen then
                                    goHomeFast()
                                    task.wait(CHAT_WAIT)

                                    if deliveryFailed then
                                        add("❌ Chat báo fail — RETRY")
                                        task.wait(0.2)
                                    else
                                        add("🎉 THÀNH CÔNG — không có chat fail")
                                        success = true
                                        break
                                    end
                                else
                                    add("⚠ Steal fail — retry")
                                    task.wait(0.2)
                                end
                            end

                            if success then
                                deliveryFailed = false
                                add("🎉 HOÀN THÀNH")
                            else
                                add("❌ Hết " .. MAX_RETRY .. " lần retry")
                            end
                        else
                            add("⚠ Không tìm thấy prompt target")
                        end
                    end
                end
            else
                add("⚠ Không có prompt Forest")
            end
        end

        if not isRunning then break end
        task.wait(0.5)
    end
end

-- ══════════ UI ══════════
local old = P.PlayerGui:FindFirstChild("v50")
if old then old:Destroy() end

local g = Instance.new("ScreenGui")
g.Name = "v50"
g.ResetOnSpawn = false
g.IgnoreGuiInset = true
g.DisplayOrder = 999999
g.Parent = P:WaitForChild("PlayerGui")

local icon = Instance.new("TextButton")
icon.Size = UDim2.new(0, 42, 0, 42)
icon.Position = UDim2.new(0, 15, 0, 150)
icon.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
icon.Text = "🌀"
icon.TextSize = 18
icon.Font = Enum.Font.GothamBold
icon.TextColor3 = Color3.fromRGB(120, 200, 255)
icon.AutoButtonColor = false
icon.Parent = g
Instance.new("UICorner", icon).CornerRadius = UDim.new(1,0)
local ist = Instance.new("UIStroke") ist.Color = Color3.fromRGB(120,200,255) ist.Thickness = 1.5 ist.Parent = icon

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 300, 0, 460)
panel.Position = UDim2.new(0.5, -150, 0.5, -230)
panel.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = g
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,6)
local ps = Instance.new("UIStroke") ps.Color = Color3.fromRGB(120,200,255) ps.Thickness = 1 ps.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 24)
title.BackgroundColor3 = Color3.fromRGB(22, 24, 33)
title.Text = "🌀 v60.3.2 — FIX ANIM"
title.TextColor3 = Color3.fromRGB(180, 230, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 10
title.Parent = panel
Instance.new("UICorner", title).CornerRadius = UDim.new(0,6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 20, 0, 20)
closeBtn.Position = UDim2.new(1, -22, 0, 2)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 33, 45)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(150, 160, 180)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 9
closeBtn.AutoButtonColor = false
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1,0)

local targetInfo = Instance.new("TextLabel")
targetInfo.Size = UDim2.new(1, -8, 0, 22)
targetInfo.Position = UDim2.new(0, 4, 0, 28)
targetInfo.BackgroundColor3 = Color3.fromRGB(30, 33, 45)
targetInfo.Text = "🎯 Target: " .. TARGET_MAP.name
targetInfo.TextColor3 = Color3.fromRGB(180, 230, 255)
targetInfo.Font = Enum.Font.GothamBold
targetInfo.TextSize = 9
targetInfo.Parent = panel
Instance.new("UICorner", targetInfo).CornerRadius = UDim.new(0,4)

local mapScroll = Instance.new("ScrollingFrame")
mapScroll.Size = UDim2.new(1, -8, 0, 130)
mapScroll.Position = UDim2.new(0, 4, 0, 54)
mapScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
mapScroll.BorderSizePixel = 0
mapScroll.ScrollBarThickness = 3
mapScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
mapScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mapScroll.Parent = panel
Instance.new("UICorner", mapScroll).CornerRadius = UDim.new(0,4)
local msp = Instance.new("UIPadding")
msp.PaddingTop = UDim.new(0,3); msp.PaddingLeft = UDim.new(0,3)
msp.PaddingRight = UDim.new(0,3); msp.PaddingBottom = UDim.new(0,3)
msp.Parent = mapScroll

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = mapScroll

logScroll = Instance.new("ScrollingFrame")
logScroll.Size = UDim2.new(1, -8, 1, -230)
logScroll.Position = UDim2.new(0, 4, 0, 190)
logScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
logScroll.BorderSizePixel = 0
logScroll.ScrollBarThickness = 3
logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
logScroll.Parent = panel
Instance.new("UICorner", logScroll).CornerRadius = UDim.new(0,4)
local lsp = Instance.new("UIPadding")
lsp.PaddingTop = UDim.new(0,3); lsp.PaddingLeft = UDim.new(0,3)
lsp.PaddingRight = UDim.new(0,3); lsp.PaddingBottom = UDim.new(0,3)
lsp.Parent = logScroll

logOutput = Instance.new("TextLabel")
logOutput.Size = UDim2.new(1, 0, 0, 0)
logOutput.BackgroundTransparency = 1
logOutput.Text = "Target: " .. TARGET_MAP.name .. "\nBấm START"
logOutput.TextColor3 = Color3.fromRGB(230, 235, 245)
logOutput.Font = Enum.Font.Code
logOutput.TextSize = 8
logOutput.TextXAlignment = Enum.TextXAlignment.Left
logOutput.TextYAlignment = Enum.TextYAlignment.Top
logOutput.TextWrapped = true
logOutput.AutomaticSize = Enum.AutomaticSize.Y
logOutput.Parent = logScroll

local TARGET_MAPS = {
    {name = "Forest",         pos = Vector3.new( 599.9, 67.6, -363.9)},
    {name = "Lake",           pos = Vector3.new( 722.5, 67.7, -363.9)},
    {name = "Desert",         pos = Vector3.new( 930.8, 67.5, -320.6)},
    {name = "Jungle",         pos = Vector3.new(1124.7, 67.5, -363.9)},
    {name = "Snow",           pos = Vector3.new(1405.1, 68.0, -363.8)},
    {name = "Volcano",        pos = Vector3.new(1863.1, 68.0, -399.5)},
    {name = "Abyss Ocean",    pos = Vector3.new(2166.1, 67.6, -363.9)},
    {name = "Prehistoric",    pos = Vector3.new(2634.4, 67.6, -363.9)},
    {name = "Cosmic",         pos = Vector3.new(3376.8, 68.4, -322.7)},
    {name = "Cherry Blossom", pos = Vector3.new(3928.0, 67.6, -363.8)},
    {name = "Titan Temple",   pos = Vector3.new(4698.0, 67.6, -363.8)},
    {name = "Light Dark",     pos = Vector3.new(5563.0, 67.6, -363.8)},
}

local mapRows = {}

local function createTargetRow(mapData)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -4, 0, 20)
    row.BackgroundColor3 = (mapData.name == TARGET_MAP.name)
        and Color3.fromRGB(80, 60, 30)
        or Color3.fromRGB(30, 33, 45)
    row.Text = mapData.name
    row.TextColor3 = Color3.fromRGB(230, 235, 245)
    row.Font = Enum.Font.GothamBold
    row.TextSize = 8
    row.AutoButtonColor = false
    row.Parent = mapScroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,3)

    table.insert(mapRows, {btn = row, data = mapData})

    row.MouseButton1Click:Connect(function()
        TARGET_MAP = mapData
        targetInfo.Text = "🎯 Target: " .. mapData.name
        for _, r in ipairs(mapRows) do
            if r.data.name == TARGET_MAP.name then
                r.btn.BackgroundColor3 = Color3.fromRGB(80, 60, 30)
            else
                r.btn.BackgroundColor3 = Color3.fromRGB(30, 33, 45)
            end
        end
        add("🎯 Target: " .. mapData.name)
    end)
end

for _, mp in ipairs(TARGET_MAPS) do createTargetRow(mp) end

local function mkBtn(text, x, y, w, color, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 22)
    b.Position = UDim2.new(0, x, 1, y)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(0, 0, 0)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 8
    b.AutoButtonColor = false
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,4)
    b.MouseButton1Click:Connect(cb)
    return b
end

mkBtn("▶ START", 4, -58, 90, Color3.fromRGB(80, 255, 120), function()
    if isRunning then
        add("■ DỪNG")
        isRunning = false
    else
        installBypass()
        clear()
        stolenPrompts = {}
        deliveryFailed = false
        add("▶ BẮT ĐẦU — Forest → " .. TARGET_MAP.name)
        isRunning = true
        task.spawn(mainLoop)
    end
end)

mkBtn("⏹ STOP", 98, -58, 90, Color3.fromRGB(255, 100, 100), function()
    isRunning = false
    add("■ STOP")
end)

mkBtn("📍 SET HOME", 192, -58, 104, Color3.fromRGB(255, 150, 50), function()
    local hrp = getHRP()
    if hrp then
        HOME_POS = hrp.Position
        add("📍 HOME set")
    end
end)

mkBtn("📍 SET FOREST", 4, -32, 140, Color3.fromRGB(120, 200, 255), function()
    local hrp = getHRP()
    if hrp then
        FOREST_POS = hrp.Position
        add("📍 FOREST set")
    end
end)

mkBtn("⚡ -", 148, -32, 70, Color3.fromRGB(255, 100, 100), function()
    SPEED_CAP = math.max(SPEED_CAP - 50, 100)
    SPEED = SPEED_CAP * 2.5
    add("⚡ Cap: " .. SPEED_CAP)
end)

mkBtn("⚡ +", 222, -32, 74, Color3.fromRGB(80, 255, 120), function()
    SPEED_CAP = math.min(SPEED_CAP + 50, 1000)
    SPEED = SPEED_CAP * 2.5
    add("⚡ Cap: " .. SPEED_CAP)
end)

-- ⭐ NÚT FIX ANIM (bấm khi nhân vật T-pose)
mkBtn("🎬 FIX ANIM", 4, -6, 140, Color3.fromRGB(255, 200, 100), function()
    restoreAnimations()
    task.wait(0.1)
    resetAnimateScript()
    task.wait(0.2)
    local h = getHum()
    if h then
        pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    add("🎬 Đã fix animation")
end)

icon.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
end)
closeBtn.MouseButton1Click:Connect(function()
    panel.Visible = false
end)

local drag, ds, sp2
icon.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        drag, ds, sp2 = true, i.Position, icon.Position
    end
end)
icon.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        drag = false
    end
end)
UIS.InputChanged:Connect(function(i)
    if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - ds
        icon.Position = UDim2.new(sp2.X.Scale, sp2.X.Offset + d.X, sp2.Y.Scale, sp2.Y.Offset + d.Y)
    end
end)

installBypass()
print("[v60.3.2] Ready — fix animation")
