local mq                = require("mq")
local ImGui             = require("ImGui")
local Module            = {}
Module.Name             = "BigBag"
Module.IsRunning        = false
Module.ShowGUI          = false
local loadedExeternally = MyUI_ScriptName ~= nil and true or false

if not loadedExeternally then
	Module.Path        = string.format("%s/%s/", mq.luaDir, Module.Name)
	Module.ThemeFile   = Module.ThemeFile == nil and string.format('%s/MyUI/ThemeZ.lua', mq.configDir) or Module.ThemeFile
	Module.Theme       = require('defaults.themes')
	Module.ThemeLoader = require('lib.theme_loader')
else
	Module.Path = MyUI_Path
	Module.ThemeFile = MyUI_ThemeFile
	Module.Theme = MyUI_Theme
	Module.ThemeLoader = MyUI_ThemeLoader
end
-- Constants
local ICON_WIDTH                                          = 40
local ICON_HEIGHT                                         = 40
local COUNT_X_OFFSET                                      = 39
local COUNT_Y_OFFSET                                      = 23
local EQ_ICON_OFFSET                                      = 500
local BAG_ITEM_SIZE                                       = 40
local INVENTORY_DELAY_SECONDS                             = 30
local MIN_SLOTS_WARN                                      = 3
local FreeSlots                                           = 0
local UsedSlots                                           = 0
local do_process_coin                                     = false
local configFile                                          = string.format("%s/MyUI/BigBag/%s/%s.lua", mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.Name())
-- EQ Texture Animation references
local animItems                                           = mq.FindTextureAnimation("A_DragItem")
local animBox                                             = mq.FindTextureAnimation("A_RecessedBox")
local animMini                                            = mq.FindTextureAnimation("A_DragItem")

-- Toggles
local toggleKey                                           = ''
local toggleModKey, toggleModKey2, toggleModKey3          = 'None', 'None', 'None'
local toggleMouse                                         = 'Middle'

-- Bag Contents
local items                                               = {}
local clickies                                            = {}
local augments                                            = {}
local bank_items                                          = {}
local bank_augments                                       = {}
local needSort                                            = true
local coin_type                                           = 0
local coin_qty                                            = ''

-- Bag Options
local sort_order                                          = { name = false, stack = false, }
local clicked                                             = false
-- GUI Activities
local show_item_background                                = true
local show_qty_win                                        = false
local themeName                                           = "Default"
local start_time                                          = os.time()
local coin_timer                                          = os.time()
local filter_text                                         = ""
local utils                                               = require('mq.Utils')
local settings                                            = {}
local MySelf                                              = mq.TLO.Me
local myCopper, mySilver, myGold, myPlat, myWeight, myStr = 0, 0, 0, 0, 0, 0
local bankCopper, bankSilver, bankGold, bankPlat          = 0, 0, 0, 0
local defaults                                            = {
	MIN_SLOTS_WARN = 3,
	show_item_background = true,
	sort_order = { name = false, stack = false, },
	themeName = "Default",
	toggleKey = '',
	toggleModKey = 'None',
	toggleModKey2 = 'None',
	toggleModKey3 = 'None',
	toggleMouse = 'None',
	INVENTORY_DELAY_SECONDS = 2,
}
local modKeys                                             = {
	"None",
	"Ctrl",
	"Alt",
	"Shift",
}
local mouseKeys                                           = {
	"Middle",
	"None",
}
local function loadSettings()
	if utils.File.Exists(configFile) then
		settings = dofile(configFile)
	else
		settings = defaults
	end

	if not loadedExeternally then
		if utils.File.Exists(Module.ThemeFile) then
			Module.Theme = dofile(Module.ThemeFile)
		end
	end
	if settings.toggleModKey == '' then settings.toggleModKey = 'None' end
	if settings.toggleModKey2 == '' then settings.toggleModKey2 = 'None' end
	if settings.toggleModKey3 == '' then settings.toggleModKey3 = 'None' end
	if settings.toggleMouse == '' then settings.toggleMouse = 'None' end
	INVENTORY_DELAY_SECONDS = settings.INVENTORY_DELAY_SECONDS ~= nil and settings.INVENTORY_DELAY_SECONDS or defaults.INVENTORY_DELAY_SECONDS
	toggleKey = settings.toggleKey ~= nil and settings.toggleKey or defaults.toggleKey
	toggleModKey = settings.toggleModKey ~= nil and settings.toggleModKey or defaults.toggleModKey
	toggleModKey2 = settings.toggleModKey2 ~= nil and settings.toggleModKey2 or defaults.toggleModKey2
	toggleModKey3 = settings.toggleModKey3 ~= nil and settings.toggleModKey3 or defaults.toggleModKey3
	toggleMouse = settings.toggleMouse ~= nil and settings.toggleMouse or defaults.toggleMouse
	themeName = settings.themeName ~= nil and settings.themeName or defaults.themeName
	MIN_SLOTS_WARN = settings.MIN_SLOTS_WARN ~= nil and settings.MIN_SLOTS_WARN or defaults.MIN_SLOTS_WARN
	show_item_background = settings.show_item_background ~= nil and settings.show_item_background or defaults.show_item_background
	sort_order = settings.sort_order ~= nil and settings.sort_order or defaults.sort_order
	if toggleModKey == 'None' then
		toggleModKey2 = 'None'
		settings.toggleModKey2 = 'None'
	end
	if toggleModKey2 == 'None' then
		toggleModKey3 = 'None'
		settings.toggleModKey3 = 'None'
	end

	myCopper = MySelf.Copper() or 0
	mySilver = MySelf.Silver() or 0
	myGold = MySelf.Gold() or 0
	myPlat = MySelf.Platinum() or 0
end

