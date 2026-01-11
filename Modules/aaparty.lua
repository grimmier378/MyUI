local mq                = require('mq')
local imgui             = require 'ImGui'
---@diagnostic disable:undefined-global

local Module            = {}
Module.ActorMailBox     = 'aa_party'
Module.IsRunning        = false
Module.Name             = 'AAParty'
Module.DisplayName      = 'AA Party'
Module.TempSettings     = {}
Module.Settings         = {}

local loadedExeternally = MyUI_ScriptName ~= nil and true or false
if not loadedExeternally then
    Module.Utils       = require('lib.common')
    Module.ThemeLoader = require('lib.theme_loader')
    Module.Actor       = require('actors')
    Module.CharLoaded  = mq.TLO.Me.DisplayName()
    Module.Mode        = 'driver'
    Module.ThemeFile   = Module.ThemeFile == nil and string.format('%s/MyUI/ThemeZ.lua', mq.configDir) or Module.ThemeFile
    Module.Theme       = require('defaults.themes')
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
local ToggleFlags                                                       = bit32.bor(Module.Utils.ImGuiToggleFlags.StarKnob,
    Module.Utils.ImGuiToggleFlags.PulseOnHover,
    Module.Utils.ImGuiToggleFlags.RightLabel)
local myself                                                            = mq.TLO.Me
local MyGroupLeader                                                     = mq.TLO.Group.Leader() or "NoGroup"
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
    ShowLeader = false,
}

function Module:LoadTheme()
    if self.Utils.File.Exists(self.ThemeFile) then
        self.Theme = dofile(self.ThemeFile)
    else
        self.Theme = require('defaults.themes') -- your local themes file incase the user doesn't have one in config folder
    end
    self.TempSettings.themeName = self.Settings[self.DisplayName].LoadTheme or 'Default'
end

function Module:LoadSettings()
    -- Check if the dialog data file exists
    local newSetting = false
    if not self.Utils.File.Exists(configFile) then
        if self.Utils.File.Exists(configFileOld) then
            self.Settings = dofile(configFileOld)
            mq.pickle(configFile, self.Settings)
        else
            self.Settings[self.DisplayName] = defaults
            mq.pickle(configFile, self.Settings)
        end
    else
        -- Load settings from the Lua config file
        self.Settings = dofile(configFile)
    end
    if self.Settings[self.DisplayName] == nil then
        self.Settings[self.DisplayName] = {}
        self.Settings[self.DisplayName] = defaults
        newSetting = true
    end

    newSetting = self.Utils.CheckDefaultSettings(defaults, self.Settings[self.DisplayName])
    newSetting = self.Utils.CheckRemovedSettings(defaults, self.Settings[self.DisplayName]) or newSetting

    if not loadedExeternally then
        self:LoadTheme()
    end

    -- Set the settings to the variables
    self.TempSettings.alphaSort   = self.Settings[self.DisplayName].AlphaSort
    self.TempSettings.aSize       = self.Settings[self.DisplayName].AutoSize
    self.TempSettings.scale       = self.Settings[self.DisplayName].Scale
    self.TempSettings.showTooltip = self.Settings[self.DisplayName].ShowTooltip
    self.TempSettings.themeName   = self.Settings[self.DisplayName].LoadTheme
    self.TempSettings.MyGroupOnly = self.Settings[self.DisplayName].MyGroupOnly
    self.TempSettings.LockWindow  = self.Settings[self.DisplayName].LockWindow
    self.TempSettings.ShowLeader  = self.Settings[self.DisplayName].ShowLeader
    if newSetting then mq.pickle(configFile, self.Settings) end
end

function Module:CheckIn()
    local now = os.time()
    if now - checkIn >= 270 or firstRun then
        return true
    end
    return false
end

function Module:CheckStale()
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
    if found then self:CheckStale() end
end

function Module:GenerateContent(who, sub, what)
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
        Check       = os.time(),
        State       = cState,
        PctAir      = myself.PctAirSupply(),
    }
