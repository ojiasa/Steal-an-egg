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
    GetAllMaps = function() return Steal and Steal.getAllMaps() or {} end,
    OnLog = function(cb) if Steal then Steal.onLog(cb) end end,

    SetPriorityIncome = function(on) if Steal then return Steal.setPriorityIncome(on) end end,
    IsPriorityIncome = function() return Steal and Steal.isPriorityIncome() or false end,
    TogglePriorityIncome = function() if Steal then return Steal.togglePriorityIncome() end end,
    SetPriorityThreshold = function(n) if Steal then Steal.setPriorityThreshold(n) end end,
    GetPriorityThreshold = function() return Steal and Steal.getPriorityThreshold() or 1000000 end,
    ClearIncomeCache = function() if Steal then Steal.clearIncomeCache() end end,

    ESP_Enable = function() if ESP then ESP.enable() end end,
    ESP_Disable = function() if ESP then ESP.disable() end end,
    ESP_Toggle = function() if ESP then return ESP.toggle() end end,
    ESP_IsEnabled = function() return ESP and ESP.isEnabled() or false end,
    ESP_SetMapFilter = function(list) if ESP then ESP.setMapFilter(list) end end,

    Version = "2.1.0",
}
local API = _G.StealEgg
_G.MyScript = API

local P = game:GetService("Players").LocalPlayer
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local function getParent()
    local ok = pcall(function()
        local t = Instance.new("Folder"); t.Parent = CoreGui; t:Destroy()
    end)
    return ok and CoreGui or P:WaitForChild("PlayerGui")
end
local PARENT = getParent()

local COLORS = {
    bg      = Color3.fromRGB(12, 14, 22),
    bg2     = Color3.fromRGB(18, 22, 32),
    bg3     = Color3.fromRGB(28, 34, 48),
    accent  = Color3.fromRGB(0, 220, 255),
    accent2 = Color3.fromRGB(0, 160, 220),
    text    = Color3.fromRGB(220, 240, 255),
    textDim = Color3.fromRGB(150, 180, 200),
    green   = Color3.fromRGB(0, 200, 120),
    red     = Color3.fromRGB(220, 60, 80),
    purple  = Color3.fromRGB(120, 90, 220),
    gold    = Color3.fromRGB(255, 200, 50),
}

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

-- Floating Icon
local icon = Instance.new("ImageButton")
icon.Size = UDim2.new(0, 50, 0, 50)
icon.Position = UDim2.new(0, 20, 0.5, -25)
icon.BackgroundColor3 = COLORS.bg
icon.BorderSizePixel = 0
icon.Image = ICON_ID
icon.Draggable = true
icon.Parent = sg
Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
local istk = Instance.new("UIStroke", icon)
istk.Color = COLORS.accent
istk.Thickness = 2.5

icon.MouseEnter:Connect(function()
    TweenService:Create(icon, TweenInfo.new(0.2), {Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0, 17, 0.5, -28)}):Play()
end)
icon.MouseLeave:Connect(function()
    TweenService:Create(icon, TweenInfo.new(0.2), {Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 20, 0.5, -25)}):Play()
end)

-- Main Panel
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 480, 0, 400)
panel.Position = UDim2.new(0.5, -240, 0.5, -200)
panel.BackgroundColor3 = COLORS.bg
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Visible = false
panel.Active = true
panel.Draggable = true
panel.Parent = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local pstk = Instance.new("UIStroke", panel)
pstk.Color = COLORS.accent
pstk.Thickness = 1.5
pstk.Transparency = 0.3

local bgImg = Instance.new("ImageLabel", panel)
bgImg.Size = UDim2.new(1, 0, 1, 0)
bgImg.BackgroundTransparency = 1
bgImg.ScaleType = Enum.ScaleType.Crop
bgImg.Image = BACKGROUND_ID
bgImg.ImageTransparency = 0.5
bgImg.ZIndex = 0
Instance.new("UICorner", bgImg).CornerRadius = UDim.new(0, 14)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -20, 0, 36)
title.Position = UDim2.new(0, 16, 0, 6)
title.BackgroundTransparency = 1
title.Text = "ＳＴＥＡＬ  ＥＧＧ  ＨＵＢ"
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = COLORS.accent
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 2

task.spawn(function()
    local hue = 0
    while title and title.Parent do
        hue = (hue + 0.003) % 1
        title.TextColor3 = Color3.fromHSV(hue, 0.5, 1)
        task.wait(0.05)
    end
end)

-- Sidebar (Cột trái)
local sidebar = Instance.new("Frame", panel)
sidebar.Position = UDim2.new(0, 12, 0, 46)
sidebar.Size = UDim2.new(0, 120, 1, -58)
sidebar.BackgroundColor3 = COLORS.bg2
sidebar.BackgroundTransparency = 0.4
sidebar.BorderSizePixel = 0
sidebar.ZIndex = 2
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local sidePad = Instance.new("UIPadding", sidebar)
sidePad.PaddingTop = UDim.new(0, 8)
sidePad.PaddingLeft = UDim.new(0, 6)
sidePad.PaddingRight = UDim.new(0, 6)
sidePad.PaddingBottom = UDim.new(0, 8)

