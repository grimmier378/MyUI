local mq                = require('mq')
local imgui             = require 'ImGui'

local Module            = {}
Module.ActorMailBox     = 'aa_party'
Module.IsRunning        = false
Module.Name             = 'AAParty'

---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false
if not loadedExeternally then
    MyUI_Utils = require('lib.common')
    MyUI_ThemeLoader = require('lib.theme_loader')
    MyUI_Actor = require('actors')
    MyUI_CharLoaded = mq.TLO.Me.DisplayName()
    MyUI_Mode = 'driver'
end

local themeID                                                           = 1
local expand, compact                                                   = {}, {}
local themeFile                                                         = string.format('%s/MyThemeZ.lua', mq.configDir)
local configFile                                                        = mq.configDir .. '/myui/AA_Party_Configs.lua'
local themezDir                                                         = mq.luaDir .. '/themez/init.lua'
local script                                                            = 'AA Party'
local MeLevel                                                           = mq.TLO.Me.Level()
local PctExp                                                            = mq.TLO.Me.PctExp()
local winFlags                                                          = bit32.bor(ImGuiWindowFlags.None)
local checkIn                                                           = os.time()
local currZone, lastZone
local PctAA, SettingAA, PtsAA, PtsSpent, PtsTotal, PtsAALast, LastState = 0, '0', 0, 0, 0, 0, ""
local firstRun                                                          = true
local hasThemeZ                                                         = MyUI_Utils.File.Exists(themezDir)

local theme                                                             = {}
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

local defaults                                                          = {
    Scale = 1,
    LoadTheme = 'Default',
    AutoSize = false,
    ShowTooltip = true,
    MaxRow = 1,
    AlphaSort = false,
}

local function loadTheme()
    if MyUI_Utils.File.Exists(themeFile) then
        theme = dofile(themeFile)
    else
        theme = require('defaults.themes') -- your local themes file incase the user doesn't have one in config folder
    end
    TempSettings.themeName = settings[script].LoadTheme or 'Default'
    if theme and theme.Theme then
        for tID, tData in pairs(theme.Theme) do
            if tData['Name'] == TempSettings.themeName then
                themeID = tID
            end
        end
    end
end

local function loadSettings()
    -- Check if the dialog data file exists
    local newSetting = false
    if not MyUI_Utils.File.Exists(configFile) then
        settings[script] = defaults
        mq.pickle(configFile, settings)
        loadSettings()
    else
        -- Load settings from the Lua config file
        settings = dofile(configFile)
        if settings[script] == nil then
            settings[script] = {}
            settings[script] = defaults
            newSetting = true
        end
    end

    if settings[script].locked == nil then
        settings[script].locked = false
        newSetting = true
    end

    if settings[script].AlphaSort == nil then
        settings[script].AlphaSort = false
        newSetting = true
    end

    if settings[script].Scale == nil then
        settings[script].Scale = 1
        newSetting = true
    end

    if settings[script].ShowTooltip == nil then
        settings[script].ShowTooltip = true
        newSetting = true
    end

    if settings[script].MaxRow == nil then
        settings[script].MaxRow = 1
        newSetting = true
    end

    if settings[script].LoadTheme == nil then
        settings[script].LoadTheme = 'Default'
        newSetting = true
    end

    loadTheme()

    if settings[script].AutoSize == nil then
        settings[script].AutoSize = TempSettings.aSize
        newSetting = true
    end

    -- Set the settings to the variables
    TempSettings.alphaSort   = settings[script].AlphaSort
    TempSettings.aSize       = settings[script].AutoSize
    TempSettings.scale       = settings[script].Scale
    TempSettings.showTooltip = settings[script].ShowTooltip
    TempSettings.themeName   = settings[script].LoadTheme
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
    local cState = mq.TLO.Me.CombatState()
    LastState = cState
    if firstRun then
        Subject = 'Hello'
        firstRun = false
    end
    return {
        Subject  = Subject,
        PctExp   = PctExp,
        PctExpAA = PctAA,
        Level    = MeLevel,
        Setting  = SettingAA,
        DoWho    = doWho,
        DoWhat   = doWhat,
        Name     = mq.TLO.Me.DisplayName(),
        Pts      = PtsAA,
        PtsTotal = PtsTotal,
        PtsSpent = PtsSpent,
        Check    = checkIn,
        State    = cState,
    }
