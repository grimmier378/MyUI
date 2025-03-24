--[[
    EverQuest DoT and Buff Tracker
    Created for MacroQuest (MQ2)

    Features:
    - Single Target UI for tracking buffs and DoTs
    - Multi-Target DoT Tracking
    - Customizable display modes
    - Slash commands for quick configuration

    Installation:
    1. Save this file in your MacroQuest lua scripts directory
    2. Load using: /lua run dot_tracker.lua

    Slash Commands:
    Single Target UI:
    - /buffmode: Toggle compact/full display mode
    - /bufflayout: Switch between vertical and horizontal layouts
    - /buffcontrols: Show/hide UI controls
    - /buffhealth: Show/hide health bar
    - /bufftarget: Show/hide target information

    Multi-Target UI:
    - /dotmode: Toggle compact/full display mode
    - /resetdottracker: Reset first target tracking

    Buttons in UI:
    - Compact/Full Mode
    - Vertical/Horizontal Layout
    - Show/Hide Health Bar
    - Show/Hide Target Info
    - Show/Hide Multi-Target UI

    Author: Community Contribution
    Version: 1.1.0
    Last Updated: 2024-03-27
]]

local mq = require('mq')
require 'ImGui'

-- Combined UI control variables
local buffs              = {}
local dots               = {}
local lastUpdateTime     = 0
local LOW_TIME_THRESHOLD = 6 -- Threshold in seconds for highlighting DoTs

-- Settings
local settings           = {}
local settingsFile       = string.format("%s/MyDots/%s/%s.lua", mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
local needSave           = false

-- Texture and animation variables
local animSpell          = mq.FindTextureAnimation('A_SpellIcons')
local animItem           = mq.FindTextureAnimation('A_DragItem')
local healthBarTexture   = mq.FindTextureAnimation('A_GaugeFill')
local icons              = require('mq.ICONS')

-- Single Target UI variables
local iconSize           = 16
local spacing            = 4
local winFlagsDefaults   = ImGuiWindowFlags.None
local winFlags           = winFlagsDefaults


-- Multi-target DoT tracking variables
local targetDots        = {}
local firstTargetID     = nil

local Module            = {}
local loadedExeternally = MyUI_ScriptName ~= nil
Module.Name             = "MyDots"
Module.IsRunning        = false

if loadedExeternally then
    Module.Utils = MyUI_Utils
else
    Module.Utils = require('lib.common')
end

local defaultSettings = {
    compactMode = false,
    horizontalLayout = false,
    showControls = true,
    showHealthBar = true,
    showTargetInfo = true,
    multiTargetCompactMode = false,
    openMultiTargetUI = false,
    openGUI = true,
    refreshRate = 500,
    autoSize = true,
    hideTitlebar = false,
    lockWindows = false,
}

local function saveSettings()
    mq.pickle(settingsFile, settings)
end

local function loadSettings()
    if Module.Utils.File.Exists(settingsFile) then
        settings = dofile(settingsFile) or {}
    else
        settings = defaultSettings
        mq.pickle(settingsFile, settings)
    end

    for setting, value in pairs(defaultSettings) do
        if settings[setting] == nil then
            settings[setting] = value
            needSave = true
        end
    end
    if needSave then
        saveSettings()
        needSave = false
    end
    if settings.autoSize then
        winFlags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, winFlagsDefaults)
    else
        winFlags = winFlagsDefaults
    end
end

-- Function to convert milliseconds to MM:SS format
local function convert_milliseconds_to_time(ms)
    local total_seconds = math.floor(ms / 1000)
    local minutes = math.floor(total_seconds / 60)
    local seconds = total_seconds % 60
    return string.format("%02d:%02d", minutes, seconds)
end

-- Function to get con color as RGB values
local function get_con_color(con)
    local colors = {
        ["GREY"] = { 0.5, 0.5, 0.5, 1.0, },               -- Grey
        ["GREEN"] = { 0.0, 1.0, 0.0, 1.0, },              -- Green
        ["LIGHT BLUE"] = { 0.076, 1.000, 0.918, 1.000, }, -- Light Blue / Cyan
        ["BLUE"] = { 0.0, 0.0, 1.0, 1.0, },               -- Blue
        ["WHITE"] = { 1.0, 1.0, 1.0, 1, },                -- White
        ["YELLOW"] = { 1.0, 1.0, 0.0, 1.0, },             -- Yellow
        ["RED"] = { 1.0, 0.0, 0.0, 1.0, },                -- Red
    }

    return colors[con] or colors["WHITE"] -- Default to white if con not found
