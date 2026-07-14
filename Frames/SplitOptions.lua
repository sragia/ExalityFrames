local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesSplitOptionsScrollFrame
local scrollFrame = EXFrames:GetFrame('smooth-scroll-frame')

---@class ExalityFramesListMenu
local listMenu = EXFrames:GetFrame('list-menu-frame')

--- @class ExalityFramesSplitOptionsFrame
local splitOptions = EXFrames:GetFrame('split-options-frame')

splitOptions.Init = function(self)
    splitOptions.pool = CreateFramePool('Frame', UIParent)
end

local function CreateItem(parent)
    local button = CreateFrame('Button', nil, parent)
    button:SetHeight(EXFrames:ScalePixel(20, parent))

    local bg = button:CreateTexture(nil, 'BACKGROUND')
    bg:SetTexture(EXFrames.assets.textures.solidWhite)
    bg:SetVertexColor(unpack(EXFrames.Theme.background))
    bg:SetAllPoints()
    button.bg = bg

    EXFrames:ApplyInputBorder(button, 1)

    local text = button:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    text:SetPoint('CENTER')
    button.text = text

    button.SetActive = function(self, active)
        if (active) then
            self.bg:SetVertexColor(unpack(EXFrames.Theme.backgroundPanel))
            self:SetInputBorderActive(true)
        else
            self.bg:SetVertexColor(unpack(EXFrames.Theme.background))
            self:SetInputBorderActive(false)
        end
    end

    button.SetText = function(self, text)
        self.text:SetText(text or "")
    end

    button:SetScript('OnClick', function(self, mouseButton)
        if mouseButton == 'RightButton' then
            if self.contextMenuItems and #self.contextMenuItems > 0 and self.onShowContextMenu then
                self:onShowContextMenu()
            end
            return
        end
        if self.onItemClick then
            self:onItemClick(self.ID)
        end
    end)

    button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

    return button
end

local function buildContextMenuEntries(itemID, menuItems)
    local entries = {}
    for _, menuItem in ipairs(menuItems) do
        table.insert(entries, {
            text = menuItem.label or menuItem.text,
            icon = menuItem.icon,
            color = menuItem.color,
            hoverColor = menuItem.hoverColor,
            onClick = function(_, button)
                if menuItem.onClick then
                    menuItem.onClick(itemID, button)
                end
            end,
        })
    end
    return entries
end

