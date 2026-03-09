local mq                = require('mq')
local ImGui             = require('ImGui')
local zep               = require('Zep')

local MAX_HISTORY_COUNT = 100

local loadedExeternally = MyUI ~= nil
local Module            = {}
if not loadedExeternally then
    Module.Utils       = require('lib.common')
    Module.ThemeLoader = require('lib.theme_loader')
    Module.Actor       = require('actors')
    Module.CharLoaded  = mq.TLO.Me.DisplayName()
    Module.Icons       = require('mq.ICONS')
    Module.Guild       = mq.TLO.Me.Guild()
    Module.Server      = mq.TLO.MacroQuest.Server()
    Module.ThemesFile  = MyUI.ThemeFile == nil and string.format('%s/MyUI/ThemeZ.lua', mq.configDir) or MyUI.ThemeFile
    Module.Theme       = {}
    Module.Mode        = 'driver'
    Module.PackageMan  = require('mq.PackageMan')
    Module.SQLite3     = Module.PackageMan.Require('lsqlite3')
else
    Module.Utils = MyUI.Utils
    Module.ThemeLoader = MyUI.ThemeLoader
    Module.Actor = MyUI.Actor
    Module.CharLoaded = MyUI.CharLoaded
    Module.Icons = MyUI.Icons
    Module.Guild = MyUI.Guild
    Module.Server = MyUI.Server
    Module.Mode = MyUI.Mode
    Module.ThemesFile = MyUI.ThemeFile
    Module.Theme = MyUI.Theme
    Module.SQLite3 = MyUI.SQLite3
end
Module.Name              = "MyChat"
Module.IsRunning         = false
Module.defaults          = Module.Utils.Library.Include('defaults.default_chat_settings')
Module.tempSettings      = {}
Module.eventNames        = {}
Module.tempFilterStrings = {}
Module.tempFilterEnabled = {}
Module.tempFilterHidden  = {}
Module.tempEventStrings  = {}
Module.tempChanColors    = {}
Module.tempFiltColors    = {}
Module.hString           = {}
Module.TLOConsoles       = {}
Module.Logtouch          = string.format('%s/MyUI/MyChat/%s/Logs/touch.lua', mq.configDir, Module.Server:gsub(' ', '_'))
Module.LogFile           = string.format('%s/MyUI/MyChat/%s/Logs/%s.log', mq.configDir, Module.Server:gsub(' ', '_'), Module.CharLoaded)
Module.SHOW              = true
Module.openGUI           = true
Module.openConfigGUI     = false
Module.SettingsFile      = string.format('%s/MyUI/MyChat/%s/%s.lua', mq.configDir, Module.Server:gsub(' ', '_'), Module.CharLoaded)
Module.DBPath            = string.format('%s/MyUI/MyChat/MyChat.db', mq.configDir)
Module.ActivePresetID    = nil
Module.ActivePresetName  = ''
Module.PresetList        = {}

Module.KeyFocus          = false
Module.KeyName           = 'RightShift'
Module.Settings          = {
    -- Channels
    Channels = {},
}
Module.console           = nil
Module.commandBuffer     = ''
--Command History
Module.commandHistory    = {}
Module.commandIndex      = nil
Module.timeStamps        = true
-- Consoles
Module.Consoles          = {}
-- Flags
Module.tabFlags          = bit32.bor(ImGuiTabBarFlags.Reorderable, ImGuiTabBarFlags.FittingPolicyShrink, ImGuiTabBarFlags.TabListPopupButton)
Module.winFlags          = bit32.bor(ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoScrollbar)
Module.PopOutFlags       = bit32.bor(ImGuiWindowFlags.NoScrollbar)


-- local var's

local setFocus                                  = false
local addChannel                                = false -- Are we adding a new channel or editing an old one
local sortedChannels                            = {}
local timeStamps, newEvent, newFilter           = true, false, false
local zBuffer                                   = 1000   -- the buffer size for the Zoom chat buffer.
local editChanID, editEventID, lastID, lastChan = 0, 0, 0, 0
local activeTabID                               = 0      -- info about active tab channels
local lastImport                                = 'none' -- file name of the last imported file, if we try and import the same file again we will abort.
local windowNum                                 = 0      --unused will remove later.
local fromConf                                  = false  -- Did we open the edit channel window from the main config window? if we did we will go back to that window after closing.
local gIcon                                     = Module.Icons.MD_SETTINGS
local firstPass, forceIndex                     = true, false
local mainBuffer                                = {}
local importFile                                = 'Server_Name/CharName.lua'
local settingsOld                               = string.format('%s/MyChat_%s_%s.lua', mq.configDir, Module.Server:gsub(' ', '_'), Module.CharLoaded)
local cleanImport                               = false
local enableSpam, resetConsoles                 = false, false
local eChan                                     = '/say'
local logFileHandle                             = nil
-- Spam reverse-filter: track lines already claimed by real channel events
local claimedLines                              = {}
local claimedLinesTTL                           = {}
local CLAIMED_TTL                               = 0.5
local showPresetSaveInput                       = false
local newPresetName                             = ''
local showPresetRenameInput                     = false
local renamePresetName                          = ''
-- Deferred delete tracking (processed after draw loop)
local pendingDeleteEvent                        = nil -- {chanID, eventID}
local pendingDeleteFilter                       = nil -- {chanID, eventID, filterID}
local pendingDeleteChannel                      = nil -- chanID

local keyboardKeys                              = {
    [1]  = 'GraveAccent',
    [2]  = 'Enter',
    [3]  = 'RightShift',
    [4]  = 'Tab',
    [5]  = 'LeftArrow',
    [6]  = 'RightArrow',
    [7]  = 'UpArrow',
    [8]  = 'DownArrow',
    [9]  = 'Backspace',
    [10] = 'Delete',
    [11] = 'Insert',
    [12] = 'Home',
    [13] = 'End',
    [14] = 'PageUp',
    [15] = 'PageDown',
    [18] = 'F1',
    [19] = 'F2',
    [20] = 'F3',
    [21] = 'F4',
    [22] = 'F5',
    [23] = 'F6',
    [24] = 'F7',
    [25] = 'F8',
    [26] = 'F9',
    [27] = 'F10',
    [28] = 'F11',
    [29] = 'F12',
    [56] = 'RightCtrl',
    [57] = 'LeftCtrl',
    [58] = 'RightAlt',
    [59] = 'LeftAlt',
    [61] = 'LeftShift',
    [64] = 'RightSuper',
    [65] = 'LeftSuper',
    [73] = 'MouseMiddle',
    [75] = 'Backslash',
    [76] = 'Slash',
    [77] = 'Menu',
}


local MyColorFlags = bit32.bor(
    ImGuiColorEditFlags.NoOptions,
    ImGuiColorEditFlags.NoInputs,
    ImGuiColorEditFlags.NoTooltip,
    ImGuiColorEditFlags.NoLabel
)

-- Forward declarations for local functions referenced by Module methods
local SetUpConsoles
local BuildEvents


---Converts ConColor String to ColorVec Table
---@param colorString string @string value for color
---@return table @Table of R,G,B,A Color Values
local function GetColorVal(colorString)
    colorString = string.lower(colorString)
    if (colorString == 'red') then return { 0.9, 0.1, 0.1, 1, } end
    if (colorString == 'yellow') then return { 1, 1, 0, 1, } end
    if (colorString == 'yellow2') then return { 0.7, 0.6, 0.1, 0.7, } end
    if (colorString == 'white') then return { 1, 1, 1, 1, } end
    if (colorString == 'blue') then return { 0, 0.5, 0.9, 1, } end
    if (colorString == 'light blue') then return { 0, 1, 1, 1, } end
    if (colorString == 'green') then return { 0, 1, 0, 1, } end
    if (colorString == 'grey') then return { 0.6, 0.6, 0.6, 1, } end
    -- return White as default if bad string
    return { 1, 1, 1, 1, }
end


---Checks for the last ID number in the table passed. returns the NextID
---@param table table -- the table we want to look up ID's in
---@return number -- returns the NextID that doesn't exist in the table yet.
local function getNextID(table)
    local maxChannelId = 0
    for channelId, _ in pairs(table) do
        local numericId = tonumber(channelId)
        if numericId < 9000 then
            if numericId and numericId > maxChannelId then
                maxChannelId = numericId
            end
        end
    end
    return maxChannelId + 1
end

local function openLogFile()
    if not logFileHandle then
        logFileHandle = io.open(Module.LogFile, "a")
    end
end

local function writeLogToFile(line)
    openLogFile()
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    if logFileHandle then
        logFileHandle:write(string.format("[%s] %s\n", timestamp, line))
        logFileHandle:flush() -- Ensure the output is immediately written to the file
    end
end

---Opens the SQLite database, sets PRAGMAs, returns db handle or nil
---@return userdata|nil db handle
function Module.OpenDB()
    local db = Module.SQLite3.open(Module.DBPath)
    if not db then
        Module.Utils.PrintOutput('MyUI', nil, 'Failed to open the MyChat Database')
        return nil
    end
    db:busy_timeout(2000)
    db:exec('PRAGMA journal_mode=WAL;')
    db:exec('PRAGMA foreign_keys = ON;')
    return db
end

