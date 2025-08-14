--[[
	Title: Generic Script Template
	Author: Grimmier
	Includes:
	Description: Generic Script Template with ThemeZ Suppport
]]

-- Load Libraries
local mq = require('mq')
local ImGui = require('ImGui')
local Module = {}
Module.IsRunning = true
Module.TempSettings = {}
Module.Name = 'MyPet'
---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false

if not loadedExeternally then
	Module.Utils       = require('lib.common')
	Module.Colors      = require('lib.colors')
	Module.Icons       = require('mq.ICONS')
	Module.ThemeLoader = require('lib.theme_loader')
	Module.CharLoaded  = mq.TLO.Me.DisplayName()
	Module.Server      = mq.TLO.MacroQuest.Server()
	Module.Theme       = {}
	Module.ThemeFile   = string.format('%s/MyUI/ThemeZ.lua', mq.configDir)
else
	Module.Utils = MyUI_Utils
	Module.Colors = MyUI_Colors
	Module.Icons = MyUI_Icons
	Module.CharLoaded = MyUI_CharLoaded
	Module.Server = MyUI_Server
	Module.Theme = MyUI_Theme
	Module.ThemeFile = MyUI_ThemeFile
	Module.ThemeLoader = MyUI_ThemeLoader
end
Module.TempSettings                                                               = {}
Module.ButtonLabels                                                               = {}
local Utils                                                                       = Module.Utils
local ToggleFlags                                                                 = bit32.bor(
	Utils.ImGuiToggleFlags.PulseOnHover,
	--Utils.ImGuiToggleFlags.SmilyKnob,
	--Utils.ImGuiToggleFlags.GlowOnHover,
	Utils.ImGuiToggleFlags.KnobBorder,
	--Utils.ImGuiToggleFlags.StarKnob,
	Utils.ImGuiToggleFlags.AnimateOnHover
--Utils.ImGuiToggleFlags.RightLabel
)
-- Variables
local themeName                                                                   = 'Default'
local defaults, settings, btnInfo                                                 = {}, {}, {}
local showMainGUI, showConfigGUI                                                  = true, false
local scale                                                                       = 1
local locked, hasThemeZ                                                           = false, false
local petHP, petTarg, petDist, petBuffs, petName, petTargHP, petLvl, petBuffCount = 0, nil, 0, {}, 'NO PET', 0, -1, 0
local lastCheck                                                                   = 0
local myPet                                                                       = mq.TLO.Pet
local btnKeys                                                                     = {
	"Attack",
	"Back",
	"Taunt",
	"Follow",
	"Guard",
	"Focus",
	"Sit",
	"Hold",
	"Stop",
	"Bye",
	"Regroup",
	"Report",
	"Swarm",
	"Kill",
	"qAttack",
	"gHold",
}
btnInfo                                                                           = {
	attack = false,
	back = false,
	taunt = false,
	follow = false,
	guard = false,
	focus = false,
	sit = false,
	hold = false,
	stop = false,
	bye = false,
	regroup = false,
	report = false,
	swarm = false,
	kill = false,
	qattack = false,
	ghold = false,
}
-- GUI Settings
local winFlags                                                                    = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoFocusOnAppearing)
local animSpell                                                                   = mq.FindTextureAnimation('A_SpellIcons')
local iconSize                                                                    = 20
local autoHide                                                                    = false
local showTitleBar                                                                = true

-- File Paths
local configFileOld                                                               = string.format('%s/MyUI/%s/%s_Configs.lua', mq.configDir, Module.Name, Module.Name)
local configFile                                                                  = string.format('%s/MyUI/%s/%s/%s.lua', mq.configDir, Module.Name, Module.Server, Module
	.CharLoaded)
local themezDir                                                                   = mq.luaDir .. '/themez/init.lua'

