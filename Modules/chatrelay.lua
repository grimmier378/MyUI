--[[
    Title: Chat Relay
    Author: Grimmier
    Description: Guild Chat Relay over Actors.
]]

local mq            = require('mq')
local ImGui         = require 'ImGui'
local Module        = {}
Module.ActorMailBox = 'chat_relay'
Module.IsRunning    = false
Module.Name         = 'ChatRelay'
Module.DisplayName  = 'Chat Relay'
Module.Path         = MyUI_Path ~= nil and MyUI_Path or string.format("%s/%s/", mq.luaDir, Module.Name)
Module.ImgPath      = Module.Path .. "images/phone.png"


---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false

if not loadedExeternally then
    MyUI_Utils       = require('lib.common')
    MyUI_ThemeLoader = require('lib.theme_loader')
    MyUI_Actor       = require('actors')
    MyUI_CharLoaded  = mq.TLO.Me.DisplayName()
    MyUI_Guild       = mq.TLO.Me.Guild()
    MyUI_Server      = mq.TLO.MacroQuest.Server()
    MyUI_Mode        = 'driver'
end

local winFlags                          = bit32.bor(ImGuiWindowFlags.None)
local currZone, lastZone, configFile, mode
local guildChat                         = {}
local tellChat                          = {}
local lastMessages                      = {}
local charBufferCount, guildBufferCount = {}, {}
local lastAnnounce                      = 0

local RelayGuild                        = false
local RelayTells                        = false
local NewMessage                        = false

local minImg                            = MyUI_Utils.SetImage(Module.ImgPath)
local Minimized                         = false
local showMain                          = false
local showConfig                        = false
local aSize                             = false
local RelayActor                        = nil
local fontSizes                         = {}
local defaults                          = {
    Scale            = 1,
    AutoSize         = false,
    ShowTooltip      = true,
    RelayTells       = true,
    RelayGuild       = true,
    MaxRow           = 1,
    EscapeToMin      = false,
    AlphaSort        = false,
    ShowOnNewMessage = true,
    IconSize         = 30,
    FontSize         = 16,
}
local settings                          = {}

function LoadSettings()
    -- Check if the dialog data file exists
    local newSetting = false
    if not MyUI_Utils.File.Exists(configFile) then
        settings[Module.DisplayName] = defaults
        mq.pickle(configFile, settings)
        LoadSettings()
    else
        -- Load settings from the Lua config file
        settings = dofile(configFile)
        if settings[Module.DisplayName] == nil then
            settings[Module.DisplayName] = {}
            -- settings[script] = defaults
            -- newSetting = true
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

    newSetting = MyUI_Utils.CheckDefaultSettings(defaults, settings[Module.DisplayName])

    RelayGuild = settings[Module.DisplayName].RelayGuild
    RelayTells = settings[Module.DisplayName].RelayTells
    if newSetting then mq.pickle(configFile, settings) end
end

local function GenerateContent(sub, message)
    return {
        Subject = sub,
        Name = MyUI_CharLoaded,
        Guild = MyUI_Guild,
        Message = message or '',
        Tell = '',
    }
end

