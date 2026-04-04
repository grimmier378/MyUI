local mq                = require("mq")
local ImGui             = require("ImGui")
local Module            = {}
Module.Name             = "MyInventory"
Module.IsRunning        = false
Module.ShowGUI          = false
Module.TempSettings     = {
    openContainers = {},
    Popped = {},
}

local loadedExternally = MyUI ~= nil or false

if not loadedExternally then
    Module.Path          = string.format("%s/%s/", mq.luaDir, Module.Name)
    Module.ThemeFile     = string.format('%s/MyUI/ThemeZ.lua', mq.configDir)
    Module.Theme         = require('defaults.themes')
    Module.ThemeLoader   = require('lib.theme_loader')
    Module.Colors        = require('lib.colors')
    Module.Utils         = require('lib.common')
    Module.CharLoaded    = mq.TLO.Me.DisplayName()
    Module.InventoryData = require('lib.inventory_data')
    Module.Icons         = require('mq.ICONS')
else
    Module.Path          = MyUI.Path
    Module.Colors        = MyUI.Colors
    Module.ThemeFile     = MyUI.ThemeFile
    Module.Theme         = MyUI.Theme
    Module.ThemeLoader   = MyUI.ThemeLoader
    Module.Utils         = MyUI.Utils
    Module.CharLoaded    = MyUI.CharLoaded
    Module.InventoryData = MyUI.InventoryData
    Module.Icons         = MyUI.Icons
end

local InventoryData   = Module.InventoryData
local Utils           = Module.Utils
local utils           = require('mq.Utils')

local ICON_WIDTH      = 40
local ICON_HEIGHT     = 40
local EQ_ICON_OFFSET  = 500

local animItems       = mq.FindTextureAnimation("A_DragItem")
local animBox         = mq.FindTextureAnimation("A_RecessedBox")

local slotBackgrounds = {}
local slotBGNames     = {
    [0]  = "A_InvCharm",
    [1]  = "A_InvEar",
    [2]  = "A_InvHead",
    [3]  = "A_InvFace",
    [4]  = "A_InvEar",
    [5]  = "A_InvNeck",
    [6]  = "A_InvShoulders",
    [7]  = "A_InvArms",
    [8]  = "A_InvBack",
    [9]  = "A_InvWrist",
    [10] = "A_InvWrist",
    [11] = "A_InvRange",
    [12] = "A_InvHands",
    [13] = "A_InvPrimary",
    [14] = "A_InvSecondary",
    [15] = "A_InvRing",
    [16] = "A_InvRing",
    [17] = "A_InvChest",
    [18] = "A_InvLegs",
    [19] = "A_InvFeet",
    [20] = "A_InvWaist",
    [21] = "A_InvPowerSource",
    [22] = "A_InvAmmo",
}

for id, name in pairs(slotBGNames) do
    slotBackgrounds[id] = mq.FindTextureAnimation(name)
end

local themeName                          = "Default"
local configFile                         = string.format("%s/MyUI/MyInventory/%s/%s.lua", mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.Name())
local settings                           = {}
local defaults                           = {
    themeName = "Default",
    toggleKey = '',
    toggleModKey = 'None',
    toggleModKey2 = 'None',
    toggleModKey3 = 'None',
}

local invData                            = {
    worn = {},
    bags = {},
    containers = {},
    clickies = {},
    freeSlots = 0,
}
local invRefreshTimer                    = os.time()
local INV_REFRESH_DELAY                  = 5
local lastFreeSlots                      = -1
local pendingAction                      = nil
local forceRefresh                       = false

local myPlat, myGold, mySilver, myCopper = 0, 0, 0, 0
local myWeight, myStr                    = 0, 0
local coinTimer                          = os.time()
local coin_type                          = 0
local coin_qty                           = ''
local show_qty_win                       = false
local do_process_coin                    = false
local MySelf                             = mq.TLO.Me

local toggleKey                          = ''
local toggleModKey                       = 'None'
local toggleModKey2                      = 'None'
local toggleModKey3                      = 'None'
local showSettings                       = false

local modKeys                            = {
    "None",
    "Ctrl",
    "Alt",
    "Shift",
}

local compareSkipKeys = {
    Name = true, Type = true, ID = true, Icon = true, Stack = true, MaxStack = true,
    Clicky = true, Charges = true, ClassList = true, RaceList = true, BonusDmgType = true,
    CanUse = true, isNoDrop = true, isNoRent = true, isNoTrade = true, isAttuneable = true,
    isLore = true, isMagic = true, isEvolving = true,
    Spelleffect = true, Worn = true, Focus1 = true, Focus2 = true,
    SpellDesc = true, WornDesc = true, Focus1Desc = true, Focus2Desc = true, ClickyDesc = true,
    SpellID = true, WornID = true, Focus1ID = true, Focus2ID = true, ClickyID = true,
    AugSlot1 = true, AugSlot2 = true, AugSlot3 = true, AugSlot4 = true, AugSlot5 = true, AugSlot6 = true,
    AugType1 = true, AugType2 = true, AugType3 = true, AugType4 = true, AugType5 = true, AugType6 = true,
    AugSlots = true, WornSlots = true, NumSlots = true, Size = true, SizeCapacity = true,
    Value = true, Weight = true, ReqLvl = true, RecLvl = true, TributeValue = true,
    EvolvingLevel = true, EvolvingExpPct = true, EvolvingMaxLevel = true,
}

