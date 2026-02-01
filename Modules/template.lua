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


local function Init()
	-- your Init code here
	mq.bind('/template', CommandHandler)
	Module.IsRunning = true
	Module.Utils.PrintOutput('main', true, "\ayModule \a-w[\at%s\a-w] \agLoaded\aw!", Module.Name)
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

local opts = {}
opts.Enabled = false
opts.Opacity = 0.5
opts.TextColor = Module.Colors.color('white')
opts.ShadowColor = Module.Colors.color('black')
opts.OffsetX = 2
opts.OffsetY = 2
opts.Blur = 0

---comment
---@param str any
---@param options table|nil # options Optional parameters: Enabled, Opacity, ShadowColor, OffsetX, OffsetY, TextColor
function Module.DropShadow(str, options)
	options                 = options or {}
	local enabled           = options.Enabled ~= false and options.Enabled or false
	local opacity           = options.Opacity or 1
	local shadowColor       = options.ShadowColor or Module.Colors.color('black')
	local offsetX           = options.OffsetX or 2
	local offsetY           = options.OffsetY or 2
	local shadowWithOpacity = ImVec4(shadowColor.x, shadowColor.y, shadowColor.z, opacity)

	if enabled then
		local cursorX, cursorY = ImGui.GetCursorPos()
		ImGui.SetCursorPosX(cursorX + offsetX)
		ImGui.SetCursorPosY(cursorY + offsetY)
		ImGui.PushStyleColor(ImGuiCol.Text, shadowWithOpacity)
		ImGui.TextUnformatted(str)
		ImGui.PopStyleColor()
		ImGui.SetCursorPosX(cursorX)
		ImGui.SetCursorPosY(cursorY)
		ImGui.PushStyleColor(ImGuiCol.Text, options.TextColor or Module.Colors.color('white'))
		ImGui.TextUnformatted(str)
		ImGui.PopStyleColor()
		return
	end
	ImGui.TextUnformatted(str)
end

-- Exposed Functions
function Module.RenderGUI()
	if Module.ShowGui then
		local open, show = ImGui.Begin(Module.Name .. "##" .. Module.CharLoaded, true, winFlags)
		if not open then
			show = false
			Module.ShowGui = false
		end
		if show then
			--GUI
			-- your code here
			Module.Utils.DropShadow("Template Module DropShadow Default", opts)
			opts.Enabled = ImGui.Checkbox("Enable DropShadow", opts.Enabled)
			opts.Opacity = ImGui.SliderFloat("DropShadow Opacity", opts.Opacity, 0.0, 1.0)
			opts.OffsetX = ImGui.SliderInt("DropShadow OffsetX", opts.OffsetX, 0, 10)
			opts.OffsetY = ImGui.SliderInt("DropShadow OffsetY", opts.OffsetY, 0, 10)
			opts.ShadowColor = ImGui.ColorEdit4("DropShadow Color", opts.ShadowColor)

			Module.Utils.DropShadow("Testing DropShadow Preview", opts)
			Module.Utils.DropShadow("Testing DEFAULT NO OPTIONS SENT")
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
	if loadedExeternally and not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end

	-- This will only allow the MainLoop to run every 500ms (half a secon)
	if mq.gettime() - drawTimerMS < 1000 then
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

--button master button test
function btnTest()
-- lua
local ScriptName = 'rgmercs'
local myName = mq.TLO.Me.DisplayName()
local raidSize = mq.TLO.Raid.Members() or 0
local IsRunning = mq.TLO.Lua.Script(ScriptName).Status() == 'RUNNING'

local tankList = {
	[1] = { Name = 'Shadowfrog', Enabled = true, },
	[2] = { Name = 'Derf', Enabled = true, },
	[3] = { Name = 'Grobash', Enabled = true, },
	[4] = { Name = 'Grimmier', Enabled = true, },
	[5] = { Name = 'Shadly', Enabled = true, },
}


if raidSize == 0 then
	if IsRunning then
		mq.cmdf('/dgg /lstop %s', ScriptName)
		mq.cmdf('/lstop %s', ScriptName)
	else
		local delay = 10
		for i = 1, mq.TLO.Me.GroupSize() - 1 do
			mq.cmdf('/timed %s /dex %s /lrun %s mini', (i * delay), mq.TLO.Group.Member(i).DisplayName(), ScriptName)
		end
		delay = delay * mq.TLO.Me.GroupSize()
		mq.cmdf('/lrun %s mini', ScriptName)
		local cmd = string.format("/timed %s /dgg /multiline ; /rgl assistclear; /timed %s /rgl assistadd %s", delay, delay + 5, myName)
		mq.cmd(cmd)
		delay = delay + 10
		for _, data in ipairs(tankList or {}) do
			if data.Enabled and mq.TLO.Group.Member(data.Name)() ~= nil then
				mq.cmdf("/timed %d /dgg /multiline ; /rgl assistadd %s", delay, data.Name)
				delay = delay + 5
			end
		end
		for i = 1, mq.TLO.Me.GroupSize() - 1 do
			local mName = mq.TLO.Group.Member(i).DisplayName() or ''
			for _, data in ipairs(tankList or {}) do
				if data.Enabled and data.Name == mName then
					goto next
				end
			end
			mq.cmdf("/timed %d /dgg /multiline ; /rgl assistadd %s", (i * 5 + delay), mName)
			::next::
		end
	end
else
	local delay = 0
	if IsRunning then
		mq.cmdf('/dgr /lstop %s', ScriptName)
		mq.cmdf('/lstop %s', ScriptName)
	else
		for i = 1, raidSize do
			if mq.TLO.Raid.Member(i).CleanName() ~= mq.TLO.Me.CleanName() then
				mq.cmdf('/timed %s /dex %s /lrun %s mini', (i * 10), mq.TLO.Raid.Member(i).CleanName(), ScriptName)
			else
				-- if it's me then just run the script immediately
				mq.cmdf('/lrun %s mini', ScriptName)
			end
			delay = i * 15
		end
		-- RAID SETUP
		local myName = mq.TLO.Me.CleanName():lower()
		delay = delay + 15
		-- enter tanks in order you wish them to be in first slot will always default to the caller of the script

		local cmd = string.format("/timed %s /dgr /multiline ; /rgl assistclear; /timed %s /rgl setma %s", delay, 5, myName)
		mq.cmd(cmd)
		delay = delay + 10 -- set to at least 5 more than the last delay before the table iterations
		for _, data in ipairs(tankList or {}) do
			if data.Enabled then
				mq.cmdf("/timed %d /dgr /multiline ; /rgl assistadd %s", delay, data.Name)
				delay = delay + 15
			end
		end
		for i = 1, raidSize do
			local memberName = mq.TLO.Raid.Member(i).CleanName()
			if not tankList[memberName] then
				mq.cmdf("/timed %d /dgr /multiline ; /rgl assistadd %s", delay, memberName)
				delay = delay + 15
			end
		end
		mq.cmdf("/timed %s /multiline ; /timed %s /rgl chaseoff; /timed %s /rgl chaseon", delay, 5, 20)
	end
end

end

-- Init the module
Init()
return Module
