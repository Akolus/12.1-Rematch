local _,rematch = ...
local L = rematch.localization
local C = rematch.constants
local settings = rematch.settings
rematch.summaryDialog = {}

-- barchart tables that contain data for either types or sources
-- filled in each: maxValue = max bar value; value = number between 0 and maxValue; total = used in calculations
local chartData = {
    [C.BARCHART_TYPES] = {
        { maxValue=100, value=0, total=0, r=0.03125, g=0.56640625, b=0.88671875, icon="Interface\\Icons\\Pet_Type_Humanoid" },
        { maxValue=100, value=0, total=0, r=0.07421875, g=0.4375, b=0.07421875, icon="Interface\\Icons\\Pet_Type_Dragon" },
        { maxValue=100, value=0, total=0, r=0.78125, g=0.765625, b=0.30078125, icon="Interface\\Icons\\Pet_Type_Flying" },
        { maxValue=100, value=0, total=0, r=0.40625, g=0.28125, b=0.3125, icon="Interface\\Icons\\Pet_Type_Undead" },
        { maxValue=100, value=0, total=0, r=0.46875, g=0.328125, b=0.25, icon="Interface\\Icons\\Pet_Type_Critter" },
        { maxValue=100, value=0, total=0, r=0.65625, g=0.4375, b=0.96875, icon="Interface\\Icons\\Pet_Type_Magical" },
        { maxValue=100, value=0, total=0, r=0.96875, g=0.640625, b=0, icon="Interface\\Icons\\Pet_Type_Elemental" },
        { maxValue=100, value=0, total=0, r=0.73828125, g=0.140625, b=0.11328125, icon="Interface\\Icons\\Pet_Type_Beast" },
        { maxValue=100, value=0, total=0, r=0.03125, g=0.66796875, b=0.69921875, icon="Interface\\Icons\\Pet_Type_Water" },
        { maxValue=100, value=0, total=0, r=0.625, g=0.625, b=0.5625, icon="Interface\\Icons\\Pet_Type_Mechanical" }
    },
    [C.BARCHART_SOURCES] = {
        { maxValue=100, value=0, total=0, r=0.29296875, g=0.4921875, b=0.33984375, icon="Interface\\Icons\\INV_Misc_Bag_CenarionHerbBag" },
        { maxValue=100, value=0, total=0, r=0.81640625, g=0.796875, b=0.55859375, icon="Interface\\Icons\\Achievement_Quests_Completed_06" },
        { maxValue=100, value=0, total=0, r=0.89453125, g=0.61328125, b=0.03125, icon="Interface\\Icons\\INV_Misc_Coin_02" },
        { maxValue=100, value=0, total=0, r=0.73046875, g=0.72265625, b=0.6875, icon="Interface\\Icons\\Trade_BlackSmithing" },
        { maxValue=100, value=0, total=0, r=0.90625, g=0.421875, b=0.09375, icon="Interface\\Icons\\INV_Pet_BattlePetTraining" },
        { maxValue=100, value=0, total=0, r=0.40234375, g=0.49609375, b=0.62109375, icon="Interface\\Icons\\Achievement_Dungeon_GloryoftheHERO" },
        { maxValue=100, value=0, total=0, r=0.3828125, g=0.1484375, b=0.6796875, icon="Interface\\Icons\\Achievement_Halloween_Bat_01" },
        { maxValue=100, value=0, total=0, r=0.48046875, g=0.66015625, b=0.67578125, icon="Interface\\Icons\\INV_Pet_BabyMurlocs_Blue" },
        { maxValue=100, value=0, total=0, r=0.56640625, g=0.05859375, b=0.171875, icon="Interface\\Icons\\ACHIEVEMENT_GUILDPERK_LADYLUCK" },
        { maxValue=100, value=0, total=0, r=0.19140625, g=0.65625, b=0.66796875, icon="Interface\\Icons\\WoW_Token01" },
        { maxValue=100, value=0, total=0, r=0.9375, g=0.828125, b=0.4375, icon="Interface\\Icons\\INV_Misc_Spyglass_03" },
        { maxValue=100, value=0, total=0, r=0.9375, g=0.828125, b=0.4375, icon="Interface\\ICONS\\TradingPostCurrency" }
    }
}