local compareLabels = {
    AC = 'AC', HP = 'HP', Mana = 'Mana', Endurance = 'Endurance',
    HPRegen = 'HP Regen', ManaRegen = 'Mana Regen', EnduranceRegen = 'End Regen',
    BaseDMG = 'Damage', Delay = 'Delay', Haste = 'Haste',
    STR = 'STR', STA = 'STA', AGI = 'AGI', DEX = 'DEX', WIS = 'WIS', INT = 'INT', CHA = 'CHA',
    hStr = 'H-STR', hSta = 'H-STA', hAgi = 'H-AGI', hDex = 'H-DEX', hWis = 'H-WIS', hInt = 'H-INT', hCha = 'H-CHA',
    MR = 'Magic Res', FR = 'Fire Res', DR = 'Disease Res', PR = 'Poison Res', CR = 'Cold Res', svCor = 'Corrupt Res',
    hMr = 'H-MR', hFr = 'H-FR', hDr = 'H-DR', hPr = 'H-PR', hCr = 'H-CR', hCor = 'H-COR',
    DmgShield = 'Dmg Shield', DmgShieldMit = 'DS Mitigation', Avoidance = 'Avoidance',
    DotShield = 'DoT Shielding', Accuracy = 'Accuracy', SpellShield = 'Spell Shield',
    HealAmount = 'Heal Amount', SpellDamage = 'Spell Damage', StunResist = 'Stun Resist',
    Clairvoyance = 'Clairvoyance', InstrumentMod = 'Instrument Mod',
}

local colorGain = ImVec4(0.4, 0.9, 0.4, 1.0)
local colorLoss = ImVec4(0.9, 0.4, 0.4, 1.0)

