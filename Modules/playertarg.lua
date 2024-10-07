--[[
    Title: PlayerTarget
    Author: Grimmier
    Description: Combines Player Information window and Target window into one.
    Displays Your player info. as well as Target: Hp, Your aggro, SecondaryAggroPlayer, Visability, Distance,
    and Buffs with name \ duration on tooltip hover.
]]
local mq = require('mq')
local ImGui = require('ImGui')
local Module = {}
Module.Name = 'PlayerTarg'
Module.IsRunning = false

---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false

if not loadedExeternally then
    MyUI_Utils = require('lib.common')
    MyUI_Icons = require('mq.ICONS')
    MyUI_Colors = require('lib.colors')
    MyUI_CharLoaded = mq.TLO.Me.DisplayName()
    MyUI_Server = mq.TLO.MacroQuest.Server()
end

local gIcon = MyUI_Icons.MD_SETTINGS
-- set variables
local pulse = true
local iconSize, progressSize = 26, 10
local flashAlpha, FontScale, cAlpha = 1, 1, 255
local ShowGUI, locked, flashBorder, rise, cRise = true, false, true, true, false
local openConfigGUI, openGUI = false, true
local themeFile = mq.configDir .. '/MyThemeZ.lua'
local configFileOld = mq.configDir .. '/MyUI_Configs.lua'
local configFile = string.format('%s/MyUI/PlayerTarg/%s/%s.lua', mq.configDir, MyUI_Server, MyUI_CharLoaded)
local ColorCount, ColorCountConf, StyleCount, StyleCountConf = 0, 0, 0, 0
local themeName = 'Default'
local script = 'PlayerTarg'
local pulseSpeed = 5
local combatPulseSpeed = 10
local colorHpMax = { 0.992, 0.138, 0.138, 1.000, }
local colorHpMin = { 0.551, 0.207, 0.962, 1.000, }
local colorMpMax = { 0.231, 0.707, 0.938, 1.000, }
local colorMpMin = { 0.600, 0.231, 0.938, 1.000, }
local colorBreathMin = { 0.600, 0.231, 0.938, 1.000, }
local colorBreathMax = { 0.231, 0.707, 0.938, 1.000, }
local testValue, testValue2 = 100, 100
local splitTarget = false
local mouseHud, mouseHudTarg = false, false
local ProgressSizeTarget = 30
local showTitleBreath = false
local bLocked = false
local breathBarShow = false
local enableBreathBar = false
local breathPct = 100
-- Flags

local tPlayerFlags = bit32.bor(ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.NoPadInnerX,
    ImGuiTableFlags.NoPadOuterX, ImGuiTableFlags.Resizable, ImGuiTableFlags.SizingFixedFit)
local winFlag = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse)
local targFlag = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse)

--Tables

local defaults, settings, themeRowBG, themeBorderBG, theme = {}, {}, {}, {}, {}
themeRowBG = { 1, 1, 1, 0, }
themeBorderBG = { 1, 1, 1, 1, }

defaults = {
    Scale = 1.0,
    LoadTheme = 'Default',
    locked = false,
    IconSize = 26,
    doPulse = true,
    SplitTarget = false,
    showXtar = false,
    ColorHPMax = { 0.992, 0.138, 0.138, 1.000, },
    ColorHPMin = { 0.551, 0.207, 0.962, 1.000, },
    ColorMPMax = { 0.231, 0.707, 0.938, 1.000, },
    ColorMPMin = { 0.600, 0.231, 0.938, 1.000, },
    ColorBreathMin = { 0.600, 0.231, 0.938, 1.000, },
    ColorBreathMax = { 0.231, 0.707, 0.938, 1.000, },
    BreathLocked = false,
    ShowTitleBreath = false,
    EnableBreathBar = false,
    pulseSpeed = 5,
    combatPulseSpeed = 10,
    DynamicHP = false,
    DynamicMP = false,
    FlashBorder = true,
    MouseOver = false,
    WinTransparency = 1.0,
    ProgressSize = 10,
    ProgressSizeTarget = 30,
}

-- Functions

local function GetInfoToolTip()
    return string.format(
        '%s\t\tlvl: %d\nClass: \t %s\nHealth:\t%d of %d\nMana:  \t%d of %d\nEnd: \t\t %d of %d\nExp: %d',
        mq.TLO.Me.DisplayName(), mq.TLO.Me.Level(), mq.TLO.Me.Class.Name(), mq.TLO.Me.CurrentHPs(), mq.TLO.Me.MaxHPs(), mq.TLO.Me.CurrentMana(), mq.TLO.Me.MaxMana(),
        mq.TLO.Me.CurrentEndurance(), mq.TLO.Me.MaxEndurance(), (mq.TLO.Me.PctExp() or 0)
    )
end

local function loadTheme()
    if MyUI_Utils.File.Exists(themeFile) then
        theme = dofile(themeFile)
    else
        theme = require('defaults.themes')
    end
    themeName = theme.LoadTheme or 'notheme'
end

