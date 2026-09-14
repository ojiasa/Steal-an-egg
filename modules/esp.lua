-- ═══════════════════════════════════════════════════════════════
-- ESP MODULE — hiển thị egg + income (không UI)
-- ═══════════════════════════════════════════════════════════════

local P  = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")

local M = {}

-- ══════════ STATE ══════════
local enabled     = false
local espObjects  = {}
local parentGui   = nil
local espFolder   = nil
local HOME_POS    = Vector3.new(465.2, 67.1, -364.1)
local filterMin   = 0
local showLobby   = false

local EggState, AssetEarnings

-- ══════════ LOAD MODULES ══════════
pcall(function()
    local ClientRS = RS:WaitForChild("Client", 5)
    if ClientRS then
        local mod = ClientRS:WaitForChild("EggState", 5)
        if mod then EggState = require(mod) end
    end
end)

pcall(function()
    local Shared = RS:WaitForChild("Shared", 5)
    local Util = Shared and Shared:WaitForChild("Util", 5)
    local mod = Util and Util:WaitForChild("AssetEarnings", 5)
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

local function getIncomeRate(eggData)
    if not AssetEarnings then return nil end
    local input = {
        Category = eggData.AssetCategory,
        Scale = eggData.AssetScale or 1,
        Mutations = eggData.Mutations or {},
    }
    local ok, r = pcall(AssetEarnings.LiveRatePerSecond, input)
    if ok and type(r) == "number" and r > 0 then return r end
    ok, r = pcall(AssetEarnings.RatePerSecond, input)
    if ok and type(r) == "number" and r > 0 then return r end
    return nil
end

-- ══════════ CREATE ESP ══════════
local function createESP(uid, data)
    local cf = data.BoundsCFrame
    if not cf then return nil end
    local pos = cf.Position

    local attach = Instance.new("Part")
    attach.Name = "ESP_" .. uid:sub(1, 8)
    attach.Anchored = true
    attach.CanCollide = false
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
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = attach
    hl.Parent = espFolder

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 190, 0, 86)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = attach
    bb.Parent = espFolder

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 16)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = prefix .. " " .. (data.AssetCategory or "Egg")
    nameLbl.TextColor3 = color
    nameLbl.TextStrokeTransparency = 0
    nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
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
    mutLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    mutLbl.Font = Enum.Font.GothamBold
    mutLbl.TextSize = 10
    mutLbl.Parent = bb

    local rate = getIncomeRate(data)
    local rateLbl = Instance.new("TextLabel")
    rateLbl.Size = UDim2.new(1, 0, 0, 15)
    rateLbl.Position = UDim2.new(0, 0, 0, 28)
    rateLbl.BackgroundTransparency = 1
    rateLbl.Text = rate and ("💵 $" .. formatMoney(rate) .. "/s") or "💵 ?"
    rateLbl.TextColor3 = rate and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(150, 150, 150)
    rateLbl.TextStrokeTransparency = 0
    rateLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    rateLbl.Font = Enum.Font.GothamBold
    rateLbl.TextSize = 13
    rateLbl.Parent = bb

    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, 0, 0, 12)
    infoLbl.Position = UDim2.new(0, 0, 0, 44)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Text = string.format("📍 %s | ⚖ %.2f",
        data.AreaId or "?", data.AssetScale or 0)
    infoLbl.TextColor3 = Color3.fromRGB(180, 220, 255)
    infoLbl.TextStrokeTransparency = 0
    infoLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
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
    distLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    distLbl.Font = Enum.Font.Code
    distLbl.TextSize = 10
    distLbl.Parent = bb

    return {
        attach = attach,
        highlight = hl,
        billboard = bb,
        distLabel = distLbl,
        rate = rate or 0,
    }
end

-- ══════════ REFRESH ══════════
local function refresh()
    if not enabled or not EggState then return end

    local ok, fd = pcall(EggState.SyncFieldEggs)
    if not ok or type(fd) ~= "table" then return end
    local records = fd.Records
    if type(records) ~= "table" then return end

    local currentUids = {}
    for _, eggData in pairs(records) do
        local uid = eggData.Uid
        if uid and type(eggData) == "table" then
            currentUids[uid] = true
            local cf = eggData.BoundsCFrame
            if cf then
                local pos = cf.Position
                local atBase = dist(pos, HOME_POS) > 150
                local passFilter = showLobby or atBase

                -- ⭐ Filter theo income
                if passFilter and filterMin > 0 then
                    local rate = getIncomeRate(eggData)
                    if not rate or rate < filterMin then passFilter = false end
                end

                if passFilter and not espObjects[uid] then
                    local obj = createESP(uid, eggData)
                    if obj then espObjects[uid] = obj end
                end
            end
        end
    end

    for uid, obj in pairs(espObjects) do
        if not currentUids[uid] then
            pcall(function() obj.attach:Destroy() end)
            pcall(function() obj.highlight:Destroy() end)
            pcall(function() obj.billboard:Destroy() end)
            espObjects[uid] = nil
        end
    end
end

local function updateDist()
    local hrp = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, obj in pairs(espObjects) do
        if obj.attach and obj.attach.Parent then
            local d = dist(obj.attach.Position, hrp.Position)
            obj.distLabel.Text = string.format("%.0f studs", d)
        end
    end
end

-- ══════════ API ══════════
function M.enable()
    if enabled then return end
    enabled = true

    if not parentGui then
        parentGui = (gethui and gethui()) or P:WaitForChild("PlayerGui")
    end
    if not espFolder then
        espFolder = Instance.new("Folder")
        espFolder.Name = "ESP_Eggs"
        espFolder.Parent = parentGui
    end

    refresh()
    print("[ESP] ✅ Enabled")
end

function M.disable()
    enabled = false
    for uid, obj in pairs(espObjects) do
        pcall(function() obj.attach:Destroy() end)
        pcall(function() obj.highlight:Destroy() end)
        pcall(function() obj.billboard:Destroy() end)
    end
    espObjects = {}
    if espFolder then espFolder:Destroy(); espFolder = nil end
    print("[ESP] ❌ Disabled")
end

function M.toggle()
    if enabled then M.disable() else M.enable() end
    return enabled
end

function M.isEnabled()
    return enabled
end

function M.setFilter(minIncome, showLobbyEggs)
    filterMin = minIncome or 0
    showLobby = showLobbyEggs or false
    if enabled then
        -- Force refresh
        M.disable()
        M.enable()
    end
end

function M.setHome(pos)
    if pos then HOME_POS = pos end
end

-- ══════════ AUTO LOOP ══════════
task.spawn(function()
    while true do
        task.wait(0.2)
        if enabled then
            refresh()
            updateDist()
        end
    end
end)

return M
