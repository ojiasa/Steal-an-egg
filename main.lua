-- ═══════════════════════════════════════════════════════════════
-- MAIN.LUA FOXNAME STYLE v3 — Select Map Overlay + Trắng Nhạt
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
    SetPriorityIncome = function(b) if Steal then return Steal.setPriorityIncome(b) end end,
    TogglePriorityIncome = function() if Steal then return Steal.togglePriorityIncome() end end,
    SetPriorityThreshold = function(n) if Steal then Steal.setPriorityThreshold(n) end end,
    GetPriorityThreshold = function() if Steal then return Steal.getPriorityThreshold() end end,
    IsPriorityIncome = function() return Steal and Steal.isPriorityIncome() or false end,
    ClearIncomeCache = function() if Steal then Steal.clearIncomeCache() end end,
    ESP_Enable = function() if ESP then ESP.enable() end end,
    ESP_Disable = function() if ESP then ESP.disable() end end,
    ESP_Toggle = function() if ESP then return ESP.toggle() end end,
    ESP_IsEnabled = function() return ESP and ESP.isEnabled() or false end,
    Version = "9.5.0",
}
local API = _G.StealEgg
_G.MyScript = API

local P = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

API.OnLog(function(msg) print("[UI-Log] " .. tostring(msg)) end)

-- ⭐ MÀU — chỉ chữ trắng nhạt, button không tô trắng
local COLORS = {
    bg      = Color3.fromRGB(12, 14, 22),
    bg2     = Color3.fromRGB(22, 26, 36),
    bg3     = Color3.fromRGB(30, 36, 50),

    -- Trắng nhạt cho CHỮ (không phải nền button)
    white   = Color3.fromRGB(225, 232, 245),
    whiteDim= Color3.fromRGB(180, 195, 215),

    accent  = Color3.fromRGB(0, 220, 255),
    text    = Color3.fromRGB(230, 240, 255),
    textDim = Color3.fromRGB(150, 165, 185),

    red     = Color3.fromRGB(220, 80, 100),
    offBg   = Color3.fromRGB(45, 52, 68),
    btnBg   = Color3.fromRGB(28, 34, 48),
    btnHover= Color3.fromRGB(42, 50, 68),
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

-- ⭐ ICON
local icon = Instance.new("ImageButton")
icon.Size = UDim2.new(0, 44, 0, 44)
icon.Position = UDim2.new(0, 15, 0, 150)
icon.BackgroundColor3 = COLORS.bg2
icon.BorderSizePixel = 0
icon.Image = "rbxassetid://86285862396979"
icon.ScaleType = Enum.ScaleType.Fit
icon.AutoButtonColor = false
icon.Draggable = true
icon.Parent = sg
Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
local istk = Instance.new("UIStroke", icon)
istk.Color = COLORS.whiteDim
istk.Thickness = 1.5

-- ⭐ MAIN PANEL
local PANEL_W, PANEL_H = 320, 380

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position = UDim2.new(0.5, -PANEL_W/2, 0.5, -PANEL_H/2)
panel.BackgroundColor3 = COLORS.bg
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = sg
panel.Active = true
panel.ClipsDescendants = false               -- ⭐ Cho dropdown overflow
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local pstk = Instance.new("UIStroke", panel)
pstk.Color = COLORS.whiteDim
pstk.Thickness = 1
pstk.Transparency = 0.5

-- ⭐ HEADER với TABS NGANG
local header = Instance.new("Frame", panel)
header.Size = UDim2.new(1, 0, 0, 38)
header.BackgroundColor3 = COLORS.bg2
header.BackgroundTransparency = 0.2
header.BorderSizePixel = 0
header.ZIndex = 2
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

-- Che góc dưới header
local headerFix = Instance.new("Frame", header)
headerFix.Size = UDim2.new(1, 0, 0, 10)
headerFix.Position = UDim2.new(0, 0, 1, -10)
headerFix.BackgroundColor3 = COLORS.bg2
headerFix.BackgroundTransparency = 0.2
headerFix.BorderSizePixel = 0
headerFix.ZIndex = 2

-- ⭐ TAB BAR ngang
local tabBar = Instance.new("Frame", header)
tabBar.Size = UDim2.new(1, -70, 1, 0)
tabBar.Position = UDim2.new(0, 8, 0, 0)
tabBar.BackgroundTransparency = 1
tabBar.ZIndex = 3

local tabLayout = Instance.new("UIListLayout", tabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center

-- ⭐ CLOSE
local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -30, 0.5, -12)
closeBtn.BackgroundColor3 = COLORS.bg3
closeBtn.Text = "✕"
closeBtn.TextColor3 = COLORS.white
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 10
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)
closeBtn.MouseEnter:Connect(function() closeBtn.BackgroundColor3 = COLORS.red end)
closeBtn.MouseLeave:Connect(function() closeBtn.BackgroundColor3 = COLORS.bg3 end)

