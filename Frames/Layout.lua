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

    f.Add = function(self, child, spec)
        if not child then
            return
        end
        spec = spec or {}
        child:SetParent(self)
        child:Show()
        table.insert(self.items, {
            frame = child,
            flex = spec.flex,
            width = spec.width,
            height = spec.height,
        })
    end

    f.ClearItems = function(self)
        wipe(self.items)
    end

    f.Layout = function(self)
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
                    else
                        flexTotal = flexTotal + (item.flex or 1)
                    end
                end
            end
            local gapTotal = visible > 1 and gap * (visible - 1) or 0
            local remaining = math.max(0, innerWidth - fixed - gapTotal)
            local x = self.padLeft
            local rowHeight = 0
            for _, item in ipairs(self.items) do
                if item.frame:IsShown() then
                    local childWidth = item.width
                    if not childWidth then
                        childWidth = flexTotal > 0 and (remaining * ((item.flex or 1) / flexTotal)) or remaining
                    end
                    local childHeight = item.height or item.frame:GetHeight() or 0
                    item.frame:ClearAllPoints()
                    item.frame:SetPoint('TOPLEFT', self, 'TOPLEFT', x, y)
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
                    rowHeight = math.max(rowHeight, childHeight)
                    x = x + childWidth + gap
                end
            end
            totalHeight = totalHeight + rowHeight
        else
            for i, item in ipairs(self.items) do
                if item.frame:IsShown() then
                    local childWidth = item.width or innerWidth
                    local childHeight = item.height or item.frame:GetHeight() or 0
                    item.frame:ClearAllPoints()
                    item.frame:SetPoint('TOPLEFT', self, 'TOPLEFT', self.padLeft, y)
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
            if item.frame and item.frame.ClearItems and item.frame.Destroy then
                item.frame:Destroy()
            end
        end
        self:ClearItems()
        self.direction = 'stack'
        self.gap = 10
        self.padLeft, self.padTop, self.padRight, self.padBottom = 0, 0, 0, 0
        layout.pool:Release(self)
    end

    f.configured = true
end

layout.Create = function(self, parent, options)
    parent, options = EXFrames.FrameBase.ResolveCreateArgs(parent, options)
    options = options or {}
    local f = self.pool:Acquire()
    if not f.configured then
        ConfigureFrame(f)
    else
        f:ClearItems()
    end
    if parent then
        f:SetParent(parent)
    end
    f:Configure(options)
    f:Show()
    return f
end
