---@diagnostic disable: inject-field, undefined-global
local mq                = require('mq')
local ImGui             = require('ImGui')
local zep               = require('Zep')

local loadedExeternally = MyUI_ScriptName ~= nil and true or false
local Module            = {}
if not loadedExeternally then
    Module.Utils       = require('lib.common')
    Module.ThemeLoader = require('lib.theme_loader')
    Module.Actor       = require('actors')
    Module.CharLoaded  = mq.TLO.Me.DisplayName()
    Module.Icons       = require('mq.ICONS')
    Module.Guild       = mq.TLO.Me.Guild()
    Module.Server      = mq.TLO.MacroQuest.Server()
    Module.ThemesFile  = MyUI_ThemeFile == nil and string.format('%s/MyUI/ThemeZ.lua', mq.configDir) or MyUI_ThemeFile
    Module.Theme       = {}
    Module.Mode        = 'driver'
else
    Module.Utils = MyUI_Utils
    Module.ThemeLoader = MyUI_ThemeLoader
    Module.Actor = MyUI_Actor
    Module.CharLoaded = MyUI_CharLoaded
    Module.Icons = MyUI_Icons
    Module.Guild = MyUI_Guild
    Module.Server = MyUI_Server
    Module.Mode = MyUI_Mode
    Module.ThemesFile = MyUI_ThemeFile
    Module.Theme = MyUI_Theme
end
Module.Name              = "MyChat"
Module.IsRunning         = false
Module.defaults          = Module.Utils.Library.Include('defaults.default_chat_settings')
Module.tempSettings      = {}
Module.eventNames        = {}
Module.tempFilterStrings = {}
Module.tempEventStrings  = {}
Module.tempChanColors    = {}
Module.tempFiltColors    = {}
Module.hString           = {}
Module.TLOConsoles       = {}
Module.SHOW              = true
Module.openGUI           = true
Module.openConfigGUI     = false
Module.refreshLinkDB     = 10
Module.mainEcho          = '/say'
-- Module.doRefresh         = false
Module.SettingsFile      = string.format('%s/MyUI/MyChat/%s/%s.lua', mq.configDir, Module.Server:gsub(' ', '_'), Module.CharLoaded)
Module.KeyFocus          = false
Module.KeyName           = 'RightShift'
Module.Settings          = {
    -- Channels
    Channels = {},
}
Module.console           = nil
Module.commandBuffer     = ''
Module.commandHistory    = {}
Module.timeStamps        = true
Module.doLinks           = false
-- Consoles
Module.Consoles          = {}
-- Flags
Module.tabFlags          = bit32.bor(ImGuiTabBarFlags.Reorderable, ImGuiTabBarFlags.FittingPolicyResizeDown, ImGuiTabBarFlags.TabListPopupButton)
Module.winFlags          = bit32.bor(ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoScrollbar)
Module.PopOutFlags       = bit32.bor(ImGuiWindowFlags.NoScrollbar)


-- local var's

local setFocus                                  = false
local commandBuffer                             = ''
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
local firstPass, forceIndex, doLinks            = true, false, false
-- local doRefresh                                 = false
local mainBuffer                                = {}
local importFile                                = 'Server_Name/CharName.lua'
local settingsOld                               = string.format('%s/MyChat_%s_%s.lua', mq.configDir, Module.Server:gsub(' ', '_'), Module.CharLoaded)
local cleanImport                               = false
local enableSpam, resetConsoles                 = false, false
local eChan                                     = '/say'
local fontSizes                                 = {}
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

---Build the consoles for each channel based on ChannelID
---@param channelID integer -- the channel ID number for the console we are setting up
local function SetUpConsoles(channelID)
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
        -- ChatWin.Consoles[channelID].enableLinks = ChatWin.Settings[channelID].enableLinks
        Module.Consoles[channelID].console = zep.Console.new(channelID .. "##Console")
        -- Module.Consoles[channelID].console.fontSize = Module.Settings.Channels[channelID].FontSize or 16
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

---Convert MQ event Strings from #*#blah #1# formats to a lua parsable pattern
local function convertEventString(oldFormat)
    -- local pattern = oldFormat:gsub("#", "")
    local pattern = oldFormat:gsub("#%*#", ".*")
    -- Convert * to Lua's wildcard .*
    -- pattern = pattern:gsub("#%*#", ".*")
    -- Convert n (where n is any number) to Lua's wildcard .*
    pattern = pattern:gsub("#%d#", ".*")

    -- Escape special characters that are not part of the wildcard transformation and should be literal
    -- Specifically targeting parentheses, plus, minus, and other special characters not typically part of text.
    pattern = pattern:gsub("([%^%[%$%(%)%.%]]%+%?])", "%%%1") -- Escaping special characters that might disrupt the pattern matching

    -- Do not escape brackets if they form part of the control structure of the pattern
    pattern = pattern:gsub("%[", "%%%[")
    pattern = pattern:gsub("%]", "%%%]")
    -- print(pattern)
    return pattern
end

---Writes settings from the settings table passed to the setting file (full path required)
-- Uses mq.pickle to serialize the table and write to file
---@param file string -- File Name and path
---@param table table -- Table of settings to write
local function writeSettings(file, table)
    mq.pickle(file, table)
    Module.SortChannels()
end

