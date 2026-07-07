local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

local LSM = LibStub:GetLibrary("LibSharedMedia-3.0", true)

---@class ExalityFramesSmoothScrollFrame
local scrollFrame = EXFrames:GetFrame('smooth-scroll-frame')

---@class DropdownOptionEntry : string|{label: string, icon?: string|{texture: string, width?: number, height?: number, imageSize?: {w: number, h: number}}, order?: number}
---@class DropdownOptions : {initial: string, onChange: function, options: table<string|number, DropdownOptionEntry>, label: string, width?: number, height?: number}

---@class ExalityFramesDropdownInput
local dropdown = EXFrames:GetFrame('dropdown')

dropdown.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
    self.optionItemPool = CreateFramePool('Frame', UIParent)
end

local DEFAULT_ICON_SIZE = 20

local function GetCenterSquareTexCoord(imageSize)
    if not imageSize then
        return 0, 1, 0, 1
    end
    local w = imageSize.w or imageSize.width
    local h = imageSize.h or imageSize.height
    if not w or not h or w <= 0 or h <= 0 then
        return 0, 1, 0, 1
    end
    if w > h then
        local inset = (1 - h / w) / 2
        return inset, 1 - inset, 0, 1
    elseif h > w then
        local inset = (1 - w / h) / 2
        return 0, 1, inset, 1 - inset
    end
    return 0, 1, 0, 1
end

local function GetOptionDisplay(optionValue)
    if type(optionValue) == 'table' then
        return optionValue.label, optionValue.icon
    end
    return optionValue, nil
end

local function ApplyIcon(textureFrame, icon)
    if not textureFrame then
        return
    end
    if icon then
        local tex, width, height, imageSize
        if type(icon) == 'table' then
            tex = icon.texture or icon.file
            width = icon.width or DEFAULT_ICON_SIZE
            height = icon.height or DEFAULT_ICON_SIZE
            imageSize = icon.imageSize
        else
            tex = icon
            width = DEFAULT_ICON_SIZE
            height = DEFAULT_ICON_SIZE
        end
        textureFrame:SetTexture(tex)
        local left, right, top, bottom = GetCenterSquareTexCoord(imageSize)
        textureFrame:SetTexCoord(left, right, top, bottom)
        textureFrame:SetSize(width, height)
        textureFrame:Show()
    else
        textureFrame:SetTexture(nil)
        textureFrame:SetTexCoord(0, 1, 0, 1)
        textureFrame:SetSize(0, 0)
        textureFrame:Hide()
    end
end

local function UpdateValueDisplayLayout(valueDisplay, valueIcon, icon, overlayFrame)
    ApplyIcon(valueIcon, icon)
    valueDisplay:ClearAllPoints()
    if icon then
        valueIcon:ClearAllPoints()
        valueIcon:SetPoint('LEFT', overlayFrame, 'LEFT', 10, 0)
        valueDisplay:SetPoint('LEFT', valueIcon, 'RIGHT', 4, 0)
    else
        valueDisplay:SetPoint('LEFT', overlayFrame, 'LEFT', 10, 0)
    end
end

local function ResolveOptionEntry(f, value)
    if value == nil then
        return nil, nil
    end

    if f.options then
        local entry = f.options[value]
        if entry ~= nil then
            return GetOptionDisplay(entry)
        end
    end

    local optionData = f.optionData
    if optionData and (optionData.isFontDropdown or optionData.isTextureDropdown) then
        return type(value) == 'string' and value or tostring(value), nil
    end

    if f.getOptionsFn then
        local options = f.getOptionsFn()
        local entry = options and options[value]
        if entry ~= nil then
            return GetOptionDisplay(entry)
        end
    end

    return type(value) == 'string' and value or tostring(value), nil
end

