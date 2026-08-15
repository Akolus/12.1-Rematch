local _,rematch = ...
local C = rematch.constants
local settings = rematch.settings

--[[
    Wrapper for Blizzard's recently expanded ScrollBox control with support for expanding/collapsing headers,
    different templates (can be different heights) in the same list, and searching.

    autoScrollBox:Setup(definition) -- sets up an autoScrollBox from a definition table (see below)
    autoScrollBox:Update() -- repopulates and updates the autoScrollBox
    autoScrollBox:Refresh() -- just updates the already-displayed buttons for minor changes
    autoScrollBox:SetCompactMode(true/false) -- changes from normal to compact mode (switches templates)
    autoScrollBox:GetCompactMode() -- returns true/false if in compact mode
    autoScrollBox:ToggleHeader(data) -- for expandable lists, expand/collapse header with data value
    autoScrollBox:ToggleAllHeaders(data) -- for expandable lists, expand/collapse all headers
    autoScrollBox:CollapseAllHeaders() -- for expandable lists, collapses all headers
    autoScrollBox:CollapseAllButData(data) -- for expandable lists, collapses all headers except the one for data
    autoScrollBox:IsHeaderExpanded(data) -- returns true if the header at data is expanded
    autoScrollBox:IsAnyExpanded() -- returns true if any header is expanded
    autoScrollBox:IsSearching() -- returns true if a search is happening (searchMask has a value)
    autoScrollBox:Select(name,data) -- selects the listbutton that contains data with the named select (or unselects if data nil)
    autoScrollBox:GetSelected(name) -- returns the currently selected data for the named select
    autoScrollBox:ScrollToTop() -- scrolls to top of the list
    autoScrollBox:ScrollDataToTop(data) -- scrolls data to the top of the list
    autoScrollBox:ScrollHeaderIntoView(data) -- scrolls header(data) into view and as much of its contents if expanded
    autoScrollBox:ScrollDataIntoView(data) -- scrolls data into view, expanding header it's within if needed
    autoScrollBox:BlingData(data) -- flashes frame that contains data, scrolling it into view if needed
    autoScrollBox:LockHeader() -- locks headers so they can't be expanded/collapsed
    autoScrollBox:UnlockHeaders() -- unlocks headers so they can be expanded/collapsed
    autoScrollBox:IsHeadersLocked() -- true if headers are locked

    definition passed in Setup() defines the templates, callbacks and behavior of the autoScrollBox:

    definition = {
        allData = {}, -- (required) ordered list of data/id's that has meaning to the calling panel
        normalTemplate = "", -- (required) list button template for normal stuff
        normalFill = function(button,data) end, -- (required) fill function for normal stuff
        normalHeight = 0, -- (required) pixel height of a normal list button

        -- all the following are optional (unless their functionality needed)

        isCompact = true/false, -- whether this starts as a compact-mode list
        compactTemplate = "", -- list button template for compact stuff
        compactFill = function(button,data) end, -- fill function for compact stuff
        compactHeight = 0, -- pixel height of a compact list button

        headerTemplate = "", -- header button template
        headerFill = function(button,data) end, -- fill function for headers
        headerCriteria = function(self,data) end, -- returns true if data is a header
        headerHeight = 0, -- pixel height of a header list button

        placeholderTemplate = "", -- placeholder button template
        placeholderFill = function(button,data) end, -- fill function for placeholders
        placeholderCriteria = function(self,data) end, -- returns true if data is a placeholder
        placeholderHeight = 0, -- pixel height of a placeholder list button

        allButton = <button>, -- button that inherits AllButtonTemplate (optional)
        expandedHeaders = {}, -- unordered table of expanded headers {header1=true,header3=true,etc}

        searchBox = <editbox>, -- EditBox where search text is entered
        searchHit = function(self,mask,data) end, -- whether data should be listed (data matches mask)

        onUpdate = function(self,percent,...) -- function called when list is updated
        onScroll = function(self,percent,...) -- function called when list is scrolled

        selects = { -- for use with autoScrollBox:Select(name,data)
            name1 = {
                        color = {r,g,b,a}, -- vertex color/alpha of select texture (white if not defined)
                        alphaMode = "", -- blend mode ("ADD", "BLEND") of select texture ("BLEND" if not defined)
                        parentKey = "<parentKey>", -- which parentKey select texture should anchor to (eg "Back") (whole button if not defined)
                        padding = <number> or {left,right,top,bottom}, -- px space around edge (0 if not defined)
                        drawLayer = "", -- drawLayer of the select texture ("OVERLAY" if not defined)
                        textureSubLevel = <number> -- textureSubLevel for the drawLayer (0 if not defined)
                        tint = true/false, -- whether to use a solid color texture over whole button
                    },
            name2 = { -- alternate selects supported (such as one select for summoned pet and another for pet card pet)
                        color = {r,g,b},
                        alphaMode = "",
                        parentKey = "<parentKey>",
                        padding = <number> or {left,right,top,bottom},
                        drawLayer = "",
                        textureSubLevel = <number>,
                        tint = false,
                    },
        }

    }

    Notes:
    - If allButton is defined, then its OnClick will be taken over (hook it after Setup(def) if needed)
    - If searchBox is defined, then its OnTextChanged will be taken over (hook it after Setup(def) if needed)
    - isCompact property should only be updated by SetCompactMode() since it needs to rebuild the view too
    - The BlingData texture is BACKGROUND textureSubLevel 7
    - The BlingData frame will anchor to parent.Back if it exists or whole parent if it doesn't

]]