local function help_marker(desc)
	ImGui.TextDisabled("(?)")
	if ImGui.IsItemHovered() then
		ImGui.BeginTooltip()
		ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
		ImGui.TextUnformatted(desc)
		ImGui.PopTextWrapPos()
		ImGui.EndTooltip()
	end
end

-- Sort routines
local function sort_inventory()
	-- Various Sorting
	if sort_order.name and sort_order.stack then
		table.sort(items, function(a, b) return a.Stack() > b.Stack() or (a.Stack() == b.Stack() and a.Name() < b.Name()) end)
		table.sort(bank_items, function(a, b) return a.Stack() > b.Stack() or (a.Stack() == b.Stack() and a.Name() < b.Name()) end)
	elseif sort_order.stack then
		table.sort(items, function(a, b) return a.Stack() > b.Stack() end)
		table.sort(bank_items, function(a, b) return a.Stack() > b.Stack() end)
	elseif sort_order.name then
		table.sort(items, function(a, b) return a.Name() < b.Name() end)
		table.sort(bank_items, function(a, b) return a.Name() < b.Name() end)
		-- else
		-- table.sort(items)
	end
end

local function process_coin()
	local coinSlot = string.format("InventoryWindow/IW_Money%s", coin_type)
	mq.TLO.Window('InventoryWindow').DoOpen()
	mq.delay(1500, function() return mq.TLO.Window('InventoryWindow').Open() end)
	mq.TLO.Window(coinSlot).LeftMouseUp()
	while mq.TLO.Window("QuantityWnd/QTYW_SliderInput").Text() ~= coin_qty do
		mq.TLO.Window("QuantityWnd/QTYW_SliderInput").SetText(coin_qty)
		mq.delay(200, function() return mq.TLO.Window("QuantityWnd/QTYW_SliderInput").Text() == coin_qty end)
	end
	while mq.TLO.Window("QuantityWnd").Open() do
		mq.TLO.Window("QuantityWnd/QTYW_Accept_Button").LeftMouseUp()
		mq.delay(200, function() return not mq.TLO.Window("QuantityWnd").Open() end)
	end
	mq.TLO.Window('InventoryWindow').DoClose()
	coin_qty = ''
end

local function draw_qty_win()
	local label = ''
	if show_qty_win then
		local labelHint = "Available: "
		if coin_type == 0 then
			labelHint = labelHint .. myPlat
			label = 'Plat'
		elseif coin_type == 1 then
			labelHint = labelHint .. myGold
			label = 'Gold'
		elseif coin_type == 2 then
			labelHint = labelHint .. mySilver
			label = 'Silver'
		elseif coin_type == 3 then
			labelHint = labelHint .. myCopper
			label = 'Copper'
		end
		ImGui.SetNextWindowPos(ImGui.GetMousePosOnOpeningCurrentPopupVec(), ImGuiCond.Appearing)
		local open, show = ImGui.Begin("Quantity##" .. coin_type, true, bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoDocking, ImGuiWindowFlags.AlwaysAutoResize))
		if not open then
			show_qty_win = false
		end
		if show then
			ImGui.Text("Enter %s Qty", label)
			ImGui.Separator()
			coin_qty = ImGui.InputTextWithHint("##Qty", labelHint, coin_qty)
			if ImGui.Button("OK##qty") then
				show_qty_win = false
				do_process_coin = true
			end
			ImGui.SameLine()
			if ImGui.Button("Cancel##qty") then
				show_qty_win = false
			end
		end
		ImGui.End()
	end
end

local function draw_currency()
	animItems:SetTextureCell(644 - EQ_ICON_OFFSET)
	ImGui.DrawTextureAnimation(animItems, 20, 20)
	ImGui.SameLine()
	ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", myPlat)
	if ImGui.IsItemHovered() then
		ImGui.BeginTooltip()
		ImGui.Text("%s Platinum", myPlat)
		ImGui.EndTooltip()
		if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
			show_qty_win = true
			coin_type = 0
		end
	end

	ImGui.SameLine()

	animItems:SetTextureCell(645 - EQ_ICON_OFFSET)
	ImGui.DrawTextureAnimation(animItems, 20, 20)
	ImGui.SameLine()
	ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", myGold)
	if ImGui.IsItemHovered() then
		ImGui.BeginTooltip()
		ImGui.Text("%s Gold", myGold)
		ImGui.EndTooltip()
		if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
			show_qty_win = true
			coin_type = 1
		end
	end

	ImGui.SameLine()

	animItems:SetTextureCell(646 - EQ_ICON_OFFSET)
	ImGui.DrawTextureAnimation(animItems, 20, 20)
	ImGui.SameLine()
	ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", mySilver)
	if ImGui.IsItemHovered() then
		ImGui.BeginTooltip()
		ImGui.Text("%s Silver", mySilver)
		ImGui.EndTooltip()
		if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
			show_qty_win = true
			coin_type = 2
		end
	end

	ImGui.SameLine()

	animItems:SetTextureCell(647 - EQ_ICON_OFFSET)
	ImGui.DrawTextureAnimation(animItems, 20, 20)
	ImGui.SameLine()
	ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", myCopper)
	if ImGui.IsItemHovered() then
		ImGui.BeginTooltip()
		ImGui.Text("%s Copper", myCopper)
		ImGui.EndTooltip()
		if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
			show_qty_win = true
			coin_type = 3
		end
	end
end

