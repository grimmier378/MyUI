-- Imports
local mq                = require('mq')
local ImGui             = require('ImGui')

local Module            = {}
Module.ActorMailBox     = 'my_buffs'
Module.Path             = MyUI_Path ~= nil and MyUI_Path or string.format("%s/%s/", mq.luaDir, Module.Mane)
local themeFile         = MyUI_ThemeFile == nil and string.format('%s/MyUI/ThemeZ.lua', mq.configDir) or MyUI_ThemeFile
local configFileOld     = mq.configDir .. '/MyUI_Configs.lua'

-- Tables
Module.boxes            = {}
Module.settings         = {}
Module.timerColor       = {}
Module.theme            = {}
Module.buffTable        = {}
Module.songTable        = {}
Module.Name             = "MyBuffs"
Module.IsRunning        = false

Module.ShowGUI,
Module.SplitWin,
Module.ShowConfig,
Module.MailBoxShow,
Module.ShowDebuffs,
Module.showTitleBar     = true, false, false, false, false, true
Module.locked,
Module.ShowIcons,
Module.ShowTimer,
Module.ShowText,
Module.ShowScroll,
Module.DoPulse          = false, true, true, true, true, true
Module.iconSize         = 24

---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false
if not loadedExeternally then
    MyUI_Utils = require('lib.common')
    MyUI_Actor = require('actors')
    MyUI_CharLoaded = mq.TLO.Me.DisplayName()
    MyUI_Mode = 'driver'
    MyUI_Icons = require('mq.ICONS')
    MyUI_Server = mq.TLO.EverQuest.Server()
end

local configFile                       = string.format("%s/MyUI/MyBuffs/%s/%s.lua", mq.configDir,
    MyUI_Server, MyUI_CharLoaded)
local MyBuffs_Actor                    = nil
local winFlag                          = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse, ImGuiWindowFlags.NoFocusOnAppearing)
local flashAlpha, flashAlphaT          = 1, 255
local rise, riseT                      = true, true
local RUNNING, firstRun, changed, solo = true, true, false, true
local songTimer, buffTime              = 20, 5
local numSlots                         = mq.TLO.Me.MaxBuffSlots() or 0 --Max Buff Slots
local Scale                            = 1.0
local animSpell                        = mq.FindTextureAnimation('A_SpellIcons')
local gIcon                            = MyUI_Icons.MD_SETTINGS
local activeButton                     = MyUI_CharLoaded -- Initialize the active button with the first box's name
local PulseSpeed                       = 5
local themeName                        = 'Default'
local mailBox                          = {}
local debuffOnMe                       = {}
local useWinPos                        = false
local ShowMenu                         = false
local sortType                         = 'none'
local showTableView                    = true
local maxSongs                         = 30
local winPositions                     = {
    Config = { x = 500, y = 500, },
    MailBox = { x = 500, y = 500, },
    Debuffs = { x = 500, y = 500, },
    Buffs = { x = 500, y = 500, },
    Songs = { x = 500, y = 500, },
}
local winSizes                         = {
    Config = { x = 300, y = 500, },
    MailBox = { x = 500, y = 500, },
    Debuffs = { x = 500, y = 500, },
    Buffs = { x = 200, y = 300, },
    Songs = { x = 200, y = 300, },
}
-- Timing Variables
local clockTimer                       = mq.gettime()
local lastTime                         = os.time()
local checkIn                          = os.time()
local frameTime                        = 17
local currZone, lastZone

-- default config settings
Module.defaults                        = {
    Scale = 1.0,
    LoadTheme = 'Default',
    locked = false,
    IconSize = 24,
    ShowIcons = true,
    ShowTimer = true,
    ShowText = true,
    DoPulse = true,
    PulseSpeed = 5,
    ShowScroll = true,
    ShowTitleBar = true,
    SplitWin = false,
    SongTimer = 20,
    ShowDebuffs = false,
    BuffTimer = 5,
    TableView = false,
    ShowMenu = true,
    SortBy = 'none',
    ShowTable = false,
    TimerColor = { 0, 0, 0, 1, },
    UseWindowPositions = false,
    WindowPositions = {
        Config = { x = 500, y = 500, },
        MailBox = { x = 500, y = 500, },
        Debuffs = { x = 500, y = 500, },
        Buffs = { x = 500, y = 500, },
        Songs = { x = 500, y = 500, },
    },
    WindowSizes = {
        Config = { x = 300, y = 500, },
        MailBox = { x = 500, y = 500, },
        Debuffs = { x = 500, y = 500, },
        Buffs = { x = 200, y = 300, },
        Songs = { x = 200, y = 300, },
    },
}

-- Functions

---comment
---@param inTable table @Table to sort
---@param sortOrder string @Sort Order accepts (alpha, dur, none)
---@return table @Returns a sorted table
local function SortBuffs(inTable, sortOrder)
    if sortOrder == 'none' or sortOrder == nil then return Module.buffTable end
    local tmpSortBuffs = {}
    for _, buff in pairs(inTable) do
        if buff.Name ~= '' then table.insert(tmpSortBuffs, buff) end
    end
    if sortOrder == 'alpha' then
        table.sort(tmpSortBuffs, function(a, b) return a.Name < b.Name end)
    elseif sortOrder == 'dur' then
        table.sort(tmpSortBuffs, function(a, b)
            if a.TotalSeconds == b.TotalSeconds then
                return a.Name < b.Name
            else
                return a.TotalSeconds < b.TotalSeconds
            end
        end)
    end
    return tmpSortBuffs
end

---comment
---@param songsTable table
---@param buffsTable table
---@return table
local function GenerateContent(subject, songsTable, buffsTable, doWho, doWhat)
    local dWho = doWho or nil
    local dWhat = doWhat or nil
    if subject == nil then subject = 'Update' end

    if #Module.boxes == 0 or firstRun then
        subject = 'Hello'
        firstRun = false
    end

    local content = {
        Name = MyUI_CharLoaded,
        Buffs = buffsTable,
        Songs = songsTable,
        DoWho = dWho,
        Debuffs = debuffOnMe or nil,
        DoWhat = dWhat,
        BuffSlots = numSlots,
        BuffCount = mq.TLO.Me.BuffCount(),
        SongCount = mq.TLO.Me.CountSongs(),
        Check = os.time(),
        Subject = subject,
        SortedBuffsA = SortBuffs(Module.buffTable, 'alpha'),
        SortedBuffsD = SortBuffs(Module.buffTable, 'dur'),
        SortedSongsA = SortBuffs(Module.songTable, 'alpha'),
        SortedSongsD = SortBuffs(Module.songTable, 'dur'),
    }
    checkIn = os.time()
    return content
end

local function GetBuff(slot)
    local buffTooltip, buffName, buffDurDisplay, buffIcon, buffID, buffBeneficial, buffHr, buffMin, buffSec, totalMin, totalSec, buffDurHMS
    local buff = mq.TLO.Me.Buff(slot)
    local duration = buff.Duration

    buffName = buff.Name() or ''
    buffIcon = buff.SpellIcon() or 0
    buffID = buff.ID() or 0
    buffBeneficial = buff.Beneficial() or false

    -- Extract hours, minutes, and seconds from buffDuration
    buffHr = duration.Hours() or 0
    buffMin = duration.Minutes() or 0
    buffSec = duration.Seconds() or 0

    -- Calculate total minutes and total seconds
    totalMin = duration.TotalMinutes() or 0
    totalSec = duration.TotalSeconds() or 0
    -- MyUI_Utils.PrintOutput('MyUI',nil,totalSec)
    buffDurHMS = duration.TimeHMS() or ''

    -- format tooltip

    local dispBuffHr = buffHr and string.format("%02d", buffHr) or "00"
    local displayBuffMin = buffMin and string.format("%02d", buffMin) or "00"
    local displayBuffSec = buffSec and string.format("%02d", buffSec) or "00"
    buffDurDisplay = string.format("%s:%s:%s", dispBuffHr, displayBuffMin, displayBuffSec)
    buffTooltip = string.format("%s) %s (%s)", slot, buffName, buffDurHMS)



    if Module.buffTable[slot] ~= nil then
        if Module.buffTable[slot].ID ~= buffID or (totalSec < 20) then
            changed = true
        else
            if totalSec - Module.buffTable[slot].TotalSeconds > 1 then changed = true end
        end
    end

    if not buffBeneficial then
        if #debuffOnMe > 0 then
            local found = false
            for i = 1, #debuffOnMe do
                if debuffOnMe[i].ID == buffID then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(debuffOnMe, {
                    Name = buffName,
                    Duration = buffDurHMS,
                    DurationDisplay = buffDurDisplay,
                    Icon = buffIcon,
                    ID = buffID,
                    Hours = buffHr,
                    Slot = slot,
                    Minutes = buffMin,
                    Seconds = buffSec,
                    TotalMinutes = totalMin,
                    TotalSeconds = totalSec,
                    Tooltip = buffTooltip,
                })
            end
        else
            table.insert(debuffOnMe, {
                Name = buffName,
                Duration = buffDurHMS,
                DurationDisplay = buffDurDisplay,
                Icon = buffIcon,
                ID = buffID,
                Hours = buffHr,
                Slot = slot,
                Minutes = buffMin,
                Seconds = buffSec,
                TotalMinutes = totalMin,
                TotalSeconds = totalSec,
                Tooltip = buffTooltip,
            })
        end
    end

    Module.buffTable[slot] = {
        Name = buffName,
        Beneficial = buffBeneficial,
        Duration = buffDurHMS,
        DurationDisplay = buffDurDisplay,
        Icon = buffIcon,
        ID = buffID,
        Slot = slot,
        Hours = buffHr,
        Minutes = buffMin,
        Seconds = buffSec,
        TotalMinutes = totalMin,
        TotalSeconds = totalSec,
        Tooltip = buffTooltip,
    }
