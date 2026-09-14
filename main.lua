-- ═══════════════════════════════════════════════════════════════
-- MAIN.LUA FOXNAME STYLE — Steal Egg UI (FIXED + HOOKED)
-- ✅ FIXED: 580x380 Size + All Bug Fixes
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
                if success then return result end
            end
        end
    end
    return nil
end

print("[Main] 📦 Loading...")
local Steal = fetch("modules/steal.lua")
local ESP   = fetch("modules/esp.lua")

_G.StealEgg = {
    Steal = Steal, ESP = ESP,
    Start = function() if Steal then Steal.start() end end,
    Stop = function() if Steal then Steal.stop() end end,
    IsRunning = function() return Steal and Steal.isRunning() or false end,
    SetTargets = function(list) if Steal then Steal.setTargets(list) end end,
    SetHome = function(p) if Steal then Steal.setHome(p) end end,
    SetForest = function(p) if Steal then Steal.setForest(p) end end,
    OnLog = function(cb) if Steal then Steal.onLog(cb) end end,
    -- ⭐ Priority Income API
    SetPriorityIncome = function(b) if Steal then return Steal.setPriorityIncome(b) end end,
    TogglePriorityIncome = function() if Steal then return Steal.togglePriorityIncome() end end,
    SetPriorityThreshold = function(n) if Steal then Steal.setPriorityThreshold(n) end end,
    GetPriorityThreshold = function() if Steal then return Steal.getPriorityThreshold() end end,
    IsPriorityIncome = function() return Steal and Steal.isPriorityIncome() or false end,
    ClearIncomeCache = function() if Steal then Steal.clearIncomeCache() end end,
    -- ESP
    ESP_Enable = function() if ESP then ESP.enable() end end,
    ESP_Disable = function() if ESP then ESP.disable() end end,
    ESP_Toggle = function() if ESP then return ESP.toggle() end end,
    ESP_IsEnabled = function() return ESP and ESP.isEnabled() or false end,
    Version = "9.3.1-FIXED",
}
local API = _G.StealEgg
_G.MyScript = API

local P = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- ⭐ GỌI LOG RA CONSOLE (bạn có thể log lên UI sau)
API.OnLog(function(msg)
    print("[UI-Log] " .. tostring(msg))
end)

local COLORS = {
    bg      = Color3.fromRGB(12, 14, 22),
    bg2     = Color3.fromRGB(18, 22, 32),
    bg3     = Color3.fromRGB(28, 34, 48),
    accent  = Color3.fromRGB(0, 220, 255),
    accent2 = Color3.fromRGB(100, 150, 255),
    text    = Color3.fromRGB(220, 240, 255),
    textDim = Color3.fromRGB(150, 180, 200),
    green   = Color3.fromRGB(100, 200, 120),
    red     = Color3.fromRGB(220, 80, 100),
    gold    = Color3.fromRGB(255, 200, 50),
    offBg   = Color3.fromRGB(40, 45, 55),
}

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

-- ══════════ UI ══════════
local old = P:WaitForChild("PlayerGui"):FindFirstChild("StealEggUI")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "StealEggUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999
sg.Parent = P:WaitForChild("PlayerGui")

-- ⭐ ICON — SQUARE + BORDER + MOBILE TOUCH
local icon = Instance.new("ImageButton")
icon.Name = "IconButton"
icon.Size = UDim2.new(0, 52, 0, 52)
icon.Position = UDim2.new(0, 15, 0, 150)

-- SQUARE
icon.BackgroundColor3 = COLORS.bg
icon.BackgroundTransparency = 0.05
icon.BorderSizePixel = 0

icon.Image = "rbxassetid://86285862396979"
icon.ScaleType = Enum.ScaleType.Fit
icon.ImageTransparency = 0

icon.AutoButtonColor = false
icon.Active = true
icon.Selectable = true
icon.ZIndex = 20
icon.Parent = sg

-- Bo góc nhẹ, KHÔNG còn hình tròn
local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0, 10)
iconCorner.Parent = icon

-- Viền
local iconStroke = Instance.new("UIStroke")
iconStroke.Name = "IconBorder"
iconStroke.Color = COLORS.accent
iconStroke.Thickness = 2
iconStroke.Transparency = 0.05
iconStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
iconStroke.Parent = icon