local function draw_bank_coin()
	ImGui.SeparatorText("Money in Bank:")
	animItems:SetTextureCell(644 - EQ_ICON_OFFSET)
	ImGui.DrawTextureAnimation(animItems, 20, 20)
	ImGui.SameLine()
	ImGui.TextColored(ImVec4(0, 1, 1, 1), " %s", bankPlat)
	if ImGui.IsItemHovered() then
		ImGui.BeginTooltip()
		ImGui.Text("%s Platinum", bankPlat)
		ImGui.EndTooltip()
	end

	ImGui.SameLine()

	animItems:SetTextureCell(645 - EQ_ICON_OFFSET)
	ImGui.DrawTextureAnimation(animItems, 20, 20)
	ImGui.SameLine()
	ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", bankGold)
	if ImGui.IsItemHovered() then
		ImGui.BeginTooltip()
		ImGui.Text("%s Gold", bankGold)
		ImGui.EndTooltip()
	end

	ImGui.SameLine()

	animItems:SetTextureCell(646 - EQ_ICON_OFFSET)
	ImGui.DrawTextureAnimation(animItems, 20, 20)
	ImGui.SameLine()
	ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", bankSilver)
	if ImGui.IsItemHovered() then
		ImGui.BeginTooltip()
		ImGui.Text("%s Silver", bankSilver)
		ImGui.EndTooltip()
	end

	ImGui.SameLine()

	animItems:SetTextureCell(647 - EQ_ICON_OFFSET)
	ImGui.DrawTextureAnimation(animItems, 20, 20)
	ImGui.SameLine()
	ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", bankCopper)
	if ImGui.IsItemHovered() then
		ImGui.BeginTooltip()
		ImGui.Text("%s Copper", bankCopper)
		ImGui.EndTooltip()
	end
	ImGui.SeparatorText('Items in Bank:')
end

local function UpdateCoin()
	myCopper = MySelf.Copper() or 0
	mySilver = MySelf.Silver() or 0
	myGold = MySelf.Gold() or 0
	myPlat = MySelf.Platinum() or 0
	bankCopper = MySelf.CopperBank() or 0
	bankSilver = MySelf.SilverBank() or 0
	bankGold = MySelf.GoldBank() or 0
	bankPlat = MySelf.PlatinumBank() or 0
end

-- The beast - this routine is what builds our inventory.

local function create_bank()
	start_time = os.time()
	bank_items = {}
	bank_augments = {}
	for i = 1, 24, 1 do
		local slot = mq.TLO.Me.Bank(i)
		if slot.Container() and slot.Container() > 0 then
			for j = 1, (slot.Container()), 1 do
				if (slot.Item(j)()) then
					table.insert(bank_items, slot.Item(j))
					if slot.Item(j).AugType() > 0 then
						table.insert(bank_augments, slot.Item(j))
					end
				end
			end
		elseif slot.ID() ~= nil then
			table.insert(bank_items, slot) -- We have an item in a bag slot
			if slot.AugType() > 0 then
				table.insert(bank_augments, slot)
			end
		end
	end
	needSort = true
end

local function create_inventory()
	if ((os.difftime(os.time(), start_time)) > INVENTORY_DELAY_SECONDS) or mq.TLO.Me.FreeInventory() ~= FreeSlots or clicked then
		start_time = os.time()
		items = {}
		clickies = {}
		augments = {}
		local tmpUsedSlots = 0
		for i = 1, 22, 1 do
			local slot = mq.TLO.Me.Inventory(i)
			if slot.ID() ~= nil then
				if slot.Clicky() then
					table.insert(clickies, slot)
				end
			end
		end
		for i = 23, 34, 1 do
			local slot = mq.TLO.Me.Inventory(i)
			if slot.Container() and slot.Container() > 0 then
				for j = 1, (slot.Container()), 1 do
					if (slot.Item(j)()) then
						table.insert(items, slot.Item(j))
						tmpUsedSlots = tmpUsedSlots + 1
						if slot.Item(j).Clicky() then
							table.insert(clickies, slot.Item(j))
						end
						if slot.Item(j).AugType() > 0 then
							table.insert(augments, slot.Item(j))
						end
					end
				end
			elseif slot.ID() ~= nil then
				table.insert(items, slot) -- We have an item in a bag slot
				tmpUsedSlots = tmpUsedSlots + 1
				if slot.Clicky() then
					table.insert(clickies, slot)
				end
				if slot.AugType() > 0 then
					table.insert(augments, slot)
				end
			end
		end

		if tmpUsedSlots ~= UsedSlots then
			UsedSlots = tmpUsedSlots
		end
		FreeSlots = mq.TLO.Me.FreeInventory()
		needSort = true
		clicked = false
		create_bank()
	end
end



-- Converts between ItemSlot and /itemnotify pack numbers
local function to_pack(slot_number)
	return "pack" .. tostring(slot_number - 22)
end

-- Converts between ItemSlot2 and /itemnotify numbers
local function to_bag_slot(slot_number)
	return slot_number + 1
end

-- Displays static utilities that always show at the top of the UI
local function display_bag_utilities()
	ImGui.PushItemWidth(200)
	local text, selected = ImGui.InputText("Filter", filter_text)
	ImGui.PopItemWidth()
	if selected then filter_text = string.gsub(text, "[^a-zA-Z0-9'`_-.]", "") or "" end
	text = filter_text
	ImGui.SameLine()
	if ImGui.SmallButton("Clear") then filter_text = "" end
end

