local mq = require('mq')
local ImGui = require('ImGui')
local Module = {}
Module.ActorMailBox = 'my_dps'
Module.Name = 'MyDPS'
Module.IsRunning = false
---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false

if not loadedExeternally then
	Module.Utils       = require('lib.common')
	Module.ThemeLoader = require('lib.theme_loader')
	Module.Actor       = require('actors')
	Module.CharLoaded  = mq.TLO.Me.DisplayName()
	Module.Server      = mq.TLO.MacroQuest.Server()
	Module.ThemeFile   = string.format('%s/MyUI/ThemeZ.lua', mq.configDir)
	Module.Theme       = {}
else
	Module.Utils = MyUI_Utils
	Module.ThemeLoader = MyUI_ThemeLoader
	Module.Actor = MyUI_Actor
	Module.CharLoaded = MyUI_CharLoaded
	Module.Server = MyUI_Server
	Module.ThemeFile = MyUI_ThemeFile
	Module.Theme = MyUI_Theme
end
Module.PetName                                                                                                                     = mq.TLO.Pet.DisplayName() or 'NoPet'
Module.TempSettings                                                                                                                = {}
local Utils                                                                                                                        = Module.Utils
local ToggleFlags                                                                                                                  = bit32.bor(
	Utils.ImGuiToggleFlags.PulseOnHover,
	--Utils.ImGuiToggleFlags.SmilyKnob,
	--Utils.ImGuiToggleFlags.StarKnob,
	Utils.ImGuiToggleFlags.RightLabel)
local ActorDPS                                                                                                                     = nil
local configFile                                                                                                                   = string.format("%s/MyUI/%s/%s/%s.lua",
	mq.configDir, Module.Name, Module.Server, Module.CharLoaded)
local damTable, settings                                                                                                           = {}, {}
local winFlags                                                                                                                     = bit32.bor(ImGuiWindowFlags.None,
	ImGuiWindowFlags.NoTitleBar)
local started                                                                                                                      = false
local clickThrough                                                                                                                 = false
local showDataWin                                                                                                                  = false
local dataWinData                                                                                                                  = {
	data = {},
	seq = nil,
	labelName = nil,
}
local tableSize                                                                                                                    = 0
local sequenceCounter, battleCounter                                                                                               = 0, 0
local dpsStartTime                                                                                                                 = os.time()
local previewBG                                                                                                                    = false
local dmgTotal, dmgCounter, dsCounter, dmgTotalDS, dmgTotalBattle, dmgBattCounter, critHealsTotal, critTotalBattle, dotTotalBattle = 0, 0, 0, 0, 0, 0, 0, 0, 0
local workingTable, battlesHistory, actorsTable, actorsWorking                                                                     = {}, {}, {}, {}
local enteredCombat                                                                                                                = false
local battleStartTime, leftCombatTime                                                                                              = 0, 0
local firstRun                                                                                                                     = true
local themeName                                                                                                                    = "Default"
local tempSettings                                                                                                                 = {}
local dataWindows                                                                                                                  = {}
local MyLeader                                                                                                                     = 'None'
local defaults                                                                                                                     = {
	Options = {
		sortNewest             = true,
		showType               = true,
		showTarget             = true,
		showMyMisses           = true,
		showMissMe             = true,
		showHitMe              = true,
		showCritHeals          = true,
		showDS                 = true,
		showHistory            = true,
		addPet                 = true,
		displayTime            = 10,
		fontScale              = 1.0,
		spamFontScale          = 1.0,
		bgColor                = { 0, 0, 0, 0.5, },
		dpsTimeSpanReportTimer = 60,
		dpsTimeSpanReport      = false,
		dpsBattleReport        = true,
		announceDNET           = false,
		battleDuration         = 10,
		sortHistory            = true,
		announceActors         = true,
		sortParty              = true,
		showCombatWindow       = true,
		useTheme               = 'Default',
		autoStart              = false,
		OutputTab              = Module.Name,
	},
	MeleeColors = {
		["crush"] = { 1, 1, 1, 1, },
		["kick"] = { 1, 1, 1, 1, },
		["bite"] = { 1, 1, 1, 1, },
		["bash"] = { 1, 1, 1, 1, },
		["hit"] = { 1, 1, 1, 1, },
		["pierce"] = { 1, 1, 1, 1, },
		["backstab"] = { 1, 0, 0, 1, },
		["slash"] = { 1, 1, 1, 1, },
		["miss"] = { 0.5, 0.5, 0.5, 1, },
		["missed-me"] = { 0.5, 0.5, 0.5, 1, },
		["non-melee"] = { 0, 1, 1, 1, },
		["hit-by"] = { 1, 0, 0, 1, },
		["crit"] = { 1, 1, 0, 1, },
		["hit-by-non-melee"] = { 1, 1, 0, 1, },
		["dShield"] = { 0, 1, 0, 1, },
		['critHeals'] = { 0, 1, 1, 1, },
		['dot'] = { 1, 1, 0, 1, },
	},
}

local function loadThemeTable()
	if Module.Utils.File.Exists(Module.ThemeFile) then
		Module.Theme = dofile(Module.ThemeFile)
	else
		Module.Theme = require('defaults.themes') -- your local themes file incase the user doesn't have one in config folder
		mq.pickle(Module.ThemeFile, Module.Theme)
	end
end

local function loadSettings()
	if not Module.Utils.File.Exists(configFile) then
		settings = defaults
		mq.pickle(configFile, settings)
	else
		settings = dofile(configFile)
		if not settings then
			settings = {}
			settings = defaults
		end
	end

	if not loadedExeternally then
		loadThemeTable()
	end

	for k, v in pairs(defaults.Options) do
		if settings.Options[k] == nil then
			settings.Options[k] = v
		end
	end

	for k, v in pairs(defaults.MeleeColors) do
		if settings.MeleeColors[k] == nil then
			settings.MeleeColors[k] = v
		end
	end

	local newSetting = false

	-- check for new settings
	newSetting = Module.Utils.CheckRemovedSettings(defaults.MeleeColors, settings.MeleeColors) or newSetting
	newSetting = Module.Utils.CheckRemovedSettings(defaults.Options, settings.Options) or newSetting

	-- check for removed settings
	newSetting = Module.Utils.CheckRemovedSettings(defaults.Options, settings.Options) or newSetting
	newSetting = Module.Utils.CheckRemovedSettings(defaults.MeleeColors, settings.MeleeColors) or newSetting

	-- set local settings
	for k, v in pairs(settings.Options or {}) do
		tempSettings[k] = v
	end
	tempSettings.doActors = settings.Options.announceActors
	themeName = settings.Options.useTheme or 'Default'
	if newSetting then mq.pickle(configFile, settings) end
end

---comment
---@param tbl table @ table to sort
---@param sortType string @ type of sort (combat, history, dps)
---@return table @ sorted table
local function sortTable(tbl, sortType)
	if sortType == nil then return tbl end
	if #tbl == 0 then return tbl end
	table.sort(tbl, function(a, b)
		if sortType == 'combat' then
			if settings.Options.sortNewest then
				return (a.sequence > b.sequence)
			else
				return (a.sequence < b.sequence)
			end
		elseif sortType == 'party' then
			if tempSettings.sortParty then
				if a.sequence == b.sequence then
					if a.dps == b.dps then
						return a.name < b.name
					else
						return a.dps > b.dps
					end
				else
					return a.sequence > b.sequence
				end
			else
				return a.name < b.name
			end
		else
			if settings.Options.sortHistory then
				return (a.sequence > b.sequence)
			else
				return (a.sequence < b.sequence)
			end
		end
		return (a.sequence < b.sequence)
	end)
	return tbl
end

