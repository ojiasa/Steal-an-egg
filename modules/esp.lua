-- ═══════════════════════════════════════════════════════════════
-- ESP MODULE v11.6 — Board size theo BoundsSize (egg >=10 mới to)
-- ═══════════════════════════════════════════════════════════════

local P  = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local W  = workspace
local UIS = game:GetService("UserInputService")

local M = {}

local enabled    = false
local espObjects = {}
local parentGui, espFolder
local HOME_POS   = Vector3.new(465.2, 67.1, -364.1)
local filterMaps = nil
local AssetEarnings
local EggState

local REFRESH_INTERVAL = 0.15
local DIST_INTERVAL    = 0.15

local IS_PC     = UIS.KeyboardEnabled and not UIS.TouchEnabled
local IS_MOBILE = UIS.TouchEnabled
local PLATFORM  = IS_PC and "PC" or (IS_MOBILE and "Mobile" or "Unknown")

local function getSafeGui()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then
            local testOk = pcall(function()
                local f = Instance.new("Folder")
                f.Parent = hui
                f:Destroy()
            end)
            if testOk then return hui end
        end
    end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then
        local testOk = pcall(function()
            local f = Instance.new("Folder")
            f.Parent = cg
            f:Destroy()
        end)
        if testOk then return cg end
    end
    return P:WaitForChild("PlayerGui")
end

pcall(function()
    local c = RS:WaitForChild("Client", 5)
    if c then
        local mod = c:WaitForChild("EggState", 5)
        if mod then
            local ok, m = pcall(require, mod)
            if ok then EggState = m end
        end
    end
end)

pcall(function()
    local s = RS:WaitForChild("Shared", 5)
    local u = s and s:FindFirstChild("Util", 5)
    local mod = u and u:FindFirstChild("AssetEarnings", 5)
    if mod then
        local ok, m = pcall(require, mod)
        if ok then AssetEarnings = m end
    end
end)

print(string.format("[ESP] Platform: %s | EggState: %s | AssetEarnings: %s",
    PLATFORM,
    tostring(EggState ~= nil),
    tostring(AssetEarnings ~= nil)))

local function dist(a, b) return (a - b).Magnitude end

local function formatMoney(n)
    if not n then return "?" end
    if n >= 1e12 then return string.format("%.2fT", n/1e12) end
    if n >= 1e9  then return string.format("%.2fB", n/1e9) end
    if n >= 1e6  then return string.format("%.2fM", n/1e6) end
    if n >= 1e3  then return string.format("%.2fK", n/1e3) end
    return string.format("%.0f", n)
end

local function getPrefixAndColor(mutation)
    if mutation == "Golden" then return "🌟", Color3.fromRGB(255, 200, 50)
    elseif mutation == "Silver" then return "⭐", Color3.fromRGB(200, 200, 220)
    elseif mutation == "Rainbow" then return "🌈", Color3.fromRGB(255, 100, 200) end
    return "🥚", Color3.fromRGB(255, 220, 80)
end

local function makeHash(eggData, pos)
    local bs = eggData.BoundsSize
    local bsHash = bs and string.format("%.1f_%.1f_%.1f", bs.X, bs.Y, bs.Z) or "?"
    return string.format("%s|%s|%.2f|%.2f|%.2f|%.4f|%s",
        tostring(eggData.AssetCategory or ""),
        tostring(eggData.BaseMutation or ""),
        pos.X, pos.Y, pos.Z,
        eggData.AssetScale or 0,
        bsHash)
end

local incomeCache = {}

local function getIncomeRate(category, scale, mutations)
    if not AssetEarnings or not category then return nil end
    local key = category .. "|" .. tostring(scale or 1)
    if incomeCache[key] ~= nil then return incomeCache[key] end
    local input = { Category = category, Scale = scale or 1, Mutations = mutations or {} }
    local r
    local ok, val = pcall(AssetEarnings.LiveRatePerSecond, input)
    if ok and type(val) == "number" and val > 0 then r = val end
    if not r then
        ok, val = pcall(AssetEarnings.RatePerSecond, input)
        if ok and type(val) == "number" and val > 0 then r = val end
    end
    incomeCache[key] = r or false
    return r
end

local function readAllEggs()
    local result = {}
    if not EggState then return result end
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then
        return result
    end
    for _, eggData in pairs(fd.Records) do
        if eggData.Uid and eggData.BoundsCFrame then
            result[eggData.Uid] = eggData
        end
    end
    return result
end