end

-- Function to update target effects (Single Target)
local function update_target_effects()
    local target = mq.TLO.Target
    buffs = {}
    dots = {}
    if not target() then
        return
    end
    local myName = mq.TLO.Me.CleanName()
    for i = 1, target.BuffCount() do
        local effect = target.Buff(i)
        if effect() then
            local effect_name = effect.Name()
            local effect_timer = effect.Duration.TotalSeconds() * 1000
            local spell_type = effect.SpellType()
            local caster = effect.Caster()
            local icon = effect.SpellIcon()
            if effect_name and effect_timer and caster == myName then
                local timer_str = convert_milliseconds_to_time(effect_timer)
                if spell_type == "Beneficial" then
                    table.insert(buffs, { name = effect_name, icon = icon, time = timer_str, raw_seconds = effect_timer / 1000, type = "buff", })
                elseif spell_type == "Detrimental" then
                    table.insert(dots, { name = effect_name, icon = icon, time = timer_str, raw_seconds = effect_timer / 1000, type = "dot", })
                end
            end
        end
    end

    table.sort(buffs, function(a, b) return a.raw_seconds < b.raw_seconds end)
    table.sort(dots, function(a, b) return a.raw_seconds < b.raw_seconds end)
end

-- Function to update DoTs across all targets
local function update_multi_target_dots()
    targetDots = {}
    local myName = mq.TLO.Me.CleanName()

    for i = 1, 20 do
        local target = mq.TLO.NearestSpawn(i)
        if target() and target.Type() == "NPC" then
            local targetKey = target.ID()
            local validDots = {}

            local buffCount = 0
            pcall(function() buffCount = target.BuffCount() or 0 end)

            for j = 1, buffCount do
                local effect
                local success, result = pcall(function()
                    effect = target.Buff(j)
                    return effect()
                end)

                if success and result and effect then
                    local effect_name = effect.Name()
                    local effect_timer = effect.Duration.TotalSeconds() * 1000
                    local spell_type = effect.SpellType()
                    local caster = effect.Caster()
                    local icon = effect.SpellIcon()

                    if effect_name and effect_timer > 0 and spell_type == "Detrimental" and caster == myName then
                        local timer_str = convert_milliseconds_to_time(effect_timer)

                        local dotStartTime = 0
                        pcall(function()
                            dotStartTime = effect.StartTime() or 0
                        end)

                        table.insert(validDots, {
                            name = effect_name,
                            icon = icon,
                            time = timer_str,
                            raw_seconds = math.floor(effect_timer / 1000),
                            startTime = dotStartTime,
                        })

                        if not firstTargetID then
                            firstTargetID = targetKey
                        end
                    end
                end
            end

            if #validDots > 0 then
                targetDots[targetKey] = {
                    name = target.CleanName(),
                    id = targetKey,
                    dots = validDots,
                    currentHP = target.PctHPs() or 0,
                    level = target.Level(),
                    conColor = target.ConColor(),
                }
            end
        end
    end
end

-- Draw status icon (Single Target)
local function DrawStatusIcon(iconID, type, txt)
    animSpell:SetTextureCell(iconID or 0)
    animItem:SetTextureCell(iconID or 3996)
    if type == 'item' then
        ImGui.DrawTextureAnimation(animItem, iconSize, iconSize)
    else
        ImGui.DrawTextureAnimation(animSpell, iconSize, iconSize)
    end
end

-- Health bar drawing function
local function draw_health_bar(targetHP)
    local barWidth = ImGui.GetContentRegionAvail()
    local barHeight = 10
    local healthPercent = targetHP / 100

    local healthColor = { 0.0, 1.0, 0.0, 0.5, }                     -- Green (Safe)
    if targetHP < 66 then healthColor = { 1.0, 1.0, 0.0, 0.5, } end -- Yellow (Mid HP)
    if targetHP < 33 then healthColor = { 1.0, 0.0, 0.0, 0.5, } end -- Red (Low HP)

    local cursorX, cursorY = ImGui.GetCursorPos()

    ImGui.DrawTextureAnimation(healthBarTexture, barWidth, barHeight)
    ImGui.SetCursorPos(cursorX, cursorY)

    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, healthColor[1], healthColor[2], healthColor[3], healthColor[4])
    ImGui.ProgressBar(healthPercent, barWidth, barHeight, "")
    ImGui.PopStyleColor()

    ImGui.SetCursorPosY(cursorY + barHeight + 2)
    ImGui.Text(string.format("%d%%", targetHP))
