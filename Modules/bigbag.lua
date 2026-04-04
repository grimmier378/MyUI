local mq                   = require("mq")
local ImGui                = require("ImGui")
local Module               = {}
Module.Name                = "BigBag"
Module.IsRunning           = false
Module.ShowGUI             = false
Module.TempSettings        = {}
Module.TempSettings.Popped = {}

local loadedExternally    = MyUI ~= nil and true or false

if not loadedExternally then
    Module.Path          = string.format("%s/%s/", mq.luaDir, Module.Name)
    Module.ThemeFile     = Module.ThemeFile == nil and string.format('%s/MyUI/ThemeZ.lua', mq.configDir) or Module.ThemeFile
    Module.Theme         = require('defaults.themes')
    Module.ThemeLoader   = require('lib.theme_loader')
    Module.Colors        = require('lib.colors')
    Module.Utils         = require('lib.common')
    Module.CharLoaded    = mq.TLO.Me.DisplayName()
    Module.InventoryData = require('lib.inventory_data')
    Module.Icons         = require('mq.ICONS')
else
    Module.Path = MyUI.Path
    Module.Colors = MyUI.Colors
    Module.ThemeFile = MyUI.ThemeFile
    Module.Theme = MyUI.Theme
    Module.ThemeLoader = MyUI.ThemeLoader
    Module.Utils = MyUI.Utils
    Module.CharLoaded = MyUI.CharLoaded
    Module.InventoryData = MyUI.InventoryData
    Module.Icons = MyUI.Icons
end
local InventoryData                                       = Module.InventoryData
local Utils                                               = Module.Utils
local ToggleFlags                                         = bit32.bor(
    Utils.ImGuiToggleFlags.PulseOnHover,
    Utils.ImGuiToggleFlags.StarKnob,
    Utils.ImGuiToggleFlags.RightLabel)