-- ⭐ Lớp sáng bên trong
local iconGlow = Instance.new("Frame")
iconGlow.Name = "Glow"
iconGlow.Size = UDim2.new(1, -6, 1, -6)
iconGlow.Position = UDim2.new(0, 3, 0, 3)
iconGlow.BackgroundTransparency = 1
iconGlow.BorderSizePixel = 0
iconGlow.ZIndex = 21
iconGlow.Parent = icon

local glowCorner = Instance.new("UICorner")
glowCorner.CornerRadius = UDim.new(0, 7)
glowCorner.Parent = iconGlow

local glowStroke = Instance.new("UIStroke")
glowStroke.Color = COLORS.accent
glowStroke.Thickness = 1
glowStroke.Transparency = 0.65
glowStroke.Parent = iconGlow

-- ⚙ icon text
local iconText = Instance.new("TextLabel")
iconText.Name = "IconText"
iconText.Size = UDim2.new(1, 0, 1, 0)
iconText.BackgroundTransparency = 1
iconText.Text = "⚙"
iconText.TextColor3 = COLORS.accent
iconText.Font = Enum.Font.GothamBold
iconText.TextSize = 22
iconText.ZIndex = 22
iconText.Parent = icon

-- ============================================================
-- MOBILE + PC CLICK
-- ============================================================

local function togglePanel()
    panel.Visible = not panel.Visible

    -- hiệu ứng đậm / nhạt
    if panel.Visible then
        icon.BackgroundTransparency = 0
        iconStroke.Transparency = 0
        iconText.TextColor3 = Color3.new(1, 1, 1)
    else
        icon.BackgroundTransparency = 0.05
        iconStroke.Transparency = 0.05
        iconText.TextColor3 = COLORS.accent
    end
end

-- Mouse
icon.MouseButton1Click:Connect(function()
    togglePanel()
end)

-- Touch mobile
icon.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        togglePanel()
    end
end)

-- ============================================================
-- HIỆU ỨNG ĐẬM / NHẠT
-- ============================================================

icon.MouseEnter:Connect(function()
    icon.BackgroundTransparency = 0
    iconStroke.Thickness = 3
    iconStroke.Transparency = 0
end)

icon.MouseLeave:Connect(function()
    if not panel.Visible then
        icon.BackgroundTransparency = 0.05
        iconStroke.Thickness = 2
        iconStroke.Transparency = 0.05
    end
end)

-- Touch bắt đầu
icon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then

        icon.BackgroundTransparency = 0
        iconStroke.Thickness = 3
        iconStroke.Transparency = 0
    end
end)

-- Touch kết thúc
icon.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then

        task.delay(0.08, function()
            if not panel.Visible then
                icon.BackgroundTransparency = 0.05
                iconStroke.Thickness = 2
                iconStroke.Transparency = 0.05
            end
        end)
    end
end)

-- ⭐ MAIN PANEL (✅ FIXED: 580x380 size)
local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.new(0, 580, 0, 380)  -- ✅ SHADOW GLADE SIZE
panel.Position = UDim2.new(0.5, -290, 0.5, -190)
panel.BackgroundColor3 = COLORS.bg
panel.BackgroundTransparency = 0.35
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = sg
panel.Active = true
panel.Draggable = true
panel.ZIndex = 1
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local pstk = Instance.new("UIStroke", panel)
pstk.Color = COLORS.accent
pstk.Thickness = 1.5

-- ⭐ BG IMAGE
local bgImg = Instance.new("ImageLabel", panel)
bgImg.Name = "BackgroundImage"
bgImg.Size = UDim2.new(1, 0, 1, 0)
bgImg.Position = UDim2.new(0, 0, 0, 0)
bgImg.BackgroundTransparency = 0.25
bgImg.ScaleType = Enum.ScaleType.Crop
bgImg.Image = "rbxassetid://116222439691339"
bgImg.ImageTransparency = 0.55
bgImg.ZIndex = 0
Instance.new("UICorner", bgImg).CornerRadius = UDim.new(0, 12)

-- ⭐ CLOSE (✅ FIXED position)
local closeBtn = Instance.new("TextButton", panel)
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -38, 0, 8)
closeBtn.BackgroundColor3 = COLORS.red
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 10
closeBtn.Cursor = "PointingHand"
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)
closeBtn.MouseEnter:Connect(function() closeBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 140) end)
closeBtn.MouseLeave:Connect(function() closeBtn.BackgroundColor3 = COLORS.red end)