end

-- Horizontal layout rendering for Single Target
local function renderHorizontalIcons(items)
    if #items == 0 then
        ImGui.Text("No Effects")
        return
    end

    local windowWidth = ImGui.GetContentRegionAvail()
    local posX = ImGui.GetCursorPosX()
    local startX = posX
    local posY = ImGui.GetCursorPosY()
    local maxWidth = 0
    local lineHeight = iconSize + spacing

    for i, item in ipairs(items) do
        ImGui.PushID(item.name .. i)
        ImGui.SetCursorPos(posX, posY)

        DrawStatusIcon(item.icon, 'spell', item.name)

        local textWidth = settings.compactMode and ImGui.CalcTextSize(item.time) or ImGui.CalcTextSize(item.name .. " - " .. item.time)
        local itemWidth = iconSize + textWidth + spacing * 2

        if i > 1 and (posX + itemWidth > windowWidth) then
            posX = startX
            posY = posY + lineHeight
            ImGui.SetCursorPos(posX, posY)
            DrawStatusIcon(item.icon, 'spell', item.name)
        end

        ImGui.SameLine()
        local isDoT = (item.type == "dot")
        if isDoT and item.raw_seconds < LOW_TIME_THRESHOLD then
            if settings.compactMode then
                ImGui.TextColored(1, 0.5, 0, 1, string.format("%s [!]", item.time))
            else
                ImGui.TextColored(1, 0.5, 0, 1, string.format("%s - %s [!]", item.name, item.time))
            end
        else
            if isDoT then
                if settings.compactMode then
                    ImGui.TextColored(1, 0, 0, 1, item.time)
                else
                    ImGui.TextColored(1, 0, 0, 1, string.format("%s - %s", item.name, item.time))
                end
            else
                if settings.compactMode then
                    ImGui.TextColored(0, 1, 0, 1, item.time)
                else
                    ImGui.TextColored(0, 1, 0, 1, string.format("%s - %s", item.name, item.time))
                end
            end
        end

        if ImGui.IsItemHovered() and ImGui.IsMouseReleased(0) then
            mq.cmdf("/cast \"%s\"", item.name)
        end

        ImGui.PopID()
        posX = posX + itemWidth
        maxWidth = math.max(maxWidth, posX - startX)
    end

    ImGui.SetCursorPosY(posY + lineHeight)
end

-- Vertical layout rendering for Single Target
local function renderVerticalItems(items)
    if #items == 0 then
        ImGui.Text("No Effects")
        return
    end

    for _, item in ipairs(items) do
        ImGui.PushID(item.name)
        DrawStatusIcon(item.icon, 'spell', item.name)
        ImGui.SameLine()

        local isDoT = (item.type == "dot")
        if isDoT and item.raw_seconds < LOW_TIME_THRESHOLD then
            if settings.compactMode then
                ImGui.TextColored(1, 0.5, 0, 1, string.format("%s [!]", item.time))
            else
                ImGui.TextColored(1, 0.5, 0, 1, string.format("%s - %s [!]", item.name, item.time))
            end
        else
            if isDoT then
                if settings.compactMode then
                    ImGui.TextColored(1, 0, 0, 1, item.time)
                else
                    ImGui.TextColored(1, 0, 0, 1, string.format("%s - %s", item.name, item.time))
                end
            else
                if settings.compactMode then
                    ImGui.TextColored(0, 1, 0, 1, item.time)
                else
                    ImGui.TextColored(0, 1, 0, 1, string.format("%s - %s", item.name, item.time))
                end
            end
        end

        ImGui.PopID()

        if ImGui.IsItemHovered() and ImGui.IsMouseReleased(0) then
            mq.cmdf("/cast \"%s\"", item.name)
        end
    end
end

