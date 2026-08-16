local _,rematch = ...
rematch.timer = {}

-- rematch.timer:Start(3,myfunc) will wait 3 seconds to run myfunc, restarting the clock if called again.
-- Note: if an inline function is used (s.timer:Start(3,function() print("hi") end)), then each call will
-- start a new timer; it uses the function as a key to which timer to restart

local running = {} -- ordered list, the current functions waiting to run
local isRunning = {} -- lookup by function, whether this timer is running
local times = {} -- lookup by function, the duration to wait before running the function
local arg1s = {} -- lookup by function, the first argument of the function (usually self)
local arg2s = {} -- lookup by function, the second argument (making these separate to reduce garbage)
local arg3s = {} -- lookup by function, the third argument

local frame = CreateFrame("Frame")
frame:Hide()

-- a function waiting to run will have its duration reset when the timer is restarted
function rematch.timer:Start(duration,func,arg1,arg2,arg3)
    assert(type(func)=="function" and type(duration)=="number","Invalid timer start.")
    isRunning[func] = true
    times[func] = duration
    arg1s[func] = arg1
    arg2s[func] = arg2
    arg3s[func] = arg3
    if not tContains(running,func) then
        tinsert(running,func)
    end
    frame:Show()
end

-- stops the timer for a waiting function
function rematch.timer:Stop(func)
    if isRunning[func] then
        isRunning[func] = nil
        for i=#running,1,-1 do
            if running[i]==func then
                tremove(running,i)
                isRunning[func] = nil
            end
        end
    end
end

-- every frame, run through each running timer and see if it's ready to run, and run if so
frame:SetScript("OnUpdate",function(self,elapsed)
    local tick = false

    for i=#running,1,-1 do
        local func = running[i]
        if func and times[func] then
            times[func] = times[func] - elapsed
            if times[func] < 0 then
                tremove(running,i)
                isRunning[func] = nil
                func(arg1s[func],arg2s[func],arg3s[func])
            end
            tick = true
        end
    end

    if not tick then
        self:Hide()
    end
end)

-- returns true/false if the given function is on a timer waiting to run
function rematch.timer:IsRunning(func)
    return isRunning[func] and true or false
end