end

function Module:SortBoxes(boxes)
    if self.TempSettings.alphaSort then
        table.sort(boxes, function(a, b)
            if a == nil or b == nil then return false end
            if a.GroupLeader == b.GroupLeader then return a.Name < b.Name end
            return a.GroupLeader < b.GroupLeader
        end)
    else
        table.sort(boxes, function(a, b)
            if a == nil or b == nil then return false end
            return a.GroupLeader < b.GroupLeader
        end)
    end
    return boxes
end

--create mailbox for actors to send messages to
function Module:MessageHandler()
    aaActor = self.Actor.register(self.ActorMailBox, function(message)
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
            table.insert(mailBox, {
                Name = who,
                Subject = subject,
                Check = check,
                DoWho = dowho,
                DoWhat = dowhat,
                When = os.date("%H:%M:%S"),
            })
            table.sort(mailBox, function(a, b)
                if a.Check == b.Check then
                    return a.Name < b.Name
                else
                    return a.Check > b.Check
                end
            end)
        end
        if subject == 'switch' then
            if who == self.CharLoaded then
                mq.cmd("/foreground")
                return
            else
                return
            end
        end
        --New member connected if Hello is true. Lets send them our data so they have it.
        if subject == 'Hello' then
            -- if who ~= Module.CharLoaded then
            if aaActor ~= nil then
                aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, self:GenerateContent(nil, 'Welcome'))
                aaActor:send({ mailbox = 'aa_party', script = 'myui', }, self:GenerateContent(nil, 'Welcome'))
            end
            -- end
            return
            -- checkIn = os.time()
        elseif subject == 'Action' then
            if dowho ~= 'N/A' then
                if MemberEntry.DoWho == self.CharLoaded then
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
                if MemberEntry.DoWho == self.CharLoaded then
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
                            if who ~= self.CharLoaded and AAPartyMode == 'driver' and groupData[i].LastPts < pts then
                                self.Utils.PrintOutput('MyUI', true,
                                    "%s gained an AA, now has %d unspent", who, pts)
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
        groupData = self:SortBoxes(groupData)
        if check == 0 then self:CheckStale() end
    end)
end

function Module:GetMyAA()
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
            PtsSpent ~= tmpPtsSpent or PtsTotal ~= tmpPtsTotal or tmpLvl ~= MeLevel or tmpPctXP ~= PctExp or
            cState ~= LastState or tmpAirSupply ~= lastAirValue) then
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
    if not changed and self:CheckIn() then
        if aaActor ~= nil then
            aaActor:send({ mailbox = 'aa_party', script = 'myui', }, self:GenerateContent(nil, 'CheckIn'))
            aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, self:GenerateContent(nil, 'CheckIn'))

            checkIn = os.time()
        end
    end
    if changed then
        if aaActor ~= nil then
            aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, self:GenerateContent())
            aaActor:send({ mailbox = 'aa_party', script = 'myui', }, self:GenerateContent())
            checkIn = os.time()
            changed = false
        end
    end
end

