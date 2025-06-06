local mq = require('mq')
local ImGui = require 'ImGui'
local Module = {}
Module.Name = 'SAST'
Module.IsRunning = false

---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false

if not loadedExeternally then
	Module.Utils = require('lib.common')
	Module.Icons = require('mq.ICONS')
	Module.CharLoaded = mq.TLO.Me.DisplayName()
	Module.Colors = require('lib.colors')
	Module.Server = mq.TLO.MacroQuest.Server()
else
	Module.Utils = MyUI_Utils
	Module.Icons = MyUI_Icons
	Module.CharLoaded = MyUI_CharLoaded
	Module.Colors = MyUI_Colors
	Module.Server = MyUI_Server
end

-- Variables
local AdvWIN = mq.TLO.Window('AdventureRequestWnd')
local ExpWIN = mq.TLO.Window('DynamicZoneWnd')
local adv, exp = false, false
local guiOpen = false
local eqWinAdvOpen, eqWinExpOpen = false, false
local groupCmd = '/dgae '
local mode = 'DanNet'
local doDelay = false
local delayTime = 1
local currZone, lastZone
local winFlags = bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoFocusOnAppearing)
local locked, showAdv, forcedOpen, refreshStats = false, false, false, false
--Helpers
local function checkAdv(draw)
	-- check for active adventure timers.Either time to enter dungeon or time to complete.
	if AdvWIN.Child('AdvRqst_EnterTimeLeftLabel').Text() ~= '' then
		adv = true
		if draw then
			ImGui.Text("Time to Enter Left: ")
			ImGui.SameLine()
			ImGui.TextColored(ImVec4(0.70, 0.754, 0.000, 1.000), AdvWIN.Child('AdvRqst_EnterTimeLeftLabel').Text())
		end
	elseif AdvWIN.Child('AdvRqst_CompleteTimeLeftLabel').Text() ~= '' then
		adv = true
		if draw then
			ImGui.Text("Time to Complete Left: ")
			ImGui.SameLine()
			ImGui.TextColored(ImVec4(0.70, 0.754, 0.000, 1.000), AdvWIN.Child('AdvRqst_CompleteTimeLeftLabel').Text())
		end
	else
		adv = false
		-- no active timers, so we are not in an adventure.
		if draw then
			ImGui.Text('No Adventure Started')
		end
	end
	return adv
end

local function checkExp()
	local checkText = ExpWIN.Child('DZ_CurrentDZValue').Text() or ''
	if checkText ~= '' then
		exp = true
		return checkText
	else
		exp = false
		return 'No Expedition Started'
	end
