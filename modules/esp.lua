-- ═══════════════════════════════════════════════════════════════
-- ESP MODULE v5 — FIX EGG RESET + STEAL
-- - Verify egg thật tồn tại (check Workspace)
-- - Hash data để phát hiện egg mới
-- - Auto clear khi egg biến mất
-- - Auto rebuild sau khi steal hoặc reset 5p
-- ═══════════════════════════════════════════════════════════════

local P  = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local W  = workspace

local M = {}

-- ══════════ STATE ══════════
local enabled    = false
local espObjects = {}   -- [uid] = {attach, highlight, billboard, distLabel, hash, lastDist}
local parentGui, espFolder
local HOME_POS   = Vector3.new(465.2, 67.1, -364.1)
local filterMaps = nil

local EggState, AssetEarnings

-- ══════════ CONFIG ══════════
local REFRESH_INTERVAL  = 0.25
local DIST_INTERVAL     = 0.15
local VERIFY_INTERVAL   = 0.5      -- verify egg thật tồn tại

-- ══════════ LOAD MODULES ══════════
pcall(function()
    local c = RS:WaitForChild("Client", 5)
    if c then
        local mod = c:WaitForChild("EggState", 5)
        if mod then EggState = require(mod) end
    end
end)
pcall(function()
    local s = RS:WaitForChild("Shared", 5)
    local u = s and s:FindFirstChild("Util", 5)
    local mod = u and u:FindFirstChild("AssetEarnings", 5)
    if mod then AssetEarnings = require(mod) end
end)

-- ══════════ HELPERS ══════════
local function dist(a, b) return (a - b).Magnitude end

local function formatMoney(n)
    if not n then return "?" end
    if n >= 1e12 then return string.format("%.2fT", n/1e12) end
    if n >= 1e9  then return string.format("%.2fB", n/1e9) end
    if n >= 1e6  then return string.format("%.2fM", n/1e6) end
    if n >= 1e3  then return string.format("%.2fK", n/1e3) end
    return string.format("%.0f", n)
end

-- ⭐ Hash data egg (để phát hiện egg mới dù uid trùng)
local function makeHash(eggData, pos)
    return string.format("%s|%s|%.2f|%.2f|%.2f|%.2f|%s",
        tostring(eggData.AssetCategory or ""),
        tostring(eggData.BaseMutation or ""),
        pos.X, pos.Y, pos.Z,
        eggData.AssetScale or 0,
        tostring(eggData.AreaId or ""))
end

-- ⭐ Check egg còn tồn tại thật trong Workspace không
local function verifyEggExists(uid)
    -- Tìm trong AreaEggSlotsClient
    local slots = W:FindFirstChild("AreaEggSlotsClient")
    if not slots then return false end

    for _, slot in ipairs(slots:GetChildren()) do
        if slot.Name == uid then return true end
    end
    return false
end

-- ⭐ Cache income
local incomeCache = {}

local function getIncomeRate(eggData)
    if not AssetEarnings then return nil end
    local key = (eggData.AssetCategory or "") .. "|"
        .. tostring(eggData.AssetScale or 1) .. "|"
        .. tostring(eggData.BaseMutation or "")
    if incomeCache[key] then return incomeCache[key] end

    local input = {
        Category = eggData.AssetCategory,
        Scale = eggData.AssetScale or 1,
        Mutations = eggData.Mutations or {},
    }
    local r
    local ok, val = pcall(AssetEarnings.LiveRatePerSecond, input)
    if ok and type(val) == "number" and val > 0 then r = val end
    if not r then
        ok, val = pcall(AssetEarnings.RatePerSecond, input)
        if ok and type(val) == "number" and val > 0 then r = val end
    end
    incomeCache[key] = r
    return r
end

