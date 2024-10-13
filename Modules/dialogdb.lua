local mq                                                          = require('mq')
local ImGui                                                       = require('ImGui')
local Module                                                      = {}
Module.theme                                                      = {}
Module.ActorMailBox                                               = nil
Module.ShowDialog, Module.ConfUI, Module.editGUI, Module.themeGUI = false, false, false, false
Module.themeName                                                  = 'Default'
Module.IsRunning                                                  = false
Module.Name                                                       = "DialogDB"
Module.Path                                                       = Module.Path ~= nil and Module.Path or string.format("%s/%s/", mq.luaDir, Module.Name)

---@diagnostic disable-next-line:undefined-global
local loadedExeternally                                           = MyUI_ScriptName ~= nil and true or false

if not loadedExeternally then
	Module.Utils       = require('lib.common')
	Module.CharLoaded  = mq.TLO.Me.DisplayName()
	Module.Server      = mq.TLO.EverQuest.Server()
	Module.Icons       = require('mq.ICONS')
	Module.Build       = mq.TLO.MacroQuest.BuildName()
	Module.ThemeLoader = require('lib.theme_loader')
else
	Module.Utils = MyUI_Utils
	Module.CharLoaded = MyUI_CharLoaded
	Module.Server = MyUI_Server
	Module.Icons = MyUI_Icons
	Module.Build = MyUI_Build
	Module.ThemeLoader = MyUI_ThemeLoader
end

local LoadTheme = Module.ThemeLoader
local themeID = 1
local themeFileOld = string.format('%s/MyThemeZ.lua', mq.configDir)
local themeFile = Module.ThemeFile == nil and string.format('%s/MyUI/ThemeZ.lua', mq.configDir) or Module.ThemeFile

local gIcon = Module.Icons.MD_SETTINGS
local hasDialog = false
local Dialog = require('defaults.npc_dialog')
local lastZone
local cmdGroup = '/dgge'
local cmdZone = '/dgza'
local cmdChar = '/dex'
local cmdSelf = '/say'
local tmpDesc = ''
local autoAdd = false
local DEBUG, newTarget = false, false
local tmpTarget = 'None'
local eZone, eTar, eDes, eCmd, newCmd, newDesc = '', '', '', '', '', ''
local CurrTarget = mq.TLO.Target.DisplayName() or 'None'
local dialogDataOld = mq.configDir .. '/npc_dialog.lua'
local dialogConfigOld = mq.configDir .. '/DialogDB_Config.lua'
local dialogData = mq.configDir .. '/MyUI/DialogDB/npc_dialog.lua'
local dialogConfig = mq.configDir .. '/MyUI/DialogDB/DialogDB_Config.lua'
local searchString = ''
local entries = {}
local showCmds = true
local showHelp = false
local inputText = ""
local currZoneShort = mq.TLO.Zone.ShortName() or 'None'
local msgPref = "\aw[\atDialogDB\aw] "

Module.Config = {
	cmdGroup = cmdGroup,
	cmdZone = cmdZone,
	cmdChar = cmdChar,
	cmdSelf = cmdSelf,
	autoAdd = false,
	themeName = Module.themeName,
}

local winFlags = bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.AlwaysAutoResize)
local delay = 1

local function fixEnding(var)
	var = var or "" -- ensure var is not nil

	-- Check if var ends with '/' or ' '
	if not var:match("[/ ]$") then
		var = var .. " "
	end

	return var
end

local function loadTheme()
	if Module.Utils.File.Exists(themeFile) then
		Module.theme = dofile(themeFile)
	else
		if Module.Utils.File.Exists(themeFileOld) then
			Module.theme = dofile(themeFileOld)
		else
			Module.theme = require('defaults.themes') -- your local themes file incase the user doesn't have one in config folder
		end
		mq.pickle(themeFile, Module.theme)
	end
	if Module.theme and Module.theme.Theme then
		for tID, tData in pairs(Module.theme.Theme) do
			if tData['Name'] == Module.themeName then
				themeID = tID
			end
		end
	end
end

local function DrawTheme(tName)
	local StyleCounter = 0
	local ColorCounter = 0
	for tID, tData in pairs(Module.theme.Theme) do
		if tData.Name == tName then
			for pID, cData in pairs(Module.theme.Theme[tID].Color) do
				ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
				ColorCounter = ColorCounter + 1
			end
			if tData['Style'] ~= nil then
				if next(tData['Style']) ~= nil then
					for sID, sData in pairs(Module.theme.Theme[tID].Style) do
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