end

local function GetSong(slot)
    local songTooltip, songName, songDurationDisplay, songIcon, songID, songBeneficial, songHr, songMin, songSec, totalMin, totalSec, songDurHMS
    songName = mq.TLO.Me.Song(slot).Name() or ''
    songIcon = mq.TLO.Me.Song(slot).SpellIcon() or 0
    songID = songName ~= '' and (mq.TLO.Me.Song(slot).ID() or 0) or 0
    songBeneficial = mq.TLO.Me.Song(slot).Beneficial() or false
    totalMin = mq.TLO.Me.Song(slot).Duration.TotalMinutes() or 0
    totalSec = mq.TLO.Me.Song(slot).Duration.TotalSeconds() or 0

    local song = mq.TLO.Me.Song(slot)
    local duration = song.Duration

    songName = song.Name() or ''
    songIcon = song.SpellIcon() or 0
    songID = song.ID() or 0
    songBeneficial = song.Beneficial() or false

    songDurHMS = duration.TimeHMS() or ''
    songHr = duration.Hours() or 0
    songMin = duration.Minutes() or 0
    songSec = duration.Seconds() or 0
    -- format tooltip
    songHr = songHr and string.format("%02d", tonumber(songHr)) or "00"
    songMin = songMin and string.format("%02d", tonumber(songMin)) or "00"
    songSec = songSec and string.format("%02d", tonumber(songSec)) or "00"
    songDurationDisplay = string.format("%s:%s:%s", songHr, songMin, songSec)

    songTooltip = string.format("%s) %s (%s)", slot, songName, songDurHMS)

    if Module.songTable[slot + 1] ~= nil then
        if Module.songTable[slot + 1].ID ~= songID and os.time() - checkIn >= 6 then changed = true end
    end
    Module.songTable[slot] = {
        Name = songName,
        Beneficial = songBeneficial,
        Duration = songDurHMS,
        DurationDisplay = songDurationDisplay,
        Icon = songIcon,
        ID = songID,
        Slot = slot,
        Hours = songHr,
        Minutes = songMin,
        Seconds = songSec,
        TotalMinutes = totalMin,
        TotalSeconds = totalSec,
        Tooltip = songTooltip,
    }
end

local function pulseIcon(speed)
    local currentTime = os.time()
    if currentTime - lastTime < frameTime then
        return -- exit if not enough time has passed
    end

    lastTime = currentTime -- update the last time
    if riseT == true then
        flashAlphaT = flashAlphaT - speed
    elseif riseT == false then
        flashAlphaT = flashAlphaT + speed
    end
    if flashAlphaT == 200 then riseT = false end
    if flashAlphaT == 10 then riseT = true end
    if rise == true then
        flashAlpha = flashAlpha + speed
    elseif rise == false then
        flashAlpha = flashAlpha - speed
    end
    if flashAlpha == 200 then rise = false end
    if flashAlpha == 10 then rise = true end
end

local function CheckIn()
    local now = os.time()
    if now - checkIn >= 240 or firstRun then
        checkIn = now
        return true
    end
    return false
end

local function CheckStale()
    local now = os.time()
    local found = false
    for i = 1, #Module.boxes do
        if Module.boxes[1].Check == nil then
            table.remove(Module.boxes, i)
            found = true
            break
        else
            if now - Module.boxes[i].Check > 300 then
                table.remove(Module.boxes, i)
                found = true
                break
            end
        end
    end
    if found then CheckStale() end
end

local function GetBuffs()
    changed = false
    local subject = 'Update'
    debuffOnMe = {}
    numSlots = mq.TLO.Me.MaxBuffSlots() or 0
    if numSlots == 0 then return end -- most likely not loaded all the way try again next cycle
    for i = 1, numSlots do
        GetBuff(i)
    end
    if mq.TLO.Me.CountSongs() > 0 then
        for i = 1, maxSongs do
            GetSong(i)
        end
    end

    if CheckIn() then
        changed = true
        subject = 'CheckIn'
    end
    if firstRun then subject = 'Hello' end
    if not solo and MyBuffs_Actor ~= nil then
        if changed or firstRun then
            MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent(subject, Module.songTable, Module.buffTable))
            MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent(subject, Module.songTable, Module.buffTable))
            changed = false
        else
            for i = 1, #Module.boxes do
                if Module.boxes[i].Name == MyUI_CharLoaded then
                    Module.boxes[i].Buffs = Module.buffTable
                    Module.boxes[i].Songs = Module.songTable
                    Module.boxes[i].SongCount = mq.TLO.Me.CountSongs() or 0
                    Module.boxes[i].BuffSlots = numSlots
                    Module.boxes[i].BuffCount = mq.TLO.Me.BuffCount() or 0
                    Module.boxes[i].Hello = false
                    Module.boxes[i].Debuffs = debuffOnMe
                    Module.boxes[i].SortedBuffsA = SortBuffs(Module.buffTable, 'alpha')
                    Module.boxes[i].SortedBuffsD = SortBuffs(Module.buffTable, 'dur')
                    Module.boxes[i].SortedSongsA = SortBuffs(Module.songTable, 'alpha')
                    Module.boxes[i].SortedSongsD = SortBuffs(Module.songTable, 'dur')
                    break
                end
            end
        end
    else
        if Module.boxes[1] == nil then
            table.insert(Module.boxes, {
                Name = MyUI_CharLoaded,
                Buffs = Module.buffTable,
                Songs = Module.songTable,
                Check = os.time(),
                BuffSlots = numSlots,
                BuffCount = mq.TLO.Me.BuffCount(),
                Debuffs = debuffOnMe,
                SortedBuffsA = SortBuffs(Module.buffTable, 'alpha'),
                SortedBuffsD = SortBuffs(Module.buffTable, 'dur'),
                SortedSongsA = SortBuffs(Module.songTable, 'alpha'),
                SortedSongsD = SortBuffs(Module.songTable, 'dur'),
            })
        else
            Module.boxes[1].Buffs = Module.buffTable
            Module.boxes[1].Songs = Module.songTable
            Module.boxes[1].Name = MyUI_CharLoaded
            Module.boxes[1].BuffCount = mq.TLO.Me.BuffCount() or 0
            Module.boxes[1].SongCount = mq.TLO.Me.CountSongs() or 0
            Module.boxes[1].BuffSlots = numSlots
            Module.boxes[1].Check = os.time()
            Module.boxes[1].Debuffs = debuffOnMe
            Module.boxes[1].SortedBuffsA = SortBuffs(Module.buffTable, 'alpha')
            Module.boxes[1].SortedBuffsD = SortBuffs(Module.buffTable, 'dur')
            Module.boxes[1].SortedSongsA = SortBuffs(Module.songTable, 'alpha')
            Module.boxes[1].SortedSongsD = SortBuffs(Module.songTable, 'dur')
        end
    end
end

