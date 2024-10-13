--[[
	---------------TextEditor Window Flags-------------
	---
	TextEditorWindowFlags.None,
	TextEditorWindowFlags.ShowWhiteSpace,
	TextEditorWindowFlags.ShowCR,
	TextEditorWindowFlags.ShowLineNumbers,
	TextEditorWindowFlags.ShowIndicators,
	TextEditorWindowFlags.HideScrollBar,
	TextEditorWindowFlags.Modal,
	TextEditorWindowFlags.WrapText,
	TextEditorWindowFlags.HideSplitMark,
	TextEditorWindowFlags.GridStyle,
	TextEditorWindowFlags.ShowLineBackground,
	TextEditorWindowFlags.ShowWrappedLineNumbers,
	TextEditorWindowFlags.ShowAirLine,
	TextEditorWindowFlags.HideTrailingNewline,

	
	-------------TextEditor function calls. ----------------
	---
	ImGui.TextEditor.new( id ) - Creates a new TextEditorObject
	TextEditor:Render(ImVec2(w,h)) - Renders with option display size arg
	TextEditor:Clear() - Clears Text
	TextEditor:SetSyntax( syntaxName ) - sets the syntax highligher format
	TextEditor:LoadContents( contents )
	TextEditor.fontSize = n
	TextEditor:GetFontSize()
	TextEditor:.windowFlags = flags
	TextEditor:IsCursorAtEnd()

	----------------- Syntax Highlighting ----------------
	Syntax support for:

	lua
	cpp
	markdown
	tree
	toml
	cmake
	scm or scheme
	janet
	lisp
	hlsl
	gl shaders vert/frag
]]

local mq                = require('mq')
local ImGui             = require 'ImGui'
local drawTimerMS       = mq.gettime() -- get the current time in milliseconds
local PackageMan        = require('mq.PackageMan')
local lfs               = PackageMan.Require('luafilesystem', 'lfs')
local editorWinFlags    = TextEditorWindowFlags.None
local TextEditor
local fontSize          = 18
local syntax            = 'lua'

---@diagnostic disable-next-line:undefined-global
local loadedExeternally = MyUI_ScriptName ~= nil and true or false

local Module            = {}
Module.Flags            = {
	[1] = { name = 'GridStyle', value = false, },
	[2] = { name = 'HideScrollBar', value = false, },
	[3] = { name = 'HideSplitMark', value = false, },
	[4] = { name = 'HideTrailingNewline', value = false, },
	[5] = { name = 'Modal', value = false, },
	[6] = { name = 'ShowAirLine', value = false, },
	[7] = { name = 'ShowCR', value = false, },
	[8] = { name = 'ShowIndicators', value = true, },
	[9] = { name = 'ShowLineBackground', value = false, },
	[10] = { name = 'ShowLineNumbers', value = true, },
	[11] = { name = 'ShowWhiteSpace', value = false, },
	[12] = { name = 'ShowWrappedLineNumbers', value = true, },
	[13] = { name = 'WrapText', value = true, },

}
Module.SaveFile         = ''
Module.SavePath         = ''
Module.OpenFile         = ''
Module.Name             = "TextEditor"        -- Name of the module used when loading and unloaing the modules.
Module.IsRunning        = false               -- Keep track of running state. if not running we can unload it.
Module.ShowGui          = true
Module.Icons            = require('mq.ICONS') -- FAWESOME ICONS
Module.CharLoaded       = mq.TLO.Me.DisplayName()

local function RenderEditor()
	ImGui.PushFont(ImGui.ConsoleFont)
	local yPos = ImGui.GetCursorPosY()
	local footerHeight = 35
	local editHeight = (ImGui.GetWindowHeight()) - yPos - footerHeight
	TextEditor:Render(ImVec2(ImGui.GetWindowWidth() * 0.98, editHeight))
	ImGui.PopFont()
end

local syntaxTypes = {
	[1] = { name = 'lua', extention = '.lua', },
	[2] = { name = 'cpp', extention = '.cpp', },
	[3] = { name = 'markdown', extention = '.md', },
	[4] = { name = 'tree', extention = '.tree', },
	[5] = { name = 'toml', extention = '.toml', },
	[6] = { name = 'cmake', extention = '.cmake', },
	[7] = { name = 'scm', extention = '.scm', },
	[8] = { name = 'janet', extention = '.janet', },
	[9] = { name = 'lisp', extention = '.lisp', },
	[10] = { name = 'hlsl', extention = '.hlsl', },
	[11] = { name = 'gl shaders', extention = '.glsl', },
}

--Helpers
-- You can keep your functions local to the module the ones here are the only ones we care about from the main script.
local function CommandHandler(...)
	local args = { ..., }
	if args[1] ~= nil then
		if args[1] == 'exit' or args[1] == 'quit' then
			Module.IsRunning = false
			printf("\ay%s \awis \arExiting\aw...", Module.Name)
		elseif args[1] == 'show' or args[1] == 'ui' then
			Module.ShowGui = not Module.ShowGui
		end
	end