-- ⭐ SIDEBAR (✅ FIXED: 100px width + padding)
local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, 100, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
sidebar.BackgroundTransparency = 0.5
sidebar.BorderSizePixel = 0
sidebar.Parent = panel
sidebar.ZIndex = 2
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 12)

local sidebarPad = Instance.new("UIPadding", sidebar)
sidebarPad.PaddingTop = UDim.new(0, 12)
sidebarPad.PaddingBottom = UDim.new(0, 12)
sidebarPad.PaddingLeft = UDim.new(0, 6)
sidebarPad.PaddingRight = UDim.new(0, 6)

local sidebarLayout = Instance.new("UIListLayout", sidebar)
sidebarLayout.Padding = UDim.new(0, 6)
sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sidebarLayout.FillDirection = Enum.FillDirection.Vertical

-- ⭐ CONTENT (✅ FIXED: match sidebar width)
local content = Instance.new("Frame")
content.Name = "ContentFrame"
content.Size = UDim2.new(1, -100, 1, 0)
content.Position = UDim2.new(0, 100, 0, 0)
content.BackgroundTransparency = 1
content.ClipsDescendants = true
content.Parent = panel
content.ZIndex = 1

local contentPad = Instance.new("UIPadding", content)
contentPad.PaddingTop = UDim.new(0, 12)
contentPad.PaddingLeft = UDim.new(0, 12)
contentPad.PaddingRight = UDim.new(0, 12)
contentPad.PaddingBottom = UDim.new(0, 12)

-- ⭐ RESIZE (✅ FIXED: better position + cursor)
local resizeHandle = Instance.new("Frame", panel)
resizeHandle.Name = "ResizeHandle"
resizeHandle.Size = UDim2.new(0, 14, 0, 14)
resizeHandle.Position = UDim2.new(1, -18, 1, -18)
resizeHandle.BackgroundColor3 = COLORS.accent
resizeHandle.BorderSizePixel = 0
resizeHandle.ZIndex = 10
resizeHandle.Cursor = "SizeNWSE"
Instance.new("UICorner", resizeHandle).CornerRadius = UDim.new(0, 3)

local resizing = false
local startSize, startMouse
resizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = true
        startSize = panel.Size
        startMouse = UIS:GetMouseLocation()
        panel.Draggable = false
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = false
        panel.Draggable = true
    end
end)
RunService.RenderStepped:Connect(function()
    if resizing then
        local cm = UIS:GetMouseLocation()
        local dx = cm.X - startMouse.X
        local dy = cm.Y - startMouse.Y
        local newW = math.clamp(startSize.X.Offset + dx, 380, 1200)  -- ✅ Min 380
        local newH = math.clamp(startSize.Y.Offset + dy, 320, 900)   -- ✅ Min 320
        panel.Size = UDim2.new(0, newW, 0, newH)
    end
end)

-- ⭐ PAGES
local currentTab = "main"
local pages = {}
local tabBtns = {}

local function setTab(id)
    currentTab = id
    for _, item in ipairs(tabBtns) do
        if item.id == id then
            item.label.TextColor3 = COLORS.accent
            item.bg.BackgroundColor3 = COLORS.bg3
            item.bg.BackgroundTransparency = 0.3
        else
            item.label.TextColor3 = COLORS.textDim
            item.bg.BackgroundColor3 = COLORS.bg2
            item.bg.BackgroundTransparency = 0.7
        end
    end
    for tid, page in pairs(pages) do page.Visible = (tid == id) end
end

-- ⭐ TAB CREATOR
local function mkTab(id, iconChar, text)
    local bg = Instance.new("Frame", sidebar)
    bg.Name = "TabButton_" .. id
    bg.Size = UDim2.new(0, 70, 0, 50)
    bg.BackgroundColor3 = COLORS.bg2
    bg.BackgroundTransparency = 0.7
    bg.BorderSizePixel = 0
    bg.Cursor = "PointingHand"
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

    local btn = Instance.new("TextButton", bg)
    btn.Name = "ClickRegion"
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 1

    local lbl = Instance.new("TextLabel", bg)
    lbl.Name = "TabLabel"
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = iconChar .. "\n" .. text
    lbl.TextColor3 = COLORS.textDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 9
    lbl.ZIndex = 2

    btn.MouseButton1Click:Connect(function() setTab(id) end)
    table.insert(tabBtns, { btn = btn, label = lbl, bg = bg, id = id })
    return bg