local function parseCurrentBattle(dur)
	if not enteredCombat then return end
	if dur > 0 then
		local dps = dur > 0 and (dmgTotalBattle / dur) or 0
		local avgDmg = dmgBattCounter > 0 and (dmgTotalBattle / dmgBattCounter) or 0
		local exists = false
		for k, v in pairs(battlesHistory) do
			if v.sequence == -1 or v.sequence == 999999 then
				v.sequence  = settings.Options.sortHistory and 999999 or -1
				v.dps       = dps
				v.dur       = dur
				v.dmg       = dmgTotalBattle
				v.crit      = critTotalBattle
				v.critHeals = critHealsTotal
				v.dot       = dotTotalBattle
				v.avg       = avgDmg
				exists      = true
				break
			end
		end
		if not exists then
			table.insert(battlesHistory,
				{
					sequence = (settings.Options.sortHistory and 999999 or -1),
					dps = dps,
					dur = dur,
					dmg = dmgTotalBattle,
					avg = avgDmg,
					crit = critTotalBattle,
					critHeals = critHealsTotal,
					dot = dotTotalBattle,
				})
		end
		battlesHistory = sortTable(battlesHistory, 'history')
		if settings.Options.announceActors and ActorDPS ~= nil then
			local msgSend = {
				Name = Module.CharLoaded,
				Leader = MyLeader,
				Subject = 'CURRENT',
				BattleNum = -2,
				DPS = dps,
				TimeSpan = dur,
				TotalDmg = dmgTotalBattle,
				AvgDmg = avgDmg,
				Remove = false,
				Crit = critTotalBattle,
				CritHeals = critHealsTotal,
				Dots = dotTotalBattle,
			}
			ActorDPS:send({ mailbox = 'my_dps', script = 'mydps', }, (msgSend))
			ActorDPS:send({ mailbox = 'my_dps', script = 'myui', }, (msgSend))
			local found = false
			for k, v in pairs(actorsTable) do
				if v.name == Module.CharLoaded then
					v.name      = Module.CharLoaded
					v.sequence  = -2
					v.dps       = dps
					v.dur       = dur
					v.dmg       = dmgTotalBattle
					v.crit      = critTotalBattle
					v.critHeals = critHealsTotal
					v.dot       = dotTotalBattle
					v.avg       = avgDmg
					found       = true
					break
				end
			end
			if not found then
				table.insert(actorsTable, {
					name      = Module.CharLoaded,
					sequence  = -2,
					dps       = dps,
					dur       = dur,
					dmg       = dmgTotalBattle,
					crit      = critTotalBattle,
					critHeals = critHealsTotal,
					dot       = dotTotalBattle,
					avg       = avgDmg,
				})
			end
		end
	end
	workingTable = sortTable(damTable, 'combat')
end

local function npcMeleeCallBack(line, dType, target, dmg)
	local typeValue = dType or nil
	if not tonumber(dmg) then
		typeValue = 'missed-me'
		dmg       = 'MISSED'
	else
		typeValue = 'hit-by'
		local startType, stopType = string.find(line, "(%w+) YOU")
		target = string.sub(line, 1, startType - 2)
	end
	if target == nil then return end
	if not enteredCombat then
		enteredCombat   = true
		dmgBattCounter  = 0
		dmgTotalBattle  = 0
		dotTotalBattle  = 0
		critTotalBattle = 0
		critHealsTotal  = 0
		battleStartTime = os.time()
		leftCombatTime  = 0
	end
	parseCurrentBattle(os.time() - battleStartTime)
	if not settings.Options.showMissMe and typeValue == 'missed-me' then return end
	if not settings.Options.showHitMe and typeValue == 'hit-by' then return end
	if damTable == nil then damTable = {} end
	sequenceCounter = sequenceCounter + 1
	table.insert(damTable, {
		type      = typeValue,
		target    = target,
		damage    = dmg,
		timestamp = os.time(),
		sequence  = sequenceCounter,
	})
	tableSize = tableSize + 1
	parseCurrentBattle(os.time() - battleStartTime)
	workingTable = sortTable(damTable, 'combat')
end

local function nonMeleeClallBack(line, target, dmg)
	if not tonumber(dmg) then return end
	if not enteredCombat then
		enteredCombat   = true
		dmgBattCounter  = 0
		critHealsTotal  = 0
		critTotalBattle = 0
		dotTotalBattle  = 0
		dmgTotalBattle  = 0
		battleStartTime = os.time()
		leftCombatTime  = 0
	end
	local dmgType = "non-melee"
	if target == nil then
		target  = 'YOU'
		dmgType = "hit-by-non-melee"
	end

	if string.find(line, "was hit") then
		target  = string.sub(line, 1, string.find(line, "was") - 2)
		dmgType = "dShield"
	end

	if dmgType ~= 'dShield' then
		dmgTotal = dmgTotal + (tonumber(dmg) or 0)
		dmgCounter = dmgCounter + 1
		if enteredCombat then
			dmgTotalBattle = dmgTotalBattle + (tonumber(dmg) or 0)
			dmgBattCounter = dmgBattCounter + 1
		end
	else
		dmgTotalDS = dmgTotalDS + (tonumber(dmg) or 0)
		dsCounter = dsCounter + 1
		if enteredCombat then
			dmgTotalBattle = dmgTotalBattle + (tonumber(dmg) or 0)
			dmgBattCounter = dmgBattCounter + 1
		end
	end

	if not settings.Options.showDS and dmgType == 'dShield' then
		parseCurrentBattle(os.time() - battleStartTime)
		return
	end

	if damTable == nil then damTable = {} end
	sequenceCounter = sequenceCounter + 1
	table.insert(damTable, {
		type      = dmgType,
		target    = target,
		damage    = dmg,
		timestamp = os.time(),
		sequence  = sequenceCounter,
	})
	tableSize = tableSize + 1
	parseCurrentBattle(os.time() - battleStartTime)
end

local function nonMeleePetClallBack(line, target, dmg)
	if not tonumber(dmg) then return end
	if not enteredCombat then
		enteredCombat   = true
		dmgBattCounter  = 0
		critHealsTotal  = 0
		critTotalBattle = 0
		dotTotalBattle  = 0
		dmgTotalBattle  = 0
		battleStartTime = os.time()
		leftCombatTime  = 0
	end
	local dmgType = "non-melee"
	if target == nil then
		target  = Module.PetName
		dmgType = "hit-by-non-melee"
	end

	if string.find(line, "was hit") then
		target  = string.sub(line, 1, string.find(line, "was") - 2)
		dmgType = "dShield"
	end

	if dmgType ~= 'dShield' then
		dmgTotal = dmgTotal + (tonumber(dmg) or 0)
		dmgCounter = dmgCounter + 1
		if enteredCombat then
			dmgTotalBattle = dmgTotalBattle + (tonumber(dmg) or 0)
			dmgBattCounter = dmgBattCounter + 1
		end
	else
		dmgTotalDS = dmgTotalDS + (tonumber(dmg) or 0)
		dsCounter = dsCounter + 1
		if enteredCombat then
			dmgTotalBattle = dmgTotalBattle + (tonumber(dmg) or 0)
			dmgBattCounter = dmgBattCounter + 1
		end
	end

	if not settings.Options.showDS and dmgType == 'dShield' then
		parseCurrentBattle(os.time() - battleStartTime)
		return
	end

	if damTable == nil then damTable = {} end
	sequenceCounter = sequenceCounter + 1
	table.insert(damTable, {
		type      = Module.PetName .. " " .. dmgType,
		target    = target,
		damage    = dmg,
		timestamp = os.time(),
		sequence  = sequenceCounter,
	})
	tableSize = tableSize + 1
	parseCurrentBattle(os.time() - battleStartTime)
end

local function dotCallBack(line, target, dmg, spell_name)
	if target == nil then
		return
	end
	if not tonumber(dmg) then return end
	if not enteredCombat then
		enteredCombat   = true
		dmgBattCounter  = 0
		critHealsTotal  = 0
		critTotalBattle = 0
		dotTotalBattle  = 0
		dmgTotalBattle  = 0
		battleStartTime = os.time()
		leftCombatTime  = 0
	end
	local dmgType = "dot"

	dmgTotalDS = dmgTotalDS + (tonumber(dmg) or 0)
	dsCounter = dsCounter + 1
	if enteredCombat then
		dmgTotalBattle = dmgTotalBattle + (tonumber(dmg) or 0)
		dotTotalBattle = dotTotalBattle + (tonumber(dmg) or 0)
		dmgBattCounter = dmgBattCounter + 1
	end

	if damTable == nil then damTable = {} end
	sequenceCounter = sequenceCounter + 1
	table.insert(damTable, {
		type      = dmgType,
		target    = target,
		damage    = string.format("DOT [%s] <%d>", spell_name, dmg),
		timestamp = os.time(),
		sequence  = sequenceCounter,
	})
	tableSize = tableSize + 1
	parseCurrentBattle(os.time() - battleStartTime)
end

local function petCallBack(line, dType, target, dmg)
	local dmgType = dType or nil
	if dmgType == nil then return end
	if not enteredCombat then
		enteredCombat   = true
		dmgBattCounter  = 0
		dmgTotalBattle  = 0
		critTotalBattle = 0
		dotTotalBattle  = 0
		critHealsTotal  = 0
		battleStartTime = os.time()
		leftCombatTime  = 0
	end
	if dmg == nil then
		dmg = 'MISSED'
		dmgType = 'miss'
	end

	dmgTotal = dmgTotal + (tonumber(dmg) or 0)
	dmgCounter = dmgCounter + 1
	if enteredCombat then
		dmgTotalBattle = dmgTotalBattle + (tonumber(dmg) or 0)
		dmgBattCounter = dmgBattCounter + 1
	end

	if not settings.Options.showMyMisses and dmgType == 'miss' then
		parseCurrentBattle(os.time() - battleStartTime)
		return
	end

	if dmgType == 'miss' then target = Module.PetName end
	if damTable == nil then damTable = {} end

	sequenceCounter = sequenceCounter + 1
	table.insert(damTable, {
		type      = Module.PetName .. " " .. dmgType,
		target    = target,
		damage    = dmg,
		timestamp = os.time(),
		sequence  = sequenceCounter,
	})
	tableSize = tableSize + 1
	parseCurrentBattle(os.time() - battleStartTime)