local function RenderCompareTooltip(equippedItem, bagItem)
    local bagData = InventoryData.FetchItemData(bagItem)
    if not bagData then return end

    local eqData = nil
    if equippedItem and equippedItem() then
        eqData = InventoryData.FetchItemData(equippedItem)
    end

    local diffs = {}
    local seen = {}

    if eqData then
        for key, eqVal in pairs(eqData) do
            if not compareSkipKeys[key] and type(eqVal) == 'number' then
                local bagVal = bagData[key] or 0
                if eqVal ~= 0 or bagVal ~= 0 then
                    diffs[#diffs + 1] = { key = key, diff = bagVal - eqVal, bagVal = bagVal, eqVal = eqVal }
                end
                seen[key] = true
            end
        end
    end

    if bagData then
        for key, bagVal in pairs(bagData) do
            if not compareSkipKeys[key] and not seen[key] and type(bagVal) == 'number' then
                local eqVal = (eqData and eqData[key]) or 0
                if eqVal ~= 0 or bagVal ~= 0 then
                    diffs[#diffs + 1] = { key = key, diff = bagVal - eqVal, bagVal = bagVal, eqVal = eqVal }
                end
            end
        end
    end

    if #diffs == 0 then
        ImGui.TextDisabled("No stat differences")
        return
    end

    if eqData then
        ImGui.TextDisabled("vs. %s", eqData.Name)
    else
        ImGui.TextDisabled("vs. (empty slot)")
    end
    ImGui.Separator()

    if ImGui.BeginTable("##compareStats", 2, ImGuiTableFlags.None) then
        ImGui.TableSetupColumn("Stat", ImGuiTableColumnFlags.WidthFixed, 120)
        ImGui.TableSetupColumn("Diff", ImGuiTableColumnFlags.WidthFixed, 80)
        for _, entry in ipairs(diffs) do
            local label = compareLabels[entry.key] or entry.key
            local diff = entry.diff
            local invert = (entry.key == 'Delay')

            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text(label)
            ImGui.TableNextColumn()
            if diff > 0 then
                local color = invert and colorLoss or colorGain
                ImGui.TextColored(color, "+%s", diff)
            elseif diff < 0 then
                local color = invert and colorGain or colorLoss
                ImGui.TextColored(color, "%s", diff)
            else
                ImGui.TextDisabled("0")
            end
        end
        ImGui.EndTable()
    end
end

local paperdollRows                      = {
    -- inventory slots grid for the table to draw. -1 is a blank space
    { 1,  -1, 2,  -1, 4, },
    { 3,  -1, 5,  -1, 6, },
    { 7,  -1, 17, -1, 8, },
    { -1, 20, -1, 18, -1, },
    { 9,  15, 12, 16, 10, },
    { 21, -1, 19, -1, 0, },
}

local weaponRow                          = { 13, 14, -1, 11, 22, }

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

    local validKeys = {}
    for k, _ in pairs(defaults) do validKeys[k] = true end
    for k, _ in pairs(settings) do
        if not validKeys[k] then settings[k] = nil end
    end

    if settings.toggleModKey == '' then settings.toggleModKey = 'None' end
    if settings.toggleModKey2 == '' then settings.toggleModKey2 = 'None' end
    if settings.toggleModKey3 == '' then settings.toggleModKey3 = 'None' end

    themeName = settings.themeName or defaults.themeName
    toggleKey = settings.toggleKey or defaults.toggleKey
    toggleModKey = settings.toggleModKey or defaults.toggleModKey
    toggleModKey2 = settings.toggleModKey2 or defaults.toggleModKey2
    toggleModKey3 = settings.toggleModKey3 or defaults.toggleModKey3

    if toggleModKey == 'None' then
        toggleModKey2 = 'None'
        settings.toggleModKey2 = 'None'
    end
    if toggleModKey2 == 'None' then
        toggleModKey3 = 'None'
        settings.toggleModKey3 = 'None'
    end
end

function Module:SaveSettings()
    mq.pickle(configFile, settings)
end

function Module:RefreshInventory()
    if loadedExternally then
        invData = MyUI.InvData or invData
    else
        local curFreeSlots = InventoryData.GetFreeSlots()
        if InventoryData.NeedsRefresh(invRefreshTimer, INV_REFRESH_DELAY) or curFreeSlots ~= lastFreeSlots or forceRefresh then
            invRefreshTimer = os.time()
            lastFreeSlots = curFreeSlots
            forceRefresh = false
            invData = {
                worn = InventoryData.GetWornItems(),
                bags = InventoryData.GetBagContents(),
                containers = InventoryData.GetBags(),
                clickies = InventoryData.GetEquippedClickies(),
                freeSlots = curFreeSlots,
            }
        end
    end
end

-- draw the item icon and the slot background image on the paper doll.
function Module:DrawItemIcon(item, iconWidth, iconHeight, id, bgAnim)
    local cursor_x, cursor_y = ImGui.GetCursorPos()
    ImGui.PushID(id)
    local bg = bgAnim or animBox
    if bg then
        if not bgAnim then bg:SetTextureCell(0) end
        ImGui.DrawTextureAnimation(bg, iconWidth, iconHeight)
    end

    if item and item() then
        ImGui.SetCursorPos(cursor_x, cursor_y)
        animItems:SetTextureCell(item.Icon() - EQ_ICON_OFFSET)
        ImGui.DrawTextureAnimation(animItems, iconWidth, iconHeight)

        if (item.Stack() or 0) > 1 then
            ImGui.PushFont(nil, ImGui.GetFontSize() * 0.68)
            local textSize = ImGui.CalcTextSize(tostring(item.Stack()))
            ImGui.SetCursorPos((cursor_x + iconWidth - 1) - textSize, cursor_y + iconHeight / 1.5)
            ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", item.Stack())
            ImGui.PopFont()
        end

        ImGui.SetCursorPos(cursor_x, cursor_y)
        ImGui.PushStyleColor(ImGuiCol.Button, 0, 0, 0, 0)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0, 0.3, 0, 0.2)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0, 0.3, 0, 0.3)
        ImGui.Button("##btn_" .. id, iconWidth, iconHeight)
        ImGui.PopStyleColor(3)
    else
        ImGui.SetCursorPos(cursor_x, cursor_y)
        ImGui.PushStyleColor(ImGuiCol.Button, 0, 0, 0, 0)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.2, 0.2, 0.2, 0.3)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0, 0, 0, 0)
        ImGui.Button("##btn_empty_" .. id, iconWidth, iconHeight)
        ImGui.PopStyleColor(3)
    end
    ImGui.PopID()
end

function Module:RenderEquipSlot(slotId)
    local slotName = InventoryData.wornSlotNames[slotId]
    local displayName = InventoryData.slotDisplayNames[slotId]
    local item = mq.TLO.Me.Inventory(slotName)

    self:DrawItemIcon(item, ICON_WIDTH, ICON_HEIGHT, 'equip_' .. slotId, slotBackgrounds[slotId])

    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        if item() then
            InventoryData.RenderItemToolTip(item, { Popped = Module.TempSettings.Popped, })
            ImGui.SeparatorText("Click Actions")
            ImGui.Text("Left Click: Pick up")
            ImGui.Text("Right Click: Swap options")
            ImGui.Text("Shift + Right Click: Pop Out Item Info")
        else
            ImGui.Text(displayName .. " (empty)")
            if mq.TLO.Cursor() then
                ImGui.Text("Left Click: Equip cursor item")
            end
        end
        ImGui.EndTooltip()
        if item() and ImGui.IsKeyDown(ImGuiMod.Shift) and ImGui.IsItemClicked(ImGuiMouseButton.Right) then
            Module.TempSettings.Popped[item.ID()] = item
        end
    end

    if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
        if mq.TLO.Me.Casting() ~= nil then return end
        mq.cmdf('/itemnotify %s leftmouseup', slotName)
        forceRefresh = true
    end

    if ImGui.BeginPopupContextItem('equipPopup_' .. slotId) then
        self:RenderSlotContextMenu(slotId)
        ImGui.EndPopup()
    end
end

