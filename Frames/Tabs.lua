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

local CONTENT_SIDE_INSET = 5
local CONTENT_TOP_EXTRA = 3

local function UpdateContentInsets(frame)
    local panel = frame.panel
    if not panel or not frame.contentHost then
        return
    end
    local side = EXFrames:ScalePixel(CONTENT_SIDE_INSET, panel)
    local top = EXFrames:ScalePixel(CONTENT_SIDE_INSET + CONTENT_TOP_EXTRA, panel)
    local bottom = EXFrames:ScalePixel(CONTENT_SIDE_INSET, panel)
    frame.contentHost:ClearAllPoints()
    frame.contentHost:SetPoint('TOPLEFT', panel, 'TOPLEFT', side, -top)
    frame.contentHost:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -side, bottom)
end

local function SetupScrollable(frame)
    UpdateContentInsets(frame)
    if not frame.scrollFrame then
        local scroll = smoothScrollFrame:Create()
        scroll:SetParent(frame.contentHost)
        scroll:SetAllPoints()
        frame.scrollFrame = scroll
    end

    frame.scrollFrame:Show()
    frame.container = frame.scrollFrame.child
    frame.container.exuiAutoSizeHeight = true
    frame.scrollable = true

    frame.UpdateScroll = function(self)
        UpdateContentInsets(self)
        local width = math.max(1, self.contentHost:GetWidth())
        local viewportHeight = math.max(1, self.contentHost:GetHeight())
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
    frame.container = frame.contentHost
    frame.container.exuiAutoSizeHeight = nil
    frame.scrollable = false
    frame.UpdateScroll = nil
    UpdateContentInsets(frame)
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
    panel:SetSubtleChrome()
    panel:SetParent(frame)
    panel:SetPoint('TOPLEFT', tabBar, 'BOTTOMLEFT')
    panel:SetPoint('BOTTOMRIGHT')
    frame.panel = panel

    local contentHost = CreateFrame('Frame', nil, panel)
    contentHost:SetFrameLevel(panel:GetFrameLevel() + 1)
    frame.contentHost = contentHost
    frame.container = contentHost
    UpdateContentInsets(frame)
    panel:HookScript('OnSizeChanged', function()
        UpdateContentInsets(frame)
    end)

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
                button:SetPoint('BOTTOMLEFT', self.tabBar, 'BOTTOMLEFT', 5, 1)
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

EXFrames.FrameBase.StandardizeCreate(tabs, 'options-only')