-- Constants
local ICON_WIDTH                                          = 40
local ICON_HEIGHT                                         = 40
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
local equipped_clickies                                   = {}
local bank_items                                          = {}
local bank_augments                                       = {}
local book                                                = {}
local trade_list                                          = {}
local display_tables                                      = {
    augments = {},
    items = {},
    clickies = {},
    bank_items = {},
    bank_augments = {},
    onehand = {},
    twohand = {},
    ranged = {},
    j_charm = {},
    j_ears = {},
    j_face = {},
    j_neck = {},
    j_fingers = {},
}
local needSort                                            = true
local checkAll                                            = false
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
local doTrade                                             = false
local defaults                                            = {
    MIN_SLOTS_WARN = 3,
    show_item_background = true,
    sort_order = { name = false, stack = false, item_type = false, },
    themeName = "Default",
    toggleKey = '',
    toggleModKey = 'None',
    toggleModKey2 = 'None',
    toggleModKey3 = 'None',
    toggleMouse = 'None',
    INVENTORY_DELAY_SECONDS = 20,
    highlightUseable = true,
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
local equipSlots                                          = InventoryData.equipSlots

function Module:LoadSettings()
    if utils.File.Exists(configFile) then
        settings = dofile(configFile)
    else
        settings = defaults
    end

    if not loadedExternally then
        if utils.File.Exists(self.ThemeFile) then
            self.Theme = dofile(self.ThemeFile)
        end
    end

    for k, v in pairs(defaults) do
        if settings[k] == nil then
            settings[k] = v
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
    for k, v in pairs(settings.sort_order) do
        if defaults.sort_order[k] == nil then
            settings.sort_order[k] = defaults.sort_order[k]
        end
    end
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

-- Sort routines

---selects and returns the sort function for Main items based on the settings enabled.
---@return function|nil
local function BuildItemSortFunc()
    if sort_order.item_type and sort_order.name and sort_order.stack then
        return function(a, b)
            if a.item.Type() == b.item.Type() then
                if a.item.Name() == b.item.Name() then
                    return a.item.Stack() > b.item.Stack()
                end
                return a.item.Name() < b.item.Name()
            end
            return a.item.Type() < b.item.Type()
        end
    elseif sort_order.item_type and sort_order.name then
        return function(a, b) return a.item.Type() < b.item.Type() or (a.item.Type() == b.item.Type() and a.item.Name() < b.item.Name()) end
    elseif sort_order.item_type and sort_order.stack then
        return function(a, b) return a.item.Type() < b.item.Type() or (a.item.Type() == b.item.Type() and a.item.Stack() > b.item.Stack()) end
    elseif sort_order.name and sort_order.stack then
        return function(a, b) return a.item.Stack() > b.item.Stack() or (a.item.Stack() == b.item.Stack() and a.item.Name() < b.item.Name()) end
    elseif sort_order.stack then
        return function(a, b) return a.item.Stack() > b.item.Stack() end
    elseif sort_order.name then
        return function(a, b) return a.item.Name() < b.item.Name() end
    elseif sort_order.item_type then
        return function(a, b) return a.item.Type() < b.item.Type() end
    end
    return nil
end

local function SortByName(a, b) return a.Name() < b.Name() end

local function SortByTypeName(a, b) return a.Type() < b.Type() or (a.Type() == b.Type() and a.Name() < b.Name()) end

function Module:SortInv()
    local sortFunc = BuildItemSortFunc()
    if sortFunc then
        table.sort(items, sortFunc)
    end

    -- bank sorting
    if sort_order.item_type and sort_order.name and sort_order.stack then
        table.sort(bank_items, function(a, b)
            if a.Type() == b.Type() then
                if a.Name() == b.Name() then return a.Stack() > b.Stack() end
                return a.Name() < b.Name()
            end
            return a.Type() < b.Type()
        end)
    elseif sort_order.item_type and sort_order.name then
        table.sort(bank_items, function(a, b) return a.Type() < b.Type() or (a.Type() == b.Type() and a.Name() < b.Name()) end)
    elseif sort_order.item_type and sort_order.stack then
        table.sort(bank_items, function(a, b) return a.Type() < b.Type() or (a.Type() == b.Type() and a.Stack() > b.Stack()) end)
    elseif sort_order.name and sort_order.stack then
        table.sort(bank_items, function(a, b) return a.Stack() > b.Stack() or (a.Stack() == b.Stack() and a.Name() < b.Name()) end)
    elseif sort_order.stack then
        table.sort(bank_items, function(a, b) return a.Stack() > b.Stack() end)
    elseif sort_order.name then
        table.sort(bank_items, SortByName)
    elseif sort_order.item_type then
        table.sort(bank_items, function(a, b) return a.Type() < b.Type() end)
    end
    table.sort(bank_augments, SortByName)

    -- display tables for the UI tabs
    local dt_items, dt_clickies, dt_augments = {}, {}, {}
    local dt_onehand, dt_twohand, dt_ranged = {}, {}, {}
    local dt_j_charm, dt_j_ears, dt_j_face, dt_j_neck, dt_j_fingers = {}, {}, {}, {}, {}

    local jewleryBuckets = {
        Charm = dt_j_charm,
        Ears = dt_j_ears,
        Face = dt_j_face,
        Neck = dt_j_neck,
        Fingers = dt_j_fingers,
    }

    for _, iData in ipairs(items) do
        local itemData = iData.item
        table.insert(dt_items, itemData)
        if iData.isClickie then table.insert(dt_clickies, itemData) end
        if iData.isAug then table.insert(dt_augments, itemData) end
        if iData.jewleryType and jewleryBuckets[iData.jewleryType] then
            table.insert(jewleryBuckets[iData.jewleryType], itemData)
        end
        if iData.weaponType == "onehand" then
            table.insert(dt_onehand, itemData)
        elseif iData.weaponType == "twohand" then
            table.insert(dt_twohand, itemData)
        elseif iData.weaponType == "ranged" then
            table.insert(dt_ranged, itemData)
        end
    end

    for _, ref in ipairs(equipped_clickies) do
        table.insert(dt_clickies, ref)
    end

    -- sort displays
    table.sort(dt_augments, SortByName)
    table.sort(dt_clickies, SortByName)
    table.sort(dt_onehand, SortByTypeName)
    table.sort(dt_twohand, SortByTypeName)
    table.sort(dt_ranged, SortByTypeName)
    table.sort(dt_j_charm, SortByName)
    table.sort(dt_j_ears, SortByName)
    table.sort(dt_j_face, SortByName)
    table.sort(dt_j_neck, SortByName)
    table.sort(dt_j_fingers, SortByName)

    display_tables = {
        items = dt_items,
        clickies = dt_clickies,
        augments = dt_augments,
        onehand = dt_onehand,
        twohand = dt_twohand,
        ranged = dt_ranged,
        j_charm = dt_j_charm,
        j_ears = dt_j_ears,
        j_face = dt_j_face,
        j_neck = dt_j_neck,
        j_fingers = dt_j_fingers,
        bank_items = bank_items,
        bank_augments = bank_augments,
    }
end

function Module:ProcessCoin()
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

function Module:QtyWindow()
    local label = ''
    local maxQty = 0
    if not show_qty_win then
        self.TempSettings.FocusedInput = false
    else
        local labelHint = "Available: "
        if coin_type == 0 then
            labelHint = labelHint .. myPlat
            maxQty = myPlat
            label = 'Plat'
        elseif coin_type == 1 then
            labelHint = labelHint .. myGold
            maxQty = myGold
            label = 'Gold'
        elseif coin_type == 2 then
            labelHint = labelHint .. mySilver
            maxQty = mySilver
            label = 'Silver'
        elseif coin_type == 3 then
            labelHint = labelHint .. myCopper
            maxQty = myCopper
            label = 'Copper'
        end
        ImGui.SetNextWindowPos(ImGui.GetMousePosOnOpeningCurrentPopupVec(), ImGuiCond.Appearing)
        local open, show = ImGui.Begin("Quantity##" .. coin_type, true, bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoDocking, ImGuiWindowFlags.AlwaysAutoResize))
        if not open then
            show_qty_win = false
            self.TempSettings.FocusedInput = false
        end
        if show then
            ImGui.Text("Enter %s Qty", label)
            ImGui.Separator()
            local changed = false
            coin_qty, changed = ImGui.InputTextWithHint("##Qty", labelHint, coin_qty, ImGuiInputTextFlags.EnterReturnsTrue)
            if not self.TempSettings.FocusedInput then
                ImGui.SetKeyboardFocusHere(-1)
                self.TempSettings.FocusedInput = true
            end
            if ImGui.Button('Max##maxqty') then
                coin_qty = string.format("%s", maxQty)
            end
            ImGui.SameLine()
            if ImGui.Button("OK##qty") or changed then
                show_qty_win = false
                do_process_coin = true
                self.TempSettings.FocusedInput = false
            end
            ImGui.SameLine()
            if ImGui.Button("Cancel##qty") then
                show_qty_win = false
                self.TempSettings.FocusedInput = false
            end
        end
        ImGui.End()
    end
end

