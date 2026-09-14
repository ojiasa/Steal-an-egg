-- ═══════════════════════════════════════════════════════════════
-- UI MENU — icon 🌀 + panel + nút bật tắt
-- Yêu cầu: _G.StealEgg đã load xong
-- ═══════════════════════════════════════════════════════════════

-- ⭐ Load script trước nếu chưa có
if not _G.StealEgg then
    loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/ojiasa/Steal-an-egg/main/loader.lua"
    ))()
    repeat task.wait() until _G.StealEgg
end

local API = _G.StealEgg
local P   = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")

-- ══════════ UI CHÍNH ══════════
local sg = Instance.new("ScreenGui")
sg.Name = "StealEggUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999
sg.Parent = (gethui and gethui()) or P:WaitForChild("PlayerGui")

-- ⭐ Icon tròn nhỏ
local icon = Instance.new("TextButton")
icon.Size = UDim2.new(0, 50, 0, 50)
icon.Position = UDim2.new(0, 15, 0, 150)
icon.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
icon.Text = "🌀"
icon.TextSize = 22
icon.Font = Enum.Font.GothamBold
icon.TextColor3 = Color3.fromRGB(120, 200, 255)
icon.AutoButtonColor = false
icon.Parent = sg
Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
local stk = Instance.new("UIStroke")
stk.Color = Color3.fromRGB(120, 200, 255)
stk.Thickness = 2
stk.Parent = icon

-- ⭐ Panel menu
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 280, 0, 340)
panel.Position = UDim2.new(0.5, -140, 0.5, -170)
panel.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local pstk = Instance.new("UIStroke")
pstk.Color = Color3.fromRGB(120, 200, 255)
pstk.Thickness = 1.5
pstk.Parent = panel

-- Title bar
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundColor3 = Color3.fromRGB(22, 24, 33)
title.Text = "🌀 STEAL EGG v" .. API.Version
title.TextColor3 = Color3.fromRGB(180, 230, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.Parent = panel
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 22)
closeBtn.Position = UDim2.new(1, -30, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 11
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

-- ⭐ Nút START/STOP FARM
local farmBtn = Instance.new("TextButton")
farmBtn.Size = UDim2.new(1, -20, 0, 45)
farmBtn.Position = UDim2.new(0, 10, 0, 45)
farmBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
farmBtn.Text = "▶ BẮT ĐẦU FARM"
farmBtn.TextColor3 = Color3.new(0, 0, 0)
farmBtn.Font = Enum.Font.GothamBold
farmBtn.TextSize = 13
farmBtn.Parent = panel
Instance.new("UICorner", farmBtn).CornerRadius = UDim.new(0, 6)

-- ⭐ Nút ESP
local espBtn = Instance.new("TextButton")
espBtn.Size = UDim2.new(1, -20, 0, 45)
espBtn.Position = UDim2.new(0, 10, 0, 100)
espBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 180)
espBtn.Text = "👁 BẬT ESP"
espBtn.TextColor3 = Color3.new(1, 1, 1)
espBtn.Font = Enum.Font.GothamBold
espBtn.TextSize = 13
espBtn.Parent = panel
Instance.new("UICorner", espBtn).CornerRadius = UDim.new(0, 6)

-- ⭐ SET HOME
local homeBtn = Instance.new("TextButton")
homeBtn.Size = UDim2.new(1, -20, 0, 35)
homeBtn.Position = UDim2.new(0, 10, 0, 155)
homeBtn.BackgroundColor3 = Color3.fromRGB(200, 130, 40)
homeBtn.Text = "📍 SET HOME"
homeBtn.TextColor3 = Color3.new(0, 0, 0)
homeBtn.Font = Enum.Font.GothamBold
homeBtn.TextSize = 11
homeBtn.Parent = panel
Instance.new("UICorner", homeBtn).CornerRadius = UDim.new(0, 6)

-- ⭐ SET FOREST
local forestBtn = Instance.new("TextButton")
forestBtn.Size = UDim2.new(1, -20, 0, 35)
forestBtn.Position = UDim2.new(0, 10, 0, 195)
forestBtn.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
forestBtn.Text = "📍 SET FOREST"
forestBtn.TextColor3 = Color3.new(0, 0, 0)
forestBtn.Font = Enum.Font.GothamBold
forestBtn.TextSize = 11
forestBtn.Parent = panel
Instance.new("UICorner", forestBtn).CornerRadius = UDim.new(0, 6)

-- ⭐ LOG
local logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, -20, 0, 80)
logFrame.Position = UDim2.new(0, 10, 0, 240)
logFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 3
logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logFrame.Parent = panel
Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0, 4)

local logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.new(1, -6, 0, 0)
logLabel.Position = UDim2.new(0, 3, 0, 3)
logLabel.BackgroundTransparency = 1
logLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 9
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.TextWrapped = true
logLabel.AutomaticSize = Enum.AutomaticSize.Y
logLabel.Parent = logFrame

local logLines = {}
local function addLog(msg)
    table.insert(logLines, tostring(msg))
    if #logLines > 50 then table.remove(logLines, 1) end
    logLabel.Text = table.concat(logLines, "\n")
    logFrame.CanvasPosition = Vector2.new(0, 999999)
end

-- ══════════ KÉO ICON ══════════
local dragging, dragStart, startPos
icon.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = i.Position
        startPos = icon.Position
    end
end)
icon.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        icon.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

-- ══════════ KÉO PANEL ══════════
local pdrag, pds, psp
title.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
        pdrag, pds, psp = true, i.Position, panel.Position
    end
end)
title.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
        pdrag = false
    end
end)
UIS.InputChanged:Connect(function(i)
    if pdrag and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - pds
        panel.Position = UDim2.new(psp.X.Scale, psp.X.Offset + d.X,
            psp.Y.Scale, psp.Y.Offset + d.Y)
    end
end)

-- ══════════ TOGGLE PANEL ══════════
icon.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
end)
closeBtn.MouseButton1Click:Connect(function()
    panel.Visible = false
end)

-- ══════════ FARM BUTTON ══════════
farmBtn.MouseButton1Click:Connect(function()
    if API.IsRunning() then
        API.Stop()
        farmBtn.Text = "▶ BẮT ĐẦU FARM"
        farmBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
    else
        API.Start()
        farmBtn.Text = "⏹ DỪNG FARM"
        farmBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    end
end)

-- ══════════ ESP BUTTON ══════════
espBtn.MouseButton1Click:Connect(function()
    local on = API.ESP_Toggle()
    if on then
        espBtn.Text = "👁 TẮT ESP"
        espBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    else
        espBtn.Text = "👁 BẬT ESP"
        espBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 180)
    end
end)

-- ══════════ SET HOME/FOREST ══════════
homeBtn.MouseButton1Click:Connect(function()
    local hrp = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        API.SetHome(hrp.Position)
        addLog("📍 Home: " .. tostring(hrp.Position))
    end
end)

forestBtn.MouseButton1Click:Connect(function()
    local hrp = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        API.SetForest(hrp.Position)
        addLog("📍 Forest: " .. tostring(hrp.Position))
    end
end)

-- ══════════ HOOK LOG ══════════
API.OnLog(function(msg)
    addLog(msg)
end)

addLog("✅ UI ready")