-- Display the collapasable menu area above the items
local function display_bag_options()
	ImGui.SetWindowFontScale(1.0)
	if ImGui.BeginChild("OptionsChild") then
		if ImGui.CollapsingHeader("Bag Options") then
			local changed = false
			sort_order.name, changed = ImGui.Checkbox("Name", sort_order.name)
			if changed then
				needSort = true
				settings.sort_order.name = sort_order.name
				mq.pickle(configFile, settings)
				clicked = true
			end
			ImGui.SameLine()
			help_marker("Order items from your inventory sorted by the name of the item.")

			local pressed = false
			sort_order.stack, pressed = ImGui.Checkbox("Stack", sort_order.stack)
			if pressed then
				needSort = true
				settings.sort_order.stack = sort_order.stack
				mq.pickle(configFile, settings)
				clicked = true
			end
			ImGui.SameLine()
			help_marker("Order items with the largest stacks appearing first.")

			local pressed2 = false
			show_item_background, pressed2 = ImGui.Checkbox("Show Slot Background", show_item_background)
			if pressed2 then
				settings.show_item_background = show_item_background
				mq.pickle(configFile, settings)
			end
			ImGui.SameLine()
			help_marker("Removes the background texture to give your bag a cool modern look.")

			ImGui.SetNextItemWidth(100)
			MIN_SLOTS_WARN = ImGui.InputInt("Min Slots Warning", MIN_SLOTS_WARN, 1, 10)
			if MIN_SLOTS_WARN ~= settings.MIN_SLOTS_WARN then
				settings.MIN_SLOTS_WARN = MIN_SLOTS_WARN
				mq.pickle(configFile, settings)
			end
			ImGui.SameLine()
			help_marker("Minimum number of slots before the warning color is displayed.")

			ImGui.SetNextItemWidth(100)
			INVENTORY_DELAY_SECONDS = ImGui.InputInt("Inventory Refresh Time (s)", INVENTORY_DELAY_SECONDS, 1, 10)
			if INVENTORY_DELAY_SECONDS ~= settings.INVENTORY_DELAY_SECONDS then
				settings.INVENTORY_DELAY_SECONDS = INVENTORY_DELAY_SECONDS
				mq.pickle(configFile, settings)
			end
			ImGui.SameLine()
			help_marker("Time in seconds between inventory refreshes, if # of free slots hasn't changed.")
		end

		if ImGui.CollapsingHeader('Toggle Settings') then
			ImGui.Text("Toggle Key")
			ImGui.SameLine()
			ImGui.SetNextItemWidth(100)
			toggleKey = ImGui.InputText("##ToggleKey", toggleKey, ImGuiInputTextFlags.CharsUppercase)
			if toggleKey ~= settings.toggleKey then
				settings.toggleKey = toggleKey:upper()
				mq.pickle(configFile, settings)
			end
			ImGui.SameLine()
			help_marker("Key to toggle the GUI (A-Z | 0-9 | F1-F12)")
			if toggleKey ~= '' then
				ImGui.Text("Toggle Mod Key")
				ImGui.SameLine()
				ImGui.SetNextItemWidth(100)

				local isSelected = false
				if settings.toggleModKey2 == '' then
					ImGui.Text("None")
				else
					if ImGui.BeginCombo("##ToggleModKey", settings.toggleModKey) then
						for k, v in pairs(modKeys) do
							isSelected = v == settings.toggleModKey
							if ImGui.Selectable(v, isSelected) then
								settings.toggleModKey = v
								if v == 'None' then
									settings.toggleModKey2 = 'None'
									settings.toggleModKey3 = 'None'
									toggleModKey2 = settings.toggleModKey2
									toggleModKey3 = settings.toggleModKey3
								end
								toggleModKey = settings.toggleModKey
								mq.pickle(configFile, settings)
							end
						end
						ImGui.EndCombo()
					end
				end
				ImGui.SameLine()
				help_marker("Modifier Key to toggle the GUI (Ctrl | Alt | Shift)")
				if settings.toggleModKey ~= 'None' then
					ImGui.Text("Toggle Mod Key2")
					ImGui.SameLine()
					ImGui.SetNextItemWidth(100)

					local isSelectedMod2 = false
					if settings.toggleModKey2 == '' then
						ImGui.Text("None")
					else
						if ImGui.BeginCombo("##ToggleModKey2", settings.toggleModKey2) then
							for k, v in pairs(modKeys) do
								isSelectedMod2 = v == settings.toggleModKey2
								if ImGui.Selectable(v, isSelectedMod2) then
									settings.toggleModKey2 = v
									if v == 'None' then
										settings.toggleModKey3 = 'None'
										toggleModKey3 = settings.toggleModKey3
									end
									toggleModKey2 = settings.toggleModKey2
									mq.pickle(configFile, settings)
								end
							end
							ImGui.EndCombo()
						end
					end
					ImGui.SameLine()
					help_marker("Modifier Key2 to toggle the GUI (Ctrl | Alt | Shift)")

					if settings.toggleModKey2 ~= 'None' then
						ImGui.Text("Toggle Mod Key3")
						ImGui.SameLine()
						ImGui.SetNextItemWidth(100)
						local isSelectedMod3 = false
						if settings.toggleModKey3 == '' then
							ImGui.Text("None")
						else
							if ImGui.BeginCombo("##ToggleModKey3", settings.toggleModKey3) then
								for k, v in pairs(modKeys) do
									isSelectedMod3 = v == settings.toggleModKey3
									if ImGui.Selectable(v, isSelectedMod3) then
										settings.toggleModKey3 = v
										toggleModKey3 = settings.toggleModKey3
										mq.pickle(configFile, settings)
									end
								end
								ImGui.EndCombo()
							end
						end
						ImGui.SameLine()
						help_marker("Modifier Key3 to toggle the GUI (Ctrl | Alt | Shift)")
					end
				end
			end
			ImGui.Text("Toggle Mouse Button")
			ImGui.SameLine()
			ImGui.SetNextItemWidth(100)
			local isSelectedMouse = false
			if settings.toggleMouse == '' then
				ImGui.Text("None")
			else
				if ImGui.BeginCombo("##ToggleMouseButton", settings.toggleMouse) then
					for k, v in pairs(mouseKeys) do
						isSelectedMouse = v == settings.toggleMouse
						if ImGui.Selectable(v, isSelectedMouse) then
							settings.toggleMouse = v
							toggleMouse = settings.toggleMouse
							mq.pickle(configFile, settings)
						end
					end
					ImGui.EndCombo()
				end
			end
			ImGui.SameLine()
			help_marker("Mouse Button to toggle the GUI (Left | Right | Middle)")
		end

		if ImGui.CollapsingHeader("Theme Settings##BigBag") then
			ImGui.Text("Cur Theme: %s", themeName)
			-- Combo Box Load Theme
			if ImGui.BeginCombo("Load Theme##BigBag", themeName) then
				for k, data in pairs(Module.Theme.Theme) do
					local isSelected = data.Name == themeName
					if ImGui.Selectable(data.Name, isSelected) then
						settings.themeName = data.Name
						themeName = settings.themeName
						mq.pickle(configFile, settings)
					end
				end
				ImGui.EndCombo()
			end
		end
	end
	ImGui.EndChild()
