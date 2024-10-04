-- Imports
local mq                                                                                                              = require('mq')
local ImGui                                                                                                           = require('ImGui')

local MyBuffs                                                                                                         = {}
MyBuffs.ActorMailBox                                                                                                  = 'my_buffs'
-- Config Paths
local themeFile                                                                                                       = mq.configDir .. '/MyThemeZ.lua'
local configFileOld                                                                                                   = mq.configDir .. '/MyUI_Configs.lua'
local configFile                                                                                                      = ''
local MyBuffs_Actor
-- Tables
MyBuffs.boxes                                                                                                         = {}
MyBuffs.settings                                                                                                      = {}
MyBuffs.timerColor                                                                                                    = {}
MyBuffs.theme                                                                                                         = {}
MyBuffs.buffTable                                                                                                     = {}
MyBuffs.songTable                                                                                                     = {}

-- local Variables
MyBuffs.ShowGUI, MyBuffs.SplitWin, MyBuffs.ShowConfig, MyBuffs.MailBoxShow, MyBuffs.ShowDebuffs, MyBuffs.showTitleBar = true, false, false, false, false, true
MyBuffs.locked, MyBuffs.ShowIcons, MyBuffs.ShowTimer, MyBuffs.ShowText, MyBuffs.ShowScroll, MyBuffs.DoPulse           = false, true, true, true, true, true
MyBuffs.iconSize                                                                                                      = 24

local winFlag                                                                                                         = bit32.bor(ImGuiWindowFlags.NoScrollbar,
    ImGuiWindowFlags.NoScrollWithMouse, ImGuiWindowFlags.NoFocusOnAppearing)
local flashAlpha, flashAlphaT                                                                                         = 1, 255
local rise, riseT                                                                                                     = true, true
local RUNNING, firstRun, changed, solo                                                                                = true, true, false, true
local songTimer, buffTime                                                                                             = 20,
    5                                                                                                                                                 -- timers for how many Minutes left before we show the timer.
local numSlots                                                                                                        = mq.TLO.Me.MaxBuffSlots() or 0 --Max Buff Slots
local Scale                                                                                                           = 1.0
local animSpell                                                                                                       = mq.FindTextureAnimation('A_SpellIcons')
local gIcon                                                                                                           = MyUI_Icons.MD_SETTINGS
local activeButton                                                                                                    = MyUI_CharLoaded -- Initialize the active button with the first box's name
local PulseSpeed                                                                                                      = 5
local script                                                                                                          = 'MyBuffs'
local themeName                                                                                                       = 'Default'
local mailBox                                                                                                         = {}
local useWinPos                                                                                                       = false
local ShowMenu                                                                                                        = false
local sortType                                                                                                        = 'none'
local showTableView                                                                                                   = true
local winPositions                                                                                                    = {
    Config = { x = 500, y = 500, },
    MailBox = { x = 500, y = 500, },
    Debuffs = { x = 500, y = 500, },
    Buffs = { x = 500, y = 500, },
    Songs = { x = 500, y = 500, },
}
local winSizes                                                                                                        = {
    Config = { x = 300, y = 500, },
    MailBox = { x = 500, y = 500, },
    Debuffs = { x = 500, y = 500, },
    Buffs = { x = 200, y = 300, },
    Songs = { x = 200, y = 300, },
}
-- Timing Variables
local lastTime                                                                                                        = os.clock()
local checkIn                                                                                                         = os.time()
local frameTime                                                                                                       = 1 / 60
local debuffOnMe                                                                                                      = {}
local currZone, lastZone

-- default config settings
MyBuffs.defaults                                                                                                      = {
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

local clockTimer                                                                                                      = mq.gettime()

-- Functions

---comment
---@param inTable table @Table to sort
---@param sortOrder string @Sort Order accepts (alpha, dur, none)
---@return table @Returns a sorted table
local function SortBuffs(inTable, sortOrder)
    if sortOrder == 'none' or sortOrder == nil then return MyBuffs.buffTable end
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

    if #MyBuffs.boxes == 0 or firstRun then
        subject = 'Hello'
        firstRun = false
    end

    local content = {
        Who = mq.TLO.Me.DisplayName(),
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
        SortedBuffsA = SortBuffs(MyBuffs.buffTable, 'alpha'),
        SortedBuffsD = SortBuffs(MyBuffs.buffTable, 'dur'),
        SortedSongsA = SortBuffs(MyBuffs.songTable, 'alpha'),
        SortedSongsD = SortBuffs(MyBuffs.songTable, 'dur'),
    }
    checkIn = os.time()
    return content
end

local function GetBuff(slot)
    local fixSlotNum = slot + 1
    local buffTooltip, buffName, buffDuration, buffIcon, buffID, buffBeneficial, buffHr, buffMin, buffSec, totalMin, totalSec, buffDurHMS
    if mq.TLO.MacroQuest.BuildName() == 'Emu' then
        -- buffs are updated more reliably on the BuffWindow ingame on EMU as you will have to periodically retarget yourself to refresh the buffs otherwise.
        buffTooltip = mq.TLO.Window('BuffWindow').Child('BW_Buff' .. slot .. '_Button').Tooltip() or ''
        buffName = (buffTooltip ~= '' and buffTooltip:find('%(')) and buffTooltip:sub(1, buffTooltip:find('%(') - 2) or ''
        buffDuration = (buffTooltip ~= '' and buffTooltip:find('%(')) and buffTooltip:sub(buffTooltip:find('%(') + 1, buffTooltip:find('%)') - 1) or ''
        buffIcon = mq.TLO.Spell(buffName).SpellIcon() or 0
        buffID = buffName ~= '' and (mq.TLO.Spell(buffName).ID() or 0) or 0
        buffBeneficial = mq.TLO.Spell(buffName).Beneficial() or false

        -- Extract hours, minutes, and seconds from buffDuration
        buffHr, buffMin, buffSec = buffDuration:match("(%d+)h"), buffDuration:match("(%d+)m"), buffDuration:match("(%d+)s")
        buffHr = buffHr and string.format("%02d", tonumber(buffHr)) or "00"
        buffMin = buffMin and string.format("%02d", tonumber(buffMin)) or "00"
        buffSec = buffSec and string.format("%02d", tonumber(buffSec)) or "00"

        -- Calculate total minutes and total seconds
        totalMin = tonumber(buffHr) * 60 + tonumber(buffMin)
        totalSec = tonumber(totalMin) * 60 + tonumber(buffSec)
        buffDurHMS = ''

        buffDurHMS = buffHr .. ":" .. buffMin .. ":" .. buffSec
    else
        buffName = mq.TLO.Me.Buff(fixSlotNum).Name() or ''
        buffDuration = mq.TLO.Me.Buff(fixSlotNum).Duration.TimeHMS() or ''
        buffIcon = mq.TLO.Me.Buff(fixSlotNum).SpellIcon() or 0
        buffID = mq.TLO.Me.Buff(fixSlotNum).ID() or 0
        buffBeneficial = mq.TLO.Me.Buff(fixSlotNum).Beneficial() or false

        -- Extract hours, minutes, and seconds from buffDuration
        buffHr = mq.TLO.Me.Buff(fixSlotNum).Duration.Hours() or 0
        buffMin = mq.TLO.Me.Buff(fixSlotNum).Duration.Minutes() or 0
        buffSec = mq.TLO.Me.Buff(fixSlotNum).Duration.Seconds() or 0

        -- Calculate total minutes and total seconds
        totalMin = mq.TLO.Me.Buff(fixSlotNum).Duration.TotalMinutes() or 0
        totalSec = mq.TLO.Me.Buff(fixSlotNum).Duration.TotalSeconds() or 0
        -- print(totalSec)
        buffDurHMS = mq.TLO.Me.Buff(fixSlotNum).Duration.TimeHMS() or ''
        buffTooltip = string.format("%s) %s (%s)", fixSlotNum, buffName, buffDurHMS)
    end

    if MyBuffs.buffTable[fixSlotNum] ~= nil then
        if MyBuffs.buffTable[fixSlotNum].ID ~= buffID or (buffID > 0 and totalSec < 20) then changed = true end
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
                    Icon = buffIcon,
                    ID = buffID,
                    Hours = buffHr,
                    Slot = fixSlotNum,
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
                Icon = buffIcon,
                ID = buffID,
                Hours = buffHr,
                Slot = fixSlotNum,
                Minutes = buffMin,
                Seconds = buffSec,
                TotalMinutes = totalMin,
                TotalSeconds = totalSec,
                Tooltip = buffTooltip,
            })
        end
    end
    MyBuffs.buffTable[fixSlotNum] = {
        Name = buffName,
        Beneficial = buffBeneficial,
        Duration = buffDurHMS,
        Icon = buffIcon,
        ID = buffID,
        Slot = fixSlotNum,
        Hours = buffHr,
        Minutes = buffMin,
        Seconds = buffSec,
        TotalMinutes = totalMin,
        TotalSeconds = totalSec,
        Tooltip = buffTooltip,
    }
