-- Sample Performance Monitor Class Module
-- shamelessly ripped from RGMercs Lua
-- as suggested by Derple

-- V1.2 Exp Horizon

local mq                  = require('mq')
local ImGui               = require('ImGui')
local ImPlot              = require('ImPlot')
local ScrollingPlotBuffer = require('lib.scrolling_plot_buffer')
local OnEmu               = (mq.TLO.MacroQuest.BuildName():lower() or "") == "emu"
local Module              = {}
local loadedExeternally   = MyUI_ScriptName ~= nil
Module.Name               = "XPTrack"
Module.IsRunning          = false
if not loadedExeternally then
    Module.Icons       = require('mq.ICONS')
    Module.Utils       = require('lib.common')
    Module.ThemeLoader = require('lib.theme_loader')
    Module.Actor       = require('actors')
    Module.CharLoaded  = mq.TLO.Me.DisplayName()
    Module.Server      = mq.TLO.MacroQuest.Server()
    Module.ThemeFile   = string.format('%s/MyUI/ThemeZ.lua', mq.configDir)
    Module.Theme       = {}
else
    Module.Utils       = MyUI_Utils
    Module.Icons       = MyUI_Icons
    Module.ThemeLoader = MyUI_ThemeLoader
    Module.Actor       = MyUI_Actor
    Module.CharLoaded  = MyUI_CharLoaded
    Module.Server      = MyUI_Server
    Module.ThemeFile   = MyUI_ThemeFile
    Module.Theme       = MyUI_Theme
end
local ConfigFile           = string.format("%s/MyUI/XPTrack/%s/%s.lua", mq.configDir, Module.Server, Module.CharLoaded)

local XPEvents             = {}
local MaxStep              = 50
local GoalMaxExpPerSec     = 0
local CurMaxExpPerSec      = 0
local LastExtentsCheck     = 0
local LastEntry            = 0
local XPPerSecond          = 0
local AAXPPerSecond        = 0
local PrevXPTotal          = 0
local PrevAATotal          = 0

local XPTotalPerLevel      = OnEmu and 330 or 100000
local XPTotalDivider       = OnEmu and 1 or 1000

local startXP              = OnEmu and mq.TLO.Me.PctExp() or (mq.TLO.Me.Exp() / XPTotalDivider)
local startLvl             = mq.TLO.Me.Level()
local startAAXP            = OnEmu and mq.TLO.Me.PctAAExp() or (mq.TLO.Me.AAExp() / XPTotalDivider)
local startAA              = mq.TLO.Me.AAPointsTotal()

local XPToNextLevel        = 0
local SecondsToLevel       = 0
local SecondsToAA          = 0
local TimeToLevel          = "<Unknown>"
local TimeToAA             = "<Unknown>"
local Resolution           = 15   -- seconds
local MaxExpSecondsToStore = 3600 --3600
local MaxHorizon           = 3600 --3600
local MinTime              = 10

local offset               = 1
local horizon_or_less      = 60
local trackback            = 1
local first_tick           = 0

local ImGui_HorizonStep1   = 1 * 60
local ImGui_HorizonStep2   = 5 * 60
local ImGui_HorizonStep3   = 30 * 60
local ImGui_HorizonStep4   = 60 * 60
local needSave             = false
local debug                = false
local showStats            = true
local showGraph            = false

-- timezone calcs
---@diagnostic disable-next-line: param-type-mismatch
local utc_now              = os.time(os.date("!*t", os.time()))
---@diagnostic disable-next-line: param-type-mismatch
local local_now            = os.time(os.date("*t", os.time()))
local utc_offset           = local_now - utc_now

-- Check if we're currently in daylight saving time
local dst                  = os.date("*t", os.time())["isdst"]

-- If we're in DST, add one hour
if dst then
    utc_offset = utc_offset + 3600
end

local function getTime()
    return os.time() + utc_offset
end