end


-- Helper to create a unique hidden label for each button.  The uniqueness is
-- necessary for drag and drop to work correctly.
local function btn_label(item)
	if not item.slot_in_bag then
		return string.format("##slot_%s", item.ItemSlot())
	else
		return string.format("##bag_%s_slot_%s", item.ItemSlot(), item.ItemSlot2())
	end
end

---Draws the individual item icon in the bag.
---@param item item The item object
local function draw_item_icon(item, iconWidth, iconHeight, drawID, clickable)
	-- Capture original cursor position
	local cursor_x, cursor_y = ImGui.GetCursorPos()
	local offsetX, offsetY = iconWidth - 1, iconHeight / 1.5
	local offsetXCharges, offsetYCharges = 2, offsetY / 2 -- Draw the background box
	ImGui.PushID(drawID)
	-- Draw the background box
	if show_item_background then
		ImGui.DrawTextureAnimation(animBox, iconWidth, iconHeight)
	end

	-- This handles our "always there" drop zone (for now...)
	if not item then
		return
	end

	-- Reset the cursor to start position, then fetch and draw the item icon
	ImGui.SetCursorPos(cursor_x, cursor_y)
	animItems:SetTextureCell(item.Icon() - EQ_ICON_OFFSET)
	ImGui.DrawTextureAnimation(animItems, iconWidth, iconHeight)

	-- Overlay the stack size text in the lower right corner
	ImGui.SetWindowFontScale(0.68)
	local TextSize = ImGui.CalcTextSize(tostring(item.Stack()))
	if item.Stack() > 1 then
		ImGui.SetCursorPos((cursor_x + offsetX) - TextSize, cursor_y + offsetY)
		ImGui.DrawTextureAnimation(animBox, TextSize, 4)
		ImGui.SetCursorPos((cursor_x + offsetX) - TextSize, cursor_y + offsetY)
		ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", item.Stack())
	end
	local TextSize2 = ImGui.CalcTextSize(tostring(item.Charges()))
	if item.Charges() >= 1 then
		ImGui.SetCursorPos((cursor_x + offsetXCharges), cursor_y + offsetYCharges)
		ImGui.DrawTextureAnimation(animBox, TextSize2, 4)
		ImGui.SetCursorPos((cursor_x + offsetXCharges), cursor_y + offsetYCharges)
		ImGui.TextColored(ImVec4(1, 1, 0, 1), "%s", item.Charges())
	end
	ImGui.SetWindowFontScale(1.0)

	-- Reset the cursor to start position, then draw a transparent button (for drag & drop)
	ImGui.SetCursorPos(cursor_x, cursor_y)

	if item.TimerReady() > 0 then
		ImGui.PushStyleColor(ImGuiCol.Button, 0.3, 0, 0, 0.4)
		ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0, 0, 0.4)
		ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.3, 00, 0, 0.3)
	else
		ImGui.PushStyleColor(ImGuiCol.Button, 0, 0, 0, 0)
		ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0, 0.3, 0, 0.2)
		ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0, 0.3, 0, 0.3)
	end
	ImGui.Button(btn_label(item), iconWidth, iconHeight)
	ImGui.PopStyleColor(3)
	ImGui.PopID()

	-- Tooltip
	if ImGui.IsItemHovered() then
		local charges = item.Charges() or 0
		local clicky = item.Clicky() or 'none'
		ImGui.BeginTooltip()
		ImGui.Text("Item: %s", item.Name())
		ImGui.Text("Qty: %s", item.Stack() or 1)
		ImGui.TextColored(ImVec4(0, 1, 1, 1), "Value: %0.1f Plat ", (item.Value() or 0) / 1000) -- 1000 copper - 1 plat
		ImGui.SameLine()
		ImGui.TextColored(ImVec4(1, 1, 0, 1), 'Trib: %s', (item.Tribute() or 0))
		if clicky ~= 'none' then
			ImGui.SeparatorText("Clicky Info")
			ImGui.TextColored(ImVec4(0, 1, 0, 1), "Clicky: %s", clicky)
			ImGui.TextColored(ImVec4(0, 1, 1, 1), "Charges: %s", charges >= 0 and charges or 'Infinite')
		end
		ImGui.SeparatorText("Click Actions")
		if clickable then
			ImGui.Text("Right Click to use item")
			ImGui.Text("Left Click Pick Up item")
		end
		ImGui.Text("Ctrl + Right Click to Inspect Item")
		ImGui.EndTooltip()
	end
	if clickable then
		if ImGui.IsItemClicked(ImGuiMouseButton.Left) and not mq.TLO.Me.Casting() then
			if item.ItemSlot2() == -1 then
				mq.cmd("/itemnotify " .. item.ItemSlot() .. " leftmouseup")
			else
				-- print(item.ItemSlot2())
				mq.cmd("/itemnotify in " .. to_pack(item.ItemSlot()) .. " " .. to_bag_slot(item.ItemSlot2()) .. " leftmouseup")
			end
		end
		if ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsItemClicked(ImGuiMouseButton.Right) then
			local link = item.ItemLink('CLICKABLE')()
			mq.cmdf('/executelink %s', link)
		elseif ImGui.IsItemClicked(ImGuiMouseButton.Right) and not mq.TLO.Me.Casting() then
			mq.cmdf('/useitem "%s"', item.Name())
			clicked = true
		end
	else
		if ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsItemClicked(ImGuiMouseButton.Right) then
			local link = item.ItemLink('CLICKABLE')()
			mq.cmdf('/executelink %s', link)
		end
	end
