-- ═══════════════════════════════════════════════════════════════
-- PET TOOL MODULE v16.3 — Fix không bán được
-- ⭐ v16.3: Listen RE/PenRoster/CoinsGathered để tính income/s
--          income = (newAmount - oldAmount) / (newTime - oldTime)
-- ═══════════════════════════════════════════════════════════════

local P = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")

local M = {}

-- ══════════ CONFIG ══════════
local config = {
    AUTO_SELL_ENABLED   = false,
    AUTO_EQUIP_ENABLED  = false,

    SELL_THRESHOLD      = 10000000,
    SELL_INCLUDE_ZERO   = false,
    SELL_MIN_INCOME_FLOOR = 100,      -- ⭐ v16.3: income tối thiểu để coi là valid

    EQUIP_INTERVAL      = 5,
    EQUIP_ON_START      = true,

    LOOP_DELAY          = 1.0,
    SELL_DELAY          = 0.3,
    EQUIP_SYNC_WAIT     = 1.0,

    COINS_LISTENER_ENABLED = true,    -- ⭐ v16.3: bật/tắt listener
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
    askSale       = NET and NET:FindFirstChild("RF/PenRoster/AskSale"),
    askSnapshot   = NET and NET:FindFirstChild("RF/PenRoster/AskLiveSnapshot"),
    wearBest      = NET and NET:FindFirstChild("RF/Haul/WearBest"),
    fetchStatus   = NET and NET:FindFirstChild("RF/Haul/FetchWearBestStatus"),
    coinsGathered = NET and NET:FindFirstChild("RE/PenRoster/CoinsGathered"),  -- ⭐ v16.3
}

-- ══════════ LOG ══════════
local function log(txt, color)
    table.insert(logs, { text = tostring(txt), time = os.clock(), color = color })
    if #logs > 200 then table.remove(logs, 1) end
    for _, cb in ipairs(logCallbacks) do pcall(cb, txt) end
    print("[PetTool] " .. tostring(txt))
end

function M.onLog(cb)
    if type(cb) == "function" then table.insert(logCallbacks, cb) end
end

-- ══════════ FORMAT ══════════
local function fmtMoney(n)
    if type(n) ~= "number" then return "?" end
    if n >= 1e12 then return string.format("$%.2fT", n/1e12) end
    if n >= 1e9 then return string.format("$%.2fB", n/1e9) end
    if n >= 1e6 then return string.format("$%.2fM", n/1e6) end
    if n >= 1e3 then return string.format("$%.0fK", n/1e3) end
    return string.format("$%.0f", n)
end

-- ══════════ INCOME CACHE ══════════
local incomeCache = {}       -- [uid] = income/s
local lastCoinData = {}      -- [uid] = { amount, time }
local coinsEventsReceived = 0
local coinsUidsTracked = 0
local coinsListenerConn = nil

-- ══════════ SETUP COINS LISTENER ⭐ v16.3 ══════════
local function setupCoinsListener()
    if not config.COINS_LISTENER_ENABLED then
        log("⚠ CoinsListener tắt theo config")
        return false
    end
    if coinsListenerConn then return true end
    if not remotes.coinsGathered then
        log("❌ Không có RE/PenRoster/CoinsGathered")
        return false
    end

    coinsListenerConn = remotes.coinsGathered.OnClientEvent:Connect(function(data, _flag)
        if type(data) ~= "table" then return end
        coinsEventsReceived = coinsEventsReceived + 1

        local now = os.clock()

        for _, entry in ipairs(data) do
            if type(entry) == "table" and entry.uid then
                local uid = tostring(entry.uid)
                local amount = tonumber(entry.amount) or 0
                local prev = lastCoinData[uid]

                if prev then
                    local dt = now - prev.time
                    local delta = amount - prev.amount

                    -- Chỉ tính income khi:
                    -- - dt đủ lớn (> 0.3s) để tránh noise
                    -- - delta >= 0 (amount luôn tăng)
                    if dt > 0.3 and delta >= 0 then
                        local income = delta / dt
                        if income > 0 then
                            incomeCache[uid] = income
                        end
                    end
                end

                lastCoinData[uid] = { amount = amount, time = now }
            end
        end

        -- Đếm số uid đã track (chỉ log 1 lần)
        if coinsEventsReceived == 1 then
            local n = 0
            for _ in pairs(lastCoinData) do n = n + 1 end
            coinsUidsTracked = n
            log(string.format("🔌 CoinsGathered connected — %d uid", n))
        end
    end)

    log("🔌 CoinsGathered listener đã kết nối")
    return true
end

