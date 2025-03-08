local mq                = require('mq')
local imgui             = require 'ImGui'
---@diagnostic disable:undefined-global

local Module            = {}
Module.ActorMailBox     = 'aa_party'
Module.IsRunning        = false
Module.Name             = 'AAParty'
Module.DisplayName      = 'AA Party'

local loadedExeternally = MyUI_ScriptName ~= nil and true or false
if not loadedExeternally then
    Module.Utils       = require('lib.common')
    Module.ThemeLoader = require('lib.theme_loader')
    Module.Actor       = require('actors')
    Module.CharLoaded  = mq.TLO.Me.DisplayName()
    Module.Mode        = 'driver'
    Module.ThemeFile   = Module.ThemeFile == nil and string.format('%s/MyUI/ThemeZ.lua', mq.configDir) or Module.ThemeFile
    Module.Theme       = {}
    Module.Colors      = require('lib.colors')
    Module.Server      = mq.TLO.MacroQuest.Server():gsub(" ", "_")
else
    Module.Utils       = MyUI_Utils
    Module.ThemeLoader = MyUI_ThemeLoader
    Module.Actor       = MyUI_Actor
    Module.CharLoaded  = MyUI_CharLoaded
    Module.Mode        = MyUI_Mode
    Module.ThemeFile   = MyUI_ThemeFile
    Module.Theme       = MyUI_Theme
    Module.Colors      = MyUI_Colors
    Module.Server      = MyUI_Server
end
local myself                                                            = mq.TLO.Me
local MyGroupLeader                                                     = mq.TLO.Group.Leader() or "NoGroup"
local themeID                                                           = 1
local expand, compact                                                   = {}, {}
local configFileOld                                                     = mq.configDir .. '/myui/AA_Party_Configs.lua'
local configFile                                                        = string.format('%s/myui/AAParty/%s/%s.lua', mq.configDir, Module.Server, Module.CharLoaded)
local themezDir                                                         = mq.luaDir .. '/themez/init.lua'
local MeLevel                                                           = myself.Level()
local PctExp                                                            = myself.PctExp()
local winFlags                                                          = bit32.bor(ImGuiWindowFlags.None)
local checkIn                                                           = os.time()
local currZone, lastZone
local lastAirValue                                                      = 100
local PctAA, SettingAA, PtsAA, PtsSpent, PtsTotal, PtsAALast, LastState = 0, '0', 0, 0, 0, 0, ""
local firstRun                                                          = true
local hasThemeZ                                                         = Module.Utils.File.Exists(themezDir)
local settings                                                          = {}
local TempSettings                                                      = {}
local groupData                                                         = {}
local mailBox                                                           = {}
local aaActor                                                           = nil
local AAPartyShow                                                       = false
local MailBoxShow                                                       = false
local AAPartyConfigShow                                                 = false
local AAPartyMode                                                       = 'driver'
local iconSize                                                          = 15
local needSave                                                          = false
local defaults                                                          = {
    Scale = 1,
    LoadTheme = 'Default',
    AutoSize = false,
    ShowTooltip = true,
    MaxRow = 1,
    AlphaSort = false,
    MyGroupOnly = true,
    LockWindow = false,
}

local function loadTheme()
    if Module.Utils.File.Exists(Module.ThemeFile) then
        Module.Theme = dofile(Module.ThemeFile)
    else
        Module.Theme = require('defaults.themes') -- your local themes file incase the user doesn't have one in config folder
    end
    TempSettings.themeName = settings[Module.DisplayName].LoadTheme or 'Default'
end

