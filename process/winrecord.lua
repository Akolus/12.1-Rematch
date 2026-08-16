local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.winrecord = {}

local playerForfeit -- true when the player forfeits a match

rematch.events:Register(rematch.winrecord,"PLAYER_LOGIN",function(self)
    self:Update() -- register/unregister based on settings
    hooksecurefunc(C_PetBattles,"ForfeitGame",function() playerForfeit=true end) -- watch for player forfeiting match
end)

function rematch.winrecord:Update()
    if settings.AutoWinRecord then
        rematch.events:Register(self,"PET_BATTLE_FINAL_ROUND",self.PET_BATTLE_FINAL_ROUND)
        rematch.events:Register(self,"PET_BATTLE_OPENING_START",self.PET_BATTLE_OPENING_START)
    else
        rematch.events:Unregister(self,"PET_BATTLE_FINAL_ROUND")
    end
end

local function teamAlive(player)
    local numPets = C_PetBattles.GetNumPets(player)
    for i=1,3 do
        local health = C_PetBattles.GetHealth(player,i)
        if health and health>0 and i<numPets then
            return true
        end
    end
    return false
end

function rematch.winrecord:PET_BATTLE_OPENING_START()
    playerForfeit = nil
end

function rematch.winrecord:PET_BATTLE_FINAL_ROUND(winner)
    self.wasInPVP = not C_PetBattles.IsPlayerNPC(Enum.BattlePetOwner.Enemy)

    if settings.AutoWinRecord and (not settings.AutoWinRecordPVPOnly or self.wasInPVP) and rematch.savedTeams:IsUserTeam(settings.currentTeamID) then
        local team = rematch.savedTeams[rematch.settings.currentTeamID]
        if not team.winrecord then
            team.winrecord = {}
        end
        -- when the player doesn't win (and even if opponent forfeits) winner appears to be 2.
        -- if player didn't win, see why they didn't win (could be a draw, could be one side forfeit)
        if winner~=Enum.BattlePetOwner.Ally then
            local allyAlive = teamAlive(Enum.BattlePetOwner.Ally)
            local enemyAlive = teamAlive(Enum.BattlePetOwner.Enemy)

            if allyAlive and enemyAlive then -- if both teams alive, someone forfeit tsk tsk
                if playerForfeit then
                    winner = Enum.BattlePetOwner.Enemy -- player forfeit match in progress, mark as loss
                else
                    winner = Enum.BattlePetOwner.Ally -- opponent likely forfeit match in progress, mark as win
                end
            elseif not allyAlive and not enemyAlive then
                winner = nil -- both teams dead, it was a draw
            else
                winner = Enum.BattlePetOwner.Enemy -- any other reason mark as a loss
            end
        end

        if winner==Enum.BattlePetOwner.Ally then
            team.winrecord.wins = (team.winrecord.wins or 0) + 1
        elseif winner==Enum.BattlePetOwner.Enemy then
            team.winrecord.losses = (team.winrecord.losses or 0) + 1
        else
            team.winrecord.draws = (team.winrecord.draws or 0) + 1
        end
        team.winrecord.battles = (team.winrecord.battles or 0)+ 1

    end
end