--[[
    Title:   AlertMaster
    Authors: Special.Ed (original), Grimmier (GUI + commands + DB migration)
    Description:
        Monitors the zone for PCs, GMs, and named NPC spawns.
        Alerts via chat, sound, beep, and/or a popup window.

    Commands:
        /alertmaster show          -- toggle search window
        /alertmaster popup         -- toggle alert popup window
        /alertmaster help          -- full usage list
]]

local mq                = require('mq')
local ImGui             = require('ImGui')
local LIP               = require('lib.lip')
local ZoneNames         = require('defaults.ZoneNames')

local Module            = {}
Module.Name             = 'AlertMaster'
Module.ActorMailBox     = 'alertmaster'
Module.IsRunning        = false

---@diagnostic disable-next-line:undefined-global
local loadedExternally = MyUI ~= nil and true or false

if not loadedExternally then
    Module.Utils       = require('lib.common')
    Module.CharLoaded  = mq.TLO.Me.DisplayName()
    Module.Colors      = require('lib.colors')
    Module.Guild       = mq.TLO.Me.Guild() or 'NoGuild'
    Module.Icons       = require('mq.ICONS')
    Module.ThemeLoader = require('lib.theme_loader')
    Module.ThemeFile   = string.format('%s/MyUI/ThemeZ.lua', mq.configDir)
    Module.Theme       = require('defaults.themes')
    Module.Path        = string.format('%s/%s/', mq.luaDir, Module.Name)
    Module.Server      = mq.TLO.EverQuest.Server()
    Module.Build       = mq.TLO.MacroQuest.BuildName()
    Module.PackageMan  = require('mq.PackageMan')
    Module.SQLite3     = Module.PackageMan.Require('lsqlite3')
    Module.Actors      = require('actors')
else
    Module.Utils       = MyUI.Utils
    Module.CharLoaded  = MyUI.CharLoaded
    Module.Colors      = MyUI.Colors
    Module.Guild       = MyUI.Guild
    Module.Icons       = MyUI.Icons
    Module.ThemeLoader = MyUI.ThemeLoader
    Module.ThemeFile   = MyUI.ThemeFile
    Module.Theme       = MyUI.Theme
    Module.Path        = MyUI.Path
    Module.Server      = MyUI.Server
    Module.Build       = MyUI.Build
    Module.SQLite3     = MyUI.SQLite3
    Module.Actors      = MyUI.Actor
end

Module.SoundPath          = string.format('%s/sounds/default/', Module.Path)
Module.DBPath             = string.format('%s/MyUI/AlertMaster/%s/AlertMasterSpawns.db', mq.configDir, Module.Server)
Module.TempSettings       = {
    NpcList          = {},
    NewSafeZone      = '',
    NewIgnoredPlayer = '',
    SendNamed        = false,
    ReplyTo          = nil,
    NamedZone        = nil,
}
Module.WatchedSpawns      = {}
Module.DB                 = nil
Module.DirtyFilthyDB      = true

local pSuccess
pSuccess, Module.ZoneList = pcall(require, 'lib.zone-list')
if not pSuccess then Module.ZoneList = {} end

-- Local aliases
-- ---------------------------------------------------------------------------

local Utils                            = Module.Utils
local SpawnCount                       = mq.TLO.SpawnCount
local NearestSpawn                     = mq.TLO.NearestSpawn
local Group                            = mq.TLO.Group
local Raid                             = mq.TLO.Raid
local Zone                             = mq.TLO.Zone

local ToggleFlags                      = bit32.bor(
    Utils.ImGuiToggleFlags.PulseOnHover,
    Utils.ImGuiToggleFlags.RightLabel)

-- Config paths and defaults
-- ---------------------------------------------------------------------------

local scriptArgs                       = { ..., }
local amVer                            = '2.07'
local smSettings                       = mq.configDir .. '/MQ2SpawnMaster.ini'
local smImportList                     = mq.configDir .. '/am_imports.lua'
local newConfigFile                    = string.format('%s/MyUI/AlertMaster/%s/%s.lua', mq.configDir, Module.Server, Module.CharLoaded)
local CharConfig                       = 'Char_' .. mq.TLO.Me.DisplayName() .. '_Config'
local CharCommands                     = 'Char_' .. mq.TLO.Me.DisplayName() .. '_Commands'

local defaultConfig                    = {
    delay       = 1,
    remindNPC   = 5,
    remind      = 30,
    aggro       = false,
    pcs         = true,
    spawns      = true,
    gms         = true,
    announce    = false,
    ignoreguild = true,
    beep        = false,
    popup       = false,
    distmid     = 600,
    distfar     = 1200,
    locked      = false,
}

Module.Settings                        = {}
Module.Settings[CharConfig]            = {}
Module.Settings[CharCommands]          = {}

local settings                         = {}
local spawnsSpawnMaster                = {}
local tSafeZones                       = {}
local spawnAlerts                      = {}
local tSpawns                          = {}
local tPlayers                         = {}
local tAnnounce                        = {}
local tGMs                             = {}
local displayTablePlayers              = {}
local numDisplayPlayers                = 0
local importedZones                    = {}
local xTarTable                        = {}

local alertTime                        = 0
local numAlerts                        = 0
local zone_id                          = Zone.ID() or 0

local delay, remind, remindNPC         = 1, 30, 5
local pcs, spawns, gms, announce       = true, true, true, false
local ignoreguild, showAggro           = true, false
local radius, zradius                  = 100, 100
local doBeep, doAlert                  = false, false
local doSoundNPC, doSoundGM, doSoundPC = false, false, false
local doSoundPCEntered, doSoundPCLeft  = false, false
local soundGM, soundNPC, soundPC       = 'GM.wav', 'NPC.wav', 'PC.wav'
local soundPCEntered, soundPCLeft      = 'PCEntered.wav', 'PCLeft.wav'
local volNPC, volGM, volPC             = 100, 100, 100
local volPCEntered, volPCLeft          = 100, 100
local DoDrawArrow                      = false
local active                           = false
local groupCmd                         = '/dgae ' -- switched to /bcaa if MQ2EQBC found

-- UI state
local SearchWindowOpen                 = false
local AlertWindowOpen                  = false
local openConfigGUI                    = false
local showTooltips                     = true
local currentTab                       = 'zone'
local newSpawnName                     = ''
local useThemeName                     = 'Default'
local ZoomLvl                          = 1.0
local doOnce                           = true
local haveSM, importZone, forceImport  = false, false, false
local currZone, lastZone
local lastRefreshZoneTime              = 0

local DistColorRanges                  = {
    orange = 600,  -- green  -> orange boundary
    red    = 1200, -- orange -> red boundary
}

-- Sound playback tracking (for auto-reset of system volume after play)
local originalVolume                   = 50
local playTime                         = 0
local playing                          = false

-- Arrow rotation accumulator (incremented each draw call)
local angle                            = 0

-- ---------------------------------------------------------------------------
-- Table / GUI setup
-- ---------------------------------------------------------------------------

local spawnListFlags                   = bit32.bor(
    ImGuiTableFlags.Resizable,
    ImGuiTableFlags.Sortable,
    ImGuiTableFlags.BordersV,
    ImGuiTableFlags.BordersOuter,
    ImGuiTableFlags.Reorderable,
    ImGuiTableFlags.ScrollY,
    ImGuiTableFlags.Hideable)

local Table_Cache                      = {
    Rules     = {},
    Unhandled = {},
    Mobs      = {},
    Alerts    = {},
}

Module.GUI_Main                        = {
    Open    = false,
    Show    = false,
    Locked  = false,
    Flags   = bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.MenuBar),
    Refresh = {
        Sort  = { Rules = true, Filtered = true, Unhandled = true, Mobs = false, },
        Table = { Rules = true, Filtered = true, Unhandled = true, Mobs = false, },
    },
    Search  = '',
    Table   = {
        Column_ID = {
            ID           = 1,
            MobName      = 2,
            MobDirtyName = 3,
            MobLoc       = 4,
            MobZoneName  = 5,
            MobDist      = 6,
            MobID        = 7,
            Action       = 8,
            Remove       = 9,
            MobLvl       = 10,
            MobConColor  = 11,
            MobAggro     = 12,
            MobDirection = 13,
            Enum_Action  = 14,
        },
        Flags = bit32.bor(
            ImGuiTableFlags.Resizable,
            ImGuiTableFlags.Sortable,
            ImGuiTableFlags.NoBordersInBodyUntilResize,
            ImGuiTableFlags.Reorderable,
            ImGuiTableFlags.ScrollY,
            ImGuiTableFlags.Hideable),
        SortSpecs = { Rules = nil, Unhandled = nil, Filtered = nil, Mobs = nil, },
    },
}

Module.GUI_Alert                       = {
    Open    = false,
    Show    = false,
    Locked  = false,
    Flags   = bit32.bor(ImGuiWindowFlags.NoCollapse),
    Refresh = {
        Sort  = { Rules = true, Filtered = true, Unhandled = true, Mobs = false, Alerts = true, },
        Table = { Rules = true, Filtered = true, Unhandled = true, Mobs = false, Alerts = true, },
    },
    Table   = {
        Column_ID = {
            ID           = 1,
            MobName      = 2,
            MobDist      = 3,
            MobID        = 4,
            MobDirection = 5,
        },
        Flags = bit32.bor(
            ImGuiTableFlags.Resizable,
            ImGuiTableFlags.Sortable,
            ImGuiTableFlags.SizingFixedFit,
            ImGuiTableFlags.BordersV,
            ImGuiTableFlags.BordersOuter,
            ImGuiTableFlags.Reorderable,
            ImGuiTableFlags.ScrollY,
            ImGuiTableFlags.Hideable),
        SortSpecs = { Rules = nil, Unhandled = nil, Filtered = nil, Mobs = nil, Alerts = nil, },
    },
}

-- FFI: Windows winmm sound -- thanks coldblooded for this code
-- ---------------------------------------------------------------------------

local ffi                              = require('ffi')
ffi.cdef [[
    int      sndPlaySoundA(const char *pszSound, unsigned int fdwSound);
    uint32_t waveOutSetVolume(void *hwo, uint32_t dwVolume);
    uint32_t waveOutGetVolume(void *hwo, uint32_t *pdwVolume);
]]
local winmm        = ffi.load('winmm')
local SND_ASYNC    = 0x0001
local SND_FILENAME = 0x00020000
local sndFlags     = SND_FILENAME + SND_ASYNC

local function getVolume()
    local buf = ffi.new('uint32_t[1]')
    winmm.waveOutGetVolume(nil, buf)
    return buf[0]
end

local function resetVolume()
    winmm.waveOutSetVolume(nil, originalVolume)
    playTime = 0
    playing  = false
end

local function setVolume(volume)
    if volume < 0 or volume > 100 then error('Volume must be between 0 and 100') end
    local vol    = math.floor(volume / 100 * 0xFFFF)
    local packed = bit32.bor(bit32.lshift(vol, 16), vol)
    winmm.waveOutSetVolume(nil, packed)
end

local function playSound(name)
    playTime = os.time()
    playing  = true
    winmm.sndPlaySoundA(Module.SoundPath .. name, sndFlags)
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function MsgPrefix()
    return '\aw[\a-tAlert Master\aw] ::\ax '
end

local function GetCharZone()
    return '\aw[\ao' .. Module.CharLoaded .. '\aw] [\at' .. Zone.ShortName() .. '\aw] '
end

local function check_safe_zone()
    return tSafeZones[Zone.ShortName()] ~= nil
end

-- ---------------------------------------------------------------------------
-- Database stuff
-- ---------------------------------------------------------------------------

function Module:OpenDB()
    if self.DB then return self.DB end
    local db = Module.SQLite3.open(Module.DBPath)
    if not db then
        Module.Utils.PrintOutput('MyUI', nil, 'Failed to open the AlertMaster Database')
        return nil
    end
    db:exec('PRAGMA journal_mode=WAL;')
    db:busy_timeout(2000)
    self.DB = db
    return db
end

function Module:CloseDB()
    if self.DB then
        self.DB:close()
        self.DB = nil
    end
end

