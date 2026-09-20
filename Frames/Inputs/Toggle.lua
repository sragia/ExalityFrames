local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ToggleOptions : {text: string, value:boolean, secondaryText: string, onChange: function}

---@class ExalityFramesToggleInput
local toggle = EXFrames:GetFrame('toggle')

toggle.pool = {}

toggle.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

-- @3x art → 1× UI units (132×72 track, 60×60 orb)
local SWITCH_WIDTH = 44
local SWITCH_HEIGHT = 23
local ORB_SIZE = 20
local ORB_PAD = 2
local LABEL_GAP = 6

local function setTinted(tex, path, color)
    tex:SetTexture(path)
    tex:SetAllPoints()
    tex:SetVertexColor(unpack(color))
end

---@param f Frame
---@param options ToggleOptions
local function ConfigureFrame(f, options)
    EXFrames.utils.addObserver(f)
    f:EnableMouse(true)

    local th = EXFrames.Theme
    local tex = EXFrames.assets.textures.input

    local switch = CreateFrame('Frame', nil, f)
    switch:SetSize(SWITCH_WIDTH, SWITCH_HEIGHT)
    switch:SetPoint('LEFT')
    f.switch = switch

    f.trackBg = switch:CreateTexture(nil, 'BACKGROUND')
    setTinted(f.trackBg, tex.toggleBg, th.background)

    f.trackBorder = switch:CreateTexture(nil, 'ARTWORK')
    setTinted(f.trackBorder, tex.toggleBgBorder, th.border)

    local orb = CreateFrame('Frame', nil, switch)
    orb:SetSize(ORB_SIZE, ORB_SIZE)
    f.orb = orb

    f.orbFill = orb:CreateTexture(nil, 'BACKGROUND')
    setTinted(f.orbFill, tex.toggleOrb, th.backgroundLight)

    f.orbBorder = orb:CreateTexture(nil, 'ARTWORK')
    setTinted(f.orbBorder, tex.toggleBorder, th.border)

    f.orbPadTop = 2

    local function placeOrb(left)
        f.orb:ClearAllPoints()
        f.orb:SetPoint('TOP', switch, 'TOP', 0, -f.orbPadTop)
        if left then
            f.orb:SetPoint('LEFT', switch, 'LEFT', ORB_PAD, 0)
        else
            f.orb:SetPoint('RIGHT', switch, 'RIGHT', -ORB_PAD, 0)
        end
    end

    f.hovering = false

    f.ApplyVisualState = function(self, on)
        if on then
            local track = self.hovering and th.accentLight or th.accent
            self.trackBg:SetVertexColor(unpack(track))
        else
            local track = self.hovering and th.backgroundLight or th.background
            self.trackBg:SetVertexColor(unpack(track))
        end
        self.trackBorder:SetVertexColor(unpack(th.border))
        self.orbFill:SetVertexColor(unpack(th.backgroundLight))
        self.orbBorder:SetVertexColor(unpack(th.border))

        placeOrb(not on)
    end

    f.Toggle = function(self)
        self:SetValue('value', not self.value)
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
        self:Toggle()
    end)

    f:SetHeight(SWITCH_HEIGHT)

    local text = f:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    text:SetTextColor(unpack(th.text))
    text:SetJustifyH('LEFT')
    text:SetWordWrap(false)
    text:SetPoint('LEFT', switch, 'RIGHT', LABEL_GAP, 0)
    text:SetPoint('RIGHT', f, 'RIGHT', 0, 0)
    text:SetText(options.text)
    f.label = text

    local secondaryText = f:CreateFontString(nil, 'OVERLAY')
    secondaryText:SetFont(EXFrames.assets.font.default(), 9, 'OUTLINE')
    secondaryText:SetPoint('TOPLEFT', text, 'BOTTOMLEFT', 0, -3)
    secondaryText:SetPoint('RIGHT', f, 'RIGHT', 0, 0)
    secondaryText:SetJustifyH('LEFT')
    secondaryText:SetWordWrap(false)
    secondaryText:SetTextColor(unpack(th.textMuted))
    secondaryText:SetText(options.secondaryText or '')
    f.secondaryText = secondaryText

    f.SetSecondaryText = function(self, label)
        self.label:ClearAllPoints()
        self.label:SetPoint('RIGHT', self, 'RIGHT', 0, 0)
        if not label or label == '' then
            self.label:SetPoint('LEFT', switch, 'RIGHT', LABEL_GAP, 0)
            self.secondaryText:SetText('')
            return
        end
        self.label:SetPoint('TOPLEFT', switch, 'TOPRIGHT', LABEL_GAP, 0)
        self.secondaryText:SetText(label)
    end

    f.SetOptionData = function(self, option)
        self.optionData = option
        self.label:SetText(option.label)
        if option.onChange then
            self.onChange = option.onChange
        end
        if option.onClick then
            self.onClick = option.onClick
        end
        if option.description then
            self:SetSecondaryText(option.description)
        end
        if option.currentValue then
            local prevSuppress = self.suppressOnChange
            self.suppressOnChange = true
            self:SetValue('value', option.currentValue())
            self.suppressOnChange = prevSuppress
        end
    end

    f.SetFrameWidth = function(self, width)
        self:SetWidth(math.max(SWITCH_WIDTH, width or SWITCH_WIDTH))
    end

    f.isConfigured = true
end

---@param self ExalityFramesToggleInput
---@param options ToggleOptions
---@param parent FRAME
---@return FRAME
toggle.Create = function(self, options, parent)
    ---@type FRAME
    local input = self.pool:Acquire()
    input.value = false
    options = options or {}
    if not input.isConfigured then
        ConfigureFrame(input, options)
    end

    if parent then
        input:SetParent(parent)
    else
        input:SetParent(nil)
    end

    input.hovering = false

    input.Destroy = function(self)
        self.onChange = nil
        self.suppressOnChange = nil
        self._valueObserver = nil
        self.hovering = false
        self:ClearObservable()
        self:SetSecondaryText()
        toggle.pool:Release(self)
    end

    if options.text then
        input.label:SetText(options.text)
    end

    if options.secondaryText then
        input:SetSecondaryText(options.secondaryText)
    end

    input:SetValue('value', options.value)

    if not input._valueObserver then
        input._valueObserver = true
        input:Observe('value', function(value)
            input:ApplyVisualState(value)
            if input.onChange and not input.suppressOnChange then
                input.onChange(value)
            end
        end)
    end

    input:ApplyVisualState(input.value)
    input:Show()
    return input
end

EXFrames.FrameBase.StandardizeCreate(toggle)
