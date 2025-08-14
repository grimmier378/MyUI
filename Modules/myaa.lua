local mq                      = require('mq')
local ImGui                   = require 'ImGui'
local drawTimerMS             = mq.gettime() -- get the current time in milliseconds
local drawTimerS              = os.time()    -- get the current time in seconds
local lastCheck               = os.time()
local Module                  = {}
local MySelf                  = mq.TLO.Me
local genAA                   = {}
local classAA                 = {}
local archAA                  = {}
local specAA                  = {}
local currentRanks            = {}
local doTrain                 = false
local doHotkey                = false
local selectedAA              = "none"
local selectedTimeLeft        = 0
local selectedTimeLeftSeconds = 0
local availAA                 = MySelf.AAPoints() or 0
local spentAA                 = MySelf.AAPointsSpent() or 0
local totalAA                 = MySelf.AAPointsTotal() or 0
local toTrain                 = {}
local toHotkey                = {}
local EQ_ICON_OFFSET          = 500
local animMini                = mq.FindTextureAnimation("A_DragItem")
local TotalMaxAA              = {
	general = 0,
	arch = 0,
	class = 0,
	special = 0,
	all = 0,
}
local CurSectionAA            = {
	general = 0,
	arch = 0,
	class = 0,
	special = 0,
	all = 0,
}

Module.Name                   = "MyAA" -- Name of the module used when loading and unloaing the modules.
Module.IsRunning              = false  -- Keep track of running state. if not running we can unload it.
Module.ShowGui                = false
-- check if the script is being loaded as a Module (externally) or as a Standalone script.
---@diagnostic disable-next-line:undefined-global
local loadedExeternally       = MyUI_ScriptName ~= nil and true or false
if not loadedExeternally then
	Module.Utils       = require('lib.common')                -- common functions for use in other scripts
	Module.Icons       = require('mq.ICONS')                  -- FAWESOME ICONS
	Module.Colors      = require('lib.colors')                -- color table for GUI returns ImVec4
	Module.ThemeLoader = require('lib.theme_loader')          -- Load the theme loader
	Module.CharLoaded  = MySelf.CleanName()
	Module.Server      = mq.TLO.MacroQuest.Server() or "Unknown" -- Get the server name
	Module.ThemeName   = 'Default'
	Module.Theme       = require('defaults.themes')           -- Get the theme table
else
	Module.Utils       = MyUI_Utils
	Module.Icons       = MyUI_Icons
	Module.Colors      = MyUI_Colors
	Module.ThemeLoader = MyUI_ThemeLoader
	Module.CharLoaded  = MyUI_CharLoaded
	Module.Server      = MyUI_Server or "Unknown" -- Get the server name
	Module.ThemeName   = MyUI_ThemeName or 'Default'
	Module.Theme       = MyUI_Theme or {}
end

local configFile = string.format("%s/MyUI/%s/%s/%s.lua", mq.configDir, Module.Name, Module.Server, Module.CharLoaded)


local defaults       = {
	showUI = true, -- Show the UI by default
	showBtn = true, -- Show the button by default
	scale = 1.0, -- Scale of the UI
}

Module.Settings      = {}

local tableFlags     = bit32.bor(
	ImGuiTableFlags.ScrollY,
	ImGuiTableFlags.BordersOuter,
	ImGuiTableFlags.BordersInner,
	ImGuiTableFlags.Resizable,
	ImGuiTableFlags.Reorderable,
	ImGuiTableFlags.Hideable,
	ImGuiTableFlags.ScrollX,
	ImGuiTableFlags.RowBg
)

local childFlags     = bit32.bor(
	ImGuiChildFlags.Border
-- ImGuiChildFlags.ResizeY
)

local buttonWinFlags = bit32.bor(
	ImGuiWindowFlags.NoTitleBar,
	ImGuiWindowFlags.NoResize,
	ImGuiWindowFlags.NoScrollbar,
	ImGuiWindowFlags.NoFocusOnAppearing,
	ImGuiWindowFlags.AlwaysAutoResize
)

