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

print("[Main] 📦 Loading modules...")
local Steal = fetch("modules/steal.lua")
local ESP   = fetch("modules/esp.lua")

_G.StealEgg = {
    Steal = Steal, ESP = ESP,
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

    ESP_Enable = function() if ESP then ESP.enable() end end,
    ESP_Disable = function() if ESP then ESP.disable() end end,
    ESP_Toggle = function() if ESP then return ESP.toggle() end end,
    ESP_IsEnabled = function() return ESP and ESP.isEnabled() or false end,
    ESP_SetMapFilter = function(list) if ESP then ESP.setMapFilter(list) end end,

    Version = "2.4.0",
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

-- 1. BẢNG MÀU TRẮNG XÁM (Độ trong suốt trong kính mờ chuẩn ảnh 3)
local COLORS = {
    bg          = Color3.fromRGB(215, 220, 228),
    card        = Color3.fromRGB(255, 255, 255),
    cardBorder  = Color3.fromRGB(180, 185, 195),
    sidebar     = Color3.fromRGB(195, 200, 210),
    activeBtn   = Color3.fromRGB(110, 115, 125),
    activeText  = Color3.fromRGB(255, 255, 255),
    textBold    = Color3.fromRGB(15, 18, 25),    -- Chữ Đen/Xám đậm nổi bật
    textDim     = Color3.fromRGB(80, 85, 95),
    toggleOn    = Color3.fromRGB(70, 75, 85),
    toggleOff   = Color3.fromRGB(190, 195, 205),
    white       = Color3.fromRGB(255, 255, 255),
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

-- 4. Icon mở UI nổi (Tăng kích thước lên 44x44)
local icon = Instance.new("ImageButton")
icon.Size = UDim2.new(0, 44, 0, 44)
icon.Position = UDim2.new(0, 15, 0.4, 0)
icon.BackgroundColor3 = COLORS.bg
icon.BorderSizePixel = 0
icon.Image = ICON_ID
icon.Draggable = true
icon.Parent = sg
Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
local istk = Instance.new("UIStroke", icon)
istk.Color = COLORS.cardBorder
istk.Thickness = 2

-- 1 & 4. Khung chính MainFrame (Hình chữ nhật 460x195, BackgroundTransparency = 0.55)
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 460, 0, 195)
panel.Position = UDim2.new(0.5, -230, 0.35, -97)
panel.BackgroundColor3 = COLORS.bg
panel.BackgroundTransparency = 0.55 -- Tăng độ trong suốt để lộ ảnh nền ở dưới
panel.BorderSizePixel = 0
panel.ClipsDescendants = false
panel.Visible = false
panel.Active = true
panel.Draggable = true
panel.Parent = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local pstk = Instance.new("UIStroke", panel)
pstk.Color = COLORS.cardBorder
pstk.Thickness = 1.5

-- 1. Ảnh nền hiển thị rõ ràng (ImageTransparency = 0.25)
local bgImg = Instance.new("ImageLabel", panel)
bgImg.Size = UDim2.new(1, 0, 1, 0)
bgImg.BackgroundTransparency = 1
bgImg.ScaleType = Enum.ScaleType.Crop
bgImg.Image = BACKGROUND_ID
bgImg.ImageTransparency = 0.25 -- Giảm mờ để hiện ảnh rõ ràng như ảnh 3
bgImg.ZIndex = 0
Instance.new("UICorner", bgImg).CornerRadius = UDim.new(0, 10)

-- 4. Icon ở góc trên trái (Kích thước 36x36)
local topIcon = Instance.new("ImageLabel", panel)
topIcon.Size = UDim2.new(0, 26, 0, 26)
topIcon.Position = UDim2.new(0, 8, 0, 5)
topIcon.BackgroundTransparency = 1
topIcon.Image = ICON_ID
topIcon.ZIndex = 2

-- 1. Tiêu đề Đen/Xám đậm In đậm
local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -45, 0, 26)
title.Position = UDim2.new(0, 38, 0, 5)
title.BackgroundTransparency = 1
title.Text = "STEAL AN EGG HUB"
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextColor3 = COLORS.textBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 2

