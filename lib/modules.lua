local Module = { _version = '0.1a', _author = 'Derple', } -- borrowed from the RGMercs Thanks Derple!
local mq = require 'mq'
---@param module_list table
---@return any
function Module.loadAll(module_list)
	local modules = {}
	for _, module in ipairs(module_list) do
		local moduleName = mq.luaDir .. "/MyUI/modules/" .. module:lower() .. ".lua"
		-- if moduleName then
		modules[module] = dofile(moduleName)
		-- end
	end

	local newModule = setmetatable(modules, Module)
	return newModule
end

function Module.unload(module_name)
	-- Check if the module has an actor mailbox to unregister
	if MyUI_Modules[module_name] and MyUI_Modules[module_name].ActorMailBox then
		MyUI_Modules[module_name].ActorMailBox = nil
	end
	-- Remove the module from package.loaded
	package.loaded["modules." .. module_name:lower()] = nil
	MyUI_Modules[module_name] = nil
end

-- Load module and register actors
function Module.load(module_name)
	package.loaded["modules." .. module_name:lower()] = nil
	local modPath = mq.luaDir .. "/MyUI/modules/" .. module_name:lower() .. ".lua"
	local moduleName = dofile(modPath)
	if moduleName then
		return moduleName
	end
	return nil
end

return Module
