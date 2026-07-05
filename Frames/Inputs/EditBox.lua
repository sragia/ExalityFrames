local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesEditBoxInput
local editBox = EXFrames:GetFrame('edit-box-input')

editBox.pool = {}

editBox.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local function ConfigureFrame(f, options)
    EXFrames.utils.addObserver(f)
    f.onChange = options.onChange

    local inputArea = CreateFrame('Frame', nil, f)
    inputArea:SetPoint('TOPLEFT', 0, -12)
    inputArea:SetPoint('BOTTOMRIGHT')
    f.inputArea = inputArea

    local bgTex = inputArea:CreateTexture(nil, 'BACKGROUND')
    bgTex:SetTexture(EXFrames.assets.textures.ui.inputBg)
    bgTex:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))
    bgTex:SetTextureSliceMargins(6, 6, 6, 6)
    bgTex:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    bgTex:SetAllPoints()

    EXFrames:ApplyInputBorder(inputArea, 1)

    local inset = EXFrames:ScalePixels(1, inputArea)
    local input = CreateFrame('EditBox', nil, inputArea)
    f.editBox = input
    input:SetAutoFocus(false)
    input:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    input:SetPoint('TOPLEFT', inset, -inset)
    input:SetPoint('BOTTOMRIGHT', -inset, inset)
    input:SetTextInsets(10, 10, 0, 0)

    f.SetInputValue = function(self, value)
        self:SetValue('inputValue', value)
        if (f.onChange) then
            f.onChange(value)
        end
    end

    input:SetScript('OnTextChanged', function(editbox, changed)
        if (changed) then
            f:SetInputValue(editbox:GetText())
        end
    end)

    input:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)

    local label = f:CreateFontString(nil, 'OVERLAY')
    label:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
    label:SetPoint('BOTTOMLEFT', inputArea, 'TOPLEFT', 0, 2)
    label:SetWidth(0)
    f.label = label

    f.SetLabel = function(self, text)
        self.label:SetText(text)
    end

    f.SetEditorValue = function(self, value)
        input:SetText(value)
    end

    f.GetEditorValue = function(self)
        return input:GetText()
    end

    local function setBorderActive(active)
        inputArea:SetInputBorderActive(active)
    end

    input:SetScript('OnEnter', function(self)
        setBorderActive(true)
    end)

    input:SetScript('OnLeave', function(self)
        if not self:HasFocus() then
            setBorderActive(false)
        end
    end)

    input:SetScript('OnEditFocusGained', function()
        setBorderActive(true)
    end)

    input:SetScript('OnEditFocusLost', function(self)
        if not self:IsMouseOver() then
            setBorderActive(false)
        end
        if self.onFocusLost then
            self.onFocusLost(self:GetText())
        end
    end)

    f.SetOptionData = function(self, option)
        self.optionData = option
        self:SetLabel(option.label)
        self:SetEditorValue(option.currentValue and option.currentValue() or '')
        self.onChange = option.onChange
    end

    f.SetMultiLine = function(self)
        input:SetMultiLine(true)
    end

    f.SetFrameWidth = function(self, width)
        self:SetWidth(width)
    end

    f.configured = true
end

---Create/Get EditBox element
---@param self ExalityFramesEditBoxInput
---@param options any
editBox.Create = function(self, options, parent)
    local f = self.pool:Acquire()
    if (not f.configured) then
        ConfigureFrame(f, options)
    end

    if (options.label) then
        f:SetLabel(options.label)
    end

    if (parent) then
        f:SetParent(parent)
    end

    if (options.initial) then
        f:SetEditorValue(options.initial)
    end

    if (options.onFocusLost) then
        f.editBox.onFocusLost = options.onFocusLost
    end

    f.Destroy = function(self)
        self:SetEditorValue('')
        editBox.pool:Release(self)
    end

    f:Show()
    return f
end
