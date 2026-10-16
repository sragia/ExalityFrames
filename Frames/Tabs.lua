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

local ATLAS_W, ATLAS_H = 211, 45
-- Horizontal caps cover the curved shadow and the 3px top radius.
local SLICE_X = 12
-- Drawn a bit under the sprite's 45px height. Insets stay in the same proportion as the art
-- (9px shadow, 31px face, 5px shadow) so the face does not drift.
local FACE_H = 26
local SHADOW_LEFT, SHADOW_RIGHT = 5, 5
local SHADOW_TOP, SHADOW_BOTTOM = 8, 4
local TAB_GAP = 10

-- Inclusive pixel rects: left, top, right, bottom.
-- Both cells use the full 45px height. The active art ends a row early; cropping it
-- shorter stretches that cell and drops the face by a pixel.
local RECTS = {
    inactive = { 1, 0, 101, 44 },
    active = { 105, 0, 205, 44 },
}

local function ApplyTabTexture(tex, key)
    local rect = RECTS[key]
    local left, top, right, bottom = rect[1], rect[2], rect[3], rect[4]
    tex:SetTexture(EXFrames.assets.textures.tabs.atlas)
    tex:SetTextureSliceMargins(SLICE_X, 0, SLICE_X, 0)
    tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    tex:SetTexCoord(left / ATLAS_W, (right + 1) / ATLAS_W, top / ATLAS_H, (bottom + 1) / ATLAS_H)
    tex:SetVertexColor(1, 1, 1, 1)
end

local function ApplyTabVisual(button, active, hovered)
    local theme = EXFrames.Theme

    ApplyTabTexture(button.bg, active and 'active' or 'inactive')

    if active or hovered then
        button.text:SetVertexColor(unpack(theme.white))
    else
        button.text:SetVertexColor(unpack(theme.textMuted))
    end
end

local function CreateTabButton(parent)
    local button = CreateFrame('Button', nil, parent)
    button.ID = ''
    button:SetSize(80, FACE_H)
    button.isActive = false

    local text = button:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    text:SetPoint('CENTER', 0, 0)
    text:SetWidth(0)
    button.text = text

    local bg = button:CreateTexture(nil, 'BACKGROUND')
    bg:SetPoint('TOPLEFT', -SHADOW_LEFT, SHADOW_TOP)
    bg:SetPoint('BOTTOMRIGHT', SHADOW_RIGHT, -SHADOW_BOTTOM)
    button.bg = bg

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
    -- Shadow is allowed to draw outside this bar.
    tabBar:SetHeight(FACE_H)
    tabBar:SetClipsChildren(false)
    frame.tabBar = tabBar

    local panel = EXFrames:GetFrame('panel-frame'):Create()
    panel:SetSubtleChrome()
    panel:SetParent(frame)
    panel:SetPoint('TOPLEFT', tabBar, 'BOTTOMLEFT')
    panel:SetPoint('BOTTOMRIGHT')
    frame.panel = panel
    -- Bottom shadow overlaps the panel edge, so the bar has to paint above it.
    tabBar:SetFrameLevel(panel:GetFrameLevel() + 2)

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
                button:SetPoint('BOTTOMLEFT', self.tabBar, 'BOTTOMLEFT', 5, -1)
            else
                button:SetPoint('BOTTOMLEFT', prev, 'BOTTOMRIGHT', TAB_GAP, 0)
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
