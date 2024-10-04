local mq = require('mq')
local ImGui = require 'ImGui'
local ModuleName = {} -- Module Name Here Returns the table of functions and any variables you wish to expose to the main script.

--[[ GLOBAL MyUI_ variables and functions.
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

	MyUI_Modules         = {} -- table to hold all loaded modules you can interact with any of their exposed functions here.
	MyUI_Mode            = 'driver' -- set to 'driver' or 'client' depending on the mode you are running in. can be checked when loading your module if you need to run different code for each mode.
	MyUI_SettingsFile    = mq.configDir .. '/MyUI/' .. MyUI_Server:gsub(" ", "_") .. '/' .. MyUI_CharLoaded .. '.lua'
	MyUI_MyChatLoaded    = false -- set to true if MyChat is loaded Check this before trying to use the MyChatHandler
	MyUI_MyChatHandler = nil -- function to take in messages and output them to a specific tab in MyChat
									this will create the tab if it does not exist and output the message to it.
									Usage: MyUI_MyChatHandler('TabName', 'Message')
									you can use 'main' for the main tab.
]]

-- Exposed Variables
ModuleName.ShowGui = false

-- Local Variables

--Helpers
-- You can keep your functions local to the module the ones here are the only ones we care about from the main script.
local function Init()
	-- your Init code here
end

-- Exposed Functions
function ModuleName.RenderGUI()
	if ModuleName.ShowGui then
		local open, show = ImGui.Begin(ModuleName .. "##" .. MyUI_CharLoaded, true, ImGuiWindowFlags.None)
		if not open then
			show = false
			ModuleName.ShowGui = false
		end
		if show then
			--GUI
			-- your code here
		end

		ImGui.End()
	end
end

function ModuleName.Unload()
	-- undo any binds and events before unloading
	-- leave empty if you don't have any binds or events
end

function ModuleName.MainLoop()
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
return ModuleName