local function stopCoinsListener()
    if coinsListenerConn then
        coinsListenerConn:Disconnect()
        coinsListenerConn = nil
        log("🛑 CoinsGathered listener dừng")
    end
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
                equippedUids[tostring(uidAttr)] = true
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

                if not ln:find("egg", 1, true) and not lc:find("egg", 1, true)
                    and not ln:find("trap", 1, true) and not ln:find("bat", 1, true)
                    and not ln:find("gậy", 1, true) and not ln:find("consumable", 1, true)
                    and not ln:find("mutation", 1, true) and not ln:find("rod", 1, true) then

                    table.insert(pets, {
                        name = tool.Name,
                        uid = tostring(uid),    -- ⭐ v16.3: normalize thành string
                        cat = cat,
                        instance = tool,
                    })
                end
            end
        end
    end
    return pets
end

-- ══════════ FETCH SNAPSHOT (fallback) ══════════
local function fetchSnapshotIncome()
    if not remotes.askSnapshot then return false end

    local ok, result = pcall(function() return remotes.askSnapshot:InvokeServer() end)
    if not ok or type(result) ~= "table" then
        log("❌ Snapshot fail")
        return false
    end

    local myUserId = P.UserId
    local count = 0

    for _, ownerData in pairs(result) do
        if type(ownerData) == "table" and ownerData.OwnerUserId == myUserId
            and type(ownerData.Records) == "table" then
            for uid, rec in pairs(ownerData.Records) do
                if type(rec) == "table" then
                    local income = rec.MoneyPerSecond or 0
                    -- Chỉ update nếu chưa có từ CoinsGathered (CoinsGathered mới hơn)
                    if incomeCache[tostring(uid)] == nil then
                        incomeCache[tostring(uid)] = income
                    end
                    count = count + 1
                end
            end
            break
        end
    end
    log(string.format("📸 Snapshot: %d record", count))
    return true
end

-- ══════════ AUTO EQUIP ══════════
local lastEquipTime = 0

local function runAutoEquip()
    if not remotes.wearBest then return false end
    log("🎽 AUTO EQUIP BEST...")

    local ok, result = pcall(function() return remotes.wearBest:InvokeServer() end)
    if ok and result == true then
        log("✅ Equip thành công")
        stats.totalEquipped = stats.totalEquipped + 1
        lastEquipTime = os.clock()
        return true
    else
        log(string.format("❌ Equip fail: %s", tostring(result)))
        return false
    end
end