end

local function GetSong(slot)
    local fixSlotNum = slot + 1
    local songTooltip, songName, songDuration, songIcon, songID, songBeneficial, songHr, songMin, songSec, totalMin, totalSec, songDurHMS
    songName = mq.TLO.Me.Song(fixSlotNum).Name() or ''
    songIcon = mq.TLO.Me.Song(fixSlotNum).SpellIcon() or 0
    songID = songName ~= '' and (mq.TLO.Me.Song(fixSlotNum).ID() or 0) or 0
    songBeneficial = mq.TLO.Me.Song(fixSlotNum).Beneficial() or false
    totalMin = mq.TLO.Me.Song(fixSlotNum).Duration.TotalMinutes() or 0
    totalSec = mq.TLO.Me.Song(fixSlotNum).Duration.TotalSeconds() or 0

    if mq.TLO.MacroQuest.BuildName() == "Emu" then
        songTooltip = mq.TLO.Window('ShortDurationBuffWindow').Child('SDBW_Buff' .. slot .. '_Button').Tooltip() or ''
        if songTooltip:find('%(') then
            songDuration = songTooltip ~= '' and songTooltip:sub(songTooltip:find('%(') + 1, songTooltip:find('%)') - 1) or ''
        else
            songDuration = '99h 99m 99s'
        end
        songHr, songMin, songSec = songDuration:match("(%d+)h"), songDuration:match("(%d+)m"), songDuration:match("(%d+)s")

        -- Extract hours, minutes, and seconds from songDuration
        songHr = songHr and string.format("%02d", tonumber(songHr)) or "00"
        songMin = songMin and string.format("%02d", tonumber(songMin)) or "00"
        songSec = songSec and string.format("%02d", tonumber(songSec)) or "99"

        -- Calculate total minutes and total seconds
        songDurHMS = ""
        if songHr == "99" then
            songDurHMS = "Permanent"
            totalSec = 99999
        else
            songDurHMS = songHr .. ":" .. songMin .. ":" .. songSec
        end
    else
        songDurHMS = mq.TLO.Me.Song(fixSlotNum).Duration.TimeHMS() or ''
        songHr = mq.TLO.Me.Song(fixSlotNum).Duration.Hours() or 0
        songMin = mq.TLO.Me.Song(fixSlotNum).Duration.Minutes() or 0
        songSec = mq.TLO.Me.Song(fixSlotNum).Duration.Seconds() or 0
        songTooltip = string.format("%s) %s (%s)", fixSlotNum, songName, songDurHMS)
    end

    if MyBuffs.songTable[slot + 1] ~= nil then
        if MyBuffs.songTable[slot + 1].ID ~= songID and os.time() - checkIn >= 6 then changed = true end
    end
    MyBuffs.songTable[fixSlotNum] = {
        Name = songName,
        Beneficial = songBeneficial,
        Duration = songDurHMS,
        Icon = songIcon,
        ID = songID,
        Slot = fixSlotNum,
        Hours = songHr,
        Minutes = songMin,
        Seconds = songSec,
        TotalMinutes = totalMin,
        TotalSeconds = totalSec,
        Tooltip = songTooltip,
    }
end

local function pulseIcon(speed)
    local currentTime = os.clock()
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
    for i = 1, #MyBuffs.boxes do
        if MyBuffs.boxes[1].Check == nil then
            table.remove(MyBuffs.boxes, i)
            found = true
            break
        else
            if now - MyBuffs.boxes[i].Check > 300 then
                table.remove(MyBuffs.boxes, i)
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
    if numSlots == 0 then return end
    for i = 0, numSlots - 1 do
        GetBuff(i)
    end
    if mq.TLO.Me.CountSongs() > 0 then
        for i = 0, 19 do
            GetSong(i)
        end
    end

    if CheckIn() then
        changed = true
        subject = 'CheckIn'
    end
    if firstRun then subject = 'Hello' end
    if not solo then
        if changed or firstRun then
            MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent(subject, MyBuffs.songTable, MyBuffs.buffTable))
            MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent(subject, MyBuffs.songTable, MyBuffs.buffTable))
            changed = false
        else
            for i = 1, #MyBuffs.boxes do
                if MyBuffs.boxes[i].Who == mq.TLO.Me.DisplayName() then
                    MyBuffs.boxes[i].Buffs = MyBuffs.buffTable
                    MyBuffs.boxes[i].Songs = MyBuffs.songTable
                    MyBuffs.boxes[i].SongCount = mq.TLO.Me.CountSongs() or 0
                    MyBuffs.boxes[i].BuffSlots = numSlots
                    MyBuffs.boxes[i].BuffCount = mq.TLO.Me.BuffCount() or 0
                    MyBuffs.boxes[i].Hello = false
                    MyBuffs.boxes[i].Debuffs = debuffOnMe
                    MyBuffs.boxes[i].SortedBuffsA = SortBuffs(MyBuffs.buffTable, 'alpha')
                    MyBuffs.boxes[i].SortedBuffsD = SortBuffs(MyBuffs.buffTable, 'dur')
                    MyBuffs.boxes[i].SortedSongsA = SortBuffs(MyBuffs.songTable, 'alpha')
                    MyBuffs.boxes[i].SortedSongsD = SortBuffs(MyBuffs.songTable, 'dur')
                    break
                end
            end
        end
    else
        if MyBuffs.boxes[1] == nil then
            table.insert(MyBuffs.boxes, {
                Who = mq.TLO.Me.DisplayName(),
                Buffs = MyBuffs.buffTable,
                Songs = MyBuffs.songTable,
                Check = os.time(),
                BuffSlots = numSlots,
                BuffCount = mq.TLO.Me.BuffCount(),
                Debuffs = debuffOnMe,
                SortedBuffsA = SortBuffs(MyBuffs.buffTable, 'alpha'),
                SortedBuffsD = SortBuffs(MyBuffs.buffTable, 'dur'),
                SortedSongsA = SortBuffs(MyBuffs.songTable, 'alpha'),
                SortedSongsD = SortBuffs(MyBuffs.songTable, 'dur'),
            })
        else
            MyBuffs.boxes[1].Buffs = MyBuffs.buffTable
            MyBuffs.boxes[1].Songs = MyBuffs.songTable
            MyBuffs.boxes[1].Who = mq.TLO.Me.DisplayName()
            MyBuffs.boxes[1].BuffCount = mq.TLO.Me.BuffCount() or 0
            MyBuffs.boxes[1].SongCount = mq.TLO.Me.CountSongs() or 0
            MyBuffs.boxes[1].BuffSlots = numSlots
            MyBuffs.boxes[1].Check = os.time()
            MyBuffs.boxes[1].Debuffs = debuffOnMe
            MyBuffs.boxes[1].SortedBuffsA = SortBuffs(MyBuffs.buffTable, 'alpha')
            MyBuffs.boxes[1].SortedBuffsD = SortBuffs(MyBuffs.buffTable, 'dur')
            MyBuffs.boxes[1].SortedSongsA = SortBuffs(MyBuffs.songTable, 'alpha')
            MyBuffs.boxes[1].SortedSongsD = SortBuffs(MyBuffs.songTable, 'dur')
        end
    end
