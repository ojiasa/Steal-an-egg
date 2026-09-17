-- ═══════════════════════════════════════════════════════════════
-- MAIN.lua v3.8.1 — Số ô nhập nhẹ & dễ nhìn + Bỏ viền trắng
-- ═══════════════════════════════════════════════════════════════

local BACKGROUND_ID = (Config and Config.BackgroundImageId) or "rbxassetid://116222439691339"
local ICON_ID = (Config and Config.IconImageId) or "rbxassetid://130473788814906"

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
    warn("[Main] ❌ " .. path)
    return nil
end

local Steal = fetch("modules/steal.lua")
local ESP   = fetch("modules/esp.lua")
local SellManager = fetch("modules/sell_manager.lua")

_G.StealEgg = {
    Steal = Steal, ESP = ESP, SellManager = SellManager,
    
    Start = function() if Steal then Steal.start() end end,
    Stop = function() if Steal then Steal.stop() end end,
    IsRunning = function() return Steal and Steal.isRunning() or false end,
    SetTargets = function(list) if Steal then Steal.setTargets(list) end end,
    GetAllMaps = function() return Steal and Steal.getAllMaps() or {} end,
    OnLog = function(cb) if Steal then Steal.onLog(cb) end end,

    SetPriorityIncome = function(on) if Steal then return Steal.setPriorityIncome(on) end end,
    IsPriorityIncome = function() return Steal and Steal.isPriorityIncome() or false end,
    TogglePriorityIncome = function() if Steal then Steal.togglePriorityIncome() end end,
    SetPriorityThreshold = function(n) if Steal then Steal.setPriorityThreshold(n) end end,
    GetPriorityThreshold = function() return Steal and Steal.getPriorityThreshold() or 1000000 end,
    ClearIncomeCache = function() if Steal then Steal.clearIncomeCache() end end,

    SetBigEggMode = function(on) if Steal and Steal.setBigEggMode then return Steal.setBigEggMode(on) end end,
    IsBigEggMode = function() return Steal and Steal.isBigEggMode and Steal.isBigEggMode() or false end,
    ToggleBigEggMode = function() if Steal and Steal.toggleBigEggMode then return Steal.toggleBigEggMode() end end,

    ESP_Enable = function() if ESP then ESP.enable() end end,
    ESP_Disable = function() if ESP then ESP.disable() end end,
    ESP_Toggle = function() if ESP then return ESP.toggle() end end,
    ESP_IsEnabled = function() return ESP and ESP.isEnabled() or false end,
    ESP_SetMapFilter = function(list) if ESP then ESP.setMapFilter(list) end end,

    SM_Start = function() if SellManager then SellManager.start() end end,
    SM_Stop = function() if SellManager then SellManager.stop() end end,
    SM_IsRunning = function() return SellManager and SellManager.isRunning() or false end,

    SM_SetAutoSell = function(on) if SellManager then return SellManager.setAutoSell(on) end end,
    SM_ToggleAutoSell = function() if SellManager then return SellManager.toggleAutoSell() end end,
    SM_IsAutoSell = function() return SellManager and SellManager.isAutoSellEnabled() or false end,

    SM_SetAutoEquip = function(on) if SellManager then return SellManager.setAutoEquip(on) end end,
    SM_ToggleAutoEquip = function() if SellManager then return SellManager.toggleAutoEquip() end end,
    SM_IsAutoEquip = function() return SellManager and SellManager.isAutoEquipEnabled() or false end,

    SM_SetThreshold = function(v) if SellManager then SellManager.setSellThreshold(v) end end,
    SM_GetThreshold = function() return SellManager and SellManager.getSellThreshold() or 1000000 end,

    SM_SetIncludeZero = function(on) if SellManager then SellManager.setIncludeZero(on) end end,
    SM_GetStats = function() return SellManager and SellManager.getStats() or {} end,
    SM_RunOnce = function() if SellManager then SellManager.runOnce() end end,
    SM_ScanInfo = function() if SellManager then SellManager.scanInfo() end end,
    SM_OnLog = function(cb) if SellManager then SellManager.onLog(cb) end end,

    Version = "3.8.1",
}
local API = _G.StealEgg
_G.MyScript = API

local P = game:GetService("Players").LocalPlayer
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local function getParent()
    local ok = pcall(function()
        local t = Instance.new("Folder"); t.Parent = CoreGui; t:Destroy()
    end)
    return ok and CoreGui or P:WaitForChild("PlayerGui")
