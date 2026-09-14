-- ═══════════════════════════════════════════════════════════════
-- MAIN.LUA v4 — UI style Foxname (tab + switch + sidebar)
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

-- ══════════ COLOR ══════════
local COLORS = {
    bg         = Color3.fromRGB(20, 20, 30),
    bg2        = Color3.fromRGB(28, 28, 40),
    bg3        = Color3.fromRGB(35, 35, 50),
    accent     = Color3.fromRGB(120, 140, 255),
    accent2    = Color3.fromRGB(150, 100, 255),
    text       = Color3.fromRGB(220, 220, 240),
    textDim    = Color3.fromRGB(150, 150, 180),
    green      = Color3.fromRGB(80, 220, 130),
    red        = Color3.fromRGB(220, 80, 80),
}

-- ══════════ UI ROOT ══════════
local sg = Instance.new("ScreenGui")
sg.Name = "StealEggUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999
sg.Parent = (gethui and gethui()) or P:WaitForChild("PlayerGui")

-- ⭐ ICON TRÒN
local icon = Instance.new("TextButton")
icon.Size = UDim2.new(0, 46, 0, 46)
icon.Position = UDim2.new(0, 15, 0, 150)
icon.BackgroundColor3 = COLORS.bg
icon.Text = "🌀"
icon.TextSize = 20
icon.Font = Enum.Font.GothamBold
icon.TextColor3 = COLORS.accent
icon.AutoButtonColor = false
icon.Parent = sg
Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
local stk = Instance.new("UIStroke")
stk.Color = COLORS.accent
stk.Thickness = 1.5
stk.Parent = icon

-- ⭐ PANEL
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 260, 0, 380)
panel.Position = UDim2.new(0.5, -130, 0.5, -190)
panel.BackgroundColor3 = COLORS.bg
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local pstk = Instance.new("UIStroke")
pstk.Color = COLORS.accent
pstk.Thickness = 1
pstk.Transparency = 0.5
pstk.Parent = panel

-- ⭐ HEADER (drag)
local header = Instance.new("TextButton")
header.Size = UDim2.new(1, 0, 0, 30)
header.BackgroundColor3 = COLORS.bg2
header.Text = "🌀  STEAL EGG"
header.TextColor3 = COLORS.text
header.Font = Enum.Font.GothamBold
header.TextSize = 11
header.TextXAlignment = Enum.TextXAlignment.Left
header.AutoButtonColor = false
header.Parent = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local headerPad = Instance.new("UIPadding")
headerPad.PaddingLeft = UDim.new(0, 12)
headerPad.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.Position = UDim2.new(1, -26, 0, 4)
closeBtn.BackgroundColor3 = COLORS.bg3
closeBtn.Text = "✕"
closeBtn.TextColor3 = COLORS.textDim
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 11
closeBtn.AutoButtonColor = false
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)

-- ⭐ SIDEBAR (tabs)
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 60, 1, -30)
sidebar.Position = UDim2.new(0, 0, 0, 30)
sidebar.BackgroundColor3 = COLORS.bg2
sidebar.BorderSizePixel = 0
sidebar.Parent = panel

local sidebarPad = Instance.new("UIPadding")
sidebarPad.PaddingTop = UDim.new(0, 8)
sidebarPad.PaddingBottom = UDim.new(0, 8)
sidebarPad.Parent = sidebar

local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 4)
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideLayout.Parent = sidebar

-- ⭐ CONTENT AREA
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -60, 1, -30)
content.Position = UDim2.new(0, 60, 0, 30)
content.BackgroundColor3 = COLORS.bg
content.BorderSizePixel = 0
content.Parent = panel

local contentPad = Instance.new("UIPadding")
contentPad.PaddingTop = UDim.new(0, 10)
contentPad.PaddingLeft = UDim.new(0, 12)
contentPad.PaddingRight = UDim.new(0, 12)
contentPad.PaddingBottom = UDim.new(0, 10)
contentPad.Parent = content

-- ══════════ TABS DATA ══════════
local tabs = {
    { id = "main",   icon = "🏠", name = "Main" },
    { id = "esp",    icon = "👁", name = "ESP" },
    { id = "map",    icon = "🎯", name = "Map" },
    { id = "log",    icon = "📋", name = "Log" },
}

local activeTab = "main"

-- ⭐ Content pages
local pages = {}

-- ══════════ TAB BUTTON ══════════
local tabButtons = {}

local function setActiveTab(id)
    activeTab = id
    for _, tab in ipairs(tabs) do
        local btn = tabButtons[tab.id]
        if btn then
            if tab.id == id then
                btn.BackgroundColor3 = COLORS.accent
                btn.TextColor3 = Color3.new(1, 1, 1)
            else
                btn.BackgroundColor3 = COLORS.bg3
                btn.TextColor3 = COLORS.textDim
            end
        end
        -- Hiện/ẩn page
        if pages[tab.id] then
            pages[tab.id].Visible = (tab.id == id)
        end
    end
