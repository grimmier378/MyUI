local mq                           = require('mq')
local ImGui                        = require 'ImGui'
MyUI                               = { Version = '1.0.0', ScriptName = 'MyUI', }

MyUI.PackageMan                    = require('mq.PackageMan')
MyUI.Actor                         = require('actors')
MyUI.CharData                      = require('lib.char_data')
MyUI.InventoryData                 = require('lib.inventory_data')
MyUI.SQLite3                       = MyUI.PackageMan.Require('lsqlite3')
MyUI.ProgressBar                   = require('lib.progressBars')
MyUI.Path                          = mq.luaDir .. '/myui/'
MyUI.Icons                         = require('mq.ICONS')
MyUI.Base64                        = require('lib.base64') -- Ensure you have a base64 module available
MyUI.Utils                         = require('lib.common')
MyUI.LoadModules                   = require('lib.modules')
MyUI.Colors                        = require('lib.colors')
MyUI.ThemeLoader                   = require('lib.theme_loader')
MyUI.AbilityPicker                 = require('lib.AbilityPicker')
MyUI.Grimmier_Img                  = MyUI.Utils.SetImage(MyUI.Path .. "images/GrimGUI.png")

-- build, char, server info
MyUI.CharLoaded                    = mq.TLO.Me.DisplayName()
MyUI.Server                        = mq.TLO.EverQuest.Server()
MyUI.Build                         = mq.TLO.MacroQuest.BuildName()
MyUI.Guild                         = mq.TLO.Me.Guild() or "none"
MyUI.CharClass                     = mq.TLO.Me.Class.ShortName() or "none"

local MyActor                      = MyUI.Actor.register('myui', function(message) end)
local mods                         = {}

MyUI.InitPctComplete               = 0
MyUI.NumModsEnabled                = 0
MyUI.CurLoading                    = 'Loading Modules...'
MyUI.Modules                       = {}
MyUI.Mode                          = 'driver'
MyUI.ConfPath                      = mq.configDir .. '/MyUI/' .. MyUI.Server:gsub(" ", "_") .. '/'
MyUI.SettingsFile                  = MyUI.ConfPath .. MyUI.CharLoaded .. '.lua'
MyUI.MyChatLoaded                  = false
MyUI.MyChatHandler                 = nil

MyUI.Settings                      = {}
MyUI.TempSettings                  = {}
MyUI.Theme                         = {}
MyUI.ThemeFile                     = string.format('%s/MyUI/MyThemeZ.lua', mq.configDir)
MyUI.ThemeName                     = 'Default'
MyUI.TempSettings.MyChatWinName    = nil
MyUI.TempSettings.MyChatFocusKey   = nil
MyUI.MyData                        = {}
MyUI.MyPetData                     = {}

MyUI.IsRunning                     = false

MyUI.TempSettings.ModuleProcessing = {}
MyUI.TempSettings.Debug            = false
MyUI.InvData                       = {}
local invRefreshTimer              = os.time()
local lastFreeSlots                = -1
local INV_REFRESH_DELAY            = 5


local ToggleFlags  = bit32.bor(
    MyUI.Utils.ImGuiToggleFlags.RightLabel,
    MyUI.Utils.ImGuiToggleFlags.PulseOnHover,
    MyUI.Utils.ImGuiToggleFlags.StarKnob,
    MyUI.Utils.ImGuiToggleFlags.AnimateOnHover
--MyUI.Utils.ImGuiToggleFlags.KnobBorder
)

local default_list = {
    'AAParty',
    'ChatRelay',
    'DialogDB',
    'MyBuffs',
    'MyChat',
    'MyDPS',
    'MyGroup',
    'MyPaths',
    'MyPet',
    'MySpells',
    'PlayerTarg',
    'SAST',
    'SillySounds',
    "AlertMaster",
    "ThemeZ",
    "BigBag",
    "XPTrack",
    "MyStats",
    "iTrack",
    "MyAA",
    "RaidWatch",
    "MyAA",
    "Clock",
    "MapButton",
    "MyInventory",
}