end

mkTab("main", "🏠", "Main")
mkTab("esp", "👁", "ESP")

-- ⭐ TOGGLE SWITCH
local function mkToggle(parent, label, defaultState, onToggle)
    local ctrl = Instance.new("Frame", parent)
    ctrl.Name = "Toggle_" .. label
    ctrl.Size = UDim2.new(1, 0, 0, 32)
    ctrl.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", ctrl)
    lbl.Name = "Label"
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = COLORS.text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 1

    local toggleBg = Instance.new("Frame", ctrl)
    toggleBg.Name = "ToggleBG"
    toggleBg.Size = UDim2.new(0, 50, 0, 24)
    toggleBg.Position = UDim2.new(1, -50, 0.5, -12)
    toggleBg.BackgroundColor3 = COLORS.offBg
    toggleBg.BorderSizePixel = 0
    toggleBg.ZIndex = 1
    Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(0.5, 0)

    local toggleBall = Instance.new("Frame", toggleBg)
    toggleBall.Name = "ToggleBall"
    toggleBall.Size = UDim2.new(0, 20, 0, 20)
    toggleBall.Position = UDim2.new(0, 2, 0.5, -10)
    toggleBall.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    toggleBall.BorderSizePixel = 0
    toggleBall.ZIndex = 2
    Instance.new("UICorner", toggleBall).CornerRadius = UDim.new(1, 0)

    local state = defaultState or false

    local function updateToggle(newState, silent)
        state = newState
        if state then
            toggleBg.BackgroundColor3 = COLORS.green
            toggleBall.BackgroundColor3 = Color3.new(1, 1, 1)
            toggleBall.Position = UDim2.new(1, -22, 0.5, -10)
        else
            toggleBg.BackgroundColor3 = COLORS.offBg
            toggleBall.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
            toggleBall.Position = UDim2.new(0, 2, 0.5, -10)
        end
        if not silent and onToggle then onToggle(state) end
    end

    local clickRegion = Instance.new("TextButton", toggleBg)
    clickRegion.Name = "ClickRegion"
    clickRegion.Size = UDim2.new(1, 0, 1, 0)
    clickRegion.BackgroundTransparency = 1
    clickRegion.Text = ""
    clickRegion.AutoButtonColor = false
    clickRegion.ZIndex = 3
    clickRegion.Cursor = "PointingHand"
    clickRegion.MouseButton1Click:Connect(function()
        updateToggle(not state)
    end)

    return {
        ctrl = ctrl,
        setState = function(s) updateToggle(s, true) end,
        getState = function() return state end
    }
end

-- ⭐ CONTROL WRAPPER
local function mkControl(parent, label)
    local ctrl = Instance.new("Frame", parent)
    ctrl.Name = "Control_" .. label
    ctrl.Size = UDim2.new(1, 0, 0, 58)
    ctrl.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", ctrl)
    lbl.Name = "Label"
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = COLORS.textDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 1

    return ctrl, lbl
end

-- ═══════════════════════════════════════════════════════════════
-- PAGE: MAIN
-- ═══════════════════════════════════════════════════════════════
local pageMain = Instance.new("Frame", content)
pageMain.Name = "MainPage"
pageMain.Size = UDim2.new(1, 0, 1, 0)
pageMain.BackgroundTransparency = 1
pageMain.ClipsDescendants = true
pageMain.ZIndex = 1
pages.main = pageMain

local mainPad = Instance.new("UIPadding", pageMain)
mainPad.PaddingTop = UDim.new(0, 0)