end

for _, tab in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 44, 0, 44)
    btn.BackgroundColor3 = COLORS.bg3
    btn.Text = tab.icon
    btn.TextColor3 = COLORS.textDim
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 18
    btn.AutoButtonColor = false
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    table.insert(tabButtons, { btn = btn, tab = tab })
    tabButtons[tab.id] = btn

    btn.MouseButton1Click:Connect(function()
        setActiveTab(tab.id)
    end)
end

-- ══════════ PAGE: MAIN ══════════
local pageMain = Instance.new("Frame")
pageMain.Size = UDim2.new(1, 0, 1, 0)
pageMain.BackgroundTransparency = 1
pageMain.Parent = content
pages.main = pageMain

local function makeSection(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = COLORS.textDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 9
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    return lbl
end

-- Farm button
makeSection(pageMain, "AUTO FARM")

local farmBtn = Instance.new("TextButton")
farmBtn.Size = UDim2.new(1, 0, 0, 34)
farmBtn.Position = UDim2.new(0, 0, 0, 22)
farmBtn.BackgroundColor3 = COLORS.green
farmBtn.Text = "▶  BẮT ĐẦU FARM"
farmBtn.TextColor3 = Color3.new(0, 0, 0)
farmBtn.Font = Enum.Font.GothamBold
farmBtn.TextSize = 11
farmBtn.AutoButtonColor = false
farmBtn.Parent = pageMain
Instance.new("UICorner", farmBtn).CornerRadius = UDim.new(0, 6)

-- Set buttons
makeSection(pageMain, "VỊ TRÍ").Position = UDim2.new(0, 0, 0, 65)

local homeBtn = Instance.new("TextButton")
homeBtn.Size = UDim2.new(0.5, -3, 0, 30)
homeBtn.Position = UDim2.new(0, 0, 0, 87)
homeBtn.BackgroundColor3 = COLORS.bg3
homeBtn.Text = "📍 HOME"
homeBtn.TextColor3 = COLORS.text
homeBtn.Font = Enum.Font.GothamBold
homeBtn.TextSize = 10
homeBtn.AutoButtonColor = false
homeBtn.Parent = pageMain
Instance.new("UICorner", homeBtn).CornerRadius = UDim.new(0, 6)

local forestBtn = Instance.new("TextButton")
forestBtn.Size = UDim2.new(0.5, -3, 0, 30)
forestBtn.Position = UDim2.new(0.5, 3, 0, 87)
forestBtn.BackgroundColor3 = COLORS.bg3
forestBtn.Text = "📍 FOREST"
forestBtn.TextColor3 = COLORS.text
forestBtn.Font = Enum.Font.GothamBold
forestBtn.TextSize = 10
forestBtn.AutoButtonColor = false
forestBtn.Parent = pageMain
Instance.new("UICorner", forestBtn).CornerRadius = UDim.new(0, 6)

-- ══════════ PAGE: ESP ══════════
local pageESP = Instance.new("Frame")
pageESP.Size = UDim2.new(1, 0, 1, 0)
pageESP.BackgroundTransparency = 1
pageESP.Visible = false
pageESP.Parent = content
pages.esp = pageESP

makeSection(pageESP, "ESP EGG")

-- Switch-style row
local function makeSwitchRow(parent, y, title, initialOn, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundColor3 = COLORS.bg2
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = COLORS.text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    -- Switch
    local sw = Instance.new("TextButton")
    sw.Size = UDim2.new(0, 40, 0, 20)
    sw.Position = UDim2.new(1, -50, 0.5, -10)
    sw.BackgroundColor3 = initialOn and COLORS.green or COLORS.bg3
    sw.Text = ""
    sw.AutoButtonColor = false
    sw.Parent = row
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = initialOn and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = sw
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = initialOn

    sw.MouseButton1Click:Connect(function()
        state = not state
        if state then
            sw.BackgroundColor3 = COLORS.green
            knob.Position = UDim2.new(1, -18, 0.5, -8)
        else
            sw.BackgroundColor3 = COLORS.bg3
            knob.Position = UDim2.new(0, 2, 0.5, -8)
        end
        if callback then callback(state) end
    end)

    return sw, function() return state end
end

local espSwitch = makeSwitchRow(pageESP, 22, "Bật ESP Egg", false, function(on)
    if on then API.ESP_Enable() else API.ESP_Disable() end
end)

-- ══════════ PAGE: MAP ══════════
local pageMap = Instance.new("Frame")
pageMap.Size = UDim2.new(1, 0, 1, 0)
pageMap.BackgroundTransparency = 1
pageMap.Visible = false
pageMap.Parent = content
pages.map = pageMap

makeSection(pageMap, "CHỌN MAP TARGET")

local mapScroll = Instance.new("ScrollingFrame")
mapScroll.Size = UDim2.new(1, 0, 1, -26)
mapScroll.Position = UDim2.new(0, 0, 0, 22)
mapScroll.BackgroundColor3 = COLORS.bg2
mapScroll.BorderSizePixel = 0
mapScroll.ScrollBarThickness = 3
mapScroll.ScrollBarImageColor3 = COLORS.accent
mapScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
mapScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mapScroll.Parent = pageMap
Instance.new("UICorner", mapScroll).CornerRadius = UDim.new(0, 6)

local mapPad = Instance.new("UIPadding")
mapPad.PaddingTop = UDim.new(0, 4)
mapPad.PaddingLeft = UDim.new(0, 4)
mapPad.PaddingRight = UDim.new(0, 4)
mapPad.PaddingBottom = UDim.new(0, 4)
mapPad.Parent = mapScroll

local mapLayout = Instance.new("UIListLayout")
mapLayout.Padding = UDim.new(0, 3)
mapLayout.Parent = mapScroll

-- ══════════ PAGE: LOG ══════════
local pageLog = Instance.new("Frame")
pageLog.Size = UDim2.new(1, 0, 1, 0)
pageLog.BackgroundTransparency = 1
pageLog.Visible = false
pageLog.Parent = content
pages.log = pageLog

makeSection(pageLog, "LOG")

local logScroll = Instance.new("ScrollingFrame")
logScroll.Size = UDim2.new(1, 0, 1, -26)
logScroll.Position = UDim2.new(0, 0, 0, 22)
logScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
logScroll.BorderSizePixel = 0
logScroll.ScrollBarThickness = 3
logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
logScroll.Parent = pageLog
Instance.new("UICorner", logScroll).CornerRadius = UDim.new(0, 6)

local logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.new(1, -8, 0, 0)
logLabel.Position = UDim2.new(0, 4, 0, 4)
logLabel.BackgroundTransparency = 1
logLabel.TextColor3 = COLORS.text
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 9
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.TextWrapped = true
logLabel.AutomaticSize = Enum.AutomaticSize.Y
logLabel.Parent = logScroll

local logLines = {}
local function addLog(msg)
    table.insert(logLines, tostring(msg))
    if #logLines > 30 then table.remove(logLines, 1) end
    logLabel.Text = table.concat(logLines, "\n")
    logScroll.CanvasPosition = Vector2.new(0, 999999)
end

-- ══════════ MAP DATA ══════════
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
    b.Size = UDim2.new(1, -8, 0, 26)
    b.BackgroundColor3 = (mapData.name == currentTarget)
        and Color3.fromRGB(80, 90, 200)
        or COLORS.bg3
    b.Text = "    " .. mapData.name
    b.TextColor3 = COLORS.text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = false
    b.Parent = mapScroll
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)

    -- Dot indicator
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 6, 0, 6)
    dot.Position = UDim2.new(0, 8, 0.5, -3)
    dot.BackgroundColor3 = (mapData.name == currentTarget)
        and COLORS.green
        or COLORS.bg
    dot.BorderSizePixel = 0
    dot.Parent = b
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    table.insert(mapButtons, { btn = b, data = mapData, dot = dot })

    b.MouseButton1Click:Connect(function()
        currentTarget = mapData.name
        API.SetTarget(mapData.name, mapData.pos)
        for _, item in ipairs(mapButtons) do
            if item.data.name == currentTarget then
                item.btn.BackgroundColor3 = Color3.fromRGB(80, 90, 200)
                item.dot.BackgroundColor3 = COLORS.green
            else
                item.btn.BackgroundColor3 = COLORS.bg3
                item.dot.BackgroundColor3 = COLORS.bg
            end
        end
        addLog("🎯 Target: " .. currentTarget)
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
header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
        pdrag, pds, psp = true, i.Position, panel.Position
    end
end)
header.InputEnded:Connect(function(i)
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
icon.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
    if panel.Visible then setActiveTab("main") end
end)
closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

farmBtn.MouseButton1Click:Connect(function()
    if API.IsRunning() then
        API.Stop()
        farmBtn.Text = "▶  BẮT ĐẦU FARM"
        farmBtn.BackgroundColor3 = COLORS.green
    else
        API.Start()
        farmBtn.Text = "⏹  DỪNG FARM"
        farmBtn.BackgroundColor3 = COLORS.red
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

setActiveTab("main")
addLog("✅ Ready")

print("[Main] ✅ Ready!")
