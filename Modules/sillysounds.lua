local mq = require('mq')
local ffi = require("ffi")
local ImGui = require('ImGui')
local Module = {}

Module.Name = "SillySounds"
Module.IsRunning = false
Module.Path = MyUI_Path ~= nil and MyUI_Path .. '/sounds/' or string.format("%s/%s/sounds/", mq.luaDir, Module.Name)

---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false

if not loadedExeternally then
    MyUI_Utils = require('lib.common')
    MyUI_Icons = require('mq.ICONS')
    MyUI_CharLoaded = mq.TLO.Me.DisplayName()
    MyUI_Server = mq.TLO.MacroQuest.Server()
end

local itemWatch = false

-- C code definitions for volume control
ffi.cdef [[
    int sndPlaySoundA(const char *pszSound, unsigned int fdwSound);
    uint32_t waveOutSetVolume(void* hwo, uint32_t dwVolume);
    uint32_t waveOutGetVolume(void* hwo, uint32_t* pdwVolume);
]]

local winmm = ffi.load("winmm")
local SND_ASYNC = 0x0001
local SND_FILENAME = 0x00020000
local flags = SND_FILENAME + SND_ASYNC
local originalVolume = 100
local soundDuration = 1
local timerPlay = 0
local playing = false

-- Main Settings
local configFile = string.format("%s/MyUI/%s/%s/%s.lua", mq.configDir, Module.Name, MyUI_Server, MyUI_CharLoaded)
local settings, defaults = {}, {}
local timerA, timerB = os.time(), os.time()
local openConfigGUI = false
local tmpTheme = 'default'
local alarmTagged = false

defaults = {
    doHit = true,
    doBonk = true,
    doLvl = true,
    doDie = true,
    doHP = true,
    doAA = true,
    doAlarm = true,
    doItem = true,
    doFizzle = true,
    volFizzle = 25,
    volAlarm = 25,
    volAA = 10,
    volHit = 2,
    volBonk = 5,
    volLvl = 100,
    volDie = 100,
    volItem = 100,
    volHP = 20,
    lowHP = 50,
    theme = 'default',
    Pulse = 1,
    ItemWatch = '',
    Sounds = {
        default = {
            soundHit = { file = "Hit.wav", duration = 2, },
            soundAlarm = { file = "Alarm.wav", duration = 5, },
            soundBonk = { file = "Bonk.wav", duration = 2, },
            soundLvl = { file = "LevelUp.wav", duration = 3, },
            soundDie = { file = "Die.wav", duration = 4, },
            soundLowHp = { file = "lowHP.wav", duration = 3, },
            soundAA = { file = "AA.wav", duration = 2, },
            soundFizzle = { file = 'Fizzle.wav', duration = 1, },
            soundItem = { file = 'Hit.wav', duration = 2, },
        },
    },
}

-- Function to play sound allowing for simultaneous plays
local function playSound(filename)
    if MyUI_Utils.File.Exists(filename) then
        timerPlay = os.time()
        playing = true
        winmm.sndPlaySoundA(filename, flags)
    else
        MyUI_Utils.PrintOutput('MyUI', nil, '\aySound File \aw[\ag%s\aw]\ao is MISSING!!\ax', filename)
    end
end

-- Function to get the current volume
local function getVolume()
    local pdwVolume = ffi.new("uint32_t[1]")
    winmm.waveOutGetVolume(nil, pdwVolume)
    return pdwVolume[0]
end

-- Function to set volume
local function setVolume(volume)
    if volume < 0 or volume > 100 then
        error("Volume must be between 0 and 100")
    end
    local vol = math.floor(volume / 100 * 0xFFFF)
    local leftRightVolume = bit32.bor(bit32.lshift(vol, 16), vol) -- Set both left and right volume
    winmm.waveOutSetVolume(nil, leftRightVolume)
end

local function eventSound(_, event, vol)
    if not settings["do" .. event] then return end
    local sound = settings.Sounds[settings.theme]["sound" .. event]
    if sound and settings["do" .. event] then
        soundDuration = sound.duration
        local fullPath = string.format("%s%s/%s", Module.Path, settings.theme, sound.file)
        setVolume(vol)
        timerPlay = os.time()
        playSound(fullPath)
    end
end

local function resetVolume()
    playing = false
    winmm.waveOutSetVolume(nil, originalVolume)
    timerPlay = 0
    mq.delay(100)
end

