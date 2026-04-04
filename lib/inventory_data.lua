local mq                       = require('mq')
local ImGui                    = require('ImGui')
local Colors                   = require('lib.colors')
-- EQ Texture Animation references
local animItems                = mq.FindTextureAnimation("A_DragItem")
local animBox                  = mq.FindTextureAnimation("A_RecessedBox")

local EQ_ICON_OFFSET           = 500
local InventoryData            = {}

InventoryData.equipSlots       = {
    [0] = 'Charm',
    [1] = 'Ears',
    [2] = 'Head',
    [3] = 'Face',
    [4] = 'Ears',
    [5] = 'Neck',
    [6] = 'Shoulder',
    [7] = 'Arms',
    [8] = 'Back',
    [9] = 'Wrists',
    [10] = 'Wrists',
    [11] = 'Ranged',
    [12] = 'Hands',
    [13] = 'Primary',
    [14] = 'Secondary',
    [15] = 'Fingers',
    [16] = 'Fingers',
    [17] = 'Chest',
    [18] = 'Legs',
    [19] = 'Feet',
    [20] = 'Waist',
    [21] = 'Powersource',
    [22] = 'Ammo',
}

InventoryData.wornSlotNames    = {
    [0] = 'charm',
    [1] = 'leftear',
    [2] = 'head',
    [3] = 'face',
    [4] = 'rightear',
    [5] = 'neck',
    [6] = 'shoulder',
    [7] = 'arms',
    [8] = 'back',
    [9] = 'leftwrist',
    [10] = 'rightwrist',
    [11] = 'ranged',
    [12] = 'hands',
    [13] = 'mainhand',
    [14] = 'offhand',
    [15] = 'leftfinger',
    [16] = 'rightfinger',
    [17] = 'chest',
    [18] = 'legs',
    [19] = 'feet',
    [20] = 'waist',
    [21] = 'powersource',
    [22] = 'ammo',
}

InventoryData.slotDisplayNames = {
    [0] = 'Charm',
    [1] = 'Left Ear',
    [2] = 'Head',
    [3] = 'Face',
    [4] = 'Right Ear',
    [5] = 'Neck',
    [6] = 'Shoulder',
    [7] = 'Arms',
    [8] = 'Back',
    [9] = 'Left Wrist',
    [10] = 'Right Wrist',
    [11] = 'Ranged',
    [12] = 'Hands',
    [13] = 'Main Hand',
    [14] = 'Off Hand',
    [15] = 'Left Finger',
    [16] = 'Right Finger',
    [17] = 'Chest',
    [18] = 'Legs',
    [19] = 'Feet',
    [20] = 'Waist',
    [21] = 'Power Source',
    [22] = 'Ammo',
}

InventoryData.Sizes            = {
    [0] = "Tiny",
    [1] = 'Small',
    [2] = 'Medium',
    [3] = 'Large',
    [4] = 'Giant',
}

InventoryData.racesShort       = {
    ['Human'] = 'HUM',
    ['Barbarian'] = 'BAR',
    ['Erudite'] = 'ERU',
    ['Wood Elf'] = 'ELF',
    ['High Elf'] = 'HIE',
    ['Dark Elf'] = 'DEF',
    ['Half Elf'] = 'HEF',
    ['Dwarf'] = 'DWF',
    ['Troll'] = 'TRL',
    ['Ogre'] = 'OGR',
    ['Halfling'] = 'HFL',
    ['Gnome'] = 'GNM',
    ['Iksar'] = 'IKS',
    ['Vah Shir'] = 'VAH',
    ['Froglok'] = 'FRG',
    ['Drakkin'] = 'DRK',
}

local statList                 = {
    'STR',
    'AGI',
    'STA',
    'INT',
    'WIS',
    'DEX',
    'CHA',
    'hStr',
    'hSta',
    'hAgi',
    'hInt',
    'hWis',
    'hDex',
    'hCha',
}


local resistList = {
    'MR',
    'FR',
    'DR',
    'PR',
    'CR',
    'svCor',
    'hMr',
    'hFr',
    'hCr',
    'hPr',
    'hDr',
    'hCor',
}

local baseList = {
    'HP',
    'Mana',
    'Endurance',
    'AC',
    'HPRegen',
    'EnduranceRegen',
    'ManaRegen',
}

local statHeroicPair = {
    { stat = 'STR', heroic = 'hStr', },
    { stat = 'AGI', heroic = 'hAgi', },
    { stat = 'STA', heroic = 'hSta', },
    { stat = 'INT', heroic = 'hInt', },
    { stat = 'WIS', heroic = 'hWis', },
    { stat = 'DEX', heroic = 'hDex', },
    { stat = 'CHA', heroic = 'hCha', },
}

local resistHeroicPair = {
    { resist = 'MR',    heroic = 'hMr',  label = 'MR', },
    { resist = 'FR',    heroic = 'hFr',  label = 'FR', },
    { resist = 'DR',    heroic = 'hDr',  label = 'DR', },
    { resist = 'PR',    heroic = 'hPr',  label = 'PR', },
    { resist = 'CR',    heroic = 'hCr',  label = 'CR', },
    { resist = 'svCor', heroic = 'hCor', label = 'COR', },
}