end

-- If there is an item on the cursor, display it.
local function display_item_on_cursor()
	if mq.TLO.Cursor() then
		local cursor_item = mq.TLO.Cursor -- this will be an MQ item, so don't forget to use () on the members!
		local mouse_x, mouse_y = ImGui.GetMousePos()
		local window_x, window_y = ImGui.GetWindowPos()
		local icon_x = mouse_x - window_x + 10
		local icon_y = mouse_y - window_y + 10
		local stack_x = icon_x + COUNT_X_OFFSET
		local stack_y = icon_y + COUNT_Y_OFFSET
		local text_size = ImGui.CalcTextSize(tostring(cursor_item.Stack()))
		ImGui.SetCursorPos(icon_x, icon_y)
		animItems:SetTextureCell(cursor_item.Icon() - EQ_ICON_OFFSET)
		ImGui.DrawTextureAnimation(animItems, ICON_WIDTH, ICON_HEIGHT)
		if cursor_item.Stackable() then
			ImGui.SetCursorPos(stack_x, stack_y)
			ImGui.DrawTextureAnimation(animBox, text_size, ImGui.GetTextLineHeight())
			ImGui.SetCursorPos(stack_x - text_size, stack_y)
			ImGui.TextUnformatted(tostring(cursor_item.Stack()))
		end
	end
end

---Handles the bag layout of individual items
local function display_bag_content()
	-- create_inventory()
	ImGui.SetWindowFontScale(1.0)
	if ImGui.BeginChild("BagContent", 0.0, 0.0) then
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
		local bag_window_width = ImGui.GetWindowWidth()
		local bag_cols = math.floor(bag_window_width / BAG_ITEM_SIZE)
		local temp_bag_cols = 1

		for index, _ in ipairs(items) do
			if string.match(string.lower(items[index].Name()), string.lower(filter_text)) then
				draw_item_icon(items[index], ICON_WIDTH, ICON_HEIGHT, 'inv' .. index, true)
				if bag_cols > temp_bag_cols then
					temp_bag_cols = temp_bag_cols + 1
					ImGui.SameLine()
				else
					temp_bag_cols = 1
				end
			end
		end
		ImGui.PopStyleVar()
	end
	ImGui.EndChild()
end

local function display_bank_content()
	-- create_inventory()
	ImGui.SetWindowFontScale(1.0)
	if ImGui.BeginChild("BankContent", 0.0, 0.0) then
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
		local bag_window_width = ImGui.GetWindowWidth()
		local bag_cols = math.floor(bag_window_width / BAG_ITEM_SIZE)
		local temp_bag_cols = 1

		for index, _ in ipairs(bank_items) do
			if string.match(string.lower(bank_items[index].Name()), string.lower(filter_text)) then
				draw_item_icon(bank_items[index], ICON_WIDTH, ICON_HEIGHT, 'bank' .. index, false)
				if bag_cols > temp_bag_cols then
					temp_bag_cols = temp_bag_cols + 1
					ImGui.SameLine()
				else
					temp_bag_cols = 1
				end
			end
		end
		ImGui.PopStyleVar()
	end
	ImGui.EndChild()
end

local function display_clickies()
	ImGui.SetWindowFontScale(1.0)
	if ImGui.BeginChild("BagClickies", 0.0, 0.0) then
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
		local bag_window_width = ImGui.GetWindowWidth()
		local bag_cols = math.floor(bag_window_width / BAG_ITEM_SIZE)
		local temp_bag_cols = 1

		for index, _ in ipairs(clickies) do
			if string.match(string.lower(clickies[index].Name()), string.lower(filter_text)) then
				draw_item_icon(clickies[index], ICON_WIDTH, ICON_HEIGHT, 'clicky' .. index, true)
				if bag_cols > temp_bag_cols then
					temp_bag_cols = temp_bag_cols + 1
					ImGui.SameLine()
				else
					temp_bag_cols = 1
				end
			end
		end
		ImGui.PopStyleVar()
	end
	ImGui.EndChild()
end

local function display_augments()
	ImGui.SetWindowFontScale(1.0)
	if ImGui.BeginChild("BagAugments", 0.0, 0.0) then
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
		local bag_window_width = ImGui.GetWindowWidth()
		local bag_cols = math.floor(bag_window_width / BAG_ITEM_SIZE)
		local temp_bag_cols = 1

		for index, _ in ipairs(augments) do
			if string.match(string.lower(augments[index].Name()), string.lower(filter_text)) then
				draw_item_icon(augments[index], ICON_WIDTH, ICON_HEIGHT, 'augments' .. index, true)
				if bag_cols > temp_bag_cols then
					temp_bag_cols = temp_bag_cols + 1
					ImGui.SameLine()
				else
					temp_bag_cols = 1
				end
			end
		end
		ImGui.PopStyleVar()
	end
	ImGui.EndChild()
end

