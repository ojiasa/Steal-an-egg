-- ═══════════════════════════════════════════════════════════════
-- STEAL MODULE v9.1 — FIX văng trời + stop không dừng
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

    SPEED          = 1500,
    SPEED_CAP      = 500,
    MAP_RADIUS     = 800,
    ARRIVE_DIST    = 10,
    BAIT_TIMEOUT   = 20,
    KB_HEALTH_DROP = 0.5,
    MAX_FIRES      = 8,
    MAX_RETRY      = 3,
    STEAL_VERIFY_WAIT = 0.35,
    CHAT_WAIT      = 2.0,

    -- ⭐ Anti-launch
    ANTI_LAUNCH_TIME = 2.5,
    ANTI_LAUNCH_Y    = 15,
    ANTI_LAUNCH_MAG  = 250,
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

local function calcIncome(eggData)
    if not AssetEarnings then return 0 end
    local input = {
        Category = eggData.AssetCategory,
        Scale = eggData.AssetScale or 1,
        Mutations = eggData.Mutations or {},
    }
    local income = 0
    local ok, val = pcall(AssetEarnings.LiveRatePerSecond, input)
    if ok and type(val) == "number" and val > 0 then income = val end
    if income == 0 then
        ok, val = pcall(AssetEarnings.RatePerSecond, input)
        if ok and type(val) == "number" and val > 0 then income = val end
    end
    return income
end

local function formatIncome(n)
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.2fK", n / 1e3) end
    return string.format("%.0f", n)
end

local function getEggCandidates()
    local candidates = {}
    if not EggState then return candidates end

    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then
        return candidates
    end

    for uid, eggData in pairs(fd.Records) do
        local cf = eggData.BoundsCFrame
        if cf then
            local pos = cf.Position
            if dist(pos, config.HOME_POS) > 150 then
                local income = calcIncome(eggData)
                local nearestMap, nearestDist = nil, 99999
                for _, m in ipairs(ALL_MAPS) do
                    local d = dist(pos, m.pos)
                    if d < nearestDist then
                        nearestMap = m
                        nearestDist = d
                    end
                end
                if nearestMap then
                    table.insert(candidates, {
                        uid = uid,
                        pos = pos,
                        income = income,
                        map = nearestMap,
                        category = eggData.AssetCategory,
                        scale = eggData.AssetScale,
                        mutation = eggData.BaseMutation,
                    })
                end
            end
        end
    end
    return candidates
end

