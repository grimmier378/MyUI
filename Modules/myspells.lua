--[[
	Title: MySpells
	Author: Grimmier
	Includes: AbilityPicker.lua
		By: Aquietone
		Many thanks to him for his work on this.
	Description: This script creates a spell bar that allows you to cast spells from your spell gems.
				It also allows you to memorize spells from the spell picker.
				Right Clicking on a spell gem will bring up a context menu to memorize, inspect, or clear the spell.
				Right Clicking on an Empty spell gem will bring up the spell picker to memorize a spell.
				Left Clicking on a spell gem will cast the spell.
				Spells that are on cooldown will have a cooldown overlay.
				Spells that are not ready to cast will have a faded gem overlay.
]]

local mq = require('mq')
local ImGui = require('ImGui')
local Module = {}
Module.IsRunning = false
Module.Name = "MySpells"
Module.TempSettings = {}

---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false

if not loadedExeternally then
	Module.Utils         = require('lib.common')
	Module.Icons         = require('mq.ICONS')
	Module.CharLoaded    = mq.TLO.Me.DisplayName()
	Module.Server        = mq.TLO.MacroQuest.Server()
	Module.AbilityPicker = require('lib.AbilityPicker')
	Module.ThemeLoader   = require('lib.theme_loader')
	Module.Path          = string.format("%s/%s/", mq.luaDir, Module.Name)
	Module.ThemeFile     = string.format('%s/MyUI/ThemeZ.lua', mq.configDir)
	Module.Colors        = require('lib.colors')
	Module.Theme         = {}
else
	Module.Utils = MyUI_Utils
	Module.Colors = MyUI_Colors
	Module.Icons = MyUI_Icons
	Module.CharLoaded = MyUI_CharLoaded
	Module.Server = MyUI_Server
	Module.AbilityPicker = MyUI_AbilityPicker
	Module.ThemeLoader = MyUI_ThemeLoader
	Module.Path = MyUI_Path
	Module.ThemeFile = MyUI_ThemeFile
	Module.Theme = MyUI_Theme
end

local Utils                                                                                          = Module.Utils
local ToggleFlags                                                                                    = bit32.bor(
	Utils.ImGuiToggleFlags.PulseOnHover,
	--Utils.ImGuiToggleFlags.SmilyKnob,
	--Utils.ImGuiToggleFlags.GlowOnHover,
	--Utils.ImGuiToggleFlags.KnobBorder,
	Utils.ImGuiToggleFlags.StarKnob,
	Utils.ImGuiToggleFlags.AnimateOnHover
--Utils.ImGuiToggleFlags.RightLabel
)

local isCaster                                                                                       = true
local picker                                                                                         = Module.AbilityPicker.new()
local pickerOpen                                                                                     = false
local bIcon                                                                                          = Module.Icons.FA_BOOK
local gIcon                                                                                          = Module.Icons.MD_SETTINGS
local defaults, settings, timerColor                                                                 = {}, {}, {}
local configFile                                                                                     = string.format('%s/myui/MySpells/%s/MySpells_%s.lua', mq.configDir,
	Module.Server, Module.CharLoaded)
local themezDir                                                                                      = mq.luaDir .. '/themez/init.lua'
local themeName                                                                                      = 'Default'
local casting                                                                                        = false
local spellBar                                                                                       = {}
local numGems                                                                                        = 8
local redGem                                                                                         = Module.Utils.SetImage(Module.Path .. '/images/red_gem.png')
local greenGem                                                                                       = Module.Utils.SetImage(Module.Path .. '/images/green_gem.png')
local purpleGem                                                                                      = Module.Utils.SetImage(Module.Path .. '/images/purple_gem.png')
local blueGem                                                                                        = Module.Utils.SetImage(Module.Path .. '/images/blue_gem.png')
local orangeGem                                                                                      = Module.Utils.SetImage(Module.Path .. '/images/orange_gem.png')
local yellowGem                                                                                      = Module.Utils.SetImage(Module.Path .. '/images/yellow_gem.png')
local openBook                                                                                       = Module.Utils.SetImage(Module.Path .. '/images/open_book.png')
local closedBook                                                                                     = Module.Utils.SetImage(Module.Path .. '/images/closed_book.png')
local memSpell                                                                                       = -1
local currentTime                                                                                    = os.time()
local maxRow, rowCount, iconSize, scale                                                              = 1, 0, 30, 1
local aSize, locked, castLocked, hasThemeZ, configWindowShow, loadSet, clearAll, CastTextColorByType = false, false, false, false, false, false, false, false
local setName                                                                                        = 'None'
local tmpName                                                                                        = ''
local showTitle, showTitleCasting                                                                    = true, false
local interrupted                                                                                    = false
local enableCastBar                                                                                  = false
local debugShow                                                                                      = false
local castTransparency                                                                               = 1.0
local startedCast, startCastTime, castBarShow                                                        = false, 0, false