local function display_details()
	ImGui.SetWindowFontScale(1.0)
	if ImGui.BeginTable("Details", 8, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.ScrollY, ImGuiTableFlags.Resizable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Reorderable)) then
		ImGui.TableSetupColumn('Icon', ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.WidthFixed, 100)
		ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn('Tribute', ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn('Worn EFX', ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn('Clicky', ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn('Charges', ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn('Augment', ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupScrollFreeze(0, 1)
		ImGui.TableHeadersRow()
		for index, _ in ipairs(items) do
			ImGui.PushID(index)
			if string.match(string.lower(items[index].Name()), string.lower(filter_text)) then
				local item = items[index]
				local clicky = item.Clicky() or 'No'
				local charges = item.Charges()
				local lbl = 'Infinite'
				if charges == -1 then
					lbl = 'Infinite'
				elseif charges == 0 then
					lbl = 'None'
				else
					lbl = charges
				end
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				draw_item_icon(item, 20, 20, 'details' .. index, true)
				ImGui.TableNextColumn()
				ImGui.PushID(string.format("##SelectItem_%s", index))
				ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(0, 1, 1, 1))
				local _, itemClicked = ImGui.Selectable(item.Name() or "None", false)
				if itemClicked then
					mq.cmdf('/executelink %s', item.ItemLink('CLICKABLE')())
				end
				ImGui.PopStyleColor()
				ImGui.PopID()

				ImGui.TableNextColumn()
				ImGui.TextColored(ImVec4(0, 1, 0.5, 1), "%0.2f pp", (item.Value() / 1000) or 0)
				ImGui.TableNextColumn()
				ImGui.Text("%s", item.Tribute() or 0)
				ImGui.TableNextColumn()
				ImGui.Text("%s", item.Worn() or 'No')
				ImGui.TableNextColumn()
				ImGui.TextColored(ImVec4(0, 1, 1, 1), clicky)
				ImGui.TableNextColumn()
				ImGui.Text("%s", lbl)
				ImGui.TableNextColumn()
				if item.AugType() > 0 then
					ImGui.TextColored(ImVec4(0, 1, 0, 1), 'Yes')
				else
					ImGui.Text('No')
				end
			end
			ImGui.PopID()
		end
		ImGui.EndTable()
	end
end

local function BigButtonTooltip()
	local toggleModes = ''
	if toggleModKey ~= 'None' and toggleModKey2 == 'None' and toggleModKey3 == 'None' and toggleKey ~= '' then
		toggleModes = string.format("%s + %s", toggleModKey, toggleKey)
	elseif toggleModKey ~= 'None' and toggleModKey2 ~= 'None' and toggleModKey3 == 'None' and toggleKey ~= '' then
		toggleModes = string.format("%s + %s + %s", toggleModKey, toggleModKey2, toggleKey)
	elseif toggleModKey ~= 'None' and toggleModKey2 ~= 'None' and toggleModKey3 ~= 'None' and toggleKey ~= '' then
		toggleModes = string.format("%s + %s + %s + %s", toggleModKey, toggleModKey2, toggleModKey3, toggleKey)
	elseif toggleModKey == 'None' and toggleKey ~= '' then
		toggleModes = string.format("%s", toggleKey)
	end

	ImGui.BeginTooltip()
	ImGui.Text("Click to Toggle Big Bag")
	ImGui.TextColored(ImVec4(1, 1, 0, 1), "%s", toggleModes)
	ImGui.SameLine()
	ImGui.Text("to Toggle GUI")
	if toggleMouse ~= 'None' then
		ImGui.TextColored(ImVec4(1.000, 0.671, 0.257, 0.500), "%s  Mouse Button", toggleMouse)
		ImGui.SameLine()
		ImGui.Text(" to Toggle GUI")
	end
	ImGui.Text(string.format("Used/Free Slots "))
	ImGui.SameLine()
	ImGui.TextColored(FreeSlots > MIN_SLOTS_WARN and ImVec4(0.354, 1.000, 0.000, 0.500) or ImVec4(1.000, 0.354, 0.0, 0.5), "(%s/%s)", UsedSlots, FreeSlots)
	ImGui.EndTooltip()
end
local function renderBtn()
	-- apply_style()
	local colorCount, styleCount = Module.ThemeLoader.StartTheme(themeName, Module.Theme)
	ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(9, 9))
	local openBtn, showBtn = ImGui.Begin(string.format("Big Bag##Mini"), true, bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoCollapse))
	if not openBtn then
		showBtn = false
	end

	if showBtn then
		if FreeSlots > MIN_SLOTS_WARN then
			animMini:SetTextureCell(3635 - EQ_ICON_OFFSET)
			ImGui.DrawTextureAnimation(animMini, 34, 34, true)
		else
			animMini:SetTextureCell(3632 - EQ_ICON_OFFSET)
			ImGui.DrawTextureAnimation(animMini, 34, 34, true)
		end

		if ImGui.IsItemHovered() then
			BigButtonTooltip()
			if ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
				Module.ShowGUI = not Module.ShowGUI
			end
		end

		if toggleMouse ~= 'None' then
			if ImGui.IsMouseReleased(ImGuiMouseButton[toggleMouse]) then
				Module.ShowGUI = not Module.ShowGUI
			end
		end
		if toggleModKey ~= 'None' and toggleKey ~= '' and toggleModKey2 == 'None' and toggleModKey3 == 'None' then
			if ImGui.IsKeyPressed(ImGuiKey[toggleKey]) and ImGui.IsKeyDown(ImGuiMod[toggleModKey]) then
				Module.ShowGUI = not Module.ShowGUI
			end
		elseif toggleModKey ~= 'None' and toggleKey ~= '' and toggleModKey2 ~= 'None' and toggleModKey3 == 'None' then
			if ImGui.IsKeyPressed(ImGuiKey[toggleKey]) and ImGui.IsKeyDown(ImGuiMod[toggleModKey]) and ImGui.IsKeyDown(ImGuiMod[toggleModKey2]) then
				Module.ShowGUI = not Module.ShowGUI
			end
		elseif toggleModKey ~= 'None' and toggleKey ~= '' and toggleModKey2 ~= 'None' and toggleModKey3 ~= 'None' then
			if ImGui.IsKeyPressed(ImGuiKey[toggleKey]) and ImGui.IsKeyDown(ImGuiMod[toggleModKey]) and ImGui.IsKeyDown(ImGuiMod[toggleModKey2]) and ImGui.IsKeyDown(ImGuiMod[toggleModKey3]) then
				Module.ShowGUI = not Module.ShowGUI
			end
		elseif toggleModKey == 'None' and toggleKey ~= '' then
			if ImGui.IsKeyPressed(ImGuiKey[toggleKey]) then
				Module.ShowGUI = not Module.ShowGUI
			end
		end
	end
	ImGui.PopStyleVar()
	Module.ThemeLoader.EndTheme(colorCount, styleCount)
	ImGui.End()
end
--- ImGui Program Loop

local function RenderTabs()
	local colorCount, styleCount = Module.ThemeLoader.StartTheme(themeName, Module.Theme)

	local open, show = ImGui.Begin(string.format("Big Bag"), true, ImGuiWindowFlags.NoScrollbar)
	if not open then
		show = false
		Module.ShowGUI = false
	end
	if show then
		display_bag_utilities()
		ImGui.SetWindowFontScale(1.25)
		ImGui.Text(string.format("Used/Free Slots "))
		ImGui.SameLine()
		ImGui.TextColored(FreeSlots > MIN_SLOTS_WARN and ImVec4(0.354, 1.000, 0.000, 0.500) or ImVec4(1.000, 0.354, 0.0, 0.5), "(%s/%s)", UsedSlots, FreeSlots)
		ImGui.SameLine()
		ImGui.Text("Weight")
		ImGui.SameLine()
		ImGui.TextColored(myWeight > myStr and ImVec4(1.000, 0.254, 0.0, 1.0) or ImVec4(0, 1, 1, 1), "%d / %d", myWeight, myStr)
		draw_currency()

		ImGui.SeparatorText('Inventory / Destroy Area')
		local sizeX = ImGui.GetWindowWidth()

		if ImGui.BeginChild('AutoInvArea', ImVec2((sizeX / 2) - 10, 40), ImGuiChildFlags.Border) then
			ImGui.TextDisabled("Inventory Coin/Item")
		end
		ImGui.EndChild()
		if ImGui.IsItemHovered() and ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
			mq.cmd("/autoinventory")
		end

		ImGui.SameLine()

		ImGui.PushStyleColor(ImGuiCol.ChildBg, ImVec4(0.2, 0, 0, 1))
		if ImGui.BeginChild('DestroyArea', ImVec2((sizeX / 2) - 15, 40), ImGuiChildFlags.Border) then
			ImGui.TextDisabled("Destroy Item")
		end
		ImGui.EndChild()
		ImGui.PopStyleColor()
		if ImGui.IsItemHovered() and mq.TLO.Cursor() then
			if ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
				mq.cmd("/destroy")
			end
		end

		ImGui.Separator()
		if ImGui.BeginChild("BagTabs") then
			if ImGui.BeginTabBar("##BagTabs") then
				if ImGui.BeginTabItem("Items") then
					display_bag_content()
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem('Clickies') then
					display_clickies()
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem('Augments') then
					display_augments()
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem('Details') then
					display_details()
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem("Bank") then
					draw_bank_coin()
					display_bank_content()
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem('Settings') then
					display_bag_options()
					ImGui.EndTabItem()
				end
				ImGui.EndTabBar()
			end
		end
		ImGui.EndChild()
		if ImGui.IsItemHovered() and mq.TLO.Cursor() then
			-- Autoinventory any items on the cursor if you click in the bag UI
			if ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
				mq.cmd("/autoinventory")
			end
		end

		-- display_item_on_cursor()
	end
	ImGui.SetWindowFontScale(1)
	Module.ThemeLoader.EndTheme(colorCount, styleCount)
	ImGui.End()
end

function Module.RenderGUI()
	if not Module.IsRunning then return end
	if Module.ShowGUI then
		RenderTabs()
	end

	renderBtn()

	draw_qty_win()
end

local function init()
	Module.IsRunning = true
	loadSettings()
	create_inventory()
	mq.bind("/bigbag", Module.CommandHandler)

	if not loadedExeternally then
		mq.imgui.init("BigBagGUI", Module.RenderGUI)
		Module.LocalLoop()
		printf("%s Loaded", Module.Name)
		printf("\aw[\at%s\ax] \atCommands", Module.Name)
		printf("\aw[\at%s\ax] \at/bigbag ui \ax- Toggle GUI", Module.Name)
		printf("\aw[\at%s\ax] \at/bigbag exit \ax- Exits", Module.Name)
	end
end
--- Main Script Loop
function Module.LocalLoop()
	while Module.IsRunning do
		mq.delay("1s")
		Module.MainLoop()
	end
end

function Module.CommandHandler(...)
	local args = { ..., }
	if args[1]:lower() == "ui" then
		Module.ShowGUI = not Module.ShowGUI
	elseif args[1]:lower() == 'exit' then
		Module.IsRunning = false
	end
end

function Module.MainLoop()
	if loadedExeternally then
		if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
	end
	create_inventory()
	if needSort then
		sort_inventory()
		needSort = false
	end
	if do_process_coin then
		process_coin()
		do_process_coin = false
	end
	if os.time() - coin_timer > 2 then
		UpdateCoin()
		coin_timer = os.time()
	end
	myWeight = MySelf.CurrentWeight()
	myStr = MySelf.STR()
end

function Module.Unload()
	mq.unbind("/bigbag")
end

init()
return Module
