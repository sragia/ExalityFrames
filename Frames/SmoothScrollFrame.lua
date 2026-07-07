local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesSmoothScrollFrame
local smoothScrollFrame = EXFrames:GetFrame('smooth-scroll-frame')

smoothScrollFrame.pool = {}

local SCROLL_STEP = 40
local SMOOTH_SPEED = 16
local MIN_THUMB_HEIGHT = 24

local function MeasureContentHeight(container)
    local containerTop = container:GetTop()
    if not containerTop then
        return container:GetHeight()
    end

    local maxExtent = container:GetHeight()

    for _, region in ipairs({ container:GetRegions() }) do
        if region:IsShown() and region.GetBottom then
            local bottom = region:GetBottom()
            if bottom then
                maxExtent = math.max(maxExtent, containerTop - bottom)
            end
        end
    end

    for _, child in ipairs({ container:GetChildren() }) do
        if child:IsShown() and child.GetBottom then
            local bottom = child:GetBottom()
            if bottom then
                maxExtent = math.max(maxExtent, containerTop - bottom)
            end
        end
    end

    return maxExtent
end

local function GetMaxScroll(f)
    local viewportHeight = f.content:GetHeight()
    local contentHeight = f.child:GetHeight()
    return math.max(0, contentHeight - viewportHeight)
end

local function UpdateThumbPosition(f)
    local maxScroll = GetMaxScroll(f)
    if maxScroll <= 0 then
        return
    end

    local scrollBar = f.scrollBar
    local thumb = scrollBar.thumb
    local trackHeight = scrollBar:GetHeight()
    local viewportHeight = f.content:GetHeight()
    local contentHeight = f.child:GetHeight()
    local thumbHeight = math.max(MIN_THUMB_HEIGHT, trackHeight * (viewportHeight / contentHeight))
    local maxThumbOffset = math.max(0, trackHeight - thumbHeight)
    local thumbOffset = (f.scrollOffset / maxScroll) * maxThumbOffset

    thumb:SetHeight(thumbHeight)
    thumb:ClearAllPoints()
    thumb:SetPoint('TOP', scrollBar, 'TOP', 0, -thumbOffset)
end

local function ApplyScroll(f, value)
    local maxScroll = GetMaxScroll(f)
    value = math.max(0, math.min(value, maxScroll))
    f.scrollOffset = value
    f.child:ClearAllPoints()
    f.child:SetPoint('TOPLEFT', f.content, 'TOPLEFT', 0, value)
    UpdateThumbPosition(f)
end

local function GetCursorYInRegion(region)
    local scale = region:GetEffectiveScale()
    local _, cursorY = GetCursorPosition()
    return cursorY / scale
end

local function EnsureOnUpdate(f)
    if f.smoothUpdateActive then
        return
    end

    f.smoothUpdateActive = true
    f:SetScript('OnUpdate', function(self, elapsed)
        local needsUpdate = false

        if self.draggingThumb then
            if not IsMouseButtonDown('LeftButton') then
                self.draggingThumb = false
                if not self.scrollBar.thumb:IsMouseOver() then
                    self.scrollBar.thumb.thumbTex:SetAlpha(0.75)
                end
            else
                local scrollBar = self.scrollBar
                local thumb = scrollBar.thumb
                local trackHeight = scrollBar:GetHeight()
                local thumbHeight = thumb:GetHeight()
                local trackTop = scrollBar:GetTop()
                local mouseY = GetCursorYInRegion(scrollBar)
                local thumbTop = mouseY + self.thumbClickOffset
                local thumbOffset = math.max(0, math.min(trackTop - thumbTop, trackHeight - thumbHeight))
                local maxScroll = GetMaxScroll(self)
                local scrollValue = maxScroll > 0 and (thumbOffset / (trackHeight - thumbHeight)) * maxScroll or 0

                self.targetScroll = scrollValue
                self.scrollOffset = scrollValue
                ApplyScroll(self, scrollValue)
                needsUpdate = true
            end
        elseif math.abs(self.scrollOffset - self.targetScroll) > 0.5 then
            local nextValue = self.scrollOffset + (self.targetScroll - self.scrollOffset) * math.min(1, elapsed * SMOOTH_SPEED)
            ApplyScroll(self, nextValue)
            needsUpdate = true
        elseif self.scrollOffset ~= self.targetScroll then
            ApplyScroll(self, self.targetScroll)
        end

        if not needsUpdate then
            self:SetScript('OnUpdate', nil)
            self.smoothUpdateActive = false
        end
    end)
end

local function UpdateContentInsets(f)
    local scrollbarWidth = f.scrollbarWidth
    local padding = f.scrollbarPadding
    local maxScroll = GetMaxScroll(f)

    f.content:ClearAllPoints()
    if maxScroll > 0 then
        f.scrollBar:Show()
        f.content:SetPoint('TOPLEFT', 0, 0)
        f.content:SetPoint('BOTTOMRIGHT', -(scrollbarWidth + padding * 2), 0)
    else
        f.scrollBar:Hide()
        f.content:SetPoint('TOPLEFT', 0, 0)
        f.content:SetPoint('BOTTOMRIGHT', 0, 0)
    end
end

