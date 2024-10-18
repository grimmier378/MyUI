-- Load Libraries
local mq = require('mq')
local sqlite3 = require('lsqlite3')
local ImGui = require('ImGui')

-- Paths
local configFile = string.format('%s/ButtonMaster.lua', mq.configDir)
local dbPath = string.format('%s/ButtonMaster.db', mq.configDir)
local RUNNING = true
local settings = {}
local globalSettings = {}
local setData = {}
local buttonData = {}
local characterData = {}
-- Database Initialization
local function initializeDB()
	local db = sqlite3.open(dbPath)
	db:exec([[
		CREATE TABLE IF NOT EXISTS settings (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			server TEXT NOT NULL,
			character TEXT NOT NULL,
			settings_button_size INTEGER NOT NULL,
			settings_version INTEGER NOT NULL,
			settings_last_backup INTEGER NOT NULL,
			UNIQUE(server, character)
		);
		CREATE TABLE IF NOT EXISTS sets (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			set_name TEXT NOT NULL,
			button_number INTEGER NOT NULL,
			button_id TEXT NOT NULL
		);
		CREATE TABLE IF NOT EXISTS buttons (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			button_number TEXT NOT NULL,
			button_label TEXT NOT NULL,
			button_render INTEGER NOT NULL,
			button_text_color TEXT,
			button_button_color TEXT,
			button_cached_countdown INTEGER,
			button_cached_cooldown INTEGER,
			button_cached_toggle_locked INTEGER,
			button_cached_last_run NUMERIC,
			button_label_mid_x INTEGER,
			button_label_mid_y INTEGER,
			button_cached_label TEXT,
			button_cmd TEXT,
			button_evaluate_label INTEGER,
			button_show_label INTEGER,
			button_icon INTEGER,
			button_icon_type TEXT,
			button_icon_lua TEXT,
			button_timer_type TEXT,
			button_cooldown TEXT
		);
		CREATE TABLE IF NOT EXISTS windows (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			server TEXT NOT NULL,
			character TEXT NOT NULL,
			window_id INTEGER NOT NULL,
			window_fps INTEGER NOT NULL,
			window_button_size INTEGER NOT NULL,
			window_advtooltip INTEGER NOT NULL,
			window_compact INTEGER NOT NULL,
			window_hide_title INTEGER NOT NULL,
			window_width INTEGER NOT NULL,
			window_height INTEGER NOT NULL,
			window_x INTEGER NOT NULL,
			window_y INTEGER NOT NULL,
			window_visible INTEGER NOT NULL,
			window_font_size INTEGER NOT NULL,
			window_locked INTEGER NOT NULL,
			window_theme TEXT NOT NULL,
			window_set_id INTEGER NOT NULL,
			window_set_name TEXT NOT NULL
		);
		CREATE TABLE IF NOT EXISTS characters (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			character TEXT NOT NULL,
			character_locked INTEGER NOT NULL,
			character_hide_title INTEGER NOT NULL
		);
	]])
	return db
end

-- Helper Functions
local function saveToDB(db, query, ...)
	local stmt = db:prepare(query)
	stmt:bind_values(...)
	stmt:step()
	stmt:finalize()
end

local function loadFromDB(db, query, ...)
	local stmt = db:prepare(query)
	stmt:bind_values(...)
	local data = {}
	for row in stmt:nrows() do
		table.insert(data, row)
	end
	stmt:finalize()
	return data
end