local function MessageHandler()
    MyBuffs_Actor = MyUI_Actor.register(Module.ActorMailBox, function(message)
        local MemberEntry    = message()
        local who            = MemberEntry.Name or 'Unknown'
        local charBuffs      = MemberEntry.Buffs or {}
        local charSongs      = MemberEntry.Songs or {}
        local charSlots      = MemberEntry.BuffSlots or 0
        local charCount      = MemberEntry.BuffCount or 0
        local charSortBuffsA = MemberEntry.SortedBuffsA or {}
        local charSortBuffsD = MemberEntry.SortedBuffsD or {}
        local charSortSongsA = MemberEntry.SortedSongsA or {}
        local charSortSongsD = MemberEntry.SortedSongsD or {}
        local check          = MemberEntry.Check or os.time()
        local doWho          = MemberEntry.DoWho or 'N/A'
        local dowhat         = MemberEntry.DoWhat or 'N/A'
        local found          = false
        local debuffActor    = MemberEntry.Debuffs or {}
        local subject        = MemberEntry.Subject or 'Update'
        table.insert(mailBox, { Name = who, Subject = subject, Check = check, DoWho = doWho, DoWhat = dowhat, When = os.date("%H:%M:%S"), })
        if #debuffActor == 0 then
            debuffActor = {}
        end
        if MemberEntry.Subject == 'Action' and who ~= 'Unknown' then
            if MemberEntry.DoWho ~= nil and MemberEntry.DoWhat ~= nil then
                if MemberEntry.DoWho == MyUI_CharLoaded then
                    local bName = MemberEntry.DoWhat:sub(5) or 0
                    if MemberEntry.DoWhat:find("^buff") then
                        mq.TLO.Me.Buff(bName).Remove()
                        GetBuffs()
                    elseif MemberEntry.DoWhat:find("^song") then
                        mq.TLO.Me.Song(bName).Remove()
                        GetBuffs()
                    elseif MemberEntry.DoWhat:find("blockbuff") then
                        bName = MemberEntry.DoWhat:sub(10) or 0
                        local bID = mq.TLO.Spell(bName).ID()
                        mq.cmdf("/blockspell add me '%s'", bID)
                        GetBuffs()
                    elseif MemberEntry.DoWhat:find("blocksong") then
                        bName = MemberEntry.DoWhat:sub(10) or 0
                        local bID = mq.TLO.Spell(bName).ID()
                        mq.cmdf("/blockspell add me '%s'", bID)
                        GetBuffs()
                    end
                end
                return
            end
        end
        --New member connected if Hello is true. Lets send them our data so they have it.
        if MemberEntry.Subject == 'Hello' then
            check = os.time()
            if who ~= MyUI_CharLoaded and who ~= 'Unknown' and MyBuffs_Actor ~= nil then
                MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent('Welcome', Module.songTable, Module.buffTable))
                MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent('Welcome', Module.songTable, Module.buffTable))
            end
        end

        if MemberEntry.Subject == 'Goodbye' and who ~= 'Unknown' then
            check = 0
        end
        -- Process the rest of the message into the groupData table.
        if MemberEntry.Subject ~= 'Action' and who ~= 'Unknown' then
            for i = 1, #Module.boxes do
                if Module.boxes[i].Name == who then
                    Module.boxes[i].Buffs = charBuffs
                    Module.boxes[i].Songs = charSongs
                    Module.boxes[i].Check = check
                    Module.boxes[i].BuffSlots = charSlots
                    Module.boxes[i].BuffCount = charCount
                    Module.boxes[i].Debuffs = debuffActor
                    Module.boxes[i].SongCount = MemberEntry.SongCount or 0
                    Module.boxes[i].SortedBuffsA = charSortBuffsA
                    Module.boxes[i].SortedBuffsD = charSortBuffsD
                    Module.boxes[i].SortedSongsA = charSortSongsA
                    Module.boxes[i].SortedSongsD = charSortSongsD
                    found = true
                    break
                end
            end
            if not found then
                table.insert(Module.boxes, {
                    Name         = who,
                    Buffs        = charBuffs,
                    Songs        = charSongs,
                    Check        = check,
                    BuffSlots    = charSlots,
                    SongCount    = MemberEntry.SongCount or 0,
                    BuffCount    = charCount,
                    Debuffs      = debuffActor,
                    SortedBuffsA = charSortBuffsA,
                    SortedBuffsD = charSortBuffsD,
                    SortedSongsA = charSortSongsA,
                    SortedSongsD = charSortSongsD,
                })
            end
        end
        if check == 0 then CheckStale() end
    end)
end

local function SayGoodBye()
    local message = {
        Subject = 'Goodbye',
        Name = MyUI_CharLoaded,
        Check = 0,
    }
    if MyBuffs_Actor ~= nil then
        MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, message)
        MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, message)
    end
end

local function loadTheme()
    if MyUI_Utils.File.Exists(themeFile) then
        Module.theme = dofile(themeFile)
    else
        Module.theme = require('defaults.themes')
        mq.pickle(themeFile, Module.theme)
    end
    themeName = Module.theme.LoadTheme or 'notheme'
end

local function loadSettings()
    local newSetting = false
    if not MyUI_Utils.File.Exists(configFile) then
        if MyUI_Utils.File.Exists(configFileOld) then
            local tmp = dofile(configFileOld)
            Module.settings[Module.Name] = tmp[Module.Name]
        else
            Module.settings[Module.Name] = Module.defaults
        end
        mq.pickle(configFile, Module.settings)
        loadSettings()
    else
        -- Load settings from the Lua config file
        Module.timerColor = {}
        Module.settings = dofile(configFile)
        if Module.settings[Module.Name] == nil then
            Module.settings[Module.Name] = {}
            Module.settings[Module.Name] = Module.defaults
            newSetting = true
        end
        Module.timerColor = Module.settings[Module.Name]
    end

    loadTheme()
    newSetting = MyUI_Utils.CheckDefaultSettings(Module.defaults, Module.settings[Module.Name])
    newSetting = MyUI_Utils.CheckDefaultSettings(Module.defaults.WindowPositions, Module.settings[Module.Name].WindowPositions) or newSetting
    newSetting = MyUI_Utils.CheckDefaultSettings(Module.defaults.WindowSizes, Module.settings[Module.Name].WindowSizes) or newSetting

    Module.showTitleBar = Module.settings[Module.Name].ShowTitleBar
    showTableView = Module.settings[Module.Name].TableView
    PulseSpeed = Module.settings[Module.Name].PulseSpeed
    Module.DoPulse = Module.settings[Module.Name].DoPulse
    Module.timerColor = Module.settings[Module.Name].TimerColor
    Module.ShowScroll = Module.settings[Module.Name].ShowScroll
    songTimer = Module.settings[Module.Name].SongTimer
    buffTime = Module.settings[Module.Name].BuffTimer
    Module.SplitWin = Module.settings[Module.Name].SplitWin
    Module.ShowTimer = Module.settings[Module.Name].ShowTimer
    Module.ShowText = Module.settings[Module.Name].ShowText
    Module.ShowIcons = Module.settings[Module.Name].ShowIcons
    Module.ShowDebuffs = Module.settings[Module.Name].ShowDebuffs
    ShowMenu = Module.settings[Module.Name].ShowMenu
    Module.iconSize = Module.settings[Module.Name].IconSize
    Module.locked = Module.settings[Module.Name].locked
    Scale = Module.settings[Module.Name].Scale
    themeName = Module.settings[Module.Name].LoadTheme
    winPositions = Module.settings[Module.Name].WindowPositions
    useWinPos = Module.settings[Module.Name].UseWindowPositions

    sortType = Module.settings[Module.Name].SortBy
    if newSetting then mq.pickle(configFile, Module.settings) end
end

