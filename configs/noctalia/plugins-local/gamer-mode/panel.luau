--!nonstrict
--
-- Gamer Mode panel. Like the widget it owns no state: it renders what the service
-- publishes and sends commands back through `noctalia.state`.
--
-- Interactive props (onClick/onChange) must be the *names* of global functions -- the
-- ui bridge resolves handlers by name and cannot call a Lua closure.
--
-- Local restyle (shaiyon): theme-colored cards like the session menu and control center,
-- a primary-tinted gamepad badge instead of the fire logo, segmented profile pickers.

local MIB_PER_GIB = 1024

local TILE_GAP = 10

local M = {}

local metrics = noctalia.state.get("metrics") or { available = false }
local gameMode = noctalia.state.get("game_mode") or { enabled = false, busy = false, suspended = {} }
local power = noctalia.state.get("power") or { available = false, profiles = {} }
local cleanup = noctalia.state.get("cleanup") or {}
local nonceCounter = 0

local function tr(key, subst)
    return noctalia.tr(key, subst)
end

local function clamp(value)
    local number = tonumber(value) or 0
    return math.max(0, math.min(1, number))
end

local function percent(fraction)
    return string.format("%d%%", math.floor(clamp(fraction) * 100 + 0.5))
end

local function gibibytes(mib)
    return (tonumber(mib) or 0) / MIB_PER_GIB
end

local function gib(mib)
    return string.format("%.1f GiB", gibibytes(mib))
end

local function ofTotal(mib)
    return string.format("of %.1f", gibibytes(mib))
end

local function temp(showTemps, value)
    if showTemps and tonumber(value) then
        return string.format("%d°C", math.floor(tonumber(value) + 0.5))
    end
    return nil
end

-- buildRows produces one entry per reading the machine actually reports. Unsupported
-- readings are absent rather than drawn as an empty bar, which would look like a real
-- idle reading.
-- The shell tints a sysmon value from its normal colour towards the highlight colour as
-- the metric climbs, holding flat below the activity threshold and saturating at the
-- critical one, with a jump to kActivityOnset the moment it crosses (sysmon_widget.cpp
-- gradientFactor). Duplicated from monitor.luau rather than shared: plugin entries run in
-- separate sandboxed Luau states with no `require`.
local ACTIVITY_ONSET = 0.25

function M.gradientFactor(value, activity, critical)
    if value == nil or activity == nil or critical == nil then
        return 0
    end
    local v = math.max(value, 0)
    local top = math.max(critical, 0)
    if top <= 0 or v <= 0 then
        return 0
    end
    local floor = math.max(0, math.min(activity, top))
    if v <= floor then
        return 0
    end
    if v >= top then
        return 1
    end
    return ACTIVITY_ONSET + (1 - ACTIVITY_ONSET) * (v - floor) / (top - floor)
end

-- Every row's `progress` is already the fraction the shell would gradient on, so the bar
-- and the reading cannot disagree.
function M.barFill(row)
    local tint = M.gradientFactor(row.progress, row.activity, row.critical)
    if tint <= 0 then
        return "primary"
    end
    return string.format("error/%.2f", 0.80 + 0.20 * tint)
end