local function loadSettings()
	-- Check if the dialog data file exists
	if not Module.Utils.File.Exists(dialogData) then
		-- If the old dialog data file exists, move it to the new location
		if Module.Utils.File.Exists(dialogDataOld) then
			Dialog = dofile(dialogDataOld)
		end
		mq.pickle(dialogData, Dialog)
	else
		local tmpDialog = dofile(dialogData) or {}
		for server, sData in pairs(Dialog) do
			tmpDialog[server] = tmpDialog[server] or {}
			for target, tData in pairs(sData) do
				tmpDialog[server][target] = tmpDialog[server][target] or {}
				for zone, zData in pairs(tData) do
					tmpDialog[server][target][zone] = tmpDialog[server][target][zone] or {}
					for desc, cmd in pairs(zData) do
						-- Only add default entries if they do not exist in the saved data
						if not tmpDialog[server][target][zone][desc] then
							tmpDialog[server][target][zone][desc] = cmd
						end
					end
				end
			end
		end
		Dialog = tmpDialog
	end
	if not Module.Utils.File.Exists(dialogConfig) then
		if Module.Utils.File.Exists(dialogConfigOld) then
			Module.Config = dofile(dialogConfigOld)
		else
			Module.ConFig = { cmdGroup = cmdGroup, cmdZone = cmdZone, cmdChar = cmdChar, autoAdd = autoAdd, cmdSelf = cmdSelf, themeName = Module.themeName, }
		end
		Module.ConfUI = true
		tmpTarget = 'None'
		mq.pickle(dialogConfig, Module.Config)
	else
		Module.Config = dofile(dialogConfig)
		cmdGroup = Module.Config.cmdGroup
		cmdZone = Module.Config.cmdZone
		cmdChar = Module.Config.cmdChar
		cmdSelf = Module.Config.cmdSelf
		autoAdd = Module.Config.autoAdd
		Module.themeName = Module.Config.themeName or 'Default'
	end
	loadTheme()

	local needSave = false
	--- Ensure that the command is a '/'' command otherwise add '/say ' to the front of it
	for server, sData in pairs(Dialog) do
		for target, tData in pairs(sData) do
			for zone, zData in pairs(tData) do
				for desc, cmd in pairs(zData) do
					if not cmd:match("^/") then
						Dialog[server][target][zone][desc] = string.format("/say %s", cmd)
						needSave = true
					end
				end
			end
		end
	end
	if needSave then
		mq.pickle(dialogData, Dialog)
	end
end

local function printHelp()
	Module.Utils.PrintOutput('MyUI', nil, "\aw[\at%s\aw] \agNPC Dialog DB \aoCommands:", msgPref)
	Module.Utils.PrintOutput('MyUI', nil, "%s\agNPC Dialog DB \aoCurrent Zone:", msgPref)
	Module.Utils.PrintOutput('MyUI', nil, "%s\ay/dialogdb add \aw[\at\"description\"\aw] [\at\"command\"\aw] \aoAdds to Current Zone description and command", msgPref)
	Module.Utils.PrintOutput('MyUI', nil, "%s\ay/dialogdb add \aw[\at\"Value\"\aw] \aoAdds to Current Zone description and command = Value ", msgPref)
	Module.Utils.PrintOutput('MyUI', nil, "%s\agNPC Dialog DB \aoAll Zones:", msgPref)
	Module.Utils.PrintOutput('MyUI', nil, "%s\ay/dialogdb addall \aw[\at\"description\"\aw] [\at\"command\"\aw] \aoAdds to All Zones description and command", msgPref)
	Module.Utils.PrintOutput('MyUI', nil, "%s\ay/dialogdb addall \aw[\at\"Value\"\aw] \aoAdds to All Zones description and command = Value ", msgPref)
	Module.Utils.PrintOutput('MyUI', nil, "%s\agNPC Dialog DB \aoCommon:", msgPref)
	Module.Utils.PrintOutput('MyUI', nil, "%s\ay/dialogdb help \aoDisplay Help", msgPref)
	Module.Utils.PrintOutput('MyUI', nil, "%s\ay/dialogdb config \aoDisplay Config Window", msgPref)
	Module.Utils.PrintOutput('MyUI', nil, "%s\ay/dialogdb debug \aoToggles Debugging, Turns off Commands and Prints them out so you can verify them", msgPref)
end