MyUI.DefaultConfig = {
    ShowMain = true,
    ThemeName = 'Default',
    GroupButtons = false,
    ResizeMini = false,
    ButtonOrder = {},
    mods_list = {
        -- load order = {name = 'mod_name', enabled = true/false}
        -- Ideally we want to Load MyChat first if Enabled.This will allow the other modules can use it.
        [1]  = { name = 'MyChat', enabled = false, },
        [2]  = { name = 'DialogDB', enabled = false, },
        [3]  = { name = 'MyGroup', enabled = false, },
        [4]  = { name = 'MyPaths', enabled = false, },
        [5]  = { name = 'MyPet', enabled = false, },
        [6]  = { name = 'MySpells', enabled = false, },
        [7]  = { name = 'PlayerTarg', enabled = false, },
        [8]  = { name = 'SAST', enabled = false, },
        [9]  = { name = 'SillySounds', enabled = false, }, -- Customized Cold's cartoonsounds
        [10] = { name = 'MyDPS', enabled = false, },
        [11] = { name = 'MyBuffs', enabled = false, },
        [12] = { name = 'ChatRelay', enabled = false, },
        [13] = { name = 'AAParty', enabled = false, },
        [14] = { name = 'AlertMaster', enabled = false, },
        [15] = { name = 'ThemeZ', enabled = false, },
        [16] = { name = 'BigBag', enabled = false, },  -- Customized Fork of Cold's Big Bag
        [17] = { name = 'XPTrack', enabled = false, }, -- Customized Fork of Derple's XPTrack
        [18] = { name = 'MyStats', enabled = false, },
        [19] = { name = 'iTrack', enabled = false, },
        [20] = { name = 'MyAA', enabled = false, },
        --[20] = { name = 'MyDots', enabled = false, }, -- Customized Fork of Zathus' MyDots
        [21] = { name = 'MyInventory', enabled = false, },
    },
}

local function LoadTheme()
    if MyUI.Utils.File.Exists(MyUI.ThemeFile) then
        MyUI.Theme = dofile(MyUI.ThemeFile)
    else
        MyUI.Theme = require('defaults.themes')
        mq.pickle(MyUI.ThemeFile, MyUI.Theme)
    end
end

local function sortModules()
    table.sort(MyUI.Settings.mods_list, function(a, b)
        return a.name < b.name
    end)
end

local function LoadSettings()
    if MyUI.Utils.File.Exists(MyUI.SettingsFile) then
        MyUI.Settings = dofile(MyUI.SettingsFile)
    else
        MyUI.Settings = MyUI.DefaultConfig
        mq.pickle(MyUI.SettingsFile, MyUI.Settings)
        LoadSettings()
    end

    local newSetting = MyUI.Utils.CheckDefaultSettings(MyUI.DefaultConfig, MyUI.Settings)
    -- newSetting = MyUI.Utils.CheckDefaultSettings(MyUI.DefaultConfig.mods_list, MyUI.Settings.mods_list) or newSetting
    for _, v in pairs(default_list) do
        local found = false
        for _, data in ipairs(MyUI.Settings.mods_list) do
            if data.name == v then
                found = true
                break
            end
        end
        if not found then
            table.insert(MyUI.Settings.mods_list, { name = v, enabled = false, })
            newSetting = true
        end
    end
    sortModules()
    LoadTheme()
    MyUI.ThemeName = MyUI.Settings.ThemeName
    if newSetting then
        mq.pickle(MyUI.SettingsFile, MyUI.Settings)
    end
end

-- borrowed from RGMercs thanks Derple! <3
local function RenderLoader()
    ImGui.SetNextWindowSize(ImVec2(400, 80), ImGuiCond.Always)
    ImGui.SetNextWindowPos(ImVec2(ImGui.GetIO().DisplaySize.x / 2 - 200, ImGui.GetIO().DisplaySize.y / 3 - 75), ImGuiCond.Always)
    local ColorCount, StyleCount = MyUI.ThemeLoader.StartTheme(MyUI.ThemeName, MyUI.Theme)
    ImGui.Begin("MyUI Loader", nil, bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoScrollbar))
    ImGui.Image(MyUI.Grimmier_Img:GetTextureID(), ImVec2(60, 60))
    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - 35)
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 70)
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 0.2, 0.7, 1 - (MyUI.InitPctComplete / 100), MyUI.InitPctComplete / 100)
    ImGui.ProgressBar(MyUI.InitPctComplete / 100, ImVec2(310, 0), MyUI.CurLoading)
    ImGui.PopStyleColor()
    MyUI.ThemeLoader.EndTheme(ColorCount, StyleCount)
    ImGui.End()
end

