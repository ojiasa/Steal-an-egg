-- ═══════════════════════════════════════════════════════════════
-- PET TOOL MODULE v16.7 — FIX BÁN PET THÀNH CÔNG
-- ⭐ SellPet:FireServer(uid, true) — arg thứ 2 là confirm flag
-- ⭐ Income tính bằng AssetEarnings (chính xác 100%)
-- ⭐ Auto Equip qua RF/Haul/WearBest
-- ═══════════════════════════════════════════════════════════════

local P = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")

local M = {}

local config = {
    AUTO_SELL_ENABLED   = false,
    AUTO_EQUIP_ENABLED  = false,
    SELL_THRESHOLD      = 10000000,
    EQUIP_INTERVAL      = 5,
    EQUIP_ON_START      = true,
    LOOP_DELAY          = 1.0,
    SELL_DELAY          = 0.3,
    EQUIP_SYNC_WAIT     = 1.0,
}

local isRunning = false
local logs = {}
local logCallbacks = {}
local stats = {
    totalSold = 0,
    totalEquipped = 0,
    lastRunTime = 0,
    cyclesRun = 0,
}

local Networking = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")

local remotes = {
    sellPet       = Networking and Networking:FindFirstChild("RE/PetSatchel/SellPet"),
    sellSelection = Networking and Networking:FindFirstChild("RE/PetSatchel/SellSelection"),
    sellEveryPet  = Networking and Networking:FindFirstChild("RE/PetSatchel/SellEveryPet"),
    wearBest      = Networking and Networking:FindFirstChild("RF/Haul/WearBest"),
}

print("[PetTool v16.7] Remote search:")
for k, v in pairs(remotes) do
    print(string.format("  %s = %s", k, v and v:GetFullName() or "❌ nil"))
end

local AssetEarnings
pcall(function()
    local shared = RS:FindFirstChild("Shared")
    local util = shared and shared:FindFirstChild("Util")
    local mod = util and util:FindFirstChild("AssetEarnings")
    if mod then AssetEarnings = require(mod) end
end)

local function log(txt, color)
    table.insert(logs, { text = tostring(txt), time = os.clock(), color = color })
    if #logs > 200 then table.remove(logs, 1) end
    for _, cb in ipairs(logCallbacks) do pcall(cb, txt) end
    print("[PetTool] " .. tostring(txt))
end

function M.onLog(cb)
    if type(cb) == "function" then table.insert(logCallbacks, cb) end
end

local function fmtMoney(n)
    if type(n) ~= "number" then return "?" end
    if n >= 1e12 then return string.format("$%.2fT", n/1e12) end
    if n >= 1e9 then return string.format("$%.2fB", n/1e9) end
    if n >= 1e6 then return string.format("$%.2fM", n/1e6) end
    if n >= 1e3 then return string.format("$%.0fK", n/1e3) end
    return string.format("$%.0f", n)
end

local function computeIncomeFromTool(tool)
    if not AssetEarnings then return 0 end
    local cat = tool:GetAttribute("Category") or tool:GetAttribute("AssetCategory")
    local scale = tool:GetAttribute("Scale") or tool:GetAttribute("AssetScale") or 1
    local mutStr = tool:GetAttribute("Mutations") or ""
    if not cat then return 0 end

    local mutations = {}
    if type(mutStr) == "string" and #mutStr > 0 then
        for m in mutStr:gmatch("[^,]+") do
            m = m:match("^%s*(.-)%s*$")
            if #m > 0 then table.insert(mutations, m) end
        end
    end

    local input = { Category = cat, Scale = scale, Mutations = mutations }
    local ok, val = pcall(AssetEarnings.LiveRatePerSecond, input)
    if ok and type(val) == "number" and val > 0 then return val end
    ok, val = pcall(AssetEarnings.RatePerSecond, input)
    if ok and type(val) == "number" and val > 0 then return val end
    return 0
end

local function scanEquippedUids()
    local equippedUids = {}
    local myUserId = P.UserId
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local ownerAttr = obj:GetAttribute("OwnerUserId") or obj:GetAttribute("Owner")
            local uidAttr = obj:GetAttribute("Uid") or obj:GetAttribute("UID")
            if ownerAttr == myUserId and uidAttr then
                equippedUids[tostring(uidAttr)] = true
            end
        end
    end
    return equippedUids
end

