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
    Module.Utils = require('lib.common')
    Module.Icons = require('mq.ICONS')
    Module.Colors = require('lib.colors')
    Module.CharLoaded = mq.TLO.Me.DisplayName()
    Module.Server = mq.TLO.MacroQuest.Server()
    Module.ThemeFile = string.format('%s/MyUI/ThemeZ.lua', mq.configDir)
    Module.Theme = {}
    Module.ThemeLoader = require('lib.theme_loader')
else
    Module.Utils = MyUI_Utils
    Module.Icons = MyUI_Icons
    Module.Colors = MyUI_Colors
    Module.CharLoaded = MyUI_CharLoaded
    Module.Server = MyUI_Server
    Module.ThemeFile = MyUI_ThemeFile
    Module.Theme = MyUI_Theme
    Module.ThemeLoader = MyUI_ThemeLoader
end
local Utils                                         = Module.Utils
local ToggleFlags                                   = bit32.bor(
    Utils.ImGuiToggleFlags.PulseOnHover,
    --Utils.ImGuiToggleFlags.SmilyKnob,
    --Utils.ImGuiToggleFlags.GlowOnHover,
    Utils.ImGuiToggleFlags.KnobBorder,
    --Utils.ImGuiToggleFlags.StarKnob,
    Utils.ImGuiToggleFlags.AnimateOnHover,
    Utils.ImGuiToggleFlags.RightLabel
)
local gIcon                                         = Module.Icons.MD_SETTINGS
-- set variables
local pulse                                         = true
local iconSize, progressSize                        = 26, 10
local flashAlpha, FontScale, cAlpha                 = 1, 1, 255
local ShowGUI, locked, flashBorder, rise, cRise     = true, false, true, true, false
local openConfigGUI, openGUI                        = false, true
local configFileOld                                 = mq.configDir .. '/Module.Configs.lua'
local configFile                                    = string.format('%s/MyUI/PlayerTarg/%s/%s.lua', mq.configDir, Module.Server, Module.CharLoaded)
local themeName                                     = 'Default'
local pulseSpeed                                    = 5
local combatPulseSpeed                              = 10
local colorHpMax                                    = { 0.992, 0.138, 0.138, 1.000, }
local colorHpMin                                    = { 0.551, 0.207, 0.962, 1.000, }
local colorMpMax                                    = { 0.231, 0.707, 0.938, 1.000, }
local colorMpMin                                    = { 0.600, 0.231, 0.938, 1.000, }
local colorBreathMin                                = { 0.600, 0.231, 0.938, 1.000, }
local colorBreathMax                                = { 0.231, 0.707, 0.938, 1.000, }
local targetTextColor                               = { 1, 1, 1, 1, }
local testValue, testValue2                         = 100, 100
local splitTarget                                   = false
local mouseHud, mouseHudTarg                        = false, false
local ProgressSizeTarget                            = 30
local showTitleBreath                               = false
local bLocked                                       = false
local breathBarShow                                 = false
local enableBreathBar                               = false
local breathPct                                     = 100
local haveAggroColor, noAggroColor
-- Flags

local tPlayerFlags                                  = bit32.bor(ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.NoPadInnerX,
    ImGuiTableFlags.NoPadOuterX, ImGuiTableFlags.Resizable, ImGuiTableFlags.SizingFixedFit)
local winFlag                                       = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoScrollbar,
    ImGuiWindowFlags.NoScrollWithMouse)
local targFlag                                      = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse)

--Tables

local defaults, settings, themeRowBG, themeBorderBG = {}, {}, {}, {}
themeRowBG                                          = { 1, 1, 1, 0, }
themeBorderBG                                       = { 1, 1, 1, 1, }

