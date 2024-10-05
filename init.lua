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

local MyActor        = MyUI_Actor.register('myui', function(message) end)
MyUI_Modules         = {}
MyUI_Mode            = 'driver'
local mods           = {}
local Minimized      = false
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
}

MyUI_DefaultConfig   = {
	ShowMain = true,
	ThemeName = 'Default',
	mods_enabled = {
		[13] = { name = 'AAParty', enabled = false, },
		[12] = { name = 'ChatRelay', enabled = false, },
		[2]  = { name = 'DialogDB', enabled = false, },
		[11] = { name = 'MyBuffs', enabled = false, },
		[1]  = { name = 'MyChat', enabled = false, },
		[10] = { name = 'MyDPS', enabled = false, },
		[3]  = { name = 'MyGroup', enabled = false, },
		[4]  = { name = 'MyPaths', enabled = false, },
		[5]  = { name = 'MyPet', enabled = false, },
		[6]  = { name = 'MySpells', enabled = false, },
		[7]  = { name = 'PlayerTarg', enabled = false, },
		[8]  = { name = 'SAST', enabled = false, },
		[9]  = { name = 'SillySounds', enabled = false, },
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

	for k, v in pairs(MyUI_DefaultConfig) do
		if MyUI_Settings[k] == nil then
			MyUI_Settings[k] = v
		end
	end

	for k, v in pairs(MyUI_DefaultConfig.mods_enabled) do
		if MyUI_Settings.mods_enabled[k] == nil then
			MyUI_Settings.mods_enabled[k] = v
		end
	end

	Minimized = not MyUI_Settings.ShowMain
	LoadTheme()
end

local function GetSortedModuleNames()
	local sorted_names = {}
	for _, data in ipairs(MyUI_Settings.mods_enabled) do
		table.insert(sorted_names, data.name)
	end
	table.sort(sorted_names)
	return sorted_names
end


local function InitModules()
	for idx, data in ipairs(MyUI_Settings.mods_enabled) do
		if data.enabled and MyUI_Modules[data.name] ~= nil then
			local message = {
				Subject = 'Hello',
				Message = 'Hello',
				Name = MyUI_CharLoaded,
				Guild = mq.TLO.Me.Guild(),
				Tell = '',
				Check = os.time,
			}
			MyActor:send({ mailbox = MyUI_Modules[data.name].ActorMailBox, script = data.name:lower(), }, message)
			MyActor:send({ mailbox = MyUI_Modules[data.name].ActorMailBox, script = 'myui', }, message)
		end
	end
end

local function RenderModules()
	for _, data in ipairs(MyUI_Settings.mods_enabled) do
		if data.enabled and MyUI_Modules[data.name] ~= nil then
			MyUI_Modules[data.name].RenderGUI()
		end
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
			if ImGui.BeginTable("Modules", 2, ImGuiWindowFlags.None) then
				local sorted_names = GetSortedModuleNames()

				for _, name in ipairs(sorted_names) do
					local module_data = nil
					for _, data in ipairs(MyUI_Settings.mods_enabled) do
						if data.name == name then
							module_data = data
							break
						end
					end

					if module_data then
						local pressed = false
						ImGui.TableNextColumn()
						module_data.enabled, pressed = ImGui.Checkbox(module_data.name, module_data.enabled)
						if pressed then
							if module_data.enabled then
								table.insert(mods, module_data.name)
								MyUI_Modules[module_data.name] = MyUI_LoadModules.load(module_data.name)
								InitModules()
							else
								for i, v in ipairs(mods) do
									if v == module_data.name then
										MyUI_Modules[module_data.name].Unload()
										MyUI_LoadModules.unload(module_data.name)
										MyUI_Modules[module_data.name] = nil
										table.remove(mods, i)
									end
								end
								InitModules()
							end
							mq.pickle(MyUI_SettingsFile, MyUI_Settings)
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
					local found = false
					for _, data in ipairs(MyUI_Settings.mods_enabled) do
						if data.name == MyUI_TempSettings.AddModule then
							found = true
							break
						end
					end
					if not found then
						table.insert(MyUI_Settings.mods_enabled, { name = MyUI_TempSettings.AddModule, enabled = false, })
						mq.pickle(MyUI_SettingsFile, MyUI_Settings)
					end
					MyUI_TempSettings.AddModule = ''
				end

				local found

				for _, v in pairs(default_list) do
					if v:lower() == MyUI_TempSettings.AddModule:lower() then
						MyUI_TempSettings.AddModule = ''
						found = true
						break
					end
				end

				if not found then
					ImGui.SameLine()

					if ImGui.Button("Remove") then
						for idx, data in ipairs(MyUI_Settings.mods_enabled) do
							if data.name:lower() == MyUI_TempSettings.AddModule:lower() then
								for i, v in ipairs(mods) do
									if v == data.name then
										MyUI_Modules[data.name].Unload()
										MyUI_LoadModules.unload(data.name)
										MyUI_Modules[data.name] = nil
										table.remove(mods, i)
									end
								end
								table.remove(MyUI_Settings.mods_enabled, idx)
								mq.pickle(MyUI_SettingsFile, MyUI_Settings)
								break
							end
						end
						MyUI_TempSettings.AddModule = ''
					end
				end
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
		ImGui.End()
	end

	RenderModules() -- This stays unchanged to render the module UIs as before
end


local function MyUI_Main()
	while MyUI_IsRunning do
		mq.doevents()
		for idx, data in ipairs(MyUI_Settings.mods_enabled) do
			if data.enabled and MyUI_Modules[data.name] ~= nil then
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

	for _, data in ipairs(MyUI_Settings.mods_enabled) do
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
