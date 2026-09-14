-- ═══════════════════════════════════════════════════════════════
-- MAIN.LUA v4 — UI BEAUTIFUL (Icon tròn + Menu Modern)
-- ═══════════════════════════════════════════════════════════════

local BASE_URL = "https://raw.githubusercontent.com/ojiasa/Steal-an-egg/main"
local FALLBACK = "https://cdn.jsdelivr.net/gh/ojiasa/Steal-an-egg@main"

local function fetch(path)
    local urls = { BASE_URL .. "/" .. path, FALLBACK .. "/" .. path }
    for _, url in ipairs(urls) do
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if ok and src and #src > 100 then
            local fn = loadstring(src, "=" .. path)
            if fn then
                local success, result = pcall(fn)
                if success then
                    print("[Main] ✅ " .. path)
                    return result
                end
            end
        end
    end
    warn("[Main] ❌ Failed: " .. path)
    return nil
end

print("[Main] 📦 Đang tải...")
local StealModule = fetch("modules/steal.lua")
local ESPModule   = fetch("modules/esp.lua")

-- ══════════ API ══════════
_G.StealEgg = {
    Steal = StealModule, ESP = ESPModule,
    Start = function() if StealModule then StealModule.start() end end,
    Stop  = function() if StealModule then StealModule.stop() end end,
    IsRunning = function() return StealModule and StealModule.isRunning() or false end,
    SetTarget = function(n,p) if StealModule then StealModule.setTarget(n,p) end end,
    SetHome   = function(p) if StealModule then StealModule.setHome(p) end end,
    SetForest = function(p) if StealModule then StealModule.setForest(p) end end,
    OnLog = function(cb) if StealModule then StealModule.onLog(cb) end end,
    ESP_Enable  = function() if ESPModule then ESPModule.enable() end end,
    ESP_Disable = function() if ESPModule then ESPModule.disable() end end,
    ESP_Toggle  = function() if ESPModule then return ESPModule.toggle() end end,
    ESP_IsEnabled = function() return ESPModule and ESPModule.isEnabled() or false end,
    Version = "4.0.0",
}
local API = _G.StealEgg
_G.MyScript = API

local P   = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")

-- ══════════ MAIN UI CONTAINER ══════════
local sg = Instance.new("ScreenGui")
sg.Name = "StealEggUI_v4"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999
sg.Parent = (gethui and gethui()) or P:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════════
-- ⭐ ICON TRÒN ĐẸP (Gradient + Glow Effect)
-- ═══════════════════════════════════════════════════════════════
local iconContainer = Instance.new("Frame")
iconContainer.Name = "IconContainer"
iconContainer.Size = UDim2.new(0, 55, 0, 55)
iconContainer.Position = UDim2.new(0, 15, 0, 150)
iconContainer.BackgroundTransparency = 1
iconContainer.Parent = sg

-- Icon chính - nền gradient
local icon = Instance.new("TextButton")
icon.Name = "MainIcon"
icon.Size = UDim2.new(1, 0, 1, 0)
icon.Position = UDim2.new(0, 0, 0, 0)
icon.BackgroundColor3 = Color3.fromRGB(45, 100, 180)
icon.BorderSizePixel = 0
icon.Text = ""
icon.AutoButtonColor = false
icon.Parent = iconContainer
Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)

-- Stroke (border sáng)
local iconStroke = Instance.new("UIStroke")
iconStroke.Color = Color3.fromRGB(100, 200, 255)
iconStroke.Thickness = 2.5
iconStroke.Parent = icon

-- Biểu tượng bên trong (thay bằng hình ảnh hoặc emoji)
local iconSymbol = Instance.new("TextLabel")
iconSymbol.Name = "IconSymbol"
iconSymbol.Size = UDim2.new(1, 0, 1, 0)
iconSymbol.BackgroundTransparency = 1
iconSymbol.Text = "⚙"  -- Có thể thay thành emoji khác: 🎮, 🔧, ⚡, etc
iconSymbol.TextColor3 = Color3.fromRGB(255, 255, 255)
iconSymbol.Font = Enum.Font.GothamBold
iconSymbol.TextSize = 28
iconSymbol.Parent = icon

-- Shadow effect (glow)
local iconShadow = Instance.new("Frame")
iconShadow.Name = "IconShadow"
iconShadow.Size = UDim2.new(1, 8, 1, 8)
iconShadow.Position = UDim2.new(0, -4, 0, -4)
iconShadow.BackgroundColor3 = Color3.fromRGB(45, 100, 180)
iconShadow.BackgroundTransparency = 0.6
iconShadow.BorderSizePixel = 0
iconShadow.Parent = iconContainer
iconShadow.ZIndex = icon.ZIndex - 1
Instance.new("UICorner", iconShadow).CornerRadius = UDim.new(1, 0)