function Module:SayGoodBye()
    local message = {
        Subject = 'Goodbye',
        Name = self.CharLoaded,
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
        if Module.TempSettings.aSize then
            winFlags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize)
        else
            winFlags = bit32.bor(ImGuiWindowFlags.None)
        end

        if Module.TempSettings.LockWindow then
            winFlags = bit32.bor(winFlags, ImGuiWindowFlags.NoMove)
        else
            winFlags = bit32.bor(winFlags)
        end

        local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(Module.Settings[Module.DisplayName].LoadTheme or 'Default', Module.Theme)
        local openGUI, showGUI = imgui.Begin("AA Party##_" .. Module.CharLoaded, true, winFlags)

        if not openGUI then
            AAPartyShow = false
        end

        if showGUI then
            if #groupData > 0 then
                local windowWidth = imgui.GetWindowWidth() - 4
                local currentX, currentY = imgui.GetCursorPosX(), imgui.GetCursorPosY()
                local itemWidth = 160 -- approximate width
                local padding = 2     -- padding between items
                local drawn = 0
                local tmpLeader = nil
                for i = 1, #groupData do
                    if groupData[i] ~= nil then
                        if not tmpLeader then
                            tmpLeader = groupData[i].GroupLeader
                            if Module.TempSettings.ShowLeader then imgui.SeparatorText("Leader: %s", tmpLeader) end
                        end
                        if (groupData[i].GroupLeader == MyGroupLeader and Module.TempSettings.MyGroupOnly) or not Module.TempSettings.MyGroupOnly then
                            if expand[groupData[i].Name] == nil then expand[groupData[i].Name] = false end
                            if compact[groupData[i].Name] == nil then compact[groupData[i].Name] = false end

                            if currentX + itemWidth > windowWidth then
                                imgui.NewLine()
                                currentY = imgui.GetCursorPosY()
                                currentX = imgui.GetCursorPosX()
                                -- currentY = imgui.GetCursorPosY()
                                ImGui.SetCursorPosY(currentY - 20)
                                if tmpLeader ~= groupData[i].GroupLeader then
                                    tmpLeader = groupData[i].GroupLeader
                                    if Module.TempSettings.ShowLeader then imgui.SeparatorText("Leader: %s", tmpLeader) end
                                end
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
                            imgui.BeginChild(groupData[i].Name, 165, childY, bit32.bor(ImGuiChildFlags.Border, ImGuiChildFlags.AutoResizeY), ImGuiWindowFlags.NoScrollbar)
                            -- Start of grouped Whole Elements
                            ImGui.BeginGroup()
                            -- Start of subgrouped Elements for tooltip
                            imgui.PushID(groupData[i].Name)
                            -- imgui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                            if ImGui.BeginTable('##data', 3, bit32.bor(ImGuiTableFlags.NoBordersInBody)) then
                                local widthMax = ImGui.GetContentRegionAvail()

                                ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.WidthFixed, 95)
                                ImGui.TableSetupColumn("Status", ImGuiTableColumnFlags.WidthFixed, iconSize)
                                ImGui.TableSetupColumn("Pts", ImGuiTableColumnFlags.WidthFixed, 55)
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
                            if ImGui.IsItemHovered() and Module.TempSettings.showTooltip then
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
                                if imgui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsMouseReleased(0) then
                                    if aaActor then
                                        aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, { Name = groupData[i].Name, Subject = 'switch', })
                                        aaActor:send({ mailbox = 'aa_party', script = 'myui', }, { Name = groupData[i].Name, Subject = 'switch', })
                                    end
                                elseif imgui.IsMouseReleased(0) then
                                    expand[groupData[i].Name] = not expand[groupData[i].Name]
                                elseif imgui.IsMouseReleased(1) then
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
                                            aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, Module:GenerateContent(groupData[i].Name, 'Action', 'Less'))
                                            aaActor:send({ mailbox = 'aa_party', script = 'myui', }, Module:GenerateContent(groupData[i].Name, 'Action', 'Less'))
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
                                            aaActor:send({ mailbox = 'aa_party', script = 'myui', }, Module:GenerateContent(groupData[i].Name, 'Action', 'More'))
                                            aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, Module:GenerateContent(groupData[i].Name, 'Action', 'More'))
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
                    Module.TempSettings.aSize = not Module.TempSettings.aSize
                    needSave = true
                end
                if ImGui.MenuItem("Toggle Tooltip##Tooltip_" .. Module.CharLoaded) then
                    Module.TempSettings.showTooltip = not Module.TempSettings.showTooltip
                    needSave = true
                end
                if ImGui.MenuItem("Toggle My Group Only##MyGroup_" .. Module.CharLoaded) then
                    Module.TempSettings.MyGroupOnly = not Module.TempSettings.MyGroupOnly
                    needSave = true
                end
                local lblLeader = Module.TempSettings.ShowLeader and "Hide Leader##HideLeader_" or "Show Leader##ShowLeader_"
                if ImGui.MenuItem(lblLeader) then
                    Module.TempSettings.ShowLeader = not Module.TempSettings.ShowLeader
                    needSave = true
                end
                local lblLock = Module.TempSettings.LockWindow and "Unlock Window##" or "Lock Window##"
                if ImGui.MenuItem(lblLock) then
                    Module.TempSettings.LockWindow = not Module.TempSettings.LockWindow
                    needSave = true
                end
                ImGui.EndPopup()
            end
        end
        Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
        imgui.End()
    end

    if MailBoxShow then
        local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(Module.Settings[Module.DisplayName].LoadTheme or 'Default', Module.Theme)
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
        local ColorCountTheme, StyleCountTheme = Module.ThemeLoader.StartTheme(Module.Settings[Module.DisplayName].LoadTheme or 'Default', Module.Theme)
        local openTheme, showConfig = ImGui.Begin('Config##_', true, bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.AlwaysAutoResize))
        if not openTheme then
            AAPartyConfigShow = false
        end
        if showConfig then
            ImGui.SeparatorText("Theme##")
            ImGui.Text("Cur Theme: %s", Module.TempSettings.themeName)
            -- Combo Box Load Theme
            if ImGui.BeginCombo("Load Theme##", Module.TempSettings.themeName) then
                for k, data in pairs(Module.Theme.Theme) do
                    local isSelected = data.Name == Module.TempSettings.themeName
                    if ImGui.Selectable(data.Name, isSelected) then
                        Module.Settings[Module.DisplayName].LoadTheme = data.Name
                        Module.TempSettings.themeName = Module.Settings[Module.DisplayName].LoadTheme
                        mq.pickle(configFile, Module.Settings)
                    end
                end
                ImGui.EndCombo()
            end

            Module.TempSettings.scale = ImGui.SliderFloat("Scale##DialogDB", Module.TempSettings.scale, 0.5, 2)
            if Module.TempSettings.scale ~= Module.Settings[Module.DisplayName].Scale then
                if Module.TempSettings.scale < 0.5 then Module.TempSettings.scale = 0.5 end
                if Module.TempSettings.scale > 2 then Module.TempSettings.scale = 2 end
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
                Module:LoadTheme()
            end

            MailBoxShow = Module.Utils.DrawToggle("Show MailBox##", MailBoxShow)
            ImGui.SameLine()
            Module.TempSettings.alphaSort = Module.Utils.DrawToggle("Alpha Sort##", Module.TempSettings.alphaSort, ToggleFlags)
            Module.TempSettings.showTooltip = Module.Utils.DrawToggle("Show Tooltip##", Module.TempSettings.showTooltip, ToggleFlags)
            Module.TempSettings.MyGroupOnly = Module.Utils.DrawToggle("My Group Only##", Module.TempSettings.MyGroupOnly, ToggleFlags)
            Module.TempSettings.LockWindow = Module.Utils.DrawToggle("Lock Window##", Module.TempSettings.LockWindow, ToggleFlags)
            Module.TempSettings.ShowLeader = Module.Utils.DrawToggle("Show Leader##", Module.TempSettings.ShowLeader, ToggleFlags)
            if ImGui.Button("Save & Close") then
                Module.Settings = dofile(configFile)
                Module.Settings[Module.DisplayName].Scale = Module.TempSettings.scale
                Module.Settings[Module.DisplayName].AlphaSort = Module.TempSettings.alphaSort
                Module.Settings[Module.DisplayName].LoadTheme = Module.TempSettings.themeName
                Module.Settings[Module.DisplayName].ShowTooltip = Module.TempSettings.showTooltip
                Module.Settings[Module.DisplayName].MyGroupOnly = Module.TempSettings.MyGroupOnly
                Module.Settings[Module.DisplayName].LockWindow = Module.TempSettings.LockWindow
                Module.Settings[Module.DisplayName].ShowLeader = Module.TempSettings.ShowLeader
                mq.pickle(configFile, Module.Settings)
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
function Module.CheckArgs(arg_tbl)
    if #arg_tbl > 0 then
        if arg_tbl[1] == 'driver' then
            AAPartyShow = true
            AAPartyMode = 'driver'
            if arg_tbl[2] ~= nil and arg_tbl[2] == 'mailbox' then
                MailBoxShow = true
            end
            print('\ayAA Party:\ao Setting \atDriver\ax Mode. UI will be displayed.')
            print('\ayAA Party:\ao Type \at/aaparty show\ax. to Toggle the UI')
        elseif arg_tbl[1] == 'client' then
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
    Module:SayGoodBye()
    mq.unbind("/aaparty")
    aaActor = nil