-- Single Target UI rendering function
local function renderSingleTargetUI()
    if not settings.openGUI then return end

    ImGui.PushStyleVar(1, 1)
    local open, shouldDraw = ImGui.Begin("MyDots Tracker", true, winFlags)

    if shouldDraw then
        if ImGui.BeginPopupContextWindow("##MyDotsContextMenuMain") then
            if ImGui.MenuItem("Show Controls") then
                settings.showControls = true
                needSave = true
            end
            if ImGui.MenuItem(settings.lockWindows and "Unlock Windows" or "Lock Windows") then
                settings.lockWindows = not settings.lockWindows
                needSave = true
            end
            ImGui.EndPopup()
        end
        if ImGui.BeginMenuBar() then
            if ImGui.SmallButton(settings.lockWindows and icons.FA_LOCK or icons.FA_UNLOCK) then
                settings.lockWindows = not settings.lockWindows
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.lockWindows and "Unlock Windows" or "Lock Windows")
            end


            if ImGui.SmallButton(settings.hideTitlebar and icons.FA_EYE or icons.FA_EYE_SLASH) then
                settings.hideTitlebar = not settings.hideTitlebar
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.hideTitlebar and "Show Title Bar" or "Hide Title Bar")
            end


            local lbl = settings.showControls and icons.FA_TOGGLE_ON or icons.FA_TOGGLE_OFF
            if ImGui.SmallButton(lbl) then
                settings.showControls = not settings.showControls
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.showControls and "Hide UI Controls" or "Show UI Controls")
            end


            lbl = settings.autoSize and icons.FA_EXPAND or icons.FA_COMPRESS
            if ImGui.SmallButton(lbl .. "##Asize") then
                settings.autoSize = not settings.autoSize
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.autoSize and "Disable AutoSize" or "Enable AutoSize")
            end

            if ImGui.SmallButton(settings.compactMode and icons.MD_UNFOLD_MORE or icons.MD_UNFOLD_LESS) then
                settings.compactMode = not settings.compactMode
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.compactMode and "Disable Compact" or "Enable Compact")
            end

            if ImGui.SmallButton(settings.horizontalLayout and icons.MD_ARROW_DOWNWARD or icons.FA_ARROW_RIGHT) then
                settings.horizontalLayout = not settings.horizontalLayout
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.horizontalLayout and "Vertical Layout" or "Horizontal Layout")
            end

            lbl = settings.showHealthBar and icons.FA_TOGGLE_ON or icons.FA_TOGGLE_OFF
            if ImGui.SmallButton(lbl .. "##HealthBar") then
                settings.showHealthBar = not settings.showHealthBar
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.showHealthBar and "Hide Health Bar" or "Show Health Bar")
            end

            if ImGui.SmallButton(settings.showTargetInfo and icons.MD_INFO_OUTLINE or icons.FA_INFO_CIRCLE) then
                settings.showTargetInfo = not settings.showTargetInfo
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.showTargetInfo and "Hide Target Info" or "Show Target Info")
            end

            if ImGui.SmallButton(settings.openMultiTargetUI and icons.FA_WINDOW_CLOSE_O or icons.MD_OPEN_IN_NEW) then
                settings.openMultiTargetUI = not settings.openMultiTargetUI
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.openMultiTargetUI and "Hide Multi Window" or "Show Multi Window")
            end


            ImGui.EndMenuBar()
        end

        local targetName = mq.TLO.Target() and mq.TLO.Target.CleanName() or "No Target"
        local targetLevel = mq.TLO.Target() and mq.TLO.Target.Level() or "N/A"
        local targetCon = mq.TLO.Target() and mq.TLO.Target.ConColor() or "WHITE"
        local targetHP = mq.TLO.Target() and mq.TLO.Target.PctHPs() or 0
        local conColor = get_con_color(targetCon)

        if settings.showTargetInfo then
            if ImGui.BeginTable("TargetTable", 3) then
                ImGui.TableSetupColumn("Info", ImGuiTableColumnFlags.WidthStretch, 60)
                ImGui.TableSetupColumn("Level", ImGuiTableColumnFlags.WidthFixed, 80)

                ImGui.TableNextRow()
                ImGui.TableNextColumn()

                ImGui.TextColored(conColor[1], conColor[2], conColor[3], conColor[4], "Target: " .. targetName)

                ImGui.TableNextColumn()
                ImGui.Text("Lvl: " .. targetLevel)

                ImGui.EndTable()
            end
        end

        if settings.showHealthBar and mq.TLO.Target() then
            draw_health_bar(targetHP)
        end



        if settings.showControls then
            ImGui.Text(settings.compactMode and "(Icons + Time Only)" or "(Icons + Names + Time)")
            ImGui.SameLine()
            ImGui.Text(settings.horizontalLayout and "(Auto-flow)" or "(List)")

            ImGui.Separator()
        end

        local all_effects = {}
        for _, buff in ipairs(buffs) do
            table.insert(all_effects, buff)
        end
        for _, dot in ipairs(dots) do
            table.insert(all_effects, dot)
        end

        table.sort(all_effects, function(a, b) return a.raw_seconds < b.raw_seconds end)

        if mq.TLO.Target() then
            if settings.horizontalLayout then
                renderHorizontalIcons(all_effects)
            else
                renderVerticalItems(all_effects)
            end
        else
            ImGui.Text("No target selected. Use targeting to see effects.")
        end
    end

    ImGui.End()
    ImGui.PopStyleVar()
    if not open then
        settings.openGUI = false
        needSave = true
    end