end
local desc = ''
--GUI
function Module.RenderGUI()
	if currZone ~= lastZone then return end
	if guiOpen or forcedOpen then
		if locked then
			winFlags = bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoMove)
		else
			winFlags = bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.AlwaysAutoResize)
		end
		local open, show = ImGui.Begin("SAST##" .. mq.TLO.Me.DisplayName(), true, winFlags)
		if not open then show = false end
		if show then
			local needRefresh = false
			local iconLocked = locked and Module.Icons.FA_LOCK or Module.Icons.FA_UNLOCK
			if adv or forcedOpen then
				ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(1.00, 0.454, 0.000, 1.000))
				ImGui.PushStyleColor(ImGuiCol.Separator, ImVec4(1.00, 0.454, 0.000, 1.000))
				ImGui.Text("Adventure Status: \t")
				ImGui.SameLine()
				ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(0.000, 0.833, 0.751, 1.000))
				ImGui.Text(desc)
				ImGui.PopStyleColor(1)
				ImGui.SameLine(200)
				ImGui.Text(Module.Icons.MD_MORE_HORIZ)
				if ImGui.IsItemHovered() then
					ImGui.SetTooltip('Click to Show More Information')
					if ImGui.IsMouseReleased(0) then
						if forcedOpen then forcedOpen = false end
						showAdv = not showAdv
					elseif ImGui.IsMouseReleased(1) then
						if mq.TLO.Window("AdventureLeaderboardWnd").Open() then
							mq.TLO.Window("AdventureLeaderboardWnd").DoClose()
						else
							mq.TLO.Window("AdventureStatsWnd/AdvStats_LeaderboardButton").LeftMouseUp()
						end
					end
				end
				ImGui.SameLine(220)
				local iconHa = eqWinAdvOpen and Module.Icons.MD_HELP or Module.Icons.MD_HELP_OUTLINE
				ImGui.Text(iconHa)
				if ImGui.IsItemHovered() then
					if ImGui.IsMouseReleased(0) then
						eqWinAdvOpen = AdvWIN.Open()
						if not eqWinAdvOpen then
							AdvWIN.DoOpen()
							eqWinAdvOpen = true
						else
							AdvWIN.DoClose()
							eqWinAdvOpen = false
						end
					end
					ImGui.BeginTooltip()
					ImGui.PushTextWrapPos(250)
					ImGui.Text("Click to Open InGame\nQuest Information:")
					ImGui.Separator()
					ImGui.Text(AdvWIN.Child('AdvRqst_NPCText').Text() or 'No Adventure')
					ImGui.PopTextWrapPos()
					ImGui.EndTooltip()
				end
				ImGui.SameLine()
				ImGui.Text(iconLocked)
				if ImGui.IsItemHovered() then
					if ImGui.IsMouseReleased(0) then
						locked = not locked
					end
				end
				ImGui.Separator()
				checkAdv(true)
				ImGui.PopStyleColor(2)
			end
			if exp and adv then ImGui.Separator() end
			if exp then
				ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(0.000, 0.833, 0.751, 1.000))
				ImGui.PushStyleColor(ImGuiCol.Separator, ImVec4(0.00, 0.833, 0.751, 1.000))
				ImGui.Text("Expedition Status:")
				ImGui.SameLine(220)
				local iconH = eqWinExpOpen and Module.Icons.MD_HELP or Module.Icons.MD_HELP_OUTLINE
				ImGui.Text(iconH)
				if ImGui.IsItemHovered() then
					if ImGui.IsMouseReleased(0) then
						eqWinExpOpen = ExpWIN.Open()
						if not eqWinExpOpen then
							ExpWIN.DoOpen()
							eqWinExpOpen = true
						else
							ExpWIN.DoClose()
							eqWinExpOpen = false
						end
					end
					ImGui.BeginTooltip()
					ImGui.PushTextWrapPos(250)
					ImGui.Text("Click to Open InGame\nQuest Information:")
					ImGui.Separator()
					ImGui.Text(desc)
					ImGui.PopTextWrapPos()
					ImGui.EndTooltip()
				end
				if not adv then
					ImGui.SameLine()
					ImGui.Text(iconLocked)
					if ImGui.IsItemHovered() then
						if ImGui.IsMouseReleased(0) then
							locked = not locked
						end
					end
				end
				ImGui.Separator()
				ImGui.Text(checkExp())
				ImGui.PopStyleColor(2)
			end
			if showAdv then
				ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(1.00, 0.454, 0.000, 1.000))
				ImGui.PushStyleColor(ImGuiCol.Separator, ImVec4(1.00, 0.454, 0.000, 1.000))
				ImGui.SeparatorText('Adventure Stats')
				local ptsAvail = mq.TLO.Window("AdventureStatsWnd/AdvStats_AvailableValue").Text() or 'Refresh Me'

				if ImGui.BeginTable('Adv Info##SAST_Info', 4, bit32.bor(ImGuiTableFlags.Resizable)) then
					ImGui.TableSetupColumn('Theme', ImGuiTableColumnFlags.WidthFixed, 90)
					ImGui.TableSetupColumn('Success', ImGuiTableColumnFlags.WidthFixed, 60)
					ImGui.TableSetupColumn('Fail', ImGuiTableColumnFlags.WidthFixed, 35)
					ImGui.TableSetupColumn('Points', ImGuiTableColumnFlags.WidthFixed, 45)
					ImGui.TableHeadersRow()

					for i = 1, 5 do
						local name = mq.TLO.Window("AdventureStatsWnd/AdvStats_ThemeList").List(i)() or "Refresh Me"
						local sucComp = mq.TLO.Window("AdventureStatsWnd/AdvStats_ThemeList").List(i, 3)() or 'Refresh Me'
						local failComp = mq.TLO.Window("AdventureStatsWnd/AdvStats_ThemeList").List(i, 4)() or 'Refresh Me'
						local points = mq.TLO.Window("AdventureStatsWnd/AdvStats_ThemeList").List(i, 7)() or 'Refresh Me'
						ImGui.TableNextColumn()
						if name == 'Refresh Me' then
							needRefresh = true
							if ImGui.Button('Refresh') then
								mq.TLO.Window('AdventureRequestWnd/AdvRqst_ViewStatsButton').LeftMouseUp()
								refreshStats = true
							end
							break
						end
						ImGui.Text(name)
						ImGui.TableNextColumn()
						ImGui.TextColored(ImVec4(0.415, 0.937, 0.340, 1.000), sucComp)
						ImGui.TableNextColumn()
						ImGui.Text(failComp)
						ImGui.TableNextColumn()
						ImGui.TextColored(ImVec4(0.7, 0.75, 0, 1), points)
					end
					-- if not needRefresh then
					-- 	local totalSuc = mq.TLO.Window("AdventureStatsWnd/AdvStats_ThemeList").List(7, 3)() or 'Refresh Me'
					-- 	local totalFail = mq.TLO.Window("AdventureStatsWnd/AdvStats_ThemeList").List(7, 4)() or 'Refresh Me'
					-- 	local totalPoints = mq.TLO.Window("AdventureStatsWnd/AdvStats_ThemeList").List(7, 7)() or 'Refresh Me'
					-- 	ImGui.TableNextColumn()
					-- 	ImGui.Separator()
					-- 	ImGui.TableNextColumn()
					-- 	ImGui.Separator()
					-- 	ImGui.TableNextColumn()
					-- 	ImGui.Separator()
					-- 	ImGui.TableNextColumn()
					-- 	ImGui.Separator()
					-- 	ImGui.TableNextColumn()
					-- 	ImGui.Text("Totals:")
					-- 	ImGui.TableNextColumn()
					-- 	ImGui.Text(totalSuc)
					-- 	ImGui.TableNextColumn()
					-- 	ImGui.Text(totalFail)
					-- 	ImGui.TableNextColumn()
					-- 	ImGui.Text(totalPoints)
					-- end
					ImGui.EndTable()
				end
				ImGui.SetCursorPosX((ImGui.GetWindowWidth() - ImGui.CalcTextSize('Points Available: ' .. ptsAvail) - 10) * 0.5)
				ImGui.Text('Points Available: ')
				ImGui.SameLine()
				ImGui.TextColored(Module.Colors.color('teal'), ptsAvail)
				ImGui.PopStyleColor(2)
				ImGui.SetCursorPosX((ImGui.GetWindowWidth() - ImGui.CalcTextSize(Module.Icons.FA_BAR_CHART) + 5) * 0.5)

				-- ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(0.000, 0.833, 0.751, 1.000)) -- teal
				ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(1.000, 1.0, 0.0, 1.000)) -- yellow

				-- ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(1.00, 0.454, 0.000, 1.000)) -- orange
				ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
				ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0, 0, 0, 0))
				ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImVec4(0, 0, 0, 0))
				if ImGui.SmallButton(Module.Icons.FA_BAR_CHART) then
					if mq.TLO.Window("AdventureLeaderboardWnd").Open() then
						mq.TLO.Window("AdventureLeaderboardWnd").DoClose()
					else
						mq.TLO.Window("AdventureStatsWnd/AdvStats_LeaderboardButton").LeftMouseUp()
					end
				end
				ImGui.PopStyleColor(4)

				if ImGui.IsItemHovered() then
					ImGui.SetTooltip('Click to Toggle Leaderboard')
				end
			end
		end

		ImGui.End()
	end
