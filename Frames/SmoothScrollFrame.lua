local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesSmoothScrollFrame
local smoothScrollFrame = EXFrames:GetFrame('smooth-scroll-frame')

smoothScrollFrame.pool = {}

local SCROLL_STEP = 40
local SMOOTH_SPEED = 16
local MIN_THUMB_HEIGHT = 24
-- Ignore sub-pixel / rounding overflow so the bar does not appear when content fits.
local SCROLL_OVERFLOW_EPSILON = 1

-- Extent of shown children only. The container's current height is not a floor,
-- so a reused scroll child can shrink after a taller page.
local function MeasureContentHeight(container)
    local containerTop = container:GetTop()
    if not containerTop then
        return nil
    end

    local maxExtent = 0
    local found = false

    local pending = false

    local function Consider(region)
        if not region:IsShown() or not region.GetBottom then
            return
        end
        local bottom = region:GetBottom()
        if not bottom then
            pending = true
            return
        end
        found = true
        maxExtent = math.max(maxExtent, containerTop - bottom)
    end

    for _, region in ipairs({ container:GetRegions() }) do
        Consider(region)
    end

    for _, child in ipairs({ container:GetChildren() }) do
        Consider(child)
    end

    if pending then
        return nil
    end
    if not found then
        return 0
    end
    return maxExtent
end

local function GetViewportHeight(f)
    -- Content is only inset horizontally, so the scroll frame height is the viewport.
    -- content:GetHeight() is stale for a frame after the anchors are rewritten.
    local height = f:GetHeight()
    if height and height > 1 then
        return height
    end
    local contentHeight = f.content and f.content:GetHeight()
    if contentHeight and contentHeight > 1 then
        return contentHeight
    end
    return 0
end

local function GetMaxScroll(f)
    local viewportHeight = GetViewportHeight(f)
    if viewportHeight <= 0 then
        return 0
    end
    local contentHeight = f.child:GetHeight()
    local overflow = contentHeight - viewportHeight
    if overflow <= SCROLL_OVERFLOW_EPSILON then
        return 0
    end
    return overflow
end

local function GetScrollbarSpace(f)
    return f.scrollbarWidth + f.scrollbarPadding * 2
end

local function ShouldShowScrollbar(f)
    return GetMaxScroll(f) > 0 and not f.scrollbarSuppressed and not f.hideScrollbar
end

local function ShouldReserveScrollbarGutter(f)
    -- Overlay mode leaves the content full width; the caller pads its rows instead.
    return ShouldShowScrollbar(f) and not f.scrollbarOverlay
end

local function SyncChildWidth(f, preferredWidth)
    local scrollbarSpace = ShouldReserveScrollbarGutter(f) and GetScrollbarSpace(f) or 0
    local availableWidth = math.max(1, f:GetWidth() - scrollbarSpace)
    local width = preferredWidth and math.min(preferredWidth, availableWidth) or availableWidth
    if math.abs(f.child:GetWidth() - width) > 0.5 then
        f.child:SetWidth(width)
    end
    return width
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
    if f.onScroll then
        f.onScroll(f, f.scrollOffset)
    end
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
    f.content:ClearAllPoints()
    f.content:SetPoint('TOPLEFT', 0, 0)
    if ShouldShowScrollbar(f) then
        f.scrollBar:SetFrameLevel(f:GetFrameLevel() + 20)
        f.scrollBar:Show()
        if f.scrollbarOverlay then
            f.content:SetPoint('BOTTOMRIGHT', 0, 0)
        else
            f.content:SetPoint('BOTTOMRIGHT', -GetScrollbarSpace(f), 0)
        end
    else
        f.scrollBar:Hide()
        f.content:SetPoint('BOTTOMRIGHT', 0, 0)
    end

    -- Keep the scroll child inside the content viewport so rows do not sit under the bar.
    SyncChildWidth(f, f.preferredChildWidth)
end