--create mailbox for actors to send messages to
local function RegisterRelayActor()
    RelayActor = MyUI_Actor.register(Module.ActorMailBox, function(message)
        local tStamp = mq.TLO.Time.Time24()
        local MemberEntry = message()
        if MemberEntry == nil then return end
        local HelloMessage = false
        if MemberEntry.Subject == 'Guild' and settings[Module.DisplayName].RelayGuild then
            if lastMessages[MemberEntry.Guild] == nil then
                lastMessages[MemberEntry.Guild] = MemberEntry.Message
            elseif lastMessages[MemberEntry.Guild] == MemberEntry.Message then
                return
            else
                lastMessages[MemberEntry.Guild] = MemberEntry.Message
            end
            if guildChat[MemberEntry.Guild] == nil then
                guildChat[MemberEntry.Guild] = ImGui.ConsoleWidget.new("chat_relay_Console" .. MemberEntry.Guild .. "##chat_relayConsole")
                guildChat[MemberEntry.Guild].fontSize = settings[Module.DisplayName].FontSize
                guildBufferCount[MemberEntry.Guild] = { Current = 1, Last = 1, }
            end
            MyUI_Utils.AppendColoredTimestamp(guildChat[MemberEntry.Guild], tStamp, MemberEntry.Message)
            guildBufferCount[MemberEntry.Guild].Current = guildBufferCount[MemberEntry.Guild].Current + 1
        elseif MemberEntry.Subject == 'Tell' and settings[Module.DisplayName].RelayTells then
            if tellChat[MemberEntry.Name] == nil then
                tellChat[MemberEntry.Name] = ImGui.ConsoleWidget.new("chat_relay_Console" .. MemberEntry.Name .. "##chat_relayConsole")
                tellChat[MemberEntry.Name].fontSize = settings[Module.DisplayName].FontSize
            end
            MyUI_Utils.AppendColoredTimestamp(tellChat[MemberEntry.Name], tStamp, MemberEntry.Message)
            charBufferCount[MemberEntry.Name].Current = charBufferCount[MemberEntry.Name].Current + 1
        elseif MemberEntry.Subject == 'Reply' and string.lower(MemberEntry.Name) == string.lower(MyUI_CharLoaded) and settings[Module.DisplayName].RelayTells then
            if MemberEntry.Tell == 'r' then
                mq.cmdf("/r %s", MemberEntry.Message)
            else
                mq.cmdf("/tell %s %s", MemberEntry.Tell, MemberEntry.Message)
            end
        elseif MemberEntry.Subject == 'GuildReply' and string.lower(MemberEntry.Name) == string.lower(MyUI_CharLoaded) and MemberEntry.Guild == MyUI_Guild then
            mq.cmdf("/gu %s", MemberEntry.Message)
        elseif MemberEntry.Subject == 'Hello' then
            if MemberEntry.Name ~= MyUI_CharLoaded then
                local announce = os.time()
                if tellChat[MemberEntry.Name] == nil and RelayActor ~= nil then
                    tellChat[MemberEntry.Name] = ImGui.ConsoleWidget.new("chat_relay_Console" .. MemberEntry.Name .. "##chat_relayConsole")
                    tellChat[MemberEntry.Name].fontSize = settings[Module.DisplayName].FontSize
                    RelayActor:send({ mailbox = 'chat_relay', script = 'myui', }, GenerateContent('Hello', 'Hello'))
                    RelayActor:send({ mailbox = 'chat_relay', script = 'chatrelay', }, GenerateContent('Hello', 'Hello'))

                    charBufferCount[MemberEntry.Name] = { Current = 1, Last = 1, }
                    MyUI_Utils.AppendColoredTimestamp(tellChat[MemberEntry.Name], tStamp, " User Added")
                    lastAnnounce = announce
                end
                if guildChat[MemberEntry.Guild] == nil then
                    guildChat[MemberEntry.Guild] = ImGui.ConsoleWidget.new("chat_relay_Console" .. MemberEntry.Guild .. "##chat_relayConsole")
                    tellChat[MemberEntry.Name].fontSize = settings[Module.DisplayName].FontSize
                    guildBufferCount[MemberEntry.Guild] = { Current = 1, Last = 1, }
                    MyUI_Utils.AppendColoredTimestamp(guildChat[MemberEntry.Guild], tStamp, " Guild Added")
                end
                if announce - lastAnnounce > 5 and RelayActor ~= nil then
                    RelayActor:send({ mailbox = 'chat_relay', script = 'myui', }, GenerateContent('Hello', 'Hello'))
                    RelayActor:send({ mailbox = 'chat_relay', script = 'chatrelay', }, GenerateContent('Hello', 'Hello'))
                    lastAnnounce = announce
                end
            end
            HelloMessage = true
        else
            return
        end

        local youSent = string.find(MemberEntry.Message, "^You") and true or false
        if not HelloMessage and not youSent then NewMessage = true end
        if settings[Module.DisplayName].ShowOnNewMessage and mode == 'driver' and not HelloMessage and not youSent then
            showMain = true
            NewMessage = false
        end
    end)