end
local PARENT = getParent()

local COLORS = {
    bg          = Color3.fromRGB(215, 220, 228),
    card        = Color3.fromRGB(255, 255, 255),
    cardBorder  = Color3.fromRGB(230, 235, 240),
    sidebar     = Color3.fromRGB(195, 200, 210),
    activeBtn   = Color3.fromRGB(120, 125, 135),
    activeText  = Color3.fromRGB(255, 255, 255),
    
    textBold    = Color3.fromRGB(209, 213, 219),
    textDim     = Color3.fromRGB(180, 185, 195),
    textShadow  = Color3.fromRGB(0, 0, 0),
    textBlack   = Color3.fromRGB(0, 0, 0),
    
    toggleOn    = Color3.fromRGB(70, 75, 85),
    toggleOff   = Color3.fromRGB(195, 200, 210),
    white       = Color3.fromRGB(255, 255, 255),
    pink        = Color3.fromRGB(255, 120, 180),
    gray        = Color3.fromRGB(140, 145, 155),
}

local TEXT_STROKE_COLOR = Color3.fromRGB(0, 0, 0)
local TEXT_STROKE_THICKNESS = 2

local function addTextStroke(textLabel, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    stroke.Color = TEXT_STROKE_COLOR
    stroke.Thickness = thickness or TEXT_STROKE_THICKNESS
    stroke.Transparency = transparency or 0
    stroke.Parent = textLabel
    return stroke
end

local ALL_MAPS = {
    "Forest","Lake","Desert","Jungle","Snow","Volcano",
    "Abyss Ocean","Prehistoric","Cosmic","Cherry Blossom",
    "Titan Temple","Light Dark",
}

local MAP_POS = {}
for _, m in ipairs(API.GetAllMaps and API.GetAllMaps() or {}) do
    MAP_POS[m.name] = m.pos
end

local old = PARENT:FindFirstChild("StealEggUI")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "StealEggUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999
sg.Parent = PARENT

-- ══════════ ICON ══════════
local icon = Instance.new("ImageButton")
icon.Size = UDim2.new(0, 44, 0, 44)
icon.Position = UDim2.new(0, 15, 0.4, 0)
icon.BackgroundColor3 = COLORS.bg
icon.BackgroundTransparency = 0.2
icon.BorderSizePixel = 0
icon.Image = ICON_ID
icon.Draggable = true
icon.Parent = sg
Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
local istk = Instance.new("UIStroke", icon)
istk.Color = COLORS.cardBorder
istk.Thickness = 2

-- ══════════ PANEL ══════════
local PANEL_WIDTH = 580
local PANEL_HEIGHT = 380

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = COLORS.bg
panel.BackgroundTransparency = 0.85
panel.BorderSizePixel = 0
panel.ClipsDescendants = false
panel.Visible = false
panel.Active = true
panel.Draggable = true
panel.Parent = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local pstk = Instance.new("UIStroke", panel)
pstk.Color = Color3.fromRGB(255, 255, 255)
pstk.Thickness = 1.5
pstk.Transparency = 0.5

local bgImg = Instance.new("ImageLabel", panel)
bgImg.Size = UDim2.new(1, 0, 1, 0)
bgImg.BackgroundTransparency = 1
bgImg.ScaleType = Enum.ScaleType.Crop
bgImg.Image = BACKGROUND_ID
bgImg.ImageTransparency = 0.1
bgImg.ZIndex = 0
Instance.new("UICorner", bgImg).CornerRadius = UDim.new(0, 14)

local topIcon = Instance.new("ImageLabel", panel)
topIcon.Size = UDim2.new(0, 32, 0, 32)
topIcon.Position = UDim2.new(0, 12, 0, 8)
topIcon.BackgroundTransparency = 1
topIcon.Image = ICON_ID
topIcon.ZIndex = 2

local titleFrame = Instance.new("Frame", panel)
titleFrame.Size = UDim2.new(1, -55, 0, 32)
titleFrame.Position = UDim2.new(0, 50, 0, 8)
titleFrame.BackgroundTransparency = 1
titleFrame.ClipsDescendants = false
titleFrame.ZIndex = 2

local titleGray = Instance.new("TextLabel", titleFrame)
titleGray.Size = UDim2.new(1, 0, 1, 0)
titleGray.Position = UDim2.new(0, 0, 0, 0)
titleGray.BackgroundTransparency = 1
titleGray.Text = "STEAL AN EGG HUB"
titleGray.Font = Enum.Font.GothamBlack
titleGray.TextSize = 17
titleGray.TextColor3 = COLORS.textBold
titleGray.TextXAlignment = Enum.TextXAlignment.Left
titleGray.ZIndex = 3
addTextStroke(titleGray, 2)

local maskFrame = Instance.new("Frame", titleFrame)
maskFrame.Size = UDim2.new(1, 0, 0, 17)
maskFrame.Position = UDim2.new(0, 0, 0, 0)
maskFrame.BackgroundTransparency = 1
maskFrame.ClipsDescendants = true
maskFrame.ZIndex = 4

local titlePink = Instance.new("TextLabel", maskFrame)
titlePink.Size = UDim2.new(1, 0, 0, 32)
titlePink.Position = UDim2.new(0, 0, 0, 0)
titlePink.BackgroundTransparency = 1
titlePink.Text = "STEAL AN EGG HUB"
titlePink.Font = Enum.Font.GothamBlack
titlePink.TextSize = 17
titlePink.TextColor3 = COLORS.pink
titlePink.TextXAlignment = Enum.TextXAlignment.Left
titlePink.ZIndex = 5
addTextStroke(titlePink, 2)

-- ══════════ SIDEBAR ══════════
local sidebar = Instance.new("Frame", panel)
sidebar.Position = UDim2.new(0, 14, 0, 48)
sidebar.Size = UDim2.new(0, 130, 1, -62)
sidebar.BackgroundColor3 = COLORS.sidebar
sidebar.BackgroundTransparency = 0.85
sidebar.BorderSizePixel = 0
sidebar.ZIndex = 2
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local sidePad = Instance.new("UIPadding", sidebar)
sidePad.PaddingTop = UDim.new(0, 6)
sidePad.PaddingLeft = UDim.new(0, 6)
sidePad.PaddingRight = UDim.new(0, 6)
sidePad.PaddingBottom = UDim.new(0, 6)

local sideLayout = Instance.new("UIListLayout", sidebar)
sideLayout.Padding = UDim.new(0, 8)

-- ══════════ CONTENT ══════════
local content = Instance.new("Frame", panel)
content.Position = UDim2.new(0, 154, 0, 48)
content.Size = UDim2.new(1, -168, 1, -62)
content.BackgroundTransparency = 1
content.ZIndex = 2

local pages = {}
local tabBtns = {}

local function setTab(id)
    for _, item in pairs(tabBtns) do
        if item.id == id then
            TweenService:Create(item.btn, TweenInfo.new(0.2), {
                BackgroundColor3 = COLORS.activeBtn, 
                BackgroundTransparency = 0.1, 
                TextColor3 = COLORS.activeText
            }):Play()
        else
            TweenService:Create(item.btn, TweenInfo.new(0.2), {
                BackgroundColor3 = COLORS.card, 
                BackgroundTransparency = 0.75, 
                TextColor3 = COLORS.textBold
            }):Play()
        end
    end
    for tid, page in pairs(pages) do page.Visible = (tid == id) end
end

-- ⭐ TAB: viền đen dày 3, không viền trắng
local function mkTab(id, text)
    local b = Instance.new("TextButton", sidebar)
    b.Size = UDim2.new(1, 0, 0, 44)
    b.BackgroundColor3 = COLORS.card
    b.BackgroundTransparency = 0.75
    b.Text = text
    b.Font = Enum.Font.GothamBlack
    b.TextSize = 15
    b.TextColor3 = COLORS.textBold
    b.AutoButtonColor = false
    b.ZIndex = 3
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    addTextStroke(b, 3)

    b.MouseButton1Click:Connect(function() setTab(id) end)
    table.insert(tabBtns, { btn = b, id = id })
    return b
end

mkTab("main", "Main")
mkTab("pet", "Pet")
mkTab("esp", "ESP")

-- ══════════ TOGGLE ROW ══════════
local function createToggleRow(parent, labelText, defaultState, hasTextBox, onToggle, onInputChanged, boxDefault)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, -4, 0, 46)
    container.BackgroundColor3 = COLORS.card
    container.BackgroundTransparency = 0.88
    container.ZIndex = 3
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(1, hasTextBox and -130 or -60, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = COLORS.textBold
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 16
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 4
    addTextStroke(lbl, 2)

    if hasTextBox then
        local box = Instance.new("TextBox", container)
        box.Size = UDim2.new(0, 60, 0, 26)
        box.Position = UDim2.new(1, -122, 0.5, -13)
        box.BackgroundColor3 = COLORS.white
        box.BackgroundTransparency = 0.1
        box.TextColor3 = COLORS.textBlack
        box.Font = Enum.Font.GothamMedium      -- ⭐ nhẹ hơn GothamBold
        box.TextSize = 13                       -- ⭐ tăng nhẹ cho dễ đọc
        box.Text = boxDefault or "1"
        box.PlaceholderText = "1"
        box.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
        box.ZIndex = 4
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

        -- ⭐ viền đen mỏng + mờ cho số dễ nhìn
        addTextStroke(box, 1, 0.35)

        box.FocusLost:Connect(function()
            local num = tonumber(box.Text)
            if num and onInputChanged then
                onInputChanged(num * 1000000)
            end
        end)
    end

    local switchBg = Instance.new("TextButton", container)
    switchBg.Size = UDim2.new(0, 46, 0, 24)
    switchBg.Position = UDim2.new(1, -54, 0.5, -12)
    switchBg.Text = ""
    switchBg.AutoButtonColor = false
    switchBg.ZIndex = 4
    Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", switchBg)
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = UDim2.new(0, 2, 0.5, -10)
    knob.BackgroundColor3 = COLORS.white
    knob.ZIndex = 5
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = defaultState or false
    local function updateVisual(instant)
        local targetColor = state and COLORS.toggleOn or COLORS.toggleOff
        local targetPos = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
        if instant then
            switchBg.BackgroundColor3 = targetColor
            knob.Position = targetPos
        else
            TweenService:Create(switchBg, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
            TweenService:Create(knob, TweenInfo.new(0.2), {Position = targetPos}):Play()
        end
    end
    updateVisual(true)

    switchBg.MouseButton1Click:Connect(function()
        state = not state
        updateVisual(false)
        if onToggle then onToggle(state) end
    end)

    return container
end

-- ══════════ DROPDOWN ══════════
local function createMultiSelectDropdown(parent, labelText, options, callback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, -4, 0, 46)
    container.BackgroundTransparency = 1
    container.ZIndex = 3

    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(0, 110, 1, 0)
    lbl.Position = UDim2.new(0, 4, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = COLORS.textBold
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3
    addTextStroke(lbl, 2)

    local dropBtn = Instance.new("TextButton", container)
    dropBtn.Size = UDim2.new(1, -120, 1, 0)
    dropBtn.Position = UDim2.new(0, 115, 0, 0)
    dropBtn.BackgroundColor3 = COLORS.card
    dropBtn.BackgroundTransparency = 0.75
    dropBtn.Text = "All Maps --"
    dropBtn.TextColor3 = COLORS.textBold
    dropBtn.Font = Enum.Font.GothamBlack
    dropBtn.TextSize = 14
    dropBtn.AutoButtonColor = false
    dropBtn.ZIndex = 4
    Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0, 8)
    addTextStroke(dropBtn, 2)

    local dropMenu = Instance.new("Frame", panel)
    dropMenu.Position = UDim2.new(0, 154 + 115, 0, 94)
    dropMenu.Size = UDim2.new(1, -168 - 119, 0, 180)
    dropMenu.BackgroundColor3 = COLORS.card
    dropMenu.BackgroundTransparency = 0.1
    dropMenu.BorderSizePixel = 0
    dropMenu.Visible = false
    dropMenu.ZIndex = 100
    Instance.new("UICorner", dropMenu).CornerRadius = UDim.new(0, 8)
    local dstk = Instance.new("UIStroke", dropMenu)
    dstk.Color = COLORS.activeBtn
    dstk.Thickness = 1.5

    local scroll = Instance.new("ScrollingFrame", dropMenu)
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.CanvasSize = UDim2.new(0, 0, 0, #options * 28)
    scroll.ZIndex = 101

    local sLayout = Instance.new("UIListLayout", scroll)
    sLayout.Padding = UDim.new(0, 2)

    local selectedMaps = {}
    for _, opt in ipairs(options) do selectedMaps[opt] = true end

    local function updateDropdownTextAndCallback()
        local count = 0
        local list = {}
        for m, sel in pairs(selectedMaps) do
            if sel then
                count = count + 1
                table.insert(list, { name = m, pos = MAP_POS[m] })
            end
        end
        if count == #options then
            dropBtn.Text = "All Maps --"
        else
            dropBtn.Text = count .. " Maps selected --"
        end
        if callback then callback(list) end
    end

    for _, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton", scroll)
        optBtn.Size = UDim2.new(1, 0, 0, 26)
        optBtn.BackgroundColor3 = selectedMaps[opt] and COLORS.sidebar or COLORS.card
        optBtn.BackgroundTransparency = 0.3
        optBtn.Text = "  " .. opt .. (selectedMaps[opt] and "  ✓" or "")
        optBtn.TextColor3 = COLORS.textBold
        optBtn.Font = Enum.Font.GothamBlack
        optBtn.TextSize = 13
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.AutoButtonColor = false
        optBtn.ZIndex = 102
        addTextStroke(optBtn, 2)

        optBtn.MouseButton1Click:Connect(function()
            selectedMaps[opt] = not selectedMaps[opt]
            optBtn.BackgroundColor3 = selectedMaps[opt] and COLORS.sidebar or COLORS.card
            optBtn.Text = "  " .. opt .. (selectedMaps[opt] and "  ✓" or "")
            updateDropdownTextAndCallback()
        end)
    end

    dropBtn.MouseButton1Click:Connect(function()
        dropMenu.Visible = not dropMenu.Visible
    end)

    return container
end

-- ══════════ TAB MAIN ══════════
local pageMain = Instance.new("ScrollingFrame", content)
pageMain.Size = UDim2.new(1, 0, 1, 0)
pageMain.BackgroundTransparency = 1
pageMain.BorderSizePixel = 0
pageMain.ScrollBarThickness = 2
pageMain.CanvasSize = UDim2.new(0, 0, 0, 240)
pageMain.ZIndex = 3
pages.main = pageMain

local mainLayout = Instance.new("UIListLayout", pageMain)
mainLayout.Padding = UDim.new(0, 8)

local mapDrop = createMultiSelectDropdown(pageMain, "Select Map", ALL_MAPS, function(list)
    API.SetTargets(list)
end)
mapDrop.LayoutOrder = 1

local bestEggToggle = createToggleRow(pageMain, "Steal Best Egg (value m)", API.IsPriorityIncome(), true, function(state)
    API.SetPriorityIncome(state)
end, function(value)
    API.SetPriorityThreshold(value)
end, "1")
bestEggToggle.LayoutOrder = 2

local bigEggToggle = createToggleRow(pageMain, "Auto Steal Big Egg", API.IsBigEggMode(), false, function(state)
    API.SetBigEggMode(state)
end, nil)
bigEggToggle.LayoutOrder = 3

local autoFarmToggle = createToggleRow(pageMain, "Auto Steal Egg", false, false, function(state)
    if state then API.Start() else API.Stop() end
end, nil)
autoFarmToggle.LayoutOrder = 4

-- ══════════ TAB PET ══════════
local pagePet = Instance.new("ScrollingFrame", content)
pagePet.Size = UDim2.new(1, 0, 1, 0)
pagePet.BackgroundTransparency = 1
pagePet.Visible = false
pagePet.BorderSizePixel = 0
pagePet.ScrollBarThickness = 2
pagePet.CanvasSize = UDim2.new(0, 0, 0, 140)
pagePet.ZIndex = 3
pages.pet = pagePet

local petLayout = Instance.new("UIListLayout", pagePet)
petLayout.Padding = UDim.new(0, 8)

local petHeader = Instance.new("TextLabel", pagePet)
petHeader.Size = UDim2.new(1, -4, 0, 26)
petHeader.BackgroundTransparency = 1
petHeader.Text = "🐾 PET MANAGER"
petHeader.TextColor3 = COLORS.pink
petHeader.Font = Enum.Font.GothamBlack
petHeader.TextSize = 14
petHeader.TextXAlignment = Enum.TextXAlignment.Left
petHeader.LayoutOrder = 1
addTextStroke(petHeader, 2)

local autoSellToggle = createToggleRow(pagePet, "Auto Sell Pet (value m)", API.SM_IsAutoSell(), true, function(state)
    API.SM_SetAutoSell(state)
    if state and not API.SM_IsRunning() then
        API.SM_Start()
    end
end, function(value)
    API.SM_SetThreshold(value)
end, "10")
autoSellToggle.LayoutOrder = 2

local autoEquipToggle = createToggleRow(pagePet, "Auto Equip Best Pet", API.SM_IsAutoEquip(), false, function(state)
    API.SM_SetAutoEquip(state)
    if state and not API.SM_IsRunning() then
        API.SM_Start()
    end
end, nil)
autoEquipToggle.LayoutOrder = 3

-- ══════════ TAB ESP ══════════
local pageESP = Instance.new("ScrollingFrame", content)
pageESP.Size = UDim2.new(1, 0, 1, 0)
pageESP.BackgroundTransparency = 1
pageESP.Visible = false
pageESP.BorderSizePixel = 0
pageESP.ScrollBarThickness = 2
pageESP.CanvasSize = UDim2.new(0, 0, 0, 60)
pageESP.ZIndex = 3
pages.esp = pageESP

local espLayout = Instance.new("UIListLayout", pageESP)
espLayout.Padding = UDim.new(0, 8)

createToggleRow(pageESP, "ESP Egg", API.ESP_IsEnabled(), false, function(state)
    if state then
        API.ESP_Enable()
    else
        API.ESP_Disable()
    end
end, nil)

-- ═══════════════════════════════════════════════════════════════
-- RESIZE BUTTON
-- ═══════════════════════════════════════════════════════════════
local resizeBtn = Instance.new("TextButton")
resizeBtn.Name = "ResizeButton"
resizeBtn.Parent = panel
resizeBtn.Size = UDim2.new(0, 28, 0, 28)
resizeBtn.Position = UDim2.new(1, -28, 1, -28)
resizeBtn.BackgroundTransparency = 1
resizeBtn.BorderSizePixel = 0
resizeBtn.Text = "◢"
resizeBtn.Font = Enum.Font.GothamBold
resizeBtn.TextSize = 18
resizeBtn.TextColor3 = Color3.fromRGB(0, 255, 230)
resizeBtn.TextTransparency = 0
resizeBtn.AutoButtonColor = false
resizeBtn.ZIndex = 100
resizeBtn.TextXAlignment = Enum.TextXAlignment.Center
resizeBtn.TextYAlignment = Enum.TextYAlignment.Center

local isResizing = false
local resizeStartPos
local resizeStartSize
local resizeInputType

local MIN_WIDTH = 450
local MIN_HEIGHT = 280

resizeBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = true
        resizeInputType = input.UserInputType
        resizeStartPos = input.Position
        resizeStartSize = panel.AbsoluteSize
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not isResizing then return end
    
    if resizeInputType == Enum.UserInputType.Touch 
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    if resizeInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end
    
    local delta = input.Position - resizeStartPos
    local newWidth = math.max(MIN_WIDTH, resizeStartSize.X + delta.X)
    local newHeight = math.max(MIN_HEIGHT, resizeStartSize.Y + delta.Y)
    
    panel.Size = UDim2.new(0, newWidth, 0, newHeight)
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = false
        resizeInputType = nil
    end
end)

UserInputService.TouchEnded:Connect(function(input)
    if isResizing then
        isResizing = false
        resizeInputType = nil
    end
end)

resizeBtn.MouseEnter:Connect(function()
    TweenService:Create(resizeBtn, TweenInfo.new(0.15), {
        TextColor3 = Color3.fromRGB(255, 255, 255)
    }):Play()
end)

resizeBtn.MouseLeave:Connect(function()
    TweenService:Create(resizeBtn, TweenInfo.new(0.15), {
        TextColor3 = Color3.fromRGB(0, 255, 230)
    }):Play()
end)

-- ══════════ INIT ══════════
setTab("main")

local initList = {}
for _, m in ipairs(ALL_MAPS) do
    if MAP_POS[m] then table.insert(initList, { name = m, pos = MAP_POS[m] }) end
end
API.SetTargets(initList)

icon.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
    if panel.Visible then
        panel.Size = UDim2.new(0, 100, 0, 60)
        panel.BackgroundTransparency = 1
        TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT),
            BackgroundTransparency = 0.85
        }):Play()
    end
end)

API.OnLog(function(msg) print("[StealEgg] " .. msg) end)
if API.SM_OnLog then
    API.SM_OnLog(function(msg) print("[SellManager] " .. msg) end)
end

print("[Main] ✅ Ready v3.8.1 — Số ô nhập nhẹ & dễ nhìn")
