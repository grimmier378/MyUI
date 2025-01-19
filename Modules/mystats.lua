local mq = require('mq')
local ImGui = require 'ImGui'
local drawTimerMS = mq.gettime() -- get the current time in milliseconds
local drawTimerS = os.time()     -- get the current time in seconds
local Module = {}
local MySelf = mq.TLO.Me
local myStats = {}
local myAltCur = {}

Module.Name = "MyStats"  -- Name of the module used when loading and unloaing the modules.
Module.IsRunning = false -- Keep track of running state. if not running we can unload it.
Module.ShowGui = true

-- check if the script is being loaded as a Module (externally) or as a Standalone script.
---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false
if not loadedExeternally then
	Module.Utils       = require('lib.common')    -- common functions for use in other scripts
	Module.Icons       = require('mq.ICONS')      -- FAWESOME ICONS
	Module.Colors      = require('lib.colors')    -- color table for GUI returns ImVec4
	Module.ThemeLoader = require('lib.theme_loader') -- Load the theme loader
	Module.CharLoaded  = MySelf.CleanName()
else
	Module.Utils       = MyUI_Utils
	Module.Icons       = MyUI_Icons
	Module.Colors      = MyUI_Colors
	Module.ThemeLoader = MyUI_ThemeLoader
	Module.CharLoaded  = MyUI_CharLoaded
end


--Helpers
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
	mq.bind('/mystats', CommandHandler)
	Module.IsRunning = true
	Module.Utils.PrintOutput('MyUI', false, "\a-w[\at%s\a-w] \agLoaded\aw!", Module.Name)
	myStats, myAltCur = Module.GetStats()
	if not loadedExeternally then
		mq.imgui.init(Module.Name, Module.RenderGUI)
		Module.LocalLoop()
	end
end

function Module.GetStats()
	local stats = {}
	table.insert(stats, 1, { ['HP'] = string.format("%s / %s", MySelf.CurrentHPs() or 0, MySelf.MaxHPs() or 0), })
	table.insert(stats, 2, { ['Regen'] = string.format("%s + %s", (MySelf.HPRegen() or 0) + 20, MySelf.HPRegenBonus() or 0), })

	table.insert(stats, 3, { ['Mana'] = string.format("%s / %s", MySelf.CurrentMana() or 0, MySelf.MaxMana() or 0), })
	table.insert(stats, 4, { ['Mana Regen'] = string.format("%s + %s", MySelf.ManaRegen() or 0, MySelf.ManaRegenBonus() or 0), })

	table.insert(stats, 5, { ['Endurance'] = string.format("%s / %s", MySelf.CurrentEndurance() or 0, MySelf.MaxEndurance() or 0), })
	table.insert(stats, 6, { ['End Regen'] = string.format("%s + %s", MySelf.EnduranceRegen() or 0, MySelf.EnduranceRegenBonus() or 0), })

	table.insert(stats, 7, { ['Haste'] = string.format("%s%%", MySelf.Haste() or 0), })
	table.insert(stats, 8, { ['ATK Bonus'] = MySelf.AttackBonus() or 0, })
	table.insert(stats, 9, { ['STATS'] = '----', })
	table.insert(stats, 10, { ['RESISTS'] = '----', })
	table.insert(stats, 11, { ['STR'] = string.format("%s + %s", MySelf.STR() or 0, MySelf.HeroicSTRBonus() or 0), })
	table.insert(stats, 13, { ['STA'] = string.format("%s + %s", MySelf.STA() or 0, MySelf.HeroicSTABonus() or 0), })
	table.insert(stats, 15, { ['AGI'] = string.format("%s + %s", MySelf.AGI() or 0, MySelf.HeroicAGIBonus() or 0), })
	table.insert(stats, 17, { ['DEX'] = string.format("%s + %s", MySelf.DEX() or 0, MySelf.HeroicDEXBonus() or 0), })
	table.insert(stats, 19, { ['WIS'] = string.format("%s + %s", MySelf.WIS() or 0, MySelf.HeroicWISBonus() or 0), })
	table.insert(stats, 21, { ['INT'] = string.format("%s + %s", MySelf.INT() or 0, MySelf.HeroicINTBonus() or 0), })
	table.insert(stats, 23, { ['CHA'] = string.format("%s + %s", MySelf.CHA() or 0, MySelf.HeroicCHABonus() or 0), })

	table.insert(stats, 12, { ['Resist Fire'] = MySelf.svFire() or 0, })
	table.insert(stats, 14, { ['Resist Cold'] = MySelf.svCold() or 0, })
	table.insert(stats, 16, { ['Resist Magic'] = MySelf.svMagic() or 0, })
	table.insert(stats, 18, { ['Resist Disease'] = MySelf.svDisease() or 0, })
	table.insert(stats, 20, { ['Resist Poison'] = MySelf.svPoison() or 0, })
	table.insert(stats, 22, { ['Resist Corruption'] = MySelf.svCorruption() or 0, })
	table.insert(stats, 24, { ['Resist Prismatic'] = MySelf.svPrismatic() or 0, })

	-- Alt Currency

	local altCur = {}
	table.insert(altCur, 1, { ['Diamond Coins'] = MySelf.AltCurrency("Diamond Coin")() or 0, })
	table.insert(altCur, 2, { ['Celestial Crests'] = MySelf.AltCurrency("Celestial Crest")() or 0, })
	table.insert(altCur, 3, { ['Gold Coins'] = MySelf.AltCurrency("Gold Coin")() or 0, })
	table.insert(altCur, 4, { ["Drinals Token"] = MySelf.AltCurrency("Drinal's Token")() or 0, })
	table.insert(altCur, 5, { ["Planar Symbol"] = MySelf.AltCurrency("Planar Symbol")() or 0, })
	return stats, altCur