end

local function StringTrim(s)
    return s:gsub("^%s*(.-)%s*$", "%1")
end

local function sortedBoxes(boxes)
    local keys = {}
    for k in pairs(boxes) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        return a < b
    end)
    return keys
end

---comments
---@param text string -- the incomming line of text from the command prompt
local function ChannelExecCommand(text, channName, channelID)
    local separator = "|"
    local args = {}
    for arg in string.gmatch(text, "([^" .. separator .. "]+)") do
        table.insert(args, arg)
    end
    local who = args[1]
    local message = args[2]
    -- todo: implement history
    if string.len(text) > 0 then
        text = StringTrim(text)
        if text == 'clear' then
            channelID:Clear()
        elseif who ~= nil and message ~= nil and RelayActor ~= nil then
            RelayActor:send({ mailbox = 'chat_relay', script = 'myui', }, { Name = channName, Subject = 'Reply', Tell = who, Message = message, })
            RelayActor:send({ mailbox = 'chat_relay', script = 'chatrelay', }, { Name = channName, Subject = 'Reply', Tell = who, Message = message, })
        end
    end
end

---comments
---@param text string -- the incomming line of text from the command prompt
local function ChannelExecGuildCommand(text, channName, channelID)
    local separator = "|"
    local args = {}
    for arg in string.gmatch(text, "([^" .. separator .. "]+)") do
        table.insert(args, arg)
    end
    local who = args[1]
    local message = args[2]
    -- todo: implement history
    if string.len(text) > 0 then
        text = StringTrim(text)
        if text == 'clear' then
            channelID:Clear()
        elseif who ~= nil and message ~= nil and RelayActor ~= nil then
            RelayActor:send({ mailbox = 'chat_relay', script = 'myui', }, { Name = who, Subject = 'GuildReply', Guild = channName, Message = message, })
            RelayActor:send({ mailbox = 'chat_relay', script = 'chatrelay', }, { Name = who, Subject = 'GuildReply', Guild = channName, Message = message, })
        end
    end
end

local function getGuildChat(line)
    if not settings[Module.DisplayName].RelayGuild then return end
    if RelayActor ~= nil then
        RelayActor:send({ mailbox = 'chat_relay', script = 'myui', }, GenerateContent('Guild', line))
        RelayActor:send({ mailbox = 'chat_relay', script = 'chatrelay', }, GenerateContent('Guild', line))
    end
end

local function sendGuildChat(line)
    if not settings[Module.DisplayName].RelayGuild then return end
    local repaceString = string.format('%s tells the guild,', MyUI_CharLoaded)
    lastMessages[MyUI_Guild] = string.gsub(line, 'You say to your guild,', repaceString)
    guildChat[MyUI_Guild]:AppendText(line)
end

local function getTellChat(line, who)
    if string.find(line, " pet tells you") then return end
    if not settings[Module.DisplayName].RelayTells then return end
    local checkNPC = string.format("npc =\"%s\"", who)
    local master = mq.TLO.Spawn(who).Master.Type() or 'noMaster'
    -- local checkPet = string.format("pcpet %s",who)
    local pet = mq.TLO.Me.Pet.DisplayName() or 'noPet'
    if (mq.TLO.SpawnCount(checkNPC)() ~= 0 or master == 'PC' or string.find(pet, who)) then return end
    if RelayActor ~= nil then
        RelayActor:send({ mailbox = 'chat_relay', script = 'chatrelay', }, GenerateContent('Tell', line))
        RelayActor:send({ mailbox = 'chat_relay', script = 'myui', }, GenerateContent('Tell', line))
    end
end

local function resizeConsoleFonts()
    for k in pairs(guildChat) do
        guildChat[k].fontSize = settings[Module.DisplayName].FontSize
    end
    for k in pairs(tellChat) do
        tellChat[k].fontSize = settings[Module.DisplayName].FontSize
    end
end

