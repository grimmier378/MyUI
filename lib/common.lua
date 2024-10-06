local mq = require('mq')
local ImGui = require('ImGui')
local CommonUtils = require('mq.Utils')

CommonUtils.Animation_Item = mq.FindTextureAnimation('A_DragItem')
CommonUtils.Animation_Spell = mq.FindTextureAnimation('A_SpellIcons')

---comment Get the current time in a formatted string
---@param slot integer @ the slot of the buff to get the duration of
---@return string @ returns the formatted time string
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

---comment Caclulate a Dynamic color within a Range based on a value between 0 and 100
---Useful for Progress Bar Colors
---@param minColor any @ the minimum color in the Range
---@param maxColor any @ the maximum color in the Range
---@param value any @ Current Value
---@return any @ returns new Color between the min and max color based on the value
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

---@param type string @ 'item' or 'pwcs' or 'spell' type of icon to draw
---@param txt string @ the tooltip text
---@param iconID integer|string @ the icon id to draw
---@param iconSize integer|nil @ the size of the icon to draw
function CommonUtils.DrawStatusIcon(iconID, type, txt, iconSize)
	iconSize = iconSize or 26
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

---@param spawn MQSpawn
function CommonUtils.GetConColor(spawn)
	local conColor = string.lower(spawn.ConColor()) or 'WHITE'
	return conColor
end

function CommonUtils.SetImage(file_path)
	return mq.CreateTexture(file_path)
end

---comment Print Output to the Console or MyChat
---@param mychat_tab any @ the MyChat Tab to output to or Pass nil to output to the main console
---@param msg any @ the message to output
---@param ... unknown @ any additional arguments to format the message
function CommonUtils.PrintOutput(mychat_tab, msg, ...)
	msg = string.format(msg, ...)
	if MyUI_MyChatHandler ~= nil and mychat_tab ~= nil then
		MyUI_MyChatHandler(mychat_tab, msg)
	else
		print(msg)
	end
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
			CommonUtils.PrintOutput('MyUI', "\ayFound Depreciated Setting: \ao%s \ayRemoving it from the Settings File.", setting)
			loaded_settings[setting] = nil
			newSetting = true
		end
	end
	return newSetting
end

---comment
--- Takes in a table of default settings and a table of loaded settings and checks for any New default settings
--- If a new setting is found it will add it to the loaded settings table
--- Returns true if a new setting was found so you know to save the settings file
---@param default_settings table @ the default settings table
---@param loaded_settings table @ the loaded settings table
---@return boolean @ returns true if a new setting was found
function CommonUtils.CheckDefaultSettings(default_settings, loaded_settings)
	local newSetting = false
	for setting, value in pairs(default_settings or {}) do
		if loaded_settings[setting] == nil then
			CommonUtils.PrintOutput('MyUI', "\ayNew Default Setting: \ao%s \ayAdding it from the Settings File.", setting)
			loaded_settings[setting] = value
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
	if timeStamps == nil then timeStamps = true end
	text = text:gsub("%[%d%d:%d%d:%d%d%] ", "")
	if timeStamps then
		-- Define TimeStamp colors
		local yellowColor = ImVec4(1, 1, 0, 1)
		local whiteColor = ImVec4(1, 1, 1, 1)
		console:AppendTextUnformatted(yellowColor, "[")
		console:AppendTextUnformatted(whiteColor, timestamp)
		console:AppendTextUnformatted(yellowColor, "] ")
	end
	if textColor ~= nil then
		console:AppendTextUnformatted(textColor, text)
		console:AppendText("") -- Move to the next line after the entry
	else
		console:AppendText(text)
	end
end

function CommonUtils.GiveItem(target_id)
	if ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
		mq.cmdf("/target id %s", target_id)
		if mq.TLO.Cursor() then
			mq.cmdf('/multiline ; /tar id %s; /face; /if (${Cursor.ID}) /click left target', target_id)
		end
	end
end

return CommonUtils