-- ═══════════════════════════════════════════════════════════════
-- ⭐ PANEL UI CHÍNH (Modern Design)
-- ═══════════════════════════════════════════════════════════════
local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.new(0, 260, 0, 420)
panel.Position = UDim2.new(0.5, -130, 0.5, -210)
panel.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = sg

local pCorner = Instance.new("UICorner", panel)
pCorner.CornerRadius = UDim.new(0, 12)

local pStroke = Instance.new("UIStroke")
pStroke.Color = Color3.fromRGB(80, 150, 220)
pStroke.Thickness = 1.5
pStroke.Parent = panel

-- ⭐ HEADER (Title + Close)
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = Color3.fromRGB(20, 50, 100)
header.BorderSizePixel = 0
header.Parent = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local headerStroke = Instance.new("UIStroke")
headerStroke.Color = Color3.fromRGB(100, 180, 255)
headerStroke.Thickness = 1
headerStroke.Parent = header

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 8, 0, 0)
title.BackgroundTransparency = 1
title.Text = "⚙ STEAL EGG"
title.TextColor3 = Color3.fromRGB(200, 240, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0.5, -14)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.AutoButtonColor = true
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- ⭐ SCROLL CONTENT
local scrollContent = Instance.new("ScrollingFrame")
scrollContent.Name = "ScrollContent"
scrollContent.Size = UDim2.new(1, 0, 1, -50)
scrollContent.Position = UDim2.new(0, 0, 0, 40)
scrollContent.BackgroundTransparency = 1
scrollContent.BorderSizePixel = 0
scrollContent.ScrollBarThickness = 3
scrollContent.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollContent.Parent = panel

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 8)
contentPadding.PaddingLeft = UDim.new(0, 8)
contentPadding.PaddingRight = UDim.new(0, 8)
contentPadding.PaddingBottom = UDim.new(0, 8)
contentPadding.Parent = scrollContent

-- ⭐ LAYOUT
local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 6)
contentLayout.FillDirection = Enum.FillDirection.Vertical
contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
contentLayout.Parent = scrollContent

-- ═══════════════════════════════════════════════════════════════
-- ⭐ BUTTON STYLES (Function)
-- ═══════════════════════════════════════════════════════════════
local function createButton(name, text, color, onClick)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, -4, 0, 35)
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.AutoButtonColor = true
    btn.Parent = scrollContent
    
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 6)
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 150, 200)
    stroke.Thickness = 1
    stroke.Parent = btn
    
    if onClick then
        btn.MouseButton1Click:Connect(onClick)
    end
    
    return btn
end

-- ═══════════════════════════════════════════════════════════════
-- ⭐ MAIN BUTTONS
-- ═══════════════════════════════════════════════════════════════
local farmBtn = createButton("FarmBtn", "▶ FARM", Color3.fromRGB(60, 180, 90), function()
    if API.IsRunning() then
        API.Stop()
        farmBtn.Text = "▶ FARM"
        farmBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 90)
    else
        API.Start()
        farmBtn.Text = "⏹ STOP"
        farmBtn.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
    end
end)

local espBtn = createButton("ESPBtn", "👁 ESP OFF", Color3.fromRGB(60, 100, 200), function()
    local on = API.ESP_Toggle()
    if on then
        espBtn.Text = "👁 ESP ON"
        espBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
    else
        espBtn.Text = "👁 ESP OFF"
        espBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 200)
    end
end)

-- ⭐ LOCATION BUTTONS (Ngang)
local locationFrame = Instance.new("Frame")
locationFrame.Name = "LocationFrame"
locationFrame.Size = UDim2.new(1, -4, 0, 35)
locationFrame.BackgroundTransparency = 1
locationFrame.Parent = scrollContent

local locLayout = Instance.new("UIListLayout")
locLayout.FillDirection = Enum.FillDirection.Horizontal
locLayout.Padding = UDim.new(0, 6)
locLayout.Parent = locationFrame

local homeBtn = createButton("HomeBtn", "📍 HOME", Color3.fromRGB(200, 140, 50), function()
    local hrp = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
    if hrp then API.SetHome(hrp.Position); addLog("📍 Home set") end
end)
homeBtn.Parent = locationFrame
homeBtn.Size = UDim2.new(0.5, -3, 0, 35)

local forestBtn = createButton("ForestBtn", "🌲 FOREST", Color3.fromRGB(80, 160, 80), function()
    local hrp = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
    if hrp then API.SetForest(hrp.Position); addLog("🌲 Forest set") end
end)
forestBtn.Parent = locationFrame
forestBtn.Size = UDim2.new(0.5, -3, 0, 35)