function Module.RenderGUI()
    if showMain then
        Minimized = false
        NewMessage = false
        --ImGui.PushStyleColor(ImGuiCol.Tab, ImVec4(0.000, 0.000, 0.000, 0.000))
        ImGui.PushStyleColor(ImGuiCol.TabActive, ImVec4(0.848, 0.449, 0.115, 1.000))
        ImGui.SetNextWindowSize(185, 480, ImGuiCond.FirstUseEver)
        if aSize then
            winFlags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize)
        else
            winFlags = bit32.bor(ImGuiWindowFlags.None)
        end
        local winLbl = string.format("%s##_%s", Module.DisplayName, MyUI_CharLoaded)
        local openGUI, showGUI = ImGui.Begin(winLbl, true, winFlags)
        if not openGUI then
            showMain = false
        end
        if showGUI then
            if ImGui.Button("Config") then
                showConfig = not showConfig
            end
            ImGui.SameLine()
            if ImGui.BeginTabBar("Chat Relay##ChatRelay", ImGuiTabBarFlags.None) then
                if RelayGuild then
                    if ImGui.BeginTabItem("Guild Chat") then
                        if ImGui.BeginTabBar("Guild Chat##GuildChat", ImGuiTabBarFlags.None) then
                            local sortedKeys = {}
                            sortedKeys = sortedBoxes(guildChat)
                            for key in pairs(sortedKeys) do
                                local gName = sortedKeys[key]
                                local gConsole = guildChat[gName]
                                local conTag = false
                                local contentSizeX, contentSizeY = ImGui.GetContentRegionAvail()
                                contentSizeY = contentSizeY - 30
                                if guildBufferCount[gName].Current > guildBufferCount[gName].Last then
                                    ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(1, 0, 0, 1))
                                    conTag = true
                                end
                                if ImGui.BeginTabItem(gName) then
                                    if guildBufferCount[gName].Current ~= guildBufferCount[gName].Last then
                                        guildBufferCount[gName].Last = guildBufferCount[gName].Current
                                    end
                                    gConsole:Render(ImVec2(contentSizeX, contentSizeY))
                                    ImGui.Separator()
                                    local textFlags = bit32.bor(0,
                                        ImGuiInputTextFlags.EnterReturnsTrue
                                    -- not implemented yet
                                    -- ImGuiInputTextFlags.CallbackCompletion,
                                    -- ImGuiInputTextFlags.CallbackHistory
                                    )
                                    -- local contentSizeX, _ = ImGui.GetContentRegionAvail()
                                    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                                    ImGui.SetCursorPosY(ImGui.GetCursorPosY() + 2)
                                    local accept = false
                                    local cmdBuffer = ''
                                    ImGui.SetNextItemWidth(contentSizeX)
                                    cmdBuffer, accept = ImGui.InputTextWithHint('##Input##' .. gName, "who|message", cmdBuffer, textFlags)
                                    if accept then
                                        ChannelExecGuildCommand(cmdBuffer, gName, gConsole)
                                        cmdBuffer = ''
                                    end
                                    ImGui.EndTabItem()
                                end
                                if conTag then
                                    ImGui.PopStyleColor()
                                end
                            end
                            ImGui.EndTabBar()
                        end
                        ImGui.EndTabItem()
                    end
                end
                if RelayTells then
                    if ImGui.BeginTabItem("Tell Chat") then
                        if ImGui.BeginTabBar("Tell Chat##TellChat", ImGuiTabBarFlags.None) then
                            local sortedKeys = {}
                            sortedKeys = sortedBoxes(tellChat)
                            for key in pairs(sortedKeys) do
                                local tName = sortedKeys[key]
                                local tConsole = tellChat[tName]
                                local contentSizeX, contentSizeY = ImGui.GetContentRegionAvail()
                                local colFlag = false
                                contentSizeY = contentSizeY - 30
                                if charBufferCount[tName].Current > charBufferCount[tName].Last then
                                    ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(1, 0, 0, 1))
                                    colFlag = true
                                end
                                if ImGui.BeginTabItem(tName) then
                                    if charBufferCount[tName].Current ~= charBufferCount[tName].Last then
                                        charBufferCount[tName].Last = charBufferCount[tName].Current
                                    end

                                    tConsole:Render(ImVec2(contentSizeX, contentSizeY))
                                    --Command Line
                                    ImGui.Separator()
                                    local textFlags = bit32.bor(0,
                                        ImGuiInputTextFlags.EnterReturnsTrue
                                    -- not implemented yet
                                    -- ImGuiInputTextFlags.CallbackCompletion,
                                    -- ImGuiInputTextFlags.CallbackHistory
                                    )
                                    -- local contentSizeX, _ = ImGui.GetContentRegionAvail()
                                    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                                    ImGui.SetCursorPosY(ImGui.GetCursorPosY() + 2)
                                    local accept = false
                                    local cmdBuffer = ''
                                    ImGui.SetNextItemWidth(contentSizeX)
                                    cmdBuffer, accept = ImGui.InputTextWithHint('##Input##' .. tName, "who|message", cmdBuffer, textFlags)
                                    if accept then
                                        ChannelExecCommand(cmdBuffer, tName, tConsole)
                                        cmdBuffer = ''
                                    end
                                    ImGui.EndTabItem()
                                end
                                if colFlag then
                                    ImGui.PopStyleColor()
                                end
                            end
                            ImGui.EndTabBar()
                        end
                        ImGui.EndTabItem()
                    end
                end
                ImGui.EndTabBar()
            end
        end
        if ImGui.IsWindowFocused(ImGuiFocusedFlags.RootAndChildWindows) and settings[Module.DisplayName].EscapeToMin then
            if ImGui.IsKeyPressed(ImGuiKey.Escape) then
                showMain = false
            end
        end
        ImGui.PopStyleColor()
        ImGui.End()
    end

    if Minimized then
        ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0.1, 0.1, 0.1, 1))
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0.2, 0.2, 0.2, 1))
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImVec4(0, 0, 0, 0.6))
        ImGui.SetNextWindowSize(100, 100, ImGuiCond.FirstUseEver)
        ImGui.SetNextWindowPos(500, 700, ImGuiCond.FirstUseEver)
        local openMini, showMini = ImGui.Begin("Chat Relay Mini##" .. MyUI_CharLoaded, true, bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar))
        if not openMini then
            Minimized = false
        end
        if showMini then
            if not settings[Module.DisplayName].ShowOnNewMessage and NewMessage then
                if ImGui.ImageButton("ChatRelay", minImg:GetTextureID(), ImVec2(settings[Module.DisplayName].IconSize, settings[Module.DisplayName].IconSize), ImVec2(0.0, 0.0), ImVec2(1, 1), ImVec4(0, 0, 0, 0), ImVec4(1, 0, 0, 1)) then
                    showMain = true
                    Minimized = false
                end
            else
                if ImGui.ImageButton("ChatRelay", minImg:GetTextureID(), ImVec2(settings[Module.DisplayName].IconSize, settings[Module.DisplayName].IconSize)) then
                    showMain = true
                    Minimized = false
                end
            end

            if ImGui.BeginPopupContextWindow() then
                -- if ImGui.MenuItem("exit") then
                --     mq.exit()
                -- end
                if ImGui.MenuItem("config") then
                    showConfig = true
                end
                ImGui.EndPopup()
            end
        end
        ImGui.PopStyleColor(3)
        ImGui.End()
    end

    if showConfig then
        local openConfGui, showConfGui = ImGui.Begin("Chat Relay Config", true, ImGuiWindowFlags.None)
        if not openConfGui then
            showConfig = false
        end
        if showConfGui then
            ImGui.Text("Chat Relay Configuration")
            ImGui.Separator()

            ImGui.Text("Chat Relay Settings")
            RelayTells = ImGui.Checkbox("Relay Tells", RelayTells)
            RelayGuild = ImGui.Checkbox("Relay Guild", RelayGuild)

            ImGui.Separator()
            settings[Module.DisplayName].ShowOnNewMessage = ImGui.Checkbox("Show on New Message", settings[Module.DisplayName].ShowOnNewMessage)
            settings[Module.DisplayName].EscapeToMin = ImGui.Checkbox("Escape to Minimize", settings[Module.DisplayName].EscapeToMin)

            ImGui.SetNextItemWidth(100)
            settings[Module.DisplayName].IconSize = ImGui.SliderInt("Icon Size", settings[Module.DisplayName].IconSize, 10, 50)
            ImGui.SetNextItemWidth(100)

            if ImGui.BeginCombo("Font Size##ChatRelay", tostring(settings[Module.DisplayName].FontSize)) then
                for k, data in pairs(fontSizes) do
                    local isSelected = data == settings[Module.DisplayName].FontSize
                    if ImGui.Selectable(tostring(data), isSelected) then
                        settings[Module.DisplayName].FontSize = data
                        resizeConsoleFonts()
                    end
                end
                ImGui.EndCombo()
            end

            ImGui.Separator()
            if ImGui.Button("Save") then
                settings[Module.DisplayName].RelayTells = RelayTells
                settings[Module.DisplayName].RelayGuild = RelayGuild
                mq.pickle(configFile, settings)
                showConfig = false
            end
            ImGui.End()
        end
    end
