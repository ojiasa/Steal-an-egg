-- ═══════════════════════════════════════════════════════════════
-- 🏃 TREADMILL — Module v3 (chỉ ẩn plot của mình)
-- ═══════════════════════════════════════════════════════════════

local P  = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local W  = workspace
local UIS = game:GetService("UserInputService")

local M = {}

local enabled    = false
local savedState = {}
local myPlot     = nil
local clonedRenders = {}   -- [plotName] = cloned render

local REFRESH_INTERVAL = 0.3

local IS_PC     = UIS.KeyboardEnabled and not UIS.TouchEnabled
local IS_MOBILE = UIS.TouchEnabled
local PLATFORM  = IS_PC and "PC" or (IS_MOBILE and "Mobile" or "Unknown")

print(string.format("[Treadmill] Platform: %s", PLATFORM))

-- ⭐ Tìm plot của mình qua Homestead/AskState
local function findMyPlot()
    local NET = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
    local askState = NET and NET:FindFirstChild("RF/Homestead/AskState")
    if not askState then return nil end
    
    local ok, state = pcall(function() return askState:InvokeServer() end)
    if not ok or type(state) ~= "table" then return nil end
    
    local owners = state.OwnersBySlot
    if not owners then return nil end
    
    local mySlot = nil
    for slot, id in pairs(owners) do
        if tostring(id) == tostring(P.UserId) then
            mySlot = slot
            break
        end
    end
    if not mySlot then return nil end
    
    local plots = W:FindFirstChild("Plots")
    if not plots then return nil end
    
    local n = tostring(mySlot)
    for _, obj in ipairs(plots:GetChildren()) do
        if obj.Name == n or obj.Name:find(n, 1, true) then
            return obj, mySlot
        end
    end
    return nil
end

-- ⭐ Tìm treadmill trong plot của mình
local function findMyTreadmills()
    local list = {}
    if not myPlot then return list end
    
    local bottom = myPlot:FindFirstChild("TreadmillBottom", true)
    if bottom then table.insert(list, bottom) end
    
    local upgrade = myPlot:FindFirstChild("TreadmillUpgrade", true)
    if upgrade then
        for _, d in ipairs(upgrade:GetDescendants()) do
            if d:IsA("BasePart") then table.insert(list, d) end
        end
    end
    return list
end

-- ⭐ Tìm render folder gần base mình (trong bán kính 100 studs)
local function findNearbyRenderFolder()
    local render = W:FindFirstChild("__ClientTreadmillRenders")
    if not render then return nil end
    
    local cp = myPlot and myPlot:FindFirstChild("CenterPoint", true)
    if not cp then
        -- Không có CenterPoint → trả về folder chính
        return render
    end
    
    local myPos = cp.Position
    
    -- Duyệt các con của render folder, tìm cái gần base mình
    for _, child in ipairs(render:GetChildren()) do
        local part = child:FindFirstChildWhichIsA("BasePart", true)
        if part and (part.Position - myPos).Magnitude < 100 then
            return child  -- chỉ con này là render của base mình
        end
    end
    
    -- Nếu không match → trả về folder chính (fallback)
    return render
end

local function hidePart(p)
    if not p then return false end
    if not savedState[p] then
        savedState[p] = {
            CanCollide = p.CanCollide,
            CanQuery = p.CanQuery,
            CanTouch = p.CanTouch,
            Transparency = p.Transparency,
            LocalTransparencyModifier = p.LocalTransparencyModifier,
        }
    end
    pcall(function()
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.Transparency = 1
        p.LocalTransparencyModifier = 1
    end)
    return true
end

-- ⭐ Ẩn render folder gần base
local function hideRender()
    local target = findNearbyRenderFolder()
    if not target then 
        print("[Treadmill] ⚠ Không thấy render")
        return false 
    end
    
    local key = tostring(target)
    if not clonedRenders[key] then
        clonedRenders[key] = target:Clone()
        clonedRenders[key].Name = target.Name .. "_Backup"
        print("[Treadmill] 📸 Clone render:", target:GetFullName())
    end
    
    target:Destroy()
    print("[Treadmill] 🗑 Xoá render:", target:GetFullName())
    return true
end

local function showRender()
    for key, clone in pairs(clonedRenders) do
        local existing = W:FindFirstChild(clone.Name:gsub("_Backup$", ""), true)
        if not existing then
            clone:Clone().Parent = W
        end
    end
    clonedRenders = {}
    print("[Treadmill] ♻ Restore render")
end

function M.hide()
    -- Refresh plot
    myPlot = findMyPlot()
    if not myPlot then
        print("[Treadmill] ❌ Không tìm thấy plot")
        return 0
    end
    print("[Treadmill] 🏠 Plot:", myPlot.Name)
    
    -- Ẩn parts
    local parts = findMyTreadmills()
    local count = 0
    for _, p in ipairs(parts) do
        if hidePart(p) then count = count + 1 end
    end
    
    -- Ẩn render
    hideRender()
    
    enabled = true
    print(string.format("[Treadmill] 🚫 Hidden %d parts", count))
    return count
end

function M.show()
    local count = 0
    for part, data in pairs(savedState) do
        if part and part.Parent then
            pcall(function()
                for k, v in pairs(data) do part[k] = v end
            end)
            count = count + 1
        end
    end
    savedState = {}
    showRender()
    enabled = false
    print(string.format("[Treadmill] ✅ Shown %d parts", count))
    return count
end

function M.toggle()
    if enabled then M.show() else M.hide() end
    return enabled
end

function M.isEnabled() return enabled end
function M.setEnabled(on)
    if on then return M.hide() else return M.show() end
end
function M.getCount()
    local n = 0
    for _ in pairs(savedState) do n = n + 1 end
    return n
end
function M.getPlatform() return PLATFORM end
function M.refreshPlot()
    myPlot = findMyPlot()
    return myPlot ~= nil
end

-- ⭐ AUTO re-hide
task.spawn(function()
    while true do
        task.wait(REFRESH_INTERVAL)
        if enabled then
            pcall(function()
                if not myPlot or not myPlot.Parent then
                    myPlot = findMyPlot()
                end
                local parts = findMyTreadmills()
                for _, p in ipairs(parts) do
                    if p.CanCollide == true or p.Transparency ~= 1 then
                        hidePart(p)
                    end
                end
                -- Re-delete render
                local target = findNearbyRenderFolder()
                if target and target.Parent then
                    hideRender()
                end
            end)
        end
    end
end)

P.CharacterAdded:Connect(function()
    if enabled then
        task.wait(1)
        savedState = {}
        myPlot = findMyPlot()
        M.hide()
    end
end)

return M