local function loadSettings()
    if not MyUI_Utils.File.Exists(configFile) then
        if MyUI_Utils.File.Exists(configFileOld) then
            local tmpOld = {}
            tmpOld = dofile(configFileOld)
            for k, v in pairs(tmpOld) do
                if k == script then
                    settings[script] = v
                end
            end
            mq.pickle(configFile, settings)
        else
            settings[script] = {}
            settings[script] = defaults
            mq.pickle(configFile, settings)
        end
    else
        -- Load settings from the Lua config file
        settings = dofile(configFile)
        if not settings[script] then
            settings[script] = {}
            settings[script] = defaults
        end
    end

    loadTheme()

    local newSetting = false

    newSetting = MyUI_Utils.CheckDefaultSettings(defaults, settings[script]) or newSetting

    if settings[script].iconSize ~= nil then
        settings[script].IconSize = settings[script].iconSize
        settings[script].iconSize = nil
        newSetting = true
    end

    colorBreathMin = settings[script].ColorBreathMin
    colorBreathMax = settings[script].ColorBreathMax
    showTitleBreath = settings[script].ShowTitleBreath
    bLocked = settings[script].BreathLocked
    enableBreathBar = settings[script].EnableBreathBar
    splitTarget = settings[script].SplitTarget
    colorHpMax = settings[script].ColorHPMax
    colorHpMin = settings[script].ColorHPMin
    colorMpMax = settings[script].ColorMPMax
    colorMpMin = settings[script].ColorMPMin
    combatPulseSpeed = settings[script].combatPulseSpeed
    pulseSpeed = settings[script].pulseSpeed
    pulse = settings[script].doPulse
    flashBorder = settings[script].FlashBorder
    progressSize = settings[script].ProgressSize
    iconSize = settings[script].IconSize
    locked = settings[script].locked
    FontScale = settings[script].Scale
    themeName = settings[script].LoadTheme
    ProgressSizeTarget = settings[script].ProgressSizeTarget

    if newSetting then mq.pickle(configFile, settings) end
end

local function pulseGeneric(speed, alpha, rising, lastTime, frameTime, maxAlpha, minAlpha)
    if speed == 0 then return alpha, rising, lastTime end
    local currentTime = os.clock()
    if currentTime - lastTime < frameTime then
        return alpha, rising, lastTime -- exit if not enough time has passed
    end
    lastTime = currentTime             -- update the last time
    if rising then
        alpha = alpha + speed
    else
        alpha = alpha - speed
    end
    if alpha >= maxAlpha then
        rising = false
    elseif alpha <= minAlpha then
        rising = true
    end
    return alpha, rising, lastTime
end

local lastTime, lastTimeCombat = os.clock(), os.clock()
local frameTime, frameTimeCombat = 1 / 60, 1 / 120

local function pulseIcon(speed)
    flashAlpha, rise, lastTime = pulseGeneric(speed, flashAlpha, rise, lastTime, frameTime, 200, 10)
    if speed == 0 then flashAlpha = 0 end
end

local function pulseCombat(speed)
    cAlpha, cRise, lastTimeCombat = pulseGeneric(speed, cAlpha, cRise, lastTimeCombat, frameTimeCombat, 250, 10)
    if speed == 0 then cAlpha = 255 end
end


---comment
---@param tName string -- name of the theme to load form table
---@param window string -- name of the window to apply the theme to
---@return integer, integer -- returns the new counter values
local function DrawTheme(tName, window)
    local StyleCounter = 0
    local ColorCounter = 0
    for tID, tData in pairs(theme.Theme) do
        if tData.Name == tName then
            for pID, cData in pairs(theme.Theme[tID].Color) do
                if window == 'main' then
                    if cData.PropertyName == 'Border' then
                        themeBorderBG = { cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4], }
                    elseif cData.PropertyName == 'TableRowBg' then
                        themeRowBG = { cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4], }
                    elseif cData.PropertyName == 'WindowBg' then
                        if not settings[script].MouseOver then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], settings[script].WinTransparency))
                            ColorCounter = ColorCounter + 1
                        elseif settings[script].MouseOver and mouseHud then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], 1.0))
                            ColorCounter = ColorCounter + 1
                        elseif settings[script].MouseOver and not mouseHud then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], settings[script].WinTransparency))
                            ColorCounter = ColorCounter + 1
                        end
                    else
                        ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
                        ColorCounter = ColorCounter + 1
                    end
                elseif window == 'targ' then
                    if cData.PropertyName == 'Border' then
                        themeBorderBG = { cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4], }
                    elseif cData.PropertyName == 'TableRowBg' then
                        themeRowBG = { cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4], }
                    elseif cData.PropertyName == 'WindowBg' then
                        if not settings[script].MouseOver then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], settings[script].WinTransparency))
                            ColorCounter = ColorCounter + 1
                        elseif settings[script].MouseOver and mouseHudTarg then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], 1.0))
                            ColorCounter = ColorCounter + 1
                        elseif settings[script].MouseOver and not mouseHudTarg then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], settings[script].WinTransparency))
                            ColorCounter = ColorCounter + 1
                        end
                    else
                        ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
                        ColorCounter = ColorCounter + 1
                    end
                else
                    ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
                    ColorCounter = ColorCounter + 1
                end
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

