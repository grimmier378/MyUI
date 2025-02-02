local mq = require("mq")
local ImGui = require("ImGui")

---@class KeypressHandler
local KeypressHandler = {}
-- Store previous key states and whether "Held" was already printed
KeypressHandler.keyStates = {}
KeypressHandler.heldPrinted = {}

-- Function to check if any modifier key is held
---@return string
function KeypressHandler:getModifierPrefix()
    local prefix = ""
    if ImGui.IsKeyDown(ImGuiKey.LeftCtrl) or ImGui.IsKeyDown(ImGuiKey.RightCtrl) then
        prefix = "ctrl+"
    elseif ImGui.IsKeyDown(ImGuiKey.LeftShift) or ImGui.IsKeyDown(ImGuiKey.RightShift) then
        prefix = "shift+"
    elseif ImGui.IsKeyDown(ImGuiKey.LeftAlt) or ImGui.IsKeyDown(ImGuiKey.RightAlt) then
        prefix = "alt+"
    end
    return prefix
end

---@param textInput? boolean @Defaults to false
function KeypressHandler:handleKeypress(textInput)
    if (textInput == nil) then textInput = false end
    if (textInput) then
        return
    end
    if not ImGui.IsWindowFocused(ImGuiFocusedFlags.RootAndChildWindows) then
        return
    end

    for i = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END, 1 do
        local key = ImGui.GetKeyName(i)
        local isDown = ImGui.IsKeyDown(i)
        local wasDown = self.keyStates[i] or false

        -- Ignore invalid keys (e.g., mouse keys)
        if key == "Unknown" or string.find(key, "Mouse") then
            self.keyStates[i] = isDown
            self.heldPrinted[i] = nil
            return
        end

        -- Handle Escape key separately
        if key == "Escape" and isDown and not wasDown then
            mq.cmd("/keypress esc")
            -- Handle modifier keys separately (we will track their state)
        elseif string.find(key, "Ctrl") or string.find(key, "Shift") or string.find(key, "Alt") then
            self.keyStates[i] = isDown
            self.heldPrinted[i] = nil
            -- Handle other keys
        elseif isDown and not wasDown then
            local prefix = self:getModifierPrefix()

            -- Send key press with modifier (if any) or without
            local command = prefix .. key
            mq.cmdf("/keypress %s hold", command)

            self.heldPrinted[i] = false -- Reset "held" state tracking
            -- Handle key being held down (print only once)
        elseif isDown and wasDown and not self.heldPrinted[i] then
            -- Only print "Held" once for each key
            self.heldPrinted[i] = true
            -- Handle key release (when key is lifted)
        elseif not isDown and wasDown then
            local prefix = self:getModifierPrefix()
            -- Send key release with modifier (if any) or without
            local command = prefix .. key
            mq.cmdf("/keypress %s release", command)

            self.heldPrinted[i] = nil
        end

        -- Update key state
        self.keyStates[i] = isDown
    end
end

return KeypressHandler