function Module:DrawCurrency()
    animItems:SetTextureCell(644 - EQ_ICON_OFFSET)
    ImGui.DrawTextureAnimation(animItems, 20, 20)
    ImGui.SameLine()
    ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", InventoryData.CommaSepValue(myPlat))
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text("%s Platinum", InventoryData.CommaSepValue(myPlat))
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
    ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", InventoryData.CommaSepValue(myGold))
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text("%s Gold", InventoryData.CommaSepValue(myGold))
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
    ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", InventoryData.CommaSepValue(mySilver))
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text("%s Silver", InventoryData.CommaSepValue(mySilver))
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
    ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", InventoryData.CommaSepValue(myCopper))
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text("%s Copper", InventoryData.CommaSepValue(myCopper))
        ImGui.EndTooltip()
        if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
            show_qty_win = true
            coin_type = 3
        end
    end
end

function Module:DrawBankCurrency()
    ImGui.SeparatorText("Money in Bank:")
    animItems:SetTextureCell(644 - EQ_ICON_OFFSET)
    ImGui.DrawTextureAnimation(animItems, 20, 20)
    ImGui.SameLine()
    ImGui.TextColored(ImVec4(0, 1, 1, 1), " %s", InventoryData.CommaSepValue(bankPlat))
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text("%s Platinum", InventoryData.CommaSepValue(bankPlat))
        ImGui.EndTooltip()
    end

    ImGui.SameLine()

    animItems:SetTextureCell(645 - EQ_ICON_OFFSET)
    ImGui.DrawTextureAnimation(animItems, 20, 20)
    ImGui.SameLine()
    ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", InventoryData.CommaSepValue(bankGold))
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text("%s Gold", InventoryData.CommaSepValue(bankGold))
        ImGui.EndTooltip()
    end

    ImGui.SameLine()

    animItems:SetTextureCell(646 - EQ_ICON_OFFSET)
    ImGui.DrawTextureAnimation(animItems, 20, 20)
    ImGui.SameLine()
    ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", InventoryData.CommaSepValue(bankSilver))
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text("%s Silver", InventoryData.CommaSepValue(bankSilver))
        ImGui.EndTooltip()
    end

    ImGui.SameLine()

    animItems:SetTextureCell(647 - EQ_ICON_OFFSET)
    ImGui.DrawTextureAnimation(animItems, 20, 20)
    ImGui.SameLine()
    ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", InventoryData.CommaSepValue(bankCopper))
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text("%s Copper", InventoryData.CommaSepValue(bankCopper))
        ImGui.EndTooltip()
    end
    ImGui.SeparatorText('Items in Bank:')
end

function Module:UpdateCoin()
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

function Module:CreateBank()
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

function Module:CreateInventory()
    local jSlots = { ['Charm'] = true, ['Ears'] = true, ['Neck'] = true, ['Fingers'] = true, ['Face'] = true, }
    local weaponSlots = { ['Primary'] = true, ['Secondary'] = true, ['Ranged'] = true, }
    local weaponTypes = {
        ["1H Slashing"] = true,
        ["1H Blunt"] = true,
        ["Piercing"] = true,
        ["2H Slashing"] = true,
        ["2H Blunt"] = true,
        ["2H Piercing"] = true,
        ["Archery"] = true,
        ["Ammo"] = true,
        ["Martial"] = true,
    }

    ---@param item MQItem
    ---@return string|nil jewleryType  ("charm", "ears", "neck", "fingers", "face")
    local function checkJewleryType(item)
        if not item() then return nil end
        for i = 1, item.WornSlots() or 0 do
            local slotID = item.WornSlot(i)()
            local slotName = equipSlots[tonumber(slotID)]
            if jSlots[slotName] and (item.AugType() or 0) == 0 then
                return slotName
            end
        end
        return nil
    end

    ---@param item MQItem
    ---@return string|nil weaponType ("Ranged", 'onehand', 'twohand')
    local function checkWeaponType(item)
        if not item() then return nil end
        for i = 1, item.WornSlots() or 0 do
            local slotID = item.WornSlot(i)()
            if weaponSlots[equipSlots[tonumber(slotID)]] and weaponTypes[item.Type()] then
                if item.Type() == "Ammo" or item.Type() == "Archery" then
                    return "ranged"
                elseif item.Type():find("2H") then
                    return "twohand"
                else
                    return "onehand"
                end
            end
        end
        return nil
    end

    ---@param item MQItem
    ---@return table DataTable {item, isClickie, isAug, jewleryType, weaponType}
    local function getItemData(item)
        return {
            item = item,
            isClickie = item.Clicky() and true or false,
            isAug = (item.AugType() or 0) > 0,
            jewleryType = checkJewleryType(item),
            weaponType = checkWeaponType(item),
        }
    end

    if ((os.difftime(os.time(), start_time)) > INVENTORY_DELAY_SECONDS) or mq.TLO.Me.FreeInventory() ~= FreeSlots or clicked then
        start_time = os.time()
        items = {}
        equipped_clickies = {}
        local tmpUsedSlots = 0

        for i = 1, 22, 1 do
            local slot = mq.TLO.Me.Inventory(i)
            if slot.ID() ~= nil and slot.Clicky() then
                table.insert(equipped_clickies, slot)
            end
        end

        for i = 23, 34, 1 do
            local slot = mq.TLO.Me.Inventory(i)
            if slot.Container() and (slot.Container() or 0) > 0 then
                for j = 1, (slot.Container()), 1 do
                    if (slot.Item(j)()) then
                        local itemName = slot.Item(j).Name() or 'unknown'
                        table.insert(items, getItemData(slot.Item(j)))

                        if trade_list[itemName] == nil and not slot.Item(j).NoDrop() and not slot.Item(j).NoTrade() then
                            trade_list[itemName] = false
                        end
                        tmpUsedSlots = tmpUsedSlots + 1

                        -- check spells and songs against our spellbook
                        local isSpell = itemName:find("Spell:")
                        local isSong = itemName:find("Song:")
                        if isSpell or isSong then
                            local spellName = slot.Item(j).Spell.Name()
                            if spellName and not book[spellName] then
                                book[spellName] = mq.TLO.Me.Book(spellName)() and true or false
                            end
                        end
                    end
                end
            elseif slot.ID() ~= nil then
                table.insert(items, getItemData(slot))
                tmpUsedSlots = tmpUsedSlots + 1
            end
        end

        if tmpUsedSlots ~= UsedSlots then
            UsedSlots = tmpUsedSlots
        end
        FreeSlots = mq.TLO.Me.FreeInventory()
        needSort = true
        clicked = false
        self:CreateBank()
    end
