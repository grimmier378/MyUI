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
    Module.Actor       = require('actors')
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
end
local Utils              = Module.Utils
local ToggleFlags        = bit32.bor(
    Utils.ImGuiToggleFlags.PulseOnHover,
    --Utils.ImGuiToggleFlags.SmilyKnob,
    Utils.ImGuiToggleFlags.GlowOnHover,
    Utils.ImGuiToggleFlags.KnobBorder,
    --Utils.ImGuiToggleFlags.StarKnob,
    Utils.ImGuiToggleFlags.AnimateOnHover,
    Utils.ImGuiToggleFlags.RightLabel)
local gIcon              = Module.Icons.MD_SETTINGS
local winFlag            = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.MenuBar)
local iconSize           = 15
local mimicMe, followMe  = false, false
local Scale              = 1
local RaidScale          = 1
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
local raidKeys           = {}
local raidLootIdx        = 0
local useEQBC            = false
local meID               = mq.TLO.Me.ID()
local OpenConfigGUI      = false
local hideTitle          = false
local showSelf           = false
local showRaidWindow     = false
local currZone, lastZone
local mygroupActor       = nil
local showMoveStatus     = true
local navDist            = 10
local raidSize           = mq.TLO.Raid.Members() or 0
local raidLeader         = mq.TLO.Raid.Leader() or 'N/A'
local tPlayerFlags       = bit32.bor(ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.NoPadInnerX, ImGuiTableFlags.NoPadOuterX, ImGuiTableFlags.Resizable,
    ImGuiTableFlags.SizingFixedFit)
local lastRaidSort       = os.clock()

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
        RaidScale = 1.0,
        LoadTheme = 'Default',
        locked = false,
        UseEQBC = false,
        WinTransparency = 1.0,
        MouseOver = false,
        ShowSelf = false,
        ShowMana = true,
        ShowEnd = true,
        ShowRoleIcons = true,
        ShowRaidWindow = false,
        ShowDummy = true,
        ShowPet = true,
        DynamicHP = false,
        DynamicMP = false,
        HideTitleBar = false,
        ShowMoveStatus = true,
        NavDist = 10,
        ShowLevel = true,
        ShowValOnBar = false,
    },
}

local function sortRaidByGroup()
    local tmpKeys = {}
    for grp = 1, 10 do
        for i = 1, raidSize do
            local member = mq.TLO.Raid.Member(i)
            if member ~= 'NULL' then
                if member.Group() == grp then
                    table.insert(tmpKeys, { name = member.Name(), slot = i, })
                end
            end
        end
    end
    raidKeys = tmpKeys
end

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
    newSetting = Module.Utils.CheckDefaultSettings(defaults[Module.Name], settings[Module.Name])
    newSetting = Module.Utils.CheckRemovedSettings(defaults[Module.Name], settings[Module.Name]) or newSetting

    showRaidWindow = settings[Module.Name].ShowRaidWindow
    showSelf = settings[Module.Name].ShowSelf
    hideTitle = settings[Module.Name].HideTitleBar
    showPet = settings[Module.Name].ShowPet
    showEnd = settings[Module.Name].ShowEnd
    showMana = settings[Module.Name].ShowMana
    useEQBC = settings[Module.Name].UseEQBC
    locked = settings[Module.Name].locked
    Scale = settings[Module.Name].Scale
    RaidScale = settings[Module.Name].RaidScale
    themeName = settings[Module.Name].LoadTheme
    navDist = settings[Module.Name].NavDist ~= nil and settings[Module.Name].NavDist or 20
    showMoveStatus = settings[Module.Name].ShowMoveStatus
    if newSetting then writeSettings(configFile, settings) end
end

