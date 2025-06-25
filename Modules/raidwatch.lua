--[[ RaidWatch Module for MyUI
This module is designed to monitor raid members in EverQuest, displaying their status, distance, and
corpse information in a GUI.
Ctrl clicking a member will bring them to the foreground.
Right clicking a member will give you options to target, switch to, or navigate to them or their corpse.
]]

local mq = require('mq')
local ImGui = require 'ImGui'
local drawTimerMS = mq.gettime() -- get the current time in milliseconds
local drawTimerS = os.time()     -- get the current time in seconds
local Module = {}

Module.Name = "RaidWatch" -- Name of the module used when loading and unloaing the modules.
Module.IsRunning = false  -- Keep track of running state. if not running we can unload it.
Module.ShowGui = true
Module.TempSettings = {
	CorpseFound = false,
}


-- check if the script is being loaded as a Module (externally) or as a Standalone script.
---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false
if not loadedExeternally then
	-- for local standalone use we will need to load in the global MyUI_ variables and functions. and make sure to include the files as needed inside of the scripts folder.
	-- Comment/Uncomment the items below as needed
	Module.Utils       = require('lib.common') -- common functions for use in other scripts
	Module.Icons       = require('mq.ICONS') -- FAWESOME ICONS
	-- Module.Actor         = require('actors') -- Actors if needed
	-- Module.Base64        = require('lib.base64') -- Ensure you have a base64 module available
	-- Module.PackageMan    = require('mq.PackageMan')
	-- Module.SQLite3       = Module.PackageMan.Require('lsqlite3')
	Module.Colors      = require('lib.colors')    -- color table for GUI returns ImVec4
	Module.ThemeLoader = require('lib.theme_loader') -- Load the theme loader
	-- Module.AbilityPicker = require('lib.AbilityPicker') -- Ability Picker

	-- build, char, server info
	Module.CharLoaded  = mq.TLO.Me.DisplayName()
	Module.Server      = mq.TLO.EverQuest.Server()
	Module.Build       = mq.TLO.MacroQuest.BuildName()
	Module.Guild       = mq.TLO.Me.Guild() or "none"
else
	-- for MyUI use we will use the global MyUI_ variables and functions.
	Module.Utils       = MyUI_Utils
	Module.Icons       = MyUI_Icons
	Module.Colors      = MyUI_Colors
	Module.ThemeLoader = MyUI_ThemeLoader
	Module.Icons       = MyUI_Icons -- if you need icons in your module
	-- Module.Colors      = MyUI_Colors -- if you need colors in your module
	-- Module.Icons       = MyUI_ICONS -- if you need icons in your module
	Module.CharLoaded  = MyUI_CharLoaded
	Module.Server      = MyUI_Server or "Unknown" -- Get the server name
end
local rSize = mq.TLO.Raid.Members() or 0
local raidMembers = {}

local function SortTable(table_to_sort)
	if #table_to_sort <= 0 then
		return {}
	end
	table.sort(table_to_sort, function(a, b)
		if a.class == b.class then
			return a.name < b.name
		else
			return a.class < b.class
		end
	end)

	return table_to_sort
end
--Helpers
-- You can keep your functions local to the module the ones here are the only ones we care about from the main script.
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

local function getMembers()
	local temp = {}
	local foundCorpse = false
	for i = 1, rSize do
		local member = mq.TLO.Raid.Member(i)
		if member() then
			local memberName = member.Name() or "Unknown_Member"
			local present = (mq.TLO.SpawnCount(string.format("PC =%s", memberName))() or 0) > 0
			local memberClass = member.Class.ShortName() or "Unknown"
			local hasCorpse = mq.TLO.Spawn(string.format("%s's corpse", memberName))() ~= nil
			local checkLD = string.format("=%s", memberName)
			if mq.TLO.Spawn(checkLD).Linkdead() then
				present = false
				memberClass = "* LD *"
			end
			table.insert(temp, {
				name = memberName,
				class = memberClass,
				present = present,
				corpse = hasCorpse,
				distance = member.Distance() or 99999,
				corpseDistance = hasCorpse and mq.TLO.Spawn(string.format("%s's corpse", memberName)).Distance() or -1,
				visable = not (member.Invis(0)() or false),
			})
			if hasCorpse then foundCorpse = true end
		end
	end
	Module.TempSettings.CorpseFound = foundCorpse
	return SortTable(temp)
end

local function Init()
	-- your Init code here
	Module.IsRunning = true
	Module.Utils.PrintOutput('main', true, "\ayModule \a-w[\at%s\a-w] \agLoaded\aw!", Module.Name)
	raidMembers = getMembers()
	-- for standalone mode we need to init the GUI and use a real loop
	if not loadedExeternally then
		mq.imgui.init(Module.Name, Module.RenderGUI)
		Module.LocalLoop()
	end
end

local winFlags = bit32.bor(
	ImGuiWindowFlags.NoCollapse,
	ImGuiWindowFlags.NoResize,
	ImGuiWindowFlags.NoTitleBar,
	ImGuiWindowFlags.AlwaysAutoResize,
	ImGuiWindowFlags.NoScrollbar,
	ImGuiWindowFlags.NoScrollWithMouse
)


