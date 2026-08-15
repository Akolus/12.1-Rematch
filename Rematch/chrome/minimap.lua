local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.minimap = RematchMinimapButton

rematch.events:Register(rematch.minimap,"PLAYER_LOGIN",function(self)
    self:Configure()
    rematch.menus:Register("MinimapFavorites",{})
end)

function rematch.minimap:OnEnter()
    if not self.isDragging then
        rematch.tooltip:ShowSimpleTooltip(self,L["Rematch"],format(L["%s Toggle Window\n%s Load Favorite Team"],C.LMB_TEXT_ICON,C.RMB_TEXT_ICON),"BOTTOMRIGHT",self,"TOPLEFT",8,-8)
    end
end

function rematch.minimap:OnLeave()
    rematch.tooltip:Hide()
end

function rematch.minimap:OnMouseDown()
    self.Icon:SetPoint("CENTER",1,-1)
    self.Icon:SetVertexColor(0.65,0.65,0.65)
end

function rematch.minimap:OnMouseUp()
    self.Icon:SetPoint("CENTER")
    self.Icon:SetVertexColor(1,1,1)
end

-- menu function to load teamID
local function loadTeam(self)
    rematch.loadTeam:LoadTeamID(self.teamID)
end

function rematch.minimap:OnClick(button)
    if button=="RightButton" then
        rematch.tooltip:Hide()
        -- rebuild menu for current favorites
        local menu = rematch.menus:GetDefinition("MinimapFavorites")
        wipe(menu) -- clear menu and rebuild
        tinsert(menu,{title=L["Favorite Teams"]})
        local teams = rematch.savedGroups["group:favorites"].teams
        if not teams or #teams==0 then -- if no teams :(
            tinsert(menu,{text=format(L["%sNo favorite teams :("],C.HEX_GREY)})
        else -- at least one team favorited, add them to menu
            for _,teamID in ipairs(teams) do
                tinsert(menu,{text=rematch.utils:GetFormattedTeamName(teamID),teamID=teamID,func=loadTeam})
            end
        end

        rematch.menus:Register("MinimapFavorites",menu)

        rematch.menus:Toggle("MinimapFavorites",self,nil,"TOPRIGHT",self,"BOTTOMLEFT",8,8)
    else
        rematch.frame:Toggle()
    end
end

function rematch.minimap:OnDragStart()
    rematch.menus:Hide()
    rematch.tooltip:Hide()
    self.isDragging = true
    self:SetScript("OnUpdate",self.OnDragUpdate)
end

function rematch.minimap:OnDragStop()
    self.Icon:SetPoint("CENTER")
    self.Icon:SetVertexColor(1,1,1)
    self:SetScript("OnUpdate",nil)
    self.isDragging = false
end

function rematch.minimap:Configure()
    self:SetShown(settings.UseMinimapButton)
    self:Update()
end

-- updates position of button based on MinimapButtonPosition setting
function rematch.minimap:Update()
    local angle = settings.MinimapButtonPosition or -162
    self:SetPoint("CENTER",Minimap,"CENTER",(105*cos(angle)),(105*sin(angle)))
end

-- OnUpdate while button being dragged, calculates new position(angle) for button and moves it
function rematch.minimap:OnDragUpdate(elapsed)
    local x,y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local minX,minY = Minimap:GetCenter()
    settings.MinimapButtonPosition = math.deg(math.atan2(y/scale-minY,x/scale-minX))
    rematch.minimap:Update()
end