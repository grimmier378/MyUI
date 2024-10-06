local mq             = require('mq')
local ImGui          = require 'ImGui'

MyUI_Utils           = require('lib.common')
MyUI_Actor           = require('actors')

MyUI_Version         = '1.0.0'
MyUI_ScriptName      = 'MyUI'

MyUI_Icons           = require('mq.ICONS')
MyUI_Base64          = require('lib.base64') -- Ensure you have a base64 module available
MyUI_PackageMan      = require('mq.PackageMan')
MyUI_LoadModules     = require('lib.modules')
MyUI_SQLite3         = MyUI_PackageMan.Require('lsqlite3')
MyUI_Colors          = require('lib.colors')
MyUI_ThemeLoader     = require('lib.theme_loader')
MyUI_AbilityPicker   = require('lib.AbilityPicker')
MyUI_Grimmier_Img    = MyUI_Utils.SetImage(mq.TLO.Lua.Dir() .. "/myui/images/GrimGUI.png")

-- build, char, server info
MyUI_CharLoaded      = mq.TLO.Me.DisplayName()
MyUI_Server          = mq.TLO.EverQuest.Server()
MyUI_Build           = mq.TLO.MacroQuest.BuildName()
MyUI_Guild           = mq.TLO.Me.Guild()

local MyActor        = MyUI_Actor.register('myui', function(message) end)
local mods           = {}
local Minimized      = false

MyUI_Modules         = {}
MyUI_Mode            = 'driver'
MyUI_SettingsFile    = mq.configDir .. '/MyUI/' .. MyUI_Server:gsub(" ", "_") .. '/' .. MyUI_CharLoaded .. '.lua'
MyUI_MyChatLoaded    = false
MyUI_MyChatHandler   = nil

local default_list   = {
	'AAParty',
	'ChatRelay',
	'DialogDB',
	'MyBuffs',
	'MyChat',
	'MyDPS',
	'MyGroup',
	'MyPaths',
	'MyPet',
	'MySpells',
	'PlayerTarg',
	'SAST',
	'SillySounds',
	"AlertMaster",
}

MyUI_DefaultConfig   = {
	ShowMain = true,
	ThemeName = 'Default',
	mods_list = {
		-- load order = {name = 'mod_name', enabled = true/false}
		-- Ideally we want to Load MyChat first if Enabled.This will allow the other modules can use it.
		[1]  = { name = 'MyChat', enabled = false, },
		[2]  = { name = 'DialogDB', enabled = false, },
		[3]  = { name = 'MyGroup', enabled = false, },
		[4]  = { name = 'MyPaths', enabled = false, },
		[5]  = { name = 'MyPet', enabled = false, },
		[6]  = { name = 'MySpells', enabled = false, },
		[7]  = { name = 'PlayerTarg', enabled = false, },
		[8]  = { name = 'SAST', enabled = false, },
		[9]  = { name = 'SillySounds', enabled = false, },
		[10] = { name = 'MyDPS', enabled = false, },
		[11] = { name = 'MyBuffs', enabled = false, },
		[12] = { name = 'ChatRelay', enabled = false, },
		[13] = { name = 'AAParty', enabled = false, },
		[14] = { name = 'AlertMaster', enabled = false, },
	},
}
MyUI_Settings        = {}
MyUI_TempSettings    = {}
MyUI_Theme           = {}
MyUI_ThemeFile       = string.format('%s/MyThemeZ.lua', mq.configDir)
MyUI_ThemeName       = 'Default'

local MyUI_IsRunning = false

local function LoadTheme()
	if MyUI_Utils.File.Exists(MyUI_ThemeFile) then
		MyUI_Theme = dofile(MyUI_ThemeFile)
	else
		MyUI_Theme = require('defaults.themes')
	end
end

local function LoadSettings()
	if MyUI_Utils.File.Exists(MyUI_SettingsFile) then
		MyUI_Settings = dofile(MyUI_SettingsFile)
	else
		MyUI_Settings = MyUI_DefaultConfig
	end

	local newSetting = MyUI_Utils.CheckDefaultSettings(MyUI_DefaultConfig, MyUI_Settings)
	newSetting = MyUI_Utils.CheckDefaultSettings(MyUI_DefaultConfig.mods_list, MyUI_Settings.mods_list) or newSetting

	Minimized = not MyUI_Settings.ShowMain
	LoadTheme()

	if newSetting then
		mq.pickle(MyUI_SettingsFile, MyUI_Settings)
	end
end

local function GetSortedModuleNames()
	local sorted_names = {}
	for _, data in ipairs(MyUI_Settings.mods_list) do
		table.insert(sorted_names, data.name)
	end
	table.sort(sorted_names)
	return sorted_names
