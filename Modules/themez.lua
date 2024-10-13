local mq = require('mq')
local ImGui = require 'ImGui'
local Module = {}
local loadedExeternally = MyUI_ScriptName ~= nil and true or false
Module.Name = "ThemeZ"   -- Name of the module used when loading and unloaing the modules.
Module.IsRunning = false -- Keep track of running state. if not running we can unload it.
Module.ShowGui = true

if not loadedExeternally then
	MyUI_Utils = require('lib.common')
	Module.ThemeLoader = require('lib.theme_loader')
else
	Module.ThemeLoader = MyUI_ThemeLoader
end

local defaults = require('defaults.themes')
local theme = {}
local settingsFile = string.format('%s/MyUI/MyThemeZ.lua', mq.configDir)
local themeName = 'Default'
local tmpName = 'Default'
-- local StyleCount = 0
-- local ColorCount = 0
local themeID = 0

local tFlags = bit32.bor(ImGuiTableFlags.NoBordersInBody)
local tempSettings = {
	['LoadTheme'] = 'Default',
	Theme = {
		[1] = {
			['Name'] = "Default",
			['Color'] = {
				Color = {},
				PropertyName = '',
			},
			['Style'] = {},
		},
	},
}

--Helper Functioons

function File_Exists(name)
	local f = io.open(name, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

local function writeSettings(file, settings)
	mq.pickle(file, settings)

	if file ~= string.format('%s/MyUI/MyThemeZ.lua', mq.configDir) then
		writeSettings(string.format('%s/MyUI/MyThemeZ.lua', mq.configDir), settings)
	end
end

local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

local function loadSettings()
	if not File_Exists(settingsFile) then
		mq.pickle(settingsFile, defaults)
		loadSettings()
	else
		-- Load settings from the Lua config file
		theme = dofile(settingsFile)
	end
	themeName = theme.LoadTheme or themeName
	tmpName = themeName
	writeSettings(settingsFile, theme)
	-- Deep copy theme into tempSettings
	-- tempSettings = deepcopy(theme)
	tempSettings = theme
	local styleFlag = false
	for tID, tData in pairs(tempSettings.Theme) do
		if tData['Style'] == nil or next(tData['Style']) == nil then
			tempSettings.Theme[tID].Style = {}
			tempSettings.Theme[tID].Style = defaults['Theme'][1]['Style']
			styleFlag = true
		end
		if tData['Color'] == nil or next(tData['Color']) == nil then
			tempSettings.Theme[tID].Color = {}
			tempSettings.Theme[tID].Color = defaults['Theme'][1]['Color']
			styleFlag = true
		end
		if tData.Name == themeName then
			themeID = tID
		end
	end

	if styleFlag then writeSettings(settingsFile, tempSettings) end
end

local function getNextID(table)
	local maxID = 0
	for k, _ in pairs(table) do
		local numericId = tonumber(k)
		if numericId and numericId > maxID then
			maxID = numericId
		end
	end
	return maxID + 1
end

local function exportRGMercs(table)
	if table == nil then return end
	local rgThemeFile = mq.configDir .. '/rgmercs/rgmercs_theme.lua'
	local f = io.open(rgThemeFile, "w")
	if f == nil then
		error("Error opening file for writing: " .. rgThemeFile)
		return
	end
	local line = 'return {'
	f:write(line .. "\n")
	for tID, tData in pairs(theme.Theme) do
		themeID = tID
		line = "\t['" .. tData.Name .. "'] = {"
		f:write(line .. "\n")
		for pID, cData in pairs(theme.Theme[tID].Color) do
			line = string.format("\t\t{ element = ImGuiCol.%s, color = {r = %.2f, g = %.2f,b = %.2f,a = %.2f}, },", cData.PropertyName, cData.Color[1], cData.Color[2],
				cData.Color[3], cData.Color[4])
			f:write(line .. "\n")
		end
		line = "\t},"
		f:write(line .. "\n")
	end
	f:write("}")
	f:close()
end

local function exportButtonMaster(table)
	local BM = {}
	local bmThemeFile = mq.configDir .. '/button_master_theme.lua'
	if theme and theme.Theme then
		for tID, tData in pairs(theme.Theme) do
			if not BM[tData.Name] then BM[tData.Name] = {} end
			themeID = tID
			for pID, cData in pairs(theme.Theme[tID].Color) do
				if not BM[tData.Name][cData.PropertyName] then BM[tData.Name][cData.PropertyName] = {} end
				BM[tData.Name][cData.PropertyName] = { cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4], }
			end
			for sID, sData in pairs(theme.Theme[tID].Style) do
				if not BM[tData.Name][sData.PropertyName] then BM[tData.Name][sData.PropertyName] = {} end
				if sData.Size ~= nil then
					BM[tData.Name][sData.PropertyName] = { sData.Size, }
				elseif sData.X ~= nil then
					BM[tData.Name][sData.PropertyName] = { sData.X, sData.Y, }
				end
			end
		end
	end
	mq.pickle(bmThemeFile, BM)
