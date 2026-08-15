local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
rematch.odTable = {}

--[[
    "On Demand" tables (odTables) are intended to be used as cache tables for more computationally expensive
    data that's only infrequently used, such as collating pets in teams, getting sources for all species, etc.

    The goal is for a process to start the table (either by odTable:Start() or a key lookup), when a pre-
    defined function will populate the table (fillFunc), and then after 0.25 seconds (or C.ODTABLE_EXPIRE_TIME)
    it will wipe itself automatically.

    To create: local odTable = rematch.odTable:Create(fillFunc,isPersistent,expireTime)
        -- fillFunc (optional) is a function to fill the table when it's started.
        -- isPersistent (optional) is true if the table should never be wiped (very computationally expensive
        --   fillFuncs should set this to true, such as defining a sourceID for all species)
        -- expireTime (optional) is the time (in seconds) before stopping the table, or C.ODTABLE_EXPIRE_TIME
        --   if this value is undefined.

    When ready to use: odTable:Start() or get odTable.key
        -- if a fillFunc is defined it will first run the function before returning the key's value
        -- remember that pairs(odTable) isn't sufficient to trigger a lookup to start; use Start() then
    
    When done with the table: odTable:Stop() (or do nothing and let 0.25 seconds elapse)
        -- this will wipes the table so it's not sitting there for the rest of the session
]]

local lookup, startTable, stopTable

local allTables = {}

function rematch.odTable:Create(fillFunc,isPersistent,expireTime)
    local odTable = {}
    allTables[odTable] = {
        isActive = false,
        fillFunc = fillFunc,
        isPersistent = isPersistent,
        expireTime = expireTime or C.ODTABLE_EXPIRE_TIME,
        start = function(self) startTable(odTable) end,
        stop = function(self) stopTable(odTable) end
    }
    setmetatable(odTable,{__index=lookup})
    return odTable
end

-- lookup function when the table's key has a value of nil
function lookup(self,key)
    -- if odTable:Start() or odTable:Stop(), return the appropriate function
    local thisTable = allTables[self]
    if key=="Start" then
        return thisTable.start
    elseif key=="Stop" then
        return thisTable.stop
    end
    -- looking up a missing key now, start if not already started (possibly run fillFunc if defined)
    if not thisTable.isActive then
        thisTable.start(self)
    end
    -- if the table started, then this key may be filled in now, return its value (if it exists)
    return rawget(self,key)
end

-- called during lookup or via odTable:Start(), actives table, runs fillFunc if defined, and then
-- starts a timer to stop or expire the table
function startTable(self)
    local thisTable = allTables[self]
    if not thisTable.isActive then -- only activate if it wasn't activated before
        thisTable.isActive = true
        if thisTable.fillFunc then -- if table has a function to fill on start
            thisTable.fillFunc(self) -- run it
        end
    end
    -- if the table is not persistent, start a timer to stop it
    if not thisTable.isPersistent then
        rematch.timer:Start(thisTable.expireTime,thisTable.stop)
    end
    return self
end

-- called after expireTime has elapsed (or odTable:Stop()), wipes the table's contents and deactivates
function stopTable(self)
    local thisTable = allTables[self]
    wipe(self)
    thisTable.isActive = false
    rematch.timer:Stop(thisTable.stop) -- in case a Stop() call happened, don't let it wipe again after expiring
    return self
end