function Module.LoadSpawnsDB()
    if Module.Utils.File.Exists(Module.DBPath) then return end

    Module.Utils.PrintOutput('MyUI', nil, 'Creating the AlertMaster Database')
    local db = Module.SQLite3.open(Module.DBPath)
    db:exec('PRAGMA journal_mode=WAL;')
    db:exec('BEGIN TRANSACTION')
    db:exec [[
        CREATE TABLE IF NOT EXISTS npc_spawns (
            zone_short TEXT NOT NULL,
            spawn_name TEXT NOT NULL,
            id         INTEGER PRIMARY KEY AUTOINCREMENT
        );
    ]]
    db:exec [[
        CREATE TABLE IF NOT EXISTS pc_ignore (
            pc_name TEXT NOT NULL UNIQUE,
            id      INTEGER PRIMARY KEY AUTOINCREMENT
        );
    ]]
    db:exec [[
        CREATE TABLE IF NOT EXISTS safe_zones (
            zone_short TEXT NOT NULL UNIQUE,
            id         INTEGER PRIMARY KEY AUTOINCREMENT
        );
    ]]
    db:exec('COMMIT')
    db:exec('PRAGMA wal_checkpoint;')

    -- Migrate any pre-existing INI entries into the DB on first run
    db:exec('BEGIN TRANSACTION')
    for zone, spawn in pairs(settings) do
        if type(spawn) == 'table' and zone ~= 'SafeZones' and zone ~= 'Ignore' and not zone:find('^Char_') then
            for key, spawnName in pairs(spawn) do
                if key:find('Spawn') then
                    local stmt = db:prepare('INSERT INTO npc_spawns (zone_short, spawn_name) VALUES (?, ?);')
                    stmt:bind_values(zone, spawnName)
                    stmt:step(); stmt:finalize()
                end
            end
        end
    end
    for _, pcName in pairs(settings.Ignore or {}) do
        local stmt = db:prepare('INSERT INTO pc_ignore (pc_name) VALUES (?);')
        stmt:bind_values(pcName); stmt:step(); stmt:finalize()
    end
    for _, zoneShort in pairs(settings.SafeZones or {}) do
        local stmt = db:prepare('INSERT INTO safe_zones (zone_short) VALUES (?);')
        stmt:bind_values(zoneShort); stmt:step(); stmt:finalize()
    end
    db:exec('COMMIT')
    db:exec('PRAGMA wal_checkpoint;')
    db:close()
end

function Module:GetSpawns(zoneShort, db)
    zoneShort = zoneShort or Zone.ShortName()
    if not db then
        Module.Utils.PrintOutput('MyUI', nil, 'Failed to open the AlertMaster Database')
        return {}
    end
    local result = {}
    local stmt, err = db:prepare('SELECT spawn_name FROM npc_spawns WHERE zone_short = ?')
    if not stmt then
        Module.Utils.PrintOutput('MyUI', nil, 'Failed to prepare SQL statement: ' .. err)
        return {}
    end
    stmt:bind_values(zoneShort)
    for row in stmt:nrows() do
        if row.spawn_name and row.spawn_name ~= '' then table.insert(result, row.spawn_name) end
    end
    stmt:finalize()
    return result
end

function Module:GetIgnoredPlayers(db)
    if not db then
        Module.Utils.PrintOutput('MyUI', nil, 'Failed to open the AlertMaster Database')
        return {}
    end
    local result = {}
    local stmt, err = db:prepare('SELECT pc_name FROM pc_ignore')
    if not stmt then
        Module.Utils.PrintOutput('MyUI', nil, 'Failed to prepare SQL statement: ' .. err)
        return {}
    end
    for row in stmt:nrows() do
        if row.pc_name and row.pc_name ~= '' then table.insert(result, row.pc_name) end
    end
    stmt:finalize()
    return result
end

function Module:GetSafeZones(db)
    if not db then
        Module.Utils.PrintOutput('MyUI', nil, 'Failed to open the AlertMaster Database')
        return {}
    end
    local result = {}
    local stmt, err = db:prepare('SELECT zone_short FROM safe_zones')
    if not stmt then
        Module.Utils.PrintOutput('MyUI', nil, 'Failed to prepare SQL statement: ' .. err)
        return {}
    end
    for row in stmt:nrows() do
        if row.zone_short and row.zone_short ~= '' then table.insert(result, row.zone_short) end
    end
    stmt:finalize()
    return result
end

function Module:AddSafeZone(zoneShort)
    local db = self:OpenDB()
    if not db then return false end
    local check, errCheck = db:prepare('SELECT zone_short FROM safe_zones WHERE zone_short = ?')
    if not check then
        Module.Utils.PrintOutput('MyUI', nil, 'Failed to prepare SQL statement: ' .. errCheck)
        return false
    end
    check:bind_values(zoneShort)
    local exists = check:step() == Module.SQLite3.ROW
    check:finalize()
    if exists then return false end
    local stmt, err = db:prepare('INSERT OR IGNORE INTO safe_zones (zone_short) VALUES (?)')
    if not stmt then
        Module.Utils.PrintOutput('MyUI', nil, 'Failed to prepare SQL statement: ' .. err)
        return false
    end
    stmt:bind_values(zoneShort)
    local rc = stmt:step(); stmt:finalize()
    self.DirtyFilthyDB = true
    return rc == Module.SQLite3.DONE
end

function Module:RemoveSafeZone(zoneShort)
    local db = self:OpenDB()
    if not db then return false end
    local stmt = db:prepare('DELETE FROM safe_zones WHERE zone_short = ?')
    stmt:bind_values(zoneShort)
    local rc = stmt:step(); stmt:finalize()
    self.DirtyFilthyDB = true
    return rc == Module.SQLite3.DONE
end

function Module:AddIgnorePCtoDB(pcName)
    local db = self:OpenDB()
    if not db then return false end
    local check = db:prepare('SELECT pc_name FROM pc_ignore WHERE pc_name = ?')
    check:bind_values(pcName)
    local exists = check:step() == Module.SQLite3.ROW
    check:finalize()
    if exists then return false end
    local stmt = db:prepare('INSERT OR IGNORE INTO pc_ignore (pc_name) VALUES (?)')
    stmt:bind_values(pcName)
    local rc = stmt:step(); stmt:finalize()
    self.DirtyFilthyDB = true
    return rc == Module.SQLite3.DONE
end

function Module:RemoveIgnoredPC(pcName)
    local db = self:OpenDB()
    if not db then return false end
    local stmt = db:prepare('DELETE FROM pc_ignore WHERE pc_name = ?')
    stmt:bind_values(pcName)
    local rc = stmt:step(); stmt:finalize()
    self.DirtyFilthyDB = true
    return rc == Module.SQLite3.DONE
end

function Module:AddSpawnToDB(zoneShort, spawnName)
    local db = self:OpenDB()
    if not db then return false end
    local check = db:prepare('SELECT zone_short FROM npc_spawns WHERE zone_short = ? AND spawn_name = ?')
    check:bind_values(zoneShort, spawnName)
    local exists = check:step() == Module.SQLite3.ROW
    check:finalize()
    if exists then return false end
    db:exec('BEGIN TRANSACTION')
    local stmt = db:prepare('INSERT OR IGNORE INTO npc_spawns (zone_short, spawn_name) VALUES (?, ?)')
    stmt:bind_values(zoneShort, spawnName)
    local rc = stmt:step(); stmt:finalize()
    db:exec('COMMIT')
    self.DirtyFilthyDB = true
    return rc == Module.SQLite3.DONE
end

function Module:DeleteSpawnFromDB(zoneShort, spawnName)
    local db = self:OpenDB()
    if not db then return false end
    local stmt = db:prepare('DELETE FROM npc_spawns WHERE zone_short = ? AND spawn_name = ?')
    stmt:bind_values(zoneShort, spawnName)
    local rc = stmt:step(); stmt:finalize()
    self.DirtyFilthyDB = true
    return rc == Module.SQLite3.DONE
end

function Module:UpdateIgnoredPlayers()
    local db = self:OpenDB()
    settings.Ignore = self:GetIgnoredPlayers(db)
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

local function save_settings()
    mq.pickle(newConfigFile, Module.Settings)
end

local function set_settings()
    local cfg               = Module.Settings[CharConfig]

    useThemeName            = cfg['theme'] or 'Default'
    ZoomLvl                 = cfg['ZoomLvl'] or 1.0
    delay                   = cfg['delay'] or defaultConfig.delay
    remind                  = cfg['remind'] or defaultConfig.remind
    remindNPC               = cfg['remindNPC'] or defaultConfig.remindNPC
    pcs                     = cfg['pcs']
    spawns                  = cfg['spawns']
    gms                     = cfg['gms']
    announce                = cfg['announce']
    ignoreguild             = cfg['ignoreguild']
    radius                  = cfg['radius'] or radius
    zradius                 = cfg['zradius'] or zradius
    doBeep                  = cfg['beep'] or false
    DoDrawArrow             = cfg['arrows'] or false
    Module.GUI_Main.Locked  = cfg['locked'] or false
    doAlert                 = cfg['popup'] or false
    showAggro               = cfg['aggro'] or false
    DistColorRanges.orange  = cfg['distmid'] or 600
    DistColorRanges.red     = cfg['distfar'] or 1200
    doSoundGM               = cfg['doSoundGM'] or false
    doSoundNPC              = cfg['doSoundNPC'] or false
    doSoundPC               = cfg['doSoundPC'] or false
    volGM                   = cfg['volGM'] or volGM
    volNPC                  = cfg['volNPC'] or volNPC
    volPC                   = cfg['volPC'] or volPC
    soundGM                 = cfg['soundGM'] or soundGM
    soundNPC                = cfg['soundNPC'] or soundNPC
    soundPC                 = cfg['soundPC'] or soundPC
    soundPCEntered          = cfg['soundPCEntered'] or soundPCEntered
    soundPCLeft             = cfg['soundPCLeft'] or soundPCLeft
    volPCEntered            = cfg['volPCEntered'] or volPCEntered
    volPCLeft               = cfg['volPCLeft'] or volPCLeft
    doSoundPCLeft           = cfg['doSoundPCLeft'] or false
    doSoundPCEntered        = cfg['doSoundPCEntered'] or false

    -- Write back defaults so the config file is always complete
    cfg['theme']            = useThemeName
    cfg['ZoomLvl']          = ZoomLvl
    cfg['radius']           = radius
    cfg['zradius']          = zradius
    cfg['remindNPC']        = remindNPC
    cfg['beep']             = doBeep
    cfg['arrows']           = DoDrawArrow
    cfg['locked']           = Module.GUI_Main.Locked
    cfg['popup']            = doAlert
    cfg['aggro']            = showAggro
    cfg['distmid']          = DistColorRanges.orange
    cfg['distfar']          = DistColorRanges.red
    cfg['doSoundGM']        = doSoundGM
    cfg['doSoundNPC']       = doSoundNPC
    cfg['doSoundPC']        = doSoundPC
    cfg['volGM']            = volGM
    cfg['volNPC']           = volNPC
    cfg['volPC']            = volPC
    cfg['soundGM']          = soundGM
    cfg['soundNPC']         = soundNPC
    cfg['soundPC']          = soundPC
    cfg['soundPCEntered']   = soundPCEntered
    cfg['soundPCLeft']      = soundPCLeft
    cfg['volPCEntered']     = volPCEntered
    cfg['volPCLeft']        = volPCLeft
    cfg['doSoundPCLeft']    = doSoundPCLeft
    cfg['doSoundPCEntered'] = doSoundPCEntered
end

local function load_settings()
    if Module.Utils.File.Exists(newConfigFile) then
        local config                  = dofile(newConfigFile)
        Module.Settings[CharCommands] = config[CharCommands] or {}
        Module.Settings[CharConfig]   = config[CharConfig] or {}
    else
        Module.Settings[CharCommands] = {}
        Module.Settings[CharConfig]   = {}

        -- Migrate from legacy INI if present
        local settingsPath            = mq.TLO.MacroQuest.Path():gsub('\\', '/') .. '/config/AlertMaster.ini'
        if Module.Utils.File.Exists(settingsPath) then
            settings                      = LIP.load(settingsPath)
            Module.Settings[CharConfig]   = settings[CharConfig] or defaultConfig
            Module.Settings[CharCommands] = settings[CharCommands] or {}
            settings[CharConfig]          = nil
            settings[CharCommands]        = nil
        else
            settings = { Ignore = {}, }
        end
        save_settings()
    end

    for k, v in pairs(defaultConfig) do
        if Module.Settings[CharConfig][k] == nil then
            Module.Settings[CharConfig][k] = v
        end
    end

    if not loadedExternally then
        if Module.Utils.File.Exists(Module.ThemeFile) then
            Module.Theme = dofile(Module.ThemeFile)
        end
    end

    if Module.Utils.File.Exists(smSettings) then
        spawnsSpawnMaster = LIP.loadSM(smSettings)
        haveSM            = true
        importZone        = true
        for section, data in pairs(spawnsSpawnMaster) do
            local lwrSection = section:lower()
            if ZoneNames[lwrSection] then
                spawnsSpawnMaster[ZoneNames[lwrSection]] = data
                spawnsSpawnMaster[section] = nil
            end
        end
        local exportFile = string.format('%s/MyUI/ExportSM.lua', mq.configDir)
        mq.pickle(exportFile, spawnsSpawnMaster)
    end

    if Module.Utils.File.Exists(smImportList) then
        importedZones = dofile(smImportList)
    end

    Module.LoadSpawnsDB()
    useThemeName       = Module.Theme.LoadTheme or useThemeName

    local db           = Module:OpenDB()
    settings.SafeZones = Module:GetSafeZones(db)
    settings.Ignore    = Module:GetIgnoredPlayers(db)

    set_settings()
    save_settings()

    tSafeZones = {}
    for _, v in ipairs(settings.SafeZones or {}) do tSafeZones[v] = true end

    SearchWindowOpen = Module.GUI_Main.Locked