end

local function DrawStyles()
	local style = {}
	tempSettings.Theme[themeID] = theme.Theme[themeID]
	if tempSettings.Theme[themeID]['Style'] == nil then
		tempSettings.Theme[themeID]['Style'] = defaults['Theme'][2]['Style']
	end
	style = tempSettings.Theme[themeID]['Style']

	ImGui.SeparatorText('Borders')
	local tmpBorder = false
	local borderPressed = false
	if style[ImGuiStyleVar.WindowBorderSize].Size == 1 then
		tmpBorder = true
	end
	tmpBorder, borderPressed = ImGui.Checkbox('WindowBorder##', tmpBorder)
	if borderPressed then
		if tmpBorder then
			style[ImGuiStyleVar.WindowBorderSize].Size = 1
		else
			style[ImGuiStyleVar.WindowBorderSize].Size = 0
		end
	end
	ImGui.SameLine()
	local tmpFBorder = false
	local borderFPressed = false
	if style[ImGuiStyleVar.FrameBorderSize].Size == 1 then
		tmpFBorder = true
	end
	tmpFBorder, borderFPressed = ImGui.Checkbox('FrameBorder##', tmpFBorder)
	if borderFPressed then
		if tmpFBorder then
			style[ImGuiStyleVar.FrameBorderSize].Size = 1
		else
			style[ImGuiStyleVar.FrameBorderSize].Size = 0
		end
	end
	ImGui.SameLine()
	local tmpCBorder = false
	local borderCPressed = false
	if style[ImGuiStyleVar.ChildBorderSize].Size == 1 then
		tmpCBorder = true
	end
	tmpCBorder, borderCPressed = ImGui.Checkbox('ChildBorder##', tmpCBorder)
	if borderCPressed then
		if tmpCBorder then
			style[ImGuiStyleVar.ChildBorderSize].Size = 1
		else
			style[ImGuiStyleVar.ChildBorderSize].Size = 0
		end
	end

	local tmpPBorder = false
	local borderPPressed = false
	if style[ImGuiStyleVar.PopupBorderSize].Size == 1 then
		tmpPBorder = true
	end
	tmpPBorder, borderPPressed = ImGui.Checkbox('PopupBorder##', tmpPBorder)
	if borderPPressed then
		if tmpPBorder then
			style[ImGuiStyleVar.PopupBorderSize].Size = 1
		else
			style[ImGuiStyleVar.PopupBorderSize].Size = 0
		end
	end
	ImGui.SameLine()
	local tmpTBorder = false
	local borderTPressed = false
	if style[ImGuiStyleVar.TabBarBorderSize].Size == 1 then
		tmpTBorder = true
	end
	tmpTBorder, borderTPressed = ImGui.Checkbox('TabBorder##', tmpTBorder)
	if borderTPressed then
		if tmpTBorder then
			style[ImGuiStyleVar.TabBarBorderSize].Size = 1
		else
			style[ImGuiStyleVar.TabBarBorderSize].Size = 0
		end
	end

	ImGui.SeparatorText('Main Sizing')
	ImGui.BeginTable('##StylesMain', 3, tFlags)
	ImGui.TableSetupColumn('##min', ImGuiTableColumnFlags.None)
	ImGui.TableSetupColumn('##max', ImGuiTableColumnFlags.None)
	ImGui.TableSetupColumn('##name', ImGuiTableColumnFlags.None)
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.SetNextItemWidth(100)
	style[ImGuiStyleVar.WindowPadding].X = ImGui.InputInt('##WindowPadding_X', style[ImGuiStyleVar.WindowPadding].X, 1, 2)
	ImGui.TableNextColumn()
	ImGui.SetNextItemWidth(100)
	style[ImGuiStyleVar.WindowPadding].Y = ImGui.InputInt(' ##WindowPadding_Y', style[ImGuiStyleVar.WindowPadding].Y, 1, 2)
	ImGui.TableNextColumn()
	ImGui.Text(style[ImGuiStyleVar.WindowPadding].PropertyName)

	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.SetNextItemWidth(100)
	style[ImGuiStyleVar.CellPadding].X = ImGui.InputInt('##CellPadding_X', style[ImGuiStyleVar.CellPadding].X, 1, 2)
	ImGui.TableNextColumn()
	ImGui.SetNextItemWidth(100)
	style[ImGuiStyleVar.CellPadding].Y = ImGui.InputInt(' ##CellPadding_Y', style[ImGuiStyleVar.CellPadding].Y, 1, 2)
	ImGui.TableNextColumn()
	ImGui.Text(style[ImGuiStyleVar.CellPadding].PropertyName)

	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.SetNextItemWidth(100)
	style[ImGuiStyleVar.FramePadding].X = ImGui.InputInt('##FramePadding_X', style[ImGuiStyleVar.FramePadding].X, 1, 2)
	ImGui.TableNextColumn()
	ImGui.SetNextItemWidth(100)
	style[ImGuiStyleVar.FramePadding].Y = ImGui.InputInt(' ##FramePadding_Y', style[ImGuiStyleVar.FramePadding].Y, 1, 2)
	ImGui.TableNextColumn()
	ImGui.Text(style[ImGuiStyleVar.FramePadding].PropertyName)

	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.SetNextItemWidth(100)
	style[ImGuiStyleVar.ItemSpacing].X = ImGui.InputInt('##ItemSpacing_X', style[ImGuiStyleVar.ItemSpacing].X, 1, 2)
	ImGui.TableNextColumn()
	ImGui.SetNextItemWidth(100)
	style[ImGuiStyleVar.ItemSpacing].Y = ImGui.InputInt(' ##ItemSpacing_Y', style[ImGuiStyleVar.ItemSpacing].Y, 1, 2)
	ImGui.TableNextColumn()
	ImGui.Text(style[ImGuiStyleVar.ItemSpacing].PropertyName)

	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.SetNextItemWidth(100)
	style[ImGuiStyleVar.ItemInnerSpacing].X = ImGui.InputInt('##ItemInnerSpacing_X', style[ImGuiStyleVar.ItemInnerSpacing].X, 1, 2)
	ImGui.TableNextColumn()
	ImGui.SetNextItemWidth(100)
	style[ImGuiStyleVar.ItemInnerSpacing].Y = ImGui.InputInt(' ##ItemInnerSpacing_Y', style[ImGuiStyleVar.ItemInnerSpacing].Y, 1, 2)
	ImGui.TableNextColumn()
	ImGui.Text(style[ImGuiStyleVar.ItemInnerSpacing].PropertyName)

	ImGui.EndTable()

	style[ImGuiStyleVar.IndentSpacing].Size = ImGui.SliderInt('IndentSpacing##', style[ImGuiStyleVar.IndentSpacing].Size, 0, 30)
	style[ImGuiStyleVar.ScrollbarSize].Size = ImGui.SliderInt('ScrollbarSize##', style[ImGuiStyleVar.ScrollbarSize].Size, 0, 20)
	style[ImGuiStyleVar.GrabMinSize].Size = ImGui.SliderInt('GrabSize##', style[ImGuiStyleVar.GrabMinSize].Size, 0, 20)

	ImGui.SeparatorText('Rounding')
	style[ImGuiStyleVar.WindowRounding].Size = ImGui.SliderInt('Window##Rounding', style[ImGuiStyleVar.WindowRounding].Size, 0, 12)
	style[ImGuiStyleVar.FrameRounding].Size = ImGui.SliderInt('Frame##Rounding', style[ImGuiStyleVar.FrameRounding].Size, 0, 12)
	style[ImGuiStyleVar.ChildRounding].Size = ImGui.SliderInt('Child##Rounding', style[ImGuiStyleVar.ChildRounding].Size, 0, 12)
	style[ImGuiStyleVar.PopupRounding].Size = ImGui.SliderInt('Popup##Rounding', style[ImGuiStyleVar.PopupRounding].Size, 0, 12)
	style[ImGuiStyleVar.ScrollbarRounding].Size = ImGui.SliderInt('Scrollbar##Rounding', style[ImGuiStyleVar.ScrollbarRounding].Size, 0, 12)
	style[ImGuiStyleVar.GrabRounding].Size = ImGui.SliderInt('Grab##Rounding', style[ImGuiStyleVar.GrabRounding].Size, 0, 12)
	style[ImGuiStyleVar.TabRounding].Size = ImGui.SliderInt('Tab##Rounding', style[ImGuiStyleVar.TabRounding].Size, 0, 12)
