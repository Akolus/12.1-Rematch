local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.tooltip = {} -- note this isn't RematchTooltip
local tooltip -- but this will be after PLAYER_LOGIN

-- forgive the NIH syndrome, but recreating a GameTooltip in-house rather than using the templates

local currentLine = 0 -- the line number added to the tooltip (increments to 1 for first line)
local isAnchored = false -- true when a SetPoint is used (if false when showing, will choose an anchor)

rematch.events:Register(rematch.tooltip,"PLAYER_LOGIN",function(self)
    tooltip = RematchTooltip
    rematch.tooltipManager:AddBehavior(tooltip) -- makes tooltips delayed based on settings.TooltipBehavior
end)

-- call this to start a tooltip; make noTitle true if there's no title text that's slightly larger than the rest
function rematch.tooltip:SetOwner(parent,noTitle)
    -- not doing a SetParent since clipped content like scrollframes need the tooltip to appear outside it
    tooltip.parent = parent
    -- hide any previous lines shown
    for _,line in ipairs(tooltip.Lines) do
        line:Hide()
    end
    if noTitle then -- if noTitle, then the first line has the same style/color text as the body
        tooltip.Lines[1]:SetFontObject("GameFontNormal")
        tooltip.Lines[1]:SetTextColor(1,0.82,0)
    else -- otherwise, first line has a slightly larger font colored white
        tooltip.Lines[1]:SetFontObject("GameTooltipHeaderText")
        tooltip.Lines[1]:SetTextColor(1,1,1)
    end
    currentLine = 0
    isAnchored = false
end

function rematch.tooltip:GetOwner()
    return tooltip.parent
end

-- returns the number of lines in the tooltip
function rematch.tooltip:GetNumLines()
    return currentLine
end

-- adds a line of text
function rematch.tooltip:AddLine(text,r,g,b)
    if not text then
        return
    end
    currentLine = currentLine + 1
    if not tooltip.Lines[currentLine] then
        tooltip.Lines[currentLine] = tooltip:CreateFontString(nil,"ARTWORK","GameFontNormal")
        tooltip.Lines[currentLine]:SetPoint("TOPLEFT",tooltip.Lines[currentLine-1],"BOTTOMLEFT",0,-C.TOOLTIP_LINE_SPACING)
        tooltip.Lines[currentLine]:SetJustifyH("LEFT")
    end
    local line = tooltip.Lines[currentLine]
    if r and g and b then
        line:SetTextColor(r,g,b)
    elseif currentLine>1 then
        line:SetTextColor(1,0.82,0)
    end
    line:SetText(text)
    line:Show()
end

-- replacement for SetPoint
function rematch.tooltip:SetPoint(anchorPoint,relativeTo,relativePoint,xoff,yoff)
    tooltip:ClearAllPoints() -- this means a tooltip can only have one anchor!
    tooltip:SetPoint(anchorPoint,relativeTo,relativePoint,xoff,yoff)
    isAnchored = true
end

-- before showing the tooltip, go through and adjust for wrapping lines and resize lines/tooltip based on the tooltip content
function rematch.tooltip:Show()
    -- determine the width (first pass), between the maximum of all lines' widths to at most C.TOOLTIP_MAX_WIDTH
    local width = 0
    for i=1,currentLine do
        width = min(max(tooltip.Lines[i]:GetUnboundedStringWidth(),width),C.TOOLTIP_MAX_WIDTH)
    end
    -- set all lines to that width (first pass) to get them to wrap if any wrap
    for i=1,currentLine do
        tooltip.Lines[i]:SetWidth(width)
    end
    -- second pass to to get maximum wrapped width (to trim the excess whitespace to the right of unfortunate spacing)
    width = 0
    for i=1,currentLine do
        width = max(tooltip.Lines[i]:GetWrappedWidth(),width)
    end
    -- set final widths and total up height while we're at it
    local height = C.TOOLTIP_PADDING*2-2 + (currentLine-1)*C.TOOLTIP_LINE_SPACING
    for i=1,currentLine do
        tooltip.Lines[i]:SetWidth(width)
        height = height + tooltip.Lines[i]:GetStringHeight()
    end
    tooltip:SetSize(width+C.TOOLTIP_PADDING*2,height)
    tooltip:Show()
end

function rematch.tooltip:Hide()
    tooltip:Hide()
end

-- using a custom GameTooltip to use as a tooltip source for stuff we can't easily build
function rematch.tooltip:GetSourceTooltip()
    local source = RematchGameTooltip
    source:SetOwner(UIParent,"ANCHOR_NONE")
    return source
end

-- mimics the GameTooltip:SetSpellID(spellID), except that it has no right columns. For now only Revive Battle Pets is
-- using this, so it just uses the right text if it exists first
function rematch.tooltip:SetSpellByID(spellID)
    local source = rematch.tooltip:GetSourceTooltip()
    source:SetSpellByID(spellID)
    rematch.tooltip:CloneGameTooltip()