defaults                                            = {
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
    TargetTextColor = { 1, 1, 1, 1, },
    NoAggroColor = { 0.8, 0.0, 1.0, 1.0, },
    HaveAggroColor = { 0.78, 0.20, 0.05, 0.8, },
    ShowToT = false,
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
    if Module.Utils.File.Exists(Module.ThemeFile) then
        Module.Theme = dofile(Module.ThemeFile)
    else
        Module.Theme = require('defaults.themes')
    end
end

local function loadSettings()
    if not Module.Utils.File.Exists(configFile) then
        if Module.Utils.File.Exists(configFileOld) then
            local tmpOld = {}
            tmpOld = dofile(configFileOld)
            for k, v in pairs(tmpOld) do
                if k == Module.Name then
                    settings[Module.Name] = v
                end
            end
            mq.pickle(configFile, settings)
        else
            settings[Module.Name] = {}
            settings[Module.Name] = defaults
            mq.pickle(configFile, settings)
        end
    else
        -- Load settings from the Lua config file
        settings = dofile(configFile)
        if not settings[Module.Name] then
            settings[Module.Name] = {}
            settings[Module.Name] = defaults
        end
    end
    if not loadedExeternally then
        loadTheme()
    end
    local newSetting = false

    newSetting = Module.Utils.CheckDefaultSettings(defaults, settings[Module.Name]) or newSetting

    if settings[Module.Name].iconSize ~= nil then
        settings[Module.Name].IconSize = settings[Module.Name].iconSize
        settings[Module.Name].iconSize = nil
        newSetting = true
    end

    colorBreathMin = settings[Module.Name].ColorBreathMin
    colorBreathMax = settings[Module.Name].ColorBreathMax
    showTitleBreath = settings[Module.Name].ShowTitleBreath
    bLocked = settings[Module.Name].BreathLocked
    enableBreathBar = settings[Module.Name].EnableBreathBar
    splitTarget = settings[Module.Name].SplitTarget
    colorHpMax = settings[Module.Name].ColorHPMax
    colorHpMin = settings[Module.Name].ColorHPMin
    colorMpMax = settings[Module.Name].ColorMPMax
    colorMpMin = settings[Module.Name].ColorMPMin
    combatPulseSpeed = settings[Module.Name].combatPulseSpeed
    pulseSpeed = settings[Module.Name].pulseSpeed
    pulse = settings[Module.Name].doPulse
    flashBorder = settings[Module.Name].FlashBorder
    progressSize = settings[Module.Name].ProgressSize
    iconSize = settings[Module.Name].IconSize
    locked = settings[Module.Name].locked
    FontScale = settings[Module.Name].Scale
    themeName = settings[Module.Name].LoadTheme
    ProgressSizeTarget = settings[Module.Name].ProgressSizeTarget
    targetTextColor = settings[Module.Name].TargetTextColor
    noAggroColor = settings[Module.Name].NoAggroColor
    haveAggroColor = settings[Module.Name].HaveAggroColor

    if newSetting then mq.pickle(configFile, settings) end
end

local function pulseGeneric(speed, alpha, rising, lastTime, frameTime, maxAlpha, minAlpha)
    if speed == 0 then return alpha, rising, lastTime end
    local currentTime = mq.gettime()
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

local lastTime, lastTimeCombat = mq.gettime(), mq.gettime()
local frameTime, frameTimeCombat = 33, 16
local function pulseIcon(speed)
    flashAlpha, rise, lastTime = pulseGeneric(speed, flashAlpha, rise, lastTime, frameTime, 200, 10)
    if speed == 0 then flashAlpha = 0 end
end

local function pulseCombat(speed)
    cAlpha, cRise, lastTimeCombat = pulseGeneric(speed, cAlpha, cRise, lastTimeCombat, frameTimeCombat, 250, 10)
    if speed == 0 then cAlpha = 255 end
end


---comment
---@param tName string -- name of the Module.Theme to load form table
---@param window string -- name of the window to apply the Module.Theme to
---@return integer, integer -- returns the new counter values
local function DrawTheme(tName, window)
    local StyleCounter = 0
    local ColorCounter = 0
    for tID, tData in pairs(Module.Theme.Theme) do
        if tData.Name == tName then
            for pID, cData in pairs(Module.Theme.Theme[tID].Color) do
                if window == 'main' then
                    if cData.PropertyName == 'Border' then
                        themeBorderBG = { cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4], }
                    elseif cData.PropertyName == 'TableRowBg' then
                        themeRowBG = { cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4], }
                    elseif cData.PropertyName == 'WindowBg' then
                        if not settings[Module.Name].MouseOver then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], settings[Module.Name].WinTransparency))
                            ColorCounter = ColorCounter + 1
                        elseif settings[Module.Name].MouseOver and mouseHud then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], 1.0))
                            ColorCounter = ColorCounter + 1
                        elseif settings[Module.Name].MouseOver and not mouseHud then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], settings[Module.Name].WinTransparency))
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
                        if not settings[Module.Name].MouseOver then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], settings[Module.Name].WinTransparency))
                            ColorCounter = ColorCounter + 1
                        elseif settings[Module.Name].MouseOver and mouseHudTarg then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], 1.0))
                            ColorCounter = ColorCounter + 1
                        elseif settings[Module.Name].MouseOver and not mouseHudTarg then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], settings[Module.Name].WinTransparency))
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
                    for sID, sData in pairs(Module.Theme.Theme[tID].Style) do
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
    Module.Utils.Animation_Spell:SetTextureCell(iconID or 0)
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
        ImGui.DrawTextureAnimation(Module.Utils.Animation_Spell, iconSize - 6, iconSize - 6, true)
    else
        ImGui.DrawTextureAnimation(Module.Utils.Animation_Spell, iconSize - 5, iconSize - 5)
    end
    ImGui.SetCursorPos(cursor_x + 2, cursor_y + 2)
    local sName = spell.Name() or '??'
    local sDur = spell.Duration.TotalSeconds() or 0
    ImGui.PushID(string.format("%s_%s_%s_invis_btn", iconID, sName, i))
    if sDur < 18 and sDur > 0 and pulse then
        local flashColor = IM_COL32(0, 0, 0, flashAlpha)
        ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
            ImGui.GetCursorScreenPosVec() + iconSize - 4, flashColor)
    end
    ImGui.SetCursorPos(cursor_x, cursor_y)
    local target = mq.TLO.Target
    ImGui.InvisibleButton(sName, ImVec2(iconSize, iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
    if ImGui.IsItemHovered() then
        if (ImGui.IsMouseReleased(1)) then
            spell.Inspect()
        end
        if ImGui.BeginTooltip() then
            ImGui.TextColored(Module.Colors.color('yellow'), '%s', sName)
            ImGui.TextColored(Module.Colors.color('green'), '%s', target.Buff(i).Duration.TimeHMS() or '')
            ImGui.Text('Cast By: ')
            ImGui.SameLine()
            ImGui.TextColored(Module.Colors.color('light blue'), '%s', caster)
            ImGui.EndTooltip()
        end
    end
    ImGui.PopID()
end

local function targetBuffs(count)
    local target = mq.TLO.Target
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
    if target.BuffCount() ~= nil then
        for i = 1, count do
            local sIcon = target.Buff(i).SpellIcon() or 0
            if target.Buff(i) ~= nil then
                DrawInspectableSpellIcon(sIcon, target.Buff(i), i)
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

function Module.RenderTargetOfTarget()
    if not mq.TLO.Target.AggroHolder() then return end
    if not settings[Module.Name].ShowToT then return end

    ImGui.SetNextWindowSize(250, 100, ImGuiCond.FirstUseEver)
    local openTot, drawToT = ImGui.Begin("Target of Target##" .. Module.Name, true)
    if drawToT then
        ImGui.SetWindowFontScale(FontScale)
        local tot = mq.TLO.Target.AggroHolder
        if tot() then
            ImGui.Text(tot.CleanName() or '?')
            if settings[Module.Name].DynamicHP then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Utils.CalculateColor(colorHpMin, colorHpMax, tot.PctHPs())))
            else
                if tot.PctHPs() < 25 then
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('orange')))
                else
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('red')))
                end
            end
            local yPos = ImGui.GetCursorPosY() - 2
            ImGui.ProgressBar(((tonumber(tot.PctHPs() or 0)) / 100), ImGui.GetContentRegionAvail(), ProgressSizeTarget, '##' .. tot.PctHPs())
            ImGui.PopStyleColor()
            ImGui.SetCursorPosY(yPos)
            ImGui.SetCursorPosX((ImGui.GetContentRegionAvail() - (ImGui.CalcTextSize("HP: 1000") * 0.5)) * 0.5)
            ImGui.Text("HP: %d%%", tot.PctHPs() or 0)
        end
    end
    ImGui.End()
