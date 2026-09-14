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

    Version = "2.0.0",
}
local API = _G.StealEgg
_G.MyScript = API

local P = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")
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

-- Icon
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

-- Panel
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 480, 0, 420)
panel.Position = UDim2.new(0.5, -240, 0.5, -210)
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

-- Sidebar
local sidebar = Instance.new("Frame", panel)
sidebar.Position = UDim2.new(0, 12, 0, 46)
sidebar.Size = UDim2.new(0, 115, 1, -58)
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
sideLayout.Parent = sidebar

-- Content
local content = Instance.new("Frame", panel)
content.Position = UDim2.new(0, 135, 0, 46)
content.Size = UDim2.new(1, -147, 1, -58)
content.BackgroundTransparency = 1
content.ZIndex = 2

-- Tabs logic
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
    b.TextColor3 = COLORS.text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = false
    b.ZIndex = 3
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(function() setTab(id) end)
    table.insert(tabBtns, { btn = b, id = id })
    return b
end

mkTab("main", "🏠 Main")
mkTab("esp",  "👁 ESP")

-- ══════════ PAGE MAIN ══════════
local pageMain = Instance.new("ScrollingFrame", content)
pageMain.Size = UDim2.new(1, 0, 1, 0)
pageMain.BackgroundTransparency = 1
pageMain.BorderSizePixel = 0
pageMain.ScrollBarThickness = 3
pageMain.ScrollBarImageColor3 = COLORS.accent
pageMain.CanvasSize = UDim2.new(0, 0, 0, 430)
pageMain.ZIndex = 3
pages.main = pageMain