--[[
    Borrowed from rgmercs
    ~Thanks Derple
]]
---@param iconID integer
---@param spell MQSpell
---@param i integer
local function DrawInspectableSpellIcon(iconID, spell, i)
    local cursor_x, cursor_y = ImGui.GetCursorPos()
    local beniColor = IM_COL32(0, 20, 180, 190) -- blue benificial default color
    MyUI_Utils.Animation_Spell:SetTextureCell(iconID or 0)
    local caster = spell.Caster() or '?'        -- the caster of the Spell
    if not spell.Beneficial() then
        beniColor = IM_COL32(255, 0, 0, 190)    --red detrimental
    end
    if caster == mq.TLO.Me.DisplayName() and not spell.Beneficial() then
        beniColor = IM_COL32(190, 190, 20, 255) -- detrimental cast by me (yellow)
    end
    ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
        ImGui.GetCursorScreenPosVec() + iconSize, beniColor)
    ImGui.SetCursorPos(cursor_x + 3, cursor_y + 3)
    if caster == mq.TLO.Me.DisplayName() and spell.Beneficial() then
        ImGui.DrawTextureAnimation(MyUI_Utils.Animation_Spell, iconSize - 6, iconSize - 6, true)
    else
        ImGui.DrawTextureAnimation(MyUI_Utils.Animation_Spell, iconSize - 5, iconSize - 5)
    end
    ImGui.SetCursorPos(cursor_x + 2, cursor_y + 2)
    local sName = spell.Name() or '??'
    local sDur = spell.Duration.TotalSeconds() or 0
    ImGui.PushID(tostring(iconID) .. sName .. "_invis_btn")
    if sDur < 18 and sDur > 0 and pulse then
        local flashColor = IM_COL32(0, 0, 0, flashAlpha)
        ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
            ImGui.GetCursorScreenPosVec() + iconSize - 4, flashColor)
    end
    ImGui.SetCursorPos(cursor_x, cursor_y)
    ImGui.InvisibleButton(sName, ImVec2(iconSize, iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
    if ImGui.IsItemHovered() then
        if (ImGui.IsMouseReleased(1)) then
            spell.Inspect()
        end
        if ImGui.BeginTooltip() then
            ImGui.TextColored(MyUI_Colors.color('yellow'), '%s', sName)
            ImGui.TextColored(MyUI_Colors.color('green'), '%s', MyUI_Utils.GetTargetBuffDuration(i))
            ImGui.Text('Cast By: ')
            ImGui.SameLine()
            ImGui.TextColored(MyUI_Colors.color('light blue'), '%s', caster)
            ImGui.EndTooltip()
        end
    end
    ImGui.PopID()
end

local function targetBuffs(count)
    local iconsDrawn = 0
    -- Width and height of each texture
    local windowWidth = ImGui.GetWindowContentRegionWidth()
    -- Calculate max icons per row based on the window width
    local maxIconsRow = (windowWidth / iconSize) - 0.75
    if rise == true then
        flashAlpha = flashAlpha + 5
    elseif rise == false then
        flashAlpha = flashAlpha - 5
    end
    if flashAlpha == 128 then rise = false end
    if flashAlpha == 25 then rise = true end
    ImGui.BeginGroup()
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
    if mq.TLO.Target.BuffCount() ~= nil then
        for i = 1, count do
            local sIcon = mq.TLO.Target.Buff(i).SpellIcon() or 0
            if mq.TLO.Target.Buff(i) ~= nil then
                DrawInspectableSpellIcon(sIcon, mq.TLO.Target.Buff(i), i)
                iconsDrawn = iconsDrawn + 1
            end
            -- Check if we've reached the max icons for the row, if so reset counter and new line
            if iconsDrawn >= maxIconsRow then
                iconsDrawn = 0 -- Reset counter
            else
                -- Use SameLine to keep drawing items on the same line, except for when a new line is needed
                if i < count then
                    ImGui.SameLine()
                else
                    ImGui.SetCursorPosX(1)
                end
            end
        end
    end
    ImGui.PopStyleVar()
    ImGui.EndGroup()
end

-- GUI
local function PlayerTargConf_GUI()
    if not openConfigGUI then return end
    ColorCountConf = 0
    StyleCountConf = 0
    ColorCountConf, StyleCountConf = DrawTheme(themeName, 'config')
    local open, showConfigGUI = ImGui.Begin("PlayerTarg Conf##" .. script, true, bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.AlwaysAutoResize))

    if not open then openConfigGUI = false end
    if showConfigGUI then
        ImGui.SetWindowFontScale(FontScale)
        ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(1, 0.4, 0.4, 0.9))
        if ImGui.Button("Reset Defaults") then
            settings = dofile(configFile)
            flashBorder = false
            progressSize = 10
            FontScale = 1
            iconSize = 26
            themeName = 'Default'
            settings[script].FlashBorder = flashBorder
            settings[script].ProgressSize = progressSize
            settings[script].Scale = FontScale
            settings[script].IconSize = iconSize
            settings[script].LoadTheme = themeName
        end
        ImGui.PopStyleColor()

        if ImGui.CollapsingHeader("Theme##" .. script) then
            ImGui.Text("Cur Theme: %s", themeName)
            -- Combo Box Load Theme
            if ImGui.BeginCombo("Load Theme##" .. script, themeName) then
                for k, data in pairs(theme.Theme) do
                    local isSelected = data.Name == themeName
                    if ImGui.Selectable(data.Name, isSelected) then
                        theme.LoadTheme = data.Name
                        themeName = theme.LoadTheme
                        settings[script].LoadTheme = themeName
                    end
                end
                ImGui.EndCombo()
            end

            if ImGui.Button('Reload Theme File') then
                loadTheme()
            end

            settings[script].MouseOver = ImGui.Checkbox('Mouse Over', settings[script].MouseOver)
            settings[script].WinTransparency = ImGui.SliderFloat('Window Transparency##' .. script, settings[script].WinTransparency, 0.1, 1.0)
        end
        ImGui.Spacing()
        if ImGui.CollapsingHeader("Scaling##" .. script) then
            -- Slider for adjusting zoom level
            local tmpZoom = FontScale
            if FontScale then
                tmpZoom = ImGui.SliderFloat("Text Scale##" .. script, tmpZoom, 0.5, 2.0)
            end
            if FontScale ~= tmpZoom then
                FontScale = tmpZoom
            end
            -- Slider for adjusting Icon Size
            local tmpSize = iconSize
            if iconSize then
                tmpSize = ImGui.SliderInt("Icon Size##" .. script, tmpSize, 15, 50)
            end
            if iconSize ~= tmpSize then
                iconSize = tmpSize
            end

            -- Slider for adjusting Progress Bar Size
            local tmpPrgSz = progressSize
            if progressSize then
                tmpPrgSz = ImGui.SliderInt("Progress Bar Size##" .. script, tmpPrgSz, 5, 50)
            end
            if progressSize ~= tmpPrgSz then
                progressSize = tmpPrgSz
            end
            ProgressSizeTarget = ImGui.SliderInt("Target Progress Bar Size##" .. script, ProgressSizeTarget, 5, 150)
            settings[script].showXtar = ImGui.Checkbox('Show XTarget Number', settings[script].showXtar)
        end
        ImGui.Spacing()

        if ImGui.CollapsingHeader("Pulse Settings##" .. script) then
            flashBorder = ImGui.Checkbox('Flash Border', flashBorder)
            ImGui.SameLine()
            local tmpPulse = pulse
            tmpPulse, _ = ImGui.Checkbox('Pulse Icons', tmpPulse)
            if _ then
                if tmpPulse == true and pulseSpeed == 0 then
                    pulseSpeed = defaults.pulseSpeed
                end
            end
            if pulse ~= tmpPulse then
                pulse = tmpPulse
            end
            if pulse then
                local tmpSpeed = pulseSpeed
                tmpSpeed = ImGui.SliderInt('Icon Pulse Speed##' .. script, tmpSpeed, 0, 50)
                if pulseSpeed ~= tmpSpeed then
                    pulseSpeed = tmpSpeed
                end
            end
            local tmpCmbtSpeed = combatPulseSpeed
            tmpCmbtSpeed = ImGui.SliderInt('Combat Pulse Speed##' .. script, tmpCmbtSpeed, 0, 50)
            if combatPulseSpeed ~= tmpCmbtSpeed then
                combatPulseSpeed = tmpCmbtSpeed
            end
        end
        ImGui.Spacing()

        if ImGui.CollapsingHeader("Dynamic Bar Colors##" .. script) then
            settings[script].DynamicHP = ImGui.Checkbox('Dynamic HP Bar', settings[script].DynamicHP)
            ImGui.SameLine()
            ImGui.SetNextItemWidth(60)
            colorHpMin = ImGui.ColorEdit4("HP Min Color##" .. script, colorHpMin, bit32.bor(ImGuiColorEditFlags.AlphaBar, ImGuiColorEditFlags.NoInputs))
            ImGui.SameLine()
            ImGui.SetNextItemWidth(60)
            colorHpMax = ImGui.ColorEdit4("HP Max Color##" .. script, colorHpMax, bit32.bor(ImGuiColorEditFlags.AlphaBar, ImGuiColorEditFlags.NoInputs))

            testValue = ImGui.SliderInt("Test HP##" .. script, testValue, 0, 100)

            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Utils.CalculateColor(colorHpMin, colorHpMax, testValue)))
            ImGui.ProgressBar((testValue / 100), ImGui.GetContentRegionAvail(), progressSize, '##Test')
            ImGui.PopStyleColor()

            settings[script].DynamicMP = ImGui.Checkbox('Dynamic Mana Bar', settings[script].DynamicMP)
            ImGui.SameLine()
            ImGui.SetNextItemWidth(60)
            colorMpMin = ImGui.ColorEdit4("Mana Min Color##" .. script, colorMpMin, bit32.bor(ImGuiColorEditFlags.NoInputs))
            ImGui.SameLine()
            ImGui.SetNextItemWidth(60)
            colorMpMax = ImGui.ColorEdit4("Mana Max Color##" .. script, colorMpMax, bit32.bor(ImGuiColorEditFlags.NoInputs))

            testValue2 = ImGui.SliderInt("Test MP##" .. script, testValue2, 0, 100)
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Utils.CalculateColor(colorMpMin, colorMpMax, testValue2)))
            ImGui.ProgressBar((testValue2 / 100), ImGui.GetContentRegionAvail(), progressSize, '##Test2')
            ImGui.PopStyleColor()
        end
        ImGui.Spacing()

        -- breath bar settings
        if ImGui.CollapsingHeader("Breath Meter##" .. script) then
            local tmpbreath = settings[script].EnableBreathBar
            tmpbreath = ImGui.Checkbox('Enable Breath', tmpbreath)
            if tmpbreath ~= settings[script].EnableBreathBar then
                settings[script].EnableBreathBar = tmpbreath
            end
            ImGui.SameLine()
            ImGui.SetNextItemWidth(60)
            colorBreathMin = ImGui.ColorEdit4("Breath Min Color##" .. script, colorBreathMin, bit32.bor(ImGuiColorEditFlags.NoInputs))
            ImGui.SameLine()
            ImGui.SetNextItemWidth(60)
            colorBreathMax = ImGui.ColorEdit4("Breath Max Color##" .. script, colorBreathMax, bit32.bor(ImGuiColorEditFlags.NoInputs))
            local testValue3 = 100
            testValue3 = ImGui.SliderInt("Test Breath##" .. script, testValue3, 0, 100)
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Utils.CalculateColor(colorBreathMin, colorBreathMax, testValue3)))
            ImGui.ProgressBar((testValue3 / 100), ImGui.GetContentRegionAvail(), progressSize, '##Test3')
            ImGui.PopStyleColor()
        end
        ImGui.Spacing()

        if ImGui.Button('Save and Close##' .. script) then
            openConfigGUI = false
            settings[script].ColorBreathMin = colorBreathMin
            settings[script].ColorBreathMax = colorBreathMax
            settings[script].ProgressSizeTarget = ProgressSizeTarget
            settings[script].ColorHPMax = colorHpMax
            settings[script].ColorHPMin = colorHpMin
            settings[script].ColorMPMax = colorMpMax
            settings[script].ColorMPMin = colorMpMin
            settings[script].FlashBorder = flashBorder
            settings[script].ProgressSize = progressSize
            settings[script].Scale = FontScale
            settings[script].IconSize = iconSize
            settings[script].LoadTheme = themeName
            settings[script].doPulse = pulse
            settings[script].pulseSpeed = pulseSpeed
            settings[script].combatPulseSpeed = combatPulseSpeed
            mq.pickle(configFile, settings)
        end
    end

    if StyleCountConf > 0 then ImGui.PopStyleVar(StyleCountConf) end
    if ColorCountConf > 0 then ImGui.PopStyleColor(ColorCountConf) end
    ImGui.SetWindowFontScale(1)
    ImGui.End()