local configure = function(f)
    f.items = {}
    f.onItemClick = nil
    f.activeID = nil

    local leftPanel = EXFrames:GetFrame('panel-frame'):Create()
    leftPanel:SetBackgroundColor(0.05, 0.05, 0.05, 0.8)
    leftPanel:SetParent(f)
    f.leftPanel = leftPanel

    local rightPanel = EXFrames:GetFrame('panel-frame'):Create()
    rightPanel:SetBackgroundColor(0.05, 0.05, 0.05, 0.8)
    rightPanel:SetParent(f)
    f.rightPanel = rightPanel

    f.ApplyPanelLayout = function(self)
        local panelInset = EXFrames:ScalePixel(5, self)
        local leftWidth = EXFrames:ScalePixel(135, self)
        local scrollTopInset = EXFrames:ScalePixel(15, self.rightPanel)
        local scrollBottomInset = EXFrames:ScalePixel(8, self.rightPanel)
        local scrollSideInset = EXFrames:ScalePixel(5, self.rightPanel)

        self.leftPanel:ClearAllPoints()
        self.leftPanel:SetPoint('TOPLEFT', panelInset, -panelInset)
        self.leftPanel:SetPoint('BOTTOMRIGHT', self, 'BOTTOMLEFT', leftWidth, panelInset)

        self.rightPanel:ClearAllPoints()
        self.rightPanel:SetPoint('TOPLEFT', self.leftPanel, 'TOPRIGHT', panelInset, 0)
        self.rightPanel:SetPoint('BOTTOMRIGHT', -panelInset, panelInset)

        self.scrollFrame:ClearAllPoints()
        self.scrollFrame:SetPoint('TOPLEFT', scrollSideInset, -scrollTopInset)
        self.scrollFrame:SetPoint('BOTTOMRIGHT', -scrollSideInset, scrollBottomInset)

        local extraInset = EXFrames:ScalePixel(5, self.leftPanel)
        self.extraButton:ClearAllPoints()
        self.extraButton:SetPoint('BOTTOMLEFT', self.leftPanel, 'BOTTOMLEFT', extraInset, extraInset)
        self.extraButton:SetPoint('BOTTOMRIGHT', self.leftPanel, 'BOTTOMRIGHT', -extraInset, extraInset)
    end

    local scrollFrame = scrollFrame:Create()
    scrollFrame:SetParent(rightPanel)
    f.scrollFrame = scrollFrame
    f.container = scrollFrame.child

    local extraButton = EXFrames:GetFrame('button'):Create()
    extraButton:SetHeight(EXFrames:ScalePixel(30, f))
    extraButton:SetParent(leftPanel)
    extraButton:Hide()
    f.extraButton = extraButton

    f:ApplyPanelLayout()

    f.UpdateScroll = function(self)
        local width = math.max(1, EXFrames:ScalePixel(self.rightPanel:GetWidth() - 15, self.rightPanel))
        local viewportHeight = math.max(1, EXFrames:ScalePixel(self.rightPanel:GetHeight() - 25, self.rightPanel))
        local contentHeight = self.container:GetHeight()
        if self.container.exuiAutoSizeHeight and contentHeight > 0 then
            self.scrollFrame:UpdateScrollChild(width, math.max(contentHeight, viewportHeight))
        else
            self.scrollFrame:UpdateScrollChild(width, viewportHeight)
        end
    end

    f.onItemClick = function(self, id)
        listMenu:Hide()
        f.activeID = id
        for _, item in ipairs(f.items) do
            item:SetActive(item.ID == id)
        end
        if (f.onItemChange) then
            f.onItemChange(id)
        end
    end

    f.ShowItemContextMenu = function(self, button)
        if not button or not button.contextMenuItems or #button.contextMenuItems == 0 then
            return
        end
        local entries = buildContextMenuEntries(button.ID, button.contextMenuItems)
        listMenu:ToggleAt(button, entries)
    end

    f.AddItems = function(self, items)
        self:ApplyPanelLayout()
        for _, item in ipairs_reverse(self.items) do
            item:ClearAllPoints()
        end
        local prev = nil
        local itemGap = EXFrames:ScalePixel(3, self.leftPanel)
        local itemInsetX = EXFrames:ScalePixel(3, self.leftPanel)
        local itemInsetTop = EXFrames:ScalePixel(5, self.leftPanel)
        for i, item in ipairs(items) do
            if (not self.items[i]) then
                self.items[i] = CreateItem(self.leftPanel)
            end
            local button = self.items[i]
            button.ID = item.ID
            button:SetText(item.label)
            button.contextMenuItems = item.contextMenuItems
            button.onItemClick = self.onItemClick
            button.onShowContextMenu = function()
                self:ShowItemContextMenu(button)
            end
            if (not prev) then
                button:SetPoint('TOPLEFT', self.leftPanel, 'TOPLEFT', itemInsetX, -itemInsetTop)
                button:SetPoint('TOPRIGHT', self.leftPanel, 'TOPRIGHT', -itemInsetX, -itemInsetTop)
            else
                button:SetActive(false)
                button:SetPoint('TOPLEFT', prev, 'BOTTOMLEFT', 0, -itemGap)
                button:SetPoint('TOPRIGHT', prev, 'BOTTOMRIGHT', 0, -itemGap)
            end

            if (self.activeID and self.activeID == item.ID) then
                button:SetActive(true)
            elseif (not self.activeID and not prev) then
                button:SetActive(true)
                self.activeID = item.ID
            end

            button:Show()
            prev = button
        end

        for i = #items + 1, #self.items do
            self.items[i]:Hide()
            self.items[i].contextMenuItems = nil
            self.items[i].onShowContextMenu = nil
        end

        if EXFrames.RefreshPixelPerfect then
            EXFrames:RefreshPixelPerfect()
        end
    end

    f.SetActiveItem = function(self, id)
        self.activeID = id
        for _, item in ipairs(self.items) do
            item:SetActive(item.ID == id)
        end
        if (self.onItemChange) then
            self.onItemChange(id)
        end
    end

    f.SetOnItemChange = function(self, callback)
        self.onItemChange = callback
    end

    f.AddExtraButton = function(self, buttonOptions)
        self.extraButton:Show()
        if (buttonOptions.color) then
            self.extraButton:SetColor(unpack(buttonOptions.color))
        end
        if (buttonOptions.text) then
            self.extraButton:SetText(buttonOptions.text)
        end
        if (buttonOptions.onClick) then
            self.extraButton:SetOnClick(buttonOptions.onClick)
        end
    end

    f.DisableExtraButton = function(self)
        self.extraButton:Hide()
    end

    f.Destroy = function(self)
        listMenu:Hide()
        self.extraButton:Hide()
        self.activeID = nil
        if self.scrollFrame then
            self.scrollFrame:Reset()
        end
        self:ClearAllPoints()
        self:Hide()
        splitOptions.pool:Release(self)
    end

    f.configured = true
end

---@param self ExalityFramesSplitOptionsFrame
---@return Frame
splitOptions.Create = function(self)
    local f = self.pool:Acquire()
    if not f.configured then
        configure(f)
    end

    if f.scrollFrame then
        f.scrollFrame:Reset()
    end

    f:Show()
    return f
end