local function HelpDocumentation()
    local prefix = '\aw[\atMyUI\aw] '
    MyUI.Utils.PrintOutput('MyUI', true, '%s\agtWelcome to \atMyUI', prefix)
    MyUI.Utils.PrintOutput('MyUI', true, '%s\ayCommands:', prefix)
    MyUI.Utils.PrintOutput('MyUI', true, '%s\ao/myui \agshow\aw - Toggle the Main UI', prefix)
    MyUI.Utils.PrintOutput('MyUI', true, '%s\ao/myui \agexit\aw - Exit the script', prefix)
    MyUI.Utils.PrintOutput('MyUI', true, '%s\ao/myui \agload \at[\aymoduleName\at]\aw - Load a module', prefix)
    MyUI.Utils.PrintOutput('MyUI', true, '%s\ao/myui \agunload \at[\aymoduleName\at]\aw - Unload a module', prefix)
    MyUI.Utils.PrintOutput('MyUI', true, '%s\ao/myui \agnew \at[\aymoduleName\at]\aw - Add a new module', prefix)
    MyUI.Utils.PrintOutput('MyUI', true, '%s\ayStartup:', prefix)
    MyUI.Utils.PrintOutput('MyUI', true, '%s\ao/lua run myui \aw[\ayclient\aw|\aydriver\aw]\aw - Start the Sctipt in either Driver or Client Mode, Default(Driver) if not specified',
        prefix)
end

local function GetSortedModuleNames()
    local sorted_names = {}
    for _, data in ipairs(MyUI.Settings.mods_list) do
        table.insert(sorted_names, data.name)
    end
    table.sort(sorted_names)
    return sorted_names
end

local function InitModules()
    for idx, data in ipairs(MyUI.Settings.mods_list) do
        if data.enabled and MyUI.Modules[data.name] ~= nil and MyUI.Modules[data.name].ActorMailBox ~= nil then
            local message = {
                Subject = 'Hello',
                Message = 'Hello',
                Name = MyUI.CharLoaded,
                Guild = MyUI.Guild,
                Tell = '',
                Check = os.time,
            }
            MyActor:send({ mailbox = MyUI.Modules[data.name].ActorMailBox, script = data.name:lower(), }, message)
            MyActor:send({ mailbox = MyUI.Modules[data.name].ActorMailBox, script = 'myui', }, message)
        end
    end
end

local function RenderModules()
    for _, data in ipairs(MyUI.Settings.mods_list) do
        if data.enabled and MyUI.Modules[data.name] ~= nil then
            if MyUI.Modules[data.name].RenderGUI ~= nil then
                MyUI.Modules[data.name].RenderGUI()
            end
        end
    end
end

local function ProcessModuleChanges()
    -- Enable/Disable Modules
    if MyUI.TempSettings.ModuleChanged then
        local module_name = MyUI.TempSettings.ModuleName
        local enabled = MyUI.TempSettings.ModuleEnabled

        for idx, data in ipairs(MyUI.Settings.mods_list) do
            if data.name == module_name then
                MyUI.Settings.mods_list[idx].enabled = enabled
                if enabled then
                    table.insert(mods, module_name)
                    MyUI.Modules[module_name] = MyUI.LoadModules.load(module_name)
                    InitModules()
                else
                    for i, v in ipairs(mods) do
                        if v == module_name then
                            if MyUI.Modules[module_name] ~= nil then
                                if MyUI.Modules[module_name].Unload ~= nil then
                                    MyUI.Modules[module_name].Unload()
                                end
                                MyUI.LoadModules.unload(module_name)
                                -- MyUI.Modules[module_name] = nil
                            end
                            table.remove(mods, i)
                        end
                    end
                    InitModules()
                end
                mq.pickle(MyUI.SettingsFile, MyUI.Settings)
                break
            end
        end
        sortModules()
        MyUI.TempSettings.ModuleChanged = false
    end

    -- Add Custom Module
    if MyUI.TempSettings.AddCustomModule then
        local found = false
        for _, data in ipairs(MyUI.Settings.mods_list) do
            if data.name:lower() == MyUI.TempSettings.AddModule:lower() then
                found = true
                break
            end
        end
        if not found then
            table.insert(MyUI.Settings.mods_list, { name = MyUI.TempSettings.AddModule, enabled = false, })
            sortModules()
            mq.pickle(MyUI.SettingsFile, MyUI.Settings)
        end
        MyUI.TempSettings.AddModule = ''
        MyUI.TempSettings.AddCustomModule = false
    end

    -- Remove Module
    if MyUI.TempSettings.RemoveModule then
        for idx, data in ipairs(MyUI.Settings.mods_list) do
            if data.name:lower() == MyUI.TempSettings.AddModule:lower() then
                for i, v in ipairs(mods) do
                    if v == data.name then
                        MyUI.Modules[data.name].Unload()
                        MyUI.LoadModules.unload(data.name)
                        -- MyUI.Modules[data.name] = nil
                        table.remove(mods, i)
                    end
                end
                table.remove(MyUI.Settings.mods_list, idx)
                sortModules()
                mq.pickle(MyUI.SettingsFile, MyUI.Settings)
                break
            end
        end
        MyUI.TempSettings.AddModule = ''
        MyUI.TempSettings.RemoveModule = false
    end
