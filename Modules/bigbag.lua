local mq                = require("mq")
local ImGui             = require("ImGui")
local Module            = {}
local openGUI           = true
local shouldDrawGUI     = true
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
Module.ImgPath                                   = Module.Path .. "images/bag.png"
local minImg                                     = mq.CreateTexture(Module.ImgPath)
-- Constants
local ICON_WIDTH                                 = 40
local ICON_HEIGHT                                = 40
local COUNT_X_OFFSET                             = 39
local COUNT_Y_OFFSET                             = 23
local EQ_ICON_OFFSET                             = 500
local BAG_ITEM_SIZE                              = 40
local INVENTORY_DELAY_SECONDS                    = 2
local MIN_SLOTS_WARN                             = 3
local FreeSlots                                  = 0
local UsedSlots                                  = 0
local configFile                                 = string.format("%s/MyUI/BigBag/%s/%s.lua", mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.Name())
-- EQ Texture Animation references
local animItems                                  = mq.FindTextureAnimation("A_DragItem")
local animBox                                    = mq.FindTextureAnimation("A_RecessedBox")

-- Toggles
local toggleKey                                  = ''
local toggleModKey, toggleModKey2, toggleModKey3 = 'None', 'None', 'None'
local toggleMouse                                = 'Middle'

-- Bag Contents
local items                                      = {}
local clickies                                   = {}
local needSort                                   = true

