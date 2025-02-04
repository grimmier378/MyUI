--[[
    Title: MyGroup
    Author: Grimmier
    Description: Stupid Simple Group Window
]]

local mq                = require('mq')
local ImGui             = require('ImGui')
local Module            = {}
Module.Name             = 'MyGroup'
Module.ActorMailBox     = 'MyGroup'

Module.IsRunning        = false
---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false

if not loadedExeternally then
    Module.Utils       = require('lib.common')
    Module.Colors      = require('lib.colors')
    Module.Icons       = require('mq.ICONS')
    Module.Actor       = require('lib.actors')
    Module.Mode        = 'driver'
    Module.CharLoaded  = mq.TLO.Me.DisplayName()
    Module.Server      = mq.TLO.MacroQuest.Server()
    Module.ThemeFile   = string.format('%s/MyUI/ThemeZ.lua', mq.configDir)
    Module.Theme       = {}
    Module.ThemeLoader = require('lib.theme_loader')
else
    Module.Utils = MyUI_Utils
    Module.Actor = MyUI_Actor
    Module.Colors = MyUI_Colors
    Module.Icons = MyUI_Icons
    Module.CharLoaded = MyUI_CharLoaded
    Module.Server = MyUI_Server
    Module.Mode = MyUI_Mode
    Module.ThemeFile = MyUI_ThemeFile
    Module.Theme = MyUI_Theme
    Module.ThemeLoader = MyUI_ThemeLoader
    Module.KeypressHandler = MyUI_KeypressHandler
end

local gIcon              = Module.Icons.MD_SETTINGS
local winFlag            = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.MenuBar)
local iconSize           = 15
local mimicMe, followMe  = false, false
local Scale              = 1
local configFile         = string.format("%s/MyUI/MyGroup/%s/%s.lua", mq.configDir, Module.Server:gsub(" ", "_"), Module.CharLoaded)
local lastTar            = mq.TLO.Target.ID() or 0
local themeName          = 'Default'
local locked             = false
local showMana           = true
local showEnd            = true
local firstRun           = true
local showPet            = true
local showGroupWindow    = false
local mouseHover         = false
local defaults, settings = {}, {}
local groupData          = {}
local mailBox            = {}
local useEQBC            = false
local meID               = mq.TLO.Me.ID()
local OpenConfigGUI      = false
local hideTitle          = false
local showSelf           = false
local currZone, lastZone
local mygroupActor       = nil
local showMoveStatus     = true
local tPlayerFlags       = bit32.bor(ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.NoPadInnerX, ImGuiTableFlags.NoPadOuterX, ImGuiTableFlags.Resizable,
    ImGuiTableFlags.SizingFixedFit)

local manaClass          = {
    [1] = 'WIZ',
    [2] = 'MAG',
    [3] = 'NEC',
    [4] = 'ENC',
    [5] = 'DRU',
    [6] = 'SHM',
    [7] = 'CLR',
    [8] = 'BST',
    [9] = 'BRD',
    [10] = 'PAL',
    [11] = 'RNG',
    [12] = 'SHD',
}

defaults                 = {
    [Module.Name] = {
        Scale = 1.0,
        LoadTheme = 'Default',
        locked = false,
        UseEQBC = false,
        WinTransparency = 1.0,
        MouseOver = false,
        ShowSelf = false,
        ShowMana = true,
        ShowEnd = true,
        ShowRoleIcons = true,
        ShowDummy = true,
        ShowPet = true,
        DynamicHP = false,
        DynamicMP = false,
        HideTitleBar = false,
        showMoveStatus = true,
    },
}

local function loadTheme()
    if Module.Utils.File.Exists(Module.ThemeFile) then
        Module.Theme = dofile(Module.ThemeFile)
    else
        Module.Theme = require('defaults.themes')
    end
    themeName = Module.Theme.LoadTheme or themeName
end

---comment Writes settings from the settings table passed to the setting file (full path required)
-- Uses mq.pickle to serialize the table and write to file
---@param file string -- File Name and path
---@param table table -- Table of settings to write
local function writeSettings(file, table)
    mq.pickle(file, table)
end

local function loadSettings()
    local newSetting = false
    if not Module.Utils.File.Exists(configFile) then
        --check for old file and convert to new format
        settings = defaults
        writeSettings(configFile, settings)
        loadSettings()
    else
        -- Load settings from the Lua config file
        settings = dofile(configFile)
    end
    if not loadedExeternally then
        loadTheme()
    end
    newSetting = Module.Utils.CheckDefaultSettings(defaults, settings)
    newSetting = Module.Utils.CheckRemovedSettings(defaults, settings) or newSetting

    showSelf = settings[Module.Name].ShowSelf
    hideTitle = settings[Module.Name].HideTitleBar
    showPet = settings[Module.Name].ShowPet
    showEnd = settings[Module.Name].ShowEnd
    showMana = settings[Module.Name].ShowMana
    useEQBC = settings[Module.Name].UseEQBC
    locked = settings[Module.Name].locked
    Scale = settings[Module.Name].Scale
    themeName = settings[Module.Name].LoadTheme
    showMoveStatus = settings[Module.Name].ShowMoveStatus
    if newSetting then writeSettings(configFile, settings) end
end