local function LoadSettings()
	if not Module.Utils.File.Exists(configFile) then
		mq.pickle(configFile, defaults)
		printf("\ayConfig file not found. Creating new config file: %s", configFile)
	end
	local config = dofile(configFile) or {}
	if type(config) == "table" then
		for k, v in pairs(defaults) do
			if config[k] == nil then
				config[k] = v
			end
		end
	end
	Module.Settings = config
	Module.ShowGui = Module.Settings.showUI
end

--Helpers
local function CommandHandler(...)
	local args = { ..., }
	if args[1] ~= nil then
		if args[1] == 'exit' or args[1] == 'quit' then
			Module.IsRunning = false
			Module.Utils.PrintOutput('MyAA', true, "\ay%s \awis \arExiting\aw...", Module.Name)
		elseif args[1] == 'show' or args[1] == 'ui' then
			Module.ShowGui = not Module.ShowGui
		end
	end
end

function Module.UpdateAA(which)
	if which == nil then which = "all" end
	if which == "general" or which == "all" then
		genAA = Module.GetAALists("general")
	end
	if which == "arch" or which == "archtype" or which == "all" then
		archAA = Module.GetAALists("arch")
	end
	if which == "class" or which == "all" then
		classAA = Module.GetAALists("class")
	end
	if which == "special" or which == "all" then
		specAA = Module.GetAALists("special")
	end
	availAA = MySelf.AAPoints() or 0
	spentAA = MySelf.AAPointsSpent() or 0
	totalAA = MySelf.AAPointsTotal() or 0
	TotalMaxAA.all = TotalMaxAA.general + TotalMaxAA.arch + TotalMaxAA.class + TotalMaxAA.special
	CurSectionAA.all = CurSectionAA.general + CurSectionAA.arch + CurSectionAA.class + CurSectionAA.special
	lastCheck = os.time() -- Update the last check time
end

local function Init()
	-- your Init code here
	LoadSettings() -- Load the settings from the config file
	mq.bind('/myaa', CommandHandler)
	Module.IsRunning = true
	Module.Utils.PrintOutput('MyAA', false, "\a-w[\at%s\a-w] \agLoaded\aw!", Module.Name)
	Module.UpdateAA("all") -- Update the AA lists

	if not loadedExeternally then
		mq.imgui.init(Module.Name, Module.RenderGUI)
		Module.LocalLoop()
	end
end

function Module.TrainAA()
	for name, data in pairs(toTrain) do
		local aaStart = availAA
		if data.row and data.list then
			data.list.Select(data.row)                                            -- Select the AA in the AA window
			mq.delay(30)
			mq.TLO.Window("AAWindow/AAW_TrainButton").LeftMouseUp()               -- Click the Train button
			mq.delay(2000, function() return MySelf.AAPoints() <= aaStart - data.cost end) -- Wait until AA points are updated
			availAA = MySelf.AAPoints() or 0                                      -- Update the available AA points
			Module.UpdateAA(data.section)                                         -- Update the AA lists after training
			if availAA == aaStart - data.cost then
				Module.Utils.PrintOutput('MyAA', false, "\aw[\at%s\ax] \agTrained \ay%s\ag for \ay%s\ag AA points.", Module.Name, name, data.cost)
			else
				Module.Utils.PrintOutput('MyAA', false, "\aw[\at%s\ax] \arFailed to train \ay%s\ar for \ay%s\ar AA points.", Module.Name, name, data.cost)
			end
		end
	end
	toTrain = {} -- Clear the toTrain table after training
	doTrain = false -- Reset the doTrain flag
end

function Module.SetHotkey()
	for name, data in pairs(toHotkey) do
		if data.row and data.list then
			data.list.Select(data.row)
			mq.delay(30)
			mq.TLO.Window("AAWindow/AAW_HotButton").LeftMouseUp()
		end
	end

	toHotkey = {} -- Clear the toHotkey table after setting hotkeys
	doHotkey = false -- Reset the doHotkey flag