-- Bag Options
local sort_order                                 = { name = false, stack = false, }
local clicked                                    = false
-- GUI Activities
local show_item_background                       = true
local themeName                                  = "Default"
local start_time                                 = os.time()
local filter_text                                = ""
local utils                                      = require('mq.Utils')
local settings                                   = {}
local defaults                                   = {
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
local modKeys                                    = {
	"None",
	"Ctrl",
	"Alt",
	"Shift",
}
local mouseKeys                                  = {
	"Left",
	"Right",
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
	elseif sort_order.stack then
		table.sort(items, function(a, b) return a.Stack() > b.Stack() end)
	elseif sort_order.name then
		table.sort(items, function(a, b) return a.Name() < b.Name() end)
		-- else
		-- table.sort(items)
	end
end

-- The beast - this routine is what builds our inventory.
local function create_inventory()
	if ((os.difftime(os.time(), start_time)) > INVENTORY_DELAY_SECONDS) or mq.TLO.Me.FreeInventory() ~= FreeSlots or clicked then
		start_time = os.time()
		items = {}
		clickies = {}
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
					end
				end
			elseif slot.ID() ~= nil then
				table.insert(items, slot) -- We have an item in a bag slot
				tmpUsedSlots = tmpUsedSlots + 1
				if slot.Clicky() then
					table.insert(clickies, slot)
				end
			end
		end

		if tmpUsedSlots ~= UsedSlots then
			UsedSlots = tmpUsedSlots
		end
		FreeSlots = mq.TLO.Me.FreeInventory()
		needSort = true
		clicked = false
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
	if ImGui.CollapsingHeader("Bag Options") then
		local changed = false
		sort_order.name, changed = ImGui.Checkbox("Name", sort_order.name)
		if changed then
			needSort = true
			settings.sort_order.name = sort_order.name
			mq.pickle(configFile, settings)
		end
		ImGui.SameLine()
		help_marker("Order items from your inventory sorted by the name of the item.")

		local pressed = false
		sort_order.stack, pressed = ImGui.Checkbox("Stack", sort_order.stack)
		if pressed then
			needSort = true
			settings.sort_order.stack = sort_order.stack
			mq.pickle(configFile, settings)
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
		toggleKey = ImGui.InputText("##ToggleKey", toggleKey)
		if toggleKey ~= settings.toggleKey then
			settings.toggleKey = toggleKey
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
	ImGui.Separator()
	ImGui.NewLine()
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
local function draw_item_icon(item, iconWidth, iconHeight)
	-- Capture original cursor position
	local cursor_x, cursor_y = ImGui.GetCursorPos()
	local offsetX, offsetY = iconWidth - 1, iconHeight / 1.5
	local offsetXCharges, offsetYCharges = 2, offsetY / 2 -- Draw the background box

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
		ImGui.TextColored(ImVec4(0, 1, 1, 1), item.Stack())
	end
	local TextSize2 = ImGui.CalcTextSize(tostring(item.Charges()))
	if item.Charges() >= 1 then
		ImGui.SetCursorPos((cursor_x + offsetXCharges), cursor_y + offsetYCharges)
		ImGui.DrawTextureAnimation(animBox, TextSize2, 4)
		ImGui.SetCursorPos((cursor_x + offsetXCharges), cursor_y + offsetYCharges)
		ImGui.TextColored(ImVec4(1, 1, 0, 1), item.Charges())
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
		ImGui.Text("Right Click to use item")
		ImGui.Text("Left Click Pick Up item")
		ImGui.Text("Ctrl + Right Click to Inspect Item")
		ImGui.EndTooltip()
	end

	if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
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
	elseif ImGui.IsItemClicked(ImGuiMouseButton.Right) then
		mq.cmdf('/useitem "%s"', item.Name())
		clicked = true
	end
	local function mouse_over_bag_window()
		local window_x, window_y = ImGui.GetWindowPos()
		local mouse_x, mouse_y = ImGui.GetMousePos()
		local window_size_x, window_size_y = ImGui.GetWindowSize()
		return (mouse_x > window_x and mouse_y > window_y) and (mouse_x < window_x + window_size_x and mouse_y < window_y + window_size_y)
	end

	-- Autoinventory any items on the cursor if you click in the bag UI
	if ImGui.IsMouseClicked(ImGuiMouseButton.Left) and mq.TLO.Cursor() and mouse_over_bag_window() then
		mq.cmd("/autoinventory")
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

	ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
	local bag_window_width = ImGui.GetWindowWidth()
	local bag_cols = math.floor(bag_window_width / BAG_ITEM_SIZE)
	local temp_bag_cols = 1

	for index, _ in ipairs(items) do
		if string.match(string.lower(items[index].Name()), string.lower(filter_text)) then
			draw_item_icon(items[index], ICON_WIDTH, ICON_HEIGHT)
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

local function display_clickies()
	ImGui.SetWindowFontScale(1.0)

	ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
	local bag_window_width = ImGui.GetWindowWidth()
	local bag_cols = math.floor(bag_window_width / BAG_ITEM_SIZE)
	local temp_bag_cols = 1

	for index, _ in ipairs(clickies) do
		if string.match(string.lower(clickies[index].Name()), string.lower(filter_text)) then
			draw_item_icon(clickies[index], ICON_WIDTH, ICON_HEIGHT)
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

local function display_details()
	ImGui.SetWindowFontScale(1.0)
	if ImGui.BeginTable("Details", 7, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.ScrollY, ImGuiTableFlags.Resizable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Reorderable)) then
		ImGui.TableSetupColumn('Icon', ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.WidthFixed, 100)
		ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn('Tribute', ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn('Worn EFX', ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn('Clicky', ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn('Charges', ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupScrollFreeze(0, 1)
		ImGui.TableHeadersRow()
		for index, _ in ipairs(items) do
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
				draw_item_icon(item, 20, 20)
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
			end
		end
		ImGui.EndTable()
	end
end

local function renderBtn()
	-- apply_style()
	local colorCount, styleCount = Module.ThemeLoader.StartTheme(themeName, Module.Theme)
	if FreeSlots > MIN_SLOTS_WARN then
		ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetStyleColor(ImGuiCol.Button))
		ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetStyleColor(ImGuiCol.ButtonHovered))
	else
		ImGui.PushStyleColor(ImGuiCol.Button, 1.000, 0.354, 0.0, 0.2)
		ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 1.000, 0.204, 0.0, 0.4)
	end
	local openBtn, showBtn = ImGui.Begin(string.format("Big Bag##Mini"), true, bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoCollapse))
	if not openBtn then
		showBtn = false
	end

	if showBtn then
		if ImGui.ImageButton("BigBag##btn", minImg:GetTextureID(), ImVec2(30, 30)) then
			Module.ShowGUI = not Module.ShowGUI
		end
		if ImGui.IsItemHovered() then
			ImGui.BeginTooltip()
			ImGui.TextUnformatted("Click to Toggle Big Bag")
			ImGui.TextUnformatted("Middle Mouse Click to Toggle GUI")
			ImGui.Text(string.format("Used/Free Slots "))
			ImGui.SameLine()
			ImGui.TextColored(FreeSlots > MIN_SLOTS_WARN and ImVec4(0.354, 1.000, 0.000, 0.500) or ImVec4(1.000, 0.354, 0.0, 0.5), "(%s/%s)", UsedSlots, FreeSlots)
			ImGui.EndTooltip()
		end

		if toggleMouse ~= 'None' then
			if ImGui.IsMouseClicked(ImGuiMouseButton[toggleMouse]) then
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
		if ImGui.BeginTabBar("BagTabs") then
			if ImGui.BeginTabItem("Items") then
				display_bag_content()
				ImGui.EndTabItem()
			end
			if ImGui.BeginTabItem('Clickies') then
				display_clickies()
				ImGui.EndTabItem()
			end
			if ImGui.BeginTabItem('Details') then
				display_details()
				ImGui.EndTabItem()
			end
			if ImGui.BeginTabItem('Settings') then
				display_bag_options()
				ImGui.EndTabItem()
			end
			ImGui.EndTabBar()
		end

		display_item_on_cursor()
	end
	Module.ThemeLoader.EndTheme(colorCount, styleCount)
	ImGui.End()
end

function Module.RenderGUI()
	if not Module.IsRunning then return end
	if Module.ShowGUI then
		RenderTabs()
	end

	renderBtn()
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
end

function Module.Unload()
	mq.unbind("/bigbag")
end

init()
return Module