local function loadSettings()
    -- Check if the dialog data file exists
    local newSetting = false
    if not Module.Utils.File.Exists(configFile) then
        if Module.Utils.File.Exists(configFileOld) then
            settings = dofile(configFileOld)
            mq.pickle(configFile, settings)
        else
            settings[Module.DisplayName] = defaults
            mq.pickle(configFile, settings)
        end
    else
        -- Load settings from the Lua config file
        settings = dofile(configFile)
    end
    if settings[Module.DisplayName] == nil then
        settings[Module.DisplayName] = {}
        settings[Module.DisplayName] = defaults
        newSetting = true
    end

    if settings[Module.DisplayName].LockWindow == nil then
        settings[Module.DisplayName].LockWindow = false
        newSetting = true
    end

    if settings[Module.DisplayName].AlphaSort == nil then
        settings[Module.DisplayName].AlphaSort = false
        newSetting = true
    end

    if settings[Module.DisplayName].Scale == nil then
        settings[Module.DisplayName].Scale = 1
        newSetting = true
    end

    if settings[Module.DisplayName].ShowTooltip == nil then
        settings[Module.DisplayName].ShowTooltip = true
        newSetting = true
    end

    if settings[Module.DisplayName].MaxRow == nil then
        settings[Module.DisplayName].MaxRow = 1
        newSetting = true
    end

    if settings[Module.DisplayName].LoadTheme == nil then
        settings[Module.DisplayName].LoadTheme = 'Default'
        newSetting = true
    end

    if settings[Module.DisplayName].MyGroupOnly == nil then
        settings[Module.DisplayName].MyGroupOnly = true
        newSetting = true
    end

    if not loadedExeternally then
        loadTheme()
    end

    if settings[Module.LockWindow] == nil then

    end

    if settings[Module.DisplayName].AutoSize == nil then
        settings[Module.DisplayName].AutoSize = TempSettings.aSize
        newSetting = true
    end

    -- Set the settings to the variables
    TempSettings.alphaSort   = settings[Module.DisplayName].AlphaSort
    TempSettings.aSize       = settings[Module.DisplayName].AutoSize
    TempSettings.scale       = settings[Module.DisplayName].Scale
    TempSettings.showTooltip = settings[Module.DisplayName].ShowTooltip
    TempSettings.themeName   = settings[Module.DisplayName].LoadTheme
    TempSettings.MyGroupOnly = settings[Module.DisplayName].MyGroupOnly
    TempSettings.LockWindow  = settings[Module.DisplayName].LockWindow
    if newSetting then mq.pickle(configFile, settings) end
end

local function CheckIn()
    local now = os.time()
    if now - checkIn >= 270 or firstRun then
        return true
    end
    return false
end

local function CheckStale()
    local now = os.time()
    local found = false
    for i = 1, #groupData do
        if groupData[1].Check == nil then
            table.remove(groupData, i)
            found = true
            break
        else
            if now - groupData[i].Check > 900 then
                table.remove(groupData, i)
                found = true
                break
            end
        end
    end
    if found then CheckStale() end
end

local function GenerateContent(who, sub, what)
    local doWhat = what or nil
    local doWho = who or nil
    local Subject = sub or 'Update'
    local cState = myself.CombatState()
    LastState = cState
    if firstRun then
        Subject = 'Hello'
        firstRun = false
    end
    return {
        Subject     = Subject,
        PctExp      = PctExp,
        PctExpAA    = PctAA,
        Level       = MeLevel,
        Setting     = SettingAA,
        GroupLeader = MyGroupLeader,
        DoWho       = doWho,
        DoWhat      = doWhat,
        Name        = myself.DisplayName(),
        Pts         = PtsAA,
        PtsTotal    = PtsTotal,
        PtsSpent    = PtsSpent,
        Check       = checkIn,
        State       = cState,
        PctAir      = myself.PctAirSupply(),
    }
end

local function sortedBoxes(boxes)
    table.sort(boxes, function(a, b)
        if a.GroupLeader == b.GroupLeader then return a.Name < b.Name end
        return a.GroupLeader < b.GroupLeader
    end)
    return boxes
end