end

local function DrawContextItem(group_type)
    if not group_type then return end
    local gpCmd = group_type == 'raid' and 'dgre' or 'dgge'
    local gpCmdAll = group_type == 'raid' and 'dgra' or 'dgga'
    local label = group_type == 'raid' and 'MyRaid' or 'MyGroup'

    if group_type == 'all' then
        gpCmd = 'dge all'
        gpCmdAll = 'dgae'
        label = 'AllGroups'
    end

    ImGui.PushStyleColor(ImGuiCol.Text, MyUI.Colors.color('teal'))
    if ImGui.MenuItem(string.format('Start %s Clients', label)) then
        mq.cmdf('/%s /lua run myui client', gpCmd)
    end
    ImGui.PopStyleColor()

    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Text, MyUI.Colors.color('tangarine'))
    if ImGui.MenuItem(string.format('Stop %s Clients', label)) then
        mq.cmdf('/%s /myui quit', gpCmd)
    end
    ImGui.PopStyleColor()

    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Text, MyUI.Colors.color('pink2'))
    if ImGui.MenuItem(string.format('Stop %s ALL', label)) then
        mq.cmdf('/%s /myui quit', gpCmdAll)
    end
    ImGui.PopStyleColor()
end

local function DrawContextMenu()
    if mq.TLO.Plugin('MQ2DanNet').IsLoaded() then
        if mq.TLO.Raid.Members() > 0 then
            DrawContextItem('raid')
            ImGui.Spacing()
            ImGui.Separator()
        elseif mq.TLO.Group.Members() > 0 then
            DrawContextItem('group')
            ImGui.Spacing()
            ImGui.Separator()
        end

        DrawContextItem('all')
        ImGui.Spacing()
        ImGui.Separator()
    end

    if MyUI.Settings.GroupButtons then
        local changed = false
        changed, MyUI.Settings.ResizeMini = ImGui.MenuItem('Resize Mini', nil, MyUI.Settings.ResizeMini)
        if changed then
            mq.pickle(MyUI.SettingsFile, MyUI.Settings)
        end
        ImGui.Spacing()
        ImGui.Separator()
    end
    if ImGui.MenuItem('Exit') then
        MyUI.IsRunning = false
    end
end

