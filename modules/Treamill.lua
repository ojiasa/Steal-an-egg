-- ═══════════════════════════════════════════════════════════════
-- 🏃 TREADMILL — Module v8 (đẩy xuống đất, không xoá)
-- ═══════════════════════════════════════════════════════════════

local P  = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local W  = workspace
local UIS = game:GetService("UserInputService")

local M = {}

local enabled    = false
local savedState = {}          -- [part] = {originalCFrame, ...}
local mySlot     = nil
local myPlot     = nil
local pushedRenders = {}       -- [render] = {originalPosition}
local logCallbacks = {}

local REFRESH_INTERVAL = 0.3
local PUSH_DISTANCE = 500      -- đẩy xuống 500 studs

local IS_PC     = UIS.KeyboardEnabled and not UIS.TouchEnabled
local IS_MOBILE = UIS.TouchEnabled
local PLATFORM  = IS_PC and "PC" or (IS_MOBILE and "Mobile" or "Unknown")

local function log(msg)
    print("[Treadmill] " .. tostring(msg))
    for _, cb in ipairs(logCallbacks) do
        pcall(cb, msg)
    end
end

function M.OnLog(cb)
    if type(cb) == "function" then
        table.insert(logCallbacks, cb)
    end
end

log(string.format("Platform: %s", PLATFORM))

local function getMySlot()
    local Packages = RS:FindFirstChild("Packages")
    if not Packages then return nil end
    local NET = Packages:FindFirstChild("Networking")
    if not NET then return nil end
    local askState = NET:FindFirstChild("RF/Homestead/AskState")
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

-- ⭐ Đẩy 1 part xuống đất
local function pushObjectDown(obj)
    if not obj then return false end
    if savedState[obj] then return false end
    
    if obj:IsA("BasePart") then
        savedState[obj] = {
            CFrame = obj.CFrame,
            Anchored = obj.Anchored,
        }
        pcall(function()
            obj.Anchored = true
            obj.CFrame = obj.CFrame - Vector3.new(0, PUSH_DISTANCE, 0)
        end)
        return true
    end
    return false
end

-- ⭐ Đẩy treadmill trong plot mình xuống
local function pushMyTreadmill()
    local plot = getMyPlot()
    if not plot then return 0 end
    
    local count = 0
    for _, obj in ipairs(plot:GetDescendants()) do
        local n = obj.Name:lower()
        if n:find("tread") or n:find("belt") or n:find("runner") then
            if pushObjectDown(obj) then count = count + 1 end
        end
    end
    return count
end

-- ⭐ Đẩy render gần base mình xuống
local function pushMyRenders()
    local plot = getMyPlot()
    if not plot then return 0 end
    local cp = plot:FindFirstChild("CenterPoint", true)
    if not cp then return 0 end
    
    local myBasePos = cp.Position
    local render = W:FindFirstChild("__ClientTreadmillRenders")
    if not render then return 0 end
    
    local count = 0
    for _, child in ipairs(render:GetChildren()) do
        local part = child:FindFirstChildWhichIsA("BasePart", true)
        if part and (part.Position - myBasePos).Magnitude < 100 then
            -- Đẩy con này xuống
            for _, d in ipairs(child:GetDescendants()) do
                if d:IsA("BasePart") then
                    if not pushedRenders[d] then
                        pushedRenders[d] = {
                            CFrame = d.CFrame,
                            Anchored = d.Anchored,
                        }
                    end
                    pcall(function()
                        d.Anchored = true
                        d.CFrame = d.CFrame - Vector3.new(0, PUSH_DISTANCE, 0)
                    end)
                end
            end
            count = count + 1
        end
    end
    return count
end

-- ⭐ Restore parts
local function restoreAll()
    local count = 0
    for obj, data in pairs(savedState) do
        if obj and obj.Parent then
            pcall(function()
                obj.CFrame = data.CFrame
                obj.Anchored = data.Anchored
            end)
            count = count + 1
        end
    end
    savedState = {}
    
    for obj, data in pairs(pushedRenders) do
        if obj and obj.Parent then
            pcall(function()
                obj.CFrame = data.CFrame
                obj.Anchored = data.Anchored
            end)
        end
    end
    pushedRenders = {}
    
    return count
end

function M.hide()
    mySlot = getMySlot()
    myPlot = getMyPlot()
    if not myPlot then
        log("❌ Không tìm thấy plot (slot=" .. tostring(mySlot) .. ")")
        return 0
    end
    log("🏠 Plot: " .. myPlot.Name .. " | Slot: " .. tostring(mySlot))
    
    local c1 = pushMyTreadmill()
    local c2 = pushMyRenders()
    
    enabled = true
    log(string.format("🚫 Đẩy xuống %d parts + %d renders", c1, c2))
    return c1 + c2
end

function M.show()
    local count = restoreAll()
    enabled = false
    log(string.format("✅ Restore %d parts", count))
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

-- ⭐ AUTO re-push
task.spawn(function()
    while true do
        task.wait(REFRESH_INTERVAL)
        if enabled then
            pcall(function()
                if not myPlot or not myPlot.Parent then
                    mySlot = getMySlot()
                    myPlot = getMyPlot()
                end
                pushMyTreadmill()
                pushMyRenders()
            end)
        end
    end
end)

P.CharacterAdded:Connect(function()
    if enabled then
        task.wait(1)
        savedState = {}
        pushedRenders = {}
        mySlot = getMySlot()
        myPlot = getMyPlot()
        M.hide()
    end
end)

return M