--create mailbox for actors to send messages to
local function MessageHandler()
    aaActor = Module.Actor.register(Module.ActorMailBox, function(message)
        local MemberEntry = message()
        local subject     = MemberEntry.Subject or 'Update'
        local aaXP        = MemberEntry.PctExpAA or 0
        local aaSetting   = MemberEntry.Setting or '0'
        local who         = MemberEntry.Name
        local pctXP       = MemberEntry.PctExp or 0
        local pts         = MemberEntry.Pts or 0
        local ptsTotal    = MemberEntry.PtsTotal or 0
        local ptsSpent    = MemberEntry.PtsSpent or 0
        local lvlWho      = MemberEntry.Level or 0
        local dowhat      = MemberEntry.DoWhat or 'N/A'
        local dowho       = MemberEntry.DoWho or 'N/A'
        local check       = MemberEntry.Check or os.time()
        local pctAir      = MemberEntry.PctAir or 100
        local groupLeader = MemberEntry.GroupLeader or 'N/A'
        local found       = false
        if MailBoxShow then
            table.insert(mailBox, { Name = who, Subject = subject, Check = check, DoWho = dowho, DoWhat = dowhat, When = os.date("%H:%M:%S"), })
            table.sort(mailBox, function(a, b)
                if a.Check == b.Check then
                    return a.Name < b.Name
                else
                    return a.Check > b.Check
                end
            end)
        end
        --New member connected if Hello is true. Lets send them our data so they have it.
        if subject == 'Hello' then
            -- if who ~= Module.CharLoaded then
            if aaActor ~= nil then
                aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, GenerateContent(nil, 'Welcome'))
                aaActor:send({ mailbox = 'aa_party', script = 'myui', }, GenerateContent(nil, 'Welcome'))
            end
            -- end
            return
            -- checkIn = os.time()
        elseif subject == 'Action' then
            if dowho ~= 'N/A' then
                if MemberEntry.DoWho == Module.CharLoaded then
                    if dowhat == 'Less' then
                        mq.TLO.Window("AAWindow/AAW_LessExpButton").LeftMouseUp()
                        return
                    elseif dowhat == 'More' then
                        mq.TLO.Window("AAWindow/AAW_MoreExpButton").LeftMouseUp()
                        return
                    end
                end
            end
        elseif subject == 'Goodbye' then
            for i = 1, #groupData do
                if groupData[i].Name == who then
                    table.remove(groupData, i)
                    break
                end
            end
        end
        if subject == 'Set' then
            if dowho ~= 'N/A' then
                if MemberEntry.DoWho == Module.CharLoaded then
                    if dowhat == 'min' then
                        mq.cmd('/alt on 0')
                        return
                    elseif dowhat == 'max' then
                        mq.cmd('/alt on 100')
                        return
                    elseif dowhat == 'mid' then
                        mq.cmd('/alt on 50')
                        return
                    end
                end
            end
        end
        if subject ~= 'Action' then
            -- Process the rest of the message into the groupData table.
            if #groupData > 0 then
                for i = 1, #groupData do
                    if groupData[i].Name == who then
                        groupData[i].PctExpAA = aaXP
                        groupData[i].PctExp = pctXP
                        groupData[i].Setting = aaSetting
                        groupData[i].Pts = pts
                        groupData[i].PtsTotal = ptsTotal
                        groupData[i].PtsSpent = ptsSpent
                        groupData[i].Level = lvlWho
                        groupData[i].Check = check
                        groupData[i].State = MemberEntry.State
                        groupData[i].PctAir = pctAir
                        groupData[i].GroupLeader = groupLeader
                        if groupData[i].LastPts ~= pts then
                            if who ~= Module.CharLoaded and AAPartyMode == 'driver' and groupData[i].LastPts < pts then
                                Module.Utils.PrintOutput('MyUI', true, "%s gained an AA, now has %d unspent", who, pts)
                            end
                            groupData[i].LastPts = pts
                        end
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(groupData,
                        {
                            Name = who,
                            Level = lvlWho,
                            PctExpAA = aaXP,
                            PctExp = pctXP,
                            DoWho = nil,
                            GroupLeader = groupLeader,
                            DoWhat = nil,
                            Setting = aaSetting,
                            Pts = pts,
                            PtsTotal = ptsTotal,
                            PtsSpent = ptsSpent,
                            LastPts = pts,
                            State = MemberEntry.State,
                            Check = check,
                            PctAir = pctAir,
                        })
                end
            else
                table.insert(groupData,
                    {
                        Name = who,
                        Level = lvlWho,
                        PctExpAA = aaXP,
                        PctExp = pctXP,
                        DoWho = nil,
                        GroupLeader = groupLeader,
                        DoWhat = nil,
                        Setting = aaSetting,
                        Pts = pts,
                        PtsTotal = ptsTotal,
                        PtsSpent = ptsSpent,
                        LastPts = pts,
                        State = MemberEntry.State,
                        Check = check,
                        PctAir = pctAir,
                    })
            end
        end
        if TempSettings.alphaSort then groupData = sortedBoxes(groupData) end
        if check == 0 then CheckStale() end
    end)
end

