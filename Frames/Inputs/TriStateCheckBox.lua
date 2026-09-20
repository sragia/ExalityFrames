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

local BOX_SIZE = 18
local MARK_SIZE = 12
local X_SIZE = 11
local ROW_HEIGHT = 20
local LABEL_GAP = 6

local function normalizeState(state)
    local value = tonumber(state)
    if value == STATE_INCLUDE or value == STATE_NEGATE then
        return value
    end
    return STATE_OFF
end

local function setTintedFill(tex, path, color)
    tex:SetTexture(path)
    tex:SetAllPoints()
    tex:SetVertexColor(unpack(color))
end

local function setTintedIcon(tex, path, color, size, anchorFrame)
    tex:SetTexture(path)
    tex:SetSize(size, size)
    tex:SetPoint('CENTER', anchorFrame, 'CENTER')
    tex:SetVertexColor(unpack(color))
end

local function ApplyStateVisual(f, state)
    local th = EXFrames.Theme
    state = normalizeState(state)

    local bg = f.hovering and th.backgroundLight or th.background
    f.boxBg:SetVertexColor(unpack(bg))
    f.checkMark:Hide()
    f.negateMark:Hide()

    if state == STATE_INCLUDE then
        f.boxBorder:SetVertexColor(unpack(th.accent))
        f.checkMark:SetVertexColor(unpack(th.accent))
        f.checkMark:Show()
        f.Label:SetTextColor(unpack(th.text))
    elseif state == STATE_NEGATE then
        f.boxBorder:SetVertexColor(unpack(th.danger))
        f.negateMark:SetVertexColor(unpack(th.danger))
        f.negateMark:Show()
        f.Label:SetTextColor(unpack(th.danger))
    else
        f.boxBorder:SetVertexColor(unpack(th.border))
        f.Label:SetTextColor(unpack(th.text))
    end
end

local function ConfigureFrame(f)
    f.state = STATE_OFF
    f:EnableMouse(true)
    f:SetHeight(ROW_HEIGHT)

    local th = EXFrames.Theme
    local cb = EXFrames.assets.textures.input.checkbox

    local box = CreateFrame('Frame', nil, f)
    box:SetSize(BOX_SIZE, BOX_SIZE)
    box:SetPoint('LEFT')
    f.box = box

    f.boxBg = box:CreateTexture(nil, 'BACKGROUND')
    setTintedFill(f.boxBg, cb.bg, th.background)

    f.boxBorder = box:CreateTexture(nil, 'ARTWORK')
    setTintedFill(f.boxBorder, cb.border, th.border)

    f.checkMark = box:CreateTexture(nil, 'OVERLAY')
    setTintedIcon(f.checkMark, cb.markIcon, th.accent, MARK_SIZE, box)
    f.checkMark:Hide()

    f.negateMark = box:CreateTexture(nil, 'OVERLAY')
    setTintedIcon(f.negateMark, cb.x, th.danger, X_SIZE, box)
    f.negateMark:Hide()

    local label = f:CreateFontString(nil, 'OVERLAY')
    label:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    label:SetTextColor(unpack(th.text))
    label:SetPoint('LEFT', box, 'RIGHT', LABEL_GAP, 0)
    label:SetWidth(0)
    f.Label = label

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

    f.hovering = false

    f:SetScript('OnEnter', function(self)
        self.hovering = true
        ApplyStateVisual(self, self.state)
    end)

    f:SetScript('OnLeave', function(self)
        self.hovering = false
        ApplyStateVisual(self, self.state)
    end)

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
        f.hovering = false
        ApplyStateVisual(f, STATE_OFF)
    end

    f.Destroy = function(self)
        self.onChange = nil
        self.suppressOnChange = nil
        self.hovering = false
        self.state = STATE_OFF
        ApplyStateVisual(self, STATE_OFF)
        triStateCheckbox.pool:Release(self)
    end

    f:Show()
    return f
end

EXFrames.FrameBase.StandardizeCreate(triStateCheckbox)
