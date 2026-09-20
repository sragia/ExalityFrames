local _, ns = ...
---@class ExalityUI
local EXUI = select(2, ...)
---@class ExalityFrames
local EXFrames = ns.EXFrames

local function getExpandSessionStore()
    if EXUI then
        local fields = EXUI:GetModule('options-fields')
        fields.optionGroupExpandSession = fields.optionGroupExpandSession or {}
        return fields.optionGroupExpandSession
    end
    EXFrames.optionGroupExpandSession = EXFrames.optionGroupExpandSession or {}
    return EXFrames.optionGroupExpandSession
end

---@class ExalityFramesOptionGroup
local optionGroup = EXFrames:GetFrame('option-group')

optionGroup.pool = {}

optionGroup.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local HEADER_HEIGHT = 32
local BODY_PADDING = 8
local PANEL_BG_OPACITY = 0.4
local HEADER_BG_OPACITY = 0.5

local function SetPanelBackgroundColor(texture, color, opacity)
    texture:SetVertexColor(color[1], color[2], color[3], opacity or PANEL_BG_OPACITY)
end

local function ApplyExpandIconColor(f)
    local th = EXFrames.Theme
    local color = f.headerHovered and th.white or th.textMuted
    f.expandIcon:SetVertexColor(unpack(color))
end

local function UpdateExpandIcon(f)
    local icons = EXFrames.assets.textures.icon
    if f.isExpanded then
        f.expandIcon:SetTexture(icons.eyeOff)
    else
        f.expandIcon:SetTexture(icons.eye)
    end
    ApplyExpandIconColor(f)
end