local TrackXP       = {
    PlayerLevel = mq.TLO.Me.Level() or 0,
    PlayerAA = mq.TLO.Me.AAPointsTotal(),
    StartTime = getTime(),

    XPTotalPerLevel = OnEmu and 330 or 100000,
    XPTotalDivider = OnEmu and 1 or 1000,

    Experience = {
        Base = OnEmu and ((mq.TLO.Me.Level() * 100) + mq.TLO.Me.PctExp()) or mq.TLO.Me.Exp(),
        Total = 0,
        Gained = 0,
    },
    AAExperience = {
        Base = OnEmu and ((mq.TLO.Me.AAPointsTotal() * 100) + mq.TLO.Me.PctAAExp()) or mq.TLO.Me.AAExp(),
        Total = 0,
        Gained = 0,
    },
}

Module.Settings     = {}
HorizonChanged      = false --

local DefaultConfig = {
    ['ExpSecondsToStore'] = MaxExpSecondsToStore,
    ['Horizon']           = ImGui_HorizonStep2,
    ['ExpPlotFillLines']  = true,
    ['GraphMultiplier']   = 1,
    OutputTab             = 'XPTrack',
    LoadTheme             = 'Default',

}

Module.Settings     = DefaultConfig

local multiplier    = tonumber(Module.Settings.GraphMultiplier)

local function ClearStats()
    TrackXP   = {
        PlayerLevel = mq.TLO.Me.Level(),
        PlayerAA = mq.TLO.Me.AAPointsTotal(),
        StartTime = getTime(),

        Experience = {
            Base = OnEmu and ((mq.TLO.Me.Level() * 100) + mq.TLO.Me.PctExp()) or mq.TLO.Me.Exp(),
            Total = 0,
            Gained = 0,
        },
        AAExperience = {
            Base = OnEmu and ((mq.TLO.Me.AAPointsTotal() * 100) + mq.TLO.Me.PctAAExp()) or mq.TLO.Me.AAExp(),
            Total = 0,
            Gained = 0,
        },
    }
    startXP   = OnEmu and (mq.TLO.Me.PctExp()) or (mq.TLO.Me.Exp() / XPTotalDivider)
    startLvl  = mq.TLO.Me.Level()
    startAAXP = OnEmu and (mq.TLO.Me.PctAAExp()) or (mq.TLO.Me.AAExp() / XPTotalDivider)
    startAA   = mq.TLO.Me.AAPointsTotal()
    XPEvents  = {}
end

local function RenderShaded(type, currentData, otherData)
    if currentData then
        local count = #currentData.expEvents.DataY
        local otherY = {}
        local now = getTime()
        if Module.Settings.ExpPlotFillLines then
            for idx, _ in ipairs(currentData.expEvents.DataY) do
                otherY[idx] = 0
                if otherData.expEvents.DataY[idx] then
                    if currentData.expEvents.DataY[idx] >= otherData.expEvents.DataY[idx] then
                        otherY[idx] = otherData.expEvents.DataY[idx]
                    end
                end
            end
            ImPlot.PlotShaded(type, currentData.expEvents.DataX, currentData.expEvents.DataY, otherY, count,
                ImPlotShadedFlags.None, currentData.expEvents.Offset - 1)
        end

        ImPlot.PlotLine(type, currentData.expEvents.DataX, currentData.expEvents.DataY, count, ImPlotLineFlags.None,
            currentData.expEvents.Offset - 1)
    end
end

local openGUI = true
local shouldDrawGUI = true

local function FormatTime(time, formatString)
    local days = math.floor(time / 86400)
    local hours = math.floor((time % 86400) / 3600)
    local minutes = math.floor((time % 3600) / 60)
    local seconds = math.floor((time % 60))
    return string.format(formatString and formatString or "%d:%02d:%02d:%02d", days, hours, minutes, seconds)
end