end

-- Multi-Target DoTs rendering function
local function renderMultiTargetDots()
    if next(targetDots) == nil then
        ImGui.Text("No DoTs on any targets")
        return
    end

    local windowWidth = ImGui.GetContentRegionAvail()
    local spacing = 5
    local currentLineWidth = 0
    local hpBarWidth = 100
    local hpBarHeight = 10
    local currentTargetID = mq.TLO.Target() and mq.TLO.Target.ID() or nil

    local sortedTargetIDs = {}

    if firstTargetID and targetDots[firstTargetID] then
        table.insert(sortedTargetIDs, firstTargetID)
    end

    for targetID, _ in pairs(targetDots) do
        if targetID ~= firstTargetID then
            table.insert(sortedTargetIDs, targetID)
        end
    end

    for _, targetID in ipairs(sortedTargetIDs) do
        local targetData = targetDots[targetID]

        ImGui.PushID(targetID)

        local conColor = get_con_color(targetData.conColor)
        local buttonColor = conColor --(currentTargetID and targetID == currentTargetID) and { 0.0, 0.5, 0.0, 1.0, } or { 0.3, 0.3, 0.3, 1.0, }
        local isWhiteCon = targetData.conColor ~= 'BLUE'
        if isWhiteCon then
            ImGui.PushStyleColor(ImGuiCol.Text, 0, 0, 1, 1)
        end
        ImGui.PushStyleColor(ImGuiCol.Button, buttonColor[1], buttonColor[2], buttonColor[3], buttonColor[4])
        if ImGui.Button(targetData.name .. " (Lvl " .. targetData.level .. ")##" .. targetID, windowWidth - spacing, 0) then
            mq.cmdf("/target id %d", targetData.id)
        end
        ImGui.PopStyleColor()
        if isWhiteCon then
            ImGui.PopStyleColor()
        end
        if settings.showHealthBar then
            -- ImGui.SameLine(0, spacing)
            draw_health_bar(targetData.currentHP)
        end

        for _, dot in ipairs(targetData.dots) do
            local dotText = settings.multiTargetCompactMode and dot.time or (dot.name .. " - " .. dot.time)
            local itemWidth = iconSize + ImGui.CalcTextSize(dotText) + spacing * 2

            if currentLineWidth + itemWidth > windowWidth then
                ImGui.NewLine()
                currentLineWidth = 0
            end

            DrawStatusIcon(dot.icon)
            ImGui.SameLine()

            if dot.raw_seconds <= LOW_TIME_THRESHOLD then
                if settings.multiTargetCompactMode then
                    ImGui.TextColored(1, 0, 0, 1, string.format("%s [!]", dot.time))
                else
                    ImGui.TextColored(1, 0, 0, 1, string.format("%s - %s [!]", dot.name, dot.time))
                end
            else
                if settings.multiTargetCompactMode then
                    ImGui.Text(dot.time)
                else
                    ImGui.Text(string.format("%s - %s", dot.name, dot.time))
                end
            end

            if ImGui.IsItemHovered() and ImGui.IsMouseReleased(0) then
                mq.cmdf("/cast \"%s\"", dot.name)
            end

            currentLineWidth = currentLineWidth + itemWidth
            ImGui.SameLine(0, spacing)
        end

        ImGui.PopID()
        ImGui.Separator()
        currentLineWidth = 0
    end