end

-- Converts between ItemSlot and /itemnotify pack numbers
function Module:SlotToPack(slot_number)
    return InventoryData.SlotToPack(slot_number)
end

function Module:SlotToBagSlot(slot_number)
    return InventoryData.SlotToBagSlot(slot_number)
end

-- Displays static utilities that always show at the top of the UI
function Module:RenderHeader()
    ImGui.PushItemWidth(200)
    local text, selected = ImGui.InputText("Filter", filter_text)
    ImGui.PopItemWidth()
    if selected then filter_text = string.gsub(text, "[^a-zA-Z0-9'`_-.]", "") or "" end
    text = filter_text
    ImGui.SameLine()
    if ImGui.SmallButton("Clear") then filter_text = "" end
end

-- Display the collapasable menu area above the items
function Module:RenderSettings()
    if ImGui.BeginChild("OptionsChild") then
        if ImGui.CollapsingHeader("Bag Options") then
            local changed = false
            sort_order.name, changed = self.Utils.DrawToggle("Name", sort_order.name, ToggleFlags)
            if changed then
                needSort = true
                settings.sort_order.name = sort_order.name
                mq.pickle(configFile, settings)
                clicked = true
            end
            ImGui.SameLine()
            self.Utils.DrawHelpMarker("Order items from your inventory sorted by the name of the item.")

            local pressed = false
            sort_order.stack, pressed = self.Utils.DrawToggle("Stack", sort_order.stack, ToggleFlags)
            if pressed then
                needSort = true
                settings.sort_order.stack = sort_order.stack
                mq.pickle(configFile, settings)
                clicked = true
            end
            ImGui.SameLine()
            self.Utils.DrawHelpMarker("Order items with the largest stacks appearing first.")

            local pressed3 = false
            sort_order.item_type, pressed3 = self.Utils.DrawToggle("Item Type", sort_order.item_type, ToggleFlags)
            if pressed3 then
                needSort = true
                settings.sort_order.item_type = sort_order.item_type
                mq.pickle(configFile, settings)
                clicked = true
            end
            ImGui.SameLine()
            self.Utils.DrawHelpMarker("Order items by their type (e.g. Armor, 1H Slash, etc.)")

            local pressed2 = false
            show_item_background, pressed2 = self.Utils.DrawToggle("Show Slot Background", show_item_background, ToggleFlags)
            if pressed2 then
                settings.show_item_background = show_item_background
                mq.pickle(configFile, settings)
            end
            ImGui.SameLine()
            self.Utils.DrawHelpMarker("Removes the background texture to give your bag a cool modern look.")

            ImGui.SetNextItemWidth(100)
            MIN_SLOTS_WARN = ImGui.InputInt("Min Slots Warning", MIN_SLOTS_WARN, 1, 10)
            if MIN_SLOTS_WARN ~= settings.MIN_SLOTS_WARN then
                settings.MIN_SLOTS_WARN = MIN_SLOTS_WARN
                mq.pickle(configFile, settings)
            end
            ImGui.SameLine()
            self.Utils.DrawHelpMarker("Minimum number of slots before the warning color is displayed.")

            ImGui.SetNextItemWidth(100)
            INVENTORY_DELAY_SECONDS = ImGui.InputInt("Inventory Refresh Time (s)", INVENTORY_DELAY_SECONDS, 1, 10)
            if INVENTORY_DELAY_SECONDS ~= settings.INVENTORY_DELAY_SECONDS then
                settings.INVENTORY_DELAY_SECONDS = INVENTORY_DELAY_SECONDS
                mq.pickle(configFile, settings)
            end
            ImGui.SameLine()
            self.Utils.DrawHelpMarker("Time in seconds between inventory refreshes, if # of free slots hasn't changed.")
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
            self.Utils.DrawHelpMarker("Key to toggle the GUI (A-Z | 0-9 | F1-F12)")
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
                self.Utils.DrawHelpMarker("Modifier Key to toggle the GUI (Ctrl | Alt | Shift)")
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
                    self.Utils.DrawHelpMarker("Modifier Key2 to toggle the GUI (Ctrl | Alt | Shift)")

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
                        self.Utils.DrawHelpMarker("Modifier Key3 to toggle the GUI (Ctrl | Alt | Shift)")
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
            self.Utils.DrawHelpMarker("Mouse Button to toggle the GUI (Left | Right | Middle)")
        end

        if ImGui.CollapsingHeader("Theme Settings##BigBag") then
            ImGui.Text("Cur Theme: %s", themeName)
            -- Combo Box Load Theme
            if ImGui.BeginCombo("Load Theme##BigBag", themeName) then
                for k, data in pairs(self.Theme.Theme) do
                    if data ~= nil then
                        local isSelected = data.Name == themeName
                        if ImGui.Selectable(data.Name, isSelected) then
                            settings.themeName = data.Name
                            themeName = settings.themeName
                            mq.pickle(configFile, settings)
                        end
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
function Module:RenderBtnLbl(item)
    if not item.slot_in_bag then
        return string.format("##slot_%s", item.ItemSlot())
    else
        return string.format("##bag_%s_slot_%s", item.ItemSlot(), item.ItemSlot2())
    end
end