local function DrawGroupMember(id)
    local member = mq.TLO.Group.Member(id)
    local memberName = member.Name()
    local r, g, b, a = 1, 1, 1, 1
    if member == 'NULL' then return end

    local hpPct
    local mpPct
    local enPct
    local zne, cls
    local sitting
    local level
    local velo
    if groupData[memberName] ~= nil then
        hpPct = groupData[memberName].CurHP / groupData[memberName].MaxHP * 100
        mpPct = groupData[memberName].CurMana / groupData[memberName].MaxMana * 100
        enPct = groupData[memberName].CurEnd / groupData[memberName].MaxEnd * 100
        zne = groupData[memberName].Zone
        cls = groupData[memberName].Class
        sitting = groupData[memberName].Sitting
        level = groupData[memberName].Level or 0
        velo = groupData[memberName].Velocity or 0
    else
        hpPct = member.PctHPs() or 0
        mpPct = member.PctMana() or 0
        enPct = member.PctEndurance() or 0
        zne = member.Present() and mq.TLO.Zone.Name() or 'Unknown'
        cls = member.Class.ShortName() or 'Unknown'
        sitting = member.Sitting()
        level = member.Level() or 0
        velo = member.Speed() or 0
    end

    function GetInfoToolTip()
        ImGui.TextColored(Module.Colors.color('tangarine'), memberName)
        ImGui.SameLine()
        ImGui.Text("(%s)", level)
        ImGui.Text("Class: %s", cls)
        if groupData[memberName] ~= nil then
            ImGui.TextColored(Module.Colors.color('pink2'), "Health: %d of %d", groupData[memberName].CurHP, groupData[memberName].MaxHP)
            ImGui.TextColored(Module.Colors.color('light blue'), "Mana: %d of %d", groupData[memberName].CurMana, groupData[memberName].MaxMana)
            ImGui.TextColored(Module.Colors.color('yellow'), "End: %d of %d", groupData[memberName].CurEnd, groupData[memberName].MaxEnd)
            if sitting then
                ImGui.TextColored(Module.Colors.color('tangarine'), Module.Icons.FA_MOON_O)
            else
                ImGui.TextColored(Module.Colors.color('green'), Module.Icons.FA_SMILE_O)
                ImGui.SameLine()
                ImGui.TextColored(Module.Colors.color('yellow'), Module.Icons.MD_DIRECTIONS_RUN)
                ImGui.SameLine()
                ImGui.TextColored(Module.Colors.color('teal'), "%0.1f", velo)
            end
            ImGui.TextColored(Module.Colors.color('softblue'), "Zone: %s", zne)
        else
            ImGui.TextColored(Module.Colors.color('pink2'), "Health: %s of 100", hpPct)
            ImGui.TextColored(Module.Colors.color('light blue'), "Mana: %s of 100", mpPct)
            ImGui.TextColored(Module.Colors.color('yellow'), "End: %s of 100", enPct)
            if sitting then
                ImGui.TextColored(Module.Colors.color('tangarine'), Module.Icons.FA_MOON_O)
            else
                ImGui.TextColored(Module.Colors.color('green'), Module.Icons.FA_SMILE_O)
            end
            ImGui.TextColored(Module.Colors.color('softblue'), "Zone: %s", zne)
        end

        if mq.TLO.Group.MainTank.ID() == member.ID() then
            ImGui.SameLine()
            Module.Utils.DrawStatusIcon('A_Tank', 'pwcs', 'Main Tank', iconSize)
        end

        if mq.TLO.Group.MainAssist.ID() == member.ID() then
            ImGui.SameLine()
            Module.Utils.DrawStatusIcon('A_Assist', 'pwcs', 'Main Assist', iconSize)
        end

        if mq.TLO.Group.Puller.ID() == member.ID() then
            ImGui.SameLine()
            Module.Utils.DrawStatusIcon('A_Puller', 'pwcs', 'Puller', iconSize)
        end
    end

    ImGui.BeginGroup()
    local sizeX, sizeY = ImGui.GetContentRegionAvail()
    if ImGui.BeginTable("##playerInfo" .. tostring(id), 4, tPlayerFlags) then
        ImGui.TableSetupColumn("##tName", ImGuiTableColumnFlags.NoResize, (sizeX * .5))
        ImGui.TableSetupColumn("##tVis", ImGuiTableColumnFlags.NoResize, 16)
        ImGui.TableSetupColumn("##tIcons", ImGuiTableColumnFlags.WidthStretch) --*.25)
        ImGui.TableSetupColumn("##tLvl", ImGuiTableColumnFlags.NoResize, 30)
        ImGui.TableNextRow()
        -- Name
        ImGui.TableNextColumn()

        if mq.TLO.Group.Leader.ID() == member.ID() then
            ImGui.TextColored(0, 1, 1, 1, 'F%d', id + 1)
            ImGui.SameLine()
            ImGui.TextColored(0, 1, 1, 1, memberName)
        else
            ImGui.Text('F%d', id + 1)
            ImGui.SameLine()
            ImGui.Text(memberName)
        end
        ImGui.SameLine()
        ImGui.Text(' ')
        if settings[Module.Name].ShowRoleIcons then
            if mq.TLO.Group.MainTank.ID() == member.ID() then
                ImGui.SameLine(0.0, 0)
                Module.Utils.DrawStatusIcon('A_Tank', 'pwcs', 'Main Tank', iconSize)
            end

            if mq.TLO.Group.MainAssist.ID() == member.ID() then
                ImGui.SameLine(0.0, 0)
                Module.Utils.DrawStatusIcon('A_Assist', 'pwcs', 'Main Assist', iconSize)
            end

            if mq.TLO.Group.Puller.ID() == member.ID() then
                ImGui.SameLine(0.0, 0)
                Module.Utils.DrawStatusIcon('A_Puller', 'pwcs', 'Puller', iconSize)
            end

            ImGui.SameLine()
        end
        -- Visiblity

        ImGui.TableNextColumn()
        if member.LineOfSight() then
            ImGui.TextColored(0, 1, 0, .5, Module.Icons.MD_VISIBILITY)
        else
            ImGui.TextColored(0.9, 0, 0, .5, Module.Icons.MD_VISIBILITY_OFF)
        end
        -- Icons

        ImGui.TableNextColumn()
        ImGui.Indent(2)
        local dist = member.Distance() or 9999
        local distColor = Module.Colors.color('green')
        if dist > 200 then
            distColor = Module.Colors.color('red')
        end
        ImGui.BeginGroup()
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
        if showMoveStatus and groupData[memberName] ~= nil then
            local velocity = groupData[memberName].Velocity or 0
            if sitting then
                ImGui.TextColored(Module.Colors.color('tangarine'), Module.Icons.FA_MOON_O)
            else
                if velocity == 0 then
                    ImGui.TextColored(Module.Colors.color('green'), Module.Icons.FA_SMILE_O)
                else
                    -- local cursorScreenPos = ImGui.GetCursorScreenPosVec()
                    -- Module.Utils.DrawArrow(ImVec2(cursorScreenPos.x + 10, cursorScreenPos.y), 0.5, 15, distColor, Module.Utils.getRelativeDirection(dirTo) or 0)
                    ImGui.TextColored(Module.Colors.color('yellow'), Module.Icons.MD_DIRECTIONS_RUN)
                    ImGui.SameLine()
                    ImGui.TextColored(Module.Colors.color('teal'), "%0.0f", velocity)
                end
            end
            ImGui.SameLine()
        end
        ImGui.TextColored(distColor, " %d ", math.floor(dist))
        ImGui.SameLine()
        local cursorScreenPos = ImGui.GetCursorScreenPosVec()
        local dirTo = member.HeadingTo() or '0'
        Module.Utils.DrawArrow(ImVec2(cursorScreenPos.x + 10, cursorScreenPos.y), 5, 15, distColor, Module.Utils.getRelativeDirection(dirTo) or 0)
        cursorScreenPos = ImGui.GetCursorPosVec()
        -- ImGui.SetCursorPos(cursorScreenPos.x + 30, cursorScreenPos.y)
        -- ImGui.TextColored(Module.Colors.color('softblue'), Module.Icons.FA_LOCATION_ARROW)

        ImGui.PopStyleVar()
        ImGui.EndGroup()
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            GetInfoToolTip()
            ImGui.EndTooltip()
        end
        ImGui.Unindent(2)
        -- Lvl
        ImGui.TableNextColumn()
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 2, 0)
        -- if groupData[memberName] == nil then
        --     groupData[memberName] = {
        --         Name = memberName or 'Unknown',
        --         Level = member.Level() or 0,
        --         Class = member.Class.ShortName() or 'Unknown',
        --         CurHP = member.CurrentHPs() or 0,
        --         MaxHP = member.MaxHPs() or 100,
        --         CurMana = member.CurrentMana() or 0,
        --         MaxMana = member.MaxMana() or 100,
        --         CurEnd = member.CurrentEndurance() or 0,
        --         MaxEnd = member.MaxEndurance() or 0,
        --         Sitting = member.Sitting() or false,
        --         Zone = member.Present() and mq.TLO.Zone.Name() or 'Unknown',
        --     }
        -- end

        if sitting then
            ImGui.TextColored(0.911, 0.351, 0.008, 1, "%d", level or 0)
        else
            ImGui.Text("%s", level or 0)
        end
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            GetInfoToolTip()
            ImGui.EndTooltip()
        end
        ImGui.PopStyleVar()
        ImGui.EndTable()
    end

    if ImGui.BeginPopupContextItem("##groupContext" .. tostring(id)) then -- Context menu for the group Roles
        if ImGui.Selectable('Switch To') then
            if useEQBC then
                mq.cmdf("/bct %s //foreground", memberName)
            else
                mq.cmdf("/dex %s /foreground", memberName)
            end
        end
        if ImGui.Selectable('Come to Me') then
            if useEQBC then
                mq.cmdf("/bct %s //nav spawn %s", memberName, Module.CharLoaded)
            else
                mq.cmdf("/dex %s /nav spawn %s", memberName, Module.CharLoaded)
            end
        end
        if ImGui.Selectable('Go To ' .. memberName) then
            mq.cmdf("/nav spawn %s", memberName)
        end
        ImGui.Separator()
        if ImGui.BeginMenu('Roles') then
            if ImGui.Selectable('Main Assist') then
                mq.cmdf("/grouproles set %s 2", memberName)
            end
            if ImGui.Selectable('Main Tank') then
                mq.cmdf("/grouproles set %s 1", memberName)
            end
            if ImGui.Selectable('Puller') then
                mq.cmdf("/grouproles set %s 3", memberName)
            end
            if mq.TLO.Me.GroupLeader() and ImGui.Selectable('Make Leader') then
                mq.cmdf("/makeleader %s", memberName)
            end
            if mq.TLO.Group.Leader.ID() == member.ID() and ImGui.Selectable('Make Me Leader') then
                mq.cmdf("/dex %s /makeleader %s", memberName, Module.CharLoaded)
            end
            ImGui.EndMenu()
        end
        ImGui.EndPopup()
    end
    ImGui.Separator()

    -- Health Bar
    if settings[Module.Name].DynamicHP then
        r = 1
        b = b * (100 - hpPct) / 150
        g = 0.1
        a = 0.9
        if Module.MyZone == zne then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(r, g, b, a))
        else
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('purple')))
        end
    else
        if hpPct <= 0 or hpPct == nil or not (Module.MyZone == groupData[memberName].Zone) then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('purple')))
        elseif hpPct < 15 then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('pink')))
        else
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('red')))
        end
    end
    ImGui.ProgressBar((hpPct / 100), ImGui.GetContentRegionAvail(), 7 * Scale, '##pctHps' .. id)
    ImGui.PopStyleColor()

    if ImGui.IsItemHovered() then
        ImGui.SetTooltip("%s\n%d%% Health", memberName, hpPct)
    end

    --My Mana Bar
    if showMana then
        for i, v in pairs(manaClass) do
            if string.find(cls, v) then
                if settings[Module.Name].DynamicMP then
                    b = 0.9
                    r = 1 * (100 - mpPct) / 200
                    g = 0.9 * mpPct / 100 > 0.1 and 0.9 * mpPct / 100 or 0.1
                    a = 0.5
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(r, g, b, a))
                else
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('light blue2')))
                end
                ImGui.ProgressBar((mpPct / 100), ImGui.GetContentRegionAvail(), 7 * Scale, '##pctMana' .. id)
                ImGui.PopStyleColor()
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("%s\n%d%% Mana", memberName, mpPct)
                end
            end
        end
    end
    if showEnd then
        --My Endurance bar
        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('yellow2')))
        ImGui.ProgressBar((enPct / 100), ImGui.GetContentRegionAvail(), 7 * Scale, '##pctEndurance' .. id)
        ImGui.PopStyleColor()
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("%s\n%d%% Endurance", memberName, enPct)
        end
    end

    ImGui.EndGroup()
    if ImGui.IsItemHovered() and member.Present() then
        Module.Utils.GiveItem(member.ID() or 0)
    end
    -- Pet Health

    if showPet then
        ImGui.BeginGroup()
        if member.Pet() ~= 'NO PET' then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('green2')))
            ImGui.ProgressBar(((tonumber(member.Pet.PctHPs() or 0)) / 100), ImGui.GetContentRegionAvail(), 5 * Scale, '##PetHp' .. id)
            ImGui.PopStyleColor()
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip('%s\n%d%% health', member.Pet.DisplayName(), member.Pet.PctHPs())
                Module.Utils.GiveItem(member.Pet.ID() or 0)
            end
        end
        ImGui.EndGroup()
    end

    ImGui.Separator()