-- Default Settings
defaults                                                                          = {
	Scale = 1.0,
	LoadTheme = 'Default',
	AutoHide = false,
	locked = false,
	ShowTitlebar = true,
	AutoSize = false,
	ButtonsRow = 2,
	IconSize = 20,
	Buttons = {
		Attack = { show = true, cmd = "/pet attack", },
		Back = { show = true, cmd = "/pet back off", },
		Taunt = { show = true, cmd = "/pet taunt", },
		Follow = { show = true, cmd = "/pet follow", },
		Guard = { show = true, cmd = "/pet guard", },
		Focus = { show = false, cmd = "/pet focus", },
		Sit = { show = true, cmd = "/pet sit", },
		Hold = { show = false, cmd = "/pet hold", },
		gHold = { show = false, cmd = "/pet ghold", },
		Stop = { show = false, cmd = "/pet stop", },
		Bye = { show = true, cmd = "/pet get lost", },
		Regroup = { show = false, cmd = "/pet regroup", },
		Report = { show = true, cmd = "/pet report health", },
		Swarm = { show = false, cmd = "/pet swarm", },
		Kill = { show = false, cmd = "/pet kill", },
		qAttack = { show = true, cmd = "/pet qattack", },

	},
	ConColors = {
		['RED'] = { 0.9, 0.4, 0.4, 0.8, },
		['YELLOW'] = { 1, 1, 0, 1, },
		['WHITE'] = { 1, 1, 1, 1, },
		['BLUE'] = { 0.2, 0.2, 1, 1, },
		['LIGHT BLUE'] = { 0, 1, 1, 1, },
		['GREEN'] = { 0, 1, 0, 1, },
		['GREY'] = { 0.6, 0.6, 0.6, 1, },
	},
	ColorHPMax = { 1.0, 0.0, 0.0, 1, },
	ColorHPMin = { 0.2, 0.2, 1.0, 1, },
	ColorTargMax = { 1.0, 0.0, 0.0, 1, },
	ColorTargMin = { 0.2, 0.2, 1.0, 1, },
}

local function loadTheme()
	-- Check for the Theme File
	if Module.Utils.File.Exists(Module.ThemeFile) then
		Module.Theme = dofile(Module.ThemeFile)
	else
		-- Create the Module.Theme file from the defaults
		Module.Theme = require('defaults.themes') -- your local themes file incase the user doesn't have one in config folder
		mq.pickle(Module.ThemeFile, Module.Theme)
	end
end

local function getPetData()
	if myPet() == 'NO PET' then
		petBuffs = {}
		return
	end
	-- petBuffs = {}
	local tmpBuffCnt = 0
	for i = 1, 120 do
		local name = mq.TLO.Me.PetBuff(i)() or 'None'
		local id = mq.TLO.Spell(name).ID() or 0
		local beneficial = mq.TLO.Spell(id).Beneficial() or nil
		local icon = mq.TLO.Spell(id).SpellIcon() or 0
		local slot = i
		petBuffs[i] = {}
		petBuffs[i] = { Name = name, ID = id, Beneficial = beneficial, Icon = icon, Slot = slot, }
		if name ~= 'None' then
			tmpBuffCnt = tmpBuffCnt + 1
		end
	end
	petBuffCount = tmpBuffCnt
end

local function loadSettings()
	local newSetting = false -- Check if we need to save the settings file

	-- Check Settings
	if not Module.Utils.File.Exists(configFile) then
		if Module.Utils.File.Exists(configFileOld) then
			-- Load the old settings file
			settings = dofile(configFileOld)
			-- Save the settings to the new file
			mq.pickle(configFile, settings)
		else
			-- Create the settings file from the defaults
			settings[Module.Name] = defaults
			mq.pickle(configFile, settings)
		end
	else
		-- Load settings from the Lua config file
		settings = dofile(configFile)
		-- Check if the settings are missing from the file
		if settings[Module.Name] == nil then
			settings[Module.Name] = {}
			settings[Module.Name] = defaults
			newSetting = true
		end
	end

	newSetting = Module.Utils.CheckDefaultSettings(defaults, settings[Module.Name])
	newSetting = Module.Utils.CheckDefaultSettings(defaults.Buttons, settings[Module.Name].Buttons) or newSetting
	newSetting = Module.Utils.CheckDefaultSettings(defaults.ConColors, settings[Module.Name].ConColors) or newSetting
	if loadedExeternally then
		-- Load the Module.Theme
		loadTheme()
	end
	-- Set the settings to the variables
	themeName = settings[Module.Name].LoadTheme or 'Default'
	showTitleBar = settings[Module.Name].ShowTitlebar
	autoHide = settings[Module.Name].AutoHide
	locked = settings[Module.Name].locked
	scale = settings[Module.Name].Scale
	themeName = settings[Module.Name].LoadTheme
	Module.TempSettings = settings[Module.Name]
	-- Save the settings if new settings were added
	if newSetting then mq.pickle(configFile, settings) end