-- ⭐ MAP SELECTOR HEADER
local mapHeader = Instance.new("TextLabel")
mapHeader.Name = "MapHeader"
mapHeader.Size = UDim2.new(1, -4, 0, 22)
mapHeader.BackgroundColor3 = Color3.fromRGB(50, 90, 160)
mapHeader.BorderSizePixel = 0
mapHeader.Text = "🎯 MAP: Snow"
mapHeader.TextColor3 = Color3.fromRGB(220, 240, 255)
mapHeader.Font = Enum.Font.GothamBold
mapHeader.TextSize = 11
mapHeader.Parent = scrollContent
Instance.new("UICorner", mapHeader).CornerRadius = UDim.new(0, 5)

-- ⭐ MAP LIST
local mapList = Instance.new("ScrollingFrame")
mapList.Name = "MapList"
mapList.Size = UDim2.new(1, -4, 0, 130)
mapList.BackgroundColor3 = Color3.fromRGB(5, 7, 12)
mapList.BorderSizePixel = 0
mapList.ScrollBarThickness = 2
mapList.CanvasSize = UDim2.new(0, 0, 0, 0)
mapList.AutomaticCanvasSize = Enum.AutomaticSize.Y
mapList.Parent = scrollContent
Instance.new("UICorner", mapList).CornerRadius = UDim.new(0, 5)

local mapLayout = Instance.new("UIListLayout")
mapLayout.Padding = UDim.new(0, 3)
mapLayout.Parent = mapList

local mapPad = Instance.new("UIPadding")
mapPad.PaddingTop = UDim.new(0, 3)
mapPad.PaddingLeft = UDim.new(0, 3)
mapPad.PaddingRight = UDim.new(0, 3)
mapPad.PaddingBottom = UDim.new(0, 3)
mapPad.Parent = mapList

-- ⭐ MAP DATA
local MAPS = {
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

local currentTarget = "Snow"
local mapButtons = {}

for _, mapData in ipairs(MAPS) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -6, 0, 22)
    b.BackgroundColor3 = (mapData.name == currentTarget)
        and Color3.fromRGB(100, 180, 70)
        or Color3.fromRGB(30, 35, 50)
    b.BorderSizePixel = 0
    b.Text = mapData.name
    b.TextColor3 = Color3.fromRGB(230, 235, 245)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.AutoButtonColor = true
    b.Parent = mapList
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)

    table.insert(mapButtons, { btn = b, data = mapData })

    b.MouseButton1Click:Connect(function()
        currentTarget = mapData.name
        API.SetTarget(mapData.name, mapData.pos)
        for _, item in ipairs(mapButtons) do
            if item.data.name == currentTarget then
                item.btn.BackgroundColor3 = Color3.fromRGB(100, 180, 70)
            else
                item.btn.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
            end
        end
        mapHeader.Text = "🎯 MAP: " .. currentTarget
        addLog("🎯 " .. currentTarget)
    end)
end

-- ⭐ LOG FRAME
local logLabel = Instance.new("TextLabel")
logLabel.Name = "LogLabel"
logLabel.Size = UDim2.new(1, -4, 0, 70)
logLabel.BackgroundColor3 = Color3.fromRGB(3, 4, 8)
logLabel.BorderSizePixel = 0
logLabel.Parent = scrollContent
logLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 8
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.TextWrapped = true
Instance.new("UICorner", logLabel).CornerRadius = UDim.new(0, 5)

local logPad = Instance.new("UIPadding")
logPad.PaddingTop = UDim.new(0, 4)
logPad.PaddingLeft = UDim.new(0, 4)
logPad.PaddingRight = UDim.new(0, 4)
logPad.Parent = logLabel

local logLines = {}
function addLog(msg)
    table.insert(logLines, tostring(msg))
    if #logLines > 20 then table.remove(logLines, 1) end
    logLabel.Text = table.concat(logLines, "\n")
end

-- ═══════════════════════════════════════════════════════════════
-- ⭐ DRAG FUNCTIONALITY
-- ═══════════════════════════════════════════════════════════════

-- Drag Icon
local dragging, dragStart, startPos
icon.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = i.Position
        startPos = iconContainer.Position
    end
end)

icon.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        iconContainer.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

-- Drag Panel
local pdrag, pds, psp
header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
        pdrag = true
        pds = i.Position
        psp = panel.Position
    end
end)

header.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
        pdrag = false
    end
end)

UIS.InputChanged:Connect(function(i)
    if pdrag and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - pds
        panel.Position = UDim2.new(psp.X.Scale, psp.X.Offset + d.X,
            psp.Y.Scale, psp.Y.Offset + d.Y)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ⭐ EVENT LISTENERS
-- ═══════════════════════════════════════════════════════════════
icon.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
end)

closeBtn.MouseButton1Click:Connect(function()
    panel.Visible = false
end)

API.OnLog(function(msg)
    addLog(msg)
end)

-- ═══════════════════════════════════════════════════════════════
-- ⭐ STARTUP
-- ═══════════════════════════════════════════════════════════════
addLog("✅ UI Loaded v4")
addLog("Ready to farm!")

print("[Main] ✅ UI Ready v4!")