local function mkLabel(parent, text, y)
    local l = Instance.new("TextLabel", parent)
    l.Size = UDim2.new(1, -10, 0, 18)
    l.Position = UDim2.new(0, 0, 0, y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = COLORS.textDim
    l.Font = Enum.Font.GothamBold
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 3
    return l
end

mkLabel(pageMain, "🤖 AUTO FARM", 0)

local farmBtn = Instance.new("TextButton", pageMain)
farmBtn.Size = UDim2.new(1, -10, 0, 36)
farmBtn.Position = UDim2.new(0, 0, 0, 20)
farmBtn.BackgroundColor3 = COLORS.green
farmBtn.Text = "▶  BẮT ĐẦU FARM"
farmBtn.TextColor3 = Color3.new(0,0,0)
farmBtn.Font = Enum.Font.GothamBold
farmBtn.TextSize = 12
farmBtn.AutoButtonColor = false
farmBtn.ZIndex = 3
Instance.new("UICorner", farmBtn).CornerRadius = UDim.new(0, 8)

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

mkLabel(pageMain, "💰 ƯU TIÊN TIỀN CAO", 64)

local prioBtn = Instance.new("TextButton", pageMain)
prioBtn.Size = UDim2.new(1, -10, 0, 36)
prioBtn.Position = UDim2.new(0, 0, 0, 84)
prioBtn.BackgroundColor3 = COLORS.bg3
prioBtn.Text = "💰 Ưu tiên tiền cao: TẮT (min $1M/s)"
prioBtn.TextColor3 = COLORS.text
prioBtn.Font = Enum.Font.GothamBold
prioBtn.TextSize = 11
prioBtn.AutoButtonColor = false
prioBtn.ZIndex = 3
Instance.new("UICorner", prioBtn).CornerRadius = UDim.new(0, 8)

prioBtn.MouseButton1Click:Connect(function()
    local on = not API.IsPriorityIncome()
    API.SetPriorityIncome(on)
    if on then
        prioBtn.Text = "💰 Ưu tiên tiền cao: BẬT (min $1M/s)"
        prioBtn.BackgroundColor3 = COLORS.gold
        prioBtn.TextColor3 = Color3.new(0, 0, 0)
    else
        prioBtn.Text = "💰 Ưu tiên tiền cao: TẮT (min $1M/s)"
        prioBtn.BackgroundColor3 = COLORS.bg3
        prioBtn.TextColor3 = COLORS.text
    end
end)

mkLabel(pageMain, "💵 Ngưỡng tối thiểu (M/s)", 128)

local threshBox = Instance.new("TextBox", pageMain)
threshBox.Size = UDim2.new(1, -10, 0, 32)
threshBox.Position = UDim2.new(0, 0, 0, 148)
threshBox.BackgroundColor3 = COLORS.bg2
threshBox.Text = "1"
threshBox.TextColor3 = COLORS.text
threshBox.Font = Enum.Font.GothamBold
threshBox.TextSize = 12
threshBox.PlaceholderText = "1"
threshBox.ZIndex = 3
Instance.new("UICorner", threshBox).CornerRadius = UDim.new(0, 8)

threshBox.FocusLost:Connect(function()
    local n = tonumber(threshBox.Text) or 1
    n = math.max(n, 0)
    API.SetPriorityThreshold(n * 1e6)
    threshBox.Text = tostring(n)
end)

mkLabel(pageMain, "🎯 CHỌN MAP FARM (multi)", 190)

local mapSelectBtn = Instance.new("TextButton", pageMain)
mapSelectBtn.Size = UDim2.new(1, -10, 0, 32)
mapSelectBtn.Position = UDim2.new(0, 0, 0, 210)
mapSelectBtn.BackgroundColor3 = COLORS.bg3
mapSelectBtn.Text = "All Maps  ▼"
mapSelectBtn.TextColor3 = COLORS.text
mapSelectBtn.Font = Enum.Font.GothamBold
mapSelectBtn.TextSize = 11
mapSelectBtn.AutoButtonColor = false
mapSelectBtn.ZIndex = 3
Instance.new("UICorner", mapSelectBtn).CornerRadius = UDim.new(0, 8)

local mapScroll = Instance.new("ScrollingFrame", pageMain)
mapScroll.Size = UDim2.new(1, -10, 0, 130)
mapScroll.Position = UDim2.new(0, 0, 0, 246)
mapScroll.BackgroundColor3 = COLORS.bg2
mapScroll.BorderSizePixel = 0
mapScroll.ScrollBarThickness = 3
mapScroll.ScrollBarImageColor3 = COLORS.accent
mapScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
mapScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mapScroll.Visible = false
mapScroll.ZIndex = 5
Instance.new("UICorner", mapScroll).CornerRadius = UDim.new(0, 8)

local mPad = Instance.new("UIPadding", mapScroll)
mPad.PaddingTop = UDim.new(0, 4)
mPad.PaddingLeft = UDim.new(0, 4)
mPad.PaddingRight = UDim.new(0, 4)
mPad.PaddingBottom = UDim.new(0, 4)

local mLayout = Instance.new("UIListLayout", mapScroll)
mLayout.Padding = UDim.new(0, 3)

local selectedMaps = {}
local mapRowBtns = {}
for _, m in ipairs(ALL_MAPS) do selectedMaps[m] = true end

local allBtn = Instance.new("TextButton", mapScroll)
allBtn.Size = UDim2.new(1, -8, 0, 24)
allBtn.BackgroundColor3 = COLORS.accent2
allBtn.Text = "  ✓ ALL MAPS"
allBtn.TextColor3 = Color3.new(1,1,1)
allBtn.Font = Enum.Font.GothamBold
allBtn.TextSize = 10
allBtn.TextXAlignment = Enum.TextXAlignment.Left
allBtn.AutoButtonColor = false
allBtn.ZIndex = 6
Instance.new("UICorner", allBtn).CornerRadius = UDim.new(0, 6)

allBtn.MouseButton1Click:Connect(function()
    for _, m in ipairs(ALL_MAPS) do selectedMaps[m] = true end
    allBtn.BackgroundColor3 = COLORS.accent2
    for _, item in ipairs(mapRowBtns) do
        item.btn.BackgroundColor3 = COLORS.accent2
        item.btn.Text = "  ✓ " .. item.name
    end
    local list = {}
    for _, m in ipairs(ALL_MAPS) do
        if MAP_POS[m] then table.insert(list, { name = m, pos = MAP_POS[m] }) end
    end
    API.SetTargets(list)
    mapSelectBtn.Text = "All Maps  ▼"
end)

for _, m in ipairs(ALL_MAPS) do
    local b = Instance.new("TextButton", mapScroll)
    b.Size = UDim2.new(1, -8, 0, 24)
    b.BackgroundColor3 = COLORS.accent2
    b.Text = "  ✓ " .. m
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = false
    b.ZIndex = 6
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

    table.insert(mapRowBtns, { btn = b, name = m })

    b.MouseButton1Click:Connect(function()
        if selectedMaps[m] then
            selectedMaps[m] = nil
            b.BackgroundColor3 = COLORS.bg3
            b.Text = "    " .. m
        else
            selectedMaps[m] = true
            b.BackgroundColor3 = COLORS.accent2
            b.Text = "  ✓ " .. m
        end
        local count = 0
        local list = {}
        for _, name in ipairs(ALL_MAPS) do
            if selectedMaps[name] and MAP_POS[name] then
                count = count + 1
                table.insert(list, { name = name, pos = MAP_POS[name] })
            end
        end
        if count == #ALL_MAPS then
            mapSelectBtn.Text = "All Maps  ▼"
            allBtn.BackgroundColor3 = COLORS.accent2
        else
            mapSelectBtn.Text = count .. " Maps  ▼"
        end
        API.SetTargets(list)
    end)
end

mapSelectBtn.MouseButton1Click:Connect(function()
    mapScroll.Visible = not mapScroll.Visible
end)

-- Home & Forest buttons
local homeBtn = Instance.new("TextButton", pageMain)
homeBtn.Size = UDim2.new(0.5, -7, 0, 30)
homeBtn.Position = UDim2.new(0, 0, 0, 382)
homeBtn.BackgroundColor3 = COLORS.bg3
homeBtn.Text = "📍 SET HOME"
homeBtn.TextColor3 = COLORS.text
homeBtn.Font = Enum.Font.GothamBold
homeBtn.TextSize = 10
homeBtn.AutoButtonColor = false
homeBtn.ZIndex = 3
Instance.new("UICorner", homeBtn).CornerRadius = UDim.new(0, 8)

local forestBtn = Instance.new("TextButton", pageMain)
forestBtn.Size = UDim2.new(0.5, -7, 0, 30)
forestBtn.Position = UDim2.new(0.5, 3, 0, 382)
forestBtn.BackgroundColor3 = COLORS.bg3
forestBtn.Text = "📍 SET FOREST"
forestBtn.TextColor3 = COLORS.text
forestBtn.Font = Enum.Font.GothamBold
forestBtn.TextSize = 10
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
local pageESP = Instance.new("Frame", content)
pageESP.Size = UDim2.new(1, 0, 1, 0)
pageESP.BackgroundTransparency = 1
pageESP.Visible = false
pageESP.ZIndex = 3
pages.esp = pageESP

mkLabel(pageESP, "👁 ESP EGG", 0)

local espBtn = Instance.new("TextButton", pageESP)
espBtn.Size = UDim2.new(1, -10, 0, 36)
espBtn.Position = UDim2.new(0, 0, 0, 20)
espBtn.BackgroundColor3 = COLORS.purple
espBtn.Text = "👁  BẬT ESP EGG"
espBtn.TextColor3 = Color3.new(1,1,1)
espBtn.Font = Enum.Font.GothamBold
espBtn.TextSize = 12
espBtn.AutoButtonColor = false
espBtn.ZIndex = 3
Instance.new("UICorner", espBtn).CornerRadius = UDim.new(0, 8)

espBtn.MouseButton1Click:Connect(function()
    local on = API.ESP_Toggle()
    if on then
        espBtn.Text = "👁  TẮT ESP EGG"
        espBtn.BackgroundColor3 = COLORS.red
    else
        espBtn.Text = "👁  BẬT ESP EGG"
        espBtn.BackgroundColor3 = COLORS.purple
    end
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
        panel.Size = UDim2.new(0, 150, 0, 120)
        panel.BackgroundTransparency = 1
        TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 480, 0, 420),
            BackgroundTransparency = 0.2
        }):Play()
    end
end)

API.OnLog(function(msg) print("[StealEgg] " .. msg) end)

print("[Main] ✅ Ready v6 (Optimized & Beautified)")