--- comments
---@param iconID integer
---@param spell table
---@param slotNum integer
local function DrawInspectableSpellIcon(iconID, spell, slotNum, view)
    if view == nil then view = 'column' end
    local cursor_x, cursor_y = ImGui.GetCursorPos()
    local beniColor = IM_COL32(0, 20, 180, 190) -- blue benificial default color
    if iconID == 0 and view ~= 'table' then
        ImGui.SetWindowFontScale(1)
        ImGui.TextDisabled("%d", slotNum)
        ImGui.SetWindowFontScale(1)
        ImGui.PushID(tostring(iconID) .. slotNum .. "_invis_btn")
        ImGui.SetCursorPos(cursor_x, cursor_y)
        ImGui.InvisibleButton("slot" .. tostring(slotNum), ImVec2(Module.iconSize, Module.iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
        ImGui.PopID()
        return
    elseif iconID == 0 and view == 'table' then
        return
    end
    animSpell:SetTextureCell(iconID or 0)
    if not spell.Beneficial then
        beniColor = IM_COL32(255, 0, 0, 190) --red detrimental
    end
    ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
        ImGui.GetCursorScreenPosVec() + Module.iconSize, beniColor)
    ImGui.SetCursorPos(cursor_x + 3, cursor_y + 3)
    ImGui.DrawTextureAnimation(animSpell, Module.iconSize - 5, Module.iconSize - 5)
    ImGui.SetCursorPos(cursor_x + 2, cursor_y + 2)
    local sName = spell.Name or '??'
    local sDur = spell.TotalSeconds or 0
    ImGui.PushID(tostring(iconID) .. sName .. "_invis_btn")
    if sDur < 18 and sDur > 0 and Module.DoPulse then
        pulseIcon(PulseSpeed)
        local flashColor = IM_COL32(0, 0, 0, flashAlpha)
        ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
            ImGui.GetCursorScreenPosVec() + Module.iconSize - 4, flashColor)
    end
    ImGui.SetCursorPos(cursor_x, cursor_y)
    ImGui.InvisibleButton(sName, ImVec2(Module.iconSize, Module.iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
    ImGui.PopID()
end

---comment
---@param tName string -- name of the theme to load form table
---@return integer, integer -- returns the new counter values
local function DrawTheme(tName)
    local StyleCounter = 0
    local ColorCounter = 0
    for tID, tData in pairs(Module.theme.Theme) do
        if tData.Name == tName then
            for pID, cData in pairs(Module.theme.Theme[tID].Color) do
                ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
                ColorCounter = ColorCounter + 1
            end
            if tData['Style'] ~= nil then
                if next(tData['Style']) ~= nil then
                    for sID, sData in pairs(Module.theme.Theme[tID].Style) do
                        if sData.Size ~= nil then
                            ImGui.PushStyleVar(sID, sData.Size)
                            StyleCounter = StyleCounter + 1
                        elseif sData.X ~= nil then
                            ImGui.PushStyleVar(sID, sData.X, sData.Y)
                            StyleCounter = StyleCounter + 1
                        end
                    end
                end
            end
        end
    end
    return ColorCounter, StyleCounter
end

local function BoxBuffs(id, sorted, view)
    if view == nil then view = 'column' end
    if sorted == nil then sorted = 'none' end
    local boxChar = Module.boxes[id].Name or '?'
    local boxBuffs = (sorted == 'alpha' and Module.boxes[id].SortedBuffsA) or (sorted == 'dur' and Module.boxes[id].SortedBuffsD) or Module.boxes[id].Buffs
    local buffSlots = Module.boxes[id].BuffSlots or 0
    local sizeX, sizeY = ImGui.GetContentRegionAvail()

    -------------------------------------------- Buffs Section ---------------------------------
    if not Module.SplitWin then sizeY = math.floor(sizeY * 0.7) else sizeY = 0.0 end
    if not Module.ShowScroll and view ~= 'table' then
        ImGui.BeginChild("Buffs##" .. boxChar .. view, ImVec2(sizeX, sizeY), ImGuiChildFlags.Border, ImGuiWindowFlags.NoScrollbar)
    elseif view ~= 'table' and Module.ShowScroll then
        ImGui.BeginChild("Buffs##" .. boxChar .. view, ImVec2(sizeX, sizeY), ImGuiChildFlags.Border)
    elseif view == 'table' then
        ImGui.BeginChild("Buffs##" .. boxChar, ImVec2(ImGui.GetColumnWidth(-1), 0.0), bit32.bor(ImGuiChildFlags.AutoResizeY, ImGuiChildFlags.AlwaysAutoResize),
            bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.AlwaysAutoResize))
    end
    local startNum, slot = 1, 1
    local rowMax = math.floor(ImGui.GetColumnWidth(-1) / (Module.iconSize)) or 1
    local rowCount = 0

    for i = startNum, buffSlots do
        slot = i
        local bName
        local sDurT = ''
        local drawn = false
        -- Normal View
        if view ~= 'table' then
            ImGui.BeginGroup()
            if boxBuffs[i] == nil or boxBuffs[i].ID == 0 then
                ImGui.SetWindowFontScale(Scale)
                ImGui.TextDisabled(tostring(slot))
                ImGui.SetWindowFontScale(1)
            else
                bName = boxBuffs[i].Name:sub(1, -1)
                sDurT = boxBuffs[i].DurationDisplay ~= nil and boxBuffs[i].DurationDisplay or ' '
                if Module.ShowIcons then
                    DrawInspectableSpellIcon(boxBuffs[i].Icon, boxBuffs[i], slot)
                    ImGui.SameLine()
                end
                if boxChar == MyUI_CharLoaded then
                    if Module.ShowTimer then
                        local sDur = boxBuffs[i].TotalMinutes or 0
                        if sDur < buffTime then
                            ImGui.PushStyleColor(ImGuiCol.Text, Module.timerColor[1], Module.timerColor[2], Module.timerColor[3], Module.timerColor[4])
                            ImGui.Text(" %s ", sDurT)
                            ImGui.PopStyleColor()
                        else
                            ImGui.Text(' ')
                        end
                        ImGui.SameLine()
                    end
                else
                    if Module.ShowTimer then
                        local sDur = boxBuffs[i].TotalSeconds or 0
                        if sDur < 20 then
                            ImGui.PushStyleColor(ImGuiCol.Text, Module.timerColor[1], Module.timerColor[2], Module.timerColor[3], Module.timerColor[4])
                            ImGui.Text(" %s ", sDurT)
                            ImGui.PopStyleColor()
                        else
                            ImGui.Text(' ')
                        end
                        ImGui.SameLine()
                    end
                end

                if Module.ShowText and boxBuffs[i].Name ~= '' then
                    ImGui.Text(boxBuffs[i].Name)
                end
            end
            ImGui.EndGroup()
        else
            ImGui.BeginGroup()

            if boxBuffs[i] ~= nil then
                bName = boxBuffs[i].Name:sub(1, -1)
                sDurT = boxBuffs[i].DurationDisplay or ' '

                DrawInspectableSpellIcon(boxBuffs[i].Icon, boxBuffs[i], slot)
                rowCount = rowCount + 1
                drawn = true
            end
            ImGui.EndGroup()
        end

        if ImGui.BeginPopupContextItem("##Buff" .. tostring(i)) then
            if boxChar == MyUI_CharLoaded then
                if ImGui.MenuItem("Inspect##" .. boxBuffs[i].Slot) then
                    mq.TLO.Me.Buff(bName).Inspect()
                end
            end

            if ImGui.MenuItem("Block##" .. i) then
                local what = string.format('blockbuff%s', boxBuffs[i].Name)
                if not solo and MyBuffs_Actor ~= nil then
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent('Action', Module.songTable, Module.buffTable, boxChar, what))
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent('Action', Module.songTable, Module.buffTable, boxChar, what))
                else
                    mq.cmdf("/blockspell add me '%s'", mq.TLO.Spell(bName).ID())
                end
            end

            if ImGui.MenuItem("Remove##" .. i) then
                local what = string.format('buff%s', boxBuffs[i].Name)
                if not solo and MyBuffs_Actor ~= nil then
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent('Action', Module.songTable, Module.buffTable, boxChar, what))
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent('Action', Module.songTable, Module.buffTable, boxChar, what))
                else
                    mq.TLO.Me.Buff(bName).Remove()
                end
            end
            ImGui.EndPopup()
        end
        if ImGui.IsItemHovered() then
            if ImGui.IsMouseDoubleClicked(0) then
                local what = string.format('buff%s', boxBuffs[i].Name)
                if not solo and MyBuffs_Actor ~= nil then
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent('Action', Module.songTable, Module.buffTable, boxChar, what))
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent('Action', Module.songTable, Module.buffTable, boxChar, what))
                else
                    mq.TLO.Me.Buff(bName).Remove()
                end
            end
            ImGui.BeginTooltip()
            if boxBuffs[i] ~= nil then
                if boxBuffs[i].Icon > 0 then
                    if boxChar == MyUI_CharLoaded then
                        ImGui.Text(boxBuffs[i].Tooltip)
                    else
                        ImGui.Text(boxBuffs[i].Name)
                    end
                else
                    ImGui.SetWindowFontScale(Scale)
                    ImGui.Text('none')
                    ImGui.SetWindowFontScale(1)
                end
            else
                ImGui.SetWindowFontScale(Scale)
                ImGui.Text('none')
                ImGui.SetWindowFontScale(1)
            end
            ImGui.EndTooltip()
        end
        if view == 'table' and drawn then
            if rowCount < rowMax then
                ImGui.SameLine(0, 0.5)
            else
                rowCount = 0
            end
        end
    end

    ImGui.EndChild()
end

local function BoxSongs(id, sorted, view)
    if view == nil then view = 'column' end
    if #Module.boxes == 0 then return end
    if sorted == nil then sorted = 'none' end
    local boxChar = Module.boxes[id].Name or '?'
    local boxSongs = (sorted == 'alpha' and Module.boxes[id].SortedSongsA) or (sorted == 'dur' and Module.boxes[id].SortedSongsD) or Module.boxes[id].Songs
    local sCount = Module.boxes[id].SongCount or 0
    local sizeX, sizeY = ImGui.GetContentRegionAvail()
    sizeX, sizeY = math.floor(sizeX), 0.0

    --------- Songs Section -----------------------
    if Module.ShowScroll and view ~= 'table' then
        ImGui.BeginChild("Songs##" .. boxChar, ImVec2(sizeX, sizeY), ImGuiChildFlags.Border)
    elseif view ~= 'table' and not Module.ShowScroll then
        ImGui.BeginChild("Songs##" .. boxChar, ImVec2(sizeX, sizeY), ImGuiChildFlags.Border, ImGuiWindowFlags.NoScrollbar)
    elseif view == 'table' then
        ImGui.BeginChild("Songs##" .. boxChar, ImVec2(ImGui.GetColumnWidth(-1), 0.0), bit32.bor(ImGuiChildFlags.AutoResizeY, ImGuiChildFlags.AlwaysAutoResize),
            bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.AlwaysAutoResize))
    end
    local rowCounterS = 0
    local maxSongRow = math.floor(ImGui.GetColumnWidth(-1) / (Module.iconSize)) or 1
    local counterSongs = 0
    for i = 1, maxSongs do
        if counterSongs > sCount then break end
        -- local songs[i] = songs[i] or nil
        local sID
        if view ~= 'table' then
            ImGui.BeginGroup()
            if boxSongs[i] == nil or boxSongs[i].Icon == 0 then
                ImGui.SetWindowFontScale(Scale)
                ImGui.TextDisabled("")
                ImGui.SetWindowFontScale(1)
            else
                if Module.ShowIcons then
                    DrawInspectableSpellIcon(boxSongs[i].Icon, boxSongs[i], i)

                    ImGui.SameLine()
                end
                if boxChar == MyUI_CharLoaded then
                    if Module.ShowTimer then
                        local sngDurS = boxSongs[i].TotalSeconds or 0
                        if sngDurS < songTimer then
                            ImGui.PushStyleColor(ImGuiCol.Text, Module.timerColor[1], Module.timerColor[2], Module.timerColor[3], Module.timerColor[4])
                            ImGui.Text(" %ss ", sngDurS)
                            ImGui.PopStyleColor()
                        else
                            ImGui.Text(' ')
                        end
                        ImGui.SameLine()
                    end
                end
                if Module.ShowText then
                    ImGui.Text(boxSongs[i].Name)
                end
                counterSongs = counterSongs + 1
            end
            ImGui.EndGroup()
        else
            ImGui.BeginGroup()
            if boxSongs[i] ~= nil then
                if boxSongs[i].Icon > 0 then
                    if Module.ShowIcons then
                        DrawInspectableSpellIcon(boxSongs[i].Icon, boxSongs[i], i, view)
                        rowCounterS = rowCounterS + 1
                    end

                    counterSongs = counterSongs + 1
                end
            end
            ImGui.EndGroup()
        end
        if ImGui.BeginPopupContextItem("##Song" .. tostring(i)) then
            if ImGui.MenuItem("Inspect##" .. i) then
                mq.TLO.Me.Song(boxSongs[i].Name).Inspect()
            end
            if ImGui.MenuItem("Block##" .. i) then
                local what = string.format('blocksong%s', boxSongs[i].Name)
                if not solo and MyBuffs_Actor ~= nil then
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent('Action', Module.songTable, Module.buffTable, boxChar, what))
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent('Action', Module.songTable, Module.buffTable, boxChar, what))
                else
                    mq.cmdf("/blocksong add me '%s'", boxSongs[i].Name)
                end
            end
            if ImGui.MenuItem("Remove##" .. i) then
                local what = string.format('song%s', boxSongs[i].Name)
                if not solo and MyBuffs_Actor ~= nil then
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent('Action', Module.songTable, Module.buffTable, boxChar, what))
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent('Action', Module.songTable, Module.buffTable, boxChar, what))
                else
                    mq.TLO.Me.Song(boxSongs[i].Name).Remove()
                end
            end
            ImGui.EndPopup()
        end
        if ImGui.IsItemHovered() then
            if ImGui.IsMouseDoubleClicked(0) then
                if not solo and MyBuffs_Actor ~= nil then
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', },
                        GenerateContent('Action', Module.songTable, Module.buffTable, boxChar, 'song' .. boxSongs[i].Name))
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', },
                        GenerateContent('Action', Module.songTable, Module.buffTable, boxChar, 'song' .. boxSongs[i].Name))
                else
                    mq.TLO.Me.Song(boxSongs[i].Name).Remove()
                end
            end
            ImGui.BeginTooltip()
            if boxSongs[i] ~= nil then
                if boxSongs[i].Icon > 0 then
                    if boxChar == MyUI_CharLoaded then
                        ImGui.Text(boxSongs[i].Tooltip)
                    else
                        ImGui.Text(boxSongs[i].Name)
                    end
                else
                    ImGui.SetWindowFontScale(Scale)
                    ImGui.Text('none')
                    ImGui.SetWindowFontScale(1)
                end
            else
                ImGui.SetWindowFontScale(Scale)
                ImGui.Text('none')
                ImGui.SetWindowFontScale(1)
            end
            ImGui.EndTooltip()
        end
        if view == 'table' then
            if rowCounterS < maxSongRow then
                ImGui.SameLine(0, 0.5)
            else
                rowCounterS = 0
            end
        end
    end

    ImGui.EndChild()