end

function Module.CmdHandler(...)
    local cmdArg = { ..., }
    if #cmdArg > 0 then
        if cmdArg[1] == 'gui' or cmdArg[1] == 'show' or cmdArg[1] == 'open' then
            AAPartyShow = not AAPartyShow
            if AAPartyShow then
                Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Toggling GUI \atOpen\ax.')
            else
                Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Toggling GUI \atClosed\ax.')
            end
        elseif cmdArg[1] == 'exit' or cmdArg[1] == 'quit' then
            Module.IsRunning = false
            Module.Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Exiting.')
            Module:SayGoodBye()
            Module.IsRunning = false
        elseif cmdArg[1] == 'mailbox' then
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

function Module.Init()
    currZone = mq.TLO.Zone.ID()
    lastZone = currZone
    firstRun = true
    if not loadedExeternally then
        Module.CheckArgs(args)
        mq.imgui.init(Module.Name, Module.RenderGUI)
    else
        Module.CheckMode()
    end
    mq.bind('/aaparty', Module.CmdHandler)
    PtsAA = myself.AAPoints()
    Module:LoadSettings()
    Module:GetMyAA()
    Module.IsRunning = true
    if Module.Utils.File.Exists(themezDir) then
        hasThemeZ = true
    end

    if aaActor ~= nil then
        aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, Module:GenerateContent(nil, 'Hello'))
        aaActor:send({ mailbox = 'aa_party', script = 'myui', }, Module:GenerateContent(nil, 'Hello'))
    end
    Module.IsRunning = true
    if not loadedExeternally then
        Module:LocalLoop()
    end