end

local function DrawSelf()
    local mySelf = mq.TLO.Me
    local memberName = mySelf.Name()
    local r, g, b, a = 1, 1, 1, 1
    if mySelf == 'NULL' then return end

    function GetInfoToolTip()
        local pInfoToolTip = (mySelf.Name() ..
            '\t\tlvl: ' .. tostring(mySelf.Level()) ..
            '\nClass: ' .. mySelf.Class.ShortName() ..
            '\nHealth: ' .. tostring(mySelf.CurrentHPs()) .. ' of ' .. tostring(mySelf.MaxHPs()) ..
            '\nMana: ' .. tostring(mySelf.CurrentMana()) .. ' of ' .. tostring(mySelf.MaxMana()) ..
            '\nEnd: ' .. tostring(mySelf.CurrentEndurance()) .. ' of ' .. tostring(mySelf.MaxEndurance()) .. '\n'
        )
        ImGui.Text(pInfoToolTip)
        if mq.TLO.Group.MainAssist.ID() == mySelf.ID() then
            ImGui.SameLine()
            Module.Utils.DrawStatusIcon('A_Assist', 'pwcs', 'Main Assist', iconSize)
        end

        if mq.TLO.Group.Puller.ID() == mySelf.ID() then
            ImGui.SameLine()
            Module.Utils.DrawStatusIcon('A_Puller', 'pwcs', 'Puller', iconSize)
        end

        if mq.TLO.Group.MainTank.ID() == mySelf.ID() then
            ImGui.SameLine()
            Module.Utils.DrawStatusIcon('A_Tank', 'pwcs', 'Main Tank', iconSize)
        end
    end

    local sizeX, sizeY = ImGui.GetContentRegionAvail()
    ImGui.BeginGroup()
    if ImGui.BeginTable("##playerInfoSelf", 4, tPlayerFlags) then
        ImGui.TableSetupColumn("##tName", ImGuiTableColumnFlags.NoResize, (sizeX * .5))
        ImGui.TableSetupColumn("##tVis", ImGuiTableColumnFlags.NoResize, 16)
        ImGui.TableSetupColumn("##tIcons", ImGuiTableColumnFlags.WidthStretch) --ImGui.GetContentRegionAvail()*.25)
        ImGui.TableSetupColumn("##tLvl", ImGuiTableColumnFlags.NoResize, 30)
        ImGui.TableNextRow()
        -- Name
        ImGui.TableNextColumn()

        -- local memberName = member.Name()

        ImGui.Text('F1')
        ImGui.SameLine()
        ImGui.Text(memberName)

        -- Visiblity
        ImGui.TableNextColumn()
        ImGui.TextColored(0, 1, 0, .5, Module.Icons.MD_VISIBILITY)

        -- Icons
        ImGui.TableNextColumn()
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 2, 0)


        ImGui.Text(' ')

        if settings[Module.Name].ShowRoleIcons then
            if mq.TLO.Group.MainTank.ID() == mySelf.ID() then
                ImGui.SameLine()
                Module.Utils.DrawStatusIcon('A_Tank', 'pwcs', 'Main Tank', iconSize)
            end

            if mq.TLO.Group.MainAssist.ID() == mySelf.ID() then
                ImGui.SameLine()
                Module.Utils.DrawStatusIcon('A_Assist', 'pwcs', 'Main Assist', iconSize)
            end

            if mq.TLO.Group.Puller.ID() == mySelf.ID() then
                ImGui.SameLine()
                Module.Utils.DrawStatusIcon('A_Puller', 'pwcs', 'Puller', iconSize)
            end
        end
        ImGui.PopStyleVar()
        -- Lvl
        ImGui.TableNextColumn()
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 2, 0)
        if mySelf.Sitting() then
            ImGui.TextColored(0.911, 0.351, 0.008, 1, "%d", mySelf.Level() or 0)
        else
            ImGui.Text("%s", mySelf.Level() or 0)
        end
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            GetInfoToolTip()
            ImGui.EndTooltip()
        end
        ImGui.PopStyleVar()
        ImGui.EndTable()
    end

    if ImGui.BeginPopupContextItem("##groupContextSelf") then -- Context menu for the group Roles
        if ImGui.BeginMenu('Roles') then
            if ImGui.Selectable('Main Assist') then
                mq.cmdf("/grouproles set %s 2", memberName)
            end
            if ImGui.Selectable('Main Tank') then
                mq.cmdf("/grouproles set %s 1", memberName)
            end
            if ImGui.Selectable('Puller') then
                mq.cmdf("/grouproles set %s 3", memberName)
            end
            if mq.TLO.Me.GroupLeader() and ImGui.Selectable('Group Leader') then
                mq.cmdf("/makeleader %s", memberName)
            end
            ImGui.EndMenu()
        end
        ImGui.EndPopup()
    end
    ImGui.Separator()

    -- Health Bar
    if settings[Module.Name].DynamicHP then
        r = 1
        b = b * (100 - mySelf.PctHPs()) / 150
        g = 0.1
        a = 0.9
        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(r, g, b, a))
    else
        if mySelf.PctHPs() <= 0 or mySelf.PctHPs() == nil then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('purple')))
        elseif mySelf.PctHPs() < 15 then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('pink')))
        else
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('red')))
        end
    end
    ImGui.ProgressBar(((tonumber(mySelf.PctHPs() or 0)) / 100), ImGui.GetContentRegionAvail(), 7 * Scale, '##pctHpsSelf')
    ImGui.PopStyleColor()

    if ImGui.IsItemHovered() then
        ImGui.SetTooltip('%s\n%d%% Health', mySelf.DisplayName(), mySelf.PctHPs())
    end

    --My Mana Bar
    if showMana then
        for i, v in pairs(manaClass) do
            if string.find(mySelf.Class.ShortName(), v) then
                if settings[Module.Name].DynamicMP then
                    b = 0.9
                    r = 1 * (100 - mySelf.PctMana()) / 200
                    g = 0.9 * mySelf.PctMana() / 100 > 0.1 and 0.9 * mySelf.PctMana() / 100 or 0.1
                    a = 0.5
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(r, g, b, a))
                else
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('light blue2')))
                end
                ImGui.ProgressBar(((tonumber(mySelf.PctMana() or 0)) / 100), ImGui.GetContentRegionAvail(), 7 * Scale, '##pctManaSelf')
                ImGui.PopStyleColor()
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip('%s\n%d%% Mana', mySelf.DisplayName(), mySelf.PctMana())
                end
            end
        end
    end
    if showEnd then
        --My Endurance bar
        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('yellow2')))
        ImGui.ProgressBar(((tonumber(mySelf.PctEndurance() or 0)) / 100), ImGui.GetContentRegionAvail(), 7 * Scale, '##pctEnduranceSelf')
        ImGui.PopStyleColor()
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip('%s\n%d%% Endurance', mySelf.DisplayName(), mySelf.PctEndurance())
        end
    end

    -- Pet Health

    if showPet then
        ImGui.BeginGroup()
        if mySelf.Pet() ~= 'NO PET' then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('green2')))
            ImGui.ProgressBar(((tonumber(mySelf.Pet.PctHPs() or 0)) / 100), ImGui.GetContentRegionAvail(), 5 * Scale, '##PetHpSelf')
            ImGui.PopStyleColor()
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip('%s\n%d%% health', mySelf.Pet.DisplayName(), mySelf.Pet.PctHPs())
                if ImGui.IsMouseClicked(0) then
                    mq.cmdf("/target id %s", mySelf.Pet.ID())
                    if mq.TLO.Cursor() then
                        mq.cmdf('/multiline ; /tar id %s; /face; /if (${Cursor.ID}) /click left target', mySelf.Pet.ID())
                    end
                end
            end
        end
        ImGui.EndGroup()
    end
    ImGui.Separator()

    ImGui.EndGroup()
    if ImGui.IsItemHovered() and ImGui.IsMouseReleased(0) then
        mq.cmdf("/target id %s", mySelf.ID())
    end