end

local function InitModules()
	for idx, data in ipairs(MyUI_Settings.mods_list) do
		if data.enabled and MyUI_Modules[data.name] ~= nil and MyUI_Modules[data.name].ActorMailBox ~= nil then
			local message = {
				Subject = 'Hello',
				Message = 'Hello',
				Name = MyUI_CharLoaded,
				Guild = MyUI_Guild,
				Tell = '',
				Check = os.time,
			}
			MyActor:send({ mailbox = MyUI_Modules[data.name].ActorMailBox, script = data.name:lower(), }, message)
			MyActor:send({ mailbox = MyUI_Modules[data.name].ActorMailBox, script = 'myui', }, message)
		end
	end
end

local function RenderModules()
	for _, data in ipairs(MyUI_Settings.mods_list) do
		if data.enabled and MyUI_Modules[data.name] ~= nil then
			MyUI_Modules[data.name].RenderGUI()
		end
	end
end

local function ProcessModuleChanges()
	-- Enable/Disable Modules
	if MyUI_TempSettings.ModuleChanged then
		local module_name = MyUI_TempSettings.ModuleName
		local enabled = MyUI_TempSettings.ModuleEnabled

		for idx, data in ipairs(MyUI_Settings.mods_list) do
			if data.name == module_name then
				MyUI_Settings.mods_list[idx].enabled = enabled
				if enabled then
					table.insert(mods, module_name)
					MyUI_Modules[module_name] = MyUI_LoadModules.load(module_name)
					InitModules()
				else
					for i, v in ipairs(mods) do
						if v == module_name then
							MyUI_Modules[module_name].Unload()
							MyUI_LoadModules.unload(module_name)
							-- MyUI_Modules[module_name] = nil
							table.remove(mods, i)
						end
					end
					InitModules()
				end
				mq.pickle(MyUI_SettingsFile, MyUI_Settings)
				break
			end
		end
		MyUI_TempSettings.ModuleChanged = false
	end

	-- Add Custom Module
	if MyUI_TempSettings.AddCustomModule then
		local found = false
		for _, data in ipairs(MyUI_Settings.mods_list) do
			if data.name == MyUI_TempSettings.AddModule then
				found = true
				break
			end
		end
		if not found then
			table.insert(MyUI_Settings.mods_list, { name = MyUI_TempSettings.AddModule, enabled = false, })
			mq.pickle(MyUI_SettingsFile, MyUI_Settings)
		end
		MyUI_TempSettings.AddModule = ''
		MyUI_TempSettings.AddCustomModule = false
	end

	-- Remove Module
	if MyUI_TempSettings.RemoveModule then
		for idx, data in ipairs(MyUI_Settings.mods_list) do
			if data.name:lower() == MyUI_TempSettings.AddModule:lower() then
				for i, v in ipairs(mods) do
					if v == data.name then
						MyUI_Modules[data.name].Unload()
						MyUI_LoadModules.unload(data.name)
						-- MyUI_Modules[data.name] = nil
						table.remove(mods, i)
					end
				end
				table.remove(MyUI_Settings.mods_list, idx)
				mq.pickle(MyUI_SettingsFile, MyUI_Settings)
				break
			end
		end
		MyUI_TempSettings.AddModule = ''
		MyUI_TempSettings.RemoveModule = false
	end
end

local function DrawContextMenu()
	if mq.TLO.Plugin('MQ2DanNet').IsLoaded() then
		if ImGui.MenuItem('Start Clients') then
			mq.cmd('/dge all /lua run myui client')
		end
		if ImGui.MenuItem('Stop Clients') then
			mq.cmd('/dge all /myui quit')
		end
		if ImGui.MenuItem('Stop ALL') then
			mq.cmd('/dgae /myui quit')
		end
	end
	ImGui.Separator()
	if ImGui.MenuItem('Exit') then
		MyUI_IsRunning = false
	end
end

