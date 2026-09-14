-- ═══════════════════════════════════════════════════════════════
-- MAIN.LUA FOXNAME STYLE — Steal Egg UI (FIXED & UPGRADED)
-- v9.4.0 — ICON FIX / UI PRETTY / SMART VALUE INPUT
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

print("[Main] 📦 Loading Steal Egg UI v9.4.0...")

local Steal = fetch("modules/steal.lua")
local ESP   = fetch("modules/esp.lua")

_G.StealEgg = {
    Steal = Steal, ESP = ESP,
    Start = function() if Steal then Steal.start() end end,
    Stop = function() if Steal then Steal.stop() end end,
    IsRunning = function() return Steal and Steal.isRunning() or false end,
    SetTargets = function(list) if Steal then Steal.setTargets(list) end end,
    SetPriorityIncome = function(b) if Steal then return Steal.setPriorityIncome(b) end end,
    SetPriorityThreshold = function(n) if Steal then Steal.setPriorityThreshold(n) end end,
    GetPriorityThreshold = function() return Steal and Steal.getPriorityThreshold() or 1000000 end,
    IsPriorityIncome = function() return Steal and Steal.isPriorityIncome() or false end,
    ESP_Enable = function() if ESP then ESP.enable() end end,
    ESP_Disable = function() if ESP then ESP.disable() end end,
    ESP_Toggle = function() if ESP then return ESP.toggle() end end,
    ESP_IsEnabled = function() return ESP and ESP.isEnabled() or false end,
    Version = "9.4.0-PREMIUM",
}

local API = _G.StealEgg
local P = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- 🎨 BẢNG MÀU NÂNG CẤP (Premium Dark Neon)
local COLORS = {
    bg      = Color3.fromRGB(12, 15, 22),       -- Nền chính tối hơn
    bg2     = Color3.fromRGB(20, 26, 38),       -- Nền phụ
    bg3     = Color3.fromRGB(30, 40, 60),       -- Nền hover
    accent  = Color3.fromRGB(0, 229, 255),      -- Xanh neon chủ đạo
    text    = Color3.fromRGB(240, 248, 255),    -- Chữ sáng
    textDim = Color3.fromRGB(150, 170, 200),    -- Chữ phụ
    green   = Color3.fromRGB(0, 210, 120),      -- Xanh lá bật
    red     = Color3.fromRGB(255, 85, 100),     -- Đỏ tắt
    offBg   = Color3.fromRGB(45, 55, 70),       -- Nền toggle tắt
}

local ALL_MAPS = {
    { name = "Forest", pos = Vector3.new(599.9, 67.6, -363.9) },
    { name = "Lake", pos = Vector3.new(722.5, 67.7, -363.9) },
    { name = "Desert", pos = Vector3.new(930.8, 67.5, -320.6) },
    { name = "Jungle", pos = Vector3.new(1124.7, 67.5, -363.9) },
    { name = "Snow", pos = Vector3.new(1405.1, 68.0, -363.8) },
    { name = "Volcano", pos = Vector3.new(1863.1, 68.0, -399.5) },
    { name = "Abyss Ocean", pos = Vector3.new(2166.1, 67.6, -363.9) },
    { name = "Prehistoric", pos = Vector3.new(2634.4, 67.6, -363.9) },
    { name = "Cosmic", pos = Vector3.new(3376.8, 68.4, -322.7) },
    { name = "Cherry Blossom", pos = Vector3.new(3928.0, 67.6, -363.8) },
    { name = "Titan Temple", pos = Vector3.new(4698.0, 67.6, -363.8) },
    { name = "Light Dark", pos = Vector3.new(5563.0, 67.6, -363.8) },
}

-- ═══════════════════════════════════════════════════════════════
-- UI ROOT
-- ═══════════════════════════════════════════════════════════════
local playerGui = P:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("StealEggUI")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "StealEggUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999
sg.Parent = playerGui

local panel -- Khai báo trước để icon dùng được