-- name is name of barchart, category is the settings.BarChartCategory value, one of these constants
local categories = {
    { name=L["Unique Pets In the Journal"], category=C.BARCHART_IN_JOURNAL },
    { name=L["Total Collected Pets"], category=C.BARCHART_TOTAL_COLLECTED },
    { name=L["Unique Collected Pets"], category=C.BARCHART_UNIQUE_COLLECTED },
    { name=L["Pets Not Collected"], category=C.BARCHART_NOT_COLLECTED },
    { name=L["Percent Collected"], category=C.BARCHART_PERCENT_COLLECTED, isPercent=true },
    { name=L["Max Level Pets"], category=C.BARCHART_MAX_LEVEL },
    { name=L["Average Pet Level"], category=C.BARCHART_AVG_LEVEL },
    { name=L["Rare Quality Pets"], category=C.BARCHART_RARE_QUALITY },
    { name=L["Pets In Teams"], category=C.BARCHART_IN_TEAMS },
}

rematch.events:Register(rematch.summaryDialog,"PLAYER_LOGIN",function(self)

    rematch.dialog:Register("PetSummaryMinimized",{
        title = L["Pet Collection"],
        accept = OKAY,
        minHeight = 275,
        minimize = {nextState="maximize", nextDialog="PetSummary"},
        layouts = {
            Default={"LayoutTabs","PetSummary"},
            Types={"LayoutTabs","BarChartDropDown","Spacer","BarChart"},
            Sources={"LayoutTabs","BarChartDropDown","Spacer","BarChart"},
            Battles={"LayoutTabs","BattleSummary","TopTeams","CheckButton"}
        },
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                rematch.summaryDialog:FirstUseSetup()
                settings.MinimizePetSummary = true -- hitting minimize button will set this
                self.LayoutTabs:SetTabs({{"Summary","Default"},{"Pet Types","Types"},{"Sources","Sources"},{"Battles","Battles"}})
                self.CheckButton:SetText(L["Rank teams by percentage won"])
                self.CheckButton:SetChecked(settings.RankWinsByPercent)
            end
            local layout = rematch.dialog:GetOpenLayout()
            if layout=="Default" then
                rematch.summaryDialog:FillSummary()
            elseif layout=="Types" then
                self.BarChart:Set(rematch.summaryDialog:GetChartData(C.BARCHART_TYPES,settings.BarChartCategory or C.BARCHART_IN_JOURNAL))
            elseif layout=="Sources" then
                self.BarChart:Set(rematch.summaryDialog:GetChartData(C.BARCHART_SOURCES,settings.BarChartCategory or C.BARCHART_IN_JOURNAL))
            elseif layout=="Battles" then
                local stats = rematch.collectionInfo:GetWinStats(3)
                self.BattleSummary:Fill(stats)
                self.TopTeams:Fill(stats.topTeams)
                self.TopTeams:SetShown(stats.teams and stats.teams>0) -- only show top teams if there are teams to show
            end
        end,
        changeFunc = function(self,info,subject)
            settings.RankWinsByPercent = self.CheckButton:GetChecked()
            rematch.dialog:Refresh()
        end
    })

    rematch.dialog:Register("PetSummary",{
        title = L["Pet Collection"],
        accept = OKAY,
        minHeight = 476, -- was 264 with summary on its own tab
        minimize = {nextState="minimize", nextDialog="PetSummaryMinimized"},
        layouts={
            Default={"LayoutTabs","PetSummary","BarChartDropDown","BarChart"},
            Sources={"LayoutTabs","PetSummary","BarChartDropDown","BarChart"},
            Battles={"LayoutTabs","Spacer","BattleSummary","TopTeams","CheckButton"}
        },
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                rematch.summaryDialog:FirstUseSetup()
                settings.MinimizePetSummary = false -- hitting minimize button will set this
                self.LayoutTabs:SetTabs({{L["Pet Types"],"Default"},{L["Sources"],"Sources"},{L["Battles"],"Battles"}})
                self.CheckButton:SetText(L["Rank teams by percentage won"])
                self.CheckButton:SetChecked(settings.RankWinsByPercent)
            end
            local layout = rematch.dialog:GetOpenLayout()
            if layout=="Default" then
                rematch.summaryDialog:FillSummary()
                self.BarChart:Set(rematch.summaryDialog:GetChartData(C.BARCHART_TYPES,settings.BarChartCategory or C.BARCHART_IN_JOURNAL))
            elseif layout=="Sources" then
                rematch.summaryDialog:FillSummary()
                self.BarChart:Set(rematch.summaryDialog:GetChartData(C.BARCHART_SOURCES,settings.BarChartCategory or C.BARCHART_IN_JOURNAL))
            elseif layout=="Battles" then
                local stats = rematch.collectionInfo:GetWinStats(10)
                self.BattleSummary:Fill(stats)
                self.TopTeams:Fill(stats.topTeams)
                self.TopTeams:SetShown(stats.teams and stats.teams>0) -- only show top teams if there are teams to show
            end
        end,
        changeFunc = function(self,info,subject)
            settings.RankWinsByPercent = self.CheckButton:GetChecked()
            rematch.dialog:Refresh()
        end
    })

    -- sets the labels to the summary dialog control
    for k,v in pairs({UniqueHeader = L["Unique"],
                      TotalHeader = L["Total"],
                      CollectedLabel = L["Pets Collected"],
                      MaxLevelLabel = L["Pets At Max Level"],
                      RarePetsLabel = L["Rare Quality Pets"],
                      DuplicatePetsLabel = L["Duplicate Collected Pets"],
                      AverageLevelLabel = L["Average Battle Pet Level"],
                      UncollectedLabel = L["Pets Not Collected"]}) do
        rematch.dialog.Canvas.PetSummary[k]:SetText(v)
    end

end)