local function pickBestEgg()
    if not isRunning then return nil end

    local candidates = getEggCandidates()
    if #candidates == 0 then
        log("⚠ Không có egg nào trên field")
        return nil
    end

    -- Filter theo target maps (dùng dist thay vì name để chính xác)
    if not config.PRIORITY_INCOME then
        local filtered = {}
        for _, c in ipairs(candidates) do
            for _, tgt in ipairs(config.TARGETS) do
                if dist(c.pos, tgt.pos) < 500 then
                    table.insert(filtered, c)
                    break
                end
            end
        end
        candidates = filtered
        if #candidates == 0 then
            log("⚠ Không có egg trong map target")
            return nil
        end
    end

    if config.PRIORITY_INCOME then
        local filtered = {}
        for _, c in ipairs(candidates) do
            if c.income >= config.PRIORITY_THRESHOLD then
                table.insert(filtered, c)
            end
        end
        candidates = filtered
        if #candidates == 0 then
            log("⚠ Không có egg >= $" .. formatIncome(config.PRIORITY_THRESHOLD) .. "/s")
            return nil
        end

        table.sort(candidates, function(a, b) return a.income > b.income end)

        log("💰 TOP 3 egg:")
        for i = 1, math.min(3, #candidates) do
            local c = candidates[i]
            local mut = c.mutation and (" [" .. c.mutation .. "]") or ""
            log(string.format("  [%d] %s%s @ %s = $%s/s",
                i, c.category, mut, c.map.name, formatIncome(c.income)))
        end
    elseif config.PREFER_FAR then
        table.sort(candidates, function(a, b)
            return dist(a.map.pos, config.HOME_POS) > dist(b.map.pos, config.HOME_POS)
        end)
    else
        local hrp = getHRP()
        if hrp then
            table.sort(candidates, function(a, b)
                return dist(a.pos, hrp.Position) < dist(b.pos, hrp.Position)
            end)
        end
    end

    local best = candidates[1]
    log(string.format("🎯 CHỌN: %s @ %s = $%s/s",
        best.category, best.map.name, formatIncome(best.income)))
    return best
end

local function findPromptNear(pos, radius)
    radius = radius or 20
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

-- ⭐ FIX: KHÔNG destroy Humanoid, chỉ reset state
local function replaceHumanoidDirect()
    local c = P.Character
    if not c then return false end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hum then return false end

    pcall(function()
        hum.PlatformStand = false
        hum.Sit = false
        hum:SetStateEnabled(Enum.HumanoidStateType.Dying, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
        hum.MaxHealth = 99999
        hum.Health = 99999
        hum.WalkSpeed = 60
        if hum:GetState() ~= Enum.HumanoidStateType.Running
            and hum:GetState() ~= Enum.HumanoidStateType.Freefall
            and hum:GetState() ~= Enum.HumanoidStateType.Jumping
            and hum:GetState() ~= Enum.HumanoidStateType.Landed then
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)

    -- Đảm bảo có Animator
    pcall(function()
        if not hum:FindFirstChildOfClass("Animator") then
            local a = Instance.new("Animator")
            a.Parent = hum
        end
    end)

    -- Reset velocity ngay
    local hrp = getHRP()
    if hrp then pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end) end

    return true
end

local function teleToPos(targetPos)
    if not isRunning then return end  -- ⭐ FIX stop

    local hrp = getHRP()
    if hrp then pcall(function()
        hrp.CFrame = CFrame.new(targetPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end) end

    if not isRunning then return end  -- ⭐ FIX stop
    replaceHumanoidDirect()

    for i = 1, 6 do
        if not isRunning then return end  -- ⭐ FIX stop
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

-- ⭐ FIX VĂNG TRỜI: chống launch trong lúc chạy về home
local function antiLaunch(duration)
    duration = duration or config.ANTI_LAUNCH_TIME
    local t0 = os.clock()
    while os.clock() - t0 < duration and isRunning do
        local hrp = getHRP()
        if hrp then
            pcall(function()
                local v = hrp.AssemblyLinearVelocity
                if v.Y > config.ANTI_LAUNCH_Y or v.Magnitude > config.ANTI_LAUNCH_MAG then
                    hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.2, 0, v.Z * 0.2)
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
            end)
        end
        task.wait()
    end
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

local function goHomeFast()
    log("🏃 CHẠY VỀ HOME")
    local startTime = os.clock()
    local t0 = startTime
    local lastPos = nil
    local stuckTime = os.clock()

    while os.clock() - t0 < 30 and isRunning do  -- ⭐ FIX stop
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
            -- ⭐ FIX văng trời: ép Y xuống nếu đang bay lên
            local v = r.AssemblyLinearVelocity
            if v.Y > config.ANTI_LAUNCH_Y then
                r.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
            end

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

local function waitForBossHit(timeout)
    timeout = timeout or config.BAIT_TIMEOUT
    log("🎯 Chờ boss Forest đánh...")
    local t0 = os.clock()
    local hum0 = getHum()
    local hrp0 = getHRP()
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
            log(string.format("💥 PHYSICS (%.0f)", speed)); return true
        end
        if speed > 60 and vel.Y > 10 then
            log(string.format("💥 VELOCITY (%.0f)", speed)); return true
        end
        if hum.Health < startHealth - config.KB_HEALTH_DROP then
            log("💥 HP"); return true
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

local function stealAtPos(eggPos, label)
    log("═══════")
    log("STEAL TẠI " .. label)
    task.wait(0.05)

    local hrp = getHRP()
    if not hrp or dist(hrp.Position, eggPos) > 30 then
        teleToPos(eggPos + Vector3.new(0, 3, 0))
        task.wait(0.1)
    end

    -- ⭐ FIX: chờ prompt load (5 lần x 0.2s = 1s)
    local prompt
    for i = 1, 5 do
        if not isRunning then return false end
        prompt = findPromptNear(eggPos, 150)
        if prompt then break end
        task.wait(0.2)
    end
    if not prompt then
        log("⚠ Không có prompt")
        return false
    end

    local slotsBefore, countBefore = getSlotSet()
    log("📊 Slots: " .. countBefore)

    for i = 1, config.MAX_FIRES do
        if not isRunning then return false end
        local h2 = getHRP()
        if h2 then
            local p2 = findPromptNear(h2.Position, 150)
            if p2 then firePromptOnce(p2) end
        end
        task.wait(config.STEAL_VERIFY_WAIT)
        local stolen, slotName = hasStolenSlot(slotsBefore)
        if stolen then
            log("🎒 SLOT MẤT: " .. slotName:sub(1, 20))
            log("✅ ĐÃ STEAL")
            return true
        end
    end
    log("⚠ Fail fire")
    return false
end

-- ══════════ MAIN LOOP ══════════
local function mainLoop()
    while isRunning do
        log("═══════════════════════")
        log("PHASE 1: Bay tới Forest")

        if not velocityMoveTo(config.FOREST_POS, 30) then
            if not isRunning then break end
            task.wait(0.5)
        else
            log("✅ Tới Forest")
            local hrp = getHRP()
            local prompt = hrp and findPromptNear(hrp.Position, config.MAP_RADIUS)

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

                    local forestBefore = getSlotSet()
                    log("⚡ Steal Forest")
                    for i = 1, 5 do
                        if not isRunning then break end
                        local h2 = getHRP()
                        if h2 then
                            local p2 = findPromptNear(h2.Position, 150)
                            if p2 then firePromptOnce(p2) end
                        end
                        task.wait(0.3)
                        local stolen = hasStolenSlot(forestBefore)
                        if stolen then log("🎒 Forest OK"); break end
                    end
                    stolenPrompts[prompt] = true
                    task.wait(0.1)

                    log("PHASE 3: Chờ boss")
                    if waitForBossHit(config.BAIT_TIMEOUT) then
                        log("PHASE 4: Chọn egg & tele")

                        local best = pickBestEgg()
                        if best then
                            log(string.format("🎯 Map: %s @ %.1f,%.1f,%.1f",
                                best.map.name, best.pos.X, best.pos.Y, best.pos.Z))

                            local targetPos = best.pos + Vector3.new(0, 3, 0)

                            -- ⭐ RETRY loop
                            local success = false
                            for attempt = 1, config.MAX_RETRY do
                                if not isRunning then break end
                                log(string.format("🔄 Attempt %d/%d", attempt, config.MAX_RETRY))
                                deliveryFailed = false

                                teleToPos(targetPos)
                                task.wait(0.15)

                                if not isRunning then break end

                                if stealAtPos(best.pos, best.category) then
                                    -- ⭐ FIX VĂNG TRỜI: bật antiLaunch song song
                                    task.spawn(antiLaunch, config.ANTI_LAUNCH_TIME)
                                    goHomeFast()
                                    task.wait(config.CHAT_WAIT)
                                    if deliveryFailed then
                                        log("❌ Chat fail — retry")
                                        task.wait(0.3)
                                    else
                                        log("🎉 SUCCESS")
                                        success = true
                                        break
                                    end
                                else
                                    log("⚠ Steal fail — retry")
                                    task.wait(0.3)
                                end
                            end

                            if not success then
                                log("❌ Hết " .. config.MAX_RETRY .. " lần retry")
                            end
                        else
                            log("⚠ Không có egg để steal")
                        end
                    end
                end
            end
        end

        if not isRunning then break end
        task.wait(0.5)
    end
end

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
    log("▶ START v9.1")
    task.spawn(mainLoop)
end

function M.stop()
    isRunning = false
    log("■ STOP")
    -- ⭐ FIX: dọn state ngay
    task.spawn(function()
        task.wait(0.1)
        local hrp = getHRP()
        if hrp then pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end) end
    end)
end

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
    log("💰 Ưu tiên: " .. (enabled and "BẬT" or "TẮT"))
    return config.PRIORITY_INCOME
end

function M.isPriorityIncome() return config.PRIORITY_INCOME end
function M.togglePriorityIncome() return M.setPriorityIncome(not config.PRIORITY_INCOME) end

function M.setPriorityThreshold(amount)
    config.PRIORITY_THRESHOLD = amount or 1000000
    log("💰 Ngưỡng: $" .. formatIncome(config.PRIORITY_THRESHOLD) .. "/s")
end

function M.getPriorityThreshold() return config.PRIORITY_THRESHOLD end
function M.getAllMaps() return ALL_MAPS end
function M.setHome(p) if p then config.HOME_POS = p end end
function M.setForest(p) if p then config.FOREST_POS = p end end
function M.getConfig() return config end

return M
