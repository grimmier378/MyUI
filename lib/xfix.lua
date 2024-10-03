-- xFix Lua

-- Name: XFix
--
-- Author: Grimmier
-- Purpose: fix stuck xtarget slots that will break automation. Sometimes these are empty slots other times they are corpses.
-- Scans xtarg list every second. if we are not in combat and there is a stuck slot we pop it and set it back to autohater.

local mq = require('mq')
local PAUSED = false
local DEBUG = false
local RUNNING = true
local version = "1.8"
local arg = { ..., }
if arg[1] and arg[1] == 'debug' then DEBUG = true end

local function debug(string)
	if (DEBUG) then print(string.format('\aoxFix::\aoDEBUG::\at %s', tostring(string))) end
end

local function help()
	print('\ayxFix::\a-o xFix Command List:')
	print('\ayxFix::\ag /xfix pause \at Toggles Pause on and off')
	print('\ayxfix::\ag /xfix debug \at Turn on and off Debug Spam')
	print('\ayxFix::\ag /xfix stop \at  Ends the script')
	print('\ayxFix::\ag /xfix help \at  Lists this command list')
	if DEBUG then print('\ayxFix::\ag Debug Spam Enabled!') end
end

local function bind(...)
	local args = { ..., }
	local key = args[1]
	local value = args[2]
	if key == 'pause' then
		if PAUSED then
			PAUSED = false
			print('\ayxFix::\ag xFix Resuming...')
		else
			PAUSED = true
			print('\ayxFix::\ao xFix Paused!')
		end
	elseif key == 'debug' then
		if DEBUG then
			DEBUG = false
			print('\ayxFix::\ao Debug Spam Disabled!')
		else
			DEBUG = true
			print('\ayxFix::\ag Debug Spam Enabled!')
		end
	elseif key == 'help' or not key then
		help()
	elseif key == 'stop' then
		RUNNING = false
	end
end

local function ScanXtar()
	if mq.TLO.Me.XTarget() > 0 then
		for i = 1, mq.TLO.Me.XTargetSlots() do
			local xTarg = mq.TLO.Me.XTarget(i)
			mq.delay(100) -- give time to populate information
			if not (xTarg.ID() > 0 and xTarg.Type() ~= 'Corpse' and xTarg.Type() ~= 'Chest') then
				local xCount = mq.TLO.Me.XTarget() or 0
				local xName, xType = xTarg.Name(), xTarg.Type()
				if (xCount > 0 and xTarg.ID() == 0) or (xType == 'Corpse') or (xType == 'Chest') then
					if ((xTarg.Name() ~= 'NULL' and xTarg.ID() == 0) or (xType == 'Corpse') or (xType == 'Chest') or (xTarg.Master.Type() == 'PC')) then
						mq.cmdf("/squelch /xtarg set %s ET", i)
						mq.delay(100)
						mq.cmdf("/squelch /xtarg set %s AH", i)
						local debugString = string.format('\ayxFix\aw:: Cleaning Xtarget Slot::\at %s\aw XTarget Count::\ao %s\aw Name::\ag %s\aw Type:: \at%s', i, xCount, xName,
						xType)
						if DEBUG then debug(debugString) end
					end
				end
			end
		end
	end
end

local function init()
	printf("\ayxFix::\ag LOADING \ayxFix::Version::\ag%s", version)
	mq.bind('/xfix', bind)
	help()
end

local function loop()
	while RUNNING do
		mq.delay('5s')
		if not PAUSED then
			ScanXtar()
		end
	end
end

init()
loop()