local function loadSettings()
    if not Module.Utils.File.Exists(Module.SettingsFile) then
        settingsOld = string.format('%s/MyChat_%s_%s.lua', mq.configDir, Module.Server:gsub(' ', '_'), Module.CharLoaded)
        if Module.Utils.File.Exists(settingsOld) then
            Module.Settings = dofile(settingsOld)
            mq.pickle(Module.SettingsFile, Module.Settings)
        else
            Module.Settings = Module.defaults
            mq.pickle(Module.SettingsFile, Module.defaults)
            -- loadSettings()
        end
    else
        -- Load settings from the Lua config file
        Module.Settings = dofile(Module.SettingsFile)
        if firstPass then
            local date = os.date("%m_%d_%Y_%H_%M")
            local backup = string.format('%s/MyChat/Backups/%s/%s_BAK_%s.lua', mq.configDir, Module.Server:gsub(' ', '_'), Module.CharLoaded, date)
            if not Module.Utils.File.Exists(backup) then mq.pickle(backup, Module.Settings) end
            reIndexSettings(Module.SettingsFile, Module.Settings)
            firstPass = false
        end
    end

    for i = 10, 40 do
        if i % 2 == 0 then
            table.insert(fontSizes, i)
            if i == 12 then
                table.insert(fontSizes, 13) -- this is the default font size so keep it in the list
            end
        end
    end

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
    -- if Module.Settings.refreshLinkDB == nil then
    --     Module.Settings.refreshLinkDB = Module.defaults.refreshLinkDB
    -- end
    -- doRefresh = Module.Settings.refreshLinkDB >= 5 or false
    -- if Module.Settings.doRefresh == nil then
    --     Module.Settings.doRefresh = doRefresh
    -- end
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

        -- if Module.Settings.Channels[channelID].Scale ~= nil then
        --     if Module.Settings.Channels[channelID].Scale <= 8 then
        --         Module.Settings.Channels[channelID].FontSize = 16
        --     else
        --         Module.Settings.Channels[channelID].FontSize = Module.Settings.Channels[channelID].Scale
        --     end
        --     Module.Settings.Channels[channelID].Scale = nil
        -- end
        -- if not Module.Settings.Channels[channelID].FontSize then
        --     Module.Settings.Channels[channelID].FontSize = 16
        -- elseif Module.Settings.Channels[channelID].FontSize < 8 then
        --     Module.Settings.Channels[channelID].FontSize = 16
        -- end

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
                    Module.Settings.Channels[channelID]['Events'][eID]['Filters'][0] = { filterString = '', color = {}, }
                end
                Module.Settings.Channels[channelID]['Events'][eID]['Filters'][0].color = eData.color
                eData.color = nil
            end
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

    eChan = Module.Settings.mainEcho
    Module.Settings.doLinks = true
    forceIndex = false
    Module.KeyFocus = Module.Settings.keyFocus ~= nil or false
    Module.KeyName = Module.Settings.keyName ~= nil and Module.Settings.keyName or 'RightShift'
    writeSettings(Module.SettingsFile, Module.Settings)
    Module.tempSettings = Module.Settings
end