end

-- mimics GameTooltip:SetItemByID(itemID)
function rematch.tooltip:SetItemByID(itemID)
    local source = rematch.tooltip:GetSourceTooltip()
    itemID = type(itemID)=="string" and itemID:match("item:(%d+)") or itemID
    source:SetItemByID(itemID)
    rematch.tooltip:CloneGameTooltip()
end

-- mimics GameTooltip:SetUnitBuff("player",index)
function rematch.tooltip:SetUnitBuff(unit,index)
    local source = rematch.tooltip:GetSourceTooltip()
    source:SetUnitBuff(unit,index)
    rematch.tooltip:CloneGameTooltip()
end

-- mimics GameTooltip:SetToyByItemID(itemID)
function rematch.tooltip:SetToyByItemID(itemID)
    local source = rematch.tooltip:GetSourceTooltip()
    source:SetToyByItemID(itemID)
    rematch.tooltip:CloneGameTooltip()
end

function rematch.tooltip:SetAchievementByID(achievementID)
    local source = rematch.tooltip:GetSourceTooltip()
    source:SetAchievementByID(achievementID)
    rematch.tooltip:CloneGameTooltip()
end

function rematch.tooltip:CloneGameTooltip()
    local source = RematchGameTooltip
    if source:NumLines()>0 then
        for i=1,source:NumLines() do
            local line = _G["RematchGameTooltipTextRight"..i]
            local text = line:GetText()
            if not text then
                line = _G["RematchGameTooltipTextLeft"..i]
                text = line:GetText()
            end
            if text and text:trim()~="" then -- skipping empty lines
                local r,g,b = line:GetTextColor()
                rematch.tooltip:AddLine(text,r,g,b)
            end
        end
    end
    source:Hide()
end

-- for simpler tooltips with a title/body; anchorPoint can be "cursor" to float the tooltip
-- at the cursor, or a full anchor can be defined. if no anchor at all, it will choose an
-- anchor to parent. if no title/body passed, it will look for tooltipTitle/Body on the parent,
-- or on the parent of the given parent if tooltipAtParent is true.
-- force is true (must nil every optional arg) if the tooltip should be shown (when options may hide it)
function rematch.tooltip:ShowSimpleTooltip(parent,title,body,anchorPoint,relativeTo,relativePoint,xoff,yoff,force)
    if rematch.utils:GetUIJustChanged() then
        return -- if ui just reconfigured or menu/dialog disappeared, don't show this tooltip
    end
    -- cursor tooltips can't be suppressed; others can
    if anchorPoint~="cursor" and ((settings.HideTooltips and not parent.isOption) or (settings.HideOptionTooltips and parent.isOption)) and not force then
        rematch.tooltip:Hide()
        return -- user doesn't want to see tooltips
    end
    if not title and not body then
        if parent.tooltipAtParent then -- if tooltipAtParent is true, move up to parent for the tooltip
            parent = parent:GetParent()
        end
        title = parent.tooltipTitle -- title/body wasn't passed, pick it up from the parent
        body = parent.tooltipBody
    end
    if not title and not body then
        return -- no title or body still, nothing to show, leave
    end

    rematch.tooltip:SetOwner(parent,not title)

    if title then
        rematch.tooltip:AddLine(title)
    end
    if body then
        rematch.tooltip:AddLine(body)
    end

    -- finally position it
    if anchorPoint=="cursor" then
        tooltip:SetScript("OnUpdate",rematch.tooltip.FollowCursor)
    elseif not anchorPoint then -- no anchor, pick one based on the parent's reference
        local corner,opposite = rematch.utils:GetCorner(rematch.utils:GetFrameForReference(parent),UIParent)
        rematch.tooltip:SetPoint(corner,parent,opposite)
    else -- and anchor was defined, use it
        rematch.tooltip:SetPoint(anchorPoint,relativeTo,relativePoint,xoff,yoff)
    end

    rematch.tooltip:Show()

    -- if displaying tooltip at cursor, then skip any potential delay and show it immediately
    if anchorPoint=="cursor" then
        tooltip:Show(true)
    end

end

-- the OnUpdate function when the tooltip is show at cursor
function rematch.tooltip:FollowCursor(elapsed)
    local x,y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x/scale,y/scale)
    if self.fadeWait > 0 then
        self.fadeWait = self.fadeWait - elapsed
    elseif self.fadeAlpha > 0 then
        self.fadeAlpha = self.fadeAlpha - elapsed/C.TOOLTIP_FADE_ALPHA
        self:SetAlpha(max(self.fadeAlpha,0))
    else
        self:Hide()
    end
end