end

-- GUI
local function PlayerTargConf_GUI()
    if not openConfigGUI then return end

    local ColorCountConf, StyleCountConf = Module.ThemeLoader.StartTheme(themeName, Module.Theme)
    local open, showConfigGUI = ImGui.Begin("PlayerTarg Conf##" .. Module.Name, true,
        bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.AlwaysAutoResize))

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
            settings[Module.Name].FlashBorder = flashBorder
            settings[Module.Name].ProgressSize = progressSize
            settings[Module.Name].Scale = FontScale
            settings[Module.Name].IconSize = iconSize
            settings[Module.Name].LoadTheme = themeName
        end
        ImGui.PopStyleColor()

        if ImGui.CollapsingHeader("Theme##" .. Module.Name) then
            ImGui.Text("Cur Theme: %s", themeName)
            -- Combo Box Load Theme
            if ImGui.BeginCombo("Load Theme##" .. Module.Name, themeName) then
                for k, data in pairs(Module.Theme.Theme) do
                    local isSelected = data.Name == themeName
                    if ImGui.Selectable(data.Name, isSelected) then
                        if settings[Module.Name].LoadTheme ~= data.Name then
                            themeName = data.Name
                            settings[Module.Name].LoadTheme = themeName
                            mq.pickle(configFile, settings)
                        end
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
        end
        ImGui.Spacing()
        if ImGui.CollapsingHeader("Scaling##" .. Module.Name) then
            -- Slider for adjusting zoom level
            local tmpZoom = FontScale
            if FontScale then
                tmpZoom = ImGui.SliderFloat("Text Scale##" .. Module.Name, tmpZoom, 0.5, 2.0)
            end
            if FontScale ~= tmpZoom then
                FontScale = tmpZoom
            end
            -- Slider for adjusting Icon Size
            local tmpSize = iconSize
            if iconSize then
                tmpSize = ImGui.SliderInt("Icon Size##" .. Module.Name, tmpSize, 15, 50)
            end
            if iconSize ~= tmpSize then
                iconSize = tmpSize
            end

            -- Slider for adjusting Progress Bar Size
            local tmpPrgSz = progressSize
            if progressSize then
                tmpPrgSz = ImGui.SliderInt("Progress Bar Size##" .. Module.Name, tmpPrgSz, 5, 50)
            end
            if progressSize ~= tmpPrgSz then
                progressSize = tmpPrgSz
            end
            ProgressSizeTarget = ImGui.SliderInt("Target Progress Bar Size##" .. Module.Name, ProgressSizeTarget, 5, 150)
            settings[Module.Name].showXtar = Module.Utils.DrawToggle('Show XTarget Number', settings[Module.Name].showXtar, ToggleFlags)
        end
        ImGui.Spacing()

        if ImGui.CollapsingHeader("Pulse Settings##" .. Module.Name) then
            flashBorder = Module.Utils.DrawToggle('Flash Border', flashBorder, ToggleFlags)
            ImGui.SameLine()
            local tmpPulse = pulse
            tmpPulse, _ = Module.Utils.DrawToggle('Pulse Icons', tmpPulse, ToggleFlags)
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
                tmpSpeed = ImGui.SliderInt('Icon Pulse Speed##' .. Module.Name, tmpSpeed, 0, 50)
                if pulseSpeed ~= tmpSpeed then
                    pulseSpeed = tmpSpeed
                end
            end
            local tmpCmbtSpeed = combatPulseSpeed
            tmpCmbtSpeed = ImGui.SliderInt('Combat Pulse Speed##' .. Module.Name, tmpCmbtSpeed, 0, 50)
            if combatPulseSpeed ~= tmpCmbtSpeed then
                combatPulseSpeed = tmpCmbtSpeed
            end
        end
        ImGui.Spacing()

        if ImGui.CollapsingHeader("Dynamic Bar Colors##" .. Module.Name) then
            settings[Module.Name].DynamicHP = Module.Utils.DrawToggle('Dynamic HP Bar', settings[Module.Name].DynamicHP, ToggleFlags)
            ImGui.SameLine()
            ImGui.SetNextItemWidth(60)
            colorHpMin = ImGui.ColorEdit4("HP Min Color##" .. Module.Name, colorHpMin, bit32.bor(ImGuiColorEditFlags.AlphaBar, ImGuiColorEditFlags.NoInputs))
            ImGui.SameLine()
            ImGui.SetNextItemWidth(60)
            colorHpMax = ImGui.ColorEdit4("HP Max Color##" .. Module.Name, colorHpMax, bit32.bor(ImGuiColorEditFlags.AlphaBar, ImGuiColorEditFlags.NoInputs))

            testValue = ImGui.SliderInt("Test HP##" .. Module.Name, testValue, 0, 100)

            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Utils.CalculateColor(colorHpMin, colorHpMax, testValue)))
            ImGui.ProgressBar((testValue / 100), ImGui.GetContentRegionAvail(), progressSize, '##Test')
            ImGui.PopStyleColor()

            settings[Module.Name].DynamicMP = Module.Utils.DrawToggle('Dynamic Mana Bar', settings[Module.Name].DynamicMP, ToggleFlags)
            ImGui.SameLine()
            ImGui.SetNextItemWidth(60)
            colorMpMin = ImGui.ColorEdit4("Mana Min Color##" .. Module.Name, colorMpMin, bit32.bor(ImGuiColorEditFlags.NoInputs))
            ImGui.SameLine()
            ImGui.SetNextItemWidth(60)
            colorMpMax = ImGui.ColorEdit4("Mana Max Color##" .. Module.Name, colorMpMax, bit32.bor(ImGuiColorEditFlags.NoInputs))

            testValue2 = ImGui.SliderInt("Test MP##" .. Module.Name, testValue2, 0, 100)
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Utils.CalculateColor(colorMpMin, colorMpMax, testValue2)))
            ImGui.ProgressBar((testValue2 / 100), ImGui.GetContentRegionAvail(), progressSize, '##Test2')
            ImGui.PopStyleColor()
        end

        ImGui.Spacing()

        targetTextColor = ImGui.ColorEdit4("Target Text Color##" .. Module.Name, targetTextColor, bit32.bor(ImGuiColorEditFlags.NoInputs))

        ImGui.Spacing()

        haveAggroColor = ImGui.ColorEdit4("Have Aggro Color##" .. Module.Name, haveAggroColor, bit32.bor(ImGuiColorEditFlags.NoInputs))

        ImGui.Spacing()

        noAggroColor = ImGui.ColorEdit4("Don't Have Aggrp Color##" .. Module.Name, noAggroColor, bit32.bor(ImGuiColorEditFlags.NoInputs))

        ImGui.Spacing()

        settings[Module.Name].ShowToT = Module.Utils.DrawToggle('Show Target of Target', settings[Module.Name].ShowToT, ToggleFlags)
        ImGui.Spacing()
        -- breath bar settings
        if ImGui.CollapsingHeader("Breath Meter##" .. Module.Name) then
            local tmpbreath = settings[Module.Name].EnableBreathBar
            tmpbreath = Module.Utils.DrawToggle('Enable Breath', tmpbreath, ToggleFlags)
            if tmpbreath ~= settings[Module.Name].EnableBreathBar then
                settings[Module.Name].EnableBreathBar = tmpbreath
            end
            ImGui.SameLine()
            ImGui.SetNextItemWidth(60)
            colorBreathMin = ImGui.ColorEdit4("Breath Min Color##" .. Module.Name, colorBreathMin, bit32.bor(ImGuiColorEditFlags.NoInputs))
            ImGui.SameLine()
            ImGui.SetNextItemWidth(60)
            colorBreathMax = ImGui.ColorEdit4("Breath Max Color##" .. Module.Name, colorBreathMax, bit32.bor(ImGuiColorEditFlags.NoInputs))
            local testValue3 = 100
            testValue3 = ImGui.SliderInt("Test Breath##" .. Module.Name, testValue3, 0, 100)
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Utils.CalculateColor(colorBreathMin, colorBreathMax, testValue3)))
            ImGui.ProgressBar((testValue3 / 100), ImGui.GetContentRegionAvail(), progressSize, '##Test3')
            ImGui.PopStyleColor()
        end
        ImGui.Spacing()

        if ImGui.Button('Save and Close##' .. Module.Name) then
            openConfigGUI = false
            settings[Module.Name].ColorBreathMin = colorBreathMin
            settings[Module.Name].ColorBreathMax = colorBreathMax
            settings[Module.Name].ProgressSizeTarget = ProgressSizeTarget
            settings[Module.Name].ColorHPMax = colorHpMax
            settings[Module.Name].ColorHPMin = colorHpMin
            settings[Module.Name].ColorMPMax = colorMpMax
            settings[Module.Name].ColorMPMin = colorMpMin
            settings[Module.Name].FlashBorder = flashBorder
            settings[Module.Name].ProgressSize = progressSize
            settings[Module.Name].Scale = FontScale
            settings[Module.Name].IconSize = iconSize
            settings[Module.Name].LoadTheme = themeName
            settings[Module.Name].doPulse = pulse
            settings[Module.Name].pulseSpeed = pulseSpeed
            settings[Module.Name].combatPulseSpeed = combatPulseSpeed
            settings[Module.Name].TargetTextColor = targetTextColor
            settings[Module.Name].NoAggroColor = noAggroColor
            settings[Module.Name].HaveAggroColor = haveAggroColor
            mq.pickle(configFile, settings)
        end
    end

    Module.ThemeLoader.EndTheme(ColorCountConf, StyleCountConf)
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
    local target = mq.TLO.Target
    if (target() ~= nil) then
        ImGui.BeginGroup()
        ImGui.SetWindowFontScale(FontScale)
        local targetName = target.CleanName() or '?'
        local xSlot = findXTarSlot(target.ID()) or 0
        local tC = Module.Utils.GetConColor(target) or "WHITE"
        if tC == 'red' then tC = 'pink' end
        local tClass = target.Class.ShortName() == 'UNKNOWN CLASS' and Module.Icons.MD_HELP_OUTLINE or
            target.Class.ShortName()
        local tLvl = target.Level() or 0
        local tBodyType = target.Body.Name() or '?'
        --Target Health Bar
        ImGui.BeginGroup()
        if settings[Module.Name].DynamicHP then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Utils.CalculateColor(colorHpMin, colorHpMax, target.PctHPs())))
        else
            if target.PctHPs() < 25 then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('orange')))
            else
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('red')))
            end
        end
        local yPos = ImGui.GetCursorPosY() - 2
        ImGui.ProgressBar(((tonumber(target.PctHPs() or 0)) / 100), ImGui.GetContentRegionAvail(), ProgressSizeTarget, '##' .. target.PctHPs())
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

            if xSlot > 0 and settings[Module.Name].showXtar then
                ImGui.TextColored(ImVec4(targetTextColor[1], targetTextColor[2], targetTextColor[3], targetTextColor[4]), "X#%s %s", xSlot, targetName)
            else
                ImGui.TextColored(ImVec4(targetTextColor[1], targetTextColor[2], targetTextColor[3], targetTextColor[4]), "%s", targetName)
            end
            -- Distance in the second column
            ImGui.TableSetColumnIndex(1)

            ImGui.PushStyleColor(ImGuiCol.Text, Module.Colors.color(tC))
            if tC == 'pink' then
                ImGui.Text('   ' .. Module.Icons.MD_WARNING)
            else
                ImGui.Text('   ' .. Module.Icons.MD_LENS)
            end
            ImGui.PopStyleColor()

            ImGui.SameLine(ImGui.GetColumnWidth() - 35)
            ImGui.PushStyleColor(ImGuiCol.Text, Module.Colors.color('yellow'))

            ImGui.Text(tostring(math.floor(target.Distance() or 0)) .. 'm')
            ImGui.PopStyleColor()
            -- Second Row: Class, Level, and Aggro%
            ImGui.TableNextRow()
            ImGui.TableSetColumnIndex(0) -- Class and Level in the first column

            ImGui.TextColored(ImVec4(targetTextColor[1], targetTextColor[2], targetTextColor[3], targetTextColor[4]), tostring(tLvl) .. ' ' .. tClass .. '\t' .. tBodyType)
            -- Aggro% text in the second column
            ImGui.TableSetColumnIndex(1)

            ImGui.TextColored(ImVec4(targetTextColor[1], targetTextColor[2], targetTextColor[3], targetTextColor[4]), tostring(target.PctHPs()) .. '%')
            ImGui.EndTable()
        end
        ImGui.EndGroup()

        ImGui.Separator()
        --Aggro % Bar
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 8, 1)
        if (target.Aggressive) then
            yPos = ImGui.GetCursorPosY() - 2
            ImGui.BeginGroup()
            if target.PctAggro() < 100 then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(noAggroColor[1], noAggroColor[2], noAggroColor[3], noAggroColor[4]))
            else
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(haveAggroColor[1], haveAggroColor[2], haveAggroColor[3], haveAggroColor[4]))
            end
            ImGui.ProgressBar(((tonumber(target.PctAggro() or 0)) / 100), ImGui.GetContentRegionAvail(), progressSize,
                '##pctAggro')
            ImGui.PopStyleColor()
            --Secondary Aggro Person

            if (target.SecondaryAggroPlayer() ~= nil) then
                ImGui.SetCursorPosY(yPos)
                ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 5)
                ImGui.Text("%s", target.SecondaryAggroPlayer())
            end
            --Aggro % Label middle of bar
            ImGui.SetCursorPosY(yPos)
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth() / 2) - 8))

            ImGui.TextColored(ImVec4(targetTextColor[1], targetTextColor[2], targetTextColor[3], targetTextColor[4]), "%d", target.PctAggro())
            if (target.SecondaryAggroPlayer() ~= nil) then
                ImGui.SetCursorPosY(yPos)
                ImGui.SetCursorPosX(ImGui.GetWindowWidth() - 40)
                ImGui.Text("%d", target.SecondaryPctAggro())
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
                target.LeftClick()
                -- Module.Utils.GiveItem(target.ID() or 0)
            end
        end
        --Target Buffs
        if tonumber(target.BuffCount()) > 0 then
            local windowWidth, windowHeight = ImGui.GetContentRegionAvail()
            -- Begin a scrollable child
            ImGui.BeginChild("TargetBuffsScrollRegion", ImVec2(windowWidth, windowHeight), ImGuiChildFlags.Border)
            targetBuffs(tonumber(target.BuffCount()))
            ImGui.EndChild()
            -- End the scrollable region
        end
    else
        ImGui.Text('')
    end