local itemDataCache = {}

function InventoryData.GetWornItems()
    local worn = {}
    for i = 0, 22 do
        local slot = mq.TLO.Me.Inventory(i)
        if slot.ID() ~= nil then
            worn[i] = slot
        end
    end
    return worn
end

function InventoryData.GetBagContents()
    local contents = {}
    for i = 23, 34 do
        local slot = mq.TLO.Me.Inventory(i)
        local packNum = i - 22
        if slot.Container() and (slot.Container() or 0) > 0 then
            for j = 1, slot.Container() do
                if slot.Item(j)() then
                    table.insert(contents, {
                        item = slot.Item(j),
                        bagNum = packNum,
                        slotNum = j,
                        slotId = i,
                    })
                end
            end
        elseif slot.ID() ~= nil then
            table.insert(contents, {
                item = slot,
                bagNum = packNum,
                slotNum = -1,
                slotId = i,
            })
        end
    end
    return contents
end

function InventoryData.GetBags()
    local bags = {}
    for i = 23, 34 do
        local packNum = i - 22
        local slot = mq.TLO.Me.Inventory(i)
        if slot.ID() ~= nil then
            bags[packNum] = slot
        end
    end
    return bags
end

function InventoryData.GetEquippedClickies()
    local clickies = {}
    for i = 0, 22 do
        local slot = mq.TLO.Me.Inventory(i)
        if slot.ID() ~= nil and slot.Clicky() then
            table.insert(clickies, slot)
        end
    end
    return clickies
end

function InventoryData.GetFreeSlots()
    return mq.TLO.Me.FreeInventory() or 0
end

function InventoryData.GetCompatibleItems(slotId, bagContents)
    local targetCategory = InventoryData.equipSlots[slotId]
    if not targetCategory then return {} end

    local compatible = {}
    for _, entry in ipairs(bagContents or {}) do
        local item = entry.item
        if item() and (item.AugType() or 0) == 0 and item.CanUse() then
            for i = 1, item.WornSlots() or 0 do
                local wornSlotID = item.WornSlot(i)()
                local slotCategory = InventoryData.equipSlots[tonumber(wornSlotID)]
                if slotCategory == targetCategory then
                    table.insert(compatible, entry)
                    break
                end
            end
        end
    end
    return compatible
end

function InventoryData.NeedsRefresh(lastRefreshTime, delaySec)
    return (os.difftime(os.time(), lastRefreshTime)) >= delaySec
end

function InventoryData.SlotToPack(slotNumber)
    return "pack" .. tostring(slotNumber - 22)
end

function InventoryData.SlotToBagSlot(slotNumber)
    return slotNumber + 1
end

function InventoryData.FetchClassList(item)
    local classList = ""
    local numClasses = item.Classes()
    if numClasses == 0 then return '' end
    if numClasses < 16 then
        for i = 1, numClasses do
            classList = string.format("%s %s", classList, item.Class(i).ShortName())
        end
    elseif numClasses == 16 then
        classList = "All"
    else
        classList = ""
    end
    return classList
end

function InventoryData.FetchRaceList(item)
    local raceList = ""
    local numRaces = item.Races() or 0
    if numRaces < 16 and numRaces > 0 then
        for i = 1, numRaces do
            local raceName = InventoryData.racesShort[item.Race(i).Name()] or ''
            raceList = string.format("%s %s", raceList, raceName)
        end
    elseif numRaces == 16 then
        raceList = "All"
    end
    return raceList
end

function InventoryData.FetchWornSlots(item)
    local SlotsString = ""
    local tmp = {}
    for i = 1, item.WornSlots() do
        local slotID = item.WornSlot(i)() or '-1'
        tmp[InventoryData.equipSlots[tonumber(slotID)]] = true
    end
    for slotID, _ in pairs(tmp) do
        SlotsString = SlotsString .. slotID .. " "
    end
    return SlotsString
end