local function eventNPC(line, who)
	if not autoAdd then return end
	local nName = mq.TLO.Target.DisplayName() or 'None'
	local tmpCheck = mq.TLO.Target.DisplayName() or 'None'
	if who:find("^" .. tmpCheck) or line:find("^" .. tmpCheck) then
		nName = tmpCheck
	else
		return
	end
	-- Module.Utils.Module.Utils.PrintOutput('MyUI',nil,tmpCheck)
	-- Module.Utils.Module.Utils.PrintOutput('MyUI',nil,who)
	local found = false
	-- Module.Utils.Module.Utils.PrintOutput('MyUI',nil,nName)
	local check = string.format("npc =%s", nName)
	if mq.TLO.SpawnCount(check)() <= 0 then return end
	-- Module.Utils.Module.Utils.PrintOutput('MyUI',nil,"%s",mq.TLO.SpawnCount(check)())
	if not line:find("^" .. nName) then return end
	line = line:gsub(nName, "")
	for w in string.gmatch(line, "%[(.-)%]") do
		if w ~= nil then
			if Dialog[Module.Server][nName] == nil then Dialog[Module.Server][nName] = {} end
			if Dialog[Module.Server][nName][currZoneShort] == nil then Dialog[Module.Server][nName][currZoneShort] = {} end
			if Dialog[Module.Server][nName]['allzones'] == nil then Dialog[Module.Server][nName]['allzones'] = {} end
			if Dialog[Module.Server][nName][currZoneShort][w] == nil then
				Dialog[Module.Server][nName][currZoneShort][w] = w
				found = true
			end
		end
	end
	if found then
		if Module.ConfUI then newTarget = false end
		mq.pickle(dialogData, Dialog)
		loadSettings()
	end
end

local function setEvents()
	if autoAdd then
		-- mq.event("npc_say1", '#1# say#*#[#*#]#*#', eventNPC)
		-- mq.event("npc_whisper2", '#1# whisper#*#[#*#]#*#', eventNPC)
		mq.event("npc_emotes3", '#1# #*#[#*#]#*#', eventNPC)
	else
		-- mq.unevent("npc_say1")
		-- mq.unevent("npc_whisper2")
		mq.unevent("npc_emotes3")
	end
end

function Module.Unload()
	mq.unevent("npc_emotes3")
	mq.unbind("/dialogdb")
end

local function checkDialog()
	hasDialog = false
	if mq.TLO.Target() ~= nil then
		CurrTarget = mq.TLO.Target.DisplayName()
		-- Module.Utils.Module.Utils.PrintOutput('MyUI',nil,"Server: %s  Zone: %s Target: %s",serverName,curZone,target)
		if Dialog[Module.Server] == nil then
			return hasDialog
		elseif Dialog[Module.Server][CurrTarget] == nil then
			return hasDialog
		elseif Dialog[Module.Server][CurrTarget][currZoneShort] == nil and Dialog[Module.Server][CurrTarget]['allzones'] == nil then
			return hasDialog
		elseif Dialog[Module.Server][CurrTarget][currZoneShort] ~= nil or Dialog[Module.Server][CurrTarget]['allzones'] ~= nil then
			hasDialog = true
			return hasDialog
		end
	end
	return hasDialog
end

local function sortedKeys(tableToSort)
	local keys = {}
	for key in pairs(tableToSort) do
		table.insert(keys, key)
	end
	table.sort(keys) -- Sorts alphabetically by default
	return keys
end

local function bind(...)
	local args = { ..., }
	local key = args[1]
	local valueChanged = false
	if #args == 1 then
		if args[1] == 'config' then
			Module.ConfUI = not Module.ConfUI
			return
		elseif args[1] == 'debug' then
			DEBUG = not DEBUG
			if DEBUG then
				Module.Utils.PrintOutput('MyUI', nil, "%s \ayDEBUGGING \agEnabled \ayALL COMMANDS WILL BE PRINTED TO CONSOLE", msgPref)
			else
				Module.Utils.PrintOutput('MyUI', nil, "%s \ayDEBUGGING \arDisabled \ayALL COMMANDS WILL BE EXECUTED", msgPref)
			end
			return
		elseif args[1] == 'help' then
			showHelp = not showHelp
			printHelp()
			return
		elseif args[1] == 'quit' or args[1] == 'exit' then
			Module.IsRunning = false
			return
		else
			showHelp = true
			printHelp()
			Module.Utils.PrintOutput('MyUI', nil, "No String Supplied try again~")
			return
		end
	end
	local name = mq.TLO.Target.DisplayName() or 'None'
	if key ~= nil then
		local value = args[2]
		if key == 'add' and #args >= 2 then
			local name = mq.TLO.Target.DisplayName() or 'None'
			if name ~= 'None' then
				if Dialog[Module.Server] == nil then
					Dialog[Module.Server] = {}
				end
				if Dialog[Module.Server][name] == nil then
					Dialog[Module.Server][name] = {}
				end
				if Dialog[Module.Server][name][currZoneShort] == nil then
					Dialog[Module.Server][name][currZoneShort] = {}
				end
				if #args == 2 then
					if Dialog[Module.Server][name][currZoneShort][value] == nil then
						local cmdValue = value
						if not cmdValue:match("^/") then cmdValue = string.format("/say %s", cmdValue) end
						Dialog[Module.Server][name][currZoneShort][value] = cmdValue
						-- Module.Utils.Module.Utils.PrintOutput('MyUI',nil,"Server: %s  Zone: %s Target: %s Dialog: %s",serverName,curZone,name, value)
					end
				elseif #args == 3 then
					if Dialog[Module.Server][name][currZoneShort][args[2]] == nil then
						if not args[3]:match("^/") then args[3] = string.format("/say %s", args[3]) end
						Dialog[Module.Server][name][currZoneShort][args[2]] = args[3]
					end
				end
				valueChanged = true
			end
		elseif key == "addall" and #args >= 2 then
			if name ~= 'None' then
				if Dialog[Module.Server] == nil then
					Dialog[Module.Server] = {}
				end
				if Dialog[Module.Server][name] == nil then
					Dialog[Module.Server][name] = {}
				end
				if Dialog[Module.Server][name]['allzones'] == nil then
					Dialog[Module.Server][name]['allzones'] = {}
				end
				if #args == 2 then
					if Dialog[Module.Server][name]['allzones'][value] == nil then
						local cmdValue = value
						if not cmdValue:match("^/") then cmdValue = string.format("/say %s", cmdValue) end
						Dialog[Module.Server][name]['allzones'][value] = cmdValue
					end
				elseif #args == 3 then
					if Dialog[Module.Server][name]['allzones'][args[2]] == nil then
						if not args[3]:match("^/") then args[3] = string.format("/say %s", args[3]) end
						Dialog[Module.Server][name]['allzones'][args[2]] = args[3]
					end
				end
				valueChanged = true
			end
		end
		if valueChanged then
			mq.pickle(dialogData, Dialog)
		end
	end