end

function Module.FormatTime(seconds)
	if seconds < 0 then
		return "N/A"
	end
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

function Module.GetAALists(which)
	availAA       = MySelf.AAPoints() or 0
	spentAA       = MySelf.AAPointsSpent() or 0
	totalAA       = MySelf.AAPointsTotal() or 0
	local tmp     = {}
	local list    = mq.TLO.Window("AAWindow/AAW_GeneralList")
	local maxList = mq.TLO.Window("AAWindow/AAW_GeneralList").Items() or 0
	if which == 'general' then
		list = mq.TLO.Window("AAWindow/AAW_GeneralList")
		maxList = mq.TLO.Window("AAWindow/AAW_GeneralList").Items() or 0
	elseif which == 'arch' then
		list = mq.TLO.Window("AAWindow/AAW_ArchList")
		maxList = mq.TLO.Window("AAWindow/AAW_ArchList").Items() or 0
	elseif which == 'class' then
		list = mq.TLO.Window("AAWindow/AAW_ClassList")
		maxList = mq.TLO.Window("AAWindow/AAW_ClassList").Items() or 0
	elseif which == 'special' then
		list = mq.TLO.Window("AAWindow/AAW_SpecialList")
		maxList = mq.TLO.Window("AAWindow/AAW_SpecialList").Items() or 0
	else
		return tmp
	end
	local tmpCounterMax = 0
	local tmpCounterCur = 0

	for i = 1, maxList do
		local aaName = list.List(i, 1)()
		local aaCurMax = list.List(i, 2)() -- value in "cur/max"
		local aaCost = list.List(i, 3)()
		local aaType = list.List(i, 4)()
		local ability = mq.TLO.AltAbility(aaName)
		local passive = ability.Passive() or false
		local minLvl = ability.MinLevel() or 0
		local canTrain = ability.CanTrain() or false -- gets buggy after training something but works ok for the initial checks
		local aaCurrent, aaMax = string.match(aaCurMax, "(%d+)/(%d+)")
		local reqAbility = ability.RequiresAbility.Name() or nil
		local reqAbilityPoints = ability.RequiresAbilityPoints() or 0
		local aaTimer = ability.MyReuseTime() or 0
		local aaTimeLeftSeconds = not passive and (mq.TLO.Me.AltAbilityTimer(ability.ID()).TotalSeconds() or 0) or -1
		aaCurrent = tonumber(aaCurrent) or 0
		aaMax = tonumber(aaMax) or 0
		aaCost = tonumber(aaCost) or 0
		currentRanks[aaName] = aaCurrent
		tmpCounterMax = tmpCounterMax + aaMax
		tmpCounterCur = tmpCounterCur + aaCurrent
		if not canTrain then
			if availAA >= aaCost and aaCurrent < aaMax and MySelf.Level() >= minLvl then
				if reqAbility == nil then
					canTrain = true
				elseif currentRanks[reqAbility] ~= nil and
					currentRanks[reqAbility] >= reqAbilityPoints then
					canTrain = true
				else
					canTrain = false
				end
			end
		end

		if aaName and aaCurrent and aaMax then
			table.insert(tmp, {
				['Name'] = aaName,
				['MinLvl'] = minLvl,
				['CanTrain'] = canTrain,
				['Passive'] = passive,
				['Current'] = aaCurrent,
				['Max'] = aaMax,
				['Cost'] = aaCost,
				['Type'] = aaType,
				['Timer'] = aaTimer,
				['TimeLeftSeconds'] = aaTimeLeftSeconds,
			})
		end
	end
	CurSectionAA[which] = tmpCounterCur
	TotalMaxAA[which] = tmpCounterMax
	return tmp
end