local mainLayout = Instance.new("UIListLayout", pageMain)
mainLayout.Padding = UDim.new(0, 10)
mainLayout.FillDirection = Enum.FillDirection.Vertical
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- ⭐ MAP SELECT
local mapCtrl, mapLabel = mkControl(pageMain, "🎯 SELECT MAP")
local mapSelect = Instance.new("TextButton", mapCtrl)
mapSelect.Name = "MapSelector"
mapSelect.Size = UDim2.new(1, 0, 0, 32)
mapSelect.Position = UDim2.new(0, 0, 0, 20)
mapSelect.BackgroundColor3 = COLORS.bg2
mapSelect.Text = "All Maps  ▼"
mapSelect.TextColor3 = COLORS.text
mapSelect.Font = Enum.Font.GothamBold
mapSelect.TextSize = 11
mapSelect.AutoButtonColor = false
mapSelect.ZIndex = 2
mapSelect.Cursor = "PointingHand"
Instance.new("UICorner", mapSelect).CornerRadius = UDim.new(0, 6)

-- Dropdown
local mapDropdown = Instance.new("Frame", mapCtrl)
mapDropdown.Name = "Dropdown"
mapDropdown.Size = UDim2.new(1, 0, 0, 0)
mapDropdown.Position = UDim2.new(0, 0, 0, 56)
mapDropdown.BackgroundTransparency = 1
mapDropdown.Visible = false
mapDropdown.ZIndex = 3

local mapScroll = Instance.new("ScrollingFrame", mapDropdown)
mapScroll.Name = "ScrollFrame"
mapScroll.Size = UDim2.new(1, 0, 0, 180)
mapScroll.BackgroundColor3 = COLORS.bg3
mapScroll.BorderSizePixel = 0
mapScroll.ScrollBarThickness = 2
mapScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
mapScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mapScroll.ZIndex = 3
Instance.new("UICorner", mapScroll).CornerRadius = UDim.new(0, 6)

local mPad = Instance.new("UIPadding", mapScroll)
mPad.PaddingTop = UDim.new(0, 4)
mPad.PaddingLeft = UDim.new(0, 4)
mPad.PaddingRight = UDim.new(0, 4)
mPad.PaddingBottom = UDim.new(0, 4)

local mLayout = Instance.new("UIListLayout", mapScroll)
mLayout.Padding = UDim.new(0, 3)
mLayout.SortOrder = Enum.SortOrder.LayoutOrder

local selectedMaps = {}
local mapRowBtns = {}

local function updateSelectedMaps()
    local targets = {}
    for _, m in ipairs(ALL_MAPS) do
        if selectedMaps[m.name] then
            table.insert(targets, m)
        end
    end
    if #targets == 0 then
        targets = ALL_MAPS
    end
    API.SetTargets(targets)
end

-- "All Maps" button
local selAllBtn = Instance.new("TextButton", mapScroll)
selAllBtn.Name = "AllMapsBtn"
selAllBtn.Size = UDim2.new(1, -8, 0, 24)
selAllBtn.BackgroundColor3 = COLORS.gold
selAllBtn.Text = "✓ All Maps"
selAllBtn.TextColor3 = Color3.new(0, 0, 0)
selAllBtn.Font = Enum.Font.GothamBold
selAllBtn.TextSize = 10
selAllBtn.TextXAlignment = Enum.TextXAlignment.Left
selAllBtn.AutoButtonColor = false
selAllBtn.ZIndex = 4
selAllBtn.Cursor = "PointingHand"
Instance.new("UICorner", selAllBtn).CornerRadius = UDim.new(0, 4)

selAllBtn.MouseButton1Click:Connect(function()
    for _, m in ipairs(ALL_MAPS) do selectedMaps[m.name] = true end
    mapSelect.Text = "All Maps  ▼"
    for _, item in ipairs(mapRowBtns) do
        item.btn.BackgroundColor3 = COLORS.green
        item.btn.TextColor3 = Color3.new(0, 0, 0)
    end
    updateSelectedMaps()
    mapDropdown.Visible = false
end)

-- Map rows
for idx, m in ipairs(ALL_MAPS) do
    local b = Instance.new("TextButton", mapScroll)
    b.Name = "MapBtn_" .. m.name
    b.Size = UDim2.new(1, -8, 0, 24)
    b.BackgroundColor3 = COLORS.bg3
    b.Text = m.name
    b.TextColor3 = COLORS.text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = false
    b.ZIndex = 4
    b.Cursor = "PointingHand"
    b.LayoutOrder = idx
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)

    table.insert(mapRowBtns, { btn = b, name = m.name })

    b.MouseButton1Click:Connect(function()
        selectedMaps[m.name] = not selectedMaps[m.name]
        if selectedMaps[m.name] then
            b.BackgroundColor3 = COLORS.green
            b.TextColor3 = Color3.new(0, 0, 0)
        else
            b.BackgroundColor3 = COLORS.bg3
            b.TextColor3 = COLORS.text
        end

        local count = 0
        for _ in pairs(selectedMaps) do count = count + 1 end
        if count == 0 then
            mapSelect.Text = "All Maps (default)  ▼"
        elseif count == #ALL_MAPS then
            mapSelect.Text = "All Maps  ▼"
        else
            mapSelect.Text = count .. " Maps  ▼"
        end
        updateSelectedMaps()
    end)