local function getMyAA()
    local changed      = false
    local tmpExpAA     = myself.PctAAExp() or 0
    local tmpSettingAA = mq.TLO.Window("AAWindow/AAW_PercentCount").Text() or '0'
    local tmpPts       = myself.AAPoints() or 0
    local tmpPtsTotal  = myself.AAPointsTotal() or 0
    local tmpPtsSpent  = myself.AAPointsSpent() or 0
    local tmpPctXP     = myself.PctExp() or 0
    local tmpLvl       = myself.Level() or 0
    local cState       = myself.CombatState() or ""
    local tmpAirSupply = myself.PctAirSupply()
    MyGroupLeader      = mq.TLO.Group.Leader() or "NoGroup"
    if firstRun or (PctAA ~= tmpExpAA or SettingAA ~= tmpSettingAA or PtsAA ~= tmpPts or
            PtsSpent ~= tmpPtsSpent or PtsTotal ~= tmpPtsTotal or tmpLvl ~= MeLevel or tmpPctXP ~= PctExp or cState ~= LastState or tmpAirSupply ~= lastAirValue) then
        PctAA = tmpExpAA
        SettingAA = tmpSettingAA
        PtsAA = tmpPts
        PtsTotal = tmpPtsTotal
        PtsSpent = tmpPtsSpent
        MeLevel = tmpLvl
        PctExp = tmpPctXP
        PctAir = tmpAirSupply
        if tmpAirSupply ~= lastAirValue then
            lastAirValue = tmpAirSupply
        end
        changed = true
    end
    if not changed and CheckIn() then
        if aaActor ~= nil then
            aaActor:send({ mailbox = 'aa_party', script = 'myui', }, GenerateContent(nil, 'CheckIn'))
            aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, GenerateContent(nil, 'CheckIn'))

            checkIn = os.time()
        end
    end
    if changed then
        if aaActor ~= nil then
            aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, GenerateContent())
            aaActor:send({ mailbox = 'aa_party', script = 'myui', }, GenerateContent())
            checkIn = os.time()
            changed = false
        end
    end
end

local function SayGoodBye()
    local message = {
        Subject = 'Goodbye',
        Name = Module.CharLoaded,
        Check = 0,
    }
    if aaActor ~= nil then
        aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, message)
        aaActor:send({ mailbox = 'aa_party', script = 'myui', }, message)
    end
end