end

function Module.RenderGUI()
    if not Module.IsRunning then return end

    ------- Main Window --------
    if showGroupWindow then
        if currZone ~= lastZone then return end
        local flags = winFlag
        if locked then
            flags = bit32.bor(flags, ImGuiWindowFlags.NoMove)
        end
        -- Default window size
        ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
        local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(themeName, Module.Theme, settings[Module.Name].MouseOver, mouseHover, settings[Module.Name].WinTransparency)
        local openGUI, showMain = ImGui.Begin("My Group##MyGroup" .. mq.TLO.Me.DisplayName(), true, flags)
        Module.KeypressHandler:handleKeypress()
        if not openGUI then Module.IsRunning = false end
        if showMain then
            mouseHover = ImGui.IsWindowHovered(ImGuiHoveredFlags.ChildWindows)
            if ImGui.BeginMenuBar() then
                local lockedIcon = locked and Module.Icons.FA_LOCK .. '##lockTabButton_MyChat' or
                    Module.Icons.FA_UNLOCK .. '##lockTablButton_MyChat'
                if ImGui.Button(lockedIcon) then
                    --ImGuiWindowFlags.NoMove
                    locked = not locked
                    settings = dofile(configFile)
                    settings[Module.Name].locked = locked
                    writeSettings(configFile, settings)
                end
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("Lock Window")
                end
                if ImGui.Button(gIcon .. '##PlayerTarg') then
                    OpenConfigGUI = not OpenConfigGUI
                end
                ImGui.EndMenuBar()
            end
            ImGui.SetWindowFontScale(Scale)
            -- Player Information
            if showSelf then
                DrawSelf()
            end

            if mq.TLO.Me.GroupSize() > 0 then
                for i = 1, mq.TLO.Me.GroupSize() - 1 do
                    local member = mq.TLO.Group.Member(i)
                    if member ~= 'NULL' then
                        ImGui.BeginGroup()
                        DrawGroupMember(i)
                        ImGui.EndGroup()
                    end
                end
            end

            if settings[Module.Name].ShowDummy then
                if mq.TLO.Me.GroupSize() < 6 then
                    local dummyCount = 6 - mq.TLO.Me.GroupSize()
                    if mq.TLO.Me.GroupSize() == 0 then dummyCount = 5 end
                    for i = 1, dummyCount do
                        ImGui.BeginChild("Dummy##" .. i, -1, 62, bit32.bor(ImGuiChildFlags.Border), ImGuiWindowFlags.NoScrollbar)
                        ImGui.Dummy(ImGui.GetContentRegionAvail(), 75)
                        ImGui.EndChild()
                    end
                end
            end

            ImGui.SeparatorText('Commands')

            local lbl = mq.TLO.Me.Invited() and 'Follow' or 'Invite'
            local sizeX, sizeY = ImGui.GetContentRegionAvail()
            local calcSize = ImGui.CalcTextSize('FOLLOW INVITE ')
            ImGui.SetCursorPosX((sizeX - calcSize) * 0.5)

            if ImGui.SmallButton(lbl) then
                mq.cmdf("/invite %s", mq.TLO.Target.Name())
            end

            if mq.TLO.Me.GroupSize() > 0 then
                ImGui.SameLine()
            end

            if mq.TLO.Me.GroupSize() > 0 then
                if ImGui.SmallButton('Disband') then
                    mq.cmdf("/disband")
                end
            end

            ImGui.Separator()
            calcSize = ImGui.CalcTextSize(' COME FOLLOW MIMIC ')
            ImGui.SetCursorPosX((sizeX - calcSize) * 0.5)
            if ImGui.SmallButton('Come') then
                if useEQBC then
                    mq.cmdf("/bcaa //nav spawn %s", Module.CharLoaded)
                else
                    mq.cmdf("/dgge /nav spawn %s", Module.CharLoaded)
                end
            end

            ImGui.SameLine()

            local tmpFollow = followMe
            if followMe then ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('pink')) end
            if ImGui.SmallButton('Follow') then
                if not followMe then
                    if useEQBC then
                        mq.cmdf("/multiline ; /dcaa //nav stop; /dcaa //afollow spawn %d", meID)
                    else
                        mq.cmdf("/multiline ; /dgge /nav stop; /dgge /afollow spawn %d", meID)
                    end
                else
                    if useEQBC then
                        mq.cmd("/bcaa //afollow off")
                    else
                        mq.cmd("/dgge /afollow off")
                    end
                end
                tmpFollow = not tmpFollow
            end
            if followMe then ImGui.PopStyleColor(1) end
            followMe = tmpFollow

            ImGui.SameLine()
            local tmpMimic = mimicMe
            if mimicMe then ImGui.PushStyleColor(ImGuiCol.Button, Module.Colors.color('pink')) end
            if ImGui.SmallButton('Mimic') then
                if mimicMe then
                    mq.cmd("/groupinfo mimicme off")
                else
                    mq.cmd("/groupinfo mimicme on")
                end
                tmpMimic = not tmpMimic
            end
            if mimicMe then ImGui.PopStyleColor(1) end
            mimicMe = tmpMimic
        end
        Module.ThemeLoader.EndTheme(ColorCount, StyleCount)

        ImGui.SetWindowFontScale(1)

        if not openGUI then
            showGroupWindow = false
        end

        ImGui.End()
    end

    -- Config Window
    if OpenConfigGUI then
        local ColorCountConf, StyleCountConf = Module.ThemeLoader.StartTheme(themeName, Module.Theme)
        local open, configShow = ImGui.Begin("MyGroup Conf", true, bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.AlwaysAutoResize))
        if not open then OpenConfigGUI = false end
        if configShow then
            ImGui.SetWindowFontScale(Scale)
            if ImGui.CollapsingHeader("Theme##" .. Module.Name) then
                ImGui.Text("Cur Theme: %s", themeName)
                -- Combo Box Load Theme
                if ImGui.BeginCombo("Load Theme##MyGroup", themeName) then
                    for k, data in pairs(Module.Theme.Theme) do
                        local isSelected = data.Name == themeName
                        if ImGui.Selectable(data.Name, isSelected) then
                            Module.Theme.LoadTheme = data.Name
                            themeName = Module.Theme.LoadTheme
                            settings[Module.Name].LoadTheme = themeName
                        end
                    end
                    ImGui.EndCombo()
                end

                if ImGui.Button('Reload Theme File') then
                    loadTheme()
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

                settings[Module.Name].MouseOver = ImGui.Checkbox('Mouse Over', settings[Module.Name].MouseOver)
                settings[Module.Name].WinTransparency = ImGui.SliderFloat('Window Transparency##' .. Module.Name, settings[Module.Name].WinTransparency, 0.1, 1.0)
                ImGui.SeparatorText("Scaling##" .. Module.Name)
                -- Slider for adjusting zoom level
                local tmpZoom = Scale
                if Scale then
                    tmpZoom = ImGui.SliderFloat("Zoom Level##MyGroup", tmpZoom, 0.5, 2.0)
                end
                if Scale ~= tmpZoom then
                    Scale = tmpZoom
                    settings[Module.Name].Scale = Scale
                end
            end
            ImGui.SeparatorText("Toggles##" .. Module.Name)
            local tmpComms = useEQBC
            tmpComms = ImGui.Checkbox('Use EQBC##' .. Module.Name, tmpComms)
            if tmpComms ~= useEQBC then
                useEQBC = tmpComms
            end

            local tmpMana = showMana
            tmpMana = ImGui.Checkbox('Mana##' .. Module.Name, tmpMana)
            if tmpMana ~= showMana then
                showMana = tmpMana
            end

            ImGui.SameLine()

            local tmpEnd = showEnd
            tmpEnd = ImGui.Checkbox('Endurance##' .. Module.Name, tmpEnd)
            if tmpEnd ~= showEnd then
                showEnd = tmpEnd
            end

            ImGui.SameLine()

            local tmpPet = showPet
            tmpPet = ImGui.Checkbox('Show Pet##' .. Module.Name, tmpPet)
            if tmpPet ~= showPet then
                showPet = tmpPet
            end
            settings[Module.Name].ShowDummy = ImGui.Checkbox('Show Dummy##' .. Module.Name, settings[Module.Name].ShowDummy)
            ImGui.SameLine()
            settings[Module.Name].ShowRoleIcons = ImGui.Checkbox('Show Role Icons##' .. Module.Name, settings[Module.Name].ShowRoleIcons)
            settings[Module.Name].DynamicHP = ImGui.Checkbox('Dynamic HP##' .. Module.Name, settings[Module.Name].DynamicHP)
            settings[Module.Name].DynamicMP = ImGui.Checkbox('Dynamic MP##' .. Module.Name, settings[Module.Name].DynamicMP)
            hideTitle = ImGui.Checkbox('Hide Title Bar##' .. Module.Name, hideTitle)
            ImGui.SameLine()
            showSelf = ImGui.Checkbox('Show Self##' .. Module.Name, showSelf)

            showMoveStatus = ImGui.Checkbox('Show Move Status##' .. Module.Name, showMoveStatus)

            ImGui.SeparatorText("Save and Close##" .. Module.Name)
            if ImGui.Button('Save and Close##' .. Module.Name) then
                OpenConfigGUI = false
                settings[Module.Name].ShowSelf = showSelf
                settings[Module.Name].HideTitleBar = hideTitle
                settings[Module.Name].ShowMana = showMana
                settings[Module.Name].ShowEnd = showEnd
                settings[Module.Name].ShowPet = showPet
                settings[Module.Name].UseEQBC = useEQBC
                settings[Module.Name].Scale = Scale
                settings[Module.Name].LoadTheme = themeName
                settings[Module.Name].ShowMoveStatus = showMoveStatus
                settings[Module.Name].locked = locked
                writeSettings(configFile, settings)
            end
        end
        Module.ThemeLoader.EndTheme(ColorCountConf, StyleCountConf)
        ImGui.SetWindowFontScale(1)
        ImGui.End()
    end