end

local function GetButtonStates()
	local stance = myPet.Stance()
	btnInfo.follow = stance == 'FOLLOW' and true or false
	btnInfo.guard = stance == 'GUARD' and true or false
	btnInfo.sit = myPet.Sitting() and true or false
	btnInfo.taunt = myPet.Taunt() and true or false
	btnInfo.stop = myPet.Stop() and true or false
	btnInfo.hold = myPet.Hold() and true or false
	btnInfo.focus = myPet.Focus() and true or false
	btnInfo.regroup = myPet.ReGroup() and true or false
	btnInfo.ghold = myPet.GHold() and true or false
end

local function DrawInspectableSpellIcon(iconID, bene, name, i)
	local spell = mq.TLO.Spell(petBuffs[i].ID)
	local cursor_x, cursor_y = ImGui.GetCursorPos()
	local beniColor = IM_COL32(0, 20, 180, 190) -- blue benificial default color
	if iconID == 0 then
		ImGui.SetWindowFontScale(settings[Module.Name].Scale)
		ImGui.Text("%s", i)
		ImGui.PushID(tostring(iconID) .. i .. "_invis_btn")
		ImGui.SetCursorPos(cursor_x, cursor_y)
		ImGui.InvisibleButton("slot" .. tostring(i), ImVec2(iconSize, iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
		ImGui.PopID()

		return
	end
	animSpell:SetTextureCell(iconID or 0)
	if not bene then
		beniColor = IM_COL32(255, 0, 0, 190) --red detrimental
	end
	ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
		ImGui.GetCursorScreenPosVec() + iconSize, beniColor)
	ImGui.SetCursorPos(cursor_x + 3, cursor_y + 3)
	ImGui.DrawTextureAnimation(animSpell, iconSize - 5, iconSize - 5)
	ImGui.SetCursorPos(cursor_x + 2, cursor_y + 2)
	local sName = name or '??'
	ImGui.PushID(tostring(iconID) .. sName .. "_invis_btn")

	ImGui.SetCursorPos(cursor_x, cursor_y)
	ImGui.InvisibleButton(sName, ImVec2(iconSize, iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
	if ImGui.BeginPopupContextItem() then
		if ImGui.MenuItem("Inspect##PetBuff" .. i) then
			spell.Inspect()
			if Module.Build == 'Emu' then
				mq.cmdf("/nomodkey /altkey /notify PetInfoWindow PetBuff%s leftmouseup", i - 1)
			end
		end
		if ImGui.MenuItem("Remove##PetBuff" .. i) then
			mq.cmdf("/nomodkey /ctrlkey /notify PetInfoWindow PetBuff%s leftmouseup", i - 1)
		end
		if ImGui.MenuItem("Block##PetBuff" .. i) then
			mq.cmdf("/blockspell add pet '%s'", petBuffs[i].ID)
		end
		ImGui.EndPopup()
	end
	if ImGui.IsItemHovered() then
		ImGui.SetWindowFontScale(settings[Module.Name].Scale)
		ImGui.BeginTooltip()
		ImGui.Text(sName)
		ImGui.EndTooltip()
	end
	ImGui.PopID()
end

local function sortButtons()
	table.sort(btnKeys)
end

function Module.RenderGUI()
	if showMainGUI then
		-- Sort the buttons before displaying them
		sortButtons()
		if (autoHide and petName ~= 'NO PET') or not autoHide then
			ImGui.SetNextWindowSize(ImVec2(275, 255), ImGuiCond.FirstUseEver)
			-- Set Window Name
			local winName = string.format('%s##Main_%s', Module.Name, Module.CharLoaded)
			-- Load Theme
			local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(themeName, Module.Theme)
			-- Create Main Window
			local openMain, showMain = ImGui.Begin(winName, true, winFlags)
			-- Check if the window is open
			if not openMain then
				showMainGUI = false
			end

			-- Check if the window is showing
			if showMain then
				-- Set Window Font Scale
				ImGui.SetWindowFontScale(scale)
				if ImGui.BeginPopupContextWindow() then
					if ImGui.MenuItem("Settings") then
						-- Toggle Config Window
						showConfigGUI = not showConfigGUI
					end
					local lockLabel = locked and 'Unlock' or 'Lock'
					if ImGui.MenuItem(lockLabel .. "##MyPet") then
						locked = not locked
						settings[Module.Name].locked = locked
						mq.pickle(configFile, settings)
					end
					local titleBarLabel = showTitleBar and 'Hide Title Bar' or 'Show Title Bar'
					if ImGui.MenuItem(titleBarLabel .. "##MyPet") then
						showTitleBar = not showTitleBar
						settings[Module.Name].ShowTitlebar = showTitleBar
						mq.pickle(configFile, settings)
					end

					if ImGui.MenuItem('Exit') then
						Module.IsRunning = false
					end
					ImGui.EndPopup()
				end
				if petName == 'NO PET' then
					ImGui.Text("NO PET")
				else
					petHP = mq.TLO.Me.Pet.PctHPs() or 0
					petTarg = myPet.Target.DisplayName() or nil
					petTargHP = myPet.Target.PctHPs() or 0
					petLvl = myPet.Level() or -1
					if ImGui.BeginTable("##SplitWindow", 2, bit32.bor(ImGuiTableFlags.BordersOuter, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable), ImVec2(-1, -1)) then
						ImGui.TableSetupColumn(petName .. "##MainPetInfo", ImGuiTableColumnFlags.None, -1)
						ImGui.TableSetupColumn("Buffs##PetBuffs", ImGuiTableColumnFlags.None, -1)
						ImGui.TableSetupScrollFreeze(0, 1)
						ImGui.TableHeadersRow()
						ImGui.TableNextRow()
						ImGui.TableNextColumn()
						ImGui.BeginGroup()
						ImGui.Text("Lvl:")
						ImGui.SameLine()
						ImGui.TextColored((Module.Colors.color('teal')), "%s", petLvl)
						ImGui.SameLine()
						ImGui.Text("Dist:")
						ImGui.SameLine()
						petDist = myPet.Distance() or 0

						if petDist >= 150 then
							ImGui.TextColored((Module.Colors.color('red')), "%.0f", petDist)
						else
							ImGui.TextColored((Module.Colors.color('green')), "%.0f", petDist)
						end
						local yPos = ImGui.GetCursorPosY() - 1
						ImGui.PushStyleColor(ImGuiCol.PlotHistogram, (Module.Utils.CalculateColor({ 0.245, 0.245, 0.938, 1.000, }, { 0.976, 0.134, 0.134, 1.000, }, petHP, nil, 0)))
						ImGui.ProgressBar(petHP / 100, -1, 15, "##")
						ImGui.PopStyleColor()
						ImGui.SetCursorPosY(yPos)
						ImGui.SetCursorPosX(ImGui.GetColumnWidth() / 2)
						ImGui.Text("%.1f%%", petHP)
						ImGui.EndGroup()
						if ImGui.IsItemHovered() then
							if ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
								mq.TLO.Pet.DoTarget()
								if mq.TLO.Cursor() ~= nil then
									-- Module.Utils.GiveItem(myPet.ID())
									mq.TLO.Pet.LeftClick()
								end
							end
						end
						local conCol = myPet.Target.ConColor() or 'WHITE'
						if conCol == nil then conCol = 'WHITE' end
						local txCol = settings[Module.Name].ConColors[conCol]
						ImGui.TextColored(ImVec4(txCol[1], txCol[2], txCol[3], txCol[4]), "%s", petTarg)
						if petTarg ~= nil then
							ImGui.PushStyleColor(ImGuiCol.PlotHistogram,
								(Module.Utils.CalculateColor({ 0.165, 0.488, 0.162, 1.000, }, { 0.858, 0.170, 0.106, 1.000, }, petTargHP, nil, 0)))
							ImGui.ProgressBar(petTargHP / 100, -1, 15)
							ImGui.PopStyleColor()
						else
							ImGui.Dummy(20, 15)
						end
						ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 2, 2)
						-- Buttons Section
						local btnCount = 0
						for i = 1, #btnKeys do
							if settings[Module.Name].Buttons[btnKeys[i]].show then
								local tmpname = btnKeys[i] or 'none'
								tmpname = string.lower(tmpname)
								if btnInfo[tmpname] ~= nil then
									if btnInfo[tmpname] then
										ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(0, 1, 1, 1))
										if ImGui.Button(btnKeys[i] .. "##ButtonPet_" .. btnKeys[i], 60, 20) then
											mq.cmd(settings[Module.Name].Buttons[btnKeys[i]].cmd)
										end
										ImGui.PopStyleColor()
									else
										if ImGui.Button(btnKeys[i] .. "##ButtonPet_" .. btnKeys[i], 60, 20) then
											mq.cmd(settings[Module.Name].Buttons[btnKeys[i]].cmd)
										end
									end
									btnCount = btnCount + 1
									if btnCount < settings[Module.Name].ButtonsRow and i < #btnKeys then
										ImGui.SameLine()
									else
										btnCount = 0
									end
								end
							end
						end
						ImGui.PopStyleVar()
						ImGui.TableNextColumn()

						local maxPerRow = math.floor((ImGui.GetColumnWidth() / iconSize) - 1)
						local rowCnt = 0
						ImGui.BeginChild('PetBuffs##PetBuf', 0.0, -1, bit32.bor(ImGuiChildFlags.None), bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoScrollbar))
						ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0.0, 0.0)
						local petDrawBuffCount = 0
						local idx = 1
						while petDrawBuffCount ~= petBuffCount do
							if petBuffs[idx] == nil then break end
							DrawInspectableSpellIcon(petBuffs[idx].Icon, petBuffs[idx].Beneficial, petBuffs[idx].Name, idx)

							if petBuffs[idx].Name ~= 'None' then
								petDrawBuffCount = petDrawBuffCount + 1
							end
							if rowCnt < maxPerRow and petDrawBuffCount < petBuffCount then
								ImGui.SameLine()
								rowCnt = rowCnt + 1
							else
								rowCnt = 0
							end

							idx = idx + 1
						end
						ImGui.PopStyleVar()
						ImGui.EndChild()

						ImGui.EndTable()
					end
				end
				-- Reset Font Scale
				ImGui.SetWindowFontScale(1)
			end
			Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
			ImGui.End()
		end
	end

	if showConfigGUI then
		ImGui.SetNextWindowSize(ImVec2(400, 400), ImGuiCond.FirstUseEver)
		local winName = string.format('%s Config##Config_%s', Module.Name, Module.CharLoaded)
		local ColCntConf, StyCntConf = Module.ThemeLoader.StartTheme(themeName, Module.Theme)
		local openConfig, showConfig = ImGui.Begin(winName, true, bit32.bor(ImGuiWindowFlags.NoCollapse))
		if not openConfig then
			showConfigGUI = false
		end
		if showConfig then
			if ImGui.Button("Save & Close") then
				settings[Module.Name].ShowTitlebar = showTitleBar
				settings[Module.Name].locked = locked
				settings[Module.Name].Scale = scale
				settings[Module.Name].IconSize = iconSize
				settings[Module.Name].LoadTheme = themeName
				settings[Module.Name].AutoHide = autoHide
				settings[Module.Name].ColorHPMax = Module.TempSettings.ColorHPMax
				settings[Module.Name].ColorHPMin = Module.TempSettings.ColorHPMin
				settings[Module.Name].ColorTargMax = Module.TempSettings.ColorTargMax
				settings[Module.Name].ColorTargMin = Module.TempSettings.ColorTargMin

				mq.pickle(configFile, settings)
				showConfigGUI = false
			end
			-- Configure ThemeZ --

			ImGui.SeparatorText("Theme##" .. Module.Name)
			if ImGui.CollapsingHeader("Theme##" .. Module.Name) then
				ImGui.Text("Cur Theme: %s", themeName)
				-- Combo Box Load Theme
				if ImGui.BeginCombo("Load Theme##" .. Module.Name, themeName) then
					for k, data in pairs(Module.Theme.Theme) do
						local isSelected = data.Name == themeName
						if ImGui.Selectable(data.Name, isSelected) then
							Module.Theme.LoadTheme = data.Name
							themeName = Module.Theme.LoadTheme
						end
					end
					ImGui.EndCombo()
				end

				-- Configure Scale --
				scale = ImGui.SliderFloat("Scale##" .. Module.Name, scale, 0.5, 2)
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

				-- Reload Theme File incase of changes --
				if ImGui.Button('Reload Theme File') then
					loadTheme()
				end
			end

			if ImGui.CollapsingHeader('ConColors##ConColors') then
				ImGui.SeparatorText("Con Colors")
				if ImGui.BeginTable('##PConCol', 2) then
					ImGui.TableNextColumn()
					settings[Module.Name].ConColors.RED = ImGui.ColorEdit4("RED##ConColors", settings[Module.Name].ConColors.RED, ImGuiColorEditFlags.NoInputs)
					ImGui.TableNextColumn()
					settings[Module.Name].ConColors.YELLOW = ImGui.ColorEdit4("YELLOW##ConColors", settings[Module.Name].ConColors.YELLOW, ImGuiColorEditFlags.NoInputs)
					ImGui.TableNextColumn()
					settings[Module.Name].ConColors.WHITE = ImGui.ColorEdit4("WHITE##ConColors", settings[Module.Name].ConColors.WHITE, ImGuiColorEditFlags.NoInputs)
					ImGui.TableNextColumn()
					settings[Module.Name].ConColors.BLUE = ImGui.ColorEdit4("BLUE##ConColors", settings[Module.Name].ConColors.BLUE, ImGuiColorEditFlags.NoInputs)
					ImGui.TableNextColumn()
					settings[Module.Name].ConColors['LIGHT BLUE'] = ImGui.ColorEdit4("LIGHT BLUE##ConColors", settings[Module.Name].ConColors['LIGHT BLUE'],
						ImGuiColorEditFlags.NoInputs)
					ImGui.TableNextColumn()
					settings[Module.Name].ConColors.GREEN = ImGui.ColorEdit4("GREEN##ConColors", settings[Module.Name].ConColors.GREEN, ImGuiColorEditFlags.NoInputs)
					ImGui.TableNextColumn()
					settings[Module.Name].ConColors.GREY = ImGui.ColorEdit4("GREY##ConColors", settings[Module.Name].ConColors.GREY, ImGuiColorEditFlags.NoInputs)
					ImGui.EndTable()
				end
			end
			-- Configure Toggles for Button Display --
			iconSize = ImGui.InputInt("Icon Size##" .. Module.Name, iconSize, 1, 5)
			if ImGui.BeginTable("##Colors", 2) then
				ImGui.TableNextColumn()
				autoHide = Module.Utils.DrawToggle("Auto Hide##" .. Module.Name, autoHide, ToggleFlags)
				ImGui.TableNextColumn()

				locked = Module.Utils.DrawToggle("Lock Window##" .. Module.Name, locked, ToggleFlags)
				ImGui.TableNextColumn()

				showTitleBar = Module.Utils.DrawToggle("Show Title Bar##" .. Module.Name, showTitleBar, ToggleFlags)
				ImGui.TableNextColumn()
				ImGui.TableNextColumn()

				-- Configure Dynamic Color for Porgress Bars --
				ImGui.SetNextItemWidth(60)
				Module.TempSettings.ColorHPMin = ImGui.ColorEdit4("Pet HP Min##" .. Module.Name, Module.TempSettings.ColorHPMin, ImGuiColorEditFlags.NoInputs)
				ImGui.TableNextColumn()

				ImGui.SetNextItemWidth(60)
				Module.TempSettings.ColorHPMax = ImGui.ColorEdit4("Pet HP Max##" .. Module.Name, Module.TempSettings.ColorHPMax, ImGuiColorEditFlags.NoInputs)
				ImGui.TableNextColumn()

				ImGui.SetNextItemWidth(60)
				Module.TempSettings.ColorTargMin = ImGui.ColorEdit4("Target HP Min##" .. Module.Name, Module.TempSettings.ColorTargMin, ImGuiColorEditFlags.NoInputs)
				ImGui.TableNextColumn()

				ImGui.SetNextItemWidth(60)
				Module.TempSettings.ColorTargMax = ImGui.ColorEdit4("Target HP Max##" .. Module.Name, Module.TempSettings.ColorTargMax, ImGuiColorEditFlags.NoInputs)
				ImGui.EndTable()
			end
			local testVal = ImGui.SliderInt("Test Slider##" .. Module.Name, 100, 0, 100)

			-- draw 2 test bars
			ImGui.SetNextItemWidth(100)
			ImGui.PushStyleColor(ImGuiCol.PlotHistogram, Module.Utils.CalculateColor(Module.TempSettings.ColorHPMin, Module.TempSettings.ColorHPMax, testVal, nil, 0))
			ImGui.ProgressBar(testVal / 100, -1, 15, 'Pet HP')
			ImGui.PopStyleColor()

			ImGui.SetNextItemWidth(100)
			ImGui.PushStyleColor(ImGuiCol.PlotHistogram, Module.Utils.CalculateColor(Module.TempSettings.ColorTargMin, Module.TempSettings.ColorTargMax, testVal, nil, 0))
			ImGui.ProgressBar(testVal / 100, -1, 15, 'Target HP')
			ImGui.PopStyleColor()

			ImGui.SeparatorText("Buttons##" .. Module.Name)
			if ImGui.CollapsingHeader('Buttons##PetConfigButtons') then
				local sizeX, sizeY = ImGui.GetContentRegionAvail()
				sizeY = sizeY - 50
				local col = math.floor(sizeX / 75) or 1
				local sorted_names = MyUI_Utils.SortTableColumns(nil, btnKeys, col)

				ImGui.SetNextItemWidth(100)
				settings[Module.Name].ButtonsRow = ImGui.InputInt("Buttons Per Row##" .. Module.Name, settings[Module.Name].ButtonsRow, 1, 5)

				ImGui.SeparatorText("Buttons to Display")
				if ImGui.BeginTable("ButtonToggles##Toggles", col, ImGuiTableFlags.ScrollY) then
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
					for i = 1, 16 do
						if sorted_names[i] ~= nil then
							local name = sorted_names[i]
							Module.ButtonLabels[name] = settings[Module.Name].Buttons[name].show and Module.Icons.FA_TOGGLE_ON or Module.Icons.FA_TOGGLE_OFF
							ImGui.Text("%s %s", Module.ButtonLabels[name], name)
							if ImGui.IsItemClicked(0) then
								settings[Module.Name].Buttons[name].show = not settings[Module.Name].Buttons[name].show
							end

							ImGui.TableNextColumn()
						end
					end
					ImGui.EndTable()
				end
			end
			-- Save & Close Button --
		end
		Module.ThemeLoader.EndTheme(ColCntConf, StyCntConf)
		ImGui.End()
	end