end

local function doBind(...)
	local args = { ..., }
	if args[1] == 'stats' then
		forcedOpen = not forcedOpen
		-- Module.Utils.PrintOutput('MyUI',nil,'Opening Stats: ',forcedOpen)
		if forcedOpen then showAdv = true end
	elseif args[1] == 'exped' then
		if not eqWinExpOpen then
			ExpWIN.DoOpen()
			eqWinExpOpen = true
		else
			ExpWIN.DoClose()
			eqWinExpOpen = false
		end
	elseif args[1] == 'adv' then
		if not eqWinAdvOpen then
			AdvWIN.DoOpen()
			eqWinAdvOpen = true
		else
			AdvWIN.DoClose()
			eqWinAdvOpen = false
		end
	elseif args[1] == 'exit' or args[1] == 'quit' then
		Module.IsRunning = false
		Module.Utils.PrintOutput('MyUI', nil, '\aySimple Adventure Status Tracking\ao Exiting...')
	end
	if #args == 2 then
		if args[1] == 'delay' then
			if tonumber(args[2]) then
				doDelay = true
				delayTime = tonumber(args[2])
				delayTime = delayTime
			else
				Module.Utils.PrintOutput('MyUI', nil, 'Invalid Delay Time')
			end
		end
	end
end

local arguments = { ..., }
local function processArgs(arg)
	if #arg == 0 then
		doDelay = true
		mode = 'Solo'
		delayTime = delayTime
	else
		if arg[1] ~= nil then
			if arg[1] and arg[1] == 'solo' then mode = 'Solo' end
			if arg[1] and arg[1] == 'dannet' then mode = 'DanNet' end
			if arg[1] and arg[1] == 'eqbc' then mode = 'EQBC' end
		end
		if #arg == 3 then
			if arg[2] == 'delay' then
				if tonumber(arg[3]) then
					doDelay = true
					delayTime = tonumber(arg[3])
					delayTime = delayTime
				else
					Module.Utils.PrintOutput('MyUI', nil, 'Invalid Delay Time')
				end
			else
				Module.Utils.PrintOutput('MyUI', nil, 'Invalid Command')
			end
		end
	end
	Module.Utils.PrintOutput('MyUI', nil, 'Simple Adventure Status Tracking')
	Module.Utils.PrintOutput('MyUI', nil, 'Usage: /lua run sast [mode]')
	Module.Utils.PrintOutput('MyUI', nil, 'Usage: /lua run sast [mode] delay [time] to add a delay to closing the window.')
	Module.Utils.PrintOutput('MyUI', nil, 'Modes: solo, dannet, eqbc')