local function checkAlarms()
    if alarmTagged then return end
    local textOutput = mq.TLO.Window('ConfirmationDialogBox').Child('CD_TextOutput').Text()
    local sessionEnded = textOutput:match("Your session %(.-%) has ended%.")
    if sessionEnded then
        alarmTagged = true
        eventSound('', 'Alarm', settings.volAlarm)
        mq.TLO.Window('ConfirmationDialogBox').DoClose()
    end
end

local function eventItem(line)
    if not settings.doItem then return end
    eventSound('', 'Item', settings.volItem)
end

-- Settings
local function loadSettings()
    if not MyUI_Utils.File.Exists(configFile) then
        settings = defaults
        mq.pickle(configFile, settings)
        loadSettings()
    else
        settings = dofile(configFile)
        if not settings then
            settings = {}
            settings = defaults
        end
    end
    tmpTheme = settings.theme or 'default'
    local newSetting = false

    newSetting = MyUI_Utils.CheckDefaultSettings(defaults, settings) or newSetting
    newSetting = MyUI_Utils.CheckDefaultSettings(defaults.Sounds.default, settings.Sounds[settings.theme]) or newSetting

    -- check for missing sound files
    for k, v in pairs(settings.Sounds[settings.theme]) do
        if not MyUI_Utils.File.Exists(string.format("%s%s/%s", Module.Path, settings.theme, v.file)) then
            settings[k] = false
            MyUI_Utils.PrintOutput('MyUI', nil, "\aySound file %s missing!!\n\tTurning %s \arOFF", string.format("%s%s/%s", Module.Path, settings.theme, v.file), k)
        end
    end

    if settings.ItemWatch ~= '' then
        local eStr = string.format("#*#%s#*#", settings.ItemWatch)
        mq.event("item_added", eStr, eventItem)
        itemWatch = true
    end
    if newSetting then mq.pickle(configFile, settings) end
end

-- Print Help
local function helpList(type)
    if type == 'help' then
        MyUI_Utils.PrintOutput('MyUI', nil, '\ay%s Help\ax', Module.Name)
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds hit     \t \ag Toggles sound on and off for your hits\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds bonk    \t \ag Toggles sound on and off for you being hit\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds fizzle    \t \ag Toggles sound on and off for your spell fizzles\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds lvl     \t \ag Toggles sound on and off for when you Level\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds aa      \t \ag Toggles sound on and off for You gain AA\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds die     \t \ag Toggles sound on and off for your Deaths\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds hp      \t \ag Toggles sound on and off for Low Health\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds hp 1-100\t \ag Sets PctHPs to toggle low HP sound, 1-100\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ay%s Volume Control\ax', Module.Name)
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds hit 0-100\t \ag Sets Volume for hits 0-100 accepts decimal values\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds bonk 0-100\t\ag Sets Volume for bonk 0-100 accepts decimal values\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds fizzle 0-100\t \ag Sets Volume for fizzle 0-100 accepts decimal values\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds lvl 0-100 \t\ag Sets Volume for lvl 0-100 accepts decimal values\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds aa 0-100 \t\ag Sets Volume for AA 0-100 accepts decimal values\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds die 0-100 \t\ag Sets Volume for die 0-100 accepts decimal values\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds volhp 0-100 \t\ag Sets Volume for lowHP 0-100 accepts decimal values\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ay%s Other\ax', Module.Name)
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds help      \t\ag Brings up this list\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds config    \t\ag Opens Config GUI Window\ax')
        MyUI_Utils.PrintOutput('MyUI', nil, '\at /sillysounds show      \t\ag Prints out the current settings\ax')
        -- MyUI_Utils.PrintOutput('MyUI',nil,'\at /sillysounds quit      \t\ag Exits the script\ax')
    elseif type == 'show' then
        MyUI_Utils.PrintOutput('MyUI', nil, '\ay%s Current Settings\ax', Module.Name)
        for k, v in pairs(settings) do
            if k ~= 'Sounds' then
                MyUI_Utils.PrintOutput('MyUI', nil, "\at%s \ax:\ag %s\ax", k, tostring(v))
            end
        end
    end
end