function Module:RenderSlotContextMenu(slotId)
    local displayName = InventoryData.slotDisplayNames[slotId]
    local slotName = InventoryData.wornSlotNames[slotId]
    ImGui.TextDisabled("Swap " .. displayName)
    ImGui.Separator()

    local bagContents = invData.bags or {}
    local compatible = InventoryData.GetCompatibleItems(slotId, bagContents)

    if #compatible == 0 then
        ImGui.TextDisabled("No compatible items in bags")
    else
        for idx, entry in ipairs(compatible) do
            local item = entry.item
            if item() then
                local cursor_x, cursor_y = ImGui.GetCursorPos()
                animItems:SetTextureCell(item.Icon() - EQ_ICON_OFFSET)
                ImGui.DrawTextureAnimation(animItems, 20, 20)
                ImGui.SameLine()
                if ImGui.Selectable(item.Name() .. '##swap_' .. idx) then
                    local packNum = entry.bagNum
                    local bagSlot = entry.slotNum
                    if bagSlot == -1 then
                        pendingAction = {
                            step = 'pickup',
                            pickupCmd = string.format('/itemnotify %d leftmouseup', entry.slotId),
                            dropCmd = string.format('/itemnotify %s leftmouseup', slotName),
                            timer = 0,
                            autoInv = true,
                        }
                    else
                        pendingAction = {
                            step = 'pickup',
                            pickupCmd = string.format('/itemnotify in pack%d %d leftmouseup', packNum, bagSlot),
                            dropCmd = string.format('/itemnotify %s leftmouseup', slotName),
                            timer = 0,
                            autoInv = true,
                        }
                    end
                end
                if ImGui.IsItemHovered() then
                    ImGui.BeginTooltip()
                    local equippedItem = mq.TLO.Me.Inventory(slotName)
                    RenderCompareTooltip(equippedItem, item)
                    ImGui.EndTooltip()
                end
            end
        end
    end
end

function Module:CommaSepValue(amount)
    local formatted = amount
    local k = 0
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

function Module:UpdateCoin()
    myCopper = MySelf.Copper() or 0
    mySilver = MySelf.Silver() or 0
    myGold = MySelf.Gold() or 0
    myPlat = MySelf.Platinum() or 0
    myWeight = MySelf.CurrentWeight() or 0
    myStr = MySelf.STR() or 0
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

function Module:DrawCoinRow(iconCell, amount, label, coinId)
    animItems:SetTextureCell(iconCell - EQ_ICON_OFFSET)
    ImGui.DrawTextureAnimation(animItems, 20, 20)
    ImGui.SameLine()
    ImGui.TextColored(ImVec4(0, 1, 1, 1), "%s", self:CommaSepValue(amount))
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text("%s %s", self:CommaSepValue(amount), label)
        ImGui.EndTooltip()
        if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
            show_qty_win = true
            coin_type = coinId
        end
    end
end

function Module:RenderCurrency()
    self:DrawCoinRow(644, myPlat, "Platinum", 0)
    self:DrawCoinRow(645, myGold, "Gold", 1)
    self:DrawCoinRow(646, mySilver, "Silver", 2)
    self:DrawCoinRow(647, myCopper, "Copper", 3)
end

function Module:QtyWindow()
    if not show_qty_win then return end
    local label, maxQty = '', 0
    if coin_type == 0 then
        maxQty = myPlat
        label = 'Plat'
    elseif coin_type == 1 then
        maxQty = myGold
        label = 'Gold'
    elseif coin_type == 2 then
        maxQty = mySilver
        label = 'Silver'
    elseif coin_type == 3 then
        maxQty = myCopper
        label = 'Copper'
    end
    local labelHint = "Available: " .. maxQty
    ImGui.SetNextWindowPos(ImGui.GetMousePosOnOpeningCurrentPopupVec(), ImGuiCond.Appearing)
    local open, show = ImGui.Begin("Quantity##MyInv_" .. coin_type, true,
        bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoDocking, ImGuiWindowFlags.AlwaysAutoResize))
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

function Module:RenderPaperdoll()
    local tableFlags = bit32.bor(ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.NoHostExtendX, ImGuiTableFlags.SizingFixedFit)
    if ImGui.BeginTable("##PaperdollTable", 5, tableFlags) then
        for i = 1, 5 do
            ImGui.TableSetupColumn("Col" .. i, ImGuiTableColumnFlags.WidthFixed, ICON_WIDTH)
        end

        for _, row in ipairs(paperdollRows) do
            ImGui.TableNextRow()
            for col, slotId in ipairs(row) do
                ImGui.TableSetColumnIndex(col - 1)
                if slotId >= 0 then
                    self:RenderEquipSlot(slotId)
                end
            end
        end

        ImGui.TableNextRow()
        ImGui.TableSetColumnIndex(0)
        ImGui.Separator()

        ImGui.TableNextRow()
        for col, slotId in ipairs(weaponRow) do
            ImGui.TableSetColumnIndex(col - 1)
            if slotId >= 0 then
                self:RenderEquipSlot(slotId)
            end
        end
        ImGui.EndTable()
    end
end