end

-- Multi-Target UI rendering function
local function renderMultiTargetUI()
    if not settings.openMultiTargetUI then return end

    local open, shouldDraw = ImGui.Begin("Multi-Target DoT Tracker", true, winFlags)

    if shouldDraw then
        if ImGui.BeginPopupContextWindow("##MyDotsContextMenu") then
            if ImGui.MenuItem("Show Controls") then
                settings.showControls = true
                needSave = true
            end
            if ImGui.MenuItem(settings.lockWindows and "Unlock Windows" or "Lock Windows") then
                settings.lockWindows = not settings.lockWindows
                needSave = true
            end
            ImGui.EndPopup()
        end
        if ImGui.BeginMenuBar() then
            if ImGui.SmallButton(settings.lockWindows and icons.FA_LOCK or icons.FA_UNLOCK) then
                settings.lockWindows = not settings.lockWindows
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.lockWindows and "Unlock Windows" or "Lock Windows")
            end


            if ImGui.SmallButton(settings.hideTitlebar and icons.FA_EYE or icons.FA_EYE_SLASH) then
                settings.hideTitlebar = not settings.hideTitlebar
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.hideTitlebar and "Show Title Bar" or "Hide Title Bar")
            end


            local lbl = settings.showControls and icons.FA_TOGGLE_ON or icons.FA_TOGGLE_OFF
            if ImGui.SmallButton(lbl) then
                settings.showControls = not settings.showControls
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.showControls and "Hide UI Controls" or "Show UI Controls")
            end


            lbl = settings.autoSize and icons.FA_EXPAND or icons.FA_COMPRESS
            if ImGui.SmallButton(lbl .. "##Asize") then
                settings.autoSize = not settings.autoSize
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.autoSize and "Disable AutoSize" or "Enable AutoSize")
            end

            if ImGui.SmallButton(settings.compactMode and icons.MD_UNFOLD_MORE or icons.MD_UNFOLD_LESS) then
                settings.compactMode = not settings.compactMode
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.compactMode and "Disable Compact" or "Enable Compact")
            end

            if ImGui.SmallButton(settings.horizontalLayout and icons.MD_ARROW_DOWNWARD or icons.FA_ARROW_RIGHT) then
                settings.horizontalLayout = not settings.horizontalLayout
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.horizontalLayout and "Vertical Layout" or "Horizontal Layout")
            end

            lbl = settings.showHealthBar and icons.FA_TOGGLE_ON or icons.FA_TOGGLE_OFF
            if ImGui.SmallButton(lbl .. "##HealthBar") then
                settings.showHealthBar = not settings.showHealthBar
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.showHealthBar and "Hide Health Bar" or "Show Health Bar")
            end

            if ImGui.SmallButton(settings.showTargetInfo and icons.MD_INFO_OUTLINE or icons.FA_INFO_CIRCLE) then
                settings.showTargetInfo = not settings.showTargetInfo
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.showTargetInfo and "Hide Target Info" or "Show Target Info")
            end

            lbl = settings.openGUI and icons.FA_WINDOW_CLOSE_O or icons.MD_OPEN_IN_NEW
            if ImGui.SmallButton(lbl) then
                settings.openGUI = not settings.openGUI
                needSave = true
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(settings.openGUI and "Close Main Window" or " Open Main Window")
            end

            ImGui.EndMenuBar()
        end

        ImGui.Separator()

        renderMultiTargetDots()
    end

    ImGui.End()

    if not open then
        settings.openMultiTargetUI = false
        needSave = true
    end
end

