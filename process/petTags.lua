local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.petTags = {}

--[[
   A PetTag is a short string to describe a pet and its abilities.

   The variable-length string is made of 32-base numbers in this format:

   000 0 0000
   ||| | |
   ||| | +- speciesID
   ||| +--- breedID (0 to ignore, or 3-12)
   ||+----- ability 3 (0 to ignore, or 1-2 for ability, or rarity 1-4 for leveling queue tag)
   |+------ ability 2 (0 to ignore, or 1-2 for ability, or level 1-25 for leveling queue tag)
   +------- ability 1 (0 to ignore, or 1-2 for ability, or Q for leveling queue tag)

   Pet tags are stored in teams and used in import/export strings. When a petID ceases to be valid,
   or if a petID doesn't exist while importing a string, the tag is used to find the highest
   level/rarity of the described pet.

   This will remove the need for a sancutary, allow accurate backup/restore of teams, support
   breeds when exporting/importing teams, and solve the problem of Blizzard occasionally changing
   the abilities of pets.

   A few special case tags for export/import are prefixed by a Z:
      ZL:  Leveling pet
      ZI:  Ignored slot
      ZR0: Random pet (0 for any pet type, 1-A for a specific pet type)
      ZU:  Unknown

   For leveling queue:
   - To create a tag for a leveling queue pet: rematch.petTags:Create(petID,true)
   - The first character of the tag is always 'Q', the second is the level and third is rarity.
   - The preferred pet for the queue is the first pet at that level and rarity or higher, up to
     and including level 24.
]]

local tagInfo = {} -- reused for generating new tags or parsing tags

-- creates a tag for the given petID and (optional) abilities
-- petID can be a journal petID, speciesID, leveling, ignored or random pet
-- abilities can be abilityIDs or a number 0, 1 or 2
-- if first ability is 'Q', then this tag is for the leveling queue
function rematch.petTags:Create(petID,...)
   local petInfo = rematch.petInfo:Fetch(petID)
   -- add abilities to tag
   if petInfo.speciesID and petInfo.isValid then
      wipe(tagInfo)
      if select(1,...)=="Q" then -- this pet is for the queue
         tinsert(tagInfo,"Q")
         tinsert(tagInfo,rematch.utils:ToBase32(petInfo.level or 0))
         tinsert(tagInfo,rematch.utils:ToBase32(petInfo.rarity or 0))
      else -- this pet is not for the queue, populate abilities
         for i=1,3 do
            local abilityID = floor(select(i,...) or 0)
            if abilityID>=0 and abilityID<3 then -- abilityID is already a 0/1/2 value
               tinsert(tagInfo,abilityID)
            else -- abilityID is an actual abilityID, find out if it's 1 or 2 (or 0 if neither)
               if abilityID==petInfo.abilityList[i] then -- if first tier ability, it's a 1
                  tinsert(tagInfo,1)
               elseif abilityID==petInfo.abilityList[i+3] then -- if second tier, it's a 2
                  tinsert(tagInfo,2)
               else -- neither first or second tier ability, mark it 0 to ignore
                  tinsert(tagInfo,0)
               end
            end
         end
      end
      -- add breed to tag (or 0 if no breed)
      tinsert(tagInfo,rematch.utils:ToBase32(petInfo.breedID or 0))
      -- add speciesID to tag
      tinsert(tagInfo,rematch.utils:ToBase32(petInfo.speciesID))
      -- return final tag
      return table.concat(tagInfo,"")
   elseif petInfo.idType=="leveling" then
      return "ZL" -- leveling pet
   elseif petInfo.idType=="ignored" then
      return "ZI" -- ignored slot
   elseif petInfo.idType=="random" then
      return "ZR"..(rematch.utils:ToBase32(petInfo.petType or 0)) -- random pet
   elseif petInfo.idType=="unnotable" then
      return "ZN"..(rematch.utils:ToBase32(petInfo.npcID or 0)) -- unnotable pet
   end
   -- if we reached here, this pet can't be turned into a tag
   return "ZU" -- unknown
end