local function scanBackpackPets()
    local pets = {}
    local backpack = P:FindFirstChild("Backpack")
    if not backpack then return pets end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local cat = tool:GetAttribute("Category") or tool:GetAttribute("AssetCategory")
            local uid = tool:GetAttribute("Uid") or tool:GetAttribute("UID")
                or tool:GetAttribute("Id") or tool:GetAttribute("ID")
            if cat and uid then
                local ln = tool.Name:lower()
                local lc = tostring(cat):lower()
                if not ln:find("egg", 1, true) and not lc:find("egg", 1, true)
                    and not ln:find("trap", 1, true) and not ln:find("bat", 1, true)
                    and not ln:find("gậy", 1, true) and not ln:find("consumable", 1, true)
                    and not ln:find("mutation", 1, true) and not ln:find("rod", 1, true) then
                    table.insert(pets, {
                        name = tool.Name,
                        uid = tostring(uid),
                        cat = cat,
                        instance = tool,
                    })
                end
            end
        end
    end
    return pets
end

local lastEquipTime = 0

local function runAutoEquip()
    if not remotes.wearBest then
        log("❌ Không có WearBest")
        return false
    end
    log("🎽 AUTO EQUIP BEST...")

    local ok, result = pcall(function()
        return remotes.wearBest:InvokeServer()
    end)

    if ok then
        log(string.format("✅ Equip OK (result=%s)", tostring(result)))
        stats.totalEquipped = stats.totalEquipped + 1
        lastEquipTime = os.clock()
        return true
    else
        log(string.format("❌ Equip fail: %s", tostring(result)))
        return false
    end
end

