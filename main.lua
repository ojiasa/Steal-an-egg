-- ═══════════════════════════════════════════════════════════════
-- MAIN.LUA v5 — UI style Shadow Glade (2 tab, multi-select map)
-- ═══════════════════════════════════════════════════════════════

local BASE = "https://raw.githubusercontent.com/ojiasa/Steal-an-egg/main"
local FALLBACK = "https://cdn.jsdelivr.net/gh/ojiasa/Steal-an-egg@main"

local function fetch(p)
    for _, url in ipairs({ BASE .. "/" .. p, FALLBACK .. "/" .. p }) do
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if ok and src and #src > 100 then
            local fn = loadstring(src, "=" .. p)
            if fn then
                local s, r = pcall(fn)
                if s then return r end
            end
        end
    end
    warn("[Main] ❌ " .. p)
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

-- Parent
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

-- ══════════ UI ══════════
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
icon.Image = "rbxassetid://86285862396979"
icon.Draggable = true
icon.Parent = sg
Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
local istk = Instance.new("UIStroke", icon)
istk.Color = COLORS.accent
istk.Thickness = 2.5

-- Panel
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 480, 0, 340)
panel.Position = UDim2.new(0.5, -240, 0.5, -170)
panel.BackgroundColor3 = COLORS.bg
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Visible = false
panel.Active = true
panel.Draggable = true
panel.Parent = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local pstk = Instance.new("UIStroke", panel)
pstk.Color = COLORS.accent
pstk.Thickness = 1.8

-- Background image
local bgImg = Instance.new("ImageLabel", panel)
bgImg.Size = UDim2.new(1, 0, 1, 0)
bgImg.BackgroundTransparency = 1
bgImg.ScaleType = Enum.ScaleType.Crop
bgImg.Image = "rbxassetid://116222439691339"
bgImg.ImageTransparency = 0.45
bgImg.ZIndex = 0
Instance.new("UICorner", bgImg).CornerRadius = UDim.new(0, 12)

-- Title
local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -20, 0, 32)
title.Position = UDim2.new(0, 15, 0, 4)
title.BackgroundTransparency = 1
title.Text = "ＳＴＥＡＬ  ＥＧＧ  ＨＵＢ"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = COLORS.accent
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 2

-- Sidebar
local sidebar = Instance.new("Frame", panel)
sidebar.Position = UDim2.new(0, 12, 0, 42)
sidebar.Size = UDim2.new(0, 110, 1, -55)
sidebar.BackgroundColor3 = COLORS.bg2
sidebar.BackgroundTransparency = 0.3
sidebar.BorderSizePixel = 0
sidebar.ZIndex = 2
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)

local sidePad = Instance.new("UIPadding", sidebar)
sidePad.PaddingTop = UDim.new(0, 8)
sidePad.PaddingLeft = UDim.new(0, 6)
sidePad.PaddingRight = UDim.new(0, 6)
sidePad.PaddingBottom = UDim.new(0, 8)

local sideLayout = Instance.new("UIListLayout", sidebar)
sideLayout.Padding = UDim.new(0, 6)
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
sideLayout.Parent = sidebar

-- Content
local content = Instance.new("Frame", panel)
content.Position = UDim2.new(0, 130, 0, 42)
content.Size = UDim2.new(1, -142, 1, -55)
content.BackgroundTransparency = 1
content.ZIndex = 2

-- ══════════ TABS ══════════
local currentTab = "main"
local pages = {}

local tabBtns = {}

local function setTab(id)
    currentTab = id
    for _, item in pairs(tabBtns) do
        if item.id == id then
            item.btn.BackgroundColor3 = COLORS.accent2
            item.btn.TextColor3 = Color3.new(1,1,1)
        else
            item.btn.BackgroundColor3 = COLORS.bg3
            item.btn.TextColor3 = COLORS.text
        end
    end
    for tid, page in pairs(pages) do
        page.Visible = (tid == id)
    end
end

local function mkTab(id, text)
    local b = Instance.new("TextButton", sidebar)
    b.Size = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = COLORS.bg3
    b.Text = text
    b.TextColor3 = COLORS.text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.AutoButtonColor = false
    b.ZIndex = 3
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function() setTab(id) end)
    table.insert(tabBtns, { btn = b, id = id })
    return b
