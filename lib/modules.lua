local Module   = { _version = '0.1a', _author = 'Derple', }
Module.__index = Module

---@param module_list table
---@return any
function Module.load(module_list)
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

function Module.Render(module_list)
	local modules = {}
	for _, module in ipairs(module_list) do
		local moduleName = require("modules." .. module:lower())
		if moduleName then
			modules[module] = moduleName
		end
	end
end

-- function Module.GetModuleList()
-- 	return Module.modules
-- end

-- function Module.GetModuleOrderedNames()
-- 	return Module.module_order
-- end

-- ---@param m string
-- function Module.GetModule(m)
-- 	for name, module in pairs(Module.modules) do
-- 		if name == m then
-- 			return module
-- 		end
-- 	end
-- 	return nil
-- end

-- function Module.ExecModule(m, fn, ...)
-- 	for name, module in pairs(Module.modules) do
-- 		if name:lower() == m:lower() then
-- 			return module[fn](module, ...)
-- 		end
-- 	end
-- 	MyUI_Utils:PrintOutput("\arModule. \at%s\ar not found!", m)
-- end

-- function Module.ExecAll(fn, ...)
-- 	local ret = {}
-- 	for _, name in pairs(Module.module_order) do
-- 		local startTime = os.clock() * 1000
-- 		local module = Module.modules[name]
-- 		ret[name] = module[fn](module, ...)

-- 		if fn == "GiveTime" then
-- 			if Module.modules.Perf then
-- 				Module.modules.Perf:OnFrameExec(name, (os.clock() * 1000) - startTime)
-- 			end
-- 		end
-- 	end

-- 	return ret
-- end

return Module