---Creates the database schema if it doesn't exist
function Module.InitDB()
    local db = Module.OpenDB()
    if not db then return end

    db:exec([[
        CREATE TABLE IF NOT EXISTS global_settings (
            char_name TEXT NOT NULL,
            server    TEXT NOT NULL DEFAULT '',
            key       TEXT NOT NULL,
            value     TEXT NOT NULL,
            PRIMARY KEY (char_name, server, key)
        );

        CREATE TABLE IF NOT EXISTS presets (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            preset_name TEXT NOT NULL,
            server      TEXT NOT NULL DEFAULT '',
            description TEXT DEFAULT '',
            created_by  TEXT NOT NULL,
            created_at  TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
            UNIQUE(preset_name, server)
        );

        CREATE TABLE IF NOT EXISTS channels (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            preset_id      INTEGER NOT NULL,
            channel_id     INTEGER NOT NULL,
            name           TEXT NOT NULL DEFAULT 'New',
            enabled        INTEGER NOT NULL DEFAULT 0,
            echo           TEXT NOT NULL DEFAULT '/say',
            main_enable    INTEGER NOT NULL DEFAULT 1,
            enable_links   INTEGER NOT NULL DEFAULT 0,
            pop_out        INTEGER NOT NULL DEFAULT 0,
            locked         INTEGER NOT NULL DEFAULT 0,
            scale          REAL NOT NULL DEFAULT 1.0,
            main_font_size INTEGER NOT NULL DEFAULT 16,
            tab_order      INTEGER NOT NULL DEFAULT 0,
            UNIQUE(preset_id, channel_id),
            FOREIGN KEY (preset_id) REFERENCES presets(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS events (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            channel_row_id INTEGER NOT NULL,
            event_index    INTEGER NOT NULL,
            event_string   TEXT NOT NULL DEFAULT 'new',
            enabled        INTEGER NOT NULL DEFAULT 1,
            UNIQUE(channel_row_id, event_index),
            FOREIGN KEY (channel_row_id) REFERENCES channels(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS filters (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            event_row_id   INTEGER NOT NULL,
            filter_index   INTEGER NOT NULL,
            filter_string  TEXT NOT NULL DEFAULT '',
            color_r        REAL NOT NULL DEFAULT 1.0,
            color_g        REAL NOT NULL DEFAULT 1.0,
            color_b        REAL NOT NULL DEFAULT 1.0,
            color_a        REAL NOT NULL DEFAULT 1.0,
            enabled        INTEGER NOT NULL DEFAULT 1,
            hidden         INTEGER NOT NULL DEFAULT 0,
            UNIQUE(event_row_id, filter_index),
            FOREIGN KEY (event_row_id) REFERENCES events(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS char_active_preset (
            char_name TEXT NOT NULL,
            server    TEXT NOT NULL DEFAULT '',
            preset_id INTEGER NOT NULL,
            PRIMARY KEY (char_name, server),
            FOREIGN KEY (preset_id) REFERENCES presets(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS char_channel_overrides (
            char_name  TEXT NOT NULL,
            server     TEXT NOT NULL DEFAULT '',
            channel_id INTEGER NOT NULL,
            preset_id  INTEGER NOT NULL,
            PRIMARY KEY (char_name, server, channel_id),
            FOREIGN KEY (preset_id) REFERENCES presets(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_channels_preset ON channels(preset_id);
        CREATE INDEX IF NOT EXISTS idx_events_channel ON events(channel_row_id);
        CREATE INDEX IF NOT EXISTS idx_filters_event ON filters(event_row_id);
    ]])

    db:exec('PRAGMA wal_checkpoint;')
    db:close()
end

--- Global settings keys and their types/defaults for DB storage
local globalSettingsKeys = {
    locked       = { type = 'bool',   default = false },
    timeStamps   = { type = 'bool',   default = true },
    Scale        = { type = 'number', default = 1.0 },
    LoadTheme    = { type = 'string', default = 'Default' },
    doLinks      = { type = 'bool',   default = true },
    mainEcho     = { type = 'string', default = '/say' },
    MainFontSize = { type = 'number', default = 16 },
    LogCommands  = { type = 'bool',   default = false },
    keyFocus     = { type = 'bool',   default = false },
    keyName      = { type = 'string', default = 'RightShift' },
}

---Checks if this character has data in the DB
---@return boolean
function Module.HasDBData()
    local db = Module.OpenDB()
    if not db then return false end
    local stmt = db:prepare('SELECT preset_id FROM char_active_preset WHERE char_name = ? AND server = ? LIMIT 1')
    if not stmt then db:close() return false end
    stmt:bind_values(Module.CharLoaded, Module.Server)
    local hasData = stmt:step() == Module.SQLite3.ROW
    stmt:finalize()
    db:close()
    return hasData
end

---Migrates a pickle settings table into the database as a new preset
---@param settings table -- the settings table from pickle
---@param charName string -- character name
function Module.MigratePickleToDB(settings, charName)
    local db = Module.OpenDB()
    if not db then return end

    local presetName = charName .. '_migrated'
    local serverName = Module.Server

    -- Check if preset already exists for this server
    local check = db:prepare('SELECT id FROM presets WHERE preset_name = ? AND server = ?')
    check:bind_values(presetName, serverName)
    if check:step() == Module.SQLite3.ROW then
        check:finalize()
        db:close()
        return -- already migrated
    end
    check:finalize()

    db:exec('BEGIN TRANSACTION')

    -- Create preset
    local pStmt = db:prepare('INSERT INTO presets (preset_name, server, created_by) VALUES (?, ?, ?)')
    pStmt:bind_values(presetName, serverName, charName)
    pStmt:step()
    pStmt:finalize()
    local presetID = db:last_insert_rowid()

    -- Insert global settings
    for key, meta in pairs(globalSettingsKeys) do
        local val = settings[key]
        if val ~= nil then
            local strVal
            if meta.type == 'bool' then
                strVal = val and '1' or '0'
            else
                strVal = tostring(val)
            end
            local gStmt = db:prepare('INSERT OR REPLACE INTO global_settings (char_name, server, key, value) VALUES (?, ?, ?, ?)')
            gStmt:bind_values(charName, serverName, key, strVal)
            gStmt:step()
            gStmt:finalize()
        end
    end

    -- Insert channels, events, filters
    if settings.Channels then
        for channelID, channelData in pairs(settings.Channels) do
            local cStmt = db:prepare([[
                INSERT INTO channels (preset_id, channel_id, name, enabled, echo, main_enable, enable_links, pop_out, locked, scale, main_font_size, tab_order)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]])
            cStmt:bind_values(
                presetID,
                channelID,
                channelData.Name or 'New',
                (channelData.enabled and 1 or 0),
                channelData.Echo or '/say',
                (channelData.MainEnable ~= false) and 1 or 0,
                (channelData.enableLinks and 1 or 0),
                (channelData.PopOut and 1 or 0),
                (channelData.locked and 1 or 0),
                channelData.Scale or 1.0,
                channelData.MainFontSize or channelData.FontSize or 16,
                channelData.TabOrder or 0
            )
            cStmt:step()
            cStmt:finalize()
            local channelRowID = db:last_insert_rowid()

            if channelData.Events then
                for eventIndex, eventData in pairs(channelData.Events) do
                    local eStmt = db:prepare([[
                        INSERT INTO events (channel_row_id, event_index, event_string, enabled)
                        VALUES (?, ?, ?, ?)
                    ]])
                    eStmt:bind_values(
                        channelRowID,
                        eventIndex,
                        eventData.eventString or 'new',
                        (eventData.enabled ~= false) and 1 or 0
                    )
                    eStmt:step()
                    eStmt:finalize()
                    local eventRowID = db:last_insert_rowid()

                    if eventData.Filters then
                        for filterIndex, filterData in pairs(eventData.Filters) do
                            local color = filterData.color or { 1.0, 1.0, 1.0, 1.0 }
                            local fStmt = db:prepare([[
                                INSERT INTO filters (event_row_id, filter_index, filter_string, color_r, color_g, color_b, color_a, enabled, hidden)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                            ]])
                            fStmt:bind_values(
                                eventRowID,
                                filterIndex,
                                filterData.filterString or '',
                                color[1] or 1.0,
                                color[2] or 1.0,
                                color[3] or 1.0,
                                color[4] or 1.0,
                                (filterData.enabled ~= false) and 1 or 0,
                                (filterData.hidden and 1 or 0)
                            )
                            fStmt:step()
                            fStmt:finalize()
                        end
                    end
                end
            end
        end
    end

    -- Set as active preset for this character
    local aStmt = db:prepare('INSERT OR REPLACE INTO char_active_preset (char_name, server, preset_id) VALUES (?, ?, ?)')
    aStmt:bind_values(charName, serverName, presetID)
    aStmt:step()
    aStmt:finalize()

    db:exec('COMMIT')
    db:exec('PRAGMA wal_checkpoint;')
    db:close()

    Module.ActivePresetID = presetID
    Module.ActivePresetName = presetName
end

---Loads settings from the database into Module.Settings
---@return boolean success
function Module.LoadSettingsFromDB()
    local db = Module.OpenDB()
    if not db then return false end

    -- Get active preset
    local presetID = nil
    local aStmt = db:prepare('SELECT preset_id FROM char_active_preset WHERE char_name = ? AND server = ? LIMIT 1')
    if not aStmt then db:close() return false end
    aStmt:bind_values(Module.CharLoaded, Module.Server)
    for row in aStmt:nrows() do
        presetID = row.preset_id
    end
    aStmt:finalize()
    if not presetID then
        db:close()
        return false
    end

    -- Get preset name
    local pStmt = db:prepare('SELECT preset_name FROM presets WHERE id = ?')
    pStmt:bind_values(presetID)
    for row in pStmt:nrows() do
        Module.ActivePresetName = row.preset_name
    end
    pStmt:finalize()
    Module.ActivePresetID = presetID

    -- Load global settings
    local settings = { Channels = {} }
    local gStmt = db:prepare('SELECT key, value FROM global_settings WHERE char_name = ? AND server = ?')
    gStmt:bind_values(Module.CharLoaded, Module.Server)
    for row in gStmt:nrows() do
        local meta = globalSettingsKeys[row.key]
        if meta then
            if meta.type == 'bool' then
                settings[row.key] = row.value == '1'
            elseif meta.type == 'number' then
                settings[row.key] = tonumber(row.value) or meta.default
            else
                settings[row.key] = row.value
            end
        end
    end
    gStmt:finalize()

    -- Load channels for this preset
    local cStmt = db:prepare('SELECT * FROM channels WHERE preset_id = ?')
    cStmt:bind_values(presetID)
    for cRow in cStmt:nrows() do
        local chanID = cRow.channel_id
        settings.Channels[chanID] = {
            Name        = cRow.name,
            enabled     = cRow.enabled == 1,
            Echo        = cRow.echo,
            MainEnable  = cRow.main_enable == 1,
            enableLinks = cRow.enable_links == 1,
            PopOut      = cRow.pop_out == 1,
            locked      = cRow.locked == 1,
            Scale       = cRow.scale,
            FontSize    = cRow.main_font_size,
            TabOrder    = cRow.tab_order,
            Events      = {},
        }
        local channelRowID = cRow.id

        -- Load events for this channel
        local eStmt = db:prepare('SELECT * FROM events WHERE channel_row_id = ? ORDER BY event_index')
        eStmt:bind_values(channelRowID)
        for eRow in eStmt:nrows() do
            local eIdx = eRow.event_index
            settings.Channels[chanID].Events[eIdx] = {
                eventString = eRow.event_string,
                enabled     = eRow.enabled == 1,
                Filters     = {},
            }
            local eventRowID = eRow.id

            -- Load filters for this event
            local fStmt = db:prepare('SELECT * FROM filters WHERE event_row_id = ? ORDER BY filter_index')
            fStmt:bind_values(eventRowID)
            for fRow in fStmt:nrows() do
                local fIdx = fRow.filter_index
                settings.Channels[chanID].Events[eIdx].Filters[fIdx] = {
                    filterString = fRow.filter_string,
                    color        = { fRow.color_r, fRow.color_g, fRow.color_b, fRow.color_a },
                    enabled      = fRow.enabled == 1,
                    hidden       = fRow.hidden == 1,
                }
            end
            fStmt:finalize()
        end
        eStmt:finalize()
    end
    cStmt:finalize()

    -- Check for channel overrides (mix-and-match)
    local oStmt = db:prepare('SELECT channel_id, preset_id FROM char_channel_overrides WHERE char_name = ? AND server = ?')
    oStmt:bind_values(Module.CharLoaded, Module.Server)
    local overrides = {}
    for oRow in oStmt:nrows() do
        table.insert(overrides, { channel_id = oRow.channel_id, preset_id = oRow.preset_id })
    end
    oStmt:finalize()

    for _, override in ipairs(overrides) do
        local overrideChanID = override.channel_id
        local overridePresetID = override.preset_id

        -- Load the overridden channel from the other preset
        local ocStmt = db:prepare('SELECT * FROM channels WHERE preset_id = ? AND channel_id = ?')
        ocStmt:bind_values(overridePresetID, overrideChanID)
        for cRow in ocStmt:nrows() do
            settings.Channels[overrideChanID] = {
                Name        = cRow.name,
                enabled     = cRow.enabled == 1,
                Echo        = cRow.echo,
                MainEnable  = cRow.main_enable == 1,
                enableLinks = cRow.enable_links == 1,
                PopOut      = cRow.pop_out == 1,
                locked      = cRow.locked == 1,
                Scale       = cRow.scale,
                FontSize    = cRow.main_font_size,
                TabOrder    = cRow.tab_order,
                Events      = {},
            }
            local channelRowID = cRow.id

            local eStmt = db:prepare('SELECT * FROM events WHERE channel_row_id = ? ORDER BY event_index')
            eStmt:bind_values(channelRowID)
            for eRow in eStmt:nrows() do
                local eIdx = eRow.event_index
                settings.Channels[overrideChanID].Events[eIdx] = {
                    eventString = eRow.event_string,
                    enabled     = eRow.enabled == 1,
                    Filters     = {},
                }
                local eventRowID = eRow.id

                local fStmt = db:prepare('SELECT * FROM filters WHERE event_row_id = ? ORDER BY filter_index')
                fStmt:bind_values(eventRowID)
                for fRow in fStmt:nrows() do
                    local fIdx = fRow.filter_index
                    settings.Channels[overrideChanID].Events[eIdx].Filters[fIdx] = {
                        filterString = fRow.filter_string,
                        color        = { fRow.color_r, fRow.color_g, fRow.color_b, fRow.color_a },
                        enabled      = fRow.enabled == 1,
                        hidden       = fRow.hidden == 1,
                    }
                end
                fStmt:finalize()
            end
            eStmt:finalize()
        end
        ocStmt:finalize()
    end

    db:close()

    Module.Settings = settings
    return true
end

---Writes current Module.Settings to the database for the active preset
function Module.WriteSettingsToDB()
    if not Module.ActivePresetID then return end
    local db = Module.OpenDB()
    if not db then return end

    db:exec('BEGIN TRANSACTION')

    -- Update global settings
    for key, meta in pairs(globalSettingsKeys) do
        local val = Module.Settings[key]
        if val ~= nil then
            local strVal
            if meta.type == 'bool' then
                strVal = val and '1' or '0'
            else
                strVal = tostring(val)
            end
            local gStmt = db:prepare('INSERT OR REPLACE INTO global_settings (char_name, server, key, value) VALUES (?, ?, ?, ?)')
            gStmt:bind_values(Module.CharLoaded, Module.Server, key, strVal)
            gStmt:step()
            gStmt:finalize()
        end
    end

    -- Delete existing channels/events/filters for this preset (CASCADE handles children)
    local dStmt = db:prepare('DELETE FROM channels WHERE preset_id = ?')
    dStmt:bind_values(Module.ActivePresetID)
    dStmt:step()
    dStmt:finalize()

    -- Re-insert channels, events, filters
    if Module.Settings.Channels then
        for channelID, channelData in pairs(Module.Settings.Channels) do
            local cStmt = db:prepare([[
                INSERT INTO channels (preset_id, channel_id, name, enabled, echo, main_enable, enable_links, pop_out, locked, scale, main_font_size, tab_order)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]])
            cStmt:bind_values(
                Module.ActivePresetID,
                channelID,
                channelData.Name or 'New',
                (channelData.enabled and 1 or 0),
                channelData.Echo or '/say',
                (channelData.MainEnable ~= false) and 1 or 0,
                (channelData.enableLinks and 1 or 0),
                (channelData.PopOut and 1 or 0),
                (channelData.locked and 1 or 0),
                channelData.Scale or 1.0,
                channelData.FontSize or 16,
                channelData.TabOrder or 0
            )
            cStmt:step()
            cStmt:finalize()
            local channelRowID = db:last_insert_rowid()

            if channelData.Events then
                for eventIndex, eventData in pairs(channelData.Events) do
                    local eStmt = db:prepare([[
                        INSERT INTO events (channel_row_id, event_index, event_string, enabled)
                        VALUES (?, ?, ?, ?)
                    ]])
                    eStmt:bind_values(
                        channelRowID,
                        eventIndex,
                        eventData.eventString or 'new',
                        (eventData.enabled ~= false) and 1 or 0
                    )
                    eStmt:step()
                    eStmt:finalize()
                    local eventRowID = db:last_insert_rowid()

                    if eventData.Filters then
                        for filterIndex, filterData in pairs(eventData.Filters) do
                            local color = filterData.color or { 1.0, 1.0, 1.0, 1.0 }
                            local fStmt = db:prepare([[
                                INSERT INTO filters (event_row_id, filter_index, filter_string, color_r, color_g, color_b, color_a, enabled, hidden)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                            ]])
                            fStmt:bind_values(
                                eventRowID,
                                filterIndex,
                                filterData.filterString or '',
                                color[1] or 1.0,
                                color[2] or 1.0,
                                color[3] or 1.0,
                                color[4] or 1.0,
                                (filterData.enabled ~= false) and 1 or 0,
                                (filterData.hidden and 1 or 0)
                            )
                            fStmt:step()
                            fStmt:finalize()
                        end
                    end
                end
            end
        end
    end

    -- Update preset timestamp
    local uStmt = db:prepare("UPDATE presets SET updated_at = datetime('now') WHERE id = ?")
    uStmt:bind_values(Module.ActivePresetID)
    uStmt:step()
    uStmt:finalize()

    db:exec('COMMIT')
    db:close()

    Module.SortChannels()
end

---Returns a list of all presets: { {id=N, name='...', created_by='...', created_at='...'}, ... }
---@return table
function Module.GetPresetList()
    local list = {}
    local db = Module.OpenDB()
    if not db then return list end
    local stmt = db:prepare('SELECT id, preset_name, server, created_by, created_at FROM presets ORDER BY server, preset_name')
    if not stmt then db:close() return list end
    for row in stmt:nrows() do
        table.insert(list, {
            id         = row.id,
            name       = row.preset_name,
            server     = row.server,
            created_by = row.created_by,
            created_at = row.created_at,
        })
    end
    stmt:finalize()
    db:close()
    Module.PresetList = list
    return list
end

---Creates a new empty preset
---@param name string
---@return integer|nil presetID
function Module.CreatePreset(name)
    local db = Module.OpenDB()
    if not db then return nil end
    local stmt = db:prepare('INSERT INTO presets (preset_name, server, created_by) VALUES (?, ?, ?)')
    if not stmt then db:close() return nil end
    stmt:bind_values(name, Module.Server, Module.CharLoaded)
    local rc = stmt:step()
    stmt:finalize()
    if rc ~= Module.SQLite3.DONE then
        db:close()
        return nil
    end
    local id = db:last_insert_rowid()
    db:close()
    return id
end

---Deletes a preset by ID (CASCADE removes channels/events/filters)
---@param presetID integer
---@return boolean
function Module.DeletePreset(presetID)
    local db = Module.OpenDB()
    if not db then return false end
    local stmt = db:prepare('DELETE FROM presets WHERE id = ?')
    stmt:bind_values(presetID)
    local rc = stmt:step()
    stmt:finalize()
    -- Also clean up char_active_preset entries
    local cStmt = db:prepare('DELETE FROM char_active_preset WHERE preset_id = ?')
    cStmt:bind_values(presetID)
    cStmt:step()
    cStmt:finalize()
    -- Clean up overrides
    local oStmt = db:prepare('DELETE FROM char_channel_overrides WHERE preset_id = ?')
    oStmt:bind_values(presetID)
    oStmt:step()
    oStmt:finalize()
    db:close()
    return rc == Module.SQLite3.DONE
end

---Copies a preset to a new name, returns the new preset ID
---@param fromPresetID integer
---@param newName string
---@return integer|nil
function Module.CopyPreset(fromPresetID, newName)
    local db = Module.OpenDB()
    if not db then return nil end

    db:exec('BEGIN TRANSACTION')

    -- Create new preset
    local pStmt = db:prepare('INSERT INTO presets (preset_name, server, created_by) VALUES (?, ?, ?)')
    pStmt:bind_values(newName, Module.Server, Module.CharLoaded)
    local rc = pStmt:step()
    pStmt:finalize()
    if rc ~= Module.SQLite3.DONE then
        db:exec('ROLLBACK')
        db:close()
        return nil
    end
    local newPresetID = db:last_insert_rowid()

    -- Copy channels
    local cStmt = db:prepare('SELECT * FROM channels WHERE preset_id = ?')
    cStmt:bind_values(fromPresetID)
    for cRow in cStmt:nrows() do
        local icStmt = db:prepare([[
            INSERT INTO channels (preset_id, channel_id, name, enabled, echo, main_enable, enable_links, pop_out, locked, scale, main_font_size, tab_order)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]])
        icStmt:bind_values(newPresetID, cRow.channel_id, cRow.name, cRow.enabled, cRow.echo,
            cRow.main_enable, cRow.enable_links, cRow.pop_out, cRow.locked, cRow.scale,
            cRow.main_font_size, cRow.tab_order)
        icStmt:step()
        icStmt:finalize()
        local newChanRowID = db:last_insert_rowid()

        -- Copy events for this channel
        local eStmt = db:prepare('SELECT * FROM events WHERE channel_row_id = ?')
        eStmt:bind_values(cRow.id)
        for eRow in eStmt:nrows() do
            local ieStmt = db:prepare('INSERT INTO events (channel_row_id, event_index, event_string, enabled) VALUES (?, ?, ?, ?)')
            ieStmt:bind_values(newChanRowID, eRow.event_index, eRow.event_string, eRow.enabled)
            ieStmt:step()
            ieStmt:finalize()
            local newEventRowID = db:last_insert_rowid()

            -- Copy filters for this event
            local fStmt = db:prepare('SELECT * FROM filters WHERE event_row_id = ?')
            fStmt:bind_values(eRow.id)
            for fRow in fStmt:nrows() do
                local ifStmt = db:prepare([[
                    INSERT INTO filters (event_row_id, filter_index, filter_string, color_r, color_g, color_b, color_a, enabled, hidden)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ]])
                ifStmt:bind_values(newEventRowID, fRow.filter_index, fRow.filter_string,
                    fRow.color_r, fRow.color_g, fRow.color_b, fRow.color_a,
                    fRow.enabled, fRow.hidden)
                ifStmt:step()
                ifStmt:finalize()
            end
            fStmt:finalize()
        end
        eStmt:finalize()
    end
    cStmt:finalize()

    db:exec('COMMIT')
    db:close()
    return newPresetID
end

---Sets the active preset for the current character and reloads
---@param presetID integer
function Module.SwitchPreset(presetID)
    local db = Module.OpenDB()
    if not db then return end

    -- Remove old active preset
    local dStmt = db:prepare('DELETE FROM char_active_preset WHERE char_name = ? AND server = ?')
    dStmt:bind_values(Module.CharLoaded, Module.Server)
    dStmt:step()
    dStmt:finalize()

    -- Set new active preset
    local iStmt = db:prepare('INSERT INTO char_active_preset (char_name, server, preset_id) VALUES (?, ?, ?)')
    iStmt:bind_values(Module.CharLoaded, Module.Server, presetID)
    iStmt:step()
    iStmt:finalize()
    db:close()

    -- Unregister all events
    for eventName, _ in pairs(Module.eventNames) do
        mq.unevent(eventName)
    end
    Module.eventNames = {}

    -- Reload from DB
    Module.LoadSettingsFromDB()
    Module.tempSettings = Module.Settings

    -- Rebuild consoles and events
    for channelID, _ in pairs(Module.Consoles) do
        Module.Consoles[channelID].console = nil
    end
    for channelID, _ in pairs(Module.Settings.Channels) do
        if not Module.Consoles[channelID] then
            Module.Consoles[channelID] = {}
        end
        SetUpConsoles(channelID)
    end
    Module.console = nil
    Module.console = zep.Console.new("Chat##Console")
    BuildEvents()
    Module.SortChannels()
end

---Renames a preset
---@param presetID integer
---@param newName string
---@return boolean
function Module.RenamePreset(presetID, newName)
    local db = Module.OpenDB()
    if not db then return false end
    local stmt = db:prepare('UPDATE presets SET preset_name = ? WHERE id = ?')
    stmt:bind_values(newName, presetID)
    local rc = stmt:step()
    stmt:finalize()
    db:close()
    if rc == Module.SQLite3.DONE then
        if Module.ActivePresetID == presetID then
            Module.ActivePresetName = newName
        end
        return true
    end
    return false
end

---Saves current settings as a new preset with the given name
---@param name string
---@return integer|nil presetID
function Module.SaveAsNewPreset(name)
    -- First write current settings to active preset to ensure they're saved
    Module.WriteSettingsToDB()
    -- Then copy the active preset
    local newID = Module.CopyPreset(Module.ActivePresetID, name)
    if newID then
        Module.GetPresetList()
    end
    return newID
end

---Build the consoles for each channel based on ChannelID
---@param channelID integer -- the channel ID number for the console we are setting up
SetUpConsoles = function(channelID)
    if Module.Consoles[channelID].console == nil then
        Module.Consoles[channelID].txtBuffer = {
            [1] = {
                color = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, },
                text = '',
            },
        }
        Module.Consoles[channelID].CommandBuffer = ''
        Module.Consoles[channelID].CommandHistory = {}
        Module.Consoles[channelID].txtAutoScroll = true
        Module.Consoles[channelID].console = zep.Console.new(channelID .. "##Console")
    end
end

local function ResetConsoles()
    for channelID, _ in pairs(Module.Consoles) do
        Module.Consoles[channelID].console = nil
        SetUpConsoles(channelID)
    end
    Module.console = nil
    Module.console = zep.Console.new("MainConsole")
end

---Takes in a table and re-numbers the Indicies to be concurrent
---@param table any @Table to reindex
---@return table @ Returns the table with the Indicies in order with no gaps.
local function reindex(table)
    local newTable = {}
    local newIdx = 0
    local indexCnt = 0
    for k, v in pairs(table) do
        indexCnt = indexCnt + 1
        if k == 0 or k == 9000 or k >= 9100 then
            newTable[k] = v
        end
    end

    for i = 1, indexCnt do
        if table[i] ~= nil then
            newIdx = newIdx + 1
            if newIdx == i then
                newTable[i] = table[i]
            else
                newTable[newIdx] = table[i]
            end
        else
            newTable[i] = nil
        end
    end
    return newTable
end


---Process ChatWin.Settings and reindex the Channel, Events, and Filter ID's
---Runs each table through the reindex function and updates the settings file when done
---@param file any @ Full File path to config file
---@param table any @ Returns the table with the Indicies in order with no gaps.
local function reIndexSettings(file, table)
    table.Channels = reindex(table.Channels)
    local tmpTbl = table
    for cID, data in pairs(table.Channels) do
        for id, cData in pairs(data) do
            if id == "Events" then
                tmpTbl.Channels[cID][id] = reindex(cData)
                table = tmpTbl
                for eID, eData in pairs(table.Channels[cID].Events) do
                    for k, v in pairs(eData) do
                        if k == "Filters" then
                            tmpTbl.Channels[cID][id][eID].Filters = reindex(v)
                        end
                    end
                end
            end
        end
    end
    table = tmpTbl
    mq.pickle(file, table)
end

---Writes settings from the settings table passed to the setting file (full path required)
-- Uses mq.pickle to serialize the table and write to file
---@param file string -- File Name and path
---@param table table -- Table of settings to write
local function writeSettings(file, table)
    Module.WriteSettingsToDB()
    Module.SortChannels()
end

local function loadSettings()
    -- Try loading from DB first
    if Module.HasDBData() then
        if Module.LoadSettingsFromDB() then
            -- successfully loaded from DB, skip pickle loading
            goto settings_loaded
        end
    end

    -- Fallback: load from pickle files
    if not Module.Utils.File.Exists(Module.SettingsFile) then
        settingsOld = string.format('%s/MyChat_%s_%s.lua', mq.configDir, Module.Server:gsub(' ', '_'), Module.CharLoaded)
        if Module.Utils.File.Exists(settingsOld) then
            Module.Settings = dofile(settingsOld)
            mq.pickle(Module.SettingsFile, Module.Settings)
        else
            Module.Settings = Module.defaults
            mq.pickle(Module.SettingsFile, Module.defaults)
        end
    else
        -- Load settings from the Lua config file
        Module.Settings = dofile(Module.SettingsFile)
        if firstPass then
            reIndexSettings(Module.SettingsFile, Module.Settings)
            firstPass = false
        end
    end

    -- Migrate pickle to DB on first load
    Module.MigratePickleToDB(Module.Settings, Module.CharLoaded)

    ::settings_loaded::

    if Module.Settings.Channels[0] == nil then
        Module.Settings.Channels[0] = {}
        Module.Settings.Channels[0] = Module.defaults['Channels'][0]
    end
    if Module.Settings.Channels[9000] == nil then
        Module.Settings.Channels[9000] = {}
        Module.Settings.Channels[9000] = Module.defaults['Channels'][9000]
    end
    if Module.Settings.Channels[9100] == nil then
        Module.Settings.Channels[9100] = {}
        Module.Settings.Channels[9100] = Module.defaults['Channels'][9100]
    end
    Module.Settings.Channels[9000].enabled = enableSpam
    local i = 1
    for channelID, channelData in pairs(Module.Settings.Channels) do
        -- setup default Echo command channels.
        if not channelData.Echo then
            Module.Settings.Channels[channelID].Echo = '/say'
        end
        -- Ensure each channel's console widget is initialized
        if not Module.Consoles[channelID] then
            Module.Consoles[channelID] = {}
        end

        if Module.Settings.Channels[channelID].MainEnable == nil then
            Module.Settings.Channels[channelID].MainEnable = true
        end
        if Module.Settings.Channels[channelID].enableLinks == nil then
            Module.Settings.Channels[channelID].enableLinks = false
        end
        if Module.Settings.Channels[channelID].PopOut == nil then
            Module.Settings.Channels[channelID].PopOut = false
        end
        if Module.Settings.Channels[channelID].locked == nil then
            Module.Settings.Channels[channelID].locked = false
        end

        if Module.Settings.Channels[channelID].TabOrder == nil then
            Module.Settings.Channels[channelID].TabOrder = i
        end
        if Module.Settings.locked == nil then
            Module.Settings.locked = false
        end

        if Module.Settings.timeStamps == nil then
            Module.Settings.timeStamps = timeStamps
        end
        timeStamps = Module.Settings.timeStamps
        if forceIndex then
            Module.Consoles[channelID].console = nil
        end

        SetUpConsoles(channelID)

        for eID, eData in pairs(channelData['Events']) do
            if eData.color then
                if not Module.Settings.Channels[channelID]['Events'][eID]['Filters'] then
                    Module.Settings.Channels[channelID]['Events'][eID]['Filters'] = {}
                end
                if Module.Settings.Channels[channelID]['Events'][eID].enabled == nil then
                    Module.Settings.Channels[channelID]['Events'][eID].enabled = true
                end
                if not Module.Settings.Channels[channelID]['Events'][eID]['Filters'][0] then
                    Module.Settings.Channels[channelID]['Events'][eID]['Filters'][0] = { filterString = '', color = {}, enabled = true, }
                end
                Module.Settings.Channels[channelID]['Events'][eID]['Filters'][0].color = eData.color
                eData.color = nil
            end
            if eData.enabled == nil then eData.enabled = true end
            for fID, fData in pairs(eData.Filters) do
                if fData.filterString == 'TANK' then
                    Module.Settings.Channels[channelID].Events[eID].Filters[fID].filterString = 'TK1'
                elseif fData.filterString == 'PET' then
                    Module.Settings.Channels[channelID].Events[eID].Filters[fID].filterString = 'PT1'
                elseif fData.filterString == 'P1' then
                    Module.Settings.Channels[channelID].Events[eID].Filters[fID].filterString = 'PT1'
                elseif fData.filterString == 'MA' then
                    Module.Settings.Channels[channelID].Events[eID].Filters[fID].filterString = 'M1'
                elseif fData.filterString == 'HEALER' then
                    Module.Settings.Channels[channelID].Events[eID].Filters[fID].filterString = 'H1'
                elseif fData.filterString == 'GROUP' then
                    Module.Settings.Channels[channelID].Events[eID].Filters[fID].filterString = 'GP1'
                elseif fData.filterString == 'ME' then
                    Module.Settings.Channels[channelID].Events[eID].Filters[fID].filterString = 'M3'
                end
                if fData.enabled == nil then
                    Module.Settings.Channels[channelID].Events[eID].Filters[fID].enabled = true
                end
                if fData.hidden == nil then
                    Module.Settings.Channels[channelID].Events[eID].Filters[fID].hidden = false
                end
                Module.tempFilterHidden[channelID] = {}
                Module.tempFilterHidden[channelID][eID] = {}
                Module.tempFilterHidden[channelID][eID][fID] = Module.Settings.Channels[channelID].Events[eID].Filters[fID].hidden
            end
        end
        i = i + 1
    end

    if Module.Settings.locked == nil then
        Module.Settings.locked = false
    end

    if Module.Settings.timeStamps == nil then
        Module.Settings.timeStamps = timeStamps
    end
    if Module.Settings.Scale == nil then
        Module.Settings.Scale = 1.0
    end

    if not loadedExeternally then
        if not Module.Utils.File.Exists(Module.ThemesFile) then
            local defaultThemes = Module.Utils.Library.Include('defaults.themes')
            Module.Theme = defaultThemes
        else
            -- Load settings from the Lua config file
            Module.Theme = dofile(Module.ThemesFile)
        end
    end

    if not Module.Settings.LoadTheme then
        Module.Settings.LoadTheme = Module.Theme.LoadTheme
    end

    if Module.Settings.doLinks == nil then
        Module.Settings.doLinks = true
    end
    if Module.Settings.mainEcho == nil then
        Module.Settings.mainEcho = '/say'
    end

    if Module.Settings.MainFontSize == nil then
        Module.Settings.MainFontSize = 16
    end

    if Module.Settings.LogCommands == nil then
        Module.Settings.LogCommands = false
    end

    eChan = Module.Settings.mainEcho
    Module.Settings.doLinks = true
    forceIndex = false
    Module.KeyFocus = Module.Settings.keyFocus ~= nil or false
    Module.KeyName = Module.Settings.keyName ~= nil and Module.Settings.keyName or 'RightShift'
    Module.tempSettings = Module.Settings
end

BuildEvents = function()
    Module.eventNames = {}
    for channelID, channelData in pairs(Module.Settings.Channels) do
        local eventOptions = { keepLinks = channelData.enableLinks, }
        for eventId, eventDetails in pairs(channelData.Events) do
            if eventDetails.enabled then
                if eventDetails.eventString ~= 'new' then
                    local eventName = string.format("event_%s_%d", channelID, eventId)
                    if channelID ~= 9000 then
                        mq.event(eventName, eventDetails.eventString, function(line) Module.EventChat(channelID, eventName, line, false) end, eventOptions)
                    elseif channelID == 9000 and enableSpam then
                        mq.event(eventName, eventDetails.eventString, function(line) Module.EventChatSpam(channelID, line) end)
                    end
                    -- Store event details for direct access
                    Module.eventNames[eventName] = eventDetails
                end
            end
        end
    end
end

local function ModifyEvent(chanID)
    local channelEvents = Module.Settings.Channels[chanID].Events
    local linksEnabled = Module.Settings.Channels[chanID].enableLinks
    local eventOptions = { keepLinks = linksEnabled, }
    for eID, eData in pairs(channelEvents) do
        local eName = string.format("event_%s_%d", chanID, eID)
        mq.unevent(eName)
    end
    -- rebuild the channels events
    for eID, eData in pairs(channelEvents) do
        local eName = string.format("event_%s_%d", chanID, eID)
        if eData.enabled then
            if eData.eventString then
                if chanID ~= 9000 then
                    mq.event(eName, eData.eventString, function(line) Module.EventChat(chanID, eName, line, false) end, eventOptions)
                elseif chanID == 9000 and enableSpam then
                    mq.event(eName, eData.eventString, function(line) Module.EventChatSpam(chanID, line) end)
                end
                Module.eventNames[eName] = eData
            end
        end
    end
end

local function ResetEvents()
    Module.Settings = Module.tempSettings
    writeSettings(Module.SettingsFile, Module.Settings)
    -- Unregister and reregister events to apply changes
    for eventName, _ in pairs(Module.eventNames) do
        mq.unevent(eventName)
    end
    Module.eventNames = {}
    loadSettings()
    BuildEvents()
end

---@param string string @ the filter string we are parsing
---@param line string @ the line captured by the event
---@param type string @ the type either 'healer' or 'group' for tokens H1 and GP1 respectivly.
---@return string string @ new value for the filter string if found else return the original
local function CheckGroup(string, line, type)
    local gSize = mq.TLO.Me.GroupSize()
    gSize = gSize - 1
    local tString = string
    for i = 1, gSize do
        local groupMember = mq.TLO.Group.Member(i)

        local class = groupMember.Class.ShortName() or 'NO GROUP'
        local name = groupMember.Name() or 'NO GROUP'
        if type == 'healer' then
            class = groupMember.Class.ShortName() or 'NO GROUP'
            if (class == 'CLR') or (class == 'DRU') or (class == 'SHM') then
                name = groupMember.CleanName() or 'NO GROUP'
                tString = string.gsub(string, 'H1', name)
            end
        end
        if type == 'group' then
            tString = string.gsub(string, 'GP1', name)
        end
        if string.find(line, tString) then
            string = tString
            return string
        end
    end
    return string
end

---@param line string @ the string we are parsing
---@return boolean @ Was the originator an NPC?
---@return string @ the NPC name if found
local function CheckNPC(line)
    local name = ''
    if string.find(line, "pet tells you") then
        name = string.sub(line, 1, string.find(line, "pet tells you") - 1)
        return true, name
    elseif string.find(line, "tells you,") then
        name = string.sub(line, 1, string.find(line, "tells you") - 2)
    elseif string.find(line, "says") then
        name = string.sub(line, 1, string.find(line, "says") - 2)
    elseif string.find(line, "whispers,") then
        name = string.sub(line, 1, string.find(line, "whispers") - 2)
    elseif string.find(line, "says to you,") then
        name = string.sub(line, 1, string.find(line, "says to you") - 2)
    elseif string.find(line, "shouts,") then
        name = string.sub(line, 1, string.find(line, "shouts") - 2)
    elseif string.find(line, "slashes") then
        name = string.sub(line, 1, string.find(line, "slashes") - 1)
    elseif string.find(line, "pierces") then
        name = string.sub(line, 1, string.find(line, "pierces") - 1)
    elseif string.find(line, "kicks") then
        name = string.sub(line, 1, string.find(line, "kicks") - 1)
    elseif string.find(line, "crushes") then
        name = string.sub(line, 1, string.find(line, "crushes") - 1)
    elseif string.find(line, "bashes") then
        name = string.sub(line, 1, string.find(line, "bashes") - 1)
    elseif string.find(line, "hits") then
        name = string.sub(line, 1, string.find(line, "hits") - 1)
    elseif string.find(line, "tries") then
        name = string.sub(line, 1, string.find(line, "tries") - 1)
    elseif string.find(line, "backstabs") then
        name = string.sub(line, 1, string.find(line, "backstabs") - 1)
    elseif string.find(line, "bites") then
        name = string.sub(line, 1, string.find(line, "bites") - 1)
    elseif string.find(line, "begins") then
        name = string.sub(line, 1, string.find(line, "begins") - 1)
    else
        return false, name
    end
    name = name:gsub(" $", "")
    local check = string.format("npc =\"%s\"", name)
    local check2 = string.format("pet =\"%s\"", name)
    local check3 = string.format("npc \"%s\"", name)

    if mq.TLO.SpawnCount(check)() ~= nil then
        if mq.TLO.SpawnCount(check)() ~= 0 then
            return true, name
        end
    end
    if mq.TLO.SpawnCount(check2)() ~= nil then
        if mq.TLO.SpawnCount(check2)() ~= 0 then
            return true, name
        end
    end
    if mq.TLO.SpawnCount(check3)() ~= nil then
        if mq.TLO.SpawnCount(check3)() ~= 0 then
            return true, name
        end
    end
    return false, name
end

function Module.BackupSettings()
    local date = os.date("%m_%d_%Y_%H_%M")
    local backup = string.format('%s/MyUI/MyChat/%s/Backups/%s_BAK_%s.lua', mq.configDir, Module.Server:gsub(' ', '_'), Module.CharLoaded, date)
    mq.pickle(backup, Module.Settings)
end

--[[ Reads in the line, channelID and eventName of the triggered events. Parses the line against the Events and Filters for that channel.
    adjusts coloring for the line based on settings for the matching event / filter and writes to the corresponding console.
    if an event contains filters and the line doesn't match any of them we discard the line and return.
    If there are no filters we use the event default coloring and write to the consoles. ]]
---@param channelID integer @ The ID number of the Channel the triggered event belongs to
---@param eventName string @ the name of the event that was triggered
---@param line string @ the line of text that triggred the event
---@param spam boolean @ are we parsing this from the spam channel?
---@return boolean
function Module.EventChat(channelID, eventName, line, spam)
    local conLine = line
    local eventDetails = Module.eventNames[eventName]
    if not eventDetails then return false end
    if not eventDetails.enabled then return false end

    if Module.Consoles[channelID] then
        local txtBuffer = Module.Consoles[channelID].txtBuffer            -- Text buffer for the channel ID we are working with.
        local colorVec = eventDetails.Filters[0].color or { 1, 1, 1, 1, } -- Color Code to change line to, default is white
        local fMatch = false
        local matchCount = 0
        local negMatch = false
        local conColorStr = 'white'
        local gSize = mq.TLO.Me.GroupSize()      -- size of the group including yourself
        local rSize = mq.TLO.Raid.Members() or 0 -- size of the raid including yourself
        gSize = gSize - 1
        if txtBuffer then
            local haveFilters = false
            for fID = 1, getNextID(eventDetails.Filters) - 1 do
                negMatch = false
                fMatch = false
                if eventDetails.Filters[fID] ~= nil then
                    local fData = eventDetails.Filters[fID]

                    if fID > 0 and fData.enabled then
                        haveFilters = true

                        local fString = fData.filterString -- String value we are filtering for
                        if string.find(fString, 'NO2') then
                            fString = string.gsub(fString, 'NO2', '')
                            negMatch = true
                        end

                        if string.find(fString, 'M3') then
                            fString = string.gsub(fString, 'M3', Module.CharLoaded)
                        elseif string.find(fString, 'PT1') then
                            fString = string.gsub(fString, 'PT1', mq.TLO.Me.Pet.DisplayName() or 'NO PET')
                        elseif string.find(fString, 'PT3') then
                            local npc, npcName = CheckNPC(line)
                            local tagged = false
                            if gSize > 0 then
                                for g = 1, gSize do
                                    if mq.TLO.Spawn(string.format("%s", npcName)).Master.Name() == mq.TLO.Group.Member(g).Name() then
                                        fString = string.gsub(fString, 'PT3', npcName)
                                        tagged = true
                                        break
                                    end
                                end
                            end
                            if rSize > 0 and not tagged then
                                for r = 1, rSize do
                                    if mq.TLO.Spawn(string.format("%s", npcName)).Master.Name() == mq.TLO.Raid.Member(r).Name() then
                                        fString = string.gsub(fString, 'PT3', npcName)
                                        tagged = true
                                        break
                                    end
                                end
                            end
                            if not tagged then
                                fString = string.gsub(fString, 'PT3', mq.TLO.Me.Pet.DisplayName() or 'NO PET')
                                tagged = true
                            end
                        elseif string.find(fString, 'M1') then
                            fString = string.gsub(fString, 'M1', mq.TLO.Group.MainAssist.Name() or 'NO MA')
                        elseif string.find(fString, 'TK1') then
                            fString = string.gsub(fString, 'TK1', mq.TLO.Group.MainTank.Name() or 'NO TANK')
                        elseif string.find(fString, 'P3') then
                            local npc, pcName = CheckNPC(line)
                            if not npc and pcName ~= (mq.TLO.Me.Pet.DisplayName() or 'NO PET') then
                                fString = string.gsub(fString, 'P3', pcName or 'None')
                            end
                        elseif string.find(fString, 'N3') then
                            local npc, npcName = CheckNPC(line)
                            if npc then
                                fString = string.gsub(fString, 'N3', npcName or 'None')
                            end
                        elseif string.find(fString, 'RL') then
                            fString = string.gsub(fString, 'RL', mq.TLO.Raid.Leader.Name() or 'NO RAID')
                        elseif string.find(fString, 'G1') then
                            fString = string.gsub(fString, 'G1', mq.TLO.Group.Member(1).Name() or 'NO GROUP')
                        elseif string.find(fString, 'G2') then
                            fString = string.gsub(fString, 'G2', mq.TLO.Group.Member(2).Name() or 'NO GROUP')
                        elseif string.find(fString, 'G3') then
                            fString = string.gsub(fString, 'G3', mq.TLO.Group.Member(3).Name() or 'NO GROUP')
                        elseif string.find(fString, 'G4') then
                            fString = string.gsub(fString, 'G4', mq.TLO.Group.Member(4).Name() or 'NO GROUP')
                        elseif string.find(fString, 'G5') then
                            fString = string.gsub(fString, 'G5', mq.TLO.Group.Member(5).Name() or 'NO GROUP')
                        elseif string.find(fString, 'H1') then
                            fString = CheckGroup(fString, line, 'healer')
                        elseif string.find(fString, 'GP1') then
                            fString = CheckGroup(fString, line, 'group')
                        end
                        if string.find(line, fString) then
                            colorVec = fData.color
                            fMatch = true
                        end
                        if fMatch and (negMatch or fData.hidden) then
                            fMatch = false
                            negMatch = false
                            matchCount = 0
                            haveFilters = true
                            goto found_match
                        end
                        if fMatch then
                            matchCount = matchCount + 1
                            goto found_match
                        end
                    end
                end
            end
            ::found_match::
            if matchCount == 0 and haveFilters then return fMatch end -- we had filters and didn't match so leave
            if not spam then
                if string.lower(Module.Settings.Channels[channelID].Name) == 'consider' then
                    local conTarg = mq.TLO.Target
                    if conTarg ~= nil then
                        conColorStr = string.lower(conTarg.ConColor() or 'white')
                        colorVec = GetColorVal(conColorStr)
                    end
                end
                -----------------------------------------
                local tStamp = mq.TLO.Time.Time24() -- Get the current timestamp
                local colorCode = ImVec4(colorVec[1], colorVec[2], colorVec[3], colorVec[4])

                if Module.Consoles[channelID].console then
                    Module.Utils.AppendColoredTimestamp(Module.Consoles[channelID].console, tStamp, conLine, colorCode, timeStamps)
                end

                -- -- write channel console
                local i = getNextID(txtBuffer)

                if timeStamps then
                    line = string.format("%s %s", tStamp, line)
                end

                -- write main console
                if Module.tempSettings.Channels[channelID].MainEnable then
                    Module.Utils.AppendColoredTimestamp(Module.console, tStamp, conLine, colorCode, timeStamps)
                    local z = getNextID(mainBuffer)

                    if z > 1 then
                        if mainBuffer[z - 1].text == '' then z = z - 1 end
                    end
                    mainBuffer[z] = {
                        color = colorVec,
                        text = line,
                    }
                    local bufferLength = #mainBuffer
                    if bufferLength > zBuffer then
                        -- Remove excess lines
                        for j = 1, bufferLength - zBuffer do
                            table.remove(mainBuffer, 1)
                        end
                    end
                end

                -- ZOOM Console hack
                if i > 1 then
                    if txtBuffer[i - 1].text == '' then i = i - 1 end
                end

                -- Add the new line to the buffer

                txtBuffer[i] = {
                    color = colorVec,
                    text = line,
                }
                -- cleanup zoom buffer
                -- Check if the buffer exceeds 1000 lines
                local bufferLength = #txtBuffer
                if bufferLength > zBuffer then
                    -- Remove excess lines
                    for j = 1, bufferLength - zBuffer do
                        table.remove(txtBuffer, 1)
                    end
                end

                -- Mark this line as claimed so Spam channel skips it
                claimedLines[conLine] = true
                claimedLinesTTL[conLine] = os.clock()
            end
            return fMatch
        else
            print("Error: txtBuffer is nil for channelID " .. channelID)
            return fMatch
        end
    else
        print("Error: ChatWin.Consoles[channelID] is nil for channelID " .. channelID)
        return false
    end
end

---Spam reverse filter: shows only lines NOT already claimed by another channel's event.
---@param channelID integer @ The ID number of the Spam channel (9000)
---@param line string @ the line of text captured by the #*# catch-all event
function Module.EventChatSpam(channelID, line)
    -- Clean stale claimed entries
    local now = os.clock()
    for k, t in pairs(claimedLinesTTL) do
        if now - t > CLAIMED_TTL then
            claimedLines[k] = nil
            claimedLinesTTL[k] = nil
        end
    end

    -- If any real channel already claimed this line, skip it
    if claimedLines[line] then return end

    -- Write to spam console (unclaimed line)
    if not Module.Consoles[channelID] then return end
    local txtBuffer = Module.Consoles[channelID].txtBuffer
    if not txtBuffer then return end

    local tStamp = mq.TLO.Time.Time24()
    local colorVec = { 1, 1, 1, 1 }
    local colorCode = ImVec4(colorVec[1], colorVec[2], colorVec[3], colorVec[4])

    if Module.Consoles[channelID].console then
        Module.Utils.AppendColoredTimestamp(Module.Consoles[channelID].console, tStamp, line, colorCode, timeStamps)
    end

    local displayLine = timeStamps and string.format("%s %s", tStamp, line) or line
    local i = getNextID(txtBuffer)
    if i > 1 and txtBuffer[i - 1].text == '' then i = i - 1 end
    txtBuffer[i] = { color = colorVec, text = displayLine }

    local bufferLength = #txtBuffer
    if bufferLength > zBuffer then
        for j = 1, bufferLength - zBuffer do
            table.remove(txtBuffer, 1)
        end
    end
end

-- Call back function for InputText. Handles command history and tab completion
---@param data ImGuiInputTextCallbackData
local function inputTextCallback(_, data)
    --Handle command history
    if data.EventFlag == ImGuiInputTextFlags.CallbackHistory then
        if data.EventKey == ImGuiKey.UpArrow then
            -- Move up in history
            if Module.historyIndex == nil then
                Module.historyIndex = #Module.commandHistory -- Start from the last command
            elseif Module.historyIndex > 1 then
                Module.historyIndex = Module.historyIndex - 1
            end
        elseif data.EventKey == ImGuiKey.DownArrow then
            -- Move down in history
            if Module.historyIndex ~= nil then
                if Module.historyIndex < #Module.commandHistory then
                    Module.historyIndex = Module.historyIndex + 1
                else
                    Module.historyIndex = nil -- Reset to empty input
                end
            end
        end

        -- Update the actual command buffer instead of data.Buffer
        if Module.historyIndex then
            Module.commandBuffer = Module.commandHistory[Module.historyIndex]
            data:DeleteChars(0, #data.Buffer)
            data:InsertChars(0, Module.commandHistory[Module.historyIndex])
        end

        return 0
    end
    return 0
end

local historyUpdated = false
local focusKeyboard = false
------------------------------------------ GUI's --------------------------------------------
local function DrawConsole(channelID)
    local settings = Module.Settings.Channels[channelID]
    local console = Module.Consoles[channelID]
    local name = settings.Name .. '##' .. channelID
    local PopOut = settings.PopOut

    local footerHeight = 35
    local contentSizeX, contentSizeY = ImGui.GetContentRegionAvail()
    contentSizeY = contentSizeY - footerHeight

    -- Render console output
    console.console:Render(ImVec2(0, contentSizeY))

    -- Separator for command input
    ImGui.Separator()

    -- Input text field flags
    local textFlags = bit32.bor(
        ImGuiInputTextFlags.EnterReturnsTrue,
        ImGuiInputTextFlags.CallbackCompletion,
        ImGuiInputTextFlags.CallbackHistory
    )

    -- Position and style adjustments
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
    ImGui.SetCursorPosY(ImGui.GetCursorPosY() + 2)
    ImGui.PushItemWidth(ImGui.GetContentRegionAvail())
    ImGui.PushStyleColor(ImGuiCol.FrameBg, ImVec4(0, 0, 0, 0))

    -- Input text field
    local cmdBuffer = settings.commandBuffer or ""
    local accept = false
    local posX, posY = ImGui.GetCursorPos()
    cmdBuffer, accept = ImGui.InputText('##Input##' .. name, cmdBuffer, textFlags)
    ImGui.PopStyleColor()
    ImGui.PopItemWidth()

    -- Tooltip for additional console info
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(settings.Echo)
        if PopOut then
            ImGui.Text(settings.Name)
            local bufferSize = string.format("Buffer Size: %s lines.", tostring(getNextID(console.txtBuffer) - 1))
            ImGui.Text(bufferSize)
        end
        ImGui.EndTooltip()
    end

    -- Handle command execution
    if accept then
        Module.ChannelExecCommand(cmdBuffer, channelID)
        cmdBuffer = ""
        settings.commandBuffer = cmdBuffer
        ImGui.SetKeyboardFocusHere(-1) -- Reset focus for seamless interaction
    end

    -- Draw the context menu for command history
    if ImGui.BeginPopupContextItem("Command History##ContextMenu") then
        if #Module.Consoles[channelID].CommandHistory > 0 then
            ImGui.Text("Command History")
            ImGui.Separator()

            -- Display history in reverse order (latest command first)
            for i = #Module.Consoles[channelID].CommandHistory, 1, -1 do
                local command = Module.Consoles[channelID].CommandHistory[i]
                if ImGui.Selectable(command) then
                    -- Fill the input field with the selected command
                    settings.commandBuffer = command
                    cmdBuffer = command
                    historyUpdated = true
                end
            end
        else
            ImGui.Text("No Command History")
        end
        ImGui.Separator()
        if ImGui.Selectable('Clear Console##ClearConsole' .. channelID) then
            -- Clear the console output
            Module.Consoles[channelID].console:Clear()
            Module.Consoles[channelID].txtBuffer = {}
            Module.Consoles[channelID].CommandHistory = {}
            settings.commandBuffer = ""
            cmdBuffer = ""
            historyUpdated = true
        end
        ImGui.EndPopup()
    end

    if focusKeyboard then
        local textSizeX, _ = ImGui.CalcTextSize(cmdBuffer)
        ImGui.SetCursorPos(posX + textSizeX, posY)
        ImGui.SetKeyboardFocusHere(-1)
        focusKeyboard = false
    end

    -- Keyboard focus handling
    if Module.KeyFocus and ImGui.IsKeyPressed(ImGuiKey[Module.KeyName]) then
        ImGui.SetKeyboardFocusHere(-1)
    end
end

local function DrawChatWindow()
    -- Main menu bar
    if ImGui.BeginMenuBar() then
        local lockedIcon = Module.Settings.locked and Module.Icons.FA_LOCK .. '##lockTabButton_MyChat' or
            Module.Icons.FA_UNLOCK .. '##lockTablButton_MyChat'
        if ImGui.Button(lockedIcon) then
            --ImGuiWindowFlags.NoMove
            Module.Settings.locked = not Module.Settings.locked
            Module.tempSettings.locked = Module.Settings.locked
            ResetEvents()
        end
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text("Lock Window")
            ImGui.EndTooltip()
        end
        if ImGui.MenuItem(gIcon .. '##' .. windowNum) then
            Module.openConfigGUI = not Module.openConfigGUI
        end
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text("Open Main Config")
            ImGui.EndTooltip()
        end
        if ImGui.BeginMenu('Options##' .. windowNum) then
            local spamOn

            _, Module.console.autoScroll = ImGui.MenuItem('Auto-scroll##' .. windowNum, nil, Module.console.autoScroll)
            _, LocalEcho = ImGui.MenuItem('Local echo##' .. windowNum, nil, LocalEcho)
            _, timeStamps = ImGui.MenuItem('Time Stamps##' .. windowNum, nil, timeStamps)
            _, Module.KeyFocus = ImGui.MenuItem('Enter Focus##' .. windowNum, nil, Module.KeyFocus)
            _, Module.Settings.LogCommands = ImGui.MenuItem('Log Commands##' .. windowNum, nil, Module.Settings.LogCommands)
            if Module.KeyFocus ~= Module.Settings.keyFocus then
                Module.Settings.keyFocus = Module.KeyFocus
                writeSettings(Module.SettingsFile, Module.Settings)
            end
            if Module.KeyFocus then
                if ImGui.BeginMenu('Focus Key') then
                    if ImGui.BeginCombo('##FocusKey', Module.KeyName) then
                        for _, key in pairs(keyboardKeys) do
                            local isSelected = Module.KeyName == key
                            if ImGui.Selectable(key, isSelected) then
                                Module.KeyName = key
                                Module.Settings.keyName = key
                                writeSettings(Module.SettingsFile, Module.Settings)
                            end
                        end
                        ImGui.EndCombo()
                    end
                    ImGui.EndMenu()
                end
            end
            spamOn, enableSpam = ImGui.MenuItem('Enable Spam##' .. windowNum, nil, enableSpam)
            if ImGui.MenuItem('Re-Index Settings##' .. windowNum) then
                forceIndex = true
                ResetEvents()
            end
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()

                ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(1, 0, 0, 1))
                ImGui.Text("!!! WARNING !!!")
                ImGui.Text("This will re-Index the ID's in your settings file!!")
                ImGui.Text("Doing this outside of the initial loading of MyChat may CLEAR your chat windows!!")
                ImGui.Text("!!! YOU HAVE BEEN WARNED !!!")
                ImGui.PopStyleColor()
                ImGui.EndTooltip()
            end

            ImGui.Separator()
            if ImGui.MenuItem('Reset all Consoles##' .. windowNum) then
                resetConsoles = true
            end
            if ImGui.MenuItem('Clear Main Console##' .. windowNum) then
                Module.console:Clear()
            end
            if ImGui.MenuItem('Exit##' .. windowNum) then
                mq.RemoveTopLevelObject('MyChatTlo')
                Module.IsRunning = false
            end
            if spamOn then
                if not enableSpam then
                    Module.Consoles[9000].console = nil
                end
                ResetEvents()
            end
            ImGui.Spacing()

            ImGui.EndMenu()
        end
        if ImGui.BeginMenu('Channels##' .. windowNum) then
            for _, Data in ipairs(sortedChannels) do
                local channelID = Data[1]
                if Module.Settings.Channels[channelID] then
                    local enabled = Module.Settings.Channels[channelID].enabled
                    local name = Module.Settings.Channels[channelID].Name
                    if channelID ~= 9000 or enableSpam then
                        if ImGui.MenuItem(name, '', enabled) then
                            Module.Settings.Channels[channelID].enabled = not enabled
                            writeSettings(Module.SettingsFile, Module.Settings)
                        end
                    end
                end
            end
            ImGui.EndMenu()
        end

        if ImGui.BeginMenu('Links##' .. windowNum) then
            for _, Data in ipairs(sortedChannels) do
                local channelID = Data[1]
                if Module.Settings.Channels[channelID] then
                    local enableLinks = Module.Settings.Channels[channelID].enableLinks
                    local name = Module.Settings.Channels[channelID].Name
                    if channelID ~= 9000 then
                        if ImGui.MenuItem(name, '', enableLinks) then
                            Module.Settings.Channels[channelID].enableLinks = not enableLinks
                            writeSettings(Module.SettingsFile, Module.Settings)
                            ModifyEvent(channelID)
                        end
                    end
                end
            end
            ImGui.Separator()

            ImGui.EndMenu()
        end
        if ImGui.BeginMenu('PopOut##' .. windowNum) then
            for _, Data in ipairs(sortedChannels) do
                local channelID = Data[1]
                if Module.Settings.Channels[channelID] then
                    if channelID ~= 9000 or enableSpam then
                        local PopOut = Module.Settings.Channels[channelID].PopOut
                        local name = Module.Settings.Channels[channelID].Name
                        if ImGui.MenuItem(name, '', PopOut) then
                            PopOut = not PopOut
                            Module.Settings.Channels[channelID].PopOut = PopOut
                            Module.tempSettings.Channels[channelID].PopOut = PopOut
                            writeSettings(Module.SettingsFile, Module.Settings)
                        end
                    end
                end
            end

            ImGui.EndMenu()
        end

        if ImGui.BeginMenu('Presets##' .. windowNum) then
            ImGui.Text('Active: ' .. (Module.ActivePresetName or 'None'))
            ImGui.Separator()

            -- Load Preset submenu
            if ImGui.BeginMenu('Load Preset##' .. windowNum) then
                local presets = Module.GetPresetList()
                for _, preset in ipairs(presets) do
                    local isActive = preset.id == Module.ActivePresetID
                    local label = preset.name
                    if preset.server ~= Module.Server then
                        label = label .. ' [' .. preset.server .. ']'
                    end
                    if isActive then label = label .. ' (active)' end
                    if ImGui.MenuItem(label .. '##load_' .. preset.id, nil, isActive) then
                        if not isActive then
                            Module.SwitchPreset(preset.id)
                        end
                    end
                    if ImGui.IsItemHovered() then
                        ImGui.BeginTooltip()
                        ImGui.Text('Server: ' .. (preset.server or ''))
                        ImGui.Text('Created by: ' .. preset.created_by)
                        ImGui.Text('Created: ' .. preset.created_at)
                        ImGui.EndTooltip()
                    end
                end
                ImGui.EndMenu()
            end

            -- Save As New Preset
            if ImGui.MenuItem('Save As New Preset...##' .. windowNum) then
                showPresetSaveInput = true
                newPresetName = Module.ActivePresetName .. '_copy'
            end

            -- Rename Current Preset
            if ImGui.MenuItem('Rename Current Preset...##' .. windowNum) then
                showPresetRenameInput = true
                renamePresetName = Module.ActivePresetName
            end

            -- Copy from another preset
            if ImGui.BeginMenu('Copy Preset##' .. windowNum) then
                local presets = Module.GetPresetList()
                for _, preset in ipairs(presets) do
                    if preset.id ~= Module.ActivePresetID then
                        if ImGui.MenuItem(preset.name .. '##copy_' .. preset.id) then
                            local copyName = preset.name .. '_copy'
                            Module.CopyPreset(preset.id, copyName)
                            Module.GetPresetList()
                        end
                    end
                end
                ImGui.EndMenu()
            end

            ImGui.Separator()

            -- Delete Preset
            if ImGui.BeginMenu('Delete Preset##' .. windowNum) then
                local presets = Module.GetPresetList()
                for _, preset in ipairs(presets) do
                    if preset.id ~= Module.ActivePresetID then
                        if ImGui.MenuItem(preset.name .. '##del_' .. preset.id) then
                            Module.DeletePreset(preset.id)
                            Module.GetPresetList()
                        end
                    else
                        ImGui.MenuItem(preset.name .. ' (active)##del_' .. preset.id, nil, false, false)
                    end
                end
                ImGui.EndMenu()
            end

            ImGui.EndMenu()
        end

        -- Preset Save popup
        if showPresetSaveInput then
            ImGui.OpenPopup('Save New Preset##Popup')
        end
        if ImGui.BeginPopup('Save New Preset##Popup') then
            ImGui.Text('Enter preset name:')
            newPresetName = ImGui.InputText('##PresetNameInput', newPresetName, 256)
            if ImGui.Button('Save##PresetSave') then
                if newPresetName ~= '' then
                    Module.SaveAsNewPreset(newPresetName)
                end
                showPresetSaveInput = false
                ImGui.CloseCurrentPopup()
            end
            ImGui.SameLine()
            if ImGui.Button('Cancel##PresetSaveCancel') then
                showPresetSaveInput = false
                ImGui.CloseCurrentPopup()
            end
            ImGui.EndPopup()
        end

        -- Preset Rename popup
        if showPresetRenameInput then
            ImGui.OpenPopup('Rename Preset##Popup')
        end
        if ImGui.BeginPopup('Rename Preset##Popup') then
            ImGui.Text('Enter new name:')
            renamePresetName = ImGui.InputText('##PresetRenameInput', renamePresetName, 256)
            if ImGui.Button('Rename##PresetRename') then
                if renamePresetName ~= '' and Module.ActivePresetID then
                    Module.RenamePreset(Module.ActivePresetID, renamePresetName)
                end
                showPresetRenameInput = false
                ImGui.CloseCurrentPopup()
            end
            ImGui.SameLine()
            if ImGui.Button('Cancel##PresetRenameCancel') then
                showPresetRenameInput = false
                ImGui.CloseCurrentPopup()
            end
            ImGui.EndPopup()
        end

        ImGui.EndMenuBar()
    end

    -- Begin Tabs Bars

    if ImGui.BeginTabBar('Channels##', Module.tabFlags) then
        -- Begin Main tab
        if ImGui.BeginTabItem('Main##' .. windowNum) then
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.Text('Main')
                local sizeBuff = string.format("Buffer Size: %s lines.", tostring(getNextID(mainBuffer) - 1))
                ImGui.Text(sizeBuff)
                ImGui.EndTooltip()
            end
            activeTabID = 0
            local footerHeight = 35
            local contentSizeX, contentSizeY = ImGui.GetContentRegionAvail()
            contentSizeY = contentSizeY - footerHeight
            if ImGui.BeginPopupContextWindow() then
                if ImGui.Selectable('Clear##' .. windowNum) then
                    Module.console:Clear()
                    mainBuffer = {}
                end
                ImGui.EndPopup()
            end

            Module.console:Render(ImVec2(0, contentSizeY))
            --Command Line
            ImGui.Separator()
            local textFlags = bit32.bor(
                ImGuiInputTextFlags.EnterReturnsTrue,
                ImGuiInputTextFlags.CallbackCompletion,
                ImGuiInputTextFlags.CallbackHistory
            )

            local contentSizeX, _ = ImGui.GetContentRegionAvail()
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
            ImGui.SetCursorPosY(ImGui.GetCursorPosY() + 2)
            ImGui.PushItemWidth(contentSizeX)
            ImGui.PushStyleColor(ImGuiCol.FrameBg, ImVec4(0, 0, 0, 0))
            ImGui.PushFont(ImGui.ConsoleFont)
            local accept = false
            Module.commandBuffer, accept = ImGui.InputText('##Input##' .. windowNum, Module.commandBuffer, textFlags, inputTextCallback)
            ImGui.PopFont()
            ImGui.PopStyleColor()
            ImGui.PopItemWidth()
            if accept then
                if #Module.commandHistory == 0 or Module.commandHistory[#Module.commandHistory] ~= Module.commandBuffer then
                    table.insert(Module.commandHistory, Module.commandBuffer)

                    -- Limit history size
                    if #Module.commandHistory > MAX_HISTORY_COUNT then
                        table.remove(Module.commandHistory, 1)
                    end
                end
                Module.ExecCommand(Module.commandBuffer)
                Module.historyIndex = nil
                Module.commandBuffer = ''
                setFocus = true
            end
            ImGui.SetItemDefaultFocus()
            if Module.KeyFocus and ImGui.IsKeyPressed(ImGuiKey[Module.KeyName]) then --and not ImGui.IsItemFocused()
                setFocus = true
            end
            if setFocus then
                setFocus = false
                ImGui.SetKeyboardFocusHere(-1)
            end
            ImGui.EndTabItem()
        end
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text('Main')
            local sizeBuff = string.format("Buffer Size: %s lines.", tostring(getNextID(mainBuffer) - 1))
            ImGui.Text(sizeBuff)
            ImGui.EndTooltip()
        end
        -- End Main tab
        -- Begin other tabs
        for _, channelData in ipairs(sortedChannels) do
            local channelID = channelData[1] or 0
            if Module.Settings.Channels[channelID] and Module.Settings.Channels[channelID].enabled then
                local name = Module.Settings.Channels[channelID].Name:gsub("^%d+%s*", "") .. '##' .. windowNum
                local links = Module.Settings.Channels[channelID].enableLinks
                local enableMain = Module.Settings.Channels[channelID].MainEnable
                local PopOut = Module.Settings.Channels[channelID].PopOut
                local tNameP = PopOut and 'Disable PopOut' or 'Enable PopOut'
                local tNameM = enableMain and 'Disable Main' or 'Enable Main'
                local tNameL = links and 'Disable Links' or 'Enable Links'

                local function tabToolTip()
                    ImGui.BeginTooltip()
                    ImGui.Text(Module.Settings.Channels[channelID].Name)
                    local sizeBuff = string.format("Buffer Size: %s lines.", tostring(getNextID(Module.Consoles[channelID].txtBuffer) - 1))
                    ImGui.Text(sizeBuff)
                    ImGui.EndTooltip()
                end

                if not PopOut then
                    if ImGui.BeginTabItem(name) then
                        activeTabID = channelID

                        if ImGui.IsItemHovered() then
                            tabToolTip()
                        end
                        if ImGui.BeginPopupContextWindow() then
                            if ImGui.Selectable('Configure##' .. windowNum) then
                                editChanID = channelID
                                addChannel = false
                                fromConf = false
                                Module.tempSettings = Module.Settings
                                Module.openEditGUI = true
                                Module.openConfigGUI = false
                            end

                            ImGui.Separator()
                            if ImGui.Selectable(tNameP .. '##' .. windowNum) then
                                PopOut = not PopOut
                                Module.Settings.Channels[channelID].PopOut = PopOut
                                Module.tempSettings.Channels[channelID].PopOut = PopOut
                                writeSettings(Module.SettingsFile, Module.Settings)
                            end

                            if ImGui.Selectable(tNameM .. '##' .. windowNum) then
                                enableMain = not enableMain
                                Module.Settings.Channels[channelID].MainEnable = enableMain
                                Module.tempSettings.Channels[channelID].MainEnable = enableMain
                                writeSettings(Module.SettingsFile, Module.Settings)
                            end

                            if channelID ~= 9000 then
                                if ImGui.Selectable(tNameL .. '##' .. windowNum) then
                                    links = not links
                                    Module.Settings.Channels[channelID].enableLinks = links
                                    Module.tempSettings.Channels[channelID].enableLinks = links
                                    writeSettings(Module.SettingsFile, Module.Settings)
                                    ModifyEvent(channelID)
                                end
                            else
                                if ImGui.Selectable('Spam Off##' .. windowNum) then
                                    enableSpam = false
                                    Module.Consoles[9000].console = nil
                                    ResetEvents()
                                end
                            end

                            ImGui.Separator()
                            if ImGui.Selectable('Clear##' .. windowNum) then
                                Module.Consoles[channelID].console:Clear()
                                Module.Consoles[channelID].txtBuffer = {}
                            end

                            ImGui.Separator()
                            if ImGui.Selectable(Module.Icons.FA_ARROW_LEFT .. ' Move Left##' .. windowNum) then
                                Module.MoveTab(channelID, 'left')
                            end
                            if ImGui.Selectable(Module.Icons.FA_ARROW_RIGHT .. ' Move Right##' .. windowNum) then
                                Module.MoveTab(channelID, 'right')
                            end

                            ImGui.EndPopup()
                        end

                        DrawConsole(channelID)

                        ImGui.EndTabItem()
                    end
                end
            end
        end
        ImGui.EndTabBar()
    end
end

function Module.RenderGUI()
    if not Module.IsRunning then return end

    ImGui.PushFont(nil, ImGui.GetFontSize() * Module.Settings.Scale)

    local windowName = 'My Chat - Main##' .. Module.CharLoaded .. '_' .. windowNum
    ImGui.SetWindowPos(windowName, ImVec2(20, 20), ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(ImVec2(640, 480), ImGuiCond.FirstUseEver)

    local themeName = Module.tempSettings.LoadTheme
    local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(themeName, Module.Theme)

    local winFlags = Module.winFlags
    if Module.Settings.locked then
        winFlags = bit32.bor(ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoScrollbar)
    end
    local openMain
    openMain, Module.SHOW = ImGui.Begin(windowName, openMain, winFlags)

    if not Module.SHOW then
        Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
        ImGui.End()
    else
        DrawChatWindow()

        Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
        ImGui.End()
    end

    for channelID, data in pairs(Module.Settings.Channels) do
        if data and data.enabled then
            local name = Module.Settings.Channels[channelID].Name .. '##' .. windowNum
            local PopOut = Module.Settings.Channels[channelID].PopOut
            local ShowPop = Module.Settings.Channels[channelID].PopOut
            if Module.Settings.Channels[channelID].locked then
                Module.PopOutFlags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoMove)
            else
                Module.PopOutFlags = bit32.bor(ImGuiWindowFlags.NoScrollbar)
            end
            if PopOut then
                ImGui.SetNextWindowSize(ImVec2(640, 480), ImGuiCond.FirstUseEver)

                local themeName = Module.tempSettings.LoadTheme
                local PopoutColorCount, PopoutStyleCount = Module.ThemeLoader.StartTheme(themeName, Module.Theme)
                local show
                PopOut, show = ImGui.Begin(name .. "##" .. channelID .. name, PopOut, Module.PopOutFlags)
                if show then
                    local lockedIcon = Module.Settings.Channels[channelID].locked and Module.Icons.FA_LOCK .. '##lockTabButton' .. channelID or
                        Module.Icons.FA_UNLOCK .. '##lockTablButton' .. channelID
                    if ImGui.Button(lockedIcon) then
                        --ImGuiWindowFlags.NoMove
                        Module.Settings.Channels[channelID].locked = not Module.Settings.Channels[channelID].locked
                        Module.tempSettings.Channels[channelID].locked = Module.Settings.Channels[channelID].locked
                        ResetEvents()
                    end
                    if ImGui.IsItemHovered() then
                        ImGui.BeginTooltip()
                        ImGui.Text("Lock Window")
                        ImGui.EndTooltip()
                    end


                    if PopOut ~= Module.Settings.Channels[channelID].PopOut then
                        Module.Settings.Channels[channelID].PopOut = PopOut
                        Module.tempSettings.Channels[channelID].PopOut = PopOut
                        ResetEvents()
                    end
                    ImGui.SameLine()
                    if ImGui.Button(Module.Icons.MD_SETTINGS .. "##" .. channelID) then
                        editChanID = channelID
                        addChannel = false
                        fromConf = false
                        Module.tempSettings = Module.Settings
                        Module.openEditGUI = not Module.openEditGUI
                        Module.openConfigGUI = false
                    end
                    if ImGui.IsItemHovered() then
                        ImGui.BeginTooltip()
                        ImGui.Text("Opens the Edit window for this channel")
                        ImGui.EndTooltip()
                    end

                    DrawConsole(channelID)
                else
                    if not ShowPop then
                        Module.Settings.Channels[channelID].PopOut = ShowPop
                        Module.tempSettings.Channels[channelID].PopOut = ShowPop
                        ResetEvents()
                        Module.ThemeLoader.EndTheme(PopoutColorCount, PopoutStyleCount)
                        ImGui.End()
                    end
                end

                Module.ThemeLoader.EndTheme(PopoutColorCount, PopoutStyleCount)

                ImGui.End()
            end
        end
    end
    if Module.openEditGUI then Module.Edit_GUI() end
    if Module.openConfigGUI then Module.Config_GUI() end

    -- Process deferred deletes after all GUI drawing is complete
    if pendingDeleteChannel then
        local chanID = pendingDeleteChannel
        pendingDeleteChannel = nil
        Module.BackupSettings()
        Module.tempSettings.Channels[chanID] = nil
        Module.tempEventStrings[chanID] = nil
        Module.tempChanColors[chanID] = nil
        Module.tempFiltColors[chanID] = nil
        Module.tempFilterStrings[chanID] = nil
        Module.tempFilterEnabled[chanID] = nil
        Module.tempFilterHidden[chanID] = nil
        Module.Settings = Module.tempSettings
        ResetEvents()
        resetEvnts = true
        Module.openEditGUI = false
        Module.openConfigGUI = false
    end

    if pendingDeleteEvent then
        local chanID, evtID = pendingDeleteEvent[1], pendingDeleteEvent[2]
        pendingDeleteEvent = nil
        if Module.tempSettings.Channels[chanID] and Module.tempSettings.Channels[chanID].Events then
            Module.tempSettings.Channels[chanID].Events[evtID] = nil
        end
        if Module.tempEventStrings[chanID] then Module.tempEventStrings[chanID][evtID] = nil end
        if Module.tempChanColors[chanID] then Module.tempChanColors[chanID][evtID] = nil end
        if Module.tempFiltColors[chanID] then Module.tempFiltColors[chanID][evtID] = nil end
        if Module.tempFilterStrings[chanID] then Module.tempFilterStrings[chanID][evtID] = nil end
        Module.hString[evtID] = nil
        Module.Settings = Module.tempSettings
        ResetEvents()
    end

    if pendingDeleteFilter then
        local chanID, evtID, fltID = pendingDeleteFilter[1], pendingDeleteFilter[2], pendingDeleteFilter[3]
        pendingDeleteFilter = nil
        if Module.tempSettings.Channels[chanID] and Module.tempSettings.Channels[chanID].Events[evtID]
            and Module.tempSettings.Channels[chanID].Events[evtID].Filters then
            Module.tempSettings.Channels[chanID].Events[evtID].Filters[fltID] = nil
        end
        if Module.tempFilterStrings[chanID] and Module.tempFilterStrings[chanID][evtID] then
            Module.tempFilterStrings[chanID][evtID][fltID] = nil
        end
        if Module.tempFiltColors[chanID] and Module.tempFiltColors[chanID][evtID] then
            Module.tempFiltColors[chanID][evtID][fltID] = nil
        end
        if Module.tempChanColors[chanID] and Module.tempChanColors[chanID][evtID] then
            Module.tempChanColors[chanID][evtID][fltID] = nil
        end
        Module.Settings = Module.tempSettings
        ResetEvents()
    end

    if not openMain then
        Module.IsRunning = false
    end

    ImGui.PopFont()
end

-------------------------------- Configure Windows and Events GUI ---------------------------
local resetEvnts = false

---Draws the Channel data for editing. Can be either an exisiting Channel or a New one.
---@param editChanID integer -- the channelID we are working with
---@param isNewChannel boolean -- is this a new channel or are we editing an old one.
function Module.AddChannel(editChanID, isNewChannel)
    local tmpName = 'NewChan'
    local tmpString = 'NewString'
    local tmpEcho = '/say'
    local channelData = {}

    if not Module.tempEventStrings[editChanID] then Module.tempEventStrings[editChanID] = {} end
    if not Module.tempChanColors then Module.tempChanColors = {} end
    if not Module.tempFiltColors[editChanID] then Module.tempFiltColors[editChanID] = {} end
    if not Module.tempFilterEnabled[editChanID] then Module.tempFilterEnabled[editChanID] = {} end
    if not Module.tempChanColors[editChanID] then Module.tempChanColors[editChanID] = {} end
    if not Module.tempFilterStrings[editChanID] then Module.tempFilterStrings[editChanID] = {} end
    if not Module.tempEventStrings[editChanID][editEventID] then Module.tempEventStrings[editChanID][editEventID] = {} end
    if not Module.tempFilterHidden[editChanID] then Module.tempFilterHidden[editChanID] = {} end

    if not isNewChannel then
        if Module.tempSettings.Channels[editChanID] ~= nil then
            for eID, eData in pairs(Module.tempSettings.Channels[editChanID].Events) do
                if eData and eData.Filters then
                    if not Module.tempFiltColors[editChanID][eID] then Module.tempFiltColors[editChanID][eID] = {} end
                    if not Module.tempFilterEnabled[editChanID][eID] then Module.tempFilterEnabled[editChanID][eID] = {} end
                    if not Module.tempFilterHidden[editChanID][eID] then Module.tempFilterHidden[editChanID][eID] = {} end
                    for fID, fData in pairs(eData.Filters) do
                        if fData then
                            if not Module.tempFiltColors[editChanID][eID][fID] then Module.tempFiltColors[editChanID][eID][fID] = {} end
                            Module.tempFiltColors[editChanID][eID][fID] = fData.color or { 1, 1, 1, 1, }
                            if Module.Settings.Channels[editChanID] and Module.Settings.Channels[editChanID].Events[eID]
                                and Module.Settings.Channels[editChanID].Events[eID].Filters[fID] then
                                Module.tempFilterEnabled[editChanID][eID][fID] = Module.Settings.Channels[editChanID].Events[eID].Filters[fID].enabled
                                Module.tempFilterHidden[editChanID][eID][fID] = Module.Settings.Channels[editChanID].Events[eID].Filters[fID].hidden
                            end
                        end
                    end
                end
            end
        end
    end

    if Module.tempSettings.Channels[editChanID] ~= nil then
        channelData = Module.tempSettings.Channels
    else
        -- Find max tab order for placement at end
        local maxTabOrder = 0
        for _, v in pairs(Module.Settings.Channels) do
            if v and v.TabOrder and v.TabOrder < 9000 and v.TabOrder > maxTabOrder then
                maxTabOrder = v.TabOrder
            end
        end
        channelData = {
            [editChanID] = {
                ['enabled'] = false,
                ['Name'] = 'new',
                ['FontSize'] = 16,
                ['Echo'] = '/say',
                ['MainEnable'] = true,
                ['PopOut'] = false,
                ['EnableLinks'] = false,
                ['TabOrder'] = maxTabOrder + 1,
                ['Events'] = {
                    [1] = {
                        ['enabled'] = true,
                        ['eventString'] = 'new',
                        ['Filters'] = {
                            [0] = {
                                ['filterString'] = '',
                                ['color'] = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, },
                                ['enabled'] = true,
                                ['hidden'] = false,
                            },
                        },
                    },
                },
            },
        }
        Module.tempSettings.Channels[editChanID] = channelData[editChanID]
    end

    if newEvent then
        local maxEventId = getNextID(channelData[editChanID].Events)
        channelData[editChanID]['Events'][maxEventId] = {
            ['enabled'] = true,
            ['eventString'] = 'new',
            ['Filters'] = {
                [0] = {
                    ['filterString'] = '',
                    ['color'] = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, },
                    ['enabled'] = true,
                    ['hidden'] = false,
                },
            },
        }
        newEvent = false
    end
    ---------------- Buttons Sliders and Channel Name ------------------------

    if not isNewChannel then
        if not Module.tempEventStrings[editChanID].Name then
            Module.tempEventStrings[editChanID].Name = channelData[editChanID].Name
        end
        if not Module.tempSettings.Channels[editChanID].Echo then
            Module.tempSettings.Channels[editChanID].Echo = '/say'
        end
        tmpEcho = Module.tempSettings.Channels[editChanID].Echo or '/say'
        tmpName = Module.tempEventStrings[editChanID].Name
        tmpName, _ = ImGui.InputText("Channel Name##ChanName" .. editChanID, tmpName, 256)
        tmpEcho, _ = ImGui.InputText("Echo Channel##Echo_ChanName" .. editChanID, tmpEcho, 256)
        if Module.tempSettings.Channels[editChanID].Echo ~= tmpEcho then
            Module.tempSettings.Channels[editChanID].Echo = tmpEcho
        end
        if Module.tempEventStrings[editChanID].Name ~= tmpName then
            Module.tempEventStrings[editChanID].Name = tmpName
        end
        lastChan = lastChan + 1
    else
        ImGui.Text('')
    end
    if ImGui.Button('Add New Event') then
        newEvent = true
    end
    ImGui.SameLine()
    if ImGui.Button('Save Settings') then
        Module.BackupSettings()
        Module.tempSettings.Channels[editChanID] = Module.tempSettings.Channels[editChanID] or { Events = {}, Name = "New Channel", enabled = true, }
        Module.tempSettings.Channels[editChanID].Name = Module.tempEventStrings[editChanID].Name or "New Channel"
        Module.tempSettings.Channels[editChanID].enabled = true
        Module.tempSettings.Channels[editChanID].MainEnable = Module.tempSettings.Channels[editChanID].MainEnable

        local channelEvents = Module.tempSettings.Channels[editChanID].Events
        for eventId, eventData in pairs(Module.tempEventStrings[editChanID]) do
            -- Skip 'Name' key used for the channel name
            if eventId ~= 'Name' then
                if eventData and eventData.eventString then
                    local tempEString = eventData.eventString or 'New'
                    if tempEString == '' then tempEString = 'New' end
                    channelEvents[eventId] = channelEvents[eventId] or { color = { 1.0, 1.0, 1.0, 1.0, }, Filters = {}, }
                    channelEvents[eventId].eventString = tempEString
                    channelEvents[eventId].color = Module.tempChanColors[editChanID][eventId] or channelEvents[eventId].color
                    channelEvents[eventId].Filters = {}
                    for filterID, filterData in pairs(Module.tempFilterStrings[editChanID][eventId] or {}) do
                        local tempFString = filterData or 'New'
                        if tempFString == '' or tempFString == nil then tempFString = 'New' end
                        channelEvents[eventId].Filters[filterID] = {
                            filterString = tempFString,
                            color = (Module.tempFiltColors[editChanID][eventId] and Module.tempFiltColors[editChanID][eventId][filterID]) or { 1.0, 1.0, 1.0, 1.0, },
                            enabled = Module.tempFilterEnabled[editChanID][eventId] and Module.tempFilterEnabled[editChanID][eventId][filterID],
                            hidden = Module.tempFilterHidden[editChanID][eventId] and Module.tempFilterHidden[editChanID][eventId][filterID],
                        }
                    end
                end
            end
        end
        Module.tempSettings.Channels[editChanID].Events = channelEvents
        Module.Settings = Module.tempSettings
        ResetEvents()
        resetEvnts = true
        Module.openEditGUI = false
        Module.tempFilterStrings, Module.tempEventStrings, Module.tempChanColors, Module.tempFilterHidden,
        Module.tempFilterEnabled, Module.tempFiltColors, Module.hString, channelData = {}, {}, {}, {}, {}, {}, {}, {}
        if fromConf then Module.openConfigGUI = true end
    end
    ImGui.SameLine()
    if ImGui.Button("DELETE Channel##" .. editChanID) then
        -- Defer delete to after draw loop completes
        pendingDeleteChannel = editChanID
    end
    ImGui.SameLine()
    if ImGui.Button(' Close ##_close') then
        Module.openEditGUI = false
        if fromConf then Module.openConfigGUI = true end
    end
    ImGui.SameLine()
    if Module.tempSettings.Channels[editChanID] then
        Module.tempSettings.Channels[editChanID].MainEnable = Module.Utils.DrawToggle('Show on Main Tab##Main', Module.tempSettings.Channels[editChanID].MainEnable)
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text('Do you want this channel to display on the Main Tab?')
            ImGui.EndTooltip()
        end
    end

    ----------------------------- Events and Filters ----------------------------
    ImGui.SeparatorText('Events and Filters')
    if ImGui.BeginChild("Details##") then
        ------------------------------ table -------------------------------------
        if channelData[editChanID] ~= nil and channelData[editChanID].Events ~= nil then
            -- Build sorted event list to avoid ipairs nil-gap issues
            local eventIDs = {}
            for eID, _ in pairs(channelData[editChanID].Events) do
                table.insert(eventIDs, eID)
            end
            table.sort(eventIDs)

            for _, eventID in ipairs(eventIDs) do
                local eventDetails = channelData[editChanID].Events[eventID]
                if eventDetails and eventDetails.eventString then
                    if Module.hString[eventID] == nil then Module.hString[eventID] = string.format(channelData[editChanID].Name .. ' : ' .. eventDetails.eventString) end
                    if ImGui.CollapsingHeader(Module.hString[eventID]) then
                        local contentSizeX = ImGui.GetWindowContentRegionWidth()

                        if ImGui.BeginChild('Events##' .. eventID, contentSizeX, 0.0, bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.AutoResizeY)) then
                            if ImGui.BeginTable("Channel Events##" .. editChanID, 4, bit32.bor(ImGuiTableFlags.NoHostExtendX)) then
                                ImGui.TableSetupColumn("ID's##_", ImGuiTableColumnFlags.WidthAlwaysAutoResize, 100)
                                ImGui.TableSetupColumn("Strings", ImGuiTableColumnFlags.WidthStretch, 150)
                                ImGui.TableSetupColumn("Color", ImGuiTableColumnFlags.WidthFixed, 50)
                                ImGui.TableSetupColumn("##Delete", ImGuiTableColumnFlags.WidthAlwaysAutoResize, 50)
                                ImGui.TableHeadersRow()
                                ImGui.TableNextRow()
                                ImGui.TableSetColumnIndex(0)

                                if ImGui.Button('Add Filter') then
                                    if not channelData[editChanID].Events[eventID].Filters then
                                        channelData[editChanID].Events[eventID].Filters = {}
                                    end
                                    local maxFilterId = getNextID(channelData[editChanID].Events[eventID]['Filters'])
                                    channelData[editChanID]['Events'][eventID].Filters[maxFilterId] = {
                                        ['filterString'] = 'new',
                                        ['color'] = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, },
                                        ['enabled'] = true,
                                        ['hidden'] = false,
                                    }
                                end
                                if ImGui.IsItemHovered() then
                                    ImGui.BeginTooltip()
                                    ImGui.Text('You can add TOKENs to your filters in place for character names.\n')
                                    ImGui.Text('LIST OF TOKENS')
                                    ImGui.Text('M3\t = Your Name')
                                    ImGui.Text('M1\t = Main Assist Name')
                                    ImGui.Text('PT1\t = Your Pet Name')
                                    ImGui.Text('PT3\t = Any Members Pet Name')
                                    ImGui.Text('GP1\t = Party Members Name')
                                    ImGui.Text('TK1\t = Main Tank Name')
                                    ImGui.Text('RL\t = Raid Leader Name')
                                    ImGui.Text('H1\t = Group Healer (DRU, CLR, or SHM)')
                                    ImGui.Text('G1 - G5\t = Party Members Name in Group Slot 1-5')
                                    ImGui.Text('N3\t = NPC Name')
                                    ImGui.Text('P3\t = PC Name')
                                    ImGui.Text('NO2\t = Ignore the If matched\n Place this in front of a token or word and it if matched it will ignore the line.')
                                    ImGui.EndTooltip()
                                end

                                ImGui.TableSetColumnIndex(1)

                                if not Module.tempEventStrings[editChanID][eventID] then Module.tempEventStrings[editChanID][eventID] = eventDetails end
                                tmpString = Module.tempEventStrings[editChanID][eventID].eventString
                                local bufferKey = editChanID .. "_" .. tostring(eventID)
                                tmpString = ImGui.InputText("Event String##EventString" .. bufferKey, tmpString, 256)
                                if Module.tempEventStrings[editChanID][eventID].eventString ~= tmpString then Module.tempEventStrings[editChanID][eventID].eventString = tmpString end

                                ImGui.TableSetColumnIndex(2)

                                if not Module.tempChanColors[editChanID][eventID] then
                                    local defColor = (eventDetails.Filters and eventDetails.Filters[0] and eventDetails.Filters[0].color) or { 1.0, 1.0, 1.0, 1.0, }
                                    Module.tempChanColors[editChanID][eventID] = defColor
                                end

                                Module.tempChanColors[editChanID][eventID] = ImGui.ColorEdit4("##Color" .. bufferKey, Module.tempChanColors[editChanID][eventID], MyColorFlags)
                                ImGui.TableSetColumnIndex(3)
                                if ImGui.Button("Delete##" .. bufferKey) then
                                    -- Defer event delete to after draw loop
                                    pendingDeleteEvent = { editChanID, eventID }
                                end
                                ImGui.TableNextRow()
                                ImGui.TableSetColumnIndex(0)
                                ImGui.SeparatorText('')
                                ImGui.TableSetColumnIndex(1)
                                ImGui.SeparatorText('Filters')
                                ImGui.TableSetColumnIndex(2)
                                ImGui.SeparatorText('')
                                ImGui.TableSetColumnIndex(3)
                                ImGui.SeparatorText('')
                                --------------- Filters ----------------------
                                -- Build sorted filter list to avoid ipairs nil-gap issues
                                local filterIDs = {}
                                if eventDetails.Filters then
                                    for fID, _ in pairs(eventDetails.Filters) do
                                        if fID > 0 then table.insert(filterIDs, fID) end
                                    end
                                    table.sort(filterIDs)
                                end

                                for _, filterID in ipairs(filterIDs) do
                                    local filterData = eventDetails.Filters[filterID]
                                    if filterData then
                                        ImGui.TableNextRow()
                                        ImGui.TableSetColumnIndex(0)
                                        ImGui.Text("fID: %s", tostring(filterID))
                                        ImGui.TableSetColumnIndex(1)
                                        if not Module.tempFilterStrings[editChanID][eventID] then
                                            Module.tempFilterStrings[editChanID][eventID] = {}
                                        end
                                        if not Module.tempFilterStrings[editChanID][eventID][filterID] then
                                            Module.tempFilterStrings[editChanID][eventID][filterID] = filterData.filterString
                                        end
                                        local tempFilter = Module.tempFilterStrings[editChanID][eventID][filterID]
                                        local tmpKey = string.format("%s_%s", eventID, filterID)
                                        tempFilter, _ = ImGui.InputText("Filter String##_" .. tmpKey, tempFilter)
                                        if Module.tempFilterStrings[editChanID][eventID][filterID] ~= tempFilter then
                                            Module.tempFilterStrings[editChanID][eventID][filterID] = tempFilter
                                        end
                                        ImGui.SameLine()
                                        if Module.tempFilterEnabled[editChanID][eventID] == nil then Module.tempFilterEnabled[editChanID][eventID] = {} end
                                        local tmpEnabl = filterData.enabled
                                        tmpEnabl, _ = Module.Utils.DrawToggle("Enabled##_" .. tmpKey, tmpEnabl)
                                        if filterData.enabled ~= tmpEnabl then
                                            Module.tempFilterEnabled[editChanID][eventID][filterID] = tmpEnabl
                                            filterData.enabled = tmpEnabl
                                            if Module.tempSettings.Channels[editChanID] and Module.tempSettings.Channels[editChanID].Events[eventID]
                                                and Module.tempSettings.Channels[editChanID].Events[eventID].Filters[filterID] then
                                                Module.tempSettings.Channels[editChanID].Events[eventID].Filters[filterID].enabled = tmpEnabl
                                            end
                                            Module.Settings = Module.tempSettings
                                            Module.WriteSettingsToDB()
                                        end
                                        ImGui.SameLine()
                                        if Module.tempFilterHidden[editChanID][eventID] == nil then Module.tempFilterHidden[editChanID][eventID] = {} end
                                        local tmpHidden = filterData.hidden or false
                                        local hiddenLabel = tmpHidden and Module.Icons.FA_EYE_SLASH or Module.Icons.FA_EYE
                                        hiddenLabel = hiddenLabel .. "##_" .. tmpKey
                                        tmpHidden, _ = Module.Utils.DrawToggle(hiddenLabel, tmpHidden)
                                        if (filterData.hidden or false) ~= tmpHidden then
                                            Module.tempFilterHidden[editChanID][eventID][filterID] = tmpHidden
                                            filterData.hidden = tmpHidden
                                            if Module.tempSettings.Channels[editChanID] and Module.tempSettings.Channels[editChanID].Events[eventID]
                                                and Module.tempSettings.Channels[editChanID].Events[eventID].Filters[filterID] then
                                                Module.tempSettings.Channels[editChanID].Events[eventID].Filters[filterID].hidden = tmpHidden
                                            end
                                            Module.Settings = Module.tempSettings
                                            Module.WriteSettingsToDB()
                                        end

                                        ImGui.TableSetColumnIndex(2)
                                        if not Module.tempFiltColors[editChanID][eventID] then Module.tempFiltColors[editChanID][eventID] = {} end
                                        if not Module.tempFiltColors[editChanID][eventID][filterID] then
                                            Module.tempFiltColors[editChanID][eventID][filterID] = filterData.color or { 1, 1, 1, 1, }
                                        end
                                        local tmpColor = filterData.color or { 1, 1, 1, 1, }
                                        filterData.color = ImGui.ColorEdit4("##Color_" .. filterID, tmpColor, MyColorFlags)
                                        if Module.tempFiltColors[editChanID][eventID][filterID] ~= tmpColor then Module.tempFiltColors[editChanID][eventID][filterID] = tmpColor end
                                        ImGui.TableSetColumnIndex(3)
                                        if ImGui.Button("Delete##_" .. filterID) then
                                            -- Defer filter delete to after draw loop
                                            pendingDeleteFilter = { editChanID, eventID, filterID }
                                        end
                                    end
                                end
                                ImGui.EndTable()
                            end
                        end
                        ImGui.EndChild()
                    else
                        Module.hString[eventID] = string.format(channelData[editChanID].Name .. ' : ' .. eventDetails.eventString)
                    end
                    lastChan = 0
                end
            end
        end
    end
    ImGui.EndChild()
end

local function buildConfig()
    -- Build a stable sorted list of channel IDs by name
    local configChannelIDs = {}
    for cID, cData in pairs(Module.tempSettings.Channels) do
        if cData then
            table.insert(configChannelIDs, { id = cID, name = cData.Name or '' })
        end
    end
    table.sort(configChannelIDs, function(a, b) return a.name < b.name end)

    if ImGui.BeginChild("Channels##") then
        for _, entry in ipairs(configChannelIDs) do
            local channelID = entry.id
            local channelData = Module.tempSettings.Channels[channelID]
            if channelData then
                if ImGui.CollapsingHeader(channelData.Name) then
                    local contentSizeX = ImGui.GetWindowContentRegionWidth()

                    if ImGui.BeginChild('Channels##' .. channelID, contentSizeX, 0.0, bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.AutoResizeY, ImGuiChildFlags.AlwaysAutoResize)) then
                        -- Begin a table for events within this channel

                        if ImGui.BeginTable("ChannelEvents_" .. channelData.Name, 4, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.RowBg, ImGuiTableFlags.Borders)) then
                            -- Set up table columns once
                            ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed, 50)
                            ImGui.TableSetupColumn("Channel", ImGuiTableColumnFlags.WidthAlwaysAutoResize, 100)
                            ImGui.TableSetupColumn("EventString", ImGuiTableColumnFlags.WidthStretch, 150)
                            ImGui.TableSetupColumn("Color", ImGuiTableColumnFlags.WidthAlwaysAutoResize)
                            -- Iterate through each event in the channel
                            local once = true
                            for eventId, eventDetails in pairs(channelData.Events) do
                                if eventDetails and eventDetails.eventString then
                                    local bufferKey = channelID .. "_" .. tostring(eventId)
                                    ImGui.TableNextRow()
                                    ImGui.TableSetColumnIndex(0)
                                    if once then
                                        if ImGui.Button("Edit Channel##" .. bufferKey) then
                                            editChanID = channelID
                                            addChannel = false
                                            Module.tempSettings = Module.Settings
                                            Module.openEditGUI = true
                                            Module.openConfigGUI = false
                                        end
                                        once = false
                                    else
                                        ImGui.Dummy(1, 1)
                                    end
                                    ImGui.TableSetColumnIndex(1)
                                    if Module.tempSettings.Channels[channelID] and Module.tempSettings.Channels[channelID].Events[eventId] then
                                        Module.tempSettings.Channels[channelID].Events[eventId].enabled = Module.Utils.DrawToggle('Enabled##' .. eventId,
                                            Module.tempSettings.Channels[channelID].Events[eventId].enabled)
                                    end
                                    ImGui.TableSetColumnIndex(2)
                                    ImGui.Text(eventDetails.eventString)
                                    ImGui.TableSetColumnIndex(3)
                                    local filterColor = { 1.0, 1.0, 1.0, 1.0, }
                                    if eventDetails.Filters and eventDetails.Filters[0] then
                                        if not eventDetails.Filters[0].color then
                                            eventDetails.Filters[0].color = filterColor
                                        end
                                        filterColor = eventDetails.Filters[0].color
                                    end
                                    ImGui.ColorEdit4("##Color" .. bufferKey, filterColor,
                                        bit32.bor(ImGuiColorEditFlags.NoOptions, ImGuiColorEditFlags.NoPicker, ImGuiColorEditFlags.NoInputs, ImGuiColorEditFlags.NoTooltip,
                                            ImGuiColorEditFlags.NoLabel))
                                end
                            end
                            -- End the table for this channel
                            ImGui.EndTable()
                        end
                    end
                    ImGui.EndChild()
                end
            end
        end
    end
    ImGui.EndChild()
end

function Module.Config_GUI(open)
    local themeName = Module.tempSettings.LoadTheme or 'Default'
    -- Push Theme Colors
    local ColorCountConf, StyleCountConf = Module.ThemeLoader.StartTheme(themeName, Module.Theme)
    local show = false
    open, show = ImGui.Begin("Event Configuration", open, bit32.bor(ImGuiWindowFlags.None))
    if not open then Module.openConfigGUI = false end
    if show then
        -- Add a button to add a new row
        if ImGui.Button("Add Channel") then
            editChanID = getNextID(Module.Settings.Channels)
            addChannel = true
            fromConf = true
            Module.tempSettings = Module.Settings
            Module.openEditGUI = true
            Module.openConfigGUI = false
        end

        ImGui.SameLine()
        if ImGui.Button("Reload Theme File") then
            loadSettings()
        end
        ImGui.SameLine()
        if loadedExeternally then
            if ImGui.Button('Edit ThemeZ') then
                if MyUI.Modules.ThemeZ ~= nil then
                    if MyUI.Modules.ThemeZ.IsRunning then
                        MyUI.Modules.ThemeZ.ShowGui = true
                    else
                        MyUI.TempSettings.ModuleChanged = true
                        MyUI.TempSettings.ModuleName = 'ThemeZ'
                        MyUI.TempSettings.ModuleEnabled = true
                    end
                else
                    MyUI.TempSettings.ModuleChanged = true
                    MyUI.TempSettings.ModuleName = 'ThemeZ'
                    MyUI.TempSettings.ModuleEnabled = true
                end
            end
        end
        ImGui.SameLine()

        if ImGui.Button('Close') then
            Module.openConfigGUI = false
            editChanID = 0
            editEventID = 0
            Module.Settings = Module.tempSettings
            ResetEvents()
        end

        ImGui.SeparatorText('Import Settings')
        importFile = ImGui.InputTextWithHint('Import##FileName', importFile, importFile, 256)
        ImGui.SameLine()
        cleanImport = Module.Utils.DrawToggle('Clean Import##clean', cleanImport)

        if ImGui.Button('Import Channels') then
            local tmp = mq.configDir .. '/MyUI/MyChat/' .. importFile
            if not Module.Utils.File.Exists(tmp) then
                mq.cmd("/msgbox 'No File Found!")
            else
                Module.BackupSettings()
                local newSettings = dofile(tmp)
                local newID = getNextID(Module.tempSettings.Channels)

                if not cleanImport and lastImport ~= tmp then
                    for cID, cData in pairs(newSettings.Channels) do
                        for existingCID, existingCData in pairs(Module.tempSettings.Channels) do
                            if existingCData.Name == cData.Name then
                                cData.Name = cData.Name .. '_NEW'
                            end
                        end
                        Module.tempSettings.Channels[newID] = cData
                        newID = newID + 1
                    end
                else
                    Module.tempSettings = {}
                    Module.tempSettings = newSettings
                end
                lastImport = tmp
                ResetEvents()
            end
        end
        ImGui.SameLine()
        if ImGui.Button('Import as New Preset') then
            local tmp = mq.configDir .. '/MyUI/MyChat/' .. importFile
            if not Module.Utils.File.Exists(tmp) then
                mq.cmd("/msgbox 'No File Found!")
            else
                local importedSettings = dofile(tmp)
                if importedSettings and importedSettings.Channels then
                    local presetName = importFile:gsub('%.lua$', ''):gsub('[/\\]', '_')
                    Module.MigratePickleToDB(importedSettings, presetName)
                    Module.GetPresetList()
                end
            end
        end

        if ImGui.CollapsingHeader("Preset Management##Header") then
            ImGui.SeparatorText('Active Preset')
            ImGui.Text('Current: %s', Module.ActivePresetName or 'None')
            if Module.ActivePresetID then
                ImGui.SameLine()
                ImGui.Text('(ID: %d)', Module.ActivePresetID)
            end

            ImGui.SeparatorText('Load Preset')
            local presets = Module.GetPresetList()
            if #presets > 0 then
                if ImGui.BeginCombo('##PresetCombo', Module.ActivePresetName or 'Select...') then
                    for _, preset in ipairs(presets) do
                        local isActive = preset.id == Module.ActivePresetID
                        local label = preset.name
                        if preset.server ~= Module.Server then
                            label = label .. ' [' .. preset.server .. ']'
                        end
                        if isActive then label = label .. ' (active)' end
                        if ImGui.Selectable(label .. '##conf_' .. preset.id, isActive) then
                            if not isActive then
                                Module.SwitchPreset(preset.id)
                                Module.tempSettings = Module.Settings
                            end
                        end
                        if ImGui.IsItemHovered() then
                            ImGui.BeginTooltip()
                            ImGui.Text('Created by: ' .. preset.created_by)
                            ImGui.Text('Created: ' .. preset.created_at)
                            ImGui.EndTooltip()
                        end
                    end
                    ImGui.EndCombo()
                end
            else
                ImGui.Text('No presets found.')
            end

            ImGui.SeparatorText('Save / Copy / Delete')
            -- Save As New Preset
            newPresetName = ImGui.InputText('New Preset Name##ConfPresetName', newPresetName, 256)
            if ImGui.Button('Save As New Preset##Conf') then
                if newPresetName ~= '' then
                    local newID = Module.SaveAsNewPreset(newPresetName)
                    if newID then
                        newPresetName = ''
                    end
                end
            end
            ImGui.SameLine()
            -- Rename
            if ImGui.Button('Rename Current##Conf') then
                if newPresetName ~= '' and Module.ActivePresetID then
                    Module.RenamePreset(Module.ActivePresetID, newPresetName)
                    newPresetName = ''
                end
            end

            -- Copy / Delete other presets
            if #presets > 1 then
                ImGui.Spacing()
                for _, preset in ipairs(presets) do
                    if preset.id ~= Module.ActivePresetID then
                        local displayName = preset.name
                        if preset.server ~= Module.Server then
                            displayName = displayName .. ' [' .. preset.server .. ']'
                        end
                        ImGui.Text(displayName)
                        ImGui.SameLine()
                        if ImGui.Button('Copy##conf_copy_' .. preset.id) then
                            Module.CopyPreset(preset.id, preset.name .. '_copy')
                            Module.GetPresetList()
                        end
                        ImGui.SameLine()
                        if ImGui.Button('Load##conf_load_' .. preset.id) then
                            Module.SwitchPreset(preset.id)
                            Module.tempSettings = Module.Settings
                        end
                        ImGui.SameLine()
                        if ImGui.Button('Delete##conf_del_' .. preset.id) then
                            Module.DeletePreset(preset.id)
                            Module.GetPresetList()
                        end
                    end
                end
            end
        end

        if ImGui.CollapsingHeader("Theme Settings##Header") then
            ImGui.SeparatorText('Theme')
            ImGui.Text("Cur Theme: %s", themeName)
            -- Combo Box Load Theme
            if ImGui.BeginCombo("Load Theme", themeName) then
                for k, data in pairs(Module.Theme.Theme) do
                    local isSelected = data['Name'] == themeName
                    if ImGui.Selectable(data['Name'], isSelected) then
                        Module.tempSettings['LoadTheme'] = data['Name']
                        themeName = Module.tempSettings['LoadTheme']
                        Module.Settings = Module.tempSettings
                        writeSettings(Module.SettingsFile, Module.Settings)
                    end
                end
                ImGui.EndCombo()
            end
        end
        ImGui.SeparatorText('Main Tab Zoom')
        -- Slider for adjusting zoom level
        local tmpZoom = Module.Settings.Scale
        if Module.Settings.Scale then
            tmpZoom = ImGui.SliderFloat("Gui Font Scale Level##MyBuffs", tmpZoom, 0.5, 2.0)
        end

        if Module.Settings.Scale ~= tmpZoom then
            Module.Settings.Scale = tmpZoom
            Module.tempSettings.Scale = tmpZoom
        end

        eChan = ImGui.InputText("Main Channel Echo##Echo", eChan, 256)
        if eChan ~= Module.Settings.mainEcho then
            Module.Settings.mainEcho = eChan
            Module.tempSettings.mainEcho = eChan
            writeSettings(Module.SettingsFile, Module.Settings)
        end
        ImGui.SeparatorText('Channels and Events Overview')
        buildConfig()
    end
    Module.ThemeLoader.EndTheme(ColorCountConf, StyleCountConf)

    ImGui.End()
end

function Module.Edit_GUI(open)
    if not Module.openEditGUI then return end

    local themeName = Module.Settings.LoadTheme
    local ColorCountEdit, StyleCountEdit = Module.ThemeLoader.StartTheme(themeName, Module.Theme)

    local showEdit
    open, showEdit = ImGui.Begin("Channel Editor", open, bit32.bor(ImGuiWindowFlags.None))
    if not open then Module.openEditGUI = false end
    if showEdit then
        if addChannel then Module.createExternConsole(string.format("New Channel %s", editChanID)) end
        Module.AddChannel(editChanID, addChannel)

        ImGui.SameLine()
        -- Close Button
        if ImGui.Button('Close') then
            Module.openEditGUI = false
            addChannel = false
            editChanID = 0
            editEventID = 0
        end
    end

    Module.ThemeLoader.EndTheme(ColorCountEdit, StyleCountEdit)
    ImGui.End()
end

function Module.StringTrim(s)
    return s:gsub("^%s*(.-)%s*$", "%1")
end

function Module.InitCommandHistory(channelID)
    local console = Module.Consoles[channelID]
    if not console.CommandHistory then
        console.CommandHistory = {}
    end
    if not console.HistoryIndex then
        console.HistoryIndex = 0
    end
end

-- Add command to history
function Module.AddToCommandHistory(channelID, command)
    Module.InitCommandHistory(channelID)
    local console = Module.Consoles[channelID]
    table.insert(console.CommandHistory, command)
    -- Reset history index to avoid conflicts

    while #console.CommandHistory > 10 do
        table.remove(console.CommandHistory, 1) -- Remove the oldest command
    end

    console.HistoryIndex = #console.CommandHistory + 1
    if Module.Settings.LogCommands then
        writeLogToFile(command)
    end
end

-- Navigate command history (up or down)
function Module.NavigateCommandHistory(channelID, direction)
    Module.InitCommandHistory(channelID)
    local console = Module.Consoles[channelID]

    if #console.CommandHistory == 0 then
        return ""
    end

    -- Adjust history index based on direction
    if direction == "up" then
        console.HistoryIndex = math.max(1, console.HistoryIndex - 1)
    elseif direction == "down" then
        console.HistoryIndex = math.min(#console.CommandHistory + 1, console.HistoryIndex + 1)
    end

    -- Return the selected command or empty string if at the end
    if console.HistoryIndex <= #console.CommandHistory then
        return console.CommandHistory[console.HistoryIndex]
    else
        return ""
    end
end

---comments
---@param text string -- the incomming line of text from the command prompt
function Module.ExecCommand(text)
    if LocalEcho then
        Module.console:AppendText(IM_COL32(128, 128, 128), "> %s", text)
    end

    if string.len(text) > 0 then
        text = Module.StringTrim(text)
        if text == 'clear' then
            Module.console:Clear()
        elseif string.sub(text, 1, 1) ~= '/' then
            if activeTabID > 0 then
                eChan = Module.Settings.Channels[activeTabID].Echo or '/say'
            end
            if string.find(eChan, '_') then
                eChan = string.gsub(eChan, '_', '')
                text = string.format("%s%s", eChan, text)
            else
                text = string.format("%s %s", eChan, text)
            end
        end
        if string.sub(text, 1, 1) == '/' then
            mq.cmdf("%s", text)
        else
            Module.console:AppendText(IM_COL32(255, 0, 0), "Unknown command: '%s'", text)
        end
    end
    if Module.Settings.LogCommands then
        writeLogToFile(text)
    end
end

---comments
---@param text string -- the incomming line of text from the command prompt
function Module.ChannelExecCommand(text, channelID)
    if LocalEcho then
        Module.console:AppendText(IM_COL32(128, 128, 128), "> %s", text)
    end

    eChan = '/say'
    if string.len(text) > 0 then
        text = Module.StringTrim(text)
        if text == 'clear' then
            Module.console:Clear()
        elseif string.sub(text, 1, 1) ~= '/' then
            if channelID > 0 then
                eChan = Module.Settings.Channels[channelID].Echo or '/say'
            end
            if string.find(eChan, '_') then
                eChan = string.gsub(eChan, '_', '')
                text = string.format("%s%s", eChan, text)
            else
                text = string.format("%s %s", eChan, text)
            end
        end
        if string.sub(text, 1, 1) == '/' then
            mq.cmdf("%s", text)
        else
            Module.console:AppendText(IM_COL32(255, 0, 0), "Unknown command: '%s'", text)
        end
        Module.AddToCommandHistory(channelID, text)
    end
end

function Module.createExternConsole(name)
    for k, v in pairs(Module.Settings.Channels) do
        local tmpName = v.Name:gsub("^%d+%s*", "")
        if tmpName == name then
            Module.TLOConsoles[name] = k
            return
        end
    end
    local newID = getNextID(Module.Settings.Channels)
    -- Place new channel at the end of the tab order
    local maxOrder = 0
    for _, v in pairs(Module.Settings.Channels) do
        if v and v.TabOrder and v.TabOrder < 9000 and v.TabOrder > maxOrder then
            maxOrder = v.TabOrder
        end
    end
    Module.Settings.Channels[newID] = {
        ['enabled'] = true,
        ['Name'] = name,
        ['FontSize'] = 16,
        ['Echo'] = '/say',
        ['MainEnable'] = true,
        ['PopOut'] = false,
        ['look'] = false,
        ['EnableLinks'] = true,
        ['TabOrder'] = maxOrder + 1,
        ['commandBuffer'] = "",
        ['Events'] = {
            [1] = {
                ['enabled'] = true,
                ['eventString'] = 'new',
                ['Filters'] = {
                    [0] = {
                        ['enabled'] = true,
                        ['filterString'] = '',
                        ['color'] = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, },
                    },
                },
            },
        },
    }
    Module.TLOConsoles[name] = newID
    ResetEvents()
end

-- TLO Handler
function Module.MyChatHandler(consoleName, message)
    -- if console specified is main then just print to main console
    if consoleName:lower() == 'main' then
        Module.Utils.AppendColoredTimestamp(Module.console, mq.TLO.Time.Time24(), message, nil, true)
        return
    end

    -- create console if it doesn't exist
    Module.createExternConsole(consoleName)
    local consoleID = Module.TLOConsoles[consoleName]

    -- main console if enabled
    if Module.Settings.Channels[consoleID].MainEnable ~= false then
        Module.Utils.AppendColoredTimestamp(Module.console, mq.TLO.Time.Time24(), message, nil, true)
    end

    -- our console
    Module.Utils.AppendColoredTimestamp(Module.Consoles[consoleID].console, mq.TLO.Time.Time24(), message, nil, true)
end

function Module.SortChannels()
    sortedChannels = {}
    for k, v in pairs(Module.Settings.Channels) do
        if v then
            table.insert(sortedChannels, { k, v.Name, v.TabOrder or 999 })
        end
    end

    -- Sort by TabOrder (lower = further left), then alphabetically as tiebreaker
    table.sort(sortedChannels, function(a, b)
        if a[3] ~= b[3] then
            return a[3] < b[3]
        end
        return a[2] < b[2]
    end)
end

---Swaps two channels' TabOrder values and re-sorts
---@param channelID integer -- the channel to move
---@param direction string -- 'left' or 'right'
function Module.MoveTab(channelID, direction)
    -- Find current position in sortedChannels
    local curIdx = nil
    for i, entry in ipairs(sortedChannels) do
        if entry[1] == channelID then
            curIdx = i
            break
        end
    end
    if not curIdx then return end

    local swapIdx = nil
    if direction == 'left' then
        -- Find the nearest visible, non-popped-out channel to the left
        for i = curIdx - 1, 1, -1 do
            local sid = sortedChannels[i][1]
            if Module.Settings.Channels[sid] and Module.Settings.Channels[sid].enabled
                and not Module.Settings.Channels[sid].PopOut then
                swapIdx = i
                break
            end
        end
    elseif direction == 'right' then
        -- Find the nearest visible, non-popped-out channel to the right
        for i = curIdx + 1, #sortedChannels do
            local sid = sortedChannels[i][1]
            if Module.Settings.Channels[sid] and Module.Settings.Channels[sid].enabled
                and not Module.Settings.Channels[sid].PopOut then
                swapIdx = i
                break
            end
        end
    end

    if not swapIdx then return end

    -- Swap TabOrder values
    local curChanID = sortedChannels[curIdx][1]
    local swapChanID = sortedChannels[swapIdx][1]
    local tmpOrder = Module.Settings.Channels[curChanID].TabOrder
    Module.Settings.Channels[curChanID].TabOrder = Module.Settings.Channels[swapChanID].TabOrder
    Module.Settings.Channels[swapChanID].TabOrder = tmpOrder
    Module.tempSettings = Module.Settings
    writeSettings(Module.SettingsFile, Module.Settings)
    Module.SortChannels()
end

function Module.Unload()
    for eventName, _ in pairs(Module.eventNames) do
        mq.unevent(eventName)
    end
    if MyUI ~= nil then
        MyUI.MyChatLoaded = false
        MyUI.MyChatHandler = nil
    end
end

local function init()
    Module.InitDB()
    if not Module.Utils.File.Exists(Module.Logtouch) then
        mq.pickle(Module.Logtouch, { touched = true, })
    end
    loadSettings()
    BuildEvents()

    -- initialize the console
    if Module.console == nil then
        Module.console = zep.Console.new("Chat##Console")
        mainBuffer = {
            [1] = {
                color = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, },
                text = '',
            },
        }
    end

    Module.console:AppendText("\ay[\aw%s\ay]\at Welcome to \agMyChat!", mq.TLO.Time())
    Module.SortChannels()
    Module.GetPresetList()
    Module.IsRunning = true

    if not loadedExeternally then
        mq.imgui.init(Module.Name, Module.RenderGUI)
        Module.LocalLoop()
    end
end

function Module.MainLoop()
    if loadedExeternally then
        MyUI.TempSettings.MyChatWinName = string.format('My Chat - Main')
        MyUI.TempSettings.MyChatFocusKey = Module.Settings.keyName
        if not MyUI.LoadModules.CheckRunning(Module.IsRunning, Module.Name) then
            MyUI.TempSettings.MyChatWinName = nil
            MyUI.TempSettings.MyChatFocusKey = nil
            return
        end
    end

    local lastTime = os.time()

    if resetConsoles then
        ResetConsoles()
        Module.SortChannels()
        resetConsoles = false
    end
    if resetEvnts then
        ResetEvents()
        Module.SortChannels()
        resetEvnts = false
    end
    if os.time() - lastTime > 5 then
        Module.SortChannels()
        lastTime = os.time()
    end
    if historyUpdated then
        historyUpdated = false
        focusKeyboard = true
    end
    if Module.Settings.LogCommands then
        openLogFile()
    else
        if logFileHandle then
            logFileHandle:close()
            logFileHandle = nil
        end
    end

    mq.doevents()

    -- Periodic cleanup of claimed lines to prevent memory growth
    local now = os.clock()
    for k, t in pairs(claimedLinesTTL) do
        if now - t > CLAIMED_TTL then
            claimedLines[k] = nil
            claimedLinesTTL[k] = nil
        end
    end
end

function Module.LocalLoop()
    while Module.IsRunning do
        Module.MainLoop()
        mq.delay(1)
    end
    Module.Unload()
end

init()

if MyUI ~= nil then
    MyUI.MyChatLoaded = true
    MyUI.MyChatHandler = Module.MyChatHandler
end

return Module
