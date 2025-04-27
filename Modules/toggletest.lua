local mq = require('mq')
local ImGui = require('ImGui')
local isRunning = true
local testToggleSize = 20
local testToggleWdith = testToggleSize * 2
local testOnColor = ImVec4(0.2, 0.8, 0.2, 1)  -- Default green
local testOffColor = ImVec4(0.8, 0.2, 0.2, 1) -- Default red
local showLabels = true
local showDefaultSize = true
local showDefaultColor = true
local testAutoWidth = false
local testStars = false

local toggleList = {
	['Toggle-1'] = false,
	['Toggle-2'] = true,
	['Toggle-3'] = false,
	['Toggle-4'] = false,
	['Toggle-5'] = true,
	['Toggle-6'] = false,
	['Toggle-7'] = false,
	['Toggle-8'] = false,
}

---@param draw_list ImDrawList Draw list to draw from
---@param pos ImVec2 Position to start from (top-left corner of the star)
---@param size number Diameter of the star's outer points as a circle
---@param star_color ImU32 Color as ImU32
---@param rotation number Rotation in radians (optional)
---@param num_points integer Number of points to draw (default 5)
---@param border boolean Optional border flag (default false)
function CommonUtils.RenderStar(draw_list, pos, size, star_color, rotation, num_points, border)
	num_points = num_points or 5
	rotation = rotation or 0
	if num_points < 2 then num_points = 2 end

	local outer_radius = size * 0.5
	local inner_radius = outer_radius * 0.5
	local center = ImVec2(pos.x + outer_radius, pos.y + outer_radius)
	local angle_step = math.pi / num_points -- half the points are inner
	local points = {}

	local function polarToVec2(angleRad, distance)
		return ImVec2(
			center.x + math.cos(angleRad) * distance,
			center.y + math.sin(angleRad) * distance
		)
	end

	for i = 0, num_points * 2 - 1 do
		local angle = rotation + (i * angle_step)
		local radius = (i % 2 == 0) and outer_radius or inner_radius
		table.insert(points, polarToVec2(angle, radius))
	end

	if border then
		draw_list:AddCircle(center, outer_radius, ImGui.GetColorU32(0.1, 0.1, 0.1, 0.4), 32, 2)
	end

	draw_list:AddConvexPolyFilled(points, star_color)
end

---@param id string Unique ID for the button
---@param value boolean Current toggle state
---@param on_color ImVec4|nil Color when ON
---@param off_color ImVec4|nil Color when OFF
---@param width number|nil Width of the toggle
---@param height number|nil Height of the toggle
---@return boolean value New toggle value
---@return boolean clicked Whether the value changed
function DrawStarToggle(id, value, on_color, off_color, width, height)
	width = width or 40
	height = height or 20
	on_color = on_color or ImVec4(0.2, 0.8, 0.2, 1) -- Default green
	off_color = off_color or ImVec4(0.8, 0.2, 0.2, 1) -- Default red

	local label = id:match("^(.-)##")
	if label and label ~= "" then
		ImGui.Text(string.format("%s:", label))
		ImGui.SameLine()
	end

	local clicked = false
	local draw_list = ImGui.GetWindowDrawList()
	local pos = { x = 0, y = 0, }
	pos.x, pos.y = ImGui.GetCursorScreenPos()
	local radius = height * 0.5

	-- Set up bounding box
	ImGui.InvisibleButton(id, width, height)
	if ImGui.IsItemClicked() then
		value = not value
		clicked = true
	end

	local t = value and 1.0 or 0.0
	local knob_x = pos.x + radius + t * (width - height)

	-- Background
	draw_list:AddRectFilled(
		ImVec2(pos.x, pos.y),
		ImVec2(pos.x + width, pos.y + height),
		ImGui.GetColorU32(value and on_color or off_color),
		height * 0.5
	)

	-- Knob (Star!)
	CommonUtils.RenderStar(draw_list, ImVec2(knob_x - radius * 0.5, pos.y), ImGui.GetColorU32(ImVec4(1, 1, 1, 1)), radius / (height))

	return value, clicked
end