function Module.RenderGUI()
    if AAPartyShow then
        imgui.SetNextWindowSize(185, 480, ImGuiCond.FirstUseEver)
        if TempSettings.aSize then
            winFlags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize)
        else
            winFlags = bit32.bor(ImGuiWindowFlags.None)
        end
        if TempSettings.LockWindow then
            winFlags = bit32.bor(winFlags, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoMove)
        else
            winFlags = bit32.bor(winFlags)
        end
        local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(settings[Module.DisplayName].LoadTheme or 'Default', Module.Theme)
        local openGUI, showGUI = imgui.Begin("AA Party##_" .. Module.CharLoaded, true, winFlags)
        if not openGUI then
            AAPartyShow = false
        end
        if showGUI then
            if #groupData > 0 then
                local windowWidth = imgui.GetWindowWidth() - 4
                local currentX, currentY = imgui.GetCursorPosX(), imgui.GetCursorPosY()
                local itemWidth = 150 -- approximate width
                local padding = 2     -- padding between items
                local drawn = 0
                for i = 1, #groupData do
                    if groupData[i] ~= nil then
                        if (groupData[i].GroupLeader == MyGroupLeader and TempSettings.MyGroupOnly) or not TempSettings.MyGroupOnly then
                            if expand[groupData[i].Name] == nil then expand[groupData[i].Name] = false end
                            if compact[groupData[i].Name] == nil then compact[groupData[i].Name] = false end

                            if currentX + itemWidth > windowWidth then
                                imgui.NewLine()
                                currentY = imgui.GetCursorPosY()
                                currentX = imgui.GetCursorPosX()
                                -- currentY = imgui.GetCursorPosY()
                                ImGui.SetCursorPosY(currentY - 20)
                            else
                                if drawn > 0 then
                                    imgui.SameLine()
                                    -- ImGui.SetCursorPosY(currentY)
                                end
                            end
                            local modY = 6

                            if (groupData[i].PctAir < 100) then modY = 10 end
                            local childY = 68 + modY
                            if not expand[groupData[i].Name] then childY = 42 + modY end
                            if compact[groupData[i].Name] then childY = 25 end
                            if compact[groupData[i].Name] and expand[groupData[i].Name] then childY = 53 + modY end
                            ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 2, 2)
                            imgui.BeginChild(groupData[i].Name, 145, childY, bit32.bor(ImGuiChildFlags.Border, ImGuiChildFlags.AutoResizeY), ImGuiWindowFlags.NoScrollbar)
                            -- Start of grouped Whole Elements
                            ImGui.BeginGroup()
                            -- Start of subgrouped Elements for tooltip
                            imgui.PushID(groupData[i].Name)
                            -- imgui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                            if ImGui.BeginTable('##data', 3, bit32.bor(ImGuiTableFlags.NoBordersInBody)) then
                                local widthMax = ImGui.GetContentRegionAvail()

                                ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.WidthFixed, 95)
                                ImGui.TableSetupColumn("Status", ImGuiTableColumnFlags.WidthFixed, iconSize)
                                ImGui.TableSetupColumn("Pts", ImGuiTableColumnFlags.WidthFixed, 25)
                                ImGui.TableNextRow()
                                ImGui.TableNextColumn()
                                imgui.Text(groupData[i].Name)
                                imgui.SameLine()
                                imgui.TextColored(Module.Colors.color('tangarine'), groupData[i].Level)
                                ImGui.TableNextColumn()
                                local combatState = groupData[i].State
                                if combatState == 'DEBUFFED' then
                                    Module.Utils.DrawStatusIcon('A_PWCSDebuff', 'pwcs', 'You are Debuffed and need a cure before resting.', iconSize)
                                elseif combatState == 'ACTIVE' then
                                    Module.Utils.DrawStatusIcon('A_PWCSStanding', 'pwcs', 'You are not in combat and may rest at any time.', iconSize)
                                elseif combatState == 'COOLDOWN' then
                                    Module.Utils.DrawStatusIcon('A_PWCSTimer', 'pwcs', 'You are recovering from combat and can not reset yet', iconSize)
                                elseif combatState == 'RESTING' then
                                    Module.Utils.DrawStatusIcon('A_PWCSRegen', 'pwcs', 'You are Resting.', iconSize)
                                elseif combatState == 'COMBAT' then
                                    Module.Utils.DrawStatusIcon('A_PWCSInCombat', 'pwcs', 'You are in Combat.', iconSize)
                                else
                                    Module.Utils.DrawStatusIcon(3996, 'item', ' ', iconSize)
                                end
                                ImGui.TableNextColumn()
                                ImGui.TextColored(Module.Colors.color('green'), groupData[i].Pts)
                                ImGui.EndTable()
                            end

                            if not compact[groupData[i].Name] then
                                imgui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(1, 0.9, 0.4, 0.5))
                                -- imgui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                                imgui.ProgressBar(groupData[i].PctExp / 100, ImVec2(137, 5), "##PctXP" .. groupData[i].Name)
                                imgui.PopStyleColor()

                                imgui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(0.2, 0.9, 0.9, 0.5))
                                -- imgui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                                imgui.ProgressBar(groupData[i].PctExpAA / 100, ImVec2(137, 5), "##AAXP" .. groupData[i].Name)
                                imgui.PopStyleColor()

                                if groupData[i].PctAir < 100 then
                                    imgui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(0.877, 0.492, 0.170, 1.000))
                                    -- imgui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                                    imgui.ProgressBar(groupData[i].PctAir / 100, ImVec2(137, 5), "##Air" .. groupData[i].Name)
                                    imgui.PopStyleColor()

                                    if ImGui.IsItemHovered() then imgui.SetTooltip("Air Supply: %s%%", groupData[i].PctAir) end
                                end
                            end

                            imgui.PopID()
                            ImGui.EndGroup()
                            -- end of subgrouped Elements for tooltip begin tooltip
                            if ImGui.IsItemHovered() and TempSettings.showTooltip then
                                imgui.BeginTooltip()
                                -- local tTipTxt = "\t\t" .. groupData[i].Name
                                imgui.TextColored(ImVec4(1, 1, 1, 1), "\t\t%s", groupData[i].Name)
                                imgui.Separator()
                                -- tTipTxt = string.format("Exp:\t\t\t%.2f %%", groupData[i].PctExp)
                                imgui.TextColored(ImVec4(1, 0.9, 0.4, 1), "Exp:\t\t\t%.2f %%", groupData[i].PctExp)
                                -- tTipTxt = string.format("AA Exp: \t%.2f %%", groupData[i].PctExpAA)
                                imgui.TextColored(ImVec4(0.2, 0.9, 0.9, 1), "AA Exp: \t%.2f %%", groupData[i].PctExpAA)
                                -- tTipTxt = string.format("Avail:  \t\t%d", groupData[i].Pts)
                                imgui.TextColored(ImVec4(0, 1, 0, 1), "Avail:  \t\t%d", groupData[i].Pts)
                                -- tTipTxt = string.format("Spent:\t\t%d", groupData[i].PtsSpent)
                                imgui.TextColored(ImVec4(0.9, 0.4, 0.4, 1), "Spent:\t\t%d", groupData[i].PtsSpent)
                                -- tTipTxt = string.format("Total:\t\t%d", groupData[i].PtsTotal)
                                imgui.TextColored(ImVec4(0.8, 0.0, 0.8, 1.0), "Total:\t\t%d", groupData[i].PtsTotal)
                                imgui.EndTooltip()
                            end
                            if imgui.IsItemHovered() then
                                if imgui.IsMouseReleased(0) then
                                    expand[groupData[i].Name] = not expand[groupData[i].Name]
                                end
                                if imgui.IsMouseReleased(1) then
                                    compact[groupData[i].Name] = not compact[groupData[i].Name]
                                end
                            end
                            -- end tooltip

                            -- expanded section for adjusting AA settings

                            if expand[groupData[i].Name] then
                                imgui.SetCursorPosX(ImGui.GetCursorPosX() + 12)
                                if imgui.Button("<##Decrease" .. groupData[i].Name) then
                                    if aaActor ~= nil then
                                        if ImGui.IsKeyDown(ImGuiMod.Ctrl) then
                                            aaActor:send({ mailbox = 'aa_party', script = 'aaparty', },
                                                { Name = MyUI_CharLoaded, Subject = 'Set', DoWho = groupData[i].Name, DoWhat = 'min', })
                                            aaActor:send({ mailbox = 'aa_party', script = 'myui', },
                                                { Name = MyUI_CharLoaded, Subject = 'Set', DoWho = groupData[i].Name, DoWhat = 'min', })
                                        else
                                            aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, GenerateContent(groupData[i].Name, 'Action', 'Less'))
                                            aaActor:send({ mailbox = 'aa_party', script = 'myui', }, GenerateContent(groupData[i].Name, 'Action', 'Less'))
                                        end
                                    end
                                end
                                imgui.SameLine()
                                local tmp = groupData[i].Setting
                                tmp = tmp:gsub("%%", "")
                                local AA_Set = tonumber(tmp) or 0
                                -- this is for my OCD on spacing
                                if AA_Set == 0 then
                                    imgui.Text("AA Set:    %d", AA_Set)
                                    imgui.SameLine()
                                    imgui.SetCursorPosX(ImGui.GetCursorPosX() + 7)
                                elseif AA_Set < 100 then
                                    imgui.Text("AA Set:   %d", AA_Set)
                                    imgui.SameLine()
                                    imgui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                                else
                                    imgui.Text("AA Set: %d", AA_Set)
                                    imgui.SameLine()
                                    imgui.SetCursorPosX(ImGui.GetCursorPosX())
                                end
                                if aaActor ~= nil then
                                    if ImGui.IsItemHovered() and ImGui.IsMouseClicked(ImGuiMouseButton.Left) and ImGui.IsKeyDown(ImGuiMod.Ctrl) then
                                        aaActor:send({ mailbox = 'aa_party', script = 'aaparty', },
                                            { Name = MyUI_CharLoaded, Subject = 'Set', DoWho = groupData[i].Name, DoWhat = 'mid', })
                                        aaActor:send({ mailbox = 'aa_party', script = 'myui', },
                                            { Name = MyUI_CharLoaded, Subject = 'Set', DoWho = groupData[i].Name, DoWhat = 'mid', })
                                    end
                                end

                                if imgui.Button(">##Increase" .. groupData[i].Name) then
                                    if aaActor ~= nil then
                                        if ImGui.IsKeyDown(ImGuiMod.Ctrl) then
                                            aaActor:send({ mailbox = 'aa_party', script = 'aaparty', },
                                                { Name = MyUI_CharLoaded, Subject = 'Set', DoWho = groupData[i].Name, DoWhat = 'max', })
                                            aaActor:send({ mailbox = 'aa_party', script = 'myui', },
                                                { Name = MyUI_CharLoaded, Subject = 'Set', DoWho = groupData[i].Name, DoWhat = 'max', })
                                        else
                                            aaActor:send({ mailbox = 'aa_party', script = 'myui', }, GenerateContent(groupData[i].Name, 'Action', 'More'))
                                            aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, GenerateContent(groupData[i].Name, 'Action', 'More'))
                                        end
                                    end
                                end
                            end
                            drawn = drawn + 1
                            ImGui.Separator()
                            imgui.EndChild()
                            ImGui.PopStyleVar()
                            -- End of grouped items
                            -- Left Click to expand the group for AA settings
                            currentX = currentX + itemWidth + padding
                        end
                    end
                end
            end
            if ImGui.BeginPopupContextWindow() then
                if ImGui.MenuItem("Config##Config_" .. Module.CharLoaded) then
                    AAPartyConfigShow = not AAPartyConfigShow
                end
                if ImGui.MenuItem("Toggle Auto Size##Size_" .. Module.CharLoaded) then
                    TempSettings.aSize = not TempSettings.aSize
                    needSave = true
                end
                if ImGui.MenuItem("Toggle Tooltip##Tooltip_" .. Module.CharLoaded) then
                    TempSettings.showTooltip = not TempSettings.showTooltip
                    needSave = true
                end
                if ImGui.MenuItem("Toggle My Group Only##MyGroup_" .. Module.CharLoaded) then
                    TempSettings.MyGroupOnly = not TempSettings.MyGroupOnly
                    needSave = true
                end
                local lbl = TempSettings.LockWindow and "Unlock Window##" or "Lock Window##"
                if ImGui.MenuItem(lbl) then
                    TempSettings.LockWindow = not TempSettings.LockWindow
                    needSave = true
                end
                ImGui.EndPopup()
            end
            Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
            imgui.End()
        else
            Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
            imgui.End()
        end
    end

    if MailBoxShow then
        local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(settings[Module.DisplayName].LoadTheme or 'Default', Module.Theme)
        local openMail, showMail = imgui.Begin("AA Party MailBox##MailBox_" .. Module.CharLoaded, true, ImGuiWindowFlags.None)
        if not openMail then
            MailBoxShow = false
            mailBox = {}
        end
        if showMail then
            ImGui.BeginTable("Mail Box##AAparty", 6, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.ScrollY), ImVec2(0.0, 0.0))
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
        Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
        imgui.End()
    else
        mailBox = {}
    end

    if AAPartyConfigShow then
        local ColorCountTheme, StyleCountTheme = Module.ThemeLoader.StartTheme(settings[Module.DisplayName].LoadTheme or 'Default', Module.Theme)
        local openTheme, showConfig = ImGui.Begin('Config##_', true, bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.AlwaysAutoResize))
        if not openTheme then
            AAPartyConfigShow = false
        end
        if showConfig then
            ImGui.SeparatorText("Theme##")
            ImGui.Text("Cur Theme: %s", TempSettings.themeName)
            -- Combo Box Load Theme
            if ImGui.BeginCombo("Load Theme##", TempSettings.themeName) then
                for k, data in pairs(Module.Theme.Theme) do
                    local isSelected = data.Name == TempSettings.themeName
                    if ImGui.Selectable(data.Name, isSelected) then
                        settings[Module.DisplayName].LoadTheme = data.Name
                        TempSettings.themeName = settings[Module.DisplayName].LoadTheme
                        mq.pickle(configFile, settings)
                    end
                end
                ImGui.EndCombo()
            end

            TempSettings.scale = ImGui.SliderFloat("Scale##DialogDB", TempSettings.scale, 0.5, 2)
            if TempSettings.scale ~= settings[Module.DisplayName].Scale then
                if TempSettings.scale < 0.5 then TempSettings.scale = 0.5 end
                if TempSettings.scale > 2 then TempSettings.scale = 2 end
            end

            if hasThemeZ or loadedExeternally then
                if ImGui.Button('Edit ThemeZ') then
                    if not loadedExeternally then
                        mq.cmd("/lua run themez")
                    else
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
            end

            if ImGui.Button('Reload Theme File') then
                loadTheme()
            end

            MailBoxShow = ImGui.Checkbox("Show MailBox##", MailBoxShow)
            ImGui.SameLine()
            TempSettings.alphaSort = ImGui.Checkbox("Alpha Sort##", TempSettings.alphaSort)
            TempSettings.showTooltip = ImGui.Checkbox("Show Tooltip##", TempSettings.showTooltip)
            TempSettings.MyGroupOnly = ImGui.Checkbox("My Group Only##", TempSettings.MyGroupOnly)
            TempSettings.LockWindow = ImGui.Checkbox("Lock Window##", TempSettings.LockWindow)
            if ImGui.Button("Save & Close") then
                settings = dofile(configFile)
                settings[Module.DisplayName].Scale = TempSettings.scale
                settings[Module.DisplayName].AlphaSort = TempSettings.alphaSort
                settings[Module.DisplayName].LoadTheme = TempSettings.themeName
                settings[Module.DisplayName].ShowTooltip = TempSettings.showTooltip
                settings[Module.DisplayName].MyGroupOnly = TempSettings.MyGroupOnly
                settings[Module.DisplayName].LockWindow = TempSettings.LockWindow
                mq.pickle(configFile, settings)
                AAPartyConfigShow = false
            end
        end
        Module.ThemeLoader.EndTheme(ColorCountTheme, StyleCountTheme)
        ImGui.End()
    end
