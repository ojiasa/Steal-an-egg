-- ═══════════════════════════════════════════════════════════════
-- 🏃 TREADMILL — Module v6 (ẩn hết render + treadmill plot mình)
-- ═══════════════════════════════════════════════════════════════

local P  = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local W  = workspace
local UIS = game:GetService("UserInputService")

local M = {}

local enabled    = false
local savedState = {}
local mySlot     = nil
local myPlot     = nil
local deletedRenders = {}

local REFRESH_INTERVAL = 0.3

local IS_PC     = UIS.KeyboardEnabled and not UIS.TouchEnabled
local IS_MOBILE = UIS.TouchEnabled
local PLATFORM  = IS_PC and "PC" or (IS_MOBILE and "Mobile" or "Unknown")

print(string.format("[Treadmill] Platform: %s", PLATFORM))

local function getMySlot()
    local NET = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
    local askState = NET and NET:FindFirstChild("RF/Homestead/AskState")
    if not askState then return nil end
    local ok, state = pcall(function() return askState:InvokeServer() end)
    if not ok or type(state) ~= "table" then return nil end
    local owners = state.OwnersBySlot
    if not owners then return nil end
    for slot, id in pairs(owners) do
        if tostring(id) == tostring(P.UserId) then return slot end
    end
    return nil
end

local function getMyPlot()
    if not mySlot then mySlot = getMySlot() end
    if not mySlot then return nil end
    local plots = W:FindFirstChild("Plots")
    if not plots then return nil end
    local n = tostring(mySlot)
    for _, obj in ipairs(plots:GetChildren()) do
        if obj.Name == n or obj.Name:find(n, 1, true) then return obj end
    end
    return nil
end

local function hideObject(obj)
    if not obj then return false end
    if savedState[obj] then return false end
    
    if obj:IsA("BasePart") then
        savedState[obj] = {
            CanCollide = obj.CanCollide,
            CanQuery = obj.CanQuery,
            CanTouch = obj.CanTouch,
            Transparency = obj.Transparency,
            LocalTransparencyModifier = obj.LocalTransparencyModifier,
        }
        pcall(function()
            obj.CanCollide = false
            obj.CanQuery = false
            obj.CanTouch = false
            obj.Transparency = 1
            obj.LocalTransparencyModifier = 1
        end)
        return true
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        savedState[obj] = {Transparency = obj.Transparency}
        pcall(function() obj.Transparency = 1 end)
        return true
    elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
        savedState[obj] = {Enabled = obj.Enabled}
        pcall(function() obj.Enabled = false end)
        return true
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
        savedState[obj] = {Enabled = obj.Enabled}
        pcall(function() obj.Enabled = false end)
        return true
    elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
        savedState[obj] = {Enabled = obj.Enabled}
        pcall(function() obj.Enabled = false end)
        return true
    end
    return false
end

-- ⭐ Ẩn tất cả treadmill trong plot của mình (dùng :GetDescendants() để tìm bất kỳ tên nào)
local function hideMyTreadmill()
    local plot = getMyPlot()
    if not plot then return 0 end
    
    local count = 0
    
    -- Duyệt tất cả descendants, tìm theo keyword
    for _, obj in ipairs(plot:GetDescendants()) do
        local n = obj.Name:lower()
        if n:find("tread") or n:find("belt") or n:find("runner") then
            if hideObject(obj) then count = count + 1 end
        end
    end
    
    return count
end

-- ⭐ Ẩn TẤT CẢ render (vì random, ẩn hết cho chắc)
local function hideAllRenders()
    local render = W:FindFirstChild("__ClientTreadmillRenders")
    if not render then return 0 end
    
    local count = 0
    for _, child in ipairs(render:GetChildren()) do
        if not deletedRenders[child] then
            deletedRenders[child] = child:Clone()
        end
        child:Destroy()
        count = count + 1
    end
    
    -- Xoá luôn folder nếu rỗng
    if #render:GetChildren() == 0 then
        render:Destroy()
    end
    
    return count
end

local function showAllRenders()
    -- Tạo lại folder nếu chưa có
    local render = W:FindFirstChild("__ClientTreadmillRenders")
    if not render then
        render = Instance.new("Folder")
        render.Name = "__ClientTreadmillRenders"
        render.Parent = W
    end
    
    for _, clone in pairs(deletedRenders) do
        local exists = false
        for _, c in ipairs(render:GetChildren()) do
            if c.Name == clone.Name then exists = true; break end
        end
        if not exists then
            clone:Clone().Parent = render
        end
    end
    deletedRenders = {}
end

function M.hide()
    mySlot = getMySlot()
    myPlot = getMyPlot()
    
    if not myPlot then
        print("[Treadmill] ❌ Không tìm thấy plot (slot=" .. tostring(mySlot) .. ")")
        return 0
    end
    print("[Treadmill] 🏠 Plot:", myPlot.Name, "| Slot:", mySlot)
    
    local countPart = hideMyTreadmill()
    local countRender = hideAllRenders()
    
    enabled = true
    print(string.format("[Treadmill] 🚫 Ẩn %d parts + %d renders", countPart, countRender))
    return countPart + countRender
end

function M.show()
    local count = 0
    for obj, data in pairs(savedState) do
        if obj and obj.Parent then
            pcall(function()
                for k, v in pairs(data) do obj[k] = v end
            end)
            count = count + 1
        end
    end
    savedState = {}
    showAllRenders()
    enabled = false
    print(string.format("[Treadmill] ✅ Hiện %d parts", count))
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
    mySlot = getMySlot()
    myPlot = getMyPlot()
    return myPlot ~= nil
end

-- ⭐ AUTO re-hide
task.spawn(function()
    while true do
        task.wait(REFRESH_INTERVAL)
        if enabled then
            pcall(function()
                if not myPlot or not myPlot.Parent then
                    mySlot = getMySlot()
                    myPlot = getMyPlot()
                end
                hideMyTreadmill()
                hideAllRenders()
            end)
        end
    end
end)

P.CharacterAdded:Connect(function()
    if enabled then
        task.wait(1)
        savedState = {}
        mySlot = getMySlot()
        myPlot = getMyPlot()
        M.hide()
    end
end)

return M