end

local function findXTarSlot(id)
    for i = 1, mq.TLO.Me.XTargetSlots() do
        if mq.TLO.Me.XTarget(i).ID() == id then
            return i
        end
    end
end

local function drawTarget()
    if (mq.TLO.Target() ~= nil) then
        ImGui.BeginGroup()
        ImGui.SetWindowFontScale(FontScale)
        local targetName = mq.TLO.Target.CleanName() or '?'
        local xSlot = findXTarSlot(mq.TLO.Target.ID()) or 0
        local tC = MyUI_Utils.GetConColor(mq.TLO.Target) or "WHITE"
        if tC == 'red' then tC = 'pink' end
        local tClass = mq.TLO.Target.Class.ShortName() == 'UNKNOWN CLASS' and MyUI_Icons.MD_HELP_OUTLINE or
            mq.TLO.Target.Class.ShortName()
        local tLvl = mq.TLO.Target.Level() or 0
        local tBodyType = mq.TLO.Target.Body.Name() or '?'
        --Target Health Bar
        ImGui.BeginGroup()
        if settings[script].DynamicHP then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Utils.CalculateColor(colorHpMin, colorHpMax, mq.TLO.Target.PctHPs())))
        else
            if mq.TLO.Target.PctHPs() < 25 then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Colors.color('orange')))
            else
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Colors.color('red')))
            end
        end
        local yPos = ImGui.GetCursorPosY() - 2
        ImGui.ProgressBar(((tonumber(mq.TLO.Target.PctHPs() or 0)) / 100), ImGui.GetContentRegionAvail(), ProgressSizeTarget, '##' .. mq.TLO.Target.PctHPs())
        ImGui.PopStyleColor()

        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Name: %s\t Lvl: %s\nClass: %s\nType: %s", targetName, tLvl, tClass, tBodyType)
        end

        ImGui.SetCursorPosY(yPos)
        ImGui.SetCursorPosX(9)
        if ImGui.BeginTable("##targetInfoOverlay", 2, tPlayerFlags) then
            ImGui.TableSetupColumn("##col1", ImGuiTableColumnFlags.NoResize, (ImGui.GetContentRegionAvail() * .5) - 8)
            ImGui.TableSetupColumn("##col2", ImGuiTableColumnFlags.NoResize, (ImGui.GetContentRegionAvail() * .5) + 8) -- Adjust width for distance and Aggro% text
            -- First Row: Name, con, distance
            ImGui.TableNextRow()
            ImGui.TableSetColumnIndex(0)
            -- Name and CON in the first column

            if xSlot > 0 and settings[script].showXtar then
                ImGui.Text("X#%s %s", xSlot, targetName)
            else
                ImGui.Text("%s", targetName)
            end
            -- Distance in the second column
            ImGui.TableSetColumnIndex(1)

            ImGui.PushStyleColor(ImGuiCol.Text, MyUI_Colors.color(tC))
            if tC == 'pink' then
                ImGui.Text('   ' .. MyUI_Icons.MD_WARNING)
            else
                ImGui.Text('   ' .. MyUI_Icons.MD_LENS)
            end
            ImGui.PopStyleColor()

            ImGui.SameLine(ImGui.GetColumnWidth() - 35)
            ImGui.PushStyleColor(ImGuiCol.Text, MyUI_Colors.color('yellow'))

            ImGui.Text(tostring(math.floor(mq.TLO.Target.Distance() or 0)) .. 'm')
            ImGui.PopStyleColor()
            -- Second Row: Class, Level, and Aggro%
            ImGui.TableNextRow()
            ImGui.TableSetColumnIndex(0) -- Class and Level in the first column

            ImGui.Text(tostring(tLvl) .. ' ' .. tClass .. '\t' .. tBodyType)
            -- Aggro% text in the second column
            ImGui.TableSetColumnIndex(1)

            ImGui.Text(tostring(mq.TLO.Target.PctHPs()) .. '%')
            ImGui.EndTable()
        end
        ImGui.EndGroup()

        ImGui.Separator()
        --Aggro % Bar
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 8, 1)
        if (mq.TLO.Target.Aggressive) then
            yPos = ImGui.GetCursorPosY() - 2
            ImGui.BeginGroup()
            if mq.TLO.Target.PctAggro() < 100 then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Colors.color('orange')))
            else
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Colors.color('purple')))
            end
            ImGui.ProgressBar(((tonumber(mq.TLO.Target.PctAggro() or 0)) / 100), ImGui.GetContentRegionAvail(), progressSize,
                '##pctAggro')
            ImGui.PopStyleColor()
            --Secondary Aggro Person

            if (mq.TLO.Target.SecondaryAggroPlayer() ~= nil) then
                ImGui.SetCursorPosY(yPos)
                ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 5)
                ImGui.Text("%s", mq.TLO.Target.SecondaryAggroPlayer())
            end
            --Aggro % Label middle of bar
            ImGui.SetCursorPosY(yPos)
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth() / 2) - 8))

            ImGui.Text("%d", mq.TLO.Target.PctAggro())
            if (mq.TLO.Target.SecondaryAggroPlayer() ~= nil) then
                ImGui.SetCursorPosY(yPos)
                ImGui.SetCursorPosX(ImGui.GetWindowWidth() - 40)
                ImGui.Text("%d", mq.TLO.Target.SecondaryPctAggro())
            end
            ImGui.EndGroup()
        else
            ImGui.Text('')
        end
        ImGui.SetWindowFontScale(1)
        ImGui.PopStyleVar()
        ImGui.EndGroup()
        if ImGui.IsItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
            if mq.TLO.Cursor() then
                MyUI_Utils.GiveItem(mq.TLO.Target.ID() or 0)
            end
        end
        --Target Buffs
        if tonumber(mq.TLO.Target.BuffCount()) > 0 then
            local windowWidth, windowHeight = ImGui.GetContentRegionAvail()
            -- Begin a scrollable child
            ImGui.BeginChild("TargetBuffsScrollRegion", ImVec2(windowWidth, windowHeight), ImGuiChildFlags.Border)
            targetBuffs(tonumber(mq.TLO.Target.BuffCount()))
            ImGui.EndChild()
            -- End the scrollable region
        end
    else
        ImGui.Text('')
    end