end

mapSelect.MouseButton1Click:Connect(function()
    mapDropdown.Visible = not mapDropdown.Visible
end)

-- ⭐ AUTO STEAL
local stealToggle = mkToggle(pageMain, "🔄 AUTO STEAL", false, function(state)
    if state then
        API.Start()
    else
        API.Stop()
    end
end)

-- ⭐ PRIORITY INCOME
local bestToggle = mkToggle(pageMain, "⭐ ƯU TIÊN TIỀN CAO", false, function(state)
    API.SetPriorityIncome(state)
end)

-- ⭐ THRESHOLD INPUT
local valCtrl, valLabel = mkControl(pageMain, "💵 NGƯỠNG TIỀN ($/s)")
local valInput = Instance.new("TextBox", valCtrl)
valInput.Name = "ThresholdInput"
valInput.Size = UDim2.new(1, 0, 0, 32)
valInput.Position = UDim2.new(0, 0, 0, 20)
valInput.BackgroundColor3 = COLORS.bg2
valInput.Text = "1000000"
valInput.TextColor3 = COLORS.text
valInput.Font = Enum.Font.GothamBold
valInput.TextSize = 12
valInput.PlaceholderText = "VD: 1000000"
valInput.ClearTextOnFocus = false
valInput.ZIndex = 2
Instance.new("UICorner", valInput).CornerRadius = UDim.new(0, 6)

valInput.FocusLost:Connect(function()
    local n = tonumber(valInput.Text)
    if n and n > 0 then
        API.SetPriorityThreshold(n)
    else
        valInput.Text = "1000000"
    end
end)

-- ⭐ SYNC STATE với module mỗi 1s
task.spawn(function()
    while task.wait(1) do
        -- Sync auto steal
        local running = API.IsRunning()
        if running ~= stealToggle.getState() then
            stealToggle.setState(running)
        end

        -- Sync priority income
        local prio = API.IsPriorityIncome()
        if prio ~= bestToggle.getState() then
            bestToggle.setState(prio)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- PAGE: ESP
-- ═══════════════════════════════════════════════════════════════
local pageESP = Instance.new("Frame", content)
pageESP.Name = "ESPPage"
pageESP.Size = UDim2.new(1, 0, 1, 0)
pageESP.BackgroundTransparency = 1
pageESP.Visible = false
pageESP.ZIndex = 1
pages.esp = pageESP

local espLayout = Instance.new("UIListLayout", pageESP)
espLayout.Padding = UDim.new(0, 10)
espLayout.FillDirection = Enum.FillDirection.Vertical
espLayout.SortOrder = Enum.SortOrder.LayoutOrder

local espHeader = Instance.new("TextLabel", pageESP)
espHeader.Name = "Header"
espHeader.Size = UDim2.new(1, 0, 0, 30)
espHeader.BackgroundTransparency = 1
espHeader.Text = "👁 ESP SETTINGS"
espHeader.TextColor3 = COLORS.text
espHeader.Font = Enum.Font.GothamBold
espHeader.TextSize = 13
espHeader.TextXAlignment = Enum.TextXAlignment.Left
espHeader.ZIndex = 1
espHeader.LayoutOrder = 1

local espToggle = mkToggle(pageESP, "Enable ESP", false, function(state)
    if state then API.ESP_Enable() else API.ESP_Disable() end
end)
espToggle.ctrl.LayoutOrder = 2

-- ══════════ INIT ══════════
setTab("main")

-- ⭐ Mở/đóng panel
icon.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
end)

-- ⭐ RightShift để toggle panel
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        panel.Visible = not panel.Visible
    end
end)

print("[Main] ✅ Ready v9.3.1-FIXED - UI 580x380 + All Fixes Applied!")