defaults                                                                                             = {
	['MySpells'] = {
		['ShowTitleBar'] = true,
		['enableCastBar'] = true,
		['ShowGemNames'] = true,
		['maxRow'] = 1,
		['locked'] = false,
		['CastLocked'] = false,
		['CastTransperancy'] = 1,
		['ShowTitleCasting'] = false,
		['IconSize'] = 30,
		['CastTextColorByType'] = false,
		['TimerColor'] = {
			[1] = 0.2503088712692261,
			[2] = 0.8347724080085754,
			[3] = 0.9431279897689819,
			[4] = 1,
		},
		['LoadTheme'] = 'Default',
		['AutoSize'] = true,
		[Module.CharLoaded] = {
			['Sets'] = {},
		},
		['EnableCastBar'] = true,
		['Scale'] = 1,
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
	else
		settings = dofile(configFile)
	end

	-- check for new settings and add them to the settings file
	for key, val in pairs(defaults[Module.Name]) do
		if type(val) ~= 'table' then
			if settings[Module.Name][key] == nil then
				settings[Module.Name][key] = val
				newSetting = true
			end
		end
	end
	-- newSetting = Module.Utils.CheckRemovedSettings(defaults[Module.Name], settings[Module.Name]) or newSetting
	if settings[Module.Name] == nil then
		settings[Module.Name] = defaults[Module.Name]
		newSetting = true
	end
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

local function MemSpell(line, spell)
	-- Module.Utils.PrintOutput(nil,"Memorized: ", spell)
	for i = 1, numGems do
		if spellBar[i].sName == spell then
			mq.delay(1)
			break
		end
	end
end

local function CastDetect(line, spell)
	-- Module.Utils.PrintOutput(nil,"Memorized: ", spell)
	if not startedCast then
		startedCast = true
		startCastTime = os.time()
		Module.TempSettings.CastingTime = mq.TLO.Me.CastTimeLeft() or 0
	end
end

local function InterruptSpell()
	casting = false
	interrupted = true
	Module.TempSettings.CastingTime = nil
end

local function CheckCasting()
	if mq.TLO.Me.Casting() ~= nil then
		castBarShow = true
		for i = 1, numGems do
			if spellBar[i].sName == mq.TLO.Me.CastTimeLeft() then
				casting = true
				break
			end
		end
	else
		casting = false
		castBarShow = false
		startedCast = false
		startCastTime = 0
	end
end

local function GetSpells(slot)
	local bonusGems = mq.TLO.Me.AltAbility('Mnemonic Retention').Rank() or 0
	numGems = 8 + bonusGems

	local function GetInfo(slotNum)
		local sToolTip = mq.TLO.Window(string.format('CastSpellWnd/CSPW_Spell%s', slotNum - 1)).Tooltip()
		local sName
		local sRecast
		local sID, sIcon, sFizzle
		local sCastTime
		local sDescription = 'No description available'
		if spellBar[slotNum] == nil then
			spellBar[slotNum] = {}
		end

		if sToolTip:find("%)%s") then
			sName = mq.TLO.Me.Gem(slotNum).Name()
			sID = mq.TLO.Spell(sName).ID() or -1
			---@diagnostic disable-next-line: undefined-field
			sRecast = mq.TLO.Spell(sName).RecastTime.TotalSeconds() or -1
			sIcon = mq.TLO.Spell(sName).SpellIcon() or -1
			sCastTime = mq.TLO.Spell(sName).MyCastTime.Seconds() or -1
			sFizzle = mq.TLO.Spell(sName).FizzleTime() or -1
			sDescription = mq.TLO.Spell(sName).Description() or 'No description available'
		else
			sName = "Empty"
			sID = -1
			sIcon = -1
			sRecast = -1
			sCastTime = -1
			sFizzle = -1
			sDescription = 'No description available'
		end

		spellBar[slotNum].sCastTime = sCastTime
		spellBar[slotNum].sName = sName
		spellBar[slotNum].sID = sID
		spellBar[slotNum].sIcon = sIcon
		spellBar[slotNum].sFizzle = sFizzle
		spellBar[slotNum].sRecast = sRecast
		spellBar[slotNum].Description = sDescription
	end

	if slot == nil then
		for i = 1, numGems do
			GetInfo(i)
		end
	else
		GetInfo(slot)
	end
end

--- comments
---@param iconID integer
---@param spell table
---@param i integer
local function DrawInspectableSpellIcon(iconID, spell, i)
	CheckCasting()
	local cursor_x, cursor_y = ImGui.GetCursorPos()
	local gem = mq.FindTextureAnimation('A_SpellGemHolder')

	-- draw gem holder
	ImGui.SetCursorPos(cursor_x - 1, cursor_y)
	ImGui.DrawTextureAnimation(gem, scale * (iconSize + 12), scale * (iconSize + 2))

	ImGui.SetCursorPos(cursor_x, cursor_y)
	if iconID == -1 then
		-- no spell in this slot
		return
	end

	-- draw spell icon
	Module.Utils.Animation_Spell:SetTextureCell(iconID or 0)
	ImGui.SetCursorPos(cursor_x + (scale * 8), cursor_y + (5 * scale))
	ImGui.DrawTextureAnimation(Module.Utils.Animation_Spell, scale * (iconSize - 4), scale * (iconSize - 5))

	----------- overlay ----------------
	ImGui.SetCursorPos(cursor_x, cursor_y - 2)
	local OverlayColor = IM_COL32(0, 0, 0, 0.9 * 255)
	local startPos = ImGui.GetCursorScreenPosVec()
	local endPos
	local recast = spell.sRecast -- + spell.sCastTime
	local gemTimer = (mq.TLO.Me.GemTimer(i)() or 0) / 1000

	local percent = (recast - gemTimer) / recast

	if gemTimer > 0 or mq.TLO.Me.Casting() ~= nil then
		-- spell is not ready to cast
		ImGui.SetCursorPos(cursor_x + (scale * 8), cursor_y + (5 * scale))
		-- spell was cast and is on cooldown
		if percent < 0 then percent = 0 end -- Ensure percent is not negative
		startPos = ImGui.GetCursorScreenPosVec()
		local oStart = startPos
		-- timer background overlay
		OverlayColor = IM_COL32(2, 2, 2, 88)
		local adjustedHeight = (scale * (iconSize - 5))
		endPos = ImVec2(startPos.x + ((iconSize) * scale), startPos.y + ((iconSize - 5) * scale))
		startPos = ImVec2(startPos.x, endPos.y - adjustedHeight)
		ImGui.GetWindowDrawList():AddRectFilled(startPos, endPos, OverlayColor)
		startPos = oStart

		-- adjust the height of the overlay based on the remaining time
		OverlayColor = IM_COL32(41, 2, 2, 190)
		adjustedHeight = (scale * (iconSize - 5)) * percent
		endPos = ImVec2(startPos.x + ((iconSize) * scale), startPos.y + ((iconSize - 5) * scale))
		startPos = ImVec2(startPos.x, endPos.y - adjustedHeight)
		-- draw the overlay
		ImGui.GetWindowDrawList():AddRectFilled(startPos, endPos, OverlayColor)
		-- set the cursor for timer display
		ImGui.SetCursorPos(cursor_x + (scale * (iconSize / 2)), cursor_y + (scale * (iconSize / 2)))
		-- print the remaining time
		if gemTimer > 0 then
			ImGui.TextColored(ImVec4(timerColor[1], timerColor[2], timerColor[3], timerColor[4]), "%d", gemTimer)
		end
		-- draw the gem Color overlay faded out to show the spell is not ready
		ImGui.SetCursorPos(cursor_x, cursor_y + 1)
		ImGui.Image(pickColorByType(spell.sID):GetTextureID(),
			ImVec2(scale * (iconSize + 37), scale * (iconSize + 2)))
		ImGui.SetCursorPos(cursor_x, cursor_y + 1)
		ImGui.Image(pickColorByType(spell.sID):GetTextureID(),
			ImVec2(scale * (iconSize + 37), scale * (iconSize + 2)), ImVec2(0, 0), ImVec2(1, 1), ImVec4(0, 0, 0, 0.85))
	else
		-- draw the gem Color overlay
		ImGui.SetCursorPos(cursor_x, cursor_y + 1)
		ImGui.Image(pickColorByType(spell.sID):GetTextureID(),
			ImVec2(scale * (iconSize + 37), scale * (iconSize + 2)))
	end

	local sName = spell.sName or '??'
	ImGui.PushID(tostring(iconID) .. sName .. "_invis_btn")
	ImGui.SetCursorPos(cursor_x, cursor_y)
	ImGui.InvisibleButton(sName, ImVec2(scale * iconSize, scale * iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
	ImGui.PopID()
end

local function SaveSet(SetName)
	if settings[Module.Name][Module.CharLoaded].Sets[SetName] == nil then
		settings[Module.Name][Module.CharLoaded].Sets[SetName] = {}
	end
	settings[Module.Name][Module.CharLoaded].Sets[SetName] = spellBar
	mq.pickle(configFile, settings)
	settings = dofile(configFile)
	tmpName = ''
end

local function LoadSet(set)
	loadSet      = false
	local setBar = {}
	for i, t in pairs(settings[Module.Name][Module.CharLoaded].Sets[set]) do
		setBar[i] = {}
		for k, v in pairs(t) do
			setBar[i][k] = v
		end
	end
	mq.TLO.Window('SpellBookWnd').DoOpen()
	mq.delay(5, function() return mq.TLO.Window('SpellBookWnd').Open() end)
	for i = 1, numGems or 8 do
		GetSpells(i)
		if setBar[i] ~= nil then
			if setBar[i].sName ~= nil then
				if mq.TLO.Me.Gem(i).Name() ~= setBar[i].sName then
					if setBar[i].sName ~= "Empty" then
						mq.cmdf("/memspell %d \"%s\"", i, setBar[i].sName)
					end

					while mq.TLO.Me.Gem(i).Name() ~= setBar[i].sName do
						if not mq.TLO.Window('SpellBookWnd').Open() then
							spellBar[i].sName = 'Empty'
							spellBar[i].sID = -1
							spellBar[i].sIcon = -1
							spellBar[i].sRecast = -1
							spellBar[i].sCastTime = -1
							GetSpells(i)
							setName = 'None'
							return
						end
					end
					spellBar[i] = setBar[i]
				end
			end
		end
	end
	mq.TLO.Window('SpellBookWnd').DoClose()
	mq.delay(1)
	setName = 'None'
end

local function ClearGems()
	for i = 1, numGems do
		mq.cmdf("/nomodkey /altkey /notify CastSpellWnd CSPW_Spell%s rightmouseup", i - 1)
		mq.delay(5000, function() return mq.TLO.Me.Gem(i)() == nil end)
		spellBar[i].sName = 'Empty'
		spellBar[i].sID = -1
		spellBar[i].sIcon = -1
		spellBar[i].sRecast = -1
		spellBar[i].sCastTime = -1
	end
	GetSpells()
	clearAll = false
end

local function DrawConfigWin()
	if not configWindowShow then return end
	local ColorCountTheme, StyleCountTheme = Module.ThemeLoader.StartTheme(themeName, Module.Theme)
	local openTheme, showTheme = ImGui.Begin('Config##MySpells_', true,
		bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoFocusOnAppearing))
	if not openTheme then
		configWindowShow = false
	end
	if not showTheme then
		Module.ThemeLoader.EndTheme(ColorCountTheme, StyleCountTheme)
		ImGui.End()
		return
	end
	ImGui.SeparatorText("Theme##MySpells")
	ImGui.Text("Cur Theme: %s", themeName)
	-- Combo Box Load Theme
	if ImGui.BeginCombo("Load Theme##MySpells", themeName) then
		for k, data in pairs(Module.Theme.Theme) do
			local isSelected = data.Name == themeName
			if ImGui.Selectable(data.Name, isSelected) then
				if data.Name ~= settings[Module.Name].LoadTheme then
					themeName = data.Name
					settings[Module.Name].LoadTheme = themeName
					mq.pickle(configFile, settings)
				end
			end
		end
		ImGui.EndCombo()
	end

	scale = ImGui.SliderFloat("Scale##DialogDB", scale, 0.5, 2)
	if scale ~= settings[Module.Name].Scale then
		if scale < 0.5 then scale = 0.5 end
		if scale > 2 then scale = 2 end
	end

	if hasThemeZ or loadedExeternally then
		if ImGui.Button('Edit ThemeZ') then
			if not loadedExeternally then
				mq.cmd("/lua run themez")
			else
				if MyUI_Modules.ThemeZ ~= nil then
					if MyUI_Modules.ThemeZ.IsRunning then
						MyUI_Modules.ThemeZ.ShowGui = true
					else
						MyUI_TempSettings.ModuleChanged = true
						MyUI_TempSettings.ModuleName = 'ThemeZ'
						MyUI_TempSettings.ModuleEnabled = true
					end
				else
					MyUI_TempSettings.ModuleChanged = true
					MyUI_TempSettings.ModuleName = 'ThemeZ'
					MyUI_TempSettings.ModuleEnabled = true
				end
			end
		end
		ImGui.SameLine()
	end

	if ImGui.Button('Reload Theme File') then
		loadTheme()
	end

	ImGui.SeparatorText("General Settings##MySpells")
	-- if mq.TLO.Me.Class.ShortName() ~= 'BRD' then
	castTransparency = ImGui.SliderFloat("Cast Bar Transparency##MySpells", castTransparency, 0.0, 1.0)
	enableCastBar = Module.Utils.DrawToggle("Enable Cast Bar##MySpells", enableCastBar, ToggleFlags)
	if enableCastBar then
		ImGui.SameLine()
		debugShow = Module.Utils.DrawToggle("Force Show CastBar##MySpells", debugShow, ToggleFlags)
		CastTextColorByType = Module.Utils.DrawToggle("Cast Text Color By Type##MySpells", CastTextColorByType, ToggleFlags)
		ImGui.SameLine()
		ImGui.HelpMarker("This will change the color of the cast bar text based on the spell type.")
	end

	settings[Module.Name].ShowGemNames = Module.Utils.DrawToggle("Show Gem Names##MySpells", settings[Module.Name].ShowGemNames, ToggleFlags)
	ImGui.SameLine()
	ImGui.HelpMarker("This will show the spell name on the spell gem.\nThis is useful for identifying spells in the spell bar.")

	-- end
	timerColor, _ = ImGui.ColorEdit4("Timer Color##MySpells", timerColor, ImGuiColorEditFlags.AlphaBar)
	ImGui.SameLine()
	ImGui.HelpMarker("This will change the color of the timer text on the spell gems.\nThis is also the Text Default color for the Cast Bar.")
	if ImGui.Button("Save & Close") then
		settings[Module.Name].CastTextColorByType = CastTextColorByType
		settings[Module.Name].CastTransperancy = castTransparency
		settings[Module.Name].EnableCastBar = enableCastBar
		settings[Module.Name].Scale = scale
		settings[Module.Name].TimerColor = timerColor
		settings[Module.Name].LoadTheme = themeName
		mq.pickle(configFile, settings)
		configWindowShow = false
	end
	Module.ThemeLoader.EndTheme(ColorCountTheme, StyleCountTheme)
	ImGui.End()
end

function Module.RenderToolTipAndContext(i)
	if mq.TLO.EverQuest.GameState() ~= "INGAME" then mq.exit() end

	if ImGui.IsItemHovered() then
		ImGui.BeginTooltip()
		ImGui.Indent(4)
		local colorName = Module.Colors.color('white')
		local manaCost = mq.TLO.Spell(spellBar[i].sID).Mana() or 0
		local curMana = mq.TLO.Me.CurrentMana() or 0
		if curMana < manaCost * 1.1 then
			colorName = Module.Colors.color('pink2')
		end
		ImGui.TextColored(colorName, "%s", spellBar[i].sName)
		ImGui.Separator()
		ImGui.TextColored(colorName, "Mana: %d", manaCost)
		ImGui.SameLine(0.0, 2)
		ImGui.TextColored(Module.Colors.color('white'), "/")
		ImGui.SameLine(0.0, 2)
		ImGui.TextColored(Module.Colors.color('teal'), "%d", curMana)
		ImGui.TextColored(Module.Colors.color('white'), "Recast: %d", spellBar[i].sRecast)
		ImGui.TextColored(Module.Colors.color('tangerine'), "Cast Time: %d", spellBar[i].sCastTime)
		ImGui.Separator()
		ImGui.PushTextWrapPos(150)
		ImGui.Text(spellBar[i].Description or 'No description available')
		ImGui.PopTextWrapPos()
		ImGui.Separator()

		ImGui.Unindent(4)

		ImGui.EndTooltip()

		if ImGui.IsMouseReleased(0) then
			mq.cmdf("/cast %s", i)
			casting = true
		elseif ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsMouseReleased(1) then
			mq.cmdf("/nomodkey /altkey /notify CastSpellWnd CSPW_Spell%s rightmouseup", i - 1)
		end
	end
	if ImGui.BeginPopupContextItem("##SpellGem" .. i) then
		if ImGui.IsKeyDown(ImGuiMod.Ctrl) then ImGui.CloseCurrentPopup() end
		if ImGui.MenuItem("Memorize") then
			if pickerOpen == true then
				memSpell = -1
				picker:SetClose()
				pickerOpen = false
				picker:ClearSelection()
			end
			memSpell = i
		end
		if ImGui.MenuItem("Inspect") then
			mq.cmdf("/altkey /notify CastSpellWnd CSPW_Spell%s leftmouseup", i - 1)
		end
		if ImGui.MenuItem("Clear") then
			mq.cmdf("/nomodkey /altkey /notify CastSpellWnd CSPW_Spell%s rightmouseup", i - 1)
		end
		ImGui.EndPopup()
	end
end

function Module.RenderGUI()
	if not Module.IsRunning then return end
	local winFlags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoFocusOnAppearing)
	if not aSize then winFlags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse) end
	if locked then winFlags = bit32.bor(winFlags, ImGuiWindowFlags.NoMove) end
	if not showTitle then winFlags = bit32.bor(winFlags, ImGuiWindowFlags.NoTitleBar) end
	if isCaster then
		local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(themeName, Module.Theme)
		local open, show = ImGui.Begin(bIcon .. '##MySpells_' .. Module.CharLoaded, true, winFlags)
		if not open then
			Module.IsRunning = false
		end
		if show then
			-- Calculate maxRow to account for window padding and element size
			local windowWidth = ImGui.GetWindowWidth() or 100
			maxRow = math.floor(windowWidth / (scale * 44))
			if aSize then
				maxRow = settings[Module.Name].maxRow
			end
			currentTime = os.time()
			rowCount = 0

			if ImGui.BeginPopupContextItem("##MySpells_theme") then
				if ImGui.MenuItem("Configure") then
					configWindowShow = not configWindowShow
				end
				local aLabel = aSize and 'Disable Auto Size' or 'Enable Auto Size'
				if ImGui.MenuItem(aLabel) then
					aSize = not aSize
					if aSize then
						settings[Module.Name].maxRow = maxRow
					end
					settings[Module.Name].AutoSize = aSize
					mq.pickle(configFile, settings)
				end
				local lockLabel = locked and 'Unlock' or 'Lock'
				if ImGui.MenuItem(lockLabel) then
					locked = not locked
					settings[Module.Name].locked = locked
					mq.pickle(configFile, settings)
				end
				local titleBarLabel = showTitle and 'Hide Title Bar' or 'Show Title Bar'
				if ImGui.MenuItem(titleBarLabel) then
					showTitle = not showTitle
					settings[Module.Name].ShowTitleBar = showTitle
					mq.pickle(configFile, settings)
				end
				ImGui.EndPopup()
			end
			local colCount = 2
			if not settings[Module.Name].ShowGemNames then
				colCount = maxRow
			end

			if ImGui.BeginTable("##SpellGems", colCount) then
				if colCount == 2 and settings[Module.Name].ShowGemNames then
					ImGui.TableSetupColumn("##Gem", ImGuiTableColumnFlags.WidthFixed, (settings[Module.Name].IconSize * scale) + 5)
					ImGui.TableSetupColumn("##Name", ImGuiTableColumnFlags.WidthStretch, 100)
				else
					for i = 1, colCount do
						ImGui.TableSetupColumn("##Gem" .. i, ImGuiTableColumnFlags.WidthFixed, (settings[Module.Name].IconSize * scale) + 5)
					end
				end
				ImGui.TableNextRow()
				ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 0)
				for i = 1, numGems do
					ImGui.TableNextColumn()
					if spellBar[i] ~= nil then
						ImGui.PushID(tostring(spellBar[i].sID) .. "_spell")

						ImGui.BeginChild("##SpellGem" .. i, ImVec2(scale * 40, scale * 33), bit32.bor(ImGuiChildFlags.AlwaysUseWindowPadding),
							bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse))


						if spellBar[i].sID > -1 then
							DrawInspectableSpellIcon(spellBar[i].sIcon, spellBar[i], i)
						else
							DrawInspectableSpellIcon(-1, spellBar[i], i)
							if ImGui.IsItemHovered() then
								ImGui.SetTooltip("Empty")
								if ImGui.IsMouseReleased(1) then
									if pickerOpen == true then
										memSpell = -1
										picker:SetClose()
										pickerOpen = false
										picker:ClearSelection()
									end
									memSpell = i
								end
							end
						end
						ImGui.EndChild()
						Module.RenderToolTipAndContext(i)
						ImGui.PopID()
						if settings[Module.Name].ShowGemNames then
							ImGui.TableNextColumn()
							ImGui.Indent(3)
							picker:SetTextColor({
								ID = spellBar[i].sID,
								Name = spellBar[i].sName,
								Category = mq.TLO.Spell(spellBar[i].sID).Category() or 'Unknown',
								AERange = mq.TLO.Spell(spellBar[i].sID).AERange() or 0,
								TargetType = mq.TLO.Spell(spellBar[i].sID).TargetType() or 'Unknown',
								Icon = spellBar[i].sIcon,
								PushBack = mq.TLO.Spell(spellBar[i].sID).PushBack() or 0,
							})
							ImGui.Selectable(string.format("%s\nCost (%s)", spellBar[i].sName, mq.TLO.Spell(spellBar[i].sID).Mana() or 0),
								false, ImGuiSelectableFlags.SpanAllColumns)
							ImGui.PopStyleColor()
							Module.RenderToolTipAndContext(i)
							ImGui.Unindent(3)
						end
					end

					-- rowCount = rowCount + 1

					-- if rowCount < maxRow then
					-- 	ImGui.SameLine()
					-- else
					-- 	rowCount = 0
					-- end
				end
				ImGui.PopStyleVar()
				ImGui.EndTable()
			end
			if memSpell ~= -1 and not picker.Draw then -- and not pickerOpen then
				-- ImGui.SetNextWindowPos(ImGui.GetMousePosOnOpeningCurrentPopupVec(), ImGuiCond.Appearing)
				picker:SetOpen()
				pickerOpen = true
			end

			if picker.Selected then
				local selected = picker.Selected or {}
				if selected.Type == 'Spell' then
					mq.cmdf("/memspell %d \"%s\"", memSpell, selected.Name)
					memSpell = -1
					picker:SetClose()
					pickerOpen = false
					picker:ClearSelection()
				end
			end
			picker:DrawAbilityPicker()

			ImGui.SetCursorPosX(ImGui.GetContentRegionAvail() * 0.5 - 5)

			if ImGui.BeginChild("##SpellBook", ImVec2(40 * scale, scale * 40), bit32.bor(ImGuiChildFlags.AlwaysUseWindowPadding),
					bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse)) then
				local cursor_x, cursor_y = ImGui.GetCursorPos()
				if mq.TLO.Window('SpellBookWnd').Open() then
					-- ImGui.SetCursorPos(cursor_x, cursor_y)
					ImGui.Image(openBook:GetTextureID(), ImVec2(scale * 60, scale * 35))
					if ImGui.IsItemHovered() then
						ImGui.SetTooltip("Close Spell Book")
						if ImGui.IsMouseReleased(0) then
							mq.TLO.Window('SpellBookWnd').DoClose()
						end
					end
				else
					-- ImGui.SetCursorPos(cursor_x, cursor_y)
					ImGui.Image(closedBook:GetTextureID(), ImVec2(60 * scale, scale * 35))
					if ImGui.IsItemHovered() then
						ImGui.SetTooltip("Open Spell Book")
						if ImGui.IsMouseReleased(0) then
							mq.TLO.Window('SpellBookWnd').DoOpen()
						end
					end
				end

				if ImGui.BeginPopupContextWindow("##SpellBook") then
					ImGui.Text(gIcon)
					if ImGui.IsItemHovered() then
						ImGui.SetTooltip("Config")
						if ImGui.IsMouseReleased(0) then
							configWindowShow = not configWindowShow
							ImGui.CloseCurrentPopup()
						end
					end
					ImGui.SameLine()
					local rIcon = aSize and Module.Icons.FA_EXPAND or Module.Icons.FA_COMPRESS
					ImGui.Text(rIcon)
					if ImGui.IsItemHovered() then
						local label = aSize and "Disable Auto Size" or "Enable Auto Size"
						ImGui.SetTooltip(label)
						if ImGui.IsMouseReleased(0) then
							aSize = not aSize

							if aSize then
								settings[Module.Name].maxRow = maxRow
							end
							settings[Module.Name].AutoSize = aSize
							mq.pickle(configFile, settings)
							ImGui.CloseCurrentPopup()
						end
					end
					ImGui.SameLine()
					local lIcon = locked and Module.Icons.FA_LOCK or Module.Icons.FA_UNLOCK
					ImGui.Text(lIcon)
					if ImGui.IsItemHovered() then
						local label = locked and "Unlock" or "Lock"
						ImGui.SetTooltip(label)
						if ImGui.IsMouseReleased(0) then
							locked = not locked

							settings[Module.Name].locked = locked
							mq.pickle(configFile, settings)
							ImGui.CloseCurrentPopup()
						end
					end
					ImGui.SameLine()
					local tIcon = showTitle and Module.Icons.FA_EYE_SLASH or Module.Icons.FA_EYE
					ImGui.Text(tIcon)
					if ImGui.IsItemHovered() then
						local label = showTitle and "Hide Title Bar" or "Show Title Bar"
						ImGui.SetTooltip(label)
						if ImGui.IsMouseReleased(0) then
							showTitle = not showTitle
							settings[Module.Name].ShowTitleBar = showTitle
							mq.pickle(configFile, settings)
							ImGui.CloseCurrentPopup()
						end
					end
					ImGui.SeparatorText("Save Set")
					ImGui.SetNextItemWidth(150)
					tmpName = ImGui.InputText("##SetName", tmpName)
					ImGui.SameLine()
					if ImGui.Button("Save Set") then
						if tmpName ~= '' then
							setName = tmpName
							SaveSet(setName)
							ImGui.CloseCurrentPopup()
						end
					end
					ImGui.SeparatorText("Load Set")
					ImGui.SetNextItemWidth(150)
					if ImGui.BeginCombo("##LoadSet", setName) then
						for k, data in pairs(settings[Module.Name][Module.CharLoaded].Sets) do
							local isSelected = k == setName
							if ImGui.Selectable(k, isSelected) then
								setName = k
							end
						end
						ImGui.EndCombo()
					end
					ImGui.SameLine()
					if ImGui.Button("Load Set") then
						if setName ~= 'None' then
							loadSet = true
						end
						ImGui.CloseCurrentPopup()
					end

					if setName ~= 'None' then
						if ImGui.Button("Delete Set") then
							settings[Module.Name][Module.CharLoaded].Sets[setName] = nil
							mq.pickle(configFile, settings)
							setName = 'None'
							tmpName = ''
							ImGui.CloseCurrentPopup()
						end
						ImGui.SameLine()
					end

					if ImGui.Button("Clear Gems") then
						clearAll = true
						ImGui.CloseCurrentPopup()
					end

					ImGui.EndPopup()
				end

				ImGui.SetWindowFontScale(1)
			end
			ImGui.EndChild()
		end
		Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
		ImGui.End()
	end

	if configWindowShow then
		DrawConfigWin()
	end

	if enableCastBar and (castBarShow or debugShow) then
		local castFlags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse, ImGuiWindowFlags.NoFocusOnAppearing)
		if castLocked then castFlags = bit32.bor(castFlags, ImGuiWindowFlags.NoMove) end
		if not showTitleCasting then castFlags = bit32.bor(castFlags, ImGuiWindowFlags.NoTitleBar) end
		local castingName = mq.TLO.Me.Casting.Name() or nil
		local castTime = Module.TempSettings.CastingTime or 0
		local timeLeft = mq.TLO.Me.CastTimeLeft() or 0
		local spellID = mq.TLO.Spell(castingName).ID() or -1
		if timeLeft > 4000000000 then
			castTime = 0
			return
		end
		if castingName == nil then
			startCastTime = 0
			castBarShow = false
			return
		end
		if not castBarShow then return end
		ImGui.SetNextWindowSize(ImVec2(150, 55), ImGuiCond.FirstUseEver)
		ImGui.SetNextWindowPos(ImGui.GetMousePosVec(), ImGuiCond.FirstUseEver)
		local ColorCountCast, StyleCountCast = Module.ThemeLoader.StartTheme(themeName, Module.Theme, true, false, castTransparency or 1)

		local openCast, showCast = ImGui.Begin('Casting##MyCastingWin_' .. Module.CharLoaded, true, castFlags)
		if not openCast then
			castBarShow = false
		end
		if showCast or debugShow then
			if castBarShow or debugShow then
				ImGui.BeginChild("##CastBar", ImVec2(-1, -1), bit32.bor(ImGuiChildFlags.None),
					bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse))
				local diff = os.time() - startCastTime
				local remaining = mq.TLO.Me.CastTimeLeft() --<= castTime and mq.TLO.Me.CastTimeLeft() or 0
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
	mq.unevent("mem_spell")
	mq.unevent("int_spell")
	mq.unevent("fiz_spell")
	mq.unevent("cast_start")
	mq.unbind("/myspells")