local function BuildEvents()
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
    if string.find(line, " pet tells you") then
        name = string.sub(line, 1, string.find(line, " pet tells you") - 1)
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
    else
        return false, name
    end
    -- print(check)
    name = name:gsub(" $", "")
    local check = string.format("npc =\"%s\"", name)
    if mq.TLO.SpawnCount(check)() ~= nil then
        --printf("Count: %s Check: %s",mq.TLO.SpawnCount(check)(),check)
        if mq.TLO.SpawnCount(check)() ~= 0 then
            return true, name
        else
            return false, name
        end
    end
    return false, name
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
    -- if spam then print('Called from Spam') end
    local eventDetails = Module.eventNames[eventName]
    if not eventDetails then return false end

    if Module.Consoles[channelID] then
        local txtBuffer = Module.Consoles[channelID].txtBuffer            -- Text buffer for the channel ID we are working with.
        local colorVec = eventDetails.Filters[0].color or { 1, 1, 1, 1, } -- Color Code to change line to, default is white
        local fMatch = false
        local matchCount = 0
        local negMatch = false
        local conColorStr = 'white'
        local gSize = mq.TLO.Me.GroupSize() -- size of the group including yourself
        gSize = gSize - 1
        if txtBuffer then
            local haveFilters = false
            for fID = 1, getNextID(eventDetails.Filters) - 1 do
                negMatch = false
                fMatch = false
                if eventDetails.Filters[fID] ~= nil then
                    local fData = eventDetails.Filters[fID]
                    if fID > 0 then
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
                            -- print(npcName)
                            if gSize > 0 then
                                for g = 1, gSize do
                                    if mq.TLO.Spawn(string.format("%s", npcName)).Master() == mq.TLO.Group.Member(g).Name() then
                                        fString = string.gsub(fString, 'PT3', npcName)
                                        -- print(npcName)
                                        tagged = true
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
                            print(npcName)
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
                        elseif string.find(fString, 'RL') then
                            fString = string.gsub(fString, 'RL', mq.TLO.Raid.Leader.Name() or 'NO RAID')
                        elseif string.find(fString, 'H1') then
                            fString = CheckGroup(fString, line, 'healer')
                        elseif string.find(fString, 'GP1') then
                            fString = CheckGroup(fString, line, 'group')
                        end
                        if string.find(line, fString) then
                            colorVec = fData.color
                            fMatch = true
                        end
                        if fMatch and negMatch then
                            fMatch = false
                            negMatch = false
                            matchCount = 0
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
            --print(tostring(#eventDetails.Filters))
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
                    -- ChatWin.console:AppendText(colorCode,conLine)
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

---Reads in the line and channelID of the triggered events. Parses the line against the Events and Filters for that channel.
---@param channelID integer @ The ID number of the Channel the triggered event belongs to
function Module.EventChatSpam(channelID, line)
    local eventDetails = Module.eventNames
    local conLine = line
    if not eventDetails then return end
    if Module.Consoles[channelID] then
        local txtBuffer = Module.Consoles[channelID].txtBuffer -- Text buffer for the channel ID we are working with.
        local colorVec = { 1, 1, 1, 1, }                       -- Color Code to change line to, default is white
        local fMatch = false
        local gSize = mq.TLO.Me.GroupSize()                    -- size of the group including yourself
        gSize = gSize - 1
        if txtBuffer then
            for cID, cData in pairs(Module.Settings.Channels) do
                if cID ~= channelID then
                    for eID, eData in pairs(cData.Events) do
                        local tmpEname = string.format("event_%d_%d", cID, eID)
                        for name, data in pairs(Module.eventNames) do
                            if name ~= 'event_9000_1' and name == tmpEname then
                                local eventPattern = convertEventString(data.eventString)
                                if string.match(line, eventPattern) then
                                    fMatch = Module.EventChat(cID, name, line, true)
                                    -- print(tostring(fMatch))
                                end
                                -- we found a match lets exit this loop.
                                if fMatch == true then break end
                            end
                        end
                        if fMatch == true then break end
                    end
                end
                if fMatch == true then break end
            end

            if fMatch then return end -- we have an event for this already
            local tStamp = mq.TLO.Time.Time24()
            local i = getNextID(txtBuffer)
            local colorCode = ImVec4(colorVec[1], colorVec[2], colorVec[3], colorVec[4])

            if timeStamps then
                line = string.format("%s %s", tStamp, line)
            end
            -- write channel console
            if Module.Consoles[channelID].console then
                Module.Utils.AppendColoredTimestamp(Module.Consoles[channelID].console, tStamp, conLine, colorCode, timeStamps)
                -- ChatWin.Consoles[channelID].console:AppendText(colorCode, conLine)
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
        else
            print("Error: txtBuffer is nil for channelID " .. channelID)
        end
    else
        print("Error: ChatWin.Consoles[channelID] is nil for channelID " .. channelID)
    end
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
        ImGui.EndPopup()
    end

    -- if ImGui.IsItemHovered() then
    --     -- Navigate command history
    --     if ImGui.IsKeyPressed(ImGuiKey.UpArrow) and ImGui.IsKeyDown(ImGuiMod.Ctrl) then
    --         settings.commandBuffer = Module.NavigateCommandHistory(channelID, "up")
    --         cmdBuffer = settings.commandBuffer
    --         historyUpdated = true
    --     end
    --     if ImGui.IsKeyPressed(ImGuiKey.DownArrow) and ImGui.IsKeyDown(ImGuiMod.Ctrl) then
    --         settings.commandBuffer = Module.NavigateCommandHistory(channelID, "down")
    --         cmdBuffer = settings.commandBuffer
    --         historyUpdated = true
    --     end
    -- end

    if focusKeyboard then
        local textSizeX, _ = ImGui.CalcTextSize(cmdBuffer)
        ImGui.SetCursorPos(posX + textSizeX * ImGui.GetIO().FontGlobalScale, posY)
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
        ImGui.SetWindowFontScale(Module.Settings.Scale)
        local lockedIcon = Module.Settings.locked and Module.Icons.FA_LOCK .. '##lockTabButton_MyChat' or
            Module.Icons.FA_UNLOCK .. '##lockTablButton_MyChat'
        if ImGui.Button(lockedIcon) then
            --ImGuiWindowFlags.NoMove
            Module.Settings.locked = not Module.Settings.locked
            Module.tempSettings.locked = Module.Settings.locked
            ResetEvents()
        end
        if ImGui.IsItemHovered() then
            ImGui.SetWindowFontScale(Module.Settings.Scale)
            ImGui.BeginTooltip()
            ImGui.Text("Lock Window")
            ImGui.EndTooltip()
        end
        if ImGui.MenuItem(gIcon .. '##' .. windowNum) then
            Module.openConfigGUI = not Module.openConfigGUI
        end
        if ImGui.IsItemHovered() then
            ImGui.SetWindowFontScale(Module.Settings.Scale)
            ImGui.BeginTooltip()
            ImGui.Text("Open Main Config")
            ImGui.EndTooltip()
        end
        if ImGui.BeginMenu('Options##' .. windowNum) then
            local spamOn
            ImGui.SetWindowFontScale(Module.Settings.Scale)
            _, Module.console.autoScroll = ImGui.MenuItem('Auto-scroll##' .. windowNum, nil, Module.console.autoScroll)
            _, LocalEcho = ImGui.MenuItem('Local echo##' .. windowNum, nil, LocalEcho)
            _, timeStamps = ImGui.MenuItem('Time Stamps##' .. windowNum, nil, timeStamps)
            _, Module.KeyFocus = ImGui.MenuItem('Enter Focus##' .. windowNum, nil, Module.KeyFocus)
            if Module.KeyFocus ~= Module.Settings.keyFocus then
                Module.Settings.keyFocus = Module.KeyFocus
                writeSettings(Module.SettingsFile, Module.Settings)
            end
            if Module.KeyFocus then
                if ImGui.BeginMenu('Focus Key') then
                    ImGui.SetWindowFontScale(Module.Settings.Scale)
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
                ImGui.SetWindowFontScale(Module.Settings.Scale)
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
                -- ChatWin.SHOW = false
                -- ChatWin.openGUI = false
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
            ImGui.SetWindowFontScale(Module.Settings.Scale)
            for _, Data in ipairs(sortedChannels) do
                -- for channelID, settings in pairs(ChatWin.Settings.Channels) do
                local channelID = Data[1]
                local enabled = Module.Settings.Channels[channelID].enabled
                local name = Module.Settings.Channels[channelID].Name
                if channelID ~= 9000 or enableSpam then
                    if ImGui.MenuItem(name, '', enabled) then
                        Module.Settings.Channels[channelID].enabled = not enabled
                        writeSettings(Module.SettingsFile, Module.Settings)
                    end
                end
            end
            ImGui.EndMenu()
        end
        -- if ImGui.BeginMenu('Zoom##' .. windowNum) then
        --     ImGui.SetWindowFontScale(Module.Settings.Scale)
        --     if ImGui.MenuItem('Main##MyChat', '', zoomMain) then
        --         zoomMain = not zoomMain
        --     end
        --     for _, Data in ipairs(sortedChannels) do
        --         -- for channelID, settings in pairs(ChatWin.Settings.Channels) do
        --         local channelID = Data[1]
        --         if channelID ~= 9000 or enableSpam then
        --             local zoom = Module.Consoles[channelID].zoom
        --             local name = Module.Settings.Channels[channelID].Name
        --             if ImGui.MenuItem(name, '', zoom) then
        --                 Module.Consoles[channelID].zoom = not zoom
        --             end
        --         end
        --     end

        --     ImGui.EndMenu()
        -- end
        if ImGui.BeginMenu('Links##' .. windowNum) then
            ImGui.SetWindowFontScale(Module.Settings.Scale)
            for _, Data in ipairs(sortedChannels) do
                -- for channelID, settings in pairs(ChatWin.Settings.Channels) do
                local channelID = Data[1]
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
            ImGui.Separator()

            ImGui.EndMenu()
        end
        if ImGui.BeginMenu('PopOut##' .. windowNum) then
            ImGui.SetWindowFontScale(Module.Settings.Scale)
            for _, Data in ipairs(sortedChannels) do
                -- for channelID, settings in pairs(ChatWin.Settings.Channels) do
                local channelID = Data[1]
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

            ImGui.EndMenu()
        end

        ImGui.EndMenuBar()
    end

    -- Begin Tabs Bars
    ImGui.SetWindowFontScale(1)
    if ImGui.BeginTabBar('Channels##', Module.tabFlags) then
        -- Begin Main tab
        if ImGui.BeginTabItem('Main##' .. windowNum) then
            ImGui.SetWindowFontScale(Module.Settings.Scale)
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
                ImGui.SetWindowFontScale(Module.Settings.Scale)
                if ImGui.Selectable('Clear##' .. windowNum) then
                    Module.console:Clear()
                    mainBuffer = {}
                end
                -- ImGui.Separator()
                -- if ImGui.Selectable('Zoom##Main' .. windowNum) then
                --     zoomMain = not zoomMain
                -- end

                ImGui.EndPopup()
            end

            Module.console:Render(ImVec2(0, contentSizeY))
            -- Module.console.fontSize = Module.Settings.MainFontSize or 16
            --Command Line
            ImGui.Separator()
            local textFlags = bit32.bor(0,
                ImGuiInputTextFlags.EnterReturnsTrue,
                -- not implemented yet
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
            Module.commandBuffer, accept = ImGui.InputText('##Input##' .. windowNum, Module.commandBuffer, textFlags)
            ImGui.PopFont()
            ImGui.PopStyleColor()
            ImGui.PopItemWidth()
            if accept then
                Module.ExecCommand(Module.commandBuffer)
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
        -- for tabNum = 1 , #ChatWin.Settings.Channels do
        for _, channelData in ipairs(sortedChannels) do
            local channelID = channelData[1]
            if Module.Settings.Channels[channelID].enabled then
                local name = Module.Settings.Channels[channelID].Name:gsub("^%d+%s*", "") .. '##' .. windowNum
                local links = Module.Settings.Channels[channelID].enableLinks
                local enableMain = Module.Settings.Channels[channelID].MainEnable
                local PopOut = Module.Settings.Channels[channelID].PopOut
                -- local tNameZ = zoom and 'Disable Zoom' or 'Enable Zoom'
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
                    ImGui.SetWindowFontScale(1)
                    if ImGui.BeginTabItem(name) then
                        activeTabID = channelID
                        ImGui.SetWindowFontScale(Module.Settings.Scale)
                        if ImGui.IsItemHovered() then
                            tabToolTip()
                        end
                        if ImGui.BeginPopupContextWindow() then
                            ImGui.SetWindowFontScale(Module.Settings.Scale)
                            if ImGui.Selectable('Configure##' .. windowNum) then
                                editChanID = channelID
                                addChannel = false
                                fromConf = false
                                Module.tempSettings = Module.Settings
                                Module.openEditGUI = true
                                Module.openConfigGUI = false
                            end

                            ImGui.Separator()
                            -- if ImGui.Selectable(tNameZ .. '##' .. windowNum) then
                            --     zoom = not zoom
                            --     Module.Consoles[channelID].zoom = zoom
                            -- end
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

                            ImGui.EndPopup()
                        end

                        DrawConsole(channelID)

                        ImGui.EndTabItem()
                    end
                    -- if ImGui.IsItemHovered() then
                    --     tabToolTip()
                    -- end
                end
            end
        end
        ImGui.EndTabBar()
    end
end

function Module.RenderGUI()
    if not Module.IsRunning then return end

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
        if Module.Settings.Channels[channelID].enabled then
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
                        ImGui.SetWindowFontScale(Module.Settings.Scale)
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
                        ImGui.SetWindowFontScale(Module.Settings.Scale)
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
                ImGui.SetWindowFontScale(1)
                Module.ThemeLoader.EndTheme(PopoutColorCount, PopoutStyleCount)

                ImGui.End()
            end
        end
    end
    if Module.openEditGUI then Module.Edit_GUI() end
    if Module.openConfigGUI then Module.Config_GUI() end

    if not openMain then
        Module.IsRunning = false
    end
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
    local tmpFilter = 'NewFilter'
    local channelData = {}

    if not Module.tempEventStrings[editChanID] then Module.tempEventStrings[editChanID] = {} end
    if not Module.tempChanColors then Module.tempChanColors = {} end
    if not Module.tempFiltColors[editChanID] then Module.tempFiltColors[editChanID] = {} end
    if not Module.tempChanColors[editChanID] then Module.tempChanColors[editChanID] = {} end
    if not Module.tempFilterStrings[editChanID] then Module.tempFilterStrings[editChanID] = {} end
    if not Module.tempEventStrings[editChanID] then channelData[editChanID] = {} end
    if not Module.tempEventStrings[editChanID][editEventID] then Module.tempEventStrings[editChanID][editEventID] = {} end

    if not isNewChannel then
        for eID, eData in pairs(Module.tempSettings.Channels[editChanID].Events) do
            if not Module.tempFiltColors[editChanID][eID] then Module.tempFiltColors[editChanID][eID] = {} end
            for fID, fData in pairs(eData.Filters) do
                if not Module.tempFiltColors[editChanID][eID][fID] then Module.tempFiltColors[editChanID][eID][fID] = {} end
                -- if not tempFiltColors[editChanID][eID][fID] then tempFiltColors[editChanID][eID][fID] = {} end
                Module.tempFiltColors[editChanID][eID][fID] = fData.color or { 1, 1, 1, 1, }
            end
        end
    end


    if Module.tempSettings.Channels[editChanID] then
        channelData = Module.tempSettings.Channels
    else
        channelData = {
            [editChanID] = {
                ['enabled'] = false,
                ['Name'] = 'new',
                ['FontSize'] = 16,
                ['Echo'] = '/say',
                ['MainEnable'] = true,
                ['PopOut'] = false,
                ['EnableLinks'] = false,
                ['Events'] = {
                    [1] = {
                        ['enabled'] = true,
                        ['eventString'] = 'new',
                        ['Filters'] = {
                            [0] = {
                                ['filter_enabled'] = true,
                                ['filterString'] = '',
                                ['color'] = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, },
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
        -- print(maxEventId)
        channelData[editChanID]['Events'][maxEventId] = {
            ['enabled'] = true,
            ['eventString'] = 'new',
            ['Filters'] = {
                [0] = {
                    ['filterString'] = '',
                    ['color'] = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, },
                },
            },
        }
        newEvent = false
    end
    ---------------- Buttons Sliders and Channel Name ------------------------
    ImGui.SetWindowFontScale(Module.Settings.Scale)
    if lastChan == 0 then
        --print(channelData.Name)
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
    -- Slider for adjusting zoom level
    if Module.Consoles[editChanID].console ~= nil then
        local changed = false
        -- if ImGui.BeginCombo("Font Size##" .. editChanID, tostring(Module.Consoles[editChanID].console.fontSize)) then
        --     for k, data in pairs(fontSizes) do
        --         local isSelected = data == Module.Consoles[editChanID].console.fontSize
        --         if ImGui.Selectable(tostring(data), isSelected) then
        --             if Module.Consoles[editChanID].console.fontSize ~= data then
        --                 -- Module.Consoles[editChanID].console.fontSize = data
        --                 Module.Settings.Channels[editChanID].FontSize = Module.Consoles[editChanID].console.fontSize
        --                 Module.tempSettings.Channels[editChanID].FontSize = Module.Consoles[editChanID].console.fontSize
        --                 changed = true
        --             end
        --         end
        --     end
        --     ImGui.EndCombo()
        -- end
        -- Module.Consoles[editChanID].console.fontSize, changed = ImGui.SliderInt("Font Size", Module.Consoles[editChanID].console.fontSize, 8, 300)
        -- Module.tempSettings.Channels[editChanID].Scale = Module.Consoles[editChanID].console.fontSize
        -- Module.Settings.Channels[editChanID].Scale = Module.Consoles[editChanID].console.fontSize
        if changed then
            mq.pickle(Module.SettingsFile, Module.Settings)
        end
    end
    if ImGui.Button('Add New Event') then
        newEvent = true
    end
    ImGui.SameLine()
    if ImGui.Button('Save Settings') then
        local date = os.date("%m_%d_%Y_%H_%M")
        local backup = string.format('%s/MyChat/Backups/%s/%s_BAK_%s.lua', mq.configDir, Module.Server:gsub(' ', '_'), Module.CharLoaded, date)
        mq.pickle(backup, Module.Settings)
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
                    channelEvents[eventId].eventString = tempEString --eventData.eventString
                    channelEvents[eventId].color = Module.tempChanColors[editChanID][eventId] or channelEvents[eventId].color
                    channelEvents[eventId].Filters = {}
                    for filterID, filterData in pairs(Module.tempFilterStrings[editChanID][eventId] or {}) do
                        local tempFString = filterData or 'New'
                        --print(filterData.." : "..tempFString)
                        if tempFString == '' or tempFString == nil then tempFString = 'New' end
                        channelEvents[eventId].Filters[filterID] = {
                            filterString = tempFString,
                            color = Module.tempFiltColors[editChanID][eventId][filterID] or { 1.0, 1.0, 1.0, 1.0, }, -- Default to white with full opacity if color not found
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
        Module.tempFilterStrings, Module.tempEventStrings, Module.tempChanColors, Module.tempFiltColors, Module.hString, channelData = {}, {}, {}, {}, {}, {}
        if fromConf then Module.openConfigGUI = true end
        return
    end
    ImGui.SameLine()
    if ImGui.Button("DELETE Channel##" .. editChanID) then
        -- Delete the event
        local date = os.date("%m_%d_%Y_%H_%M")

        local backup = string.format('%s/MyChat/Backups/%s/%s_BAK_%s.lua', mq.configDir, Module.Server:gsub(' ', '_'), Module.CharLoaded, date)
        mq.pickle(backup, Module.Settings)
        Module.tempSettings.Channels[editChanID] = nil
        Module.tempEventStrings[editChanID] = nil
        Module.tempChanColors[editChanID] = nil
        Module.tempFiltColors[editChanID] = nil
        Module.tempFilterStrings[editChanID] = nil

        isNewChannel = false
        ResetEvents()
        resetEvnts = true
        Module.openEditGUI = false
        Module.openConfigGUI = false
        return
    end
    ImGui.SameLine()
    if ImGui.Button(' Close ##_close') then
        Module.openEditGUI = false
        if fromConf then Module.openConfigGUI = true end
    end
    ImGui.SameLine()
    if Module.tempSettings.Channels[editChanID] then
        Module.tempSettings.Channels[editChanID].MainEnable = ImGui.Checkbox('Show on Main Tab##Main', Module.tempSettings.Channels[editChanID].MainEnable)
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
        if channelData[editChanID].Events ~= nil then
            for eventID, eventDetails in ipairs(channelData[editChanID].Events) do
                if Module.hString[eventID] == nil then Module.hString[eventID] = string.format(channelData[editChanID].Name .. ' : ' .. eventDetails.eventString) end
                if ImGui.CollapsingHeader(Module.hString[eventID]) then
                    local contentSizeX = ImGui.GetWindowContentRegionWidth()
                    ImGui.SetWindowFontScale(Module.Settings.Scale)
                    if ImGui.BeginChild('Events##' .. eventID, contentSizeX, 0.0, bit32.bor(ImGuiChildFlags.Border, ImGuiChildFlags.AutoResizeY)) then
                        if ImGui.BeginTable("Channel Events##" .. editChanID, 4, bit32.bor(ImGuiTableFlags.NoHostExtendX)) then
                            ImGui.SetWindowFontScale(Module.Settings.Scale)
                            ImGui.TableSetupColumn("ID's##_", ImGuiTableColumnFlags.WidthAlwaysAutoResize, 100)
                            ImGui.TableSetupColumn("Strings", ImGuiTableColumnFlags.WidthStretch, 150)
                            ImGui.TableSetupColumn("Color", ImGuiTableColumnFlags.WidthFixed, 50)
                            ImGui.TableSetupColumn("##Delete", ImGuiTableColumnFlags.WidthAlwaysAutoResize, 50)
                            ImGui.TableHeadersRow()
                            ImGui.TableNextRow()
                            ImGui.TableSetColumnIndex(0)

                            if ImGui.Button('Add Filter') then
                                newFilter = true
                                if newFilter then
                                    --printf("eID: %s", eventID )
                                    if not channelData[editChanID].Events[eventID].Filters then
                                        channelData[editChanID].Events[eventID].Filters = {}
                                    end
                                    local maxFilterId = getNextID(channelData[editChanID].Events[eventID]['Filters'])
                                    --printf("fID: %s",maxFilterId)
                                    channelData[editChanID]['Events'][eventID].Filters[maxFilterId] = {
                                        ['filterString'] = 'new',
                                        ['color'] = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, },
                                    }
                                    newFilter = false
                                end
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
                            Module.hString[eventID] = Module.hString[eventID]
                            if Module.tempEventStrings[editChanID][eventID].eventString ~= tmpString then Module.tempEventStrings[editChanID][eventID].eventString = tmpString end

                            ImGui.TableSetColumnIndex(2)

                            if not Module.tempChanColors[editChanID][eventID] then
                                Module.tempChanColors[editChanID][eventID] = eventDetails.Filters[0].color or { 1.0, 1.0, 1.0, 1.0, } -- Default to white with full opacity
                            end

                            Module.tempChanColors[editChanID][eventID] = ImGui.ColorEdit4("##Color" .. bufferKey, Module.tempChanColors[editChanID][eventID], MyColorFlags)
                            ImGui.TableSetColumnIndex(3)
                            if ImGui.Button("Delete##" .. bufferKey) then
                                -- Delete the event
                                Module.tempSettings.Channels[editChanID].Events[eventID] = nil
                                Module.tempEventStrings[editChanID][eventID] = nil
                                Module.tempChanColors[editChanID][eventID] = nil
                                Module.tempFiltColors[editChanID][eventID] = nil
                                Module.tempFilterStrings[editChanID][eventID] = nil
                                ResetEvents()
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
                            for filterID, filterData in ipairs(eventDetails.Filters) do
                                if filterID > 0 then --and filterData.filterString ~= '' then
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
                                    -- Display the filter string input field
                                    local tmpKey = string.format("%s_%s", eventID, filterID)
                                    tempFilter, _ = ImGui.InputText("Filter String##_" .. tmpKey, tempFilter)
                                    -- Update the filter string in tempFilterStrings
                                    if Module.tempFilterStrings[editChanID][eventID][filterID] ~= tempFilter then
                                        Module.tempFilterStrings[editChanID][eventID][filterID] = tempFilter
                                    end
                                    ImGui.TableSetColumnIndex(2)
                                    if not Module.tempFiltColors[editChanID][eventID] then Module.tempFiltColors[editChanID][eventID] = {} end
                                    if not Module.tempFiltColors[editChanID][eventID][filterID] then Module.tempFiltColors[editChanID][eventID][filterID] = filterData.color or {} end
                                    local tmpColor = {}
                                    tmpColor = filterData['color']
                                    -- Display the color picker for the filter
                                    filterData['color'] = ImGui.ColorEdit4("##Color_" .. filterID, tmpColor, MyColorFlags)
                                    if Module.tempFiltColors[editChanID][eventID][filterID] ~= tmpColor then Module.tempFiltColors[editChanID][eventID][filterID] = tmpColor end
                                    ImGui.TableSetColumnIndex(3)
                                    if ImGui.Button("Delete##_" .. filterID) then
                                        -- Delete the Filter
                                        Module.tempSettings.Channels[editChanID].Events[eventID].Filters[filterID] = nil
                                        --printf("chanID: %s, eID: %s, fID: %s",editChanID,eventID,filterID)
                                        Module.tempFilterStrings[editChanID][eventID][filterID] = nil
                                        Module.tempChanColors[editChanID][eventID][filterID] = nil
                                        Module.tempFiltColors[editChanID][eventID][filterID] = nil
                                        ResetEvents()
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
    ImGui.EndChild()
    ImGui.SetWindowFontScale(1)
end

local function buildConfig()
    lastID = 0
    if ImGui.BeginChild("Channels##") then
        for channelID, channelData in pairs(Module.tempSettings.Channels) do
            if channelID ~= lastID then
                if ImGui.CollapsingHeader(channelData.Name) then
                    local contentSizeX = ImGui.GetWindowContentRegionWidth()
                    ImGui.SetWindowFontScale(Module.Settings.Scale)
                    if ImGui.BeginChild('Channels##' .. channelID, contentSizeX, 0.0, bit32.bor(ImGuiChildFlags.Border, ImGuiChildFlags.AutoResizeY, ImGuiChildFlags.AlwaysAutoResize)) then
                        -- Begin a table for events within this channel
                        if ImGui.BeginTable("ChannelEvents_" .. channelData.Name, 4, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.RowBg, ImGuiTableFlags.Borders, ImGui.GetWindowWidth() - 5)) then
                            ImGui.SetWindowFontScale(Module.Settings.Scale)
                            -- Set up table columns once
                            ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed, 50)
                            ImGui.TableSetupColumn("Channel", ImGuiTableColumnFlags.WidthAlwaysAutoResize, 100)
                            ImGui.TableSetupColumn("EventString", ImGuiTableColumnFlags.WidthStretch, 150)
                            ImGui.TableSetupColumn("Color", ImGuiTableColumnFlags.WidthAlwaysAutoResize)
                            -- Iterate through each event in the channel
                            local once = true
                            for eventId, eventDetails in pairs(channelData.Events) do
                                local bufferKey = channelID .. "_" .. tostring(eventId)
                                local name = channelData.Name
                                local bufferKey = channelID .. "_" .. tostring(eventId)
                                local channelKey = "##ChannelName" .. channelID
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
                                Module.tempSettings.Channels[channelID].Events[eventId].enabled = ImGui.Checkbox('Enabled##' .. eventId,
                                    Module.tempSettings.Channels[channelID].Events[eventId].enabled)
                                ImGui.TableSetColumnIndex(2)
                                ImGui.Text(eventDetails.eventString)
                                ImGui.TableSetColumnIndex(3)
                                if not eventDetails.Filters[0].color then
                                    eventDetails.Filters[0].color = { 1.0, 1.0, 1.0, 1.0, } -- Default to white with full opacity
                                end
                                ImGui.ColorEdit4("##Color" .. bufferKey, eventDetails.Filters[0].color,
                                    bit32.bor(ImGuiColorEditFlags.NoOptions, ImGuiColorEditFlags.NoPicker, ImGuiColorEditFlags.NoInputs, ImGuiColorEditFlags.NoTooltip,
                                        ImGuiColorEditFlags.NoLabel))
                            end
                            -- End the table for this channel
                            ImGui.EndTable()
                        end
                    end
                    ImGui.EndChild()
                end
            end
            lastID = channelID
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
        ImGui.SetWindowFontScale(Module.Settings.Scale)
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
                if MyUI_Modules.ThemeZ ~= nil then
                    if MyUI_Modules.ThemeZ.IsRunning then
                        MyUI_Modules.ThemeZ.ShowGui = true
                    else
                        MyUI_TempSettings.ModuleChanged = true
                        MyUI_TempSettings.ModuleName = 'ThemeZ'
                        MyUI_TempSettings.ModuleEnabled = true
                    end
                else
                    MyUI_TempSettings.ModuleChanged = true
                    MyUI_TempSettings.ModuleName = 'ThemeZ'
                    MyUI_TempSettings.ModuleEnabled = true
                end
            end
        end
        ImGui.SameLine()
        -- Close Button
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
        cleanImport = ImGui.Checkbox('Clean Import##clean', cleanImport)

        if ImGui.Button('Import Channels') then
            local tmp = mq.configDir .. '/MyUI/MyChat/' .. importFile
            if not Module.Utils.File.Exists(tmp) then
                mq.cmd("/msgbox 'No File Found!")
            else
                -- Load settings from the Lua config file
                local date = os.date("%m_%d_%Y_%H_%M")

                -- print(date)
                local backup = string.format('%s/MyChat/Backups/%s/%s_BAK_%s.lua', mq.configDir, Module.Server:gsub(' ', '_'), Module.CharLoaded, date)
                mq.pickle(backup, Module.Settings)
                local newSettings = {}
                local newID = getNextID(Module.tempSettings.Channels)

                newSettings = dofile(tmp)
                -- print(tostring(cleanImport))
                if not cleanImport and lastImport ~= tmp then
                    for cID, cData in pairs(newSettings.Channels) do
                        for existingCID, existingCData in pairs(Module.tempSettings.Channels) do
                            if existingCData.Name == cData.Name then
                                local newName = cData.Name .. '_NEW'
                                cData.Name = newName
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

        if Module.console ~= nil then
            local changed = false
            -- if ImGui.BeginCombo("Main Tab Font Size##" .. editChanID, tostring(Module.console.fontSize)) then
            --     for k, data in pairs(fontSizes) do
            --         local isSelected = data == Module.console.fontSize
            --         if ImGui.Selectable(tostring(data), isSelected) then
            --             if Module.console.fontSize ~= data then
            --                 Module.console.fontSize = data
            --                 Module.Settings.MainFontSize = Module.console.fontSize

            --                 changed = true
            --             end
            --         end
            --     end
            --     ImGui.EndCombo()
            -- end
            if changed then
                writeSettings(Module.SettingsFile, Module.Settings)
            end


            -- Module.console.fontSize = ImGui.SliderInt("Main Tab Font Size", Module.console.fontSize, 8, 300)
            -- Module.Settings.MainFontSize = Module.console.fontSize
            -- writeSettings(Module.SettingsFile, Module.Settings)
        end

        if Module.Settings.Scale ~= tmpZoom then
            Module.Settings.Scale = tmpZoom
            Module.tempSettings.Scale = tmpZoom
        end

        -- local tmpRefLink = (doRefresh and Module.Settings.refreshLinkDB >= 5) and Module.Settings.refreshLinkDB or 0
        -- tmpRefLink = ImGui.InputInt("Refresh Delay##LinkRefresh", tmpRefLink, 5, 5)
        -- if tmpRefLink < 0 then tmpRefLink = 0 end
        -- if tmpRefLink ~= Module.Settings.refreshLinkDB then
        --     -- ChatWin.Settings.refreshLinkDB = tmpRefLink
        --     Module.tempSettings.refreshLinkDB = tmpRefLink
        --     doRefresh = tmpRefLink >= 5 or false
        -- end
        -- ImGui.SameLine()
        -- local txtOnOff = doRefresh and 'ON' or 'OFF'
        -- ImGui.Text(txtOnOff)
        eChan = ImGui.InputText("Main Channel Echo##Echo", eChan, 256)
        if eChan ~= Module.Settings.mainEcho then
            Module.Settings.mainEcho = eChan
            Module.tempSettings.mainEcho = eChan
            writeSettings(Module.SettingsFile, Module.Settings)
        end
        ImGui.SeparatorText('Channels and Events Overview')
        table.sort(Module.tempSettings.Channels, function(a, b)
            return a.Name < b.Name
        end)
        buildConfig()
    end
    Module.ThemeLoader.EndTheme(ColorCountConf, StyleCountConf)
    ImGui.SetWindowFontScale(1)
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
        ImGui.SetWindowFontScale(Module.Settings.Scale)

        Module.createExternConsole(string.format("New Channel %s", editChanID))
        Module.AddChannel(editChanID, false)

        ImGui.SameLine()
        -- Close Button
        if ImGui.Button('Close') then
            Module.openEditGUI = false
            addChannel = false
            editChanID = 0
            editEventID = 0
        end
    end
    ImGui.SetWindowFontScale(1)
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

    -- todo: implement history
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
        table.insert(Module.commandHistory, text)
    end
end

---comments
---@param text string -- the incomming line of text from the command prompt
function Module.ChannelExecCommand(text, channelID)
    if LocalEcho then
        Module.console:AppendText(IM_COL32(128, 128, 128), "> %s", text)
    end

    local eChan = '/say'
    -- todo: implement history
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
    Module.Settings.Channels[newID] = {
        ['enabled'] = true,
        ['Name'] = name,
        ['FontSize'] = 16,
        ['Echo'] = '/say',
        ['MainEnable'] = true,
        ['PopOut'] = false,
        ['look'] = false,
        ['EnableLinks'] = true,
        ['commandBuffer'] = "",
        ['Events'] = {
            [1] = {
                ['enabled'] = true,
                ['eventString'] = 'new',
                ['Filters'] = {
                    [0] = {
                        ['filter_enabled'] = true,
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
        table.insert(sortedChannels, { k, v.Name, })
    end

    -- Sort function to first sort by numeric prefixes (if the first word is a number),
    -- then sort alphabetically for non-numeric names
    table.sort(sortedChannels, function(a, b)
        -- Extract the first word from both names
        local firstWordA = a[2]:match("^%S+")
        local firstWordB = b[2]:match("^%S+")

        -- Check if the first word is a number
        local aIsNumeric = tonumber(firstWordA) ~= nil
        local bIsNumeric = tonumber(firstWordB) ~= nil

        if aIsNumeric and bIsNumeric then
            -- Both are numeric, so sort by numeric value
            return tonumber(firstWordA) < tonumber(firstWordB)
        elseif aIsNumeric ~= bIsNumeric then
            -- One is numeric, one is not; numeric comes first
            return aIsNumeric
        else
            -- Neither are numeric, sort alphabetically
            return a[2] < b[2]
        end
    end)
end

function Module.Unload()
    for eventName, _ in pairs(Module.eventNames) do
        mq.unevent(eventName)
    end
    MyUI_MyChatLoaded = false
    MyUI_MyChatHandler = nil
end

local function init()
    loadSettings()
    BuildEvents()

    -- initialize the console
    if Module.console == nil then
        Module.console = zep.Console.new("Chat##Console")
        -- Module.console.fontSize = Module.Settings.MainFontSize or 16
        mainBuffer = {
            [1] = {
                color = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, },
                text = '',
            },
        }
    end

    Module.console:AppendText("\ay[\aw%s\ay]\at Welcome to \agMyChat!", mq.TLO.Time())
    Module.SortChannels()
    Module.IsRunning = true

    if not loadedExeternally then
        mq.imgui.init(Module.Name, Module.RenderGUI)
        Module.LocalLoop()
    end
end

function Module.MainLoop()
    if loadedExeternally then
        if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
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
    mq.doevents()
end

function Module.LocalLoop()
    while Module.IsRunning do
        Module.MainLoop()
        mq.delay(1)
    end
end

init()

MyUI_MyChatLoaded = true
MyUI_MyChatHandler = Module.MyChatHandler

return Module