end

local function sortedBoxes(boxes)
    table.sort(boxes, function(a, b)
        return a.Name < b.Name
    end)
    return boxes
end

function Module.RenderGUI()
    if currZone ~= lastZone then return end

    if Module.ShowGUI then
        ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
        local flags = winFlag
        if Module.locked then
            flags = bit32.bor(ImGuiWindowFlags.NoMove, flags)
        end
        if not Module.settings[Module.Name].ShowTitleBar then
            flags = bit32.bor(ImGuiWindowFlags.NoTitleBar, flags)
        end
        if not Module.ShowScroll then
            flags = bit32.bor(flags, ImGuiWindowFlags.NoScrollbar)
        end
        if ShowMenu then
            flags = bit32.bor(flags, ImGuiWindowFlags.MenuBar)
        end

        local ColorCount, StyleCount = DrawTheme(themeName)
        local winPosX, winPosY = winPositions.Buffs.x, winPositions.Buffs.y
        local winSizeX, winSizeY = winSizes.Buffs.x, winSizes.Buffs.y
        if useWinPos then
            ImGui.SetNextWindowPos(ImVec2(winPosX, winPosY), ImGuiCond.Appearing)
            ImGui.SetNextWindowSize(ImVec2(winSizeX, winSizeY), ImGuiCond.Appearing)
        end
        local splitIcon = Module.SplitWin and MyUI_Icons.FA_TOGGLE_ON or MyUI_Icons.FA_TOGGLE_OFF
        local sortIcon = sortType == 'none' and MyUI_Icons.FA_SORT_NUMERIC_ASC or sortType == 'alpha' and MyUI_Icons.FA_SORT_ALPHA_ASC or MyUI_Icons.MD_TIMER
        local lockedIcon = Module.locked and MyUI_Icons.FA_LOCK or MyUI_Icons.FA_UNLOCK
        local openGUI, showMain = ImGui.Begin("MyBuffs##" .. MyUI_CharLoaded, true, flags)
        if not openGUI then
            Module.ShowGUI = false
        end
        if showMain then
            if ImGui.BeginMenuBar() then
                if ImGui.Button(lockedIcon .. "##lockTabButton_MyBuffs") then
                    Module.locked = not Module.locked

                    Module.settings[Module.Name].locked = Module.locked
                    mq.pickle(configFile, Module.settings)
                end

                if ImGui.IsItemHovered() then
                    ImGui.BeginTooltip()
                    ImGui.Text("Lock Window")
                    ImGui.EndTooltip()
                end
                if ImGui.BeginMenu('Menu') then
                    if ImGui.Selectable(gIcon .. " Settings") then
                        Module.ShowConfig = not Module.ShowConfig
                    end

                    if ImGui.Selectable(MyUI_Icons.FA_TABLE .. " Show Table") then
                        showTableView = not showTableView
                        Module.settings[Module.Name].TableView = showTableView
                        mq.pickle(configFile, Module.settings)
                    end

                    if ImGui.Selectable(splitIcon .. " Split Window") then
                        Module.SplitWin = not Module.SplitWin

                        Module.settings[Module.Name].SplitWin = Module.SplitWin
                        mq.pickle(configFile, Module.settings)
                    end

                    if ImGui.BeginMenu(sortIcon .. " Sort Menu") then
                        if ImGui.Selectable(MyUI_Icons.FA_SORT_NUMERIC_ASC .. " Sort by Slot") then
                            sortType = 'none'
                            Module.settings[Module.Name].SortBy = sortType
                            mq.pickle(configFile, Module.settings)
                        end
                        if ImGui.Selectable(MyUI_Icons.FA_SORT_ALPHA_ASC .. " Sort by Name") then
                            sortType = 'alpha'
                            Module.settings[Module.Name].SortBy = sortType
                            mq.pickle(configFile, Module.settings)
                        end
                        if ImGui.Selectable(MyUI_Icons.MD_TIMER .. " Sort by Duration") then
                            sortType = 'dur'
                            Module.settings[Module.Name].SortBy = sortType
                        end
                        ImGui.EndMenu()
                    end

                    ImGui.EndMenu()
                end

                if ImGui.BeginMenu(sortIcon .. "Sort") then
                    if ImGui.Selectable(MyUI_Icons.FA_SORT_NUMERIC_ASC .. " Sort by Slot") then
                        sortType = 'none'
                    end
                    if ImGui.Selectable(MyUI_Icons.FA_SORT_ALPHA_ASC .. " Sort by Name") then
                        sortType = 'alpha'
                    end
                    if ImGui.Selectable(MyUI_Icons.MD_TIMER .. " Sort by Duration") then
                        sortType = 'dur'
                    end
                    ImGui.EndMenu()
                end
                ImGui.EndMenuBar()
            end

            if not showTableView then
                ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4, 3)
                ImGui.SetWindowFontScale(Scale)
                if not solo then
                    if #Module.boxes > 0 then
                        -- Sort boxes by the 'Name' attribute
                        local sorted_boxes = sortedBoxes(Module.boxes)
                        ImGui.SetNextItemWidth(ImGui.GetWindowWidth() - 15)
                        if ImGui.BeginCombo("##CharacterCombo", activeButton) then
                            for i = 1, #sorted_boxes do
                                local box = sorted_boxes[i]
                                if ImGui.Selectable(box.Name, activeButton == box.Name) then
                                    activeButton = box.Name
                                end
                            end
                            ImGui.EndCombo()
                        end

                        -- Draw the content of the active button
                        for i = 1, #sorted_boxes do
                            if sorted_boxes[i].Name == activeButton then
                                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
                                BoxBuffs(i, sortType)
                                if not Module.SplitWin then BoxSongs(i, sortType) end
                                ImGui.PopStyleVar()
                                break
                            end
                        end
                    end
                else
                    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
                    BoxBuffs(1, sortType)
                    if not Module.SplitWin then BoxSongs(1, sortType) end
                    ImGui.PopStyleVar()
                end
                ImGui.PopStyleVar()
            else
                -- ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4, 3)
                ImGui.SetWindowFontScale(Scale)
                local tFlags = bit32.bor(
                    ImGuiTableFlags.Resizable,
                    -- ImGuiTableFlags.Sortable,
                    -- ImGuiTableFlags.SizingFixedFit,
                    ImGuiTableFlags.Borders,
                    ImGuiTableFlags.BordersOuter,
                    ImGuiTableFlags.Reorderable,
                    ImGuiTableFlags.ScrollY,
                    ImGuiTableFlags.Hideable
                )
                if ImGui.BeginTable("Group Table##1", 3, tFlags) then
                    ImGui.TableSetupScrollFreeze(0, 1)
                    ImGui.TableSetupColumn("Name")
                    ImGui.TableSetupColumn("Buffs")
                    ImGui.TableSetupColumn("Songs")
                    ImGui.TableHeadersRow()
                    if #Module.boxes > 0 then
                        ImGui.SetWindowFontScale(Scale)
                        for i = 1, #Module.boxes do
                            ImGui.TableNextColumn()
                            ImGui.SetWindowFontScale(Scale)
                            if Module.boxes[i].Name == MyUI_CharLoaded then
                                ImGui.TextColored(ImVec4(0, 1, 1, 1), Module.boxes[i].Name)
                            else
                                ImGui.Text(Module.boxes[i].Name)
                            end
                            ImGui.TableNextColumn()
                            ImGui.SetWindowFontScale(Scale)
                            BoxBuffs(i, sortType, 'table')
                            ImGui.TableNextColumn()
                            ImGui.SetWindowFontScale(Scale)
                            BoxSongs(i, sortType, 'table')
                        end
                        ImGui.SetWindowFontScale(1)
                    end
                    ImGui.EndTable()
                end
            end
        end

        local curPosX, curPosY = ImGui.GetWindowPos()
        local curSizeX, curSizeY = ImGui.GetWindowSize()
        if curPosX ~= winPosX or curPosY ~= winPosY or curSizeX ~= winSizeX or curSizeY ~= winSizeY then
            winPositions.Buffs.y = curPosY
            winPositions.Buffs.x = curPosX
            winSizeX, winSizeY = curSizeX, curSizeY
            winSizes.Buffs.x = winSizeX
            winSizes.Buffs.y = winSizeY
            Module.settings[Module.Name].WindowPositions.Buffs.x = curPosX
            Module.settings[Module.Name].WindowPositions.Buffs.y = curPosY
            Module.settings[Module.Name].WindowSizes.Buffs.x = winSizeX
            Module.settings[Module.Name].WindowSizes.Buffs.y = winSizeY
            mq.pickle(configFile, Module.settings)
        end
        if ImGui.BeginPopupContextWindow("Options") then
            local lbl = Module.locked and " Un-Lock Window" or " Lock Window"
            if ImGui.MenuItem(lockedIcon .. lbl) then
                Module.locked = not Module.locked
                Module.settings[Module.Name].locked = Module.locked
                mq.pickle(configFile, Module.settings)
            end
            if ImGui.MenuItem(gIcon .. "Settings") then
                Module.ShowConfig = not Module.ShowConfig
            end
            if ImGui.MenuItem("Show Table") then
                showTableView = not showTableView
                Module.settings[Module.Name].TableView = showTableView
                mq.pickle(configFile, Module.settings)
            end
            if ImGui.MenuItem("Split Window") then
                Module.SplitWin = not Module.SplitWin
                Module.settings[Module.Name].SplitWin = Module.SplitWin
                mq.pickle(configFile, Module.settings)
            end
            if ImGui.MenuItem(MyUI_Icons.FA_SORT_NUMERIC_ASC .. "Sort by Slot") then
                sortType = 'none'
                Module.settings[Module.Name].SortBy = sortType
                mq.pickle(configFile, Module.settings)
            end
            if ImGui.MenuItem(MyUI_Icons.FA_SORT_ALPHA_ASC .. "Sort by Name") then
                sortType = 'alpha'
                Module.settings[Module.Name].SortBy = sortType
                mq.pickle(configFile, Module.settings)
            end
            if ImGui.MenuItem(MyUI_Icons.MD_TIMER .. "Sort by Duration") then
                sortType = 'dur'
                Module.settings[Module.Name].SortBy = sortType
                mq.pickle(configFile, Module.settings)
            end
            ImGui.EndPopup()
        end
        if StyleCount > 0 then ImGui.PopStyleVar(StyleCount) end
        if ColorCount > 0 then ImGui.PopStyleColor(ColorCount) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
    end

    if Module.SplitWin then
        if currZone ~= lastZone then return end

        local flags = winFlag
        if Module.locked then
            flags = bit32.bor(ImGuiWindowFlags.NoMove, flags)
        end
        if not Module.settings[Module.Name].ShowTitleBar then
            flags = bit32.bor(ImGuiWindowFlags.NoTitleBar, flags)
        end
        if not Module.ShowScroll then
            flags = bit32.bor(flags, ImGuiWindowFlags.NoScrollbar)
        end
        -- Default window size
        local winPosX, winPosY = winPositions.Songs.x, winPositions.Songs.y
        local winSizeX, winSizeY = winSizes.Songs.x, winSizes.Songs.y
        if useWinPos then
            ImGui.SetNextWindowSize(ImVec2(winSizeX, winSizeY), ImGuiCond.Appearing)
            ImGui.SetNextWindowPos(ImVec2(winPosX, winPosY), ImGuiCond.Appearing)
        end
        ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
        local ColorCountSongs, StyleCountSongs = DrawTheme(themeName)
        local songWin, show = ImGui.Begin("MyBuffs Songs##Songs" .. MyUI_CharLoaded, true, flags)
        ImGui.SetWindowFontScale(Scale)
        if not songWin then
            Module.SplitWin = false
        end
        if show then
            if #Module.boxes > 0 then
                for i = 1, #Module.boxes do
                    if Module.boxes[i].Name == activeButton then
                        BoxSongs(i, sortType)
                    end
                end
            end
            ImGui.SetWindowFontScale(1)
            ImGui.Spacing()
        end

        local curPosX, curPosY = ImGui.GetWindowPos()
        local curSizeX, curSizeY = ImGui.GetWindowSize()
        if curPosX ~= winPosX or curPosY ~= winPosY or curSizeX ~= winSizeX or curSizeY ~= winSizeY then
            winPositions.Songs.y = curPosY
            winPositions.Songs.x = curPosX
            winSizeX, winSizeY = curSizeX, curSizeY
            Module.settings[Module.Name].WindowSizes.Songs.x = winSizeX
            Module.settings[Module.Name].WindowSizes.Songs.y = winSizeY
            Module.settings[Module.Name].WindowPositions.Songs.x = curPosX
            Module.settings[Module.Name].WindowPositions.Songs.y = curPosY
            mq.pickle(configFile, Module.settings)
        end

        if StyleCountSongs > 0 then ImGui.PopStyleVar(StyleCountSongs) end
        if ColorCountSongs > 0 then ImGui.PopStyleColor(ColorCountSongs) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
    end

    if Module.ShowConfig then
        local winPosX, winPosY = winPositions.Config.x, winPositions.Config.y
        local winSizeX, winSizeY = winSizes.Config.x, winSizes.Config.y
        local ColorCountConf, StyleCountConf = DrawTheme(themeName)
        if useWinPos then
            ImGui.SetNextWindowSize(ImVec2(winSizeX, winSizeY), ImGuiCond.Appearing)
            ImGui.SetNextWindowPos(ImVec2(winPosX, winPosY), ImGuiCond.Appearing)
        end
        ImGui.SetNextWindowSize(200, 300, ImGuiCond.FirstUseEver)
        local openConfig, showConfigGui = ImGui.Begin("MyBuffs Conf", nil, bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.NoFocusOnAppearing, ImGuiWindowFlags.NoCollapse))
        ImGui.SetWindowFontScale(Scale)
        if not openConfig then
            Module.ShowConfig = false
        end
        if showConfigGui then
            ImGui.SameLine()
            ImGui.SeparatorText('Theme')
            if ImGui.CollapsingHeader('Theme##Coll' .. Module.Name) then
                ImGui.Text("Cur Theme: %s", themeName)
                -- Combo Box Load Theme

                if ImGui.BeginCombo("Load Theme##MyBuffs", themeName) then
                    ImGui.SetWindowFontScale(Scale)
                    for k, data in pairs(Module.theme.Theme) do
                        local isSelected = data.Name == themeName
                        if ImGui.Selectable(data.Name, isSelected) then
                            Module.theme.LoadTheme = data.Name
                            themeName = Module.theme.LoadTheme
                            Module.settings[Module.Name].LoadTheme = themeName
                        end
                    end
                    ImGui.EndCombo()
                end

                if ImGui.Button('Reload Theme File') then
                    loadTheme()
                end
            end
            --------------------- Sliders ----------------------
            ImGui.SeparatorText('Scaling')
            if ImGui.CollapsingHeader('Scaling##Coll' .. Module.Name) then
                -- Slider for adjusting zoom level
                local tmpZoom = Scale
                if Scale then
                    tmpZoom = ImGui.SliderFloat("Text Scale##MyBuffs", tmpZoom, 0.5, 2.0)
                end
                if Scale ~= tmpZoom then
                    Scale = tmpZoom
                end

                -- Slider for adjusting IconSize
                local tmpSize = Module.iconSize
                if Module.iconSize then
                    tmpSize = ImGui.SliderInt("Icon Size##MyBuffs", tmpSize, 15, 50)
                end
                if Module.iconSize ~= tmpSize then
                    Module.iconSize = tmpSize
                end
            end
            ImGui.SeparatorText('Timers')
            local vis = ImGui.CollapsingHeader('Timers##Coll' .. Module.Name)
            if vis then
                Module.timerColor = ImGui.ColorEdit4('Timer Color', Module.timerColor, bit32.bor(ImGuiColorEditFlags.NoInputs))

                ---- timer threshold adjustment sliders
                local tmpBuffTimer = buffTime
                if buffTime then
                    ImGui.SetNextItemWidth(150)
                    tmpBuffTimer = ImGui.InputInt("Buff Timer (Minutes)##MyBuffs", tmpBuffTimer, 1, 600)
                end
                if tmpBuffTimer < 0 then tmpBuffTimer = 0 end
                if buffTime ~= tmpBuffTimer then
                    buffTime = tmpBuffTimer
                end

                local tmpSongTimer = songTimer
                if songTimer then
                    ImGui.SetNextItemWidth(150)
                    tmpSongTimer = ImGui.InputInt("Song Timer (Seconds)##MyBuffs", tmpSongTimer, 1, 600)
                end
                if tmpSongTimer < 0 then tmpSongTimer = 0 end
                if songTimer ~= tmpSongTimer then
                    songTimer = tmpSongTimer
                end
            end
            --------------------- input boxes --------------------

            ---------- Checkboxes ---------------------
            ImGui.SeparatorText('Toggles')
            if ImGui.CollapsingHeader('Toggles##Coll' .. Module.Name) then
                local tmpShowIcons = Module.ShowIcons
                tmpShowIcons = ImGui.Checkbox('Show Icons', tmpShowIcons)
                if tmpShowIcons ~= Module.ShowIcons then
                    Module.ShowIcons = tmpShowIcons
                end
                ImGui.SameLine()
                local tmpPulseIcons = Module.DoPulse
                tmpPulseIcons = ImGui.Checkbox('Pulse Icons', tmpPulseIcons)
                if tmpPulseIcons ~= Module.DoPulse then
                    Module.DoPulse = tmpPulseIcons
                end
                local tmpPulseSpeed = PulseSpeed
                if Module.DoPulse then
                    ImGui.SetNextItemWidth(150)
                    tmpPulseSpeed = ImGui.InputInt("Pulse Speed##MyBuffs", tmpPulseSpeed, 1, 10)
                end
                if PulseSpeed < 0 then PulseSpeed = 0 end
                if PulseSpeed ~= tmpPulseSpeed then
                    PulseSpeed = tmpPulseSpeed
                end

                ImGui.Separator()
                if ImGui.BeginTable("Toggles##", 2) then
                    ImGui.TableNextColumn()
                    local tmpShowText = Module.ShowText
                    tmpShowText = ImGui.Checkbox('Show Text', tmpShowText)
                    if tmpShowText ~= Module.ShowText then
                        Module.ShowText = tmpShowText
                    end
                    ImGui.TableNextColumn()
                    local tmpShowTimer = Module.ShowTimer
                    tmpShowTimer = ImGui.Checkbox('Show Timer', tmpShowTimer)
                    if tmpShowTimer ~= Module.ShowTimer then
                        Module.ShowTimer = tmpShowTimer
                    end
                    ImGui.TableNextColumn()
                    local tmpScroll = Module.ShowScroll
                    tmpScroll = ImGui.Checkbox('Show Scrollbar', tmpScroll)
                    if tmpScroll ~= Module.ShowScroll then
                        Module.ShowScroll = tmpScroll
                    end
                    ImGui.TableNextColumn()
                    local tmpSplit = Module.SplitWin
                    tmpSplit = ImGui.Checkbox('Split Win', tmpSplit)
                    if tmpSplit ~= Module.SplitWin then
                        Module.SplitWin = tmpSplit
                    end
                    ImGui.TableNextColumn()
                    Module.MailBoxShow = ImGui.Checkbox('Show MailBox', Module.MailBoxShow)
                    ImGui.TableNextColumn()
                    Module.ShowDebuffs = ImGui.Checkbox('Show Debuffs', Module.ShowDebuffs)
                    ImGui.TableNextColumn()
                    Module.showTitleBar = ImGui.Checkbox('Show Title Bar', Module.showTitleBar)
                    ImGui.TableNextColumn()
                    useWinPos = ImGui.Checkbox('Use Window Positions', useWinPos)
                    ImGui.TableNextColumn()
                    ShowMenu = ImGui.Checkbox('Show Menu', ShowMenu)
                    ImGui.TableNextColumn()
                    showTableView = ImGui.Checkbox('Show Table', showTableView)

                    ImGui.EndTable()
                end
            end

            ImGui.SeparatorText('Save and Close')

            if ImGui.Button('Save and Close') then
                Module.settings[Module.Name].UseWindowPositions = useWinPos
                Module.settings[Module.Name].ShowTitleBar = Module.showTitleBar
                Module.settings[Module.Name].DoPulse = Module.DoPulse
                Module.settings[Module.Name].PulseSpeed = PulseSpeed
                Module.settings[Module.Name].TimerColor = Module.timerColor
                Module.settings[Module.Name].ShowScroll = Module.ShowScroll
                Module.settings[Module.Name].SongTimer = songTimer
                Module.settings[Module.Name].BuffTimer = buffTime
                Module.settings[Module.Name].IconSize = Module.iconSize
                Module.settings[Module.Name].Scale = Scale
                Module.settings[Module.Name].SplitWin = Module.SplitWin
                Module.settings[Module.Name].LoadTheme = themeName
                Module.settings[Module.Name].ShowIcons = Module.ShowIcons
                Module.settings[Module.Name].ShowText = Module.ShowText
                Module.settings[Module.Name].ShowTimer = Module.ShowTimer
                Module.settings[Module.Name].ShowDebuffs = Module.ShowDebuffs
                Module.settings[Module.Name].ShowMenu = ShowMenu
                Module.settings[Module.Name].ShowMailBox = Module.MailBoxShow
                Module.settings[Module.Name].ShowTableView = showTableView

                mq.pickle(configFile, Module.settings)

                Module.ShowConfig = false
            end
        end


        local curPosX, curPosY = ImGui.GetWindowPos()
        local curSizeX, curSizeY = ImGui.GetWindowSize()
        if curPosX ~= winPosX or curPosY ~= winPosY or curSizeX ~= winSizeX or curSizeY ~= winSizeY then
            winPositions.Config.x = curPosX
            winPositions.Config.y = curPosY
            winSizeX, winSizeY = curSizeX, curSizeY
            Module.settings[Module.Name].WindowPositions.Config.x = curPosX
            Module.settings[Module.Name].WindowPositions.Config.y = curPosY
            Module.settings[Module.Name].WindowSizes.Config.x = winSizeX
            Module.settings[Module.Name].WindowSizes.Config.y = winSizeY
            mq.pickle(configFile, Module.settings)
        end
        if StyleCountConf > 0 then ImGui.PopStyleVar(StyleCountConf) end
        if ColorCountConf > 0 then ImGui.PopStyleColor(ColorCountConf) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
    end

    if Module.ShowDebuffs then
        local found = false
        ImGui.SetNextWindowSize(80, 239, ImGuiCond.Appearing)
        local winPosX, winPosY = winPositions.Debuffs.x, winPositions.Debuffs.y
        local winSizeX, winSizeY = winSizes.Debuffs.x, winSizes.Debuffs.y
        if useWinPos then
            ImGui.SetNextWindowSize(ImVec2(winSizeX, winSizeY), ImGuiCond.Appearing)
            ImGui.SetNextWindowPos(ImVec2(winPosX, winPosY), ImGuiCond.Appearing)
        end
        for i = 1, #Module.boxes do
            if #Module.boxes[i].Debuffs > 1 then
                found = true
                break
            end
        end
        if found then
            ColorCountDebuffs, StyleCountDebuffs = DrawTheme(themeName)
            local openDebuffs, showDebuffs = ImGui.Begin("MyBuffs Debuffs##" .. MyUI_CharLoaded, true,
                bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoFocusOnAppearing))
            ImGui.SetWindowFontScale(Scale)

            if not openDebuffs then
                Module.ShowDebuffs = false
            end
            if showDebuffs then
                for i = 1, #Module.boxes do
                    if #Module.boxes[i].Debuffs > 1 then
                        local sizeX, sizeY = ImGui.GetContentRegionAvail()
                        if ImGui.BeginChild(Module.boxes[i].Name .. "##Debuffs_" .. Module.boxes[i].Name, ImVec2(sizeX, 60), bit32.bor(ImGuiChildFlags.Border), bit32.bor(ImGuiWindowFlags.NoScrollbar)) then
                            ImGui.Text(Module.boxes[i].Name)
                            for k, v in pairs(Module.boxes[i].Debuffs) do
                                if v.ID > 0 then
                                    DrawInspectableSpellIcon(v.Icon, v, k)
                                    ImGui.SetItemTooltip(v.Tooltip)
                                    ImGui.SameLine(0, 0)
                                end
                            end
                        end
                        ImGui.EndChild()
                    end
                end
            end
            local curPosX, curPosY = ImGui.GetWindowPos()
            local curSizeX, curSizeY = ImGui.GetWindowSize()
            if curPosX ~= winPosX or curPosY ~= winPosY or curSizeX ~= winSizeX or curSizeY ~= winSizeY then
                winSizeX, winSizeY = curSizeX, curSizeY
                winSizes.Debuffs.x = winSizeX
                winSizes.Debuffs.y = winSizeY
                winPositions.Debuffs.x = curPosX
                winPositions.Debuffs.y = curPosY
                Module.settings[Module.Name].WindowSizes.Debuffs.x = winSizeX
                Module.settings[Module.Name].WindowSizes.Debuffs.y = winSizeY
                Module.settings[Module.Name].WindowPositions.Debuffs.x = curPosX
                Module.settings[Module.Name].WindowPositions.Debuffs.y = curPosY
                mq.pickle(configFile, Module.settings)
            end
            if StyleCountDebuffs > 0 then ImGui.PopStyleVar(StyleCountDebuffs) end
            if ColorCountDebuffs > 0 then ImGui.PopStyleColor(ColorCountDebuffs) end
            ImGui.SetWindowFontScale(1)
            ImGui.End()
        end
    end

    if Module.MailBoxShow then
        local ColorCountMail, StyleCountMail = DrawTheme(themeName)
        local winPosX, winPosY = winPositions.MailBox.x, winPositions.MailBox.y
        local winSizeX, winSizeY = winSizes.MailBox.x, winSizes.MailBox.y
        if useWinPos then
            ImGui.SetNextWindowPos(ImVec2(winPosX, winPosY), ImGuiCond.Appearing)
            ImGui.SetNextWindowSize(ImVec2(winSizeX, winSizeY), ImGuiCond.Appearing)
        end
        local openMail, showMail = ImGui.Begin("MyBuffs MailBox##MailBox_MyBuffs_" .. MyUI_CharLoaded, true, ImGuiWindowFlags.NoFocusOnAppearing)
        if not openMail then
            Module.MailBoxShow = false
            mailBox = {}
        end
        if showMail then
            ImGui.Text('Clear')
            if ImGui.IsItemHovered() and ImGui.IsMouseReleased(0) then
                ImGui.BeginTooltip()
                ImGui.Text("Clear Mail Box")
                ImGui.EndTooltip()
                mailBox = {}
            end
            if ImGui.BeginTable("Mail Box##MyBuffs", 6, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.ScrollY), ImVec2(0.0, 0.0)) then
                ImGui.TableSetupScrollFreeze(0, 1)
                ImGui.TableSetupColumn("Sender", ImGuiTableColumnFlags.WidthFixed, 100)
                ImGui.TableSetupColumn("Subject", ImGuiTableColumnFlags.WidthFixed, 100)
                ImGui.TableSetupColumn("TimeStamp", ImGuiTableColumnFlags.WidthFixed, 100)
                ImGui.TableSetupColumn("DoWho", ImGuiTableColumnFlags.WidthFixed, 100)
                ImGui.TableSetupColumn("DoWhat", ImGuiTableColumnFlags.WidthFixed, 100)
                ImGui.TableSetupColumn("CheckIn", ImGuiTableColumnFlags.WidthFixed, 100)
                ImGui.TableHeadersRow()
                for i = 1, #mailBox do
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn()
                    ImGui.Text(mailBox[i].Name)
                    ImGui.TableNextColumn()
                    ImGui.Text(mailBox[i].Subject)
                    ImGui.TableNextColumn()
                    ImGui.Text(mailBox[i].When)
                    ImGui.TableNextColumn()
                    ImGui.Text(mailBox[i].DoWho)
                    ImGui.TableNextColumn()
                    ImGui.Text(mailBox[i].DoWhat)
                    ImGui.TableNextColumn()
                    ImGui.Text(tostring(mailBox[i].Check))
                end
                ImGui.EndTable()
            end
        end

        local curPosX, curPosY = ImGui.GetWindowPos()
        local curSizeX, curSizeY = ImGui.GetWindowSize()
        if curPosX ~= winPosX or curPosY ~= winPosY or curSizeX ~= winSizeX or curSizeY ~= winSizeY then
            winPositions.MailBox.x = curPosX
            winPositions.MailBox.y = curPosY
            winSizeX, winSizeY = curSizeX, curSizeY
            Module.settings[Module.Name].WindowPositions.MailBox.x = curPosX
            Module.settings[Module.Name].WindowPositions.MailBox.y = curPosY
            Module.settings[Module.Name].WindowSizes.MailBox.x = winSizeX
            Module.settings[Module.Name].WindowSizes.MailBox.y = winSizeY
            mq.pickle(configFile, Module.settings)
        end
        if StyleCountMail > 0 then ImGui.PopStyleVar(StyleCountMail) end
        if ColorCountMail > 0 then ImGui.PopStyleColor(ColorCountMail) end
        ImGui.End()
    else
        mailBox = {}
    end
