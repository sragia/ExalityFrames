local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

--- @class ExalityFramesTabsFrame
local tabs = EXFrames:GetFrame('tabs-frame')

---@class ExalityFramesSmoothScrollFrame
local smoothScrollFrame = EXFrames:GetFrame('smooth-scroll-frame')

tabs.Init = function(self)
    tabs.pool = CreateFramePool('Frame', UIParent)
end

local function ApplyTabVisual(button, active, hovered)
    local theme = EXFrames.Theme

    button.underline:Show()
    button.glow:Show()

    if active then
        button.text:SetVertexColor(unpack(theme.white))
        button.underline:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        button.glow:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    elseif hovered then
        button.text:SetVertexColor(unpack(theme.white))
        button.underline:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], 1)
        button.glow:SetVertexColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 0.55)
    else
        button.text:SetVertexColor(unpack(theme.textMuted))
        button.underline:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], 0.7)
        button.glow:SetVertexColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 0.25)
    end
end

local function CreateTabButton(parent)
    local button = CreateFrame('Button', nil, parent)
    button.ID = ''
    button:SetSize(80, 20)
    button.isActive = false

    local text = button:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    text:SetPoint('CENTER', 0, 0)
    text:SetWidth(0)
    button.text = text

    local underline = button:CreateTexture(nil, 'OVERLAY')
    underline:SetHeight(1)
    underline:SetPoint('BOTTOMLEFT', text, 'BOTTOMLEFT', -5, -6)
    underline:SetPoint('BOTTOMRIGHT', text, 'BOTTOMRIGHT', 5, -6)
    button.underline = underline

    local glow = button:CreateTexture(nil, 'ARTWORK')
    glow:SetTexture(EXFrames.assets.textures.tabs.glow)
    glow:SetHeight(20)
    glow:SetPoint('BOTTOMLEFT', underline, 'TOPLEFT', 0, 0)
    glow:SetPoint('BOTTOMRIGHT', underline, 'TOPRIGHT', 0, 0)
    button.glow = glow

    button.SetActive = function(self, active)
        self.isActive = active and true or false
        ApplyTabVisual(self, self.isActive, false)
    end

    button.SetText = function(self, label)
        self.text:SetText(label)
        self:SetWidth(self.text:GetStringWidth() + 20)
    end

    button:SetScript('OnEnter', function(self)
        ApplyTabVisual(self, self.isActive, true)
    end)

    button:SetScript('OnLeave', function(self)
        ApplyTabVisual(self, self.isActive, false)
    end)

    button:SetScript('OnClick', function(self)
        if (self.onClick) then
            self:onClick(self.ID)
        end
    end)

    ApplyTabVisual(button, false, false)

    return button
end

local function SetupScrollable(frame)
    if not frame.scrollFrame then
        local scroll = smoothScrollFrame:Create()
        scroll:SetParent(frame.panel)
        scroll:SetPoint('TOPLEFT', 5, -5)
        scroll:SetPoint('BOTTOMRIGHT', -5, 5)
        frame.scrollFrame = scroll
    end

    frame.scrollFrame:Show()
    frame.container = frame.scrollFrame.child
    frame.container.exuiAutoSizeHeight = true
    frame.scrollable = true

    frame.UpdateScroll = function(self)
        local width = math.max(1, self.panel:GetWidth() - 15)
        local viewportHeight = math.max(1, self.panel:GetHeight() - 15)
        local contentHeight = self.container:GetHeight()
        if contentHeight > 0 then
            self.scrollFrame:UpdateScrollChild(width, math.max(contentHeight, viewportHeight))
        else
            self.scrollFrame:UpdateScrollChild(width, viewportHeight)
        end
    end
end

local function ClearScrollable(frame)
    if frame.scrollFrame then
        frame.scrollFrame:Destroy()
        frame.scrollFrame = nil
    end
    frame.container = frame.panel
    frame.container.exuiAutoSizeHeight = nil
    frame.scrollable = false
    frame.UpdateScroll = nil
end

local configure = function(frame)
    frame.tabs = {}
    frame.activeTabID = nil

    local tabBar = CreateFrame('Frame', nil, frame)
    tabBar:SetPoint('TOPLEFT', 0, 0)
    tabBar:SetPoint('TOPRIGHT', 0, 0)
    tabBar:SetHeight(30)
    frame.tabBar = tabBar

    local panel = EXFrames:GetFrame('panel-frame'):Create()
    panel:SetBackgroundColor(0.12, 0.12, 0.12, 0.8)
    panel:SetParent(frame)
    panel:SetPoint('TOPLEFT', tabBar, 'BOTTOMLEFT')
    panel:SetPoint('BOTTOMRIGHT')
    frame.panel = panel
    frame.container = panel

    frame.onTabClick = function(self, id)
        frame.activeTabID = id
        for _, tab in ipairs(frame.tabs) do
            tab:SetActive(tab.ID == id)
        end
        if (frame.onTabChange) then
            frame.onTabChange(id)
        end
    end

    frame.AddTabs = function(self, tabs)
        for _, tab in ipairs_reverse(self.tabs) do
            tab:ClearAllPoints()
        end
        local prev = nil
        for i, tab in ipairs(tabs) do
            if (not self.tabs[i]) then
                self.tabs[i] = CreateTabButton(self.tabBar)
            end
            local button = self.tabs[i]
            button.ID = tab.ID
            button:SetText(tab.label)
            button.onClick = self.onTabClick
            if (not prev) then
                button:SetPoint('BOTTOMLEFT', self.tabBar, 'BOTTOMLEFT', 20, 1)
            else
                button:SetPoint('BOTTOMLEFT', prev, 'BOTTOMRIGHT', 3, 0)
            end

            if (self.activeTabID and self.activeTabID == tab.ID) then
                button:SetActive(true)
            elseif (not self.activeTabID and not prev) then
                button:SetActive(true)
                self.activeTabID = tab.ID
            else
                button:SetActive(false)
            end
            prev = button
        end
    end

    frame.SetOnTabChange = function(self, callback)
        self.onTabChange = callback
    end

    frame.SetActiveTab = function(self, id)
        self.activeTabID = id
        for _, tab in ipairs(self.tabs) do
            tab:SetActive(tab.ID == id)
        end
        if (self.onTabChange) then
            self.onTabChange(id)
        end
    end

    frame.Destroy = function(self)
        ClearScrollable(self)
        self:ClearAllPoints()
        self:Hide()
        tabs.pool:Release(self)
    end

    frame.configured = true
end

---@param self ExalityFramesTabsFrame
---@param options? {scrollable?: boolean}
---@return Frame
tabs.Create = function(self, options)
    local f = self.pool:Acquire()
    if not f.configured then
        configure(f)
    end

    if options and options.scrollable then
        SetupScrollable(f)
    else
        ClearScrollable(f)
    end

    f:Show()

    return f
end
