local mq = require('mq')
local ImGui = require('ImGui')
local CommonUtils = require('mq.Utils')

CommonUtils.Animation_Item = mq.FindTextureAnimation('A_DragItem')
CommonUtils.Animation_Spell = mq.FindTextureAnimation('A_SpellIcons')

function CommonUtils.GetTargetBuffDuration(slot)
	local remaining = mq.TLO.Target.Buff(slot).Duration() or 0
	remaining = remaining / 1000 -- convert to seconds
	-- Calculate hours, minutes, and seconds
	local h = math.floor(remaining / 3600) or 0
	remaining = remaining % 3600 -- remaining seconds after removing hours
	local m = math.floor(remaining / 60) or 0
	local s = remaining % 60  -- remaining seconds after removing minutes
	-- Format the time string as H : M : S
	local sRemaining = string.format("%02d:%02d:%02d", h, m, s)
	return sRemaining
end

function CommonUtils.CalculateColor(minColor, maxColor, value)
	-- Ensure value is within the range of 0 to 100
	value = math.max(0, math.min(100, value))

	-- Calculate the proportion of the value within the range
	local proportion = value / 100

	-- Interpolate between minColor and maxColor based on the proportion
	local r = minColor[1] + proportion * (maxColor[1] - minColor[1])
	local g = minColor[2] + proportion * (maxColor[2] - minColor[2])
	local b = minColor[3] + proportion * (maxColor[3] - minColor[3])
	local a = minColor[4] + proportion * (maxColor[4] - minColor[4])

	return r, g, b, a
end