local function ApplyClosedValueStyling(f, value)
    local optionData = f.optionData
    if optionData and optionData.isFontDropdown and LSM and value then
        f.valueDisplay:SetFont(LSM:Fetch('font', value), 10, 'OUTLINE')
    else
        f.valueDisplay:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
    end

    if optionData and optionData.isTextureDropdown and LSM and value then
        f.texture:SetTexture(LSM:Fetch('statusbar', value))
        f.texture:SetVertexColor(0.8, 0.8, 0.8, 1)
        f.texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    else
        f.texture:SetTexture(EXFrames.assets.textures.ui.inputBg)
        f.texture:SetTextureSliceMargins(6, 6, 6, 6)
        f.texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        f.texture:SetVertexColor(unpack(EXFrames.Theme.background))
    end
end

local function UpdateClosedValueDisplay(f, value)
    if not f.valueDisplay then
        return
    end
    local displayValue = value
    if f.optionData and f.optionData.getDisplayValue then
        displayValue = f.optionData.getDisplayValue(value)
    end
    local label, icon = ResolveOptionEntry(f, displayValue)
    if not label then
        return
    end
    ApplyClosedValueStyling(f, displayValue)
    UpdateValueDisplayLayout(f.valueDisplay, f.valueIcon, icon, f.overlayFrame)
    f.valueDisplay:SetText(label ~= '' and label or ' ')
end

local function UpdateOptionRowLayout(valueDisplay, valueIcon, icon, option)
    ApplyIcon(valueIcon, icon)
    valueDisplay:ClearAllPoints()
    if icon then
        valueIcon:ClearAllPoints()
        valueIcon:SetPoint('LEFT', option, 'LEFT', 10, 0)
        valueDisplay:SetPoint('LEFT', valueIcon, 'RIGHT', 4, 0)
    else
        valueDisplay:SetPoint('LEFT', option, 'LEFT', 10, 0)
    end
end

local function GetOptionRowHeight(f)
    return EXFrames:ScalePixel(20, f)
end

local function GetOptionRowPitch(f)
    return GetOptionRowHeight(f) + EXFrames:ScalePixel(2, f)
end

local function CreateOption(f, frameOptions)
    local option = dropdown.optionItemPool:Acquire()
    option.optionData = f.optionData
    option.dropdownId = f.dropdownId
    local rowHeight = GetOptionRowHeight(f)
    option:SetHeight(rowHeight)

    if (not option.valueDisplay) then
        local valueDisplay = option:CreateFontString(nil, 'OVERLAY')
        option.valueDisplay = valueDisplay
        valueDisplay:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
        valueDisplay:SetWidth(0)

        local valueIcon = option:CreateTexture(nil, 'OVERLAY')
        valueIcon:SetPoint('LEFT', 10, 0)
        valueIcon:SetSize(0, 0)
        valueIcon:Hide()
        option.valueIcon = valueIcon

        local tex = option:CreateTexture(nil, 'BACKGROUND')
        tex:SetTexture(EXFrames.assets.textures.ui.inputBg)
        tex:SetTextureSliceMargins(6, 6, 6, 6)
        tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        tex:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))
        tex:SetAllPoints()
        option.texture = tex

        option.SetOption = function(self, value, label, icon)
            if (self.optionData and self.optionData.isFontDropdown and LSM) then
                valueDisplay:SetFont(LSM:Fetch('font', value), 10, 'OUTLINE')
            else
                valueDisplay:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
            end
            if (self.optionData and self.optionData.isTextureDropdown and LSM) then
                self.texture:SetTexture(LSM:Fetch('statusbar', value))
                self.texture:SetVertexColor(0.8, 0.8, 0.8, 1)
                self.texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
            else
                self.texture:SetTexture(EXFrames.assets.textures.ui.inputBg)
                self.texture:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))
                self.texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
            end
            option.value = value
            UpdateOptionRowLayout(valueDisplay, option.valueIcon, icon, option)
            option.valueDisplay:SetText(label or '')
        end
        local selectedTex = option:CreateTexture(nil, 'ARTWORK')
        selectedTex:SetTexture(EXFrames.assets.textures.solidWhite)
        selectedTex:SetVertexColor(unpack(EXFrames.Theme.accent))
        selectedTex:SetAllPoints()
        selectedTex:SetAlpha(0)
        option.selectedTex = selectedTex

        option.SetSelected = function(self, selected)
            local isTextureDropdown = self.optionData and self.optionData.isTextureDropdown
            if (selected) then
                if isTextureDropdown then
                    option.texture:SetVertexColor(1, 1, 1, 1)
                else
                    option.selectedTex:SetAlpha(0.22)
                end
            else
                if isTextureDropdown then
                    option.texture:SetVertexColor(0.8, 0.8, 0.8, 1)
                else
                    option.selectedTex:SetAlpha(0)
                end
            end
        end
    end

    option:SetScript('OnMouseDown', function(self)
        EXFrames:Callback('dropdownSelect', self.dropdownId, self.value)
        f:SetInputValue(self.value)
        f:SetValue('isOpen', false)
    end)

    if (not option.hoverContainer) then
        option.hoverContainer = true
        local hoverTex = option:CreateTexture(nil, 'BORDER')
        hoverTex:SetTexture(EXFrames.assets.textures.solidWhite)
        hoverTex:SetVertexColor(unpack(EXFrames.Theme.accent))
        hoverTex:SetAllPoints()
        hoverTex:SetAlpha(0)
        option.onHover      = EXFrames.utils.animation.fade(hoverTex, 0.1, 0, 0.15)
        option.onHoverLeave = EXFrames.utils.animation.fade(hoverTex, 0.1, 0.15, 0)
    end

    option:SetScript('OnEnter', function(self)
        self.onHover:Play()
    end)
    option:SetScript('OnLeave', function(self)
        self.onHoverLeave:Play()
    end)
    return option