end

-- GUI
local cFlag = false

function Module.RenderGUI()
	if not Module.IsRunning then return end
	if Module.ShowGui then
		ImGui.SetNextWindowSize(450, 300, ImGuiCond.FirstUseEver)
		ImGui.SetNextWindowSize(450, 300, ImGuiCond.Always)

		local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(themeName, theme)
		-- Begin GUI
		local open, show = ImGui.Begin("ThemeZ Builder##", true, bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoScrollbar))
		if not open then
			show = false
			Module.ShowGui = false
		end
		if show then
			-- create table entry for themeID if missing.
			if tempSettings.Theme[themeID] == nil then
				local i = themeID + 1
				tempSettings.Theme = {
					[i] = {
						['Name'] = '',
						['Color'] = {
							Color = {},
							PropertyName = '',
						},
						['Style'] = {},
					},
				}
			end
			local newName = tempSettings.Theme[themeID]['Name'] or 'New'
			-- Save Current Theme to Config
			local pressed = ImGui.Button("Save")
			if pressed then
				if tmpName == '' then tmpName = themeName end
				if tempSettings.Theme[themeID]['Name'] ~= tmpName then
					local nID = getNextID(tempSettings.Theme)
					tempSettings.Theme[nID] = {
						['Name'] = tmpName,
						['Color'] = tempSettings.Theme[themeID]['Color'],
					}
					themeID = nID
				end
				writeSettings(settingsFile, tempSettings)
				theme = deepcopy(tempSettings)
			end

			ImGui.SameLine()

			local pressed = ImGui.Button("Export BM Theme")
			if pressed then
				exportButtonMaster(tempSettings)
			end

			ImGui.SameLine()

			local pressed = ImGui.Button("Export RGMercs Theme")
			if pressed then
				exportRGMercs(tempSettings)
			end

			ImGui.SameLine()
			-- Make New Theme
			local newPressed = ImGui.Button("New")
			if newPressed then
				local nID = getNextID(tempSettings.Theme)
				tempSettings.Theme[nID] = {
					['Name'] = tmpName,
					['Color'] = theme.Theme[themeID]['Color'],
				}
				themeName = tmpName
				themeID = nID
				for k, data in pairs(tempSettings.Theme) do
					if data.Name == themeName then
						tempSettings['LoadTheme'] = data['Name']
						themeName = tempSettings['LoadTheme']
						tmpName = themeName
					end
				end
				writeSettings(settingsFile, tempSettings)
				-- theme = deepcopy(tempSettings)
				theme = tempSettings
			end

			ImGui.SameLine()
			-- Exit/Close
			local ePressed = ImGui.Button("Exit")
			if ePressed then
				Module.IsRunning = false
			end
			-- Edit Name
			ImGui.Text("Cur Theme: %s", themeName)
			tmpName = ImGui.InputText("Theme Name", tmpName)
			-- Combo Box Load Theme
			if ImGui.BeginCombo("Load Theme", themeName) then
				for k, data in pairs(tempSettings.Theme) do
					local isSelected = (data['Name'] == themeName)
					if ImGui.Selectable(data['Name'], isSelected) then
						tempSettings['LoadTheme'] = data['Name']
						themeName = tempSettings['LoadTheme']
						tmpName = themeName
					end
				end
				ImGui.EndCombo()
			end
			ImGui.Separator()

			local cWidth, xHeight = ImGui.GetContentRegionAvail()
			ImGui.BeginChild("ThemeZ##", cWidth - 5, xHeight - 15)
			local collapsed, _ = ImGui.CollapsingHeader("Colors##")

			if collapsed then
				if ImGui.Button('Defaults##Color') then
					tempSettings.Theme[themeID]['Color'] = defaults.Theme[1].Color
				end
				cWidth, xHeight = ImGui.GetContentRegionAvail()
				if cFlag then
					ImGui.BeginChild('Colors', cWidth, xHeight * 0.5, ImGuiChildFlags.Border)
				else
					ImGui.BeginChild('Colors', cWidth, xHeight, ImGuiChildFlags.Border)
				end
				for pID, pData in pairs(tempSettings.Theme[themeID]['Color']) do
					if pID ~= nil then
						local propertyName = pData.PropertyName
						if propertyName ~= nil then
							pData.Color = ImGui.ColorEdit4(pData.PropertyName .. "##", pData.Color)
						end
					end
				end
				ImGui.EndChild()
			end
			cWidth, xHeight = ImGui.GetContentRegionAvail()
			local collapsed2, _ = ImGui.CollapsingHeader("Styles##")
			if collapsed2 then
				cFlag = true
				if not collapsed then
					ImGui.BeginChild('Styles', cWidth, xHeight, ImGuiChildFlags.Border)
				else
					ImGui.BeginChild('Styles', cWidth, xHeight * 0.5, ImGuiChildFlags.Border)
				end
				if ImGui.Button('Defaults##Style') then
					tempSettings.Theme[themeID]['Style'] = defaults.Theme[1].Style
				end
				DrawStyles()
				ImGui.EndChild()
			else
				cFlag = false
			end

			ImGui.EndChild()
		end
		-- ImGui.PopStyleVar(StyleCount)
		-- ImGui.PopStyleColor(ColorCount)
		Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
		ImGui.End()
	end