-- since many sessions may not use this dialog at all, any setup stuff for dialog controls is done here on first use
function rematch.summaryDialog:FirstUseSetup()
    if not self.isSetup then
        self.isSetup = true
        local menu = {}
        for i,info in ipairs(categories) do
            tinsert(menu,{text=info.name, value=i})
        end
        rematch.dialog.Canvas.BarChartDropDown.DropDown:BasicSetup(menu,
            function(value)
                settings.BarChartCategory = value
                rematch.dialog.Canvas.BarChart:Set(rematch.summaryDialog:GetChartData(rematch.dialog:GetOpenLayout()=="Types" and C.BARCHART_TYPES or C.BARCHART_SOURCES,settings.BarChartCategory or C.BARCHART_IN_JOURNAL))
            end
        )
        rematch.dialog.Canvas.BarChartDropDown.DropDown:SetSelection(settings.BarChartCategory)

        rematch.dialog.Canvas.TopTeams.WinsLabel:SetText(L["Wins"])


        rematch.dialog.Canvas.BattleSummary.WinLabel:SetText(L["Won"])
        rematch.dialog.Canvas.BattleSummary.LossLabel:SetText(L["Lost"])
        rematch.dialog.Canvas.BattleSummary.DrawLabel:SetText(L["Draw"])
    end
end

-- main tab of dialog, summary statistics of collection
function rematch.summaryDialog:FillSummary()
    -- collection[speciesID] = {petType,source,numPets,numAt25,totalLevels,numPoor,numCommon,numUncommon,numRare}
    local stats = rematch.collectionInfo:GetCollectionStats()

    local summary = rematch.dialog.Canvas.PetSummary

    summary.TotalInJournal:SetText(format(L["There are %s%d\124r unique pets in the journal"],C.HEX_WHITE,stats.numInJournal))
    summary.TotalCollected:SetText(format(L["You've collected %s%.1f%%\124r of them"],C.HEX_WHITE,stats.numCollectedUnique*100/max(1,stats.numInJournal)))

    if stats.numInJournal==0 or stats.numCollectedTotal==0 then
        return -- pets didn't load for some reason or user has no pets, leave
    end

    local barWidth = 248
    summary.RareBar:SetWidth(max(stats.numTotalRare*barWidth/stats.numCollectedTotal,0.1))
    summary.UncommonBar:SetWidth(max(stats.numUncommon*barWidth/stats.numCollectedTotal,0.1))
    summary.CommonBar:SetWidth(max(stats.numCommon*barWidth/stats.numCollectedTotal,0.1))
    summary.PoorBar:SetWidth(max(stats.numPoor*barWidth/stats.numCollectedTotal,0.1))

    summary.CollectedUniqueCount:SetText(stats.numCollectedUnique)
    summary.CollectedTotalCount:SetText(stats.numCollectedTotal)
    summary.MaxLevelUniqueCount:SetText(stats.numUniqueMax)
    summary.MaxLevelTotalCount:SetText(stats.numTotalMax)
    summary.RarePetsUniqueCount:SetText(stats.numUniqueRare)
    summary.RarePetsTotalCount:SetText(stats.numTotalRare)

    summary.DuplicatePetsCount:SetText(stats.numCollectedTotal-stats.numCollectedUnique)
    summary.AverageLevel:SetText(floor(stats.averageLevel)==stats.averageLevel and stats.averageLevel or format("%.1f",stats.averageLevel))
    summary.UncollectedCount:SetText(stats.numInJournal-stats.numCollectedUnique)