local function ConfigureFrame(f)
    local th = EXFrames.Theme

    f.scrollOffset = 0
    f.targetScroll = 0
    f.scrollStep = SCROLL_STEP
    f.scrollbarWidth = EXFrames:ScalePixel(4, f)
    f.scrollbarPadding = EXFrames:ScalePixel(2, f)

    f:SetClipsChildren(true)
    f:EnableMouseWheel(true)

    local content = CreateFrame('Frame', nil, f)
    content:SetClipsChildren(true)
    content:EnableMouseWheel(true)
    f.content = content

    local child = CreateFrame('Frame', nil, content)
    child:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0)
    f.child = child

    local scrollBar = CreateFrame('Frame', nil, f)
    scrollBar:SetWidth(f.scrollbarWidth)
    scrollBar:SetPoint('TOPRIGHT', -f.scrollbarPadding, -f.scrollbarPadding)
    scrollBar:SetPoint('BOTTOMRIGHT', -f.scrollbarPadding, f.scrollbarPadding)
    f.scrollBar = scrollBar

    local track = scrollBar:CreateTexture(nil, 'BACKGROUND')
    track:SetTexture(EXFrames.assets.textures.solidWhite)
    track:SetVertexColor(unpack(th.gray))
    track:SetAlpha(0.35)
    track:SetAllPoints()
    scrollBar.track = track

    local thumb = CreateFrame('Button', nil, scrollBar)
    thumb:SetWidth(f.scrollbarWidth)
    thumb:SetHeight(MIN_THUMB_HEIGHT)
    thumb:SetPoint('TOP', scrollBar, 'TOP', 0, 0)

    local thumbTex = thumb:CreateTexture(nil, 'ARTWORK')
    thumbTex:SetTexture(EXFrames.assets.textures.solidWhite)
    thumbTex:SetVertexColor(unpack(th.accent))
    thumbTex:SetAlpha(0.75)
    thumbTex:SetAllPoints()
    thumb.thumbTex = thumbTex
    scrollBar.thumb = thumb

    thumb:SetScript('OnEnter', function(self)
        self.thumbTex:SetAlpha(1)
    end)
    thumb:SetScript('OnLeave', function(self)
        if not f.draggingThumb then
            self.thumbTex:SetAlpha(0.75)
        end
    end)
    thumb:SetScript('OnMouseDown', function(self, button)
        if button ~= 'LeftButton' then
            return
        end

        f.draggingThumb = true
        f.thumbClickOffset = self:GetTop() - GetCursorYInRegion(scrollBar)
        EnsureOnUpdate(f)
    end)
    thumb:SetScript('OnMouseUp', function(self)
        f.draggingThumb = false
        if not self:IsMouseOver() then
            self.thumbTex:SetAlpha(0.75)
        end
    end)

    scrollBar:EnableMouse(true)
    scrollBar:SetScript('OnMouseDown', function(_, button)
        if button ~= 'LeftButton' or f.draggingThumb then
            return
        end

        local thumbHeight = thumb:GetHeight()
        local trackHeight = scrollBar:GetHeight()
        local trackTop = scrollBar:GetTop()
        local mouseY = GetCursorYInRegion(scrollBar)
        local thumbOffset = math.max(0, math.min(trackTop - mouseY - thumbHeight / 2, trackHeight - thumbHeight))
        local maxScroll = GetMaxScroll(f)
        local scrollValue = maxScroll > 0 and (thumbOffset / (trackHeight - thumbHeight)) * maxScroll or 0

        f.targetScroll = scrollValue
        EnsureOnUpdate(f)
    end)

    local function OnMouseWheel(self, delta)
        local maxScroll = GetMaxScroll(f)
        if maxScroll <= 0 then
            return
        end

        f.targetScroll = math.max(0, math.min(f.targetScroll + (delta > 0 and -1 or 1) * f.scrollStep, maxScroll))
        EnsureOnUpdate(f)
    end

    f:SetScript('OnMouseWheel', OnMouseWheel)
    content:SetScript('OnMouseWheel', OnMouseWheel)

    f.UpdateScrollbar = function(self)
        UpdateContentInsets(self)

        local maxScroll = GetMaxScroll(self)
        if maxScroll <= 0 then
            self.targetScroll = 0
            self.scrollOffset = 0
            self.child:ClearAllPoints()
            self.child:SetPoint('TOPLEFT', self.content, 'TOPLEFT', 0, 0)
            return
        end

        UpdateThumbPosition(self)
    end

    f.UpdateScrollChild = function(self, width, height)
        self.child:SetWidth(width)
        if height then
            self.child:SetHeight(height)
        end

        local measuredHeight = MeasureContentHeight(self.child)
        if measuredHeight > self.child:GetHeight() then
            self.child:SetHeight(measuredHeight)
        end

        local maxScroll = GetMaxScroll(self)
        self.targetScroll = math.min(self.targetScroll, maxScroll)
        self.scrollOffset = math.min(self.scrollOffset, maxScroll)
        self:UpdateScrollbar()
        ApplyScroll(self, self.scrollOffset)
    end

    f.GetVerticalScroll = function(self)
        return self.scrollOffset
    end

    f.SetVerticalScroll = function(self, value)
        local maxScroll = GetMaxScroll(self)
        value = math.max(0, math.min(value, maxScroll))
        self.scrollOffset = value
        self.targetScroll = value
        ApplyScroll(self, value)
    end

    f.Destroy = function(self)
        self.draggingThumb = false
        self:SetScript('OnUpdate', nil)
        self.smoothUpdateActive = false
        self.scrollOffset = 0
        self.targetScroll = 0
        smoothScrollFrame.pool:Release(self)
    end

    f:SetScript('OnSizeChanged', function(self)
        self:UpdateScrollbar()
    end)

    UpdateContentInsets(f)
    f.configured = true
end

smoothScrollFrame.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

---Create a smooth-scrolling frame with a custom scrollbar.
---@param self ExalityFramesSmoothScrollFrame
---@return Frame
smoothScrollFrame.Create = function(self)
    local f = self.pool:Acquire()
    if not f.configured then
        ConfigureFrame(f)
    end

    f.scrollOffset = 0
    f.targetScroll = 0
    f.draggingThumb = false
    f:Show()
    return f
end