end

function Module.CheckMode()
    if Module.Mode == 'driver' then
        AAPartyShow = true
        AAPartyMode = 'driver'
        Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Setting \atDriver\ax Mode. UI will be displayed.')
        Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Type \at/aaparty show\ax. to Toggle the UI')
    elseif Module.Mode == 'client' then
        AAPartyMode = 'client'
        AAPartyShow = false
        Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Setting \atClient\ax Mode. UI will not be displayed.')
        Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Type \at/aaparty show\ax. to Toggle the UI')
    end
end

local args = { ..., }
function Module.CheckArgs(args)
    if #args > 0 then
        if args[1] == 'driver' then
            AAPartyShow = true
            AAPartyMode = 'driver'
            if args[2] ~= nil and args[2] == 'mailbox' then
                MailBoxShow = true
            end
            print('\ayAA Party:\ao Setting \atDriver\ax Mode. UI will be displayed.')
            print('\ayAA Party:\ao Type \at/aaparty show\ax. to Toggle the UI')
        elseif args[1] == 'client' then
            AAPartyMode = 'client'
            AAPartyShow = false
            print('\ayAA Party:\ao Setting \atClient\ax Mode. UI will not be displayed.')
            print('\ayAA Party:\ao Type \at/aaparty show\ax. to Toggle the UI')
        end
    else
        AAPartyShow = true
        AAPartyMode = 'driver'
        print('\ayAA Party: \aoNo arguments passed, defaulting to \atDriver\ax Mode. UI will be displayed.')
        print('\ayAA Party: \aoUse \at/lua run aaparty client\ax To start with the UI Off.')
        print('\ayAA Party:\ao Type \at/aaparty show\ax. to Toggle the UI')
    end
