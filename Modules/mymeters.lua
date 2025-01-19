--[[
	Title: MyMeters
	Author: Grimmier

	Description: Shows your Breath meter, Casting bars and potentially a few other ones as i add to it later.
]]

local mq = require('mq')
local ImGui = require('ImGui')
local Module = {}
Module.IsRunning = false
Module.Name = "MyMeters"

---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false

if not loadedExeternally then
	Module.Utils       = require('lib.common')
	Module.Icons       = require('mq.ICONS')
	Module.CharLoaded  = mq.TLO.Me.DisplayName()
	Module.Server      = mq.TLO.MacroQuest.Server()
	Module.ThemeLoader = require('lib.theme_loader')
	Module.Path        = string.format("%s/%s/", mq.luaDir, Module.Name)
	Module.ThemeFile   = string.format('%s/MyUI/ThemeZ.lua', mq.configDir)
	Module.Theme       = {}
else
	Module.Utils = MyUI_Utils
	Module.Icons = MyUI_Icons
	Module.CharLoaded = MyUI_CharLoaded
	Module.Server = MyUI_Server
	Module.ThemeLoader = MyUI_ThemeLoader
	Module.Path = MyUI_Path
	Module.ThemeFile = MyUI_ThemeFile
	Module.Theme = MyUI_Theme
end

local picker = Module.AbilityPicker.new()
local pickerOpen = false
local bIcon = Module.Icons.FA_BOOK
local gIcon = Module.Icons.MD_SETTINGS
local defaults, settings, timerColor = {}, {}, {}
local configFile = string.format('%s/myui/%s/%s/%s.lua', mq.configDir, Module.Name, Module.Server, Module.CharLoaded)
local themezDir = mq.luaDir .. '/themez/init.lua'
local themeName = 'Default'
local casting = false
local spellBar = {}
local numGems = 8
local redGem = Module.Utils.SetImage(Module.Path .. '/images/red_gem.png')
local greenGem = Module.Utils.SetImage(Module.Path .. '/images/green_gem.png')
local purpleGem = Module.Utils.SetImage(Module.Path .. '/images/purple_gem.png')
local blueGem = Module.Utils.SetImage(Module.Path .. '/images/blue_gem.png')
local orangeGem = Module.Utils.SetImage(Module.Path .. '/images/orange_gem.png')
local yellowGem = Module.Utils.SetImage(Module.Path .. '/images/yellow_gem.png')
local openBook = Module.Utils.SetImage(Module.Path .. '/images/open_book.png')
local closedBook = Module.Utils.SetImage(Module.Path .. '/images/closed_book.png')
local memSpell = -1
local currentTime = os.time()
local maxRow, rowCount, iconSize, scale = 1, 0, 30, 1
local aSize, locked, castLocked, hasThemeZ, configWindowShow, loadSet, clearAll, CastTextColorByType = false, false, false, false, false, false, false, false
local setName = 'None'
local tmpName = ''
local showTitle, showTitleCasting = true, false
local interrupted = false
local enableCastBar = false
local debugShow = false
local castTransparency = 1.0
local startedCast, startCastTime, castBarShow = false, 0, false

defaults = {
	[Module.Name] = {
		Scale = 1.0,
		LoadTheme = 'Default',
		locked = false,
		CastLocked = false,
		CastTransperancy = 1.0,
		ShowTitleCasting = false,
		ShowTitleBar = true,
		enableCastBar = false,
		CastTextColorByType = false,
		IconSize = 30,
		TimerColor = { 1, 1, 1, 1, },
		maxRow = 1,
		AutoSize = false,
	},
}

