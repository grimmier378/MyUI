local Module = { _version = '0.1a', _author = 'Derple, Grimmier', } -- Original borrowed from the RGMercs Thanks Derple! <3 then I hacked it apart.
local mq = require 'mq'


---@param module_list table
---@return any
function Module.loadAll(module_list)
	local modules = {}
	local count = 0
	for _, module in ipairs(module_list) do
		local moduleName = mq.luaDir .. "/MyUI/modules/" .. module:lower() .. ".lua"
		Module.checkExternal(module)
		modules[module] = dofile(moduleName)
		count = count + 1
		MyUI_InitPctComplete = ((count / #module_list) * 100)
		MyUI_CurLoading = "Loading Module: " .. module .. " .."
	end

	local newModule = setmetatable(modules, Module)
	return newModule
end

function Module.unload(module_name)
	if MyUI_Modules[module_name] and MyUI_Modules[module_name].ActorMailBox then
		MyUI_Modules[module_name].ActorMailBox = nil
	end
	if module_name:lower() == 'mychat' then
		MyUI_MyChatLoaded  = false
		MyUI_MyChatHandler = nil
		MyUI_Utils.PrintOutput(nil, nil, "\ayMyChat\ao Unloaded\at Defaulting Output to \ayMain Console")
	end
	MyUI_Modules[module_name] = nil
end

function Module.load(module_name)
	Module.checkExternal(module_name)
	package.loaded["modules." .. module_name:lower()] = nil
	local modPath = mq.luaDir .. "/MyUI/modules/" .. module_name:lower() .. ".lua"
	local moduleName = dofile(modPath)
	if moduleName then
		return moduleName
	end
	return nil
end

function Module.checkExternal(module_name)
	local status = mq.TLO.Lua.Script(module_name:lower()).Status() or ''
	if status == 'RUNNING' then
		mq.cmdf('/lua stop %s', module_name:lower())
		mq.delay(5)
	end
end

function Module.CheckRunning(is_running, module_name)
	if is_running == nil then return false end
	if not is_running then
		MyUI_TempSettings.ModuleChanged = true
		MyUI_TempSettings.ModuleName = module_name
		MyUI_TempSettings.ModuleEnabled = false
		return false
	end
	return true
end

return Module