end

function Module.Unload()
    mq.unbind('/mygroup')
end

-- Actors

local function CheckStale()
    local now = os.time()
    local found = false
    for i = 1, #groupData do
        if groupData[0].Check == nil then
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

local function GenerateContent(sub)
    local Subject = sub or 'Update'
    if firstRun then
        Subject = 'Hello'
        firstRun = false
    end
    return {
        Subject  = Subject,
        Who      = mq.TLO.Me.DisplayName(),
        CurHP    = mq.TLO.Me.CurrentHPs(),
        MaxHP    = mq.TLO.Me.MaxHPs(),
        CurMana  = mq.TLO.Me.CurrentMana(),
        MaxMana  = mq.TLO.Me.MaxMana(),
        CurEnd   = mq.TLO.Me.CurrentEndurance(),
        MaxEnd   = mq.TLO.Me.MaxEndurance(),
        Check    = os.time(),
        Level    = mq.TLO.Me.Level(),
        Class    = mq.TLO.Me.Class.ShortName(),
        Sitting  = mq.TLO.Me.Sitting(),
        Zone     = mq.TLO.Zone.Name(),
        Velocity = mq.TLO.Me.Speed(),
    }
end

local function MessageHandler()
    mygroupActor = Module.Actor.register(Module.ActorMailBox, function(message)
        local MemberEntry = message()
        local subject     = MemberEntry.Subject or 'Update'
        local who         = MemberEntry.Who or 'N/A'
        local curHP       = MemberEntry.CurHP or 0
        local maxHP       = MemberEntry.MaxHP or 0
        local curMana     = MemberEntry.CurMana or 0
        local maxMana     = MemberEntry.MaxMana or 0
        local curEnd      = MemberEntry.CurEnd or 0
        local maxEnd      = MemberEntry.MaxEnd or 0
        local check       = MemberEntry.Check or os.time()
        local zone        = MemberEntry.Zone or 'Unknown'
        local velocity    = MemberEntry.Velocity or 0
        local found       = false
        if MailBoxShow then
            table.insert(mailBox, { Name = who, Subject = subject, CurHP = curHP, MaxHP = maxHP, CurMana = curMana, MaxMana = maxMana, CurEnd = curEnd, MaxEnd = maxEnd, })
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
            if mygroupActor ~= nil then
                mygroupActor:send({ mailbox = Module.ActorMailBox, script = 'mygroup', }, GenerateContent('Welcome'))
                mygroupActor:send({ mailbox = Module.ActorMailBox, script = 'myui', }, GenerateContent('Welcome'))
            end
            -- end
            return
            -- checkIn = os.time()
        elseif subject == 'Goodbye' then
            groupData[who] = nil
        end
        if subject ~= 'Action' then
            -- Process the rest of the message into the groupData table.
            if groupData[who] ~= nil then
                groupData[who].CurHP = curHP
                groupData[who].MaxHP = maxHP
                groupData[who].CurMana = curMana
                groupData[who].MaxMana = maxMana
                groupData[who].CurEnd = curEnd
                groupData[who].MaxEnd = maxEnd
                groupData[who].Check = check
                groupData[who].Name = who
                groupData[who].Level = MemberEntry.Level
                groupData[who].Class = MemberEntry.Class or 'N/A'
                groupData[who].Zone = zone
                groupData[who].Sitting = MemberEntry.Sitting
                groupData[who].Velocity = velocity
            else
                groupData[who] = {
                    Name = who,
                    CurHP = curHP,
                    MaxHP = maxHP,
                    CurMana = curMana,
                    MaxMana = maxMana,
                    CurEnd = curEnd,
                    MaxEnd = maxEnd,
                    Check = check,
                    Level = MemberEntry.Level,
                    Class = MemberEntry.Class or 'N/A',
                    Zone = zone,
                    Sitting = MemberEntry.Sitting,
                    Velocity = velocity,
                }
            end
        end
        if check == 0 then CheckStale() end
    end)