end

function Module.RenderGUI()
    ColorCount = 0
    StyleCount = 0
    local flags = winFlag
    -- Default window size
    ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
    ColorCount, StyleCount = DrawTheme(themeName, 'main')
    if locked then
        flags = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoScrollWithMouse)
    end
    if ShowGUI then
        local open, show = ImGui.Begin(MyUI_CharLoaded .. "##Target", true, flags)
        if not open then
            ShowGUI = false
        end
        if show then
            mouseHud = ImGui.IsWindowHovered(ImGuiHoveredFlags.ChildWindows)

            -- ImGui.BeginGroup()
            if ImGui.BeginMenuBar() then
                -- if ZoomLvl > 1.25 then ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4,7) end
                local lockedIcon = locked and MyUI_Icons.FA_LOCK .. '##lockTabButton_MyChat' or
                    MyUI_Icons.FA_UNLOCK .. '##lockTablButton_MyChat'
                if ImGui.Button(lockedIcon) then
                    --ImGuiWindowFlags.NoMove
                    locked = not locked
                    settings = dofile(configFile)
                    settings[script].locked = locked
                    mq.pickle(configFile, settings)
                end
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("Lock Window")
                end
                if ImGui.Button(gIcon .. '##PlayerTarg') then
                    openConfigGUI = not openConfigGUI
                end
                local splitIcon = splitTarget and MyUI_Icons.FA_TOGGLE_ON .. '##PtargSplit' or MyUI_Icons.FA_TOGGLE_OFF .. '##PtargSplit'
                if ImGui.Button(splitIcon) then
                    splitTarget = not splitTarget
                    settings = dofile(configFile)
                    settings[script].SplitTarget = splitTarget
                    mq.pickle(configFile, settings)
                end
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("Split Windows")
                end
                ImGui.SetCursorPosX(ImGui.GetWindowContentRegionWidth() - 10)
                if ImGui.MenuItem('X##Close' .. script) then
                    Module.IsRunning = false
                end
                ImGui.EndMenuBar()
            end

            ImGui.SetCursorPosX((ImGui.GetContentRegionAvail() / 2) - 22)
            ImGui.Dummy(iconSize - 5, iconSize - 6)
            ImGui.SameLine()
            ImGui.SetCursorPosX(5)
            -- Player Information
            -- ImGui.PushStyleVar(ImGuiStyleVar.CellPadding)
            ImGui.BeginGroup()
            local tPFlags = tPlayerFlags
            local cFlag = bit32.bor(ImGuiChildFlags.AlwaysAutoResize)
            if mq.TLO.Me.Combat() then
                if flashBorder then
                    ImGui.PushStyleColor(ImGuiCol.Border, 0.9, 0.1, 0.1, (cAlpha / 255))
                    cFlag = bit32.bor(ImGuiChildFlags.Border, cFlag)
                    tPFlags = tPlayerFlags
                else
                    ImGui.PushStyleColor(ImGuiCol.TableRowBg, 0.9, 0.1, 0.1, (cAlpha / 255))
                    tPFlags = bit32.bor(ImGuiTableFlags.RowBg, tPlayerFlags)
                    cFlag = bit32.bor(ImGuiChildFlags.AlwaysAutoResize)
                end
            else
                if flashBorder then
                    ImGui.PushStyleColor(ImGuiCol.Border, themeBorderBG[1], themeBorderBG[2], themeBorderBG[3], themeBorderBG[4])
                    cFlag = bit32.bor(ImGuiChildFlags.Border, cFlag)
                    tPFlags = tPlayerFlags
                else
                    ImGui.PushStyleColor(ImGuiCol.TableRowBg, themeRowBG[1], themeRowBG[2], themeRowBG[3], themeRowBG[4])
                    tPFlags = bit32.bor(ImGuiTableFlags.RowBg, tPlayerFlags)
                    cFlag = bit32.bor(ImGuiChildFlags.AlwaysAutoResize)
                end
            end
            ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 1, 1)
            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4, 2)
            if flashBorder then ImGui.BeginChild('pInfo##', 0, ((iconSize + 4) * FontScale), cFlag, ImGuiWindowFlags.NoScrollbar) end
            if ImGui.BeginTable("##playerInfo", 4, tPFlags) then
                ImGui.TableSetupColumn("##tName", ImGuiTableColumnFlags.NoResize, (ImGui.GetContentRegionAvail() * .5))
                ImGui.TableSetupColumn("##tVis", ImGuiTableColumnFlags.NoResize, 24)
                ImGui.TableSetupColumn("##tIcons", ImGuiTableColumnFlags.WidthStretch, 80) --ImGui.GetContentRegionAvail()*.25)
                ImGui.TableSetupColumn("##tLvl", ImGuiTableColumnFlags.NoResize, 30)
                ImGui.TableNextRow()

                -- Name

                ImGui.TableSetColumnIndex(0)
                local meName = mq.TLO.Me.DisplayName()
                ImGui.SetWindowFontScale(FontScale)
                ImGui.Text(" %s", meName)
                ImGui.SetWindowFontScale(1)
                local combatState = mq.TLO.Me.CombatState()
                if mq.TLO.Me.Poisoned() and mq.TLO.Me.Diseased() then
                    ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                    MyUI_Utils.DrawStatusIcon(2579, 'item', 'Diseased and Posioned', iconSize)
                elseif mq.TLO.Me.Poisoned() then
                    ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                    MyUI_Utils.DrawStatusIcon(42, 'spell', 'Posioned', iconSize)
                elseif mq.TLO.Me.Diseased() then
                    ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                    MyUI_Utils.DrawStatusIcon(41, 'spell', 'Diseased', iconSize)
                elseif mq.TLO.Me.Dotted() then
                    ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                    MyUI_Utils.DrawStatusIcon(5987, 'item', 'Dotted', iconSize)
                elseif mq.TLO.Me.Cursed() then
                    ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                    MyUI_Utils.DrawStatusIcon(5759, 'item', 'Cursed', iconSize)
                elseif mq.TLO.Me.Corrupted() then
                    ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                    MyUI_Utils.DrawStatusIcon(5758, 'item', 'Corrupted', iconSize)
                end
                ImGui.SameLine(ImGui.GetColumnWidth() - 25)
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
                -- Visiblity
                ImGui.TableSetColumnIndex(1)
                if mq.TLO.Target() ~= nil then
                    ImGui.SetWindowFontScale(FontScale)
                    if mq.TLO.Target.LineOfSight() then
                        ImGui.TextColored(ImVec4(0, 1, 0, 1), MyUI_Icons.MD_VISIBILITY)
                    else
                        ImGui.TextColored(ImVec4(0.9, 0, 0, 1), MyUI_Icons.MD_VISIBILITY_OFF)
                    end
                    ImGui.SetWindowFontScale(1)
                end

                -- Icons
                ImGui.TableSetColumnIndex(2)
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
                ImGui.Text('')
                if mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
                    ImGui.SameLine()
                    MyUI_Utils.DrawStatusIcon('A_Tank', 'pwcs', 'Main Tank', iconSize)
                end
                if mq.TLO.Group.MainAssist.ID() == mq.TLO.Me.ID() then
                    ImGui.SameLine()
                    MyUI_Utils.DrawStatusIcon('A_Assist', 'pwcs', 'Main Assist', iconSize)
                end
                if mq.TLO.Group.Puller.ID() == mq.TLO.Me.ID() then
                    ImGui.SameLine()
                    MyUI_Utils.DrawStatusIcon('A_Puller', 'pwcs', 'Puller', iconSize)
                end
                ImGui.SameLine()
                --  ImGui.SameLine()
                ImGui.Text(' ')
                ImGui.SameLine()
                ImGui.SetWindowFontScale(FontScale)
                ImGui.Text(mq.TLO.Me.Heading() or '??')
                ImGui.PopStyleVar()
                -- Lvl
                ImGui.TableSetColumnIndex(3)
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 2, 0)

                ImGui.Text(tostring(mq.TLO.Me.Level() or 0))
                ImGui.SetWindowFontScale(1)
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip(GetInfoToolTip())
                end
                ImGui.PopStyleVar()
                ImGui.EndTable()
            end
            if flashBorder then ImGui.EndChild() end
            ImGui.PopStyleColor()
            ImGui.PopStyleVar()
            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4, 3)

            ImGui.Separator()
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 8, 1)
            -- My Health Bar
            local yPos = ImGui.GetCursorPosY()

            if settings[script].DynamicHP then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Utils.CalculateColor(colorHpMin, colorHpMax, mq.TLO.Me.PctHPs())))
            else
                if mq.TLO.Me.PctHPs() <= 0 then
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Colors.color('purple')))
                elseif mq.TLO.Me.PctHPs() < 15 then
                    if pulse then
                        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Colors.color('orange')))
                        if not mq.TLO.Me.CombatState() == 'COMBAT' then pulse = false end
                    else
                        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Colors.color('red')))
                        if not mq.TLO.Me.CombatState() == 'COMBAT' then pulse = true end
                    end
                else
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Colors.color('red')))
                end
            end
            ImGui.ProgressBar(((tonumber(mq.TLO.Me.PctHPs() or 0)) / 100), ImGui.GetContentRegionAvail(), progressSize, '##pctHps')
            ImGui.PopStyleColor()
            ImGui.SetCursorPosY(yPos - 1)
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth() / 2) - 8))
            ImGui.SetWindowFontScale(FontScale)
            ImGui.Text(tostring(mq.TLO.Me.PctHPs() or 0))
            ImGui.SetWindowFontScale(1)
            local yPos = ImGui.GetCursorPosY()
            --My Mana Bar
            if (tonumber(mq.TLO.Me.MaxMana()) > 0) then
                if settings[script].DynamicMP then
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Utils.CalculateColor(colorMpMin, colorMpMax, mq.TLO.Me.PctMana())))
                else
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Colors.color('light blue2')))
                end
                ImGui.ProgressBar(((tonumber(mq.TLO.Me.PctMana() or 0)) / 100), ImGui.GetContentRegionAvail(), progressSize, '##pctMana')
                ImGui.PopStyleColor()
                ImGui.SetCursorPosY(yPos - 1)
                ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth() / 2) - 8))
                ImGui.SetWindowFontScale(FontScale)
                ImGui.Text(tostring(mq.TLO.Me.PctMana() or 0))
                ImGui.SetWindowFontScale(1)
            end
            local yPos = ImGui.GetCursorPosY()
            --My Endurance bar
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Colors.color('yellow2')))
            ImGui.ProgressBar(((tonumber(mq.TLO.Me.PctEndurance() or 0)) / 100), ImGui.GetContentRegionAvail(), progressSize, '##pctEndurance')
            ImGui.PopStyleColor()
            ImGui.SetCursorPosY(yPos - 1)
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth() / 2) - 8))
            ImGui.SetWindowFontScale(FontScale)
            ImGui.Text(tostring(mq.TLO.Me.PctEndurance() or 0))
            ImGui.SetWindowFontScale(1)
            ImGui.Separator()
            ImGui.EndGroup()
            if ImGui.IsItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                if mq.TLO.Cursor() then
                    mq.cmd("/autoinventory")
                end
                mq.cmdf("/target %s", mq.TLO.Me())
            end
            ImGui.PopStyleVar()
            --Target Info
            if not splitTarget then
                drawTarget()
            end
            ImGui.PopStyleVar(2)
        end
        if StyleCount > 0 then ImGui.PopStyleVar(StyleCount) end
        if ColorCount > 0 then ImGui.PopStyleColor(ColorCount) end

        ImGui.End()
    end

    if splitTarget and mq.TLO.Target() ~= nil then
        local colorCountTarget, styleCountTarget = DrawTheme(themeName, 'targ')
        local tmpFlag = targFlag
        if locked then tmpFlag = bit32.bor(targFlag, ImGuiWindowFlags.NoMove) end
        local openT, showT = ImGui.Begin("Target##TargetPopout" .. MyUI_CharLoaded, true, tmpFlag)
        if showT then
            if ImGui.IsWindowHovered(ImGuiHoveredFlags.ChildWindows) then
                mouseHudTarg = true
            else
                mouseHudTarg = false
            end
            ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 1, 1)
            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4, 2)
            drawTarget()
            ImGui.PopStyleVar(2)
        end

        if styleCountTarget > 0 then ImGui.PopStyleVar(styleCountTarget) end
        if colorCountTarget > 0 then ImGui.PopStyleColor(colorCountTarget) end

        ImGui.End()
    end

    if enableBreathBar and breathBarShow then
        local bFlags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse, ImGuiWindowFlags.NoFocusOnAppearing)
        if bLocked then bFlags = bit32.bor(bFlags, ImGuiWindowFlags.NoMove) end
        if not showTitleBreath then bFlags = bit32.bor(bFlags, ImGuiWindowFlags.NoTitleBar) end


        local ColorCountBreath, StyleCountBreath = DrawTheme(themeName, 'breath')
        ImGui.SetNextWindowSize(ImVec2(150, 55), ImGuiCond.FirstUseEver)
        ImGui.SetNextWindowPos(ImGui.GetMousePosVec(), ImGuiCond.FirstUseEver)
        local openBreath, showBreath = ImGui.Begin('Breath##MyBreathWin_' .. MyUI_CharLoaded, true, bFlags)
        if not openBreath then
            breathBarShow = false
        end
        if showBreath then
            ImGui.SetWindowFontScale(FontScale)

            local yPos = ImGui.GetCursorPosY()
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (MyUI_Utils.CalculateColor(colorBreathMin, colorBreathMax, breathPct)))
            ImGui.ProgressBar((breathPct / 100), ImGui.GetContentRegionAvail(), progressSize, '##pctBreath')
            ImGui.PopStyleColor()
            if ImGui.BeginPopupContextItem("##MySpells_CastWin") then
                local lockLabel = bLocked and 'Unlock' or 'Lock'
                if ImGui.MenuItem(lockLabel .. "##Breath") then
                    bLocked = not bLocked

                    settings[script].BreathLocked = bLocked
                    mq.pickle(configFile, settings)
                end
                ImGui.EndPopup()
            end
            ImGui.SetWindowFontScale(1)
        end
        if StyleCountBreath > 0 then ImGui.PopStyleVar(StyleCountBreath) end
        if ColorCountBreath > 0 then ImGui.PopStyleColor(ColorCountBreath) end
        ImGui.End()
    end

    if openConfigGUI then
        PlayerTargConf_GUI()
    end
end

--Setup and Loop
function Module.Unload()
    return
end

local function init()
    Module.IsRunning = true
    loadSettings()
    if not loadedExeternally then
        mq.imgui.init('GUI_Target', Module.RenderGUI)
        Module.LocalLoop()
    end
end

local clockTimer = mq.gettime()

function Module.MainLoop()
    if loadedExeternally then
        ---@diagnostic disable-next-line: undefined-global
        if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
    end

    local timeDiff = mq.gettime() - clockTimer
    if timeDiff > 10 then
        pulseIcon(pulseSpeed)
        pulseCombat(combatPulseSpeed)

        ---@diagnostic disable-next-line: undefined-field
        breathPct = mq.TLO.Me.PctAirSupply() or 100
        if breathPct < 100 then
            breathBarShow = true
        else
            breathBarShow = false
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
    printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", script)
    mq.exit()
end

init()
return Module
