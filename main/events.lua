local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
rematch.events = {}

local events = CreateFrame("Frame")

-- indexed by event name, ordered list of {module,callback} where module can be a "name" and rematch.name
-- is used as 'self' (or the given value if rematch[name] doesn't exist)
local register = {}

-- calls any registered callbacks in the order they were registered for the given event
local function runCallbacks(self,event,...)
    if register[event] then
        for _,info in ipairs(register[event]) do
            if type(info[2])=="function" then
                info[2](rematch[info[1]] or info[1],...)
            end
        end
    end
end
events:SetScript("OnEvent",runCallbacks)

-- raises an abitrary event for other parts of the addon to handle, such as REMATCH_PET_PICKED_UP
function rematch.events:Fire(event,...)
    runCallbacks(self,event,...)
end

-- finds the index of a module's callback in the registered event, if it exists
local function getModuleIndex(module,event)
    if register[event] then
        for index,info in pairs(register[event]) do
            if info[1]==module then
                return index
            end
        end
    end
end

-- any events flagged for removal will wait until all callbacks are handled for an event
local function cleanup()
    for event,info in pairs(register) do
        for i=#info,1,-1 do
            if info[i][2]=="remove" then
                tremove(info,i)
            end
        end
        if #info==0 then
            if not event:match("^REMATCH_") then
                events:UnregisterEvent(event)
            end
            register[event] = nil
        end
    end
end

-- registers an event for a module with a callback
function rematch.events:Register(module,event,callback)
    if not register[event] then
        register[event] = {}
    end
    local index = getModuleIndex(module,event)
    if not index then -- newly registered
        tinsert(register[event],{module,callback})
        if not event:match("^REMATCH_") then
            events:RegisterEvent(event)
        end
    elseif callback then -- already registered (or was flagged for remove), changing/restoring callback function
        register[event][index][2] = callback
    end
end

-- unregisters an event for a module
function rematch.events:Unregister(module,event)
    if register[event] then
        local index = getModuleIndex(module,event)
        if index then
            register[event][index][2] = "remove"
            rematch.timer:Start(0,cleanup)
        end
    end
end

-- for debugging
function rematch.events:GetRegister()
    return register
end