end

local function DrawTheme(tName)
    local StyleCounter = 0
    local ColorCounter = 0
    for tID, tData in pairs(theme.Theme) do
        if tData.Name == tName then
            for pID, cData in pairs(theme.Theme[tID].Color) do
                ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
                ColorCounter = ColorCounter + 1
            end
            if tData['Style'] ~= nil then
                if next(tData['Style']) ~= nil then
                    for sID, sData in pairs(theme.Theme[tID].Style) do
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

local function sortedBoxes(boxes)
    table.sort(boxes, function(a, b)
        return a.Name < b.Name
    end)
    return boxes
end

--create mailbox for actors to send messages to
local function MessageHandler()
    aaActor = MyUI_Actor.register(Module.ActorMailBox, function(message)
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
            -- if who ~= MyUI_CharLoaded then
            if aaActor ~= nil then
                aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, GenerateContent(nil, 'Welcome'))
                aaActor:send({ mailbox = 'aa_party', script = 'myui', }, GenerateContent(nil, 'Welcome'))
            end
            -- end
            return
            -- checkIn = os.time()
        elseif subject == 'Action' then
            if dowho ~= 'N/A' then
                if MemberEntry.DoWho == MyUI_CharLoaded then
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
                        if groupData[i].LastPts ~= pts then
                            if who ~= MyUI_CharLoaded and AAPartyMode == 'driver' and groupData[i].LastPts < pts then
                                MyUI_Utils.PrintOutput('MyUI', true, "%s gained an AA, now has %d unspent", who, pts)
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
                            DoWhat = nil,
                            Setting = aaSetting,
                            Pts = pts,
                            PtsTotal = ptsTotal,
                            PtsSpent = ptsSpent,
                            LastPts = pts,
                            State = MemberEntry.State,
                            Check = check,
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
                        DoWhat = nil,
                        Setting = aaSetting,
                        Pts = pts,
                        PtsTotal = ptsTotal,
                        PtsSpent = ptsSpent,
                        LastPts = pts,
                        State = MemberEntry.State,
                        Check = check,
                    })
            end
        end
        if TempSettings.alphaSort then groupData = sortedBoxes(groupData) end
        if check == 0 then CheckStale() end
    end)
end