end

local function getMyInfo()
    local mySelf = mq.TLO.Me
    groupData[mySelf.Name()] = {
        Name = mySelf.Name(),
        Level = mySelf.Level() or 0,
        CurHP = mySelf.CurrentHPs() or 0,
        MaxHP = mySelf.MaxHPs() or 0,
        CurMana = mySelf.CurrentMana() or 0,
        MaxMana = mySelf.MaxMana() or 0,
        CurEnd = mySelf.CurrentEndurance() or 0,
        MaxEnd = mySelf.MaxEndurance() or 0,
        Class = mySelf.Class.ShortName() or 'N/A',
        Sitting = mySelf.Sitting() or false,
        ID = mq.TLO.Me.ID() or 0,
        Pet = mq.TLO.Me.Pet() or 0,
        Zone = Module.MyZone,
        Velocity = mq.TLO.Me.Speed() or 0,
    }
    if mygroupActor ~= nil then
        mygroupActor:send({ mailbox = Module.ActorMailBox, script = 'mygroup', }, GenerateContent('Update'))
        mygroupActor:send({ mailbox = Module.ActorMailBox, script = 'myui', }, GenerateContent('Update'))
    end
end

local function ProcessArgs(...)
    local args = { ..., }
    if args[1] == nil then args[1] = 'driver' end
    if arg[1] == 'client' then
        Module.Mode = 'client'
        showGroupWindow = false
    elseif args[1] == 'driver' then
        Module.Mode = 'driver'
        showGroupWindow = true
    end