end

function Module.Unload()
	return
end

local function Init()
	loadSettings()

	-- Check if ThemeZ exists
	if Module.Utils.File.Exists(themezDir) then
		hasThemeZ = true
	end
	-- Initialize ImGui	getPetData()
	lastCheck = os.time()
	GetButtonStates()
	Module.IsRunning = true
	if not loadedExeternally then
		mq.imgui.init(Module.Name, Module.RenderGUI)
		Module.LocalLoop()
	end
end

local clockTimer = mq.gettime()
function Module.MainLoop()
	if loadedExeternally then
		---@diagnostic disable-next-line: undefined-global
		if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
	end

	local timeDiff = mq.gettime() - clockTimer
	if timeDiff > 100 then
		petName = myPet.DisplayName() or 'NO PET'
		-- Process ImGui Window Flag Changes
		winFlags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoFocusOnAppearing)
		winFlags = locked and bit32.bor(ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize, winFlags) or winFlags
		-- winFlags = aSize and bit32.bor(winFlags, ImGuiWindowFlags.AlwaysAutoResize) or winFlags
		winFlags = not showTitleBar and bit32.bor(winFlags, ImGuiWindowFlags.NoTitleBar) or winFlags
		if petName ~= 'NO PET' then
			GetButtonStates()
			getPetData()
		else
			petBuffCount = 0
			petBuffs = {}
		end
		clockTimer = mq.gettime()
	end
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