end

local clockTimer = mq.gettime()

function Module.MainLoop()
    if loadedExeternally then
        if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
    end
    local elapsedTime = mq.gettime() - clockTimer
    if elapsedTime >= 2000 then
        currZone = mq.TLO.Zone.ID()
        if currZone ~= lastZone then
            lastZone = currZone
        end
        if aaActor ~= nil then
            Module:GetMyAA()
            Module:CheckStale()
        else
            Module:MessageHandler()
        end

        clockTimer = mq.gettime()
    end
    if needSave then
        Module.Settings[Module.DisplayName].Scale = Module.TempSettings.scale
        Module.Settings[Module.DisplayName].AlphaSort = Module.TempSettings.alphaSort
        Module.Settings[Module.DisplayName].LoadTheme = Module.TempSettings.themeName
        Module.Settings[Module.DisplayName].ShowTooltip = Module.TempSettings.showTooltip
        Module.Settings[Module.DisplayName].MyGroupOnly = Module.TempSettings.MyGroupOnly
        Module.Settings[Module.DisplayName].LockWindow = Module.TempSettings.LockWindow
        Module.Settings[Module.DisplayName].ShowLeader = Module.TempSettings.ShowLeader
        mq.pickle(configFile, Module.Settings)
        needSave = false
    end
end

function Module:LocalLoop()
    while self.IsRunning do
        self.MainLoop()
        mq.delay(50)
    end
end

if mq.TLO.EverQuest.GameState() ~= "INGAME" then
    printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", Module.DisplayName)
    mq.exit()
end

Module:MessageHandler()
Module.Init()
Module.MainLoop()
return Module