function M.buildRows(m, showTemps)
    local rows = {}
    if type(m) ~= "table" or not m.available then
        return rows
    end

    rows[#rows + 1] = {
        label = "CPU",
        glyph = "cpu-usage",
        progress = clamp(m.cpuPerc),
            activity = 0.50,
            critical = 0.90,
        value = percent(m.cpuPerc),
        note = temp(showTemps, m.cpuTemp),
    }
    rows[#rows + 1] = {
        label = "RAM",
        glyph = "memory",
        progress = clamp(m.memPerc),
            activity = 0.60,
            critical = 0.90,
        value = gib(m.memUsedMb),
        note = ofTotal(m.memTotalMb),
    }

    -- Swap only when the machine has some. A zero total is not a bar at 0%, it is a
    -- machine with swap turned off, and drawing it would invite a reading that is not
    -- there.
    if m.swapTotalMb and m.swapTotalMb > 0 then
        rows[#rows + 1] = {
            label = "Swap",
            glyph = "storage",
            progress = clamp(m.swapPerc),
            activity = 0.20,
            critical = 0.80,
            value = gib(m.swapUsedMb),
            note = ofTotal(m.swapTotalMb),
        }
    end

    if m.gpuAvailable and m.gpuPerc then
        rows[#rows + 1] = {
            label = "GPU",
            glyph = "gpu-usage",
            progress = clamp(m.gpuPerc),
            activity = 0.50,
            critical = 0.95,
            value = percent(m.gpuPerc),
            note = temp(showTemps, m.gpuTemp),
        }
    end
    if m.vramUsedMb and m.vramTotalMb then
        rows[#rows + 1] = {
            label = "VRAM",
            glyph = "storage",
            progress = clamp(m.vramPerc),
            activity = 0.50,
            critical = 0.90,
            value = gib(m.vramUsedMb),
            note = ofTotal(m.vramTotalMb),
        }
    end
    return rows
end

local function perSecond(bytes)
    local value = tonumber(bytes) or 0
    if value >= 1024 * 1024 then
        return string.format("%.1f MB/s", value / (1024 * 1024))
    elseif value >= 1024 then
        return string.format("%.0f KB/s", value / 1024)
    end
    return string.format("%.0f B/s", value)
end

-- Readings that are not a proportion of anything. Load average needs a core count to
-- become a percentage and the shell does not report one; a network rate has no ceiling to
-- measure against. Both are shown as figures rather than invented into bars.
function M.buildFigures(m)
    local figures = {}
    if type(m) ~= "table" or not m.available then
        return figures
    end
    if m.load1 and m.load5 and m.load15 then
        figures[#figures + 1] = {
            label = tr("panel.load"),
            glyph = "performance",
            detail = string.format("%.2f  %.2f  %.2f", m.load1, m.load5, m.load15),
        }
    end
    if m.netRxPerSec and m.netTxPerSec then
        figures[#figures + 1] = {
            label = tr("panel.network"),
            glyph = "antenna-bars-5",
            detail = "↓ " .. perSecond(m.netRxPerSec) .. "  ↑ " .. perSecond(m.netTxPerSec),
        }
    end
    return figures
end

