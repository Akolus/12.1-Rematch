local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.utils = {}

--[[ print utils ]]

-- use instead of print to prefix Rematch before the text
function rematch.utils:Write(...)
    print(format("%sRematch:\124r",C.HEX_GOLD),...)
end

-- for all chat frames registered for system messages, send the text with the system color
function rematch.utils:WriteSystem(text)
    for i=1,NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        if frame and frame:IsEventRegistered("CHAT_MSG_SYSTEM") then
            local color = C_ChatInfo.GetColorForChatType("SYSTEM")
            frame:AddMessage(text,color.r,color.g,color.b)
        end
    end
end

--[[ string utils ]]

-- DesensitizedText doesn't work for Russian or German clients; use the less efficient string:lower() compare
local locale = GetLocale()
local useAltSensitivity = locale=="ruRU" or locale=="deDE"
local useUnaccent = locale=="frFR" or locale=="deDE" or locale=="itIT" or locale=="esES" or locale=="esMX" or locale=="ptPT" or locale=="ptBR"

local accentMap = {
    ["à"]="a", ["á"]="a", ["â"]="a", ["ã"]="a", ["ä"]="a", ["ç"]="c", ["è"]="e",
    ["é"]="e", ["ê"]="e", ["ë"]="e", ["ì"]="i", ["í"]="i", ["î"]="i", ["ï"]="i",
    ["ñ"]="n", ["ò"]="o", ["ó"]="o", ["ô"]="o", ["õ"]="o", ["ö"]="o", ["ù"]="u",
    ["ú"]="u", ["û"]="u", ["ü"]="u", ["ý"]="y", ["ÿ"]="y", ["À"]="A", ["Á"]="A",
    ["Â"]="A", ["Ã"]="A", ["Ä"]="A", ["Ç"]="C", ["È"]="E", ["É"]="E", ["Ê"]="E",
    ["Ë"]="E", ["Ì"]="I", ["Í"]="I", ["Î"]="I", ["Ï"]="I", ["Ñ"]="N", ["Ò"]="O",
    ["Ó"]="O", ["Ô"]="O", ["Õ"]="O", ["Ö"]="O", ["Ù"]="U", ["Ú"]="U", ["Û"]="U",
    ["Ü"]="U", ["Ý"]="Y"
}

-- DesensitizeText returns text in a literal (magic characters escaped) and case-insensitive format
local function literal(c) return "%"..c end
local function caseinsensitive(c) return format("[%s%s]",c:lower(),c:upper()) end
local function unaccent(c) return accentMap[c] or c end

function rematch.utils:DesensitizeText(text)
	if type(text)=="string" then
        text = text:trim()
        if useUnaccent and text:match("[\128-\244]") then
            text = text:gsub("[%z\1-\127\194-\244][\128-\191]*",unaccent)
        end
		if useAltSensitivity then -- for ruRU/deDE clients use the lower case text
			return text:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]",literal):lower()
		else
			return text:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]",literal):gsub("%a",caseinsensitive)
		end
	else
        return ""
    end
end

-- returns true if any ... matches the given pattern
-- when doing a case-insensitive match, use this instead of a direct match; so it can handle ruRU/deDE matches
function rematch.utils:match(pattern,...)
	if type("pattern")=="string" then
		for i=1,select("#",...) do
			local candidate = select(i,...)
			if type(candidate)=="string" then
                if useUnaccent and candidate:match("[\128-\244]") then
                    candidate = candidate:gsub("[%z\1-\127\194-\244][\128-\191]*",unaccent)
                end
				if useAltSensitivity and candidate:lower():match(pattern) then
					return true
				elseif candidate:match(pattern) then
					return true
				end
			end
		end
	end
	return false
end

-- using a 256x256 texture divided into 32px squares 8 across and 8 down, return the string to represent a badge at the given index (0-based)
function rematch.utils:GetBadgeAsText(index,size,borderless)
    size = size or 0 -- default to 0 for size
    local left = index%8*32
    local top = floor(index/8)*32
    local file = format("Interface\\AddOns\\Rematch\\textures\\badges-%s",borderless and "borderless" or "borders")
    return format("\124T%s:%d:%d:0:0:256:256:%d:%d:%d:%d\124t",file,size,size,left,left+32,top,top+32)
