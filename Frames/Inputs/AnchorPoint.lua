local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesAnchorPoint
local anchorPoint = EXFrames:GetFrame('anchor-point')

anchorPoint.pool = {}

anchorPoint.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local paddingX = 10
local paddingY = 3
local borderSize = 2
local pointSize = 16

local points = {
    'TOPLEFT',
    'TOPRIGHT',
    'BOTTOMLEFT',
    'BOTTOMRIGHT',
    'CENTER',
    'TOP',
    'BOTTOM',
    'LEFT',
    'RIGHT',
}

local function ConfigureFrame(f)
    f:SetSize(150, 80)
    EXFrames.utils.addObserver(f)
    f.value = 'CENTER'

    local label = f:CreateFontString(nil, 'OVERLAY')
    label:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
    label:SetPoint('TOPLEFT', paddingX - pointSize / 2, 0)
    label:SetWidth(0)
    label:SetText('Anchor Point')
    f.Label = label

    local border = CreateFrame('Frame', nil, f, 'BackdropTemplate')
    border:SetBackdrop(EXFrames.assets.backdrop.pixelPerfect(borderSize))
    border:SetBackdropBorderColor(1, 1, 1, 0.3)
    border:SetBackdropColor(0, 0, 0, 0.3)
    border:SetPoint('LEFT', paddingX, 0)
    border:SetPoint('TOP', label, 'BOTTOM', 0, -borderSize - pointSize / 2 - 5)
    border:SetPoint('BOTTOM', 0, paddingY + borderSize)
    border:SetPoint('RIGHT', -paddingX - borderSize, 0)
    f.Border = border

    f.points = {}
    for _, point in ipairs(points) do
        local p = CreateFrame('Button', nil, f)
        p.isActive = false
        p:SetSize(pointSize, pointSize)

        local x = 0
        local y = 0
        if (point:find('LEFT')) then
            x = borderSize / 2
        elseif (point:find('RIGHT')) then
            x = -borderSize / 2
        end

        if (point:find('TOP')) then
            y = -borderSize / 2
        elseif (point:find('BOTTOM')) then
            y = borderSize / 2
        end

        p:SetPoint('CENTER', border, point, x, y)


        local tooltip = EXFrames:GetFrame('tooltip'):Get({
            text = point,
        }, p)
        p.Tooltip = tooltip

        local texture = p:CreateTexture(nil, 'OVERLAY')
        texture:SetTexture(EXFrames.assets.textures.input.anchorPoint.inactive)
        texture:SetAllPoints()
        p.texture = texture

        p.Point = point

        p:SetScript('OnEnter', function(self)
            self.Tooltip:ShowTooltip()
            if (self.isActive) then return end
            self.texture:SetTexture(EXFrames.assets.textures.input.anchorPoint.active)
            self.texture:SetVertexColor(0.4, 0.4, 0.4, 1)
        end)

        p:SetScript('OnLeave', function(self)
            self.Tooltip:HideTooltip()
            if (self.isActive) then return end
            self.texture:SetTexture(EXFrames.assets.textures.input.anchorPoint.inactive)
            self.texture:SetVertexColor(1, 1, 1, 1)
        end)

        p:SetScript('OnClick', function(self)
            f:SetValue('value', self.Point)
        end)

        p.SetActive = function(self, active)
            self.texture:SetTexture(active and
                EXFrames.assets.textures.input.anchorPoint.active or
                EXFrames.assets.textures.input.anchorPoint.inactive
            )
            self.texture:SetVertexColor(1, 1, 1, 1)
            self.isActive = active
        end

        f.points[point] = p
    end


    f:Observe('value', function(value, _, _, self)
        for _, p in pairs(f.points) do
            p:SetActive(p.Point == value)
        end

        if (f.onChange) then
            f.onChange(value)
        end
    end)

    f.SetFrameWidth = function(self, width)
        f:SetWidth(width)
    end

    f.SetOptionData = function(self, option)
        self.optionData = option
        self.Label:SetText(option.label)
        local value = option.currentValue and option.currentValue() or 'CENTER'
        f.value = value
        for _, p in pairs(self.points) do
            p:SetActive(p.Point == value)
        end
        f.onChange = option.onChange
    end

    f.configured = true
end

---Create/Get Anchor Point element
---@param self ExalityFramesAnchorPoint
---@return Frame
anchorPoint.Create = function(self)
    local f = self.pool:Acquire()
    if (not f.configured) then
        ConfigureFrame(f)
    end
    f.Destroy = function(self)
        anchorPoint.pool:Release(self)
    end

    f:Show()
    return f
end