end

-- ---------------------------------------------------------------------------
-- Actors for passing updated information.
-- this can probably be simpified to just send the request and have the end
-- user just refresh from the database as we now use sql lite
-- ---------------------------------------------------------------------------

local amActor = nil

function Module:MessageHandler()
    amActor = Module.Actors.register('alertmaster', function(message)
        local data = message()
        if data == nil then return end
        local subject = data.Subject or 'Hello'
        local zone    = data.Zone or 'Unknown'
        local replyTo = data.ReplyTo or Module.ActorMailBox
        if subject == 'GetNamed' and zone ~= 'Unknown' then
            Module.TempSettings.SendNamed = true
            Module.TempSettings.NamedZone = zone
            Module.TempSettings.ReplyTo   = replyTo
        end
    end)
end

-----------------------------------------------------------------------------
-- Spawn lists
-----------------------------------------------------------------------------

function Module:AddSpawnToList(name)
    if name == nil then return end
    local zone   = Zone.ShortName()
    local result = Module:AddSpawnToDB(zone, name)
    if result == false then
        Module.Utils.PrintOutput('AlertMaster', nil, '\aySpawn alert "' .. name .. '" already exists.')
        return
    end
    local db = Module:OpenDB()
    Module.TempSettings.NpcList = Module:GetSpawns(Zone.ShortName(), db)
    Module.Utils.PrintOutput('AlertMaster', nil, '\ayAdded spawn alert for ' .. name .. ' in ' .. zone)
end

local function import_spawnmaster(val)
    local zoneShort = Zone.ShortName()
    local val_str   = tostring(val):gsub('"', '')
    if zoneShort == nil then return false end

    local flag = true
    for _, v in ipairs(Module.TempSettings.NpcList) do
        if v == val_str then
            flag = false; break
        end
    end

    importedZones[zoneShort] = true
    mq.pickle(smImportList, importedZones)

    if flag then
        return Module:AddSpawnToList(val_str) ~= nil
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Some more Helpers
-- ---------------------------------------------------------------------------

local function print_status()
    local P = function(s) Module.Utils.PrintOutput('AlertMaster', nil, s) end
    P('\ayAlert Status: ' .. (active and 'on' or 'off'))
    P('\a-tPCs: \a-y' ..
        tostring(pcs) .. '\ax radius: \a-y' .. radius .. '\ax zradius: \a-y' .. zradius .. '\ax delay: \a-y' .. delay .. 's\ax remind: \a-y' .. remind .. ' seconds\ax')
    P('\a-tremindNPC: \a-y' .. remindNPC .. '\at minutes\ax')
    P('\agClose Range\a-t Below: \a-g' .. DistColorRanges.orange .. '\ax')
    P('\aoMid Range\a-t Between: \a-g' .. DistColorRanges.orange .. '\a-t and \a-r' .. DistColorRanges.red .. '\ax')
    P('\arLong Range\a-t Greater than: \a-r' .. DistColorRanges.red .. '\ax')
    P('\a-tAnnounce PCs: \a-y' .. tostring(announce) .. '\ax')
    P('\a-tSpawns (zone wide): \a-y' .. tostring(spawns) .. '\ax')
    P('\a-tGMs (zone wide): \a-y' .. tostring(gms) .. '\ax')
    P('\a-tPopup Alerts: \a-y' .. tostring(doAlert) .. '\ax')
    P('\a-tBeep: \a-y' .. tostring(doBeep) .. '\ax')
    P('\a-tSound PC Alerts: \a-y' .. tostring(doSoundPC) .. '\ax')
    P('\a-tSound NPC Alerts: \a-y' .. tostring(doSoundNPC) .. '\ax')
    P('\a-tSound GM Alerts: \a-y' .. tostring(doSoundGM) .. '\ax')
    P('\a-tVolume PC Alerts: \a-y' .. volPC .. '\ax')
    P('\a-tVolume NPC Alerts: \a-y' .. volNPC .. '\ax')
    P('\a-tVolume GM Alerts: \a-y' .. volGM .. '\ax')
end

local function run_char_commands()
    if Module.Settings[CharCommands] == nil then return end
    for _, cmd in pairs(Module.Settings[CharCommands]) do
        mq.cmdf(cmd)
        Module.Utils.PrintOutput('AlertMaster', nil, string.format('Ran command: "%s"', cmd))
    end
end

local function ColorDistance(distance)
    return Utils.ColorDistance(distance, DistColorRanges.orange, DistColorRanges.red)
end

local function isSpawnInAlerts(spawnName, alertsTable)
    for _, spawn in pairs(alertsTable) do
        if spawn.DisplayName() == spawnName or spawn.Name() == spawnName then
            return true
        end
    end
    return false
end

---@param spawn MQSpawn
local function SpawnToEntry(spawn, id, dataTable)
    if not spawn or not spawn.ID() then return end
    local surName = spawn.Surname() or ''
    if surName:find("'s ") then return end
    local pAggro = (dataTable == xTarTable) and (spawn.PctAggro() or 0) or 0
    return {
        ID           = id or 0,
        MobName      = spawn.DisplayName() or ' ',
        MobDirtyName = spawn.Name() or ' ',
        MobZoneName  = Zone.Name() or ' ',
        MobDist      = math.floor(spawn.Distance() or 0),
        MobLoc       = spawn.Loc() or ' ',
        MobID        = spawn.ID() or 0,
        MobLvl       = spawn.Level() or 0,
        MobConColor  = string.lower(spawn.ConColor() or 'white'),
        MobAggro     = pAggro,
        MobDirection = spawn.HeadingTo() or '0',
        Enum_Action  = 'unhandled',
    }
end

---@param spawn MQSpawn
local function InsertTableSpawn(dataTable, spawn, id, opts)
    if not spawn then return end
    local entry = SpawnToEntry(spawn, id, dataTable)
    if not entry then return end
    if opts then for k, v in pairs(opts) do entry[k] = v end end
    table.insert(dataTable, entry)
end

local function should_include_player(spawn)
    local name  = spawn.DisplayName()
    local guild = spawn.Guild() or 'None'
    for _, v in pairs(settings.Ignore or {}) do
        if v == name then return false end
    end
    local in_group = Group.Members() ~= nil and Group.Member(name).Index() ~= nil
    local in_raid  = Raid.Members() > 0 and Raid.Member(name)() ~= nil
    local in_guild = ignoreguild and (Module.Guild == guild)
    return not (in_group or in_raid or in_guild)
end

-- ---------------------------------------------------------------------------
-- Table sort functions
-- TODO: Clean up these 2 functions into a single one that works for both
-- sort using column number and not have to define all of the columns in advance
-- ---------------------------------------------------------------------------

local function TableSortSpecs(a, b)
    for i = 1, Module.GUI_Main.Table.SortSpecs.SpecsCount do
        local spec  = Module.GUI_Main.Table.SortSpecs:Specs(i)
        local col   = Module.GUI_Main.Table.Column_ID

        local delta = 0
        if spec.ColumnUserID == col.MobName then
            if a.MobName and b.MobName then
                if a.MobName < b.MobName then
                    delta = -1
                elseif a.MobName > b.MobName then
                    delta = 1
                end
            else
                return 0
            end
        elseif spec.ColumnUserID == col.MobID then
            if a.MobID and b.MobID then
                if a.MobID < b.MobID then
                    delta = -1
                elseif a.MobID > b.MobID then
                    delta = 1
                end
            else
                return 0
            end
        elseif spec.ColumnUserID == col.MobLvl then
            if a.MobLvl and b.MobLvl then
                if a.MobLvl < b.MobLvl then
                    delta = -1
                elseif a.MobLvl > b.MobLvl then
                    delta = 1
                end
            else
                return 0
            end
        elseif spec.ColumnUserID == col.MobDist then
            if a.MobDist and b.MobDist then
                if a.MobDist < b.MobDist then
                    delta = -1
                elseif a.MobDist > b.MobDist then
                    delta = 1
                end
            else
                return 0
            end
        elseif spec.ColumnUserID == col.MobAggro then
            if a.MobAggro and b.MobAggro then
                if a.MobAggro < b.MobAggro then
                    delta = -1
                elseif a.MobAggro > b.MobAggro then
                    delta = 1
                end
            else
                return 0
            end
        elseif spec.ColumnUserID == col.Action then
            if a.Enum_Action < b.Enum_Action then
                delta = -1
            elseif a.Enum_Action > b.Enum_Action then
                delta = 1
            end
        end
        if delta ~= 0 then
            if spec.SortDirection == ImGuiSortDirection.Ascending then
                return delta < 0
            else
                return delta > 0
            end
        end
    end
    return a.MobName < b.MobName
end

local function AlertTableSortSpecs(a, b)
    for i = 1, Module.GUI_Alert.Table.SortSpecs.SpecsCount do
        local spec  = Module.GUI_Alert.Table.SortSpecs:Specs(i)
        local col   = Module.GUI_Alert.Table.Column_ID
        local delta = 0
        if spec.ColumnUserID == col.MobName then
            if a.MobName and b.MobName then
                if a.MobName < b.MobName then
                    delta = -1
                elseif a.MobName > b.MobName then
                    delta = 1
                end
            else
                return 0
            end
        elseif spec.ColumnUserID == col.MobDist then
            if a.MobDist and b.MobDist then
                if a.MobDist < b.MobDist then
                    delta = -1
                elseif a.MobDist > b.MobDist then
                    delta = 1
                end
            else
                return 0
            end
        end
        if delta ~= 0 then
            if spec.SortDirection == ImGuiSortDirection.Ascending then
                return delta < 0
            else
                return delta > 0
            end
        end
    end
    return a.MobName < b.MobName
end

-- ---------------------------------------------------------------------------
-- Refresh all the things
-- ---------------------------------------------------------------------------

function Module:RefreshUnhandled()
    local splitSearch = {}
    for part in string.gmatch(Module.GUI_Main.Search, '[^%s]+') do
        table.insert(splitSearch, string.lower(part))
    end
    local newTable = {}
    for _, v in ipairs(Table_Cache.Rules) do
        local found = 0
        local nameLower = string.lower(v.MobName)
        for _, search in ipairs(splitSearch) do
            if string.find(nameLower, search) or string.find(string.lower(v.MobDirtyName), search) then
                found = found + 1
            end
        end
        if #splitSearch == found then table.insert(newTable, v) end
    end
    Table_Cache.Unhandled                   = newTable
    Module.GUI_Main.Refresh.Sort.Rules      = true
    Module.GUI_Main.Refresh.Table.Unhandled = false
end

function Module:RefreshAlerts()
    local tmp = {}
    for _, v in pairs(spawnAlerts) do table.insert(tmp, v) end
    local newTable = {}
    for _, spawn in ipairs(tmp) do
        InsertTableSpawn(newTable, spawn, tonumber(spawn.ID()))
    end
    Table_Cache.Alerts                    = newTable
    Module.GUI_Alert.Refresh.Sort.Alerts  = true
    Module.GUI_Alert.Refresh.Table.Alerts = false
    doOnce                                = false
end