-- 4. Cột bên trái (Sidebar) tăng chiều rộng lên 125px cho dễ bấm
local sidebar = Instance.new("Frame", panel)
sidebar.Position = UDim2.new(0, 10, 0, 36)
sidebar.Size = UDim2.new(0, 125, 1, -44)
sidebar.BackgroundColor3 = COLORS.sidebar
sidebar.BackgroundTransparency = 0.4
sidebar.BorderSizePixel = 0
sidebar.ZIndex = 2
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)

local sidePad = Instance.new("UIPadding", sidebar)
sidePad.PaddingTop = UDim.new(0, 4)
sidePad.PaddingLeft = UDim.new(0, 4)
sidePad.PaddingRight = UDim.new(0, 4)
sidePad.PaddingBottom = UDim.new(0, 4)

local sideLayout = Instance.new("UIListLayout", sidebar)
sideLayout.Padding = UDim.new(0, 4)

-- Khu vực nội dung bên phải
local content = Instance.new("Frame", panel)
content.Position = UDim2.new(0, 142, 0, 36)
content.Size = UDim2.new(1, -152, 1, -44)
content.BackgroundTransparency = 1
content.ZIndex = 2

local currentTab = "main"
local pages = {}
local tabBtns = {}

local function setTab(id)
    currentTab = id
    for _, item in pairs(tabBtns) do
        if item.id == id then
            TweenService:Create(item.btn, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.activeBtn, TextColor3 = COLORS.activeText}):Play()
        else
            TweenService:Create(item.btn, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.card, TextColor3 = COLORS.textBold}):Play()
        end
    end
    for tid, page in pairs(pages) do page.Visible = (tid == id) end
end

local function mkTab(id, text)
    local b = Instance.new("TextButton", sidebar)
    b.Size = UDim2.new(1, 0, 0, 32)
    b.BackgroundColor3 = COLORS.card
    b.BackgroundTransparency = 0.2
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.TextColor3 = COLORS.textBold
    b.AutoButtonColor = false
    b.ZIndex = 3
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    local bStk = Instance.new("UIStroke", b)
    bStk.Color = COLORS.cardBorder
    bStk.Thickness = 1

    b.MouseButton1Click:Connect(function() setTab(id) end)
    table.insert(tabBtns, { btn = b, id = id })
    return b
end

mkTab("main", "Main")
mkTab("esp",  "ESP")

-- ══════════ TÍNH NĂNG GIAO DIỆN ══════════

