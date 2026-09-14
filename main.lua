-- ═══════════════════════════════════════════════════════════════
-- MAIN.LUA v3 — UI GỌN cho mobile
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
    Version = "1.0.0",
}
local API = _G.StealEgg
_G.MyScript = API

local P   = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")

-- ══════════ UI GỌN ══════════
local sg = Instance.new("ScreenGui")
sg.Name = "StealEggUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999
sg.Parent = (gethui and gethui()) or P:WaitForChild("PlayerGui")

-- Icon
local icon = Instance.new("TextButton")
icon.Size = UDim2.new(0, 45, 0, 45)
icon.Position = UDim2.new(0, 15, 0, 150)
icon.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
icon.Text = "🌀"
icon.TextSize = 20
icon.Font = Enum.Font.GothamBold
icon.TextColor3 = Color3.fromRGB(120, 200, 255)
icon.AutoButtonColor = false
icon.Parent = sg
Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
local stk = Instance.new("UIStroke")
stk.Color = Color3.fromRGB(120, 200, 255)
stk.Thickness = 2
stk.Parent = icon

-- ⭐ PANEL GỌN — 240 x 340
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 240, 0, 340)
panel.Position = UDim2.new(0.5, -120, 0.5, -170)
panel.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local pstk = Instance.new("UIStroke")
pstk.Color = Color3.fromRGB(120, 200, 255)
pstk.Thickness = 1.5
pstk.Parent = panel

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.BackgroundColor3 = Color3.fromRGB(22, 24, 33)
title.Text = "🌀 STEAL EGG"
title.TextColor3 = Color3.fromRGB(180, 230, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 11
title.Parent = panel
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 22, 0, 18)
closeBtn.Position = UDim2.new(1, -25, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 10
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

-- ⭐ FARM btn — nhỏ gọn
local farmBtn = Instance.new("TextButton")
farmBtn.Size = UDim2.new(1, -14, 0, 30)
farmBtn.Position = UDim2.new(0, 7, 0, 30)
farmBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
farmBtn.Text = "▶ FARM"
farmBtn.TextColor3 = Color3.new(0, 0, 0)
farmBtn.Font = Enum.Font.GothamBold
farmBtn.TextSize = 11
farmBtn.Parent = panel
Instance.new("UICorner", farmBtn).CornerRadius = UDim.new(0, 5)

-- ⭐ ESP btn
local espBtn = Instance.new("TextButton")
espBtn.Size = UDim2.new(1, -14, 0, 30)
espBtn.Position = UDim2.new(0, 7, 0, 63)
espBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 180)
espBtn.Text = "👁 ESP"
espBtn.TextColor3 = Color3.new(1, 1, 1)
espBtn.Font = Enum.Font.GothamBold
espBtn.TextSize = 11
espBtn.Parent = panel
Instance.new("UICorner", espBtn).CornerRadius = UDim.new(0, 5)

-- ⭐ HOME / FOREST — nằm ngang
local homeBtn = Instance.new("TextButton")
homeBtn.Size = UDim2.new(0.5, -8, 0, 26)
homeBtn.Position = UDim2.new(0, 7, 0, 96)
homeBtn.BackgroundColor3 = Color3.fromRGB(200, 130, 40)
homeBtn.Text = "📍 HOME"
homeBtn.TextColor3 = Color3.new(0, 0, 0)
homeBtn.Font = Enum.Font.GothamBold
homeBtn.TextSize = 9
homeBtn.Parent = panel
Instance.new("UICorner", homeBtn).CornerRadius = UDim.new(0, 5)

local forestBtn = Instance.new("TextButton")
forestBtn.Size = UDim2.new(0.5, -8, 0, 26)
forestBtn.Position = UDim2.new(0.5, 1, 0, 96)
forestBtn.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
forestBtn.Text = "📍 FOREST"
forestBtn.TextColor3 = Color3.new(0, 0, 0)
forestBtn.Font = Enum.Font.GothamBold
forestBtn.TextSize = 9
forestBtn.Parent = panel
Instance.new("UICorner", forestBtn).CornerRadius = UDim.new(0, 5)

-- ⭐ Label MAP
local mapHeader = Instance.new("TextLabel")
mapHeader.Size = UDim2.new(1, -14, 0, 20)
mapHeader.Position = UDim2.new(0, 7, 0, 125)
mapHeader.BackgroundColor3 = Color3.fromRGB(80, 60, 160)
mapHeader.Text = "🎯 MAP: Snow"
mapHeader.TextColor3 = Color3.new(1, 1, 1)
mapHeader.Font = Enum.Font.GothamBold
mapHeader.TextSize = 10
mapHeader.Parent = panel
Instance.new("UICorner", mapHeader).CornerRadius = UDim.new(0, 5)

