local mq = require('mq')
local ImGui = require('ImGui')
local ImAnim = require('ImAnim')
local StatusBar = {}
StatusBar._state = StatusBar._state or {}

local function clamp01(x)
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

local function getBarState(id, now)
	local state = StatusBar._state[id]
	if not state then
		state = { lastP = 0.0, dir = 1, t0 = now, }
		StatusBar._state[id] = state
	end
	return state
end

local function to01(percent)
	if percent > 1.0 then
		return clamp01(percent / 100.0)
	end
	return clamp01(percent)
end


---Draw a vertical Progress bar using ImAnim efx
---@param label string Label ID for the bar
---@param percent float|integer Percentage (0-100 or 0.0-1.0) to fill the bar
---@param lowCol ImVec4|table|nil Color at 0% fill
---@param highCol ImVec4|table|nil Color at 100% fill
---@param opts table|nil Optional settings:
---@return integer
function StatusBar.DrawProgressVert(label, percent, lowCol, highCol, opts)
	opts = opts or {}
	if lowCol == nil then lowCol = ImVec4(ImGui.GetStyleColor(ImGuiCol.PlotHistogram)) end
	if highCol == nil then highCol = ImVec4(ImGui.GetStyleColor(ImGuiCol.PlotHistogram)) end

	local now       = mq.gettime()
	local dl        = ImGui.GetWindowDrawList()

	-- shared opts (same names as horizontal)
	local borderOn  = (opts.border == true)
	local borderTh  = opts.borderThickness or 1.0
	local borderCol = (opts.borderColor ~= nil) and opts.borderColor or ImVec4(0.8, 0.8, 0.8, 1.0)

	local width     = (opts.width and opts.width > 3) and opts.width or 24.0 -- vertical bar width
	local padEnd    = opts.padEnd or 6.0                                  -- spacing after bar
	local rounding  = opts.rounding or 0.0
	local showText  = (opts.showText == true)
	local textFmt   = opts.textFmt or "%.0f%%"

	local showTicks = (opts.showTicks == true)
	local tickEvery = opts.tickEvery or 0.05
	local tickAlpha = opts.tickAlpha or 80
	local tickH     = opts.tickThickness or 1.0 -- thickness of horizontal tick lines

	local shimmerOn = (opts.shimmer == true)
	local glowOn    = (opts.glow == true)
	local bgU32     = opts.bgU32 or IM_COL32(30, 32, 40, 255)
	local tweenSec  = opts.tweenSeconds or 0.35

	local gradOn    = (opts.fillGradient == true)
	local gradMode  = opts.fillGradientMode or "static" -- "static" or "dynamic"
	local gradDir   = opts.fillGradientDir or "tb"   -- for vertical bars, default "tb"

	local target    = to01(percent)
	local id        = ImGui.GetID(label)

	local progress  = ImAnim.TweenFloat(
		id,
		ImHashStr(label),
		target,
		tweenSec,
		ImAnim.EasePreset(IamEaseType.OutExpo),
		IamPolicy.Crossfade,
		0
	)
	progress        = clamp01(progress)

	-- layout
	local bar_pos   = ImGui.GetCursorScreenPosVec()
	local avail     = ImGui.GetContentRegionAvailVec()
	local height    = (opts.height and opts.height > 3) and opts.height or (avail.y - padEnd)
	if height < 10 then height = 10 end

	local bar_size = ImVec2(width, height)
	local bar_max  = ImVec2(bar_pos.x + bar_size.x, bar_pos.y + bar_size.y)

	-- Background
	dl:AddRectFilled(bar_pos, bar_max, bgU32, rounding)

	local function DrawTicks()
		local insetX = 3.0
		local x1 = bar_pos.x + insetX
		local x2 = bar_pos.x + bar_size.x - insetX

		local steps = math.floor(1.0 / tickEvery + 0.5)
		for i = 0, steps do
			local t = i * tickEvery
			if t > 1.00001 then break end

			-- vertical fill is bottom->top; tick position is along height
			local y = bar_pos.y + (bar_size.y * (1.0 - t))

			dl:AddRectFilled(
				ImVec2(x1, y - tickH * 0.5),
				ImVec2(x2, y + tickH * 0.5),
				IM_COL32(255, 255, 255, tickAlpha),
				0.0
			)
		end
	end

	-- if showTicks and tickEvery > 0 then DrawTicks() end

	-- Fill bottom->top
	local filled_h = bar_size.y * progress
	if filled_h > 2.0 then
		local fill_min = ImVec2(bar_pos.x, bar_pos.y + (bar_size.y - filled_h)) -- top of fill
		local fill_max = ImVec2(bar_pos.x + bar_size.x, bar_pos.y + bar_size.y) -- bottom

		if gradOn then
			local topCol, bottomCol

			if gradMode == "dynamic" then
				-- top color tracks current progress (max-ish at current fill)
				topCol = ImAnim.GetBlendedColor(lowCol, highCol, progress, IamColorSpace.OKLAB)
			else
				topCol = highCol
			end
			bottomCol         = lowCol

			local colorTop    = ImGui.ColorConvertFloat4ToU32(topCol)
			local colorBottom = ImGui.ColorConvertFloat4ToU32(bottomCol)

			if gradDir == "lr" then
				dl:AddRectFilledMultiColor(fill_min, fill_max, colorBottom, colorTop, colorTop, colorBottom)
			else
				-- "tb": MAX on top, MIN on bottom
				dl:AddRectFilledMultiColor(fill_min, fill_max, colorTop, colorTop, colorBottom, colorBottom)
			end

			-- soft rounding hint (multicolor fill has no rounding)
			dl:AddRect(fill_min, fill_max, IM_COL32(255, 255, 255, 30), rounding, ImDrawFlags.RoundCornersBottom, 1.0)
		else
			local fill_col = ImAnim.GetBlendedColor(lowCol, highCol, progress, IamColorSpace.OKLAB)
			local fill_u32 = ImGui.ColorConvertFloat4ToU32(fill_col)

			-- bottom corners should be rounded (bar fills upward)
			dl:AddRectFilled(fill_min, fill_max, fill_u32, rounding, ImDrawFlags.RoundCornersBottom)
		end

		-- Glow edge (at the top of the fill)
		if glowOn then
			local edgeY = fill_min.y -- top of filled region
			local x1 = bar_pos.x
			local x2 = bar_pos.x + bar_size.x

			-- Max depth of glow into the fill (in pixels)
			local maxDepth = math.min(16.0, filled_h)
			local layers = 4
			local layerStep = maxDepth / layers

			for i = 0, layers - 1 do
				-- i=0 is brightest and thinnest at the edge
				local t = i / (layers - 1) -- 0..1
				local alpha = 0.35 * (1.0 - t) -- fade out as it goes down
				local a255 = math.floor(alpha * 255)

				local y1 = edgeY + (i * layerStep)
				local y2 = edgeY + ((i + 1) * layerStep)


				if y1 < fill_min.y then y1 = fill_min.y end
				if y2 > fill_max.y then y2 = fill_max.y end
				if y2 > bar_max.y then y2 = bar_max.y end

				if y2 > y1 then
					dl:AddRectFilled(
						ImVec2(x1, y1),
						ImVec2(x2, y2),
						IM_COL32(255, 255, 255, a255),
						4.0
					)
				end
			end
		end

		-- Shimmer
		if shimmerOn then
			local shimmerFollows = (opts.shimmerFollows ~= false) -- default true
			local shimmerSpeed   = opts.shimmerSpeed or 0.5
			local shimmerHeight  = opts.shimmerHeight or 30.0 -- vertical shimmer height
			local deadzone       = opts.shimmerDeadzone or 0.001
			local barState       = getBarState(id, now)
			local phase          = (((now - (barState.t0 or now)) * 0.001) * shimmerSpeed) % 1.0

			if shimmerFollows then
				local delta = progress - (barState.lastP or progress)
				local newDir = barState.dir or 1
				if delta > deadzone then newDir = 1 end
				if delta < -deadzone then newDir = -1 end
				if newDir ~= (barState.dir or 1) then
					barState.t0 = now - (phase / shimmerSpeed) * 1000.0
					barState.dir = newDir
				end
			else
				barState.dir = 1 -- always upward shimmer
			end

			phase = (((now - (barState.t0 or now)) * 0.001) * shimmerSpeed) % 1.0

			local pos01 = phase
			if shimmerFollows and (barState.dir or 1) < 0 then
				pos01 = 1.0 - phase
			end

			local shimmer_y = fill_max.y - (pos01 * filled_h)

			if shimmer_y >= fill_min.y then
				local shimmer_alpha = 0.15 * math.sin(((fill_max.y - shimmer_y) / filled_h) * math.pi)
				local a_sh = math.floor(shimmer_alpha * 255)

				dl:AddRectFilledMultiColor(
					ImVec2(bar_pos.x, shimmer_y - shimmerHeight),
					ImVec2(bar_pos.x + bar_size.x, shimmer_y),
					IM_COL32(255, 255, 255, 0),
					IM_COL32(255, 255, 255, 0),
					IM_COL32(255, 255, 255, a_sh),
					IM_COL32(255, 255, 255, a_sh)
				)
			end

			barState.lastP = progress
		end

		-- Overlay image mask (vertical)
		if opts.overlayOn and opts.overlay ~= nil then
			local pad           = opts.overlayPadding or 0.0
			local uv0           = opts.overlayUv0 or ImVec2(0, 0)
			local uv1           = opts.overlayUv1 or ImVec2(1, 1)
			local tint          = opts.overlayTint or IM_COL32(255, 255, 255, 255)

			local texID         = opts.overlay.GetTextureID and opts.overlay:GetTextureID() or opts.overlay
			local overlayStatic = (opts.overlayStatic == true)

			if overlayStatic then
				-- Full-size looking glass
				dl:AddImage(
					texID,
					ImVec2(bar_pos.x - pad, bar_pos.y - pad),
					ImVec2(bar_max.x + pad, bar_max.y + pad),
					uv0, uv1,
					tint
				)
			else
				-- Dynamic: clip overlay to the filled portion (bottom -> top), and clip UVs accordingly
				if filled_h > 2.0 then
					-- fill_min is the TOP of the filled region, fill_max is the bottom
					local oMin   = ImVec2(bar_pos.x - pad, fill_min.y - pad)
					local oMax   = ImVec2(bar_max.x + pad, bar_max.y + pad)

					-- Clip UVs so the bottom stays aligned and we only sample the filled fraction.
					-- Keep uv1.y as the bottom, move uv0.y downward as progress decreases.
					local vSpanY = (uv1.y - uv0.y)
					local v0y    = uv1.y - (vSpanY * progress)
					local uv0c   = ImVec2(uv0.x, v0y)

					dl:AddImage(texID, oMin, oMax, uv0c, uv1, tint)
				end
			end
		end
	end

	if showTicks and tickEvery > 0 then DrawTicks() end

	-- Text (centered)
	if showText then
		local pctText = string.format(textFmt, progress * 100.0)
		local txtSize = ImGui.CalcTextSizeVec(pctText)
		local txtPos = ImVec2(
			bar_pos.x + (bar_size.x - txtSize.x) * 0.5,
			bar_pos.y + (bar_size.y - txtSize.y) * 0.5
		)
		dl:AddText(txtPos, IM_COL32(255, 255, 255, 200), pctText)
	end

	-- Border
	if borderOn then
		local colU32
		if borderCol == nil then
			colU32 = IM_COL32(255, 255, 255, 120)
		elseif type(borderCol) == "number" then
			colU32 = borderCol
		else
			colU32 = ImGui.ColorConvertFloat4ToU32(borderCol)
		end
		dl:AddRect(bar_pos, bar_max, colU32, rounding, 0, borderTh)
	end

	-- Reserve space
	ImGui.Dummy(ImVec2(bar_size.x, bar_size.y + padEnd))
	return progress