end

-- takes a petType (1-10) and returns a text string for the icon (20x20) with the thin circle border
function rematch.utils:PetTypeAsText(petType,size,borderless)
    if not size then
        size = 16
    end
	local pattern = "\124TInterface\\PetBattles\\PetIcon-%s:%d:%d:0:0:128:256:102:63:129:168\124t"
    if borderless then
        pattern = "\124TInterface\\Icons\\Pet_Type_%s:%d:%d\124t"
    end
	local suffix = PET_TYPE_SUFFIX[petType]
	return suffix and format(pattern,suffix,size,size) or "?"
end

-- converts 64x64 icons (like in Interface\Icons) to text
function rematch.utils:IconAsText(icon,size)
    if not size then
        size = 16
    end
    return format("\124T%s:%d:%d:0:0:64:64:5:59:5:59\124t",icon,size,size)
end

-- for PetTags and and TeamStrings to store base-32 numbers in strings
local digitsOut = {} -- to avoid garbage creation, this is reused to build a 32-base number
local digitsIn = "0123456789ABCDEFGHIJKLMNOPQRSTUV"
-- convert number to base 32: VV = 1023
function rematch.utils:ToBase32(number)
	number = tonumber(number)
	if number then
		wipe(digitsOut)
		number = math.abs(floor(number))
		repeat
			local digit = (number%32) + 1
			number = floor(number/32)
			tinsert(digitsOut,1,digitsIn:sub(digit,digit))
		until number==0
		return table.concat(digitsOut,"")
	end
end

-- converts a 6-digit hex like FFD200 to an r,g,b value, or white 0.9,0.9,0.9 if not a valid hex value
function rematch.utils:HexToRGB(hex)
    if not hex or hex:len()~=6 then
        return 0.9,0.9,0.9
    else
        local r = tonumber(hex:sub(1,2),16)/255
        local g = tonumber(hex:sub(3,4),16)/255
        local b = tonumber(hex:sub(5,6),16)/255
        return r or 0.9,g or 0.9,b or 0.9
    end
end

-- for "type:id" ids (team:0, target:0, group:0, header:0, placeholder:0) returns the type of the id
function rematch.utils:GetIDType(id)
    if type(id)=="string" then
        return (id:match("(.-):.+"))
    end
end

-- returns the name of a marker (1 to 8) colored for that marker
function rematch.utils:GetFormattedMarkerName(marker)
    if marker and C.MARKER_COLORS[marker] and _G["RAID_TARGET_"..marker] then
        return "\124cff"..C.MARKER_COLORS[marker]..(settings.PetMarkerNames[marker] or _G["RAID_TARGET_"..marker])
    end
end

-- returns the name of the teamID formatted with color codes
function rematch.utils:GetFormattedTeamName(teamID)
    local team = rematch.savedTeams[teamID]
    if team then
        local group = rematch.savedGroups[team.groupID]
        local color = group and (settings.ColorTeamNames and group.color) or "E8E8E8"
        return format("\124cff%s%s\124r",color,team.name or "")
    end
end

-- returns the name of the groupID formatted with color codes
function rematch.utils:GetFormattedGroupName(groupID)
    local group = rematch.savedGroups[groupID]
    if group then
        local color = group.color or "FFD200"
        return format("\124cff%s%s\124r",color,group.name or "")
    end
end

-- returns the name of the target with a 0.9,0.9,0.9 color
function rematch.utils:GetFormattedTargetName(targetID)
    local name = rematch.targetInfo:GetNpcName(targetID)
    if name==C.CACHE_RETRIEVING then -- if name isn't cached yet, caller will want to try again later
        return name
    else
        local expansionID = rematch.targetInfo:GetExpansionID(targetID)
        local color = expansionID and (settings.ColorTargetNames and C.EXPANSION_COLORS[expansionID]) or "E8E8E8"
        return format("\124cff%s%s\124r",color,name or "")
    end
end

-- returns the name of the target header with a 1,0.82,0 color
function rematch.utils:GetFormattedHeaderName(headerID)
    local name = rematch.targetInfo:GetHeaderName(headerID)
    local expansionID = rematch.targetInfo:GetHeaderExpansionID(headerID)
    local color = expansionID and C.EXPANSION_COLORS[expansionID] or "FFD200"
    return format("\124cff%s%s\124r",color,name or "")
