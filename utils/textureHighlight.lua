local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
rematch.textureHighlight = {}

local highlightFrame = CreateFrame("Frame",nil,UIParent,"RematchUseParentLevelTemplate")
highlightFrame:Hide()
local highlightPool = {}

-- highlights the given texture(s); multiple textures can be highlighted at once but if they
-- overlap they should be separated with a textureSubLevel gap between them (since highlight
-- will appear 1 textureSubLevel above each); all textures being highlighted at once should
-- have the same parent
function rematch.textureHighlight:Show(...)
    local numHighlights = select("#",...)
    local texture = select(1,...)
    local parentFrame = texture and texture:GetParent()
    if not parentFrame then
        return
    end
    -- move invisible highlight frame to cover parent frame
    highlightFrame:SetParent(parentFrame)
    highlightFrame:SetFrameStrata(parentFrame:GetFrameStrata())
    highlightFrame:SetFrameLevel(parentFrame:GetFrameLevel())
    highlightFrame:ClearAllPoints()
    highlightFrame:SetPoint("TOPLEFT",parentFrame,"TOPLEFT")
    highlightFrame:SetPoint("BOTTOMRIGHT",parentFrame,"BOTTOMRIGHT")
    -- now apply highlights to each texture at one textureSubLevel higher
    local index = 1
    for i=1,numHighlights do
        local texture = select(i,...)
        if texture then
            if not highlightPool[index] then
                highlightPool[index] = highlightFrame:CreateTexture(nil,"ARTWORK") -- drawLayer may change
            end
            local highlight = highlightPool[index]
            local drawLayer,textureSubLevel = texture:GetDrawLayer()
            highlight:ClearAllPoints()
            highlight:SetPoint("TOPLEFT",texture,"TOPLEFT")
            highlight:SetPoint("BOTTOMRIGHT",texture,"BOTTOMRIGHT")
            highlight:SetDrawLayer(drawLayer,textureSubLevel+1)
            highlight:SetTexture(texture:GetTexture())
            highlight:SetTexCoord(texture:GetTexCoord())
            highlight:SetDesaturated(C.HIGHLIGHT_DESATURATE and texture:IsDesaturated())
            highlight:SetVertexColor(C.HIGHLIGHT_VERTEX,C.HIGHLIGHT_VERTEX,C.HIGHLIGHT_VERTEX,C.HIGHLIGHT_ALPHA)
            highlight:SetBlendMode("ADD")
            highlight:SetShown(texture:IsShown())
            index = index + 1
        end
    end
    -- hide any remaining
    for i=index+1,#highlightPool do
        highlightPool[i]:Hide()
    end
    highlightFrame:Show()
end

-- hides the current highlight
function rematch.textureHighlight:Hide()
    highlightFrame:Hide()
    for _,highlight in ipairs(highlightPool) do
        highlight:Hide()
    end
end