local function GetInfoToolTip(id, raid)
    if id == nil then return end
    local member
    if raid then
        member = mq.TLO.Raid.Member(id)
    else
        member = mq.TLO.Group.Member(id)
    end
    if member == nil then return end
    if member.Name() == nil then return end
    local memberName = member.Name() or "NO"
    local r, g, b, a = 1, 1, 1, 1
    if member == 'NULL' then return end
    if groupData[memberName] ~= nil then
        ImGui.TextColored(Module.Colors.color('tangarine'), memberName)
        ImGui.SameLine()
        ImGui.Text("(%s)", groupData[memberName].Level)
        ImGui.Text("Class: %s", groupData[memberName].Class)
        ImGui.TextColored(Module.Colors.color('pink2'), "Health: %d of %d", groupData[memberName].CurHP, groupData[memberName].MaxHP)
        ImGui.TextColored(Module.Colors.color('light blue'), "Mana: %d of %d", groupData[memberName].CurMana, groupData[memberName].MaxMana)
        ImGui.TextColored(Module.Colors.color('yellow'), "End: %d of %d", groupData[memberName].CurEnd, groupData[memberName].MaxEnd)
        if groupData[memberName].Sitting then
            ImGui.TextColored(Module.Colors.color('tangarine'), Module.Icons.FA_MOON_O)
        else
            ImGui.TextColored(Module.Colors.color('green'), Module.Icons.FA_SMILE_O)
            ImGui.SameLine()
            ImGui.TextColored(Module.Colors.color('yellow'), Module.Icons.MD_DIRECTIONS_RUN)
            ImGui.SameLine()
            ImGui.TextColored(Module.Colors.color('teal'), "%0.1f", groupData[memberName].Velocity)
        end
        ImGui.TextColored(Module.Colors.color('green'), "Distance: %0.1f", member.Distance() or 9999)
        ImGui.TextColored(Module.Colors.color('softblue'), "Zone: %s", groupData[memberName].Zone)
    else
        ImGui.TextColored(Module.Colors.color('tangarine'), memberName)
        ImGui.SameLine()
        ImGui.Text("Level: %d", member.Level())
        ImGui.Text("Class: %s", member.Class.ShortName())
        if member.PctHPs() ~= nil then
            ImGui.TextColored(Module.Colors.color('pink2'), "Health: %d of 100", member.PctHPs())
        end
        if member.PctMana() ~= nil then
            ImGui.TextColored(Module.Colors.color('light blue'), "Mana: %d of 100", member.PctMana())
        end
        if member.PctEndurance() ~= nil then
            ImGui.TextColored(Module.Colors.color('yellow'), "End: %d of 100", member.PctEndurance())
        end
        if member.Sitting() then
            ImGui.TextColored(Module.Colors.color('tangarine'), Module.Icons.FA_MOON_O)
        else
            ImGui.TextColored(Module.Colors.color('green'), Module.Icons.FA_SMILE_O)
        end
        ImGui.TextColored(Module.Colors.color('green'), "Distance: %0.1f", member.Distance() or 9999)
        ImGui.TextColored(Module.Colors.color('softblue'), "Zone: %s", mq.TLO.Zone.Name())
    end

    local entry = false
    if mq.TLO.Group.MainTank.ID() == member.ID() then
        if entry then ImGui.SameLine() end
        Module.Utils.DrawStatusIcon('A_Tank', 'pwcs', 'Main Tank', iconSize)
        entry = true
    end

    if mq.TLO.Group.MainAssist.ID() == member.ID() then
        if entry then ImGui.SameLine() end
        Module.Utils.DrawStatusIcon('A_Assist', 'pwcs', 'Main Assist', iconSize)
        entry = true
    end

    if mq.TLO.Group.Puller.ID() == member.ID() then
        if entry then ImGui.SameLine() end
        Module.Utils.DrawStatusIcon('A_Puller', 'pwcs', 'Puller', iconSize)
        entry = true
    end
end