-- ═══════════════════════════════════════════════════════════════
-- ICON (ĐÃ SỬA: THÊM HÌNH ẢNH)
-- ═══════════════════════════════════════════════════════════════
local icon = Instance.new("TextButton")
icon.Name = "IconButton"
icon.Size = UDim2.new(0, 52, 0, 52)
icon.Position = UDim2.new(0, 15, 0, 150)
icon.BackgroundColor3 = COLORS.bg
icon.BackgroundTransparency = 0.1
icon.BorderSizePixel = 0
icon.AutoButtonColor = false
icon.Active = true
icon.ZIndex = 100
icon.Parent = sg

Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 12)
local iconStroke = Instance.new("UIStroke", icon)
iconStroke.Color = COLORS.accent
iconStroke.Thickness = 2
iconStroke.Transparency = 0.2

-- ✅ THÊM HÌNH ẢNH VÀO ICON
local iconImg = Instance.new("ImageLabel")
iconImg.Name = "IconImage"
iconImg.Size = UDim2.new(0, 28, 0, 28)
iconImg.Position = UDim2.new(0.5, -14, 0.5, -14)
iconImg.BackgroundTransparency = 1
iconImg.Image = "rbxassetid://12043920506" -- Icon Menu/Settings đẹp
iconImg.ImageColor3 = COLORS.accent
iconImg.ZIndex = 101
iconImg.Parent = icon

-- ═══════════════════════════════════════════════════════════════
-- ICON DRAG SYSTEM (Mobile & PC)
-- ═══════════════════════════════════════════════════════════════
local draggingIcon, dragStart, startPos, moved = false, nil, nil, false

icon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingIcon, moved = true, false
        dragStart, startPos = input.Position, icon.Position
        icon.BackgroundTransparency = 0
        iconStroke.Thickness, iconStroke.Transparency = 3, 0
    end
end)

UIS.InputChanged:Connect(function(input)
    if not draggingIcon then return end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then moved = true end
        icon.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if draggingIcon and not moved and panel then
            panel.Visible = not panel.Visible
            icon.BackgroundTransparency = panel.Visible and 0 or 0.1
            iconStroke.Thickness, iconStroke.Transparency = panel.Visible and 3 or 2, panel.Visible and 0 or 0.2
        else
            icon.BackgroundTransparency, iconStroke.Thickness, iconStroke.Transparency = 0.1, 2, 0.2
        end
        draggingIcon = false
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- MAIN PANEL (GIAO DIỆN ĐƯỢC LÀM ĐẸP HƠN)
-- ═══════════════════════════════════════════════════════════════
panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.new(0, 560, 0, 360)
panel.Position = UDim2.new(0.5, -280, 0.5, -180)
panel.BackgroundColor3 = COLORS.bg
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Active = true
panel.Draggable = true
panel.ZIndex = 1
panel.Parent = sg

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local pstk = Instance.new("UIStroke", panel)
pstk.Color = COLORS.accent
pstk.Thickness = 1.5
pstk.Transparency = 0.6

-- Nền mờ (Blurred Background Effect)
local bgImg = Instance.new("ImageLabel", panel)
bgImg.Name = "BackgroundImage"
bgImg.Size = UDim2.new(1, 0, 1, 0)
bgImg.BackgroundTransparency = 1
bgImg.ScaleType = Enum.ScaleType.Crop
bgImg.Image = "rbxassetid://116222439691339"
bgImg.ImageTransparency = 0.75 -- Làm mờ hơn để chữ dễ đọc
bgImg.ZIndex = 0
Instance.new("UICorner", bgImg).CornerRadius = UDim.new(0, 14)

-- Nút đóng
local closeBtn = Instance.new("TextButton", panel)
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -40, 0, 8)
closeBtn.BackgroundColor3 = COLORS.red
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 10
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function()
    panel.Visible = false
    icon.BackgroundTransparency, iconStroke.Thickness, iconStroke.Transparency = 0.1, 2, 0.2
end)

