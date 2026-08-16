local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.titlebar = rematch.frame.TitleBar
rematch.frame:Register("titlebar")

local collapseOnEscLists = {} -- autoscrollbox lists that can be collapsed with ESC key (closebutton onkeydown)

rematch.events:Register(rematch.titlebar,"PLAYER_LOGIN",function(self)
    self.Title:SetText(L["Rematch"])
end)

function rematch.titlebar:Configure()
    local mode = rematch.layout:GetMode(C.CURRENT)
    local journalActive = rematch.journal:IsActive()
    local showLock = not journalActive
    local showView = mode~=0 and not journalActive
    local showMinimize = not journalActive
    self.Portrait:SetShown(journalActive)
    self.LockButton:SetShown(showLock)
    self.PrevModeButton:SetShown(showView)
    self.NextModeButton:SetShown(showView)
    self.MinimizeButton:SetShown(showMinimize)
    -- enable/disable the prev/next mode buttons (when anchored on right, prev button increases mode)
    if settings.Anchor=="BOTTOMRIGHT" or settings.Anchor=="TOPRIGHT" then
        self.PrevModeButton:SetEnabled(mode>0 and mode<3)
        self.NextModeButton:SetEnabled(mode>1 and mode<4)
    else
        self.PrevModeButton:SetEnabled(mode>1 and mode<4)
        self.NextModeButton:SetEnabled(mode>0 and mode<3)
    end
    self.CloseButton:SetScript("OnKeyDown",self.CloseButton.OnKeyDown)
end

function rematch.titlebar:Update()
    self.MinimizeButton:SetIcon(rematch.layout:GetMode(C.CURRENT)==0 and "maximize" or "minimize")
    self.LockButton:SetIcon(settings.LockPosition and "lock" or "unlock")
end

function rematch.titlebar.CloseButton:OnClick()
    rematch.frame:Toggle()
end

function rematch.titlebar.MinimizeButton:OnClick()
    rematch.frame:ToggleMinimized()
end

function rematch.titlebar.LockButton:OnClick()
    settings.LockPosition = not settings.LockPosition
    rematch.titlebar:Update()
    PlaySound(C.SOUND_PANEL_TAB)
end

function rematch.titlebar.PrevModeButton:OnClick()
    local mode = rematch.layout:GetMode(C.CURRENT)
    if not mode then
        return
    end
    -- when rematch anchored on right, prev mode button increases mode
    if (settings.Anchor=="BOTTOMRIGHT" or settings.Anchor=="TOPRIGHT") and mode<3 then
        rematch.layout:ChangeMode(mode + 1)
        PlaySound(C.SOUND_PANEL_TAB)
    elseif mode>1 then
        rematch.layout:ChangeMode(mode - 1)
        PlaySound(C.SOUND_PANEL_TAB)
    end
end

function rematch.titlebar.NextModeButton:OnClick()
    local mode = rematch.layout:GetMode(C.CURRENT)
    if not mode then
        return
    end
    -- when rematch anchored on right, next mode button decreases mode
    if (settings.Anchor=="BOTTOMRIGHT" or settings.Anchor=="TOPRIGHT") and mode>1 then
        rematch.layout:ChangeMode(mode-1)
        PlaySound(C.SOUND_PANEL_TAB)
    elseif mode<3 then
        rematch.layout:ChangeMode(mode+1)
        PlaySound(C.SOUND_PANEL_TAB)
    end
end

-- if the parent frame has it, it always eats keys
function rematch.titlebar.CloseButton:OnKeyDown(key)
    local propagate = true
    if key==GetBindingKey("TOGGLEGAMEMENU") then
        -- if CollapseOnEsc enabled, go through and collapse any lists
        if settings.CollapseOnEsc then
            if #collapseOnEscLists==0 then -- if we haven't gathered lists that can be collapsed
                tinsert(collapseOnEscLists,rematch.optionsPanel.List)
                tinsert(collapseOnEscLists,rematch.teamsPanel.List)
                tinsert(collapseOnEscLists,rematch.targetsPanel.List)
            end
            for _,list in ipairs(collapseOnEscLists) do
                if list:IsVisible() and list:IsAnyExpanded() then
                    list:ToggleAllHeaders()
                    propagate = false
                end
            end
        end
        -- if not in journal (which can't collapse) then collapse if settings permit
        if propagate and not rematch.journal:IsActive() then
            -- if maximized (and option allows) minimize on ESC
            if rematch.layout:GetMode(C.CURRENT)~=0 and not settings.LockDrawer then
                rematch.frame:ToggleMinimized()
                propagate = false
            elseif not settings.LockWindow then -- otherwise hide the window
                rematch.frame:Hide()
                propagate = false
            end
        end
    end
    self:SetPropagateKeyboardInput(propagate)
end