function InventoryData.FetchItemData(item)
    if not item() then return nil end
    local cachedID = item.ID()
    if itemDataCache[cachedID] then return itemDataCache[cachedID] end

    local tmpItemData = {
        Name = item.Name(),
        Type = item.Type(),
        ID = cachedID,
        ReqLvl = item.RequiredLevel() or 0,
        RecLvl = item.RecommendedLevel() or 0,
        AC = item.AC() or 0,
        BaseDMG = item.Damage() or 0,
        Delay = item.ItemDelay() or 0,
        Value = item.Value() or 0,
        Weight = item.Weight() or 0,
        Stack = item.Stack() or 0,
        MaxStack = item.StackSize() or 0,
        Clicky = item.Clicky(),
        Charges = (item.Charges() or 0) ~= -1 and (item.Charges() or 0) or 'Infinite',
        ClassList = InventoryData.FetchClassList(item),
        RaceList = InventoryData.FetchRaceList(item),
        TributeValue = item.Tribute() or 0,

        HP = item.HP() or 0,
        Mana = item.Mana() or 0,
        Endurance = item.Endurance() or 0,

        STR = item.STR() or 0,
        AGI = item.AGI() or 0,
        STA = item.STA() or 0,
        INT = item.INT() or 0,
        WIS = item.WIS() or 0,
        DEX = item.DEX() or 0,
        CHA = item.CHA() or 0,

        MR = item.svMagic() or 0,
        FR = item.svFire() or 0,
        DR = item.svDisease() or 0,
        PR = item.svPoison() or 0,
        CR = item.svCold() or 0,
        svCor = item.svCorruption() or 0,

        hStr = item.HeroicSTR() or 0,
        hAgi = item.HeroicAGI() or 0,
        hSta = item.HeroicSTA() or 0,
        hInt = item.HeroicINT() or 0,
        hDex = item.HeroicDEX() or 0,
        hCha = item.HeroicCHA() or 0,
        hWis = item.HeroicWIS() or 0,

        hMr = item.HeroicSvMagic() or 0,
        hFr = item.HeroicSvFire() or 0,
        hDr = item.HeroicSvDisease() or 0,
        hPr = item.HeroicSvPoison() or 0,
        hCr = item.HeroicSvCold() or 0,
        hCor = item.HeroicSvCorruption() or 0,

        AugSlots = item.Augs() or 0,
        AugSlot1 = item.AugSlot(1).Name() or 'none',
        AugSlot2 = item.AugSlot(2).Name() or 'none',
        AugSlot3 = item.AugSlot(3).Name() or 'none',
        AugSlot4 = item.AugSlot(4).Name() or 'none',
        AugSlot5 = item.AugSlot(5).Name() or 'none',
        AugSlot6 = item.AugSlot(6).Name() or 'none',

        AugType1 = item.AugSlot1() or 'none',
        AugType2 = item.AugSlot2() or 'none',
        AugType3 = item.AugSlot3() or 'none',
        AugType4 = item.AugSlot4() or 'none',
        AugType5 = item.AugSlot5() or 'none',
        AugType6 = item.AugSlot6() or 'none',

        Spelleffect = item.Spell.Name() or "",
        Worn = item.Worn.Spell() and (item.Worn.Spell.Name() or '') or 'none',
        Focus1 = item.Focus() and (item.Focus.Spell.Name() or '') or 'none',
        Focus2 = item.Focus2() and (item.Focus2.Spell.Name() or '') or 'none',
        Haste = item.Haste() or 0,
        DmgShield = item.DamShield() or 0,
        DmgShieldMit = item.DamageShieldMitigation() or 0,
        Avoidance = item.Avoidance() or 0,
        DotShield = item.DoTShielding() or 0,
        InstrumentMod = item.InstrumentMod() or 0,
        HPRegen = item.HPRegen() or 0,
        ManaRegen = item.ManaRegen() or 0,
        EnduranceRegen = item.EnduranceRegen() or 0,
        Accuracy = item.Accuracy() or 0,
        BonusDmgType = item.DMGBonusType() or 'None',
        SpellShield = item.SpellShield() or 0,
        Clairvoyance = item.Clairvoyance() or 0,
        HealAmount = item.HealAmount() or 0,
        SpellDamage = item.SpellDamage() or 0,
        StunResist = item.StunResist() or 0,
        CanUse = item.CanUse() or false,

        isNoDrop = item.NoDrop() or false,
        isNoRent = item.NoRent() or false,
        isNoTrade = item.NoTrade() or false,
        isAttuneable = item.Attuneable() or false,
        isLore = item.Lore() or false,
        isMagic = item.Magic() or false,

        EvolvingLevel = item.Evolving.Level() or 0,
        EvolvingExpPct = item.Evolving.ExpPct() or 0,
        EvolvingMaxLevel = item.Evolving.MaxLevel() or 0,

        SpellDesc = item.Spell and (item.Spell.Description() or '') or '',
        WornDesc = item.Worn.Spell and (item.Worn.Spell.Description() or '') or '',
        Focus1Desc = item.Focus and (item.Focus.Spell.Description() or '') or '',
        Focus2Desc = item.Focus2 and (item.Focus2.Spell.Description() or '') or '',
        ClickyDesc = item.Clicky and (item.Clicky.Spell.Description() or '') or '',

        SpellID = item.Spell and (item.Spell.ID() or 0) or 0,
        WornID = item.Worn.Spell and (item.Worn.Spell.ID() or 0) or 0,
        Focus1ID = item.Focus and (item.Focus.Spell.ID() or 0) or 0,
        Focus2ID = item.Focus2 and (item.Focus2.Spell.ID() or 0) or 0,
        ClickyID = item.Clicky and (item.Clicky.Spell.ID() or 0) or 0,

        WornSlots = InventoryData.FetchWornSlots(item),
        NumSlots = item.Container() or 0,
        Size = item.Size() or 0,
        SizeCapacity = item.SizeCapacity() or 0,
    }

    tmpItemData.isEvolving = (tmpItemData.EvolvingMaxLevel > 0)

    itemDataCache[cachedID] = tmpItemData
    return tmpItemData
end

function InventoryData.CommaSepValue(amount)
    local formatted = amount
    local k = 0
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

