-- ═══════════════════════════════════════════════════════════════
-- PET TOOL MODULE v16.1 — Classifier cho 2 chức năng chính
-- 1. Auto Sell (theo value m)
-- 2. Auto Equip Best (WearBest)
-- v16.1: Fix bug bán hết khi set threshold
--        - SELL_INCLUDE_ZERO = false mặc định
--        - Chỉ bán pet CÓ trong incomeCache (không fallback = 0)
--        - Cache cả pet income = 0 (để phân biệt "chưa biết" vs "biết là 0")
--        - Skip sell nếu vừa equip xong < 1s (tránh bán pet vừa swap)
-- ═══════════════════════════════════════════════════════════════

local P = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")

local M = {}

-- ══════════ CONFIG ══════════
local config = {
    -- Feature toggles
    AUTO_SELL_ENABLED   = false,
    AUTO_EQUIP_ENABLED  = false,
    
    -- Auto Sell config
    SELL_THRESHOLD      = 10000000,  -- 10M $/s (mặc định mới)
    SELL_INCLUDE_ZERO   = false,     -- ⭐ v16.1: false — không bán pet income=0/chưa biết
    
    -- Auto Equip config
    EQUIP_INTERVAL      = 5,
    EQUIP_ON_START      = true,
    
    -- Timing
    LOOP_DELAY          = 1.0,
    SELL_DELAY          = 0.3,
    EQUIP_SYNC_WAIT     = 1.0,       -- ⭐ v16.1: chờ sau equip trước khi sell
}

-- ══════════ STATE ══════════
local isRunning = false
local logs = {}
local logCallbacks = {}
local stats = {
    totalSold = 0,
    totalEquipped = 0,
    lastRunTime = 0,
    cyclesRun = 0,
}

-- ══════════ REMOTES ══════════
local NET = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
local remotes = {
    askSale      = NET and NET:FindFirstChild("RF/PenRoster/AskSale"),
    askSnapshot  = NET and NET:FindFirstChild("RF/PenRoster/AskLiveSnapshot"),
    wearBest     = NET and NET:FindFirstChild("RF/Haul/WearBest"),
    fetchStatus  = NET and NET:FindFirstChild("RF/Haul/FetchWearBestStatus"),
}

-- ══════════ LOG HELPER ══════════
local function log(txt, color)
    table.insert(logs, { text = tostring(txt), time = os.clock(), color = color })
    if #logs > 200 then table.remove(logs, 1) end
    
    for _, cb in ipairs(logCallbacks) do pcall(cb, txt) end
    print("[PetTool] " .. tostring(txt))
end

function M.onLog(cb)
    if type(cb) == "function" then table.insert(logCallbacks, cb) end
end

-- ══════════ FORMAT MONEY ══════════
local function fmtMoney(n)
    if type(n) ~= "number" then return "?" end
    if n >= 1e12 then return string.format("$%.2fT", n/1e12) end
    if n >= 1e9 then return string.format("$%.2fB", n/1e9) end
    if n >= 1e6 then return string.format("$%.2fM", n/1e6) end
    if n >= 1e3 then return string.format("$%.0fK", n/1e3) end
    return string.format("$%.0f", n)
end

-- ══════════ SCAN EQUIPPED ══════════
local function scanEquippedUids()
    local equippedUids = {}
    local myUserId = P.UserId
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local ownerAttr = obj:GetAttribute("OwnerUserId") or obj:GetAttribute("Owner")
            local uidAttr = obj:GetAttribute("Uid") or obj:GetAttribute("UID")
            
            if ownerAttr == myUserId and uidAttr then
                equippedUids[uidAttr] = true
            end
        end
    end
    
    return equippedUids
end