end

local function MessageHandler()
    MyBuffs_Actor = MyUI_Actor.register('my_buffs', function(message)
        local MemberEntry    = message()
        local who            = MemberEntry.Who or 'Unknown'
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
                if MemberEntry.DoWho == mq.TLO.Me.DisplayName() then
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
            if who ~= mq.TLO.Me.DisplayName() and who ~= 'Unknown' then
                MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent('Welcome', MyBuffs.songTable, MyBuffs.buffTable))
                MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent('Welcome', MyBuffs.songTable, MyBuffs.buffTable))
            end
        end

        if MemberEntry.Subject == 'Goodbye' and who ~= 'Unknown' then
            check = 0
        end
        -- Process the rest of the message into the groupData table.
        if MemberEntry.Subject ~= 'Action' and who ~= 'Unknown' then
            for i = 1, #MyBuffs.boxes do
                if MyBuffs.boxes[i].Who == who then
                    MyBuffs.boxes[i].Buffs = charBuffs
                    MyBuffs.boxes[i].Songs = charSongs
                    MyBuffs.boxes[i].Check = check
                    MyBuffs.boxes[i].BuffSlots = charSlots
                    MyBuffs.boxes[i].BuffCount = charCount
                    MyBuffs.boxes[i].Debuffs = debuffActor
                    MyBuffs.boxes[i].SongCount = MemberEntry.SongCount or 0
                    MyBuffs.boxes[i].SortedBuffsA = charSortBuffsA
                    MyBuffs.boxes[i].SortedBuffsD = charSortBuffsD
                    MyBuffs.boxes[i].SortedSongsA = charSortSongsA
                    MyBuffs.boxes[i].SortedSongsD = charSortSongsD
                    found = true
                    break
                end
            end
            if not found then
                table.insert(MyBuffs.boxes, {
                    Who          = who,
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
        Who = mq.TLO.Me.DisplayName(),
        Check = 0,
    }
    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, message)
    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, message)
end

local function loadTheme()
    if MyUI_Utils.File.Exists(themeFile) then
        MyBuffs.theme = dofile(themeFile)
    else
        MyBuffs.theme = require('defaults.themes')
        mq.pickle(themeFile, MyBuffs.theme)
    end
    themeName = MyBuffs.theme.LoadTheme or 'notheme'
end