local function runAutoSell()
    if not remotes.sellPet then
        log("❌ Không có SellPet")
        return 0
    end
    if not AssetEarnings then
        log("❌ Không có AssetEarnings")
        return 0
    end

    if os.clock() - lastEquipTime < config.EQUIP_SYNC_WAIT then
        log(string.format("⏭ Skip sell — vừa equip %.1fs trước",
            os.clock() - lastEquipTime))
        return 0
    end

    local backpackPets = scanBackpackPets()
    if #backpackPets == 0 then
        log("ℹ Không có pet")
        return 0
    end

    local equippedUids = scanEquippedUids()
    local toSell = {}
    local keepCount = 0

    for _, pet in ipairs(backpackPets) do
        if not equippedUids[pet.uid] then
            local income = computeIncomeFromTool(pet.instance)
            if income < config.SELL_THRESHOLD then
                table.insert(toSell, { pet = pet, income = income })
            else
                keepCount = keepCount + 1
            end
        end
    end

    if #toSell == 0 then
        log(string.format("ℹ Không pet nào < %s (giữ: %d, tổng: %d)",
            fmtMoney(config.SELL_THRESHOLD), keepCount, #backpackPets))
        return 0
    end

    log(string.format("💸 AUTO SELL: %d pet (< %s)", #toSell, fmtMoney(config.SELL_THRESHOLD)))

    local soldCount = 0
    for i, item in ipairs(toSell) do
        local pet = item.pet
        -- ⭐ v16.7: Thêm arg `true` (confirm flag)
        local success = pcall(function()
            remotes.sellPet:FireServer(pet.uid, true)
        end)

        if success then
            soldCount = soldCount + 1
            log(string.format("  [%d/%d] ✅ %s (%s)",
                i, #toSell, pet.name:sub(1, 30), fmtMoney(item.income) .. "/s"))
        else
            log(string.format("  [%d/%d] ❌ %s", i, #toSell, pet.name:sub(1, 30)))
        end
        task.wait(config.SELL_DELAY)
    end

    stats.totalSold = stats.totalSold + soldCount
    log(string.format("🏁 Đã bán %d/%d", soldCount, #toSell))
    return soldCount
end

local function mainLoop()
    log("═══════════════════════════")
    log("🚀 PET TOOL v16.7 STARTED")
    log(string.format("   Auto Sell: %s | Auto Equip: %s",
        config.AUTO_SELL_ENABLED and "ON" or "OFF",
        config.AUTO_EQUIP_ENABLED and "ON" or "OFF"))
    log(string.format("   Threshold: %s", fmtMoney(config.SELL_THRESHOLD)))
    log(string.format("   SellPet: %s", remotes.sellPet and "✅" or "❌"))
    log(string.format("   WearBest: %s", remotes.wearBest and "✅" or "❌"))
    log(string.format("   AssetEarnings: %s", AssetEarnings and "✅" or "❌"))
    log("═══════════════════════════")

    while isRunning do
        stats.cyclesRun = stats.cyclesRun + 1
        local cycleStart = os.clock()

        if config.AUTO_EQUIP_ENABLED then
            if os.clock() - lastEquipTime >= config.EQUIP_INTERVAL
                or config.EQUIP_ON_START then
                runAutoEquip()
                config.EQUIP_ON_START = false
                task.wait(2)
            end
        end

        if config.AUTO_SELL_ENABLED then
            runAutoSell()
        end

        stats.lastRunTime = os.clock() - cycleStart
        task.wait(config.LOOP_DELAY)
    end

    log("🛑 STOPPED")
end

function M.start()
    if isRunning then return end
    if not AssetEarnings then log("❌ AssetEarnings nil"); return end
    if not remotes.sellPet then log("❌ SellPet nil"); return end
    isRunning = true
    config.EQUIP_ON_START = true
    lastEquipTime = 0
    task.spawn(mainLoop)
end

function M.stop() isRunning = false end
function M.isRunning() return isRunning end

function M.setAutoSell(enabled)
    config.AUTO_SELL_ENABLED = enabled and true or false
    log(string.format("💰 Auto Sell: %s", enabled and "BẬT" or "TẮT"))
    return config.AUTO_SELL_ENABLED
end

function M.toggleAutoSell() return M.setAutoSell(not config.AUTO_SELL_ENABLED) end
function M.isAutoSellEnabled() return config.AUTO_SELL_ENABLED end

function M.setAutoEquip(enabled)
    config.AUTO_EQUIP_ENABLED = enabled and true or false
    if enabled then config.EQUIP_ON_START = true end
    log(string.format("🎽 Auto Equip: %s", enabled and "BẬT" or "TẮT"))
    return config.AUTO_EQUIP_ENABLED
end

function M.toggleAutoEquip() return M.setAutoEquip(not config.AUTO_EQUIP_ENABLED) end
function M.isAutoEquipEnabled() return config.AUTO_EQUIP_ENABLED end

function M.setSellThreshold(value)
    config.SELL_THRESHOLD = tonumber(value) or 10000000
    log(string.format("💰 Ngưỡng: %s", fmtMoney(config.SELL_THRESHOLD)))
end

function M.getSellThreshold() return config.SELL_THRESHOLD end
function M.setIncludeZero(enabled) log("ℹ v16.7 không dùng") end
function M.setEquipInterval(seconds) config.EQUIP_INTERVAL = tonumber(seconds) or 5 end
function M.setEquipSyncWait(seconds) config.EQUIP_SYNC_WAIT = tonumber(seconds) or 1.0 end

function M.runOnce()
    task.spawn(function()
        log("═══ RUN ONCE ═══")
        if config.AUTO_EQUIP_ENABLED then
            runAutoEquip()
            task.wait(2)
        end
        if config.AUTO_SELL_ENABLED then
            runAutoSell()
        end
        log("═══ XONG ═══")
    end)
end

function M.scanInfo()
    task.spawn(function()
        local bp = scanBackpackPets()
        local eq = scanEquippedUids()
        local eqN = 0
        for _ in pairs(eq) do eqN = eqN + 1 end

        log("═══════ SCAN INFO ═══════")
        log(string.format("📊 Backpack: %d pet | Equip: %d", #bp, eqN))

        for i = 1, math.min(10, #bp) do
            local pet = bp[i]
            local income = computeIncomeFromTool(pet.instance)
            local status
            if eq[pet.uid] then status = "[EQUIP]"
            elseif income < config.SELL_THRESHOLD then status = "→ SELL"
            else status = "→ KEEP" end

            log(string.format("  [%d] %s — %s %s",
                i, pet.name:sub(1, 25), fmtMoney(income) .. "/s", status))
        end
        log("════════════════════════")
    end)
end

function M.getStats()
    return {
        totalSold = stats.totalSold,
        totalEquipped = stats.totalEquipped,
        cyclesRun = stats.cyclesRun,
        lastRunTime = stats.lastRunTime,
        autoSellEnabled = config.AUTO_SELL_ENABLED,
        autoEquipEnabled = config.AUTO_EQUIP_ENABLED,
        sellThreshold = config.SELL_THRESHOLD,
    }
end

function M.getLogs() return logs end
function M.clearLogs() logs = {} end
function M.getConfig() return config end
function M.clearCache() log("ℹ v16.7 không dùng cache") end
function M.getIncomeCache() return {} end
function M.setLoopDelay(s) config.LOOP_DELAY = tonumber(s) or 1.0 end
function M.setSellDelay(s) config.SELL_DELAY = tonumber(s) or 0.3 end

return M