end

-- Function to merge dialogues and handle Dialog display
local function handleCombinedDialog()
	local allZonesTable = Dialog[Module.Server][CurrTarget]['allzones'] or {}
	local curZoneTable = Dialog[Module.Server][CurrTarget][currZoneShort] or {}
	local combinedTable = {}

	-- First, fill combinedTable with all zones data
	for k, v in pairs(allZonesTable) do
		combinedTable[k] = v
	end
	-- Then, override or add with current zone data
	for k, v in pairs(curZoneTable) do
		combinedTable[k] = v
	end

	return combinedTable
end

local function DrawEditWin(server, target, zone, desc, cmd)
	local ColorCountEdit, StyleCountEdit = DrawTheme(Module.themeName)
	local openE, showE = ImGui.Begin("Edit Dialog##Dialog_Edit_" .. Module.CharLoaded, true, ImGuiWindowFlags.NoCollapse)
	if not openE then
		Module.editGUI = false
		entries = {}
	end
	if not showE then
		LoadTheme.EndTheme(ColorCountEdit, StyleCountEdit)
		ImGui.End()
		return
	end

	if #entries == 0 then
		table.insert(entries, { desc = desc, cmd = cmd, })
	end

	ImGui.Text("Edit Dialog")
	ImGui.Separator()
	ImGui.Text(string.format("Target: %s", target))
	ImGui.Text(string.format("Zone: %s", zone))
	ImGui.SameLine()

	local aZones = (zone == 'allzones')
	aZones, _ = ImGui.Checkbox("All Zones##EditDialogAllZones", aZones)
	eZone = aZones and 'allzones' or currZoneShort
	if zone ~= eZone then
		zone = eZone
	end
	if ImGui.Button("Save All##SaveAllButton") then
		for _, entry in ipairs(entries) do
			if entry.desc ~= "" and entry.desc ~= "NEW" then
				if not entry.cmd:match("^/") then entry.cmd = string.format("/say %s", entry.cmd) end
				Dialog[server][target] = Dialog[server][target] or {}
				Dialog[server][target][eZone] = Dialog[server][target][eZone] or {}
				Dialog[server][target][eZone][entry.desc] = entry.cmd
			end
		end
		mq.pickle(dialogData, Dialog)
		newTarget = false
		Module.editGUI = false
	end
	ImGui.SameLine()
	if ImGui.Button("Add Row##AddRowButton") then
		table.insert(entries, { desc = "NEW", cmd = "NEW", })
	end
	ImGui.SameLine()
	if ImGui.Button("Clear##ClearRowsButton") then
		entries = {}
		table.insert(entries, { desc = "NEW", cmd = "NEW", })
	end
	ImGui.Separator()
	ImGui.Text("Description:")
	ImGui.SameLine(160)
	ImGui.Text("Command:")
	ImGui.BeginChild("##EditDialogChild", 0.0, 0.0, ImGuiChildFlags.Border)
	for i, entry in ipairs(entries) do
		ImGui.SetNextItemWidth(150)
		entry.desc, _ = ImGui.InputText("##EditDialogDesc" .. i, entry.desc)
		ImGui.SameLine()
		ImGui.SetNextItemWidth(150)
		entry.cmd, _ = ImGui.InputText("##EditDialogCmd" .. i, entry.cmd)
		ImGui.SameLine()
		if ImGui.Button("Remove##" .. i) then
			table.remove(entries, i)
		end

		ImGui.Separator()
	end
	ImGui.EndChild()

	LoadTheme.EndTheme(ColorCountEdit, StyleCountEdit)
	ImGui.End()