end

function Module.CheckMode()
    if MyUI_Mode == 'driver' then
        Module.ShowGUI = true
        solo = false
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayMyBuffs.\ao Setting \atDriver\ax Mode. Actors [\agEnabled\ax] UI [\agOn\ax].')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayMyBuffs.\ao Type \at/mybuffs show\ax. to Toggle the UI')
    elseif MyUI_Mode == 'client' then
        Module.ShowGUI = false
        solo = false
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayMyBuffs.\ao Setting \atClient\ax Mode.Actors [\agEnabled\ax] UI [\arOff\ax].')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayMyBuffs.\ao Type \at/mybuffs show\ax. to Toggle the UI')
    else
        Module.ShowGUI = true
        solo = true
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayMyBuffs.\ao Setting \atSolo\ax Mode. Actors [\arDisabled\ax] UI [\agOn\ax].')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayMyBuffs.\ao Type \at/mybuffs show\ax. to Toggle the UI')
    end
end

function Module.CheckArgs(args)
    if #args > 0 then
        if args[1] == 'driver' then
            ShowGUI = true
            solo = false
            if args[2] ~= nil and args[2] == 'mailbox' then
                MailBoxShow = true
            end
            print('\ayMyBuffs:\ao Setting \atDriver\ax Mode. Actors [\agEnabled\ax] UI [\agOn\ax].')
            print('\ayMyBuffs:\ao Type \at/mybuffs show\ax. to Toggle the UI')
        elseif args[1] == 'client' then
            ShowGUI = false
            solo = false
            print('\ayMyBuffs:\ao Setting \atClient\ax Mode.Actors [\agEnabled\ax] UI [\arOff\ax].')
            print('\ayMyBuffs:\ao Type \at/mybuffs show\ax. to Toggle the UI')
        elseif args[1] == 'solo' then
            ShowGUI = true
            solo = true
            print('\ayMyBuffs:\ao Setting \atSolo\ax Mode. Actors [\arDisabled\ax] UI [\agOn\ax].')
            print('\ayMyBuffs:\ao Type \at/mybuffs show\ax. to Toggle the UI')
        end
    else
        ShowGUI = true
        solo = true
        print('\ayMyBuffs: \aoUse \at/lua run mybuffs client\ax To start with Actors [\agEnabled\ax] UI [\arOff\ax].')
        print('\ayMyBuffs: \aoUse \at/lua run mybuffs driver\ax To start with the Actors [\agEnabled\ax] UI [\agOn\ax].')
        print('\ayMyBuffs: \aoType \at/mybuffs show\ax. to Toggle the UI')
        print('\ayMyBuffs: \aoNo arguments passed, defaulting to \agSolo\ax Mode. Actors [\arDisabled\ax] UI [\agOn\ax].')
    end