function Module:RefreshZone()
    local existing = {}
    for _, entry in ipairs(Table_Cache.Rules or {}) do
        existing[entry.MobID] = entry
    end

    local liveIDs = {}
    local zoneNpcs = mq.getFilteredSpawns(function(spawn) return spawn.Type() == 'NPC' end)
    for _, spawn in ipairs(zoneNpcs) do
        if spawn() then
            local id = tonumber(spawn.ID())
            if id then liveIDs[id] = spawn end
        end
    end

    local newTable = {}
    for id, spawn in pairs(liveIDs) do
        if existing[id] then
            table.insert(newTable, existing[id])
        else
            InsertTableSpawn(newTable, spawn, id)
        end
    end

    xTarTable = {}
    for i = 1, mq.TLO.Me.XTargetSlots() do
        local xt = mq.TLO.Me.XTarget(i)
        if xt() and xt() ~= 0 and xt.ID() > 0 then
            InsertTableSpawn(xTarTable, xt, tonumber(xt.ID()))
        end
    end
    if showAggro then
        for _, xEntry in ipairs(xTarTable) do
            for j, entry in ipairs(newTable) do
                if entry.MobID == xEntry.MobID then
                    newTable[j].MobAggro = xEntry.MobAggro; break
                end
            end
        end
    end
    Table_Cache.Rules                       = newTable
    Table_Cache.Mobs                        = newTable
    Module.GUI_Main.Refresh.Sort.Mobs       = true
    Module.GUI_Main.Refresh.Table.Mobs      = false
    Module.GUI_Main.Refresh.Table.Unhandled = true
end

-- ---------------------------------------------------------------------------
-- Spawn scanning
-- ---------------------------------------------------------------------------

local function spawn_search_players(search)
    local tmp = {}
    local cnt = SpawnCount(search)()
    if cnt == nil or cnt <= 0 then return tmp end
    for i = 1, cnt do
        local pc = NearestSpawn(i, search)
        if pc ~= nil and pc.DisplayName() ~= nil then
            local name  = pc.DisplayName() or 'unknown'
            local guild = pc.Guild() or 'No Guild'
            if should_include_player(pc) then
                tmp[name] = {
                    name     = (pc.GM() and '\ag*GM*\ax ' or '') .. '\ar' .. name .. '\ax',
                    tblName  = name,
                    level    = pc.Level() or 0,
                    guild    = '<\ay' .. guild .. '\ax>',
                    tblGuild = guild,
                    distance = math.floor(pc.Distance() or 0),
                    time     = os.time(),
                    isGM     = pc.GM() or false,
                }
            end
        end
    end

    for name, v in pairs(tmp) do
        if displayTablePlayers[name] == nil then
            displayTablePlayers[name] = v
            numDisplayPlayers = numDisplayPlayers + 1
        else
            displayTablePlayers[name].distance = v.distance
            displayTablePlayers[name].time     = v.time
        end
    end

    if search ~= 'gm' then
        local toRemove = {}
        for name in pairs(displayTablePlayers) do
            if tmp[name] == nil then
                toRemove[#toRemove + 1] = name
            end
        end
        for _, name in ipairs(toRemove) do
            displayTablePlayers[name] = nil
            numDisplayPlayers = numDisplayPlayers - 1
        end
    end
    return tmp
end

local function spawn_search_npcs()
    local tmp     = {}
    local db      = Module:OpenDB()
    local tracked = Module:GetSpawns(Zone.ShortName(), db)
    for _, name in pairs(tracked) do
        local search = 'npc ' .. name
        local cnt    = SpawnCount(search)()
        for i = 1, cnt do
            local spawn = NearestSpawn(i, search)
            local id    = spawn.ID()
            if spawn ~= nil and id ~= nil then
                if spawn.DisplayName() == name or spawn.Name() == name then
                    tmp[id] = spawn
                end
            end
        end
    end
    return tmp
end

local function check_for_gms()
    local tmp = spawn_search_players('gm')
    if not (active and gms and not check_safe_zone()) then return end
    for name, v in pairs(tmp) do
        if tGMs[name] == nil then
            tGMs[name] = v
            Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' ' .. v.guild .. ' entered the zone. ' .. v.distance .. ' units away.')
            if doSoundGM then
                setVolume(volGM); playSound(soundGM)
            end
        elseif remind > 0 and os.difftime(os.time(), tGMs[name].time) > remind then
            tGMs[name].time = v.time
            if doSoundGM then
                setVolume(volGM); playSound(soundGM)
            end
            Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' loitering ' .. v.distance .. ' units away.')
        end
    end
    for name, v in pairs(tGMs) do
        if tmp[name] == nil then
            tGMs[name] = nil
            Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' left the zone.')
        end
    end
end

local function check_for_pcs()
    local search = 'pc radius ' .. radius .. ' zradius ' .. zradius .. ' notid ' .. mq.TLO.Me.ID()
    local tmp    = spawn_search_players(search)
    if not (active and pcs and not check_safe_zone()) then return end
    for name, v in pairs(tmp) do
        if tPlayers[name] == nil then
            tPlayers[name] = v
            Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' ' .. v.guild .. ' entered the alert radius. ' .. v.distance .. ' units away.')
            if doSoundPC then
                setVolume(volPC); playSound(soundPC)
            end
            run_char_commands()
        elseif remind > 0 and os.difftime(os.time(), tPlayers[name].time) > remind then
            tPlayers[name].time = v.time
            if doSoundPC then
                setVolume(volPC); playSound(soundPC)
            end
            Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' loitering ' .. v.distance .. ' units away.')
            run_char_commands()
        end
    end
    for name, v in pairs(tPlayers) do
        if tmp[name] == nil then
            tPlayers[name] = nil
            Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' left the alert radius.')
        end
    end
end

local function check_for_spawns()
    if not active then return end

    if haveSM and (importZone or forceImport) then
        local zoneShort = Zone.ShortName()
        if not importedZones[zoneShort] or forceImport then
            local tmpSM   = {}
            local fixName = Zone.Name():gsub('the ', ''):lower()
            if spawnsSpawnMaster[Zone.Name():lower()] ~= nil then
                tmpSM = spawnsSpawnMaster[Zone.Name():lower()]
            elseif spawnsSpawnMaster[Module.ZoneList[zoneShort]] ~= nil then
                tmpSM = spawnsSpawnMaster[Module.ZoneList[zoneShort]]
            elseif spawnsSpawnMaster[fixName] ~= nil then
                tmpSM = spawnsSpawnMaster[fixName]
            end
            local counter = 0
            for _, v in pairs(tmpSM) do
                if import_spawnmaster(v) then counter = counter + 1 end
            end
            if spawnsSpawnMaster[zoneShort] ~= nil then
                for _, v in pairs(spawnsSpawnMaster[zoneShort]) do
                    if import_spawnmaster(v) then counter = counter + 1 end
                end
            end
            importZone  = false
            forceImport = false
            mq.pickle(smImportList, importedZones)
            Module.Utils.PrintOutput('AlertMaster', nil, string.format('\aw[\atAlert Master\aw] \agImported \aw[\ay%d\aw]\ag Spawn Master Spawns...', counter))
        end
    end

    local tmp = spawn_search_npcs()
    if tmp == nil or not spawns then return end

    local spawnAlertsUpdated = false
    local tableUpdate        = false

    for id, v in pairs(tmp) do
        if tSpawns[id] == nil then
            if not check_safe_zone() then
                Module.Utils.PrintOutput('AlertMaster', nil,
                    GetCharZone() .. '\ag' .. tostring(v.DisplayName()) .. '\ax spawn alert! ' .. math.floor(v.Distance() or 0) .. ' units away.')
                spawnAlertsUpdated = true
            end
            tableUpdate     = true
            tSpawns[id]     = { DisplayName = v.DisplayName(), Spawn = v, }
            spawnAlerts[id] = v
            numAlerts       = numAlerts + 1
        end
    end

    for id, v in pairs(tSpawns) do
        if tmp[id] == nil then
            if not check_safe_zone() and v.DisplayName ~= nil then
                Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. '\ag' .. tostring(v.DisplayName) .. '\ax was killed or despawned.')
            end
            tableUpdate     = true
            tSpawns[id]     = nil
            spawnAlerts[id] = nil
            numAlerts       = numAlerts - 1
        end
    end

    if next(spawnAlerts) ~= nil then
        if tableUpdate or doOnce then Module:RefreshAlerts() end
        if spawnAlertsUpdated then
            if doAlert then AlertWindowOpen = true end
            alertTime = os.time()
            if doSoundNPC then
                setVolume(volNPC); playSound(soundNPC)
            elseif doBeep then
                mq.cmdf('/beep')
            end
        end
    else
        AlertWindowOpen = false
    end
end

local function check_for_announce()
    local tmp = spawn_search_players('pc notid ' .. mq.TLO.Me.ID())
    if not (active and announce and not check_safe_zone()) then return end
    for name, v in pairs(tmp) do
        if tAnnounce[name] == nil then
            tAnnounce[name] = v
            Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' ' .. v.guild .. ' entered the zone.')
            if doSoundPCEntered then
                setVolume(volPCEntered); playSound(soundPCEntered)
            end
        end
    end
    for name, v in pairs(tAnnounce) do
        if tmp[name] == nil then
            tAnnounce[name] = nil
            Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. v.name .. ' left the zone.')
            if doSoundPCLeft then
                setVolume(volPCLeft); playSound(soundPCLeft)
            end
        end
    end
end

local function check_for_zone_change()
    if not active then return false end
    if zone_id ~= nil and zone_id == Zone.ID() then return false end
    AlertWindowOpen                                                                = false
    tGMs, tAnnounce, tPlayers, tSpawns                                             = {}, {}, {}, {}
    spawnAlerts, displayTablePlayers                                               = {}, {}
    Table_Cache.Unhandled, Table_Cache.Alerts, Table_Cache.Mobs, Table_Cache.Rules = {}, {}, {}, {}
    numDisplayPlayers                                                              = 0
    zone_id                                                                        = Zone.ID()
    alertTime                                                                      = os.time()
    doOnce                                                                         = true
    if haveSM then importZone = true end
    return true
end

-- ---------------------------------------------------------------------------
-- GUI: toolbar
-- ---------------------------------------------------------------------------

local btnIconDel = Module.Icons.MD_DELETE

local function DrawButtonToggles()
    -- Lock / unlock
    local lockIcon = Module.GUI_Main.Locked and Module.Icons.FA_LOCK .. '##lockTabButton' or Module.Icons.FA_UNLOCK .. '##lockTabButton'
    if ImGui.SmallButton(lockIcon) then
        Module.GUI_Main.Locked = not Module.GUI_Main.Locked
        Module.Settings[CharConfig]['locked'] = Module.GUI_Main.Locked
        save_settings()
    end
    if ImGui.IsItemHovered() and showTooltips then ImGui.SetTooltip('Lock Window') end

    -- Config
    if ImGui.SmallButton(Module.Icons.MD_SETTINGS) then
        openConfigGUI = not openConfigGUI; save_settings()
    end
    if ImGui.IsItemHovered() and showTooltips then ImGui.SetTooltip('Config') end

    -- Alert popup toggle
    local alertColor = doAlert and Module.Colors.color('btn_green') or Module.Colors.color('btn_red')
    ImGui.PushStyleColor(ImGuiCol.Button, alertColor)
    if ImGui.SmallButton(doAlert and Module.Icons.MD_ALARM or Module.Icons.MD_ALARM_OFF) then mq.cmdf('/alertmaster doalert') end
    ImGui.PopStyleColor(1)
    if ImGui.IsItemHovered() and showTooltips then ImGui.SetTooltip('Toggle Popup Alerts On/Off') end

    -- Beep toggle
    ImGui.PushStyleColor(ImGuiCol.Button, doBeep and Module.Colors.color('btn_green') or Module.Colors.color('btn_red'))
    if ImGui.SmallButton(doBeep and Module.Icons.FA_BELL_O or Module.Icons.FA_BELL_SLASH_O) then mq.cmdf('/alertmaster beep') end
    ImGui.PopStyleColor(1)
    if ImGui.IsItemHovered() and showTooltips then ImGui.SetTooltip('Toggle Beep Alerts On/Off') end

    -- Alert window toggle
    ImGui.PushStyleColor(ImGuiCol.Button, AlertWindowOpen and Module.Colors.color('btn_green') or Module.Colors.color('btn_red'))
    if ImGui.SmallButton(AlertWindowOpen and Module.Icons.MD_VISIBILITY or Module.Icons.MD_VISIBILITY_OFF) then mq.cmdf('/alertmaster popup') end
    ImGui.PopStyleColor(1)
    if ImGui.IsItemHovered() and showTooltips then ImGui.SetTooltip('Show/Hide Alert Window') end

    -- Add target dirty name
    if ImGui.SmallButton(Module.Icons.FA_HASHTAG) then mq.cmdf('/alertmaster spawnadd ${Target}') end
    if ImGui.IsItemHovered() and showTooltips then ImGui.SetTooltip('Add Target #DirtyName to SpawnList') end

    -- Add target display name
    if ImGui.SmallButton(Module.Icons.FA_BULLSEYE) then mq.cmdf('/alertmaster spawnadd "${Target.DisplayName}"') end
    if ImGui.IsItemHovered() and showTooltips then ImGui.SetTooltip('Add Target Clean Name to SpawnList.\nHandy for hunting a specific mob type.') end

    -- Arrow toggle
    ImGui.PushStyleColor(ImGuiCol.Button, DoDrawArrow and Module.Colors.color('btn_green') or Module.Colors.color('btn_red'))
    if ImGui.SmallButton(DoDrawArrow and Module.Icons.FA_ARROW_UP or Module.Icons.FA_ARROW_DOWN) then
        DoDrawArrow = not DoDrawArrow
        Module.Settings[CharConfig]['arrows'] = DoDrawArrow
        save_settings()
    end
    ImGui.PopStyleColor(1)
    if ImGui.IsItemHovered() and showTooltips then ImGui.SetTooltip('Toggle Drawing Arrows On/Off') end

    -- Aggro toggle
    ImGui.PushStyleColor(ImGuiCol.Button, showAggro and Module.Colors.color('btn_green') or Module.Colors.color('btn_red'))
    if ImGui.SmallButton(Module.Icons.MD_PRIORITY_HIGH) then mq.cmdf('/alertmaster aggro') end
    ImGui.PopStyleColor(1)
    if ImGui.IsItemHovered() and showTooltips then ImGui.SetTooltip('Toggle Aggro Status On/Off') end

    -- Master scan toggle
    ImGui.PushStyleColor(ImGuiCol.Button, active and Module.Colors.color('btn_green') or Module.Colors.color('btn_red'))
    if ImGui.SmallButton(active and Module.Icons.FA_HEARTBEAT or Module.Icons.MD_DO_NOT_DISTURB) then
        mq.cmdf(active and '/alertmaster off' or '/alertmaster on')
    end
    ImGui.PopStyleColor(1)
    if ImGui.IsItemHovered() and showTooltips then ImGui.SetTooltip('Toggle ALL Scanning and Alerts On/Off') end

    -- Tooltip mode indicator
    ImGui.Text(showTooltips and Module.Icons.MD_HELP or Module.Icons.MD_HELP_OUTLINE)
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip('Right-Click to toggle Tooltips.')
        if ImGui.IsMouseReleased(0) or ImGui.IsMouseReleased(1) then showTooltips = not showTooltips end
    end