local function RenderDebug()
    if not MyUI.TempSettings.Debug then
        return
    end
    local ColorCount, StyleCount = MyUI.ThemeLoader.StartTheme(MyUI.ThemeName, MyUI.Theme)
    ImGui.SetNextWindowSize(ImVec2(400, 200), ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowPos(ImVec2(100, 100), ImGuiCond.FirstUseEver)
    local open_debug, show_debug = ImGui.Begin(MyUI.ScriptName .. " Debug##" .. MyUI.CharLoaded, true)
    if not open_debug then
        MyUI.TempSettings.Debug = false
        show_debug = false
    end
    if show_debug then
        ImGui.PushFont(ImGui.ConsoleFont, 16)

        local totalTime = 0
        local tempSort = GetSortedModuleNames()
        if ImGui.BeginTable("Module Processing", 2, ImGuiTableFlags.Borders) then
            ImGui.TableSetupColumn("Module Name", ImGuiTableColumnFlags.WidthFixed, 150)
            ImGui.TableSetupColumn("Time (ms)", ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableHeadersRow()

            for _, name in ipairs(tempSort or {}) do
                if MyUI.TempSettings.ModuleProcessing[name] ~= nil then
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn()
                    ImGui.Indent()
                    ImGui.Text(MyUI.TempSettings.ModuleProcessing[name].ModName)
                    ImGui.Unindent()
                    ImGui.TableNextColumn()
                    ImGui.Indent()
                    ImGui.Text(string.format("%.0f", MyUI.TempSettings.ModuleProcessing[name].Timer or 0))
                    ImGui.Unindent()
                    totalTime = totalTime + (MyUI.TempSettings.ModuleProcessing[name].Timer or 0)
                end
            end
            ImGui.EndTable()
        end
        ImGui.Separator()
        ImGui.Text("Total Time:")
        local ttSec = totalTime / 1000
        ImGui.SameLine()
        ImGui.TextColored(MyUI.Colors.color(ttSec < 1 and 'green' or (ttSec < 2 and 'yellow' or 'red')), "%.3f seconds", ttSec)
        ImGui.PopFont()
    end

    MyUI.ThemeLoader.EndTheme(ColorCount, StyleCount)
    ImGui.End()
end

local function GetButtonOrder()
    local order = MyUI.Settings.ButtonOrder or {}
    local hasBtn = {}
    for _, data in ipairs(MyUI.Settings.mods_list) do
        if data.enabled and MyUI.Modules[data.name] ~= nil and MyUI.Modules[data.name].RenderMiniButton ~= nil then
            hasBtn[data.name] = true
        end
    end
    local seen = {}
    local result = {}
    for _, name in ipairs(order) do
        if hasBtn[name] then
            table.insert(result, name)
            seen[name] = true
        end
    end
    for _, data in ipairs(MyUI.Settings.mods_list) do
        if hasBtn[data.name] and not seen[data.name] then
            table.insert(result, data.name)
        end
    end
    return result
end

local function RenderMini()
    local ColorCount, StyleCount = MyUI.ThemeLoader.StartTheme(MyUI.ThemeName, MyUI.Theme)
    local miniFlags
    if MyUI.Settings.GroupButtons then
        local btnCount = #GetButtonOrder() + 1
        local initCols = math.min(btnCount, 5)
        local initRows = math.ceil(btnCount / initCols)
        local initW = initCols * (34 + 2) + 16
        local initH = initRows * (34 + 2) + 16
        ImGui.SetNextWindowSize(ImVec2(initW, initH), ImGuiCond.FirstUseEver)
        miniFlags = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoScrollbar)
    else
        miniFlags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar)
    end
    local openMini, showMini = ImGui.Begin(MyUI.ScriptName .. "##Mini" .. MyUI.CharLoaded, true, miniFlags)

    if not openMini then
        MyUI.IsRunning = false
    end
    if showMini then
        local clicked = MyUI.Utils.DrawMiniButton("##MyUIBtn", nil, { image = MyUI.Grimmier_Img:GetTextureID(), })
        if clicked then
            MyUI.Settings.ShowMain = not MyUI.Settings.ShowMain
        end
        if ImGui.BeginPopupContextItem("MyUI##MiniContext") then
            DrawContextMenu()
            ImGui.Separator()
            ImGui.EndPopup()
        end
        if MyUI.Settings.GroupButtons then
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(2, 2))
            local winWidth = ImGui.GetContentRegionAvail()
            local cols = math.max(1, math.floor(winWidth / (34 + 2)))
            local col = 2
            local btnOrder = GetButtonOrder()
            local drawList = ImGui.GetWindowDrawList()
            local btnRects = {}
            local dragSrcIdx = nil
            for i, name in ipairs(btnOrder) do
                if col <= cols then
                    ImGui.SameLine()
                    col = col + 1
                else
                    col = 2
                end
                MyUI.Modules[name]:RenderMiniButton(true)
                local minX, minY = ImGui.GetItemRectMin()
                local maxX, maxY = ImGui.GetItemRectMax()
                btnRects[i] = { minX = minX, minY = minY, maxX = maxX, maxY = maxY, }
                if ImGui.BeginDragDropSource() then
                    dragSrcIdx = i
                    ImGui.SetDragDropPayload("MINI_BTN", i)
                    ImGui.Text(name)
                    ImGui.EndDragDropSource()
                end
                if ImGui.BeginDragDropTarget() then
                    drawList:AddRectFilled(ImVec2(minX, minY), ImVec2(maxX, maxY), IM_COL32(0, 255, 255, 60), 3.0, ImDrawFlags.RoundCornersAll)
                    drawList:AddRect(ImVec2(minX, minY), ImVec2(maxX, maxY), IM_COL32(0, 255, 255, 255), 3.0, ImDrawFlags.RoundCornersAll, 2.0)
                    local payload = ImGui.AcceptDragDropPayload("MINI_BTN")
                    if payload ~= nil then
                        local srcIdx = payload.Data
                        btnOrder[srcIdx], btnOrder[i] = btnOrder[i], btnOrder[srcIdx]
                        MyUI.Settings.ButtonOrder = btnOrder
                        mq.pickle(MyUI.SettingsFile, MyUI.Settings)
                    end
                    ImGui.EndDragDropTarget()
                end
            end
            ImGui.PopStyleVar()
            if MyUI.Settings.ResizeMini then
                local totalBtns = #btnOrder + 1
                local rows = math.ceil(totalBtns / cols)
                local clampW = cols * (34 + 2) + 16
                local clampH = rows * (34 + 2) + 16
                ImGui.SetWindowSize(ImVec2(clampW, clampH))
            end
            if dragSrcIdx and btnRects[dragSrcIdx] then
                local r = btnRects[dragSrcIdx]
                drawList:AddRectFilled(ImVec2(r.minX, r.minY), ImVec2(r.maxX, r.maxY), IM_COL32(255, 165, 0, 60), 3.0, ImDrawFlags.RoundCornersAll)
                drawList:AddRect(ImVec2(r.minX, r.minY), ImVec2(r.maxX, r.maxY), IM_COL32(255, 165, 0, 255), 3.0, ImDrawFlags.RoundCornersAll, 2.0)
            end
        end
    end
    if not MyUI.Settings.GroupButtons then
        if ImGui.BeginPopupContextWindow() then
            DrawContextMenu()
            ImGui.Separator()
            ImGui.EndPopup()
        end
    end
    if MyUI.TempSettings.MyChatWinName ~= nil and MyUI.TempSettings.MyChatFocusKey ~= nil then
        if ImGui.IsKeyPressed(ImGuiKey[MyUI.TempSettings.MyChatFocusKey]) then
            ImGui.SetWindowFocus(MyUI.TempSettings.MyChatWinName)
        end
    end
    MyUI.ThemeLoader.EndTheme(ColorCount, StyleCount)
    ImGui.End()