local function pickColorByType(spellID)
	local spell = mq.TLO.Spell(spellID)
	local categoryName = spell.Category()
	local subcaterogy = spell.Subcategory()
	local targetType = spell.TargetType()
	if targetType == 'Single' or targetType == 'Line of Sight' or targetType == 'Undead' or categoryName == 'Taps' then
		return redGem, ImVec4(0.9, 0.1, 0.1, 1)
	elseif targetType == 'Self' then
		return yellowGem, ImVec4(1, 1, 0, 1)
	elseif targetType == 'Group v2' or targetType == 'Group v1' or targetType == 'AE PC v2' then
		return purpleGem, ImVec4(0.8, 0.0, 1.0, 1.0)
	elseif targetType == 'Beam' then
		return blueGem, ImVec4(0, 1, 1, 1)
	elseif targetType == 'Targeted AE' and (categoryName == 'Utility Detrimental' or spell.PushBack() > 0 or spell.AERange() < 20) then
		return greenGem, ImVec4(0, 1, 0, 1)
	elseif targetType == 'Targeted AE' then
		return orangeGem, ImVec4(1.0, 0.76, 0.03, 1.0)
	elseif targetType == 'PB AE' then
		return blueGem, ImVec4(0, 1, 1, 1)
	elseif targetType == 'Pet' then
		return redGem, ImVec4(0.9, 0.1, 0.1, 1)
	elseif targetType == 'Pet2' then
		return redGem, ImVec4(0.9, 0.1, 0.1, 1)
	elseif targetType == 'Free Target' then
		return greenGem, ImVec4(0, 1, 0, 1)
	else
		return redGem, ImVec4(1, 1, 1, 1)
	end
end

local function loadTheme()
	if Module.Utils.File.Exists(Module.ThemeFile) then
		Module.Theme = dofile(Module.ThemeFile)
	else
		Module.Theme = require('defaults.themes') -- your local themes file incase the user doesn't have one in config folder
		mq.pickle(Module.ThemeFile, Module.Theme)
	end
end

local function loadSettings()
	-- Check if the dialog data file exists
	local newSetting = false
	if not Module.Utils.File.Exists(configFile) then
		settings = defaults
		mq.pickle(configFile, settings)
		loadSettings()
	else
		settings = dofile(configFile)
	end

	-- check for new settings and add them to the settings file
	newSetting = Module.Utils.CheckDefaultSettings(defaults, settings)
	newSetting = Module.Utils.CheckRemovedSettings(defaults, settings) or newSetting

	if settings[Module.Name][Module.CharLoaded] == nil then
		settings[Module.Name][Module.CharLoaded] = {}
		settings[Module.Name][Module.CharLoaded].Sets = {}
		newSetting = true
	end

	if not loadedExeternally then
		loadTheme()
	end
	-- Set the settings to the variables
	CastTextColorByType = settings[Module.Name].CastTextColorByType
	castTransparency = settings[Module.Name].CastTransperancy or 1
	showTitleCasting = settings[Module.Name].ShowTitleCasting
	castLocked = settings[Module.Name].CastLocked
	enableCastBar = settings[Module.Name].EnableCastBar
	showTitle = settings[Module.Name].ShowTitleBar
	maxRow = settings[Module.Name].maxRow
	aSize = settings[Module.Name].AutoSize
	iconSize = settings[Module.Name].IconSize
	locked = settings[Module.Name].locked
	scale = settings[Module.Name].Scale
	themeName = settings[Module.Name].LoadTheme
	timerColor = settings[Module.Name].TimerColor
	if newSetting then mq.pickle(configFile, settings) end
end


local function CastDetect(line, spell)
	-- Module.Utils.PrintOutput(nil,"Memorized: ", spell)
	if not startedCast then
		startedCast = true
		startCastTime = os.time()
	end
end

local function InterruptSpell()
	casting = false
	interrupted = true
end

local function CheckCasting()
	if mq.TLO.Me.Casting() ~= nil then
		castBarShow = true

		casting = true
	else
		casting = false
		castBarShow = false
	end
end