-- ⭐ MAP LIST — NHỎ, scroll
local mapList = Instance.new("ScrollingFrame")
mapList.Size = UDim2.new(1, -14, 0, 110)
mapList.Position = UDim2.new(0, 7, 0, 147)
mapList.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
mapList.BorderSizePixel = 0
mapList.ScrollBarThickness = 3
mapList.CanvasSize = UDim2.new(0, 0, 0, 0)
mapList.AutomaticCanvasSize = Enum.AutomaticSize.Y
mapList.Parent = panel
Instance.new("UICorner", mapList).CornerRadius = UDim.new(0, 4)

local mapLayout = Instance.new("UIListLayout")
mapLayout.Padding = UDim.new(0, 2)
mapLayout.Parent = mapList

local mapPad = Instance.new("UIPadding")
mapPad.PaddingTop = UDim.new(0, 4)
mapPad.PaddingLeft = UDim.new(0, 4)
mapPad.PaddingRight = UDim.new(0, 4)
mapPad.PaddingBottom = UDim.new(0, 4)
mapPad.Parent = mapList

-- ⭐ Log — ngắn
local logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, -14, 0, 60)
logFrame.Position = UDim2.new(0, 7, 0, 260)
logFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 3
logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logFrame.Parent = panel
Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0, 4)

local logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.new(1, -6, 0, 0)
logLabel.Position = UDim2.new(0, 3, 0, 3)
logLabel.BackgroundTransparency = 1
logLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 8
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.TextWrapped = true
logLabel.AutomaticSize = Enum.AutomaticSize.Y
logLabel.Parent = logFrame

local logLines = {}
local function addLog(msg)
    table.insert(logLines, tostring(msg))
    if #logLines > 30 then table.remove(logLines, 1) end
    logLabel.Text = table.concat(logLines, "\n")
    logFrame.CanvasPosition = Vector2.new(0, 999999)
end

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
    b.Size = UDim2.new(1, -8, 0, 20)
    b.BackgroundColor3 = (mapData.name == currentTarget)
        and Color3.fromRGB(100, 70, 20)
        or Color3.fromRGB(30, 33, 45)
    b.Text = mapData.name
    b.TextColor3 = Color3.fromRGB(230, 235, 245)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 9
    b.Parent = mapList
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)

    table.insert(mapButtons, { btn = b, data = mapData })

    b.MouseButton1Click:Connect(function()
        currentTarget = mapData.name
        API.SetTarget(mapData.name, mapData.pos)
        for _, item in ipairs(mapButtons) do
            if item.data.name == currentTarget then
                item.btn.BackgroundColor3 = Color3.fromRGB(100, 70, 20)
            else
                item.btn.BackgroundColor3 = Color3.fromRGB(30, 33, 45)
            end
        end
        mapHeader.Text = "🎯 MAP: " .. currentTarget
        addLog("🎯 " .. currentTarget)
    end)
end

-- ══════════ DRAG ICON ══════════
local dragging, dragStart, startPos
icon.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = i.Position; startPos = icon.Position
    end
end)
icon.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        icon.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

-- ══════════ DRAG PANEL ══════════
local pdrag, pds, psp
title.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
        pdrag, pds, psp = true, i.Position, panel.Position
    end
end)
title.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then pdrag = false end
end)
UIS.InputChanged:Connect(function(i)
    if pdrag and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - pds
        panel.Position = UDim2.new(psp.X.Scale, psp.X.Offset + d.X,
            psp.Y.Scale, psp.Y.Offset + d.Y)
    end
end)

-- ══════════ EVENTS ══════════
icon.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible end)
closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

farmBtn.MouseButton1Click:Connect(function()
    if API.IsRunning() then
        API.Stop()
        farmBtn.Text = "▶ FARM"
        farmBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
    else
        API.Start()
        farmBtn.Text = "⏹ STOP"
        farmBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    end
end)

espBtn.MouseButton1Click:Connect(function()
    local on = API.ESP_Toggle()
    if on then
        espBtn.Text = "👁 ESP ON"
        espBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    else
        espBtn.Text = "👁 ESP"
        espBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 180)
    end
end)

homeBtn.MouseButton1Click:Connect(function()
    local hrp = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
    if hrp then API.SetHome(hrp.Position); addLog("📍 Home set") end
end)

forestBtn.MouseButton1Click:Connect(function()
    local hrp = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
    if hrp then API.SetForest(hrp.Position); addLog("📍 Forest set") end
end)

API.OnLog(function(msg) addLog(msg) end)

addLog("✅ Ready")

print("[Main] ✅ Ready!")