function InventoryData.DrawItemValue(value)
    local val_plat = math.floor(value / 1000)
    local val_gold = math.floor((value - (val_plat * 1000)) / 100)
    local val_silver = math.floor((value - (val_plat * 1000) - (val_gold * 100)) / 10)
    local val_copper = value - (val_plat * 1000) - (val_gold * 100) - (val_silver * 10)

    animItems:SetTextureCell(644 - EQ_ICON_OFFSET)
    ImGui.DrawTextureAnimation(animItems, 10, 10)
    ImGui.SameLine()
    ImGui.TextColored(ImVec4(0, 1, 1, 1), " %s ", InventoryData.CommaSepValue(val_plat))
    ImGui.SameLine()

    animItems:SetTextureCell(645 - EQ_ICON_OFFSET)
    ImGui.DrawTextureAnimation(animItems, 10, 10)
    ImGui.SameLine()
    ImGui.TextColored(ImVec4(0, 1, 1, 1), " %s ", InventoryData.CommaSepValue(val_gold))
    ImGui.SameLine()

    animItems:SetTextureCell(646 - EQ_ICON_OFFSET)
    ImGui.DrawTextureAnimation(animItems, 10, 10)
    ImGui.SameLine()
    ImGui.TextColored(ImVec4(0, 1, 1, 1), " %s ", InventoryData.CommaSepValue(val_silver))
    ImGui.SameLine()

    animItems:SetTextureCell(647 - EQ_ICON_OFFSET)
    ImGui.DrawTextureAnimation(animItems, 10, 10)
    ImGui.SameLine()
    ImGui.TextColored(ImVec4(0, 1, 1, 1), " %s ", InventoryData.CommaSepValue(val_copper))
end

---Draws the individual item icon in the bag.
---@param item item The item object
function InventoryData:DrawItemIcon(item, iconWidth, iconHeight, drawID, clickable, iconOnly, opts)
    if not item() then return end

    local highlightUseable = opts ~= nil and (opts.highlightUseable or false) or false
    local showItemBackground = opts ~= nil and (opts.showItemBackground or false) or false

    -- Capture original cursor position
    local cursor_x, cursor_y = ImGui.GetCursorPos()
    local offsetX, offsetY = iconWidth - 1, iconHeight / 1.5
    local offsetXCharges, offsetYCharges = 2, offsetY / 2 -- Draw the background box
    ImGui.PushID(drawID)
    -- Draw the background box
    if showItemBackground then
        ImGui.DrawTextureAnimation(animBox, iconWidth, iconHeight)
    end

    -- This handles our "always there" drop zone (for now...)
    if not item then
        return
    end

    -- Reset the cursor to start position, then fetch and draw the item icon
    ImGui.SetCursorPos(cursor_x, cursor_y)
    animItems:SetTextureCell(item.Icon() - EQ_ICON_OFFSET)
    local canUse = (item.CanUse() and highlightUseable) or false
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

            InventoryData.RenderItemToolTip(item)
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