function Module.RenderGUI()
	if not Module.IsRunning then return end

	if enableCastBar and (castBarShow or debugShow) then
		local castFlags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse, ImGuiWindowFlags.NoFocusOnAppearing)
		if castLocked then castFlags = bit32.bor(castFlags, ImGuiWindowFlags.NoMove) end
		if not showTitleCasting then castFlags = bit32.bor(castFlags, ImGuiWindowFlags.NoTitleBar) end
		local ColorCountCast, StyleCountCast = Module.ThemeLoader.StartTheme(themeName, Module.Theme, true, false, castTransparency or 1)
		ImGui.SetNextWindowSize(ImVec2(150, 55), ImGuiCond.FirstUseEver)
		ImGui.SetNextWindowPos(ImGui.GetMousePosVec(), ImGuiCond.FirstUseEver)

		local openCast, showCast = ImGui.Begin('Casting##MyCastingWin_' .. Module.CharLoaded, true, castFlags)
		if not openCast then
			castBarShow = false
		end
		if showCast or debugShow then
			local castingName = mq.TLO.Me.Casting.Name() or nil
			local castTime = mq.TLO.Spell(castingName).MyCastTime() or 0
			local spellID = mq.TLO.Spell(castingName).ID() or -1
			if castingName == nil then
				startCastTime = 0
				castBarShow = false
			end
			if (castingName ~= nil and startCastTime ~= 0) or debugShow then
				ImGui.BeginChild("##CastBar", ImVec2(-1, -1), bit32.bor(ImGuiChildFlags.None),
					bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse))
				local diff = os.time() - startCastTime
				local remaining = mq.TLO.Me.CastTimeLeft() <= castTime and mq.TLO.Me.CastTimeLeft() or 0
				-- if remaining < 0 then remaining = 0 end
				local colorHpMin = { 0.0, 1.0, 0.0, 1.0, }
				local colorHpMax = { 1.0, 0.0, 0.0, 1.0, }
				ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Utils.CalculateColor(colorHpMin, colorHpMax, (remaining / castTime * 100))))
				ImGui.ProgressBar(remaining / castTime, ImVec2(ImGui.GetWindowWidth(), 15), '')
				ImGui.PopStyleColor()
				local lbl = remaining > 0 and string.format("%.1f", (remaining / 1000)) or '0'
				local _, colorSetting = pickColorByType(spellID)
				if not CastTextColorByType then
					colorSetting = ImVec4(timerColor[1], timerColor[2], timerColor[3], timerColor[4])
				end
				ImGui.TextColored(colorSetting, "%s %ss", castingName, lbl)
				ImGui.EndChild()
			end
			if ImGui.BeginPopupContextItem("##MySpells_CastWin") then
				local lockLabel = castLocked and 'Unlock' or 'Lock'
				if ImGui.MenuItem(lockLabel .. "##Casting") then
					castLocked = not castLocked
					settings[Module.Name].CastLocked = castLocked
					mq.pickle(configFile, settings)
				end
				local titleBarLabel = showTitleCasting and 'Hide Title Bar' or 'Show Title Bar'
				if ImGui.MenuItem(titleBarLabel .. "##Casting") then
					showTitleCasting = not showTitleCasting
					settings[Module.Name].ShowTitleCasting = showTitleCasting
					mq.pickle(configFile, settings)
				end
				ImGui.EndPopup()
			end
		end
		Module.ThemeLoader.EndTheme(ColorCountCast, StyleCountCast)
		ImGui.End()
	end
end

function Module.Unload()
	mq.unevent("int_spell")
	mq.unevent("fiz_spell")
	mq.unevent("cast_start")
end

local function Init()
	if not mq.TLO.Plugin("MQ2Cast").IsLoaded() then mq.cmd("/plugin MQ2Cast") end

	if mq.TLO.Me.MaxMana() == 0 then
		Module.Utils.PrintOutput(nil, true, "You are not a caster!")
		Module.IsRunning = false
		return
	end
	loadSettings()
	if Module.Utils.File.Exists(themezDir) then
		hasThemeZ = true
	end
	mq.event("int_spell", "Your spell is interrupted.", InterruptSpell)
	mq.event("fiz_spell", "Your#*#spell fizzles#*#", InterruptSpell)
	mq.event('cast_start', "You begin casting #1#.#*#", CastDetect)
	Module.IsRunning = true
	if not loadedExeternally then
		mq.imgui.init('GUI_MySpells', Module.RenderGUI)
		Module.LocalLoop()
	end
end

function Module.MainLoop()
	if loadedExeternally then
		---@diagnostic disable-next-line: undefined-global
		if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
	end

	mq.doevents()

	if not picker.Draw then pickerOpen = false end
	CheckCasting()
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

Init()
return Module