end

local function meleeCallBack(line, dType, target, dmg)
	if string.find(line, "have been healed") then return end
	local dmgType = dType or nil
	if dmgType == nil then return end
	if not enteredCombat then
		enteredCombat   = true
		dmgBattCounter  = 0
		dmgTotalBattle  = 0
		critTotalBattle = 0
		dotTotalBattle  = 0
		critHealsTotal  = 0
		battleStartTime = os.time()
		leftCombatTime  = 0
	end
	if dmg == nil then
		dmg = 'MISSED'
		dmgType = 'miss'
	end

	dmgTotal = dmgTotal + (tonumber(dmg) or 0)
	dmgCounter = dmgCounter + 1
	if enteredCombat then
		dmgTotalBattle = dmgTotalBattle + (tonumber(dmg) or 0)
		dmgBattCounter = dmgBattCounter + 1
	end

	if not settings.Options.showMyMisses and dmgType == 'miss' then
		parseCurrentBattle(os.time() - battleStartTime)
		return
	end

	if dmgType == 'miss' then target = 'YOU' end
	if damTable == nil then damTable = {} end

	sequenceCounter = sequenceCounter + 1
	table.insert(damTable, {
		type      = dmgType,
		target    = target,
		damage    = dmg,
		timestamp = os.time(),
		sequence  = sequenceCounter,
	})
	tableSize = tableSize + 1
	parseCurrentBattle(os.time() - battleStartTime)
end

local function critCallBack(line, dmg)
	if not tonumber(dmg) then return end
	if not enteredCombat then
		enteredCombat   = true
		dmgBattCounter  = 0
		dmgTotalBattle  = 0
		critTotalBattle = 0
		dotTotalBattle  = 0
		critHealsTotal  = 0
		battleStartTime = os.time()
		leftCombatTime  = 0
	end

	if enteredCombat then
		critTotalBattle = critTotalBattle + (tonumber(dmg) or 0)
	end

	if damTable == nil then damTable = {} end
	sequenceCounter = sequenceCounter + 1
	table.insert(damTable, {
		type      = "crit",
		target    = mq.TLO.Target.CleanName(),
		damage    = string.format("CRIT <%d>", dmg),
		timestamp = os.time(),
		sequence  = sequenceCounter,
	})
	tableSize = tableSize + 1
	parseCurrentBattle(os.time() - battleStartTime)
end

local function critHealCallBack(line, dmg)
	if not tonumber(dmg) then return end
	if not enteredCombat then
		enteredCombat   = true
		battleStartTime = os.time()
		leftCombatTime  = 0
	end

	if enteredCombat then
		critHealsTotal = critHealsTotal + (tonumber(dmg) or 0)
	end

	if damTable == nil then damTable = {} end
	sequenceCounter = sequenceCounter + 1
	table.insert(damTable, {
		type      = "critHeals",
		target    = "You",
		damage    = string.format("CRIT_HEAL <%d>", dmg),
		timestamp = os.time(),
		sequence  = sequenceCounter,
	})
	tableSize = tableSize + 1
	parseCurrentBattle(os.time() - battleStartTime)
end

local function cleanTable()
	if tableSize > 0 then
		local currentTime = os.time()
		local i = 1
		while i <= tableSize do
			if currentTime - damTable[i].timestamp > settings.Options.displayTime then
				table.remove(damTable, i)
				tableSize = tableSize - 1
			else
				i = i + 1
			end
		end
	end
end

---comment
---@param num number @ Number to clean
---@param percision number|nil @ default 0 - Number of decimal places
---@param percAlways boolean|nil @ default false - Always show decimal places
---@return string
local function cleanNumber(num, percision, percAlways)
	if num == nil then return "0" end
	if percision == nil then percision = 0 end
	if percAlways == nil then percAlways = false end
	local label = ""
	local floatNum = 0
	if num >= 1000000000 then
		floatNum = num / 1000000
		if percision == 2 then
			label = string.format("%.2f b", floatNum)
		elseif percision == 1 then
			label = string.format("%.1f b", floatNum)
		elseif percision == 0 then
			label = string.format("%.0f b", floatNum)
		end
	elseif num >= 1000000 then
		floatNum = num / 1000000
		if percision == 2 then
			label = string.format("%.2f m", floatNum)
		elseif percision == 1 then
			label = string.format("%.1f m", floatNum)
		elseif percision == 0 then
			label = string.format("%.0f m", floatNum)
		end
	elseif num >= 1000 then
		floatNum = num / 1000
		if percision == 2 then
			label = string.format("%.2f k", floatNum)
		elseif percision == 1 then
			label = string.format("%.1f k", floatNum)
		else
			label = string.format("%.0f k", floatNum)
		end
	else
		if not percAlways then
			label = string.format("%.0f", num)
		else
			if percision == 2 then
				label = string.format("%.2f", num)
			elseif percision == 1 then
				label = string.format("%.1f", num)
			else
				label = string.format("%.0f", num)
			end
		end
	end
	return label
end

---comment
---@param t any
---@return table
local function checkColor(t)
	if settings.MeleeColors[t] then
		return settings.MeleeColors[t]
	else
		return { 1, 1, 1, 1, }
	end
end

local color = {
	red    = ImVec4(0.981, 0.484, 0.484, 1.000),
	green  = ImVec4(0, 1, 0, 1),
	blue   = ImVec4(0, 0, 1, 1),
	yellow = ImVec4(1, 1, 0, 1),
	orange = ImVec4(1.0, 0.5, 0, 1),
	teal   = ImVec4(0, 1, 1, 1),
	white  = ImVec4(1, 1, 1, 1),
}

local function ShowData(labelName, data, seq)
	if not showDataWin then return end
	local open, show = ImGui.Begin("Battle Details##" .. labelName, true, ImGuiWindowFlags.AlwaysAutoResize)
	if not open then
		dataWindows[labelName] = nil
		if dataWindows == nil then
			showDataWin = false
		end
	end
	if show then
		ImGui.Text("Battle Details %s", labelName)
		ImGui.Separator()
		ImGui.BeginTable("Battle Details", 2, ImGuiTableFlags.Borders)
		ImGui.TableNextRow()

		ImGui.TableNextColumn()
		ImGui.Text("Name:")

		ImGui.TableNextColumn()
		ImGui.TextColored(color.yellow, " %s", labelName)

		ImGui.TableNextColumn()
		ImGui.Text("Battle:")

		ImGui.TableNextColumn()
		ImGui.TextColored(color.teal, "%s", seq)

		ImGui.TableNextColumn()
		ImGui.Text("Duration:")

		ImGui.TableNextColumn()
		ImGui.TextColored(color.orange, "%s", cleanNumber(data.dur, 0, true))

		ImGui.TableNextColumn()
		ImGui.Text("DPS:")

		ImGui.TableNextColumn()
		ImGui.TextColored(color.green, "%s", cleanNumber(data.dps, 1, true))

		ImGui.TableNextColumn()
		ImGui.Text("Avg Dmg:")

		ImGui.TableNextColumn()
		ImGui.TextColored(color.red, "%s", cleanNumber(data.avg, 1, true))

		ImGui.TableNextColumn()
		ImGui.Text("Crit Dmg:")

		ImGui.TableNextColumn()
		ImGui.TextColored(color.yellow, "%s", cleanNumber(data.crit, 2))

		ImGui.TableNextColumn()
		ImGui.Text("Dots:")

		ImGui.TableNextColumn()
		ImGui.TextColored(color.orange, "%s", cleanNumber(data.dot, 2))

		ImGui.TableNextColumn()
		ImGui.Text("Crit Heals:")

		ImGui.TableNextColumn()
		ImGui.TextColored(color.teal, "%s", cleanNumber(data.critHeals, 1))

		ImGui.TableNextColumn()
		ImGui.Text("Total Damage:")

		ImGui.TableNextColumn()
		ImGui.TextColored(color.orange, "%s", cleanNumber(data.dmg, 2))

		ImGui.EndTable()
	end
	ImGui.End()
end

