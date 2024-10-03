local mq             = require('mq')
local ImGui          = require 'ImGui'

MyUI_Utils           = require('lib.common')
MyUI_Actor           = require('actors')

MyUI_Version         = '1.0.0'
MyUI_ScriptName      = 'GrimGUI'

MyUI_Icons           = MyUI_Utils.Library.Include('mq.ICONS')
MyUI_Base64          = MyUI_Utils.Library.Include('lib.base64') -- Ensure you have a base64 module available
MyUI_PackageMan      = MyUI_Utils.Library.Include('mq.PackageMan')
MyUI_LoadModules     = MyUI_Utils.Library.Include('lib.modules')

MyUI_SQLite3         = MyUI_PackageMan.Require('lsqlite3')
MyUI_Colors          = MyUI_Utils.Library.Include('lib.colors')
MyUI_ThemeLoader     = require('lib.theme_loader')
MyUI_AbilityPicker   = MyUI_Utils.Library.Include('lib.AbilityPicker')

-- build, char, server info
MyUI_CharLoaded      = mq.TLO.Me.DisplayName()
MyUI_Server          = mq.TLO.EverQuest.Server()
MyUI_Build           = mq.TLO.MacroQuest.BuildName()

local MyActor        = MyUI_Actor.register('myui', function(message) end)
MyUI_Modules         = {}
MyUI_Mode            = 'driver'
local mods           = {}
MyUI_SettingsFile    = mq.configDir .. '/MyUI/' .. MyUI_Server:gsub(" ", "_") .. '/' .. MyUI_CharLoaded .. '.lua'

MyUI_DefaultConfig   = {
	ShowMain = true,
	mods_enabled = {
		ChatRelay = false,
		AAParty = false,
		DialogDB = false,
		MyBuffs = false,
		MyChat = false,
		MyDps = false,
		MyGroup = false,
		MyPaths = false,
		MyPet = false,
		MySpells = false,
		PlayerTarg = false,
		SAST = false,
		SillySounds = false,
	},
}
MyUI_Settings        = {}
MyUI_Theme           = {}
MyUI_ThemeName       = 'Default'

local MyUI_IsRunning = false

local function LoadSettings()
	if MyUI_Utils.File.Exists(MyUI_SettingsFile) then
		MyUI_Settings = dofile(MyUI_SettingsFile)
	else
		MyUI_Settings = MyUI_DefaultConfig
	end
end

local function RenderModules()
	for modName, enabled in pairs(MyUI_Settings.mods_enabled) do
		if enabled and MyUI_Modules[modName] ~= nil then
			MyUI_Modules[modName].RenderGUI()
		end
	end
end

local function MyUI_Render()
	if MyUI_Settings.ShowMain then
		ImGui.SetNextWindowSize(400, 200, ImGuiCond.FirstUseEver)
		local color_count, style_count = MyUI_ThemeLoader.StartTheme(MyUI_Theme)

		local open_gui, show_gui = ImGui.Begin(MyUI_ScriptName .. "##" .. MyUI_CharLoaded, true, ImGuiWindowFlags.None)

		if not open_gui then
			MyUI_Settings.ShowMain = false
			mq.pickle(MyUI_SettingsFile, MyUI_Settings)
		end
		if ImGui.BeginTable("Modules", 2, ImGuiWindowFlags.None) then
			if show_gui then
				for modName, enabled in pairs(MyUI_Settings.mods_enabled) do
					local pressed = false
					ImGui.TableNextColumn()
					enabled, pressed = ImGui.Checkbox(modName, enabled)
					if pressed then
						if MyUI_Settings.mods_enabled[modName] == false then
							if enabled then
								table.insert(mods, modName)
								MyUI_Modules = MyUI_LoadModules.load(mods)
							end
						end
						MyUI_Settings.mods_enabled[modName] = not MyUI_Settings.mods_enabled[modName]
						mq.pickle(MyUI_SettingsFile, MyUI_Settings)
					end
				end
			end
			ImGui.EndTable()
		end

		MyUI_ThemeLoader.EndTheme(color_count, style_count)
		ImGui.End()
	end
	RenderModules()
end

local function MyUI_Main()
	while MyUI_IsRunning do
		mq.doevents()
		for modName, enabled in pairs(MyUI_Settings.mods_enabled) do
			if enabled and MyUI_Modules[modName] ~= nil then
				MyUI_Modules[modName].MainLoop()
				mq.delay(10)
			end
		end
		mq.delay(1)
	end
end

local args = { ..., }

local function CheckMode(value)
	if value[1] == 'client' then
		MyUI_Mode = 'client'
	else
		MyUI_Mode = 'driver'
	end
end

local function CommandHandler(...)
	local args = { ..., }
	if args[1] == 'show' then
		MyUI_Settings.ShowMain = not MyUI_Settings.ShowMain
		mq.pickle(MyUI_SettingsFile, MyUI_Settings)
	elseif args[1] == 'exit' or args[1] == 'quit' then
		MyUI_IsRunning = false
	end
end

local function StartUp()
	mq.bind('/grimgui', CommandHandler)
	CheckMode(args)
	LoadSettings()

	for modName, enabled in pairs(MyUI_Settings.mods_enabled) do
		if enabled then
			table.insert(mods, modName)
		end
	end
	MyUI_Modules = MyUI_LoadModules.load(mods)

	for modName, enabled in pairs(MyUI_Settings.mods_enabled) do
		if enabled and MyUI_Modules[modName] ~= nil then
			local message = {
				Subject = 'Hello',
				Message = 'Hello',
				Name = MyUI_CharLoaded,
				Guild = mq.TLO.Me.Guild(),
				Tell = '',
				Check = os.time,
			}
			MyActor:send({ mailbox = MyUI_Modules[modName].ActorMailBox, script = modName:lower(), }, message)
			MyActor:send({ mailbox = MyUI_Modules[modName].ActorMailBox, script = 'grimgui', }, message)
		end
	end

	MyUI_IsRunning = true
	mq.imgui.init(MyUI_ScriptName .. "##" .. MyUI_CharLoaded, MyUI_Render)
end

StartUp()
MyUI_Main()