end

function SetSetting(setting, value)
    settings[Module.DisplayName][setting] = value
    mq.pickle(configFile, settings)
end

function Module.CheckMode()
    if MyUI_Mode == 'driver' then
        Minimized = settings[Module.DisplayName].EscapeToMin
        showMain = not Minimized
        mode = 'driver'
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ao Setting \atDriver\ax Mode. UI will be displayed.')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ao Type \at/chatrelay show\ax. to Toggle the UI')
    elseif MyUI_Mode == 'client' then
        showMain = false
        mode = 'client'
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ao Setting \atClient\ax Mode. UI will not be displayed.')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ao Type \at/chatrelay show\ax. to Toggle the UI')
    end
end

local function processCommand(...)
    local args = { ..., }
    if #args > 0 then
        if args[1] == 'gui' or args[1] == 'show' or args[1] == 'open' then
            showMain = not showMain
            if showMain then
                MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ao Toggling GUI \atOpen\ax.')
            else
                MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ao Toggling GUI \atClosed\ax.')
            end
        elseif args[1] == 'exit' or args[1] == 'quit' then
            Module.IsRunning = false
            MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ao Exiting.')
            Module.IsRunning = false
        elseif args[1] == 'tells' then
            settings[Module.DisplayName].RelayTells = not settings[Module.DisplayName].RelayTells
            RelayTells = settings[Module.DisplayName].RelayTells
            mq.pickle(configFile, settings)
        elseif args[1] == 'guild' then
            settings[Module.DisplayName].RelayGuild = not settings[Module.DisplayName].RelayGuild
            RelayGuild = settings[Module.DisplayName].RelayGuild
            mq.pickle(configFile, settings)
        elseif args[1] == 'autoshow' then
            settings[Module.DisplayName].ShowOnNewMessage = not settings[Module.DisplayName].ShowOnNewMessage
            mq.pickle(configFile, settings)
        else
            MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ao Invalid command given.')
        end
    else
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ao No command given.')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ag /chatrelay gui \ao- Toggles the GUI on and off.')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ag /chatrelay tells \ao- Toggles the Relay of Tells.')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ag /chatrelay guild \ao- Toggles the Relay of Guild Chat.')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ag /chatrelay autoshow \ao- Toggles the Show on New Message.')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayChat Relay:\ag /chatrelay exit \ao- Exits the plugin.')
    end