-- returns the three abilityIDs in the tag, if defined; abilityID 0 is undefined
function rematch.petTags:GetAbilities(tag)
   local speciesID = rematch.petTags:GetSpecies(tag)
   if speciesID then
      wipe(tagInfo)
      local petInfo = rematch.altInfo:Fetch(speciesID)
      for i=1,3 do
         local abilityOffset = tonumber(tag:sub(i,i),32)
         if abilityOffset==1 or abilityOffset==2 then
            tinsert(tagInfo,petInfo.abilityList[i+(abilityOffset-1)*3] or 0)
         else
            tinsert(tagInfo,0)
         end
      end
      return tagInfo[1],tagInfo[2],tagInfo[3]
   end
end

-- returns the species in the tag, if defined (may be nil for leveling, ignored or random)
function rematch.petTags:GetSpecies(tag)
   if type(tag)=="string" then
      return tonumber(tag:sub(5,-1),32)
   end
end

-- returns the best-matched collected petID from the tag, that's not one of the given notPetIDs,
-- or the speciesID or special petID (0, "ignored", "random:x") if not a collected pet
function rematch.petTags:FindPetID(tag,excludePetIDs)

   if type(tag)~="string" then
      return -- all tags are string, no petID
   elseif tag=="ZL" then
      return 0 -- this is a tag for a leveling slot
   elseif tag=="ZI" then
      return "ignored" -- this is a tag for an ignored slot
   elseif tag:match("^ZR%w") then
      return "random:"..tonumber(tag:match("^ZR(%w+)"),32)
   else -- this is a full tag
      local speciesID = rematch.petTags:GetSpecies(tag)
      if not speciesID then
         return
      end
      -- first see if there's either 0 or 1 copy of this speciesID
      local petInfo = rematch.petInfo:Fetch(speciesID)
      if not petInfo.isValid then
         return -- this is not a valid pet
      elseif petInfo.count==0 then
         return speciesID -- pet is not collected
      elseif petInfo.count==1 then
         local speciesPetIDs = rematch.roster:GetSpeciesPetIDs(speciesID)
         local petID = speciesPetIDs and speciesPetIDs[1]
         --local _,petID = C_PetJournal.FindPetIDByName(petInfo.speciesName)
         if petID and (petID~=noPetID1 and petID~=noPetID1 and petID~=noPetID1) then
            return petID -- pet found
         else
            return speciesID -- pet not found; should never get to this if count==1
         end
      end
      -- if we reached here, there's more than one pet of that speciesID owned; set up criteria for a search
      local minLevel = 0
      local minRarity = 0
      local maxLevel = 25
      local forQueue = false
      if tag:sub(1,1)=="Q" then -- if this is for the leveling queue, adjust level and rarity criteria
         minLevel = tonumber(tag:sub(2,2),32) or 0
         minRarity = tonumber(tag:sub(3,3),32) or 0
         maxLevel = 24
         forQueue = true
      end
      local breedID = tonumber(tag:sub(4,4),32) or 0
      local bestPetID
      local bestWeight = 0
      -- now look for a pet that's at least minLevel and minRarity and at most maxLevel
      for _,petID in ipairs(rematch.roster:GetSpeciesPetIDs(speciesID)) do
         if not excludePetIDs or not excludePetIDs[petID] then
            local petInfo = rematch.petInfo:Fetch(petID)
            if petInfo.level and petInfo.level>=minLevel and petInfo.level<=maxLevel and petInfo.rarity and petInfo.rarity>=minRarity and petInfo.canBattle then
               -- if we reached here, this petID is not an excluded pet and it also meets the level and rarity requirements
               -- now calculate a weight of this pet and replace the bestPetID if the weight is better

               -- if breedID is used and it matches, weight of 1; otherwise 0
               local breedWeight = (breedID~=0 and petInfo.breedID==breedID) and 1 or 0
               -- for queue, we want the minimum level; for non-queue, we want the maximum level
               local levelWeight = forQueue and (25-petInfo.level) or petInfo.level
               -- rarity is the lowest priority
               local rarityWeight = petInfo.rarity or 0

               -- if this is for the queue or prioritizing breeds on import, give breed the highest weight
               local weight
               if forQueue or settings.PrioritizeBreedOnImport then -- bllr
                  weight = breedWeight*1000 + levelWeight*10 + rarityWeight
               else -- llbr
                  weight = levelWeight*100 + breedWeight*10 + rarityWeight
               end

               -- if this pet's weight is greater than best so far, this is current pet best
               if weight>bestWeight then
                  bestPetID = petID
                  bestWeight = weight
               end
            end
         end
      end
      -- return the best petID found, or the speciesID if none found
      return bestPetID or speciesID
   end

end