end

-- returns the placeholder text with a 0.5,0.5,0.5 color (placeholderID is either actual text to display or a numeric groupID)
function rematch.utils:GetFormattedPlaceholderName(placeholderID)
    local color = "808080"
    local name = placeholderID -- placeholders can be the text they display, like "No recent targets"
    local groupID = tonumber(placeholderID)
    if groupID then -- but if it's a number then it means it's a placeholder for a groupID
        if groupID==C.FAVORITE_TEAMS_GROUPID then
            name = L["No favorite teams"]
        elseif groupID==C.UNGROUPED_TEAMS_GROUPID then
            name = L["No ungrouped teams"]
        else -- a user-created group
            name = L["No teams in this group"]
        end
    end
    return format("\124cff%s%s\124r",color,name)
end

function rematch.utils:GetFormattedExpansionName(expansionID)
    local color = expansionID and C.EXPANSION_COLORS[expansionID] or "E8E8E8"
    return format("\124cff%s%s\124r",color,_G["EXPANSION_NAME"..expansionID] or UNKNOWN)
end

function rematch.utils:GetFormattedActionName(actionID)
    if actionID=="cage" then
        return L["Cage Pet (Without Confirmation)"]
    elseif actionID=="favorite" then
        return L["Set/Remove Favorite"]
    elseif actionID=="leveling" then
        return L["Add/Remove From Leveling Queue"]
    elseif actionID=="marker:0" then
        return L["Remove Pet Tags"]
    elseif type(actionID)=="string" then
        local markerIndex = actionID:match("marker:(.+)")
        if tonumber(markerIndex) then
            return format(L["Set/Remove Pet Tag: %s"],rematch.utils:GetFormattedMarkerName(tonumber(markerIndex)))
        end
    end
    return actionID
end

-- if dim is true, set text to 0.5,0.5,0.5; otherwise set to r,g,b (or 1,0.82,0 if none given)
function rematch.utils:SetDimText(fontstring,dim,r,g,b)
    if not r then
        r,g,b = 1,0.82,0
    end
    if dim then
        fontstring:SetTextColor(0.5,0.5,0.5)
    else
        fontstring:SetTextColor(r,g,b)
    end
end

--[[ table utils ]]

-- does a tinsert(table,value) only if value doesn't exist in the given ordered table
function rematch.utils:TableInsertDistinct(otable,value,noNils)
    if value==nil and noNils then
        return
    end
    for _,candidate in ipairs(otable) do
        if candidate==value then
            return -- value already in table, leave
        end
    end
    -- not found, safe to insert
    tinsert(otable,value)
end

-- removes all given values from the given ordered table
function rematch.utils:TableRemoveByValue(otable,value)
    for i=#otable,1,-1 do
        if otable[i]==value then
            tremove(otable,i)
        end
    end
end

-- moves the value in the otable to come after the 'after' value (or top of list if after is C.TOP_OF_LIST)
function rematch.utils:TableMoveValueAfter(otable,value,after)
    if value==after then -- can't make a value come after itself
        return -- it's not moving, already done
    end
    rematch.utils:TableRemoveByValue(otable,value) -- remove the value first
    if after==C.TOP_OF_LIST then
        table.insert(otable,1,value) -- insert to top of list
        return -- and leave
    end
    for index,candidate in ipairs(otable) do
        if candidate==after then -- found the 'after' that value is to come after
            table.insert(otable,index+1,value)
            return
        end
    end
end

-- returns the index the given value can be found in the given ordered table
function rematch.utils:GetIndexByValue(otable,value)
    for index,candidate in ipairs(otable) do
        if candidate==value then
            return index
        end
    end
end

-- returns the size of utable, an unordered table. if utable is a function it will use it as an iterator
function rematch.utils:GetSize(utable)
    local count = 0
    if type(utable)=="function" then
        for id in utable() do
            count = count + 1
        end
    elseif type(utable)=="table" then
        for id in pairs(utable) do
            count = count + 1
        end
    end
    return count
end