end

--[[ chart data ]]

-- returns a chartData subtable filled in for the given category
-- chart is either C.BARCHART_TYPES or C.BARCHART_SOURCES to choose which bar chart to get data for
-- category is one of C.BARCHART_IN_JOURNAL, C.BARCHART_TOTAL_COLLECTED, etc of which category of data for the chart
function rematch.summaryDialog:GetChartData(chart,category)
    local data = chartData[chart]
    assert(type(data)=="table" and #data>0,"Invalid chart data set: "..(chart or "nil"))
    assert(type(category)=="number","Invalid chart category: "..(category or "nil"))
    for _,info in ipairs(data) do
        info.total = 0
        info.value = 0
    end
    -- total values for each bar
    -- collection[speciesID] = {petType,source,numPets,numAt25,totalLevels,numInTeams,numPoor,numCommon,numUncommon,numRare}
    for _,info in pairs(rematch.collectionInfo:GetSpeciesStats()) do
        local addValue = 0
        local column = info[chart] -- either C.BARCHART_TYPES (1) or C.BARCHART_SOURCES (2) -- first two info indexes
        if column and data[column] then
            if category==C.BARCHART_IN_JOURNAL then
                addValue = 1 -- unique pets in journal
            elseif category==C.BARCHART_TOTAL_COLLECTED then
                addValue = info[3]
            elseif category==C.BARCHART_UNIQUE_COLLECTED then
                addValue = min(1,info[3])
            elseif category==C.BARCHART_NOT_COLLECTED and info[3]==0 then
                addValue = 1
            elseif category==C.BARCHART_PERCENT_COLLECTED then
                data[column].total = data[column].total + 1 -- total count of this type/source
                addValue = info[3]>0 and 1 or 0
            elseif category==C.BARCHART_MAX_LEVEL then
                addValue = info[4]
            elseif category==C.BARCHART_AVG_LEVEL then
                data[column].total = data[column].total + info[5] -- total levels of this type/source
                addValue = info[3]
            elseif category==C.BARCHART_RARE_QUALITY then
                addValue = info[10]
            elseif category==C.BARCHART_IN_TEAMS then
                addValue = info[6]
            end
            data[column].value = data[column].value + addValue
        end
    end
    -- some post-total calculations
    if category==C.BARCHART_PERCENT_COLLECTED then
        for _,info in ipairs(data) do
            info.value = floor(info.value*100/max(info.total,0.1)+0.5) -- rounding to nearest whole percent
        end
    elseif category==C.BARCHART_AVG_LEVEL then
        for _,info in ipairs(data) do
            info.value = floor(info.total*10/max(info.value,0.1)+0.5)/10 -- rounding to nearest tenth
        end
    end
    -- find max value across all bars
    local maxValue = 1 -- 1 is minimum maxValue
    for _,info in ipairs(data) do
        maxValue = max(maxValue,info.value)
    end
    -- have maxValue, now set all bars to that maxValue
    for _,info in ipairs(data) do
        if category==C.BARCHART_PERCENT_COLLECTED then
            info.maxValue = 100
            info.formattedValue = "%d%%"
        elseif category==C.BARCHART_AVG_LEVEL then
            info.maxValue = 25
            info.formattedValue = nil
        else
            info.maxValue = maxValue
            info.formattedValue = nil
        end
    end
    return data
end