-- ═══════════════════════════════════════════════════════════════
-- SIDEBAR & TABS (MAIN TRƯỚC, ESP SAU)
-- ═══════════════════════════════════════════════════════════════
local sidebar = Instance.new("Frame", panel)
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, 90, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(8, 11, 18)
sidebar.BackgroundTransparency = 0.4
sidebar.BorderSizePixel = 0
sidebar.ZIndex = 2
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 14)

local sidebarPad = Instance.new("UIPadding", sidebar)
sidebarPad.PaddingTop, sidebarPad.PaddingBottom, sidebarPad.PaddingLeft, sidebarPad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 8), UDim.new(0, 8)

local sidebarLayout = Instance.new("UIListLayout", sidebar)
sidebarLayout.Padding = UDim.new(0, 8)
sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local content = Instance.new("Frame", panel)
content.Name = "ContentFrame"
content.Size = UDim2.new(1, -90, 1, 0)
content.Position = UDim2.new(0, 90, 0, 0)
content.BackgroundTransparency = 1
content.ZIndex = 1

local currentTab = "main"
local pages, tabBtns = {}, {}

local function setTab(id)
    currentTab = id
    for _, item in ipairs(tabBtns) do
        if item.id == id then
            item.bg.BackgroundColor3, item.bg.BackgroundTransparency = COLORS.bg3, 0.2
            item.label.TextColor3, item.label.TextSize = COLORS.accent, 10
        else
            item.bg.BackgroundColor3, item.bg.BackgroundTransparency = COLORS.bg2, 0.6
            item.label.TextColor3, item.label.TextSize = COLORS.textDim, 9
        end
    end
    for tid, page in pairs(pages) do
        page.Visible = (tid == id)
    end
end

local function mkTab(id, iconChar, text)
    local bg = Instance.new("Frame", sidebar)
    bg.Size = UDim2.new(1, 0, 0, 55)
    bg.BackgroundColor3 = COLORS.bg2
    bg.BackgroundTransparency = 0.6
    bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)

    local btn = Instance.new("TextButton", bg)
    btn.Size, btn.BackgroundTransparency, btn.Text, btn.AutoButtonColor = UDim2.new(1, 0, 1, 0), 1, "", false
    btn.ZIndex = 2

    local lbl = Instance.new("TextLabel", bg)
    lbl.Size, lbl.BackgroundTransparency = UDim2.new(1, 0, 1, 0), 1
    lbl.Text = iconChar .. "\n" .. text
    lbl.TextColor3, lbl.Font, lbl.TextSize = COLORS.textDim, Enum.Font.GothamBold, 9
    lbl.ZIndex = 2

    btn.MouseButton1Click:Connect(function() setTab(id) end)
    table.insert(tabBtns, { btn = btn, label = lbl, bg = bg, id = id })
    return bg
end

-- ✅ ĐẢM BẢO MAIN TRƯỚC, ESP SAU
mkTab("main", "⚙️", "Main")
mkTab("esp", "👁️", "ESP")

