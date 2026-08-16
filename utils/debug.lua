local _,rematch = ...
local L = rematch.localization
rematch.debug = {}

local debugTypes = {
    error = true,
    layout = false,
    savedvar = false,
    journal = false,
    roster = false,
    event = true,
    updates = true,
    teams = false,
}

rematch.debug.times = {} -- used to log times
local profileStop

-- returns where the calling function was called from
function rematch.debug:CallerID()
    local where = (debugstack():match(".-\n.-\n.-\n.-\\AddOns\\.-\\(.-:%d+.-)\n") or ""):gsub("\"]","")
    if where:len()==0 then
        where = (debugstack():match(".-\n.-\n.-\\AddOns\\.-\\(.-:%d+.-)\n") or ""):gsub("\"]","")
    end
    return where:len()>0 and where or debugstack()
end


function rematch.debug:Write(debugType,...)
    if debugTypes[debugType] then
        print(...)
    end
end

-- returns the parentKey under rematch of the given frame
function rematch.debug:GetModuleName(module)
    for k,v in pairs(rematch) do
        if module==v then
            return k
        end
    end
    return module
end

-- call this to wrap all update functions to print "Updating <parentKey>"
local updateHooks
function rematch.debug:MonitorUpdates()
    for k,v in pairs(rematch) do
        if type(v)=="table" and type(v.Update)=="function" then
            local o = v.Update
            rematch[k].Update = function(self,...)
                rematch.debug:Write("updates","Updating",k)
                return o(self,...)
            end
        end
    end
end

function rematch.debug:StartProfile()
    profileStop = debugprofilestop()
end

function rematch.debug:Profile(name)
    rematch.debug.times[name] = (rematch.debug.times[name] or 0) + (debugprofilestop()-profileStop)
    profileStop = debugprofilestop()
end