local sideLayout = Instance.new("UIListLayout", sidebar)
sideLayout.Padding = UDim.new(0, 6)

-- Content (Cột phải)
local content = Instance.new("Frame", panel)
content.Position = UDim2.new(0, 140, 0, 46)
content.Size = UDim2.new(1, -152, 1, -58)
content.BackgroundTransparency = 1
content.ZIndex = 2

-- Quản lý Tab
local currentTab = "main"
local pages = {}
local tabBtns = {}

local function setTab(id)
    currentTab = id
    for _, item in pairs(tabBtns) do
        if item.id == id then
            TweenService:Create(item.btn, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.accent2, TextColor3 = Color3.new(1,1,1)}):Play()
        else
            TweenService:Create(item.btn, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.bg3, TextColor3 = COLORS.text}):Play()
        end
    end
    for tid, page in pairs(pages) do page.Visible = (tid == id) end
end

local function mkTab(id, text)
    local b = Instance.new("TextButton", sidebar)
    b.Size = UDim2.new(1, 0, 0, 36)
    b.BackgroundColor3 = COLORS.bg3
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.TextColor3 = COLORS.text
    b.AutoButtonColor = false
    b.ZIndex = 3
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(function() setTab(id) end)
    table.insert(tabBtns, { btn = b, id = id })
    return b
end

mkTab("main", "🏠 Main")
mkTab("esp",  "👁 ESP")

-- ══════════ TẠO HÀM COMPONENT CHUẨN (TOGGLE SWITCH & DROPDOWN) ══════════

local function createToggle(parent, labelText, defaultState, callback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, -10, 0, 40)
    container.BackgroundColor3 = COLORS.bg2
    container.BackgroundTransparency = 0.3
    container.ZIndex = 3
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = COLORS.text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 4

    local switchBg = Instance.new("TextButton", container)
    switchBg.Size = UDim2.new(0, 44, 0, 22)
    switchBg.Position = UDim2.new(1, -54, 0.5, -11)
    switchBg.Text = ""
    switchBg.AutoButtonColor = false
    switchBg.ZIndex = 4
    Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", switchBg)
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.ZIndex = 5
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = defaultState or false
    local function updateVisual(instant)
        local targetColor = state and COLORS.green or COLORS.bg3
        local targetPos = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
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
        if callback then callback(state) end
    end)

    return container
end