function Module.RenderGUI()
    if not openGUI then
        Module.IsRunning = false
        return
    end
    openGUI, shouldDrawGUI = ImGui.Begin('xpTrack##' .. Module.CharLoaded, openGUI, ImGuiWindowFlags.NoScrollbar)
    local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(Module.Settings.LoadTheme, Module.Theme)
    if shouldDrawGUI then
        ImGui.SameLine()
        local pressed
        local waitfordata = (getTime() - TrackXP.StartTime) <= MinTime
        -- cleaned up the button so its smaller
        if ImGui.Button(Module.Icons.MD_DELETE_SWEEP) then
            ClearStats()
        end
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Reset Stats")
        end
        ImGui.SameLine()
        local label = showStats and "Show Conf" or "Show Stats"
        if ImGui.Button(label) then
            showStats = not showStats
            showGraph = false
        end
        ImGui.SameLine()
        if ImGui.Button("Show Graph") then
            showGraph = true
            showStats = false
        end
        ImGui.TextColored(ImVec4(0, 1, 1, 1), "Current ")
        ImGui.SameLine()
        ImGui.TextColored(ImVec4(0.352, 0.970, 0.399, 1.000), "XP: %2.3f%%", mq.TLO.Me.PctExp())
        if TrackXP.PlayerLevel >= 51 then
            ImGui.SameLine()
            ImGui.TextColored(ImVec4(0.983, 0.729, 0.290, 1.000), "  AA XP: %2.3f%% ", mq.TLO.Me.PctAAExp())
        end
        if waitfordata then
            ImGui.Separator()
            ImGui.Text("waiting for data...")
            ImGui.SameLine()
            ImGui.Text("%s", MinTime - (getTime() - TrackXP.StartTime))
        end
        if showStats then
            if ImGui.BeginTable("ExpStats", 2, bit32.bor(ImGuiTableFlags.Borders)) then
                ImGui.TableSetupColumn("Exp Stats", ImGuiTableColumnFlags.WidthFixed, 120)
                ImGui.TableSetupColumn("Values", ImGuiTableColumnFlags.WidthStretch)
                if not waitfordata then
                    -- wait for MinTime
                    ImGui.TableNextColumn()
                    ImGui.Text("Exp Session Time")
                    ImGui.TableNextColumn()
                    ImGui.Text(FormatTime(getTime() - TrackXP.StartTime))
                    ImGui.TableNextColumn()
                    ImGui.Text("Exp Horizon Time")
                    ImGui.TableNextColumn()
                    ImGui.Text(FormatTime(Module.Settings.Horizon))
                    -- XP Section
                    ImGui.TableNextColumn()
                    ImGui.TextColored(ImVec4(1, 1, 0, 1), "Exp Start value")
                    ImGui.TableNextColumn()
                    ImGui.TextColored(ImVec4(1, 1, 0, 1), "Lvl: ")
                    ImGui.SameLine()
                    ImGui.TextColored(ImVec4(0, 1, 1, 1), "%d ", startLvl)
                    ImGui.SameLine()
                    ImGui.TextColored(ImVec4(1, 1, 0, 1), "XP: ")
                    ImGui.SameLine()
                    ImGui.TextColored(ImVec4(0, 1, 1, 1), "%2.3f%%", startXP)
                    ImGui.TableNextColumn()
                    ImGui.Text("Exp Gained")
                    ImGui.TableNextColumn()
                    local color = TrackXP.Experience.Total > 0 and ImVec4(0, 1, 0, 1) or ImVec4(1, 0, 0, 1)
                    ImGui.TextColored(ImVec4(0.983, 0.729, 0.290, 1.000), "%d Lvls ", (TrackXP.PlayerLevel - startLvl))
                    ImGui.SameLine()
                    ImGui.TextColored(color, "%2.3f%% Xp", (OnEmu and TrackXP.Experience.Total or TrackXP.Experience.Total / XPTotalDivider))
                    ImGui.TableNextColumn()
                    ImGui.Text("current Exp / Min")
                    ImGui.TableNextColumn()
                    ImGui.Text("%2.3f%%", XPPerSecond * 60)
                    ImGui.TableNextColumn()
                    ImGui.Text("current Exp / Hr")
                    ImGui.TableNextColumn()
                    ImGui.Text("%2.3f%%", XPPerSecond * 3600)
                    ImGui.TableNextColumn()
                    ImGui.Text("Time To Level")
                    ImGui.TableNextColumn()
                    ImGui.TextColored(ImVec4(0.983, 0.729, 0.290, 1.000), "%s", TimeToLevel)
                    -- AA Section
                    if TrackXP.PlayerLevel >= 51 then
                        ImGui.TableNextColumn()
                        ImGui.TextColored(ImVec4(1, 1, 0, 1), "AA Start value")
                        ImGui.TableNextColumn()
                        ImGui.TextColored(ImVec4(1, 1, 0, 1), "Pts: ")
                        ImGui.SameLine()
                        ImGui.TextColored(ImVec4(0, 1, 1, 1), "%d ", startAA)
                        ImGui.SameLine()
                        ImGui.TextColored(ImVec4(1, 1, 0, 1), "AA XP: ")
                        ImGui.SameLine()
                        ImGui.TextColored(ImVec4(0, 1, 1, 1), "%2.3f%%", startAAXP)
                        ImGui.TableNextColumn()
                        ImGui.Text("AA Gained")
                        ImGui.TableNextColumn()
                        ImGui.TextColored(ImVec4(0.983, 0.729, 0.290, 1.000), "%d Pts", (TrackXP.PlayerAA - startAA))
                        ImGui.SameLine()
                        ImGui.TextColored(ImVec4(0, 1, 0, 1), "%2.3f%% AA Xp", (OnEmu and TrackXP.AAExperience.Total or TrackXP.AAExperience.Total / XPTotalDivider / 100))
                        ImGui.TableNextColumn()
                        ImGui.Text("current AA / Min")
                        ImGui.TableNextColumn()
                        if not OnEmu then
                            ImGui.Text("%2.1f Pts", AAXPPerSecond * 60)
                        else
                            ImGui.Text("%2.3f %%", AAXPPerSecond * 60)
                        end
                        ImGui.TableNextColumn()
                        ImGui.Text("current AA / Hr")
                        ImGui.TableNextColumn()
                        if not OnEmu then
                            ImGui.Text("%2.1f Pts", AAXPPerSecond * 3600)
                        else
                            ImGui.Text("%2.1f Pts", AAXPPerSecond * 36)
                        end
                        ImGui.TableNextColumn()
                        ImGui.Text("Time To AA")
                        ImGui.TableNextColumn()
                        ImGui.TextColored(ImVec4(0.983, 0.729, 0.290, 1.000), "%s", TimeToAA)
                    end
                end
                ImGui.EndTable()
            end
        elseif not showGraph then
            ImGui.SeparatorText("Config Options")
            if not waitfordata then
                -- because interacting with the settings while waiting for data will cause a crash
                Module.Settings.ExpSecondsToStore, pressed = ImGui.SliderInt("Exp observation period",
                    Module.Settings.ExpSecondsToStore, 60, MaxExpSecondsToStore, "%d s")

                Module.Settings.GraphMultiplier, pressed = ImGui.SliderInt("Scaleup for regular XP",
                    Module.Settings.GraphMultiplier, 1, 20, "%d x")
                if pressed then
                    if Module.Settings.GraphMultiplier < 5 then
                        Module.Settings.GraphMultiplier = 1
                    elseif Module.Settings.GraphMultiplier < 15 then
                        Module.Settings.GraphMultiplier = 10
                    else
                        Module.Settings.GraphMultiplier = 20
                    end

                    local new_multiplier = tonumber(Module.Settings.GraphMultiplier)

                    for idx, pt in ipairs(XPEvents.Exp.expEvents.DataY) do
                        XPEvents.Exp.expEvents.DataY[idx] = (pt / multiplier) * new_multiplier
                    end

                    multiplier = new_multiplier
                    needSave = true
                end

                Module.Settings.Horizon, pressed = ImGui.SliderInt("Horizon for plot",
                    Module.Settings.Horizon, ImGui_HorizonStep1, ImGui_HorizonStep4, "%d s")
                if pressed then
                    if Module.Settings.Horizon < ImGui_HorizonStep2 then
                        Module.Settings.Horizon = ImGui_HorizonStep1
                        HorizonChanged = true
                    elseif Module.Settings.Horizon < ImGui_HorizonStep3 then
                        Module.Settings.Horizon = ImGui_HorizonStep2
                        HorizonChanged = true
                    elseif Module.Settings.Horizon < ImGui_HorizonStep4 then
                        Module.Settings.Horizon = ImGui_HorizonStep3
                        HorizonChanged = true
                    else
                        Module.Settings.Horizon = ImGui_HorizonStep4
                        HorizonChanged = true
                    end
                    needSave = true
                end

                Module.Settings.ExpPlotFillLines, pressed = Module.Utils.DrawToggle("Shade Plot Lines", Module.Settings.ExpPlotFillLines)
                if pressed then
                    needSave = true
                end
            end
            ImGui.SeparatorText('Themes')
            ImGui.Text("Cur Theme: %s", Module.themeName)
            -- Combo Box Load Theme
            if ImGui.BeginCombo("Load Theme##XPTrack", Module.themeName) then
                for k, data in pairs(Module.Theme.Theme) do
                    local isSelected = data.Name == Module.themeName
                    if ImGui.Selectable(data.Name, isSelected) then
                        Module.Settings.LoadTheme = data.Name
                        if Module.themeName ~= Module.Settings.LoadTheme then
                            mq.pickle(ConfigFile, Module.Settings)
                        end
                        Module.themeName = Module.Settings.LoadTheme
                    end
                end
                ImGui.EndCombo()
            end
        elseif showGraph and not waitfordata then
            local ordMagDiff = 10 ^
                math.floor(math.abs(math.log(
                    (CurMaxExpPerSec > 0 and CurMaxExpPerSec or 1) / (GoalMaxExpPerSec > 0 and GoalMaxExpPerSec or 1), 10)))

            -- converge on new max recalc min and maxes
            if CurMaxExpPerSec < GoalMaxExpPerSec then
                CurMaxExpPerSec = CurMaxExpPerSec + ordMagDiff
            end

            if CurMaxExpPerSec > GoalMaxExpPerSec then
                CurMaxExpPerSec = CurMaxExpPerSec - ordMagDiff
            end
            if ImPlot.BeginPlot("Experience Tracker") then
                ImPlot.SetupAxisScale(ImAxis.X1, ImPlotScale.Time)
                if multiplier == 1 then
                    ImPlot.SetupAxes("Local Time", "Exp ")
                else
                    ImPlot.SetupAxes("Local Time", string.format("reg. Exp in %sths", multiplier))
                end
                if not waitfordata then
                    ImPlot.SetupAxisLimits(ImAxis.X1, getTime() - Module.Settings.ExpSecondsToStore, getTime(), ImGuiCond.Always)
                    ImPlot.SetupAxisLimits(ImAxis.Y1, 1, CurMaxExpPerSec, ImGuiCond.Always)
                    ImPlot.PushStyleVar(ImPlotStyleVar.FillAlpha, 0.35)
                    RenderShaded("Exp", XPEvents.Exp, XPEvents.AA)
                    RenderShaded("AA", XPEvents.AA, XPEvents.Exp)
                    ImPlot.PopStyleVar()
                end
                ImPlot.EndPlot()
            end
        end
    end
    ImGui.Spacing()
    Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
    ImGui.End()