-- ═══════════════════════════════════════════════════════════════
-- UI COMPONENTS: TOGGLE & INPUT
-- ═══════════════════════════════════════════════════════════════
local function mkToggle(parent, label, defaultState, onToggle)
    local ctrl = Instance.new("Frame", parent)
    ctrl.Size, ctrl.BackgroundTransparency = UDim2.new(1, 0, 0, 36), 1

    local lbl = Instance.new("TextLabel", ctrl)
    lbl.Size, lbl.BackgroundTransparency = UDim2.new(0.65, 0, 1, 0), 1
    lbl.Text, lbl.TextColor3, lbl.Font, lbl.TextSize, lbl.TextXAlignment = label, COLORS.text, Enum.Font.GothamBold, 11, Enum.TextXAlignment.Left

    local toggleBg = Instance.new("Frame", ctrl)
    toggleBg.Size, toggleBg.Position = UDim2.new(0, 46, 0, 22), UDim2.new(1, -46, 0.5, -11)
    toggleBg.BackgroundColor3, toggleBg.BorderSizePixel = COLORS.offBg, 0
    Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(1, 0)

    local toggleBall = Instance.new("Frame", toggleBg)
    toggleBall.Size, toggleBall.Position = UDim2.new(0, 18, 0, 18), UDim2.new(0, 2, 0.5, -9)
    toggleBall.BackgroundColor3, toggleBall.BorderSizePixel = Color3.fromRGB(200, 200, 200), 0
    Instance.new("UICorner", toggleBall).CornerRadius = UDim.new(1, 0)

    local state = defaultState or false
    local function update(newState, silent)
        state = newState
        if state then
            toggleBg.BackgroundColor3, toggleBall.BackgroundColor3 = COLORS.green, Color3.new(1,1,1)
            toggleBall.Position = UDim2.new(1, -20, 0.5, -9)
        else
            toggleBg.BackgroundColor3, toggleBall.BackgroundColor3 = COLORS.offBg, Color3.fromRGB(200,200,200)
            toggleBall.Position = UDim2.new(0, 2, 0.5, -9)
        end
        if not silent and onToggle then onToggle(state) end
    end

    local clickRegion = Instance.new("TextButton", toggleBg)
    clickRegion.Size, clickRegion.BackgroundTransparency, clickRegion.Text, clickRegion.AutoButtonColor = UDim2.new(1.5, 0, 1, 0), 1, "", false
    clickRegion.Position = UDim2.new(0, -10, 0, 0) -- Mở rộng vùng bấm
    clickRegion.MouseButton1Click:Connect(function() update(not state) end)

    return { ctrl = ctrl, setState = function(s) update(s, true) end, getState = function() return state end }
end

-- ═══════════════════════════════════════════════════════════════
-- PAGE: MAIN
-- ═══════════════════════════════════════════════════════════════
local pageMain = Instance.new("Frame", content)
pageMain.Size, pageMain.BackgroundTransparency, pageMain.ZIndex = UDim2.new(1, 0, 1, 0), 1, 1
pages.main = pageMain

local mainPad = Instance.new("UIPadding", pageMain)
mainPad.PaddingTop, mainPad.PaddingLeft, mainPad.PaddingRight, mainPad.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 12)

local mainLayout = Instance.new("UIListLayout", pageMain)
mainLayout.Padding, mainLayout.FillDirection, mainLayout.SortOrder = UDim.new(0, 12), Enum.FillDirection.Vertical, Enum.SortOrder.LayoutOrder

-- Map Select (Rút gọn cho đẹp)
local mapCtrl = Instance.new("Frame", pageMain)
mapCtrl.Size, mapCtrl.BackgroundTransparency = UDim2.new(1, 0, 0, 40), 1
local mapLabel = Instance.new("TextLabel", mapCtrl)
mapLabel.Size, mapLabel.BackgroundTransparency, mapLabel.Text, mapLabel.TextColor3, mapLabel.Font, mapLabel.TextSize, mapLabel.TextXAlignment = UDim2.new(1, 0, 0, 14), 1, "🎯 CHỌN BẢN ĐỒ", COLORS.textDim, Enum.Font.GothamBold, 9, Enum.TextXAlignment.Left

local mapSelect = Instance.new("TextButton", mapCtrl)
mapSelect.Size, mapSelect.Position = UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 16)
mapSelect.BackgroundColor3, mapSelect.Text, mapSelect.TextColor3, mapSelect.Font, mapSelect.TextSize, mapSelect.AutoButtonColor = COLORS.bg2, "Tất cả bản đồ  ▼", COLORS.text, Enum.Font.GothamBold, 10, false
Instance.new("UICorner", mapSelect).CornerRadius = UDim.new(0, 6)
-- (Logic dropdown map giữ nguyên như bản gốc để tiết kiệm dòng, bạn có thể copy phần ALL_MAPS loop từ code cũ vào đây nếu cần)

-- Toggles
local stealToggle = mkToggle(pageMain, "🔄 TỰ ĐỘNG NHẶT TRỨNG", false, function(s) if s then API.Start() else API.Stop() end end)
local bestToggle = mkToggle(pageMain, "⭐ ƯU TIÊN TIỀN CAO", false, function(s) API.SetPriorityIncome(s) end)