local function createDropdown(parent, labelText, options, defaultOption, callback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, -10, 0, 60)
    container.BackgroundTransparency = 1
    container.ZIndex = 3

    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.Text = labelText
    lbl.TextColor3 = COLORS.textDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3

    local dropBtn = Instance.new("TextButton", container)
    dropBtn.Size = UDim2.new(1, 0, 0, 32)
    dropBtn.Position = UDim2.new(0, 0, 0, 22)
    dropBtn.BackgroundColor3 = COLORS.bg2
    dropBtn.Text = "  " .. (defaultOption or options[1] or "Select...") .. "  ▼"
    dropBtn.TextColor3 = COLORS.text
    dropBtn.Font = Enum.Font.GothamBold
    dropBtn.TextSize = 11
    dropBtn.TextXAlignment = Enum.TextXAlignment.Left
    dropBtn.AutoButtonColor = false
    dropBtn.ZIndex = 4
    Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0, 8)

    local listFrame = Instance.new("ScrollingFrame", parent.Parent.Parent) -- nổi lên trên cùng của panel
    listFrame.Size = UDim2.new(0, 200, 0, 130)
    listFrame.BackgroundColor3 = COLORS.bg3
    listFrame.BorderSizePixel = 0
    listFrame.ScrollBarThickness = 3
    listFrame.ScrollBarImageColor3 = COLORS.accent
    listFrame.Visible = false
    listFrame.ZIndex = 99
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", listFrame).Color = COLORS.accent

    local lLayout = Instance.new("UIListLayout", listFrame)
    lLayout.Padding = UDim.new(0, 2)

    for _, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton", listFrame)
        optBtn.Size = UDim2.new(1, 0, 0, 28)
        optBtn.BackgroundColor3 = COLORS.bg2
        optBtn.Text = "  " .. opt
        optBtn.TextColor3 = COLORS.text
        optBtn.Font = Enum.Font.Gotham
        optBtn.TextSize = 11
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.AutoButtonColor = false
        optBtn.ZIndex = 100

        optBtn.MouseButton1Click:Connect(function()
            dropBtn.Text = "  " .. opt .. "  ▼"
            listFrame.Visible = false
            if callback then callback(opt) end
        end)
    end
    listFrame.CanvasSize = UDim2.new(0, 0, 0, #options * 30)

    dropBtn.MouseButton1Click:Connect(function()
        listFrame.Visible = not listFrame.Visible
        if listFrame.Visible then
            local absPos = dropBtn.AbsolutePosition
            listFrame.Position = UDim2.new(0, absPos.X, 0, absPos.Y + 36)
        end
    end)

    return container
end

-- ══════════ PAGE MAIN ══════════
local pageMain = Instance.new("ScrollingFrame", content)
pageMain.Size = UDim2.new(1, 0, 1, 0)
pageMain.BackgroundTransparency = 1
pageMain.BorderSizePixel = 0
pageMain.ScrollBarThickness = 3
pageMain.ScrollBarImageColor3 = COLORS.accent
pageMain.CanvasSize = UDim2.new(0, 0, 0, 320)
pageMain.ZIndex = 3
pages.main = pageMain

local mainLayout = Instance.new("UIListLayout", pageMain)
mainLayout.Padding = UDim.new(0, 10)
local mainPad = Instance.new("UIPadding", pageMain)
mainPad.PaddingTop = UDim.new(0, 4)
mainPad.PaddingLeft = UDim.new(0, 2)

-- 1. Toggle Auto Farm
createToggle(pageMain, "🤖 AUTO FARM", false, function(state)
    if state then
        API.Start()
    else
        API.Stop()
    end
end)

-- 2. Toggle Priority Income
createToggle(pageMain, "💰 ƯU TIÊN TIỀN CAO (min $1M/s)", API.IsPriorityIncome(), function(state)
    API.SetPriorityIncome(state)
end)

-- 3. Dropdown Chọn Map (Thay thế Select Map cũ cực gọn)
createDropdown(pageMain, "🎯 CHỌN MAP FARM", ALL_MAPS, "All Maps", function(selected)
    if selected == "All Maps" then
        local list = {}
        for _, m in ipairs(ALL_MAPS) do
            if MAP_POS[m] then table.insert(list, { name = m, pos = MAP_POS[m] }) end
        end
        API.SetTargets(list)
    else
        if MAP_POS[selected] then
            API.SetTargets({ { name = selected, pos = MAP_POS[selected] } })
        end
    end
end)

-- 4. Set Home / Forest Buttons
local tpFrame = Instance.new("Frame", pageMain)
tpFrame.Size = UDim2.new(1, -10, 0, 36)
tpFrame.BackgroundTransparency = 1
tpFrame.ZIndex = 3

local homeBtn = Instance.new("TextButton", tpFrame)
homeBtn.Size = UDim2.new(0.5, -4, 1, 0)
homeBtn.BackgroundColor3 = COLORS.bg3
homeBtn.Text = "📍 SET HOME"
homeBtn.TextColor3 = COLORS.text
homeBtn.Font = Enum.Font.GothamBold
homeBtn.TextSize = 11
homeBtn.AutoButtonColor = false
homeBtn.ZIndex = 3
Instance.new("UICorner", homeBtn).CornerRadius = UDim.new(0, 8)

local forestBtn = Instance.new("TextButton", tpFrame)
forestBtn.Size = UDim2.new(0.5, -4, 1, 0)
forestBtn.Position = UDim2.new(0.5, 4, 0, 0)
forestBtn.BackgroundColor3 = COLORS.bg3
forestBtn.Text = "📍 SET FOREST"
forestBtn.TextColor3 = COLORS.text
forestBtn.Font = Enum.Font.GothamBold
forestBtn.TextSize = 11
forestBtn.AutoButtonColor = false
forestBtn.ZIndex = 3
Instance.new("UICorner", forestBtn).CornerRadius = UDim.new(0, 8)

homeBtn.MouseButton1Click:Connect(function()
    local hrp = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
    if hrp then API.SetHome(hrp.Position) end
end)
forestBtn.MouseButton1Click:Connect(function()
    local hrp = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
    if hrp then API.SetForest(hrp.Position) end
end)

-- ══════════ PAGE ESP ══════════
local pageESP = Instance.new("ScrollingFrame", content)
pageESP.Size = UDim2.new(1, 0, 1, 0)
pageESP.BackgroundTransparency = 1
pageESP.Visible = false
pageESP.BorderSizePixel = 0
pageESP.ScrollBarThickness = 3
pageESP.ScrollBarImageColor3 = COLORS.accent
pageESP.CanvasSize = UDim2.new(0, 0, 0, 100)
pageESP.ZIndex = 3
pages.esp = pageESP

local espLayout = Instance.new("UIListLayout", pageESP)
espLayout.Padding = UDim.new(0, 10)
local espPad = Instance.new("UIPadding", pageESP)
espPad.PaddingTop = UDim.new(0, 4)
espPad.PaddingLeft = UDim.new(0, 2)

createToggle(pageESP, "👁 BẬT ESP EGG", API.ESP_IsEnabled(), function(state)
    API.ESP_Toggle()
end)

-- ══════════ INIT KẾT NỐI ══════════
setTab("main")

local initList = {}
for _, m in ipairs(ALL_MAPS) do
    if MAP_POS[m] then table.insert(initList, { name = m, pos = MAP_POS[m] }) end
end
API.SetTargets(initList)

icon.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
    if panel.Visible then
        panel.Size = UDim2.new(0, 150, 0, 120)
        panel.BackgroundTransparency = 1
        TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 480, 0, 400),
            BackgroundTransparency = 0.2
        }):Play()
    end
end)

API.OnLog(function(msg) print("[StealEgg] " .. msg) end)

print("[Main] ✅ Ready v2.1 - Sidebar & Toggle Switch UI")