-- ⭐⭐⭐ v11.6: Board bằng nhau, chỉ egg >=10 mới to dần
local function getScaleStyle(eggScale, boundsSize)
    eggScale = eggScale or 1

    local avgSize = 3.5
    if boundsSize then
        avgSize = (boundsSize.X + boundsSize.Y + boundsSize.Z) / 3
    else
        avgSize = 3.5 * eggScale
    end

    -- ⭐ Egg <10 → board bằng nhau (1.0)
    -- ⭐ Egg >=10 → tăng 0.2 mỗi đơn vị (cap 4.0)
    local boardScale = 1.0
    local offsetY = 3

    if avgSize >= 10.0 then
        local extra = avgSize - 10.0
        boardScale = math.min(1.0 + extra * 0.2, 4.0)
        offsetY = math.min(3 + extra * 0.8, 20)
    end

    local scaleColor = Color3.fromRGB(180, 180, 180)
    local scaleIcon = "⚖"
    if eggScale >= 3.5 then
        scaleColor = Color3.fromRGB(255, 80, 80)
        scaleIcon = "🔥"
    elseif eggScale >= 2.5 then
        scaleColor = Color3.fromRGB(255, 150, 50)
        scaleIcon = "⭐"
    elseif eggScale >= 1.5 then
        scaleColor = Color3.fromRGB(100, 255, 100)
    elseif eggScale >= 1.0 then
        scaleColor = Color3.fromRGB(255, 220, 100)
    end

    return boardScale, offsetY, scaleColor, scaleIcon, avgSize
end

local function createESP(uid, pos, info, hash)
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

    local prefix, color = getPrefixAndColor(info.mutation)
    local eggScale = info.scale or 1
    local boundsSize = info.boundsSize

    local boardScale, offsetY, scaleColor, scaleIcon, avgSize = getScaleStyle(eggScale, boundsSize)

    local baseW = 115
    local baseH = 55
    local boardW = math.floor(baseW * boardScale)
    local boardH = math.floor(baseH * boardScale)

    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = attach
    hl.Parent = espFolder

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, boardW, 0, boardH)
    bb.StudsOffset = Vector3.new(0, offsetY, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = math.huge
    bb.Adornee = attach
    bb.Parent = espFolder

    local bg = Instance.new("Frame", bb)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.35
    bg.BorderSizePixel = 0
    bg.ZIndex = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 5)

    local stroke = Instance.new("UIStroke", bg)
    stroke.Color = scaleColor
    stroke.Thickness = math.min(2.5, 1 + (boardScale - 1) * 0.5)
    stroke.Transparency = 0.2

    local pad = Instance.new("UIPadding", bg)
    pad.PaddingTop = UDim.new(0, 3)
    pad.PaddingBottom = UDim.new(0, 3)
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 4)

    local layout = Instance.new("UIListLayout", bg)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 1)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, math.floor(13 * boardScale))
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = prefix .. " " .. (info.name or "Egg")
    nameLbl.TextColor3 = color
    nameLbl.TextStrokeTransparency = 0.3
    nameLbl.TextStrokeColor3 = color
    nameLbl.Font = Enum.Font.GothamBlack
    nameLbl.TextSize = math.floor(11 * boardScale)
    nameLbl.LayoutOrder = 1
    nameLbl.ZIndex = 1
    nameLbl.Parent = bg

    local mutLbl = Instance.new("TextLabel")
    mutLbl.Size = UDim2.new(1, 0, 0, math.floor(10 * boardScale))
    mutLbl.BackgroundTransparency = 1
    mutLbl.Text = info.mutation and ("✨ " .. info.mutation) or ""
    mutLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
    mutLbl.TextStrokeTransparency = 0.3
    mutLbl.TextStrokeColor3 = Color3.fromRGB(255, 200, 100)
    mutLbl.Font = Enum.Font.GothamBlack
    mutLbl.TextSize = math.floor(9 * boardScale)
    mutLbl.LayoutOrder = 2
    mutLbl.ZIndex = 1
    mutLbl.Parent = bg

    local rateLbl = Instance.new("TextLabel")
    rateLbl.Size = UDim2.new(1, 0, 0, math.floor(13 * boardScale))
    rateLbl.BackgroundTransparency = 1
    rateLbl.Text = info.rate and ("💵 $" .. formatMoney(info.rate) .. "/s") or "💵 ?"
    rateLbl.TextColor3 = info.rate and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(150, 150, 150)
    rateLbl.TextStrokeTransparency = 0.3
    rateLbl.TextStrokeColor3 = rateLbl.TextColor3
    rateLbl.Font = Enum.Font.GothamBlack
    rateLbl.TextSize = math.floor(11 * boardScale)
    rateLbl.LayoutOrder = 3
    rateLbl.ZIndex = 1
    rateLbl.Parent = bg

    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, 0, 0, math.floor(11 * boardScale))
    infoLbl.BackgroundTransparency = 1
    infoLbl.Text = string.format("📍 %s | %s %.2f", info.area or "?", scaleIcon, eggScale)
    infoLbl.TextColor3 = scaleColor
    infoLbl.TextStrokeTransparency = 0.3
    infoLbl.TextStrokeColor3 = scaleColor
    infoLbl.Font = Enum.Font.GothamBlack
    infoLbl.TextSize = math.floor(10 * boardScale)
    infoLbl.LayoutOrder = 4
    infoLbl.ZIndex = 1
    infoLbl.Parent = bg

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1, 0, 0, math.floor(10 * boardScale))
    distLbl.BackgroundTransparency = 1
    distLbl.Text = "..."
    distLbl.TextColor3 = Color3.fromRGB(150, 255, 150)
    distLbl.TextStrokeTransparency = 0.3
    distLbl.TextStrokeColor3 = Color3.fromRGB(150, 255, 150)
    distLbl.Font = Enum.Font.Code
    distLbl.TextSize = math.floor(9 * boardScale)
    distLbl.LayoutOrder = 5
    distLbl.ZIndex = 1
    distLbl.Parent = bg

    return {
        attach = attach,
        highlight = hl,
        billboard = bb,
        bg = bg,
        stroke = stroke,
        distLabel = distLbl,
        rateLabel = rateLbl,
        nameLabel = nameLbl,
        mutLabel = mutLbl,
        infoLabel = infoLbl,
        lastDist = -999,
        hash = hash,
        lastRate = info.rate,
        lastName = info.name,
        lastScale = eggScale,
        lastAvgSize = avgSize,
    }