end

---Draw a horizontal Progress bar using ImAnim efx
---@param label string Label ID for the bar
---@param percent float|integer Percentage (0-100 or 0.0-1.0) to fill the bar
---@param lowCol ImVec4|table|nil Color at 0% fill
---@param highCol ImVec4|table|nil Color at 100% fill
---@param opts table|nil Optional settings:
---@return integer
function StatusBar.DrawProgress(label, percent, lowCol, highCol, opts)
	opts = opts or {}
	if opts.vertical == true then
		return StatusBar.DrawProgressVert(label, percent, lowCol, highCol, opts)
	end
	if lowCol == nil then lowCol = ImVec4(ImGui.GetStyleColor(ImGuiCol.PlotHistogram)) end
	if highCol == nil then highCol = ImVec4(ImGui.GetStyleColor(ImGuiCol.PlotHistogram)) end

	local now       = mq.gettime() -- milliseconds since launch
	local dl        = ImGui.GetWindowDrawList()
	local borderOn  = (opts.border == true)
	local borderTh  = opts.borderThickness or 1.0
	local borderCol = opts.borderColor or ImVec4(0.8, 0.8, 0.8, 1.0)
	local height    = opts.height or 24.0
	local width     = opts.width or 0.0 -- if 0, will use all available horizontal space
	local padEnd    = opts.padEnd or 20.0
	local rounding  = opts.rounding or 6.0
	local showText  = (opts.showText == true)
	local textFmt   = opts.textFmt or "%.0f%%"
	local showTicks = (opts.showTicks == true)
	local tickEvery = opts.tickEvery or 0.05
	local tickAlpha = opts.tickAlpha or 80
	local shimmerOn = (opts.shimmer == true)
	local glowOn    = (opts.glow == true)
	local bgU32     = opts.bgU32 or IM_COL32(30, 32, 40, 255)
	local tweenSec  = opts.tweenSeconds or 0.35
	local gradOn    = (opts.fillGradient == true)
	local gradMode  = opts.fillGradientMode or "static" -- "static" or "dynamic"
	local gradDir   = opts.fillGradientDir or "lr"   -- "lr" or "tb"
	local target    = to01(percent)
	local id        = ImGui.GetID(label)

	local progress  = ImAnim.TweenFloat(
		id,
		ImHashStr(label),
		target,
		tweenSec,
		ImAnim.EasePreset(IamEaseType.OutExpo),
		IamPolicy.Crossfade,
		0 -- dt not required when using internal timing
	)

	progress        = clamp01(progress)
	-- layout
	local bar_pos   = ImGui.GetCursorScreenPosVec()
	local avail     = ImGui.GetContentRegionAvailVec()
	if width <= 3 then width = avail.x - padEnd end
	if width < 10 then width = 10 end
	local bar_size = ImVec2(width, height)
	local bar_max  = ImVec2(bar_pos.x + bar_size.x, bar_pos.y + bar_size.y)

	dl:AddRectFilled(bar_pos, bar_max, bgU32, rounding)

	---Draw tick marks on progress bars at desired intervals
	local function DrawTicks()
		local tickW = opts.tickThickness or 1.0
		local insetY = 3.0
		local y1 = bar_pos.y + insetY
		local y2 = bar_pos.y + bar_size.y - insetY

		local steps = math.floor(1.0 / tickEvery + 0.5)
		for i = 0, steps do
			local t = i * tickEvery
			if t > 1.00001 then break end

			local x = bar_pos.x + (bar_size.x * t)
			dl:AddRectFilled(
				ImVec2(x - tickW * 0.5, y1),
				ImVec2(x + tickW * 0.5, y2),
				IM_COL32(255, 255, 255, tickAlpha),
				0.0
			)
		end
	end

	--ticks on background
	-- if showTicks and tickEvery > 0 then DrawTicks() end

	-- fill
	local filled_w = bar_size.x * progress
	if filled_w > 2.0 then
		local fill_max = ImVec2(bar_pos.x + filled_w, bar_pos.y + bar_size.y)

		if gradOn then
			-- Gradient endpoints:
			-- static: low -> high across the fill
			-- dynamic: right edge tracks current progress color
			local colorLeft, colorRight
			if gradMode == "dynamic" then
				colorLeft = lowCol
				colorRight = ImAnim.GetBlendedColor(lowCol, highCol, progress, IamColorSpace.OKLAB)
			else
				colorLeft = lowCol
				colorRight = highCol
			end

			local colorLow = ImGui.ColorConvertFloat4ToU32(colorLeft)
			local colorHigh = ImGui.ColorConvertFloat4ToU32(colorRight)

			if gradDir == "tb" then
				dl:AddRectFilledMultiColor(
					bar_pos, fill_max,
					colorHigh, colorHigh,
					colorLow, colorLow
				)
			else
				-- left -> right (left=cL, right=cR)
				dl:AddRectFilledMultiColor(
					bar_pos, fill_max,
					colorLow, colorHigh, colorHigh, colorLow
				)
			end

			-- MultiColor fill doesn't round corners;
			dl:AddRect(bar_pos, fill_max, IM_COL32(255, 255, 255, 30), rounding, ImDrawFlags.RoundCornersLeft, 1.0)
		else
			-- Original single-color fill
			local fill_col = ImAnim.GetBlendedColor(lowCol, highCol, progress, IamColorSpace.OKLAB)
			local fill_u32 = ImGui.ColorConvertFloat4ToU32(fill_col)
			dl:AddRectFilled(bar_pos, fill_max, fill_u32, rounding, ImDrawFlags.RoundCornersLeft)
		end

		-- glow edge
		if glowOn then
			local glow_x = bar_pos.x + filled_w - 4.0
			for i = 0, 3 do
				local alpha = 0.30 * (1.0 - i * 0.25)
				local offset = i * 4.0
				local a255 = math.floor(alpha * 255 * (1.0 - i * 0.2))
				dl:AddRectFilled(
					ImVec2(glow_x - offset, bar_pos.y),
					ImVec2(glow_x + 4.0, bar_pos.y + bar_size.y),
					IM_COL32(255, 255, 255, a255),
					4.0
				)
			end
		end

		-- shimmer
		if shimmerOn then
			local shimmerFollows = (opts.shimmerFollows ~= false) -- default true
			local shimmerSpeed = opts.shimmerSpeed or 0.5 -- cycles per second
			local shimmerWidth = opts.shimmerWidth or 60.0
			local deadzone = opts.shimmerDeadzone or 0.001
			local barState = getBarState(id, now)

			-- Current phase under existing anchor (0..1)
			local phase = (((now - (barState.t0 or now)) * 0.001) * shimmerSpeed) % 1.0

			if shimmerFollows then
				-- Determine direction from progress movement
				local delta = progress - (barState.lastP or progress)

				local newDir = barState.dir or 1
				if delta > deadzone then newDir = 1 end
				if delta < -deadzone then newDir = -1 end

				-- If direction changed, re-anchor time so phase continues smoothly
				if newDir ~= (barState.dir or 1) then
					barState.t0 = now - (phase / shimmerSpeed) * 1000.0
					barState.dir = newDir
				end
			else
				-- Force always left-to-right
				barState.dir = 1
			end

			-- Recompute phase after possible re-anchor
			phase = (((now - (barState.t0 or now)) * 0.001) * shimmerSpeed) % 1.0

			-- Convert phase to position; reverse only if following and decreasing
			local pos01 = phase
			if shimmerFollows and (barState.dir or 1) < 0 then
				pos01 = 1.0 - phase
			end

			local shimmer_pos = pos01 * filled_w
			if shimmer_pos < filled_w then
				local shimmer_alpha = 0.15 * math.sin((shimmer_pos / filled_w) * math.pi)
				local a_sh = math.floor(shimmer_alpha * 255)

				dl:AddRectFilledMultiColor(
					ImVec2(bar_pos.x + shimmer_pos, bar_pos.y),
					ImVec2(bar_pos.x + shimmer_pos + shimmerWidth, bar_pos.y + bar_size.y),
					IM_COL32(255, 255, 255, 0),
					IM_COL32(255, 255, 255, a_sh),
					IM_COL32(255, 255, 255, a_sh),
					IM_COL32(255, 255, 255, 0)
				)
			end

			-- update last progress at end of shimmer evaluation
			barState.lastP = progress
		end
	end

	--ticks on top of the fill bar
	if showTicks and tickEvery > 0 then DrawTicks() end

	-- Overlay image mask
	-- Overlay image mask
	if opts.overlayOn and opts.overlay ~= nil then
		local pad   = opts.overlayPadding or 0.0
		local uv0   = opts.overlayUv0 or ImVec2(0, 0)
		local uv1   = opts.overlayUv1 or ImVec2(1, 1)
		local tint  = opts.overlayTint or IM_COL32(255, 255, 255, 255)

		local texID = opts.overlay.GetTextureID and opts.overlay:GetTextureID() or opts.overlay
		if (opts.overlayStatic == true) then
			-- "Looking glass": always full-size, full UVs
			dl:AddImage(
				texID,
				ImVec2(bar_pos.x - pad, bar_pos.y - pad),
				ImVec2(bar_max.x + pad, bar_max.y + pad),
				uv0, uv1,
				tint
			)
		else
			-- Dynamic: clip overlay to the filled portion (and clip UVs to match)
			if filled_w > 2.0 then
				local oMin   = ImVec2(bar_pos.x - pad, bar_pos.y - pad)
				local oMax   = ImVec2(bar_pos.x + filled_w + pad, bar_max.y + pad)

				-- Shrink UV span to match the filled fraction, anchored on the left
				local uSpanX = (uv1.x - uv0.x)
				local u1x    = uv0.x + (uSpanX * progress)
				local uv1c   = ImVec2(u1x, uv1.y)

				dl:AddImage(texID, oMin, oMax, uv0, uv1c, tint)
			end
		end
	end

	-- text
	if showText then
		local pctText = string.format(textFmt, progress * 100.0)
		local txtSize = ImGui.CalcTextSizeVec(pctText)
		local txtPos = ImVec2(
			bar_pos.x + (bar_size.x - txtSize.x) * 0.5,
			bar_pos.y + (bar_size.y - txtSize.y) * 0.5
		)
		dl:AddText(txtPos, IM_COL32(255, 255, 255, 200), pctText)
	end

	-- Border (draw last so it frames everything)
	if borderOn then
		local colU32
		if borderCol == nil then
			colU32 = IM_COL32(255, 255, 255, 120)
		elseif type(borderCol) == "number" then
			colU32 = borderCol
		else
			colU32 = ImGui.ColorConvertFloat4ToU32(borderCol)
		end
		dl:AddRect(bar_pos, bar_max, colU32, rounding, 0, borderTh)
	end

	ImGui.Dummy(ImVec2(bar_size.x, bar_size.y))
	return progress
end

return StatusBar