end

mkTab("main", "🏠 Main")
mkTab("esp",  "👁 ESP")

-- ══════════ PAGE MAIN ══════════
local pageMain = Instance.new("Frame", content)
pageMain.Size = UDim2.new(1, 0, 1, 0)
pageMain.BackgroundTransparency = 1
pageMain.ZIndex = 3
pages.main = pageMain

local function mkLabel(parent, text, y, h)
    local l = Instance.new("TextLabel", parent)
    l.Size = UDim2.new(1, 0, 0, h or 18)
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

-- Select map
mkLabel(pageMain, "🎯 CHỌN MAP FARM (multi)", 0, 18)

local mapSelectBtn = Instance.new("TextButton", pageMain)
mapSelectBtn.Size = UDim2.new(1, 0, 0, 30)
mapSelectBtn.Position = UDim2.new(0, 0, 0, 20)
mapSelectBtn.BackgroundColor3 = COLORS.bg3
mapSelectBtn.Text = "All Maps  ▼"
mapSelectBtn.TextColor3 = COLORS.text
mapSelectBtn.Font = Enum.Font.GothamBold
mapSelectBtn.TextSize = 11
mapSelectBtn.AutoButtonColor = false
mapSelectBtn.ZIndex = 3
Instance.new("UICorner", mapSelectBtn).CornerRadius = UDim.new(0, 6)

-- Map list (ẩn)
local mapScroll = Instance.new("ScrollingFrame", pageMain)
mapScroll.Size = UDim2.new(1, 0, 0, 130)
mapScroll.Position = UDim2.new(0, 0, 0, 54)
mapScroll.BackgroundColor3 = COLORS.bg2
mapScroll.BorderSizePixel = 0
mapScroll.ScrollBarThickness = 3
mapScroll.ScrollBarImageColor3 = COLORS.accent
mapScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
mapScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mapScroll.Visible = false
mapScroll.ZIndex = 5
Instance.new("UICorner", mapScroll).CornerRadius = UDim.new(0, 6)

local mPad = Instance.new("UIPadding", mapScroll)
mPad.PaddingTop = UDim.new(0, 4)
mPad.PaddingLeft = UDim.new(0, 4)
mPad.PaddingRight = UDim.new(0, 4)
mPad.PaddingBottom = UDim.new(0, 4)

local mLayout = Instance.new("UIListLayout", mapScroll)
mLayout.Padding = UDim.new(0, 3)

-- State
local selectedMaps = {}   -- {[name] = true}
local allSelected = true

local mapRowBtns = {}

-- "All" button
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
Instance.new("UICorner", allBtn).CornerRadius = UDim.new(0, 4)

allBtn.MouseButton1Click:Connect(function()
    allSelected = true
    selectedMaps = {}
    for _, m in ipairs(ALL_MAPS) do selectedMaps[m] = true end
    allBtn.BackgroundColor3 = COLORS.accent2
    for _, item in ipairs(mapRowBtns) do
        item.btn.BackgroundColor3 = COLORS.accent2
    end
    -- Apply
    local list = {}
    for _, m in ipairs(ALL_MAPS) do
        if MAP_POS[m] then table.insert(list, { name = m, pos = MAP_POS[m] }) end
    end
    API.SetTargets(list)
    mapSelectBtn.Text = "All Maps  ▼"
end)

-- Init all selected
for _, m in ipairs(ALL_MAPS) do selectedMaps[m] = true end

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
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)

    table.insert(mapRowBtns, { btn = b, name = m })

    b.MouseButton1Click:Connect(function()
        if selectedMaps[m] then
            selectedMaps[m] = nil
            b.BackgroundColor3 = COLORS.bg3
            b.Text = "    " .. m
            allSelected = false
            allBtn.BackgroundColor3 = COLORS.bg3
        else
            selectedMaps[m] = true
            b.BackgroundColor3 = COLORS.accent2
            b.Text = "  ✓ " .. m
        end
        -- Update select btn text
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
            allSelected = true
            allBtn.BackgroundColor3 = COLORS.accent2
        else
            mapSelectBtn.Text = count .. " Maps  ▼"
        end
        API.SetTargets(list)
    end)
