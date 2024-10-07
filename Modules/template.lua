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

Module.Name = "Template" -- Name of the module used when loading and unloaing the modules.
Module.IsRunning = false -- Keep track of running state. if not running we can unload it.
Module.ShowGui = true

-- check if the script is being loaded as a Module (externally) or as a Standalone script.
---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false
if not loadedExeternally then
	-- for local standalone use we will need to load in the global MyUI_ variables and functions. and make sure to include the files as needed inside of the scripts folder.
	-- Comment/Uncomment the items below as needed
	MyUI_Utils       = require('lib.common') -- common functions for use in other scripts
	MyUI_Icons       = require('mq.ICONS')  -- FAWESOME ICONS
	-- MyUI_Actor         = require('actors') -- Actors if needed
	-- MyUI_Base64        = require('lib.base64') -- Ensure you have a base64 module available
	-- MyUI_PackageMan    = require('mq.PackageMan')
	-- MyUI_SQLite3       = MyUI_PackageMan.Require('lsqlite3')
	MyUI_Colors      = require('lib.colors')      -- color table for GUI returns ImVec4
	MyUI_ThemeLoader = require('lib.theme_loader') -- Load the theme loader
	-- MyUI_AbilityPicker = require('lib.AbilityPicker') -- Ability Picker

	-- build, char, server info
	MyUI_CharLoaded  = mq.TLO.Me.DisplayName()
	MyUI_Server      = mq.TLO.EverQuest.Server()
	MyUI_Build       = mq.TLO.MacroQuest.BuildName()
	MyUI_Guild       = mq.TLO.Me.Guild()
end


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

-- Exposed Functions
function Module.RenderGUI()
	if Module.ShowGui then
		local open, show = ImGui.Begin(Module.Name .. "##" .. MyUI_CharLoaded, true, ImGuiWindowFlags.None)
		if not open then
			show = false
			Module.ShowGui = false
		end
		if show then
			--GUI
			-- your code here
			ImGui.Text("Hello World!")

			ImGui.Text("Timer S: %d", drawTimerS)
		end

		ImGui.End()
	end
end

function Module.Unload()
	-- undo any binds and events before unloading
	-- leave empty if you don't have any binds or events
	mq.unbind('/template')
end

function Module.MainLoop()
	-- This will unload the module gracefully if IsRunning state changes.
	if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end

	-- This will only allow the MainLoop to run every 500ms (half a secon)
	if mq.gettime() - drawTimerMS < 500 then
		return
	else
		-- your code here
		drawTimerMS = mq.gettime()
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