-- ══════════ AUTO SELL ══════════
local function runAutoSell()
    if not remotes.askSale then
        log("❌ Không có AskSale")
        return 0
    end

    if os.clock() - lastEquipTime < config.EQUIP_SYNC_WAIT then
        log(string.format("⏭ Skip sell — vừa equip %.1fs trước", 
            os.clock() - lastEquipTime))
        return 0
    end

    local backpackPets = scanBackpackPets()
    if #backpackPets == 0 then
        log("ℹ Không có pet trong backpack")
        return 0
    end

    local equippedUids = scanEquippedUids()

    local toSell = {}
    local skipped, keepCount = 0, 0

    for _, pet in ipairs(backpackPets) do
        if not equippedUids[pet.uid] then
            local income = incomeCache[pet.uid]

            if income == nil then
                -- Chưa có income → skip (an toàn)
                skipped = skipped + 1
            elseif income < config.SELL_THRESHOLD then
                table.insert(toSell, { pet = pet, income = income })
            else
                keepCount = keepCount + 1
            end
        end
    end

    if skipped > 0 then
        log(string.format("  ⏭ Skip %d pet — chưa có income trong cache", skipped))
        log("  💡 Cache size: " .. (function()
            local n = 0; for _ in pairs(incomeCache) do n = n + 1 end; return n
        end)())
        log("  💡 CoinsEvents: " .. coinsEventsReceived)
    end

    if #toSell == 0 then
        log(string.format("ℹ Không pet nào < %s (bán: 0, giữ: %d, skip: %d)",
            fmtMoney(config.SELL_THRESHOLD), keepCount, skipped))
        return 0
    end

    log(string.format("💸 AUTO SELL: %d pet (< %s)", #toSell, fmtMoney(config.SELL_THRESHOLD)))

    local soldCount = 0
    for i, item in ipairs(toSell) do
        local pet = item.pet
        local success = pcall(function() return remotes.askSale:InvokeServer(pet.uid) end)

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

-- ══════════ MAIN LOOP ══════════
local function mainLoop()
    log("═══════════════════════════")
    log("🚀 PET TOOL v16.3 STARTED")
    log(string.format("   Auto Sell: %s | Auto Equip: %s",
        config.AUTO_SELL_ENABLED and "ON" or "OFF",
        config.AUTO_EQUIP_ENABLED and "ON" or "OFF"))
    log(string.format("   Threshold: %s | Include zero: %s",
        fmtMoney(config.SELL_THRESHOLD),
        config.COINS_LISTENER_ENABLED and "listener" or "off"))
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
            -- Snapshot làm fallback (chỉ update uid chưa có)
            fetchSnapshotIncome()
            task.wait(0.5)
            runAutoSell()
        end

        stats.lastRunTime = os.clock() - cycleStart
        task.wait(config.LOOP_DELAY)
    end

    log("🛑 STOPPED")
end

-- ══════════ PUBLIC API ══════════
function M.start()
    if isRunning then return end
    isRunning = true
    config.EQUIP_ON_START = true
    lastEquipTime = 0

    if config.COINS_LISTENER_ENABLED then
        setupCoinsListener()
    end

    task.spawn(mainLoop)
end

function M.stop()
    isRunning = false
    stopCoinsListener()
end

function M.isRunning() return isRunning end

-- ⭐ v16.3: Manual connect/disconnect listener
function M.connectCoinsListener()
    return setupCoinsListener()
end

function M.disconnectCoinsListener()
    stopCoinsListener()
end

-- ⭐ v16.3: Debug info
function M.getCoinsDebugInfo()
    local cacheCount = 0
    for _ in pairs(incomeCache) do cacheCount = cacheCount + 1 end
    local trackCount = 0
    for _ in pairs(lastCoinData) do trackCount = trackCount + 1 end
    return {
        eventsReceived = coinsEventsReceived,
        uidsTracked = trackCount,
        incomeCacheSize = cacheCount,
        hasListener = coinsListenerConn ~= nil,
    }
end

-- Toggle Auto Sell
function M.setAutoSell(enabled)
    config.AUTO_SELL_ENABLED = enabled and true or false
    log(string.format("💰 Auto Sell: %s", enabled and "BẬT" or "TẮT"))
    return config.AUTO_SELL_ENABLED
end

function M.toggleAutoSell() return M.setAutoSell(not config.AUTO_SELL_ENABLED) end
function M.isAutoSellEnabled() return config.AUTO_SELL_ENABLED end

-- Toggle Auto Equip
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

function M.setIncludeZero(enabled)
    config.SELL_INCLUDE_ZERO = enabled and true or false
    log(string.format("📦 Include zero: %s", enabled and "BẬT" or "TẮT"))
end

function M.setEquipInterval(seconds)
    config.EQUIP_INTERVAL = tonumber(seconds) or 5
end

function M.setEquipSyncWait(seconds)
    config.EQUIP_SYNC_WAIT = tonumber(seconds) or 1.0
end

function M.setCoinsListenerEnabled(enabled)
    config.COINS_LISTENER_ENABLED = enabled and true or false
    if not enabled then stopCoinsListener() end
    log(string.format("🔌 Coins listener: %s", enabled and "BẬT" or "TẮT"))
end

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

function M.scanInfo()
    task.spawn(function()
        local bp = scanBackpackPets()
        local eq = scanEquippedUids()
        local eqN = 0
        for _ in pairs(eq) do eqN = eqN + 1 end

        local cacheN = 0
        for _ in pairs(incomeCache) do cacheN = cacheN + 1 end

        log("═══════ SCAN INFO ═══════")
        log(string.format("📊 Backpack: %d pet | Equip: %d", #bp, eqN))
        log(string.format("📊 Income cache: %d | Coins events: %d",
            cacheN, coinsEventsReceived))

        -- Match rate
        local matched = 0
        for _, pet in ipairs(bp) do
            if incomeCache[pet.uid] ~= nil then matched = matched + 1 end
        end
        log(string.format("📊 Match rate: %d/%d pet có income",
            matched, #bp))

        for i = 1, math.min(5, #bp) do
            local pet = bp[i]
            local inc = incomeCache[pet.uid]
            log(string.format("  [%d] %s — %s%s",
                i, pet.name:sub(1, 25),
                inc and fmtMoney(inc) .. "/s" or "(no income)",
                eq[pet.uid] and " [EQUIP]" or ""))
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
        coinsEvents = coinsEventsReceived,
    }
end

function M.getLogs() return logs end
function M.clearLogs() logs = {} end
function M.getConfig() return config end

function M.clearCache()
    incomeCache = {}
    lastCoinData = {}
    coinsEventsReceived = 0
    log("🗑 Cleared cache")
end

function M.getIncomeCache() return incomeCache end

function M.setLoopDelay(s) config.LOOP_DELAY = tonumber(s) or 1.0 end
function M.setSellDelay(s) config.SELL_DELAY = tonumber(s) or 0.3 end

return M
