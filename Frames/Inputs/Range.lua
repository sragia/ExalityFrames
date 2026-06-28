local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesRangeInput
local range = EXFrames:GetFrame('range-input')

range.pool = {}

range.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local function ConfigureFrame(f)
    EXFrames.utils.addObserver(f)
    f:SetSize(200, 32)
    f.step = 1
    f.min = 0
    f.max = 100
    f.value = 0

    hooksecurefunc(f, 'SetPoint', function(self)
        C_Timer.After(0.01, function()
            self:UpdateSparkPosition()
        end)
    end)

    -- Bar container (same positioning as EditBox inner input)
    local bar = CreateFrame('Frame', nil, f)
    bar:SetPoint('TOPLEFT', 0, -12)
    bar:SetPoint('BOTTOMRIGHT')
    bar:EnableMouse(true)
    f.bar = bar

    -- Background (reuses EditBox textures)
    local bgTex = bar:CreateTexture(nil, 'BACKGROUND')
    bgTex:SetTexture(EXFrames.assets.textures.ui.inputBg)
    bgTex:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))
    bgTex:SetTextureSliceMargins(6, 6, 6, 6)
    bgTex:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    bgTex:SetAllPoints()

    -- Border overlay (reuses EditBox textures)
    local borderTex = bar:CreateTexture(nil, 'OVERLAY', nil, 7)
    borderTex:SetTexture(EXFrames.assets.textures.ui.inputBorder)
    borderTex:SetVertexColor(unpack(EXFrames.Theme.border))
    borderTex:SetTextureSliceMargins(6, 6, 6, 6)
    borderTex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    borderTex:SetAllPoints()

    local function setBorderActive(active)
        if active then
            borderTex:SetVertexColor(unpack(EXFrames.Theme.accent))
        else
            borderTex:SetVertexColor(unpack(EXFrames.Theme.border))
        end
    end

    -- Accent fill (left-anchored, width driven by spark position)
    local fillFrame = CreateFrame('Frame', nil, bar)
    fillFrame:SetPoint('TOPLEFT', bar, 'TOPLEFT')
    fillFrame:SetPoint('BOTTOMLEFT', bar, 'BOTTOMLEFT')
    fillFrame:SetWidth(1)
    local fillTex = fillFrame:CreateTexture(nil, 'ARTWORK')
    fillTex:SetColorTexture(unpack(EXFrames.Theme.accent))
    fillTex:SetAllPoints()
    f.fillFrame = fillFrame

    -- Spark: visual-only Frame — bar handles all mouse events so hover stays reliable
    local spark = CreateFrame('Frame', nil, bar)
    spark:SetSize(1, 1)
    spark:SetPoint('CENTER', bar, 'LEFT', 0, 0)
    local sparkTex = spark:CreateTexture(nil, 'OVERLAY')
    sparkTex:SetColorTexture(1, 1, 1, 0.85)
    sparkTex:SetAllPoints()
    f.spark = spark

    -- Overlay frame so value text renders above the border texture
    local overlayFrame = CreateFrame('Frame', nil, bar)
    overlayFrame:SetAllPoints()

    local valueText = overlayFrame:CreateFontString(nil, 'OVERLAY')
    valueText:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    valueText:SetPoint('CENTER')
    f.valueText = valueText

    -- EditBox shown only on right-click, hidden by default
    local editBox = CreateFrame('EditBox', nil, bar)
    editBox:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    editBox:SetPoint('TOPLEFT', 2, -2)
    editBox:SetPoint('BOTTOMRIGHT', -2, 2)
    editBox:SetJustifyH('CENTER')
    editBox:SetTextInsets(2, 2, 0, 0)
    editBox:SetClampRectInsets(0, 0, 0, 0)
    editBox:SetNumericFullRange(true)
    editBox:SetAutoFocus(false)
    editBox:Hide()
    f.editBox = editBox

    -- Label above bar (same pattern as EditBox)
    local label = f:CreateFontString(nil, 'OVERLAY')
    label:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
    label:SetPoint('BOTTOMLEFT', bar, 'TOPLEFT', 0, 3)
    label:SetWidth(0)
    f.label = label

    -- +/- visuals: plain Frames (no mouse capture), hidden until bar is hovered.
    -- Clicks detected in bar:OnMouseUp by cursor X position.
    local leftBtn = CreateFrame('Frame', nil, bar)
    leftBtn:SetPoint('TOPLEFT', bar, 'TOPLEFT')
    leftBtn:SetPoint('BOTTOMLEFT', bar, 'BOTTOMLEFT')
    leftBtn:SetWidth(20)
    leftBtn:Hide()
    local leftBtnText = leftBtn:CreateFontString(nil, 'OVERLAY')
    leftBtnText:SetFont(EXFrames.assets.font.default(), 14, 'OUTLINE')
    leftBtnText:SetText('−')
    leftBtnText:SetTextColor(unpack(EXFrames.Theme.text))
    leftBtnText:SetPoint('CENTER')

    local rightBtn = CreateFrame('Frame', nil, bar)
    rightBtn:SetPoint('TOPRIGHT', bar, 'TOPRIGHT')
    rightBtn:SetPoint('BOTTOMRIGHT', bar, 'BOTTOMRIGHT')
    rightBtn:SetWidth(20)
    rightBtn:Hide()
    local rightBtnText = rightBtn:CreateFontString(nil, 'OVERLAY')
    rightBtnText:SetFont(EXFrames.assets.font.default(), 14, 'OUTLINE')
    rightBtnText:SetText('+')
    rightBtnText:SetTextColor(unpack(EXFrames.Theme.text))
    rightBtnText:SetPoint('CENTER')

    local function showHover()
        setBorderActive(true)
        leftBtn:Show()
        rightBtn:Show()
        spark:SetWidth(EXFrames:ScalePixel(2))
    end

    local function hideHover()
        if not editBox:HasFocus() then
            setBorderActive(false)
        end
        leftBtn:Hide()
        rightBtn:Hide()
        spark:SetWidth(EXFrames:ScalePixel(1))
    end

    -- bar is the sole mouse-capturing frame, so OnEnter/OnLeave are reliable
    bar:SetScript('OnEnter', showHover)
    bar:SetScript('OnLeave', function()
        if f.isDragging then return end
        hideHover()
    end)

    local function getBarLocalX()
        return GetCursorPosition() / bar:GetEffectiveScale() - bar:GetLeft()
    end

    bar:SetScript('OnMouseDown', function(_, button)
        if button ~= 'LeftButton' then return end
        local localX = getBarLocalX()
        local barWidth = bar:GetWidth()
        if localX > 20 and localX < barWidth - 20 then
            f.isDragging = true
        end
    end)

    bar:SetScript('OnUpdate', function()
        if not f.isDragging then return end
        local localX = getBarLocalX()
        local barWidth = bar:GetWidth()
        local inset = 4
        localX = math.max(inset, math.min(barWidth - inset, localX))

        spark:ClearAllPoints()
        spark:SetPoint('CENTER', bar, 'LEFT', localX, 0)
        fillFrame:SetWidth(math.max(1, localX))

        local trackWidth = barWidth - inset * 2
        local perc = (localX - inset) / trackWidth
        local rawValue = f.min + perc * (f.max - f.min)
        local step = f.step or 1
        local value = f.min + math.floor((rawValue - f.min) / step + 0.5) * step
        value = math.max(math.min(value, f.max), f.min)

        if value ~= f.value then
            f.value = value
            if value % 1 == 0 then
                valueText:SetText(string.format('%.0f', value))
            else
                valueText:SetText(string.format('%.2f', value))
            end
        end
    end)

    bar:SetScript('OnMouseUp', function(_, button)
        if button == 'RightButton' then
            local displayValue
            if f.value % 1 == 0 then
                displayValue = string.format('%.0f', f.value)
            else
                displayValue = string.format('%.2f', f.value)
            end
            editBox:SetText(displayValue)
            editBox:Show()
            editBox:SetFocus()
            valueText:Hide()
            setBorderActive(true)
            return
        end

        if button ~= 'LeftButton' then return end

        if f.isDragging then
            f.isDragging = false
            f:SetValue('value', f.value)
            if not bar:IsMouseOver() then hideHover() end
            return
        end

        local localX = getBarLocalX()
        local barWidth = bar:GetWidth()
        if localX <= 20 then
            local newValue = f.value - f.step
            if newValue >= f.min then f:SetValue('value', newValue) end
        elseif localX >= barWidth - 20 then
            local newValue = f.value + f.step
            if newValue <= f.max then f:SetValue('value', newValue) end
        end
    end)

    editBox:SetScript('OnEditFocusGained', function()
        setBorderActive(true)
    end)

    editBox:SetScript('OnEditFocusLost', function(self)
        self:Hide()
        valueText:Show()
        if not bar:IsMouseOver() then
            setBorderActive(false)
        end
        if f.value % 1 == 0 then
            valueText:SetText(string.format('%.0f', f.value))
        else
            valueText:SetText(string.format('%.2f', f.value))
        end
    end)

    editBox:SetScript('OnEnterPressed', function(self)
        local value = tonumber(self:GetText())
        if not value then
            self:ClearFocus()
            return
        end
        value = math.max(math.min(value, f.max), f.min)
        f:SetValue('value', value)
        self:ClearFocus()
    end)

    editBox:SetScript('OnEscapePressed', function(self)
        self:ClearFocus()
    end)

    --- Public functions
    f.SetLabel = function(self, text)
        self.label:SetText(text)
    end

    f.SetFrameWidth = function(self, width)
        self:SetWidth(width)
        C_Timer.After(0.2, function()
            self:UpdateSparkPosition()
        end)
    end

    f.SetOptionData = function(self, option)
        self.optionData = option
        self.min = option.min or 0
        self.max = option.max or 100
        self.step = option.step or 1
        self:SetLabel(option.label)
        if option.currentValue then
            self:SetValue('value', option.currentValue())
        end
    end

    f.UpdateSparkPosition = function(self)
        local barWidth = bar:GetWidth()
        if barWidth < 1 then return end
        local barHeight = bar:GetHeight()
        local inset = 4
        local trackWidth = barWidth - inset * 2
        local perc = math.max(0, math.min(1, (self.value - self.min) / (self.max - self.min)))
        local sparkX = inset + perc * trackWidth
        spark:ClearAllPoints()
        spark:SetPoint('CENTER', bar, 'LEFT', sparkX, 0)
        spark:SetSize(EXFrames:ScalePixel(1), EXFrames:ScalePixel(math.max(1, barHeight)))
        fillFrame:SetWidth(math.max(1, sparkX))
    end

    f.SetOnChange = function(self, onChange)
        self.OnChange = onChange
    end

    f:Observe('value', function(value)
        f:UpdateSparkPosition()
        if not value or (type(value) ~= 'number' and type(value) ~= 'string') then return end
        if value % 1 == 0 then
            valueText:SetText(string.format('%.0f', value))
        else
            valueText:SetText(string.format('%.2f', value))
        end
        if f.OnChange and not f.isDragging then
            f.OnChange(value)
        end
    end)

    f.configured = true
end

---Create Range input
---@param self ExalityFramesRangeInput
range.Create = function(self)
    local f = self.pool:Acquire()
    if not f.configured then
        ConfigureFrame(f)
    end

    f.onChange = nil

    f.Destroy = function(self)
        range.pool:Release(self)
    end

    f:Show()
    return f
end