---comment
---@param item any
---@return boolean colorChange #should we change color
---@return boolean trashItem #is the item considered trash
---@return boolean lvlHigh #is the level higher than player level
---@return string toolTipSpell #the tooltip for the spell if spell
function Module:ColorItemInfo(item)
    local isSpell = item.Name():find("Spell:")
    local isSong = item.Name():find("Song:")
    local iType = item.Type() or ''
    local toolTipSpell = ''
    local colorChange = false
    local lvlHigh = false
    local trashItem = false

    if isSpell or isSong then
        local spellName = item.Spell.Name() --:gsub("Spell: ", ""):gsub("Song: ", "")
        local spellLvl = mq.TLO.Spell(spellName).Level() or 0
        if not book[spellName] then
            if spellLvl > MySelf.Level() then
                lvlHigh = true
            end
            colorChange = true
            toolTipSpell = spellLvl > 0 and string.format("Lvl %s", spellLvl) or ''
        else
            toolTipSpell = "Already Know"
        end
    else
        if iType == 'Combinable' or iType == 'Food' or iType == 'Drink' then
            trashItem = true
            colorChange = false
        else
            colorChange = true
        end
    end
    return colorChange, trashItem, lvlHigh, toolTipSpell
end

---Draws the individual item icon in the bag.
---@param item item The item object
function Module:Draw_Item_Icon(item, iconWidth, iconHeight, drawID, clickable, iconOnly)
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
    local canUse = (item.CanUse() and settings.HighlightUseable) or false
    ImGui.DrawTextureAnimation(animItems, iconWidth, iconHeight)

    if not iconOnly then
        -- Overlay the stack size text in the lower right corner
        ImGui.PushFont(nil, ImGui.GetFontSize() * 0.68)
        local TextSize = ImGui.CalcTextSize(tostring(item.Stack()))
        if item.Stack() > 1 then
            ImGui.SetCursorPos((cursor_x + offsetX) - TextSize, cursor_y + offsetY)
            ImGui.DrawTextureAnimation(animBox, TextSize, 4)
            ImGui.SetCursorPos((cursor_x + offsetX) - TextSize, cursor_y + offsetY)
            ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", item.Stack())
        end
        local TextSize2 = ImGui.CalcTextSize(tostring(item.Charges()))
        if item.Charges() >= 1 and item.Clicky() then
            ImGui.SetCursorPos((cursor_x + offsetXCharges), cursor_y + offsetYCharges)
            ImGui.DrawTextureAnimation(animBox, TextSize2, 4)
            ImGui.SetCursorPos((cursor_x + offsetXCharges), cursor_y + offsetYCharges)
            ImGui.TextColored(ImVec4(1, 1, 0, 1), "%s", item.Charges())
        end
        ImGui.PopFont()

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
        local colorChange, lvlHigh, toolTipSpell = false, false, ''
        if canUse then
            colorChange, _, lvlHigh, toolTipSpell = self:ColorItemInfo(item)
        end

        if colorChange then
            if lvlHigh then
                ImGui.PushStyleColor(ImGuiCol.Button, 0.8, 0.1, 0.2, 0.2)
            else
                ImGui.PushStyleColor(ImGuiCol.Button, 0, 0.8, 0.2, 0.2)
            end
        end

        ImGui.Button(self:RenderBtnLbl(item), iconWidth, iconHeight)

        if colorChange then
            ImGui.PopStyleColor(1)
        end

        ImGui.PopStyleColor(3)
    end
    ImGui.PopID()

    if not iconOnly then
        -- Tooltip
        if ImGui.IsItemHovered() then
            local charges = item.Charges() or 0
            local clicky = item.Clicky() or 'none'
            ImGui.BeginTooltip()

            InventoryData.RenderItemToolTip(item, { Popped = Module.TempSettings.Popped, highlightUseable = settings.highlightUseable, showItemBackground = show_item_background, })
            ImGui.SeparatorText("Click Actions")
            if clickable then
                ImGui.Text("Right Click to use item")
                ImGui.Text("Left Click Pick Up item")
            end
            ImGui.Text('Shift + Right Click to Pop Out Item Info')
            ImGui.Text("Ctrl + Right Click to Inspect Item")
            ImGui.EndTooltip()
            if ImGui.IsKeyDown(ImGuiMod.Shift) and ImGui.IsItemClicked(ImGuiMouseButton.Right) then
                self.TempSettings.Popped[item.ID()] = item
            end
        end

        if clickable then
            if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
                if mq.TLO.Me.Casting() ~= nil then return end
                if item.ItemSlot2() == -1 then
                    mq.cmd("/itemnotify " .. item.ItemSlot() .. " leftmouseup")
                else
                    -- print(item.ItemSlot2())
                    mq.cmd("/itemnotify in " .. self:SlotToPack(item.ItemSlot()) .. " " .. self:SlotToBagSlot(item.ItemSlot2()) .. " leftmouseup")
                end
            end
            if ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsItemClicked(ImGuiMouseButton.Right) then
                local link = item.ItemLink('CLICKABLE')()
                mq.cmdf('/executelink %s', link)
            elseif ImGui.IsItemClicked(ImGuiMouseButton.Right) and not ImGui.IsKeyDown(ImGuiMod.Shift) then
                if mq.TLO.Me.Casting() ~= nil then return end
                mq.cmdf('/useitem "%s"', item.Name())
                clicked = true
            end
        else
            if (ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsItemClicked(ImGuiMouseButton.Right)) then
                local link = item.ItemLink('CLICKABLE')()
                mq.cmdf('/executelink %s', link)
            end
        end
    end
end

