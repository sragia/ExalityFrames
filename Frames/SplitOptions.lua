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

local DEFAULT_CATEGORY_BG = { 0.18, 0.18, 0.18, 0.7 }
local DEFAULT_CATEGORY_TEXT = { 0.65, 0.65, 0.65, 1 }

local function CreateCategoryLabel(parent)
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetHeight(EXFrames:ScalePixel(20, parent))
    frame.isCategory = true

    local bg = frame:CreateTexture(nil, 'BACKGROUND')
    bg:SetTexture(EXFrames.assets.textures.solidWhite)
    bg:SetAllPoints()
    bg:SetVertexColor(unpack(DEFAULT_CATEGORY_BG))
    frame.bg = bg

    local text = frame:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
    text:SetTextColor(unpack(DEFAULT_CATEGORY_TEXT))
    text:SetJustifyH('LEFT')
    text:SetPoint('LEFT', 6, 0)
    text:SetPoint('RIGHT', -6, 0)
    frame.text = text

    frame.SetText = function(self, value)
        self.text:SetText(value or '')
    end

    frame.SetColors = function(self, bgColor, textColor)
        self.bg:SetVertexColor(unpack(bgColor or DEFAULT_CATEGORY_BG))
        self.text:SetTextColor(unpack(textColor or DEFAULT_CATEGORY_TEXT))
    end

    frame.SetActive = function() end

    ForwardMouseWheel(frame)

    return frame
end

local function ApplyItemVisual(button, active, hovered)
    local theme = EXFrames.Theme

    if active then
        button.bg:SetVertexColor(unpack(theme.backgroundPanel))
        button.glow:SetVertexColor(unpack(theme.accent))
        button:SetInputBorderActive(true)
    elseif hovered then
        button.bg:SetVertexColor(unpack(theme.backgroundLight))
        button.glow:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.55)
        button:SetInputBorderActive(true)
    else
        button.bg:SetVertexColor(unpack(theme.background))
        button.glow:SetVertexColor(unpack(theme.border))
        button:SetInputBorderActive(false)
    end
end

local TEXT_PAD_LEFT = 6
local TEXT_PAD_RIGHT = 6
local PREVIEW_SIZE = 14
local PREVIEW_PAD_RIGHT = 4
local PREVIEW_GAP = 4
-- Border slack should not enable the bar.
local SCROLL_FIT_EPSILON = 1

local function GetScrollbarGutter(scroll)
    local width = scroll.scrollbarWidth or 0
    local padding = scroll.scrollbarPadding or 0
    return width + padding * 2
end

local function ListNeedsScroll(viewport, listHeight)
    return viewport > 1 and (listHeight - viewport) > SCROLL_FIT_EPSILON
end

local function MeasureItemListHeight(parent, items, itemGap, itemInsetTop)
    local contentHeight = itemInsetTop
    local hasPrev = false
    for _, item in ipairs(items) do
        if item.type == 'category' then
            local rowHeight = EXFrames:ScalePixel(20, parent)
            local spacingAbove = EXFrames:ScalePixel(item.spacingAbove or 0, parent)
            if not hasPrev then
                contentHeight = contentHeight + rowHeight + spacingAbove
            else
                contentHeight = contentHeight + rowHeight + itemGap + spacingAbove
            end
        else
            local rowHeight = EXFrames:ScalePixel(item.sublabel ~= nil and 36 or 20, parent)
            contentHeight = contentHeight + rowHeight + (hasPrev and itemGap or 0)
        end
        hasPrev = true
    end
    return contentHeight
end

local function ForwardMouseWheel(row)
    row:EnableMouseWheel(true)
    row:SetScript('OnMouseWheel', function(self, delta)
        local scroll = self.scrollFrame
        if not scroll and self.GetParent then
            local parent = self:GetParent()
            scroll = parent and parent.scrollFrame
        end
        if not scroll then
            return
        end
        local handler = scroll.HandleMouseWheel or scroll:GetScript('OnMouseWheel')
        if handler then
            handler(scroll, delta)
        end
    end)
end