local function DrawGroupMember(id)
    local barSize = settings[Module.Name].ShowValOnBar and 12 or 7
    local member = mq.TLO.Group.Member(id)
    local r, g, b, a = 1, 1, 1, 1
    if member == 'NULL' then return end
    local memberName = member.Name()

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
    ImGui.PushID(memberName)
    ImGui.BeginGroup()
    local colCount = settings[Module.Name].ShowLevel and 4 or 3
    local sizeX, sizeY = ImGui.GetContentRegionAvail()
    if ImGui.BeginTable("##playerInfo" .. tostring(id), colCount, tPlayerFlags) then
        ImGui.TableSetupColumn("##tName", ImGuiTableColumnFlags.NoResize, (sizeX * .5))
        ImGui.TableSetupColumn("##tVis", ImGuiTableColumnFlags.NoResize, 16)
        ImGui.TableSetupColumn("##tIcons", ImGuiTableColumnFlags.WidthStretch) --*.25)
        if settings[Module.Name].ShowLevel then
            ImGui.TableSetupColumn("##tLvl", ImGuiTableColumnFlags.NoResize, 30)
        end
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

                    ImGui.TextColored(Module.Colors.color('teal'), "%0.0f", velocity)
                    ImGui.SameLine()
                    ImGui.TextColored(Module.Colors.color('yellow'), Module.Icons.MD_DIRECTIONS_RUN)
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
        ImGui.Unindent(2)
        if settings[Module.Name].ShowLevel then
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
            ImGui.PopStyleVar()
        end
        ImGui.EndTable()
    end

    -- Module.DrawContext(member)

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
        if (groupData[memberName] ~= nil) then
            if hpPct == nil or hpPct <= 0 or not (Module.MyZone == groupData[memberName].Zone) then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('purple')))
            elseif hpPct < 15 then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('pink')))
            else
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('red')))
            end
        else
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('red')))
        end
    end
    local cursorX, cursorY = ImGui.GetCursorPos()
    ImGui.ProgressBar((hpPct / 100), ImGui.GetContentRegionAvail(), barSize * Scale, '##pctHps' .. id)
    if settings[Module.Name].ShowValOnBar then
        ImGui.SetCursorPos(cursorX + 2, cursorY)

        local txtLabel = groupData[memberName] ~= nil and
            string.format("%d / %d", groupData[memberName].CurHP, groupData[memberName].MaxHP) or
            string.format("%d%%", hpPct)

        ImGui.SetCursorPos(ImGui.GetWindowContentRegionWidth() * 0.5 - (ImGui.CalcTextSize(txtLabel) * 0.5), cursorY - 2)

        ImGui.Text(txtLabel)
    end
    ImGui.PopStyleColor()


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
                cursorX, cursorY = ImGui.GetCursorPos()
                ImGui.ProgressBar((mpPct / 100), ImGui.GetContentRegionAvail(), barSize * Scale, '##pctMana' .. id)
                ImGui.PopStyleColor()
                if settings[Module.Name].ShowValOnBar then
                    ImGui.SetCursorPos(cursorX + 2, cursorY)

                    local txtLabel = groupData[memberName] ~= nil and
                        string.format("%d / %d", groupData[memberName].CurMana, groupData[memberName].MaxMana) or
                        string.format("%d%%", mpPct)

                    ImGui.SetCursorPos(ImGui.GetWindowContentRegionWidth() * 0.5 - (ImGui.CalcTextSize(txtLabel) * 0.5), cursorY - 2)

                    ImGui.Text(txtLabel)
                end
            end
        end
    end
    if showEnd then
        --My Endurance bar
        cursorX, cursorY = ImGui.GetCursorPos()
        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('yellow2')))
        ImGui.ProgressBar((enPct / 100), ImGui.GetContentRegionAvail(), barSize * Scale, '##pctEndurance' .. id)
        ImGui.PopStyleColor()
        if settings[Module.Name].ShowValOnBar then
            local txtLabel = groupData[memberName] ~= nil and string.format("%d / %d", groupData[memberName].CurEnd, groupData[memberName].MaxEnd) or string.format("%d%%", enPct)
            ImGui.SetCursorPos(ImGui.GetWindowContentRegionWidth() * 0.5 - (ImGui.CalcTextSize(txtLabel) * 0.5), cursorY - 2)

            ImGui.Text(txtLabel)
        end
    end

    ImGui.EndGroup()
    Module.DrawContext(member)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        GetInfoToolTip(id)
        ImGui.EndTooltip()

        if ImGui.IsItemHovered() and ImGui.IsMouseReleased(0) and ImGui.IsKeyDown(ImGuiMod.Ctrl) then
            mq.cmdf("/dex %s /foreground", member.Name())
        end
        if member.Present() and ImGui.IsMouseReleased(0) then
            mq.cmdf("/target id %s", member.ID())

            Module.Utils.GiveItem(member.ID() or 0)
        end
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
                if ImGui.IsMouseReleased(0) then
                    Module.Utils.GiveItem(member.Pet.ID() or 0)
                end
            end
        end
        ImGui.EndGroup()
    end
    ImGui.PopID()
    ImGui.Separator()
end

function Module.DrawContext(member)
    if member == nil then return end
    local memberName = member.Name()
    ImGui.PushID(member.ID())
    if ImGui.BeginPopupContextItem("##groupContext" .. tostring(member.ID())) then -- Context menu for the group Roles
        if ImGui.Selectable('Switch To') then
            if useEQBC then
                mq.cmdf("/bct %s //foreground", memberName)
            else
                mq.cmdf("/dex %s /foreground", memberName)
            end
        end
        if ImGui.Selectable('Come to Me') then
            if useEQBC then
                mq.cmdf("/bct %s //nav id \"%s\" dist=%d lineofsight=on", memberName, mq.TLO.Me.ID(), navDist)
            else
                mq.cmdf("/dex %s /nav id \"%s\" dist=%d lineofsight=on", memberName, mq.TLO.Me.ID(), navDist)
            end
        end
        if ImGui.Selectable('Go To ' .. memberName) then
            mq.cmdf("/nav id %s dist=%d lineofsight=on", member.ID() or 0, navDist)
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
    ImGui.PopID()
