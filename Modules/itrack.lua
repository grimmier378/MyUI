local mq                = require('mq')
local ImGui             = require('ImGui')
local Actors            = require('actors')
local CommonUtils       = require('mq.Utils')

local mailboxName       = "ItemTracker"
local actor
local trackedItems      = {}
local itemData          = {}
local saveFileName      = mq.configDir .. "/itemtracker.lua"
local mainWindowFlags   = bit32.bor(ImGuiWindowFlags.None)
local buttonWinFlags    = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoCollapse)

local removedItems      = {}
local myName            = mq.TLO.Me.CleanName()

-- variables for UI
local tmpTxt            = ""
local needSave          = false
local Module            = {}
local loadedExeternally = MyUI_ScriptName ~= nil
Module.Name             = "iTrack"
Module.IsRunning        = false
Module.Settings         = {}
Module.Server           = mq.TLO.EverQuest.Server()
-- local animItems         = mq.FindTextureAnimation("A_DragItem")
-- local animBox           = mq.FindTextureAnimation("A_RecessedBox")
local animMini          = mq.FindTextureAnimation("A_DragItem")
local EQ_ICON_OFFSET    = 500
local configFile        = string.format("%s/MyUI/%s/%s/%s.lua", mq.configDir, Module.Name, Module.Server, myName)

local defaults          = {
	showUI = true,
	lockWindow = false,
}

local function sortTrackedItems()
	local tmp = {}
	for _, item in ipairs(trackedItems) do
		if item ~= "" then
			table.insert(tmp, { name = item, })
		end
	end
	table.sort(tmp, function(a, b) return a.name < b.name end)
	trackedItems = {}
	for _, item in ipairs(tmp) do
		table.insert(trackedItems, item.name)
	end
end

local function loadConfig()
	if not CommonUtils.File.Exists(configFile) then
		mq.pickle(configFile, defaults)
		printf("\ayConfig file not found. Creating new config file: %s", configFile)
	end
	local config = dofile(configFile) or {}
	if type(config) == "table" then
		for k, v in pairs(defaults) do
			if config[k] == nil then
				config[k] = v
			end
		end
	end
	Module.Settings = config
end

local function saveTrackedItems()
	sortTrackedItems()
	mq.pickle(saveFileName, { trackedItems = trackedItems, })
end

local function loadTrackedItems()
	local loadedData = dofile(saveFileName) or {}
	if type(loadedData) == "table" and type(loadedData.trackedItems) == "table" then
		for _, item in ipairs(loadedData.trackedItems) do
			table.insert(trackedItems, item)
		end
	end
	sortTrackedItems()
end

-- Register Actor
local function RegisterActors()
	actor = Actors.register(mailboxName, function(message)
		if not message() then return end
		local received_message = message()
		local who = received_message.Sender or "Unknown"
		local items = received_message.Items or {}
		local tracking = received_message.Tracking or {}
		local remItem = received_message.Remove or nil
		local switch = received_message.Switch or nil

		if switch then
			if switch == myName then
				mq.cmd("/foreground")
			end
			return
		end
		-- if we were told to remove an item do so.
		if remItem ~= nil then
			printf("\ayRemoving\ax Item:\at %s", remItem)
			itemData[remItem] = nil
			for _, itemname in ipairs(trackedItems) do
				if itemname == remItem then
					table.remove(trackedItems, _)
					break
				end
			end
			saveTrackedItems()
			goto end_message
		end
		trackedItems = tracking
		sortTrackedItems()

		-- Add \ update the item data in the table. with the who and count information

		for _, itemName in ipairs(trackedItems) do
			if itemData[itemName] == nil then itemData[itemName] = {} end
			if itemData[itemName][who] == nil then itemData[itemName][who] = {} end
			if items[itemName] then
				itemData[itemName][who].inventory = items[itemName].inventory
				itemData[itemName][who].bank = items[itemName].bank
			end
		end

		-- check and set has item flag if anyone has the itme for display purposes
		for item, data in pairs(itemData) do
			if type(data) == 'table' then
				itemData[item].HasItem = false
				for who, info in pairs(data) do
					if type(info) ~= 'boolean' then
						if info.inventory > 0 or info.bank > 0 then
							itemData[item].HasItem = true
						end
					end
				end
			end
		end

		-- Remove items that are no longer being tracked this is a redundant check incase we missed a message telling us to remove an item.
		for itemName, v in pairs(itemData) do
			if not TableContains(trackedItems, itemName) then
				itemData[itemName] = nil
			end
		end
		::end_message::
	end)
end

-- Function to Check Item Counts
local function checkItems()
	local items = {}

	for _, itemName in ipairs(trackedItems) do
		local invCount = mq.TLO.FindItemCount(itemName)() or 0
		local bankCount = mq.TLO.FindItemBankCount(itemName)() or 0
		items[itemName] = { inventory = invCount, bank = bankCount, }
	end

	actor:send({ mailbox = mailboxName, }, { Items = items, Sender = myName, Tracking = trackedItems, })