local function loadSettings()
    local newSetting = false
    if not MyUI_Utils.File.Exists(configFile) then
        if MyUI_Utils.File.Exists(configFileOld) then
            local tmp = dofile(configFileOld)
            MyBuffs.settings[script] = tmp[script]
        else
            MyBuffs.settings[script] = MyBuffs.defaults
        end
        mq.pickle(configFile, MyBuffs.settings)
        loadSettings()
    else
        -- Load settings from the Lua config file
        MyBuffs.timerColor = {}
        MyBuffs.settings = dofile(configFile)
        if MyBuffs.settings[script] == nil then
            MyBuffs.settings[script] = {}
            MyBuffs.settings[script] = MyBuffs.defaults
            newSetting = true
        end
        MyBuffs.timerColor = MyBuffs.settings[script]
    end

    loadTheme()

    if MyBuffs.settings[script].WindowPositions == nil then
        MyBuffs.settings[script].WindowPositions = {}
        newSetting = true
    end
    if MyBuffs.settings[script].WindowSizes == nil then
        MyBuffs.settings[script].WindowSizes = {}
    end
    for k, v in pairs(MyBuffs.defaults.WindowPositions) do
        if MyBuffs.settings[script].WindowPositions[k] == nil then
            MyBuffs.settings[script].WindowPositions[k] = v
            newSetting = true
        end
    end
    for k, v in pairs(MyBuffs.defaults.WindowSizes) do
        if MyBuffs.settings[script].WindowSizes == nil then
            MyBuffs.settings[script].WindowSizes = {}
        end
        if MyBuffs.settings[script].WindowSizes[k] == nil then
            MyBuffs.settings[script].WindowSizes[k] = v
            newSetting = true
        end
    end
    for k, v in pairs(MyBuffs.defaults) do
        if k ~= 'WindowPositions' and k ~= 'WindowSizes' then
            if MyBuffs.settings[script][k] == nil then
                MyBuffs.settings[script][k] = v
                newSetting = true
            end
        end
    end
    MyBuffs.showTitleBar = MyBuffs.settings[script].ShowTitleBar
    showTableView = MyBuffs.settings[script].TableView
    PulseSpeed = MyBuffs.settings[script].PulseSpeed
    MyBuffs.DoPulse = MyBuffs.settings[script].DoPulse
    MyBuffs.timerColor = MyBuffs.settings[script].TimerColor
    MyBuffs.ShowScroll = MyBuffs.settings[script].ShowScroll
    songTimer = MyBuffs.settings[script].SongTimer
    buffTime = MyBuffs.settings[script].BuffTimer
    MyBuffs.SplitWin = MyBuffs.settings[script].SplitWin
    MyBuffs.ShowTimer = MyBuffs.settings[script].ShowTimer
    MyBuffs.ShowText = MyBuffs.settings[script].ShowText
    MyBuffs.ShowIcons = MyBuffs.settings[script].ShowIcons
    MyBuffs.ShowDebuffs = MyBuffs.settings[script].ShowDebuffs
    ShowMenu = MyBuffs.settings[script].ShowMenu
    MyBuffs.iconSize = MyBuffs.settings[script].IconSize
    MyBuffs.locked = MyBuffs.settings[script].locked
    Scale = MyBuffs.settings[script].Scale
    themeName = MyBuffs.settings[script].LoadTheme
    winPositions = MyBuffs.settings[script].WindowPositions
    useWinPos = MyBuffs.settings[script].UseWindowPositions

    sortType = MyBuffs.settings[script].SortBy
    if newSetting then mq.pickle(configFile, MyBuffs.settings) end
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
        ImGui.InvisibleButton("slot" .. tostring(slotNum), ImVec2(MyBuffs.iconSize, MyBuffs.iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
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
        ImGui.GetCursorScreenPosVec() + MyBuffs.iconSize, beniColor)
    ImGui.SetCursorPos(cursor_x + 3, cursor_y + 3)
    ImGui.DrawTextureAnimation(animSpell, MyBuffs.iconSize - 5, MyBuffs.iconSize - 5)
    ImGui.SetCursorPos(cursor_x + 2, cursor_y + 2)
    local sName = spell.Name or '??'
    local sDur = spell.TotalSeconds or 0
    ImGui.PushID(tostring(iconID) .. sName .. "_invis_btn")
    if sDur < 18 and sDur > 0 and MyBuffs.DoPulse then
        pulseIcon(PulseSpeed)
        local flashColor = IM_COL32(0, 0, 0, flashAlpha)
        ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
            ImGui.GetCursorScreenPosVec() + MyBuffs.iconSize - 4, flashColor)
    end
    ImGui.SetCursorPos(cursor_x, cursor_y)
    ImGui.InvisibleButton(sName, ImVec2(MyBuffs.iconSize, MyBuffs.iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
    ImGui.PopID()
end

---comment
---@param tName string -- name of the theme to load form table
---@return integer, integer -- returns the new counter values
local function DrawTheme(tName)
    local StyleCounter = 0
    local ColorCounter = 0
    for tID, tData in pairs(MyBuffs.theme.Theme) do
        if tData.Name == tName then
            for pID, cData in pairs(MyBuffs.theme.Theme[tID].Color) do
                ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
                ColorCounter = ColorCounter + 1
            end
            if tData['Style'] ~= nil then
                if next(tData['Style']) ~= nil then
                    for sID, sData in pairs(MyBuffs.theme.Theme[tID].Style) do
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
    local boxChar = MyBuffs.boxes[id].Who or '?'
    local boxBuffs = (sorted == 'alpha' and MyBuffs.boxes[id].SortedBuffsA) or (sorted == 'dur' and MyBuffs.boxes[id].SortedBuffsD) or MyBuffs.boxes[id].Buffs
    local buffSlots = MyBuffs.boxes[id].BuffSlots or 0
    local sizeX, sizeY = ImGui.GetContentRegionAvail()

    -------------------------------------------- Buffs Section ---------------------------------
    if not MyBuffs.SplitWin then sizeY = math.floor(sizeY * 0.7) else sizeY = 0.0 end
    if not MyBuffs.ShowScroll and view ~= 'table' then
        ImGui.BeginChild("Buffs##" .. boxChar .. view, ImVec2(sizeX, sizeY), ImGuiChildFlags.Border, ImGuiWindowFlags.NoScrollbar)
    elseif view ~= 'table' and MyBuffs.ShowScroll then
        ImGui.BeginChild("Buffs##" .. boxChar .. view, ImVec2(sizeX, sizeY), ImGuiChildFlags.Border)
    elseif view == 'table' then
        ImGui.BeginChild("Buffs##" .. boxChar, ImVec2(ImGui.GetColumnWidth(-1), 0.0), bit32.bor(ImGuiChildFlags.AutoResizeY, ImGuiChildFlags.AlwaysAutoResize),
            bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.AlwaysAutoResize))
    end
    local startNum, slot = 1, 1
    local rowMax = math.floor(ImGui.GetColumnWidth(-1) / (MyBuffs.iconSize)) or 1
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
                sDurT = boxBuffs[i].Duration ~= nil and boxBuffs[i].Duration or ' '
                if MyBuffs.ShowIcons then
                    DrawInspectableSpellIcon(boxBuffs[i].Icon, boxBuffs[i], slot)
                    ImGui.SameLine()
                end
                if boxChar == mq.TLO.Me.DisplayName() then
                    if MyBuffs.ShowTimer then
                        local sDur = boxBuffs[i].TotalMinutes or 0
                        if sDur < buffTime then
                            ImGui.PushStyleColor(ImGuiCol.Text, MyBuffs.timerColor[1], MyBuffs.timerColor[2], MyBuffs.timerColor[3], MyBuffs.timerColor[4])
                            ImGui.Text(" %s ", sDurT)
                            ImGui.PopStyleColor()
                        else
                            ImGui.Text(' ')
                        end
                        ImGui.SameLine()
                    end
                else
                    if MyBuffs.ShowTimer then
                        local sDur = boxBuffs[i].TotalSeconds or 0
                        if sDur < 20 then
                            ImGui.PushStyleColor(ImGuiCol.Text, MyBuffs.timerColor[1], MyBuffs.timerColor[2], MyBuffs.timerColor[3], MyBuffs.timerColor[4])
                            ImGui.Text(" %s ", sDurT)
                            ImGui.PopStyleColor()
                        else
                            ImGui.Text(' ')
                        end
                        ImGui.SameLine()
                    end
                end

                if MyBuffs.ShowText and boxBuffs[i].Name ~= '' then
                    ImGui.Text(boxBuffs[i].Name)
                end
            end
            ImGui.EndGroup()
        else
            ImGui.BeginGroup()

            if boxBuffs[i] ~= nil then
                bName = boxBuffs[i].Name:sub(1, -1)
                sDurT = boxBuffs[i].Duration or ' '

                DrawInspectableSpellIcon(boxBuffs[i].Icon, boxBuffs[i], slot)
                rowCount = rowCount + 1
                drawn = true
            end
            ImGui.EndGroup()
        end

        if ImGui.BeginPopupContextItem("##Buff" .. tostring(i)) then
            if boxChar == mq.TLO.Me.DisplayName() then
                if ImGui.MenuItem("Inspect##" .. boxBuffs[i].Slot) then
                    mq.TLO.Me.Buff(bName).Inspect()
                end
            end

            if ImGui.MenuItem("Block##" .. i) then
                local what = string.format('blockbuff%s', boxBuffs[i].Name)
                if not solo then
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent('Action', MyBuffs.songTable, MyBuffs.buffTable, boxChar, what))
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent('Action', MyBuffs.songTable, MyBuffs.buffTable, boxChar, what))
                else
                    mq.cmdf("/blockspell add me '%s'", mq.TLO.Spell(bName).ID())
                end
            end

            if ImGui.MenuItem("Remove##" .. i) then
                local what = string.format('buff%s', boxBuffs[i].Name)
                if not solo then
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent('Action', MyBuffs.songTable, MyBuffs.buffTable, boxChar, what))
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent('Action', MyBuffs.songTable, MyBuffs.buffTable, boxChar, what))
                else
                    mq.TLO.Me.Buff(bName).Remove()
                end
            end
            ImGui.EndPopup()
        end
        if ImGui.IsItemHovered() then
            if ImGui.IsMouseDoubleClicked(0) then
                local what = string.format('buff%s', boxBuffs[i].Name)
                if not solo then
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent('Action', MyBuffs.songTable, MyBuffs.buffTable, boxChar, what))
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent('Action', MyBuffs.songTable, MyBuffs.buffTable, boxChar, what))
                else
                    mq.TLO.Me.Buff(bName).Remove()
                end
            end
            ImGui.BeginTooltip()
            if boxBuffs[i] ~= nil then
                if boxBuffs[i].Icon > 0 then
                    if boxChar == mq.TLO.Me.DisplayName() then
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
    if #MyBuffs.boxes == 0 then return end
    if sorted == nil then sorted = 'none' end
    local boxChar = MyBuffs.boxes[id].Who or '?'
    local boxSongs = (sorted == 'alpha' and MyBuffs.boxes[id].SortedSongsA) or (sorted == 'dur' and MyBuffs.boxes[id].SortedSongsD) or MyBuffs.boxes[id].Songs
    local sCount = MyBuffs.boxes[id].SongCount or 0
    local sizeX, sizeY = ImGui.GetContentRegionAvail()
    sizeX, sizeY = math.floor(sizeX), 0.0

    --------- Songs Section -----------------------
    if MyBuffs.ShowScroll and view ~= 'table' then
        ImGui.BeginChild("Songs##" .. boxChar, ImVec2(sizeX, sizeY), ImGuiChildFlags.Border)
    elseif view ~= 'table' and not MyBuffs.ShowScroll then
        ImGui.BeginChild("Songs##" .. boxChar, ImVec2(sizeX, sizeY), ImGuiChildFlags.Border, ImGuiWindowFlags.NoScrollbar)
    elseif view == 'table' then
        ImGui.BeginChild("Songs##" .. boxChar, ImVec2(ImGui.GetColumnWidth(-1), 0.0), bit32.bor(ImGuiChildFlags.AutoResizeY, ImGuiChildFlags.AlwaysAutoResize),
            bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.AlwaysAutoResize))
    end
    local rowCounterS = 0
    local maxSongRow = math.floor(ImGui.GetColumnWidth(-1) / (MyBuffs.iconSize)) or 1
    local counterSongs = 0
    for i = 1, 20 do
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
                if MyBuffs.ShowIcons then
                    DrawInspectableSpellIcon(boxSongs[i].Icon, boxSongs[i], i)

                    ImGui.SameLine()
                end
                if boxChar == mq.TLO.Me.DisplayName() then
                    if MyBuffs.ShowTimer then
                        local sngDurS = boxSongs[i].TotalSeconds or 0
                        if sngDurS < songTimer then
                            ImGui.PushStyleColor(ImGuiCol.Text, MyBuffs.timerColor[1], MyBuffs.timerColor[2], MyBuffs.timerColor[3], MyBuffs.timerColor[4])
                            ImGui.Text(" %ss ", sngDurS)
                            ImGui.PopStyleColor()
                        else
                            ImGui.Text(' ')
                        end
                        ImGui.SameLine()
                    end
                end
                if MyBuffs.ShowText then
                    ImGui.Text(boxSongs[i].Name)
                end
                counterSongs = counterSongs + 1
            end
            ImGui.EndGroup()
        else
            ImGui.BeginGroup()
            if boxSongs[i] ~= nil then
                if boxSongs[i].Icon > 0 then
                    if MyBuffs.ShowIcons then
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
                if not solo then
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent('Action', MyBuffs.songTable, MyBuffs.buffTable, boxChar, what))
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent('Action', MyBuffs.songTable, MyBuffs.buffTable, boxChar, what))
                else
                    mq.cmdf("/blocksong add me '%s'", boxSongs[i].Name)
                end
            end
            if ImGui.MenuItem("Remove##" .. i) then
                local what = string.format('song%s', boxSongs[i].Name)
                if not solo then
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', }, GenerateContent('Action', MyBuffs.songTable, MyBuffs.buffTable, boxChar, what))
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', }, GenerateContent('Action', MyBuffs.songTable, MyBuffs.buffTable, boxChar, what))
                else
                    mq.TLO.Me.Song(boxSongs[i].Name).Remove()
                end
            end
            ImGui.EndPopup()
        end
        if ImGui.IsItemHovered() then
            if ImGui.IsMouseDoubleClicked(0) then
                if not solo then
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'mybuffs', },
                        GenerateContent('Action', MyBuffs.songTable, MyBuffs.buffTable, boxChar, 'song' .. boxSongs[i].Name))
                    MyBuffs_Actor:send({ mailbox = 'my_buffs', script = 'myui', },
                        GenerateContent('Action', MyBuffs.songTable, MyBuffs.buffTable, boxChar, 'song' .. boxSongs[i].Name))
                else
                    mq.TLO.Me.Song(boxSongs[i].Name).Remove()
                end
            end
            ImGui.BeginTooltip()
            if boxSongs[i] ~= nil then
                if boxSongs[i].Icon > 0 then
                    if boxChar == mq.TLO.Me.DisplayName() then
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
        return a.Who < b.Who
    end)
    return boxes