-- ══════════ SCAN BACKPACK ══════════
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
                
                -- Bỏ egg / gear / consumable
                if not ln:find("egg", 1, true) and not lc:find("egg", 1, true)
                    and not ln:find("trap", 1, true) and not ln:find("bat", 1, true)
                    and not ln:find("gậy", 1, true) and not ln:find("consumable", 1, true)
                    and not ln:find("mutation", 1, true) and not ln:find("rod", 1, true) then
                    
                    table.insert(pets, {
                        name = tool.Name,
                        uid = uid,
                        cat = cat,
                        instance = tool,
                    })
                end
            end
        end
    end
    
    return pets
end

-- ══════════ FETCH SNAPSHOT (INCOME CACHE) ══════════
local incomeCache = {}

local function fetchSnapshotIncome()
    if not remotes.askSnapshot then
        log("❌ Không có AskLiveSnapshot")
        return false
    end
    
    local ok, result = pcall(function() return remotes.askSnapshot:InvokeServer() end)
    if not ok or type(result) ~= "table" then
        log("❌ Snapshot fail")
        return false
    end
    
    local myUserId = P.UserId
    local count = 0
    local newCount = 0
    
    for _, ownerData in pairs(result) do
        if type(ownerData) == "table" and ownerData.OwnerUserId == myUserId
            and type(ownerData.Records) == "table" then
            for uid, rec in pairs(ownerData.Records) do
                if type(rec) == "table" then
                    local income = rec.MoneyPerSecond or 0
                    -- ⭐ v16.1: Cache CẢ income = 0 (để phân biệt "biết là 0" vs "chưa biết")
                    if incomeCache[uid] == nil then newCount = newCount + 1 end
                    incomeCache[uid] = income
                    count = count + 1
                end
            end
            break
        end
    end
    
    log(string.format("📸 Snapshot: %d pet (+%d cache mới)", count, newCount))
    return true
end

-- ══════════ CHỨC NĂNG 1: AUTO EQUIP BEST ══════════
local lastEquipTime = 0

local function runAutoEquip()
    if not remotes.wearBest then
        log("❌ Không có WearBest")
        return false
    end
    
    log("🎽 AUTO EQUIP BEST...")
    
    local ok, result = pcall(function() return remotes.wearBest:InvokeServer() end)
    
    if ok and result == true then
        log("✅ Equip best thành công")
        stats.totalEquipped = stats.totalEquipped + 1
        lastEquipTime = os.clock()
        return true
    else
        log(string.format("❌ Equip fail: %s", tostring(result)))
        return false
    end
end