-- ══════════ CREATE ══════════
local function createESP(uid, data, pos)
    local attach = Instance.new("Part")
    attach.Name = "ESP_" .. uid:sub(1, 8)
    attach.Anchored = true
    attach.CanCollide = false
    attach.CanQuery = false
    attach.CanTouch = false
    attach.Transparency = 1
    attach.Size = Vector3.new(0.1, 0.1, 0.1)
    attach.CFrame = CFrame.new(pos)
    attach.Parent = espFolder

    local color = Color3.fromRGB(255, 220, 80)
    local prefix = "🥚"
    if data.BaseMutation == "Golden" then
        color = Color3.fromRGB(255, 200, 50); prefix = "🌟"
    elseif data.BaseMutation == "Silver" then
        color = Color3.fromRGB(200, 200, 220); prefix = "⭐"
    elseif data.BaseMutation == "Rainbow" then
        color = Color3.fromRGB(255, 100, 200); prefix = "🌈"
    end

    local hl = Instance.new("Highlight")
    hl.FillColor = color; hl.OutlineColor = color
    hl.FillTransparency = 0.6; hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = attach; hl.Parent = espFolder

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 190, 0, 86)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.Adornee = attach; bb.Parent = espFolder

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 16)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = prefix .. " " .. (data.AssetCategory or "Egg")
    nameLbl.TextColor3 = color
    nameLbl.TextStrokeTransparency = 0
    nameLbl.TextStrokeColor3 = Color3.new(0,0,0)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 13
    nameLbl.Parent = bb

    local mutLbl = Instance.new("TextLabel")
    mutLbl.Size = UDim2.new(1, 0, 0, 12)
    mutLbl.Position = UDim2.new(0, 0, 0, 16)
    mutLbl.BackgroundTransparency = 1
    mutLbl.Text = data.BaseMutation and ("✨ " .. data.BaseMutation) or ""
    mutLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
    mutLbl.TextStrokeTransparency = 0
    mutLbl.TextStrokeColor3 = Color3.new(0,0,0)
    mutLbl.Font = Enum.Font.GothamBold
    mutLbl.TextSize = 10
    mutLbl.Parent = bb

    local rate = getIncomeRate(data)
    local rateLbl = Instance.new("TextLabel")
    rateLbl.Size = UDim2.new(1, 0, 0, 15)
    rateLbl.Position = UDim2.new(0, 0, 0, 28)
    rateLbl.BackgroundTransparency = 1
    rateLbl.Text = rate and ("💵 $" .. formatMoney(rate) .. "/s") or "💵 ?"
    rateLbl.TextColor3 = rate and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(150,150,150)
    rateLbl.TextStrokeTransparency = 0
    rateLbl.TextStrokeColor3 = Color3.new(0,0,0)
    rateLbl.Font = Enum.Font.GothamBold
    rateLbl.TextSize = 13
    rateLbl.Parent = bb

    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, 0, 0, 12)
    infoLbl.Position = UDim2.new(0, 0, 0, 44)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Text = string.format("📍 %s | ⚖ %.2f", data.AreaId or "?", data.AssetScale or 0)
    infoLbl.TextColor3 = Color3.fromRGB(180, 220, 255)
    infoLbl.TextStrokeTransparency = 0
    infoLbl.TextStrokeColor3 = Color3.new(0,0,0)
    infoLbl.Font = Enum.Font.Code
    infoLbl.TextSize = 10
    infoLbl.Parent = bb

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1, 0, 0, 12)
    distLbl.Position = UDim2.new(0, 0, 0, 58)
    distLbl.BackgroundTransparency = 1
    distLbl.Text = "..."
    distLbl.TextColor3 = Color3.fromRGB(150, 255, 150)
    distLbl.TextStrokeTransparency = 0
    distLbl.TextStrokeColor3 = Color3.new(0,0,0)
    distLbl.Font = Enum.Font.Code
    distLbl.TextSize = 10
    distLbl.Parent = bb

    return {
        attach = attach,
        highlight = hl,
        billboard = bb,
        distLabel = distLbl,
        hash = makeHash(data, pos),
        lastDist = -999,
        nameLabel = nameLbl,
        mutLabel = mutLbl,
        rateLabel = rateLbl,
        infoLabel = infoLbl,
    }
end

-- ══════════ DESTROY ══════════
local function destroyObj(obj)
    if not obj then return end
    pcall(function() if obj.attach then obj.attach:Destroy() end end)
    pcall(function() if obj.highlight then obj.highlight:Destroy() end end)
    pcall(function() if obj.billboard then obj.billboard:Destroy() end end)
end

-- ══════════ REFRESH ══════════
local function refresh()
    if not enabled or not EggState then return end

    -- Verify folder
    if not espFolder or not espFolder.Parent then
        parentGui = (gethui and gethui()) or P:WaitForChild("PlayerGui")
        espFolder = Instance.new("Folder")
        espFolder.Name = "ESP_Eggs"
        espFolder.Parent = parentGui
        espObjects = {}
    end

    local ok, fd = pcall(EggState.SyncFieldEggs)
    if not ok or type(fd) ~= "table" then return end
    local records = fd.Records
    if type(records) ~= "table" then return end

    local currentUids = {}

    for _, eggData in pairs(records) do
        local uid = eggData.Uid
        if uid and type(eggData) == "table" then
            local cf = eggData.BoundsCFrame
            if cf then
                local pos = cf.Position
                local atBase = dist(pos, HOME_POS) > 150

                -- Filter map
                local passFilter = atBase
                if filterMaps and #filterMaps > 0 then
                    passFilter = false
                    for _, mapName in ipairs(filterMaps) do
                        if eggData.AreaId == mapName then
                            passFilter = true
                            break
                        end
                    end
                end

                if passFilter then
                    currentUids[uid] = true
                    local obj = espObjects[uid]
                    local newHash = makeHash(eggData, pos)

                    if not obj then
                        -- Tạo mới
                        obj = createESP(uid, eggData, pos)
                        if obj then espObjects[uid] = obj end
                    elseif obj.hash ~= newHash then
                        -- ⭐ Hash đổi → egg mới cùng uid → destroy + tạo lại
                        destroyObj(obj)
                        espObjects[uid] = nil
                        obj = createESP(uid, eggData, pos)
                        if obj then espObjects[uid] = obj end
                    else
                        -- Update vị trí
                        if obj.attach and obj.attach.Parent then
                            pcall(function()
                                obj.attach.CFrame = CFrame.new(pos)
                            end)
                        else
                            -- Attach mất → tạo lại
                            destroyObj(obj)
                            espObjects[uid] = nil
                        end
                    end
                else
                    -- Không pass filter → xóa nếu có
                    local obj = espObjects[uid]
                    if obj then
                        destroyObj(obj)
                        espObjects[uid] = nil
                    end
                end
            end
        end
    end

    -- ⭐ Cleanup uid không còn trong SyncFieldEggs → egg đã bị steal/biến mất
    for uid, obj in pairs(espObjects) do
        if not currentUids[uid] then
            destroyObj(obj)
            espObjects[uid] = nil
        end
    end