end

function MyBuffs.RenderGUI()
    if currZone ~= lastZone then return end

    if MyBuffs.ShowGUI then
        ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
        local flags = winFlag
        if MyBuffs.locked then
            flags = bit32.bor(ImGuiWindowFlags.NoMove, flags)
        end
        if not MyBuffs.settings[script].ShowTitleBar then
            flags = bit32.bor(ImGuiWindowFlags.NoTitleBar, flags)
        end
        if not MyBuffs.ShowScroll then
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
        local splitIcon = MyBuffs.SplitWin and MyUI_Icons.FA_TOGGLE_ON or MyUI_Icons.FA_TOGGLE_OFF
        local sortIcon = sortType == 'none' and MyUI_Icons.FA_SORT_NUMERIC_ASC or sortType == 'alpha' and MyUI_Icons.FA_SORT_ALPHA_ASC or MyUI_Icons.MD_TIMER
        local lockedIcon = MyBuffs.locked and MyUI_Icons.FA_LOCK or MyUI_Icons.FA_UNLOCK
        local openGUI, showMain = ImGui.Begin("MyBuffs##" .. mq.TLO.Me.DisplayName(), true, flags)
        if not openGUI then
            MyBuffs.ShowGUI = false
        end
        if showMain then
            if ImGui.BeginMenuBar() then
                if ImGui.Button(lockedIcon .. "##lockTabButton_MyBuffs") then
                    MyBuffs.locked = not MyBuffs.locked

                    MyBuffs.settings[script].locked = MyBuffs.locked
                    mq.pickle(configFile, MyBuffs.settings)
                end

                if ImGui.IsItemHovered() then
                    ImGui.BeginTooltip()
                    ImGui.Text("Lock Window")
                    ImGui.EndTooltip()
                end
                if ImGui.BeginMenu('Menu') then
                    if ImGui.Selectable(gIcon .. " Settings") then
                        MyBuffs.ShowConfig = not MyBuffs.ShowConfig
                    end

                    if ImGui.Selectable(MyUI_Icons.FA_TABLE .. " Show Table") then
                        showTableView = not showTableView
                        MyBuffs.settings[script].TableView = showTableView
                        mq.pickle(configFile, MyBuffs.settings)
                    end

                    if ImGui.Selectable(splitIcon .. " Split Window") then
                        MyBuffs.SplitWin = not MyBuffs.SplitWin

                        MyBuffs.settings[script].SplitWin = MyBuffs.SplitWin
                        mq.pickle(configFile, MyBuffs.settings)
                    end

                    if ImGui.BeginMenu(sortIcon .. " Sort Menu") then
                        if ImGui.Selectable(MyUI_Icons.FA_SORT_NUMERIC_ASC .. " Sort by Slot") then
                            sortType = 'none'
                            MyBuffs.settings[script].SortBy = sortType
                            mq.pickle(configFile, MyBuffs.settings)
                        end
                        if ImGui.Selectable(MyUI_Icons.FA_SORT_ALPHA_ASC .. " Sort by Name") then
                            sortType = 'alpha'
                            MyBuffs.settings[script].SortBy = sortType
                            mq.pickle(configFile, MyBuffs.settings)
                        end
                        if ImGui.Selectable(MyUI_Icons.MD_TIMER .. " Sort by Duration") then
                            sortType = 'dur'
                            MyBuffs.settings[script].SortBy = sortType
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
                    if #MyBuffs.boxes > 0 then
                        -- Sort boxes by the 'Who' attribute
                        local sorted_boxes = sortedBoxes(MyBuffs.boxes)
                        ImGui.SetNextItemWidth(ImGui.GetWindowWidth() - 15)
                        if ImGui.BeginCombo("##CharacterCombo", activeButton) then
                            for i = 1, #sorted_boxes do
                                local box = sorted_boxes[i]
                                if ImGui.Selectable(box.Who, activeButton == box.Who) then
                                    activeButton = box.Who
                                end
                            end
                            ImGui.EndCombo()
                        end

                        -- Draw the content of the active button
                        for i = 1, #sorted_boxes do
                            if sorted_boxes[i].Who == activeButton then
                                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
                                BoxBuffs(i, sortType)
                                if not MyBuffs.SplitWin then BoxSongs(i, sortType) end
                                ImGui.PopStyleVar()
                                break
                            end
                        end
                    end
                else
                    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
                    BoxBuffs(1, sortType)
                    if not MyBuffs.SplitWin then BoxSongs(1, sortType) end
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
                    ImGui.TableSetupColumn("Who")
                    ImGui.TableSetupColumn("Buffs")
                    ImGui.TableSetupColumn("Songs")
                    ImGui.TableHeadersRow()
                    if #MyBuffs.boxes > 0 then
                        ImGui.SetWindowFontScale(Scale)
                        for i = 1, #MyBuffs.boxes do
                            ImGui.TableNextColumn()
                            ImGui.SetWindowFontScale(Scale)
                            if MyBuffs.boxes[i].Who == mq.TLO.Me.CleanName() then
                                ImGui.TextColored(ImVec4(0, 1, 1, 1), MyBuffs.boxes[i].Who)
                            else
                                ImGui.Text(MyBuffs.boxes[i].Who)
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
            MyBuffs.settings[script].WindowPositions.Buffs.x = curPosX
            MyBuffs.settings[script].WindowPositions.Buffs.y = curPosY
            MyBuffs.settings[script].WindowSizes.Buffs.x = winSizeX
            MyBuffs.settings[script].WindowSizes.Buffs.y = winSizeY
            mq.pickle(configFile, MyBuffs.settings)
        end
        if ImGui.BeginPopupContextWindow("Options") then
            local lbl = MyBuffs.locked and " Un-Lock Window" or " Lock Window"
            if ImGui.MenuItem(lockedIcon .. lbl) then
                MyBuffs.locked = not MyBuffs.locked
                MyBuffs.settings[script].locked = MyBuffs.locked
                mq.pickle(configFile, MyBuffs.settings)
            end
            if ImGui.MenuItem(gIcon .. "Settings") then
                MyBuffs.ShowConfig = not MyBuffs.ShowConfig
            end
            if ImGui.MenuItem("Show Table") then
                showTableView = not showTableView
                MyBuffs.settings[script].TableView = showTableView
                mq.pickle(configFile, MyBuffs.settings)
            end
            if ImGui.MenuItem("Split Window") then
                MyBuffs.SplitWin = not MyBuffs.SplitWin
                MyBuffs.settings[script].SplitWin = MyBuffs.SplitWin
                mq.pickle(configFile, MyBuffs.settings)
            end
            if ImGui.MenuItem(MyUI_Icons.FA_SORT_NUMERIC_ASC .. "Sort by Slot") then
                sortType = 'none'
                MyBuffs.settings[script].SortBy = sortType
                mq.pickle(configFile, MyBuffs.settings)
            end
            if ImGui.MenuItem(MyUI_Icons.FA_SORT_ALPHA_ASC .. "Sort by Name") then
                sortType = 'alpha'
                MyBuffs.settings[script].SortBy = sortType
                mq.pickle(configFile, MyBuffs.settings)
            end
            if ImGui.MenuItem(MyUI_Icons.MD_TIMER .. "Sort by Duration") then
                sortType = 'dur'
                MyBuffs.settings[script].SortBy = sortType
                mq.pickle(configFile, MyBuffs.settings)
            end
            ImGui.EndPopup()
        end
        if StyleCount > 0 then ImGui.PopStyleVar(StyleCount) end
        if ColorCount > 0 then ImGui.PopStyleColor(ColorCount) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
    end

    if MyBuffs.SplitWin then
        if currZone ~= lastZone then return end

        local flags = winFlag
        if MyBuffs.locked then
            flags = bit32.bor(ImGuiWindowFlags.NoMove, flags)
        end
        if not MyBuffs.settings[script].ShowTitleBar then
            flags = bit32.bor(ImGuiWindowFlags.NoTitleBar, flags)
        end
        if not MyBuffs.ShowScroll then
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
        local songWin, show = ImGui.Begin("MyBuffs Songs##Songs" .. mq.TLO.Me.DisplayName(), true, flags)
        ImGui.SetWindowFontScale(Scale)
        if not songWin then
            MyBuffs.SplitWin = false
        end
        if show then
            if #MyBuffs.boxes > 0 then
                for i = 1, #MyBuffs.boxes do
                    if MyBuffs.boxes[i].Who == activeButton then
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
            MyBuffs.settings[script].WindowSizes.Songs.x = winSizeX
            MyBuffs.settings[script].WindowSizes.Songs.y = winSizeY
            MyBuffs.settings[script].WindowPositions.Songs.x = curPosX
            MyBuffs.settings[script].WindowPositions.Songs.y = curPosY
            mq.pickle(configFile, MyBuffs.settings)
        end

        if StyleCountSongs > 0 then ImGui.PopStyleVar(StyleCountSongs) end
        if ColorCountSongs > 0 then ImGui.PopStyleColor(ColorCountSongs) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
    end

    if MyBuffs.ShowConfig then
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
            MyBuffs.ShowConfig = false
        end
        if showConfigGui then
            ImGui.SameLine()
            ImGui.SeparatorText('Theme')
            if ImGui.CollapsingHeader('Theme##Coll' .. script) then
                ImGui.Text("Cur Theme: %s", themeName)
                -- Combo Box Load Theme

                if ImGui.BeginCombo("Load Theme##MyBuffs", themeName) then
                    ImGui.SetWindowFontScale(Scale)
                    for k, data in pairs(MyBuffs.theme.Theme) do
                        local isSelected = data.Name == themeName
                        if ImGui.Selectable(data.Name, isSelected) then
                            MyBuffs.theme.LoadTheme = data.Name
                            themeName = MyBuffs.theme.LoadTheme
                            MyBuffs.settings[script].LoadTheme = themeName
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
            if ImGui.CollapsingHeader('Scaling##Coll' .. script) then
                -- Slider for adjusting zoom level
                local tmpZoom = Scale
                if Scale then
                    tmpZoom = ImGui.SliderFloat("Text Scale##MyBuffs", tmpZoom, 0.5, 2.0)
                end
                if Scale ~= tmpZoom then
                    Scale = tmpZoom
                end

                -- Slider for adjusting IconSize
                local tmpSize = MyBuffs.iconSize
                if MyBuffs.iconSize then
                    tmpSize = ImGui.SliderInt("Icon Size##MyBuffs", tmpSize, 15, 50)
                end
                if MyBuffs.iconSize ~= tmpSize then
                    MyBuffs.iconSize = tmpSize
                end
            end
            ImGui.SeparatorText('Timers')
            local vis = ImGui.CollapsingHeader('Timers##Coll' .. script)
            if vis then
                MyBuffs.timerColor = ImGui.ColorEdit4('Timer Color', MyBuffs.timerColor, bit32.bor(ImGuiColorEditFlags.NoInputs))

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
            if ImGui.CollapsingHeader('Toggles##Coll' .. script) then
                local tmpShowIcons = MyBuffs.ShowIcons
                tmpShowIcons = ImGui.Checkbox('Show Icons', tmpShowIcons)
                if tmpShowIcons ~= MyBuffs.ShowIcons then
                    MyBuffs.ShowIcons = tmpShowIcons
                end
                ImGui.SameLine()
                local tmpPulseIcons = MyBuffs.DoPulse
                tmpPulseIcons = ImGui.Checkbox('Pulse Icons', tmpPulseIcons)
                if tmpPulseIcons ~= MyBuffs.DoPulse then
                    MyBuffs.DoPulse = tmpPulseIcons
                end
                local tmpPulseSpeed = PulseSpeed
                if MyBuffs.DoPulse then
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
                    local tmpShowText = MyBuffs.ShowText
                    tmpShowText = ImGui.Checkbox('Show Text', tmpShowText)
                    if tmpShowText ~= MyBuffs.ShowText then
                        MyBuffs.ShowText = tmpShowText
                    end
                    ImGui.TableNextColumn()
                    local tmpShowTimer = MyBuffs.ShowTimer
                    tmpShowTimer = ImGui.Checkbox('Show Timer', tmpShowTimer)
                    if tmpShowTimer ~= MyBuffs.ShowTimer then
                        MyBuffs.ShowTimer = tmpShowTimer
                    end
                    ImGui.TableNextColumn()
                    local tmpScroll = MyBuffs.ShowScroll
                    tmpScroll = ImGui.Checkbox('Show Scrollbar', tmpScroll)
                    if tmpScroll ~= MyBuffs.ShowScroll then
                        MyBuffs.ShowScroll = tmpScroll
                    end
                    ImGui.TableNextColumn()
                    local tmpSplit = MyBuffs.SplitWin
                    tmpSplit = ImGui.Checkbox('Split Win', tmpSplit)
                    if tmpSplit ~= MyBuffs.SplitWin then
                        MyBuffs.SplitWin = tmpSplit
                    end
                    ImGui.TableNextColumn()
                    MyBuffs.MailBoxShow = ImGui.Checkbox('Show MailBox', MyBuffs.MailBoxShow)
                    ImGui.TableNextColumn()
                    MyBuffs.ShowDebuffs = ImGui.Checkbox('Show Debuffs', MyBuffs.ShowDebuffs)
                    ImGui.TableNextColumn()
                    MyBuffs.showTitleBar = ImGui.Checkbox('Show Title Bar', MyBuffs.showTitleBar)
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
                MyBuffs.settings[script].UseWindowPositions = useWinPos
                MyBuffs.settings[script].ShowTitleBar = MyBuffs.showTitleBar
                MyBuffs.settings[script].DoPulse = MyBuffs.DoPulse
                MyBuffs.settings[script].PulseSpeed = PulseSpeed
                MyBuffs.settings[script].TimerColor = MyBuffs.timerColor
                MyBuffs.settings[script].ShowScroll = MyBuffs.ShowScroll
                MyBuffs.settings[script].SongTimer = songTimer
                MyBuffs.settings[script].BuffTimer = buffTime
                MyBuffs.settings[script].IconSize = MyBuffs.iconSize
                MyBuffs.settings[script].Scale = Scale
                MyBuffs.settings[script].SplitWin = MyBuffs.SplitWin
                MyBuffs.settings[script].LoadTheme = themeName
                MyBuffs.settings[script].ShowIcons = MyBuffs.ShowIcons
                MyBuffs.settings[script].ShowText = MyBuffs.ShowText
                MyBuffs.settings[script].ShowTimer = MyBuffs.ShowTimer
                MyBuffs.settings[script].ShowDebuffs = MyBuffs.ShowDebuffs
                MyBuffs.settings[script].ShowMenu = ShowMenu
                MyBuffs.settings[script].ShowMailBox = MyBuffs.MailBoxShow
                MyBuffs.settings[script].ShowTableView = showTableView

                mq.pickle(configFile, MyBuffs.settings)

                MyBuffs.ShowConfig = false
            end
        end


        local curPosX, curPosY = ImGui.GetWindowPos()
        local curSizeX, curSizeY = ImGui.GetWindowSize()
        if curPosX ~= winPosX or curPosY ~= winPosY or curSizeX ~= winSizeX or curSizeY ~= winSizeY then
            winPositions.Config.x = curPosX
            winPositions.Config.y = curPosY
            winSizeX, winSizeY = curSizeX, curSizeY
            MyBuffs.settings[script].WindowPositions.Config.x = curPosX
            MyBuffs.settings[script].WindowPositions.Config.y = curPosY
            MyBuffs.settings[script].WindowSizes.Config.x = winSizeX
            MyBuffs.settings[script].WindowSizes.Config.y = winSizeY
            mq.pickle(configFile, MyBuffs.settings)
        end
        if StyleCountConf > 0 then ImGui.PopStyleVar(StyleCountConf) end
        if ColorCountConf > 0 then ImGui.PopStyleColor(ColorCountConf) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
    end

    if MyBuffs.ShowDebuffs then
        local found = false
        ImGui.SetNextWindowSize(80, 239, ImGuiCond.Appearing)
        local winPosX, winPosY = winPositions.Debuffs.x, winPositions.Debuffs.y
        local winSizeX, winSizeY = winSizes.Debuffs.x, winSizes.Debuffs.y
        if useWinPos then
            ImGui.SetNextWindowSize(ImVec2(winSizeX, winSizeY), ImGuiCond.Appearing)
            ImGui.SetNextWindowPos(ImVec2(winPosX, winPosY), ImGuiCond.Appearing)
        end
        for i = 1, #MyBuffs.boxes do
            if #MyBuffs.boxes[i].Debuffs > 1 then
                found = true
                break
            end
        end
        if found then
            ColorCountDebuffs, StyleCountDebuffs = DrawTheme(themeName)
            local openDebuffs, showDebuffs = ImGui.Begin("MyBuffs Debuffs##" .. mq.TLO.Me.DisplayName(), true,
                bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoFocusOnAppearing))
            ImGui.SetWindowFontScale(Scale)

            if not openDebuffs then
                MyBuffs.ShowDebuffs = false
            end
            if showDebuffs then
                for i = 1, #MyBuffs.boxes do
                    if #MyBuffs.boxes[i].Debuffs > 1 then
                        local sizeX, sizeY = ImGui.GetContentRegionAvail()
                        if ImGui.BeginChild(MyBuffs.boxes[i].Who .. "##Debuffs_" .. MyBuffs.boxes[i].Who, ImVec2(sizeX, 60), bit32.bor(ImGuiChildFlags.Border), bit32.bor(ImGuiWindowFlags.NoScrollbar)) then
                            ImGui.Text(MyBuffs.boxes[i].Who)
                            for k, v in pairs(MyBuffs.boxes[i].Debuffs) do
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
                MyBuffs.settings[script].WindowSizes.Debuffs.x = winSizeX
                MyBuffs.settings[script].WindowSizes.Debuffs.y = winSizeY
                MyBuffs.settings[script].WindowPositions.Debuffs.x = curPosX
                MyBuffs.settings[script].WindowPositions.Debuffs.y = curPosY
                mq.pickle(configFile, MyBuffs.settings)
            end
            if StyleCountDebuffs > 0 then ImGui.PopStyleVar(StyleCountDebuffs) end
            if ColorCountDebuffs > 0 then ImGui.PopStyleColor(ColorCountDebuffs) end
            ImGui.SetWindowFontScale(1)
            ImGui.End()
        end
    end

    if MyBuffs.MailBoxShow then
        local ColorCountMail, StyleCountMail = DrawTheme(themeName)
        local winPosX, winPosY = winPositions.MailBox.x, winPositions.MailBox.y
        local winSizeX, winSizeY = winSizes.MailBox.x, winSizes.MailBox.y
        if useWinPos then
            ImGui.SetNextWindowPos(ImVec2(winPosX, winPosY), ImGuiCond.Appearing)
            ImGui.SetNextWindowSize(ImVec2(winSizeX, winSizeY), ImGuiCond.Appearing)
        end
        local openMail, showMail = ImGui.Begin("MyBuffs MailBox##MailBox_MyBuffs_" .. mq.TLO.Me.Name(), true, ImGuiWindowFlags.NoFocusOnAppearing)
        if not openMail then
            MyBuffs.MailBoxShow = false
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
            MyBuffs.settings[script].WindowPositions.MailBox.x = curPosX
            MyBuffs.settings[script].WindowPositions.MailBox.y = curPosY
            MyBuffs.settings[script].WindowSizes.MailBox.x = winSizeX
            MyBuffs.settings[script].WindowSizes.MailBox.y = winSizeY
            mq.pickle(configFile, MyBuffs.settings)
        end
        if StyleCountMail > 0 then ImGui.PopStyleVar(StyleCountMail) end
        if ColorCountMail > 0 then ImGui.PopStyleColor(ColorCountMail) end
        ImGui.End()
    else
        mailBox = {}
    end