local function getMyAA()
    local changed      = false
    local tmpExpAA     = mq.TLO.Me.PctAAExp() or 0
    local tmpSettingAA = mq.TLO.Window("AAWindow/AAW_PercentCount").Text() or '0'
    local tmpPts       = mq.TLO.Me.AAPoints() or 0
    local tmpPtsTotal  = mq.TLO.Me.AAPointsTotal() or 0
    local tmpPtsSpent  = mq.TLO.Me.AAPointsSpent() or 0
    local tmpPctXP     = mq.TLO.Me.PctExp() or 0
    local tmpLvl       = mq.TLO.Me.Level() or 0
    local cState       = mq.TLO.Me.CombatState() or ""
    if firstRun or (PctAA ~= tmpExpAA or SettingAA ~= tmpSettingAA or PtsAA ~= tmpPts or
            PtsSpent ~= tmpPtsSpent or PtsTotal ~= tmpPtsTotal or tmpLvl ~= MeLevel or tmpPctXP ~= PctExp or cState ~= LastState) then
        PctAA = tmpExpAA
        SettingAA = tmpSettingAA
        PtsAA = tmpPts
        PtsTotal = tmpPtsTotal
        PtsSpent = tmpPtsSpent
        MeLevel = tmpLvl
        PctExp = tmpPctXP
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
        Name = MyUI_CharLoaded,
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
        local ColorCount, StyleCount = DrawTheme(settings[script].LoadTheme or 'Default')
        local openGUI, showGUI = imgui.Begin("AA Party##AA_Party_" .. MyUI_CharLoaded, true, winFlags)
        if not openGUI then
            AAPartyShow = false
        end
        if showGUI then
            if #groupData > 0 then
                local windowWidth = imgui.GetWindowWidth() - 4
                local currentX, currentY = imgui.GetCursorPosX(), imgui.GetCursorPosY()
                local itemWidth = 150 -- approximate width
                local padding = 2     -- padding between items
                for i = 1, #groupData do
                    if i == 1 then currentY = imgui.GetCursorPosY() end
                    if groupData[i] ~= nil then
                        if expand[groupData[i].Name] == nil then expand[groupData[i].Name] = false end
                        if compact[groupData[i].Name] == nil then compact[groupData[i].Name] = false end

                        if currentX + itemWidth > windowWidth then
                            imgui.NewLine()
                            currentY = imgui.GetCursorPosY()
                            currentX = imgui.GetCursorPosX()
                            -- currentY = imgui.GetCursorPosY()
                            ImGui.SetCursorPosY(currentY - 20)
                        else
                            if i > 1 then
                                imgui.SameLine()
                                -- ImGui.SetCursorPosY(currentY)
                            end
                        end
                        local childY = 68
                        if not expand[groupData[i].Name] then childY = 42 end
                        if compact[groupData[i].Name] then childY = 25 end
                        if compact[groupData[i].Name] and expand[groupData[i].Name] then childY = 51 end
                        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 2, 2)
                        imgui.BeginChild(groupData[i].Name, 145, childY, bit32.bor(ImGuiChildFlags.Border, ImGuiChildFlags.AutoResizeY), ImGuiWindowFlags.NoScrollbar)
                        -- Start of grouped Whole Elements
                        ImGui.BeginGroup()
                        -- Start of subgrouped Elements for tooltip
                        imgui.PushID(groupData[i].Name)
                        imgui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                        imgui.Text("%s (%s)", groupData[i].Name, groupData[i].Level)
                        ImGui.SameLine()
                        local combatState = groupData[i].State
                        if combatState == 'DEBUFFED' then
                            MyUI_Utils.DrawStatusIcon('A_PWCSDebuff', 'pwcs', 'You are Debuffed and need a cure before resting.', iconSize)
                        elseif combatState == 'ACTIVE' then
                            MyUI_Utils.DrawStatusIcon('A_PWCSStanding', 'pwcs', 'You are not in combat and may rest at any time.', iconSize)
                        elseif combatState == 'COOLDOWN' then
                            MyUI_Utils.DrawStatusIcon('A_PWCSTimer', 'pwcs', 'You are recovering from combat and can not reset yet', iconSize)
                        elseif combatState == 'RESTING' then
                            MyUI_Utils.DrawStatusIcon('A_PWCSRegen', 'pwcs', 'You are Resting.', iconSize)
                        elseif combatState == 'COMBAT' then
                            MyUI_Utils.DrawStatusIcon('A_PWCSInCombat', 'pwcs', 'You are in Combat.', iconSize)
                        else
                            MyUI_Utils.DrawStatusIcon(3996, 'item', ' ', iconSize)
                        end

                        if not compact[groupData[i].Name] then
                            imgui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(1, 0.9, 0.4, 0.5))
                            imgui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                            imgui.ProgressBar(groupData[i].PctExp / 100, ImVec2(137, 5), "##PctXP" .. groupData[i].Name)
                            imgui.PopStyleColor()
                            imgui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(0.2, 0.9, 0.9, 0.5))
                            imgui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                            imgui.ProgressBar(groupData[i].PctExpAA / 100, ImVec2(137, 5), "##AAXP" .. groupData[i].Name)
                            imgui.PopStyleColor()
                        end

                        imgui.PopID()
                        ImGui.EndGroup()
                        -- end of subgrouped Elements for tooltip begin tooltip
                        if ImGui.IsItemHovered() and TempSettings.showTooltip then
                            imgui.BeginTooltip()
                            local tTipTxt = "\t\t" .. groupData[i].Name
                            imgui.TextColored(ImVec4(1, 1, 1, 1), tTipTxt)
                            imgui.Separator()
                            tTipTxt = string.format("Exp:\t\t\t%.2f %%", groupData[i].PctExp)
                            imgui.TextColored(ImVec4(1, 0.9, 0.4, 1), tTipTxt)
                            tTipTxt = string.format("AA Exp: \t%.2f %%", groupData[i].PctExpAA)
                            imgui.TextColored(ImVec4(0.2, 0.9, 0.9, 1), tTipTxt)
                            tTipTxt = string.format("Avail:  \t\t%d", groupData[i].Pts)
                            imgui.TextColored(ImVec4(0, 1, 0, 1), tTipTxt)
                            tTipTxt = string.format("Spent:\t\t%d", groupData[i].PtsSpent)
                            imgui.TextColored(ImVec4(0.9, 0.4, 0.4, 1), tTipTxt)
                            tTipTxt = string.format("Total:\t\t%d", groupData[i].PtsTotal)
                            imgui.TextColored(ImVec4(0.8, 0.0, 0.8, 1.0), tTipTxt)
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
                                    aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, GenerateContent(groupData[i].Name, 'Action', 'Less'))
                                    aaActor:send({ mailbox = 'aa_party', script = 'myui', }, GenerateContent(groupData[i].Name, 'Action', 'Less'))
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

                            if imgui.Button(">##Increase" .. groupData[i].Name) then
                                if aaActor ~= nil then
                                    aaActor:send({ mailbox = 'aa_party', script = 'myui', }, GenerateContent(groupData[i].Name, 'Action', 'More'))
                                    aaActor:send({ mailbox = 'aa_party', script = 'aaparty', }, GenerateContent(groupData[i].Name, 'Action', 'More'))
                                end
                            end
                        end

                        ImGui.Separator()
                        imgui.EndChild()
                        ImGui.PopStyleVar()
                        -- End of grouped items
                        -- Left Click to expand the group for AA settings
                        currentX = currentX + itemWidth + padding
                    end
                end
            end
            if ImGui.BeginPopupContextWindow() then
                if ImGui.MenuItem("Config##Config_" .. MyUI_CharLoaded) then
                    AAPartyConfigShow = not AAPartyConfigShow
                end
                if ImGui.MenuItem("Toggle Auto Size##Size_" .. MyUI_CharLoaded) then
                    TempSettings.aSize = not TempSettings.aSize
                end
                if ImGui.MenuItem("Toggle Tooltip##Tooltip_" .. MyUI_CharLoaded) then
                    TempSettings.showTooltip = not TempSettings.showTooltip
                end
                ImGui.EndPopup()
            end
            MyUI_ThemeLoader.EndTheme(ColorCount, StyleCount)
            imgui.End()
        else
            MyUI_ThemeLoader.EndTheme(ColorCount, StyleCount)
            imgui.End()
        end
    end

    if MailBoxShow then
        local ColorCount, StyleCount = DrawTheme(settings[script].LoadTheme or 'Default')
        local openMail, showMail = imgui.Begin("AA Party MailBox##MailBox_" .. MyUI_CharLoaded, true, ImGuiWindowFlags.None)
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
        MyUI_ThemeLoader.EndTheme(ColorCount, StyleCount)
        imgui.End()
    else
        mailBox = {}
    end

    if AAPartyConfigShow then
        local ColorCountTheme, StyleCountTheme = DrawTheme(settings[script].LoadTheme or 'Default')
        local openTheme, showConfig = ImGui.Begin('Config##MySpells_', true, bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.AlwaysAutoResize))
        if not openTheme then
            AAPartyConfigShow = false
        end
        if showConfig then
            ImGui.SeparatorText("Theme##MySpells")
            ImGui.Text("Cur Theme: %s", TempSettings.themeName)
            -- Combo Box Load Theme
            if ImGui.BeginCombo("Load Theme##MySpells", TempSettings.themeName) then
                for k, data in pairs(theme.Theme) do
                    local isSelected = data.Name == TempSettings.themeName
                    if ImGui.Selectable(data.Name, isSelected) then
                        theme.LoadTheme = data.Name
                        themeID = k
                        TempSettings.themeName = theme.LoadTheme
                    end
                end
                ImGui.EndCombo()
            end

            TempSettings.scale = ImGui.SliderFloat("Scale##DialogDB", TempSettings.scale, 0.5, 2)
            if TempSettings.scale ~= settings[script].Scale then
                if TempSettings.scale < 0.5 then TempSettings.scale = 0.5 end
                if TempSettings.scale > 2 then TempSettings.scale = 2 end
            end

            if hasThemeZ then
                if ImGui.Button('Edit ThemeZ') then
                    mq.cmd("/lua run themez")
                end
                ImGui.SameLine()
            end

            if ImGui.Button('Reload Theme File') then
                loadTheme()
            end

            MailBoxShow = ImGui.Checkbox("Show MailBox##MySpells", MailBoxShow)
            ImGui.SameLine()
            TempSettings.alphaSort = ImGui.Checkbox("Alpha Sort##MySpells", TempSettings.alphaSort)
            TempSettings.showTooltip = ImGui.Checkbox("Show Tooltip##MySpells", TempSettings.showTooltip)

            if ImGui.Button("Save & Close") then
                settings = dofile(configFile)
                settings[script].Scale = TempSettings.scale
                settings[script].AlphaSort = TempSettings.alphaSort
                settings[script].LoadTheme = TempSettings.themeName
                settings[script].ShowTooltip = TempSettings.showTooltip
                mq.pickle(configFile, settings)
                AAPartyConfigShow = false
            end
        end
        MyUI_ThemeLoader.EndTheme(ColorCountTheme, StyleCountTheme)
        ImGui.End()
    end