end

-- ══════════ VERIFY (check egg thật có tồn tại) ══════════
-- Dùng để phát hiện egg đã bị steal nhưng SyncFieldEggs còn cache
local function verifyAll()
    if not enabled then return end

    for uid, obj in pairs(espObjects) do
        -- Nếu attach mất → clear
        if not obj.attach or not obj.attach.Parent then
            destroyObj(obj)
            espObjects[uid] = nil
        end
    end
end

-- ══════════ UPDATE DIST ══════════
local function updateDist()
    local hrp = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local myPos = hrp.Position

    for _, obj in pairs(espObjects) do
        if obj.attach and obj.attach.Parent then
            local d = dist(obj.attach.Position, myPos)
            if math.abs(d - obj.lastDist) > 1 then
                obj.distLabel.Text = string.format("%.0f studs", d)
                obj.lastDist = d
            end
        end
    end
end

-- ══════════ FORCE CLEAR ══════════
local function forceClear()
    for uid, obj in pairs(espObjects) do
        destroyObj(obj)
    end
    espObjects = {}
end

-- ══════════ API ══════════
function M.enable()
    if enabled then return end
    enabled = true

    if not parentGui or not parentGui.Parent then
        parentGui = (gethui and gethui()) or P:WaitForChild("PlayerGui")
    end
    if not espFolder or not espFolder.Parent then
        espFolder = Instance.new("Folder")
        espFolder.Name = "ESP_Eggs"
        espFolder.Parent = parentGui
    end

    incomeCache = {}
    refresh()
    print("[ESP] ✅ Enabled")
end

function M.disable()
    enabled = false
    forceClear()
    if espFolder then
        espFolder:Destroy()
        espFolder = nil
    end
    incomeCache = {}
    print("[ESP] ❌ Disabled")
end

function M.toggle()
    if enabled then M.disable() else M.enable() end
    return enabled
end

function M.isEnabled() return enabled end

function M.setMapFilter(mapList)
    filterMaps = mapList
    if enabled then
        forceClear()
        refresh()
    end
end

function M.setHome(pos) if pos then HOME_POS = pos end end
function M.getCount()
    local n = 0
    for _ in pairs(espObjects) do n = n + 1 end
    return n
end

-- ══════════ MAIN LOOPS ══════════
-- Refresh: quét egg mới
task.spawn(function()
    while true do
        task.wait(REFRESH_INTERVAL)
        if enabled then pcall(refresh) end
    end
end)

-- Update distance
task.spawn(function()
    while true do
        task.wait(DIST_INTERVAL)
        if enabled then pcall(updateDist) end
    end
end)

-- Verify: check attach còn sống
task.spawn(function()
    while true do
        task.wait(VERIFY_INTERVAL)
        if enabled then pcall(verifyAll) end
    end
end)

-- ⭐ Sau khi respawn → rebuild
P.CharacterAdded:Connect(function()
    if enabled then
        print("[ESP] 🔄 Respawn — rebuild")
        task.wait(1)
        forceClear()
        if not espFolder or not espFolder.Parent then
            parentGui = (gethui and gethui()) or P:WaitForChild("PlayerGui")
            espFolder = Instance.new("Folder")
            espFolder.Name = "ESP_Eggs"
            espFolder.Parent = parentGui
        end
        refresh()
    end
end)

-- ⭐ Hook chat để biết khi steal thành công → force refresh
task.spawn(function()
    pcall(function()
        local chatEvents = RS:WaitForChild("DefaultChatSystemChatEvents", 5)
        if not chatEvents then return end
        local onMsg = chatEvents:WaitForChild("OnMessageDoneFiltering", 5)
        if not onMsg then return end
        onMsg.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then return end
            local msg = string.lower(tostring(data.Message or ""))
            if msg:find("steal") or msg:find("carried")
                or msg:find("picked up") or msg:find("collected")
            then
                if enabled then
                    task.wait(0.3)
                    forceClear()
                    refresh()
                    print("[ESP] 🔄 Steal detected — rebuild")
                end
            end
        end)
    end)
end)

return M