end

-- ---------------------------------------------------------------------------
-- GUI: row renderers
-- ---------------------------------------------------------------------------

local function DrawRuleRow(entry)
    local spawn = mq.TLO.Spawn(entry.MobID)
    if not spawn() then return end
    entry.MobDist      = math.floor(spawn.Distance() or 0)
    entry.MobLoc       = spawn.Loc() or ' '
    entry.MobDirection = spawn.HeadingTo() or '0'

    ImGui.TableNextColumn()
    if ImGui.SmallButton(Module.Icons.FA_USER_PLUS) then Module:AddSpawnToList(entry.MobName) end
    if ImGui.IsItemHovered() and showTooltips then ImGui.SetTooltip('Add to Spawn List') end

    ImGui.TableNextColumn()
    ImGui.PushStyleColor(ImGuiCol.Text, spawnAlerts[entry.MobID] ~= nil and Module.Colors.color('green') or Module.Colors.color('white'))
    ImGui.Text('%s', entry.MobName)
    ImGui.PopStyleColor()
    if ImGui.IsItemHovered() then
        if showTooltips then
            local tip = entry.MobName .. '\n\nRight-Click to Navigate\nCtrl+Right-Click Group Nav'
            if Module.Build:lower() == 'emu' then tip = tip .. '\nShift+Left-Click to Target' end
            ImGui.SetTooltip(tip)
        end
        if ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsMouseReleased(1) then
            mq.cmdf('/noparse %s/docommand /timed ${Math.Rand[5,25]} /nav id %s', groupCmd, entry.MobID)
        elseif ImGui.IsKeyDown(ImGuiMod.Shift) and ImGui.IsMouseReleased(0) and Module.Build:lower() == 'emu' then
            mq.cmdf('/target id %s', entry.MobID)
        elseif ImGui.IsMouseReleased(1) then
            mq.cmdf('/nav id %s', entry.MobID)
        end
    end
    ImGui.SameLine()

    ImGui.TableNextColumn()
    ImGui.PushStyleColor(ImGuiCol.Text, Module.Colors.color(entry.MobConColor))
    ImGui.Text('%s', tostring(entry.MobLvl))
    ImGui.PopStyleColor()

    ImGui.TableNextColumn()
    local distance = math.floor(entry.MobDist or 0)
    ImGui.PushStyleColor(ImGuiCol.Text, ColorDistance(distance))
    ImGui.Text(tostring(distance))
    ImGui.PopStyleColor()

    ImGui.TableNextColumn()
    if entry.MobAggro ~= 0 then
        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, Module.Colors.color('red'))
        ImGui.ProgressBar(tonumber(entry.MobAggro) / 100, ImGui.GetColumnWidth(), 15)
        ImGui.PopStyleColor()
    end

    ImGui.TableNextColumn()
    ImGui.Text('%s', tostring(entry.MobID))

    ImGui.TableNextColumn()
    ImGui.Text('%s', tostring(entry.MobLoc))

    ImGui.TableNextColumn()
    if DoDrawArrow then
        angle = Module.Utils.getRelativeDirection(entry.MobDirection) or 0
        local pos = ImGui.GetCursorScreenPosVec()
        Module.Utils.DrawArrow(ImVec2(pos.x + 10, pos.y), 5, 15, ColorDistance(distance), angle)
    end
end

local function DrawAlertRuleRow(entry)
    local spawn = mq.TLO.Spawn(entry.MobID)
    if not spawn() then return end

    ImGui.TableSetColumnIndex(0)
    ImGui.PushStyleColor(ImGuiCol.Text, Module.Colors.color('green'))
    ImGui.Text(entry.MobName)
    ImGui.PopStyleColor(1)
    if ImGui.IsItemHovered() then
        if showTooltips then
            ImGui.SetTooltip('Right-Click to Navigate: ' .. entry.MobName .. '\nCtrl+Right-Click to Group Navigate.')
        end
        if ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsMouseReleased(1) then
            mq.cmdf('/noparse %s/docommand /timed ${Math.Rand[10,60]} /nav id %s', groupCmd, entry.MobID)
        elseif ImGui.IsMouseReleased(1) then
            mq.cmdf('/nav id %s', entry.MobID)
        end
    end

    ImGui.TableSetColumnIndex(1)
    ImGui.PushStyleColor(ImGuiCol.Text, Module.Colors.color(entry.MobConColor))
    ImGui.Text(entry.MobLvl)
    ImGui.PopStyleColor()

    ImGui.TableSetColumnIndex(2)
    local distance = math.floor(spawn.Distance() or -1)
    ImGui.PushStyleColor(ImGuiCol.Text, ColorDistance(distance))
    ImGui.Text('%s', tostring(distance))
    ImGui.PopStyleColor()

    ImGui.TableSetColumnIndex(3)
    -- Arrow is always drawn in the alert window (DoDrawArrow guard was commented out in original)
    angle = Module.Utils.getRelativeDirection(entry.MobDirection) or 0
    local pos = ImGui.GetCursorScreenPosVec()
    Module.Utils.DrawArrow(ImVec2(pos.x + 10, pos.y), 5, 15, ColorDistance(distance), angle)
end

-- ---------------------------------------------------------------------------
-- GUI: config sub-panels
-- ---------------------------------------------------------------------------

function Module:DrawSafeZoneConfig()
    ImGui.Text('Safe Zones:')
    Module.TempSettings.NewSafeZone = Module.TempSettings.NewSafeZone or ''
    local newZone, entered = ImGui.InputTextWithHint('Add Safe Zone##SafeZoneInput',
        'Zone ShortName and Press ENTER', Module.TempSettings.NewSafeZone, ImGuiInputTextFlags.EnterReturnsTrue)
    if entered then
        Module:AddSafeZone(newZone)
        Module.TempSettings.NewSafeZone = ''
    else
        Module.TempSettings.NewSafeZone = newZone
    end
    ImGui.Separator()
    if ImGui.BeginTable('SafeZoneTable##SafeZoneTable', 2, ImGuiTableFlags.Borders) then
        ImGui.TableSetupColumn('Zone Name', ImGuiTableColumnFlags.WidthStretch)
        ImGui.TableSetupColumn('Actions', ImGuiTableColumnFlags.WidthFixed, 100)
        ImGui.TableHeadersRow()
        for i, zone in ipairs(settings.SafeZones or {}) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn(); ImGui.Text(zone)
            ImGui.TableNextColumn()
            if ImGui.SmallButton('Delete##SafeZoneDelete' .. i) then Module:RemoveSafeZone(zone) end
        end
        ImGui.EndTable()
    end
end

function Module:DrawIgnoredPlayersConfig()
    ImGui.Text('Ignored Players:')
    Module.TempSettings.NewIgnoredPlayer = Module.TempSettings.NewIgnoredPlayer or ''
    local newPlayer, entered = ImGui.InputText('Add Ignored Player##IgnoredPlayerInput',
        Module.TempSettings.NewIgnoredPlayer, ImGuiInputTextFlags.EnterReturnsTrue)
    if entered then
        Module:AddIgnorePCtoDB(newPlayer)
        Module.TempSettings.NewIgnoredPlayer = ''
    else
        Module.TempSettings.NewIgnoredPlayer = newPlayer
    end
    ImGui.Separator()
    if ImGui.BeginTable('IgnoredPlayersTable##IgnoredPlayersTable', 2, ImGuiTableFlags.Borders) then
        ImGui.TableSetupColumn('Player Name', ImGuiTableColumnFlags.WidthStretch)
        ImGui.TableSetupColumn('Actions', ImGuiTableColumnFlags.WidthFixed, 100)
        ImGui.TableHeadersRow()
        for i, player in ipairs(settings.Ignore or {}) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn(); ImGui.Text(player)
            ImGui.TableNextColumn()
            if ImGui.SmallButton('Delete##IgnoredPlayerDelete' .. i) then Module:RemoveIgnoredPC(player) end
        end
        ImGui.EndTable()
    end
end

local function DrawSoundRow(label, doFlag, flagKey, sndVar, sndKey, volVar, volKey)
    ImGui.SeparatorText(label .. '##AlertMaster')
    local tmpDo = Module.Utils.DrawToggle(label .. '##AlertMaster', doFlag, ToggleFlags, ImVec2(40, 16))
    if tmpDo ~= doFlag then
        Module.Settings[CharConfig][flagKey] = tmpDo
        save_settings()
    end
    ImGui.SameLine(); ImGui.SetNextItemWidth(70)
    local tmpSnd = ImGui.InputText('Filename##' .. flagKey, sndVar)
    ImGui.SameLine(); ImGui.SetNextItemWidth(100)
    local tmpVol = ImGui.InputFloat('Volume##' .. flagKey, volVar, 0.1)
    ImGui.SameLine()
    if ImGui.Button('Test and Save##' .. flagKey) then
        setVolume(tmpVol); playSound(tmpSnd)
        Module.Settings[CharConfig][volKey] = tmpVol
        Module.Settings[CharConfig][sndKey] = tmpSnd
        save_settings()
    end
    return tmpDo, tmpSnd, tmpVol
end

-- ---------------------------------------------------------------------------
-- GUI: windows
-- ---------------------------------------------------------------------------