end

-- GUI Rendering
local needRemove = false

-- New variable to track selected item
local selectedItem = nil
local colGreen = ImVec4(0.409, 1.000, 0.409, 1.000)
local colWhite = ImVec4(1, 1, 1, 1)
local colYellow = ImVec4(1, 1, 0, 1)

local function renderBtn()
	-- apply_style()
	local winBtnFlags = Module.Settings.lockWindow and bit32.bor(ImGuiWindowFlags.NoMove, buttonWinFlags) or buttonWinFlags

	local openBtn, showBtn = ImGui.Begin(string.format("Item Tracker##Mini"), true, winBtnFlags)
	if not openBtn then
		showBtn = false
	end

	if showBtn then
		local cursorPosX, cursorPosY = ImGui.GetCursorScreenPos()
		animMini:SetTextureCell(1147 - EQ_ICON_OFFSET)
		ImGui.DrawTextureAnimation(animMini, 34, 34, true)
		ImGui.SetCursorScreenPos(cursorPosX, cursorPosY)
		ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
		ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0.5, 0.5, 0, 0.5))
		ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImVec4(0, 0, 0, 0))
		if ImGui.Button("##ItemTrackerBtn", ImVec2(34, 34)) then
			Module.Settings.showUI = not Module.Settings.showUI
			mq.pickle(configFile, Module.Settings)
		end
		ImGui.PopStyleColor(3)
		-- if ImGui.IsItemHovered() then
		-- 	if ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
		-- 		Module.Settings.showUI = not Module.Settings.showUI
		-- 		mq.pickle(configFile, Module.Settings)
		-- 	end
		-- end
	end
	if ImGui.IsWindowHovered() then
		ImGui.BeginTooltip()
		ImGui.Text("Item Tracker")
		ImGui.Text("Left-click to toggle UI")
		ImGui.Text("Right-click for options")
		ImGui.EndTooltip()
	end
	if ImGui.BeginPopupContextWindow("ItemTrackerContext") then
		if ImGui.MenuItem(Module.Settings.lockWindow and "Unlock Window" or "Lock Window") then
			Module.Settings.lockWindow = not Module.Settings.lockWindow
			mq.pickle(configFile, Module.Settings)
		end
		ImGui.EndPopup()
	end
	ImGui.End()
end

local function renderMain()
	ImGui.SetNextWindowSize(ImVec2(600, 400), ImGuiCond.FirstUseEver)
	local winFlags = Module.Settings.lockWindow and bit32.bor(ImGuiWindowFlags.NoMove, mainWindowFlags) or mainWindowFlags
	local open, show = ImGui.Begin("Item Tracker##1", true, winFlags)
	if not open then show = false end
	if show then
		-- Add Item UI
		ImGui.Text("Items to Track")
		tmpTxt = ImGui.InputTextWithHint("##ItemInput", "Enter Item Name...", tmpTxt)
		if ImGui.IsItemHovered() and mq.TLO.Cursor() ~= nil then
			tmpTxt = mq.TLO.Cursor.Name() or tmpTxt
			mq.cmd("/autoinventory")
			needSave = true
		end
		ImGui.SameLine()
		if ImGui.Button("Add") and tmpTxt ~= "" then
			needSave = true
		end
		ImGui.Separator()

		-- Begin Split Pane
		-- local contentWidth, sizeY = ImGui.GetContentRegionAvail()
		local leftWidth = 150
		ImGui.BeginChild("ItemList", ImVec2(leftWidth, 0), bit32.bor(ImGuiChildFlags.ResizeX, ImGuiChildFlags.Border))
		for _, item in ipairs(trackedItems) do
			if itemData[item] ~= nil and itemData[item].HasItem then
				ImGui.PushStyleColor(ImGuiCol.Text, colGreen)
			else
				ImGui.PushStyleColor(ImGuiCol.Text, colWhite)
			end
			if ImGui.Selectable(item, selectedItem == item) then
				selectedItem = item
			end
			ImGui.PopStyleColor()
			if ImGui.IsItemHovered() then
				ImGui.BeginTooltip()
				ImGui.TextColored(colYellow, item)
				ImGui.Text("Right-click to remove")
				ImGui.EndTooltip()
			end
			if ImGui.BeginPopupContextItem() then
				if ImGui.MenuItem("Remove " .. item) then
					removedItems[item] = true
					needRemove = true
					if selectedItem == item then selectedItem = nil end
				end
				ImGui.EndPopup()
			end
		end
		ImGui.EndChild()

		-- Right Side: Item Data Table
		ImGui.SameLine()
		ImGui.BeginChild("ItemDataView", ImVec2(0, 0), ImGuiChildFlags.Border)
		if selectedItem and itemData[selectedItem] then
			-- ImGui.Text("Item: ")
			-- ImGui.SameLine()
			ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(0, 1, 1, 1))
			ImGui.TextWrapped(selectedItem)
			ImGui.PopStyleColor()
			if ImGui.BeginTable("ItemTable", 3, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable)) then
				ImGui.TableSetupColumn("Character")
				ImGui.TableSetupColumn("Inventory")
				ImGui.TableSetupColumn("Bank")
				ImGui.TableHeadersRow()
				for char, data in pairs(itemData[selectedItem]) do
					if type(data) ~= 'boolean' then
						local colInv = (data.inventory or 0) > 0 and colYellow or colWhite
						local colBank = (data.bank or 0) > 0 and colGreen or colWhite
						ImGui.TableNextRow()
						ImGui.TableSetColumnIndex(0)
						ImGui.Text(char)
						if ImGui.IsItemHovered() and ImGui.IsMouseReleased(0) then
							actor:send({ mailbox = mailboxName, }, { Sender = myName, Switch = char, })
						end
						ImGui.TableSetColumnIndex(1)
						ImGui.TextColored(colInv, tostring(data.inventory or 0))
						ImGui.TableSetColumnIndex(2)
						ImGui.TextColored(colBank, tostring(data.bank or 0))
					end
				end
				ImGui.EndTable()
			end
		elseif selectedItem then
			ImGui.Text("No data for: " .. selectedItem)
		else
			ImGui.Text("Select an item to view details.")
		end
		ImGui.EndChild()
	end
	ImGui.End()
	if not open then
		Module.Settings.showUI = false
		mq.pickle(configFile, Module.Settings)
	end