local function ConfigureFrame(f)
    local th = EXFrames.Theme

    f.isExpanded = true
    f.collapsible = true
    f.onLayoutRequest = nil
    f.bodyLayout = nil
    f.targetWidth = 100
    f.headerHovered = false

    local mainBg = f:CreateTexture(nil, 'BACKGROUND')
    mainBg:SetTexture(EXFrames.assets.textures.solidWhite)
    SetPanelBackgroundColor(mainBg, th.backgroundDeep)
    mainBg:SetAllPoints()
    f.mainBg = mainBg

    local header = CreateFrame('Button', nil, f)
    header:SetFrameLevel(f:GetFrameLevel() + 1)
    header:SetPoint('TOPLEFT')
    header:SetPoint('TOPRIGHT')
    header:SetHeight(HEADER_HEIGHT)
    f.header = header

    local headerBg = header:CreateTexture(nil, 'BACKGROUND')
    headerBg:SetTexture(EXFrames.assets.textures.solidWhite)
    SetPanelBackgroundColor(headerBg, th.backgroundDeep, HEADER_BG_OPACITY)
    headerBg:SetAllPoints()
    f.headerBg = headerBg

    local title = header:CreateFontString(nil, 'OVERLAY')
    title:SetFont(EXFrames.assets.font.default(), 15, 'OUTLINE')
    title:SetTextColor(unpack(th.white))
    title:SetPoint('LEFT', 10, 0)
    title:SetPoint('RIGHT', -28, 0)
    title:SetJustifyH('LEFT')
    f.title = title

    local expandIcon = header:CreateTexture(nil, 'OVERLAY')
    expandIcon:SetTexture(EXFrames.assets.textures.icon.eyeOff)
    expandIcon:SetSize(14, 14)
    expandIcon:SetPoint('RIGHT', -10, 0)
    f.expandIcon = expandIcon

    local accent = f:CreateTexture(nil, 'ARTWORK')
    accent:SetTexture(EXFrames.assets.textures.solidWhite)
    accent:SetVertexColor(unpack(th.accent))
    accent:SetHeight(1)
    accent:SetPoint('TOPLEFT', header, 'BOTTOMLEFT', 0, 0)
    accent:SetPoint('TOPRIGHT', header, 'BOTTOMRIGHT', 0, 0)
    f.accent = accent

    local body = CreateFrame('Frame', nil, f)
    body:SetFrameLevel(f:GetFrameLevel() + 2)
    f.body = body

    header:SetScript('OnClick', function()
        if not f.collapsible then
            return
        end
        f:SetExpanded(not f.isExpanded)
        if f.expandSessionKey then
            getExpandSessionStore()[f.expandSessionKey] = f.isExpanded
        end
        if f.onLayoutRequest then
            f.onLayoutRequest()
        end
    end)

    header:SetScript('OnEnter', function()
        f.headerHovered = true
        ApplyExpandIconColor(f)
    end)

    header:SetScript('OnLeave', function()
        f.headerHovered = false
        ApplyExpandIconColor(f)
    end)

    f.GetBody = function(self)
        return self.body
    end

    local function isInvalidBodyLayout(group, layout)
        if not layout then
            return true
        end
        if layout == group or layout == group.body or layout == group.header then
            return true
        end
        if layout.header and layout.body and layout ~= group then
            return true
        end
        local p = group:GetParent()
        while p do
            if p == layout then
                return true
            end
            p = p:GetParent()
        end
        return false
    end

    f.SetBodyLayout = function(self, layout, excludeLayout)
        if not layout then
            if self.bodyLayout and self.bodyLayout.Destroy then
                self.bodyLayout:Destroy()
            end
            self.bodyLayout = nil
            return
        end
        if layout == excludeLayout or isInvalidBodyLayout(self, layout) then
            return false
        end
        if self.bodyLayout and self.bodyLayout ~= layout and self.bodyLayout.Destroy then
            self.bodyLayout:Destroy()
        end
        self.bodyLayout = layout
        layout:SetParent(self.body)
        layout:ClearAllPoints()
        layout:SetFrameLevel(self.body:GetFrameLevel() + 1)
        self.body:SetHeight(1)
        layout:SetPoint('TOPLEFT', self.body, 'TOPLEFT', 0, 0)
        layout:SetPoint('TOPRIGHT', self.body, 'TOPRIGHT', 0, 0)
        layout:Show()
        return true
    end

    f.SetExpanded = function(self, expanded)
        if not self.collapsible then
            expanded = true
        end
        self.isExpanded = expanded ~= false
        if self.isExpanded then
            self.body:Show()
        else
            self.body:Hide()
        end
        UpdateExpandIcon(self)
        self:Layout()
    end

    f.IsExpanded = function(self)
        return self.isExpanded
    end

    f.SetFrameWidth = function(self, width)
        self.targetWidth = width
        self:SetWidth(width)
        self:Layout()
    end

    f.Layout = function(self)
        local width = math.max(1, self:GetWidth() > 0 and self:GetWidth() or self.targetWidth)
        self:SetWidth(width)

        local headerH = EXFrames:ScalePixel(HEADER_HEIGHT, self)
        local borderH = EXFrames:ScalePixel(1, self)
        local pad = EXFrames:ScalePixel(BODY_PADDING, self)

        self.header:SetHeight(headerH)
        self.accent:SetHeight(borderH)

        local totalHeight = headerH + borderH
        if self.isExpanded then
            self.body:Show()
            local innerWidth = math.max(1, width - pad * 2)
            self.body:ClearAllPoints()
            self.body:SetPoint('TOPLEFT', self.accent, 'BOTTOMLEFT', pad, -pad)
            self.body:SetWidth(innerWidth)
            if self.bodyLayout then
                if self.bodyLayout:GetParent() ~= self.body then
                    self.bodyLayout:SetParent(self.body)
                end
                self.body:SetHeight(10000)
                self.bodyLayout:SetWidth(innerWidth)
                self.bodyLayout:Layout()
                local bodyHeight = math.max(1, self.bodyLayout:GetHeight())
                self.body:SetHeight(bodyHeight)
            else
                self.body:SetHeight(1)
            end
            totalHeight = totalHeight + pad + self.body:GetHeight() + pad
        else
            self.body:Hide()
        end

        self:SetHeight(math.max(1, totalHeight))
    end

    f.SetOptionData = function(self, option)
        self.optionData = option
        self.title:SetText(option.label or '')
        local titleSize = option.titleSize
        if not titleSize and option.accent then
            titleSize = 14
        end
        self.title:SetFont(EXFrames.assets.font.default(), titleSize or 15, 'OUTLINE')
        self.collapsible = option.collapsible ~= false
        if option.accent then
            self.accent:SetVertexColor(unpack(option.accent))
        else
            self.accent:SetVertexColor(unpack(th.accent))
        end
        if self.collapsible then
            self.expandIcon:Show()
            self.header:EnableMouse(true)
        else
            self.expandIcon:Hide()
            self.header:EnableMouse(false)
        end
        self.expandSessionKey = self.expandSessionKey or option.expandSessionKey
        local expanded = option.expanded
        if type(expanded) == 'function' then
            expanded = expanded(option)
        end
        if self.expandSessionKey then
            local session = getExpandSessionStore()[self.expandSessionKey]
            if session ~= nil then
                expanded = session
            end
        end
        self:SetExpanded(expanded ~= false)
    end

    f.configured = true
end

---@param self ExalityFramesOptionGroup
---@param parent? Frame
---@return Frame
optionGroup.Create = function(self, parent)
    local f = self.pool:Acquire()
    if not f.configured then
        ConfigureFrame(f)
    end

    f.onLayoutRequest = nil
    f.bodyLayout = nil
    f.expandSessionKey = nil
    f.collapsible = true
    f.isExpanded = true
    f.headerHovered = false

    if parent then
        f:SetParent(parent)
    else
        f:SetParent(nil)
    end

    f.Destroy = function(self)
        self.onLayoutRequest = nil
        if self.bodyLayout and self.bodyLayout.Destroy then
            self.bodyLayout:Destroy()
        end
        self.bodyLayout = nil
        self.body:Hide()
        optionGroup.pool:Release(self)
    end

    f:Show()
    return f
end

EXFrames.FrameBase.StandardizeCreate(optionGroup, 'parent-only')