end

function Module.CommandHandler(...)
	local args = { ..., }
	if args[1] == 'config' then
		configWindowShow = not configWindowShow
	end
end

local function Init()
	-- if not mq.TLO.Plugin("MQ2Cast").IsLoaded() then mq.cmd("/plugin MQ2Cast") end

	if mq.TLO.Me.MaxMana() == 0 then
		isCaster = false
		Module.Utils.PrintOutput(nil, true, "You are not a caster!")
	end
	loadSettings()
	if Module.Utils.File.Exists(themezDir) then
		hasThemeZ = true
	end
	picker:InitializeAbilities({ 'spell', })
	mq.event("mem_spell", "You have finished memorizing #1#.#*#", MemSpell)
	mq.event("int_spell", "Your spell is interrupted.", InterruptSpell)
	mq.event("fiz_spell", "Your#*#spell fizzles#*#", InterruptSpell)
	mq.event('cast_start', "You begin casting #1#.#*#", CastDetect)
	GetSpells()
	Module.IsRunning = true
	if not loadedExeternally then
		mq.imgui.init('GUI_MySpells', Module.RenderGUI)
		Module.LocalLoop()
	end
	mq.bind("/myspells", Module.CommandHandler)
end

function Module.MainLoop()
	if loadedExeternally then
		---@diagnostic disable-next-line: undefined-global
		if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
	end
	if mq.TLO.EverQuest.GameState() ~= "INGAME" then mq.exit() end
	mq.doevents()

	if loadSet then LoadSet(setName) end
	if clearAll then ClearGems() end
	if not picker.Draw then pickerOpen = false end
	CheckCasting()

	picker:Reload()
	GetSpells()
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
