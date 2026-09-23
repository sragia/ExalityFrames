local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesCheckbox
local checkbox = EXFrames:GetFrame('checkbox')

checkbox.pool = {}

checkbox.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local BOX_SIZE = 18
local MARK_SIZE = 12
local ROW_HEIGHT = 20
local LABEL_GAP = 6

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

local function ConfigureFrame(f)
    EXFrames.utils.addObserver(f)
    f.value = false
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

    local label = f:CreateFontString(nil, 'OVERLAY')
    label:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    label:SetTextColor(unpack(th.text))
    label:SetPoint('LEFT', box, 'RIGHT', LABEL_GAP, 0)
    label:SetWidth(0)
    f.Label = label

    f.hovering = false

    f.ApplyVisualState = function(self, checked)
        local bg = self.hovering and th.backgroundLight or th.background
        self.boxBg:SetVertexColor(unpack(bg))
        if checked then
            self.boxBorder:SetVertexColor(unpack(th.accent))
            self.checkMark:SetVertexColor(unpack(th.accent))
            self.checkMark:Show()
        else
            self.boxBorder:SetVertexColor(unpack(th.border))
            self.checkMark:Hide()
        end
    end

    f.SetLabel = function(self, text)
        self.Label:SetText(text)
    end

    f:SetScript('OnEnter', function(self)
        self.hovering = true
        self:ApplyVisualState(self.value)
    end)

    f:SetScript('OnLeave', function(self)
        self.hovering = false
        self:ApplyVisualState(self.value)
    end)

    f:SetScript('OnMouseDown', function(self)
        self:SetValue('value', not self.value)
    end)

    f.SetFrameWidth = function(self, width)
        self:SetWidth(width)
    end

    f:Observe('value', function(value, _, _, self)
        self:ApplyVisualState(value)
        if self.onChange and not self.suppressOnChange then
            self.onChange(value)
        end
    end)

    f.SetOptionData = function(self, option)
        self.optionData = option
        self:SetLabel(option.label or '')
        self.onChange = option.onChange

        self.suppressOnChange = true
        self:SetValue('value', option.currentValue and option.currentValue() or false)
        self.suppressOnChange = false
    end

    f.configured = true
end

---@param self ExalityFramesCheckbox
---@return Frame
checkbox.Create = function(self)
    local f = self.pool:Acquire()
    if not f.configured then
        ConfigureFrame(f)
    end

    f.hovering = false
    f:ApplyVisualState(f.value)

    f.Destroy = function(self)
        self.onChange = nil
        self.suppressOnChange = nil
        self.hovering = false
        self:ClearObservable()
        checkbox.pool:Release(self)
    end

    f:Show()
    return f
end

EXFrames.FrameBase.StandardizeCreate(checkbox)
