-- ═══════════════════════════════════════════════════════════════
-- LOADER — Tải modules từ GitHub
-- Repo: https://github.com/ojiasa/Steal-an-egg
-- ═══════════════════════════════════════════════════════════════

local BASE_URL = "https://raw.githubusercontent.com/ojiasa/Steal-an-egg/main"

-- ⭐ Fallback nếu raw.githubusercontent bị chặn
local FALLBACK_URL = "https://cdn.jsdelivr.net/gh/ojiasa/Steal-an-egg@main"

local function fetch(path)
    -- Thử raw github trước
    local urls = {
        BASE_URL .. "/" .. path,
        FALLBACK_URL .. "/" .. path,   -- Fallback qua jsdelivr
    }

    for _, url in ipairs(urls) do
        local ok, src = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and src and #src > 100 then
            local fn, err = loadstring(src, "=" .. path)
            if fn then
                local success, result = pcall(fn)
                if success then
                    print("[Loader] ✅ Loaded: " .. path)
                    return result
                else
                    warn("[Loader] Runtime error " .. path .. ": " .. tostring(result))
                end
            else
                warn("[Loader] Syntax error " .. path .. ": " .. tostring(err))
            end
        end
    end

    warn("[Loader] ❌ Failed: " .. path)
    return nil
end

print("[Loader] 📦 Đang tải modules...")

-- ⭐ Load modules
local StealModule = fetch("modules/steal.lua")
local ESPModule   = fetch("modules/esp.lua")

-- ⭐ EXPOSE API
_G.StealEgg = {
    -- Module refs
    Steal = StealModule,
    ESP   = ESPModule,

    -- ⭐ Steal API
    Start = function()
        if StealModule then StealModule.start() end
    end,
    Stop = function()
        if StealModule then StealModule.stop() end
    end,
    IsRunning = function()
        return StealModule and StealModule.isRunning() or false
    end,
    SetTarget = function(name, pos)
        if StealModule then StealModule.setTarget(name, pos) end
    end,
    SetHome = function(pos)
        if StealModule then StealModule.setHome(pos) end
    end,
    SetForest = function(pos)
        if StealModule then StealModule.setForest(pos) end
    end,
    OnLog = function(callback)
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
        if ESPModule then return ESPModule.toggle() end
    end,
    ESP_IsEnabled = function()
        return ESPModule and ESPModule.isEnabled() or false
    end,
    ESP_SetFilter = function(minIncome, showLobby)
        if ESPModule then ESPModule.setFilter(minIncome, showLobby) end
    end,

    -- ⭐ Info
    Version = "1.0.0",
    Repo    = "https://github.com/ojiasa/Steal-an-egg",
}

-- Alias để tương thích code cũ
_G.MyScript = _G.StealEgg

print("[Loader] ✅ Ready!")
print("[Loader] Sử dụng: _G.StealEgg.Start() / .ESP_Toggle()")
