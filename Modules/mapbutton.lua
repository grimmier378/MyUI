local mq               = require('mq')
local ImGui            = require 'ImGui'
local Module           = {}
local MySelf           = mq.TLO.Me
local EQ_ICON_OFFSET   = 500
local animMini         = mq.FindTextureAnimation("A_DragItem")

Module.Name            = "MapButton" -- Name of the module used when loading and unloaing the modules.
Module.IsRunning       = false       -- Keep track of running state. if not running we can unload it.
Module.ShowGui         = false
-- check if the script is being loaded as a Module (externally) or as a Standalone script.
---@diagnostic disable-next-line:undefined-global
local loadedExternally = MyUI ~= nil and true or false
if not loadedExternally then
    Module.Utils       = require('lib.common')                   -- common functions for use in other scripts
    Module.Icons       = require('mq.ICONS')                     -- FAWESOME ICONS
    Module.Colors      = require('lib.colors')                   -- color table for GUI returns ImVec4
    Module.ThemeLoader = require('lib.theme_loader')             -- Load the theme loader
    Module.CharLoaded  = MySelf.CleanName()
    Module.Server      = mq.TLO.MacroQuest.Server() or "Unknown" -- Get the server name
else
    Module.Utils       = MyUI.Utils
    Module.Icons       = MyUI.Icons
    Module.Colors      = MyUI.Colors
    Module.ThemeLoader = MyUI.ThemeLoader
    Module.CharLoaded  = MyUI.CharLoaded
    Module.Server      = MyUI.Server or "Unknown" -- Get the server name
end

local configFile = string.format("%s/MyUI/%s/%s/%s.lua", mq.configDir, Module.Name, Module.Server, Module.CharLoaded)


local defaults       = {
    showUI = true,  -- Show the UI by default
    showBtn = true, -- Show the button by default
    scale = 1.0,    -- Scale of the UI
    HideOnStart = true,
}

Module.Settings      = {}

local buttonWinFlags = bit32.bor(
    ImGuiWindowFlags.NoTitleBar,
    ImGuiWindowFlags.NoResize,
    ImGuiWindowFlags.NoScrollbar,
    ImGuiWindowFlags.NoFocusOnAppearing,
    ImGuiWindowFlags.AlwaysAutoResize
)

local function LoadSettings()
    if Module.Utils.File.Exists(configFile) then
        Module.Settings = dofile(configFile)
    else
        Module.Settings = defaults
        mq.pickle(configFile, Module.Settings)
    end
end

--Helpers
local function CommandHandler(...)
    local args = { ..., }
    if args[1] ~= nil then
        if args[1] == 'exit' or args[1] == 'quit' then
            Module.IsRunning = false
            Module.Utils.PrintOutput('MyAA', true, "\ay%s \awis \arExiting\aw...", Module.Name)
        elseif args[1] == 'show' or args[1] == 'ui' then
            Module.ShowGui = not Module.ShowGui
        end
    end
end

local function Init()
    LoadSettings()
    Module.IsRunning = true
    if not mq.TLO.Plugin("MQNearby").IsLoaded() then
        Module.IsRunning = false
        Module.Utils.PrintOutput('MyAA', true, "\arMQNearby plugin is not loaded. \ayPlease load it before using %s.", Module.Name)
    end
    if Module.Settings.HideOnStart then
        mq.cmd("/nearby hide")
    end
    if not loadedExternally then
        mq.imgui.init(Module.Name, Module.RenderGUI)
        Module.LocalLoop()
    end
end

function Module:RenderMiniButton(grouped)
    if not grouped then
        ImGui.SetNextWindowPos(ImVec2(200, 20), ImGuiCond.FirstUseEver)
        local openBtn, showBtn = ImGui.Begin(string.format(Module.Name .. "##MiniBtn" .. Module.CharLoaded), true, buttonWinFlags)
        if not openBtn then
            showBtn = false
        end

        if showBtn then
            local cursorPosX, cursorPosY = ImGui.GetCursorScreenPos()
            animMini:SetTextureCell(6849 - EQ_ICON_OFFSET)
            ImGui.DrawTextureAnimation(animMini, 34, 34, true)
            ImGui.SetCursorScreenPos(cursorPosX, cursorPosY)
            ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0.5, 0.5, 0, 0.5))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImVec4(0, 0, 0, 0))
            if ImGui.Button("##" .. Module.Name, ImVec2(34, 34)) then
                mq.cmd("/nearby toggle")
            end
            ImGui.PopStyleColor(3)
        end
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text(Module.Name)
            ImGui.Text("Toggle NearBy Map")
            ImGui.Separator()
            ImGui.TextColored(ImVec4(1, 1, 0, 1), "(Ctrl + M) or\n(Shift + MiddleMouseBtn)\nto toggle")
            ImGui.EndTooltip()
        end
        if (ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsKeyPressed(ImGuiKey.M)) or
            (ImGui.IsMouseReleased(ImGuiMouseButton['Middle']) and ImGui.IsKeyDown(ImGuiMod.Shift)) then
            mq.cmd("/nearby toggle")
        end
        if ImGui.BeginPopupContextItem("options##MapButton") then
            local changed = false
            changed, Module.Settings.HideOnStart = ImGui.MenuItem("HideOnStart##mapbutton", nil, Module.Settings.HideOnStart)
            if changed then
                mq.pickle(configFile, Module.Settings)
            end
            ImGui.EndPopup()
        end
        ImGui.End()
    else
        local cursorPosX, cursorPosY = ImGui.GetCursorScreenPos()
        animMini:SetTextureCell(6849 - EQ_ICON_OFFSET)
        ImGui.DrawTextureAnimation(animMini, 34, 34, true)
        ImGui.SetCursorScreenPos(cursorPosX, cursorPosY)
        ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0.5, 0.5, 0, 0.5))
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImVec4(0, 0, 0, 0))
        if ImGui.Button("##" .. Module.Name, ImVec2(34, 34)) then
            mq.cmd("/nearby toggle")
        end
        ImGui.PopStyleColor(3)
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text(Module.Name)
            ImGui.Text("Toggle NearBy Map")
            ImGui.Separator()
            ImGui.TextColored(ImVec4(1, 1, 0, 1), "(Ctrl + M) or\n(Shift + MiddleMouseBtn)\nto toggle")
            ImGui.EndTooltip()
        end
        if (ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsKeyPressed(ImGuiKey.M)) or
            (ImGui.IsMouseReleased(ImGuiMouseButton['Middle']) and ImGui.IsKeyDown(ImGuiMod.Shift)) then
            mq.cmd("/nearby toggle")
        end
        if ImGui.BeginPopupContextItem("options##MapButton") then
            local changed = false
            changed, Module.Settings.HideOnStart = ImGui.MenuItem("HideOnStart##mapbutton", nil, Module.Settings.HideOnStart)
            if changed then
                mq.pickle(configFile, Module.Settings)
            end
            ImGui.EndPopup()
        end
    end
end

-- Exposed Functions
function Module.RenderGUI()
    if not MyUI.Settings.GroupButtons then Module:RenderMiniButton() end
end

function Module.Unload()
end

function Module.MainLoop()
    if not MyUI.LoadModules.CheckRunning(Module.IsRunning, Module.Name) then return end
    if not mq.TLO.Plugin("MQNearby").IsLoaded() then
        Module.IsRunning = false
        Module.Utils.PrintOutput('MyAA', true, "\arMQNearby plugin is not loaded. \ayPlease load it before using %s.", Module.Name)
    end
    mq.delay(1)
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

Init()
return Module