end

function Module.Unload()
    SayGoodBye()
    mq.unbind("/aaparty")
    aaActor = nil
end

local function processCommand(...)
    local args = { ..., }
    if #args > 0 then
        if args[1] == 'gui' or args[1] == 'show' or args[1] == 'open' then
            AAPartyShow = not AAPartyShow
            if AAPartyShow then
                Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Toggling GUI \atOpen\ax.')
            else
                Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Toggling GUI \atClosed\ax.')
            end
        elseif args[1] == 'exit' or args[1] == 'quit' then
            Module.IsRunning = false
            Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Exiting.')
            SayGoodBye()
            Module.IsRunning = false
        elseif args[1] == 'mailbox' then
            MailBoxShow = not MailBoxShow
            if MailBoxShow then
                Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Toggling MailBox \atOpen\ax.')
            else
                Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Toggling MailBox \atClosed\ax.')
            end
        else
            Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Invalid command given.')
        end
    else
        Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao No command given.')
        Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ag /aaparty gui \ao- Toggles the GUI on and off.')
        Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ag /aaparty exit \ao- Exits the plugin.')
    end
end

local function init()
    currZone = mq.TLO.Zone.ID()
    lastZone = currZone
    firstRun = true
    if not loadedExeternally then
        Module.CheckArgs(args)
        mq.imgui.init(Module.Name, Module.RenderGUI)
    else
        Module.CheckMode()
    end
    mq.bind('/aaparty', processCommand)
    PtsAA = myself.AAPoints()
    loadSettings()
    getMyAA()
    Module.IsRunning = true
    if Module.Utils.File.Exists(themezDir) then
        hasThemeZ = true
    end

    if aaActor ~= nil then
        aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, GenerateContent(nil, 'Hello'))
        aaActor:send({ mailbox = 'aa_party', script = 'myui', }, GenerateContent(nil, 'Hello'))
    end
    Module.IsRunning = true
    if not loadedExeternally then
        Module.LocalLoop()
    end
