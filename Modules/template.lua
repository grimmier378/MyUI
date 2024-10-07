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
local drawTimerMS = mq.gettime()
local drawTimerS = os.time()
-- Exposed Variables
local Module = {}
Module.Name = "Template" -- Name of the module used when loading and unloaing the modules.
Module.IsRunning = false -- Keep track of running state. if not running we can unload it.
Module.ShowGui = true

-- Local Variables

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

	if os.time() - drawTimerS < 5 then
		return
		-- your code here
	else
		-- drawTimerMS = mq.gettime()
		drawTimerS = os.time()
	end
	--[[
	your MainLoop code here without the loop.
	
	DO NOT USE WHILE loops here.

	If you need to specify a delay you cah set a timer variable and check it in the MainLoop
	to execute code every x seconds, use os.time() for the compare.
	to execute code every x milliseconds, use mq.gettime() for the compare.

	Exapmle:
	outside the MainLoop: local timer = os.time()
	in the MainLoop:
	if os.time() - timer >= 1 then
		-- your code here
		timer = os.time()
	end
	]]
end

-- Init the module

Init()
return Module