end

local function DrawRaidMember(id)
    local member = mq.TLO.Raid.Member(id)
    local memberName = member.Name()
    local r, g, b, a = 1, 1, 1, 1
    if member == 'NULL' then return end
    local memberDistance = member.Distance() or 9999
    local hpPct = 0
    local mpPct = 0
    local enPct = 0
    local cls
    local sitting
    local level
    local velo
    if groupData[memberName] ~= nil then
        hpPct = (groupData[memberName].CurHP / groupData[memberName].MaxHP * 100) or 0
        mpPct = groupData[memberName].CurMana / groupData[memberName].MaxMana * 100
        enPct = groupData[memberName].CurEnd / groupData[memberName].MaxEnd * 100
        cls = groupData[memberName].Class
        sitting = groupData[memberName].Sitting
        level = groupData[memberName].Level or 0
        velo = groupData[memberName].Velocity or 0
    else
        hpPct = member.PctHPs() or 0
        mpPct = member.PctMana() or 0
        enPct = member.PctEndurance() or 0
        cls = member.Class.ShortName() or 'Unknown'
        sitting = member.Sitting()
        level = member.Level() or 0
        velo = member.Speed() or 0
    end

    ImGui.BeginChild("##RaidMember" .. tostring(id), 0.0, (90 * RaidScale), bit32.bor(ImGuiChildFlags.Border), ImGuiWindowFlags.NoScrollbar)
    ImGui.BeginGroup()
    local sizeX, sizeY = ImGui.GetContentRegionAvail()
    if ImGui.BeginTable("##playerInfo" .. tostring(id), 3, tPlayerFlags) then
        ImGui.TableSetupColumn("##tName", ImGuiTableColumnFlags.NoResize, (sizeX * .5))
        ImGui.TableSetupColumn("##tVis", ImGuiTableColumnFlags.NoResize, 16)
        ImGui.TableSetupColumn("##tIcons", ImGuiTableColumnFlags.WidthStretch) --*.25)
        ImGui.TableNextRow()
        -- Name
        ImGui.TableNextColumn()
        if settings[Module.Name].ShowLevel then
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 2, 0)

            if sitting then
                ImGui.TextColored(0.911, 0.351, 0.008, 1, "%d", level or 0)
            else
                ImGui.Text("%s", level or 0)
            end
            ImGui.PopStyleVar()
            ImGui.SameLine()
        end
        if mq.TLO.Raid.Leader.ID() == member.ID() then
            ImGui.TextColored(0, 1, 1, 1, memberName)
        else
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
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            GetInfoToolTip(id, true)
            ImGui.EndTooltip()
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
        local distColor = Module.Colors.color('green')
        if memberDistance > 200 then
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

                    ImGui.TextColored(Module.Colors.color('teal'), "%0.0f", velocity)
                    ImGui.SameLine()
                    ImGui.TextColored(Module.Colors.color('yellow'), Module.Icons.MD_DIRECTIONS_RUN)
                end
            end
            ImGui.SameLine()
        end
        ImGui.TextColored(distColor, " %d ", math.floor(memberDistance))
        ImGui.SameLine()
        local cursorScreenPos = ImGui.GetCursorScreenPosVec()
        local dirTo = member.HeadingTo() or '0'
        Module.Utils.DrawArrow(ImVec2(cursorScreenPos.x + 10, cursorScreenPos.y), 5, 15, distColor, Module.Utils.getRelativeDirection(dirTo) or 0)
        cursorScreenPos = ImGui.GetCursorPosVec()
        -- ImGui.SetCursorPos(cursorScreenPos.x + 30, cursorScreenPos.y)
        -- ImGui.TextColored(Module.Colors.color('softblue'), Module.Icons.FA_LOCATION_ARROW)

        ImGui.PopStyleVar()
        ImGui.EndGroup()

        ImGui.Unindent(2)
        -- Lvl

        ImGui.EndTable()
    end
    -- Module.DrawContext(member)

    ImGui.Separator()

    -- Health Bar
    if settings[Module.Name].DynamicHP then
        r = 1
        b = b * (100 - hpPct) / 150
        g = 0.1
        a = 0.9
        if mq.TLO.SpawnCount(string.format("PC =\"%s\"", memberName))() > 0 then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(r, g, b, a))
        else
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('purple')))
        end
    else
        local tmpCheck = groupData[memberName] ~= nil and groupData[memberName].Zone or 'Unknown'
        if tmpCheck == 'Unknown' then
            if mq.TLO.SpawnCount(string.format("name =%s", memberName))() > 0 then
                tmpCheck = mq.TLO.Zone.Name()
            end
        end
        if hpPct <= 0 or hpPct == nil or not (Module.MyZone == tmpCheck) then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('purple')))
        elseif hpPct < 15 then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('pink')))
        else
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('red')))
        end
    end
    ImGui.ProgressBar((hpPct / 100), ImGui.GetContentRegionAvail(), 7 * RaidScale, '##pctHps' .. id)
    ImGui.PopStyleColor()

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
                ImGui.ProgressBar((mpPct / 100), ImGui.GetContentRegionAvail(), 7 * RaidScale, '##pctMana' .. id)
                ImGui.PopStyleColor()
            end
        end
    end
    if showEnd then
        --My Endurance bar
        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('yellow2')))
        ImGui.ProgressBar((enPct / 100), ImGui.GetContentRegionAvail(), 7 * RaidScale, '##pctEndurance' .. id)
        ImGui.PopStyleColor()
    end

    ImGui.EndGroup()
    if ImGui.IsItemHovered() then
        if ImGui.IsItemHovered() and ImGui.IsMouseReleased(0) and ImGui.IsKeyDown(ImGuiMod.Ctrl) then
            mq.cmdf("/dex %s /foreground", member.Name())
        elseif ImGui.IsItemHovered() and ImGui.IsMouseReleased(0) then
            mq.cmdf("/target %s", member.Name())
            Module.Utils.GiveItem(member.ID() or 0)
        end
        ImGui.BeginTooltip()
        GetInfoToolTip(id, true)
        ImGui.EndTooltip()
    end
    Module.DrawContext(member)

    -- Pet Health

    if showPet then
        ImGui.BeginGroup()
        if member.Pet() ~= 'NO PET' then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('green2')))
            ImGui.ProgressBar(((tonumber(member.Pet.PctHPs() or 0)) / 100), ImGui.GetContentRegionAvail(), 5 * RaidScale, '##PetHp' .. id)
            ImGui.PopStyleColor()
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip('%s\n%d%% health', member.Pet.DisplayName(), member.Pet.PctHPs())
                if ImGui.IsMouseReleased(0) then
                    Module.Utils.GiveItem(member.Pet.ID() or 0)
                end
            end
        end
        ImGui.EndGroup()
    end
    ImGui.EndChild()