function Module:RenderBagSlot(packNum)
    local slotId = packNum + 22
    local bag = mq.TLO.Me.Inventory(slotId)
    self:DrawItemIcon(bag, ICON_WIDTH, ICON_HEIGHT, 'bag_' .. packNum)

    local isContainer = bag() and (bag.Container() or 0) > 0
    local bagType = bag() and (bag.Type() or '') or ''
    local isBagUsable = bag() and not isContainer and (bag.Clicky() or bagType == 'Food' or bagType == 'Drink')

    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        if bag() then
            InventoryData.RenderItemToolTip(bag, { Popped = Module.TempSettings.Popped, })
            ImGui.SeparatorText("Click Actions")
            if isContainer then
                ImGui.Text("Right Click: Open bag")
            elseif isBagUsable then
                ImGui.Text("Right Click: Use item")
            end
            ImGui.Text("Left Click: Pick up bag")
            ImGui.Text("Ctrl + Right Click: Inspect Item")
            ImGui.Text("Shift + Right Click: Pop Out Item Info")
        else
            ImGui.Text("Pack " .. packNum .. " (empty)")
        end
        ImGui.EndTooltip()
        if bag() and ImGui.IsKeyDown(ImGuiMod.Shift) and ImGui.IsItemClicked(ImGuiMouseButton.Right) then
            Module.TempSettings.Popped[bag.ID()] = bag
        end
    end

    if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
        if mq.TLO.Me.Casting() ~= nil then return end
        mq.cmdf('/itemnotify %d leftmouseup', slotId)
        forceRefresh = true
    end

    if bag() then
        if ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsItemClicked(ImGuiMouseButton.Right) then
            local link = bag.ItemLink('CLICKABLE')()
            mq.cmdf('/executelink %s', link)
        elseif ImGui.IsItemClicked(ImGuiMouseButton.Right) and not ImGui.IsKeyDown(ImGuiMod.Shift) then
            if isContainer then
                self.TempSettings.openContainers[packNum] = not self.TempSettings.openContainers[packNum]
            elseif isBagUsable then
                if mq.TLO.Me.Casting() ~= nil then return end
                mq.cmdf('/useitem "%s"', bag.Name())
            end
        end
    end
end

function Module:RenderBagSlots()
    local tableFlags = bit32.bor(ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.NoHostExtendX, ImGuiTableFlags.SizingFixedFit)
    if ImGui.BeginTable("##BagGrid", 2, tableFlags) then
        ImGui.TableSetupColumn("BL", ImGuiTableColumnFlags.WidthFixed, ICON_WIDTH)
        ImGui.TableSetupColumn("BR", ImGuiTableColumnFlags.WidthFixed, ICON_WIDTH)
        for row = 0, 4 do
            ImGui.TableNextRow()
            ImGui.TableSetColumnIndex(0)
            self:RenderBagSlot(row * 2 + 1)
            ImGui.TableSetColumnIndex(1)
            self:RenderBagSlot(row * 2 + 2)
        end
        ImGui.EndTable()
    end
end

function Module:DrawContainerSlotIcon(item, packNum, slotNum)
    self:DrawItemIcon(item, ICON_WIDTH, ICON_HEIGHT, string.format('cont_%d_%d', packNum, slotNum))

    if item and item() then
        local iType = item.Type() or ''
        local isUsable = item.Clicky() or iType == 'Food' or iType == 'Drink'
        local isContainer = (item.Container() or 0) > 0

        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            InventoryData.RenderItemToolTip(item, { Popped = Module.TempSettings.Popped, })
            ImGui.SeparatorText("Click Actions")
            ImGui.Text("Left Click: Pick up")
            if isUsable and not isContainer then
                ImGui.Text("Right Click: Use item")
            end
            ImGui.Text("Ctrl + Right Click: Inspect Item")
            ImGui.Text("Shift + Right Click: Pop Out Item Info")
            ImGui.EndTooltip()
            if ImGui.IsKeyDown(ImGuiMod.Shift) and ImGui.IsItemClicked(ImGuiMouseButton.Right) then
                Module.TempSettings.Popped[item.ID()] = item
            end
        end

        if ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsItemClicked(ImGuiMouseButton.Right) then
            local link = item.ItemLink('CLICKABLE')()
            mq.cmdf('/executelink %s', link)
        elseif ImGui.IsItemClicked(ImGuiMouseButton.Right) and not ImGui.IsKeyDown(ImGuiMod.Shift) then
            if isUsable and not isContainer then
                if mq.TLO.Me.Casting() ~= nil then return end
                mq.cmdf('/useitem "%s"', item.Name())
            end
        end

        if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
            if mq.TLO.Me.Casting() ~= nil then return end
            mq.cmdf('/itemnotify in pack%d %d leftmouseup', packNum, slotNum)
            forceRefresh = true
        end
    else
        if ImGui.IsItemHovered() and mq.TLO.Cursor() then
            ImGui.BeginTooltip()
            ImGui.Text("Left Click: Drop item here")
            ImGui.EndTooltip()
        end

        if ImGui.IsItemClicked(ImGuiMouseButton.Left) and mq.TLO.Cursor() then
            mq.cmdf('/itemnotify in pack%d %d leftmouseup', packNum, slotNum)
            forceRefresh = true
        end
    end
end