local function DrawAATable(which_Table, label)
	local ListName = mq.TLO.Window("AAWindow/AAW_GeneralList")
	if label == "General" then
		ListName = mq.TLO.Window("AAWindow/AAW_GeneralList")
	elseif label == "Archtype" then
		ListName = mq.TLO.Window("AAWindow/AAW_ArchList")
	elseif label == "Class" then
		ListName = mq.TLO.Window("AAWindow/AAW_ClassList")
	elseif label == "Special" then
		ListName = mq.TLO.Window("AAWindow/AAW_SpecialList")
	else
		return
	end
	local sizeX, sizeY = ImGui.GetContentRegionAvail()
	if ImGui.BeginChild("Child##" .. label, ImVec2(sizeX, sizeY * 0.7), childFlags) then
		ImGui.SetWindowFontScale(Module.Settings.scale)

		if ImGui.BeginTable(label .. "##TableData3", 6, tableFlags) then
			ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.WidthStretch)
			ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthFixed, 50)
			ImGui.TableSetupColumn("Cost", ImGuiTableColumnFlags.WidthFixed, 30)
			ImGui.TableSetupColumn("Type", ImGuiTableColumnFlags.WidthFixed, 100)
			ImGui.TableSetupColumn("Train", ImGuiTableColumnFlags.WidthFixed, 40)
			ImGui.TableSetupColumn("HotKey", ImGuiTableColumnFlags.WidthFixed, 50)
			ImGui.TableSetupScrollFreeze(0, 1) -- Make the first row always visible
			ImGui.TableHeadersRow()
			ImGui.TableNextRow()
			for _, data in ipairs(which_Table) do
				ImGui.PushID(data.Name .. data.Type)
				ImGui.TableNextColumn()
				local isSelected = (selectedAA == data.Name)
				if ImGui.Selectable(data.Name .. "##" .. data.Type, isSelected) then
					local rowNum = ListName.List(data.Name, 1)() or 0 -- Select the AA in the AA window
					ListName.Select(rowNum)            -- Select the AA in the AA window
					selectedAA = data.Name
					selectedTimeLeft = data.TimeLeftSeconds or -1
				end
				ImGui.TableNextColumn()
				ImGui.Indent(3)
				ImGui.Text(string.format("%s / %s", data.Current or 0, data.Max or 0))
				ImGui.Unindent(3)
				ImGui.TableNextColumn()
				ImGui.Indent(10)
				ImGui.Text(data.Cost or "N/A")
				ImGui.Unindent(10)
				ImGui.TableNextColumn()
				ImGui.Text(data.Type or "N/A")
				ImGui.TableNextColumn()
				local cost = tonumber(data.Cost) or 0
				local cur = tonumber(data.Current) or 0
				local max = tonumber(data.Max) or 0
				if data.CanTrain then
					if ImGui.SmallButton("Train##" .. data.Name) then
						selectedAA = data.Name
						local rowNum = ListName.List(data.Name, 1)() or 0                                -- Select the AA in the AA window
						toTrain[data.Name] = { row = rowNum, list = ListName, cost = cost or 0, section = label:lower(), } -- Store the row number and list for later use
						doTrain = true
					end
				end
				ImGui.TableNextColumn()
				if not data.Passive and (tonumber(data.Current) or 0) > 0 then
					if ImGui.SmallButton("HotKey##" .. data.Name) then
						selectedAA = data.Name
						local rowNum = ListName.List(data.Name, 1)() or 0               -- Select the AA in the AA window
						toHotkey[data.Name] = { row = rowNum, list = ListName, section = label:lower(), } -- Store the row number and list for later use
						doHotkey = true
					end
				end
				ImGui.PopID()
			end
			ImGui.EndTable()
		end
		ImGui.SetWindowFontScale(1)
	end
	ImGui.EndChild()
end