local function BuildAlertRows()
    if zone_id ~= Zone.ID() then return end
    if ImGui.BeginTable('AlertTable', 4, Module.GUI_Alert.Table.Flags) then
        ImGui.TableSetupScrollFreeze(0, 1)
        local col = Module.GUI_Alert.Table.Column_ID
        ImGui.TableSetupColumn('Name', bit32.bor(ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.WidthFixed), 90, col.MobName)
        ImGui.TableSetupColumn('Lvl', bit32.bor(ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.WidthFixed), 30, col.MobLvl)
        ImGui.TableSetupColumn('Dist', bit32.bor(ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.WidthFixed), 50, col.MobDist)
        ImGui.TableSetupColumn('Dir', bit32.bor(ImGuiTableColumnFlags.NoResize, ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.NoSort), 30, col.MobDirection)
        ImGui.TableHeadersRow()

        local sortSpecs = ImGui.TableGetSortSpecs()
        if sortSpecs and (sortSpecs.SpecsDirty or Module.GUI_Alert.Refresh.Sort.Rules) then
            if #Table_Cache.Alerts > 0 then
                Module.GUI_Alert.Table.SortSpecs = sortSpecs
                table.sort(Table_Cache.Alerts, AlertTableSortSpecs)
                Module.GUI_Alert.Table.SortSpecs = nil
            end
            sortSpecs.SpecsDirty = false
            Module.GUI_Alert.Refresh.Sort.Rules = false
        end

        local clipper = ImGuiListClipper.new()
        clipper:Begin(#Table_Cache.Alerts)
        while clipper:Step() do
            for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                local entry = Table_Cache.Alerts[i + 1]
                ImGui.PushID(entry.ID); ImGui.TableNextRow()
                DrawAlertRuleRow(entry)
                ImGui.PopID()
            end
        end
        clipper:End()
        ImGui.EndTable()
    end
end

local function DrawAlertGUI()
    if not AlertWindowOpen then return end
    if currZone ~= lastZone then return end
    local colorCount, styleCount = Module.ThemeLoader.StartTheme(useThemeName, Module.Theme)
    local open, show = ImGui.Begin('Alert Window##' .. Module.CharLoaded, true, Module.GUI_Alert.Flags)
    if not open then AlertWindowOpen = false end
    if show then BuildAlertRows() end
    Module.ThemeLoader.EndTheme(colorCount, styleCount)
    ImGui.End()
end

local function DrawSearchWindow()
    if currZone ~= lastZone then return end
    if not SearchWindowOpen then return end

    local flags = Module.GUI_Main.Flags
    if Module.GUI_Main.Locked then
        flags = bit32.bor(flags, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize)
    else
        flags = bit32.band(flags, bit32.bnot(ImGuiWindowFlags.NoMove), bit32.bnot(ImGuiWindowFlags.NoResize))
    end

    local colorCount, styleCount = Module.ThemeLoader.StartTheme(useThemeName, Module.Theme)
    local open, show = ImGui.Begin('Alert Master##' .. Module.CharLoaded, true, flags)
    if not open then SearchWindowOpen = false end

    if show then
        ImGui.BeginMenuBar()
        DrawButtonToggles()
        ImGui.EndMenuBar()
        ImGui.Separator()

        -- Zone tab / NPC list tab switcher
        if ImGui.Button(Zone.Name(), 160, 0.0) then
            currentTab = 'zone'; Module:RefreshZone()
        end
        if ImGui.IsItemHovered() and showTooltips then
            ImGui.SetTooltip(string.format('Zone Short Name: %s\nSpawn Count: %s', Zone.ShortName(), tostring(#Table_Cache.Unhandled)))
        end
        ImGui.SameLine()
        local tabLabel = 'NPC List'
        if next(spawnAlerts) ~= nil then
            tabLabel = Module.Icons.FA_BULLHORN .. ' NPC List ' .. Module.Icons.FA_BULLHORN
            ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('btn_red'))
        else
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.4, 0.8, 0.4)
        end
        if ImGui.Button(tabLabel) then currentTab = 'npcList' end
        ImGui.PopStyleColor(1)

        -- Zone NPC table
        if currentTab == 'zone' then
            if ImGui.BeginTabBar('Spawns##Tabs') then
                if ImGui.BeginTabItem(string.format("NPC's (%s)###NpcTabLabel", #Table_Cache.Unhandled)) then
                    local searchText, changed = ImGui.InputText('Search##RulesSearch', Module.GUI_Main.Search)
                    if changed and Module.GUI_Main.Search ~= searchText then
                        Module.GUI_Main.Search                  = searchText
                        Module.GUI_Main.Refresh.Sort.Rules      = true
                        Module.GUI_Main.Refresh.Table.Unhandled = true
                    end
                    ImGui.SameLine()
                    if ImGui.Button('Clear##ClearRulesSearch') then
                        Module.GUI_Main.Search                  = ''
                        Module.GUI_Main.Refresh.Sort.Rules      = false
                        Module.GUI_Main.Refresh.Table.Unhandled = true
                    end
                    ImGui.Separator()

                    if ImGui.BeginTable('##RulesTable', 8, Module.GUI_Main.Table.Flags) then
                        ImGui.TableSetupScrollFreeze(0, 1)
                        local col = Module.GUI_Main.Table.Column_ID
                        ImGui.TableSetupColumn(Module.Icons.FA_USER_PLUS, bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.NoSort), 15, col.Remove)
                        ImGui.TableSetupColumn('Name', bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.DefaultSort), 120, col.MobName)
                        ImGui.TableSetupColumn('Lvl', bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.DefaultSort), 30, col.MobLvl)
                        ImGui.TableSetupColumn('Dist', bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.DefaultSort), 40, col.MobDist)
                        ImGui.TableSetupColumn('Aggro', bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.DefaultSort), 30, col.MobAggro)
                        ImGui.TableSetupColumn('ID', bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.DefaultSort), 30, col.MobID)
                        ImGui.TableSetupColumn('Loc', bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.NoSort), 90, col.MobLoc)
                        ImGui.TableSetupColumn(Module.Icons.FA_COMPASS, bit32.bor(ImGuiTableColumnFlags.NoResize, ImGuiTableColumnFlags.NoSort, ImGuiTableColumnFlags.WidthFixed), 15,
                            col.MobDirection)
                        ImGui.TableHeadersRow()

                        local sortSpecs = ImGui.TableGetSortSpecs()
                        if sortSpecs and (sortSpecs.SpecsDirty or Module.GUI_Main.Refresh.Sort.Rules) then
                            if #Table_Cache.Unhandled > 0 then
                                Module.GUI_Main.Table.SortSpecs = sortSpecs
                                table.sort(Table_Cache.Unhandled, TableSortSpecs)
                                Module.GUI_Main.Table.SortSpecs = nil
                            end
                            sortSpecs.SpecsDirty = false
                            Module.GUI_Main.Refresh.Sort.Rules = false
                        end

                        local clipper = ImGuiListClipper.new()
                        clipper:Begin(#Table_Cache.Unhandled)
                        while clipper:Step() do
                            for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                                local entry = Table_Cache.Unhandled[i + 1]
                                ImGui.PushID(entry.ID); ImGui.TableNextRow()
                                DrawRuleRow(entry)
                                ImGui.PopID()
                            end
                        end
                        clipper:End()
                        ImGui.EndTable()
                    end
                    ImGui.EndTabItem()
                end

                if ImGui.BeginTabItem(string.format('Players (%s)###PCTabLabel', numDisplayPlayers)) then
                    if ImGui.BeginTable('PlayersInZone###PCTable', 4, Module.GUI_Main.Table.Flags) then
                        ImGui.TableSetupScrollFreeze(0, 1)
                        ImGui.TableSetupColumn('Name', ImGuiTableColumnFlags.WidthFixed, 120)
                        ImGui.TableSetupColumn('Guild', ImGuiTableColumnFlags.WidthFixed, 100)
                        ImGui.TableSetupColumn('Level', ImGuiTableColumnFlags.WidthFixed, 50)
                        ImGui.TableSetupColumn('Distance', ImGuiTableColumnFlags.WidthFixed, 70)
                        ImGui.TableHeadersRow()
                        for _, player in pairs(displayTablePlayers) do
                            ImGui.TableNextRow()
                            ImGui.TableNextColumn(); ImGui.TextColored(ImVec4(0, 1, 1, 1), player.tblName or 'N/A')
                            ImGui.TableNextColumn(); ImGui.TextColored(ImVec4(1, 1, 0, 1), player.tblGuild or 'N/A')
                            ImGui.TableNextColumn(); ImGui.Text('%s', player.level or 'N/A')
                            ImGui.TableNextColumn(); ImGui.Text('%0.1f', player.distance or 9999)
                        end
                        ImGui.EndTable()
                    end
                    ImGui.EndTabItem()
                end
                ImGui.EndTabBar()
            end

            -- NPC watch-list tab
        elseif currentTab == 'npcList' then
            if #Module.TempSettings.NpcList == 0 then
                local db = Module:OpenDB()
                Module.TempSettings.NpcList = Module:GetSpawns(Zone.ShortName(), db)
            end

            ImGui.SetNextItemWidth(160)
            local changed
            newSpawnName, changed = ImGui.InputText('##NewSpawnName', newSpawnName, 256)
            if ImGui.IsItemHovered() and showTooltips then
                ImGui.SetTooltip('Enter Spawn Name (case-sensitive).\nAlso accepts variables like ${Target.DisplayName}.')
            end
            ImGui.SameLine()
            if ImGui.Button(Module.Icons.FA_USER_PLUS) and newSpawnName ~= '' then
                Module:AddSpawnToList(newSpawnName)
                newSpawnName = ''
            end
            if ImGui.IsItemHovered() and showTooltips then ImGui.SetTooltip('Add to SpawnList') end

            ImGui.SameLine()
            if haveSM and ImGui.Button('Import Zone##ImportSM') then
                forceImport = true; importZone = true
                check_for_spawns()
            end

            -- Build sorted list: live alerts first, then alphabetical
            local sortedNpcs = {}
            for _, spawnName in ipairs(Module.TempSettings.NpcList) do
                table.insert(sortedNpcs, { name = spawnName, isInAlerts = isSpawnInAlerts(spawnName, spawnAlerts), })
            end
            table.sort(sortedNpcs, function(a, b)
                if a.isInAlerts ~= b.isInAlerts then return a.isInAlerts end
                return a.name < b.name
            end)

            if next(sortedNpcs) ~= nil then
                if ImGui.BeginTable('NPCListTable', 3, spawnListFlags) then
                    ImGui.TableSetupScrollFreeze(0, 1)
                    ImGui.TableSetupColumn('NPC Name##AMList')
                    ImGui.TableSetupColumn('Zone##AMList')
                    ImGui.TableSetupColumn(' ' .. btnIconDel .. '##AMList',
                        bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.NoSort, ImGuiTableColumnFlags.NoResize), 20)
                    ImGui.TableHeadersRow()
                    for index, npc in ipairs(sortedNpcs) do
                        local spawnName   = npc.name
                        local displayName = spawnName:gsub('_', ' '):gsub('%d*$', '')
                        ImGui.TableNextRow()
                        ImGui.TableNextColumn()
                        if npc.isInAlerts then ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1) end
                        ImGui.Text(displayName)
                        if npc.isInAlerts then
                            ImGui.PopStyleColor()
                            if ImGui.IsItemHovered() then
                                if showTooltips then
                                    ImGui.SetTooltip('Green Names are up!\nRight-Click to Navigate.\nCtrl+Right-Click to Group Navigate.')
                                end
                                if ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsMouseReleased(1) then
                                    mq.cmdf('/noparse %s/docommand /timed ${Math.Rand[10,60]} /nav spawn "%s"', groupCmd, spawnName)
                                elseif ImGui.IsMouseReleased(1) then
                                    mq.cmdf('/nav spawn "%s"', spawnName)
                                end
                            end
                        end
                        ImGui.TableNextColumn(); ImGui.Text(Zone.ShortName())
                        ImGui.TableNextColumn()
                        if ImGui.SmallButton(btnIconDel .. '##AM_Remove' .. index) then
                            mq.cmdf('/alertmaster spawndel "' .. spawnName .. '"')
                        end
                        if ImGui.IsItemHovered() and showTooltips then ImGui.SetTooltip('Delete Spawn From SpawnList') end
                    end
                    ImGui.EndTable()
                end
            else
                ImGui.Text('No spawns in list for this zone. Add some!')
            end
        end
    end

    Module.ThemeLoader.EndTheme(colorCount, styleCount)
    ImGui.End()
end