-- Binds
local function bind(...)
    local newSetting = false
    local args = { ..., }
    local key = args[1]
    local value = tonumber(args[2], 10) or nil
    if key == nil then
        helpList('help')
        return
    end
    if string.lower(key) == 'hit' then
        if value ~= nil then
            settings.volHit = value or 50
            MyUI_Utils.PrintOutput('MyUI', nil, "setting %s Volume to %s", key, tostring(settings.volHit))
            playSound(string.format("%s%s/%s", Module.Path, settings.theme, settings.Sounds[settings.theme].soundHit.file))
        else
            settings.doHit = not settings.doHit
            MyUI_Utils.PrintOutput('MyUI', nil, "setting %s to %s", key, tostring(settings.doHit))
        end
        newSetting = true
    elseif string.lower(key) == 'bonk' then
        if value ~= nil then
            settings.volBonk = value or 50
            MyUI_Utils.PrintOutput('MyUI', nil, "setting %s Volume to %d", key, tostring(settings.volBonk))
            playSound(string.format("%s%s/%s", Module.Path, settings.theme, settings.Sounds[settings.theme].soundBonk.file))
        else
            settings.doBonk = not settings.doBonk
            MyUI_Utils.PrintOutput('MyUI', nil, "setting %s to %s", key, tostring(settings.doBonk))
        end
        newSetting = true
    elseif string.lower(key) == 'aa' then
        if value ~= nil then
            settings.volAA = value or 50
            MyUI_Utils.PrintOutput('MyUI', nil, "setting %s Volume to %d", key, tostring(settings.volAA))
            playSound(string.format("%s%s/%s", Module.Path, settings.theme, settings.Sounds[settings.theme].soundAA.file))
        else
            settings.doAA = not settings.doAA
            MyUI_Utils.PrintOutput('MyUI', nil, "setting %s to %s", key, tostring(settings.doAA))
        end
        newSetting = true
    elseif string.lower(key) == 'config' then
        openConfigGUI = not openConfigGUI
    elseif string.lower(key) == 'lvl' then
        if value ~= nil then
            settings.volLvl = value or 50
            MyUI_Utils.PrintOutput('MyUI', nil, "setting %s Volume to %d", key, tostring(settings.volLvl))
            playSound(string.format("%s%s/%s", Module.Path, settings.theme, settings.Sounds[settings.theme].soundLvl.file))
        else
            settings.doLvl = not settings.doLvl
            MyUI_Utils.PrintOutput('MyUI', nil, "setting %s to %s", key, tostring(settings.doLvl))
        end
        newSetting = true
    elseif string.lower(key) == 'die' then
        if value ~= nil then
            settings.volDie = value or 50
            MyUI_Utils.PrintOutput('MyUI', nil, "setting %s Volume to %d", key, tostring(settings.volDie))
            playSound(string.format("%s%s/%s", Module.Path, settings.theme, settings.Sounds[settings.theme].soundDie.file))
        else
            settings.doDie = not settings.doDie
            MyUI_Utils.PrintOutput('MyUI', nil, "setting %s to %s", key, tostring(settings.doDie))
        end
        newSetting = true
    elseif string.lower(key) == 'hp' then
        if value ~= nil then
            settings.lowHP = value or 0
            MyUI_Utils.PrintOutput('MyUI', nil, "setting %s to %s", key, tostring(value))
        else
            settings.doHP = not settings.doHP
            MyUI_Utils.PrintOutput('MyUI', nil, "setting %s to %s", key, tostring(settings.doHP))
        end
        newSetting = true
    elseif string.lower(key) == 'volhp' then
        if value ~= nil then
            settings.volHP = value or 50
            MyUI_Utils.PrintOutput('MyUI', nil, "setting %s Volume to %d", key, tostring(settings.volHP))
            playSound(string.format("%s%s/%s", Module.Path, settings.theme, settings.Sounds[settings.theme].soundLowHp.file))
            newSetting = true
        end
    elseif string.lower(key) == 'help' or key == nil then
        helpList('help')
    elseif string.lower(key) == 'show' then
        helpList(key)
    elseif string.lower(key) == 'quit' or key == nil then
        Module.IsRunning = false
    end
    if newSetting then mq.pickle(configFile, settings) end
end