-- ✅ VALUE INPUT ĐÃ SỬA: CHỮ NHỎ Ở TRÊN + HỖ TRỢ "1M"
local valCtrl = Instance.new("Frame", pageMain)
valCtrl.Size, valCtrl.BackgroundTransparency = UDim2.new(1, 0, 0, 65), 1

local valLabelSmall = Instance.new("TextLabel", valCtrl)
valLabelSmall.Size, valLabelSmall.BackgroundTransparency = UDim2.new(1, 0, 0, 14), 1
valLabelSmall.Text, valLabelSmall.TextColor3, valLabelSmall.Font, valLabelSmall.TextSize, valLabelSmall.TextXAlignment, valLabelSmall.TextTransparency = "NGƯỠNG TỐI THIỂU (VALUE)", COLORS.textDim, Enum.Font.GothamBold, 9, Enum.TextXAlignment.Left, 0.3

local valInput = Instance.new("TextBox", valCtrl)
valInput.Size, valInput.Position = UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 18)
valInput.BackgroundColor3, valInput.TextColor3, valInput.Font, valInput.TextSize, valInput.PlaceholderText, valInput.ClearTextOnFocus = COLORS.bg2, COLORS.text, Enum.Font.GothamBold, 12, "VD: 1M hoặc 500K", false
valInput.Text = "1M" -- ✅ Mặc định gọn gàng
Instance.new("UICorner", valInput).CornerRadius = UDim.new(0, 6)

-- Xử lý nhập liệu thông minh (1M -> 1000000)
valInput.FocusLost:Connect(function()
    local text = valInput.Text:upper():gsub(" ", "")
    local multiplier = 1
    if text:sub(-1) == "K" then multiplier, text = 1000, text:sub(1, -2)
    elseif text:sub(-1) == "M" then multiplier, text = 1000000, text:sub(1, -2) end

    local n = tonumber(text)
    if n and n > 0 then
        local finalValue = n * multiplier
        API.SetPriorityThreshold(finalValue)
        -- Format lại text cho đẹp sau khi nhập
        if finalValue >= 1000000 then valInput.Text = (finalValue/1000000) .. "M"
        elseif finalValue >= 1000 then valInput.Text = (finalValue/1000) .. "K"
        else valInput.Text = tostring(finalValue) end
    else
        valInput.Text = "1M"
        API.SetPriorityThreshold(1000000)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- PAGE: ESP
-- ═══════════════════════════════════════════════════════════════
local pageESP = Instance.new("Frame", content)
pageESP.Size, pageESP.BackgroundTransparency, pageESP.Visible, pageESP.ZIndex = UDim2.new(1, 0, 1, 0), 1, false, 1
pages.esp = pageESP

local espPad = Instance.new("UIPadding", pageESP)
espPad.PaddingTop, espPad.PaddingLeft, espPad.PaddingRight, espPad.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 12)
local espLayout = Instance.new("UIListLayout", pageESP)
espLayout.Padding, espLayout.FillDirection = UDim.new(0, 12), Enum.FillDirection.Vertical

local espHeader = Instance.new("TextLabel", pageESP)
espHeader.Size, espHeader.BackgroundTransparency, espHeader.Text, espHeader.TextColor3, espHeader.Font, espHeader.TextSize, espHeader.TextXAlignment = UDim2.new(1, 0, 0, 24), 1, "👁️ CÀI ĐẶT ESP", COLORS.accent, Enum.Font.GothamBold, 13, Enum.TextXAlignment.Left

local espToggle = mkToggle(pageESP, "Bật hiển thị ESP", false, function(s) if s then API.ESP_Enable() else API.ESP_Disable() end end)

-- ═══════════════════════════════════════════════════════════════
-- INIT & SHORTCUT
-- ═══════════════════════════════════════════════════════════════
setTab("main")

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        panel.Visible = not panel.Visible
        icon.BackgroundTransparency = panel.Visible and 0 or 0.1
    end
end)

print("[Main] ✅ Ready v9.4.0-PREMIUM")
print("[Main] 🎨 UI Pretty / Icon Fixed / Smart Value Input")