-- ⭐ CONTENT
local content = Instance.new("Frame", panel)
content.Size = UDim2.new(1, -16, 1, -48)
content.Position = UDim2.new(0, 8, 0, 44)
content.BackgroundTransparency = 1
content.Parent = panel
content.ClipsDescendants = false
content.ZIndex = 1

local pages = {}
local tabBtns = {}
local currentTab = "main"

-- ⭐ TAB CREATOR — chữ trắng nhạt, button không tô
local function mkTab(id, iconText, labelText)
    local bg = Instance.new("TextButton", tabBar)
    bg.Size = UDim2.new(0, 88, 0, 26)
    bg.BackgroundColor3 = COLORS.bg3
    bg.BackgroundTransparency = 0.5
    bg.Text = ""
    bg.AutoButtonColor = false
    bg.ZIndex = 4
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
    local stk = Instance.new("UIStroke", bg)
    stk.Color = COLORS.whiteDim
    stk.Thickness = 1
    stk.Transparency = 0.7

    local ic = Instance.new("TextLabel", bg)
    ic.Size = UDim2.new(0, 22, 1, 0)
    ic.Position = UDim2.new(0, 4, 0, 0)
    ic.BackgroundTransparency = 1
    ic.Text = iconText
    ic.TextColor3 = COLORS.whiteDim
    ic.Font = Enum.Font.GothamBold
    ic.TextSize = 12
    ic.ZIndex = 5

    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.new(1, -28, 1, 0)
    lbl.Position = UDim2.new(0, 26, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = COLORS.whiteDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 5

    bg.MouseButton1Click:Connect(function()
        currentTab = id
        for _, item in ipairs(tabBtns) do
            if item.id == id then
                item.bg.BackgroundTransparency = 0.15
                item.stk.Transparency = 0.3
                item.ic.TextColor3 = COLORS.white
                item.lbl.TextColor3 = COLORS.white
            else
                item.bg.BackgroundTransparency = 0.5
                item.stk.Transparency = 0.7
                item.ic.TextColor3 = COLORS.whiteDim
                item.lbl.TextColor3 = COLORS.whiteDim
            end
        end
        for tid, page in pairs(pages) do page.Visible = (tid == id) end
    end)

    table.insert(tabBtns, { bg = bg, ic = ic, lbl = lbl, stk = stk, id = id })
end

mkTab("main", "🏠", "Main")
mkTab("esp", "👁", "ESP")

-- ⭐ TOGGLE SWITCH
local function mkToggle(parent, label, defaultState, onToggle)
    local ctrl = Instance.new("Frame", parent)
    ctrl.Size = UDim2.new(1, 0, 0, 30)
    ctrl.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", ctrl)
    lbl.Size = UDim2.new(0.65, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = COLORS.text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local toggleBg = Instance.new("Frame", ctrl)
    toggleBg.Size = UDim2.new(0, 42, 0, 22)
    toggleBg.Position = UDim2.new(1, -42, 0.5, -11)
    toggleBg.BackgroundColor3 = COLORS.offBg
    toggleBg.BorderSizePixel = 0
    Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(0.5, 0)
    local tgStk = Instance.new("UIStroke", toggleBg)
    tgStk.Color = COLORS.whiteDim
    tgStk.Thickness = 1
    tgStk.Transparency = 0.6

    local toggleBall = Instance.new("Frame", toggleBg)
    toggleBall.Size = UDim2.new(0, 18, 0, 18)
    toggleBall.Position = UDim2.new(0, 2, 0.5, -9)
    toggleBall.BackgroundColor3 = COLORS.whiteDim
    toggleBall.BorderSizePixel = 0
    Instance.new("UICorner", toggleBall).CornerRadius = UDim.new(1, 0)

    local state = defaultState or false

    local function updateToggle(newState, silent)
        state = newState
        if state then
            -- ⭐ ON: nền sáng nhạt (không phải trắng đục)
            toggleBg.BackgroundColor3 = COLORS.whiteDim
            tgStk.Transparency = 0.3
            toggleBall.BackgroundColor3 = COLORS.bg
            toggleBall.Position = UDim2.new(1, -20, 0.5, -9)
        else
            toggleBg.BackgroundColor3 = COLORS.offBg
            tgStk.Transparency = 0.6
            toggleBall.BackgroundColor3 = COLORS.whiteDim
            toggleBall.Position = UDim2.new(0, 2, 0.5, -9)
        end
        if not silent and onToggle then onToggle(state) end
    end

    updateToggle(state, true)

    local clickRegion = Instance.new("TextButton", toggleBg)
    clickRegion.Size = UDim2.new(1, 0, 1, 0)
    clickRegion.BackgroundTransparency = 1
    clickRegion.Text = ""
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
local function mkControl(parent, label, h)
    local ctrl = Instance.new("Frame", parent)
    ctrl.Size = UDim2.new(1, 0, 0, h or 50)
    ctrl.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", ctrl)
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = COLORS.whiteDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    return ctrl, lbl
end

-- ═══════════════════════════════════════════════════════════════
-- PAGE: MAIN
-- ═══════════════════════════════════════════════════════════════
local pageMain = Instance.new("Frame", content)
pageMain.Size = UDim2.new(1, 0, 1, 0)
pageMain.BackgroundTransparency = 1
pages.main = pageMain

local mainLayout = Instance.new("UIListLayout", pageMain)
mainLayout.Padding = UDim.new(0, 8)
mainLayout.FillDirection = Enum.FillDirection.Vertical

-- ⭐ MAP SELECT — chỉ có 1 button, KHÔNG dropdown bên trong
local mapCtrl, mapLabel = mkControl(pageMain, "🎯 SELECT MAP", 50)

local mapSelect = Instance.new("TextButton", mapCtrl)
mapSelect.Size = UDim2.new(1, 0, 0, 30)
mapSelect.Position = UDim2.new(0, 0, 0, 16)
mapSelect.BackgroundColor3 = COLORS.bg2
mapSelect.Text = "All Maps   ▾"
mapSelect.TextColor3 = COLORS.white
mapSelect.Font = Enum.Font.GothamBold
mapSelect.TextSize = 11
mapSelect.AutoButtonColor = false
Instance.new("UICorner", mapSelect).CornerRadius = UDim.new(0, 6)
local msStk = Instance.new("UIStroke", mapSelect)
msStk.Color = COLORS.whiteDim
msStk.Thickness = 1
msStk.Transparency = 0.6

mapSelect.MouseEnter:Connect(function()
    mapSelect.BackgroundColor3 = COLORS.btnHover
end)
mapSelect.MouseLeave:Connect(function()
    mapSelect.BackgroundColor3 = COLORS.bg2
end)

-- ⭐ DROPDOWN — OVERLAY HIỆN BÊN PHẢI NÚT (hoặc đè lên trên)
local mapDropdown = Instance.new("Frame", panel)   -- ⭐ child của PANEL, không phải control
mapDropdown.Size = UDim2.new(0, 180, 0, 220)
mapDropdown.BackgroundColor3 = COLORS.bg2
mapDropdown.BackgroundTransparency = 0.05
mapDropdown.BorderSizePixel = 0
mapDropdown.Visible = false
mapDropdown.ZIndex = 100                             -- ⭐ Trên tất cả
Instance.new("UICorner", mapDropdown).CornerRadius = UDim.new(0, 8)
local ddStk = Instance.new("UIStroke", mapDropdown)
ddStk.Color = COLORS.whiteDim
ddStk.Thickness = 1
ddStk.Transparency = 0.4

-- ⭐ Vị trí: bên phải nút "Select Map" (được set lại khi click)
local mapScroll = Instance.new("ScrollingFrame", mapDropdown)
mapScroll.Size = UDim2.new(1, -8, 1, -8)
mapScroll.Position = UDim2.new(0, 4, 0, 4)
mapScroll.BackgroundTransparency = 1
mapScroll.BorderSizePixel = 0
mapScroll.ScrollBarThickness = 2
mapScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
mapScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local mLayout = Instance.new("UIListLayout", mapScroll)
mLayout.Padding = UDim.new(0, 3)

local selectedMaps = {}
local mapRowBtns = {}

local function updateSelectedMaps()
    local targets = {}
    for _, m in ipairs(ALL_MAPS) do
        if selectedMaps[m.name] then
            table.insert(targets, m)
        end
    end
    if #targets == 0 then targets = ALL_MAPS end
    API.SetTargets(targets)
end

-- "All Maps" button (chỉ chữ trắng nhạt, nền xám)
local selAllBtn = Instance.new("TextButton", mapScroll)
selAllBtn.Size = UDim2.new(1, 0, 0, 24)
selAllBtn.BackgroundColor3 = COLORS.btnBg
selAllBtn.Text = "✓  All Maps"
selAllBtn.TextColor3 = COLORS.white
selAllBtn.Font = Enum.Font.GothamBold
selAllBtn.TextSize = 10
selAllBtn.TextXAlignment = Enum.TextXAlignment.Left
selAllBtn.AutoButtonColor = false
Instance.new("UICorner", selAllBtn).CornerRadius = UDim.new(0, 4)

selAllBtn.MouseButton1Click:Connect(function()
    for _, m in ipairs(ALL_MAPS) do selectedMaps[m.name] = true end
    mapSelect.Text = "All Maps   ▾"
    for _, item in ipairs(mapRowBtns) do
        item.btn.BackgroundColor3 = COLORS.btnBg
        item.btn.TextColor3 = COLORS.white
    end
    updateSelectedMaps()
    mapDropdown.Visible = false
end)

for _, m in ipairs(ALL_MAPS) do
    local b = Instance.new("TextButton", mapScroll)
    b.Size = UDim2.new(1, 0, 0, 24)
    b.BackgroundColor3 = COLORS.btnBg
    b.Text = "     " .. m.name
    b.TextColor3 = COLORS.textDim
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)

    table.insert(mapRowBtns, { btn = b, name = m.name })

    b.MouseButton1Click:Connect(function()
        selectedMaps[m.name] = not selectedMaps[m.name]
        if selectedMaps[m.name] then
            -- ⭐ Không tô trắng — chỉ đổi chữ + đổi nền nhẹ
            b.BackgroundColor3 = COLORS.btnHover
            b.TextColor3 = COLORS.white
            b.Text = "  ✓  " .. m.name
        else
            b.BackgroundColor3 = COLORS.btnBg
            b.TextColor3 = COLORS.textDim
            b.Text = "     " .. m.name
        end

        local count = 0
        for _ in pairs(selectedMaps) do count = count + 1 end
        if count == 0 then
            mapSelect.Text = "All Maps (default)   ▾"
        elseif count == #ALL_MAPS then
            mapSelect.Text = "All Maps   ▾"
        else
            mapSelect.Text = count .. " Maps   ▾"
        end
        updateSelectedMaps()
    end)
end

-- ⭐ Bấm select → hiện dropdown BÊN PHẢI nút
mapSelect.MouseButton1Click:Connect(function()
    if mapDropdown.Visible then
        mapDropdown.Visible = false
        return
    end

    -- ⭐ Đặt vị trí: bên phải nút Select Map
    local posBtn = mapSelect.AbsolutePosition
    local posPanel = panel.AbsolutePosition
    local sizeBtn = mapSelect.AbsoluteSize

    -- Tọa độ tương đối trong panel
    local relX = posBtn.X - posPanel.X + sizeBtn.X + 6  -- bên phải + 6px
    local relY = posBtn.Y - posPanel.Y

    -- Nếu không đủ chỗ bên phải → hiện bên trái
    if relX + 180 > PANEL_W then
        relX = posBtn.X - posPanel.X - 180 - 6
    end

    -- Nếu tràn xuống → dịch lên
    if relY + 220 > PANEL_H then
        relY = PANEL_H - 220 - 10
    end

    mapDropdown.Position = UDim2.new(0, relX, 0, relY)
    mapDropdown.Visible = true
end)

-- ⭐ AUTO STEAL
local stealToggle = mkToggle(pageMain, "🔄 AUTO STEAL", false, function(state)
    if state then API.Start() else API.Stop() end
end)

-- ⭐ PRIORITY INCOME
local bestToggle = mkToggle(pageMain, "⭐ ƯU TIÊN TIỀN CAO", false, function(state)
    API.SetPriorityIncome(state)
end)

-- ⭐ THRESHOLD INPUT
local valCtrl, valLabel = mkControl(pageMain, "💵 NGƯỠNG TIỀN ($/s)", 50)

local valInput = Instance.new("TextBox", valCtrl)
valInput.Size = UDim2.new(1, 0, 0, 30)
valInput.Position = UDim2.new(0, 0, 0, 16)
valInput.BackgroundColor3 = COLORS.bg2
valInput.Text = "1000000"
valInput.TextColor3 = COLORS.white
valInput.Font = Enum.Font.GothamBold
valInput.TextSize = 12
valInput.PlaceholderText = "VD: 1000000"
valInput.ClearTextOnFocus = false
Instance.new("UICorner", valInput).CornerRadius = UDim.new(0, 6)
local viStk = Instance.new("UIStroke", valInput)
viStk.Color = COLORS.whiteDim
viStk.Thickness = 1
viStk.Transparency = 0.6

valInput.FocusLost:Connect(function()
    local n = tonumber(valInput.Text)
    if n and n > 0 then
        API.SetPriorityThreshold(n)
    else
        valInput.Text = "1000000"
    end
end)

-- ⭐ SYNC STATE
task.spawn(function()
    while task.wait(1) do
        local running = API.IsRunning()
        if running ~= stealToggle.getState() then
            stealToggle.setState(running)
        end
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
pageESP.Size = UDim2.new(1, 0, 1, 0)
pageESP.BackgroundTransparency = 1
pageESP.Visible = false
pages.esp = pageESP

local espLayout = Instance.new("UIListLayout", pageESP)
espLayout.Padding = UDim.new(0, 8)

local espHeader = Instance.new("TextLabel", pageESP)
espHeader.Size = UDim2.new(1, 0, 0, 24)
espHeader.BackgroundTransparency = 1
espHeader.Text = "👁 ESP SETTINGS"
espHeader.TextColor3 = COLORS.white
espHeader.Font = Enum.Font.GothamBold
espHeader.TextSize = 12
espHeader.TextXAlignment = Enum.TextXAlignment.Left

local espToggle = mkToggle(pageESP, "Enable ESP", false, function(state)
    if state then API.ESP_Enable() else API.ESP_Disable() end
end)

-- ══════════ INIT ══════════
for _, item in ipairs(tabBtns) do
    if item.id == "main" then
        item.bg.BackgroundTransparency = 0.15
        item.stk.Transparency = 0.3
        item.ic.TextColor3 = COLORS.white
        item.lbl.TextColor3 = COLORS.white
    else
        item.bg.BackgroundTransparency = 0.5
        item.stk.Transparency = 0.7
        item.ic.TextColor3 = COLORS.whiteDim
        item.lbl.TextColor3 = COLORS.whiteDim
    end
end

icon.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
    if not panel.Visible then mapDropdown.Visible = false end
end)

-- ⭐ Click ra ngoài dropdown → đóng
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        -- Nếu click không phải vào dropdown hoặc nút select → đóng
        if mapDropdown.Visible then
            local mx, my = input.Position.X, input.Position.Y
            local ddPos = mapDropdown.AbsolutePosition
            local ddSize = mapDropdown.AbsoluteSize
            local btnPos = mapSelect.AbsolutePosition
            local btnSize = mapSelect.AbsoluteSize

            local inDropdown = mx >= ddPos.X and mx <= ddPos.X + ddSize.X
                            and my >= ddPos.Y and my <= ddPos.Y + ddSize.Y
            local inBtn = mx >= btnPos.X and mx <= btnPos.X + btnSize.X
                       and my >= btnPos.Y and my <= btnPos.Y + btnSize.Y

            if not inDropdown and not inBtn then
                mapDropdown.Visible = false
            end
        end
    end
end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        panel.Visible = not panel.Visible
        if not panel.Visible then mapDropdown.Visible = false end
    end
end)

print("[Main] ✅ Ready v9.5 - Overlay dropdown!")