-- Function to draw settings for each alert type
local function DrawAlertSettings(alertName, script, path, configFile)
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    local alert = string.format("do%s", alertName)
    local volAlert = string.format("vol%s", alertName)
    local soundAlert = string.format("sound%s", alertName)
    settings[alert] = ImGui.Checkbox(alertName .. " Alert##" .. script, settings[alert])
    ImGui.TableNextColumn()
    ImGui.SetNextItemWidth(70)
    settings.Sounds[settings.theme][soundAlert].file = ImGui.InputText('Filename##' .. alertName .. 'SND', settings.Sounds[settings.theme][soundAlert].file)
    ImGui.TableNextColumn()
    ImGui.SetNextItemWidth(100)
    settings[volAlert] = ImGui.InputFloat('Volume##' .. alertName .. 'VOL', settings[volAlert], 0.1)
    ImGui.TableNextColumn()
    ImGui.SetNextItemWidth(100)
    settings.Sounds[settings.theme][soundAlert].duration = ImGui.InputInt('Duration##' .. alertName .. 'DUR', settings.Sounds[settings.theme][soundAlert].duration)
    ImGui.TableNextColumn()
    if ImGui.Button("Test and Save##" .. alertName .. "ALERT") then
        soundDuration = settings.Sounds[settings.theme][soundAlert].duration
        setVolume(settings[volAlert])
        playSound(string.format("%s%s/%s", path, settings.theme, settings.Sounds[settings.theme][soundAlert].file))
        mq.pickle(configFile, settings)
    end
end

-- UI
function Module.RenderGUI()
    if not openConfigGUI then return end
    local lbl = string.format("%s##%s", Module.Name, MyUI_CharLoaded)
    local openUI, openConfigUI = ImGui.Begin(lbl, true, bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.NoCollapse))
    if not openUI then
        openConfigGUI = not openConfigGUI
        ImGui.End()
        return
    end
    if openConfigUI then
        tmpTheme = ImGui.InputText("Sound Folder Name##FolderName", tmpTheme)
        ImGui.SameLine()
        if ImGui.Button('Update##' .. Module.Name) then
            if settings.Sounds[tmpTheme] == nil then
                settings.Sounds[tmpTheme] = {
                    soundHit = { file = "Hit.wav", duration = 2, },
                    soundBonk = { file = "Bonk.wav", duration = 2, },
                    soundLvl = { file = "LevelUp.wav", duration = 3, },
                    soundDie = { file = "Die.wav", duration = 4, },
                    soundLowHp = { file = "lowHP.wav", duration = 3, },
                    soundAlarm = { file = "Alarm.wav", duration = 5, },
                    soundAA = { file = "AA.wav", duration = 2, },
                    soundFizzle = { file = 'Fizzle.wav', duration = 1, },
                    soundItem = { file = 'Hit.wav', duration = 2, },
                }
            end
            settings.theme = tmpTheme
            mq.pickle(configFile, settings)
            loadSettings()
        end

        if ImGui.BeginTable('Settings_Table##' .. Module.Name, 5, ImGuiTableFlags.None) then
            ImGui.TableSetupColumn('##Toggle_' .. Module.Name, ImGuiTableColumnFlags.WidthAlwaysAutoResize)
            ImGui.TableSetupColumn('##File_' .. Module.Name, ImGuiTableColumnFlags.WidthAlwaysAutoResize)
            ImGui.TableSetupColumn('##Vol_' .. Module.Name, ImGuiTableColumnFlags.WidthAlwaysAutoResize)
            ImGui.TableSetupColumn('##Dur_' .. Module.Name, ImGuiTableColumnFlags.WidthAlwaysAutoResize)
            ImGui.TableSetupColumn('##SaveBtn_' .. Module.Name, ImGuiTableColumnFlags.WidthAlwaysAutoResize)

            DrawAlertSettings('Hit', Module.Name, Module.Path, configFile)
            DrawAlertSettings('Bonk', Module.Name, Module.Path, configFile)
            DrawAlertSettings('Fizzle', Module.Name, Module.Path, configFile)
            DrawAlertSettings('Lvl', Module.Name, Module.Path, configFile)
            DrawAlertSettings('AA', Module.Name, Module.Path, configFile)
            DrawAlertSettings('Die', Module.Name, Module.Path, configFile)
            DrawAlertSettings('Alarm', Module.Name, Module.Path, configFile)
            DrawAlertSettings('LowHp', Module.Name, Module.Path, configFile)
            DrawAlertSettings('Item', Module.Name, Module.Path, configFile)

            ImGui.EndTable()
        end
        local tmpLowHp, tmpPulse = settings.lowHP, settings.Pulse
        tmpLowHp = ImGui.InputInt('Low HP Threshold##LowHealthThresh', tmpLowHp, 1)
        if tmpLowHp ~= settings.lowHP then
            settings.lowHP = tmpLowHp
        end

        tmpPulse = ImGui.InputInt('Pulse Delay##LowHealthPulse', tmpPulse, 1)
        if tmpPulse ~= settings.Pulse then
            settings.Pulse = tmpPulse
        end

        if settings.doItem then
            settings.ItemWatch = ImGui.InputText('Item Watch##ItemWatch', settings.ItemWatch)
        end

        if ImGui.Button('Close') then
            mq.pickle(configFile, settings)
            if settings.doItem then
                if itemWatch then
                    mq.unevent("item_added")
                    itemWatch = false
                end
                if settings.ItemWatch ~= '' then
                    local eStr = string.format("#*#%s#*#", settings.ItemWatch)
                    mq.event("item_added", eStr, function(line)
                        eventSound(line, 'Item', settings.volItem)
                        soundDuration = settings.Sounds[settings.theme].soundItem.duration
                    end)
                    itemWatch = true
                end
            end
            openConfigGUI = not openConfigGUI
        end
    end
    ImGui.End()