local function DrawHistory(tbl, isHistory)
	if settings.Options.showHistory ~= tempSettings.showHistory then
		settings.Options.showHistory = tempSettings.showHistory
		mq.pickle(configFile, settings)
	end
	ImGui.SetWindowFontScale(tempSettings.fontScale)
	if #tbl > 0 then
		if ImGui.BeginTable("Battles", 9, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable,
				ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.ScrollY)) then
			ImGui.TableSetupScrollFreeze(0, 1)
			ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.None)
			ImGui.TableSetupColumn("Battle", ImGuiTableColumnFlags.None)
			ImGui.TableSetupColumn("DPS", ImGuiTableColumnFlags.None)
			ImGui.TableSetupColumn("Dur", ImGuiTableColumnFlags.None)
			ImGui.TableSetupColumn("Avg.", ImGuiTableColumnFlags.None)
			ImGui.TableSetupColumn("Crit Dmg", ImGuiTableColumnFlags.None)
			ImGui.TableSetupColumn("Dots", ImGuiTableColumnFlags.None)
			ImGui.TableSetupColumn("Crit Heals", ImGuiTableColumnFlags.None)
			ImGui.TableSetupColumn("Total", ImGuiTableColumnFlags.None)
			ImGui.TableSetupScrollFreeze(0, 1)
			ImGui.TableHeadersRow()

			for index, data in ipairs(tbl) do
				ImGui.PushID(index)
				local seq = ((data.sequence == -1 or data.sequence == 999999 or data.sequence == -2) and
					"Current" or (data.sequence == -3 and "Last") or data.sequence)

				local textColor = color.white
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				local labelName = data.name ~= nil and data.name or Module.CharLoaded

				textColor = labelName == Module.CharLoaded and color.teal or color.white

				ImGui.PushStyleColor(ImGuiCol.Text, textColor)
				local selected, pressed = false, false
				selected, pressed = ImGui.Selectable(labelName, selected, ImGuiSelectableFlags.SpanAllColumns)
				if pressed then
					dataWinData["data"] = data
					dataWinData["seq"] = seq
					dataWinData['labelName'] = (isHistory and seq ~= "Current") and string.format("%s_%s", labelName, seq) or labelName
					showDataWin = true
				end
				if ImGui.IsItemHovered() then
					ImGui.SetTooltip("Click to view %s details.", labelName)
				end
				ImGui.PopStyleColor()
				ImGui.TableNextColumn()
				textColor = seq == "Current" and color.yellow or color.orange
				ImGui.TextColored(textColor, "%s", seq)
				ImGui.TableNextColumn()
				ImGui.Text(cleanNumber(data.dps, 1, true))
				ImGui.TableNextColumn()
				ImGui.Text("%.0f", data.dur)
				ImGui.TableNextColumn()
				ImGui.Text(cleanNumber(data.avg, 1, true))
				ImGui.TableNextColumn()
				ImGui.Text(cleanNumber(data.crit, 2))
				ImGui.TableNextColumn()
				ImGui.Text(cleanNumber(data.dot, 2))
				ImGui.TableNextColumn()
				ImGui.Text(cleanNumber(data.critHeals, 1))
				ImGui.TableNextColumn()
				ImGui.Text(cleanNumber(data.dmg, 2))
				ImGui.PopID()
			end
			ImGui.EndTable()
		end
	end
end

local function DrawButtons()
	local changedSettings = false

	local btnLabel = started and "Stop" or "Start"
	if ImGui.Button(btnLabel) then
		if started then
			started = false
			clickThrough = false
		else
			clickThrough = true
			started = true
		end
		tempSettings.autoStart = started
		changedSettings = true
	end
	if ImGui.IsItemHovered() then
		ImGui.SetTooltip("%s the DPS Window.", btnLabel)
	end

	ImGui.SameLine()

	local btnLabel2 = tempSettings.showCombatWindow and "Hide" or "Show"
	if ImGui.Button(btnLabel2) then
		tempSettings.showCombatWindow = not tempSettings.showCombatWindow
		changedSettings = true
	end
	if ImGui.IsItemHovered() then
		ImGui.SetTooltip("%s the DPS Window.", btnLabel2)
	end

	for k, v in pairs(tempSettings or {}) do
		if settings.Options[k] ~= nil then
			settings.Options[k] = v
			changedSettings = true
		end
	end
	if changedSettings then
		mq.pickle(configFile, settings)
		changedSettings = false
	end
end

local function DrawColorOptions()
	if ImGui.CollapsingHeader("Color Key") then
		if ImGui.BeginTable("Color Key", 2, ImGuiTableFlags.Borders) then
			for type, color in pairs(settings.MeleeColors) do
				ImGui.TableNextColumn()
				settings.MeleeColors[type] = ImGui.ColorEdit4(type, color, bit32.bor(ImGuiColorEditFlags.NoInputs, ImGuiColorEditFlags.AlphaBar))
				ImGui.SameLine()
				ImGui.HelpMarker(string.format("Set the color for %s messages.", type))
			end
			ImGui.EndTable()
		end
		ImGui.SeparatorText("Window Background Color")
		settings.Options.bgColor = ImGui.ColorEdit4("Background Color", settings.Options.bgColor, bit32.bor(ImGuiColorEditFlags.NoInputs, ImGuiColorEditFlags.AlphaBar))
		if tempSettings.bgColor ~= settings.Options.bgColor then
			tempSettings.bgColor = settings.Options.bgColor
		end
		ImGui.SameLine()
		ImGui.HelpMarker("Set the background color of the window.")
		ImGui.SameLine()
		if ImGui.Button("BG Preview") then
			previewBG = not previewBG
		end
	end
end