-- Main Function to Convert Config to DB
local function convertConfigToDB()
	local db = initializeDB()
	local config, err = loadfile(configFile)
	if err or not config then
		print("Error loading config file:", err)
		return
	end
	local newVersion = 8

	local settings = config()

	-- Save Global Settings
	saveToDB(db, "INSERT OR REPLACE INTO settings (server, character, settings_button_size, settings_version, settings_last_backup) VALUES (?, ?, ?, ?, ?)",
		"global", "global", settings.Global.ButtonSize or 0, newVersion, settings.LastBackup or 0)

	-- Save Sets
	for setName, buttons in pairs(settings.Sets) do
		for buttonNumber, buttonID in pairs(buttons) do
			saveToDB(db, "INSERT OR REPLACE INTO sets (set_name, button_number, button_id) VALUES (?, ?, ?)", setName, buttonNumber, buttonID)
		end
	end

	-- Save Buttons
	for buttonID, buttonData in pairs(settings.Buttons) do
		saveToDB(db, [[
			INSERT OR REPLACE INTO buttons (
				button_number, button_label, button_render, button_text_color, button_button_color,
				button_cached_countdown, button_cached_cooldown, button_cached_toggle_locked,
				button_cached_last_run, button_label_mid_x, button_label_mid_y, button_cached_label,
				button_cmd, button_evaluate_label, button_show_label, button_icon,
				button_icon_type, button_icon_lua, button_timer_type, button_cooldown
			) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
			buttonID, buttonData.Label or "", buttonData.highestRenderTime or 0, buttonData.TextColorRGB or "", buttonData.ButtonColorRGB or "",
			buttonData.CachedCountDown or 0, buttonData.CachedCoolDownTimer or 0, buttonData.CachedToggleLocked or 0,
			buttonData.CachedLastRan or 0, buttonData.labelMidX or 0, buttonData.labelMidY or 0, buttonData.CachedLabel or "",
			buttonData.Cmd or "", buttonData.EvaluateLabel and 1 or 0, buttonData.ShowLabel and 1 or 0, buttonData.Icon or 0,
			buttonData.IconType or "", buttonData.IconLua or "", buttonData.TimerType or "", buttonData.Cooldown or ""
		)
	end

	-- Save Character Data
	for charName, charData in pairs(settings.Characters or {}) do
		saveToDB(db, "INSERT INTO characters (character, character_locked, character_hide_title) VALUES (?, ?, ?)",
			charName, charData.Locked and 1 or 0, charData.HideTitleBar and 1 or 0)

		if charData.Windows then
			for windowID, windowData in ipairs(charData.Windows or {}) do
				windowData.Pos = windowData.Pos or { x = 0, y = 0, } -- Default position
				for setIndex, setName in ipairs(windowData.Sets or {}) do
					saveToDB(db, [[
						INSERT OR REPLACE INTO windows (
							server, character, window_id, window_fps, window_button_size, window_advtooltip,
							window_compact, window_hide_title, window_width, window_height, window_x, window_y,
							window_visible, window_font_size, window_locked, window_theme, window_set_id, window_set_name
						) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
						mq.TLO.EverQuest.Server(), charName, windowID, windowData.FPS or 0, windowData.ButtonSize or 0, windowData.AdvTooltips and 1 or 0,
						windowData.CompactMode and 1 or 0, windowData.HideTitleBar and 1 or 0, windowData.Width or 0, windowData.Height or 0,
						windowData.Pos.x or 0, windowData.Pos.y or 0, windowData.Visible and 1 or 0, windowData.Font or 0,
						windowData.Locked and 1 or 0, windowData.Theme or "", setIndex, setName
					)
				end
			end
		end
	end

	db:close()
	print("Conversion complete!")
end

-- Retrieve and Deserialize Data
local function retrieveDataFromDB()
	local db = initializeDB()
	settings = {
		Global = {},
		Version = 8,
		LastBackup = os.time(),
		Sets = {},
		Buttons = {},
		Characters = {},
	}

	local globalSettingsData = loadFromDB(db, "SELECT settings_button_size, settings_version, settings_last_backup FROM settings WHERE server='global' AND character='global'")
	if globalSettingsData[1] then
		settings.Global = {
			ButtonSize = globalSettingsData[1].settings_button_size,
		}
		settings.Version = globalSettingsData[1].settings_version
		settings.LastBackup = globalSettingsData[1].settings_last_backup
	end

	local setsData = loadFromDB(db, "SELECT set_name, button_number, button_id FROM sets")
	for _, set in ipairs(setsData) do
		settings.Sets[set.set_name] = settings.Sets[set.set_name] or {}
		settings.Sets[set.set_name][set.button_number] = set.button_id
	end

	local buttonsData = loadFromDB(db, "SELECT * FROM buttons")
	for _, button in ipairs(buttonsData) do
		settings.Buttons[button.button_number] = {
			Label = button.button_label,
			highestRenderTime = button.button_render,
			TextColorRGB = button.button_text_color,
			ButtonColorRGB = button.button_button_color,
			CachedCountDown = button.button_cached_countdown,
			CachedCoolDownTimer = button.button_cached_cooldown,
			CachedToggleLocked = button.button_cached_toggle_locked,
			CachedLastRan = button.button_cached_last_run,
			labelMidX = button.button_label_mid_x,
			labelMidY = button.button_label_mid_y,
			CachedLabel = button.button_cached_label,
			Cmd = button.button_cmd,
			EvaluateLabel = button.button_evaluate_label == 1,
			ShowLabel = button.button_show_label == 1,
			Icon = button.button_icon,
			IconType = button.button_icon_type,
			IconLua = button.button_icon_lua,
			TimerType = button.button_timer_type,
			Cooldown = button.button_cooldown,
		}
	end

	local charactersData = loadFromDB(db, "SELECT character, character_locked, character_hide_title FROM characters")
	for _, char in ipairs(charactersData) do
		settings.Characters[char.character] = {
			Locked = char.character_locked == 1,
			HideTitleBar = char.character_hide_title == 1,
			Windows = {},
		}
	end

	local windowsData = loadFromDB(db, "SELECT * FROM windows")
	for _, window in ipairs(windowsData) do
		local character = settings.Characters[window.character]
		character.Windows[window.window_id] = character.Windows[window.window_id] or {
			Sets = {},
		}
		local win = character.Windows[window.window_id]
		win.FPS = window.window_fps
		win.ButtonSize = window.window_button_size
		win.AdvTooltips = window.window_advtooltip == 1
		win.CompactMode = window.window_compact == 1
		win.HideTitleBar = window.window_hide_title == 1
		win.Width = window.window_width
		win.Height = window.window_height
		win.Pos = { x = window.window_x, y = window.window_y, }
		win.Visible = window.window_visible == 1
		win.Font = window.window_font_size
		win.Locked = window.window_locked == 1
		win.Theme = window.window_theme
		win.Sets[window.window_set_id] = window.window_set_name
	end

	return settings
end

-- Export Function
local function exportDBToLua()
	local settings = retrieveDataFromDB()
	local fileName = string.format("%s/ButtonMasterTest_BAK_%s.lua", mq.configDir, os.date("%m_%d_%Y_%H_%M"))
	mq.pickle(fileName, settings)
	print("Export complete:", fileName)
end

-- GUI Functions
local function showButtonData(buttonID, button)
	if ImGui.TreeNode(string.format("Button: %s", buttonID)) then
		for key, value in pairs(button) do
			ImGui.Text(string.format("%s: %s", key, tostring(value)))
		end
		ImGui.TreePop()
	end
end

local function showSetData(setName, set)
	if ImGui.TreeNode(string.format("Set: %s", setName)) then
		for buttonNumber, buttonID in pairs(set) do
			ImGui.Text(string.format("Button Number: %d, Button ID: %s", buttonNumber, buttonID))
		end
		ImGui.TreePop()
	end
end

local function showWindowData(windowID, window)
	if ImGui.TreeNode(string.format("Window: %d", windowID)) then
		for key, value in pairs(window) do
			if key == "Pos" then
				ImGui.Text(string.format("%s: x=%d, y=%d", key, value.x, value.y))
			elseif key == "Sets" then
				if ImGui.TreeNode("Sets") then
					for setID, setName in pairs(value) do
						ImGui.Text(string.format("Set ID: %d, Set Name: %s", setID, setName))
					end
					ImGui.TreePop()
				end
			else
				ImGui.Text(string.format("%s: %s", key, tostring(value)))
			end
		end
		ImGui.TreePop()
	end
end

local function showCharacterData(characterName, character)
	if ImGui.TreeNode(string.format("Character: %s", characterName)) then
		ImGui.Text(string.format("Locked: %s", tostring(character.Locked)))
		ImGui.Text(string.format("HideTitleBar: %s", tostring(character.HideTitleBar)))
		if ImGui.TreeNode("Windows") then
			for windowID, window in pairs(character.Windows) do
				showWindowData(windowID, window)
			end
			ImGui.TreePop()
		end
		ImGui.TreePop()
	end
end

local function DrawGUI()
	if not RUNNING then return end
	local openGUI, showGUI = ImGui.Begin("Button Master Data", true)
	if not openGUI then
		RUNNING = false
	end
	if showGUI then
		if ImGui.Button("Export to Lua") then
			exportDBToLua()
		end


		ImGui.Text(string.format("Version: %d", settings.Version))
		ImGui.Text(string.format("Last Backup: %d", settings.LastBackup))


		if ImGui.TreeNode("Global") then
			ImGui.Text(string.format("Button Size: %d", globalSettings.ButtonSize))
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Sets") then
			for setName, set in pairs(setData) do
				showSetData(setName, set)
			end
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Buttons") then
			for buttonID, button in pairs(buttonData) do
				showButtonData(buttonID, button)
			end
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Characters") then
			for characterName, character in pairs(characterData) do
				showCharacterData(characterName, character)
			end
			ImGui.TreePop()
		end
	end
	ImGui.End()
end

local function Init()
	-- Run the conversion
	if not io.open(dbPath, "r") then
		convertConfigToDB()
	end

	settings = retrieveDataFromDB()
	globalSettings = settings.Global
	setData = settings.Sets
	buttonData = settings.Buttons
	characterData = settings.Characters

	-- Initialize ImGui
	mq.imgui.init("Button Master Data", DrawGUI)
end

local function Loop()
	-- Main Loop
	while RUNNING do
		if mq.TLO.EverQuest.GameState() ~= "INGAME" then
			print("Not in game, exiting...")
			mq.exit()
		end
		mq.delay(100) -- Delay to prevent excessive CPU usage
	end
end

-- Make sure we are in game before running the script
if mq.TLO.EverQuest.GameState() ~= "INGAME" then
	print("Not in game, try again later...")
	mq.exit()
end



Init()
Loop()