end

-- Toggle map list
mapSelectBtn.MouseButton1Click:Connect(function()
    mapScroll.Visible = not mapScroll.Visible
end)

-- Auto farm toggle
mkLabel(pageMain, "🤖 AUTO FARM", 190, 18)

local farmBtn = Instance.new("TextButton", pageMain)
farmBtn.Size = UDim2.new(1, 0, 0, 34)
farmBtn.Position = UDim2.new(0, 0, 0, 210)
farmBtn.BackgroundColor3 = COLORS.green
farmBtn.Text = "▶  BẬT AUTO FARM"
farmBtn.TextColor3 = Color3.new(0,0,0)
farmBtn.Font = Enum.Font.GothamBold
farmBtn.TextSize = 12
farmBtn.AutoButtonColor = false
farmBtn.ZIndex = 3
Instance.new("UICorner", farmBtn).CornerRadius = UDim.new(0, 6)

farmBtn.MouseButton1Click:Connect(function()
    if API.IsRunning() then
        API.Stop()
        farmBtn.Text = "▶  BẬT AUTO FARM"
        farmBtn.BackgroundColor3 = COLORS.green
    else
        API.Start()
        farmBtn.Text = "⏹  TẮT AUTO FARM"
        farmBtn.BackgroundColor3 = COLORS.red
    end
end)

-- Set Home/Forest
local homeBtn = Instance.new("TextButton", pageMain)
homeBtn.Size = UDim2.new(0.5, -3, 0, 26)
homeBtn.Position = UDim2.new(0, 0, 0, 250)
homeBtn.BackgroundColor3 = COLORS.bg3
homeBtn.Text = "📍 HOME"
homeBtn.TextColor3 = COLORS.text
homeBtn.Font = Enum.Font.GothamBold
homeBtn.TextSize = 10
homeBtn.AutoButtonColor = false
homeBtn.ZIndex = 3
Instance.new("UICorner", homeBtn).CornerRadius = UDim.new(0, 6)

local forestBtn = Instance.new("TextButton", pageMain)
forestBtn.Size = UDim2.new(0.5, -3, 0, 26)
forestBtn.Position = UDim2.new(0.5, 3, 0, 250)
forestBtn.BackgroundColor3 = COLORS.bg3
forestBtn.Text = "📍 FOREST"
forestBtn.TextColor3 = COLORS.text
forestBtn.Font = Enum.Font.GothamBold
forestBtn.TextSize = 10
forestBtn.AutoButtonColor = false
forestBtn.ZIndex = 3
Instance.new("UICorner", forestBtn).CornerRadius = UDim.new(0, 6)

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

mkLabel(pageESP, "👁 CHỌN MAP ESP (multi)", 0, 18)

local espMapBtn = Instance.new("TextButton", pageESP)
espMapBtn.Size = UDim2.new(1, 0, 0, 30)
espMapBtn.Position = UDim2.new(0, 0, 0, 20)
espMapBtn.BackgroundColor3 = COLORS.bg3
espMapBtn.Text = "All Maps  ▼"
espMapBtn.TextColor3 = COLORS.text
espMapBtn.Font = Enum.Font.GothamBold
espMapBtn.TextSize = 11
espMapBtn.AutoButtonColor = false
espMapBtn.ZIndex = 3
Instance.new("UICorner", espMapBtn).CornerRadius = UDim.new(0, 6)

local espMapScroll = Instance.new("ScrollingFrame", pageESP)
espMapScroll.Size = UDim2.new(1, 0, 0, 130)
espMapScroll.Position = UDim2.new(0, 0, 0, 54)
espMapScroll.BackgroundColor3 = COLORS.bg2
espMapScroll.BorderSizePixel = 0
espMapScroll.ScrollBarThickness = 3
espMapScroll.ScrollBarImageColor3 = COLORS.accent
espMapScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
espMapScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
espMapScroll.Visible = false
espMapScroll.ZIndex = 5
Instance.new("UICorner", espMapScroll).CornerRadius = UDim.new(0, 6)