---Handles the bag layout of individual items
function Module:RenderBagContents(contentType)
    if contentType == nil then
        contentType = 'items'
    end
    -- create_inventory()
    if ImGui.BeginChild("BagContent##" .. contentType, 0.0, 0.0) then
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
        local bag_window_width = ImGui.GetWindowWidth()
        local bag_cols = math.floor(bag_window_width / BAG_ITEM_SIZE)
        local temp_bag_cols = 1

        for index, _ in ipairs(display_tables[contentType] or {}) do
            if string.match(string.lower(display_tables[contentType][index].Name()), string.lower(filter_text)) then
                self:Draw_Item_Icon(display_tables[contentType][index], ICON_WIDTH, ICON_HEIGHT, 'inv' .. index, true)
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

function Module:RenderWeapons()
    if ImGui.BeginChild("BagWeapons", 0.0, 0.0) then
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
        local function drawItemsTables(tableName)
            local bag_window_width = ImGui.GetWindowWidth()
            local bag_cols = math.floor(bag_window_width / BAG_ITEM_SIZE)
            local temp_bag_cols = 1
            for index, _ in ipairs(display_tables[tableName] or {}) do
                if string.match(string.lower(display_tables[tableName][index].Name()), string.lower(filter_text)) then
                    self:Draw_Item_Icon(display_tables[tableName][index], ICON_WIDTH, ICON_HEIGHT, tableName .. index, true)
                    if bag_cols > temp_bag_cols then
                        temp_bag_cols = temp_bag_cols + 1
                        ImGui.SameLine()
                    else
                        temp_bag_cols = 1
                    end
                end
            end
            ImGui.NewLine()
        end
        ImGui.SeparatorText('1 Handed Weapons')
        drawItemsTables('onehand')
        ImGui.SeparatorText('2 Handed Weapons')
        drawItemsTables('twohand')
        ImGui.SeparatorText('Ranged Weapons')
        drawItemsTables('ranged')

        ImGui.PopStyleVar()
    end
    ImGui.EndChild()
end

function Module:RenderJewlery()
    if ImGui.BeginChild("BagJewlery", 0.0, 0.0) then
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
        local function drawItemsTables(tableName)
            local bag_window_width = ImGui.GetWindowWidth()
            local bag_cols = math.floor(bag_window_width / BAG_ITEM_SIZE)
            local temp_bag_cols = 1
            for index, _ in ipairs(display_tables[tableName] or {}) do
                if string.match(string.lower(display_tables[tableName][index].Name()), string.lower(filter_text)) then
                    self:Draw_Item_Icon(display_tables[tableName][index], ICON_WIDTH, ICON_HEIGHT, tableName .. index, true)
                    if bag_cols > temp_bag_cols then
                        temp_bag_cols = temp_bag_cols + 1
                        ImGui.SameLine()
                    else
                        temp_bag_cols = 1
                    end
                end
            end
            ImGui.NewLine()
        end
        ImGui.SeparatorText('Charms')
        drawItemsTables('j_charm')
        ImGui.SeparatorText('Earrings')
        drawItemsTables('j_ears')
        ImGui.SeparatorText('Masks / Face')
        drawItemsTables('j_face')
        ImGui.SeparatorText('Necklaces')
        drawItemsTables('j_neck')
        ImGui.SeparatorText('Rings')
        drawItemsTables('j_fingers')

        ImGui.PopStyleVar()
    end
    ImGui.EndChild()
end

function Module:RenderDetails()
    if ImGui.Button("Trade Selected Items") then
        doTrade = true
    end
    ImGui.SameLine()
    checkAll = false
    if ImGui.Button("Check All") then
        checkAll = true
    end
    if ImGui.BeginTable("Details", 9, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.ScrollY, ImGuiTableFlags.Resizable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Reorderable)) then
        ImGui.TableSetupColumn('Trade', ImGuiTableColumnFlags.WidthFixed, 25)
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
        for index, _ in ipairs(display_tables.items or {}) do
            ImGui.PushID(index)
            if string.match(string.lower(display_tables.items[index].Name()), string.lower(filter_text)) then
                local item = display_tables.items[index]
                local clicky = item.Clicky() or 'No'
                local charges = item.Charges()
                local lbl = 'Infinite'
                if charges == -1 then
                    lbl = 'Infinite'
                elseif charges == 0 or clicky == 'No' then
                    lbl = 'None'
                else
                    lbl = charges
                end
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                if trade_list[item.Name()] ~= nil then
                    if checkAll then
                        trade_list[item.Name()] = true -- Check all items if the button is pressed
                    end
                    trade_list[item.Name()], _ = ImGui.Checkbox(string.format("##Trade_%s", index), trade_list[item.Name()])
                else
                    ImGui.TextColored(ImVec4(0.51, 0.4, 0.1, 1), "NA")
                    if ImGui.IsItemHovered() then
                        ImGui.BeginTooltip()
                        ImGui.Text("This item is NO TRADE")
                        ImGui.EndTooltip()
                    end
                end
                ImGui.TableNextColumn()
                Module:Draw_Item_Icon(item, 20, 20, 'details' .. index, true)
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
                ImGui.TextColored(self.Colors.color('teal'), clicky)
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

function Module:ClickTrade()
    mq.delay(3000)
    if mq.TLO.Window("TradeWnd").Open() then
        mq.TLO.Window("TradeWnd").Child("TRDW_Trade_Button").LeftMouseUp()
    end
    mq.delay(3000)
    if mq.TLO.Window("GiveWnd").Open() then
        mq.TLO.Window("GiveWnd").Child("GVW_Give_Button").LeftMouseUp()
    end
    mq.delay(3000)
end