end

function MyUI.Render()
    if MyUI.InitPctComplete < 100 and MyUI.NumModsEnabled > 0 then
        RenderLoader()
    else
        if MyUI.Settings.ShowMain then
            local ColorCount, StyleCount = MyUI.ThemeLoader.StartTheme(MyUI.ThemeName, MyUI.Theme)

            Minimized = false
            ImGui.SetNextWindowSize(400, 200, ImGuiCond.FirstUseEver)
            ImGui.SetNextWindowSizeConstraints(ImVec2(200, 200), ImVec2(4000, 4000))
            ImGui.PushFont(ImGui.ConsoleFont, 16)

            -- local ColorCount, StyleCount = MyUI.ThemeLoader.StartTheme(MyUI.ThemeName, MyUI.Theme)
            local open_gui, show_gui = ImGui.Begin(MyUI.ScriptName .. "##" .. MyUI.CharLoaded, true, ImGuiWindowFlags.None)

            if not open_gui then
                MyUI.Settings.ShowMain = false
                Minimized = true
                mq.pickle(MyUI.SettingsFile, MyUI.Settings)
            end

            if show_gui then
                if ImGui.IsWindowFocused() then
                    if ImGui.IsKeyPressed(ImGuiKey.Escape) then
                        MyUI.Settings.ShowMain = false
                        Minimized = true
                        mq.pickle(MyUI.SettingsFile, MyUI.Settings)
                    end
                end
                ImGui.Text(MyUI.Icons.MD_SETTINGS)
                if ImGui.BeginPopupContextItem() then
                    DrawContextMenu()
                    ImGui.EndPopup()
                end
                if ImGui.CollapsingHeader('Theme##Coll' .. 'MyUI') then
                    ImGui.Text("Cur Theme: %s", MyUI.ThemeName)
                    -- Combo Box Load Theme

                    if ImGui.BeginCombo("Load Theme##MyBuffs", MyUI.ThemeName) then
                        for k, data in pairs(MyUI.Theme.Theme) do
                            local isSelected = data.Name == MyUI.ThemeName
                            if ImGui.Selectable(data.Name, isSelected) then
                                if MyUI.ThemeName ~= data.Name then
                                    MyUI.ThemeName = data.Name
                                    MyUI.Settings.ThemeName = MyUI.ThemeName
                                    mq.pickle(MyUI.SettingsFile, MyUI.Settings)
                                end
                            end
                        end
                        ImGui.EndCombo()
                    end

                    if ImGui.Button('Reload Theme File') then
                        LoadTheme()
                    end


                    ImGui.SameLine()
                    if ImGui.Button('Edit ThemeZ') then
                        if MyUI.Modules['ThemeZ'] ~= nil then
                            if MyUI.Modules['ThemeZ'].IsRunning then
                                MyUI.Modules['ThemeZ'].ShowGui = true
                            else
                                MyUI.TempSettings.ModuleChanged = true
                                MyUI.TempSettings.ModuleName = 'ThemeZ'
                                MyUI.TempSettings.ModuleEnabled = true
                            end
                        else
                            MyUI.TempSettings.ModuleChanged = true
                            MyUI.TempSettings.ModuleName = 'ThemeZ'
                            MyUI.TempSettings.ModuleEnabled = true
                        end
                    end
                end
                ImGui.SeparatorText('Modules')
                local sizeX, sizeY = ImGui.GetContentRegionAvail()
                if (sizeX or 125) < 125 then sizeX = 125 end
                local col = math.floor((sizeX or 125) / 125) or 1
                if ImGui.BeginTable("Modules", col, ImGuiWindowFlags.None) then
                    local tempSort = GetSortedModuleNames()
                    local sorted_names = MyUI.Utils.SortTableColumns(nil, tempSort, col)

                    for _, name in ipairs(sorted_names) do
                        local module_data = nil
                        for _, data in ipairs(MyUI.Settings.mods_list) do
                            if data.name == name then
                                module_data = data
                                goto continue
                            end
                        end
                        ::continue::

                        if module_data then
                            local pressed = false
                            ImGui.TableNextColumn()
                            ImGui.SetNextItemWidth(120)
                            local new_state = MyUI.Utils.DrawToggle(module_data.name,
                                module_data.enabled,
                                ToggleFlags,
                                ImVec2(46, 20),
                                {
                                    OnColor = ImVec4(0.026, 0.519, 0.791, 1.000),
                                    OffColor = ImVec4(1, 0.2, 0.2, 0.8),
                                    KnobColor = ImVec4(1.000, 0.785, 0.000, 1.000),
                                    BorderColor = ImVec4(1, 1, 1, 0.7),
                                }
                            )

                            -- If checkbox changed, set flags for processing
                            if new_state ~= module_data.enabled then
                                MyUI.TempSettings.ModuleChanged = true
                                MyUI.TempSettings.ModuleName = module_data.name
                                MyUI.TempSettings.ModuleEnabled = new_state
                            end
                        end
                    end
                    ImGui.EndTable()
                end

                -- Add Custom Module Section
                ImGui.SetNextItemWidth(150)
                MyUI.TempSettings.AddModule = ImGui.InputText("Add Custom Module", MyUI.TempSettings.AddModule or '')

                MyUI.TempSettings.Debug = MyUI.Utils.DrawToggle("Debug Mode", MyUI.TempSettings.Debug, ToggleFlags, 16)
                local newGroupButtons = MyUI.Utils.DrawToggle("Group Buttons", MyUI.Settings.GroupButtons, ToggleFlags, 16)
                if newGroupButtons ~= MyUI.Settings.GroupButtons then
                    MyUI.Settings.GroupButtons = newGroupButtons
                    mq.pickle(MyUI.SettingsFile, MyUI.Settings)
                end
                if MyUI.TempSettings.AddModule ~= '' then
                    if ImGui.Button("Add") then
                        MyUI.TempSettings.AddCustomModule = true
                    end

                    local found = false
                    for _, v in pairs(default_list) do
                        if v:lower() == MyUI.TempSettings.AddModule:lower() then
                            found = true
                            MyUI.TempSettings.AddModule = ''
                            goto found_one
                        end
                    end
                    ::found_one::
                    if not found then
                        ImGui.SameLine()
                        if ImGui.Button("Remove") then
                            MyUI.TempSettings.RemoveModule = true
                        end
                    end
                end
            end
            MyUI.ThemeLoader.EndTheme(ColorCount, StyleCount)
            ImGui.End()
            ImGui.PopFont()
        end

        RenderModules()

        RenderDebug()
    end
    RenderMini()
