local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
rematch.main = {}

local inWorld -- returned by IsPlayerInWorld; true/false if player is in the world (not in a loading screen)

rematch.events:Register(rematch.main,"PLAYER_LOGIN",function(self)

    -- Rematch 4.x to Rematch 5.x upgrade should be handled before any other PLAYER_LOGIN
    -- (rematch.main is the first to register for PLAYER_LOGIN from toc)
    rematch.convert:ConversionCheck()

    hooksecurefunc(C_PetJournal,"SetAbility",function(slotIndex,spellIndex,petSpellID)
        rematch.timer:Start(0,rematch.main.FireAbilitiesChanged)
    end)

    hooksecurefunc(C_PetJournal,"SetPetLoadOutInfo",function(slotIndex,petID)
        rematch.timer:Start(0,rematch.main.FireLoadoutsChanged)
    end)

    hooksecurefunc(C_PetJournal,"PickupPet",function(petID)
        rematch.events:Fire("REMATCH_PET_PICKED_UP_ON_CURSOR",petID)
        rematch.events:Register(rematch.main,"CURSOR_CHANGED",rematch.main.CURSOR_CHANGED)
    end)

    rematch.events:Register(self,"PLAYER_LEAVING_WORLD",self.PLAYER_LEAVING_WORLD)
    rematch.events:Register(self,"PLAYER_ENTERING_WORLD",self.PLAYER_ENTERING_WORLD)
    rematch.events:Register(self,"PET_BATTLE_CLOSE",self.PET_BATTLE_CLOSE)
    rematch.events:Register(self,"UNIT_SPELLCAST_SUCCEEDED",self.UNIT_SPELLCAST_SUCCEEDED)

	-- add launcher button for LDB if it exists
	local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1",true)
	if ldb then
	  ldb:NewDataObject("Rematch",{ type="launcher", icon="Interface\\Icons\\PetJournalPortrait", iconCoords={0.075,0.925,0.075,0.925}, tooltiptext=L["Toggle Rematch"], OnClick=rematch.frame.Toggle	})
	end

end)

function rematch.main:CURSOR_CHANGED()
    if not rematch.utils:IsPetOnCursor() then
        rematch.events:Fire("REMATCH_PET_DROPPED_FROM_CURSOR")
        rematch.events:Unregister(rematch.main,"CURSOR_CHANGED")
    end
end

-- called a frame after abilities changed (in case multiple abilities changing at once)
function rematch.main:FireAbilitiesChanged()
    rematch.events:Fire("REMATCH_ABILITIES_CHANGED")
end

-- called a frame after loadouts changed (in case multiple loadouts changing at once)
function rematch.main:FireLoadoutsChanged()
    rematch.events:Fire("REMATCH_LOADOUTS_CHANGED")
end

-- returns true if player is not in a loading screen
function rematch.main:IsPlayerInWorld()
    return inWorld
end

function rematch.main:PLAYER_ENTERING_WORLD()
    inWorld = true
end

function rematch.main:PLAYER_LEAVING_WORLD()
    inWorld = false
end

-- post-battle processing: for load healthiest pet and also to process queue
function rematch.main:ProcessHealthChange()
    rematch.main:StopPostBattleTimer()
    if rematch.settings.LoadHealthiest and rematch.settings.LoadHealthiestAfterBattle then
        rematch.loadTeam:AssertHealthiestPet()
    end
    rematch.queue:Process()
end

-- this usually fires in pairs; begin watching for PET_JOURNAL_LIST_UPDATE (health/xp changes) for a little while
-- to do a bit of post-battle processing
function rematch.main:PET_BATTLE_CLOSE()
    rematch.events:Register(self,"PET_JOURNAL_LIST_UPDATE",self.PET_JOURNAL_LIST_UPDATE)
    rematch.timer:Start(C.POST_BATTLE_TIMER,self.StopPostBattleTimer,self)
end

-- fired in the POST_BATTLE_TIMER window (a few seconds), presumably pet health/xp changed
function rematch.main:PET_JOURNAL_LIST_UPDATE()
    rematch.events:Unregister(self,"PET_JOURNAL_LIST_UPDATE")
    rematch.timer:Start(C.QUEUE_PROCESS_WAIT,rematch.main.ProcessHealthChange)
end

-- stops watching for PET_JOURNAL_LIST_UPDATE; called when a pet is slotted too
function rematch.main:StopPostBattleTimer()
    rematch.events:Unregister(self,"PET_JOURNAL_LIST_UPDATE")
end

-- when revive or bandage used to heal pets, trigger a LoadHealthiest bit (if enabled) and process queue
function rematch.main:UNIT_SPELLCAST_SUCCEEDED(unit,cast,spellID)
    if unit=="player" and (spellID==C.REVIVE_SPELL_ID or spellID==C.BANDAGE_SPELL_ID) then
        rematch.timer:Start(C.QUEUE_PROCESS_WAIT,rematch.main.ProcessHealthChange)
    end
end