local function RenderBtn()
	-- apply_style()
	ImGui.SetNextWindowPos(ImVec2(200, 20), ImGuiCond.FirstUseEver)
	local openBtn, showBtn = ImGui.Begin(string.format(Module.Name .. "##MiniBtn" .. Module.CharLoaded), true, buttonWinFlags)
	if not openBtn then
		showBtn = false
	end

	if showBtn then
		local cursorPosX, cursorPosY = ImGui.GetCursorScreenPos()
		animMini:SetTextureCell(2305 - EQ_ICON_OFFSET)
		ImGui.DrawTextureAnimation(animMini, 34, 34, true)
		ImGui.SetCursorScreenPos(cursorPosX, cursorPosY)
		ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
		ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0.5, 0.5, 0, 0.5))
		ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImVec4(0, 0, 0, 0))
		if ImGui.Button("##" .. Module.Name, ImVec2(34, 34)) then
			Module.ShowGui = not Module.ShowGui
			Module.Settings.showUI = Module.ShowGui
			mq.pickle(configFile, Module.Settings)
		end
		ImGui.PopStyleColor(3)
		-- if ImGui.IsItemHovered() then
		-- 	if ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
		-- 		Module.Settings.showUI = not Module.Settings.showUI
		-- 		mq.pickle(configFile, Module.Settings)
		-- 	end
		-- end
	end
	if ImGui.IsWindowHovered() then
		ImGui.BeginTooltip()
		ImGui.Text(Module.Name)
		ImGui.Text("Left-click to toggle UI")
		-- ImGui.Text("Right-click for options")
		ImGui.Text("Available AA: %s", availAA)
		ImGui.EndTooltip()
	end
	-- if ImGui.BeginPopupContextWindow("ItemTrackerContext") then
	-- 	if ImGui.MenuItem(Module.Settings.lockWindow and "Unlock Window" or "Lock Window") then
	-- 		Module.Settings.lockWindow = not Module.Settings.lockWindow
	-- 		mq.pickle(configFile, Module.Settings)
	-- 	end
	-- 	ImGui.EndPopup()
	-- end
	ImGui.End()
end
local tabPage = mq.TLO.Window("AAWindow/AAW_Subwindows")