end

function Module.Unload()
    mq.unbind("/xpt")
end

local function CheckExpChanged()
    local me = mq.TLO.Me
    local currentExp = me.Exp()
    if currentExp ~= TrackXP.Experience.Base then
        if me.Level() == TrackXP.PlayerLevel then
            TrackXP.Experience.Gained = currentExp - TrackXP.Experience.Base
        elseif me.Level() > TrackXP.PlayerLevel then
            TrackXP.Experience.Gained = XPTotalPerLevel - TrackXP.Experience.Base + currentExp
        else
            TrackXP.Experience.Gained = TrackXP.Experience.Base - XPTotalPerLevel + currentExp
        end

        TrackXP.Experience.Total = TrackXP.Experience.Total + TrackXP.Experience.Gained
        TrackXP.Experience.Base = currentExp
        TrackXP.PlayerLevel = me.Level()

        return true
    end

    TrackXP.Experience.Gained = 0
    return false
end

local function CheckAAExpChanged()
    local me = mq.TLO.Me
    local currentExp = me.AAExp()
    if currentExp ~= TrackXP.AAExperience.Base then
        if me.AAPointsTotal() == TrackXP.PlayerAA then
            TrackXP.AAExperience.Gained = currentExp - TrackXP.AAExperience.Base
        else
            TrackXP.AAExperience.Gained = currentExp - TrackXP.AAExperience.Base +
                ((me.AAPointsTotal() - TrackXP.PlayerAA) * XPTotalPerLevel)
        end

        TrackXP.AAExperience.Total = TrackXP.AAExperience.Total + TrackXP.AAExperience.Gained
        TrackXP.AAExperience.Base = currentExp
        TrackXP.PlayerAA = me.AAPointsTotal()

        return true
    end

    TrackXP.AAExperience.Gained = 0
    return false