local function Config_GUI()
    if not openConfigGUI then return end
    local colorCount, styleCount = Module.ThemeLoader.StartTheme(useThemeName, Module.Theme)
    local open, show = ImGui.Begin('Alert master Config', true, bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.NoCollapse))
    if not open then openConfigGUI = false end

    if show then
        if ImGui.CollapsingHeader('Theme Settings##AlertMaster') then
            ImGui.Text('Cur Theme: %s', useThemeName)
            if ImGui.BeginCombo('Load Theme', useThemeName) then
                for _, data in pairs(Module.Theme.Theme) do
                    local isSelected = data.Name == useThemeName
                    if ImGui.Selectable(data.Name, isSelected) then
                        Module.Theme.LoadTheme               = data.Name
                        useThemeName                         = data.Name
                        Module.Settings[CharConfig]['theme'] = useThemeName
                        save_settings()
                    end
                end
                ImGui.EndCombo()
            end
            local tmpZoom = ImGui.SliderFloat('Text Scaling', ZoomLvl, 0.5, 2.0)
            if tmpZoom ~= ZoomLvl then
                ZoomLvl = tmpZoom
                Module.Settings[CharConfig]['ZoomLvl'] = ZoomLvl
            end
            if ImGui.Button('Reload Theme File') then load_settings() end
            ImGui.SameLine()
            if loadedExternally and ImGui.Button('Edit ThemeZ') then
                ---@diagnostic disable-next-line:undefined-global
                if MyUI.Modules.ThemeZ ~= nil then
                    if MyUI.Modules.ThemeZ.IsRunning then
                        MyUI.Modules.ThemeZ.ShowGui = true
                    else
                        MyUI.TempSettings.ModuleChanged = true
                        MyUI.TempSettings.ModuleName    = 'ThemeZ'
                        MyUI.TempSettings.ModuleEnabled = true
                    end
                else
                    MyUI.TempSettings.ModuleChanged = true
                    MyUI.TempSettings.ModuleName    = 'ThemeZ'
                    MyUI.TempSettings.ModuleEnabled = true
                end
            end
        end

        if ImGui.CollapsingHeader('Toggles##AlertMaster') then
            if ImGui.BeginTable('##ToggleTable', 2, ImGuiTableFlags.Resizable) then
                ImGui.TableSetupColumn('##ToggleCol1')
                ImGui.TableSetupColumn('##ToggleCol2')
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                for k, v in pairs(Module.Settings[CharConfig]) do
                    if type(v) == 'boolean' then
                        ImGui.PushID(k)
                        local newVal, pressed = Module.Utils.DrawToggle(k, v, ToggleFlags, ImVec2(40, 16))
                        Module.Settings[CharConfig][k] = newVal
                        if pressed then
                            set_settings(); save_settings()
                        end
                        ImGui.TableNextColumn()
                        ImGui.PopID()
                    end
                end
                ImGui.EndTable()
            end
        end

        if ImGui.CollapsingHeader('Sounds##AlertMaster') then
            doSoundGM, soundGM, volGM                      = DrawSoundRow('GM Alert', doSoundGM, 'doSoundGM', soundGM, 'soundGM', volGM, 'volGM')
            doSoundPC, soundPC, volPC                      = DrawSoundRow('PC Alert', doSoundPC, 'doSoundPC', soundPC, 'soundPC', volPC, 'volPC')
            doSoundPCEntered, soundPCEntered, volPCEntered = DrawSoundRow('PC Entered', doSoundPCEntered, 'doSoundPCEntered', soundPCEntered, 'soundPCEntered', volPCEntered,
                'volPCEntered')
            doSoundPCLeft, soundPCLeft, volPCLeft          = DrawSoundRow('PC Left', doSoundPCLeft, 'doSoundPCLeft', soundPCLeft, 'soundPCLeft', volPCLeft, 'volPCLeft')
            doSoundNPC, soundNPC, volNPC                   = DrawSoundRow('NPC Alert', doSoundNPC, 'doSoundNPC', soundNPC, 'soundNPC', volNPC, 'volNPC')
        end

        if ImGui.CollapsingHeader('Commands') then
            if ImGui.BeginTable('CommandTable', 2, ImGuiTableFlags.Resizable) then
                ImGui.TableSetupColumn('Command')
                ImGui.TableSetupColumn('Text')
                for key, command in pairs(Module.Settings[CharCommands]) do
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn(); ImGui.Text(key)
                    ImGui.TableNextColumn()
                    local tmpCmd = ImGui.InputText('##' .. key, command)
                    if tmpCmd ~= command then
                        Module.Settings[CharCommands][key] = (tmpCmd == '' or tmpCmd == nil) and nil or tmpCmd
                        save_settings()
                    end
                end
                ImGui.EndTable()
            end
        end

        if ImGui.CollapsingHeader('Safe Zones##AlertMaster') then Module:DrawSafeZoneConfig() end
        if ImGui.CollapsingHeader('Ignored Players##AlertMaster') then Module:DrawIgnoredPlayersConfig() end

        if ImGui.Button('Save & Close') then
            openConfigGUI                          = false
            Module.Settings[CharConfig]['theme']   = useThemeName
            Module.Settings[CharConfig]['ZoomLvl'] = ZoomLvl
            save_settings()
        end
    end

    Module.ThemeLoader.EndTheme(colorCount, styleCount)
    ImGui.End()
end


function Module.RenderGUI()
    ImGui.PushFont(nil, ImGui.GetFontSize() * ZoomLvl)
    DrawSearchWindow()
    DrawAlertGUI()
    Config_GUI()
    ImGui.PopFont()
end

-- ---------------------------------------------------------------------------
-- Commands
-- TODO: Cleanup binds so they can be setup in a for loop
-- this should make less writing out each and every bind.
-- ---------------------------------------------------------------------------

local function load_binds()
    local function bind_alertmaster(cmd, val)
        local zone    = Zone.ShortName()
        local val_num = tonumber(val, 10)
        local val_str = tostring(val):gsub('"', '')

        if cmd == 'on' then
            active = true
            Module.Utils.PrintOutput('AlertMaster', nil, '\ayAlert Master enabled.')
        elseif cmd == 'off' then
            active = false
            tGMs, tAnnounce, tPlayers, tSpawns = {}, {}, {}, {}
            Module.Utils.PrintOutput('AlertMaster', nil, '\ayAlert Master disabled.')
        end

        if cmd == 'quit' or cmd == 'exit' then
            Module.IsRunning = false
            Module.Utils.PrintOutput('AlertMaster', nil, '\ayAlert Master\ao Shutting Down.')
            return
        end

        if cmd == 'popup' then
            AlertWindowOpen = not AlertWindowOpen
            Module.Utils.PrintOutput('AlertMaster', nil, AlertWindowOpen and '\ayShowing Alert Window.' or '\ayClosing Alert Window.')
        end

        if cmd == 'show' then
            if SearchWindowOpen then
                SearchWindowOpen = false
                Module.Utils.PrintOutput('AlertMaster', nil, '\ayClosing Search UI.')
            else
                Module:RefreshZone()
                SearchWindowOpen = true
                Module.Utils.PrintOutput('AlertMaster', nil, '\ayShowing Search UI.')
            end
        end

        if cmd == 'doalert' then
            doAlert = not doAlert
            Module.Settings[CharConfig]['popup'] = doAlert
            save_settings()
            Module.Utils.PrintOutput('AlertMaster', nil, doAlert and '\ayAlert PopUp Enabled.' or '\ayAlert PopUp Disabled.')
        end

        -- Toggle booleans (no arg): match cmd against settings keys by lowercase.
        -- doalert->popup is a key mismatch, handled explicitly above.
        if val_str == nil and val_num == nil then
            local cfg = Module.Settings[CharConfig]
            for key in pairs(cfg) do
                if type(cfg[key]) == 'boolean' and key:lower() == cmd then
                    cfg[key] = not cfg[key]
                    set_settings()
                    save_settings()
                    Module.Utils.PrintOutput('AlertMaster', nil, '\ay' .. key .. ' = ' .. tostring(cfg[key]))
                    break
                end
            end
        end

        -- Numeric settings: match cmd against settings keys (case-insensitive).
        -- vol* are excluded here because they have side effects handled below.
        local explicitCmds = { volnpc = true, volpc = true, volgm = true, }
        if val_num ~= nil and not explicitCmds[cmd] then
            local cfg = Module.Settings[CharConfig]
            for key in pairs(cfg) do
                if key:lower() == cmd then
                    local minVal = (cmd == 'remind' or cmd == 'remindnpc') and 0 or 1
                    if val_num >= minVal then
                        cfg[key] = val_num
                        set_settings()
                        save_settings()
                        Module.Utils.PrintOutput('AlertMaster', nil, '\ay' .. key .. ' = ' .. val_num)
                    end
                    break
                end
            end
        end

        if cmd == 'volnpc' and val_num and val_num > 0 then
            volNPC = val_num; Module.Settings[CharConfig]['volNPC'] = volNPC
            save_settings(); setVolume(volNPC); playSound(soundNPC)
            Module.Utils.PrintOutput('AlertMaster', nil, '\ayNPC Volume = ' .. volNPC)
        end

        if cmd == 'volpc' and val_num and val_num > 0 then
            volPC = val_num; Module.Settings[CharConfig]['volPC'] = volPC
            save_settings(); setVolume(volPC); playSound(soundPC)
            Module.Utils.PrintOutput('AlertMaster', nil, '\ayPC Volume = ' .. volPC)
        end

        if cmd == 'volgm' and val_num and val_num > 0 then
            volGM = val_num; Module.Settings[CharConfig]['volGM'] = volGM
            save_settings(); setVolume(volGM); playSound(soundGM)
            Module.Utils.PrintOutput('AlertMaster', nil, '\ayGM Volume = ' .. volGM)
        end

        if cmd == 'dosound' and val_str ~= nil then
            if val_str == 'npc' then
                doSoundNPC = not doSoundNPC
                Module.Settings[CharConfig]['doSoundNPC'] = doSoundNPC
                Module.Utils.PrintOutput('AlertMaster', nil, '\aySetting doSoundNPC = ' .. tostring(doSoundNPC))
            elseif val_str == 'pc' then
                doSoundPC = not doSoundPC
                Module.Settings[CharConfig]['doSoundPC'] = doSoundPC
                Module.Utils.PrintOutput('AlertMaster', nil, '\aySetting doSoundPC = ' .. tostring(doSoundPC))
            elseif val_str == 'gm' then
                doSoundGM = not doSoundGM
                Module.Settings[CharConfig]['doSoundGM'] = doSoundGM
                Module.Utils.PrintOutput('AlertMaster', nil, '\aySetting doSoundGM = ' .. tostring(doSoundGM))
            end
            save_settings()
        end

        if cmd == 'distfar' and val_num and val_num > 0 then
            DistColorRanges.red = val_num; Module.Settings[CharConfig]['distfar'] = DistColorRanges.red
            save_settings()
            Module.Utils.PrintOutput('AlertMaster', nil, '\arFar Range\a-t Greater than:\a-r' .. DistColorRanges.red .. '\ax')
        end

        if cmd == 'distmid' and val_num and val_num > 0 then
            DistColorRanges.orange = val_num; Module.Settings[CharConfig]['distmid'] = DistColorRanges.orange
            save_settings()
            Module.Utils.PrintOutput('AlertMaster', nil, '\aoMid Range\a-t Between: \a-g' .. DistColorRanges.orange .. ' \a-tand \a-r' .. DistColorRanges.red .. '\ax')
        end

        if cmd == 'reload' then
            load_settings()
            Module.Utils.PrintOutput('AlertMaster', nil, '\ayReloading Settings from File!')
        end

        -- On/off booleans: match cmd against settings keys by lowercase.
        -- gm->gms is a key mismatch, handled explicitly below.
        if val_str == 'on' or val_str == 'off' then
            local cfg = Module.Settings[CharConfig]
            for key in pairs(cfg) do
                if type(cfg[key]) == 'boolean' and key:lower() == cmd then
                    cfg[key] = (val_str == 'on')
                    set_settings()
                    save_settings()
                    Module.Utils.PrintOutput('AlertMaster', nil, '\ay' .. key .. ' ' .. val_str)
                    break
                end
            end
        end

        if cmd == 'spawnadd' then
            if val_str == nil or val_str == 'nil' then
                if mq.TLO.Target() ~= nil and mq.TLO.Target.Type() == 'NPC' then
                    val_str = mq.TLO.Target.DisplayName()
                else
                    Module.Utils.PrintOutput('AlertMaster', true, '\arNO \aoSpawn supplied\aw or \agTarget')
                    return
                end
            end
            Module:AddSpawnToList(val_str)
        elseif cmd == 'spawndel' and val_str and #val_str > 0 then
            Module:DeleteSpawnFromDB(zone, val_str)
            local db = Module:OpenDB()
            Module.TempSettings.NpcList = Module:GetSpawns(Zone.ShortName(), db)
        elseif cmd == 'spawnlist' then
            Module.Utils.PrintOutput('AlertMaster', nil, '\aySpawn Alerts (\a-t' .. zone .. '\ax): ')
            local db = Module:OpenDB()
            local list = Module:GetSpawns(zone, db)
            for _, name in ipairs(list) do
                local up = false
                for _, s in pairs(tSpawns) do
                    if s ~= nil and s.DisplayName == name then
                        up = true; break
                    end
                end
                if up then
                    Module.Utils.PrintOutput('AlertMaster', nil, string.format('\ag[Live] %s\ax', name))
                else
                    Module.Utils.PrintOutput('AlertMaster', nil, string.format('\a-t[Dead] %s\ax', name))
                end
            end
        end

        -- Command management
        local cmdCount = 0
        for _ in pairs(Module.Settings[CharCommands]) do cmdCount = cmdCount + 1 end

        if cmd == 'cmdadd' and val_str and #val_str > 0 then
            if Module.Settings[CharCommands] == nil then Module.Settings[CharCommands] = {} end
            for _, v in pairs(Module.Settings[CharCommands]) do
                if v == val_str then
                    Module.Utils.PrintOutput('AlertMaster', nil, '\ayCommand "' .. val_str .. '" already exists.')
                    return
                end
            end
            Module.Settings[CharCommands]['Cmd' .. cmdCount + 1] = val_str
            save_settings()
            Module.Utils.PrintOutput('AlertMaster', nil, '\ayAdded Command "' .. val_str .. '"')
        elseif cmd == 'cmddel' and val_str and #val_str > 0 then
            for k, v in pairs(Module.Settings[CharCommands]) do
                if k:lower() == val_str:lower() or v == val_str then
                    Module.Settings[CharCommands][k] = nil; break
                end
            end
            save_settings()
            Module.Utils.PrintOutput('AlertMaster', nil, '\ayRemoved Command "' .. val_str .. '"')
        elseif cmd == 'cmdlist' then
            if cmdCount > 0 then
                Module.Utils.PrintOutput('AlertMaster', nil, '\ayCommands (\a-t' .. Module.CharLoaded .. '\ax): ')
                for k, v in pairs(Module.Settings[CharCommands]) do
                    Module.Utils.PrintOutput('AlertMaster', nil, '\t\a-t' .. k .. ' - ' .. v)
                end
            else
                Module.Utils.PrintOutput('AlertMaster', nil, '\ayCommands (\a-t' .. Module.CharLoaded .. '\ax): No commands configured.')
            end
        end

        -- Ignore list management
        if cmd == 'ignoreadd' and val_str and #val_str > 0 then
            local result = Module:AddIgnorePCtoDB(val_str)
            Module.Utils.PrintOutput('AlertMaster', nil, result and '\ayNow ignoring "' .. val_str .. '"' or '\ayAlready ignoring "' .. val_str .. '".')
        elseif cmd == 'ignoredel' and val_str and #val_str > 0 then
            local result = Module:RemoveIgnoredPC(val_str)
            Module.Utils.PrintOutput('AlertMaster', nil, result and '\ayNo longer ignoring "' .. val_str .. '"' or '\ay"' .. val_str .. '" was not being ignored.')
        elseif cmd == 'ignorelist' then
            Module.Utils.PrintOutput('AlertMaster', nil, '\ayIgnore List (\a-t' .. Module.CharLoaded .. '\ax): ')
            for i, v in ipairs(settings.Ignore or {}) do
                if v ~= nil then Module.Utils.PrintOutput('AlertMaster', nil, '\t\a-t' .. i .. ' - ' .. v) end
            end
        end

        if cmd == 'announce' then
            if val_str == 'on' then
                announce = true; Module.Settings[CharConfig]['announce'] = true; save_settings()
                Module.Utils.PrintOutput('AlertMaster', nil, '\ayNow announcing players entering/exiting the zone.')
            elseif val_str == 'off' then
                announce = false; Module.Settings[CharConfig]['announce'] = false; save_settings()
                Module.Utils.PrintOutput('AlertMaster', nil, '\ayNo longer announcing players entering/exiting the zone.')
            end
        end

        if cmd == 'gm' then
            if val_str == 'on' then
                gms = true; Module.Settings[CharConfig]['gms'] = true; save_settings()
                Module.Utils.PrintOutput('AlertMaster', nil, '\ayGM Alerts enabled.')
            elseif val_str == 'off' then
                gms = false; Module.Settings[CharConfig]['gms'] = false; save_settings()
                Module.Utils.PrintOutput('AlertMaster', nil, '\ayGM Alerts disabled.')
            end
        end

        if cmd == 'status' then print_status() end

        if cmd == nil or cmd == 'help' then
            local P = function(s) Module.Utils.PrintOutput('AlertMaster', nil, s) end
            P('\ayAlert Master Usage:')
            P('\a-y- General -')
            P('\t\ay/alertmaster status\a-t -- print current status/settings')
            P('\t\ay/alertmaster help\a-t -- print this help')
            P('\t\ay/alertmaster on|off\a-t -- toggle all alerts')
            P('\t\ay/alertmaster gm on|off\a-t -- toggle GM alerts')
            P('\t\ay/alertmaster pcs on|off\a-t -- toggle PC alerts')
            P('\t\ay/alertmaster spawns on|off\a-t -- toggle spawn alerts')
            P('\t\ay/alertmaster beep\a-t -- toggle audible beep alerts')
            P('\t\ay/alertmaster doalert\a-t -- toggle popup alerts')
            P('\t\ay/alertmaster announce on|off\a-t -- toggle zone entry/exit announcements')
            P('\t\ay/alertmaster radius #\a-t -- set alert radius')
            P('\t\ay/alertmaster zradius #\a-t -- set alert z-radius')
            P('\t\ay/alertmaster delay #\a-t -- set alert check delay (seconds)')
            P('\t\ay/alertmaster remind #\a-t -- set player/GM reminder interval (seconds)')
            P('\t\ay/alertmaster remindnpc #\a-t -- set NPC reminder interval (minutes)')
            P('\t\ay/alertmaster popup\a-t -- show/hide alert window')
            P('\t\ay/alertmaster reload\a-t -- reload config file')
            P('\t\ay/alertmaster distmid #\a-t -- green->orange distance threshold')
            P('\t\ay/alertmaster distfar #\a-t -- orange->red distance threshold')
            P('\a-y- Sounds -')
            P('\t\ay/alertmaster dosound pc|npc|gm\a-t -- toggle custom sound alerts')
            P('\t\ay/alertmaster volpc 1-100\a-t -- set PC sound volume')
            P('\t\ay/alertmaster volnpc 1-100\a-t -- set NPC sound volume')
            P('\t\ay/alertmaster volgm 1-100\a-t -- set GM sound volume')
            P('\a-y- Ignore List -')
            P('\t\ay/alertmaster ignoreadd pcname\a-t -- add PC to ignore list')
            P('\t\ay/alertmaster ignoredel pcname\a-t -- remove PC from ignore list')
            P('\t\ay/alertmaster ignorelist\a-t -- display ignore list')
            P('\a-y- Spawns -')
            P('\t\ay/alertmaster spawnadd npc\a-t -- add NPC to tracked spawns')
            P('\t\ay/alertmaster spawndel npc\a-t -- remove NPC from tracked spawns')
            P('\t\ay/alertmaster spawnlist\a-t -- list tracked spawns for current zone')
            P('\t\ay/alertmaster show\a-t -- toggle search window')
            P('\t\ay/alertmaster aggro\a-t -- toggle aggro bars in search window')
            P('\a-y- Commands -')
            P('\t\ay/alertmaster cmdadd command\a-t -- add command to run on PC alert')
            P('\t\ay/alertmaster cmddel command\a-t -- remove command')
            P('\t\ay/alertmaster cmdlist\a-t -- list configured commands')
        end
    end

    mq.bind('/alertmaster', bind_alertmaster)