end

function Module.Unload()
	mq.unbind("/sast")
end

local function startup()
	processArgs(arguments)
	--check for MQ2EQBC plugin
	if mode == 'EQBC' then
		if not mq.TLO.Plugin('mq2eqbc').IsLoaded() then
			Module.Utils.PrintOutput('MyUI', nil, 'EQBC Not Loaded... Loading EQBC...')
			mq.cmd('/plugin eqbc')
		end
		groupCmd = '/bcaa /'
	elseif mode == 'DanNet' then
		if not mq.TLO.Plugin('mq2dannet').IsLoaded() then
			Module.Utils.PrintOutput('MyUI', nil, 'DanNet Not Loaded... Loading DanNet...')
			mq.cmd('/plugin dannet')
		end
		groupCmd = '/dgae '
	end
	mq.bind("/sast", doBind)
	local dTime = delayTime ~= nil and delayTime or 'None'
	Module.Utils.PrintOutput('MyUI', nil, 'Starting SAST \aoMode: \at%s \aodoDelay: \at%s \aoDelayTime: \at%ss', mode, doDelay, dTime)
	Module.Utils.PrintOutput('MyUI', nil, '\agSimple Adventure Status Tracking\ax\ay Loaded...\ax')
	Module.Utils.PrintOutput('MyUI', nil, 'Use: \ay/sast stats\ax to toggle Adventure Stats')
	Module.Utils.PrintOutput('MyUI', nil, 'Use: \ay/sast adv\ax to toggle Adventure Window')
	Module.Utils.PrintOutput('MyUI', nil, 'Use: \ay/sast exped\ax to toggle Expedition Window')
	currZone = mq.TLO.Zone.ID()
	lastZone = currZone
	Module.IsRunning = true
	if not loadedExeternally then
		mq.imgui.init('Adventure Status', Module.RenderGUI)
		Module.LocalLoop()
	end