local function MyUI_Render()
	if MyUI_Settings.ShowMain then
		Minimized = false
		ImGui.SetNextWindowSize(400, 200, ImGuiCond.FirstUseEver)

		local open_gui, show_gui = ImGui.Begin(MyUI_ScriptName .. "##" .. MyUI_CharLoaded, true, ImGuiWindowFlags.None)

		if not open_gui then
			MyUI_Settings.ShowMain = false
			Minimized = true
			mq.pickle(MyUI_SettingsFile, MyUI_Settings)
		end

		if show_gui then
			ImGui.Text(MyUI_Icons.MD_SETTINGS)
			if ImGui.BeginPopupContextItem() then
				DrawContextMenu()
				ImGui.EndPopup()
			end

			local sizeX, sizeY = ImGui.GetContentRegionAvail()
			local col = math.floor(sizeX / 125) or 1
			local sorted_names = GetSortedModuleNames()
			local total_items = #sorted_names
			local rows = math.ceil(total_items / col)

			if ImGui.BeginTable("Modules", col, ImGuiWindowFlags.None) then
				for row = 1, rows do
					for column = 1, col do
						local index = (row - 1) + (column - 1) * rows + 1
						if index <= total_items then
							local name = sorted_names[index]
							local module_data = nil

							for _, data in ipairs(MyUI_Settings.mods_list) do
								if data.name == name then
									module_data = data
									break
								end
							end

							if module_data then
								ImGui.TableNextColumn()
								ImGui.SetNextItemWidth(120)
								local new_state = ImGui.Checkbox(module_data.name, module_data.enabled)

								-- If checkbox changed, set flags for processing
								if new_state ~= module_data.enabled then
									MyUI_TempSettings.ModuleChanged = true
									MyUI_TempSettings.ModuleName = module_data.name
									MyUI_TempSettings.ModuleEnabled = new_state
								end
							end
						end
					end
				end
				ImGui.EndTable()
			end

			-- Add Custom Module Section
			ImGui.SetNextItemWidth(150)
			MyUI_TempSettings.AddModule = ImGui.InputText("Add Custom Module", MyUI_TempSettings.AddModule or '')

			if MyUI_TempSettings.AddModule ~= '' then
				if ImGui.Button("Add") then
					MyUI_TempSettings.AddCustomModule = true
				end

				local found = false
				for _, v in pairs(default_list) do
					if v:lower() == MyUI_TempSettings.AddModule:lower() then
						found = true
						MyUI_TempSettings.AddModule = ''
						break
					end
				end

				if not found then
					ImGui.SameLine()
					if ImGui.Button("Remove") then
						MyUI_TempSettings.RemoveModule = true
					end
				end
			end
		end

		if ImGui.IsWindowFocused(ImGuiFocusedFlags.RootAndChildWindows) then
			if ImGui.IsKeyPressed(ImGuiKey.Escape) then
				MyUI_Settings.ShowMain = false
				Minimized = true
				mq.pickle(MyUI_SettingsFile, MyUI_Settings)
			end
		end

		ImGui.End()
	end


	if Minimized then
		local open_gui, show_gui = ImGui.Begin(MyUI_ScriptName .. "##Mini" .. MyUI_CharLoaded, true,
			bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar))

		if not open_gui then
			MyUI_Settings.ShowMain = false
			Minimized = true
			mq.pickle(MyUI_SettingsFile, MyUI_Settings)
		end
		if show_gui then
			if ImGui.ImageButton("MyUI", MyUI_Grimmier_Img:GetTextureID(), ImVec2(30, 30)) then
				MyUI_Settings.ShowMain = true
				Minimized = false
			end
		end
		if ImGui.BeginPopupContextWindow() then
			DrawContextMenu()
			ImGui.EndPopup()
		end
		ImGui.End()
	end

	RenderModules()
end

local function MyUI_Main()
	while MyUI_IsRunning do
		mq.doevents()
		ProcessModuleChanges()
		for idx, data in ipairs(MyUI_Settings.mods_list) do
			if data.enabled then
				MyUI_Modules[data.name].MainLoop()
			end
		end
		mq.delay(1)
	end
end

local args = { ..., }
local function CheckMode(value)
	if value == nil then
		MyUI_Mode = 'driver'
		return
	end
	if value[1] == 'client' then
		MyUI_Mode = 'client'
	elseif value[1] == 'driver' then
		MyUI_Mode = 'driver'
	end
end

local function CommandHandler(...)
	args = { ..., }
	if args[1] == 'show' then
		MyUI_Settings.ShowMain = not MyUI_Settings.ShowMain
		mq.pickle(MyUI_SettingsFile, MyUI_Settings)
	elseif args[1] == 'exit' or args[1] == 'quit' then
		MyUI_IsRunning = false
	end
end

local function StartUp()
	mq.bind('/myui', CommandHandler)
	CheckMode(args)
	LoadSettings()

	for _, data in ipairs(MyUI_Settings.mods_list) do
		if data.enabled then
			table.insert(mods, data.name)
		end
	end

	MyUI_Modules = MyUI_LoadModules.loadAll(mods)

	InitModules()

	MyUI_IsRunning = true
	mq.imgui.init(MyUI_ScriptName .. "##" .. MyUI_CharLoaded, MyUI_Render)
end

StartUp()
MyUI_Main()
