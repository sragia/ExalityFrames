local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

--[[
Tri-state checkbox for filter tokens:
0 = off, 1 = include, 2 = negate
]]

---@class ExalityFramesTriStateCheckbox
local triStateCheckbox = EXFrames:GetFrame('tri-state-checkbox')

triStateCheckbox.pool = {}

triStateCheckbox.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local STATE_OFF = 0
local STATE_INCLUDE = 1
local STATE_NEGATE = 2

local function normalizeState(state)
    local value = tonumber(state)
    if value == STATE_INCLUDE or value == STATE_NEGATE then
        return value
    end
    return STATE_OFF
end

local function ApplyStateVisual(f, state)
    local th = EXFrames.Theme
    state = normalizeState(state)

    if state == STATE_INCLUDE then
        f.Mark:Show()
        f.Mark:SetVertexColor(unpack(th.text))
        f.NegateMark:Hide()
        f.Label:SetTextColor(unpack(th.text))
    elseif state == STATE_NEGATE then
        f.Mark:Hide()
        f.NegateMark:Show()
        f.NegateMark:SetVertexColor(unpack(th.danger))
        f.Label:SetTextColor(unpack(th.danger))
    else
        f.Mark:Hide()
        f.NegateMark:Hide()
        f.Label:SetTextColor(unpack(th.text))
    end
end

local function ConfigureFrame(f)
    f.state = STATE_OFF
    f:EnableMouse(true)
    f:SetSize(1, 20)

    local base = f:CreateTexture(nil, 'ARTWORK')
    base:SetTexture(EXFrames.assets.textures.input.checkbox.base)
    base:SetSize(15, 15)
    base:SetPoint('LEFT')
    f.Base = base

    local hover = f:CreateTexture(nil, 'OVERLAY')
    hover:SetTexture(EXFrames.assets.textures.input.checkbox.hover)
    hover:SetSize(15, 15)
    hover:SetPoint('CENTER', base, 'CENTER')
    hover:SetAlpha(0)
    f.Hover = hover

    local mark = f:CreateTexture(nil, 'OVERLAY')
    mark:SetTexture(EXFrames.assets.textures.input.checkbox.mark)
    mark:SetSize(20, 15)
    mark:SetPoint('CENTER', base, 'CENTER', 2, 1)
    mark:Hide()
    f.Mark = mark

    local negateMark = f:CreateTexture(nil, 'OVERLAY')
    negateMark:SetTexture(EXFrames.assets.textures.icon.closeBold)
    negateMark:SetSize(11, 11)
    negateMark:SetPoint('CENTER', base, 'CENTER')
    negateMark:Hide()
    f.NegateMark = negateMark

    local label = f:CreateFontString(nil, 'OVERLAY')
    label:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    label:SetPoint('LEFT', base, 'RIGHT', 5, -1)
    label:SetWidth(0)
    f.Label = label

    f:SetScript('OnEnter', function(self)
        self.Hover:SetAlpha(1)
    end)
    f:SetScript('OnLeave', function(self)
        self.Hover:SetAlpha(0)
    end)

    f.SetLabel = function(self, text)
        self.Label:SetText(text)
    end

    f.SetState = function(self, state)
        state = normalizeState(state)
        self.state = state
        ApplyStateVisual(self, state)
        if self.onChange and not self.suppressOnChange then
            self.onChange(state)
        end
    end

    f.GetState = function(self)
        return normalizeState(self.state)
    end

    f:SetScript('OnMouseDown', function(self)
        local currentState = self:GetState()
        local nextState = STATE_OFF
        if currentState == STATE_OFF then
            nextState = STATE_INCLUDE
        elseif currentState == STATE_INCLUDE then
            nextState = STATE_NEGATE
        end
        self:SetState(nextState)
    end)

    f.SetFrameWidth = function(self, width)
        self:SetWidth(width)
    end

    f.SetOptionData = function(self, option)
        self.optionData = option
        self:SetLabel(option.label or '')
        self.onChange = option.onChange
        local value = STATE_OFF
        if option.currentValue then
            value = normalizeState(option.currentValue())
        end
        self.suppressOnChange = true
        self:SetState(value)
        self.suppressOnChange = false
    end

    f.configured = true
end

---@param self ExalityFramesTriStateCheckbox
---@return Frame
triStateCheckbox.Create = function(self)
    local f = self.pool:Acquire()
    if not f.configured then
        ConfigureFrame(f)
    else
        f.state = STATE_OFF
        ApplyStateVisual(f, STATE_OFF)
    end
    f.Destroy = function(self)
        self.onChange = nil
        self.suppressOnChange = nil
        self.state = STATE_OFF
        ApplyStateVisual(self, STATE_OFF)
        triStateCheckbox.pool:Release(self)
    end
    f:Show()
    return f
end