end

local function processCommand(...)
    local args = { ..., }
    if #args > 0 then
        if args[1] == 'gui' or args[1] == 'show' or args[1] == 'open' then
            Module.ShowGUI = not Module.ShowGUI
            if Module.ShowGUI then
                MyUI_Utils.PrintOutput('MyUI', nil, '\ayMyBuffs.\ao Toggling GUI \atOpen\ax.')
            else
                MyUI_Utils.PrintOutput('MyUI', nil, '\ayMyBuffs.\ao Toggling GUI \atClosed\ax.')
            end
        elseif args[1] == 'exit' or args[1] == 'quit' then
            MyUI_Utils.PrintOutput('MyUI', nil, '\ayMyBuffs.\ao Exiting.')
            if not solo then SayGoodBye() end
            Module.IsRunning = false
        elseif args[1] == 'mailbox' then
            Module.MailBoxShow = not Module.MailBoxShow
        end
    else
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayMyBuffs.\ao No command given.')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayMyBuffs.\ag /mybuffs gui \ao- Toggles the GUI on and off.')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayMyBuffs.\ag /mybuffs exit \ao- Exits the plugin.')
    end
end

function Module.Unload()
    mq.unbind('/mybuffs')
    SayGoodBye()
    MyBuffs_Actor = nil
end

local arguments = { ..., }

local function init()
    if loadedExeternally then
        Module.CheckMode()
    else
        Module.CheckArgs(arguments)
    end
    -- check for theme file or load defaults from our themes.lua
    loadSettings()
    currZone = mq.TLO.Zone.ID()
    lastZone = currZone
    if not solo then
        MessageHandler()
    end

    GetBuffs()
    firstRun = false

    mq.bind('/mybuffs', processCommand)
    Module.IsRunning = true
    if not loadedExeternally then
        mq.imgui.init(Module.Nam, Module.RenderGUI)
        Module.LocalLoop()
    end
end

function Module.MainLoop()
    if loadedExeternally then
        ---@diagnostic disable-next-line: undefined-global
        if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
    end

    if mq.gettime() - clockTimer >= 10 then
        currZone = mq.TLO.Zone.ID()
        if currZone ~= lastZone then
            lastZone = currZone
        end
        if not solo then CheckStale() end
        GetBuffs()
        clockTimer = mq.gettime()
    end
end

function Module.LocalLoop()
    while Module.IsRunning do
        Module.MainLoop()
        mq.delay(1)
    end
end

init()
return Module