function Module:RenderContainerWindows()
    local colorCount, styleCount = self.ThemeLoader.StartTheme(themeName, self.Theme)
    for packNum, isOpen in pairs(self.TempSettings.openContainers) do
        if isOpen then
            local slotId = packNum + 22
            local bag = mq.TLO.Me.Inventory(slotId)
            if bag() and bag.Container() and bag.Container() > 0 then
                local bagName = bag.Name() or ("Pack " .. packNum)
                local slots = bag.Container()
                local initCols = math.min(slots, 5)
                local initRows = math.ceil(slots / initCols)
                local initW = initCols * (ICON_WIDTH + 2) + 16
                local initH = initRows * (ICON_WIDTH + 2) + 40
                ImGui.SetNextWindowSize(ImVec2(initW, initH), ImGuiCond.FirstUseEver)
                local open, show = ImGui.Begin(
                    bagName .. "##MyInvContainer_" .. packNum, true,
                    ImGuiWindowFlags.NoScrollbar
                )
                if not open then
                    self.TempSettings.openContainers[packNum] = false
                end
                if show then
                    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(2, 2))
                    local winWidth, winHeight = ImGui.GetContentRegionAvail()
                    local cols = math.max(1, math.floor(winWidth / (ICON_WIDTH + 2)))
                    local col = 1
                    local rowY = 0
                    for j = 1, bag.Container() do
                        if rowY + ICON_WIDTH > winHeight then break end
                        local item = bag.Item(j)
                        self:DrawContainerSlotIcon(item, packNum, j)
                        if col < cols then
                            col = col + 1
                            ImGui.SameLine()
                        else
                            col = 1
                            rowY = rowY + ICON_WIDTH + 2
                        end
                    end
                    ImGui.PopStyleVar()
                end
                ImGui.End()
            else
                self.TempSettings.openContainers[packNum] = false
            end
        end
    end
    self.ThemeLoader.EndTheme(colorCount, styleCount)
end

function Module:RenderSettingsWindow()
    if not showSettings then return end
    local colorCount, styleCount = self.ThemeLoader.StartTheme(themeName, self.Theme)
    ImGui.SetNextWindowSize(350, 0, ImGuiCond.FirstUseEver)
    local open, show = ImGui.Begin("My Inventory Settings##MyInvSettings", true, ImGuiWindowFlags.AlwaysAutoResize)
    if not open then
        showSettings = false
    end
    if show then
        if ImGui.CollapsingHeader("Theme##MyInvTheme", ImGuiTreeNodeFlags.DefaultOpen) then
            ImGui.Text("Current Theme: %s", themeName)
            if ImGui.BeginCombo("Load Theme##MyInv", themeName) then
                for k, data in pairs(self.Theme.Theme) do
                    if data ~= nil then
                        local isSelected = data.Name == themeName
                        if ImGui.Selectable(data.Name, isSelected) then
                            settings.themeName = data.Name
                            themeName = settings.themeName
                            self:SaveSettings()
                        end
                    end
                end
                ImGui.EndCombo()
            end
        end

        if ImGui.CollapsingHeader("Toggle Keybind##MyInvToggle", ImGuiTreeNodeFlags.DefaultOpen) then
            ImGui.Text("Toggle Key")
            ImGui.SameLine()
            ImGui.SetNextItemWidth(100)
            toggleKey = ImGui.InputText("##ToggleKey", toggleKey, ImGuiInputTextFlags.CharsUppercase)
            if toggleKey ~= settings.toggleKey then
                settings.toggleKey = toggleKey:upper()
                self:SaveSettings()
            end
            ImGui.SameLine()
            self.Utils.DrawHelpMarker("Key to toggle the GUI (A-Z | 0-9 | F1-F12)")

            if toggleKey ~= '' then
                ImGui.Text("Modifier 1")
                ImGui.SameLine()
                ImGui.SetNextItemWidth(100)
                if ImGui.BeginCombo("##ToggleModKey", settings.toggleModKey) then
                    for _, v in ipairs(modKeys) do
                        local isSelected = v == settings.toggleModKey
                        if ImGui.Selectable(v, isSelected) then
                            settings.toggleModKey = v
                            if v == 'None' then
                                settings.toggleModKey2 = 'None'
                                settings.toggleModKey3 = 'None'
                                toggleModKey2 = 'None'
                                toggleModKey3 = 'None'
                            end
                            toggleModKey = v
                            self:SaveSettings()
                        end
                    end
                    ImGui.EndCombo()
                end
                ImGui.SameLine()
                self.Utils.DrawHelpMarker("Modifier Key (Ctrl | Alt | Shift)")

                if toggleModKey ~= 'None' then
                    ImGui.Text("Modifier 2")
                    ImGui.SameLine()
                    ImGui.SetNextItemWidth(100)
                    if ImGui.BeginCombo("##ToggleModKey2", settings.toggleModKey2) then
                        for _, v in ipairs(modKeys) do
                            local isSelected = v == settings.toggleModKey2
                            if ImGui.Selectable(v, isSelected) then
                                settings.toggleModKey2 = v
                                if v == 'None' then
                                    settings.toggleModKey3 = 'None'
                                    toggleModKey3 = 'None'
                                end
                                toggleModKey2 = v
                                self:SaveSettings()
                            end
                        end
                        ImGui.EndCombo()
                    end
                    ImGui.SameLine()
                    self.Utils.DrawHelpMarker("Second Modifier Key (Ctrl | Alt | Shift)")

                    if toggleModKey2 ~= 'None' then
                        ImGui.Text("Modifier 3")
                        ImGui.SameLine()
                        ImGui.SetNextItemWidth(100)
                        if ImGui.BeginCombo("##ToggleModKey3", settings.toggleModKey3) then
                            for _, v in ipairs(modKeys) do
                                local isSelected = v == settings.toggleModKey3
                                if ImGui.Selectable(v, isSelected) then
                                    settings.toggleModKey3 = v
                                    toggleModKey3 = v
                                    self:SaveSettings()
                                end
                            end
                            ImGui.EndCombo()
                        end
                        ImGui.SameLine()
                        self.Utils.DrawHelpMarker("Third Modifier Key (Ctrl | Alt | Shift)")
                    end
                end
            end
        end
    end
    self.ThemeLoader.EndTheme(colorCount, styleCount)
    ImGui.End()