local function RenderUI()
	ImGui.SetNextWindowSize(600, 400, ImGuiCond.FirstUseEver)
	local open, show = ImGui.Begin('Toggle Test2', true)
	if show then
		local screenWidth, screenHeight = ImGui.GetContentRegionAvail()

		-- draw options and color selections on the left
		if ImGui.BeginChild('left', (screenWidth - 10) * 0.5, screenHeight - 10, bit32.bor(ImGuiChildFlags.ResizeX, ImGuiChildFlags.Border)) then
			ImGui.TextWrapped("Showing Labels works the same as any Other ImGui label. anything before ## will be the label and displayed.")
			ImGui.Spacing()

			showLabels = ImGui.Checkbox("Show Labels", showLabels)
			showDefaultSize = ImGui.Checkbox("Show Default Size", showDefaultSize)
			showDefaultColor = ImGui.Checkbox("Show Default Color", showDefaultColor)
			testStars = ImGui.Checkbox("Star Toggle", testStars)

			ImGui.Spacing()
			ImGui.SeparatorText("Toggle Button Color")

			testOnColor = ImGui.ColorEdit4('On Color', testOnColor, bit32.bor(ImGuiColorEditFlags.NoInputs))

			testOffColor = ImGui.ColorEdit4('Off Color', testOffColor, bit32.bor(ImGuiColorEditFlags.NoInputs))
			ImGui.Spacing()
			ImGui.SeparatorText("Toggle Button Size")
			ImGui.TextWrapped("The size of the toggle button is set by the height and width. The default is height * 2.")
			ImGui.Spacing()

			testToggleSize = ImGui.SliderInt('Height', testToggleSize, 5, 100)

			ImGui.Spacing()
			testAutoWidth = ImGui.Checkbox("Auto Width", testAutoWidth)
			if not testAutoWidth then
				testToggleWdith = ImGui.SliderInt('Width', testToggleWdith, 0, 100)
			else
				testToggleWdith = testToggleSize * 2
			end
			if testToggleWdith == 0 then
				testToggleWdith = testToggleSize * 2
			end
			if testToggleSize < 5 then
				testToggleSize = 5
			end
		end
		ImGui.EndChild()
		ImGui.SameLine()
		local cursorX, cursorY = ImGui.GetCursorPos()
		if ImGui.BeginChild('right', (screenWidth - 5 - cursorX), screenHeight - 10, bit32.bor(ImGuiChildFlags.Border)) then
			ImGui.TextWrapped("This is a test of the toggle button. This test is using Labels and Default Size and Coloring.")
			ImGui.Spacing()
			for id, value in pairs(toggleList) do
				-- configure the label \ id

				local label = showLabels and string.format("%s##%s", id, id) or string.format("##%s", id)

				if showDefaultSize then
					if showDefaultColor then
						if testStars then
							toggleList[id], _ = DrawStarToggle(label, toggleList[id]) -- Default size and color
						else
							toggleList[id], _ = DrawToggle(label, toggleList[id]) -- Default size and color
						end
					else
						if testStars then
							toggleList[id], _ = DrawStarToggle(label, toggleList[id], testOnColor, testOffColor) -- Default size and custom color
						else
							toggleList[id], _ = DrawToggle(label, toggleList[id], testOnColor, testOffColor) -- Default size and custom color
						end
					end
				else
					if showDefaultColor then
						if testStars then
							toggleList[id], _ = DrawStarToggle(label, toggleList[id], nil, nil, testToggleSize, testToggleWdith) -- Custom size and default color
						else
							toggleList[id], _ = DrawToggle(label, toggleList[id], nil, nil, testToggleSize, testToggleWdith) -- Custom size and default color
						end
					else
						-- Custom size and custom color
						-- optionally you can supply a width as as a last parameter but default is height * 2
						if testStars then
							toggleList[id], _ = DrawStarToggle(label, toggleList[id], testOnColor, testOffColor, testToggleSize, testToggleWdith) -- Custom size and custom color
						else
							-- Custom size and custom color
							-- optionally you can supply a width as as a last parameter but default is height * 2
							-- toggleList[id], _ = DrawStarToggle(label, toggleList[id], testOnColor, testOffColor, testToggleSize, testToggleWdith) -- Custom size and custom color
							-- toggleList[id], _ = DrawStarToggle(label, toggleList[id], nil, nil, testToggleSize, testToggleWdith) -- Custom size and default color

							toggleList[id], _ = DrawToggle(label, toggleList[id], testOnColor, testOffColor, testToggleSize, testToggleWdith) -- Custom size and custom color
						end
					end
				end
				ImGui.SameLine()
				if toggleList[id] then
					ImGui.TextColored(testOnColor, "ON")
				else
					ImGui.TextColored(testOffColor, "OFF")
				end
				ImGui.Spacing()
			end
		end
		ImGui.EndChild()
	end
	ImGui.End()
	if not open then
		isRunning = false
	end
end

local function Init()
	mq.imgui.init('Toggle Test', RenderUI)
end

local function Main()
	while isRunning do
		mq.delay(100)
	end
end

Init()
Main()
