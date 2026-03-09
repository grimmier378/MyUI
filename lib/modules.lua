local Module = { _version = '0.1a', _author = 'Derple, Grimmier', } -- Original borrowed from the RGMercs Thanks Derple! <3 then I hacked it apart.
local mq = require 'mq'

---@class module

--- Load a Module
---@param path string Path to the Module
---@return module|nil @The loaded Module or nil if it failed to load
local function loadModule(path)
    -- Macroquest wraps lua's dofile such that on error it returns a string with a stack trace
    local result = dofile(path)
    if not result then return nil end
    if type(result) == "string" and result:find("stack traceback") then
        MyUI.Utils.PrintOutput(nil, nil, "\arError loading %s:\n%s", path, result)
        return nil
    end
    return result
end

---@param module_list table
---@return module newModule A table of loaded Modules with the Module class as its metatable
function Module.loadAll(module_list)
    local modules = {}
    local count = 0
    if #module_list >= 0 then
        -- load mychat first to avoid spamming the main console on load
        for _, module in ipairs(module_list) do
            if module:lower() == 'mychat' then
                local moduleName = mq.luaDir .. "/MyUI/modules/" .. module:lower() .. ".lua"
                Module.checkExternal(module)
                modules[module] = loadModule(moduleName)
                count = count + 1
                MyUI.InitPctComplete = ((count / #module_list) * 100)
                MyUI.CurLoading = module
                mq.delay(1)
                break
            end
        end
        for _, module in ipairs(module_list) do
            if module:lower() == 'mychat' then
                -- skip it since we already loaded it
                goto continue
            end
            local moduleName = mq.luaDir .. "/MyUI/modules/" .. module:lower() .. ".lua"
            Module.checkExternal(module)
            modules[module] = loadModule(moduleName)
            count = count + 1
            MyUI.InitPctComplete = ((count / #module_list) * 100)
            MyUI.CurLoading = module
            mq.delay(1)

            ::continue::
        end
    else
        MyUI.InitPctComplete = 100
    end

    local newModule = setmetatable(modules, Module)
    return newModule
end

--- Unload a Module
---@param module_name string Name of the Module
function Module.unload(module_name)
    if MyUI.Modules[module_name] and MyUI.Modules[module_name].ActorMailBox then
        MyUI.Modules[module_name].ActorMailBox = nil
    end
    if module_name:lower() == 'mychat' then
        MyUI.MyChatLoaded  = false
        MyUI.MyChatHandler = nil
        MyUI.Utils.PrintOutput(nil, nil, "\ayMyChat\ao Unloaded\at Defaulting Output to \ayMain Console")
    end

    MyUI.Modules[module_name] = nil
end

--- Load a Module from cli
---@param module_name string Path to the Module
---@return module|nil @The loaded Module or nil if it failed to load
function Module.load(module_name)
    Module.checkExternal(module_name)
    local modPath = mq.luaDir .. "/MyUI/modules/" .. module_name:lower() .. ".lua"
    local moduleName = loadModule(modPath)
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
        MyUI.TempSettings.ModuleChanged = true
        MyUI.TempSettings.ModuleName = module_name
        MyUI.TempSettings.ModuleEnabled = false
        return false
    end
    return true
end

return Module