end

local clockTimer = mq.gettime()

function Module.MainLoop()
    if loadedExeternally then
        if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
    end
    local elapsedTime = mq.gettime() - clockTimer
    if not loadedExeternally or elapsedTime >= 50 then
        currZone = mq.TLO.Zone.ID()
        if currZone ~= lastZone then
            lastZone = currZone
        end
        if aaActor ~= nil then
            getMyAA()
            CheckStale()
        else
            MessageHandler()
        end
        if needSave then
            settings[Module.DisplayName].Scale = TempSettings.scale
            settings[Module.DisplayName].AlphaSort = TempSettings.alphaSort
            settings[Module.DisplayName].LoadTheme = TempSettings.themeName
            settings[Module.DisplayName].ShowTooltip = TempSettings.showTooltip
            settings[Module.DisplayName].MyGroupOnly = TempSettings.MyGroupOnly
            settings[Module.DisplayName].LockWindow = TempSettings.LockWindow
            mq.pickle(configFile, settings)
            needSave = false
        end
        clockTimer = mq.gettime()
    end
end

function Module.LocalLoop()
    while Module.IsRunning do
        Module.MainLoop()
        mq.delay(50)
    end
end

if mq.TLO.EverQuest.GameState() ~= "INGAME" then
    printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", Module.DisplayName)
    mq.exit()
end

MessageHandler()
init()
Module.MainLoop()
return Module