function Module:TradeItems()
    local target = mq.TLO.Target
    if not target() and not target.Type() == "PC" and (target.Name() or "unknown") ~= self.CharLoaded then
        printf('[\ayBigBag\ax] \amTarget is NOT selected\ax')
        doTrade = false
        return
    end
    local target_id = target.ID() or 0
    if target.Distance() > 15 then
        mq.cmdf("/nav id %s dist=12", target_id)
        while mq.TLO.Navigation.Active() do
            mq.delay(1000, function() return not mq.TLO.Navigation.Active() end)
        end
    end

    local counter = 1
    for itemName, trade in pairs(trade_list) do
        if trade then
            if mq.TLO.FindItem(itemName).ID() ~= nil then
                local itemSlot = mq.TLO.FindItem('=' .. itemName).ItemSlot() or 0
                local itemSlot2 = mq.TLO.FindItem('=' .. itemName).ItemSlot2() or 0
                if itemSlot == 0 or itemSlot2 == 0 then
                    goto Next -- Skip if we don't have a valid item slot
                end
                local pickup1 = itemSlot - 22
                local pickup2 = itemSlot2 + 1

                --grab the whole stack, or specific amount
                mq.cmd('/shift /itemnotify in pack' .. pickup1 .. ' ' .. pickup2 .. ' leftmouseup')
                -- mq.cmdf("/itemnotify %s leftmouseup", itemName)
                mq.delay(3000, function() return mq.TLO.Cursor() ~= nil end)
                if (mq.TLO.Cursor.Container() or 0) > 0 then
                    mq.cmd("/autoinventory")
                    mq.delay(3000, function() return mq.TLO.Cursor() == nil end)
                end
                if mq.TLO.Cursor() ~= nil then
                    mq.TLO.Target.LeftClick()
                end
                mq.delay(3000, function() return mq.TLO.Cursor() == nil end)

                if counter == 8 then
                    self:ClickTrade()
                    mq.delay(3000, function() return not mq.TLO.Window("TradeWnd").Open() end)
                    counter = 1
                else
                    counter = counter + 1
                end
            end
            ::Next::
            trade_list[itemName] = false -- Reset the trade list for this item
        end
    end
    self:ClickTrade()
    doTrade = false
    trade_list = {}
    self:CreateInventory()
end

function Module:BigButtonTooltip()
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

function Module:RenderMiniButton(grouped)
    if not grouped then
        local colorCount, styleCount = self.ThemeLoader.StartTheme(themeName, self.Theme)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(9, 9))
        local openBtn, showBtn = ImGui.Begin(string.format("Big Bag##Mini"), true, bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoCollapse))
        if not openBtn then
            showBtn = false
        end

        if showBtn then
            local cursorX, cursorY = ImGui.GetCursorScreenPos()
            if FreeSlots > MIN_SLOTS_WARN then
                animMini:SetTextureCell(3635 - EQ_ICON_OFFSET)
                ImGui.DrawTextureAnimation(animMini, 34, 34, true)
                ImGui.SetCursorPos(20, 20)
                Module.Utils.DropShadow(FreeSlots, { Enabled = true, })
            else
                animMini:SetTextureCell(3632 - EQ_ICON_OFFSET)
                ImGui.DrawTextureAnimation(animMini, 34, 34, true)
                ImGui.SetCursorPos(20, 20)
                Module.Utils.DropShadow(FreeSlots, { Enabled = true, }, nil, Module.Utils.Colors.color('teal'))
            end

            ImGui.SetCursorScreenPos(cursorX, cursorY)
            ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0, 0.5, 0.5, 0.5))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImVec4(0, 0, 0, 0))
            if ImGui.Button("##BigBagsBtn", ImVec2(34, 34)) then
                self.ShowGUI = not self.ShowGUI
            end
            ImGui.PopStyleColor(3)

            if ImGui.IsItemHovered() then
                self:BigButtonTooltip()
            end
        end
        ImGui.PopStyleVar()
        self.ThemeLoader.EndTheme(colorCount, styleCount)
        ImGui.End()
        return
    end

    local cursorX, cursorY = ImGui.GetCursorScreenPos()
    if FreeSlots > MIN_SLOTS_WARN then
        animMini:SetTextureCell(3635 - EQ_ICON_OFFSET)
        ImGui.DrawTextureAnimation(animMini, 34, 34, true)
        ImGui.SetCursorPos(20, 20)
        Module.Utils.DropShadow(FreeSlots, { Enabled = true, })
    else
        animMini:SetTextureCell(3632 - EQ_ICON_OFFSET)
        ImGui.DrawTextureAnimation(animMini, 34, 34, true)
        ImGui.SetCursorPos(20, 20)
        Module.Utils.DropShadow(FreeSlots, { Enabled = true, }, nil, Module.Utils.Colors.color('teal'))
    end

    ImGui.SetCursorScreenPos(cursorX, cursorY)
    ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0, 0.5, 0.5, 0.5))
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImVec4(0, 0, 0, 0))
    if ImGui.Button("##BigBagsBtn", ImVec2(34, 34)) then
        self.ShowGUI = not self.ShowGUI
    end
    ImGui.PopStyleColor(3)

    if ImGui.IsItemHovered() then
        self:BigButtonTooltip()
    end
end

--- ImGui Program Loop