-- Exposed Functions
function Module.RenderGUI()
	local styleCount, colorCount = Module.ThemeLoader.StartTheme(MyUI_ThemeName or Module.ThemeName, MyUI_Theme or Module.Theme)
	if Module.ShowGui then
		ImGui.SetNextWindowSize(ImVec2(600, 400), ImGuiCond.FirstUseEver)
		ImGui.SetNextWindowPos(ImVec2(100, 100), ImGuiCond.FirstUseEver)
		local open, show = ImGui.Begin(Module.Name .. "##1" .. Module.CharLoaded, true, ImGuiWindowFlags.None)
		if not open then
			show = false
			Module.ShowGui = false
			Module.Settings.showUI = Module.ShowGui
			mq.pickle(configFile, Module.Settings)
		end
		if show then
			local sizeX, sizeY = ImGui.GetContentRegionAvail()
			Module.Settings.showBtn, _ = ImGui.Checkbox("Show Mini Button", Module.Settings.showBtn)
			ImGui.SameLine()
			ImGui.SetNextItemWidth(100)
			Module.Settings.scale, _ = ImGui.SliderFloat("Scale", Module.Settings.scale, 0.5, 2.0, "%.1f")
			ImGui.SetWindowFontScale(Module.Settings.scale)

			ImGui.Text("Available AA:")
			ImGui.SameLine()
			ImGui.TextColored(Module.Colors.color("yellow"), "%s", availAA)
			ImGui.SameLine()

			ImGui.Text("Spent:")
			ImGui.SameLine()
			ImGui.TextColored(Module.Colors.color("teal"), "%s", spentAA)
			ImGui.SameLine()

			ImGui.Text("Total AA:")
			ImGui.SameLine()
			ImGui.TextColored(Module.Colors.color('tangarine'), "%s", totalAA)

			ImGui.SeparatorText("Current Ranks:")

			ImGui.Text('Gen:')
			ImGui.SameLine()
			ImGui.TextColored(Module.Colors.color('yellow'), "%s/%s", CurSectionAA.general, TotalMaxAA.general)
			ImGui.SameLine()

			ImGui.Text('Arch:')
			ImGui.SameLine()
			ImGui.TextColored(Module.Colors.color('green2'), "%s/%s", CurSectionAA.arch, TotalMaxAA.arch)
			ImGui.SameLine()

			ImGui.Text('Class:')
			ImGui.SameLine()
			ImGui.TextColored(Module.Colors.color('teal'), "%s/%s", CurSectionAA.class, TotalMaxAA.class)
			ImGui.SameLine()

			ImGui.Text('Spec:')
			ImGui.SameLine()
			ImGui.TextColored(Module.Colors.color('tangarine'), "%s/%s", CurSectionAA.special, TotalMaxAA.special)

			ImGui.Text("Cur / Max Ranks:")
			ImGui.SameLine()
			ImGui.TextColored(Module.Colors.color('green'), "%s/%s", CurSectionAA.all, TotalMaxAA.all)
			if _ then
				mq.pickle(configFile, Module.Settings)
			end
			if ImGui.BeginTabBar("MyAA") then
				if ImGui.BeginTabItem(string.format("General (%s/%s)###GeneralMyAA", CurSectionAA.general, TotalMaxAA.general)) then
					tabPage.SetCurrentTab(1)
					DrawAATable(genAA, "General")
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem(string.format("Archtype (%s/%s)###ArchtypeMyAA", CurSectionAA.arch, TotalMaxAA.arch)) then
					tabPage.SetCurrentTab(2)
					DrawAATable(archAA, "Archtype")
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem(string.format("Class (%s/%s)###ClassMyAA", CurSectionAA.class, TotalMaxAA.class)) then
					tabPage.SetCurrentTab(3)
					DrawAATable(classAA, "Class")
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem(string.format("Special (%s/%s)###SpecialMyAA", CurSectionAA.special, TotalMaxAA.special)) then
					tabPage.SetCurrentTab(4)
					DrawAATable(specAA, "Special")
					ImGui.EndTabItem()
				end
				ImGui.EndTabBar()
			end
			ImGui.Separator()
			if ImGui.BeginChild("AA Description", ImVec2(sizeX, sizeY * 0.2), childFlags) then
				ImGui.PushTextWrapPos(sizeX - 20)
				if selectedTimeLeft > 0 then
					ImGui.Text('Time Left:')
					ImGui.SameLine()
					ImGui.TextColored(Module.Colors.color('yellow'), "%s", Module.FormatTime(selectedTimeLeft - (os.time() - lastCheck)))
				elseif selectedTimeLeft == 0 then
					ImGui.TextColored(Module.Colors.color('green'), 'Ready')
				elseif selectedTimeLeft == -1 then
					ImGui.Text('Passive')
				end
				ImGui.Text(mq.TLO.Window("AAWindow/AAW_Description").Text():gsub("<BR>", "\n"):gsub("%%", " "))
				ImGui.PopTextWrapPos()
			end
			ImGui.EndChild()
			ImGui.SetWindowFontScale(1)
		end

		ImGui.End()
	end
	if Module.Settings.showBtn then
		RenderBtn()
	end
	MyUI_ThemeLoader.EndTheme(styleCount, colorCount)
end

function Module.Unload()
	mq.unbind('/myaa')
end

function Module.MainLoop()
	if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end

	-- if not Module.ShowGui or (Module.ShowGui and mq.gettime() - drawTimerMS < 500) then
	-- 	return
	-- else
	-- 	drawTimerMS = mq.gettime()
	-- 	genAA = Module.GetAALists("general")
	-- 	classAA = Module.GetAALists("class")
	-- 	archAA = Module.GetAALists("arch")
	-- 	specAA = Module.GetAALists("special")
	-- end
	if Module.LastCheck == nil then
		Module.LastCheck = mq.gettime()
	end
	if mq.gettime() - Module.LastCheck > 3000 then
		Module.UpdateAA("all") -- Update the AA lists
		Module.LastCheck = mq.gettime()
	end
	if doTrain then
		Module.TrainAA()
	end
	if doHotkey then
		Module.SetHotkey()
	end
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

Init()
return Module
