-- ═══════════════════════════════════════════════════════════════
-- MAIN.LUA FOXNAME STYLE — Steal Egg UI (IMPROVED)
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
    ESP_Enable = function() if ESP then ESP.enable() end end,
    ESP_Disable = function() if ESP then ESP.disable() end end,
    ESP_Toggle = function() if ESP then return ESP.toggle() end end,
    ESP_IsEnabled = function() return ESP and ESP.isEnabled() or false end,
    Version = "7.0.0",
}
local API = _G.StealEgg
_G.MyScript = API

local P = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")

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
    "Forest","Lake","Desert","Jungle","Snow","Volcano",
    "Abyss Ocean","Prehistoric","Cosmic","Cherry Blossom",
    "Titan Temple","Light Dark",
}

-- ══════════ UI ══════════
local old = P:WaitForChild("PlayerGui"):FindFirstChild("StealEggUI")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "StealEggUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999
sg.Parent = P:WaitForChild("PlayerGui")

-- ⭐ ICON (Image-based, fallback to text if image missing)
local icon = Instance.new("ImageButton")
icon.Size = UDim2.new(0, 50, 0, 50)
icon.Position = UDim2.new(0, 15, 0, 150)
icon.BackgroundColor3 = COLORS.bg
icon.BorderSizePixel = 0
icon.Image = "rbxassetid://86285862396979" -- Replace with your icon asset ID
icon.ScaleType = Enum.ScaleType.Fit
icon.AutoButtonColor = false
icon.Draggable = true
icon.Parent = sg
Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
local istk = Instance.new("UIStroke", icon)
istk.Color = COLORS.accent
istk.Thickness = 2

-- Fallback text if image doesn't load
local iconText = Instance.new("TextLabel", icon)
iconText.Size = UDim2.new(1, 0, 1, 0)
iconText.BackgroundTransparency = 1
iconText.Text = "⚙"
iconText.TextColor3 = COLORS.accent
iconText.Font = Enum.Font.GothamBold
iconText.TextSize = 22

-- ⭐ MAIN PANEL
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 500, 0, 480)
panel.Position = UDim2.new(0.5, -250, 0.5, -240)
panel.BackgroundColor3 = COLORS.bg
panel.BackgroundTransparency = 0.35
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = sg
panel.Active = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local pstk = Instance.new("UIStroke", panel)
pstk.Color = COLORS.accent
pstk.Thickness = 1.5

-- ⭐ BACKGROUND IMAGE
local bgImg = Instance.new("ImageLabel", panel)
bgImg.Size = UDim2.new(1, 0, 1, 0)
bgImg.Position = UDim2.new(0, 0, 0, 0)
bgImg.BackgroundTransparency = 0.25
bgImg.ScaleType = Enum.ScaleType.Crop
bgImg.Image = "rbxassetid://116222439691339"
bgImg.ImageTransparency = 0.55
bgImg.ZIndex = 0
Instance.new("UICorner", bgImg).CornerRadius = UDim.new(0, 12)

-- ⭐ CLOSE BUTTON (X)
local closeBtn = Instance.new("TextButton", panel)
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -35, 0, 7)
closeBtn.BackgroundColor3 = COLORS.red
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 10
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
local closeBtnStk = Instance.new("UIStroke", closeBtn)
closeBtnStk.Color = COLORS.red
closeBtnStk.Thickness = 1

closeBtn.MouseButton1Click:Connect(function()
    panel.Visible = false
end)

closeBtn.MouseEnter:Connect(function()
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 140)
end)

closeBtn.MouseLeave:Connect(function()
    closeBtn.BackgroundColor3 = COLORS.red
end)

-- ⭐ SIDEBAR
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 80, 1, 0)
sidebar.Position = UDim2.new(0, 0, 0, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
sidebar.BackgroundTransparency = 0.5
sidebar.BorderSizePixel = 0
sidebar.Parent = panel
sidebar.ZIndex = 2
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 12)

-- ⭐ CONTENT AREA
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -80, 1, 0)
content.Position = UDim2.new(0, 80, 0, 0)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.Parent = panel