local setView, populateList, handleSelect, setupSelect, getDataHeight, updateListSpeed -- local functions defined at end
local disableSearch = false -- set to true during a setView

local selectFrames = {} -- indexed by autoscrollbox(self), unordered {selectName=Frame,selectName=Frame,etc}

local allLists = {} -- lookup table of all AutoScrollBox frames that get set up (indexed by autoscrollbox)

RematchAutoScrollBoxMixin = {}

-- sets up the scrollbox definition, view, factories and data provider; this should be called only once
function RematchAutoScrollBoxMixin:Setup(definition)
    -- some verification that necessities are defined
    assert(type(definition)=="table","Invalid AutoScrollBox definition table")
    assert(type(definition.allData)=="table","Missing allData for AutoScrollBox")
    assert(type(definition.normalTemplate)=="string" and type(definition.normalFill)=="function","Invalid AutoScrollBox normal template")
    assert(type(definition.normalHeight)=="number" and definition.normalHeight>0,"Invalid AutoScrollBox normal height")

    -- if already setup, leave
    if self.isSetup then
        return
    end

    Mixin(self,definition) -- absorbing attributes of the definition to self
    self.displayData = {} -- managed in this module, list of data to display (can be subset of allData)

    if self.allButton then
        self.allButton:SetScript("OnClick",function()
            self:ToggleAllHeaders()
            PlaySound(C.SOUND_HEADER_CLICK)
        end)
    end

    -- and if searchBox defined, this AutoScrollBox is going to take over its OnTextChanged
    if self.searchBox then
        self.searchMask = ""
        self.searchBox:SetScript("OnTextChanged",function(editBox) -- note editBox rather than self; keeping self reference to AutoScrollBox
            local text = editBox:GetText()
            local newMask
            if text and text:match(rematch.constants.PET_ID_PATTERN) then
                newMask = text -- special case if search is a petID (Battle-0-000000000000), don't desensitize it
            else
                newMask = rematch.utils:DesensitizeText(text)
            end
            if newMask~=self.searchMask then
                self.searchMask = newMask
                self:Update()
            end
        end)
    end

    -- if selects defined, this AutoScrollBox will have at least one selectFrames
    if type(definition.selects)=="table" then
        for name,selectDefinition in pairs(definition.selects) do
            self:SetupSelect(name,selectDefinition)
        end
    end

    if type(definition.onUpdate)=="function" then
        self.ScrollBox:RegisterCallback("OnUpdate",function(...) definition.onUpdate(self,...) end)
    end

    if type(definition.onScroll)=="function" then
        self.ScrollBox:RegisterCallback("OnScroll",function(...) definition.onScroll(self,...) end)
    end

    -- separate OnScroll callback to disable ScrollToTopButton/ScrollToBottomButton
    self.ScrollBox:RegisterCallback("OnScroll",function(...)
        local _,percent,_,extent = ...
        if extent==0 then -- can't scroll, disable top and bottom
            self.ScrollToTopButton:SetToDisable()
            self.ScrollToBottomButton:SetToDisable()
        elseif percent<0.00000001 then -- at top, disable top, enable bottom
            self.ScrollToTopButton:SetToDisable()
            self.ScrollToBottomButton:SetToEnable()
        elseif percent>0.99999999 then -- at bottom, enable top, disable bottom
            self.ScrollToTopButton:SetToEnable()
            self.ScrollToBottomButton:SetToDisable()
        else -- somewhere in middle of scrollable list, enable top and bottom
            self.ScrollToTopButton:SetToEnable()
            self.ScrollToBottomButton:SetToEnable()
        end
    end)

    self.ScrollBox:RegisterCallback("OnUpdate",function(...)
        updateListSpeed(self)
    end)

    setView(self) -- create view (local so it can't be called from outside here or SetCompactMode)

    self.ScrollBox:SetPanExtent(self.isCompact and self.compactHeight or self.normalHeight)

    allLists[self] = true
    updateListSpeed(self)

    self.isSetup = true
end

-- updates the scrollbox to reflect both the contents of allData and the header/search effect if any
function RematchAutoScrollBoxMixin:Update()
    -- first clear the CaptureButton; we don't know how far the list extends yet
    self.CaptureButton:ClearAllPoints()
    self.CaptureButton:Hide()
    -- update the displayData that will be fed into the data provider
    populateList(self)
    -- update the data provider from displayData
    self.dataProvider = CreateDataProvider()
    for _,data in ipairs(self.displayData) do
        self.dataProvider:Insert(data)
    end
    self.ScrollBox:SetDataProvider(self.dataProvider,ScrollBoxConstants.RetainScrollPosition)
    -- update allButton if one defined and headers used
    if self.allButton and self.expandedHeaders then
        self.allButton:SetEnabled(not self:IsSearching() and not self:IsHeadersLocked())
        self.allButton:SetExpanded(self:IsAnyExpanded())
    end
    if self.searchBox then
        self.searchBox:SetEnabled(not self:IsHeadersLocked())
    end
    -- if list doesn't take up enough space to be scrollable, there's empty space; fill with CaptureButton
    if not self:IsScrollable() then
        local lastListButton = self:GetLastListButton()
        if lastListButton then -- there's at least one button, anchor topleft to it
            self.CaptureButton:SetPoint("TOPLEFT",lastListButton,"BOTTOMLEFT")
        else -- if there is no lastListButton, make capture extend whole autoscrollbox area
            self.CaptureButton:SetPoint("TOPLEFT",self,"TOPLEFT",5,-4)
        end
        self.CaptureButton:SetPoint("BOTTOMRIGHT",self,"BOTTOMRIGHT",-29,4)
        self.CaptureButton:Show()
    end
end

-- if any list has a speed set, all lists are set to the same speed
function RematchAutoScrollBoxMixin:SetSpeed(speed)
    if speed==C.MOUSE_SPEED_SLOW or speed==C.MOUSE_SPEED_NORMAL or speed==C.MOUSE_SPEED_MEDIUM or speed==C.MOUSE_SPEED_FAST then
        settings.MousewheelSpeed = speed
    else
        settings.MousewheelSpeed = C.MOUSE_SPEED_NORMAL
    end
    for list in pairs(allLists) do
        updateListSpeed(list)
    end
end

-- returns true if the list has enough content that it's scrollable
function RematchAutoScrollBoxMixin:IsScrollable()
    return self.ScrollBar:HasScrollableExtent()
end

-- for lists that aren't scrollable, get the last displayed listbutton (for drag/drop interactions with CaptureButton)
-- (when the list is full and scrollable this is the last defined button that's visible--but may be off edge of bottom)
function RematchAutoScrollBoxMixin:GetLastListButton()
    local frames = self.ScrollBox:GetFrames()
    for i=#frames,1,-1 do
        if frames[i]:IsVisible() then
            return frames[i]
        end
    end
end

-- refreshes the contents of the visible buttons; this is intended for select/unselecting and
-- other minor interactions with the scrollbox. if any data may change or scrolling happen, use
-- autoscrollbox:Update() instead
function RematchAutoScrollBoxMixin:Refresh()
    for _,frame in ipairs(self.ScrollBox:GetFrames()) do
        local data = frame.data
        if not frame:IsVisible() or not data then
            -- do nothing, possibly an empty list
        elseif self.headerCriteria and self.headerCriteria(self,data) then
            self.headerFill(frame,data)
            handleSelect(self,frame)
        elseif self.placeholderCriteria and self.placeholderCriteria(self,data) then
            self.placeholderFill(frame,data)
            handleSelect(self,frame)
        elseif self.isCompact then
            self.compactFill(frame,data)
            handleSelect(self,frame)
        else
            self.normalFill(frame,data)
            handleSelect(self,frame)
        end
    end
    if self.allButton and self.expandedHeaders then
        self.allButton:SetEnabled(not self:IsSearching() and not self:IsHeadersLocked())
    end
    if self.searchBox then
        self.searchBox:SetEnabled(not self:IsHeadersLocked())
    end
end

-- locks headers so they can't be expanded/collapsed
function RematchAutoScrollBoxMixin:LockHeaders()
    self.headersLocked = true
    self:Refresh()
end

-- unlocks headers so they can be expanded/collapsed
function RematchAutoScrollBoxMixin:UnlockHeaders()
    self.headersLocked = false
    self:Refresh()
end

-- returns current lock state of headers
function RematchAutoScrollBoxMixin:IsHeadersLocked()
    return self.headersLocked
end

-- changes to/from normal and compact modes (rebuilds view too)
function RematchAutoScrollBoxMixin:SetCompactMode(isCompact)
    local newCompact = isCompact and true or false
    if self:GetCompactMode()~=newCompact then -- only need to change if value is different
        self.isCompact = newCompact
        setView(self)
        self.ScrollBox:SetPanExtent(self.isCompact and self.compactHeight or self.normalHeight)
    end
end

-- gets the current compact mode
function RematchAutoScrollBoxMixin:GetCompactMode()
    return self.isCompact and true or false
end

-- this expands a header and scrolls it to the top, clearing search if any happening;
-- the calling function should also clear the searchbox if it has instructions/other stuff
-- collapseOthers will collapse all other headers
function RematchAutoScrollBoxMixin:ExpandHeader(data,collapseOthers)
    if not self:IsHeadersLocked() and self.expandedHeaders and self.headerCriteria(self,data) then
        -- clear search
        self.searchMask = ""
        self.searchBox:SetText("")
        -- collapse all headers if chosen
        if collapseOthers then
            wipe(self.expandedHeaders)
        end
        -- ensure this header expanded
        self.expandedHeaders[data] = true
        -- update and scroll to top
        self:Update()
        if self.expandedHeaders[data] then
            self:ScrollDataToTop(data)
        end
    end
end

-- toggles the given header and updates the list if expandedHeaders was defined
function RematchAutoScrollBoxMixin:ToggleHeader(data)
    if self.expandedHeaders and not self:IsSearching() and not self:IsHeadersLocked() and self.headerCriteria(self,data) then
        self.expandedHeaders[data] = not self.expandedHeaders[data] or nil -- toggle true/nil
        self:Update()
        if self.expandedHeaders[data] then -- if expanding a header, scroll the header and contents into view
            self:ScrollHeaderIntoView(data)
        end
    end
end

-- collapses or expands all headers in self.expandedHeaders and updates the list
function RematchAutoScrollBoxMixin:ToggleAllHeaders()
    if self.expandedHeaders and not self:IsSearching() and not self:IsHeadersLocked() then
        if self:IsAnyExpanded() then
            wipe(self.expandedHeaders)
        else
            for _,data in ipairs(self.allData) do
                if self.headerCriteria(self,data) then
                    self.expandedHeaders[data] = true
                end
            end
        end
        self:Update()
    end
end

-- collapses all  headers
function RematchAutoScrollBoxMixin:CollapseAllHeaders(noUpdate)
    if self.expandedHeaders and next(self.expandedHeaders) then
        wipe(self.expandedHeaders)
        if not noRefresh then
            self:Update()
        end
    end
end

-- collapses all headers except for the one that contains data (expands if not expanded), and keeps data in view
function RematchAutoScrollBoxMixin:CollapseAllButData(data)
    if self.expandedHeaders then
        -- first verify if anything needs done
        local expandedCount = 0
        local expandedData
        if rematch.utils:GetSize(self.expandedHeaders)==1 then -- if only one header expanded
            for _,atData in ipairs(self.displayData) do
                if atData==data then -- and data is within that expanded header
                    return -- then our work is done, leave
                end
            end
        end
        wipe(self.expandedHeaders) -- close all headers
        -- find the one belonging to data (it may be data itself)
        local atHeader
        for _,atData in ipairs(self.allData) do
            if self.headerCriteria(self,atData) then
                atHeader = atData
            end
            if atData==data then
                break
            end
        end
        if atHeader then
            self.expandedHeaders[atHeader] = true
        end
    end
    -- update to get headers collapsed
    self:Update()
    -- then scroll data back into view if needed
    self:ScrollDataIntoView(data)
end

-- returns true if the given data is an expanded header
function RematchAutoScrollBoxMixin:IsHeaderExpanded(data)
    return self.expandedHeaders and self.expandedHeaders[data] or false
end

-- returns true if at least one header is expanded
function RematchAutoScrollBoxMixin:IsAnyExpanded()
    return next(self.expandedHeaders) and true or false
end

-- returns true if a search is in progress (non-empty mask and there's a searchHit function)
function RematchAutoScrollBoxMixin:IsSearching()
    return self.searchMask and self.searchHit and self.searchMask~="" and not disableSearch
end

-- puts the named select onto the button that contains data, if any (or clears if none or it's not in view)
-- when the list is going to be updated by the calling function already, noRefresh = true to skip the refresh
function RematchAutoScrollBoxMixin:Select(name,data,noRefresh)
    local selectFrame = selectFrames[self] and selectFrames[self][name]
    if selectFrame and selectFrame.data~=data then
        selectFrame.data = data
        if not noRefresh then
            self:Refresh()
        end
    end
end

-- returns the data currently selected for the named select
function RematchAutoScrollBoxMixin:GetSelected(name)
    local selectFrame = selectFrames[self] and selectFrames[self][name]
    if selectFrame then
        return selectFrame.data
    end
end

-- creates or updates a selectFrame of the given properties, to use with autoscrollbox:Select(name,data)
function RematchAutoScrollBoxMixin:SetupSelect(name,def)
    assert(type(name)=="string" and type(def)=="table","Invalid AutoScrollBox SetupSelect")
    if not selectFrames[self] then
        selectFrames[self] = {}
    end
    if name and not selectFrames[self][name] then
        selectFrames[self][name] = CreateFrame("Frame",nil,self,def.tint and "RematchAutoScrollBoxTintTemplate" or "RematchAutoScrollBoxSelectTemplate")
    end
    local selectFrame = selectFrames[self][name]
    -- color is {red,greem,blue[,alpha]}
    if def.tint then
        selectFrame.Texture:SetColorTexture(def.color[1] or 1,def.color[2] or 1,def.color[3] or 1,def.color[4] or 1)
    elseif type(def.color)=="table" then
        for _,texture in ipairs(selectFrame.Textures) do
            texture:SetVertexColor(def.color[1] or 1,def.color[2] or 1,def.color[3] or 1,def.color[4] or 1)
        end
    end
    -- if defined, parentKey is the parentKey of the listbutton the select frame is anchored to
    selectFrame.parentKey = def.parentKey
    if not def.tint then
        -- if padding is a single number, nudge corners in by that amount
        if type(def.padding)=="number" then
            selectFrame.TopLeft:SetPoint("TOPLEFT",def.padding,-def.padding)
            selectFrame.TopRight:SetPoint("TOPRIGHT",-def.padding,-def.padding)
            selectFrame.BottomLeft:SetPoint("BOTTOMLEFT",def.padding,def.padding)
            selectFrame.BottomRight:SetPoint("BOTTOMRIGHT",-def.padding,def.padding)
        end
        -- if def.padding is {left,right,top,bottom}, nudge corners in by those amounts
        if type(def.padding)=="table" then
            selectFrame.TopLeft:SetPoint("TOPLEFT",def.padding[1] or 0,-def.padding[3] or 0)
            selectFrame.TopRight:SetPoint("TOPRIGHT",-def.padding[2] or 0,-def.padding[3] or 0)
            selectFrame.BottomLeft:SetPoint("BOTTOMLEFT",def.padding[1] or 0,def.padding[4] or 0)
            selectFrame.BottomRight:SetPoint("BOTTOMRIGHT",-def.padding[2] or 0,def.padding[4] or 0)
        end
        -- drawLayer can include an optional textureSubLevel
        if type(def.drawLayer)=="string" then
            for _,texture in ipairs(selectFrame.Textures) do
                texture:SetDrawLayer(def.drawLayer,def.textureSubLevel)
            end
        end
        -- alphaMode is commonly "ADD", "BLEND"
        if type(def.alphaMode)=="string" then
            for _,texture in ipairs(selectFrame.Textures) do
                texture:SetBlendMode(def.alphaMode)
            end
        end
    end

end

-- scrolls to the top of the list
function RematchAutoScrollBoxMixin:ScrollToTop()
    self.ScrollBox:ScrollToOffset(0,floor(self:GetHeight()+0.5))
end

-- scrolls the list so that the given data is at top
function RematchAutoScrollBoxMixin:ScrollDataToTop(data)
    local height = 0
    for index,atData in ipairs(self.displayData) do
        if atData==data then
            self.ScrollBox:ScrollToOffset(height,floor(self:GetHeight()+0.5))
            return
        end
        height = height + getDataHeight(self,atData)
    end
end

-- if a header is not within the frame, or its contents extend beyond the bottom of the frame, scroll the header
-- up until contents are in view or the header is at the top of the frame
function RematchAutoScrollBoxMixin:ScrollHeaderIntoView(data)
    if not data or not self.headerCriteria or not self.headerCriteria(self,data) then
        return -- data isn't a header, get out of here
    end
    local height = 0 -- running total offset from top
    local frameHeight = floor(self:GetHeight() + 0.5)
    -- define top/bottom boundry
    local topOffset = floor(self.ScrollBox:GetDerivedScrollOffset() + 0.5)
    local bottomOffset = topOffset + frameHeight
    -- find header offset and the height of the header and its contents
    local headerOffset
    local contentHeight
    for index,atData in ipairs(self.displayData) do
        if headerOffset and contentHeight then -- we have everything needed, stop looking
            break
        elseif atData==data then
            headerOffset = height
        elseif headerOffset and self.headerCriteria(self,atData) then -- found next header after one we're scrolling
            contentHeight = height - headerOffset
        end
        height = height + getDataHeight(self,atData)
    end
    -- couldn't find header, leave with no change
    if not headerOffset then
        return
    end
    -- if reached end of list without running into another header to define contentHeight, then content is the rest
    if not contentHeight then
        contentHeight = height - headerOffset
    end
    -- if header and its content are within the top/bottom offsets of the frame, everything is good, leave
    if headerOffset >= topOffset and headerOffset+contentHeight <= bottomOffset then
        return
    end
    -- including half of next header in visible content so it's obvious that the current header's content has ended
    contentHeight = contentHeight + self.headerHeight/2
    -- if header and its contents span more than the height of the frame, scroll header to top
    if contentHeight >= frameHeight then
        self.ScrollBox:ScrollToOffset(headerOffset,frameHeight)
    else -- if header and contents can fit but don't yet, scroll up the difference
        local difference = headerOffset+contentHeight - bottomOffset + 8
        if difference ~= 0 then -- was > 0 before when scrolling up to be in view (may revisit when scrolling down into view)
            self.ScrollBox:ScrollToOffset(topOffset+difference,frameHeight)
        end
    end
end

-- if the data is not already in view, scroll it into view, potentially expanding the header it's in if so
function RematchAutoScrollBoxMixin:ScrollDataIntoView(data)
    -- first if this is a header, use ScrollHeaderIntoView instead (so if expanded it will bring contents up too)
    if self.headerCriteria and self.headerCriteria(self,data) then
        self:ScrollHeaderIntoView(data)
        return
    end
    -- confirm data exists, capturing which header it's in on the way
    local found = false
    local headerID -- watching these to keep track of which header it's in
    for _,atData in ipairs(self.allData) do
        if self.headerCriteria and self.headerCriteria(self,atData) then
            headerID = atData
        elseif data==atData then
            found = true
            break
        end
    end
    if not found then
        return -- didn't find the data, leave
    end
    -- if headers are used and data is within a header not expanded, it needs expanded
    if headerID and not self.expandedHeaders[headerID] then
        self:ToggleHeader(headerID) -- this will scroll header into view also
    end
    -- check if data is visible
    if self:IsDataVisible(data) then
        return -- data is visible, leave
    end
    -- here, data is in displayData but not visible, scroll to it
    local height = 0
    for index,atData in ipairs(self.displayData) do
        if atData==data then
            -- centering data: scrolling to height (offset of data) - half frame height + data height
            local frameHeight = floor(self:GetHeight()+0.5)
            self.ScrollBox:ScrollToOffset(height-frameHeight/2+getDataHeight(self,data),frameHeight)
            return -- scrolled data to center, leave
        end
        height = height + getDataHeight(self,atData)
    end
end

-- flashes a list button by moving the Bling frame
function RematchAutoScrollBoxMixin:BlingData(data)
    if not self:IsDataVisible(data) then
        self:ScrollDataIntoView(data) -- first scroll it into view if it's not visible
    end
    -- then loop over visible buttons to find the one to bling
    for _,frame in pairs(self.ScrollBox:GetFrames()) do
        if frame.data==data and frame:IsVisible() then
            self.Bling:ClearAllPoints()
            self.Bling:SetParent(frame)
            local anchorTo = frame.Back
            if not anchorTo or not anchorTo:IsVisible() then
                anchorTo = frame
            end
            self.Bling:SetPoint("TOPLEFT",anchorTo,"TOPLEFT",1,-1)
            self.Bling:SetPoint("BOTTOMRIGHT",anchorTo,"BOTTOMRIGHT",-1,1)
            self.Bling:Show()
            return
        end
    end
end

-- returns true if the data is in the visible list (one of the displayed list buttons contains data)
function RematchAutoScrollBoxMixin:IsDataVisible(data)
    for _,frame in pairs(self.ScrollBox:GetFrames()) do
        if frame.data==data and frame:IsVisible() then
            return true -- data is visible
        end
    end
    return false -- data is not visible
end

-- alternate form of IsDataInVisible that also returns data about where it is
function RematchAutoScrollBoxMixin:IsDataInView(data)
    local height = 0 -- running total offset from top
    local frameHeight = floor(self:GetHeight() + 0.5)
    -- define top/bottom boundry
    local topOffset = floor(self.ScrollBox:GetDerivedScrollOffset() + 0.5)
    local bottomOffset = topOffset + frameHeight
    for index,atData in ipairs(self.displayData) do
        if atData==data then
            break
        end
        height = height + getDataHeight(self,atData)
    end
    -- here, height is the top offset of data; return true if height is between topOffset and bottomOffset
    if height >= topOffset and (height + getDataHeight(self,data)) <= bottomOffset then
        return true, height, topOffset -- return true, offset of data, offset of top of frame
    else
        return false, height, topOffset
    end
end

-- returns the frame data is in, if it's visible
function RematchAutoScrollBoxMixin:GetDataFrame(data)
    for _,frame in pairs(self.ScrollBox:GetFrames()) do
        if frame.data==data and frame:IsVisible() then
            return frame
        end
    end
end

--[[ scroll to end button mixin ]]

RematchAutoScrollBoxScrollToEndMixin = {}

function RematchAutoScrollBoxScrollToEndMixin:OnMouseDown()
    if not self.isDisabled then
        self.Texture:SetTexCoord(0,1,0.5,1)
        self.Highlight:SetTexCoord(0,1,0.5,1)
    end
end

function RematchAutoScrollBoxScrollToEndMixin:OnMouseUp()
    if not self.isDisabled then
        self.Texture:SetTexCoord(0,1,0,0.5)
        self.Highlight:SetTexCoord(0,1,0,0.5)
    end
end

-- self.scrollMethod should be "ScrollToBegin" or "ScrollToEnd", the ScrollBox method to scroll to top/bottom
function RematchAutoScrollBoxScrollToEndMixin:OnClick(button)
    local scrollBox = self:GetParent().ScrollBox
    scrollBox[self.scrollMethod](scrollBox)
    PlaySound(SOUNDKIT.IG_CHAT_BOTTOM)
end

-- to minimize work since this can be called many times while scrolling, this only does work if button needs enabled
function RematchAutoScrollBoxScrollToEndMixin:SetToEnable()
    if self.isDisabled then
        self.isDisabled = false
        self:GetScript("OnMouseUp")(self)
        self:SetAlpha(1)
        self:GetParent().ScrollBar[self.stepButton]:SetAlpha(1) -- un-dims the scrollbar's built-in Back/Forward button
        self.Highlight:SetAlpha(0.3)
    end
end

-- to minimize work since this can be called many times while scrolling, this only does work if button needs disabled
function RematchAutoScrollBoxScrollToEndMixin:SetToDisable()
    if not self.isDisabled then
        self:GetScript("OnMouseUp")(self)
        self:SetAlpha(0.5)
        self:GetParent().ScrollBar[self.stepButton]:SetAlpha(0.5) -- dims the scrollbar's built-in Back/Forward button
        self.Highlight:SetAlpha(0)
        self.isDisabled = true
    end
end

--[[ local stuff ]]

-- this fills displayData with data from allData. for simple lists with no headers or search, it's a direct copy;
-- when headers or searching is involved, displayData is likely a subset of allData
function populateList(self)
    wipe(self.displayData)
    local skip = false
    local hasHeaders = self.expandedHeaders and self.headerTemplate and self.headerCriteria and true or false
    local hasSearch = self.searchHit and self:IsSearching()
    if hasHeaders and hasSearch then
        wipe(self.expandedHeaders) -- searching collapses headers (otherwise things get weird)
    end
    for index,data in ipairs(self.allData) do
        local add = false
        if not hasHeaders and not hasSearch then
            -- no headers no search, just list everything
            add = true
        elseif not hasHeaders and hasSearch then
            -- no headers but search happening, list all search hits
            add = self.searchHit(self,self.searchMask,data) and true or false
        elseif hasHeaders and not hasSearch then
            -- headers are used but no search, list all headers and expanded contents
            if self.headerCriteria(self,data) then
                add = true
                skip = not self.expandedHeaders[data]
            elseif not skip then
                add = true
            end
        elseif hasHeaders and hasSearch then
            -- both headers and search used; take a deep breath
            -- 1. always add headers
            -- 2. if adding a header right after another while searching, deleting previous header if it doesn't search hit
            -- 3. if header search hit, add everything after until next header
            -- 4. when done, if last item is a header, delete it if it's not a search hit
            if self.headerCriteria(self,data) then
                add = true -- always add headers initially (this may be removed)
                if index>1 then
                    local lastData = self.displayData[#self.displayData]
                    if self.headerCriteria(self,lastData) and not self.searchHit(self,self.searchMask,lastData) then
                        tremove(self.displayData,#self.displayData) -- if we just added a header (that wasn't a search hit) and adding a new one, delete prior
                    end
                end
                skip = not self.searchHit(self,self.searchMask,data)
            elseif not skip then -- header was a search hit, list everything under this header
                add = true
            elseif self.searchHit(self,self.searchMask,data) then -- non-header search hit
                add = true
            end
        end
        if add then
            tinsert(self.displayData,data)
        end
    end
    -- finally, if headers and search used, drop any trailing headers that were not a search hit
    if hasHeaders and hasSearch then
        local lastData = self.displayData[#self.displayData]
        if self.headerCriteria(self,lastData) and not self.searchHit(self,self.searchMask,lastData) then
            tremove(self.displayData,#self.displayData)
        end
    end
end

-- creates and sets the view, only called in initial Setup and SetCompactMode
function setView(self)
    if self.view then
        self.view:Flush() -- if old view exists, release its stuff
    end
    -- isCompact is a local value here because once a view is created, switching to/from compact mode without
    -- rebuilding the view has undesirable effects (script ran too long lockup)
    local isCompact = self.isCompact and type(self.compactFill)=="function" and type(self.compactTemplate)=="string"
    self.view = CreateScrollBoxListLinearView()
    self.view:SetElementFactory(function(factory,data)
        if self.headerCriteria and self.headerFill and self.headerTemplate and (self.headerCriteria(self,data) or data=="PrimeHeader") then
            factory(self.headerTemplate,function(button,data)
                button.data = data
                self.headerFill(button,data)
                handleSelect(self,button)
            end)
        elseif self.placeholderCriteria and self.placeholderFill and self.placeholderTemplate and (self.placeholderCriteria(self,data) or data=="PrimePlaceholder") then
            factory(self.placeholderTemplate,function(button,data)
                button.data = data
                self.placeholderFill(button,data)
                handleSelect(self,button)
            end)
        elseif isCompact then
            factory(self.compactTemplate,function(button,data)
                button.data = data
                self.compactFill(button,data)
                handleSelect(self,button)
            end)
        else
            factory(self.normalTemplate,function(button,data)
                button.data = data
                self.normalFill(button,data)
                handleSelect(self,button)
            end)
        end
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox,self.ScrollBar,self.view)

    -- when mixed templates are used, the client can freeze up when a different-sized one is brought in later,
    -- such as 20 collapsed 24px-tall headers expanding to show 40px-tall normal list buttons amid the headers.
    -- this will "prime the pump" of the header and non-header versions (compact and normal are mutually exclusive)
    -- by creating and updating a list of 2 elements--a header and non header--which seems to fix the issue
    if self.headerTemplate and self.headerCriteria then
        disableSearch = true -- these two elements probably won't match a search and they need to be added
        self.dataProvider = CreateDataProvider()
        self.dataProvider:Insert("PrimeHeader")
        self.dataProvider:Insert("PrimeNonHeader")
        self.dataProvider:Insert("PrimePlaceholder")
        self.ScrollBox:SetDataProvider(self.dataProvider,ScrollBoxConstants.RetainScrollPosition)
        self.dataProvider:RemoveIndexRange(1,2) -- view should be safe now, removing two elements from data provider
        disableSearch = false
    end
end

-- called in fills to claim a selectFrame if the selectFrame's data matches the data being filled
function handleSelect(self,button)
    if selectFrames[self] then
        for _,selectFrame in pairs(selectFrames[self]) do
            if button.data and button.data==selectFrame.data then -- if this button should be selected, claim the selectFrame
                selectFrame:SetParent(button)
                selectFrame:SetPoint("TOPLEFT",selectFrame.parentKey and button[selectFrame.parentKey] or button,"TOPLEFT")
                selectFrame:SetPoint("BOTTOMRIGHT",selectFrame.parentKey and button[selectFrame.parentKey] or button,"BOTTOMRIGHT")
                selectFrame:Show()
                selectFrame.parent = button
            elseif selectFrame.parent==button or not selectFrame.parent then -- otherwise if selectframe is attached to this button and shouldn't be, or it's not claimed, hide it
                selectFrame:Hide()
                selectFrame.parent = nil
            end
        end
    end
end

-- returns the pixel height of the button that data would exist in
function getDataHeight(self,data)
    if self.headerCriteria and self.headerCriteria(self,data) then
        return self.headerHeight
    elseif self.placeholderCriteria and self.placeholderCriteria(self,data) then
        return self.placeholderHeight
    elseif self.isCompact then
        return self.compactHeight
    else
        return self.normalHeight
    end
end

-- updates the list (autoscrollbox) wheelPanScalar to adjust scroll speed to settings.MousewheelSpeed
function updateListSpeed(list)
    if allLists[list] then
        local speed = settings.MousewheelSpeed
        local scrollBox = list.ScrollBox
        local wheelPanScalar
        if speed==C.MOUSE_SPEED_SLOW then
            wheelPanScalar = 1
        elseif speed==C.MOUSE_SPEED_NORMAL then
            wheelPanScalar = 2
        else -- the other speeds are based on height of the list (autoscrollbox)
            local panExtent = max(scrollBox:GetPanExtent() or 0,1)
            local height = list:GetHeight()-panExtent
            if speed==C.MOUSE_SPEED_MEDIUM then
                wheelPanScalar = (height/2-(height/2)%panExtent)/panExtent
            elseif speed==C.MOUSE_SPEED_FAST then
                wheelPanScalar = (height-height%panExtent)/panExtent
            end
        end
        scrollBox.wheelPanScalar = (wheelPanScalar and wheelPanScalar>0) and wheelPanScalar or 2
    end
end