end

function Module.RenderGUI()
    local flags = winFlag
    -- Default window size
    local target = mq.TLO.Target
    ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
    local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(themeName, Module.Theme, settings[Module.Name].MouseOver, mouseHud, settings[Module.Name].WinTransparency)
    if locked then
        flags = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoScrollWithMouse)
    end
    if ShowGUI then
        local open, show = ImGui.Begin(Module.CharLoaded .. "##Target", true, flags)
        if not open then
            ShowGUI = false
        end
        if show then
            mouseHud = ImGui.IsWindowHovered(ImGuiHoveredFlags.ChildWindows)
            pulseIcon(pulseSpeed)
            pulseCombat(combatPulseSpeed)

            -- ImGui.BeginGroup()
            if ImGui.BeginMenuBar() then
                -- if ZoomLvl > 1.25 then ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4,7) end
                local lockedIcon = locked and Module.Icons.FA_LOCK .. '##lockTabButton_MyChat' or
                    Module.Icons.FA_UNLOCK .. '##lockTablButton_MyChat'
                if ImGui.Button(lockedIcon) then
                    --ImGuiWindowFlags.NoMove
                    locked = not locked
                    settings = dofile(configFile)
                    settings[Module.Name].locked = locked
                    mq.pickle(configFile, settings)
                end
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("Lock Window")
                end
                if ImGui.Button(gIcon .. '##PlayerTarg') then
                    openConfigGUI = not openConfigGUI
                end
                local splitIcon = splitTarget and Module.Icons.FA_TOGGLE_ON .. '##PtargSplit' or Module.Icons.FA_TOGGLE_OFF .. '##PtargSplit'
                if ImGui.Button(splitIcon) then
                    splitTarget = not splitTarget
                    settings = dofile(configFile)
                    settings[Module.Name].SplitTarget = splitTarget
                    mq.pickle(configFile, settings)
                end
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("Split Windows")
                end
                ImGui.SetCursorPosX(ImGui.GetWindowContentRegionWidth() - 10)
                if ImGui.MenuItem('X##Close' .. Module.Name) then
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
                    Module.Utils.DrawStatusIcon(2579, 'item', 'Diseased and Posioned', iconSize)
                elseif mq.TLO.Me.Poisoned() then
                    ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                    Module.Utils.DrawStatusIcon(42, 'spell', 'Posioned', iconSize)
                elseif mq.TLO.Me.Diseased() then
                    ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                    Module.Utils.DrawStatusIcon(41, 'spell', 'Diseased', iconSize)
                elseif mq.TLO.Me.Dotted() then
                    ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                    Module.Utils.DrawStatusIcon(5987, 'item', 'Dotted', iconSize)
                elseif mq.TLO.Me.Cursed() then
                    ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                    Module.Utils.DrawStatusIcon(5759, 'item', 'Cursed', iconSize)
                elseif mq.TLO.Me.Corrupted() then
                    ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                    Module.Utils.DrawStatusIcon(5758, 'item', 'Corrupted', iconSize)
                end
                ImGui.SameLine(ImGui.GetColumnWidth() - 25)
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
                -- Visiblity
                ImGui.TableSetColumnIndex(1)
                if target() ~= nil then
                    ImGui.SetWindowFontScale(FontScale)
                    if target.LineOfSight() then
                        ImGui.TextColored(ImVec4(0, 1, 0, 1), Module.Icons.MD_VISIBILITY)
                    else
                        ImGui.TextColored(ImVec4(0.9, 0, 0, 1), Module.Icons.MD_VISIBILITY_OFF)
                    end
                    ImGui.SetWindowFontScale(1)
                end

                -- Icons
                ImGui.TableSetColumnIndex(2)
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
                ImGui.Text('')
                if mq.TLO.Group.MainTank.ID() == mq.TLO.Me.ID() then
                    ImGui.SameLine()
                    Module.Utils.DrawStatusIcon('A_Tank', 'pwcs', 'Main Tank', iconSize)
                end
                if mq.TLO.Group.MainAssist.ID() == mq.TLO.Me.ID() then
                    ImGui.SameLine()
                    Module.Utils.DrawStatusIcon('A_Assist', 'pwcs', 'Main Assist', iconSize)
                end
                if mq.TLO.Group.Puller.ID() == mq.TLO.Me.ID() then
                    ImGui.SameLine()
                    Module.Utils.DrawStatusIcon('A_Puller', 'pwcs', 'Puller', iconSize)
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

            if settings[Module.Name].DynamicHP then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Utils.CalculateColor(colorHpMin, colorHpMax, mq.TLO.Me.PctHPs())))
            else
                if mq.TLO.Me.PctHPs() <= 0 then
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('purple')))
                elseif mq.TLO.Me.PctHPs() < 15 then
                    if pulse then
                        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('orange')))
                        if not mq.TLO.Me.CombatState() == 'COMBAT' then pulse = false end
                    else
                        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('red')))
                        if not mq.TLO.Me.CombatState() == 'COMBAT' then pulse = true end
                    end
                else
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('red')))
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
                if settings[Module.Name].DynamicMP then
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Utils.CalculateColor(colorMpMin, colorMpMax, mq.TLO.Me.PctMana())))
                else
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('light blue2')))
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
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Colors.color('yellow2')))
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

        Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
        ImGui.End()
    end

    if splitTarget and target() ~= nil then
        local colorCountTarget, styleCountTarget = Module.ThemeLoader.StartTheme(themeName, Module.Theme, settings[Module.Name].MouseOver, mouseHudTarg,
            settings[Module.Name].WinTransparency)
        local tmpFlag = targFlag
        if locked then tmpFlag = bit32.bor(targFlag, ImGuiWindowFlags.NoMove) end
        local openT, showT = ImGui.Begin("Target##TargetPopout" .. Module.CharLoaded, true, tmpFlag)
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

        Module.ThemeLoader.EndTheme(colorCountTarget, styleCountTarget)

        ImGui.End()
    end

    if enableBreathBar and breathBarShow then
        local bFlags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse, ImGuiWindowFlags.NoFocusOnAppearing)
        if bLocked then bFlags = bit32.bor(bFlags, ImGuiWindowFlags.NoMove) end
        if not showTitleBreath then bFlags = bit32.bor(bFlags, ImGuiWindowFlags.NoTitleBar) end


        local ColorCountBreath, StyleCountBreath = Module.ThemeLoader.StartTheme(themeName, Module.Theme)
        ImGui.SetNextWindowSize(ImVec2(150, 55), ImGuiCond.FirstUseEver)
        ImGui.SetNextWindowPos(ImGui.GetMousePosVec(), ImGuiCond.FirstUseEver)
        local openBreath, showBreath = ImGui.Begin('Breath##MyBreathWin_' .. Module.CharLoaded, true, bFlags)
        if not openBreath then
            breathBarShow = false
        end
        if showBreath then
            ImGui.SetWindowFontScale(FontScale)

            local yPos = ImGui.GetCursorPosY()
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Utils.CalculateColor(colorBreathMin, colorBreathMax, breathPct)))
            ImGui.ProgressBar((breathPct / 100), ImGui.GetContentRegionAvail(), progressSize, '##pctBreath')
            ImGui.PopStyleColor()
            if ImGui.BeginPopupContextItem("##MySpells_CastWin") then
                local lockLabel = bLocked and 'Unlock' or 'Lock'
                if ImGui.MenuItem(lockLabel .. "##Breath") then
                    bLocked = not bLocked

                    settings[Module.Name].BreathLocked = bLocked
                    mq.pickle(configFile, settings)
                end
                ImGui.EndPopup()
            end
            ImGui.SetWindowFontScale(1)
        end
        Module.ThemeLoader.EndTheme(ColorCountBreath, StyleCountBreath)
        ImGui.End()
    end

    if settings[Module.Name].ShowToT then
        Module.RenderTargetOfTarget()
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
    -- if not mq.TLO.Plugin("MQ2Cast").IsLoaded() then mq.cmd("/plugin MQ2Cast") end
end

local clockTimer = mq.gettime()

function Module.MainLoop()
    if loadedExeternally then
        ---@diagnostic disable-next-line: undefined-global
        if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
    end

    local timeDiff = mq.gettime() - clockTimer
    -- if timeDiff > 3 then

    ---@diagnostic disable-next-line: undefined-field
    breathPct = mq.TLO.Me.PctAirSupply() or 100
    if breathPct < 100 then
        breathBarShow = true
    else
        breathBarShow = false
    end
    -- end
end

function Module.LocalLoop()
    while Module.IsRunning do
        Module.MainLoop()
        mq.delay(1)
    end
end

if mq.TLO.EverQuest.GameState() ~= "INGAME" then
    printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", Module.Name)
    mq.exit()
end

init()
return Module