-- compares two values and returns true if the same; if tables it does a deep compare to return true if the two tables have the same content
-- if forTeams is true, it will ignore the teamID so two teams can be compared (teamID will always be different if not same team)
function rematch.utils:AreSame(utable1,utable2,forTeams)
    local utype1 = type(utable1)
    local utype2 = type(utable2)
    if utype1~=utype2 then
        return false -- not the same types, not equal
    elseif utype1~="table" then
        return utable1==utable2 -- same types but not tables, return whether equal
    end
    -- here both utables are definitely tables
    for k,v in pairs(utable1) do
        if forTeams and k=="teamID" then
            -- for teams don't compare teamIDs
        elseif forTeams and k=="name" then
            if not self:AreSame((v or ""):lower(),(utable2[k] or ""):lower()) then
                return false -- case insensitive compare on team names
            end
        elseif not self:AreSame(v,utable2[k]) then
            return false
        end
    end
    for k,v in pairs(utable2) do
        if forTeams and k=="teamID" then
            -- for teams don't compare teamIDs
        elseif forTeams and k=="name" then
            if not self:AreSame((v or ""):lower(),(utable1[k] or ""):lower()) then
                return false -- case insensitive compare on team names
            end
        elseif not self:AreSame(v,utable1[k]) then
            return false
        end
    end
    -- if we reached here, then both tables are the same
    return true
end

-- returns true if value equals something in the passed varargs
function rematch.utils:AnyEquals(value,...)
    for i=1,select("#",...) do
        if value and value==select(i,...) then
            return true
        end
    end
    return false
end

--[[ UIJustChanged utils ]]

-- at times, we don't want to show tooltips or cards if the UI was recongifured, a dialog dismissed, a menu
-- chosen, etc. and an OnEnter happens because an element appears under the mouse. So any time elements may come
-- and go, call rematch.utils:SetUIJustChanged(); and in the tooltip or card functions, call
-- rematch.utils:GetUIJustChanged() to determine whether to ignore the OnEnter
local uiJustChanged = false
function rematch.utils:SetUIJustChanged()
    uiJustChanged = true
    rematch.timer:Start(0.05,rematch.utils.ResetUIJustChanged)
end

function rematch.utils:ResetUIJustChanged()
    uiJustChanged = false
end

function rematch.utils:GetUIJustChanged()
    return uiJustChanged
end

--[[ anchoring utils ]]

-- returns the corner a frame is closest to a corner of reference (and its opposite corner)
-- (if frame is closest to TOPRIGHT corner of reference, returns "TOPRIGHT","BOTTOMLEFT")
function rematch.utils:GetCorner(frame,reference)
    local fx,fy = frame:GetCenter()
    local fScale = frame:GetEffectiveScale()
    local rx,ry = reference:GetCenter()
    local rScale = reference:GetEffectiveScale()
    fx = fx*fScale -- adjust for potentially different scales
    fy = fy*fScale
    rx = rx*rScale
    ry = ry*rScale
	ry=ry*1.2 -- raise y threshold up 20% of reference to favor anchoring upwards
	if fx<rx and fy<ry then -- bottomleft
		return "BOTTOMLEFT","TOPRIGHT"
	elseif fx<rx and fy>ry then -- topleft
		return "TOPLEFT","BOTTOMRIGHT"
	elseif fx>rx and fy>ry then -- topright
		return "TOPRIGHT","BOTTOMLEFT"
	else -- bottomright (or dead center)
		return "BOTTOMRIGHT","TOPLEFT"
	end
end

-- when anchoring stuff with GetCorner, it's not enough to anchor to an opposite corner of
-- the frame being anchored to, since in a list of many buttons the anchor can change
-- mid-list. so this function will look for the reference
function rematch.utils:GetFrameForReference(startingFrame)
    local frame = startingFrame
    while frame do
        frame = frame:GetParent()
        if frame and (frame==rematch.frame or frame==rematch.dialog) then
            return frame
        end
    end
    -- if we reached here, no major references were an ancestor of startingFrame,
    -- use the startingFrame to reference to
    return startingFrame
end