end

local function DrawConfigWin()
	if tmpTarget == 'None' then
		tmpTarget = CurrTarget
	end
	ImGui.SetNextWindowSize(580, 350, ImGuiCond.Appearing)
	local ColorCountConf, StyleCountConf = DrawTheme(Module.themeName)
	local openC, showC = ImGui.Begin("NPC Dialog Config##Dialog_Config_" .. Module.CharLoaded, true, ImGuiWindowFlags.NoCollapse)
	if not openC then
		if newTarget then
			Dialog[Module.Server][tmpTarget] = nil
			newTarget = false
		end
		Module.ConfUI = false
		tmpTarget = 'None'
	end
	if not showC then
		LoadTheme.EndTheme(ColorCountConf, StyleCountConf)
		ImGui.End()
		return
	end
	local tmpGpCmd = cmdGroup:gsub(" $", "") or ''
	local tmpZnCmd = cmdZone:gsub(" $", "") or ''
	local tmpChCmd = cmdChar:gsub(" $", "") or ''
	local tmpSlCmd = cmdSelf:gsub(" $", "") or ''

	ImGui.SeparatorText("Command's Config")

	ImGui.BeginTable("Command Config##DialogConfigTable", 2, ImGuiTableFlags.Borders)
	ImGui.TableSetupColumn("##DialogConfigCol1", ImGuiTableColumnFlags.WidthFixed, 380)
	ImGui.TableSetupColumn("##DialogConfigCol2", ImGuiTableColumnFlags.WidthStretch)
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	tmpGpCmd, _ = ImGui.InputText("Group Command##DialogConfig", tmpGpCmd)
	if tmpGpCmd ~= cmdGroup then
		cmdGroup = tmpGpCmd:gsub(" $", "")
	end
	ImGui.TableNextColumn()
	if ImGui.Button("Set Group Command##DialogConfig") then
		Module.Config.cmdGroup = tmpGpCmd:gsub(" $", "")
		mq.pickle(dialogConfig, Module.Config)
	end
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	tmpZnCmd, _ = ImGui.InputText("Zone Command##DialogConfig", tmpZnCmd)
	if tmpZnCmd ~= cmdZone then
		cmdZone = tmpZnCmd:gsub(" $", "")
	end
	ImGui.TableNextColumn()
	if ImGui.Button("Set Zone Command##DialogConfig") then
		Module.Config.cmdZone = tmpZnCmd:gsub(" $", "")
		mq.pickle(dialogConfig, Module.Config)
	end
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	tmpChCmd, _ = ImGui.InputText("Character Command##DialogConfig", tmpChCmd)
	if tmpChCmd ~= cmdChar then
		cmdChar = tmpChCmd:gsub(" $", "")
	end
	ImGui.TableNextColumn()
	if ImGui.Button("Set Character Command##DialogConfig") then
		Module.Config.cmdChar = tmpChCmd:gsub(" $", "")
		mq.pickle(dialogConfig, Module.Config)
	end
	ImGui.EndTable()
	if ImGui.Button("Select Theme##DialogConfig") then
		Module.themeGUI = not Module.themeGUI
	end
	ImGui.Separator()
	--- Dialog Config Table
	if tmpTarget ~= nil and tmpTarget ~= 'None' then
		local sizeX, sizeY = ImGui.GetContentRegionAvail()
		ImGui.SeparatorText(tmpTarget .. "'s Dialogs")
		-- ImGui.BeginChild("DialogConfigChild", sizeX, sizeY -30, bit32.bor(ImGuiChildFlags.Border))
		ImGui.BeginTable("NPC Dialogs##DialogConfigTable2", 5, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.ScrollY), ImVec2(sizeX, sizeY - 80))
		ImGui.TableSetupScrollFreeze(0, 1)
		ImGui.TableSetupColumn("NPC##DialogDB_Config", ImGuiTableColumnFlags.WidthFixed, 100)
		ImGui.TableSetupColumn("Zone##DialogDB_Config", ImGuiTableColumnFlags.WidthFixed, 100)
		ImGui.TableSetupColumn("Description##DialogDB_Config", ImGuiTableColumnFlags.WidthStretch, 100)
		ImGui.TableSetupColumn("Trigger##DialogDB_Config", ImGuiTableColumnFlags.WidthStretch, 100)
		ImGui.TableSetupColumn("##DialogDB_Config_Save", ImGuiTableColumnFlags.WidthFixed, 120)
		ImGui.TableHeadersRow()
		local id = 1
		if Dialog[Module.Server][tmpTarget] == nil then
			Dialog[Module.Server][tmpTarget] = { allzones = {}, [currZoneShort] = {}, }
			newTarget = true
		else
			-- Use sortedKeys to sort zones and then descriptions within zones
			local sortedZones = sortedKeys(Dialog[Module.Server][tmpTarget])
			for _, z in ipairs(sortedZones) do
				local sortedDescriptions = sortedKeys(Dialog[Module.Server][tmpTarget][z])
				for _, d in ipairs(sortedDescriptions) do
					local c = Dialog[Module.Server][tmpTarget][z][d]
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
					ImGui.Text(tmpTarget)
					ImGui.TableNextColumn()
					ImGui.Text(z)
					ImGui.TableNextColumn()
					ImGui.Text(d)
					ImGui.TableNextColumn()
					ImGui.Text(c)
					ImGui.TableNextColumn()
					if ImGui.Button("Edit##DialogDB_Config_Edit_" .. id) then
						eZone = z
						eTar = tmpTarget
						eDes = d
						eCmd = c
						newCmd = c
						newDesc = d
						Module.editGUI = true
					end
					ImGui.SameLine()
					if ImGui.Button("Delete##DialogDB_Config_" .. id) then
						Dialog[Module.Server][tmpTarget][z][d] = nil
						mq.pickle(dialogData, Dialog)
					end
					id = id + 1
				end
			end
		end
		ImGui.EndTable()
		if ImGui.Button("Delete NPC##DialogConfig") then
			Dialog[Module.Server][tmpTarget] = nil
			mq.pickle(dialogData, Dialog)
			Module.ConfUI = false
		end
		-- ImGui.EndChild()
	end
	local tmpTxtAuto = autoAdd and "Disable Auto Add" or "Enable Auto Add"
	if ImGui.Button(tmpTxtAuto .. "##DialogConfigAutoAdd") then
		autoAdd = not autoAdd
		Module.Config.autoAdd = autoAdd
		mq.pickle(dialogConfig, Module.Config)
		setEvents()
	end
	ImGui.SameLine()
	if ImGui.Button("Add Dialog##DialogConfig") then
		if Dialog[Module.Server][tmpTarget] == nil then
			Dialog[Module.Server][tmpTarget] = { allzones = {}, [currZoneShort] = {}, }
		end
		eZone = currZoneShort
		eTar = tmpTarget
		eDes = "NEW"
		eCmd = "NEW"
		newCmd = "NEW"
		newDesc = "NEW"
		Module.editGUI = true
	end
	ImGui.SameLine()
	if ImGui.Button("Refresh Target##DialogConf_Refresh") then
		tmpTarget = mq.TLO.Target.DisplayName()
	end
	ImGui.SameLine()
	if ImGui.Button("Cancel##DialogConf_Cancel") then
		if newTarget then
			Dialog[Module.Server][tmpTarget] = nil
			newTarget = false
		end
		Module.ConfUI = false
	end
	ImGui.SameLine()
	if ImGui.Button("Close##DialogConf_Close") then
		Module.ConfUI = false
	end
	LoadTheme.EndTheme(ColorCountConf, StyleCountConf)
	ImGui.End()