end

local function CloseWindow(win)
	if win == 'adv' then
		AdvWIN.DoClose()
	elseif win == 'exp' then
		ExpWIN.DoClose()
	end
	local cmdWinName = win == AdvWIN and "'AdventureRequestWnd'" or 'DynamicZoneWnd'
	if mode ~= 'Solo' then
		mq.cmdf('/noparse %s/lua parse mq.TLO.Window("%s").DoClose()', groupCmd, cmdWinName)
	end
end

local clockTimer = mq.gettime()
local refreshTimer = 0
local delTimerAdv = os.time()
local delTimerExp = os.time()
function Module.MainLoop()
	if mq.TLO.EverQuest.GameState() ~= "INGAME" then
		Module.IsRunning = false
		return
	end
	if loadedExeternally then
		---@diagnostic disable-next-line: undefined-global
		if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
	end
	desc = AdvWIN.Child('AdvRqst_ProgressTextLabel').Text() or 'None'
	if refreshStats and refreshTimer == 0 then
		refreshTimer = mq.gettime()
		-- mq.delay(3000, function() return (mq.TLO.Window("AdventureStatsWnd/AdvStats_ThemeList").List(1)() or 0) ~= 0 end)
	end
	if refreshStats and mq.gettime() - refreshTimer >= 200 and ((mq.TLO.Window("AdventureStatsWnd/AdvStats_ThemeList").List(1)() or 0) ~= 0) then
		mq.TLO.Window('AdventureStatsWnd/AdvStats_DoneButton').LeftMouseUp()
		-- mq.TLO.Window('AdventureStatsWnd').DoClose()
		refreshStats = false
		refreshTimer = 0
	end
	currZone = mq.TLO.Zone.ID()
	if mq.TLO.Window('CharacterListWnd').Open() then return false end
	if currZone ~= lastZone then
		lastZone = currZone
		clockTimer = mq.gettime()
	end
	local curTime = os.time()
	if mq.gettime() - clockTimer > 1000 then
		local advActive = checkAdv()
		local expActive = checkExp() ~= 'No Expedition Started'
		if advActive or expActive then
			guiOpen = true
			-- if ingame window is open and we didn't set the flag close it on all characters. we most likely zoned or just accepted the quest.

			if not eqWinAdvOpen and AdvWIN.Open() and advActive then
				if doDelay then
					if curTime - delTimerAdv >= delayTime then
						CloseWindow('adv')

						delTimerAdv = os.time()
					end
				else
					CloseWindow('adv')
				end
			end
			if not eqWinExpOpen and ExpWIN.Open() and expActive then
				if doDelay then
					if curTime - delTimerExp >= delayTime then
						CloseWindow('exp')

						delTimerExp = os.time()
					end
				else
					CloseWindow('exp')
				end
			end
		else
			guiOpen = false
		end
		clockTimer = mq.gettime()
	end
end

function Module.LocalLoop()
	while Module.IsRunning do
		Module.MainLoop()
		mq.delay(1)
	end
end

if mq.TLO.EverQuest.GameState() ~= "INGAME" then
	printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", Module.Name)
	mq.exit()
end

startup()
return Module