-- 3. Ô tính năng Steal Best Egg (value m) + Ô TextBox nhập số (Tự động nhân 1M)
local function createToggleRow(parent, labelText, defaultState, hasTextBox, onToggle, onInputChanged)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, -6, 0, 32)
    container.BackgroundColor3 = COLORS.card
    container.BackgroundTransparency = 0.45 -- Trắng mờ đẹp mắt
    container.ZIndex = 3
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)
    local cStk = Instance.new("UIStroke", container)
    cStk.Color = COLORS.cardBorder
    cStk.Thickness = 1

    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(1, hasTextBox and -110 or -50, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = COLORS.textBold
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 4

    if hasTextBox then
        local box = Instance.new("TextBox", container)
        box.Size = UDim2.new(0, 50, 0, 20)
        box.Position = UDim2.new(1, -95, 0.5, -10)
        box.BackgroundColor3 = COLORS.white
        box.BackgroundTransparency = 0.2
        box.TextColor3 = COLORS.textBold
        box.Font = Enum.Font.GothamBold
        box.TextSize = 10
        box.Text = "" -- Xóa chữ "1M" cố định
        box.PlaceholderText = "1"
        box.ZIndex = 4
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
        local bStk = Instance.new("UIStroke", box)
        bStk.Color = COLORS.cardBorder
        bStk.Thickness = 1

        box.FocusLost:Connect(function()
            local num = tonumber(box.Text)
            if num and onInputChanged then
                onInputChanged(num * 1000000) -- Tự động hiểu nhập 1 là 1M, 10 là 10M
            end
        end)
    end

    local switchBg = Instance.new("TextButton", container)
    switchBg.Size = UDim2.new(0, 36, 0, 18)
    switchBg.Position = UDim2.new(1, -42, 0.5, -9)
    switchBg.Text = ""
    switchBg.AutoButtonColor = false
    switchBg.ZIndex = 4
    Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", switchBg)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = COLORS.white
    knob.ZIndex = 5
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = defaultState or false
    local function updateVisual(instant)
        local targetColor = state and COLORS.toggleOn or COLORS.toggleOff
        local targetPos = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
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

-- 2. Dropdown Select Map chuẩn kích thước, neo chính xác bên dưới "All Maps --"
local function createMultiSelectDropdown(parent, labelText, options, callback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, -6, 0, 32)
    container.BackgroundTransparency = 1
    container.ZIndex = 3

    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(0, 80, 1, 0)
    lbl.Position = UDim2.new(0, 4, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = COLORS.textBold
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3

    local dropBtn = Instance.new("TextButton", container)
    dropBtn.Size = UDim2.new(1, -85, 1, 0)
    dropBtn.Position = UDim2.new(0, 85, 0, 0)
    dropBtn.BackgroundColor3 = COLORS.card
    dropBtn.BackgroundTransparency = 0.3
    dropBtn.Text = "All Maps --"
    dropBtn.TextColor3 = COLORS.textDim
    dropBtn.Font = Enum.Font.GothamBold
    dropBtn.TextSize = 10
    dropBtn.AutoButtonColor = false
    dropBtn.ZIndex = 4
    Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0, 6)
    local dStk = Instance.new("UIStroke", dropBtn)
    dStk.Color = COLORS.cardBorder
    dStk.Thickness = 1

    -- Bảng xổ xuống Dropdown (Parented vào panel để không bị che clip)
    local dropMenu = Instance.new("Frame", panel)
    dropMenu.BackgroundColor3 = COLORS.card
    dropMenu.BackgroundTransparency = 0.1
    dropMenu.BorderSizePixel = 0
    dropMenu.Visible = false
    dropMenu.ZIndex = 100
    Instance.new("UICorner", dropMenu).CornerRadius = UDim.new(0, 6)
    local dstk = Instance.new("UIStroke", dropMenu)
    dstk.Color = COLORS.activeBtn
    dstk.Thickness = 1.5

    local scroll = Instance.new("ScrollingFrame", dropMenu)
    scroll.Size = UDim2.new(1, 0, 1, -26)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.CanvasSize = UDim2.new(0, 0, 0, #options * 24)
    scroll.ZIndex = 101

    local sLayout = Instance.new("UIListLayout", scroll)
    sLayout.Padding = UDim.new(0, 2)

    local selectedMaps = {}
    for _, opt in ipairs(options) do selectedMaps[opt] = true end

    for _, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton", scroll)
        optBtn.Size = UDim2.new(1, 0, 0, 22) -- Giãn full chiều rộng
        optBtn.BackgroundColor3 = selectedMaps[opt] and COLORS.sidebar or COLORS.card
        optBtn.BackgroundTransparency = 0.2
        optBtn.Text = "  " .. opt .. (selectedMaps[opt] and "  ✓" or "")
        optBtn.TextColor3 = COLORS.textBold
        optBtn.Font = Enum.Font.GothamMedium
        optBtn.TextSize = 10
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.AutoButtonColor = false
        optBtn.ZIndex = 102

        optBtn.MouseButton1Click:Connect(function()
            selectedMaps[opt] = not selectedMaps[opt]
            optBtn.BackgroundColor3 = selectedMaps[opt] and COLORS.sidebar or COLORS.card
            optBtn.Text = "  " .. opt .. (selectedMaps[opt] and "  ✓" or "")
        end)
    end

    -- Nút "Xác nhận" ở dưới cùng
    local confirmBtn = Instance.new("TextButton", dropMenu)
    confirmBtn.Size = UDim2.new(1, 0, 0, 24)
    confirmBtn.Position = UDim2.new(0, 0, 1, -24)
    confirmBtn.BackgroundColor3 = COLORS.activeBtn
    confirmBtn.Text = "Xác nhận"
    confirmBtn.TextColor3 = COLORS.white
    confirmBtn.Font = Enum.Font.GothamBold
    confirmBtn.TextSize = 10
    confirmBtn.ZIndex = 102
    Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 4)

    confirmBtn.MouseButton1Click:Connect(function()
        dropMenu.Visible = false
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
    end)

    dropBtn.MouseButton1Click:Connect(function()
        dropMenu.Visible = not dropMenu.Visible
        if dropMenu.Visible then
            -- Neo chính xác vị trí và đồng nhất chiều rộng với nút "All Maps --"
            local absPos = dropBtn.AbsolutePosition - panel.AbsolutePosition
            dropMenu.Position = UDim2.new(0, absPos.X, 0, absPos.Y + dropBtn.AbsoluteSize.Y + 3)
            dropMenu.Size = UDim2.new(0, dropBtn.AbsoluteSize.X, 0, 120)
        end
    end)

    return container
end

-- ══════════ TAB MAIN CONTENT ══════════
local pageMain = Instance.new("ScrollingFrame", content)
pageMain.Size = UDim2.new(1, 0, 1, 0)
pageMain.BackgroundTransparency = 1
pageMain.BorderSizePixel = 0
pageMain.ScrollBarThickness = 2
pageMain.CanvasSize = UDim2.new(0, 0, 0, 130)
pageMain.ZIndex = 3
pages.main = pageMain

local mainLayout = Instance.new("UIListLayout", pageMain)
mainLayout.Padding = UDim.new(0, 6)

-- Select Map đưa lên đầu
local mapDrop = createMultiSelectDropdown(pageMain, "Select Map", ALL_MAPS, function(list)
    API.SetTargets(list)
end)
mapDrop.LayoutOrder = 1

-- 3. Steal Best Egg (value m)
local bestEggToggle = createToggleRow(pageMain, "Steal Best Egg (value m)", API.IsPriorityIncome(), true, function(state)
    API.SetPriorityIncome(state)
end, function(value)
    API.SetPriorityThreshold(value)
end)
bestEggToggle.LayoutOrder = 2

-- Auto Steal Egg
local autoFarmToggle = createToggleRow(pageMain, "Auto Steal Egg", false, false, function(state)
    if state then API.Start() else API.Stop() end
end, nil)
autoFarmToggle.LayoutOrder = 3

-- ══════════ TAB ESP CONTENT ══════════
local pageESP = Instance.new("ScrollingFrame", content)
pageESP.Size = UDim2.new(1, 0, 1, 0)
pageESP.BackgroundTransparency = 1
pageESP.Visible = false
pageESP.BorderSizePixel = 0
pageESP.ScrollBarThickness = 2
pageESP.CanvasSize = UDim2.new(0, 0, 0, 50)
pageESP.ZIndex = 3
pages.esp = pageESP

local espLayout = Instance.new("UIListLayout", pageESP)
espLayout.Padding = UDim.new(0, 6)

createToggleRow(pageESP, "ESP Egg", API.ESP_IsEnabled(), false, function(state)
    API.ESP_Toggle()
end, nil)

-- TAY NẮM KÉO DÃN (RESIZE HANDLE) TÀNG HÌNH HOÀN TOÀN
local resizeBtn = Instance.new("TextButton", panel)
resizeBtn.Size = UDim2.new(0, 20, 0, 20)
resizeBtn.Position = UDim2.new(1, -20, 1, -20)
resizeBtn.BackgroundTransparency = 1 -- Tàn hình hoàn toàn
resizeBtn.Text = "" -- Không hiển thị biểu tượng
resizeBtn.AutoButtonColor = false
resizeBtn.ZIndex = 10

local resizing = false
local startSize, startMousePos

resizeBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        startSize = panel.Size
        startMousePos = input.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - startMousePos
        local newWidth = math.max(360, startSize.X.Offset + delta.X)
        local newHeight = math.max(160, startSize.Y.Offset + delta.Y)
        panel.Size = UDim2.new(0, newWidth, 0, newHeight)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = false
    end
end)

-- ══════════ KHỞI CHẠY ══════════
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
            Size = UDim2.new(0, 460, 0, 195),
            BackgroundTransparency = 0.55
        }):Play()
    end
end)

API.OnLog(function(msg) print("[StealEgg] " .. msg) end)

print("[Main] ✅ Ready v2.4 - Fully Fixed Dropdown, Glass Effect & Invisible Resize!")