-- ══════════ CHỨC NĂNG 2: AUTO SELL ══════════
local function runAutoSell()
    if not remotes.askSale then
        log("❌ Không có AskSale")
        return 0
    end
    
    -- ⭐ v16.1: Skip nếu vừa equip xong (tránh bán pet vừa swap)
    if os.clock() - lastEquipTime < config.EQUIP_SYNC_WAIT then
        log(string.format("⏭ Bỏ sell — vừa equip xong, chờ %.1fs sync", config.EQUIP_SYNC_WAIT))
        return 0
    end
    
    -- 1. Scan backpack
    local backpackPets = scanBackpackPets()
    if #backpackPets == 0 then
        log("ℹ Không có pet trong backpack để bán")
        return 0
    end
    
    -- 2. Scan equipped để loại bỏ
    local equippedUids = scanEquippedUids()
    
    -- 3. Lọc pet có thể bán
    -- ⭐ v16.1: CHỈ bán pet CÓ trong incomeCache
    local toSell = {}
    local skipped = 0
    for _, pet in ipairs(backpackPets) do
        -- KHÔNG bán pet đang equip
        if not equippedUids[pet.uid] then
            local income = incomeCache[pet.uid]
            
            if income == nil then
                -- ⭐ Không có trong cache → SKIP (an toàn, không bán)
                skipped = skipped + 1
            else
                -- Có income trong cache → check ngưỡng
                if income < config.SELL_THRESHOLD then
                    table.insert(toSell, { pet = pet, income = income })
                end
            end
        end
    end
    
    if skipped > 0 then
        log(string.format("  ⏭ Bỏ qua %d pet — chưa có trong snapshot", skipped))
    end
    
    if #toSell == 0 then
        log(string.format("ℹ Không pet nào < %s (đã check %d pet)", 
            fmtMoney(config.SELL_THRESHOLD), #backpackPets - skipped))
        return 0
    end
    
    -- 4. Bán từng pet
    log(string.format("💸 AUTO SELL: %d pet (< %s)", #toSell, fmtMoney(config.SELL_THRESHOLD)))
    
    local soldCount = 0
    for i, item in ipairs(toSell) do
        local pet = item.pet
        local incomeStr = fmtMoney(item.income) .. "/s"
        
        local success = pcall(function() return remotes.askSale:InvokeServer(pet.uid) end)
        
        if success then
            soldCount = soldCount + 1
            log(string.format("  [%d/%d] ✅ %s (%s)", 
                i, #toSell, pet.name:sub(1, 30), incomeStr))
        else
            log(string.format("  [%d/%d] ❌ %s (%s)", 
                i, #toSell, pet.name:sub(1, 30), incomeStr))
        end
        
        task.wait(config.SELL_DELAY)
    end
    
    stats.totalSold = stats.totalSold + soldCount
    log(string.format("🏁 Đã bán %d/%d pet", soldCount, #toSell))
    return soldCount
end

-- ══════════ MAIN LOOP ══════════
local function mainLoop()
    log("═══════════════════════════")
    log("🚀 PET TOOL STARTED (v16.1)")
    log(string.format("   Auto Sell: %s (ngưỡng %s)", 
        config.AUTO_SELL_ENABLED and "ON" or "OFF",
        fmtMoney(config.SELL_THRESHOLD)))
    log(string.format("   Auto Equip: %s", 
        config.AUTO_EQUIP_ENABLED and "ON" or "OFF"))
    log(string.format("   Include zero: %s", 
        config.SELL_INCLUDE_ZERO and "ON" or "OFF"))
    log("═══════════════════════════")
    
    while isRunning do
        stats.cyclesRun = stats.cyclesRun + 1
        local cycleStart = os.clock()
        
        -- ⭐⭐⭐ ƯU TIÊN 1: AUTO EQUIP BEST (nếu bật)
        if config.AUTO_EQUIP_ENABLED then
            if os.clock() - lastEquipTime >= config.EQUIP_INTERVAL 
                or config.EQUIP_ON_START then
                runAutoEquip()
                config.EQUIP_ON_START = false
                task.wait(2)  -- Chờ server xử lý
            end
        end
        
        -- ⭐⭐⭐ ƯU TIÊN 2: AUTO SELL (nếu bật)
        if config.AUTO_SELL_ENABLED then
            -- Fetch snapshot để có income mới nhất
            fetchSnapshotIncome()
            task.wait(0.5)
            
            -- Bán pet
            runAutoSell()
        end
        
        -- Log cycle time
        local cycleTime = os.clock() - cycleStart
        stats.lastRunTime = cycleTime
        
        task.wait(config.LOOP_DELAY)
    end
    
    log("🛑 PET TOOL STOPPED")
end

-- ══════════ PUBLIC API ══════════

-- Start/Stop
function M.start()
    if isRunning then return end
    if not remotes.askSnapshot then
        log("❌ Không tìm thấy remote (AskLiveSnapshot) — không start được")
        return
    end
    isRunning = true
    config.EQUIP_ON_START = true
    lastEquipTime = 0
    task.spawn(mainLoop)
end

function M.stop()
    isRunning = false
end

function M.isRunning()
    return isRunning
end

-- Toggle Auto Sell
function M.setAutoSell(enabled)
    config.AUTO_SELL_ENABLED = enabled and true or false
    log(string.format("💰 Auto Sell: %s", enabled and "BẬT" or "TẮT"))
    return config.AUTO_SELL_ENABLED
end

function M.toggleAutoSell()
    return M.setAutoSell(not config.AUTO_SELL_ENABLED)
end

function M.isAutoSellEnabled()
    return config.AUTO_SELL_ENABLED
end

-- Toggle Auto Equip
function M.setAutoEquip(enabled)
    config.AUTO_EQUIP_ENABLED = enabled and true or false
    if enabled then
        config.EQUIP_ON_START = true
    end
    log(string.format("🎽 Auto Equip: %s", enabled and "BẬT" or "TẮT"))
    return config.AUTO_EQUIP_ENABLED
end

function M.toggleAutoEquip()
    return M.setAutoEquip(not config.AUTO_EQUIP_ENABLED)
end

function M.isAutoEquipEnabled()
    return config.AUTO_EQUIP_ENABLED
end

-- Set threshold
function M.setSellThreshold(value)
    config.SELL_THRESHOLD = tonumber(value) or 10000000
    log(string.format("💰 Ngưỡng bán: %s", fmtMoney(config.SELL_THRESHOLD)))
end

function M.getSellThreshold()
    return config.SELL_THRESHOLD
end

-- Include zero income
function M.setIncludeZero(enabled)
    config.SELL_INCLUDE_ZERO = enabled and true or false
    log(string.format("📦 Bán pet income=0: %s", enabled and "BẬT" or "TẮT"))
end

-- Set interval equip
function M.setEquipInterval(seconds)
    config.EQUIP_INTERVAL = tonumber(seconds) or 5
    log(string.format("⏱ Equip interval: %ds", config.EQUIP_INTERVAL))
end

-- Manual run
function M.runOnce()
    task.spawn(function()
        log("═══ RUN ONCE ═══")
        
        if config.AUTO_EQUIP_ENABLED then
            runAutoEquip()
            task.wait(2)
        end
        
        if config.AUTO_SELL_ENABLED then
            fetchSnapshotIncome()
            task.wait(0.5)
            runAutoSell()
        end
        
        log("═══ XONG ═══")
    end)
end

-- Scan only (không bán)
function M.scanInfo()
    task.spawn(function()
        local backpackPets = scanBackpackPets()
        local equippedUids = scanEquippedUids()
        
        local eqCount = 0
        for _ in pairs(equippedUids) do eqCount = eqCount + 1 end
        
        log(string.format("📊 Backpack: %d pet | Equip: %d pet", 
            #backpackPets, eqCount))
        
        -- Debug: hiện 5 pet đầu + income
        for i = 1, math.min(5, #backpackPets) do
            local pet = backpackPets[i]
            local income = incomeCache[pet.uid]
            local incomeStr = income and fmtMoney(income) .. "/s" or "?"
            local eqStr = equippedUids[pet.uid] and " [EQUIP]" or ""
            log(string.format("  [%d] %s — %s%s", 
                i, pet.name:sub(1, 30), incomeStr, eqStr))
        end
    end)
end

-- Get stats
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

-- Get logs
function M.getLogs()
    return logs
end

function M.clearLogs()
    logs = {}
end

-- Get config
function M.getConfig()
    return config
end

-- ══════════ UTILITY ══════════
function M.setLoopDelay(seconds)
    config.LOOP_DELAY = tonumber(seconds) or 1.0
end

function M.setSellDelay(seconds)
    config.SELL_DELAY = tonumber(seconds) or 0.3
end

function M.setEquipSyncWait(seconds)
    config.EQUIP_SYNC_WAIT = tonumber(seconds) or 1.0
    log(string.format("⏱ Equip sync wait: %.1fs", config.EQUIP_SYNC_WAIT))
end

function M.clearCache()
    incomeCache = {}
    log("🗑 Cleared income cache")
end

function M.getIncomeCache()
    return incomeCache
end

return M
