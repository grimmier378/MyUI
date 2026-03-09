-- damageNumber.lua
-- Floating damage numbers (reusable, no windows/buttons)
-- Uses mq.gettime() dt + ImAnim TweenFloat
-- Uses drawlist:AddText(font, size, ...) to avoid SetWindowFontScale side effects

local mq               = require("mq")
local imgui            = require("ImGui")
local iam              = require("ImAnim")

local DamageNumber     = {}

DamageNumber.Defaults  = {
	-- Options: Can pass as overrides when calling TakeDamage or GenerateText, or modify these defaults directly.
	life_time      = 2.0,                  -- how long the text lives (seconds)
	pop_up         = 0.2,                  -- how long the pop up animation lasts (seconds)
	pop_down       = 0.3,                  -- how long the pop down animation lasts (seconds)
	fade_delay     = 0.8,                  -- how long before fading starts (seconds)
	fade_time      = 0.7,                  -- how long fading lasts (seconds)
	float_px       = 100.0,                -- how many pixels to float over the lifetime (higher = more float)
	y_offset_px    = 0.0,                  -- Y offset in pixels from the anchor point (start of the animation)
	scale_mult     = 1.5,                  -- Text Scale multiplier (1.0 = default font size, 2.0 = double size, etc)
	color          = { 255, 100, 100, 255, }, -- RGBA
	wobble_px      = 0.0,                  -- horizontal randomization to reduce overlap (set to 0 to disable)
	base_font_size = nil,                  -- if nil -> uses imgui.GetFontSize(), if set -> treated as "base" font size before pop/scale_mult
	drop_shadow    = nil,                  -- {0,0,0,255} to enable
	drop_offset    = 1,                    -- pixel offset (x and y)
}

DamageNumber._items    = {}
DamageNumber._lastMs   = nil
DamageNumber._frameNow = nil
DamageNumber._frameDt  = nil

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function now_ms()
	return mq.gettime()
end

local function col32(c, alphaMul)
	local r, g, b, a = c[1], c[2], c[3], c[4]
	if alphaMul then a = math.floor(a * alphaMul) end
	return IM_COL32(r, g, b, a)
end

local function TweenFloatSafe(id, ch, target, dur, ez, policy, dt, init_value)
	if init_value ~= nil then
		return iam.TweenFloat(id, ch, target, dur, ez, policy, dt, init_value)
	end
	return iam.TweenFloat(id, ch, target, dur, ez, policy, dt)
end

local function tick_dt()
	local now = now_ms()
	if DamageNumber._frameNow == now and DamageNumber._frameDt ~= nil then
		return now, DamageNumber._frameDt
	end
	DamageNumber._frameNow = now

	local dt = 1.0 / 60.0
	if DamageNumber._lastMs then
		dt = (now - DamageNumber._lastMs) / 1000.0
		if dt <= 0 then dt = 1.0 / 60.0 end
		if dt > 0.1 then dt = 0.1 end
	end
	DamageNumber._lastMs = now
	DamageNumber._frameDt = dt
	return now, dt
end


-- Creates Floating Text stored in a table until drawn in a drawlist with DrawAt functions below.
function DamageNumber.GenerateText(anchor_key, text, opts)
	if opts == nil or type(opts) ~= "table" then opts = {} end
	local cfg = {}
	for k, v in pairs(DamageNumber.Defaults) do cfg[k] = v end
	for k, v in pairs(opts) do cfg[k] = v end

	local key = anchor_key or "default"
	local wobble = 0.0
	if cfg.wobble_px and cfg.wobble_px > 0 then
		-- random between -wobble_px and +wobble_px
		wobble = math.random(-cfg.wobble_px, cfg.wobble_px)
	end

	table.insert(DamageNumber._items, {
		anchor = key,
		text   = tostring(text),
		cfg    = cfg,
		start  = now_ms(),
		seeded = false,
		lane_x = wobble,
	})
end

-- displays negative values for taking damage
function DamageNumber.TakeDamage(anchor_key, dmg, opts)
	return DamageNumber.GenerateText(anchor_key, string.format("-%d", tonumber(dmg) or 0), opts)
end