-- currentMenuID is for dropdowns and comboboxes, returns a new incrementing unique number so each menu instance is unique
local currentMenuID = 0
function rematch.utils:GetNewMenuID()
    currentMenuID = currentMenuID + 1
    return currentMenuID
end

-- -- making our own copy of ITEM_QUALITY_COLORS to make the rare blue a bit brighter
-- local rarityColors = CopyTable(ITEM_QUALITY_COLORS)
-- rarityColors[Enum.ItemQuality.Rare].r = 0.125 -- min(1,rarityColors[Enum.ItemQuality.Rare].r+0.125)
-- rarityColors[Enum.ItemQuality.Rare].g = 0.56422 -- min(1,rarityColors[Enum.ItemQuality.Rare].g+0.125)
-- rarityColors[Enum.ItemQuality.Rare].b = 0.99166 -- min(1,rarityColors[Enum.ItemQuality.Rare].b+0.125)
-- rarityColors[Enum.ItemQuality.Rare].hex = "\124cff2090fd"
-- -- call this instead of using GetItemQualityColor or ITEM_QUALITY_COLORS
-- function rematch.utils:GetRarityColor(rarity)
--     return rarity and rarityColors[rarity] or rarityColors[Enum.ItemQuality.Common]
-- end

--[[ buff utils ]]

-- for setting buff tooltips that need a buff index, returns the index if found
function rematch.utils:GetBuffIndex(spellID)
    local index = 0
    local buff
    repeat
        index = index + 1
        buff = C_UnitAuras.GetBuffDataByIndex("player",index)
        if buff and buff.spellId==spellID then
            return index
        end
    until not buff
end

-- returns the name and spellID if safari hat, pet treat, etc item's buff is active
function rematch.utils:GetItemBuff(itemID)
    local buffName, spellID = C_Item.GetItemSpell(itemID)
    if buffName and C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
        return buffName, spellID
    end
end

--[[ ui utils ]]

-- making our own copy of ITEM_QUALITY_COLORS to make the rare blue a bit brighter
local rarityColors = CopyTable(ITEM_QUALITY_COLORS)
rarityColors[Enum.ItemQuality.Rare].r = 0.125 -- min(1,rarityColors[Enum.ItemQuality.Rare].r+0.125)
rarityColors[Enum.ItemQuality.Rare].g = 0.56422 -- min(1,rarityColors[Enum.ItemQuality.Rare].g+0.125)
rarityColors[Enum.ItemQuality.Rare].b = 0.99166 -- min(1,rarityColors[Enum.ItemQuality.Rare].b+0.125)
rarityColors[Enum.ItemQuality.Rare].hex = "\124cff2090fd"
-- call this instead of using GetItemQualityColor or ITEM_QUALITY_COLORS
function rematch.utils:GetRarityColor(rarity)
    return rarity and rarityColors[rarity] or rarityColors[Enum.ItemQuality.Common]
end

-- updates a statusbar progress texture to a percent of the maxWidth with the given colors
-- this assumes the statusbar is just a texture of the colored portion
function rematch.utils:UpdateStatusBar(statusbar,value,maxValue,width,r,g,b)
    local percent = value and maxValue and maxValue>0 and value/maxValue or 0
    if percent==0 then
        statusbar:Hide()
    else
        statusbar:Show()
        statusbar:SetWidth(percent*width)
        statusbar:SetVertexColor(r or 0,g or 0,b or 0)
    end
end