end

local function destroyObj(obj)
    if not obj then return end
    pcall(function() if obj.attach then obj.attach:Destroy() end end)
    pcall(function() if obj.highlight then obj.highlight:Destroy() end end)
    pcall(function() if obj.billboard then obj.billboard:Destroy() end end)
end

local function refresh()
    if not enabled then return end

    if not espFolder or not espFolder.Parent then
        parentGui = getSafeGui()
        espFolder = Instance.new("Folder")
        espFolder.Name = "ESP_Eggs"
        espFolder.Parent = parentGui
        espObjects = {}
    end

    local allEggs = readAllEggs()
    local currentUids = {}

    for uid, eggData in pairs(allEggs) do
        local pos = eggData.BoundsCFrame.Position

        local passFilter = true
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

            local info = {
                name = eggData.AssetCategory or "Egg",
                mutation = eggData.BaseMutation,
                area = eggData.AreaId,
                scale = eggData.AssetScale,
                boundsSize = eggData.BoundsSize,
                rate = getIncomeRate(eggData.AssetCategory, eggData.AssetScale, eggData.Mutations),
            }
            local newHash = makeHash(eggData, pos)

            local obj = espObjects[uid]

            if not obj then
                obj = createESP(uid, pos, info, newHash)
                if obj then espObjects[uid] = obj end
            elseif obj.hash ~= newHash then
                destroyObj(obj)
                espObjects[uid] = nil
                obj = createESP(uid, pos, info, newHash)
                if obj then espObjects[uid] = obj end
            else
                if obj.attach and obj.attach.Parent then
                    pcall(function()
                        obj.attach.CFrame = CFrame.new(pos)
                    end)
                    if info.rate and obj.lastRate ~= info.rate then
                        obj.lastRate = info.rate
                        pcall(function()
                            obj.rateLabel.Text = "💵 $" .. formatMoney(info.rate) .. "/s"
                            obj.rateLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                            obj.rateLabel.TextStrokeColor3 = Color3.fromRGB(100, 255, 100)
                        end)
                    end
                else
                    destroyObj(obj)
                    espObjects[uid] = nil
                end
            end
        else
            if espObjects[uid] then
                destroyObj(espObjects[uid])
                espObjects[uid] = nil
            end
        end
    end

    for uid, obj in pairs(espObjects) do
        if not currentUids[uid] then
            destroyObj(obj)
            espObjects[uid] = nil
        end
    end
end

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

local function forceClear()
    for uid, obj in pairs(espObjects) do
        destroyObj(obj)
    end
    espObjects = {}
end

function M.enable()
    if enabled then return end
    print("[ESP] ═══ ENABLE DEBUG ═══")
    print("[ESP] Platform: " .. PLATFORM)
    print("[ESP] EggState: " .. tostring(EggState ~= nil))
    print("[ESP] AssetEarnings: " .. tostring(AssetEarnings ~= nil))

    local testEggs = readAllEggs()
    local count = 0
    for _ in pairs(testEggs) do count = count + 1 end
    print("[ESP] Số egg đọc được: " .. count)

    enabled = true
    parentGui = getSafeGui()
    if not espFolder or not espFolder.Parent then
        espFolder = Instance.new("Folder")
        espFolder.Name = "ESP_Eggs"
        espFolder.Parent = parentGui
    end
    incomeCache = {}
    refresh()
    print("[ESP] ✅ Enabled — count: " .. M.getCount())
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

function M.getPlatform() return PLATFORM end

task.spawn(function()
    while true do
        task.wait(REFRESH_INTERVAL)
        if enabled then pcall(refresh) end
    end
end)

task.spawn(function()
    while true do
        task.wait(DIST_INTERVAL)
        if enabled then pcall(updateDist) end
    end
end)

P.CharacterAdded:Connect(function()
    if enabled then
        task.wait(1)
        forceClear()
        if not espFolder or not espFolder.Parent then
            parentGui = getSafeGui()
            espFolder = Instance.new("Folder")
            espFolder.Name = "ESP_Eggs"
            espFolder.Parent = parentGui
        end
        refresh()
    end
end)

return M