end

-- Exposed Functions
function Module.RenderGUI()
	if Module.ShowGui then
		local open, show = ImGui.Begin(Module.Name .. "##" .. Module.CharLoaded, true, ImGuiWindowFlags.None)
		if not open then
			show = false
			Module.ShowGui = false
			Module.IsRunning = false
		end
		if show then
			if ImGui.BeginTable("MyInfo", 4, bit32.bor(ImGuiTableFlags.ScrollY)) then
				ImGui.TableNextRow()
				ImGui.TableSetColumnIndex(0)
				local txtColor      = 'teal'
				local valColor      = 'yellow'
				local sectionChange = false
				for i, data in ipairs(myStats) do
					if i % 2 == 0 then
						txtColor = 'softblue'
						valColor = 'green2'
					else
						txtColor = 'teal'
						valColor = 'yellow'
					end
					for k, v in pairs(data) do
						if sectionChange then
							if i % 2 == 0 then
								txtColor = 'white'
								valColor = 'tangarine'
							else
								txtColor = 'purple2'
								valColor = 'pink2'
							end
						end
						if k == 'STATS' or k == 'RESISTS' then
							ImGui.TableNextRow()
							ImGui.TableSetColumnIndex(0)
							sectionChange = true
						else
							ImGui.TextColored(Module.Colors.color(txtColor), "%s:", k)
							ImGui.TableNextColumn()
							ImGui.TextColored(Module.Colors.color(valColor), "%s", v)
							ImGui.TableNextColumn()
						end
					end
				end
				ImGui.TableNextRow()
				ImGui.TableSetColumnIndex(0)
				ImGui.TableNextColumn()
				ImGui.TextColored(ImVec4(0, 1, 0, 1), "Alt Currency:")
				ImGui.TableNextRow()
				ImGui.TableSetColumnIndex(0)
				for _, data in ipairs(myAltCur) do
					for k, v in pairs(data) do
						ImGui.TextColored(Module.Colors.color('grey'), "%s:", k)
						ImGui.TableNextColumn()
						ImGui.TextColored(Module.Colors.color('yellow'), "%s", v)
						ImGui.TableNextColumn()
					end
				end
				ImGui.EndTable()
			end
		end

		ImGui.End()
	end
end

function Module.Unload()
	mq.unbind('/mystats')
end

function Module.MainLoop()
	if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end

	if mq.gettime() - drawTimerMS < 500 then
		return
	else
		drawTimerMS = mq.gettime()
		myStats, myAltCur = Module.GetStats()
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