function Module:RenderTabs()
    local colorCount, styleCount = self.ThemeLoader.StartTheme(themeName, self.Theme)

    local open, show = ImGui.Begin(string.format("Big Bag"), true, ImGuiWindowFlags.NoScrollbar)
    if not open then
        show = false
        self.ShowGUI = false
    end
    if show then
        self:RenderHeader()
        ImGui.PushFont(nil, ImGui.GetFontSize() * 1.25)
        ImGui.Text(string.format("Used/Free Slots "))
        ImGui.SameLine()
        ImGui.TextColored(FreeSlots > MIN_SLOTS_WARN and ImVec4(0.354, 1.000, 0.000, 0.500) or ImVec4(1.000, 0.354, 0.0, 0.5), "(%s/%s)", UsedSlots, FreeSlots)
        ImGui.SameLine()
        ImGui.Text("Weight")
        ImGui.SameLine()
        ImGui.TextColored(myWeight > myStr and ImVec4(1.000, 0.254, 0.0, 1.0) or ImVec4(0, 1, 1, 1), "%d / %d", myWeight, myStr)
        self:DrawCurrency()

        ImGui.SeparatorText('Inventory / Destroy Area')
        local sizeX = ImGui.GetWindowWidth()

        if ImGui.BeginChild('AutoInvArea', ImVec2((sizeX / 2) - 10, 40), ImGuiChildFlags.Borders) then
            ImGui.TextDisabled("Inventory Coin/Item")
        end
        ImGui.EndChild()
        if ImGui.IsItemHovered() and ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
            mq.cmd("/autoinventory")
        end

        ImGui.SameLine()

        ImGui.PushStyleColor(ImGuiCol.ChildBg, ImVec4(0.2, 0, 0, 1))
        if ImGui.BeginChild('DestroyArea', ImVec2((sizeX / 2) - 15, 40), ImGuiChildFlags.Borders) then
            ImGui.TextDisabled("Destroy Item")
        end
        ImGui.EndChild()
        ImGui.PopStyleColor()
        if ImGui.IsItemHovered() and mq.TLO.Cursor() then
            if ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
                mq.cmd("/destroy")
            end
        end
        local pressed
        ImGui.SetNextItemWidth(100)
        settings.HighlightUseable, pressed = self.Utils.DrawToggle("Highlight Useable", settings.HighlightUseable, Utils.ImGuiToggleFlags.StarKnob)
        if pressed then
            mq.pickle(configFile, settings)
        end
        ImGui.SameLine()
        self.Utils.DrawHelpMarker("Highlight items that are useable by your class.")

        ImGui.Separator()
        ImGui.PopFont()
        if ImGui.BeginChild("BagTabs") then
            if ImGui.BeginTabBar("##BagTabs", bit32.bor(ImGuiTabBarFlags.Reorderable)) then
                if ImGui.BeginTabItem("Items") then
                    self:RenderBagContents('items')
                    ImGui.EndTabItem()
                end
                if ImGui.BeginTabItem("Jewlery") then
                    self:RenderJewlery()
                    ImGui.EndTabItem()
                end
                if ImGui.BeginTabItem('Clickies') then
                    self:RenderBagContents('clickies')
                    ImGui.EndTabItem()
                end
                if ImGui.BeginTabItem('Augments') then
                    -- self:RenderAugs()
                    self:RenderBagContents('augments')
                    ImGui.EndTabItem()
                end

                if ImGui.BeginTabItem('Weapons') then
                    self:RenderWeapons()
                    ImGui.EndTabItem()
                end
                if ImGui.BeginTabItem('Details') then
                    self:RenderDetails()
                    ImGui.EndTabItem()
                end
                if ImGui.BeginTabItem("Bank") then
                    self:DrawBankCurrency()
                    self:RenderBagContents('bank_items')
                    ImGui.EndTabItem()
                end
                if ImGui.BeginTabItem('Settings') then
                    self:RenderSettings()
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
    self.ThemeLoader.EndTheme(colorCount, styleCount)
    ImGui.End()
end

function Module.RenderGUI()
    if not Module.IsRunning then return end
    if toggleMouse ~= 'None' then
        if ImGui.IsMouseReleased(ImGuiMouseButton[toggleMouse]) and not ImGui.IsKeyDown(ImGuiMod.Ctrl) and not ImGui.IsKeyDown(ImGuiMod.Shift) then
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
    if Module.ShowGUI then
        Module:RenderTabs()
    end

    if not MyUI.Settings.GroupButtons then Module:RenderMiniButton() end

    Module:QtyWindow()

    for k, v in pairs(Module.TempSettings.Popped) do
        if v and v.ID() then
            InventoryData.RenderItemInfoWin(v, Module.TempSettings.Popped,
                { Sender = Module.Name, showItemBackground = show_item_background, highlightUseable = settings.highlightUseable, })
        else
            Module.TempSettings.Popped[k] = nil
        end
    end
end

function Module:Init()
    self.IsRunning = true
    self:LoadSettings()
    self:CreateInventory()
    -- get_book()
    mq.bind("/bigbag", self.CommandHandler)

    if not loadedExternally then
        mq.imgui.init("BigBagGUI", self.RenderGUI)
        self:LocalLoop()
        printf("%s Loaded", self.Name)
        printf("\aw[\at%s\ax] \atCommands", self.Name)
        printf("\aw[\at%s\ax] \at/bigbag ui \ax- Toggle GUI", self.Name)
        printf("\aw[\at%s\ax] \at/bigbag exit \ax- Exits", self.Name)
    end
end

--- Main Script Loop
function Module:LocalLoop()
    while self.IsRunning do
        mq.delay("1s")
        self.MainLoop()
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
    if loadedExternally then
        if not MyUI.LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
    end
    Module:CreateInventory()
    if needSort then
        Module:SortInv()
        needSort = false
    end
    if do_process_coin then
        Module:ProcessCoin()
        do_process_coin = false
    end
    if os.time() - coin_timer > 2 then
        Module:UpdateCoin()
        coin_timer = os.time()
    end

    if doTrade then
        Module:TradeItems()
    end

    myWeight = MySelf.CurrentWeight()
    myStr = MySelf.STR()
end

function Module.Unload()
    mq.unbind("/bigbag")
end

Module:Init()
return Module