end

function Module:RenderMainWindow()
    local colorCount, styleCount = self.ThemeLoader.StartTheme(themeName, self.Theme)
    local open, show = ImGui.Begin("My Inventory##" .. Module.CharLoaded, true,
        bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.MenuBar))
    if not open then
        show = false
        self.ShowGUI = false
    end
    if show then
        if ImGui.BeginMenuBar() then
            if ImGui.BeginMenu("Menu") then
                if ImGui.MenuItem("Settings") then
                    showSettings = not showSettings
                end
                ImGui.Separator()
                if ImGui.MenuItem("Close") then
                    self.ShowGUI = false
                end
                if ImGui.MenuItem("Exit") then
                    self.IsRunning = false
                end
                ImGui.EndMenu()
            end
            ImGui.EndMenuBar()
        end

        local freeSlots = invData.freeSlots or 0
        ImGui.Text("Weight")
        ImGui.SameLine()
        ImGui.TextColored(
            myWeight > myStr and ImVec4(1.000, 0.254, 0.0, 1.0) or ImVec4(0, 1, 1, 1),
            "%d / %d", myWeight, myStr
        )
        ImGui.SameLine()
        ImGui.Text("Free Slots:")
        ImGui.SameLine()
        ImGui.TextColored(
            freeSlots > 3 and ImVec4(0.354, 1.000, 0.000, 0.500) or ImVec4(1.000, 0.354, 0.0, 0.5),
            "%d", freeSlots
        )
        if mq.TLO.Cursor() then
            ImGui.PushTextWrapPos(ImGui.GetWindowContentRegionWidth() - 2)
            ImGui.TextColored(Module.Colors.color('yellow'), "Cursor: %s", mq.TLO.Cursor.Name() or "item")
            ImGui.PopTextWrapPos()
        else
            ImGui.TextDisabled(" ")
        end
        ImGui.Separator()

        local childFlags = bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.AutoResizeX, ImGuiChildFlags.AutoResizeY)

        if ImGui.BeginChild("Paperdoll##MyInv", ImVec2(0, 0), childFlags) then
            self:RenderPaperdoll()
        end
        ImGui.EndChild()

        ImGui.SameLine()

        if ImGui.BeginChild("Bags##MyInv", ImVec2(0, 0), childFlags) then
            ImGui.TextDisabled("Bags")
            self:RenderBagSlots()
            ImGui.Separator()
            self:RenderCurrency()
        end
        ImGui.EndChild()

        ImGui.Separator()
        if mq.TLO.Cursor() then
            if ImGui.Button("Destroy##MyInv") then
                mq.cmd('/destroy')
                forceRefresh = true
            end
        end
        local btnWidth = ImGui.CalcTextSize("Done") + ImGui.GetStyle().FramePadding.x * 2
        ImGui.SameLine(ImGui.GetWindowWidth() - btnWidth - ImGui.GetStyle().WindowPadding.x)
        if ImGui.Button("Done##MyInv") then
            self.ShowGUI = false
        end

        if mq.TLO.Cursor() and ImGui.IsWindowHovered(ImGuiHoveredFlags.ChildWindows) and not ImGui.IsAnyItemHovered() then
            if ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
                mq.cmd('/autoinventory')
                forceRefresh = true
            end
        end
    end
    self.ThemeLoader.EndTheme(colorCount, styleCount)
    ImGui.End()
end

