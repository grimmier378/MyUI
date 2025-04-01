--[[ Template for Module Creatio/Conversion

GLOBAL MyUI_ variables and functions.
	MyUI_Utils           = require('lib.common') -- some common functions on other scripts
	MyUI_Actor           = require('actors') -- Load Actors globally for use in modules

	MyUI_Icons           = require('mq.ICONS') -- text icons for GUI
	MyUI_Base64          = require('lib.base64') -- for encoding/decoding data to share between clients
	MyUI_PackageMan      = require('mq.PackageMan') -- Globally load the Package Manager
	MyUI_LoadModules     = require('lib.modules') -- Functions to load and unload modules.
	MyUI_SQLite3         = MyUI_PackageMan.Require('lsqlite3') -- globally load sqlite3 package
	MyUI_Colors          = require('lib.colors')  -- color table for GUI returns ImVec4
	MyUI_ThemeLoader     = require('lib.theme_loader')
	MyUI_AbilityPicker   = require('lib.AbilityPicker')

	-- General MQ Build, Char Name, Server Name
	MyUI_CharLoaded      = mq.TLO.Me.DisplayName()
	MyUI_Server          = mq.TLO.EverQuest.Server()
	MyUI_Build           = mq.TLO.MacroQuest.BuildName()
	MyUI_Guild           = mq.TLO.Me.Guild()

	MyUI_Modules         = {} -- table to hold all loaded modules you can interact with any of their exposed functions here.
	MyUI_Mode            = 'driver' -- set to 'driver' or 'client' depending on the mode you are running in. can be checked when loading your module if you need to run different code for each mode.
	MyUI_SettingsFile    = mq.configDir .. '/MyUI/' .. MyUI_Server:gsub(" ", "_") .. '/' .. MyUI_CharLoaded .. '.lua'
	MyUI_MyChatLoaded    = false -- set to true if MyChat is loaded Check this before trying to use the MyChatHandler
	MyUI_MyChatHandler = nil -- function to take in messages and output them to a specific tab in MyChat
							this will create the tab if it does not exist and output the message to it.
						Usage: MyUI_MyChatHandler('TabName', 'Message')
							you can use 'main' for the main tab.

	To output to MyChat without directly accessing the handler you can use MyUI_Utils.PrintOutput()
	MyUI_Utils.PrintOutput will process the output and send it to the correct console(s) based on the parameters and status of MyChaat

	usage: MyUI_Utils.PrintOutput('TabName', outputMainAlso, 'Message %s', 'with formatting')
		-- This will output to the specified tab and the main console if outputMainAlso is true.
		-- Leaving the TabName nil will output to the main console only.


]]

local mq = require('mq')
local ImGui = require 'ImGui'
local drawTimerMS = mq.gettime() -- get the current time in milliseconds
local drawTimerS = os.time()     -- get the current time in seconds
local Module = {}

Module.Name = "Clock"    -- Name of the module used when loading and unloaing the modules.
Module.IsRunning = false -- Keep track of running state. if not running we can unload it.
Module.ShowGui = true

-- check if the script is being loaded as a Module (externally) or as a Standalone script.
---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false
if not loadedExeternally then
	-- for local standalone use we will need to load in the global MyUI_ variables and functions. and make sure to include the files as needed inside of the scripts folder.
	-- Comment/Uncomment the items below as needed
	MyUI_Utils       = require('lib.common') -- common functions for use in other scripts
	MyUI_Icons       = require('mq.ICONS') -- FAWESOME ICONS
	-- MyUI_Actor         = require('actors') -- Actors if needed
	-- MyUI_Base64        = require('lib.base64') -- Ensure you have a base64 module available
	-- MyUI_PackageMan    = require('mq.PackageMan')
	-- MyUI_SQLite3       = MyUI_PackageMan.Require('lsqlite3')
	MyUI_Colors      = require('lib.colors')    -- color table for GUI returns ImVec4
	MyUI_ThemeLoader = require('lib.theme_loader') -- Load the theme loader
	-- MyUI_AbilityPicker = require('lib.AbilityPicker') -- Ability Picker

	-- build, char, server info
	MyUI_CharLoaded  = mq.TLO.Me.DisplayName()
	MyUI_Server      = mq.TLO.EverQuest.Server()
	MyUI_Build       = mq.TLO.MacroQuest.BuildName()
	MyUI_Guild       = mq.TLO.Me.Guild() or "none"
