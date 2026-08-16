local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.toast = {}

function rematch.toast:Setup(petID)
    local petInfo = rematch.petInfo:Fetch(petID)
    if petID then
        self.Title:SetText(L["Now leveling:"])
        self.Name:SetText(petInfo.name)
        self.Icon.Texture:SetTexture(petInfo.icon)
    else
        self.Title:SetText(L["Rematch's leveling queue is empty"])
        self.Name:SetText(L["All done leveling pets!"])
        self.Icon.Texture:SetTexture("Interface\\Icons\\INV_Pet_Achievement_WinAPetBattle")
    end
end

function rematch.toast:ToastLevelingPet(petID)
    if settings.HidePetToast then
        return -- aww :(
    end
    if not self.LevelingToastSystem then
        self.LevelingToastSystem = AlertFrame:AddQueuedAlertFrameSubSystem("RematchLevelingToastTemplate",self.Setup,2,0)
    end
    self.LevelingToastSystem:AddAlert(petID)
end
