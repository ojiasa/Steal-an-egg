-- ═══════════════════════════════════════════════════════════════
-- LOADER — Tải modules + expose API cho UI
-- ═══════════════════════════════════════════════════════════════

local BASE_URL = "https://raw.githubusercontent.com/USERNAME/REPO/main"

local function fetch(path)
    local url = BASE_URL .. "/" .. path
    local ok, src = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or not src then
        warn("[Loader] Không tải được: " .. path)
        return nil
    end
    local fn, err = loadstring(src, "=" .. path)
    if not fn then
        warn("[Loader] Syntax error " .. path .. ": " .. tostring(err))
        return nil
    end
    return fn()
end

-- ⭐ Load modules
local StealModule = fetch("modules/steal.lua")
local ESPModule   = fetch("modules/esp.lua")

if not StealModule then warn("❌ Không load steal module") end
if not ESPModule   then warn("❌ Không load ESP module") end

-- ⭐ EXPOSE API cho UI
_G.MyScript = {
    -- Module refs
    Steal = StealModule,
    ESP   = ESPModule,

    -- ⭐ Steal API
    Steal_Start = function()
        if StealModule then StealModule.start() end
    end,
    Steal_Stop = function()
        if StealModule then StealModule.stop() end
    end,
    Steal_IsRunning = function()
        return StealModule and StealModule.isRunning() or false
    end,
    Steal_SetTarget = function(name, pos)
        if StealModule then StealModule.setTarget(name, pos) end
    end,
    Steal_SetHome = function(pos)
        if StealModule then StealModule.setHome(pos) end
    end,
    Steal_SetForest = function(pos)
        if StealModule then StealModule.setForest(pos) end
    end,
    Steal_OnLog = function(callback)
        if StealModule then StealModule.onLog(callback) end
    end,

    -- ⭐ ESP API
    ESP_Enable = function()
        if ESPModule then ESPModule.enable() end
    end,
    ESP_Disable = function()
        if ESPModule then ESPModule.disable() end
    end,
    ESP_Toggle = function()
        if ESPModule then ESPModule.toggle() end
    end,
    ESP_IsEnabled = function()
        return ESPModule and ESPModule.isEnabled() or false
    end,
    ESP_SetFilter = function(minIncome, showLobby)
        if ESPModule then ESPModule.setFilter(minIncome, showLobby) end
    end,

    -- ⭐ Thông tin
    Version = "1.0.0",
    Authors = "you",
}

print("[Loader] ✅ Ready — _G.MyScript sẵn sàng")
print("[Loader] Ví dụ dùng:")
print("  _G.MyScript.Steal_Start()")
print("  _G.MyScript.Steal_Stop()")
print("  _G.MyScript.ESP_Toggle()")