end

function MyUI.Main()
    local ModTimer
    while MyUI.IsRunning do
        if mq.TLO.EverQuest.GameState() ~= "INGAME" then mq.exit() end
        mq.doevents()
        ProcessModuleChanges()
        MyUI.MyData = MyUI.CharData.GetMyData()
        MyUI.MyData.Buffs, MyUI.MyData.DebuffsOnMe = MyUI.CharData.GetBuffs()
        MyUI.MyData.Songs = MyUI.CharData.GetSongs()
        MyUI.MyPetData = MyUI.CharData.GetPetData()
        local curFreeSlots = MyUI.InventoryData.GetFreeSlots()
        if MyUI.InventoryData.NeedsRefresh(invRefreshTimer, INV_REFRESH_DELAY) or curFreeSlots ~= lastFreeSlots then
            invRefreshTimer = os.time()
            lastFreeSlots = curFreeSlots
            MyUI.InvData = {
                worn = MyUI.InventoryData.GetWornItems(),
                bags = MyUI.InventoryData.GetBagContents(),
                containers = MyUI.InventoryData.GetBags(),
                clickies = MyUI.InventoryData.GetEquippedClickies(),
                freeSlots = curFreeSlots,
            }
        end
        for idx, data in ipairs(MyUI.Settings.mods_list) do
            if data.enabled then
                mq.doevents()
                if MyUI.TempSettings.Debug then
                    ModTimer = mq.gettime()
                else
                    ModTimer = 0
                end
                local moduleData = MyUI.Modules[data.name]
                if moduleData and moduleData.MainLoop ~= nil then moduleData.MainLoop() end
                -- printf("Module: \at%s\ax took \ay%.2f ms\ax to run", data.name, (os.clock() - ModTimer) * 1000)
                if MyUI.TempSettings.Debug then
                    if MyUI.TempSettings.ModuleProcessing[data.name] == nil then
                        MyUI.TempSettings.ModuleProcessing[data.name] = {}
                    end
                    MyUI.TempSettings.ModuleProcessing[data.name] = { ModName = data.name, Timer = (mq.gettime() - ModTimer), }
                else
                    MyUI.TempSettings.ModuleProcessing[data.name] = nil
                end
            else
                MyUI.TempSettings.ModuleProcessing[data.name] = nil
            end
        end
        mq.doevents()
        mq.delay(1)
    end