end

local function CommandHandler(...)
    local args = { ..., }

    if args[1] == 'ui' or args[1] == 'gui' or args[1] == 'show' then
        showGroupWindow = not showGroupWindow
    end
end


local function init()
    loadSettings()
    mq.bind('/mygroup', CommandHandler)
    currZone = mq.TLO.Zone.ID()
    lastZone = currZone
    Module.IsRunning = true
    getMyInfo()
    CheckStale()
    Module.MyZone = mq.TLO.Zone.Name()
    showGroupWindow = Module.Mode == 'driver' and true or false
    if not loadedExeternally then
        mq.imgui.init(Module.Name, Module.RenderGUI)
        Module.LocalLoop()
    end
    if mygroupActor ~= nil then
        mygroupActor:send({ mailbox = Module.ActorMailBox, script = 'mygroup', }, GenerateContent('Hello'))
        mygroupActor:send({ mailbox = Module.ActorMailBox, script = 'myui', }, GenerateContent('Hello'))
    end
end

local clockTimer = mq.gettime()

function Module.MainLoop()
    if loadedExeternally then
        ---@diagnostic disable-next-line: undefined-global
        if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
    end

    meID = mq.TLO.Me.ID()
    if mq.TLO.Window('CharacterListWnd').Open() then return false end
    currZone = mq.TLO.Zone.ID()
    Module.MyZone = mq.TLO.Zone.Name()

    if currZone ~= lastZone then
        mimicMe = false
        followMe = false
        lastZone = currZone
    end

    if hideTitle then
        winFlag = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.MenuBar)
    else
        winFlag = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.MenuBar)
    end

    if mimicMe and lastTar ~= mq.TLO.Target.ID() then
        lastTar = mq.TLO.Target.ID()
        mq.cmdf("/dgge /target id %s", mq.TLO.Target.ID())
    end

    getMyInfo()

    if mygroupActor ~= nil then
        CheckStale()
    else
        MessageHandler()
    end
end

function Module.LocalLoop()
    while Module.IsRunning do
        Module.MainLoop()
        mq.delay(1)
    end
    mq.unbind('/mygroup')
end

if mq.TLO.EverQuest.GameState() ~= "INGAME" then
    printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", Module.Name)
    mq.unbind('/mygroup')

    mq.exit()
end
-- ProcessArgs(...)
MessageHandler()
init()
return Module