end

local function GetDropdownWidth(f, frameOptions)
    local width = f:GetWidth()
    if width and width > 0 then
        return width
    end
    return frameOptions.width or 200
end

local function PopulateOptions(f, options, frameOptions, selectedValue)
    dropdown.optionItemPool:ReleaseAll()
    local previous
    local optionsNum = CountTable(options)
    local visibleRows = min(optionsNum, 10)
    local dropdownWidth = GetDropdownWidth(f, frameOptions)
    local rowPitch = GetOptionRowPitch(f)
    local rowGap = EXFrames:ScalePixel(2, f)

    local container = f.optionContainer
    local overLimit = optionsNum > 10
    if (overLimit) then
        container = f.optionContainer.scrollFrame.child
        f.optionContainer.scrollFrame:Show()
    else
        f.optionContainer.scrollFrame:Hide()
    end

    local placed = 0
    for value, label in EXFrames.utils.spairs(options, function(t, a, b)
        if (type(t[a]) == 'table' and type(t[b]) == 'table') then
            if (t[a].order and t[b].order) then
                return t[a].order < t[b].order
            end
            if (t[a].order) then
                return true
            end
            if (t[b].order) then
                return false
            end
            return (t[a].label or '') < (t[b].label or '')
        end
        return t[a] < t[b]
    end) do
        local labelText, icon = GetOptionDisplay(label)
        if not labelText then
            labelText = type(value) == 'string' and value or tostring(value)
        end
        local option = CreateOption(f, frameOptions)
        if (overLimit) then
            option:SetWidth(dropdownWidth)
        else
            option:SetWidth(dropdownWidth)
        end
        option:SetOption(value, labelText, icon)
        option:SetSelected(option.value == selectedValue)
        option:SetPoint('TOPLEFT',
            previous or container,
            previous and 'BOTTOMLEFT' or 'TOPLEFT',
            0,
            previous and -rowGap or (overLimit and 0 or rowGap)
        )
        option:SetParent(container)
        option:Show()
        previous = option
        placed = placed + 1
    end

    local totalHeight = math.max(rowPitch, (placed * rowPitch) + rowGap)
    f.optionContainer:SetHeight((visibleRows * rowPitch) + rowGap)

    if (overLimit) then
        local scroll = f.optionContainer.scrollFrame
        local scrollWidth = math.max(1, dropdownWidth)
        scroll:UpdateScrollChild(scrollWidth, totalHeight)
        scroll:SetVerticalScroll(0)
    end