end

local function DrawThemeWin()
	local ColorCountTheme, StyleCountTheme = DrawTheme(Module.themeName)
	local openTheme, showTheme = ImGui.Begin('Theme Selector##DialogDB_' .. Module.CharLoaded, true, bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.AlwaysAutoResize))
	if not openTheme then
		Module.themeGUI = false
	end
	if not showTheme then
		LoadTheme.EndTheme(ColorCountTheme, StyleCountTheme)
		ImGui.End()
		return
	end
	ImGui.SeparatorText("Theme##DialogDB")

	ImGui.Text("Cur Theme: %s", Module.themeName)
	-- Combo Box Load Theme
	if ImGui.BeginCombo("Load Theme##DialogDB", Module.themeName) then
		for k, data in pairs(Module.theme.Theme) do
			local isSelected = data.Name == Module.themeName
			if ImGui.Selectable(data.Name, isSelected) then
				Module.Config.themeName = data.Name
				themeID = k
				if Module.themeName ~= Module.Config.themeName then
					mq.pickle(dialogConfig, Module.Config)
				end
				Module.themeName = Module.Config.themeName
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

	LoadTheme.EndTheme(ColorCountTheme, StyleCountTheme)
	ImGui.End()
end

local function DrawHelpWin()
	ImGui.SetNextWindowSize(600, 350, ImGuiCond.Appearing)
	local openHelpWin, showHelpWin = ImGui.Begin("Help##DialogDB_" .. Module.CharLoaded, true, bit32.bor(ImGuiWindowFlags.NoCollapse))
	if not openHelpWin then
		showHelp = false
	end
	if not showHelpWin then
		ImGui.End()
		return
	end
	ImGui.SeparatorText("NPC Dialog DB Help")
	ImGui.Text("Commands:")
	local sizeX, sizeY = ImGui.GetContentRegionAvail()
	ImGui.BeginTable("HelpTable", 2, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.ScrollY, ImGuiTableFlags.RowBg, ImGuiTableFlags.Resizable), ImVec2(sizeX, sizeY - 20))
	ImGui.TableSetupColumn("Command", ImGuiTableColumnFlags.WidthAlwaysAutoResize)
	ImGui.TableSetupColumn("Description", ImGuiTableColumnFlags.WidthStretch, 230)
	ImGui.TableHeadersRow()
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.Text("/dialogdb add [\"description\"] [\"command\"]")
	ImGui.TableNextColumn()
	ImGui.TextWrapped("Adds to Current Zone description and command")
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.Text("/dialogdb add [\"Value\"]")
	ImGui.TableNextColumn()
	ImGui.TextWrapped("Adds to Current Zone description and command = Value")
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.Text("/dialogdb addall [\"description\"] [\"command\"]")
	ImGui.TableNextColumn()
	ImGui.TextWrapped("Adds to All Zones description and command")
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.Text("/dialogdb addall [\"Value\"]")
	ImGui.TableNextColumn()
	ImGui.TextWrapped("Adds to All Zones description and command = Value")
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.Text("/dialogdb help")
	ImGui.TableNextColumn()
	ImGui.Text("Display Help")
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.Text("/dialogdb config")
	ImGui.TableNextColumn()
	ImGui.Text("Display Config Window")
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.Text("/dialogdb debug")
	ImGui.TableNextColumn()
	ImGui.TextWrapped("Toggles Debugging, Turns off Commands and Prints them out so you can verify them")
	ImGui.EndTable()
	ImGui.End()