end

local function commandHandler(...)
	local args = { ..., }
	if #args > 0 then
		if args[1] == 'exit' or args[1] == 'quit' then
			Module.IsRunning = false
			MyUI_Utils.PrintOutput('MyUI', true, "\ay%s \awis \arExiting\aw...", Module.Name)
		elseif args[1] == 'show' or args[1] == 'ui' then
			Module.ShowGui = not Module.ShowGui
		end
	end
end
--
local function startup()
	Module.ShowGui = true
	Module.IsRunning = true
	loadSettings()
	mq.bind("/themez", commandHandler)
	if not loadedExeternally then
		mq.imgui.init("ThemeZ Builder##", Module.RenderGUI)
		Module.LocalLoop()
	end
	MyUI_Utils.PrintOutput('MyUI', false, "\ayModule \a-w[\at%s\a-w] \agLoaded\aw!", Module.Name)
	MyUI_Utils.PrintOutput('MyUI', false, "\ayTheme \a-w[\at%s\a-w] \agLoaded\aw!", themeName)
	MyUI_Utils.PrintOutput('MyUI', false, "\ay/themez \a-w[\atshow\a-w] \aoToggles the GUI\aw!")
	MyUI_Utils.PrintOutput('MyUI', false, "\ay/themez \a-w[\atexit\a-w] \aoExits the Module\aw!")
end
--
function Module.MainLoop()
	if loadedExeternally then
		if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
	end
end

function Module.Unload()
	mq.unbind('/themez')
end

function Module.LocalLoop()
	while Module.IsRunning do
		mq.delay(1)
		Module.MainLoop()
	end
	mq.exit()
end

startup()

return Module