-- Exposed Functions
function Module.RenderGUI()
	if rSize <= 0 and #raidMembers <= 0 then
		Module.ShowGui = false
		return
	end
	if Module.ShowGui then
		ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(0.1, 0.1, 0.1, 0.8))
		local open, show = ImGui.Begin(Module.Name .. "##" .. Module.CharLoaded, true, winFlags)
		if not open then
			show = false
			Module.ShowGui = false
		end
		if show then
			--GUI
			-- your code here
			local colCount = Module.TempSettings.CorpseFound and 4 or 3
			if ImGui.BeginTable("Raid Watch##" .. Module.CharLoaded, colCount) then
				if colCount == 4 then ImGui.TableSetupColumn("Corpse", ImGuiTableColumnFlags.WidthFixed, 70) end
				ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.WidthStretch, 5)
				ImGui.TableSetupColumn("Class", ImGuiTableColumnFlags.WidthFixed, ImGui.CalcTextSize('* LD *'))
				ImGui.TableSetupColumn("Distance", ImGuiTableColumnFlags.WidthFixed, ImGui.CalcTextSize('(99999)'))
				ImGui.TableNextRow()
			end

			for _, data in ipairs(raidMembers or {}) do
				local displayString = string.format("%s - %s", data.name, data.class)

				if colCount == 4 then
					ImGui.TableNextColumn()

					if data.corpse then
						ImGui.TextColored(Module.Colors.color("pink"), Module.Icons.MD_HEALING)
						ImGui.SameLine()
						ImGui.Text("(%0.1f)", data.corpseDistance)
					end
				end

				ImGui.TableNextColumn()

				ImGui.PushID(data.name .. data.class)

				if data.present then
					if not data.visable then
						ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(0.734, 0.734, 0.734, 1.000))
					else
						ImGui.PushStyleColor(ImGuiCol.Text, Module.Colors.color("softblue"))
					end
				else
					ImGui.PushStyleColor(ImGuiCol.Text, Module.Colors.color("tangarine"))
				end
				ImGui.PushStyleColor(ImGuiCol.HeaderHovered, ImVec4(0.036, 0.000, 0.137, 0.800))

				local label = data.visable and data.name or string.format("%s %s", Module.Icons.FA_EYE_SLASH, data.name)

				if ImGui.Selectable(label, false, ImGuiSelectableFlags.SpanAllColumns) then
					if data.corpse then
						mq.cmdf("/target %s's", data.name)
					else
						mq.cmdf("/target %s", data.name)
					end
					if ImGui.IsKeyDown(ImGuiMod.Ctrl) then
						mq.cmdf("/dex %s /foreground", data.name)
					end
				end

				ImGui.PopStyleColor(2)

				if ImGui.BeginPopupContextItem(data.name .. "##RaidMemberContext") then
					if ImGui.Selectable("switch", false) then
						mq.cmdf("/dex %s /foreground", data.name)
					end
					if ImGui.Selectable('Come to Me') then
						mq.cmdf("/dex %s /nav id %s dist=15 lineofsight=on", data.name, mq.TLO.Me.ID())
					end
					if ImGui.Selectable('Go To ' .. data.name) then
						local id = mq.TLO.Spawn(string.format("=%s", data.name)).ID() or 0
						if id > 0 then
							mq.cmdf("/nav id %s dist=15 lineofsight=on", id)
						end
					end
					if data.corpse then
						if ImGui.Selectable("Nav to Corpse") then
							local corpse = mq.TLO.Spawn(string.format("%s's corpse", data.name))
							if corpse() then
								mq.cmdf("/nav id %s dist=15 lineofsight=on", corpse.ID())
							else
								Module.Utils.PrintOutput('main', true, "\arNo Corpse found for %s", data.name)
							end
						end
					end
					ImGui.EndPopup()
				end
				ImGui.PopID()

				ImGui.TableNextColumn()

				if data.present then
					ImGui.TextColored(Module.Colors.color("softblue"), data.class)
				else
					ImGui.TextColored(Module.Colors.color("tangarine"), data.class)
				end

				ImGui.TableNextColumn()

				if data.present then
					if data.distance > 100 then
						ImGui.TextColored(Module.Colors.color("tangarine"), "(%0.1f)", mq.TLO.Spawn(string.format("=%s", data.name)).Distance() or 99999)
					else
						ImGui.TextColored(Module.Colors.color("yellow"), "(%0.1f)", mq.TLO.Spawn(string.format("=%s", data.name)).Distance() or 99999)
					end
				end
			end
			ImGui.EndTable()
		end
		ImGui.PopStyleColor()
		ImGui.End()
	end
end

function Module.Unload()
	-- undo any binds and events before unloading
	-- leave empty if you don't have any binds or events
end

function Module.MainLoop()
	-- This will unload the module gracefully if IsRunning state changes.
	if loadedExeternally and not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end

	-- This will only allow the MainLoop to run every 500ms (half a secon)
	if mq.gettime() - drawTimerMS < 1000 then
		return
	else
		-- your code here
		drawTimerMS = mq.gettime()
		rSize = mq.TLO.Raid.Members() or 0
		if rSize > 0 then raidMembers = getMembers() end

		if rSize > 0 then
			Module.ShowGui = true
		else
			Module.ShowGui = false
			raidMembers = {}
		end
		-- drawTimerS = os.time()
	end
	--[[
	your MainLoop code here without the loop.
	
	DO NOT USE WHILE loops here.
	The real loop for standalone mode is
	Module.LocalLoop()
	which will call this function in a loop.
	
	For Module use in MyUI the MainLoop will be called by the main script as needed.
	]]
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

-- Init the module
Init()
return Module