end

local function CheckExpChangedEmu()
    local me = mq.TLO.Me
    local currentExp = ((me.Level() * 100) + me.PctExp())
    if currentExp ~= TrackXP.Experience.Base then
        TrackXP.Experience.Gained = currentExp - TrackXP.Experience.Base

        TrackXP.Experience.Total = TrackXP.Experience.Total + TrackXP.Experience.Gained
        TrackXP.Experience.Base = currentExp
        TrackXP.PlayerLevel = me.Level()

        return true
    end

    TrackXP.Experience.Gained = 0
    return false
end

local function CheckAAExpChangedEmu()
    local me = mq.TLO.Me
    local currentExp = ((me.AAPointsTotal() * 100) + me.PctAAExp())
    if currentExp ~= TrackXP.AAExperience.Base then
        TrackXP.AAExperience.Gained = currentExp - TrackXP.AAExperience.Base

        TrackXP.AAExperience.Total = TrackXP.AAExperience.Total + TrackXP.AAExperience.Gained
        TrackXP.AAExperience.Base = currentExp
        TrackXP.PlayerAA = me.AAPointsTotal()

        return true
    end

    TrackXP.AAExperience.Gained = 0
    return false
end

local function CommandHandler(...)
    local args = { ..., }
    if args[1] == "reset" then
        ClearStats()
        Module.Utils.PrintOutput('XPTraclk', false, "\aw[\atXP Track\ax] \aoStats Reset")
    elseif args[1] == 'exit' then
        openGUI = false
    end