end

function Module.Unload()
    mq.unevent("guild_chat_relay")
    mq.unevent("guild_out_chat_relay")
    mq.unevent("tell_chat_relay")
    mq.unevent("out_chat_relay")
    mq.unbind("/chatrelay")
    RelayActor = nil
end

local arguments = { ..., }
function Module.CheckArgs(args)
    if #args > 0 then
        if args[1] == 'driver' then
            if args[2] ~= nil then
                if args[2] == 'mini' then Minimized = true else showMain = true end
            else
                showMain = true
            end
            mode = 'driver'
            print('\ayChat Relay:\ao Setting \atDriver\ax Mode. UI will be displayed.')
            print('\ayChat Relay:\ao Type \at/chatrelay show\ax. to Toggle the UI')
        elseif args[1] == 'client' then
            showMain = false
            mode = 'client'
            print('\ayChat Relay:\ao Setting \atClient\ax Mode. UI will not be displayed.')
            print('\ayChat Relay:\ao Type \at/chatrelay show\ax. to Toggle the UI')
        end
    else
        showMain = true
        mode = 'driver'
        print('\ayChat Relay: \aoNo arguments passed, defaulting to \atDriver\ax Mode. UI will be displayed.')
        print('\ayChat Relay: \aoUse \at/lua run chatrelay client\ax To start with the UI Off.')
        print('\ayChat Relay:\ao Type \at/chatrelay show\ax. to Toggle the UI')
    end