end

local function DrawMainWin()
	local ColorCount, StyleCount = DrawTheme(Module.themeName)
	local openMain, showMain = ImGui.Begin("NPC Dialog##DialogDB_Main_" .. Module.CharLoaded, true, winFlags)
	if not openMain then
		Module.ShowDialog = false
	end
	if not showMain then
		LoadTheme.EndTheme(ColorCount, StyleCount)
		ImGui.End()
		return
	end
	if checkDialog() then
		ImGui.PushID('theme')
		ImGui.Text(gIcon)
		ImGui.PopID()
		if ImGui.IsItemHovered() then
			if ImGui.IsMouseReleased(0) then
				Module.ConfUI = not Module.ConfUI
				tmpTarget = CurrTarget
			end
			if ImGui.IsMouseReleased(1) then
				Module.themeGUI = not Module.themeGUI
			end
		end
		ImGui.SameLine()
		ImGui.Text("%s's Dialog", CurrTarget)
		local dialogCombined = handleCombinedDialog()
		if next(dialogCombined) ~= nil then
			local sortedKeyList = sortedKeys(dialogCombined)
			if dialogCombined[tmpDesc] == nil then
				tmpDesc = 'None'
			end
			ImGui.SetNextItemWidth(200)
			searchString = ImGui.InputText("Filter##DialogDB", searchString or "")
			ImGui.SetNextItemWidth(200)
			if ImGui.BeginCombo("##DialogDBCombined", tmpDesc) then
				for _, desc in pairs(sortedKeyList) do
					if (searchString ~= "" and string.find(desc:lower(), searchString:lower())) or (searchString == "") then
						local isSelected = (desc == tmpDesc)
						if ImGui.Selectable(desc, isSelected) then
							tmpDesc = desc
							_G["cmdString"] = dialogCombined[desc] -- Global to maintain state outside of this function
						end
						if isSelected then
							ImGui.SetItemDefaultFocus()
						end
					end
				end
				ImGui.EndCombo()
			end
			ImGui.SameLine()
			local eyeCon = showCmds and Module.Icons.FA_CARET_UP or Module.Icons.FA_CARET_DOWN

			if ImGui.Button(eyeCon) then showCmds = not showCmds end
			if showCmds then
				if _G["cmdString"] and _G["cmdString"] ~= '' then
					ImGui.Separator()
					if ImGui.Button('Say ##DialogDBCombined') then
						if not DEBUG then
							mq.cmdf("%s", _G["cmdString"])
						else
							Module.Utils.PrintOutput('MyUI', nil, "%s", _G["cmdString"])
						end
						searchString = ""
					end
					if mq.TLO.Me.GroupSize() > 1 then
						ImGui.SameLine()
						if ImGui.Button('Group Say ##DialogDBCombined') then
							if cmdGroup:find("^/d") then
								cmdGroup = cmdGroup .. " "
							end
							if not DEBUG then
								mq.cmdf("/multiline ; %s/target %s; /timed 5, %s%s", cmdGroup, CurrTarget, cmdGroup, _G["cmdString"])
							else
								Module.Utils.PrintOutput('MyUI', nil, "/multiline ; %s/target %s; /timed 5, %s%s", cmdGroup, CurrTarget, cmdGroup, _G["cmdString"])
							end
							searchString = ""
						end
						ImGui.SameLine()
						local tmpDelay = delay
						ImGui.SetNextItemWidth(75)
						tmpDelay = ImGui.InputInt("Delay##DialogDBCombined", tmpDelay, 1, 1)
						if tmpDelay < 0 then tmpDelay = 0 end
						if tmpDelay ~= delay then
							delay = tmpDelay
						end
						if ImGui.Button('Group Say Delayed ##DialogDBCombined') then
							local cDelay = delay * 10
							for i = 1, mq.TLO.Me.GroupSize() - 1 do
								if i == 1 then cDelay = 10 end
								if mq.TLO.Group.Member(i).Present() then
									if mq.TLO.Group.Member(i).Distance() < 100 then
										local pName = mq.TLO.Group.Member(i).DisplayName()
										if cmdChar:find("/bct") then
											pName = pName .. " /"
										else
											pName = pName .. " "
										end
										if not DEBUG then
											mq.cmdf("/multiline ; %s %s/target %s; %s %s/timed %s, %s", cmdChar, pName, CurrTarget, cmdChar, pName, cDelay, _G["cmdString"])
										else
											Module.Utils.PrintOutput('MyUI', nil, "/multiline ; %s %s/target %s; %s %s/timed %s, %s", cmdChar, pName, CurrTarget, cmdChar, pName,
												cDelay,
												_G["cmdString"])
										end
										cDelay = cDelay + (delay * 10)
									end
								end
							end
							if not DEBUG then
								mq.cmdf("/timed %s, %s", cDelay, _G["cmdString"])
							else
								Module.Utils.PrintOutput('MyUI', nil, "/timed %s, %s", cDelay, _G["cmdString"])
							end
							searchString = ""
						end
						ImGui.SameLine()
						if ImGui.Button('Zone Members ##DialogDBCombined') then
							if cmdZone:find("^/d") then
								cmdZone = cmdZone .. " "
							end
							if not DEBUG then
								mq.cmdf("/multiline ; %s/target %s; /timed 5, %s%s", cmdZone, CurrTarget, cmdZone, _G["cmdString"])
							else
								Module.Utils.PrintOutput('MyUI', nil, "/multiline ; %s/target %s; /timed 5, %s%s", cmdZone, CurrTarget, cmdZone, _G["cmdString"])
							end
							searchString = ""
						end
					end
				end
			end
		end
	end
	LoadTheme.EndTheme(ColorCount, StyleCount)
	ImGui.End()