end

mq.bind("/xpt", CommandHandler)
Module.Utils.PrintOutput('XPTraclk', false, "\aw[\atXP Track\ax] \aoCommand: \ay/xpt \aoArgumentss: \aw[\ayreset\aw|\ayexit\aw]")

function Module.MainLoop()
    if loadedExeternally then
        ---@diagnostic disable-next-line: undefined-global
        if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
    end

    local now = math.floor(getTime())

    if mq.TLO.EverQuest.GameState() == "INGAME" then
        if not XPEvents.Exp then
            while (now % Resolution) ~= 0 do -- wait for first resolution tick then initialize buffer
                mq.delay(100)
                now = math.floor(getTime())
            end
            XPEvents.Exp = {
                lastFrame = now,
                expEvents =
                    ScrollingPlotBuffer:new(math.ceil(2 * MaxHorizon)),
            }
        end

        if not XPEvents.AA then
            XPEvents.AA = {
                lastFrame = now,
                expEvents =
                    ScrollingPlotBuffer:new(math.ceil(2 * MaxHorizon)),
            }
        end
        if not OnEmu then
            if CheckExpChanged() then
                Module.Utils.PrintOutput('XPTraclk', false,
                    "\ayXP Gained: \ag%02.3f%% \aw|| \ayXP Total: \ag%02.3f%% \aw|| \ayStart: \am%d \ayCur: \am%d \ayExp/Sec: \ag%2.3f%%",
                    TrackXP.Experience.Gained / XPTotalDivider,
                    TrackXP.Experience.Total / XPTotalDivider,
                    TrackXP.StartTime,
                    now,
                    TrackXP.Experience.Total / XPTotalDivider /
                    (math.floor(now / Resolution) * Resolution - TrackXP.StartTime))
            end

            if mq.TLO.Me.PctAAExp() > 0 and CheckAAExpChanged() then
                Module.Utils.PrintOutput('XPTraclk', false, "\ayAA Gained: \ag%2.2f \aw|| \ayAA Total: \ag%2.2f",
                    TrackXP.AAExperience.Gained / XPTotalDivider / 100,
                    TrackXP.AAExperience.Total / XPTotalDivider / 100)
            end
        else
            if CheckExpChangedEmu() then
                Module.Utils.PrintOutput('XPTraclk', false,
                    "\ayXP Gained: \ag%02.3f%% \aw|| \ayXP Total: \ag%02.3f%% \aw|| \ayStart: \am%d \ayCur: \am%d \aw|| \ayExp/Min: \ag%2.3f%%  \ayExp/Hr: \ag%2.3f%%",
                    TrackXP.Experience.Gained,
                    TrackXP.Experience.Total,
                    TrackXP.StartTime,
                    now,
                    (XPPerSecond * 60),
                    (XPPerSecond * 3600))
            end

            if mq.TLO.Me.PctAAExp() > 0 and CheckAAExpChangedEmu() then
                Module.Utils.PrintOutput('XPTraclk', false, "\ayAA Gained: \ag%2.2f%% \aw|| \ayAA Total: \ag%2.2f%%, \aw|| \ayAA/Min: \ag%2.2f%% \aw|| \ayAA/Hr: \ag%2.1f pts",
                    TrackXP.AAExperience.Gained,
                    TrackXP.AAExperience.Total,
                    (AAXPPerSecond * 60),
                    (AAXPPerSecond * 36))
            end
        end
    end

    if mq.TLO.EverQuest.GameState() == "INGAME" and now > LastEntry and (now % Resolution) ~= 0 then -- if not at resolution tick, just insert the previous data again
        LastEntry = now
        XPEvents.Exp.lastFrame = now
        ---@diagnostic disable-next-line: undefined-field
        XPEvents.Exp.expEvents:AddPoint(now, XPPerSecond * 60 * 60 * multiplier, TrackXP.Experience.Total)
        XPEvents.AA.lastFrame = now
        ---@diagnostic disable-next-line: undefined-field
        XPEvents.AA.expEvents:AddPoint(now, AAXPPerSecond * 60 * 60, TrackXP.AAExperience.Total)
    elseif mq.TLO.EverQuest.GameState() == "INGAME" and now > LastEntry and (now % Resolution) == 0 then -- if at resolution tick, do proper calculation
        LastEntry = now
        if first_tick == 0 then first_tick = now end
        local totalevents = #XPEvents.Exp.expEvents.TotalXP
        local rolled = (totalevents == 2 * MaxHorizon) -- double horizon so we can still recalc XPS values
        offset = XPEvents.Exp.expEvents.Offset
        local horizon = Module.Settings.Horizon
        horizon_or_less = math.min(horizon, math.max(Resolution, (math.floor((totalevents) / Resolution) * Resolution)))

        if rolled then                        -- we're full, just go round + 1 (because we have not yet entered the value)
            trackback = ((offset - 1 - horizon) % (totalevents + 1)) + 1
        elseif totalevents + 1 > horizon then -- can go back at least one horizon_ticks before hitting start + 1 (because we have not yet entered the value)
            trackback = totalevents + 1 - horizon
        else                                  -- not a full horizon tick yet, take partials (only every Resolution tick)
            trackback = 1
        end

        if XPEvents.Exp.expEvents.TotalXP[trackback] then
            PrevXPTotal = XPEvents.Exp.expEvents.TotalXP[trackback]
        else
            PrevXPTotal = TrackXP.Experience.Total
        end
        if XPEvents.AA.expEvents.TotalXP[trackback] then
            PrevAATotal = XPEvents.AA.expEvents.TotalXP[trackback]
        else
            PrevAATotal = TrackXP.AAExperience.Total
        end

        XPPerSecond            = ((TrackXP.Experience.Total - PrevXPTotal) / XPTotalDivider) / horizon_or_less
        XPToNextLevel          = 100 - mq.TLO.Me.PctExp()
        AAXPPerSecond          = ((TrackXP.AAExperience.Total - PrevAATotal) / XPTotalDivider) / horizon_or_less

        AAXPPerSecond          = AAXPPerSecond / (OnEmu and 1 or 100) -- divide by 100 to get full AA, not % values
        SecondsToLevel         = XPToNextLevel / (XPPerSecond * XPTotalDivider)
        TimeToLevel            = XPPerSecond <= 0 and "<Unknown>" or FormatTime(SecondsToLevel, "%d Days %d Hours %d Mins")

        local XPToNextAA       = 100 - mq.TLO.Me.PctAAExp()
        SecondsToAA            = XPToNextAA / (AAXPPerSecond * XPTotalDivider)
        TimeToAA               = AAXPPerSecond <= 0 and "<Unknown>" or FormatTime(SecondsToAA, "%d Days %d Hours %d Mins")

        XPEvents.Exp.lastFrame = now
        ---@diagnostic disable-next-line: undefined-field
        XPEvents.Exp.expEvents:AddPoint(now, XPPerSecond * 60 * 60 * multiplier, TrackXP.Experience.Total)


        XPEvents.AA.lastFrame = now
        ---@diagnostic disable-next-line: undefined-field
        XPEvents.AA.expEvents:AddPoint(now, AAXPPerSecond * 60 * 60, TrackXP.AAExperience.Total)
    end

    if now - LastExtentsCheck > 0.5 then
        local newGoal = 0
        local totalevents = #XPEvents.Exp.expEvents.TotalXP
        local rolled = (totalevents == 2 * MaxHorizon)
        local div = 1
        local multiplier2 = multiplier
        local horizon = Module.Settings.Horizon

        local horizonChanged = HorizonChanged

        if horizonChanged == true and debug then
            print("BEFORE ---------------------------------------------------------->")
            print("#: " .. #XPEvents.AA.expEvents.TotalXP)
            print("Offset: " .. XPEvents.AA.expEvents.Offset)
            print("horizon: " .. horizon)
            for idx, exp in ipairs(XPEvents.AA.expEvents.DataY) do
                print(idx .. " - EXP Y: " .. XPEvents.AA.expEvents.DataY[idx] .. " - total: " .. XPEvents.AA.expEvents.TotalXP[idx])
            end
        end

        LastExtentsCheck = now
        for id, expData in pairs(XPEvents) do
            if id == "AA" then
                div = 100
                multiplier2 = 1
            else
                div = 1
                multiplier2 = multiplier
            end
            for idx, exp in ipairs(expData.expEvents.DataY) do
                -- is this entry visible?
                local curGoal = math.ceil(exp / MaxStep * MaxStep * 1.25)
                local visible = expData.expEvents.DataX[idx] > (now - MaxHorizon)

                if visible then
                    if curGoal > newGoal then
                        newGoal = curGoal
                    end
                    if horizonChanged then
                        if rolled then -- we're full, just go round
                            expData.expEvents.DataY[idx] = ((((expData.expEvents.TotalXP[idx] - expData.expEvents.TotalXP[((idx - 1 - horizon) % totalevents) + 1]) / XPTotalDivider) / horizon) /
                                div) * 60 * 60 * multiplier2
                        elseif idx > horizon then -- can go back at least one horizon_ticks before hitting start
                            expData.expEvents.DataY[idx] = ((((expData.expEvents.TotalXP[idx] - expData.expEvents.TotalXP[idx - horizon]) / XPTotalDivider) / horizon) /
                                div) * 60 * 60 * multiplier2
                        else -- not a full horizon tick yet, take partials (only every Resolution tick)
                            expData.expEvents.DataY[idx] = ((((expData.expEvents.TotalXP[idx] - expData.expEvents.TotalXP[1]) / XPTotalDivider) / math.max(Resolution, (math.floor((idx) / Resolution) * Resolution))) / div) *
                                60 * 60 * multiplier2
                        end
                    end
                end
            end
        end
        GoalMaxExpPerSec = newGoal
        if horizonChanged == true and debug then
            print("AFTER <---------------------------------------------------------")
            print("#: " .. #XPEvents.AA.expEvents.TotalXP)
            print("Offset: " .. XPEvents.AA.expEvents.Offset)
            print("horizon: " .. horizon)
            for idx, exp in ipairs(XPEvents.AA.expEvents.DataY) do
                print(idx .. " - EXP Y: " .. XPEvents.AA.expEvents.DataY[idx] .. " - total: " .. XPEvents.AA.expEvents.TotalXP[idx])
            end
        end
        HorizonChanged = false
    end
    if needSave then
        mq.pickle(ConfigFile, Module.Settings)
        needSave = false
    end
end

function Module.LoadSettings()
    if Module.Utils.File.Exists(ConfigFile) then
        Module.Settings = dofile(ConfigFile)
    end

    local newSetting = false

    newSetting = Module.Utils.CheckDefaultSettings(Module.Settings, DefaultConfig)
    newSetting = Module.Utils.CheckRemovedSettings(Module.Settings, DefaultConfig) or newSetting

    if newSetting then mq.pickle(ConfigFile, Module.Settings) end
    Module.themeName = Module.Settings.LoadTheme
    Module.IsRunning = true
end

Module.LoadSettings()


-- TODO: check for persona / other char switch and reset stats?
if not loadedExeternally then
    mq.imgui.init('xptracker', Module.RenderGUI)
    while Module.IsRunning do
        Module.MainLoop()
        mq.delay(100)
    end
end
return Module