end

function Module.CheckMode()
    if MyUI_Mode == 'driver' then
        AAPartyShow = true
        AAPartyMode = 'driver'
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Setting \atDriver\ax Mode. UI will be displayed.')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Type \at/aaparty show\ax. to Toggle the UI')
    elseif MyUI_Mode == 'client' then
        AAPartyMode = 'client'
        AAPartyShow = false
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Setting \atClient\ax Mode. UI will not be displayed.')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Type \at/aaparty show\ax. to Toggle the UI')
    end
end

local args = { ..., }
function Module.CheckArgsar(args)
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
                MyUI_Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Toggling GUI \atOpen\ax.')
            else
                MyUI_Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Toggling GUI \atClosed\ax.')
            end
        elseif args[1] == 'exit' or args[1] == 'quit' then
            Module.IsRunning = false
            MyUI_Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Exiting.')
            SayGoodBye()
            Module.IsRunning = false
        elseif args[1] == 'mailbox' then
            MailBoxShow = not MailBoxShow
            if MailBoxShow then
                MyUI_Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Toggling MailBox \atOpen\ax.')
            else
                MyUI_Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Toggling MailBox \atClosed\ax.')
            end
        else
            MyUI_Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao Invalid command given.')
        end
    else
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ao No command given.')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ag /aaparty gui \ao- Toggles the GUI on and off.')
        MyUI_Utils.PrintOutput('MyUI', nil, '\ayAA Party:\ag /aaparty exit \ao- Exits the plugin.')
    end
end

local function init()
    currZone = mq.TLO.Zone.ID()
    lastZone = currZone
    firstRun = true
    if not loadedExeternally then
        Module.CheckArgsar(args)
        mq.imgui.init(script .. "##" .. MyUI_CharLoaded, Module.RenderGUI)
    else
        Module.CheckMode()
    end
    mq.bind('/aaparty', processCommand)
    PtsAA = mq.TLO.Me.AAPoints()
    loadSettings()
    getMyAA()
    Module.IsRunning = true
    if MyUI_Utils.File.Exists(themezDir) then
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
        ---@diagnostic disable-next-line: undefined-global
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
    printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", script)
    mq.exit()
end

MessageHandler()
init()
Module.MainLoop()
return Module