end

-- ---------------------------------------------------------------------------
-- TLO
-- ---------------------------------------------------------------------------

---@class AlertMasterDataType
---@field IsNamed boolean
---@field IsActive boolean
---@type DataType
local alertMasterDataType = mq.DataType.new('AlertMaster', {
    Members = {
        IsNamed = function(param, self)
            if param and param:len() > 0 then
                return 'bool', isSpawnInAlerts(param, spawnAlerts) or false
            end
            return 'bool', false
        end,

        IsActive = function(param, self)
            return 'bool', active
        end,
    },
    ToString = function(self)
        return 'AlertMaster'
    end,
})

function AlertMasterTLOHandler(param)
    return alertMasterDataType, active
end

mq.AddTopLevelObject('AlertMaster', AlertMasterTLOHandler)


local function setup()
    if mq.TLO.EverQuest.GameState() ~= 'INGAME' then
        printf('\aw[\at%s\ax] \arNot in game, \ayTry again later...', Module.Name)
        mq.exit()
    end

    originalVolume = getVolume()
    active         = true
    radius         = tonumber(scriptArgs[1]) or 200
    zradius        = tonumber(scriptArgs[2]) or 100
    currZone       = mq.TLO.Zone.ID()
    lastZone       = mq.TLO.Zone.ID()

    if mq.TLO.Plugin('mq2eqbc').IsLoaded() then groupCmd = '/bcaa /' end

    load_settings()
    load_binds()
    Module:MessageHandler()

    Module.GUI_Main.Refresh.Table.Rules     = true
    Module.GUI_Main.Refresh.Table.Filtered  = true
    Module.GUI_Main.Refresh.Table.Unhandled = true

    Module.Utils.PrintOutput('AlertMaster', false,
        '\ayAlert Master version:\a-g' .. amVer ..
        '\n' .. MsgPrefix() .. '\ayOriginal by (\a-to_O\ay) Special.Ed (\a-tO_o\ay)' ..
        '\n' .. MsgPrefix() .. '\ayUpdated by (\a-tO_o\ay) Grimmier (\a-to_O\ay)')
    Module.Utils.PrintOutput('AlertMaster', false, '\ay/alertmaster help for usage')
    print_status()

    Module:RefreshZone()
    Module.IsRunning = true
    check_for_pcs()
    check_for_gms()
    check_for_announce()
    check_for_spawns()

    if not loadedExternally then
        mq.imgui.init(Module.Name, Module.RenderGUI)
        Module.LocalLoop()
    end
end

function Module.MainLoop()
    currZone = mq.TLO.Zone.ID()

    if currZone ~= lastZone then
        numAlerts = 0
        lastZone = mq.TLO.Zone.ID()
        check_for_zone_change()
        Module:RefreshZone()
    end

    if loadedExternally then
        ---@diagnostic disable-next-line:undefined-global
        if not MyUI.LoadModules.CheckRunning(Module.IsRunning, Module.Name) then
            mq.RemoveTopLevelObject('AlertMaster')
            mq.unbind('/alertmaster')
            return
        end
    end

    check_for_pcs()
    check_for_gms()
    check_for_announce()
    check_for_spawns()

    if Module.DirtyFilthyDB then
        local db           = Module:OpenDB()
        settings.Ignore    = Module:GetIgnoredPlayers(db)
        settings.SafeZones = Module:GetSafeZones(db)
        tSafeZones         = {}
        for _, v in ipairs(settings.SafeZones or {}) do tSafeZones[v] = true end
        Module.DirtyFilthyDB = false
    end

    -- NPC remind pulse: re-announce and re-open popup after remindNPC minutes
    local now = os.time()
    if not check_safe_zone() and numAlerts > 0 and (now - alertTime) > (remindNPC * 60) then
        for _, v in pairs(tSpawns) do
            if v ~= nil then
                local dist = math.floor(v.Spawn.Distance() or 0)
                Module.Utils.PrintOutput('AlertMaster', nil, GetCharZone() .. '\ag' .. (v.DisplayName or 'Unknown') .. '\ax spawn alert! ' .. dist .. ' units away.')
            end
        end
        if doSoundNPC then
            setVolume(volNPC); playSound(soundNPC)
        elseif doBeep then
            mq.cmdf('/beep')
        end
        if doAlert and not AlertWindowOpen then AlertWindowOpen = true end
        alertTime = now
    end

    -- Sound auto-reset after 2 seconds
    if playing and playTime > 0 and (os.time() - playTime) > 2 then resetVolume() end
    -- Track external volume changes
    if not playing and playTime == 0 then originalVolume = getVolume() end

    if Module.TempSettings.SendNamed then
        local db = Module:OpenDB()
        if amActor ~= nil then
            amActor:send({ mailbox = Module.TempSettings.ReplyTo, absolute_mailbox = true, }, {
                Who       = Module.CharLoaded,
                NamedList = Module:GetSpawns(Module.TempSettings.NamedZone, db) or {},
            })
        end
        Module.TempSettings.SendNamed = false
        Module.TempSettings.ReplyTo   = nil
        Module.TempSettings.NamedZone = nil
    end

    local now2 = os.time()
    if (#Table_Cache.Mobs < 1 or SearchWindowOpen) and (now2 - lastRefreshZoneTime) >= 5 then
        Module:RefreshZone()
        lastRefreshZoneTime = now2
    end
    if Module.GUI_Main.Refresh.Table.Unhandled then Module:RefreshUnhandled() end
end

function Module.LocalLoop()
    while Module.IsRunning do
        Module.MainLoop()
        mq.delay(delay .. 's')
    end
    Module.Unload()
end

function Module.Unload()
    Module:CloseDB()
    mq.unbind('/alertmaster')
    mq.RemoveTopLevelObject('AlertMaster')
end

setup()

return Module