end

--- File Picker Dialog Stuff --

SelectedFilePath = string.format('%s/', mq.TLO.MacroQuest.Path()) -- Default config folder path prefix
CurrentDirectory = mq.TLO.MacroQuest.Path()
SelectedFile = nil
ShowSaveFileSelector = false
ShowOpenFileSelector = false

-- Function to get the contents of a directory
local function GetDirectoryContents(path)
	local folders = {}
	local files = {}
	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." then
			local f = path .. '/' .. file
			local attr = lfs.attributes(f)
			if attr.mode == "directory" then
				table.insert(folders, file)
			elseif attr.mode == "file" then
				table.insert(files, file)
			end
		end
	end
	return folders, files
end

-- Function to draw the folder button tree
local function DrawFolderButtonTree(currentPath)
	local folders = {}
	for folder in string.gmatch(currentPath, "[^/]+") do
		table.insert(folders, folder)
	end

	local path = ""
	for i, folder in ipairs(folders) do
		path = path .. folder .. "/"
		ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0.2, 0.2, 0.2, 1))
		local btnLblFolder = string.format("^%s", mq.TLO.MacroQuest.Path())
		btnLblFolder = folder:gsub(btnLblFolder, "...")
		if ImGui.Button(btnLblFolder) then
			CurrentDirectory = path:gsub("/$", "")
		end
		ImGui.PopStyleColor()
		if i < #folders then
			ImGui.SameLine()
			ImGui.Text("/")
			ImGui.SameLine()
		end
	end
end

-- Function to draw the file selector
local function DrawFileSelector()
	DrawFolderButtonTree(CurrentDirectory)
	ImGui.Separator()
	local folders, files = GetDirectoryContents(CurrentDirectory)
	if CurrentDirectory ~= mq.TLO.MacroQuest.Path() then
		if ImGui.Button("Back") then
			CurrentDirectory = CurrentDirectory:match("(.*)/[^/]+$")
		end
		ImGui.SameLine()
	end
	local tmpFolder = CurrentDirectory:gsub(mq.TLO.MacroQuest.Path() .. "/", "")
	ImGui.SetNextItemWidth(180)
	if ImGui.BeginCombo("Select Folder", tmpFolder) then
		for _, folder in ipairs(folders) do
			if ImGui.Selectable(folder) then
				CurrentDirectory = CurrentDirectory .. '/' .. folder
			end
		end
		ImGui.EndCombo()
	end

	local tmpfile = SelectedFilePath:gsub(CurrentDirectory .. "/", "")
	ImGui.SetNextItemWidth(180)
	if ImGui.BeginCombo("Select File", tmpfile or "Select a file") then
		for _, file in ipairs(files) do
			if ImGui.Selectable(file) then
				SelectedFile = file
				SelectedFilePath = CurrentDirectory .. '/' .. SelectedFile
				ShowOpenFileSelector = false
			end
		end
		ImGui.EndCombo()
	end
	if ImGui.Button('Cancel##Open') then
		ShowOpenFileSelector = false
	end
end


local fontSizes = {}
for i = 10, 40 do
	if i % 2 == 0 then
		table.insert(fontSizes, i)
		if i == 12 then
			table.insert(fontSizes, 13) -- this is the default font size so keep it in the list
		end
	end
end

local function Init()
	-- your Init code here
	mq.bind('/txtedit', CommandHandler)
	Module.IsRunning = true
	printf("\ayModule \a-w[\at%s\a-w] \agLoaded\aw!", Module.Name)
	for _, data in ipairs(Module.Flags) do
		if data.value then
			editorWinFlags = bit32.bor(editorWinFlags, TextEditorWindowFlags[data.name])
		end
	end
	TextEditor = ImGui.TextEditor.new("##TextEditor")
	TextEditor:SetSyntax(syntax)
	TextEditor.fontSize = fontSize
	TextEditor.windowFlags = editorWinFlags
	if not loadedExeternally then
		mq.imgui.init(Module.Name, Module.RenderGUI)
		Module.LocalLoop()
	end
end