function InventoryData.RenderItemToolTip(item, opts)
    if not item() then return end
    local itemData = InventoryData.FetchItemData(item)
    if not itemData then return end

    opts = opts or {}

    local hasStats = false
    local hasResists = false
    local hasBase = false
    local numCombatEfx = item.CombatEffects() or 0
    local hasCombatEffects = numCombatEfx and numCombatEfx > 0

    for _, stat in pairs(statList) do
        if itemData[stat] and (itemData[stat] > 0 or itemData[stat] < 0) then
            hasStats = true
            break
        end
    end
    for _, resist in pairs(resistList) do
        if itemData[resist] and (itemData[resist] > 0 or itemData[resist] < 0) then
            hasResists = true
            break
        end
    end
    for _, base in pairs(baseList) do
        if itemData[base] and (itemData[base] > 0 or itemData[base] < 0) then
            hasBase = true
            break
        end
    end

    local MySelf = mq.TLO.Me
    local cursorY = ImGui.GetCursorPosY()

    ImGui.Text("Item: ")
    ImGui.SameLine()
    local canUse = itemData.CanUse and (itemData.ReqLvl <= MySelf.Level())
    if canUse then
        ImGui.TextColored(Colors.color('green'), "%s", itemData.Name)
    elseif itemData.ReqLvl > MySelf.Level() then
        ImGui.TextColored(Colors.color('tangarine'), "%s", itemData.Name)
    else
        ImGui.TextColored(Colors.color('grey'), "%s", itemData.Name)
    end
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text("Click to copy item Name to clipboard")
        ImGui.EndTooltip()
        if ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
            ImGui.LogToClipboard()
            ImGui.LogText(itemData.Name)
            ImGui.LogFinish()
        end
    end

    ImGui.Text("Item ID: ")
    ImGui.SameLine()
    ImGui.TextColored(Colors.color('yellow'), "%s", itemData.ID)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text("Click to copy item ID to clipboard")
        ImGui.EndTooltip()
        if ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
            ImGui.LogToClipboard()
            ImGui.LogText(itemData.ID)
            ImGui.LogFinish()
        end
    end

    if item then
        local cursorX = ImGui.GetCursorPosX()
        local cursorY2 = ImGui.GetCursorPosY()
        ImGui.SetCursorPosY(cursorY)
        ImGui.SetCursorPosX(ImGui.GetWindowWidth() - 60)
        InventoryData:DrawItemIcon(item, 50, 50, true, false, true, opts)
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text("Click to compare with items worn in allowed slots.")
            ImGui.EndTooltip()
            if ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
                local numSlots = item.WornSlots() or 0
                if numSlots > 0 and opts.Popped then
                    for i = 1, numSlots do
                        local slotID = item.WornSlot(i)() or '-1'
                        local wornItem = mq.TLO.Me.Inventory(slotID)
                        if wornItem() and wornItem.ID() then
                            opts.Popped[wornItem.ID()] = wornItem
                        end
                    end
                end
            end
        end
        ImGui.SetCursorPosX(cursorX)
        ImGui.SetCursorPosY(cursorY2)
    end

    ImGui.Spacing()

    ImGui.Text("Type: ")
    ImGui.SameLine()
    ImGui.TextColored(Colors.color('teal'), "%s", itemData.Type)

    ImGui.Text("Size: ")
    ImGui.SameLine()
    ImGui.TextColored(Colors.color('yellow'), "%s", InventoryData.Sizes[itemData.Size] or 'Unknown')

    local restrictionString = ''
    local needSameLine = false
    if itemData.isMagic then
        needSameLine = true
        restrictionString = restrictionString .. 'Magic '
    end
    if itemData.isNoDrop then
        if needSameLine then restrictionString = restrictionString .. ',' end
        restrictionString = restrictionString .. 'No Drop '
        needSameLine = true
    end
    if itemData.isNoRent then
        if needSameLine then restrictionString = restrictionString .. ',' end
        restrictionString = restrictionString .. 'No Rent '
        needSameLine = true
    end
    if itemData.isNoTrade then
        if needSameLine then restrictionString = restrictionString .. ',' end
        restrictionString = restrictionString .. 'No Trade '
        needSameLine = true
    end
    if itemData.isLore then
        if needSameLine then restrictionString = restrictionString .. ',' end
        restrictionString = restrictionString .. 'Lore '
        needSameLine = true
    end
    if itemData.isAttuneable then
        if needSameLine then restrictionString = restrictionString .. ',' end
        restrictionString = restrictionString .. 'Attuneable '
        needSameLine = true
    end

    if restrictionString ~= '' then
        ImGui.PushTextWrapPos(ImGui.GetWindowWidth() - 60)
        ImGui.TextColored(Colors.color('grey'), "%s", restrictionString)
        ImGui.PopTextWrapPos()
    end

    if ImGui.BeginTable('basicinfo##basicinfo', 2, ImGuiTableFlags.None) then
        ImGui.TableSetupColumn("Info##basicinfo", ImGuiTableColumnFlags.WidthFixed, 60)
        ImGui.TableSetupColumn("Value##basicinfo", ImGuiTableColumnFlags.WidthStretch, 240)
        ImGui.TableNextRow()
        if itemData.ClassList and itemData.ClassList ~= '' then
            ImGui.TableNextColumn()
            ImGui.Text("Classes:")
            ImGui.TableNextColumn()
            ImGui.PushTextWrapPos(ImGui.GetColumnWidth(-1))
            ImGui.TextColored(Colors.color('grey'), "%s", itemData.ClassList)
            ImGui.PopTextWrapPos()
        end
        if itemData.RaceList and itemData.RaceList ~= '' then
            ImGui.TableNextColumn()
            ImGui.Text("Races:")
            ImGui.TableNextColumn()
            ImGui.PushTextWrapPos(ImGui.GetColumnWidth(-1))
            ImGui.TextColored(Colors.color('grey'), "%s", itemData.RaceList)
            ImGui.PopTextWrapPos()
        end
        if itemData.WornSlots ~= '' then
            ImGui.TableNextColumn()
            ImGui.Text('Slots:')
            ImGui.TableNextColumn()
            ImGui.PushTextWrapPos(ImGui.GetColumnWidth(-1))
            ImGui.TextColored(Colors.color('grey'), "%s", itemData.WornSlots)
            ImGui.PopTextWrapPos()
        end
        ImGui.EndTable()
    end

    if ImGui.BeginTable('LVlInfo##lvl', 2, ImGuiTableFlags.None) then
        ImGui.TableSetupColumn("Level Info##lvlinfo", ImGuiTableColumnFlags.WidthFixed, 150)
        ImGui.TableSetupColumn("Value##lvlvalue", ImGuiTableColumnFlags.WidthFixed, 150)
        ImGui.TableNextRow()
        if itemData.ReqLvl > 0 then
            ImGui.TableNextColumn()
            ImGui.Text('Req Lvl: ')
            ImGui.SameLine()
            local reqColorLabel = itemData.ReqLvl <= MySelf.Level() and 'green' or 'tangarine'
            ImGui.TextColored(Colors.color(reqColorLabel), "%s", itemData.ReqLvl)
        end
        if itemData.RecLvl and itemData.RecLvl > 0 then
            ImGui.TableNextColumn()
            ImGui.Text('Rec Lvl: ')
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('softblue'), "%s", itemData.RecLvl)
        end
        ImGui.TableNextColumn()
        ImGui.Text("Weight: ")
        ImGui.SameLine()
        ImGui.TextColored(Colors.color('pink2'), "%s", itemData.Weight)
        if itemData.NumSlots and itemData.NumSlots > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("Slots: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('yellow'), "%s", itemData.NumSlots)
            if itemData.SizeCapacity and itemData.SizeCapacity > 0 then
                ImGui.TableNextColumn()
                ImGui.Text("Bag Size:")
                ImGui.SameLine()
                ImGui.TextColored(Colors.color('teal'), "%s", InventoryData.Sizes[itemData.SizeCapacity] or 'Unknown')
            end
        end
        if itemData.MaxStack > 1 then
            ImGui.TableNextColumn()
            ImGui.Text("Qty: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('yellow'), "%s", itemData.Stack)
            ImGui.SameLine()
            ImGui.Text(" / ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('teal'), "%s", itemData.MaxStack)
        end
        ImGui.EndTable()
    end

    if ImGui.BeginTable("DamageStats", 2, ImGuiTableFlags.None) then
        ImGui.TableSetupColumn("Stat##dmg", ImGuiTableColumnFlags.WidthFixed, 150)
        ImGui.TableSetupColumn("Value##dmg", ImGuiTableColumnFlags.WidthFixed, 150)
        ImGui.TableNextRow()
        if itemData.BaseDMG > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("Dmg: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('pink2'), "%s", itemData.BaseDMG or 'NA')
        end
        if itemData.Delay > 0 then
            ImGui.TableNextColumn()
            ImGui.Text(" Dly: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('yellow'), "%s", itemData.Delay or 'NA')
        end
        if itemData.BonusDmgType ~= 'None' then
            ImGui.TableNextColumn()
            ImGui.Text("Bonus %s Dmg ", itemData.BonusDmgType)
            ImGui.TableNextColumn()
        end
        if itemData.Haste > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("Haste: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('green'), "%s%%", itemData.Haste)
        end
        if itemData.DmgShield > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("Dmg Shield: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('yellow'), "%s", itemData.DmgShield)
        end
        if itemData.DmgShieldMit > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("DS Mit: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('teal'), "%s", itemData.DmgShieldMit)
        end
        if itemData.Avoidance > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("Avoidance: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('green'), "%s", itemData.Avoidance)
        end
        if itemData.DotShield > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("DoT Shielding: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('yellow'), "%s", itemData.DotShield)
        end
        if itemData.Accuracy > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("Accuracy: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('green'), "%s", itemData.Accuracy)
        end
        if itemData.SpellShield > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("Spell Shield: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('teal'), "%s", itemData.SpellShield)
        end
        if itemData.HealAmount > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("Heal Amt: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('pink2'), "%s", itemData.HealAmount)
        end
        if itemData.SpellDamage > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("Spell Dmg: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('teal'), "%s", itemData.SpellDamage)
        end
        if itemData.StunResist > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("Stun Res: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('green'), "%s", itemData.StunResist)
        end
        if itemData.Clairvoyance > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("Clairvoyance: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('green'), "%s", itemData.Clairvoyance)
        end
        if itemData.BaseDMG > 0 and itemData.Delay > 0 then
            ImGui.TableNextColumn()
            ImGui.Text("Ratio: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('teal'), "%0.3f", (itemData.Delay / (itemData.BaseDMG or 1)) or 0)
        end
        ImGui.EndTable()
    end

    ImGui.Spacing()

    if hasBase then
        ImGui.SeparatorText('Stats')
        if ImGui.BeginTable("BaseStats##itemBaseStats", 2, ImGuiTableFlags.None) then
            ImGui.TableSetupColumn("Stat", ImGuiTableColumnFlags.WidthFixed, 150)
            ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthFixed, 150)
            ImGui.TableNextRow()
            if itemData.AC > 0 then
                ImGui.TableNextColumn()
                ImGui.Text(" AC: ")
                ImGui.SameLine()
                ImGui.TextColored(Colors.color('teal'), " %s", itemData.AC)
                ImGui.TableNextRow()
            end
            if itemData.HP and itemData.HP > 0 then
                ImGui.TableNextColumn()
                ImGui.Text("HPs: ")
                ImGui.SameLine()
                ImGui.TextColored(Colors.color('pink2'), "%s", itemData.HP)
            end
            if itemData.Mana and itemData.Mana > 0 then
                ImGui.TableNextColumn()
                ImGui.Text("Mana: ")
                ImGui.SameLine()
                ImGui.TextColored(Colors.color('teal'), "%s", itemData.Mana)
            end
            if itemData.Endurance and itemData.Endurance > 0 then
                ImGui.TableNextColumn()
                ImGui.Text("End: ")
                ImGui.SameLine()
                ImGui.TextColored(Colors.color('yellow'), "%s", itemData['Endurance'])
            end
            if itemData.HPRegen > 0 then
                ImGui.TableNextColumn()
                ImGui.Text("HP Regen: ")
                ImGui.SameLine()
                ImGui.TextColored(Colors.color('pink2'), "%s", itemData.HPRegen)
            end
            if itemData.ManaRegen > 0 then
                ImGui.TableNextColumn()
                ImGui.Text("Mana Regen: ")
                ImGui.SameLine()
                ImGui.TextColored(Colors.color('teal'), "%s", itemData.ManaRegen)
            end
            if itemData.EnduranceRegen > 0 then
                ImGui.TableNextColumn()
                ImGui.Text("Endurance Regen: ")
                ImGui.SameLine()
                ImGui.TextColored(Colors.color('yellow'), "%s", itemData.EnduranceRegen)
            end
            ImGui.EndTable()
        end
    end

    if hasStats then
        if ImGui.BeginTable("Stats##itemStats", 2, ImGuiTableFlags.None) then
            ImGui.TableSetupColumn("Stat##stats", ImGuiTableColumnFlags.WidthFixed, 150)
            ImGui.TableSetupColumn("Value##stats", ImGuiTableColumnFlags.WidthFixed, 150)
            ImGui.TableNextRow()
            for _, statInfo in ipairs(statHeroicPair) do
                if itemData[statInfo.stat] and itemData[statInfo.stat] > 0 then
                    ImGui.TableNextColumn()
                    ImGui.Text("%s: ", statInfo.stat)
                    ImGui.SameLine()
                    ImGui.TextColored(Colors.color('tangarine'), "%s", itemData[statInfo.stat])
                    if itemData[statInfo.heroic] > 0 then
                        ImGui.SameLine()
                        ImGui.TextColored(Colors.color('yellow'), " + %s", itemData[statInfo.heroic])
                    end
                end
            end
            ImGui.EndTable()
        end
    end

    if hasResists then
        ImGui.SeparatorText('Resists')
        if ImGui.BeginTable("Resists##itemResists", 2, ImGuiTableFlags.None) then
            ImGui.TableSetupColumn("Stat##res", ImGuiTableColumnFlags.WidthFixed, 150)
            ImGui.TableSetupColumn("Value##res", ImGuiTableColumnFlags.WidthFixed, 150)
            ImGui.TableNextRow()
            for _, resInfo in ipairs(resistHeroicPair) do
                if itemData[resInfo.resist] > 0 then
                    ImGui.TableNextColumn()
                    ImGui.Text("%s:\t", resInfo.label)
                    ImGui.SameLine()
                    ImGui.TextColored(Colors.color('green'), "%s", itemData[resInfo.resist])
                    if itemData[resInfo.heroic] > 0 then
                        ImGui.SameLine()
                        ImGui.TextColored(Colors.color('yellow'), " + %s", itemData[resInfo.heroic])
                    end
                end
            end
            ImGui.EndTable()
        end
    end

    if itemData.AugSlots > 0 then
        ImGui.SeparatorText('Augments')
        for i = 1, itemData.AugSlots do
            local augSlotName = itemData['AugSlot' .. i] or 'none'
            local augTypeName = itemData['AugType' .. i] or 'none'
            if augSlotName ~= 'none' or augTypeName ~= 21 then
                ImGui.Text("Slot %s: ", i)
                ImGui.SameLine()
                ImGui.PushTextWrapPos(290)
                ImGui.TextColored(Colors.color('teal'), "%s Type (%s)", (augSlotName ~= 'none' and augSlotName or 'Empty'), augTypeName)
                ImGui.PopTextWrapPos()
            end
        end
    end

    if hasCombatEffects or itemData.Clicky or itemData.Spelleffect ~= '' or itemData.Worn ~= 'none' or
        itemData.Focus1 ~= 'none' or itemData.Focus2 ~= 'none' then
        ImGui.SeparatorText('Efx')
        if itemData.Clicky then
            ImGui.Dummy(10, 10)
            ImGui.Text("Charges: ")
            ImGui.SameLine()
            ImGui.TextColored(Colors.color('yellow'), "%s", itemData.Charges)
            ImGui.Text("Clicky Spell: ")
            ImGui.SameLine()
            ImGui.PushTextWrapPos(290)
            ImGui.TextColored(Colors.color('teal'), "%s", itemData.Clicky)
            if ImGui.IsItemHovered() then
                if ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
                    mq.TLO.Spell(itemData.ClickyID).Inspect()
                end
            end
            if itemData.ClickyDesc ~= '' then
                ImGui.Indent(5)
                ImGui.TextColored(Colors.color('yellow'), itemData.ClickyDesc)
                ImGui.Unindent(5)
            end
            ImGui.PopTextWrapPos()
        end

        if (itemData.Spelleffect ~= "" and
                not ((itemData.Spelleffect == itemData.Clicky) or (itemData.Spelleffect == itemData.Worn) or
                    (itemData.Focus1 == itemData.Spelleffect) or (itemData.Focus2 == itemData.Spelleffect))) then
            ImGui.Dummy(10, 10)
            local effectTypeLabel = item.EffectType() ~= 'None' and item.EffectType() or "Spell"
            ImGui.Text("%s Effect: ", effectTypeLabel)
            ImGui.SameLine()
            ImGui.PushTextWrapPos(290)
            ImGui.TextColored(Colors.color('teal'), "%s", itemData.Spelleffect)
            if ImGui.IsItemHovered() then
                if ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
                    mq.TLO.Spell(itemData.SpellID).Inspect()
                end
            end
            if itemData.SpellDesc ~= '' then
                ImGui.Indent(5)
                ImGui.TextColored(Colors.color('yellow'), itemData.SpellDesc)
                ImGui.Unindent(5)
            end
            ImGui.PopTextWrapPos()
        end

        if itemData.Worn ~= 'none' then
            ImGui.Dummy(10, 10)
            ImGui.Text("Worn Effect: ")
            ImGui.SameLine()
            ImGui.PushTextWrapPos(290)
            ImGui.TextColored(Colors.color('teal'), "%s", itemData.Worn)
            if ImGui.IsItemHovered() then
                if ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
                    mq.TLO.Spell(itemData.WornID).Inspect()
                end
            end
            if itemData.WornDesc ~= '' then
                ImGui.Indent(5)
                ImGui.TextColored(Colors.color('yellow'), itemData.WornDesc)
                ImGui.Unindent(5)
            end
            ImGui.PopTextWrapPos()
        end

        if itemData.Focus1 ~= 'none' then
            ImGui.Dummy(10, 10)
            ImGui.Text("Focus Effect: ")
            ImGui.SameLine()
            ImGui.PushTextWrapPos(290)
            ImGui.TextColored(Colors.color('teal'), "%s", itemData.Focus1)
            if ImGui.IsItemHovered() then
                if ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
                    mq.TLO.Spell(itemData.Focus1ID).Inspect()
                end
            end
            if itemData.Focus1Desc ~= '' then
                ImGui.Indent(5)
                ImGui.TextColored(Colors.color('yellow'), itemData.Focus1Desc)
                ImGui.Unindent(5)
            end
            ImGui.PopTextWrapPos()
        end

        if itemData.Focus2 ~= 'none' then
            ImGui.Dummy(10, 10)
            ImGui.Text("Focus2 Effect: ")
            ImGui.SameLine()
            ImGui.PushTextWrapPos(290)
            ImGui.TextColored(Colors.color('teal'), "%s", itemData.Focus2)
            if ImGui.IsItemHovered() then
                if ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
                    mq.TLO.Spell(itemData.Focus2ID).Inspect()
                end
            end
            if itemData.Focus2Desc ~= '' then
                ImGui.Indent(5)
                ImGui.TextColored(Colors.color('yellow'), itemData.Focus2Desc)
                ImGui.Unindent(5)
            end
            ImGui.PopTextWrapPos()
        end
    end

    if itemData.isEvolving then
        ImGui.SeparatorText('Evolving Info')
        ImGui.Text("Evolving Level: ")
        ImGui.SameLine()
        ImGui.TextColored(Colors.color("tangarine"), "%d", itemData.EvolvingLevel)
        ImGui.Text("Evolving Max Level: ")
        ImGui.SameLine()
        ImGui.TextColored(Colors.color("teal"), "%d", itemData.EvolvingMaxLevel)
        ImGui.Text("Evolving Exp: ")
        ImGui.SameLine()
        ImGui.TextColored(Colors.color("yellow"), "%0.2f%%", itemData.EvolvingExpPct)
    end

    ImGui.SeparatorText('Value')
    ImGui.Dummy(10, 10)
    ImGui.Text("Value: ")
    ImGui.SameLine()
    InventoryData.DrawItemValue(itemData.Value or 0)
    if itemData.TributeValue > 0 then
        ImGui.Text("Tribute Value: ")
        ImGui.SameLine()
        ImGui.TextColored(Colors.color('yellow'), "%s", itemData.TributeValue)
    end
end

function InventoryData.RenderItemInfoWin(item, poppedTable, opts)
    if item == nil then return end
    if opts == nil or type(opts) ~= 'table' then opts = {} end
    local senderScript = opts ~= nil and (opts.Sender or "unknown") or "unknown"
    local itemID = item.ID()
    local itemName = item.Name()

    ImGui.SetNextWindowSize(320, 0.0, ImGuiCond.Always)
    local mouseX, mouseY = ImGui.GetMousePos()
    ImGui.SetNextWindowPos((mouseX - 30), (mouseY - 5), ImGuiCond.FirstUseEver)
    local open, show = ImGui.Begin(string.format("%s##iteminfo_%s_%s", itemName, itemID, senderScript), true)
    if not open then
        show = false
        poppedTable[itemID] = nil
    end
    if show then
        if ImGui.IsWindowFocused() then
            if ImGui.IsKeyPressed(ImGuiKey.Escape) then
                show = false
                poppedTable[itemID] = nil
            end
        end
        opts.Popped = poppedTable or {}
        InventoryData.RenderItemToolTip(item, opts)
    end
    ImGui.End()
end

return InventoryData