local ePad = Instance.new("UIPadding", espMapScroll)
ePad.PaddingTop = UDim.new(0, 4)
ePad.PaddingLeft = UDim.new(0, 4)
ePad.PaddingRight = UDim.new(0, 4)
ePad.PaddingBottom = UDim.new(0, 4)

local eLayout = Instance.new("UIListLayout", espMapScroll)
eLayout.Padding = UDim.new(0, 3)

local espSelected = {}
for _, m in ipairs(ALL_MAPS) do espSelected[m] = true end

local espRowBtns = {}

local espAllBtn = Instance.new("TextButton", espMapScroll)
espAllBtn.Size = UDim2.new(1, -8, 0, 24)
espAllBtn.BackgroundColor3 = COLORS.accent2
espAllBtn.Text = "  ✓ ALL MAPS"
espAllBtn.TextColor3 = Color3.new(1,1,1)
espAllBtn.Font = Enum.Font.GothamBold
espAllBtn.TextSize = 10
espAllBtn.TextXAlignment = Enum.TextXAlignment.Left
espAllBtn.AutoButtonColor = false
espAllBtn.ZIndex = 6
Instance.new("UICorner", espAllBtn).CornerRadius = UDim.new(0, 4)

espAllBtn.MouseButton1Click:Connect(function()
    for _, m in ipairs(ALL_MAPS) do espSelected[m] = true end
    espAllBtn.BackgroundColor3 = COLORS.accent2
    for _, item in ipairs(espRowBtns) do
        item.btn.BackgroundColor3 = COLORS.accent2
        item.btn.Text = "  ✓ " .. item.name
    end
    API.ESP_SetMapFilter(nil)
    espMapBtn.Text = "All Maps  ▼"
end)

for _, m in ipairs(ALL_MAPS) do
    local b = Instance.new("TextButton", espMapScroll)
    b.Size = UDim2.new(1, -8, 0, 24)
    b.BackgroundColor3 = COLORS.accent2
    b.Text = "  ✓ " .. m
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = false
    b.ZIndex = 6
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)

    table.insert(espRowBtns, { btn = b, name = m })

    b.MouseButton1Click:Connect(function()
        if espSelected[m] then
            espSelected[m] = nil
            b.BackgroundColor3 = COLORS.bg3
            b.Text = "    " .. m
            espAllBtn.BackgroundColor3 = COLORS.bg3
        else
            espSelected[m] = true
            b.BackgroundColor3 = COLORS.accent2
            b.Text = "  ✓ " .. m
        end
        local list = {}
        for _, name in ipairs(ALL_MAPS) do
            if espSelected[name] then table.insert(list, name) end
        end
        if #list == #ALL_MAPS or #list == 0 then
            API.ESP_SetMapFilter(nil)
            espMapBtn.Text = "All Maps  ▼"
        else
            API.ESP_SetMapFilter(list)
            espMapBtn.Text = #list .. " Maps  ▼"
        end
    end)
end

espMapBtn.MouseButton1Click:Connect(function()
    espMapScroll.Visible = not espMapScroll.Visible
end)

-- ESP toggle
mkLabel(pageESP, "👁 ESP EGG", 190, 18)

local espBtn = Instance.new("TextButton", pageESP)
espBtn.Size = UDim2.new(1, 0, 0, 34)
espBtn.Position = UDim2.new(0, 0, 0, 210)
espBtn.BackgroundColor3 = COLORS.purple
espBtn.Text = "👁  BẬT ESP EGG"
espBtn.TextColor3 = Color3.new(1,1,1)
espBtn.Font = Enum.Font.GothamBold
espBtn.TextSize = 12
espBtn.AutoButtonColor = false
espBtn.ZIndex = 3
Instance.new("UICorner", espBtn).CornerRadius = UDim.new(0, 6)

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

-- Set all maps ban đầu cho steal
local initList = {}
for _, m in ipairs(ALL_MAPS) do
    if MAP_POS[m] then table.insert(initList, { name = m, pos = MAP_POS[m] }) end
end
API.SetTargets(initList)

icon.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
end)

API.OnLog(function(msg) print("[StealEgg] " .. msg) end)

print("[Main] ✅ Ready v2")