end

local args = { ..., }
local function CheckMode(value)
    if value == nil then
        MyUI.Mode = 'driver'
        return
    end
    if value[1] == 'client' then
        MyUI.Mode = 'client'
    elseif value[1] == 'driver' then
        MyUI.Mode = 'driver'
    end
end

local function CommandHandler(...)
    args = { ..., }

    if #args > 1 then
        local module_name = args[2]:lower()
        if args[1] == 'unload' then
            for k, _ in pairs(MyUI.Modules) do
                if k:lower() == module_name then
                    MyUI.LoadModules.CheckRunning(false, k)
                    MyUI.Utils.PrintOutput('MyUI', true, "\ay%s \awis \arExiting\aw...", k)
                    goto finished_cmd
                end
            end
        elseif args[1] == 'load' then
            for _, data in ipairs(MyUI.Settings.mods_list) do
                local tmpName = data.name:lower()
                if tmpName == module_name then
                    if MyUI.Modules[data.name] ~= nil then
                        if MyUI.Modules[data.name].IsRunning then
                            MyUI.Utils.PrintOutput('MyUI', true, "\ay%s \awis \agAlready Loaded\aw...", data.name)
                            goto finished_cmd
                        end
                    else
                        MyUI.TempSettings.ModuleChanged = true
                        MyUI.TempSettings.ModuleName = data.name
                        MyUI.TempSettings.ModuleEnabled = true
                        MyUI.Utils.PrintOutput('MyUI', true, "\ay%s \awis \agLoaded\aw...", data.name)
                        goto finished_cmd
                    end
                end
            end
        elseif args[1] == 'new' then
            MyUI.TempSettings.AddModule = args[2]
            MyUI.TempSettings.AddCustomModule = true
            MyUI.Utils.PrintOutput('MyUI', true, "\ay%s \awis \agAdded\aw...", args[2])
            goto finished_cmd
        elseif args[1] == 'remove' then
            MyUI.TempSettings.AddModule = args[2]
            MyUI.TempSettings.RemoveModule = true
            MyUI.Utils.PrintOutput('MyUI', true, "\ay%s \awis \arRemoved\aw...", args[2])
            goto finished_cmd
        end
        MyUI.Utils.PrintOutput('MyUI', true, "\aoModule Named: \ay%s was \arNot Found\aw...", args[2])
    else
        if args[1] == 'show' then
            MyUI.Settings.ShowMain = not MyUI.Settings.ShowMain
            mq.pickle(MyUI.SettingsFile, MyUI.Settings)
        elseif args[1] == 'exit' or args[1] == 'quit' then
            MyUI.IsRunning = false
            MyUI.Utils.PrintOutput('MyUI', true, "\ay%s \awis \arExiting\aw...", MyUI.ScriptName)
        else
            HelpDocumentation()
        end
    end
    ::finished_cmd::
end

local function StartUp()
    mq.bind('/myui', CommandHandler)
    CheckMode(args)
    LoadSettings()
    MyUI.MyData = MyUI.CharData.GetMyData()
    MyUI.MyData.Buffs, MyUI.MyData.DebuffsOnMe = MyUI.CharData.GetBuffs()
    MyUI.MyData.Songs = MyUI.CharData.GetSongs()
    MyUI.MyPetData = MyUI.CharData.GetPetData()

    mq.imgui.init(MyUI.ScriptName, MyUI.Render)
    for _, data in ipairs(MyUI.Settings.mods_list) do
        if (data.name == 'MyGroup' or data.name == 'MyBuffs' or data.name == 'AAParty') and MyUI.Mode == 'client' then
            data.enabled = true
        end
        if data.enabled then
            table.insert(mods, data.name)
            MyUI.NumModsEnabled = MyUI.NumModsEnabled + 1
        end
    end
    if MyUI.NumModsEnabled > 0 then
        MyUI.Modules = MyUI.LoadModules.loadAll(mods)
    else
        MyUI.InitPctComplete = 100
    end

    InitModules()

    MyUI.IsRunning = true
    HelpDocumentation()
end

StartUp()
MyUI.Main()