function Module:RenderMiniButton(grouped)
    if not grouped then
        local colorCount, styleCount = self.ThemeLoader.StartTheme(themeName, self.Theme)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(9, 9))
        local openBtn, showBtn = ImGui.Begin("My Inventory##Mini", true,
            bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoCollapse))
        if not openBtn then
            showBtn = false
        end

        if showBtn then
            local cursorX, cursorY = ImGui.GetCursorScreenPos()
            local freeSlots = invData.freeSlots or 0
            animItems:SetTextureCell(3515 - EQ_ICON_OFFSET)
            ImGui.DrawTextureAnimation(animItems, 34, 34, true)
            ImGui.SetCursorPos(20, 20)
            Utils.DropShadow(freeSlots, { Enabled = true, })

            ImGui.SetCursorScreenPos(cursorX, cursorY)
            ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0, 0.5, 0.5, 0.5))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImVec4(0, 0, 0, 0))
            if ImGui.Button("##MyInventoryBtn", ImVec2(34, 34)) then
                self.ShowGUI = not self.ShowGUI
            end
            ImGui.PopStyleColor(3)

            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.Text("My Inventory")
                ImGui.Text("Free Slots: %d", invData.freeSlots or 0)
                ImGui.EndTooltip()
            end
        end
        ImGui.PopStyleVar()
        self.ThemeLoader.EndTheme(colorCount, styleCount)
        ImGui.End()
        return
    end

    local cursorX, cursorY = ImGui.GetCursorScreenPos()
    local freeSlots = invData.freeSlots or 0
    animItems:SetTextureCell(3515 - EQ_ICON_OFFSET)
    ImGui.DrawTextureAnimation(animItems, 34, 34, true)
    ImGui.SetCursorPos(20, 20)
    Utils.DropShadow(freeSlots, { Enabled = true, })

    ImGui.SetCursorScreenPos(cursorX, cursorY)
    ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0, 0.5, 0.5, 0.5))
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImVec4(0, 0, 0, 0))
    if ImGui.Button("##MyInventoryBtn", ImVec2(34, 34)) then
        self.ShowGUI = not self.ShowGUI
    end
    ImGui.PopStyleColor(3)

    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text("My Inventory")
        ImGui.Text("Free Slots: %d", invData.freeSlots or 0)
        ImGui.EndTooltip()
    end
end

function Module:ProcessPendingActions()
    if not pendingAction then return end

    if pendingAction.step == 'pickup' then
        if mq.TLO.Cursor() ~= nil then
            pendingAction = nil
            return
        end
        mq.cmd(pendingAction.pickupCmd)
        pendingAction.step = 'waitcursor'
        pendingAction.timer = mq.gettime()
    elseif pendingAction.step == 'waitcursor' then
        if mq.TLO.Cursor() ~= nil then
            mq.cmd(pendingAction.dropCmd)
            pendingAction.step = 'waitdrop'
            pendingAction.timer = mq.gettime()
        elseif mq.gettime() - pendingAction.timer > 3000 then
            pendingAction = nil
        end
    elseif pendingAction.step == 'waitdrop' then
        if mq.TLO.Cursor() ~= nil and pendingAction.autoInv then
            mq.cmd('/autoinventory')
            pendingAction.step = 'waitautoinv'
            pendingAction.timer = mq.gettime()
        elseif mq.TLO.Cursor() == nil then
            pendingAction = nil
            forceRefresh = true
        elseif mq.gettime() - pendingAction.timer > 3000 then
            pendingAction = nil
            forceRefresh = true
        end
    elseif pendingAction.step == 'waitautoinv' then
        if mq.TLO.Cursor() == nil then
            pendingAction = nil
            forceRefresh = true
        elseif mq.gettime() - pendingAction.timer > 3000 then
            pendingAction = nil
            forceRefresh = true
        end
    end
end

function Module.RenderGUI()
    if not Module.IsRunning then return end

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

    if not MyUI.Settings.GroupButtons then Module:RenderMiniButton() end
    if Module.ShowGUI then
        Module:RenderMainWindow()
    end
    Module:RenderContainerWindows()
    Module:QtyWindow()
    Module:RenderSettingsWindow()
    local poppedToRemove = {}
    for k, v in pairs(Module.TempSettings.Popped) do
        if v and v.ID() then
            InventoryData.RenderItemInfoWin(v, Module.TempSettings.Popped, { Sender = Module.Name, })
        else
            poppedToRemove[#poppedToRemove + 1] = k
        end
    end
    for _, k in ipairs(poppedToRemove) do
        Module.TempSettings.Popped[k] = nil
    end
end

function Module.MainLoop()
    if loadedExternally then
        if not MyUI.LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
    end
    Module:RefreshInventory()
    Module:ProcessPendingActions()
    if do_process_coin then
        Module:ProcessCoin()
        do_process_coin = false
    end
    if os.time() - coinTimer > 2 then
        Module:UpdateCoin()
        coinTimer = os.time()
    end
end

function Module:LocalLoop()
    while self.IsRunning do
        mq.delay("1s")
        self.MainLoop()
    end
end

function Module.CommandHandler(...)
    local args = { ..., }
    if #args == 0 then
        Module.ShowGUI = not Module.ShowGUI
        return
    end
    local cmd = args[1]:lower()
    if cmd == "show" then
        Module.ShowGUI = true
    elseif cmd == "hide" then
        Module.ShowGUI = false
    elseif cmd == "toggle" or cmd == "ui" then
        Module.ShowGUI = not Module.ShowGUI
    elseif cmd == "exit" then
        Module.IsRunning = false
    end
end

function Module:Init()
    self.IsRunning = true
    self:LoadSettings()
    self:RefreshInventory()
    mq.bind("/myinventory", self.CommandHandler)

    if not loadedExternally then
        mq.imgui.init("MyInventoryGUI", self.RenderGUI)
        self:LocalLoop()
        printf("%s Loaded", self.Name)
        printf("\aw[\at%s\ax] \at/myinventory ui \ax- Toggle GUI", self.Name)
        printf("\aw[\at%s\ax] \at/myinventory exit \ax- Exit", self.Name)
    end
end

function Module.Unload()
    mq.unbind("/myinventory")
end

Module:Init()
return Module