local function DrawOptions()
	DrawColorOptions()

	if ImGui.CollapsingHeader("Options") then
		local col = ((ImGui.GetWindowContentRegionWidth() - 20) / 300) > 1 and ((ImGui.GetWindowContentRegionWidth() - 20) / 300) or 1
		tempSettings.OutputTab = ImGui.InputText("OutputTab##", tempSettings.OutputTab)
		ImGui.SameLine()
		ImGui.HelpMarker("Set the output tab for DPS Reports.")

		local tmpTimer = tempSettings.dpsTimeSpanReportTimer / 60
		ImGui.SetNextItemWidth(120)
		tmpTimer = ImGui.SliderFloat("DPS Report Timer (minutes)", tmpTimer, 0.5, 60, "%.2f")
		ImGui.SameLine()
		ImGui.HelpMarker("Set the time span for DPS Over Time Span Reporting.")
		ImGui.SetNextItemWidth(120)
		tempSettings.battleDuration = ImGui.InputInt("Battle Duration End Delay", tempSettings.battleDuration)
		ImGui.SameLine()
		ImGui.HelpMarker(
			"Set the time in seconds to make sure we dont enter combat again.\n This will allow Battle Reports to handle toons that have long delay's between engaging the next mob.")

		ImGui.SetNextItemWidth(120)
		tempSettings.displayTime = ImGui.SliderInt("Display Time", tempSettings.displayTime, 1, 60)
		ImGui.SameLine()
		ImGui.HelpMarker("Set the time in seconds to display the damage.")

		ImGui.SetNextItemWidth(120)
		tempSettings.fontScale = ImGui.SliderFloat("Font Scale", tempSettings.fontScale, 0.5, 2, "%.2f")
		ImGui.SameLine()
		ImGui.HelpMarker("Set the font scale for the Report window.")

		ImGui.SetNextItemWidth(120)
		tempSettings.spamFontScale = ImGui.SliderFloat("Spam Font Scale", tempSettings.spamFontScale, 0.5, 2, "%.2f")
		ImGui.SameLine()
		ImGui.HelpMarker("Set the font scale for the CombatSpam window.")
	end
	if ImGui.CollapsingHeader("Toggles") then
		local colToggles = ((ImGui.GetWindowContentRegionWidth() - 20) / 300) > 1 and ((ImGui.GetWindowContentRegionWidth() - 20) / 300) or 1
		if ImGui.BeginTable("Options", colToggles, ImGuiTableFlags.Borders) then
			ImGui.TableNextColumn()

			tempSettings.showHistory = Module.Utils.DrawToggle("Show Battle History", tempSettings.showHistory, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Show the Battle History Window.")
			ImGui.TableNextColumn()
			tempSettings.showCombatWindow = Module.Utils.DrawToggle("Show Combat Spam History", tempSettings.showCombatWindow, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Show the Combat Spam Window.")
			ImGui.TableNextColumn()
			tempSettings.showType = Module.Utils.DrawToggle("Show Type", tempSettings.showType, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Show the type of attack.")
			ImGui.TableNextColumn()
			tempSettings.showTarget = Module.Utils.DrawToggle("Show Target", tempSettings.showTarget, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Show the target of the attack. or YOU MISS")
			ImGui.TableNextColumn()
			tempSettings.sortNewest = Module.Utils.DrawToggle("Sort Newest Combat Spam on top", tempSettings.sortNewest, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Sort Combat Spam the newest on top.")
			ImGui.TableNextColumn()
			tempSettings.sortHistory = Module.Utils.DrawToggle("Sort Newest History on top", tempSettings.sortHistory, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Sort Battle History Table the newest on top.")
			ImGui.TableNextColumn()
			tempSettings.sortParty = Module.Utils.DrawToggle("Sort Party DPS on top", tempSettings.sortParty, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Sort Party DPS the highest on top. Refrehses at about 30fps so you can read it otherwise its jumps around to fast")
			ImGui.TableNextColumn()
			tempSettings.showMyMisses = Module.Utils.DrawToggle("Show My Misses", tempSettings.showMyMisses, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Show your misses.")
			ImGui.TableNextColumn()
			tempSettings.showMissMe = Module.Utils.DrawToggle("Show Missed Me", tempSettings.showMissMe, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Show NPC missed you.")
			ImGui.TableNextColumn()
			tempSettings.showHitMe = Module.Utils.DrawToggle("Show Hit Me", tempSettings.showHitMe, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Show NPC hit you.")
			ImGui.TableNextColumn()
			tempSettings.showCritHeals = Module.Utils.DrawToggle("Show Crit Heals", tempSettings.showCritHeals, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Show Critical Heals.")
			ImGui.TableNextColumn()
			tempSettings.showDS = Module.Utils.DrawToggle("Show Damage Shield", tempSettings.showDS, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Show Damage Shield Spam Damage.")
			ImGui.TableNextColumn()
			tempSettings.dpsTimeSpanReport = Module.Utils.DrawToggle("Do DPS over Time Reporting", tempSettings.dpsTimeSpanReport, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Report DPS over a set time span.")
			ImGui.TableNextColumn()
			tempSettings.dpsBattleReport = Module.Utils.DrawToggle("Do DPS Battle Reporting", tempSettings.dpsBattleReport, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Report DPS For last Battle.")
			ImGui.TableNextColumn()
			tempSettings.announceDNET = Module.Utils.DrawToggle("Announce to DanNet Group", tempSettings.announceDNET, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Announce DPS Reports to DanNet Group.")
			ImGui.TableNextColumn()
			tempSettings.announceActors = Module.Utils.DrawToggle("Announce to Actors", tempSettings.announceActors, ToggleFlags, ImVec2(46, 20))
			ImGui.SameLine()
			ImGui.HelpMarker("Announce DPS Battle Reports to Actors.")
			ImGui.EndTable()
		end
	end

	if ImGui.CollapsingHeader("Theme Setting") then
		ImGui.Text("Cur Theme: %s", themeName)
		-- Combo Box Load Theme
		if ImGui.BeginCombo("Load Theme##DialogDB", themeName) then
			for k, data in pairs(Module.Theme.Theme) do
				local isSelected = data.Name == themeName
				if ImGui.Selectable(data.Name, isSelected) then
					tempSettings.useTheme = data.Name
					themeName = tempSettings.useTheme
				end
			end
			ImGui.EndCombo()
		end

		if ImGui.Button('Reload Theme File') then
			loadThemeTable()
		end

		ImGui.SameLine()
		if loadedExeternally then
			if ImGui.Button('Edit ThemeZ') then
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
	end
	DrawButtons()
end

function Module.RenderGUI()
	if not Module.IsRunning then return end

	-- Combat Spam
	if tempSettings.showCombatWindow then
		ImGui.SetNextWindowSize(400, 200, ImGuiCond.FirstUseEver)
		local bgColor = tempSettings.bgColor
		if previewBG or started then
			ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(bgColor[1], bgColor[2], bgColor[3], bgColor[4]))
		else
			ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(0.1, 0.1, 0.1, 0.9))
		end
		local isWindowOpen, showWin = ImGui.Begin(Module.Name .. "##" .. Module.CharLoaded, true, winFlags)
		if not isWindowOpen then
			Module.IsRunning = false
		end
		if showWin then
			ImGui.SetWindowFontScale(tempSettings.spamFontScale)
			if not started then
				ImGui.PushTextWrapPos((ImGui.GetWindowContentRegionWidth() - 20) or 20)
				ImGui.Text("This will show the last %d seconds of YOUR melee attacks.", tempSettings.displayTime)
				ImGui.TextColored(color.orange, "WARNING The window is click through after you start.")
				ImGui.Text("You can Toggle Moving the window with /mydps move.")
				ImGui.Text("You can Toggle the This Screen with /mydps ui. Which will allow you to resize the window again")
				ImGui.Text("run /mydps help for a list of commands.")
				ImGui.Text("Click Start to enable.")
				ImGui.PopTextWrapPos()
				ImGui.Separator()
				DrawColorOptions()
				DrawButtons()
			else
				ImGui.PushTextWrapPos((ImGui.GetWindowContentRegionWidth() - 2) or 20)
				if tableSize > 0 and workingTable ~= nil then
					for i, v in ipairs(workingTable) do
						local color = checkColor(v.type)
						local output = ""

						if settings.Options.showType and v.type ~= nil then
							output = output .. " " .. v.type
						end

						if settings.Options.showTarget and v.target ~= nil then
							output = output .. " " .. v.target
						end

						if v.damage ~= nil then
							output = output .. " " .. v.damage
							ImGui.TextColored(ImVec4(color[1], color[2], color[3], color[4]), "%s", output)
						end
					end
				end
				ImGui.PopTextWrapPos()
			end
			ImGui.PopStyleColor()
			ImGui.SetWindowFontScale(1)
		end
		ImGui.End()
	end

	-- Battle History Window
	if tempSettings.showHistory then
		local ColorCount, StyleCount = Module.ThemeLoader.StartTheme(tempSettings.useTheme, Module.Theme)
		ImGui.SetNextWindowSize(400, 200, ImGuiCond.FirstUseEver)
		local openReport, showReport = ImGui.Begin("DPS Report##" .. Module.CharLoaded, true, ImGuiWindowFlags.None)
		if not openReport then
			tempSettings.showHistory = false
			settings.Options.showHistory = false
			mq.pickle(configFile, settings)
			Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayShow Battle History set to %s\ax", Module.Name, tempSettings.showHistory)
		end
		if showReport then
			if ImGui.BeginTabBar("MyDPS##") then
				if ImGui.BeginTabItem("My History") then
					DrawHistory(battlesHistory, true)
					ImGui.EndTabItem()
				end
				if settings.Options.announceActors and ImGui.BeginTabItem("Party") then
					DrawHistory(actorsWorking)
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem("Config") then
					DrawOptions()
					ImGui.EndTabItem()
				end
				ImGui.EndTabBar()
			end
		end
		Module.ThemeLoader.EndTheme(ColorCount, StyleCount)
		ImGui.End()
	end

	if showDataWin then
		if dataWinData.labelName ~= nil then
			dataWindows[dataWinData.labelName] = { data = dataWinData.data, seq = dataWinData.seq, }
			dataWinData = {
				data = {},
				seq = nil,
				labelName = nil,
			}
		end
		for k, v in pairs(dataWindows) do
			ShowData(k, v.data, v.seq)
		end
	end
end

local function pHelp()
	local help = {
		[1] = string.format("\aw[\at%s\ax] \ayCommands\ax", Module.Name)
		,
		[2] = string.format("\aw[\at%s\ax] \ay/lua run mydps\ax - Run the script.", Module.Name)
		,
		[3] = string.format("\aw[\at%s\ax] \ay/lua run mydps start\ax - Run and Start, bypassing the Options Display.", Module.Name)
		,
		[4] = string.format("\aw[\at%s\ax] \ay/lua run mydps start hide\ax - Run and Start, bypassing the Options Display and Hides the Spam Window.", Module.Name)
		,
		[5] = string.format("\aw[\at%s\ax] \ay/mydps start\ax - Start the DPS window.", Module.Name)
		,
		[6] = string.format("\aw[\at%s\ax] \ay/mydps exit\ax - Exit the script.", Module.Name)
		,
		[7] = string.format("\aw[\at%s\ax] \ay/mydps ui\ax - Toggle the Options UI.", Module.Name)
		,
		[8] = string.format("\aw[\at%s\ax] \ay/mydps hide\ax - Toggles show|hide of the Damage Spam Window.", Module.Name)
		,
		[9] = string.format("\aw[\at%s\ax] \ay/mydps clear\ax - Clear the data.", Module.Name)
		,
		[10] = string.format("\aw[\at%s\ax] \ay/mydps showtype\ax - Toggle Showing the type of attack.", Module.Name)
		,
		[11] = string.format("\aw[\at%s\ax] \ay/mydps showtarget\ax - Toggle Showing the Target of the attack.", Module.Name)
		,
		[12] = string.format("\aw[\at%s\ax] \ay/mydps showds\ax - Toggle Showing damage shield.", Module.Name)
		,
		[13] = string.format("\aw[\at%s\ax] \ay/mydps history\ax - Toggle the battle history window.", Module.Name)
		,
		[14] = string.format("\aw[\at%s\ax] \ay/mydps mymisses\ax - Toggle Showing my misses.", Module.Name)
		,
		[15] = string.format("\aw[\at%s\ax] \ay/mydps missed-me\ax - Toggle Showing NPC missed me.", Module.Name)
		,
		[16] = string.format("\aw[\at%s\ax] \ay/mydps hitme\ax - Toggle Showing NPC hit me.", Module.Name)
		,
		[17] = string.format("\aw[\at%s\ax] \ay/mydps sort [new|old]\ax - Sort Toggle newest on top. [new|old] arguments optional so set direction", Module.Name)
		,
		[18] = string.format("\aw[\at%s\ax] \ay/mydps sorthistory [new|old]\ax - Sort history Toggle newest on top. [new|old] arguments optional so set direction", Module.Name)
		,
		[19] = string.format("\aw[\at%s\ax] \ay/mydps settings\ax - Print current settings to console.", Module.Name)
		,
		[20] = string.format("\aw[\at%s\ax] \ay/mydps doreporting [all|battle|time]\ax - Toggle DPS Auto DPS reporting on for 'Battles, Time based, or BOTH'.", Module.Name)
		,
		[21] = string.format("\aw[\at%s\ax] \ay/mydps report\ax - Report the Time Based DPS since Last Report.", Module.Name)
		,
		[22] = string.format("\aw[\at%s\ax] \ay/mydps battlereport\ax - Report the battle history to console.", Module.Name)
		,
		[23] = string.format("\aw[\at%s\ax] \ay/mydps announce\ax - Toggle Announce to DanNet Group.", Module.Name)
		,
		[24] = string.format("\aw[\at%s\ax] \ay/mydps move\ax - Toggle click through, allows moving of window.", Module.Name)
		,
		[25] = string.format("\aw[\at%s\ax] \ay/mydps delay #\ax - Set the combat spam display time in seconds.", Module.Name)
		,
		[26] = string.format("\aw[\at%s\ax] \ay/mydps battledelay #\ax - Set the Battle ending Delay time in seconds.", Module.Name)
		,
		[27] = string.format("\aw[\at%s\ax] \ay/mydps help\ax - Show this help.", Module.Name)
		,
	}
	for i = 1, #help do
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, help[i])
	end
end

local function pCurrentSettings()
	local msg = ''
	for k, v in pairs(settings.Options) do
		if k == "bgColor" then
			msg = string.format("\aw[\at%s\ax] \ay%s\ax = {\ar%s\ax, \ag%s\ax, \at%s\ax,\ao %s\ax}", Module.Name, k, v[1], v[2], v[3], v[4])
			Module.Utils.PrintOutput(tempSettings.OutputTab, nil, msg)
		else
			msg = string.format("\aw[\at%s\ax] \ay%s\ax = \at%s", Module.Name, k, v)
			Module.Utils.PrintOutput(tempSettings.OutputTab, nil, msg)
		end
	end
end

local function announceDanNet(msg)
	if settings.Options.announceDNET then
		mq.cmdf("/squelch /dgt %s", msg)
	end
end

---comment
---@param dur integer @ duration in seconds
---@param rType string @ type of report (ALL, COMBAT)
local function pDPS(dur, rType)
	if dur == nil then
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayNothing to Report! Try again later.", Module.Name)
		return
	end
	if rType:lower() == "all" then
		local dps          = dur > 0 and (dmgTotal / dur) or 0
		local dpsDS        = dur > 0 and (dmgTotalDS / dur) or 0
		local avgDmg       = dmgCounter > 0 and (dmgTotal / dmgCounter) or 0
		local grandTotal   = dmgTotal + dmgTotalDS
		local grandCounter = dmgCounter + dsCounter
		local grangAvg     = grandCounter > 0 and (grandTotal / grandCounter) or 0
		local grandDPS     = dur > 0 and (grandTotal / dur) or 0
		local msgNoDS      = string.format(
			"\aw[\at%s\ax] \ayDPS \ax(\aoNO DS\ax): \at%.2f\ax, \ayTimeSpan:\ax\ao %.2f min\ax, \ayTotal Damage: \ax\ao%d\ax, \ayTotal Attempts: \ax\ao%d\ax, \ayAverage: \ax\ao%d\ax",
			Module.Name, dps, (dur / 60), dmgTotal, dmgCounter, avgDmg)
		local msgDS        = string.format(
			"\aw[\at%s\ax] \ayDPS \ax(\atDS Dmg\ax): \at%.2f\ax, \ayTimeSpan: \ax\ao%.2f min\ax, \ayTotal Damage: \ax\ao%d\ax, \ayTotal Hits: \ax\ao%d\ax",
			Module.Name, dpsDS, (dur / 60), dmgTotalDS, dsCounter)
		local msgALL       = string.format(
			"\aw[\at%s\ax] \ayDPS \ax(\agALL\ax): \ag%.2f\ax, \ayTimeSpan: \ax\ao%.2f min\ax, \ayTotal Damage: \ax\ao%d\ax, \ayTotal Attempts: \ax\ao%d\ax, \ayAverage:\ax \ao%d\ax",
			Module.Name, grandDPS, (dur / 60), grandTotal, grandCounter, grangAvg)

		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, msgNoDS)
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, msgDS)
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, msgALL)

		if settings.Options.announceDNET then
			announceDanNet(msgNoDS)
			announceDanNet(msgDS)
			announceDanNet(msgALL)
		end
		dmgTotal     = 0
		dmgCounter   = 0
		dmgTotalDS   = 0
		dsCounter    = 0
		dpsStartTime = os.time()
	elseif rType:lower() == 'combat' then
		local dps     = dur > 0 and (dmgTotalBattle / dur) or 0
		local avgDmg  = dmgBattCounter > 0 and (dmgTotalBattle / dmgBattCounter) or 0
		battleCounter = battleCounter + 1
		table.insert(battlesHistory, {
			sequence = battleCounter,
			dps = dps,
			dur = dur,
			dmg = dmgTotalBattle,
			avg = avgDmg,
			crit = critTotalBattle,
			critHeals = critHealsTotal,
			dot = dotTotalBattle,
		})
		if settings.Options.dpsBattleReport then
			local msg = string.format(
				"\aw[\at%s\ax] \ayChar:\ax\ao %s\ax, \ayDPS \ax(\aoBATTLE\ax): \at%s\ax, \ayTimeSpan:\ax\ao %.0f sec\ax, \ayTotal Damage: \ax\ao%s\ax, \ayAvg. Damage: \ax\ao%s\ax",
				Module.Name, Module.CharLoaded, cleanNumber(dps, 1, true), dur, cleanNumber(dmgTotalBattle, 2), cleanNumber(avgDmg, 1, true))
			Module.Utils.PrintOutput(tempSettings.OutputTab, nil, msg)
			if settings.Options.announceDNET then
				announceDanNet(msg)
			end
		end
		if settings.Options.announceActors and ActorDPS ~= nil then
			local msgSend = {
				Name = Module.CharLoaded,
				Subject = 'Update',
				Leader = MyLeader,
				BattleNum = -3,
				DPS = dps,
				TimeSpan = dur,
				TotalDmg = dmgTotalBattle,
				AvgDmg = avgDmg,
				Remove = false,
				Crit = critTotalBattle,
				CritHeals = critHealsTotal,
				Dot = dotTotalBattle,
			}
			ActorDPS:send({ mailbox = 'my_dps', script = 'mydps', }, (msgSend))
			ActorDPS:send({ mailbox = 'my_dps', script = 'myui', }, (msgSend))
			for k, v in ipairs(actorsTable) do
				if v.name == Module.CharLoaded then
					v.name      = Module.CharLoaded
					v.sequence  = -3
					v.dps       = dps
					v.dur       = dur
					v.dmg       = dmgTotalBattle
					v.crit      = critTotalBattle
					v.critHeals = critHealsTotal
					v.dot       = dotTotalBattle
					v.avg       = avgDmg
					break
				end
			end
		end
		dmgTotalBattle = 0
		dotTotalBattle = 0
		battlesHistory = sortTable(battlesHistory, 'history')
	end
end

local function pBattleHistory()
	if battleCounter == 0 then
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayNo Battle History\ax", Module.Name)
		return
	end
	for i, v in ipairs(battlesHistory) do
		local msg = string.format(
			"\aw[\at%s\ax] \ayChar:\ax\ao %s\ax, \ayBattle: \ax\ao%d\ax, \ayDPS: \ax\at%s\ax, \ayDuration: \ax\ao%s sec\ax, \ayTotal Damage: \ax\ao%s\ax, \ayAvg. Damage: \ax\ao%s\ax",
			Module.Name, Module.CharLoaded, v.sequence, cleanNumber(v.dps, 1, true), v.dur, cleanNumber(v.dmg, 2), cleanNumber(v.avg, 1, true))
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, msg)
		if settings.Options.announceDNET then
			announceDanNet(msg)
		end
	end
end

local function processCommand(...)
	local args = { ..., }
	if #args == 0 then
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \arInvalid command, \ayType /mydps help for a list of commands.", Module.Name)
		return
	end
	local cmd = args[1]
	cmd = cmd:lower()
	if cmd == "exit" then
		Module.IsRunning = false
	elseif cmd == "ui" then
		started = false
		tempSettings.showCombatWindow = true
		winFlags = bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.NoTitleBar)
	elseif cmd == "hide" then
		if #args == 2 then
			if args[2] == 'on' then
				tempSettings.showCombatWindow = false
			elseif args[2] == 'off' then
				tempSettings.showCombatWindow = true
			end
		end
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayToggle Combat Spam set to %s\ax", Module.Name, tempSettings.showCombatWindow)
	elseif cmd == "clear" then
		damTable, battlesHistory             = {}, {}
		battleStartTime, dpsStartTime        = 0, 0
		dmgTotal, dmgCounter, dsCounter      = 0, 0, 0
		dmgTotalDS, battleCounter, tableSize = 0, 0, 0
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayTable Cleared\ax", Module.Name)
	elseif cmd == 'start' then
		started = true
		clickThrough = true
		winFlags = bit32.bor(ImGuiWindowFlags.NoMouseInputs, ImGuiWindowFlags.NoDecoration)
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayStarted\ax", Module.Name)
	elseif cmd == 'showtype' then
		if #args == 2 then
			if args[2] == 'on' then
				tempSettings.showType = true
			elseif args[2] == 'off' then
				tempSettings.showType = false
			end
		else
			tempSettings.showType = not tempSettings.showType
		end
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayShow Type set to %s\ax", Module.Name, tempSettings.showType)
	elseif cmd == 'showtarget' then
		if #args == 2 then
			if args[2] == 'on' then
				tempSettings.showTarget = true
			elseif args[2] == 'off' then
				tempSettings.showTarget = false
			end
		else
			tempSettings.showTarget = not tempSettings.showTarget
		end
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayShow Target set to %s\ax", Module.Name, tempSettings.showTarget)
	elseif cmd == 'showds' then
		if #args == 2 then
			if args[2] == 'on' then
				tempSettings.showDS = true
			elseif args[2] == 'off' then
				tempSettings.showDS = false
			end
		else
			tempSettings.showDS = not tempSettings.showDS
		end
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayShow Damage Shield set to %s\ax", Module.Name, tempSettings.showDS)
	elseif cmd == 'history' then
		if #args == 2 then
			if args[2] == 'on' then
				tempSettings.showHistory = true
			elseif args[2] == 'off' then
				tempSettings.showHistory = false
			end
		else
			tempSettings.showHistory = not tempSettings.showHistory
		end
		tempSettings.showHistory = tempSettings.showHistory
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayShow Battle History set to %s\ax", Module.Name, tempSettings.showHistory)
	elseif cmd == 'mymisses' then
		if #args == 2 then
			if args[2] == 'on' then
				tempSettings.showMyMisses = true
			elseif args[2] == 'off' then
				tempSettings.showMyMisses = false
			end
		else
			tempSettings.showMyMisses = not tempSettings.showMyMisses
		end
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayShow My Misses set to %s\ax", Module.Name, tempSettings.showMyMisses)
	elseif cmd == 'missed-me' then
		if #args == 2 then
			if args[2] == 'on' then
				tempSettings.showMissMe = true
			elseif args[2] == 'off' then
				tempSettings.showMissMe = false
			end
		else
			tempSettings.showMissMe = not tempSettings.showMissMe
		end
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayShow Missed Me set to %s\ax", Module.Name, tempSettings.showMissMe)
	elseif cmd == 'hitme' then
		if #args == 2 then
			if args[2] == 'on' then
				tempSettings.showHitMe = true
			elseif args[2] == 'off' then
				tempSettings.showHitMe = false
			end
		else
			tempSettings.showHitMe = not tempSettings.showHitMe
		end
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayShow Hit Me set to %s\ax", Module.Name, tempSettings.showHitMe)
	elseif cmd == 'sort' then
		if #args == 2 then
			if args[2] == 'new' then
				tempSettings.sortNewest = true
			elseif args[2] == 'old' then
				tempSettings.sortNewest = false
			end
		else
			tempSettings.sortNewest = not tempSettings.sortNewest
		end
		local dir = tempSettings.sortNewest and "Newest" or "Oldest"
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \aySort Combat Spam\ax \at%s \axOn Top!", Module.Name, dir)
	elseif cmd == 'sorthistory' then
		if #args == 2 then
			if args[2] == 'new' then
				tempSettings.sortHistory = true
			elseif args[2] == 'old' then
				tempSettings.sortHistory = false
			end
		else
			tempSettings.sortHistory = not tempSettings.sortHistory
		end
		battlesHistory = sortTable(battlesHistory, 'history')
		local dir = tempSettings.sortHistory and "Newest" or "Oldest"
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \aySorted Battle History\ax \at%s \axOn Top!", Module.Name, dir)
	elseif cmd == 'move' then
		clickThrough = not clickThrough
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayClick Through set to %s\ax", Module.Name, clickThrough)
	elseif cmd == 'settings' then
		pCurrentSettings()
	elseif cmd == 'report' then
		local dur = os.time() - dpsStartTime
		pDPS(dur, 'ALL')
	elseif cmd == 'battlereport' then
		pBattleHistory()
	elseif cmd == 'announce' then
		if #args == 2 then
			if args[2] == 'on' then
				tempSettings.announceDNET = true
			elseif args[2] == 'off' then
				tempSettings.announceDNET = false
			end
		else
			tempSettings.announceDNET = not tempSettings.announceDNET
		end
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayAnnounce to DanNet Group set to %s\ax", Module.Name, tempSettings.announceDNET)
	elseif #args == 2 and cmd == 'doreporting' then
		if args[2] == 'battle' then
			tempSettings.dpsBattleReport = not tempSettings.dpsBattleReport
			Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayDo DPS Battle Reporting set to %s\ax", Module.Name, tempSettings.dpsBattleReport)
		elseif args[2] == 'time' then
			tempSettings.dpsTimeSpanReport = not tempSettings.dpsTimeSpanReport
			Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayDo DPS Reporting set to %s\ax", Module.Name, tempSettings.dpsTimeSpanReport)
		elseif args[2] == 'all' then
			tempSettings.dpsBattleReport = not tempSettings.dpsBattleReport
			tempSettings.dpsTimeSpanReport = tempSettings.dpsBattleReport
			Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayDo DPS Reporting set to %s\ax", Module.Name, tempSettings.dpsTimeSpanReport)
		else
			Module.Utils.PrintOutput(tempSettings.OutputTab, nil,
				"\aw[\at%s\ax] \arInvalid argument, \ayType \at/mydps doreporting\ax takes arguments \aw[\agall\aw|\agbattle\aw|\agtime\aw] \ayplease try again.", Module.Name)
		end
	elseif #args == 2 and cmd == "delay" then
		if tonumber(args[2]) then
			tempSettings.displayTime = tonumber(args[2])
			Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayDisplay time set to %s\ax", Module.Name, tempSettings.displayTime)
		else
			Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \arInvalid argument, \ayType /mydps help for a list of commands.", Module.Name)
		end
	elseif #args == 2 and cmd == "battledelay" then
		if tonumber(args[2]) then
			tempSettings.battleDuration = tonumber(args[2])
			Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayBattle Duration time set to %s\ax", Module.Name, tempSettings.battleDuration)
		else
			Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \arInvalid argument, \ayType /mydps help for a list of commands.", Module.Name)
		end
	elseif cmd == "help" then
		pHelp()
	else
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \arUnknown command, \ayType /mydps help for a list of commands.", Module.Name)
	end
	local changed = false
	for k, v in pairs(tempSettings) do
		settings.Options[k] = v
		changed = true
	end
	if changed then
		mq.pickle(configFile, settings)
	end
end

--create mailbox for actors to send messages to
local function RegisterActor()
	ActorDPS = Module.Actor.register(Module.ActorMailBox, function(message)
		local MemberEntry  = message()
		local who          = MemberEntry.Name
		local leader       = MemberEntry.Leader or 'None'
		local timeSpan     = MemberEntry.TimeSpan or 0
		local avgDmg       = MemberEntry.AvgDmg or 0
		local dps          = MemberEntry.DPS or 0
		local totalDmg     = MemberEntry.TotalDmg or 0
		local battleNum    = MemberEntry.BattleNum or 0
		local critDmg      = MemberEntry.Crit or 0
		local critHealsAmt = MemberEntry.CritHeals or 0
		local dotDmg       = MemberEntry.Dot or 0
		local report       = MemberEntry.Report or ''
		if who == Module.CharLoaded then return end
		if MyLeader ~= 'None' and leader ~= MyLeader then return end

		if #actorsTable == 0 then
			table.insert(actorsTable, {
				name = who,
				leader = leader,
				dps = dps,
				avg = avgDmg,
				dmg = totalDmg,
				dot = dotDmg,
				dur = timeSpan,
				sequence = battleNum,
				crit = critDmg,
				critHeals = critHealsAmt,
			})
		else
			local found = false
			for i = 1, #actorsTable do
				if actorsTable[i].name == who then
					if MemberEntry.Remove then
						table.remove(actorsTable, i)
					else
						actorsTable[i].name      = who
						actorsTable[i].leader    = leader
						actorsTable[i].dps       = dps
						actorsTable[i].avg       = avgDmg
						actorsTable[i].dmg       = totalDmg
						actorsTable[i].dur       = timeSpan
						actorsTable[i].crit      = critDmg
						actorsTable[i].dot       = dotDmg
						actorsTable[i].critHeals = critHealsAmt
						actorsTable[i].sequence  = battleNum
					end
					found = true
					break
				end
			end
			if not found then
				table.insert(actorsTable, {
					name = who,
					leader = leader,
					dps = dps,
					avg = avgDmg,
					dmg = totalDmg,
					dot = dotDmg,
					dur = timeSpan,
					sequence = battleNum,
					crit = critDmg,
					critHeals = critHealsAmt,
				})
			end
		end
		if report ~= '' and who ~= Module.CharLoaded then
			Module.Utils.PrintOutput(tempSettings.OutputTab, nil, report)
		end
	end)
end

function Module.Unload()
	mq.unevent("melee_crit")
	mq.unevent("melee_crit2")
	mq.unevent("melee_crit3")
	mq.unevent("melee_deadly_strike")
	mq.unevent("melee_non_melee")
	mq.unevent("melee_damage_shield")
	mq.unevent("melee_you_hit_non-melee")
	mq.unevent("melee_do_damage")
	mq.unevent("melee_miss")
	mq.unevent("melee_got_hit")
	mq.unevent("melee_missed_me")
	mq.unevent("melee_crit_heal")
	mq.unevent("melee_damage_dot")
	if Module.TempSettings.petLoaded then
		mq.unevent("melee_pet_damage")
		mq.unevent("melee_pet_non_melee")
	end
	mq.unbind("/mydps")
end

local Arguments = { ..., }

local function CheckArgs(args)
	if args[1] ~= nil and args[1] == "start" then
		if #args == 2 and args[2] == 'hide' then
			tempSettings.showCombatWindow = false
		end
		started = true
		clickThrough = true
		winFlags = bit32.bor(ImGuiWindowFlags.NoMouseInputs, ImGuiWindowFlags.NoDecoration)
		Module.Utils.PrintOutput(tempSettings.OutputTab, nil, "\aw[\at%s\ax] \ayStarted\ax", Module.Name)
	end
end

local function petEvent()
	if Module.PetName ~= 'NoPet' then
		local str = string.format("#*#%s #1# #2# for #3# points of damage#*#", Module.PetName)
		mq.event("melee_pet_damage", str, petCallBack)
		str = string.format("#*#%s hit #1# for #2# points of non-melee damage#*#", Module.PetName)
		mq.event("melee_pet_non_melee", str, nonMeleePetClallBack)
		Module.TempSettings.petLoaded = true
	end
end

local function Init()
	loadSettings()

	-- Register Events
	local str = string.format("#*#%s scores a critical hit! #*#(#1#)", Module.CharLoaded)

	mq.event("melee_crit", "#*#You score a critical hit! #*#(#1#)", critCallBack)
	mq.event("melee_crit2", "#*#You deliver a critical blast! #*#(#1#)", critCallBack)
	mq.event("melee_crit3", str, critCallBack)
	str = string.format("#*#%s scores a Deadly Strike! #*#(#1#)", Module.CharLoaded)
	mq.event("melee_deadly_strike", str, critCallBack)
	str = string.format("#*#%s hit #1# for #2# points of non-melee damage#*#", Module.CharLoaded)
	mq.event("melee_non_melee", str, nonMeleeClallBack)

	mq.event('melee_damage_dot', '#1# has taken #2# damage from your #3#', dotCallBack)
	mq.event("melee_damage_shield", "#*# was hit by non-melee for #2# points of damage#*#", nonMeleeClallBack)
	mq.event("melee_you_hit_non-melee", "#*#You were hit by non-melee for #2# damage#*#", nonMeleeClallBack)
	mq.event("melee_do_damage", "#*#You #1# #2# for #3# points of damage#*#", meleeCallBack)
	mq.event("melee_miss", "#*#You try to #1# #2#, but miss#*#", meleeCallBack)
	mq.event("melee_got_hit", "#2# #1# YOU for #3# points of damage#*#", npcMeleeCallBack)
	mq.event("melee_missed_me", "#2# tries to #1# YOU, but misses#*#", npcMeleeCallBack)
	mq.event("melee_crit_heal", "#*#You perform an exceptional heal! #*#(#1#)", critHealCallBack)
	mq.bind("/mydps", processCommand)
	-- #*# has taken #1# damage from #*# by #*# -- dot dmg others
	-- #*# has taken #1# damage from your #*# -- dot dmg you
	-- Pet dmg
	petEvent()
	-- Register Actor Mailbox
	if settings.Options.announceActors then RegisterActor() end

	-- Print Help
	pHelp()

	-- Check for arguments
	if not loadedExeternally then
		CheckArgs(Arguments)
	else
		started = settings.Options.autoStart
		clickThrough = started
	end

	Module.IsRunning = true
	if not loadedExeternally then
		mq.imgui.init(Module.Name, Module.RenderGUI)
		Module.LocalLoop()
	end
end

local clockTimer = mq.gettime()

function Module.MainLoop()
	-- Main Loop
	if loadedExeternally then
		---@diagnostic disable-next-line: undefined-global
		if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
	end

	if tempSettings.doActors ~= settings.Options.announceActors then
		if settings.Options.announceActors then
			RegisterActor()
		end
		tempSettings.doActors = settings.Options.announceActors
	end

	if started then
		winFlags = clickThrough and bit32.bor(ImGuiWindowFlags.NoMouseInputs, ImGuiWindowFlags.NoDecoration) or bit32.bor(ImGuiWindowFlags.NoDecoration)
	else
		winFlags = bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.NoTitleBar)
	end

	local currentTime = os.time()
	if currentTime - dpsStartTime >= settings.Options.dpsTimeSpanReportTimer then
		mq.doevents()
		local dur = currentTime - dpsStartTime
		if settings.Options.dpsTimeSpanReport then
			pDPS(dur, 'ALL')
		end
	end

	if mq.TLO.Me.CombatState() ~= 'COMBAT' and enteredCombat then
		if leftCombatTime == 0 then
			leftCombatTime = os.time()
		end
		mq.doevents()

		local endOfCombat = os.time() - leftCombatTime
		if endOfCombat > settings.Options.battleDuration then
			enteredCombat = false
			local battleDuration = os.time() - battleStartTime - endOfCombat
			for k, v in pairs(battlesHistory) do
				if v.sequence == -1 or v.sequence == 999999 then
					table.remove(battlesHistory, k)
				end
			end
			pDPS(battleDuration, "COMBAT")
			battleStartTime = 0
			leftCombatTime = 0
		end
	end
	-- Clean up the table
	if battleStartTime > 0 then
		mq.doevents()
		parseCurrentBattle(currentTime - battleStartTime)
	end
	cleanTable()
	if firstRun then
		actorsWorking = sortTable(actorsTable, 'party')
		firstRun = false
	end
	-- if tempSettings.sortParty then
	actorsWorking = sortTable(actorsTable, 'party')
	-- else
	-- 	actorsWorking = actorsTable
	-- end
	Module.PetName = mq.TLO.Pet.DisplayName() or 'NoPet'
	if not Module.TempSettings.petLoaded and Module.PetName ~= 'NoPet' then
		petEvent()
	end

	if Module.TempSettings.petLoaded and Module.PetName == 'NoPet' then
		mq.unevent("melee_pet_damage")
		mq.unevent("melee_pet_non_melee")
		Module.TempSettings.petLoaded = false
	end

	if mq.TLO.Raid.Members() > 0 then
		MyLeader = mq.TLO.Raid.Leader.CleanName()
	elseif mq.TLO.Group.Leader() ~= nil then
		MyLeader = mq.TLO.Group.Leader.CleanName()
	else
		MyLeader = 'None'
	end

	mq.doevents()
	-- mq.delay(5)
	-- if tempSettings.sortParty then
	-- 	uiTime = uiTime + 5
	-- 	if uiTime >= 34 then
	-- 		if tempSettings.doActors then actorsWorking = sortTable(actorsTable, 'party') end
	-- 		uiTime = 0
	-- 	end
	-- end
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