-- Exposed Functions
function Module.RenderGUI()
	if Module.ShowGui then
		local open, show = ImGui.Begin(Module.Name .. "##" .. Module.CharLoaded, true, bit32.bor(ImGuiWindowFlags.MenuBar))
		if not open then
			show = false
			Module.ShowGui = false
			ImGui.End()
			return
		end
		if show then
			if ImGui.BeginMenuBar() then
				if ImGui.BeginMenu('File##' .. Module.Name) then
					if ImGui.MenuItem('Open##' .. Module.Name) then
						ShowOpenFileSelector = not ShowOpenFileSelector
					end
					if Module.SavePath ~= '' then
						if ImGui.MenuItem('Save##' .. Module.Name) then
							if Module.SaveFile == '' then
								Module.WriteFile(Module.SavePath, TextEditor.text)
							elseif Module.SaveFile ~= '' then
								Module.SavePath = Module.SaveFile
								Module.WriteFile(Module.SavePath, TextEditor.text)
							end
							Module.SavePath = ''
							Module.SaveFile = ''
						end
					end
					if ImGui.MenuItem('Exit##' .. Module.Name) then
						Module.ShowGui = false
						Module.IsRunning = false
					end
					ImGui.EndMenu()
				end
				if ImGui.BeginMenu('Options##' .. Module.Name) then
					if ImGui.BeginMenu('Flags##' .. Module.Name) then
						for k, data in ipairs(Module.Flags) do
							local label = data.name .. "##" .. Module.Name
							if ImGui.MenuItem(label, nil, data.value) then
								Module.Flags[k].value = not Module.Flags[k].value
							end
						end
						ImGui.EndMenu()
					end
					if ImGui.BeginMenu('Font Size##' .. Module.Name) then
						if ImGui.BeginCombo("Font Size##Editor", tostring(fontSize)) then
							for k, data in pairs(fontSizes) do
								local isSelected = data == fontSize
								if ImGui.Selectable(tostring(data), isSelected) then
									if fontSize ~= data then
										fontSize = data
										TextEditor.fontSize = data
									end
								end
							end
							ImGui.EndCombo()
						end
						ImGui.EndMenu()
					end
					ImGui.EndMenu()
				end
				if ImGui.BeginMenu('Syntax Highlighting##' .. Module.Name) then
					ImGui.SetNextItemWidth(100)
					if ImGui.BeginCombo('Syntax Highlighting##' .. Module.Name, syntax) then
						for i, data in ipairs(syntaxTypes) do
							local isSelected = data.name == syntax
							if ImGui.Selectable(data.name, isSelected) then
								if syntax ~= data.name then
									syntax = data.name
									TextEditor:SetSyntax(syntax)
								end
							end
						end
						ImGui.EndCombo()
					end
					ImGui.EndMenu()
				end

				if ImGui.Button('Clear##' .. Module.Name) then
					Module.SaveFile = ''
					Module.SavePath = ''
					Module.OpenFile = ''
					TextEditor:Clear()
				end
				ImGui.EndMenuBar()
			end

			if Module.OpenFile == '' then
				ImGui.Text('No File Loaded')
			elseif Module.OpenFile ~= '' and Module.SavePath == '' then
				Module.SavePath = Module.OpenFile
				ImGui.Text('File: ' .. Module.OpenFile)
			elseif Module.OpenFile ~= '' and Module.SavePath ~= '' and Module.SaveFile == '' then
				Module.SaveFile = Module.OpenFile
				ImGui.Text('File: ' .. Module.OpenFile)
			else
				ImGui.Text('File: ' .. Module.OpenFile)
			end

			Module.SaveFile = ImGui.InputText('##SaveFile', Module.SaveFile)
			if Module.SaveFile ~= '' and Module.SaveFile ~= Module.SavePath then
				Module.SavePath = Module.SaveFile
			end

			if ShowOpenFileSelector then
				DrawFileSelector()
				local file = io.open(SelectedFilePath, "r")
				if file then
					Module.OpenFile = SelectedFilePath
					local content = file:read("*a")
					file:close()
					TextEditor:LoadContents(content)
					Module.SavePath = ''
					Module.SaveFile = ''
				end
			end
			if ImGui.BeginChild('##TextEditorWidget', ImVec2(0, 0), ImGuiChildFlags.Border) then
				RenderEditor()
			end
			ImGui.EndChild()
		end

		ImGui.End()
	end
end

function Module.WriteFile(fullPath, output)
	mq.pickle(fullPath, {})
	local file = io.open(fullPath, "w")
	if file then
		file:write(output)
		file:close()
		printf("\ayFile \aw[\at%s\aw] \agSaved\aw!", fullPath)
	else
		printf("\arFailed to save file \aw[\at%s\aw]!", fullPath)
	end
end

function Module.Unload()
	mq.unbind('/txtedit')
end

function Module.MainLoop()
	if loadedExeternally then
		---@diagnostic disable-next-line: undefined-global
		if not MyUI_LoadModules.CheckRunning(Module.IsRunning, Module.Name) then
			Module.IsRunning = false
			return
		end
	end

	if mq.gettime() - drawTimerMS < 5 then
		return
	else
		drawTimerMS = mq.gettime()
	end
	editorWinFlags = TextEditorWindowFlags.None
	for _, data in ipairs(Module.Flags) do
		if data.value then
			editorWinFlags = bit32.bor(editorWinFlags, TextEditorWindowFlags[data.name])
		end
	end
	TextEditor.windowFlags = editorWinFlags
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