function M.suspendedLines(gm)
    local lines = {}
    for _, target in ipairs((type(gm) == "table" and gm.suspended) or {}) do
        -- Frozen and stopped are materially different to a user reading this list: one
        -- resumes exactly where it left off, the other was shut down and restarted.
        local state = target.action == "freeze" and tr("panel.frozen") or tr("panel.stopped")
        lines[#lines + 1] = string.format("%s (%s, %s)", tostring(target.match), tostring(target.kind), state)
    end
    return lines
end

-- M.powerProfileAt resolves the zero-based index the select reports back to a profile
-- name, or nil when the index no longer matches the published list.
function M.powerProfileAt(index)
    local position = (tonumber(index) or -1) + 1
    local profiles = (type(power) == "table" and power.profiles) or {}
    return profiles[position]
end

-- ── suspend profile ──

local SUSPEND_PROFILES = { "light", "heavy" }

function M.suspendProfiles()
    return { SUSPEND_PROFILES[1], SUSPEND_PROFILES[2] }
end

-- The chosen profile travels with the enable command rather than changing the setting,
-- because a plugin reads its own settings and cannot write them. It starts from whatever
-- the setting says and then lives as long as the loaded panel entry, which outlives any
-- one opening of the panel but not a shell restart or a plugin reload.
--
-- The bar's right-click toggle cannot see this: the widget is a separate entry with its
-- own state, so it enables the profile named in the settings. Selecting here and then
-- right-clicking the icon is the one path where the two disagree.
local selectedProfileName = nil

function M.selectedProfile()
    if selectedProfileName then
        return selectedProfileName
    end
    local configured = noctalia.getConfig("profile")
    return configured == "heavy" and "heavy" or "light"
end

function M.selectSuspendProfile(index)
    local name = SUSPEND_PROFILES[(tonumber(index) or -1) + 1]
    if not name then
        noctalia.log("gamermode: ignoring an out-of-range suspend profile selection")
        return false
    end
    selectedProfileName = name
    return true
end

local function selectedSuspendIndex()
    local current = M.selectedProfile()
    for index, name in ipairs(SUSPEND_PROFILES) do
        if name == current then
            return index - 1
        end
    end
    return 0
end

local function selectedPowerIndex()
    for index, profile in ipairs(power.profiles or {}) do
        if profile == power.active then
            return index - 1
        end
    end
    return 0
end

-- ── rendering ──

local function card(props, children)
    local base = { fill = "surface_container", radius = 12, padding = 12, gap = 10 }
    for key, value in pairs(props or {}) do
        base[key] = value
    end
    return ui.column(base, children)
end

local function caption(text)
    return ui.label({ text = text, color = "on_surface_variant", fontSize = 11, fontWeight = "semibold" })
end

-- One stat tile: icon + name, a large reading, a side note (temperature or total), a bar.
local function statTile(row)
    return card({ flexGrow = 1, flexBasis = 0, gap = 6 }, {
        ui.row({ align = "center", gap = 6 }, {
            ui.glyph({ name = row.glyph, size = 14, color = "primary" }),
            caption(row.label),
            ui.spacer({ flexGrow = 1 }),
            ui.label({ text = row.note or "", color = "on_surface_variant", fontSize = 11 }),
        }),
        ui.label({ text = row.value, color = "on_surface", fontSize = 20, fontWeight = "semibold" }),
        ui.progress({
            height = 6,
            progress = row.progress,
            fill = M.barFill(row),
            track = "surface_container_high",
            radius = 3,
        }),
    })
end

-- Small readings without a bar (swap, load, network) side by side in one card.
local function chip(glyph, label, value)
    return ui.column({ gap = 2, flexGrow = 1 }, {
        ui.row({ align = "center", gap = 6 }, {
            ui.glyph({ name = glyph, size = 12, color = "primary" }),
            caption(label),
        }),
        ui.label({ text = value, color = "on_surface", fontSize = 12, fontWeight = "medium" }),
    })
end

local function statsSection(children)
    local rows = M.buildRows(metrics, noctalia.getConfig("show_temps") ~= false)
    if #rows == 0 then
        children[#children + 1] = card({}, { caption(tr("panel.metrics_unavailable")) })
        return
    end

    local tiles, extras = {}, {}
    for _, row in ipairs(rows) do
        if row.label == "Swap" then
            extras[#extras + 1] = chip(row.glyph, row.label, row.value .. " " .. row.note)
        else
            tiles[#tiles + 1] = statTile(row)
        end
    end
    for index = 1, #tiles, 2 do
        children[#children + 1] = ui.row({ gap = TILE_GAP }, { tiles[index], tiles[index + 1] })
    end

    for _, figure in ipairs(M.buildFigures(metrics)) do
        extras[#extras + 1] = chip(figure.glyph, figure.label, figure.detail)
    end
    if #extras > 0 then
        children[#children + 1] = ui.row({
            fill = "surface_container",
            radius = 12,
            padding = 12,
            gap = 12,
        }, extras)
    end
    if not metrics.gpuAvailable then
        children[#children + 1] = caption(tr("panel.gpu_unsupported"))
    end
end

local function header()
    local on = gameMode.enabled == true
    local toggle
    if gameMode.busy then
        toggle = ui.button({ text = tr("panel.working"), enabled = false, variant = "outline" })
    else
        toggle = ui.button({
            text = on and tr("panel.disable") or tr("panel.enable"),
            glyph = on and "player-stop-filled" or "player-play-filled",
            variant = on and "outline" or "primary",
            onClick = "onToggleGameMode",
        })
    end

    return ui.row({ align = "center", gap = 12, fill = "surface_container", radius = 12, padding = 12 }, {
        -- Badge: solid primary while running, quiet outline while off.
        ui.row({
            width = 40,
            height = 40,
            radius = 20,
            align = "center",
            justify = "center",
            fill = on and "primary" or "surface_container_high",
            border = on and "primary" or "outline_variant",
            borderWidth = 1,
        }, {
            ui.glyph({ name = "device-gamepad-2", size = 20, color = on and "on_primary" or "primary" }),
        }),
        ui.column({ gap = 0, flexGrow = 1 }, {
            ui.label({ text = tr("panel.title"), fontSize = 15, fontWeight = "bold" }),
            ui.label({
                text = on and tr("panel.state_on") or tr("panel.state_off"),
                fontSize = 11,
                color = on and "primary" or "on_surface_variant",
            }),
        }),
        toggle,
        ui.button({ glyph = "settings", variant = "ghost", tooltip = tr("panel.settings"), onClick = "onOpenSettings" }),
        ui.button({ glyph = "close", variant = "ghost", tooltip = tr("panel.close"), onClick = "onCloseClicked" }),
    })
end

-- Segmented picker: one button per option, the active one filled.
local function segmented(options, activeIndex, handlers)
    local buttons = {}
    for index, text in ipairs(options) do
        buttons[index] = ui.button({
            text = text,
            controlSize = "sm",
            variant = index - 1 == activeIndex and "primary" or "outline",
            flexGrow = 1,
            onClick = handlers[index],
        })
    end
    return ui.row({ gap = 6 }, buttons)
end

-- Handlers must be global names, so each segment gets its own small global.
local POWER_HANDLERS = { "onPower1", "onPower2", "onPower3", "onPower4" }
local SUSPEND_HANDLERS = { "onSuspend1", "onSuspend2" }

local function profilesCard()
    local rows = {}
    rows[#rows + 1] = caption(tr("panel.power_profile"))
    if power.available then
        local labels = {}
        for index, name in ipairs(power.profiles or {}) do
            labels[index] = tr("panel.power." .. tostring(name))
        end
        rows[#rows + 1] = segmented(labels, selectedPowerIndex(), POWER_HANDLERS)
    else
        rows[#rows + 1] = ui.label({ text = tr("panel.power_unavailable"), color = "on_surface_variant", fontSize = 11 })
    end

    rows[#rows + 1] = caption(tr("panel.mode_profile"))
    if gameMode.enabled then
        -- While running, the profile in force is the one the session recorded.
        rows[#rows + 1] = ui.label({ text = tr("panel.profiles." .. tostring(gameMode.profile or "light")) })
    else
        local labels = {}
        for index, name in ipairs(M.suspendProfiles()) do
            labels[index] = tr("panel.profiles." .. name)
        end
        rows[#rows + 1] = segmented(labels, selectedSuspendIndex(), SUSPEND_HANDLERS)
    end
    return card({}, rows)
end

local function suspendedCard()
    local lines = M.suspendedLines(gameMode)
    local rows = { caption(tr("panel.suspended") .. (#lines > 0 and ("  " .. #lines) or "")) }
    if #lines == 0 then
        rows[#rows + 1] = ui.label({ text = tr("panel.nothing_suspended"), fontSize = 11, color = "on_surface_variant" })
    end
    for _, line in ipairs(lines) do
        rows[#rows + 1] = ui.label({ text = line, fontSize = 11 })
    end
    return card({}, rows)
end

-- Deleting the shader caches is the one action here that destroys something, so the button
-- asks first and names the size it is about to remove.
local shadersArmed = false

local function maintenanceCard()
    local working = cleanup.running ~= nil
    local rows = {
        caption(tr("cleanup.title")),
        ui.row({ gap = 6 }, {
            ui.button({
                -- The size arrives from the service, which measured it when the button armed.
                text = shadersArmed and tr("cleanup.shaders_confirm", { size = cleanup.shaderSize or "?" })
                    or tr("cleanup.shaders"),
                glyph = shadersArmed and "alert-triangle" or "trash",
                variant = shadersArmed and "destructive" or "outline",
                controlSize = "sm",
                enabled = not working,
                flexGrow = 1,
                onClick = "onClearShaders",
            }),
            ui.button({
                text = tr("cleanup.pagecache"),
                glyph = "memory",
                variant = "outline",
                controlSize = "sm",
                enabled = not working,
                flexGrow = 1,
                onClick = "onDropPageCache",
            }),
            ui.button({
                text = tr("cleanup.swap"),
                glyph = "refresh",
                variant = "outline",
                controlSize = "sm",
                enabled = not working,
                flexGrow = 1,
                onClick = "onReclaimSwap",
            }),
        }),
    }
    if type(cleanup.message) == "string" and cleanup.message ~= "" then
        rows[#rows + 1] = ui.label({
            text = cleanup.message,
            fontSize = 11,
            color = cleanup.ok == false and "error" or "on_surface_variant",
        })
    end
    return card({}, rows)
end

local function render()
    local children = {}
    statsSection(children)
    children[#children + 1] = profilesCard()
    if gameMode.enabled then
        children[#children + 1] = suspendedCard()
    end
    children[#children + 1] = maintenanceCard()

    panel.render(ui.column({ padding = 16, gap = 10, flexGrow = 1 }, {
        header(),
        ui.scroll({ flexGrow = 1 }, { ui.column({ gap = 10 }, children) }),
    }))
end

local function sendCommand(action, extra)
    nonceCounter = nonceCounter + 1
    local command = { nonce = noctalia.nowMs() * 1000 + nonceCounter, action = action }
    for key, value in pairs(extra or {}) do
        command[key] = value
    end
    noctalia.state.set("command", command)
end

-- ── shell entry points (must be globals) ──

function onOpen()
    metrics = noctalia.state.get("metrics") or metrics
    gameMode = noctalia.state.get("game_mode") or gameMode
    power = noctalia.state.get("power") or power
    render()
end

-- The command carries the chosen profile so one button both picks and applies. Disabling
-- ignores it: the session already records which profile was in force.
function onToggleGameMode()
    sendCommand("toggle", { profile = M.selectedProfile() })
end

local function choosePower(index)
    local profile = M.powerProfileAt(index)
    if not profile then
        noctalia.log("gamermode: ignoring an out-of-range power profile selection")
        return
    end
    sendCommand("set-power-profile", { profile = profile })
end

function onPower1() choosePower(0) end
function onPower2() choosePower(1) end
function onPower3() choosePower(2) end
function onPower4() choosePower(3) end

local function chooseSuspend(index)
    if M.selectSuspendProfile(index) then
        render()
    end
end

function onSuspend1() chooseSuspend(0) end
function onSuspend2() chooseSuspend(1) end

function onOpenSettings()
    noctalia.openSettings()
end

-- The first click measures and arms; the second deletes. Anything else the user does in
-- the panel is a chance to have changed their mind, so the arming does not persist past a
-- different cleanup being started.
function onClearShaders()
    if shadersArmed then
        shadersArmed = false
        sendCommand("cleanup", { job = "shaders" })
    else
        shadersArmed = true
        sendCommand("cleanup", { job = "shaders-measure" })
    end
    render()
end

function onDropPageCache()
    shadersArmed = false
    sendCommand("cleanup", { job = "pagecache" })
    render()
end

function onReclaimSwap()
    shadersArmed = false
    sendCommand("cleanup", { job = "swap" })
    render()
end

function onCloseClicked()
    panel.close()
end

noctalia.state.watch("metrics", function(value)
    metrics = type(value) == "table" and value or { available = false }
    render()
end)

noctalia.state.watch("game_mode", function(value)
    gameMode = type(value) == "table" and value or { enabled = false, busy = false, suspended = {} }
    render()
end)

noctalia.state.watch("power", function(value)
    power = type(value) == "table" and value or { available = false, profiles = {} }
    render()
end)

noctalia.state.watch("cleanup", function(value)
    cleanup = type(value) == "table" and value or {}
    render()
end)

return M