local function draw_item(item, basePos, dl, idBase, now, dt)
	local cfg = item.cfg
	local elapsed = (now - item.start) / 1000.0
	if elapsed >= cfg.life_time then
		return false
	end

	-- Must be called within an active ImGui window/frame (CurrentWindow needed for GetID)
	local root       = imgui.GetID(idBase .. "::" .. tostring(item.start) .. "::" .. item.text)
	local ch_scale   = imgui.GetID("scale")
	local ch_floaty  = imgui.GetID("floaty")
	local ch_alpha   = imgui.GetID("alpha")

	local init_scale = (not item.seeded) and 1.0 or nil
	local init_y     = (not item.seeded) and 0.0 or nil

	-- pop scale (keep Cut so retargeting feels snappy)
	local pop_scale
	if elapsed < cfg.pop_up then
		pop_scale = TweenFloatSafe(
			root, ch_scale,
			1.4, cfg.pop_up,
			iam.EasePreset(IamEaseType.OutBack),
			IamPolicy.Cut,
			dt,
			init_scale
		)
	else
		pop_scale = TweenFloatSafe(
			root, ch_scale,
			1.0, cfg.pop_down,
			iam.EasePreset(IamEaseType.OutQuad),
			IamPolicy.Cut,
			dt
		)
	end

	-- float up (Crossfade so it doesn't snap to the end)
	local float_y = TweenFloatSafe(
		root, ch_floaty,
		cfg.float_px, cfg.life_time,
		iam.EasePreset(IamEaseType.OutQuad),
		IamPolicy.Crossfade,
		dt,
		init_y
	)

	-- alpha (Crossfade for fade)
	local alpha = 1.0
	if elapsed < cfg.fade_delay then
		alpha = 1.0
	else
		alpha = TweenFloatSafe(
			root, ch_alpha,
			0.0, cfg.fade_time,
			iam.EasePreset(IamEaseType.OutQuad),
			IamPolicy.Crossfade,
			dt
		)
	end
	alpha = clamp(alpha, 0.0, 1.0)

	-- Font + explicit size
	local font = imgui.GetFont()
	local base = cfg.base_font_size or imgui.GetFontSize()
	if base <= 0 then base = 13.0 end

	local size = base * pop_scale * (cfg.scale_mult or 1.0)

	-- Centering: CalcTextSizeVec() returns at current font size.
	-- We'll scale it proportionally to our chosen size.
	local raw = imgui.CalcTextSizeVec(item.text)
	local scale = size / base
	local w = raw.x * scale
	local h = raw.y * scale

	local x = basePos.x - (w * 0.5) + (item.lane_x or 0.0)
	local y = basePos.y - cfg.y_offset_px - float_y

	-- Optional Drop Shadow
	if cfg.drop_shadow ~= nil then
		local shadowColor = col32(cfg.drop_shadow, alpha)
		local offset = cfg.drop_offset or 1

		dl:AddText(
			font,
			size,
			ImVec2(x + offset, y + offset),
			shadowColor,
			item.text
		)
	end

	-- Main text
	dl:AddText(
		font,
		size,
		ImVec2(x, y),
		col32(cfg.color, alpha),
		item.text
	)

	item.seeded = true
	return true
end

-- Draw all active items for an anchor at a given position, using a given draw list.
function DamageNumber.DrawAt(basePos, drawlist, idBase, anchor_key)
	local now, dt = tick_dt()

	local keep = {}
	for _, item in ipairs(DamageNumber._items) do
		if anchor_key == nil or item.anchor == anchor_key then
			local alive = draw_item(item, basePos, drawlist, idBase, now, dt)
			if alive then table.insert(keep, item) end
		else
			table.insert(keep, item)
		end
	end
	DamageNumber._items = keep
end

-- draw at mouse (foreground)
function DamageNumber.DrawAtMouse(offset, idBase, anchor_key)
	offset = offset or ImVec2(0, 0)
	local pos = imgui.GetMousePosVec()
	pos = ImVec2(pos.x + offset.x, pos.y + offset.y)
	return DamageNumber.DrawAt(pos, imgui.GetForegroundDrawList(), idBase, anchor_key)
end

-- draw in main viewport foreground
function DamageNumber.DrawAtScreen(screenPos, idBase, anchor_key)
	return DamageNumber.DrawAt(screenPos, imgui.GetForegroundDrawList(), idBase, anchor_key)
end

-- draw in main viewport background (behind windows)
function DamageNumber.DrawAtScreenBackground(screenPos, idBase, anchor_key)
	return DamageNumber.DrawAt(screenPos, imgui.GetBackgroundDrawList(), idBase, anchor_key)
end

return DamageNumber