end

local gTime = string.format("%s %s", mq.TLO.GameTime.Time12():sub(1, 5), mq.TLO.GameTime.Hour() > 12 and 'PM' or 'AM')
--[[
	-- This is the main module template for MyUI. It is a basic template to get you started with your own modules.
	-- You can use this as a base to build your own modules and add your own functionality.
	-- The template will load the module and allow you to use it in the MyUI framework.
	-- You can also use this as a standalone script if you want to run it outside of MyUI.

]]

--Helpers
-- You can keep your functions local to the module the ones here are the only ones we care about from the main script.
local function CommandHandler(...)
	local args = { ..., }
	if args[1] ~= nil then
		if args[1] == 'exit' or args[1] == 'quit' then
			Module.IsRunning = false
			MyUI_Utils.PrintOutput('MyUI', true, "\ay%s \awis \arExiting\aw...", Module.Name)
		elseif args[1] == 'show' or args[1] == 'ui' then
			Module.ShowGui = not Module.ShowGui
		end
	end
end

--[[
	-- This is the main function that will be called when the module is loaded.
	-- You can use this to initialize your module and set up any variables or functions you need.
	-- You can also use this to bind any commands or events you need to handle.
	-- This will be called when the module is loaded and will run in the background until the module is unloaded.
]]

local function Init()
	-- your Init code here
	mq.bind('/template', CommandHandler)
	Module.IsRunning = true
	MyUI_Utils.PrintOutput('main', true, "\ayModule \a-w[\at%s\a-w] \agLoaded\aw!", Module.Name)

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

--[[
	-- This is the function that will be called to render the GUI for the module.
	-- You can use this to create your own GUI and add any functionality you need.
	-- This will be called every frame and will run in the background until the module is unloaded.
]]
function Module.RenderGUI()
	if Module.ShowGui then
		ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(0.1, 0.1, 0.1, 0.8))
		local open, show = ImGui.Begin(Module.Name .. "##" .. MyUI_CharLoaded, true, winFlags)
		if not open then
			show = false
			Module.ShowGui = false
		end
		if show then
			--GUI
			-- your code here

			-- ImGui.Text("Char: ")
			-- ImGui.SameLine()
			-- ImGui.TextColored(MyUI_Colors.color('yellow'), " %s", MyUI_CharLoaded)

			ImGui.PushTextWrapPos(250)

			ImGui.Text("Zone:")
			ImGui.SameLine()
			ImGui.TextColored(MyUI_Colors.color('softblue'), " %s", mq.TLO.Zone.Name())

			ImGui.Text("RealTime: ")
			ImGui.SameLine()
			ImGui.TextColored(MyUI_Colors.color('yellow'), os.date("%I:%M:%S %p (%A)"))

			ImGui.Text("GameTime: ")
			ImGui.SameLine()
			ImGui.TextColored(MyUI_Colors.color('teal'), gTime)

			ImGui.PopTextWrapPos()
		end
		ImGui.PopStyleColor()
		ImGui.End()
	end
end

--[[
	-- This is the function that will be called to unload the module.
	-- You can use this to clean up any variables or functions you need to unload.
	-- This will be called when the module is unloaded and will run in the background until the module is unloaded.
]]
function Module.Unload()
	-- undo any binds and events before unloading
	-- leave empty if you don't have any binds or events
	mq.unbind('/template')
end

--[[
	-- This is the Main Loop for the module.
	-- This will be called from the main script and will run in the background until the module is unloaded.
	]]
function Module.MainLoop()
	-- This will unload the module gracefully if IsRunning state changes.
	if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end

	-- This will only allow the MainLoop to run every 500ms (half a secon)
	if mq.gettime() - drawTimerMS < 3500 then
		return
	else
		-- your code here
		drawTimerMS = mq.gettime()
		gTime = string.format("%s %s", mq.TLO.GameTime.Time12():sub(1, 5), mq.TLO.GameTime.Hour() > 12 and 'PM' or 'AM')
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

--[[
	-- This is the Local Loop for the module.
	-- you call this when not loading this script as a module.
	-- This will call the MainLoop function every 1ms.
]]
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