end

local function DrawSelf()
    local mySelf = mq.TLO.Me
    local memberName = mySelf.Name()
    local r, g, b, a = 1, 1, 1, 1
    if mySelf == 'NULL' then return end
    local barSize = settings[Module.Name].ShowValOnBar and 12 or 7
    local sizeX, sizeY = ImGui.GetContentRegionAvail()
    ImGui.BeginGroup()
    local colCount = settings[Module.Name].ShowLevel and 4 or 3
    if ImGui.BeginTable("##playerInfoSelf", colCount, tPlayerFlags) then
        ImGui.TableSetupColumn("##tName", ImGuiTableColumnFlags.NoResize, (sizeX * .5))
        ImGui.TableSetupColumn("##tVis", ImGuiTableColumnFlags.NoResize, 16)
        ImGui.TableSetupColumn("##tIcons", ImGuiTableColumnFlags.WidthStretch) --ImGui.GetContentRegionAvail()*.25)
        if colCount == 4 then
            ImGui.TableSetupColumn("##tLvl", ImGuiTableColumnFlags.NoResize, 30)
        end
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
        if colCount == 4 then
            ImGui.TableNextColumn()
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 2, 0)
            if mySelf.Sitting() then
                ImGui.TextColored(0.911, 0.351, 0.008, 1, "%d", mySelf.Level() or 0)
            else
                ImGui.Text("%s", mySelf.Level() or 0)
            end
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                GetInfoToolTip(0, false)
                ImGui.EndTooltip()
            end
            ImGui.PopStyleVar()
        end
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
    local cursorX, cursorY = ImGui.GetCursorPos()
    ImGui.ProgressBar(((tonumber(mySelf.PctHPs() or 0)) / 100), ImGui.GetContentRegionAvail(), barSize * Scale, '##pctHpsSelf')
    ImGui.PopStyleColor()
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        GetInfoToolTip(0, false)
        ImGui.EndTooltip()
    end
    if settings[Module.Name].ShowValOnBar then
        ImGui.SetCursorPos(cursorX + 2, cursorY)

        local txtLabel = string.format("%d / %d", mySelf.CurrentHPs(), mySelf.MaxHPs())

        ImGui.SetCursorPos(ImGui.GetWindowContentRegionWidth() * 0.5 - (ImGui.CalcTextSize(txtLabel) * 0.5), cursorY - 2)

        ImGui.Text(txtLabel)
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
                cursorX, cursorY = ImGui.GetCursorPos()
                ImGui.ProgressBar(((tonumber(mySelf.PctMana() or 0)) / 100), ImGui.GetContentRegionAvail(), barSize * Scale, '##pctManaSelf')
                ImGui.PopStyleColor()
                if ImGui.IsItemHovered() then
                    ImGui.BeginTooltip()
                    GetInfoToolTip(0, false)
                    ImGui.EndTooltip()
                end
                if settings[Module.Name].ShowValOnBar then
                    ImGui.SetCursorPos(cursorX + 2, cursorY)

                    local txtLabel = string.format("%d / %d", mySelf.CurrentMana(), mySelf.MaxMana())

                    ImGui.SetCursorPos(ImGui.GetWindowContentRegionWidth() * 0.5 - (ImGui.CalcTextSize(txtLabel) * 0.5), cursorY - 2)

                    ImGui.Text(txtLabel)
                end
            end
        end
    end
    if showEnd then
        --My Endurance bar
        cursorX, cursorY = ImGui.GetCursorPos()
        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('yellow2')))
        ImGui.ProgressBar(((tonumber(mySelf.PctEndurance() or 0)) / 100), ImGui.GetContentRegionAvail(), barSize * Scale, '##pctEnduranceSelf')
        ImGui.PopStyleColor()
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            GetInfoToolTip(0, false)
            ImGui.EndTooltip()
        end
        if settings[Module.Name].ShowValOnBar then
            local txtLabel = string.format("%d / %d", mySelf.CurrentEndurance(), mySelf.MaxEndurance())

            ImGui.SetCursorPos(ImGui.GetWindowContentRegionWidth() * 0.5 - (ImGui.CalcTextSize(txtLabel) * 0.5), cursorY - 2)

            ImGui.Text(txtLabel)
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
                if ImGui.IsMouseReleased(0) then
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
    local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(themeName, Module.Theme, settings[Module.Name].MouseOver, mouseHover, settings[Module.Name].WinTransparency)

    ------- Main Window --------
    if showGroupWindow then
        if currZone ~= lastZone then return end
        local flags = winFlag
        if locked then
            flags = bit32.bor(flags, ImGuiWindowFlags.NoMove)
        end
        -- Default window size
        ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
        local openGUI, showMain = ImGui.Begin("My Group##MyGroup" .. mq.TLO.Me.DisplayName(), true, flags)

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
                if ImGui.SmallButton('Disband') then
                    mq.cmdf("/disband")
                end
            end

            ImGui.Separator()
            calcSize = ImGui.CalcTextSize(' COME FOLLOW MIMIC ')
            ImGui.SetCursorPosX((sizeX - calcSize) * 0.5)
            if ImGui.SmallButton('Come') then
                if useEQBC then
                    mq.cmdf("/bcaa //nav id %s dist=%d lineofsight=on", mq.TLO.Me.ID(), navDist)
                else
                    mq.cmdf("/dgge /nav id %s dist=%d lineofsight=on", mq.TLO.Me.ID(), navDist)
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

        ImGui.SetWindowFontScale(1)

        if not openGUI then
            showGroupWindow = false
        end

        ImGui.End()
    end



    if showRaidWindow and raidSize > 0 then
        if currZone ~= lastZone then return end
        local flags = winFlag
        if locked then
            flags = bit32.bor(flags, ImGuiWindowFlags.NoMove)
        end
        -- Default window size
        ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
        local openGUI, showMain = ImGui.Begin("My Raid##MyGroup" .. mq.TLO.Me.DisplayName(), true, flags)

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

            if raidSize > 0 then
                local col = math.floor(raidSize / 6) > 0 and math.floor(raidSize / 6) or 1
                if ImGui.BeginTable("Raid", col) then
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn()
                    local cnt = 1
                    for k, v in ipairs(raidKeys) do
                        local member = mq.TLO.Raid.Member(v.slot)
                        if cnt == 7 then
                            ImGui.TableNextColumn()
                            cnt = 1
                        end
                        if member ~= 'NULL' then
                            ImGui.BeginGroup()
                            DrawRaidMember(v.slot)
                            ImGui.EndGroup()
                        end
                        cnt = cnt + 1
                    end
                    ImGui.EndTable()
                end
            end

            ImGui.SeparatorText('Commands')

            local lbl = mq.TLO.Me.Invited() and 'Follow' or 'Invite'
            local sizeX, sizeY = ImGui.GetContentRegionAvail()
            local calcSize = ImGui.CalcTextSize('FOLLOW INVITE ')
            ImGui.SetCursorPosX((sizeX - calcSize) * 0.5)

            if ImGui.SmallButton(lbl) then
                mq.cmdf("/raidinvite %s", mq.TLO.Target.Name())
            end

            if mq.TLO.Me.GroupSize() > 0 then
                ImGui.SameLine()
            end

            if mq.TLO.Me.GroupSize() > 0 then
                if ImGui.SmallButton('Disband') then
                    mq.cmdf("/raiddisband")
                end
            end

            ImGui.Separator()
            ImGui.Spacing()
            calcSize = ImGui.CalcTextSize(' COME FOLLOW ')
            ImGui.SetCursorPosX((sizeX - calcSize) * 0.5)
            if ImGui.SmallButton('Come') then
                if useEQBC then
                    mq.cmdf("/bcaa //nav id %s dist=%d lineofsight=on", mq.TLO.Me.ID(), navDist)
                else
                    mq.cmdf("/dgre /nav id %s dist=%d lineofsight=on", mq.TLO.Me.ID(), navDist)
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
                        mq.cmdf("/multiline ; /dgre /nav stop; /dgze /afollow spawn %d", meID)
                    end
                else
                    if useEQBC then
                        mq.cmd("/bcaa //afollow off")
                    else
                        mq.cmd("/dgre /afollow off")
                    end
                end
                tmpFollow = not tmpFollow
            end
            if followMe then ImGui.PopStyleColor(1) end
            followMe = tmpFollow

            if raidLeader == Module.CharLoaded then
                ImGui.SeparatorText('Raid Loot Settings')
                if raidLootIdx == 0 then
                    raidLootIdx = tonumber(mq.TLO.Window('RaidOptionsWindow/RAIDOPTIONS_CurrentLootType').Text()) or 1
                end
                ImGui.SetCursorPosX(sizeX * 0.5 - 50)
                local raidLoot = { 'Raid Leader', 'Leaders Only', 'Leader Selected', 'Everyone', }
                ImGui.SetNextItemWidth(100)
                if ImGui.BeginCombo('Loot##MyGroup', raidLoot[raidLootIdx]) then
                    for i, loot in ipairs(raidLoot) do
                        local isSelected = raidLootIdx == i
                        if ImGui.Selectable(loot, isSelected) then
                            if raidLootIdx ~= i then
                                mq.cmdf("/Setloottype %d", i)
                                raidLootIdx = i
                            end
                        end
                    end
                    ImGui.EndCombo()
                end
            end
        end

        ImGui.SetWindowFontScale(1)

        if not openGUI then
            showRaidWindow = false
        end

        ImGui.End()
    end

    -- Config Window
    if OpenConfigGUI then
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

                settings[Module.Name].MouseOver = Module.Utils.DrawToggle('Mouse Over', settings[Module.Name].MouseOver, ToggleFlags)
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
                if RaidScale then
                    local tmpRaid = RaidScale
                    tmpRaid = ImGui.SliderFloat("Raid Zoom Level##MyGroup", tmpRaid, 0.5, 2.0)
                    if tmpRaid ~= RaidScale then
                        RaidScale = tmpRaid
                        settings[Module.Name].RaidScale = RaidScale
                    end
                end
            end
            ImGui.SeparatorText("Toggles##" .. Module.Name)
            if ImGui.BeginTable("##tGroupToggles", 2, tPlayerFlags) then
                ImGui.TableNextRow()
                ImGui.TableNextColumn()

                local tmpComms = useEQBC
                tmpComms = Module.Utils.DrawToggle('Use EQBC##' .. Module.Name, tmpComms, ToggleFlags)
                if tmpComms ~= useEQBC then
                    useEQBC = tmpComms
                end
                ImGui.TableNextColumn()
                local tmpMana = showMana
                tmpMana = Module.Utils.DrawToggle('Mana##' .. Module.Name, tmpMana, ToggleFlags)
                if tmpMana ~= showMana then
                    showMana = tmpMana
                end
                ImGui.TableNextColumn()

                local tmpEnd = showEnd
                tmpEnd = Module.Utils.DrawToggle('Endurance##' .. Module.Name, tmpEnd, ToggleFlags)
                if tmpEnd ~= showEnd then
                    showEnd = tmpEnd
                end
                ImGui.TableNextColumn()

                local tmpPet = showPet
                tmpPet = Module.Utils.DrawToggle('Show Pet##' .. Module.Name, tmpPet, ToggleFlags)
                if tmpPet ~= showPet then
                    showPet = tmpPet
                end
                ImGui.TableNextColumn()
                settings[Module.Name].ShowDummy = Module.Utils.DrawToggle('Show Dummy##' .. Module.Name, settings[Module.Name].ShowDummy, ToggleFlags)
                ImGui.TableNextColumn()
                settings[Module.Name].ShowRoleIcons = Module.Utils.DrawToggle('Show Role Icons##' .. Module.Name, settings[Module.Name].ShowRoleIcons, ToggleFlags)
                ImGui.TableNextColumn()
                settings[Module.Name].DynamicHP = Module.Utils.DrawToggle('Dynamic HP##' .. Module.Name, settings[Module.Name].DynamicHP, ToggleFlags)
                ImGui.TableNextColumn()
                settings[Module.Name].DynamicMP = Module.Utils.DrawToggle('Dynamic MP##' .. Module.Name, settings[Module.Name].DynamicMP, ToggleFlags)
                ImGui.TableNextColumn()
                hideTitle = Module.Utils.DrawToggle('Hide Title Bar##' .. Module.Name, hideTitle, ToggleFlags)
                ImGui.TableNextColumn()
                showSelf = Module.Utils.DrawToggle('Show Self##' .. Module.Name, showSelf, ToggleFlags)
                ImGui.TableNextColumn()
                showRaidWindow = Module.Utils.DrawToggle('Show Raid##' .. Module.Name, showRaidWindow, ToggleFlags)
                ImGui.TableNextColumn()
                settings[Module.Name].ShowLevel = Module.Utils.DrawToggle('Show Level##' .. Module.Name, settings[Module.Name].ShowLevel, ToggleFlags)
                ImGui.TableNextColumn()
                showMoveStatus = Module.Utils.DrawToggle('Show Move Status##' .. Module.Name, showMoveStatus, ToggleFlags)
                ImGui.TableNextColumn()
                settings[Module.Name].ShowValOnBar = Module.Utils.DrawToggle('Show Value on Bar##' .. Module.Name, settings[Module.Name].ShowValOnBar, ToggleFlags)
                ImGui.EndTable()
            end
            local tmpDist
            if tmpDist == nil then tmpDist = navDist end
            ImGui.SetNextItemWidth(100)
            tmpDist = ImGui.InputInt('Nav Stop Dist##' .. Module.Name, tmpDist, 1, 5)
            if tmpDist < 1 then tmpDist = 1 end
            if tmpDist > 100 then tmpDist = 100 end
            if tmpDist ~= navDist then
                navDist = tmpDist
            end
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
                settings[Module.Name].RaidScale = RaidScale
                settings[Module.Name].LoadTheme = themeName
                settings[Module.Name].ShowMoveStatus = showMoveStatus
                settings[Module.Name].locked = locked
                settings[Module.Name].ShowRaidWindow = showRaidWindow
                settings[Module.Name].NavDist = tmpDist
                writeSettings(configFile, settings)
            end
        end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
    end
    Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
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
    raidSize = mq.TLO.Raid.Members() or 0
    raidLeader = mq.TLO.Raid.Leader() or 'N/A'
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
    if #args == 2 then
        if args[1] == 'show' and args[2] == 'group' then
            showGroupWindow = true
        elseif args[1] == 'show' and args[2] == 'raid' then
            showRaidWindow = true
        elseif args[1] == 'hide' and args[2] == 'group' then
            showGroupWindow = false
        elseif args[1] == 'hide' and args[2] == 'raid' then
            showRaidWindow = false
        end
    elseif args[1] == 'ui' or args[1] == 'gui' or args[1] == 'show' then
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
        mq.cmdf("/dgge /target id %s", lastTar)
    end

    getMyInfo()

    if raidSize > 0 then
        sortRaidByGroup()
    end

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