end

local function init()
    local tStamp = mq.TLO.Time.Time24()
    configFile = string.format("%s/MyUI/ChatRelay/%s/%s.lua", mq.configDir, MyUI_Server, MyUI_CharLoaded)
    currZone = mq.TLO.Zone.ID()
    lastZone = currZone
    mq.bind('/chatrelay', processCommand)
    LoadSettings()
    if loadedExeternally then
        Module.CheckMode()
    else
        Module.CheckArgs(arguments)
    end
    RegisterRelayActor()
    -- mq.delay(250)
    mq.event('guild_chat_relay', '#*# tells the guild, #*#', getGuildChat, { keepLinks = true, })
    mq.event('guild_out_chat_relay', 'You say to your guild, #*#', sendGuildChat, { keepLinks = true, })
    mq.event('tell_chat_relay', "#1# tells you, '#*#", getTellChat, { keepLinks = true, })
    mq.event('out_chat_relay', "You told #1#, '#*#", getTellChat, { keepLinks = true, })
    Module.IsRunning = true
    guildChat[MyUI_Guild] = ImGui.ConsoleWidget.new("chat_relay_Console" .. MyUI_Guild .. "##chat_relayConsole")
    guildChat[MyUI_Guild].fontSize = settings[Module.DisplayName].FontSize
    tellChat[MyUI_CharLoaded] = ImGui.ConsoleWidget.new("chat_relay_Console" .. MyUI_CharLoaded .. "##chat_relayConsole")
    tellChat[MyUI_CharLoaded].fontSize = settings[Module.DisplayName].FontSize
    MyUI_Utils.AppendColoredTimestamp(guildChat[MyUI_Guild], tStamp, "Welcome to Chat Relay")
    MyUI_Utils.AppendColoredTimestamp(tellChat[MyUI_CharLoaded], tStamp, "Welcome to Chat Relay")
    charBufferCount[MyUI_CharLoaded] = { Current = 1, Last = 1, }
    guildBufferCount[MyUI_Guild] = { Current = 1, Last = 1, }
    lastAnnounce = os.time()
    Module.IsRunning = true
    if not loadedExeternally then
        mq.imgui.init(Module.Name, Module.RenderGUI)
        Module.LocalLoop()
    end
end

local clockTimer = mq.gettime()

function Module.MainLoop()
    if loadedExeternally then
        ---@diagnostic disable-next-line: undefined-global
        if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
    end
    mq.doevents()
    local elapsedTime = mq.gettime() - clockTimer
    if elapsedTime >= 50 then
        currZone = mq.TLO.Zone.ID()
        if currZone ~= lastZone then
            lastZone = currZone
        end
        if not showMain and mode == 'driver' then Minimized = true end
    end
end

function Module.LocalLoop()
    while Module.IsRunning do
        Module.MainLoop()
        mq.delay(1)
    end
end

if mq.TLO.EverQuest.GameState() ~= "INGAME" then
    printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", Module.DisplayName)
    mq.exit()
end

init()

return Module
