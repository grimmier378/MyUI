local mq = require('mq')
local ImGui = require 'ImGui'
local drawTimerMS = mq.gettime() -- get the current time in milliseconds
local drawTimerS = os.time()     -- get the current time in seconds
local Module = {}
local MySelf = mq.TLO.Me
local genAA = {}
local classAA = {}
local archAA = {}
local specAA = {}
local doTrain = false

Module.Name = "MyAA"     -- Name of the module used when loading and unloaing the modules.
Module.IsRunning = false -- Keep track of running state. if not running we can unload it.
Module.ShowGui = true

-- check if the script is being loaded as a Module (externally) or as a Standalone script.
---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false
if not loadedExeternally then
	Module.Utils       = require('lib.common')    -- common functions for use in other scripts
	Module.Icons       = require('mq.ICONS')      -- FAWESOME ICONS
	Module.Colors      = require('lib.colors')    -- color table for GUI returns ImVec4
	Module.ThemeLoader = require('lib.theme_loader') -- Load the theme loader
	Module.CharLoaded  = MySelf.CleanName()
else
	Module.Utils       = MyUI_Utils
	Module.Icons       = MyUI_Icons
	Module.Colors      = MyUI_Colors
	Module.ThemeLoader = MyUI_ThemeLoader
	Module.CharLoaded  = MyUI_CharLoaded
end
local availAA = MySelf.AAPoints() or 0
local toTrain = {}
--Helpers
local function CommandHandler(...)
	local args = { ..., }
	if args[1] ~= nil then
		if args[1] == 'exit' or args[1] == 'quit' then
			Module.IsRunning = false
			Module.Utils.PrintOutput('MyUI', true, "\ay%s \awis \arExiting\aw...", Module.Name)
		elseif args[1] == 'show' or args[1] == 'ui' then
			Module.ShowGui = not Module.ShowGui
		end
	end
end

local function Init()
	-- your Init code here
	mq.bind('/myaa', CommandHandler)
	Module.IsRunning = true
	Module.Utils.PrintOutput('MyUI', false, "\a-w[\at%s\a-w] \agLoaded\aw!", Module.Name)
	genAA = Module.GetAALists("general")
	classAA = Module.GetAALists("class")
	archAA = Module.GetAALists("arch")
	specAA = Module.GetAALists("special")

	if not loadedExeternally then
		mq.imgui.init(Module.Name, Module.RenderGUI)
		Module.LocalLoop()
	end
end

function Module.GetAALists(which)
	availAA = MySelf.AAPoints() or 0
	local tmp = {}
	local list = mq.TLO.Window("AAWindow/AAW_GeneralList")
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

	for i = 1, maxList do
		local aaName = list.List(i, 1)()
		local aaCurMax = list.List(i, 2)() -- value in "cur/max"
		local aaCost = list.List(i, 3)()
		local aaType = list.List(i, 4)()
		local aaCurrent, aaMax = string.match(aaCurMax, "(%d+)/(%d+)")
		if aaName and aaCurrent and aaMax then
			table.insert(tmp, { ['Name'] = aaName, ['Current'] = tonumber(aaCurrent), ['Max'] = tonumber(aaMax), ['Cost'] = aaCost, ['Type'] = aaType, })
		end
	end
	return tmp
end

