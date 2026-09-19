-- ═══════════════════════════════════════════════════════════════
-- 🏃 ANTI-TREADMILL — Module (folder riêng, tab trong main)
-- ═══════════════════════════════════════════════════════════════

local P  = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local W  = workspace
local UIS = game:GetService("UserInputService")

local M = {}

local enabled    = false
local savedState = {}
local hiddenRenderFolder = nil
local renderOriginalParent = nil

local REFRESH_INTERVAL = 0.5

local IS_PC     = UIS.KeyboardEnabled and not UIS.TouchEnabled
local IS_MOBILE = UIS.TouchEnabled
local PLATFORM  = IS_PC and "PC" or (IS_MOBILE and "Mobile" or "Unknown")

print(string.format("[AntiTreadmill] Platform: %s", PLATFORM))

local function findRealTreadmills()
    local list = {}
    local plots = W:FindFirstChild("Plots")
    if not plots then return list end
    for _, plot in ipairs(plots:GetChildren()) do
        local bottom = plot:FindFirstChild("TreadmillBottom")
        if bottom then table.insert(list, bottom) end
        local upgrade = plot:FindFirstChild("TreadmillUpgrade")
        if upgrade then
            for _, d in ipairs(upgrade:GetDescendants()) do
                if d:IsA("BasePart") then table.insert(list, d) end
            end
        end
    end
    return list
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

local function hideRender()
    local render = W:FindFirstChild("__ClientTreadmillRenders")
    if not render then return false end
    renderOriginalParent = W
    pcall(function() render.Parent = RS end)
    hiddenRenderFolder = render
    return true
end

local function showRender()
    local render = RS:FindFirstChild("__ClientTreadmillRenders")
    if render and renderOriginalParent then
        pcall(function() render.Parent = renderOriginalParent end)
    end
    hiddenRenderFolder = nil
end

function M.hide()
    local parts = findRealTreadmills()
    local count = 0
    for _, p in ipairs(parts) do
        if hidePart(p) then count = count + 1 end
    end
    hideRender()
    enabled = true
    print(string.format("[AntiTreadmill] 🚫 Hidden %d parts", count))
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
    print(string.format("[AntiTreadmill] ✅ Shown %d parts", count))
    return count
end

function M.toggle()
    if enabled then M.show() else M.hide() end
    return enabled
end

function M.isEnabled() return enabled end

function M.getCount()
    local n = 0
    for _ in pairs(savedState) do n = n + 1 end
    return n
end

function M.getPlatform() return PLATFORM end

task.spawn(function()
    while true do
        task.wait(REFRESH_INTERVAL)
        if enabled then
            pcall(function()
                local parts = findRealTreadmills()
                for _, p in ipairs(parts) do
                    if p.CanCollide == true or p.Transparency ~= 1 then
                        hidePart(p)
                    end
                end
                local render = W:FindFirstChild("__ClientTreadmillRenders")
                if render then
                    renderOriginalParent = W
                    pcall(function() render.Parent = RS end)
                    hiddenRenderFolder = render
                end
            end)
        end
    end
end)

P.CharacterAdded:Connect(function()
    if enabled then
        task.wait(1)
        savedState = {}
        M.hide()
    end
end)

return M