local function ApplyLabelPoints(button)
    local rightPad = TEXT_PAD_RIGHT
    if button.previewButton and button.previewButton:IsShown() then
        rightPad = PREVIEW_PAD_RIGHT + PREVIEW_SIZE + PREVIEW_GAP
    end

    button.text:ClearAllPoints()
    button.subtext:ClearAllPoints()
    if button.dualLine then
        button.text:SetPoint('TOPLEFT', TEXT_PAD_LEFT, -5)
        button.text:SetPoint('TOPRIGHT', -rightPad, -5)
        button.subtext:SetPoint('TOPLEFT', button.text, 'BOTTOMLEFT', 0, -1)
        button.subtext:SetPoint('TOPRIGHT', button.text, 'BOTTOMRIGHT', 0, -1)
    else
        button.text:SetPoint('LEFT', TEXT_PAD_LEFT, 0)
        button.text:SetPoint('RIGHT', -rightPad, 0)
    end
end

local function CreateItem(parent, dualLine)
    local button = CreateFrame('Button', nil, parent)
    local height = dualLine and 36 or 20
    button:SetHeight(EXFrames:ScalePixel(height, parent))
    button.isCategory = false
    button.dualLine = dualLine
    button.isActive = false
    button.previewEnabled = false

    local bg = button:CreateTexture(nil, 'BACKGROUND')
    bg:SetTexture(EXFrames.assets.textures.solidWhite)
    bg:SetVertexColor(unpack(EXFrames.Theme.background))
    bg:SetAllPoints()
    button.bg = bg

    EXFrames:ApplyInputBorder(button, 1)

    local glow = button:CreateTexture(nil, 'ARTWORK')
    glow:SetTexture(EXFrames.assets.textures.splitOptions.glow)
    glow:SetAllPoints()
    glow:SetVertexColor(unpack(EXFrames.Theme.border))
    button.glow = glow

    local text = button:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    text:SetJustifyH('LEFT')
    text:SetWordWrap(false)
    text:SetMaxLines(1)
    button.text = text

    local subtext = button:CreateFontString(nil, 'OVERLAY')
    subtext:SetFont(EXFrames.assets.font.default(), 9, 'OUTLINE')
    subtext:SetTextColor(0.55, 0.55, 0.55, 1)
    subtext:SetJustifyH('LEFT')
    subtext:SetWordWrap(false)
    subtext:SetMaxLines(1)
    button.subtext = subtext

    local previewButton = CreateFrame('Button', nil, button)
    previewButton:SetSize(EXFrames:ScalePixel(PREVIEW_SIZE, parent), EXFrames:ScalePixel(PREVIEW_SIZE, parent))
    previewButton:SetPoint('RIGHT', EXFrames:ScalePixel(-PREVIEW_PAD_RIGHT, parent), 0)
    previewButton:Hide()
    local previewIcon = previewButton:CreateTexture(nil, 'ARTWORK')
    previewIcon:SetAllPoints()
    previewButton.icon = previewIcon
    button.previewButton = previewButton

    ApplyLabelPoints(button)
    if not dualLine then
        subtext:Hide()
    end

    button.SetActive = function(self, active)
        self.isActive = active and true or false
        ApplyItemVisual(self, self.isActive, self:IsMouseOver())
    end

    button.SetText = function(self, value)
        self.text:SetText(value or '')
    end

    button.SetSubText = function(self, value)
        if self.dualLine then
            self.subtext:SetText(value or '')
            self.subtext:SetShown(value and value ~= '')
        end
    end

    button.ApplyPreviewIconColor = function(self, hovered)
        if self.previewEnabled then
            if hovered then
                self.previewButton.icon:SetVertexColor(unpack(EXFrames.Theme.accentLight))
            else
                self.previewButton.icon:SetVertexColor(unpack(EXFrames.Theme.accent))
            end
        else
            if hovered then
                self.previewButton.icon:SetVertexColor(unpack(EXFrames.Theme.text))
            else
                self.previewButton.icon:SetVertexColor(unpack(EXFrames.Theme.border))
            end
        end
    end

    button.SetPreviewEnabled = function(self, enabled)
        self.previewEnabled = enabled and true or false
        local icon = self.previewEnabled and self.previewIconOn or self.previewIconOff
        if icon then
            self.previewButton.icon:SetTexture(icon)
        end
        self:ApplyPreviewIconColor(self.previewButton:IsMouseOver())
    end

    button.SetPreview = function(self, config)
        if not config then
            self.previewButton:Hide()
            self.onPreviewToggle = nil
            self.previewEnabled = false
            self.previewIconOn = nil
            self.previewIconOff = nil
            ApplyLabelPoints(self)
            return
        end

        self.previewIconOn = config.iconOn
        self.previewIconOff = config.iconOff
        self.onPreviewToggle = config.onToggle
        self.previewButton:Show()
        self:SetPreviewEnabled(config.enabled)
        ApplyLabelPoints(self)
    end

    previewButton:SetScript('OnEnter', function()
        button:ApplyPreviewIconColor(true)
        ApplyItemVisual(button, button.isActive, true)
    end)

    previewButton:SetScript('OnLeave', function()
        button:ApplyPreviewIconColor(false)
        ApplyItemVisual(button, button.isActive, button:IsMouseOver())
    end)

    previewButton:SetScript('OnClick', function()
        local enabled = not button.previewEnabled
        button:SetPreviewEnabled(enabled)
        if button.onPreviewToggle then
            button.onPreviewToggle(button.ID, enabled)
        end
    end)

    ForwardMouseWheel(previewButton)

    button:SetScript('OnEnter', function(self)
        ApplyItemVisual(self, self.isActive, true)
    end)

    button:SetScript('OnLeave', function(self)
        ApplyItemVisual(self, self.isActive, false)
    end)

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

    ForwardMouseWheel(button)

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