local function ReconcileContentHeight(f)
    if not f:IsShown() or not f.child then
        return
    end

    local measured = MeasureContentHeight(f.child)
    if measured then
        local target = math.max(measured, 1)
        if math.abs(f.child:GetHeight() - target) > SCROLL_OVERFLOW_EPSILON then
            f.child:SetHeight(target)
        end
    end

    local maxScroll = GetMaxScroll(f)
    f.targetScroll = math.min(f.targetScroll or 0, maxScroll)
    f.scrollOffset = math.min(f.scrollOffset or 0, maxScroll)
    if f.UpdateScrollbar then
        f:UpdateScrollbar()
    end
    ApplyScroll(f, f.scrollOffset or 0)
end

local function QueueContentReconcile(f)
    f.reconcileGeneration = (f.reconcileGeneration or 0) + 1
    local generation = f.reconcileGeneration
    local function Run(passesLeft)
        C_Timer.After(0, function()
            if f.reconcileGeneration ~= generation or not f:IsShown() or not f.child then
                return
            end
            ReconcileContentHeight(f)
            if passesLeft > 1 then
                Run(passesLeft - 1)
            end
        end)
    end
    -- Reused widgets keep their previous rect for a frame, so measure again once that settles.
    Run(2)
end

local function ConfigureFrame(f)
    local th = EXFrames.Theme

    f.scrollOffset = 0
    f.targetScroll = 0
    f.scrollbarSuppressed = false
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

    f.HandleMouseWheel = function(self, delta)
        local maxScroll = GetMaxScroll(self)
        if maxScroll <= 0 then
            return
        end

        self.targetScroll = math.max(0, math.min(self.targetScroll + (delta > 0 and -1 or 1) * self.scrollStep, maxScroll))
        EnsureOnUpdate(self)
    end

    local function OnMouseWheel(_, delta)
        f:HandleMouseWheel(delta)
    end

    f:SetScript('OnMouseWheel', OnMouseWheel)
    content:SetScript('OnMouseWheel', OnMouseWheel)
    child:EnableMouseWheel(true)
    child:SetScript('OnMouseWheel', OnMouseWheel)

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

    f.SetScrollbarSuppressed = function(self, suppressed)
        if self.scrollbarSuppressed == suppressed then
            return
        end
        self.scrollbarSuppressed = suppressed
        if suppressed then
            self.targetScroll = 0
            self.scrollOffset = 0
            ApplyScroll(self, 0)
        end
        self:UpdateScrollbar()
    end

    f.UpdateScrollChild = function(self, width, height)
        self.preferredChildWidth = width

        -- Measure against the full viewport first so bar visibility is not based on an already-inset width.
        self.scrollBar:Hide()
        self.content:ClearAllPoints()
        self.content:SetPoint('TOPLEFT', 0, 0)
        self.content:SetPoint('BOTTOMRIGHT', 0, 0)

        if height then
            self.child:SetHeight(height)
        end

        SyncChildWidth(self, width)

        local maxScroll = GetMaxScroll(self)
        self.targetScroll = math.min(self.targetScroll, maxScroll)
        self.scrollOffset = math.min(self.scrollOffset, maxScroll)
        self:UpdateScrollbar()
        ApplyScroll(self, self.scrollOffset)
        -- Drop a bar left over from the previous page once widget rects are current.
        QueueContentReconcile(self)
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

    f.Reset = function(self)
        self.reconcileGeneration = (self.reconcileGeneration or 0) + 1
        self.draggingThumb = false
        self:SetScript('OnUpdate', nil)
        self.smoothUpdateActive = false
        self.scrollOffset = 0
        self.targetScroll = 0
        self.scrollbarSuppressed = false
        self.hideScrollbar = nil
        self.preferredChildWidth = nil
        if self.child then
            self.child:SetSize(1, 1)
            self.child:ClearAllPoints()
            self.child:SetPoint('TOPLEFT', self.content, 'TOPLEFT', 0, 0)
        end
        self:UpdateScrollbar()
    end

    f.Destroy = function(self)
        self:Reset()
        self:Hide()
        smoothScrollFrame.pool:Release(self)
    end

    f:SetScript('OnSizeChanged', function(self)
        self:UpdateScrollbar()
        QueueContentReconcile(self)
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

    f:Reset()
    f:Show()
    return f
end

EXFrames.FrameBase.StandardizeCreate(smoothScrollFrame)