---@param iconID integer
---@param spell MQSpell -- Spell Userdata
---@param slot integer -- the slot of the spell
---@param iconSize integer|nil	-- default 32
---@param pulse boolean|nil
function CommonUtils.DrawInspectableSpellIcon(iconID, spell, slot, iconSize, pulse, flashAlpha)
	local cursor_x, cursor_y = ImGui.GetCursorPos()
	local beniColor = IM_COL32(0, 20, 180, 190) -- blue benificial default color
	CommonUtils.Animation_Spell:SetTextureCell(iconID or 0)
	---@diagnostic disable-next-line: undefined-global
	local caster = spell.Caster() or '?' -- the caster of the Spell
	if not spell.Beneficial() then
		beniColor = IM_COL32(255, 0, 0, 190) --red detrimental
	end
	if caster == MyUI_CharLoaded and not spell.Beneficial() then
		beniColor = IM_COL32(190, 190, 20, 255) -- detrimental cast by me (yellow)
	end
	ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
		ImGui.GetCursorScreenPosVec() + iconSize, beniColor)
	ImGui.SetCursorPos(cursor_x + 3, cursor_y + 3)
	if caster == MyUI_CharLoaded and spell.Beneficial() then
		ImGui.DrawTextureAnimation(CommonUtils.Animation_Spell, iconSize - 6, iconSize - 6, true)
	else
		ImGui.DrawTextureAnimation(CommonUtils.Animation_Spell, iconSize - 5, iconSize - 5)
	end
	ImGui.SetCursorPos(cursor_x + 2, cursor_y + 2)
	local sName = spell.Name() or '??'
	local sDur = spell.Duration.TotalSeconds() or 0
	ImGui.PushID(tostring(iconID) .. sName .. "_invis_btn")
	if sDur < 18 and sDur > 0 and pulse then
		local flashColor = IM_COL32(0, 0, 0, flashAlpha)
		ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
			ImGui.GetCursorScreenPosVec() + iconSize - 4, flashColor)
	end
	ImGui.SetCursorPos(cursor_x, cursor_y)
	ImGui.InvisibleButton(sName, ImVec2(iconSize, iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
	if ImGui.IsItemHovered() then
		if (ImGui.IsMouseReleased(1)) then
			spell.Inspect()
		end
		if ImGui.BeginTooltip() then
			ImGui.TextColored(MyUI_Colors.color('yellow'), '%s', sName)
			ImGui.TextColored(MyUI_Colors.color('green'), '%s', CommonUtils.GetTargetBuffDuration(slot))
			ImGui.Text('Cast By: ')
			ImGui.SameLine()
			ImGui.TextColored(MyUI_Colors.color('light blue'), '%s', caster)
			ImGui.EndTooltip()
		end
	end
	ImGui.PopID()
end

---@param type string @ 'item' or 'pwcs' or 'spell' type of icon to draw
---@param txt string @ the tooltip text
---@param iconID integer|string @ the icon id to draw
---@param iconSize integer @ the size of the icon to draw
function CommonUtils.DrawStatusIcon(iconID, type, txt, iconSize)
	CommonUtils.Animation_Spell:SetTextureCell(iconID or 0)
	CommonUtils.Animation_Item:SetTextureCell(iconID or 3996)
	if type == 'item' then
		ImGui.DrawTextureAnimation(CommonUtils.Animation_Item, iconSize, iconSize)
	elseif type == 'pwcs' then
		local animPWCS = mq.FindTextureAnimation(iconID)
		animPWCS:SetTextureCell(iconID)
		ImGui.DrawTextureAnimation(animPWCS, iconSize, iconSize)
	else
		ImGui.DrawTextureAnimation(CommonUtils.Animation_Spell, iconSize, iconSize)
	end
	if ImGui.IsItemHovered() then
		ImGui.SetTooltip(txt)
	end
end

function CommonUtils.DrawTargetBuffs(count, flashAlpha, rise, iconSize)
	local iconsDrawn = 0
	-- Width and height of each texture
	local windowWidth = ImGui.GetWindowContentRegionWidth()
	-- Calculate max icons per row based on the window width
	local maxIconsRow = (windowWidth / iconSize) - 0.75
	if rise == true then
		flashAlpha = flashAlpha + 5
	elseif rise == false then
		flashAlpha = flashAlpha - 5
	end
	if flashAlpha == 128 then rise = false end
	if flashAlpha == 25 then rise = true end
	ImGui.BeginGroup()
	ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
	if mq.TLO.Me.BuffCount() ~= nil then
		for i = 1, count do
			local sIcon = mq.TLO.Target.Buff(i).SpellIcon() or 0
			if mq.TLO.Target.Buff(i) ~= nil then
				CommonUtils.DrawInspectableSpellIcon(sIcon, mq.TLO.Target.Buff(i), i, iconSize, true, flashAlpha)
				iconsDrawn = iconsDrawn + 1
			end
			-- Check if we've reached the max icons for the row, if so reset counter and new line
			if iconsDrawn >= maxIconsRow then
				iconsDrawn = 0 -- Reset counter
			else
				-- Use SameLine to keep drawing items on the same line, except for when a new line is needed
				if i < count then
					ImGui.SameLine()
				else
					ImGui.SetCursorPosX(1)
				end
			end
		end
	end
	ImGui.PopStyleVar()
	ImGui.EndGroup()
end

---@param spawn MQSpawn
function CommonUtils.CetConLevel(spawn)
	local conColor = string.lower(spawn.ConColor()) or 'WHITE'
	return conColor
end

function CommonUtils.SetImage(file_path)
	return mq.CreateTexture(file_path)
end

function CommonUtils.PrintOutput(msg, ...)
	msg = string.format(msg, ...)
	printf(msg)
end

---comment
--- Takes in a table of default settings and a table of loaded settings and checks for depreciated settings
--- If a depreciated setting is found it will remove it from the loaded settings table
--- Returns true if a new setting was found so you know to save the settings file
---@param default_settings table @ the default settings table
---@param loaded_settings table @ the loaded settings table
---@return boolean @ returns true if a new setting was found
function CommonUtils.CheckRemovedSettings(default_settings, loaded_settings)
	local newSetting = false
	for setting, value in pairs(loaded_settings or {}) do
		if default_settings[setting] == nil then
			CommonUtils.PrintOutput("\ayFound Depreciated Setting: \ao%s \ayRemoving it from the Settings File.", setting)
			loaded_settings[setting] = nil
			newSetting = true
		end
	end
	return newSetting
end

-- Function to append colored text segments
---@param console any @ the console we are writing to
---@param timestamp string @ the timestamp for the line
---@param text string @ the text we are writing
---@param textColor table|nil @ the color we are writing the text in
---@param timeStamps boolean|nil @ are we writing timestamps?
function CommonUtils.AppendColoredTimestamp(console, timestamp, text, textColor, timeStamps)
	text = text:gsub("%[%d%d:%d%d:%d%d%] ", "")
	if timeStamps then
		-- Define TimeStamp colors
		local yellowColor = ImVec4(1, 1, 0, 1)
		local whiteColor = ImVec4(1, 1, 1, 1)
		console:AppendTextUnformatted(yellowColor, "[")
		console:AppendTextUnformatted(whiteColor, timestamp)
		console:AppendTextUnformatted(yellowColor, "] ")
	end

	console:AppendText(text)
end

function CommonUtils.GiveItem(target_id)
	if ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
		mq.cmdf("/target id %s", target_id)
		if TLO.Cursor() then
			mq.cmdf('/multiline ; /tar id %s; /face; /if (${Cursor.ID}) /click left target', target_id)
		end
	end
end

return CommonUtils