end

local clockTimer = mq.gettime()

function Module.Unload()
    mq.unevent("gained_level")
    mq.unevent("hit")
    mq.unevent("been_hit")
    mq.unevent("you_died")
    mq.unevent("you_died2")
    mq.unevent("gained_aa")
    mq.unevent("spell_fizzle")
    mq.unevent("item_added")
    mq.unbind('/sillysounds')
end

-- Init
local function init()
    helpList('help')
    loadSettings()
    originalVolume = getVolume()
    -- Event bindings
    mq.event("gained_level", "You have gained a level! Welcome to level #*#", function(line)
        eventSound(line, 'Lvl', settings.volLvl)
        soundDuration = settings.Sounds[settings.theme].soundLvl.duration
    end)
    mq.event("hit", "You #*# for #*# of damage.", function(line)
        eventSound(line, 'Hit', settings.volHit)
        soundDuration = settings.Sounds[settings.theme].soundHit.duration
    end)
    mq.event("been_hit", "#*# YOU for #*# of damage.", function(line)
        eventSound(line, 'Bonk', settings.volBonk)
        soundDuration = settings.Sounds[settings.theme].soundBonk.duration
    end)
    mq.event("you_died", "You died.", function(line)
        eventSound(line, 'Die', settings.volDie)
        soundDuration = settings.Sounds[settings.theme].soundDie.duration
    end)
    mq.event("you_died2", "You have been slain by#*#", function(line)
        eventSound(line, 'Die', settings.volDie)
        soundDuration = settings.Sounds[settings.theme].soundDie.duration
    end)
    mq.event("gained_aa", "#*#gained an ability point#*#", function(line)
        eventSound(line, 'AA', settings.volAA)
        soundDuration = settings.Sounds[settings.theme].soundAA.duration
    end)
    mq.event("spell_fizzle", "Your#*#spell fizzles#*#", function(line)
        eventSound(line, 'Fizzle', settings.volFizzle)
        soundDuration = settings.Sounds[settings.theme].soundFizzle.duration
    end)

    -- Slash Command Binding
    mq.bind('/sillysounds', bind)
    Module.IsRunning = true
    if not loadedExeternally then
        mq.imgui.init(Module.Name, Module.RenderGUI)
        Module.LocalLoop()
    end
end

-- Main loop
function Module.MainLoop()
    if loadedExeternally then
        ---@diagnostic disable-next-line: undefined-global
        if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
    end

    mq.doevents()

    if mq.TLO.Window('ConfirmationDialogBox').Open() then
        alarmTagged = false
        checkAlarms()
    end

    if mq.TLO.Me.PctHPs() <= settings.lowHP and mq.TLO.Me.PctHPs() > 1 and settings.doHP then
        timerA = os.time()
        if timerA - timerB > settings.Pulse then
            originalVolume = getVolume()
            setVolume(settings.volHP)
            timerPlay = os.time()
            soundDuration = settings.Sounds[settings.theme].soundLowHp.duration
            playSound(string.format("%s%s/%s", Module.Path, settings.theme, settings.Sounds[settings.theme].soundLowHp.file))
            timerB = os.time()
        end
    end

    local tnpVol = getVolume()
    if playing == true and timerPlay > 0 then
        local curTime = os.time()
        if curTime - timerPlay > soundDuration then
            resetVolume()
            clockTimer = mq.gettime()
        end
    end

    if not playing and timerPlay == 0 then
        if mq.gettime() - clockTimer > 100 then
            local tmpVol = getVolume()
            if originalVolume ~= tmpVol then
                originalVolume = tmpVol
            end
            clockTimer = mq.gettime()
        end
    end
end

function Module.LocalLoop()
    while Module.IsRunning do
        Module.MainLoop()
        mq.delay(1)
    end
end

if mq.TLO.EverQuest.GameState() ~= "INGAME" then
    printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", Module.Name)
    mq.exit()
end

init()

return Module