end

local function ConfigureFrame(f, options)
    EXFrames.utils.addObserver(f)
    f.dropdownId = EXFrames.utils.generateRandomString(10)
    f:SetSize(options.width or 200, options.height or 40)
    f:SetFrameStrata('TOOLTIP')
    f.isOpen = false
    f.frameOptions = options
    f.onChange = options.onChange
    f.options = options.options

    if (not f.inputArea) then
        local inputArea = CreateFrame('Frame', nil, f)
        inputArea:SetPoint('TOPLEFT', 0, -12)
        inputArea:SetPoint('BOTTOMRIGHT')
        f.inputArea = inputArea

        local tex = inputArea:CreateTexture(nil, 'BACKGROUND')
        tex:SetTexture(EXFrames.assets.textures.ui.inputBg)
        tex:SetTextureSliceMargins(6, 6, 6, 6)
        tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        tex:SetVertexColor(unpack(EXFrames.Theme.background))
        tex:SetAllPoints()
        f.texture = tex

        EXFrames:ApplyInputBorder(inputArea, 1)

        local overlayFrame = CreateFrame('Frame', nil, inputArea)
        overlayFrame:SetAllPoints()
        overlayFrame:EnableMouse(false)
        f.overlayFrame = overlayFrame

        local valueDisplay = overlayFrame:CreateFontString(nil, 'OVERLAY')
        f.valueDisplay = valueDisplay
        valueDisplay:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
        valueDisplay:SetJustifyV('MIDDLE')
        valueDisplay:SetWidth(0)
        valueDisplay:SetText(' ')

        local valueIcon = overlayFrame:CreateTexture(nil, 'ARTWORK')
        valueIcon:SetPoint('LEFT', overlayFrame, 'LEFT', 10, 0)
        valueIcon:SetSize(0, 0)
        valueIcon:Hide()
        f.valueIcon = valueIcon

        f:Observe('value', function(value)
            UpdateClosedValueDisplay(f, value)
        end)

        f.SetInputValue = function(self, value)
            self:SetValue('value', value)
            if (self.onChange) then
                self.onChange(value)
            end
        end

        f:SetScript('OnMouseDown', function()
            local isOpen = not f.isOpen
            EXFrames:Callback(isOpen and 'dropdownOpen' or 'dropdownClose', f.dropdownId)
            f:SetValue('isOpen', isOpen)
        end)

        local chevron = overlayFrame:CreateTexture(nil, 'OVERLAY')
        chevron:SetSize(12, 12)
        chevron:SetPoint('RIGHT', overlayFrame, 'RIGHT', -10, 0)
        chevron:SetTexture(EXFrames.assets.textures.icon.chevronDown)
        f.chevron = chevron
        f:Observe('isOpen', function(value)
            if (value) then
                if f.getOptionsFn then
                    f:SetOptions(f.getOptionsFn())
                end
                f.optionContainer:Show()
                PopulateOptions(f, f.options or {}, f.frameOptions, f.value)
                chevron:SetRotation(math.rad(180))
            else
                f.optionContainer:Hide()
                chevron:SetRotation(math.rad(0))
            end
        end)
    end

    if (not f.hoverContainer) then
        f.hoverContainer = true  -- sentinel so this block only runs once per frame
        local function setDropdownBorderActive(active)
            if f.inputArea then
                f.inputArea:SetInputBorderActive(active)
            end
        end
        f.setDropdownBorderActive = setDropdownBorderActive
    end

    if (not f.label) then
        local textFrame = f:CreateFontString(nil, 'OVERLAY')
        textFrame:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
        textFrame:SetPoint('BOTTOMLEFT', f.inputArea or f.texture, 'TOPLEFT', 0, 2)
        textFrame:SetWidth(0)
        f.label = textFrame

        f.SetLabel = function(self, text)
            self.label:SetText(text)
        end
    end
    f.label:SetText(options.label or '')

    f:SetScript('OnEnter', function(self)
        self.setDropdownBorderActive(true)
    end)
    f:SetScript('OnLeave', function(self)
        self.setDropdownBorderActive(false)
    end)

    if (not f.optionContainer) then
        local optionContainer = CreateFrame('Frame', nil, UIParent)
        optionContainer:SetHeight(1)
        optionContainer:SetPoint('TOPLEFT', f, 'BOTTOMLEFT', 0, -5)
        optionContainer:SetPoint('TOPRIGHT', f, 'BOTTOMRIGHT', 0, -5)
        optionContainer:SetFrameStrata('FULLSCREEN_DIALOG')
        optionContainer:SetFrameLevel(99)
        f.optionContainer = optionContainer
        optionContainer:Hide()
        optionContainer:SetScript('OnEnter', function() end)
        optionContainer:SetScript('OnLeave', function() end)
        local optionContainerBg = optionContainer:CreateTexture(nil, 'BACKGROUND')
        optionContainerBg:SetTexture(EXFrames.assets.textures.solidWhite)
        optionContainerBg:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))
        optionContainerBg:SetAllPoints()
        f.optionContainerBg = optionContainerBg

        local scrollFrame = scrollFrame:Create()
        scrollFrame:SetParent(optionContainer)
        scrollFrame:SetPoint('TOPLEFT', 0, 0)
        scrollFrame:SetPoint('BOTTOMRIGHT', 0, 0)
        scrollFrame:Hide()
        f.optionContainer.scrollFrame = scrollFrame
    end

    if (options.initial) then
        f:SetValue('value', options.initial)
    end

    f.SetOptions = function(self, newOptions)
        self.options = newOptions
    end

    f.SetOptionData = function(self, option)
        self.optionData = option
        self.getOptionsFn = option.getOptions
        self:SetLabel(option.label)
        if option.getOptions then
            self:SetOptions(nil)
        elseif option.options then
            self:SetOptions(option.options)
        else
            self:SetOptions({})
        end
        self.frameOptions.isFontDropdown = option.isFontDropdown
        self.frameOptions.isTextureDropdown = option.isTextureDropdown
        self.onChange = option.onChange
        if option.currentValue then
            self:SetValue('value', option.currentValue())
        end
    end

    f.SetFrameWidth = function(self, width)
        self.frameOptions.width = width
        self:SetWidth(width)
    end

    local handleDropdownEvent = function(event, id)
        if (event == 'dropdownOpen') then
            if (id ~= f.dropdownId and f.isOpen) then
                f:SetValue('isOpen', false) -- Close dropdown if other has closed it
            end
        end
        if (event == 'windowClose' or event == 'menuItemClick') then
            f:SetValue('isOpen', false)
        end
    end

    EXFrames:RegisterCallback({
        events = { 'dropdownOpen', 'windowClose', 'menuItemClick' },
        func = handleDropdownEvent
    })
end


---@param self ExalityFramesDropdownInput
---@param options DropdownOptions
---@param parent FRAME
---@return FRAME
dropdown.Create = function(self, options, parent)
    local input = self.pool:Acquire()
    ConfigureFrame(input, options)
    if (parent) then
        input:SetParent(parent)
    else
        input:SetParent(nil)
    end
    input.Destroy = function(self)
        self.optionData = nil
        self.getOptionsFn = nil
        self:SetValue('isOpen', false)
        dropdown.pool:Release(self)
    end
    input:Show()
    return input
end