-- takes a multi-line editbox and a table of text and adds the text to the table over time
-- (exports of more than a few thousand characters cause editboxes to flake out if done all at once)
-- if highlight is true, highlight all the text when done
local spoolFunc -- used for timer to spool
function rematch.utils:SpoolText(editbox,text,highlight)
    if spoolFunc then -- in case a SpoolText was called while the timer is running, stop the timer
        rematch.timer:Stop(spoolFunc)
    end
    editbox:SetText("") -- start with an empty editbox
    editbox:ClearFocus() -- get the cursor out (we'll set focus back at end)
    local maxLines = #text -- save number of lines of text before going into spoolFunc
    if maxLines==0 then
        return -- there's no text, leave
    end
    local pleaseWait = editbox:GetParent().PleaseWait
    if pleaseWait then
        pleaseWait.Text:SetText(L["Please Wait..."])
    end
    if maxLines>10 and pleaseWait then -- if more than 10 lines of text, put up the PleaseWait bit
        pleaseWait:Show()
    end
    local chunkSize = C.EXPORT_CHUNK_FAST -- the amount of lines to grab in each pass
    -- get average line length; if greater than 25 then grab 2 lines at a time instead of default 5
    local totalWidth = 0
    for _,line in ipairs(text) do
        totalWidth = totalWidth + line:len()
    end
    local averageWidth = totalWidth/maxLines
    if averageWidth > 200 then -- for very long texts (backed up teams) do one line at a time
        chunkSize = C.EXPORT_CHUNK_SLOW
    elseif totalWidth/maxLines > 50 then -- for moderate texts (csv pet export) do two lines at a time
        chunkSize = C.EXPORT_CHUNK_MEDIUM
    end
    -- new function generated for every new SpoolText to use above values; this is the function called every frame until done
    spoolFunc = function(firstRun)
        -- if editbox is no longer on screen, stop filling it
        if not firstRun and not editbox:IsVisible() then
            return
        end
        -- update Please Wait progress bar
        if pleaseWait then
            rematch.utils:UpdateStatusBar(pleaseWait.Bar,maxLines-#text,maxLines,196,1,0.82,0)
        end
        local lines = ""
        for i=1,chunkSize do -- gather up a few lines in one chunk
            local line = text[1]
            if line then
                lines = lines..line.."\n" -- this is causing garbage, but this is a rare/one off event
                --editbox:Insert(line.."\n")
                tremove(text,1)
            end
        end
        editbox:Insert(lines) -- add the chunk to the end of the text in the editbox
        if #text>0 then -- if there's more lines to add, come back next frame
            rematch.timer:Start(0,spoolFunc)
            return
        end
        -- if we reached here, we're done
        if pleaseWait then -- hide the Please Wait frame
            pleaseWait:Hide()
        end
        editbox:SetCursorPosition(0) -- scroll back to top
        if highlight then -- and highlight if requested
            editbox:HighlightText()
        end
        editbox:SetFocus(true)
    end
    spoolFunc(true) -- kick it off
end

-- updates a statusbar progress texture to a percent of the maxWidth with the given colors
-- this assumes the statusbar is just a texture of the colored portion
function rematch.utils:UpdateStatusBar(statusbar,value,maxValue,width,r,g,b)
    local percent = value and maxValue and maxValue>0 and value/maxValue or 0
    if percent==0 then
        statusbar:Hide()
    else
        statusbar:Show()
        statusbar:SetWidth(percent*width)
        statusbar:SetVertexColor(r or 0,g or 0,b or 0)
    end
end

-- function to hide all extraneous popups and flyouts
function rematch.utils:HideWidgets()
    rematch.tooltip:Hide()
    rematch.menus:Hide()
    rematch.cardManager:HideAllCards()
    rematch.miniLoadoutPanel.AbilityFlyout:Hide()
    rematch.loadoutPanel.AbilityFlyout:Hide()
    rematch.dragFrame:Hide()
end

--[[ texture utils ]]

-- tints a texture based on petInfo.tint value
function rematch.utils:TintTexture(texture,tint)
    if not tint then
        texture:SetDesaturated(false)
        texture:SetVertexColor(1,1,1)
    elseif tint=="red" then
        texture:SetDesaturated(true)
        texture:SetVertexColor(1,0.25,0.25)
    elseif tint=="grey" then
        texture:SetDesaturated(true)
        texture:SetVertexColor(0.75,0.75,0.75)
    end
end

-- into either badges-borderless or badges-borders, returns left,right,top,bottom for given petType
function rematch.utils:GetBadgeCoordsByPetType(petType)
    if petType and petType>=1 and petType<=10 then -- pet has a valid type
        local x = (petType-1)%8
        local y = floor((petType-1)/8)
        return x/8,(x+1)/8,y/8,(y+1)/8
    else -- pet doesn't have a type, return random icon coords
        return 0.25,.375,0.125,0.25
    end
end

--[[ pet utils ]]

-- if a pet is on the cursor, returns its petID, returns false otherwise
function rematch.utils:IsPetOnCursor()
    local cursorType,petID = GetCursorInfo()
    return cursorType=="battlepet" and true or false
end

-- returns information about pet on the curosr; or false if no pet on the cursor
-- includeLevelingInfo false: return petID
-- includeLevelingInfo true:  return petID, canLevel, alreadyQueued, queueIndex
function rematch.utils:GetPetCursorInfo(includeLevelingInfo)
    local cursorType,petID = GetCursorInfo()
    local canLevel,alreadyQueued,queueIndex
    if cursorType=="battlepet" and petID then
        if includeLevelingInfo then
            canLevel = rematch.queue:PetIDCanLevel(petID) -- true/false if pet can level
            alreadyQueued = rematch.queue:IsPetLeveling(petID) -- true/false if pet is already in queue
            queueIndex = rematch.queue:GetPetIndex(petID) -- numeric index into settings.LevelingQueue of petID
            return petID,canLevel,alreadyQueued,queueIndex
        else
            return petID
        end
    end
    return false
end

-- if in battle and given petID is slotted, return the "battle:1:x" petID, otherwise return the given petID
function rematch.utils:GetBattlePetID(petID)
    if C_PetBattles.IsInBattle() and C_PetJournal.PetIsSlotted(petID) then
        for i=1,3 do
            local slottedPetID = C_PetJournal.GetPetLoadOutInfo(i)
            if petID==slottedPetID then
                return "battle:1:"..i
            end
        end
    end
    return petID
end

-- returns true if queued for a battle or multiple accounts logged in
function rematch.utils:IsJournalLocked()
    return (C_PetBattles.GetPVPMatchmakingInfo() or not C_PetJournal.IsJournalUnlocked()) and true or false
end

-- to avoid the need for many 'not isjournallocked' which can make logic weird
function rematch.utils:IsJournalUnlocked()
    return not rematch.utils:IsJournalLocked()
end

-- called from card manager, if a pet is being clicked, look for special handling and return
-- true if something happend
-- if chat modifier key is down (usually Shift) then handle the linking of the pet to chat or AH
-- returns true if it was handled
function rematch.utils:HandleSpecialPetClicks(petID)
    -- something is targeting, try to target the pet being clicked
    if SpellIsTargeting() then
        local petInfo = rematch.petInfo:Fetch(petID)
        if petInfo.idType=="pet" and petInfo.isOwned then
            C_PetJournal.SpellTargetBattlePet(petID)
        end
        return true
    end
    -- pet is being shift+clicked
    if IsModifiedClick("CHATLINK") then
        local petInfo = rematch.petInfo:Fetch(petID)
        if AuctionHouseFrame and AuctionHouseFrame.SearchBar.SearchBox:IsVisible() and petInfo.speciesName then
            AuctionHouseFrame.SearchBar.SearchBox:SetText(petInfo.speciesName) -- AH is up, put pet in search box
        elseif petInfo.isOwned and petInfo.idType=="pet" then
            ChatEdit_InsertLink(C_PetJournal.GetBattlePetLink(petID)) -- pet being linked to chat likely
        end
        return true
    end
end

-- if an ability is shift+clicked, send to chat with the stats of the abilityID if possible
-- (petID will give a link with actual stats for the pet's level/rarity/etc)
-- returns true if it was handled
function rematch.utils:HandleSpecialAbilityClicks(abilityID,petID)
    if abilityID and IsModifiedClick("CHATLINK") and C_PetBattles.GetAbilityInfoByID(abilityID) then
        local petInfo = rematch.petInfo:Fetch(petID)
        local link = GetBattlePetAbilityHyperlink(abilityID,petInfo.maxHealth or 100,petInfo.power or 0,petInfo.speed or 0)
        if link then
            ChatEdit_InsertLink(link)
        end
        return true
    end
end

--[[ misc utils ]]

-- takes an expression which can be a function or a literal. if a function it returns the return of that function;
-- if a literal it returns the literal
function rematch.utils:Evaluate(expression,info,subject)
    if type(expression)=="function" then
        return expression(info,subject)
    else
        return expression
    end
end

-- returns a YYYYMMDDHHMISS of the current datetime
function rematch.utils:GetDateTime()
    return tonumber(date("%Y%m%d%H%M%S"))
end

