local Module   = { _version = '0.1a', _author = 'Derple', } -- borrowed from the RGMercs Thanks Derple!
Module.__index = Module

---@param module_list table
---@return any
function Module.loadAll(module_list)
	local modules = {}
	for _, module in ipairs(module_list) do
		local moduleName = require("modules." .. module:lower())
		if moduleName then
			modules[module] = moduleName
		end
	end

	local newModule = setmetatable(modules, Module)
	return newModule
end

---@param module_name string
---@return any
function Module.load(module_name)
	local moduleName = require("modules." .. module_name:lower())
	if moduleName then
		return moduleName
	end
	return nil
end

return Module