end

function Module.RenderGUI()
	renderBtn()

	if Module.Settings.showUI then
		renderMain()
	end
end

-- Helper function to check if a table contains a value
function TableContains(table, element)
	for _, value in pairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

-- Load tracked items from previous session
local function init()
	loadConfig()
	loadTrackedItems()
	RegisterActors()
	if not loadedExeternally then
		mq.imgui.init("itemTracker", Module.RenderGUI)
	end
	mq.bind("/itrack", Module.CommandHandler)
	Module.IsRunning = true
	Module.PrintHelp()
	checkItems()
end

function Module.CommandHandler(...)
	local args = { ..., }
	if args[1] == "show" then
		Module.Settings.showUI = true
		mq.pickle(configFile, Module.Settings)
	elseif args[1] == "hide" then
		Module.Settings.showUI = false
		mq.pickle(configFile, Module.Settings)
	elseif args[1] == "add" and args[2] then
		tmpTxt = args[2]
		needSave = true
	elseif args[1] == "remove" and args[2] then
		removedItems[args[2]:lower()] = true
		needRemove = true
	elseif args[1] == "list" then
		if #trackedItems > 0 then
			printf("\ayTracked Items:")
			for _, item in ipairs(trackedItems) do
				printf("\at- %s", item)
			end
		else
			printf("\ayNo items are being tracked.")
		end
	elseif args[1] == "help" then
		Module.PrintHelp()
	elseif args[1] == 'quit' then
		Module.IsRunning = false
		Module.Unload()
	else
		printf("\ayInvalid command.")
		Module.PrintHelp()
	end
end

function Module.PrintHelp()
	printf("\ay/itrack show \ax- Show the item tracker UI")
	printf("\ay/itrack hide \ax- Hide the item tracker UI")
	printf("\ay/itrack add <item> \ax- Add an item to track")
	printf("\ay/itrack remove <item> \ax- Remove an item from tracking")
	printf("\ay/itrack list \ax- List all tracked items")
end

init()
local refreshTimer = os.clock()
-- Main Script Loop

function Module.Unload()
	mq.unbind("/itrack")
	actor = nil
	Module.IsRunning = false
end

function Module.MainLoop()
	if loadedExeternally then
		---@diagnostic disable-next-line: undefined-global
		if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
	end
	if needRemove then
		for item, _ in pairs(removedItems) do
			for i, trackedItem in ipairs(trackedItems) do
				if trackedItem == item or trackedItem:lower() == item:lower() then
					table.remove(trackedItems, i)
					actor:send({ mailbox = mailboxName, }, { Items = {}, Sender = myName, Tracking = {}, Remove = trackedItem, })
					break
				end
			end
		end
		removedItems = {}
		needRemove = false
		saveTrackedItems()
	end

	if needSave then
		if tmpTxt ~= "" then
			if not TableContains(trackedItems, tmpTxt) then
				table.insert(trackedItems, tmpTxt)
			end
			tmpTxt = ""
		end
		checkItems()
		needSave = false
		saveTrackedItems()
	end

	mq.doevents()
	if os.difftime(os.clock(), refreshTimer) > 3 then
		checkItems()
		refreshTimer = os.clock()
	end
end

function Module.LocalLoop()
	while Module.IsRunning do
		Module.MainLoop()
		mq.delay(10) -- Adjust the delay as needed
	end
end

if not loadedExeternally then
	Module.LocalLoop()
end
return Module