local tableFlags = bit32.bor(
	ImGuiTableFlags.ScrollY,
	ImGuiTableFlags.BordersOuter,
	ImGuiTableFlags.BordersInner,
	ImGuiTableFlags.Resizable,
	ImGuiTableFlags.Reorderable,
	ImGuiTableFlags.Hideable,
	ImGuiTableFlags.ScrollX,
	ImGuiTableFlags.RowBg
)

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
	if ImGui.BeginTable(label .. "##table2", 5, tableFlags, ImVec2(0, sizeY * 0.75)) then
		ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthFixed, 100)
		ImGui.TableSetupColumn("Cost", ImGuiTableColumnFlags.WidthFixed, 40)
		ImGui.TableSetupColumn("Type", ImGuiTableColumnFlags.WidthFixed, 100)
		ImGui.TableSetupColumn("Train", ImGuiTableColumnFlags.WidthFixed, 100)
		ImGui.TableSetupScrollFreeze(0, 1) -- Make the first row always visible
		ImGui.TableHeadersRow()
		ImGui.TableNextRow()
		for _, data in ipairs(which_Table) do
			ImGui.PushID(data.Name .. data.Type)
			ImGui.TableNextColumn()
			if ImGui.Selectable(data.Name .. "##" .. data.Type, false, ImGuiSelectableFlags.SpanAllColumns) then
				local rowNum = ListName.List(data.Name, 1)() or 0 -- Select the AA in the AA window
				ListName.Select(rowNum)               -- Select the AA in the AA window
			end
			ImGui.TableNextColumn()
			ImGui.Text(string.format("%s / %s", data.Current or 0, data.Max or 0))
			ImGui.TableNextColumn()
			ImGui.Text(data.Cost or "N/A")
			ImGui.TableNextColumn()
			ImGui.Text(data.Type or "N/A")
			ImGui.TableNextColumn()
			local cost = tonumber(data.Cost) or 0
			local cur = tonumber(data.Current) or 0
			local max = tonumber(data.Max) or 0
			if availAA >= cost and cur < max then
				if ImGui.SmallButton("train##" .. data.Name) then
					local rowNum = ListName.List(data.Name, 1)() or 0 -- Select the AA in the AA window
					toTrain[data.Name] = { row = rowNum, list = ListName, } -- Store the row number and list for later use
					doTrain = true
				end
			end
			ImGui.PopID()
		end

		ImGui.EndTable()
	end
end

-- Exposed Functions
function Module.RenderGUI()
	if Module.ShowGui then
		ImGui.SetNextWindowSize(ImVec2(600, 400), ImGuiCond.FirstUseEver)
		ImGui.SetNextWindowPos(ImVec2(100, 100), ImGuiCond.FirstUseEver)
		local open, show = ImGui.Begin(Module.Name .. "##1" .. Module.CharLoaded, true, ImGuiWindowFlags.None)
		if not open then
			show = false
			Module.ShowGui = false
			Module.IsRunning = false
		end
		if show then
			local sizeX, sizeY = ImGui.GetContentRegionAvail()
			ImGui.Text("Available AA: %s", availAA)

			if ImGui.BeginTabBar("MyAA") then
				if ImGui.BeginTabItem("General") then
					DrawAATable(genAA, "General")
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem("Archtype") then
					DrawAATable(archAA, "Archtype")
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem("Class") then
					DrawAATable(classAA, "Class")
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem("Special") then
					DrawAATable(specAA, "Special")
					ImGui.EndTabItem()
				end
				ImGui.EndTabBar()
			end
			ImGui.Separator()
			if ImGui.BeginChild("AA Description", ImVec2(sizeX, sizeY * 0.2), bit32.bor(ImGuiChildFlags.Border)) then
				ImGui.PushTextWrapPos(sizeX - 20)
				ImGui.Text(mq.TLO.Window("AAWindow/AAW_Description").Text():gsub("<BR>", "\n"))
				ImGui.PopTextWrapPos()
			end
			ImGui.EndChild()
		end

		ImGui.End()
	end
end

function Module.Unload()
	mq.unbind('/myaa')
end

function Module.MainLoop()
	if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end

	if mq.gettime() - drawTimerMS < 500 then
		return
	else
		drawTimerMS = mq.gettime()
		genAA = Module.GetAALists("general")
		classAA = Module.GetAALists("class")
		archAA = Module.GetAALists("arch")
		specAA = Module.GetAALists("special")
	end
	if doTrain then
		for name, data in pairs(toTrain) do
			if data.row and data.list then
				data.list.Select(data.row)                  -- Select the AA in the AA window
				mq.delay(300)
				mq.TLO.Window("AAWindow/AAW_TrainButton").LeftMouseUp() -- Click the Train button
			end
		end

		toTrain = {} -- Clear the toTrain table after training
		doTrain = false -- Reset the doTrain flag
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
