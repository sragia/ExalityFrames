local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesRangeInput
local range = EXFrames:GetFrame('range-input')

range.pool = {}

range.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local function formatValue(value)
    if value % 1 == 0 then
        return string.format('%.0f', value)
    end
    return string.format('%.2f', value)
end

local function ConfigureFrame(f)
    EXFrames.utils.addObserver(f)
    f:SetSize(200, 32)
    f.step = 1
    f.min = 0
    f.max = 100
    f.value = 0
    f.suppressOnChange = false
    f.trackInset = EXFrames:ScalePixel(4, f)
    f.buttonWidth = EXFrames:ScalePixel(20, f)

    -- Bar container (same positioning as EditBox inner input)
    local bar = CreateFrame('Frame', nil, f)
    bar:SetPoint('TOPLEFT', 0, -EXFrames:ScalePixel(12, f))
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

    EXFrames:ApplyInputBorder(bar, 1)

    local function setBorderActive(active)
        bar:SetInputBorderActive(active)
    end

    -- Accent fill (left-anchored, width driven by spark position)
    local fillFrame = CreateFrame('Frame', nil, bar)
    fillFrame:SetPoint('TOPLEFT', bar, 'TOPLEFT')
    fillFrame:SetPoint('BOTTOMLEFT', bar, 'BOTTOMLEFT')
    fillFrame:SetWidth(1)
    local fillTex = fillFrame:CreateTexture(nil, 'ARTWORK')
    fillTex:SetTexture(EXFrames.assets.textures.solidWhiteTexture)
    fillTex:SetTextureSliceMargins(6, 6, 6, 6)
    fillTex:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    fillTex:SetVertexColor(unpack(EXFrames.Theme.accentDark))
    fillTex:SetAllPoints()
    f.fillFrame = fillFrame

    -- Spark: pixel-aligned vertical line texture (no mouse capture; bar handles input)
    local sparkTex = bar:CreateTexture(nil, 'OVERLAY', nil, 5)
    sparkTex:SetTexture(EXFrames.assets.textures.solidWhite)
    sparkTex:SetVertexColor(1, 1, 1, 0.85)
    sparkTex:SetSnapToPixelGrid(true)
    sparkTex:SetTexelSnappingBias(0)
    f.sparkTex = sparkTex
    f.sparkThickness = 1

    f.ApplySparkLayout = function(self, sparkX)
        local thickness = self.sparkThickness or 1
        local x = EXFrames:ScalePixel(sparkX, bar)
        local w = EXFrames:ScalePixels(thickness, bar)
        local minFill = EXFrames:ScalePixels(1, bar)
        sparkTex:ClearAllPoints()
        sparkTex:SetPoint('TOPLEFT', bar, 'TOPLEFT', x, 0)
        sparkTex:SetPoint('BOTTOMLEFT', bar, 'BOTTOMLEFT', x, 0)
        sparkTex:SetWidth(w)
        fillFrame:SetWidth(math.max(minFill, x))
    end

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
    label:SetPoint('BOTTOMLEFT', bar, 'TOPLEFT', 0, EXFrames:ScalePixel(3, f))
    label:SetWidth(0)
    f.label = label

    -- +/- visuals: plain Frames (no mouse capture), hidden until bar is hovered.
    -- Clicks detected in bar:OnMouseUp by cursor X position.
    local leftBtn = CreateFrame('Frame', nil, bar)
    leftBtn:SetPoint('TOPLEFT', bar, 'TOPLEFT')
    leftBtn:SetPoint('BOTTOMLEFT', bar, 'BOTTOMLEFT')
    leftBtn:SetWidth(f.buttonWidth)
    leftBtn:Hide()
    local leftBtnText = leftBtn:CreateFontString(nil, 'OVERLAY')
    leftBtnText:SetFont(EXFrames.assets.font.default(), 14, 'OUTLINE')
    leftBtnText:SetText('−')
    leftBtnText:SetTextColor(unpack(EXFrames.Theme.text))
    leftBtnText:SetPoint('CENTER')

    local rightBtn = CreateFrame('Frame', nil, bar)
    rightBtn:SetPoint('TOPRIGHT', bar, 'TOPRIGHT')
    rightBtn:SetPoint('BOTTOMRIGHT', bar, 'BOTTOMRIGHT')
    rightBtn:SetWidth(f.buttonWidth)
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
        f.sparkThickness = 2
        f:UpdateSparkPosition()
    end

    local function hideHover()
        if not editBox:HasFocus() then
            setBorderActive(false)
        end
        leftBtn:Hide()
        rightBtn:Hide()
        f.sparkThickness = 1
        f:UpdateSparkPosition()
    end

    -- bar is the sole mouse-capturing frame, so OnEnter/OnLeave are reliable
    bar:SetScript('OnEnter', showHover)
    bar:SetScript('OnLeave', function()
        if f.isDragging then return end
        hideHover()
    end)

    bar:HookScript('OnSizeChanged', function()
        f:UpdateSparkPosition()
        if bar.PPBorder then
            bar.PPBorder:SetBorderThickness(bar.PPBorder.thicknessPixels or 1)
        end
    end)

    local function getBarLocalX()
        return GetCursorPosition() / bar:GetEffectiveScale() - bar:GetLeft()
    end

    bar:SetScript('OnMouseDown', function(_, button)
        if button ~= 'LeftButton' then return end
        local localX = getBarLocalX()
        local barWidth = bar:GetWidth()
        if localX > f.buttonWidth and localX < barWidth - f.buttonWidth then
            f.isDragging = true
        end
    end)

    bar:SetScript('OnUpdate', function()
        if not f.isDragging then return end
        local localX = getBarLocalX()
        local barWidth = bar:GetWidth()
        localX = math.max(f.trackInset, math.min(barWidth - f.trackInset, localX))
        f:ApplySparkLayout(localX)

        local trackWidth = barWidth - f.trackInset * 2
        local perc = (localX - f.trackInset) / trackWidth
        local rawValue = f.min + perc * (f.max - f.min)
        local step = f.step or 1
        local value = f.min + math.floor((rawValue - f.min) / step + 0.5) * step
        value = math.max(math.min(value, f.max), f.min)

        if value ~= f.value then
            f.value = value
            valueText:SetText(formatValue(value))
        end
    end)

    bar:SetScript('OnMouseUp', function(_, button)
        if button == 'RightButton' then
            editBox:SetText(formatValue(f.value))
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
        if localX <= f.buttonWidth then
            local newValue = f.value - f.step
            if newValue >= f.min then f:SetValue('value', newValue) end
        elseif localX >= barWidth - f.buttonWidth then
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
        valueText:SetText(formatValue(f.value))
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
        self:UpdateSparkPosition()
        C_Timer.After(0, function()
            if self:IsShown() then
                self:UpdateSparkPosition()
            end
        end)
    end

    f.UpdateSparkPosition = function(self)
        local barWidth = bar:GetWidth()
        if barWidth < 1 then return end
        local trackWidth = barWidth - self.trackInset * 2
        if trackWidth < 1 then return end
        local rangeSpan = self.max - self.min
        local perc = rangeSpan > 0 and math.max(0, math.min(1, (self.value - self.min) / rangeSpan)) or 0
        local sparkX = self.trackInset + perc * trackWidth
        self:ApplySparkLayout(sparkX)
    end

    f.ResetForAcquire = function(self)
        self.isDragging = false
        self.suppressOnChange = false
        self.min = 0
        self.max = 100
        self.step = 1
        self.value = 0
        self.optionData = nil
        self.sparkThickness = 1
        self.trackInset = EXFrames:ScalePixel(4, self)
        self.buttonWidth = EXFrames:ScalePixel(20, self)
        leftBtn:SetWidth(self.buttonWidth)
        rightBtn:SetWidth(self.buttonWidth)
        editBox:Hide()
        editBox:ClearFocus()
        valueText:Show()
        valueText:SetText('')
        fillFrame:SetWidth(EXFrames:ScalePixels(1, bar))
        self:ApplySparkLayout(self.trackInset)
    end

    f.SetState = function(self, value)
        if self.optionData then
            self.min = self.optionData.min or 0
            self.max = self.optionData.max or 100
            self.step = self.optionData.step or 1
        end
        self.suppressOnChange = true
        self:SetValue('value', value)
        self.suppressOnChange = false
        self:UpdateSparkPosition()
    end

    f.SetOptionData = function(self, option)
        self.optionData = option
        self.min = option.min or 0
        self.max = option.max or 100
        self.step = option.step or 1
        self:SetLabel(option.label)
        self.suppressOnChange = true
        local value = option.currentValue and option.currentValue() or self.min
        self:SetValue('value', value)
        self.suppressOnChange = false
        self:UpdateSparkPosition()
    end

    f.SetOnChange = function(self, onChange)
        self.OnChange = onChange
    end

    f:Observe('value', function(value)
        f:UpdateSparkPosition()
        if not value or (type(value) ~= 'number' and type(value) ~= 'string') then return end
        valueText:SetText(formatValue(value))
        if f.OnChange and not f.isDragging and not f.suppressOnChange then
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
    f.OnChange = nil
    f:ResetForAcquire()

    f.Destroy = function(self)
        self:ResetForAcquire()
        range.pool:Release(self)
    end

    f:Show()
    return f
end
