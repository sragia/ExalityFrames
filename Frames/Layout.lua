local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesLayoutFrame
local layout = EXFrames:GetFrame('layout-frame')

layout.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local function NormalizePadding(padding)
    if type(padding) == 'number' then
        return padding, padding, padding, padding
    end
    if type(padding) == 'table' then
        return padding[1] or 0, padding[2] or 0, padding[3] or 0, padding[4] or 0
    end
    return 0, 0, 0, 0
end

local function ConfigureFrame(f)
    f.items = {}
    f.direction = 'stack'
    f.gap = 10
    f.padLeft, f.padTop, f.padRight, f.padBottom = 0, 0, 0, 0

    f.SetDirection = function(self, direction)
        self.direction = direction == 'row' and 'row' or 'stack'
    end

    f.SetGap = function(self, gap)
        self.gap = gap or 0
    end

    f.SetPadding = function(self, padding)
        self.padLeft, self.padTop, self.padRight, self.padBottom = NormalizePadding(padding)
    end

    local function layoutContainsAncestorChild(layoutFrame, child)
        if not layoutFrame or not child or child == layoutFrame then
            return child == layoutFrame
        end
        if child.GetBody then
            local groupBody = child:GetBody()
            local parent = layoutFrame
            while parent do
                if parent == child or parent == groupBody then
                    return true
                end
                parent = parent:GetParent()
            end
        end
        local parent = layoutFrame:GetParent()
        while parent do
            if parent == child then
                return true
            end
            parent = parent:GetParent()
        end
        return false
    end

    local function safeSetPoint(frame, ...)
        if not frame then
            return false
        end
        local ok = pcall(frame.SetPoint, frame, ...)
        return ok
    end

    f.Add = function(self, child, spec)
        if not child then
            return
        end
        if layoutContainsAncestorChild(self, child) then
            return
        end
        spec = spec or {}
        child:SetParent(self)
        child:Show()
        table.insert(self.items, {
            frame = child,
            flex = spec.flex,
            width = spec.width,
            widthPercent = spec.widthPercent,
            height = spec.height,
            align = spec.align,
        })
    end

    f.ClearItems = function(self)
        wipe(self.items)
    end

    f.Layout = function(self)
        for i = #self.items, 1, -1 do
            if layoutContainsAncestorChild(self, self.items[i].frame) then
                table.remove(self.items, i)
            end
        end

        local width = math.max(1, self:GetWidth())
        local innerWidth = math.max(1, width - self.padLeft - self.padRight)
        local gap = self.gap or 0
        local y = -self.padTop
        local totalHeight = self.padTop + self.padBottom

        if self.direction == 'row' then
            local fixed = 0
            local flexTotal = 0
            local visible = 0
            for _, item in ipairs(self.items) do
                if item.frame:IsShown() then
                    visible = visible + 1
                    if item.width then
                        fixed = fixed + item.width
                    elseif item.widthPercent then
                        fixed = fixed + innerWidth * item.widthPercent / 100
                    else
                        flexTotal = flexTotal + (item.flex or 1)
                    end
                end
            end
            local gapTotal = visible > 1 and gap * (visible - 1) or 0
            local remaining = math.max(0, innerWidth - fixed - gapTotal)
            local x = self.padLeft
            local rowHeight = 0
            local placements = {}
            for _, item in ipairs(self.items) do
                if item.frame:IsShown() and not layoutContainsAncestorChild(self, item.frame) then
                    local childWidth = item.width
                    if not childWidth and item.widthPercent then
                        childWidth = innerWidth * item.widthPercent / 100
                    end
                    if not childWidth then
                        childWidth = flexTotal > 0 and (remaining * ((item.flex or 1) / flexTotal)) or remaining
                    end
                    item.frame:SetWidth(childWidth)
                    if item.frame.SetFrameWidth then
                        item.frame:SetFrameWidth(childWidth)
                    end
                    if item.height then
                        item.frame:SetHeight(item.height)
                    end
                    local childHeight = item.height or item.frame:GetHeight() or 0
                    if item.frame.Layout then
                        item.frame:Layout()
                        childHeight = item.frame:GetHeight()
                    end
                    rowHeight = math.max(rowHeight, childHeight)
                    table.insert(placements, {
                        item = item,
                        x = x,
                        height = childHeight,
                    })
                    x = x + childWidth + gap
                end
            end
            local rowBottom = y - rowHeight
            for _, placement in ipairs(placements) do
                local item = placement.item
                if not layoutContainsAncestorChild(self, item.frame) then
                    local childHeight = placement.height
                    local align = string.lower(item.align or 'top')
                    item.frame:ClearAllPoints()
                    if align == 'top' then
                        safeSetPoint(item.frame, 'TOPLEFT', self, 'TOPLEFT', placement.x, y)
                    elseif align == 'center' then
                        safeSetPoint(item.frame, 'TOPLEFT', self, 'TOPLEFT', placement.x, y - (rowHeight - childHeight) / 2)
                    else
                        safeSetPoint(item.frame, 'BOTTOMLEFT', self, 'TOPLEFT', placement.x, rowBottom)
                    end
                end
            end
            totalHeight = totalHeight + rowHeight
        else
            for i, item in ipairs(self.items) do
                if item.frame:IsShown() and not layoutContainsAncestorChild(self, item.frame) then
                    local childWidth = item.width
                    if not childWidth and item.widthPercent then
                        childWidth = innerWidth * item.widthPercent / 100
                    end
                    childWidth = childWidth or innerWidth
                    local childHeight = item.height or item.frame:GetHeight() or 0
                    item.frame:SetWidth(childWidth)
                    if item.frame.SetFrameWidth then
                        item.frame:SetFrameWidth(childWidth)
                    end
                    if item.height then
                        item.frame:SetHeight(item.height)
                    end
                    if item.frame.Layout then
                        item.frame:Layout()
                        childHeight = item.frame:GetHeight()
                    end
                    if not layoutContainsAncestorChild(self, item.frame) then
                        item.frame:ClearAllPoints()
                        safeSetPoint(item.frame, 'TOPLEFT', self, 'TOPLEFT', self.padLeft, y)
                    end
                    y = y - childHeight - gap
                    totalHeight = totalHeight + childHeight
                    if i < #self.items then
                        totalHeight = totalHeight + gap
                    end
                end
            end
        end

        self:SetHeight(math.max(1, totalHeight))
        return totalHeight
    end

    f.Configure = function(self, options)
        options = options or {}
        if options.direction then
            self:SetDirection(options.direction)
        end
        if options.gap ~= nil then
            self:SetGap(options.gap)
        end
        if options.padding ~= nil then
            self:SetPadding(options.padding)
        end
        if options.width then
            self:SetWidth(options.width)
        end
    end

    f.Destroy = function(self)
        for _, item in ipairs(self.items) do
            local frame = item.frame
            if frame then
                if frame.ClearItems and frame.Destroy then
                    frame:Destroy()
                else
                    frame:SetParent(nil)
                end
            end
        end
        self:ClearItems()
        self.direction = 'stack'
        self.gap = 10
        self.padLeft, self.padTop, self.padRight, self.padBottom = 0, 0, 0, 0
        if self._layoutDedicated then
            self:SetParent(nil)
            self:Hide()
        else
            layout.pool:Release(self)
        end
    end

    f.configured = true
end

layout.Create = function(self, parent, options)
    parent, options = EXFrames.FrameBase.ResolveCreateArgs(parent, options)
    options = options or {}
    for _ = 1, 8 do
        local f = self.pool:Acquire()
        local existingParent = f:GetParent()
        if existingParent and parent and existingParent ~= parent then
            if f.ClearItems then
                f:ClearItems()
            end
            f:SetParent(nil)
            self.pool:Release(f)
        else
            if not f.configured then
                ConfigureFrame(f)
            else
                f:ClearItems()
            end
            if parent then
                f:SetParent(parent)
            elseif existingParent then
                f:SetParent(nil)
            end
            f:Configure(options)
            f:Show()
            return f
        end
    end
    local f = CreateFrame('Frame', parent or UIParent)
    ConfigureFrame(f)
    f:Configure(options)
    f:Show()
    return f
end

layout.CreateDedicated = function(self, parent, options)
    parent, options = EXFrames.FrameBase.ResolveCreateArgs(parent, options)
    options = options or {}
    local f = CreateFrame('Frame', parent or UIParent)
    ConfigureFrame(f)
    f._layoutDedicated = true
    f:Configure(options)
    f:Show()
    return f
end