end

function Module.RenderGUI()
	if currZoneShort ~= lastZone then return end
	--- Dialog Main Window
	if Module.ShowDialog then
		DrawMainWin()
	end

	--- Dialog Config Window
	if Module.ConfUI then
		DrawConfigWin()
	end

	--- Dialog Edit Window
	if Module.editGUI then
		DrawEditWin(Module.Server, eTar, eZone, eDes, eCmd)
	end

	--- Theme Selector Window
	if Module.themeGUI then
		DrawThemeWin()
	end

	-- help window
	if showHelp then
		DrawHelpWin()
	end
end

local function init()
	if Module.Build ~= 'Emu' then Module.Server = 'Live' end -- really only care about server name for EMU as the dialogs may vary from serever to server to server
	loadSettings()
	Module.Utils.PrintOutput('MyUI', nil, "Dialog Data Loaded for %s", Module.Server)
	Running = true
	setEvents()
	mq.bind('/dialogdb', bind)
	currZoneShort = mq.TLO.Zone.ShortName() or 'None'
	lastZone = currZoneShort
	Module.Utils.PrintOutput('MyUI', nil, "%s\agDialog DB \aoLoaded... \at/dialogdb help \aoDisplay Help", msgPref)
	Module.IsRunning = true
	if not loadedExeternally then
		mq.imgui.init(Module.Nam, Module.RenderGUI)
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
	if elapsedTime >= 16 then
		currZoneShort = mq.TLO.Zone.ShortName() or 'None'
		if currZoneShort ~= lastZone then
			tmpDesc = ''
			CurrTarget = 'None'
			hasDialog = false
			Module.ShowDialog = false
			Module.ConfUI = false
			Module.editGUI = false
			lastZone = currZoneShort
			searchString = ""
		end
		if checkDialog() then
			Module.ShowDialog = true
		else
			Module.ShowDialog = false
			if CurrTarget ~= mq.TLO.Target.DisplayName() then tmpDesc = '' end
		end
	end
	mq.doevents()
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