local function firstSelectableID(items)
    for _, item in ipairs(items) do
        if item.type ~= 'category' and item.ID then
            return item.ID
        end
    end
    return nil
end

local configure = function(f)
    f.items = {}
    f.categoryLabels = {}
    f.onItemClick = nil
    f.activeID = nil
    f.leftWidth = 135

    local leftPanel = EXFrames:GetFrame('panel-frame'):Create()
    leftPanel:SetSubtleChrome()
    leftPanel:SetParent(f)
    f.leftPanel = leftPanel

    local rightPanel = EXFrames:GetFrame('panel-frame'):Create()
    rightPanel:SetSubtleChrome()
    rightPanel:SetParent(f)
    f.rightPanel = rightPanel

    local leftScroll = scrollFrame:Create()
    leftScroll:SetParent(leftPanel)
    -- Rows pad themselves for the bar, so the scroll child stays full width.
    leftScroll.scrollbarOverlay = true
    leftScroll.hideScrollbar = true
    leftScroll:HookScript('OnSizeChanged', function()
        if f.RefreshItemScrollLayout then
            f:RefreshItemScrollLayout()
        end
    end)
    f.leftScroll = leftScroll
    f.leftContainer = leftScroll.child

    local rightScroll = scrollFrame:Create()
    rightScroll:SetParent(rightPanel)
    f.scrollFrame = rightScroll
    f.container = rightScroll.child

    local extraButton = EXFrames:GetFrame('simple-button'):Create(leftPanel)
    extraButton:SetHeight(EXFrames:ScalePixel(30, f))
    extraButton:Hide()
    f.extraButton = extraButton

    f.ApplyPanelLayout = function(self)
        local panelInset = EXFrames:ScalePixel(5, self)
        local leftWidth = EXFrames:ScalePixel(self.leftWidth or 135, self)
        local scrollTopInset = EXFrames:ScalePixel(15, self.rightPanel)
        local scrollBottomInset = EXFrames:ScalePixel(8, self.rightPanel)
        local scrollSideInset = EXFrames:ScalePixel(5, self.rightPanel)
        local leftScrollInset = EXFrames:ScalePixel(3, self.leftPanel)
        local extraInset = EXFrames:ScalePixel(5, self.leftPanel)
        local extraHeight = self.extraButton:IsShown() and EXFrames:ScalePixel(30, self) or 0
        local extraGap = self.extraButton:IsShown() and EXFrames:ScalePixel(5, self.leftPanel) or 0

        self.leftPanel:ClearAllPoints()
        self.leftPanel:SetPoint('TOPLEFT', panelInset, -panelInset)
        self.leftPanel:SetPoint('BOTTOMRIGHT', self, 'BOTTOMLEFT', leftWidth, panelInset)

        self.rightPanel:ClearAllPoints()
        self.rightPanel:SetPoint('TOPLEFT', self.leftPanel, 'TOPRIGHT', panelInset, 0)
        self.rightPanel:SetPoint('BOTTOMRIGHT', -panelInset, panelInset)

        self.scrollFrame:ClearAllPoints()
        self.scrollFrame:SetPoint('TOPLEFT', scrollSideInset, -scrollTopInset)
        self.scrollFrame:SetPoint('BOTTOMRIGHT', -scrollSideInset, scrollBottomInset)

        self.extraButton:ClearAllPoints()
        self.extraButton:SetPoint('BOTTOMLEFT', self.leftPanel, 'BOTTOMLEFT', extraInset, extraInset)
        self.extraButton:SetPoint('BOTTOMRIGHT', self.leftPanel, 'BOTTOMRIGHT', -extraInset, extraInset)

        self.leftScroll:ClearAllPoints()
        self.leftScroll:SetPoint('TOPLEFT', leftScrollInset, -leftScrollInset)
        self.leftScroll:SetPoint('TOPRIGHT', -leftScrollInset, -leftScrollInset)
        self.leftScroll:SetPoint('BOTTOMLEFT', leftScrollInset, extraInset + extraHeight + extraGap)
        self.leftScroll:SetPoint('BOTTOMRIGHT', -leftScrollInset, extraInset + extraHeight + extraGap)
    end

    f:ApplyPanelLayout()

    f.UpdateScroll = function(self)
        local width = math.max(1, EXFrames:ScalePixel(self.rightPanel:GetWidth() - 15, self.rightPanel))
        local viewportHeight = math.max(1, EXFrames:ScalePixel(self.rightPanel:GetHeight() - 25, self.rightPanel))
        local contentHeight = self.container:GetHeight()
        if self.container.exuiAutoSizeHeight and contentHeight > 0 then
            -- Use real content height only; padding to the viewport falsely enables the scrollbar after resizes.
            self.scrollFrame:UpdateScrollChild(width, contentHeight)
        else
            self.scrollFrame:UpdateScrollChild(width, viewportHeight)
        end
    end

    f.UpdateLeftScroll = function(self)
        -- Use the scroll frame viewport width, not the child (child is often 0 before sizing).
        local width = math.max(1, self.leftScroll:GetWidth())
        if width <= 1 then
            local inset = EXFrames:ScalePixel(6, self.leftPanel)
            width = math.max(1, EXFrames:ScalePixel(self.leftWidth or 135, self) - inset)
        end
        -- Actual list height only — do not pad to the viewport or the bar can stick after layout changes.
        local contentHeight = math.max(1, self.leftContainer:GetHeight() or 0)
        self.leftScroll:UpdateScrollChild(width, contentHeight)
    end

    f.SetLeftWidth = function(self, width)
        self.leftWidth = width or 135
        self:ApplyPanelLayout()
    end

    f.onItemClick = function(self, id)
        listMenu:Hide()
        f.activeID = id
        for _, item in ipairs(f.items) do
            if not item.isCategory then
                item:SetActive(item.ID == id)
            end
        end
        if f.onItemChange then
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

    f.RefreshItemScrollLayout = function(self)
        if self.refreshingItemScroll or not self.itemData then
            return
        end
        local viewport = self.leftScroll:GetHeight() or 0
        local needsScroll = ListNeedsScroll(viewport, self.itemListHeight or 0)
        if needsScroll == self.itemsNeedScroll then
            return
        end
        self:AddItems(self.itemData)
    end

    f.AddItems = function(self, items)
        self.refreshingItemScroll = true
        self.itemData = items

        local usesDualLine = false
        for _, item in ipairs(items) do
            if item.type ~= 'category' and item.sublabel ~= nil then
                usesDualLine = true
                break
            end
        end
        if usesDualLine and (self.leftWidth or 135) < 160 then
            self.leftWidth = 160
        end

        self:ApplyPanelLayout()
        -- Size the scroll child before anchoring items so TOPLEFT/TOPRIGHT stretch works.
        self:UpdateLeftScroll()

        for _, item in ipairs_reverse(self.items) do
            item:ClearAllPoints()
            item:Hide()
        end
        for _, label in ipairs_reverse(self.categoryLabels) do
            label:ClearAllPoints()
            label:Hide()
        end

        local prev = nil
        local itemGap = EXFrames:ScalePixel(3, self.leftPanel)
        local itemInsetX = EXFrames:ScalePixel(3, self.leftPanel)
        local itemInsetTop = EXFrames:ScalePixel(5, self.leftPanel)
        local viewport = self.leftScroll:GetHeight() or 0
        local needsScroll = ListNeedsScroll(viewport, MeasureItemListHeight(self.leftPanel, items, itemGap, itemInsetTop))
        local rightInset = itemInsetX + (needsScroll and GetScrollbarGutter(self.leftScroll) or 0)
        local firstRow, firstRowY
        local itemIndex = 0
        local categoryIndex = 0
        local contentHeight = itemInsetTop

        for _, item in ipairs(items) do
            if item.type == 'category' then
                categoryIndex = categoryIndex + 1
                if not self.categoryLabels[categoryIndex] then
                    self.categoryLabels[categoryIndex] = CreateCategoryLabel(self.leftContainer)
                end
                local label = self.categoryLabels[categoryIndex]
                label.scrollFrame = self.leftScroll
                label:SetText(item.label)
                label:SetColors(item.bgColor, item.textColor)
                label:Show()
                local gapAbove = itemGap + EXFrames:ScalePixel(item.spacingAbove or 0, self.leftPanel)
                if not prev then
                    local topOffset = itemInsetTop + EXFrames:ScalePixel(item.spacingAbove or 0, self.leftPanel)
                    firstRow = label
                    firstRowY = -topOffset
                    label:SetPoint('TOPLEFT', self.leftContainer, 'TOPLEFT', itemInsetX, firstRowY)
                    label:SetPoint('TOPRIGHT', self.leftContainer, 'TOPRIGHT', -rightInset, firstRowY)
                    contentHeight = contentHeight + label:GetHeight() + EXFrames:ScalePixel(item.spacingAbove or 0, self.leftPanel)
                else
                    label:SetPoint('TOPLEFT', prev, 'BOTTOMLEFT', 0, -gapAbove)
                    label:SetPoint('TOPRIGHT', prev, 'BOTTOMRIGHT', 0, -gapAbove)
                    contentHeight = contentHeight + label:GetHeight() + gapAbove
                end
                prev = label
            else
                itemIndex = itemIndex + 1
                local wantsDual = item.sublabel ~= nil
                if not self.items[itemIndex] or self.items[itemIndex].dualLine ~= wantsDual then
                    if self.items[itemIndex] then
                        self.items[itemIndex]:Hide()
                        self.items[itemIndex]:SetParent(nil)
                    end
                    self.items[itemIndex] = CreateItem(self.leftContainer, wantsDual)
                end
                local button = self.items[itemIndex]
                button.scrollFrame = self.leftScroll
                button.ID = item.ID
                button:SetText(item.label)
                button:SetSubText(item.sublabel)
                button:SetPreview(item.preview)
                button.contextMenuItems = item.contextMenuItems
                button.onItemClick = self.onItemClick
                button.onShowContextMenu = function()
                    self:ShowItemContextMenu(button)
                end
                if not prev then
                    firstRow = button
                    firstRowY = -itemInsetTop
                    button:SetPoint('TOPLEFT', self.leftContainer, 'TOPLEFT', itemInsetX, firstRowY)
                    button:SetPoint('TOPRIGHT', self.leftContainer, 'TOPRIGHT', -rightInset, firstRowY)
                else
                    button:SetActive(false)
                    button:SetPoint('TOPLEFT', prev, 'BOTTOMLEFT', 0, -itemGap)
                    button:SetPoint('TOPRIGHT', prev, 'BOTTOMRIGHT', 0, -itemGap)
                end

                if self.activeID and self.activeID == item.ID then
                    button:SetActive(true)
                end

                button:Show()
                contentHeight = contentHeight + button:GetHeight() + (prev and itemGap or 0)
                prev = button
            end
        end

        for i = itemIndex + 1, #self.items do
            self.items[i]:Hide()
            self.items[i].contextMenuItems = nil
            self.items[i].onShowContextMenu = nil
            self.items[i]:SetPreview(nil)
        end
        for i = categoryIndex + 1, #self.categoryLabels do
            self.categoryLabels[i]:Hide()
        end

        if not self.activeID or not self:_hasItemID(self.activeID, items) then
            self.activeID = firstSelectableID(items)
        end
        if self.activeID then
            for _, button in ipairs(self.items) do
                if not button.isCategory then
                    button:SetActive(button.ID == self.activeID)
                end
            end
        end

        local actualNeedsScroll = ListNeedsScroll(viewport, contentHeight)
        if actualNeedsScroll ~= needsScroll and firstRow then
            needsScroll = actualNeedsScroll
            rightInset = itemInsetX + (needsScroll and GetScrollbarGutter(self.leftScroll) or 0)
            firstRow:SetPoint('TOPRIGHT', self.leftContainer, 'TOPRIGHT', -rightInset, firstRowY)
        end

        self.itemListHeight = contentHeight
        self.itemsNeedScroll = needsScroll
        self.leftScroll.hideScrollbar = not needsScroll

        -- Bottom padding must not by itself turn the bar on. Clamp when every row already fits.
        local childHeight = contentHeight + itemInsetTop
        if not needsScroll and viewport > 1 then
            childHeight = math.min(childHeight, viewport)
        end
        self.leftContainer:SetHeight(math.max(childHeight, 1))
        self:UpdateLeftScroll()
        self.refreshingItemScroll = false

        if not self.itemScrollRefreshQueued then
            self.itemScrollRefreshQueued = true
            C_Timer.After(0, function()
                self.itemScrollRefreshQueued = false
                if self:IsShown() and self.RefreshItemScrollLayout then
                    self:RefreshItemScrollLayout()
                end
            end)
        end

        if EXFrames.RefreshPixelPerfect then
            EXFrames:RefreshPixelPerfect()
        end
    end

    f._hasItemID = function(self, id, items)
        for _, item in ipairs(items) do
            if item.type ~= 'category' and item.ID == id then
                return true
            end
        end
        return false
    end

    f.SetActiveItem = function(self, id)
        self.activeID = id
        for _, item in ipairs(self.items) do
            if not item.isCategory then
                item:SetActive(item.ID == id)
            end
        end
        if self.onItemChange then
            self.onItemChange(id)
        end
    end

    f.SetOnItemChange = function(self, callback)
        self.onItemChange = callback
    end

    f.SyncPreviewToggles = function(self, isEnabled)
        for _, item in ipairs(self.items) do
            if not item.isCategory and item.previewButton and item.previewButton:IsShown() then
                item:SetPreviewEnabled(isEnabled(item.ID))
            end
        end
    end

    f.SetContentActionButton = function(self, buttonOptions)
        if not buttonOptions then
            if self.contentActionButton then
                self.contentActionButton:Hide()
            end
            return
        end
        if not self.contentActionButton then
            local btn = EXFrames:GetFrame('simple-button'):Create(self.container)
            btn:SetHeight(EXFrames:ScalePixel(30, self))
            btn:SetFrameWidth(EXFrames:ScalePixel(140, self))
            btn:SetPoint('TOPRIGHT', self.container, 'TOPRIGHT', -EXFrames:ScalePixel(5, self.container), -EXFrames:ScalePixel(5, self.container))
            self.contentActionButton = btn
        end
        self.contentActionButton:Show()
        self.contentActionButton:SetOptionData({
            label = buttonOptions.text or buttonOptions.label,
            onClick = buttonOptions.onClick,
        })
    end

    f.AddExtraButton = function(self, buttonOptions)
        self.extraButton:Show()
        self.extraButton:SetOptionData({
            label = buttonOptions.text or buttonOptions.label,
            onClick = buttonOptions.onClick,
            icon = buttonOptions.icon,
        })
        self:ApplyPanelLayout()
    end

    f.DisableExtraButton = function(self)
        self.extraButton:Hide()
        self:ApplyPanelLayout()
    end

    f.Destroy = function(self)
        listMenu:Hide()
        self.extraButton:Hide()
        if self.contentActionButton then
            self.contentActionButton:Hide()
        end
        self.activeID = nil
        self.itemData = nil
        self.refreshingItemScroll = false
        if self.scrollFrame then
            self.scrollFrame:Reset()
        end
        if self.leftScroll then
            self.leftScroll:Reset()
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
    if f.leftScroll then
        f.leftScroll:Reset()
    end

    f:Show()
    return f
end

EXFrames.FrameBase.StandardizeCreate(splitOptions)