function CommandHandler(...)
    local args = { ..., }
    if args[1] == 'buffmode' then
        settings.compactMode = not settings.compactMode
        print("\ay" .. (settings.compactMode and "Switched to compact mode (icons + time only)" or "Switched to full mode (icons + names + time)"))
    elseif args[1] == 'bufflayout' then
        settings.horizontalLayout = not settings.horizontalLayout
        print("\ay" .. (settings.horizontalLayout and "Switched to horizontal layout (auto-flow)" or "Switched to vertical layout (list)"))
    elseif args[1] == 'buffcontrols' then
        settings.showControls = not settings.showControls
        print("\ay" .. (settings.showControls and "UI controls visible" or "UI controls hidden"))
    elseif args[1] == 'buffhealth' then
        settings.showHealthBar = not settings.showHealthBar
        print("\ay" .. (settings.showHealthBar and "Health bar visible" or "Health bar hidden"))
    elseif args[1] == 'bufftarget' then
        settings.showTargetInfo = not settings.showTargetInfo
        print("\ay" .. (settings.showTargetInfo and "Target info visible" or "Target info hidden"))
    elseif args[1] == 'dotmode' then
        settings.multiTargetCompactMode = not settings.multiTargetCompactMode
        print("\ay" .. (settings.multiTargetCompactMode and "Switched to compact mode (icons + time only)" or "Switched to full mode (icons + names + time)"))
    elseif args[1] == 'resetdottracker' then
        firstTargetID = nil
        print("\ayFirst target tracking reset.")
    elseif args[1] == 'show' then
        settings.openGUI = true
    elseif args[1] == 'hide' then
        settings.openGUI = false
    elseif args[1] == 'exit' or args[1] == 'quit' then
        mq.exit()
    else
        PrintHelp()
    end
end

mq.bind("/mydots", CommandHandler)

function PrintHelp()
    printf("[\ayMyDots\ax] Usage:\at /mydots\ax <\aycommand\ax>")
    printf("[\ayMyDots\ax] Commands:")
    printf("[\ayMyDots\ax] \at/mydots\ax \aybuffmode\ax: Toggle compact/full display mode")
    printf("[\ayMyDots\ax] \at/mydots\ax \aybufflayout\ax: Switch between vertical and horizontal layouts")
    printf("[\ayMyDots\ax] \at/mydots\ax \aybuffcontrols\ax: Show/hide UI controls")
    printf("[\ayMyDots\ax] \at/mydots\ax \aybuffhealth\ax: Show/hide health bar")

    printf("[\ayMyDots\ax] \at/mydots\ax \aybufftarget\ax: Show/hide target information")
    printf("[\ayMyDots\ax] \at/mydots\ax \aydotmode\ax: Toggle multi-target DoT compact mode")
    printf("[\ayMyDots\ax] \at/mydots\ax \ayresetdottracker\ax: Reset first target tracking")
    printf("[\ayMyDots\ax] \at/mydots\ax \ayshow\ax: Show the UI")
    printf("[\ayMyDots\ax] \at/mydots\ax \ayhide\ax: Hide the UI")
    printf("[\ayMyDots\ax] \at/mydots\ax \ayexit\ax: Exit the script")
end

function Module.RenderGUI()
    renderSingleTargetUI()
    renderMultiTargetUI()
end

function Module.Unload()
    mq.unbind("/mydots")
end

local function Init()
    loadSettings()
    -- Combined initialization
    if not loadedExeternally then
        mq.imgui.init("MyDots", Module.RenderGUI)
    end
    -- Main loop
    print("\ayTarget Buffs & DoTs tracker started.")
    PrintHelp()

    Module.IsRunning = true
end
function Module.MainLoop()
    if loadedExeternally then
        ---@diagnostic disable-next-line: undefined-global
        if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
    end

    winFlags = winFlagsDefaults
    if settings.autoSize then
        winFlags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, winFlags)
    end
    if settings.showControls then
        winFlags = bit32.bor(ImGuiWindowFlags.MenuBar, winFlags)
    end
    if settings.hideTitlebar then
        winFlags = bit32.bor(ImGuiWindowFlags.NoTitleBar, winFlags)
    end
    if settings.lockWindows then
        winFlags = bit32.bor(ImGuiWindowFlags.NoMove, winFlags)
    end

    local currentTime = mq.gettime()
    if currentTime - lastUpdateTime > settings.refreshRate then
        update_target_effects()
        update_multi_target_dots()
        lastUpdateTime = currentTime
    end
    if needSave then
        saveSettings()
        needSave = false
    end
end

function Module.LocalLoop()
    while Module.IsRunning do
        if mq.TLO.EverQuest.GameState() ~= "INGAME" then
            mq.exit()
        end
        Module.MainLoop()
        mq.delay(100) -- Adjust the delay as needed
    end
    print("\ayClosing Target Buffs & DoTs tracker.")
end

Init()

if not loadedExeternally then
    Module.LocalLoop()
end
return Module