local contentPad = Instance.new("UIPadding", content)
contentPad.PaddingTop = UDim.new(0, 15)
contentPad.PaddingLeft = UDim.new(0, 15)
contentPad.PaddingRight = UDim.new(0, 15)
contentPad.PaddingBottom = UDim.new(0, 15)

-- ⭐ RESIZE HANDLE (Bottom Right Corner)
local resizeHandle = Instance.new("Frame", panel)
resizeHandle.Size = UDim2.new(0, 16, 0, 16)
resizeHandle.Position = UDim2.new(1, -16, 1, -16)
resizeHandle.BackgroundColor3 = COLORS.accent
resizeHandle.BorderSizePixel = 0
resizeHandle.ZIndex = 10
resizeHandle.Cursor = "ResizeNWSE"
Instance.new("UICorner", resizeHandle).CornerRadius = UDim.new(0, 4)

-- Resize logic
local resizing = false
local startSize, startPos, startMouse

resizeHandle.MouseButton1Down:Connect(function()
    resizing = true
    startSize = panel.Size
    startPos = panel.Position
    startMouse = game:GetService("UserInputService"):GetMouseLocation()
end)

game:GetService("UserInputService").InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = false
    end
end)

game:GetService("RunService").RenderStepped:Connect(function()
    if resizing then
        local currentMouse = game:GetService("UserInputService"):GetMouseLocation()
        local deltaX = currentMouse.X - startMouse.X
        local deltaY = currentMouse.Y - startMouse.Y
        
        local newWidth = math.max(300, startSize.X.Offset + deltaX)
        local newHeight = math.max(250, startSize.Y.Offset + deltaY)
        
        panel.Size = UDim2.new(0, newWidth, 0, newHeight)
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
            item.bg.BackgroundTransparency = 0.3
        else
            item.label.TextColor3 = COLORS.textDim
            item.bg.BackgroundTransparency = 0.7
        end
    end
    for tid, page in pairs(pages) do page.Visible = (tid == id) end
end

-- ⭐ TAB CREATOR
local function mkTab(id, icon, text)
    local bg = Instance.new("Frame", sidebar)
    bg.Size = UDim2.new(1, 0, 0, 50)
    bg.BackgroundColor3 = COLORS.bg2
    bg.BackgroundTransparency = 0.7
    bg.BorderSizePixel = 0
    bg.Parent = sidebar

    local btn = Instance.new("TextButton", bg)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = icon .. "\n" .. text
    btn.TextColor3 = COLORS.textDim
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9
    btn.AutoButtonColor = false
    
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = icon .. "\n" .. text
    lbl.TextColor3 = COLORS.textDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 9

    btn.MouseButton1Click:Connect(function() setTab(id) end)
    table.insert(tabBtns, { btn = btn, label = lbl, bg = bg, id = id })
    return bg
end

mkTab("main", "🏠", "Main")
mkTab("esp", "👁", "ESP")

-- ⭐ TOGGLE SWITCH PILL CREATOR
local function mkToggle(parent, label, defaultState, onToggle)
    local ctrl = Instance.new("Frame", parent)
    ctrl.Size = UDim2.new(1, 0, 0, 50)
    ctrl.BackgroundTransparency = 1
    
    -- Label
    local lbl = Instance.new("TextLabel", ctrl)
    lbl.Size = UDim2.new(0.6, 0, 0, 16)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = COLORS.textDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Toggle Switch Container (Pill shape)
    local toggleBg = Instance.new("Frame", ctrl)
    toggleBg.Size = UDim2.new(0, 50, 0, 24)
    toggleBg.Position = UDim2.new(1, -50, 0, 0)
    toggleBg.BackgroundColor3 = COLORS.offBg
    toggleBg.BorderSizePixel = 0
    Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(0.5, 0)
    
    -- Toggle Ball (Inner Circle)
    local toggleBall = Instance.new("Frame", toggleBg)
    toggleBall.Size = UDim2.new(0, 20, 0, 20)
    toggleBall.Position = UDim2.new(0, 2, 0.5, -10)
    toggleBall.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    toggleBall.BorderSizePixel = 0
    Instance.new("UICorner", toggleBall).CornerRadius = UDim.new(1, 0)
    
    local state = defaultState or false
    
    local function updateToggle(newState)
        state = newState
        if state then
            -- ON state: green background, ball slides right
            toggleBg.BackgroundColor3 = COLORS.green
            toggleBall.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            toggleBall.Position = UDim2.new(1, -22, 0.5, -10)
        else
            -- OFF state: dark background, ball on left
            toggleBg.BackgroundColor3 = COLORS.offBg
            toggleBall.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
            toggleBall.Position = UDim2.new(0, 2, 0.5, -10)
        end
        if onToggle then onToggle(state) end
    end
    
    -- Click handler
    local clickRegion = Instance.new("TextButton", toggleBg)
    clickRegion.Size = UDim2.new(1, 0, 1, 0)
    clickRegion.BackgroundTransparency = 1
    clickRegion.Text = ""
    clickRegion.MouseButton1Click:Connect(function()
        updateToggle(not state)
    end)
    
    -- Expose methods
    return {
        ctrl = ctrl,
        setState = updateToggle,
        getState = function() return state end
    }
end

-- ═══════════════════════════════════════════════════════════════
-- PAGE: MAIN
-- ═══════════════════════════════════════════════════════════════
local pageMain = Instance.new("Frame", content)
pageMain.Size = UDim2.new(1, 0, 1, 0)
pageMain.BackgroundTransparency = 1
pages.main = pageMain

local mainLayout = Instance.new("UIListLayout", pageMain)
mainLayout.Padding = UDim.new(0, 12)
mainLayout.FillDirection = Enum.FillDirection.Vertical

local mainPad = Instance.new("UIPadding", pageMain)
mainPad.PaddingTop = UDim.new(0, 0)

-- ⭐ SELECT MAP (dropdown)
local function mkControl(parent, label)
    local ctrl = Instance.new("Frame", parent)
    ctrl.Size = UDim2.new(1, 0, 0, 0)
    ctrl.BackgroundTransparency = 1
    
    local lbl = Instance.new("TextLabel", ctrl)
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = COLORS.textDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    return ctrl, lbl
end

local mapCtrl, mapLabel = mkControl(pageMain, "🎯 SELECT MAP")
local mapSelect = Instance.new("TextButton", mapCtrl)
mapSelect.Size = UDim2.new(1, 0, 0, 32)
mapSelect.Position = UDim2.new(0, 0, 0, 20)
mapSelect.BackgroundColor3 = COLORS.bg2
mapSelect.Text = "All Maps  ▼"
mapSelect.TextColor3 = COLORS.text
mapSelect.Font = Enum.Font.GothamBold
mapSelect.TextSize = 11
mapSelect.AutoButtonColor = false
mapSelect.Parent = mapCtrl
Instance.new("UICorner", mapSelect).CornerRadius = UDim.new(0, 6)

-- Dropdown list
local mapScroll = Instance.new("ScrollingFrame", pageMain)
mapScroll.Size = UDim2.new(1, 0, 0, 120)
mapScroll.Position = UDim2.new(0, 0, 0, 0)
mapScroll.BackgroundColor3 = COLORS.bg3
mapScroll.BorderSizePixel = 0
mapScroll.ScrollBarThickness = 2
mapScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
mapScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mapScroll.Visible = false
mapScroll.Parent = pageMain
Instance.new("UICorner", mapScroll).CornerRadius = UDim.new(0, 6)

local mPad = Instance.new("UIPadding", mapScroll)
mPad.PaddingTop = UDim.new(0, 4)
mPad.PaddingLeft = UDim.new(0, 4)
mPad.PaddingRight = UDim.new(0, 4)

local mLayout = Instance.new("UIListLayout", mapScroll)
mLayout.Padding = UDim.new(0, 3)

local selectedMaps = {}
local mapRowBtns = {}

-- Add "Select All" button
local selAllBtn = Instance.new("TextButton", mapScroll)
selAllBtn.Size = UDim2.new(1, -8, 0, 22)
selAllBtn.BackgroundColor3 = COLORS.gold
selAllBtn.Text = "All Maps"
selAllBtn.TextColor3 = Color3.new(0, 0, 0)
selAllBtn.Font = Enum.Font.GothamBold
selAllBtn.TextSize = 10
selAllBtn.TextXAlignment = Enum.TextXAlignment.Left
selAllBtn.AutoButtonColor = false
Instance.new("UICorner", selAllBtn).CornerRadius = UDim.new(0, 4)

selAllBtn.MouseButton1Click:Connect(function()
    for _, m in ipairs(ALL_MAPS) do selectedMaps[m] = true end
    mapSelect.Text = "All Maps  ▼"
    for _, item in ipairs(mapRowBtns) do
        item.btn.BackgroundColor3 = COLORS.green
        item.btn.TextColor3 = Color3.new(0, 0, 0)
    end
    mapScroll.Visible = false
end)

-- Add map items
for _, m in ipairs(ALL_MAPS) do
    local b = Instance.new("TextButton", mapScroll)
    b.Size = UDim2.new(1, -8, 0, 22)
    b.BackgroundColor3 = COLORS.bg3
    b.Text = m
    b.TextColor3 = COLORS.text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    
    table.insert(mapRowBtns, { btn = b, name = m })
    
    b.MouseButton1Click:Connect(function()
        selectedMaps[m] = not selectedMaps[m]
        if selectedMaps[m] then
            b.BackgroundColor3 = COLORS.green
            b.TextColor3 = Color3.new(0, 0, 0)
        else
            b.BackgroundColor3 = COLORS.bg3
            b.TextColor3 = COLORS.text
        end
        
        local count = 0
        for _ in pairs(selectedMaps) do count = count + 1 end
        if count == 0 then
            mapSelect.Text = "No Maps  ▼"
        elseif count == #ALL_MAPS then
            mapSelect.Text = "All Maps  ▼"
        else
            mapSelect.Text = count .. " Maps  ▼"
        end
    end)
end

mapSelect.MouseButton1Click:Connect(function()
    mapScroll.Visible = not mapScroll.Visible
end)

-- ⭐ AUTO STEAL (Toggle Switch Pill)
local stealToggle = mkToggle(pageMain, "🔄 AUTO STEAL", false, function(state)
    if state then
        API.Start()
    else
        API.Stop()
    end
end)

-- ⭐ SELECT VALUE (input)
local valCtrl, valLabel = mkControl(pageMain, "💵 SELECT VALUE")
local valInput = Instance.new("TextBox", valCtrl)
valInput.Size = UDim2.new(1, 0, 0, 32)
valInput.Position = UDim2.new(0, 0, 0, 20)
valInput.BackgroundColor3 = COLORS.bg2
valInput.Text = "100000"
valInput.TextColor3 = COLORS.text
valInput.Font = Enum.Font.GothamBold
valInput.TextSize = 12
valInput.PlaceholderText = "Enter value..."
valInput.Parent = valCtrl
Instance.new("UICorner", valInput).CornerRadius = UDim.new(0, 6)

-- ⭐ STEAL BEST EGG (Toggle Switch Pill)
local bestToggle = mkToggle(pageMain, "⭐ STEAL BEST EGG", false, function(state)
    -- Custom logic here
end)

-- ═══════════════════════════════════════════════════════════════
-- PAGE: ESP
-- ═══════════════════════════════════════════════════════════════
local pageESP = Instance.new("Frame", content)
pageESP.Size = UDim2.new(1, 0, 1, 0)
pageESP.BackgroundTransparency = 1
pageESP.Visible = false
pages.esp = pageESP

local espLabel = Instance.new("TextLabel", pageESP)
espLabel.Size = UDim2.new(1, 0, 0, 30)
espLabel.BackgroundTransparency = 1
espLabel.Text = "👁 ESP SETTINGS"
espLabel.TextColor3 = COLORS.text
espLabel.Font = Enum.Font.GothamBold
espLabel.TextSize = 12

-- ⭐ ESP Toggle (Toggle Switch Pill)
local espToggle = mkToggle(pageESP, "Enable ESP", false, function(state)
    if state then
        API.ESP_Enable()
    else
        API.ESP_Disable()
    end
end)
espToggle.ctrl.Position = UDim2.new(0, 0, 0, 40)

-- ══════════ INIT ══════════
setTab("main")
icon.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible end)

print("[Main] ✅ Ready v7 - Toggle Switch Edition!")