end

function MyBuffs.CheckMode()
    if MyUI_Mode == 'driver' then
        MyBuffs.ShowGUI = true
        solo = false
        print('\ayMyBuffs.\ao Setting \atDriver\ax Mode. Actors [\agEnabled\ax] UI [\agOn\ax].')
        print('\ayMyBuffs.\ao Type \at/mybuffs show\ax. to Toggle the UI')
    elseif MyUI_Mode == 'client' then
        MyBuffs.ShowGUI = false
        solo = false
        print('\ayMyBuffs.\ao Setting \atClient\ax Mode.Actors [\agEnabled\ax] UI [\arOff\ax].')
        print('\ayMyBuffs.\ao Type \at/mybuffs show\ax. to Toggle the UI')
    else
        MyBuffs.ShowGUI = true
        solo = true
        print('\ayMyBuffs.\ao Setting \atSolo\ax Mode. Actors [\arDisabled\ax] UI [\agOn\ax].')
        print('\ayMyBuffs.\ao Type \at/mybuffs show\ax. to Toggle the UI')
    end
end

local function processCommand(...)
    local args = { ..., }
    if #args > 0 then
        if args[1] == 'gui' or args[1] == 'show' or args[1] == 'open' then
            MyBuffs.ShowGUI = not MyBuffs.ShowGUI
            if MyBuffs.ShowGUI then
                print('\ayMyBuffs.\ao Toggling GUI \atOpen\ax.')
            else
                print('\ayMyBuffs.\ao Toggling GUI \atClosed\ax.')
            end
        elseif args[1] == 'exit' or args[1] == 'quit' then
            print('\ayMyBuffs.\ao Exiting.')
            if not solo then SayGoodBye() end
            RUNNING = false
        elseif args[1] == 'mailbox' then
            MyBuffs.MailBoxShow = not MyBuffs.MailBoxShow
        end
    else
        print('\ayMyBuffs.\ao No command given.')
        print('\ayMyBuffs.\ag /mybuffs gui \ao- Toggles the GUI on and off.')
        print('\ayMyBuffs.\ag /mybuffs exit \ao- Exits the plugin.')
    end
end

function MyBuffs.Unload()
    mq.unbind('/mybuffs')
end

local function init()
    configFile = string.format("%s/MyUI/MyBuffs/%s/%s.lua", mq.configDir, MyUI_Server, MyUI_CharLoaded)

    MyBuffs.CheckMode()
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
end

function MyBuffs.MainLoop()
    currZone = mq.TLO.Zone.ID()
    local elapsedTime = mq.gettime() - clockTimer
    if (not solo and elapsedTime >= 500) or (solo and elapsedTime >= 33) then -- refresh faster if solo, otherwise every half second to report is reasonable
        if currZone ~= lastZone then
            lastZone = currZone
        end
        if not solo then CheckStale() end
        GetBuffs()
    end
end

init()
return MyBuffs
