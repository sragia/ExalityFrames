local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesColorPicker
local colorPicker = EXFrames:GetFrame('color-picker')

colorPicker.pool = {}

colorPicker.Init = function(self)
    self.pool = CreateFramePool('Button', UIParent)
end

local MAX_RECENT_COLORS = 8
local sessionRecentColors = {}
local colorClipboard = nil

local function Clamp01(value)
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function NormalizeHueFromRGB(h)
    if not h then
        return 0
    end
    if h > 1 then
        return Clamp01(h / 360)
    end
    return Clamp01(h)
end

local function HueToColorUtilRange(h)
    return Clamp01(h) * 360
end

local function CopyColor(color)
    return {
        r = Clamp01(color.r or color[1] or 1),
        g = Clamp01(color.g or color[2] or 1),
        b = Clamp01(color.b or color[3] or 1),
        a = Clamp01(color.a or color[4] or 1),
    }
end

local function ColorEquals(a, b)
    if (not a) or (not b) then
        return false
    end
    return math.abs((a.r or 0) - (b.r or 0)) < 0.001 and
        math.abs((a.g or 0) - (b.g or 0)) < 0.001 and
        math.abs((a.b or 0) - (b.b or 0)) < 0.001 and
        math.abs((a.a or 0) - (b.a or 0)) < 0.001
end

local function ColorToHex(color, includeAlpha)
    local r = math.floor(Clamp01(color.r or 1) * 255 + 0.5)
    local g = math.floor(Clamp01(color.g or 1) * 255 + 0.5)
    local b = math.floor(Clamp01(color.b or 1) * 255 + 0.5)
    local a = math.floor(Clamp01(color.a or 1) * 255 + 0.5)
    if includeAlpha then
        return string.format("#%02X%02X%02X%02X", r, g, b, a)
    end
    return string.format("#%02X%02X%02X", r, g, b)
end

local function ParseHex(input)
    if type(input) ~= "string" then
        return nil
    end

    local hex = input:gsub("#", ""):gsub("[^%x]", ""):upper()
    if #hex == 6 then
        local r = tonumber(hex:sub(1, 2), 16) / 255
        local g = tonumber(hex:sub(3, 4), 16) / 255
        local b = tonumber(hex:sub(5, 6), 16) / 255
        return { r = r, g = g, b = b }
    end
    if #hex == 8 then
        local r = tonumber(hex:sub(1, 2), 16) / 255
        local g = tonumber(hex:sub(3, 4), 16) / 255
        local b = tonumber(hex:sub(5, 6), 16) / 255
        local a = tonumber(hex:sub(7, 8), 16) / 255
        return { r = r, g = g, b = b, a = a }, true
    end
    return nil
end

local function AddRecentColor(color)
    local nextColor = CopyColor(color)
    for i = #sessionRecentColors, 1, -1 do
        if ColorEquals(sessionRecentColors[i], nextColor) then
            table.remove(sessionRecentColors, i)
        end
    end
    table.insert(sessionRecentColors, 1, nextColor)
    while #sessionRecentColors > MAX_RECENT_COLORS do
        table.remove(sessionRecentColors)
    end
end

local function ApplyGradient(tex, orientation, startColor, endColor)
    if tex.SetGradient then
        tex:SetGradient(orientation, startColor, endColor)
    else
        tex:SetColorTexture(startColor:GetRGBA())
    end
end

local function ConfigureMiniButton(btn, text)
    btn:SetSize(44, 16)
    btn:EnableMouse(true)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(EXFrames.assets.textures.ui.buttonBg)
    bg:SetTextureSliceMargins(6, 6, 6, 6)
    bg:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    bg:SetVertexColor(unpack(EXFrames.Theme.accent))
    btn.bg = bg

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER")
    label:SetFont(EXFrames.assets.font.default(), 10, "OUTLINE")
    label:SetText(text)
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(unpack(EXFrames.Theme.accentLight))
    end)
    btn:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(unpack(EXFrames.Theme.accent))
    end)
end

local function CreateChannelInput(parent, labelText, width)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width or 88, 20)
    EXFrames:ApplyInputBorder(container, 1)

    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(EXFrames.assets.textures.ui.inputBg)
    bg:SetTextureSliceMargins(6, 6, 6, 6)
    bg:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    bg:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFont(EXFrames.assets.font.default(), 10, "OUTLINE")
    label:SetPoint("LEFT", 4, 0)
    label:SetText(labelText)

    local input = CreateFrame("EditBox", nil, container)
    input:SetAutoFocus(false)
    input:SetPoint("TOPLEFT", 20, -2)
    input:SetPoint("BOTTOMRIGHT", -2, 2)
    input:SetFont(EXFrames.assets.font.default(), 10, "OUTLINE")
    input:SetJustifyH("RIGHT")
    input:SetTextInsets(2, 4, 0, 0)

    container.label = label
    container.input = input
    return container
end

local function ConfigureFrame(f)
    EXFrames.utils.addObserver(f)
    f:SetHeight(20)
    f.color = { r = 1, g = 1, b = 1, a = 1 }
    f.hsv = { h = 0, s = 0, v = 1 }
    f.hasOpacity = true

    local colorBoxContainer = CreateFrame('Frame', nil, f)
    EXFrames:ApplyInputBorder(colorBoxContainer, 1)
    colorBoxContainer:SetSize(20, 20)
    colorBoxContainer:SetPoint('LEFT')
    local colorBox = colorBoxContainer:CreateTexture(nil, 'BACKGROUND')
    colorBox:SetTexture(EXFrames.assets.textures.solidBg)
    colorBox:SetVertexColor(1, 1, 1, 1)
    local borderInset = EXFrames:ScalePixels(1, colorBoxContainer)
    colorBox:SetPoint('TOPLEFT', borderInset, -borderInset)
    colorBox:SetPoint('BOTTOMRIGHT', -borderInset, borderInset)
    f.colorBox = colorBox

    local label = f:CreateFontString(nil, 'OVERLAY')
    label:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    label:SetPoint('LEFT', colorBoxContainer, 'RIGHT', 5, 0)
    label:SetWidth(0)
    f.label = label

    local overlay = CreateFrame("Button", nil, UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("TOOLTIP")
    overlay:EnableMouse(true)
    overlay:Hide()
    f.overlay = overlay

    local picker = CreateFrame("Frame", nil, overlay)
    picker:SetSize(332, 290)
    picker:SetPoint("LEFT", f, "RIGHT", 8, 0)
    picker:SetFrameStrata("TOOLTIP")
    picker:SetFrameLevel(overlay:GetFrameLevel() + 20)
    picker:Hide()
    f.picker = picker
    EXFrames:ApplyInputBorder(picker, 1)

    local pickerBg = picker:CreateTexture(nil, "BACKGROUND")
    pickerBg:SetAllPoints()
    pickerBg:SetTexture(EXFrames.assets.textures.ui.panelBg)
    pickerBg:SetTextureSliceMargins(12, 12, 12, 12)
    pickerBg:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    pickerBg:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))

    local svFrame = CreateFrame("Frame", nil, picker)
    svFrame:SetSize(170, 170)
    svFrame:SetPoint("TOPLEFT", 10, -10)
    svFrame:EnableMouse(true)
    f.svFrame = svFrame
    EXFrames:ApplyInputBorder(svFrame, 1)

    local svHue = svFrame:CreateTexture(nil, "BACKGROUND")
    svHue:SetAllPoints()
    svHue:SetTexture(EXFrames.assets.textures.solidWhite)
    f.svHue = svHue

    local svWhite = svFrame:CreateTexture(nil, "ARTWORK")
    svWhite:SetAllPoints()
    svWhite:SetTexture(EXFrames.assets.textures.solidWhite)
    ApplyGradient(
        svWhite,
        "HORIZONTAL",
        CreateColor(1, 1, 1, 1),
        CreateColor(1, 1, 1, 0)
    )

    local svBlack = svFrame:CreateTexture(nil, "ARTWORK")
    svBlack:SetAllPoints()
    svBlack:SetTexture(EXFrames.assets.textures.solidWhite)
    ApplyGradient(
        svBlack,
        "VERTICAL",
        CreateColor(0, 0, 0, 1),
        CreateColor(0, 0, 0, 0)
    )

    local svCursor = CreateFrame("Frame", nil, svFrame)
    svCursor:SetSize(10, 10)
    svCursor:SetFrameLevel(svFrame:GetFrameLevel() + 5)
    local svCursorOuter = svCursor:CreateTexture(nil, "OVERLAY")
    svCursorOuter:SetAllPoints()
    svCursorOuter:SetTexture(EXFrames.assets.textures.solidWhite)
    svCursorOuter:SetColorTexture(0, 0, 0, 1)
    local svCursorInner = svCursor:CreateTexture(nil, "OVERLAY")
    svCursorInner:SetPoint("TOPLEFT", 1, -1)
    svCursorInner:SetPoint("BOTTOMRIGHT", -1, 1)
    svCursorInner:SetTexture(EXFrames.assets.textures.solidWhite)
    svCursorInner:SetColorTexture(1, 1, 1, 1)
    f.svCursor = svCursor

    local hueFrame = CreateFrame("Frame", nil, picker)
    hueFrame:SetSize(16, 170)
    hueFrame:SetPoint("TOPLEFT", svFrame, "TOPRIGHT", 8, 0)
    hueFrame:EnableMouse(true)
    f.hueFrame = hueFrame
    EXFrames:ApplyInputBorder(hueFrame, 1)
    local hueTexture = hueFrame:CreateTexture(nil, "ARTWORK")
    hueTexture:SetAllPoints()
    hueTexture:SetTexture(EXFrames.assets.textures.input.colorPicker.hueVertical)
    f.hueTexture = hueTexture

    local hueThumb = CreateFrame("Frame", nil, hueFrame)
    hueThumb:SetSize(20, 4)
    hueThumb:SetFrameLevel(hueFrame:GetFrameLevel() + 5)
    local hueThumbTex = hueThumb:CreateTexture(nil, "OVERLAY")
    hueThumbTex:SetAllPoints()
    hueThumbTex:SetColorTexture(1, 1, 1, 1)
    f.hueThumb = hueThumb

    local alphaFrame = CreateFrame("Frame", nil, picker)
    alphaFrame:SetSize(16, 170)
    alphaFrame:SetPoint("TOPLEFT", hueFrame, "TOPRIGHT", 8, 0)
    alphaFrame:EnableMouse(true)
    f.alphaFrame = alphaFrame
    EXFrames:ApplyInputBorder(alphaFrame, 1)

    local alphaChecker = alphaFrame:CreateTexture(nil, "BACKGROUND")
    alphaChecker:SetAllPoints()
    alphaChecker:SetTexture(EXFrames.assets.textures.input.colorPicker.alphaChecker, "REPEAT", "REPEAT")
    alphaChecker:SetHorizTile(true)
    alphaChecker:SetVertTile(true)
    local checkerTileWidth, checkerTileHeight = 8, 8
    local function UpdateAlphaCheckerTiling()
        local width = alphaFrame:GetWidth()
        local height = alphaFrame:GetHeight()
        if width <= 0 or height <= 0 then
            return
        end
        alphaChecker:SetTexCoord(0, width / checkerTileWidth, 0, height / checkerTileHeight)
    end
    alphaFrame:HookScript("OnSizeChanged", UpdateAlphaCheckerTiling)
    alphaFrame:HookScript("OnShow", UpdateAlphaCheckerTiling)
    UpdateAlphaCheckerTiling()

    local alphaGradient = alphaFrame:CreateTexture(nil, "ARTWORK")
    alphaGradient:SetAllPoints()
    alphaGradient:SetTexture(EXFrames.assets.textures.solidWhite)
    f.alphaGradient = alphaGradient

    local alphaThumb = CreateFrame("Frame", nil, alphaFrame)
    alphaThumb:SetSize(20, 4)
    alphaThumb:SetFrameLevel(alphaFrame:GetFrameLevel() + 5)
    local alphaThumbTex = alphaThumb:CreateTexture(nil, "OVERLAY")
    alphaThumbTex:SetAllPoints()
    alphaThumbTex:SetColorTexture(1, 1, 1, 1)
    f.alphaThumb = alphaThumb

    local hexArea = CreateFrame("Frame", nil, picker)
    hexArea:SetSize(88, 24)
    hexArea:SetPoint("TOPLEFT", alphaFrame, "TOPRIGHT", 8, -10)
    EXFrames:ApplyInputBorder(hexArea, 1)
    local hexBg = hexArea:CreateTexture(nil, "BACKGROUND")
    hexBg:SetAllPoints()
    hexBg:SetTexture(EXFrames.assets.textures.ui.inputBg)
    hexBg:SetTextureSliceMargins(6, 6, 6, 6)
    hexBg:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    hexBg:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))

    local hexInput = CreateFrame("EditBox", nil, hexArea)
    hexInput:SetAutoFocus(false)
    hexInput:SetPoint("TOPLEFT", 2, -2)
    hexInput:SetPoint("BOTTOMRIGHT", -2, 2)
    hexInput:SetFont(EXFrames.assets.font.default(), 11, "OUTLINE")
    hexInput:SetTextInsets(4, 4, 0, 0)
    f.hexInput = hexInput

    local previewLabel = picker:CreateFontString(nil, "OVERLAY")
    previewLabel:SetFont(EXFrames.assets.font.default(), 10, "OUTLINE")
    previewLabel:SetPoint("TOPLEFT", svFrame, "BOTTOMLEFT", 0, -8)
    previewLabel:SetText("Prev / Current")

    local prevSwatch = CreateFrame("Button", nil, picker)
    prevSwatch:SetSize(30, 18)
    prevSwatch:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 0, -4)
    EXFrames:ApplyInputBorder(prevSwatch, 1)
    local prevSwatchTex = prevSwatch:CreateTexture(nil, "ARTWORK")
    prevSwatchTex:SetAllPoints()
    prevSwatchTex:SetTexture(EXFrames.assets.textures.solidWhite)
    f.prevSwatchTex = prevSwatchTex
    f.prevSwatch = prevSwatch

    local currentSwatch = CreateFrame("Frame", nil, picker)
    currentSwatch:SetSize(30, 18)
    currentSwatch:SetPoint("LEFT", prevSwatch, "RIGHT", 6, 0)
    EXFrames:ApplyInputBorder(currentSwatch, 1)
    local currentSwatchTex = currentSwatch:CreateTexture(nil, "ARTWORK")
    currentSwatchTex:SetAllPoints()
    currentSwatchTex:SetTexture(EXFrames.assets.textures.solidWhite)
    f.currentSwatchTex = currentSwatchTex

    local copyBtn = CreateFrame("Button", nil, picker)
    copyBtn:SetPoint("TOPLEFT", prevSwatch, "BOTTOMLEFT", 0, -6)
    ConfigureMiniButton(copyBtn, "Copy")
    f.copyBtn = copyBtn

    local pasteBtn = CreateFrame("Button", nil, picker)
    pasteBtn:SetPoint("LEFT", copyBtn, "RIGHT", 6, 0)
    ConfigureMiniButton(pasteBtn, "Paste")
    f.pasteBtn = pasteBtn

    local recentLabel = picker:CreateFontString(nil, "OVERLAY")
    recentLabel:SetFont(EXFrames.assets.font.default(), 10, "OUTLINE")
    recentLabel:SetPoint("TOPLEFT", copyBtn, "BOTTOMLEFT", 0, -8)
    recentLabel:SetText("Recent")

    local recentButtons = {}
    for i = 1, MAX_RECENT_COLORS do
        local swatch = CreateFrame("Button", nil, picker)
        swatch:SetSize(14, 14)
        if i == 1 then
            swatch:SetPoint("TOPLEFT", recentLabel, "BOTTOMLEFT", 0, -4)
        else
            swatch:SetPoint("LEFT", recentButtons[i - 1], "RIGHT", 4, 0)
        end
        EXFrames:ApplyInputBorder(swatch, 1)
        local tex = swatch:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(EXFrames.assets.textures.solidWhite)
        swatch.tex = tex
        swatch:Hide()
        recentButtons[i] = swatch
    end
    f.recentButtons = recentButtons

    local rgbaContainer = CreateFrame("Frame", nil, picker)
    rgbaContainer:SetSize(88, 90)
    rgbaContainer:SetPoint("TOPLEFT", hexArea, "BOTTOMLEFT", 0, -14)

    local rInput = CreateChannelInput(rgbaContainer, "R", 88)
    rInput:SetPoint("TOPLEFT")
    local gInput = CreateChannelInput(rgbaContainer, "G", 88)
    gInput:SetPoint("TOPLEFT", rInput, "BOTTOMLEFT", 0, -4)
    local bInput = CreateChannelInput(rgbaContainer, "B", 88)
    bInput:SetPoint("TOPLEFT", gInput, "BOTTOMLEFT", 0, -4)
    local aInput = CreateChannelInput(rgbaContainer, "A", 88)
    aInput:SetPoint("TOPLEFT", bInput, "BOTTOMLEFT", 0, -4)

    local channelInputs = {
        r = rInput.input,
        g = gInput.input,
        b = bInput.input,
        a = aInput.input,
    }
    f.channelInputs = channelInputs

    local closeBtn = CreateFrame("Button", nil, picker)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", -3, -3)
    local closeIcon = closeBtn:CreateTexture(nil, "OVERLAY")
    closeIcon:SetAllPoints()
    closeIcon:SetTexture(EXFrames.assets.textures.icon.close)
    closeBtn:SetScript("OnClick", function()
        f:ClosePicker()
    end)

    local confirmBtn = CreateFrame("Button", nil, picker)
    confirmBtn:SetSize(88, 22)
    confirmBtn:SetPoint("TOPLEFT", aInput, "BOTTOMLEFT", 0, -8)
    EXFrames:ApplyInputBorder(confirmBtn, 1)
    local confirmBg = confirmBtn:CreateTexture(nil, "BACKGROUND")
    confirmBg:SetAllPoints()
    confirmBg:SetTexture(EXFrames.assets.textures.solidWhite)
    confirmBg:SetVertexColor(unpack(EXFrames.Theme.successDark))
    local confirmText = confirmBtn:CreateFontString(nil, "OVERLAY")
    confirmText:SetFont(EXFrames.assets.font.default(), 10, "OUTLINE")
    confirmText:SetPoint("CENTER")
    confirmText:SetText("Accept")
    f.confirmBtn = confirmBtn

    f.SetLabel = function(self, text)
        self.label:SetText(text)
    end

    f.SetFrameWidth = function(self, width)
        self:SetWidth(width)
    end

    f.GetWorkingColor = function(self)
        return self.pendingColor or self.color
    end

    f.PreviewPendingColor = function(self)
        if self.onChange and self.pendingColor and self.picker:IsShown() then
            self.onChange(CopyColor(self.pendingColor))
        end
    end

    f.ClosePicker = function(self, keepChanges)
        if not self.picker:IsShown() then
            return
        end
        local shouldRestore = (not keepChanges) and self.pendingColor and self.previousColor and
            (not ColorEquals(self.pendingColor, self.previousColor))
        self.picker:Hide()
        self.overlay:Hide()
        self.isDragging = nil
        self.dragTarget = nil
        self.pendingColor = nil
        if shouldRestore and self.onChange then
            self.onChange(CopyColor(self.previousColor))
        end
    end

    f.OpenPicker = function(self)
        self.previousColor = CopyColor(self.color)
        self.pendingColor = CopyColor(self.color)
        local h, s, v = C_ColorUtil.ConvertRGBToHSV(
            self.pendingColor.r,
            self.pendingColor.g,
            self.pendingColor.b
        )
        self.hsv.h = NormalizeHueFromRGB(h)
        self.hsv.s = Clamp01(s or 0)
        self.hsv.v = Clamp01(v or 0)
        self.picker:ClearAllPoints()
        self.picker:SetPoint("TOPLEFT", self, "TOPRIGHT", 8, 0)
        self.overlay:Show()
        self.picker:Show()
        self:RefreshPickerVisuals()
    end

    f.ConfirmSelection = function(self)
        if self.pendingColor then
            local committed = CopyColor(self.pendingColor)
            self:SetValue("color", committed)
            AddRecentColor(committed)
        end
        self:ClosePicker(true)
    end

    f.TogglePicker = function(self)
        if self.picker:IsShown() then
            self:ClosePicker()
        else
            self:OpenPicker()
        end
    end

    f.UpdateHueBase = function(self)
        local r, g, b = C_ColorUtil.ConvertHSVToRGB(HueToColorUtilRange(self.hsv.h), 1, 1)
        self.svHue:SetVertexColor(r, g, b, 1)
    end

    f.UpdateAlphaGradient = function(self)
        local c = self:GetWorkingColor()
        ApplyGradient(
            self.alphaGradient,
            "VERTICAL",
            CreateColor(c.r, c.g, c.b, 0),
            CreateColor(c.r, c.g, c.b, 1)
        )
    end

    f.UpdatePickerMarkers = function(self)
        local svWidth, svHeight = self.svFrame:GetWidth(), self.svFrame:GetHeight()
        local svX = self.hsv.s * svWidth
        local svY = (1 - self.hsv.v) * svHeight
        self.svCursor:ClearAllPoints()
        self.svCursor:SetPoint("CENTER", self.svFrame, "TOPLEFT", svX, -svY)

        local hueY = self.hsv.h * self.hueFrame:GetHeight()
        self.hueThumb:ClearAllPoints()
        self.hueThumb:SetPoint("CENTER", self.hueFrame, "TOP", 0, -hueY)

        local activeColor = self:GetWorkingColor()
        local alphaY = (1 - (activeColor.a or 1)) * self.alphaFrame:GetHeight()
        self.alphaThumb:ClearAllPoints()
        self.alphaThumb:SetPoint("CENTER", self.alphaFrame, "TOP", 0, -alphaY)
    end

    f.UpdateHexText = function(self)
        if self.hexUpdating then
            return
        end
        self.hexUpdating = true
        local activeColor = self:GetWorkingColor()
        local hex = self.hasOpacity and ColorToHex(activeColor, true) or ColorToHex(activeColor, false)
        self.hexInput:SetText(hex)
        self.hexUpdating = false
    end

    f.UpdateChannelInputs = function(self)
        if self.numericUpdating then
            return
        end
        self.numericUpdating = true
        local c = self:GetWorkingColor()
        self.channelInputs.r:SetText(string.format("%d", math.floor((c.r or 0) * 255 + 0.5)))
        self.channelInputs.g:SetText(string.format("%d", math.floor((c.g or 0) * 255 + 0.5)))
        self.channelInputs.b:SetText(string.format("%d", math.floor((c.b or 0) * 255 + 0.5)))
        self.channelInputs.a:SetText(string.format("%d", math.floor((c.a or 0) * 100 + 0.5)))
        self.channelInputs.a:GetParent():SetShown(self.hasOpacity)
        self.numericUpdating = false
    end

    f.UpdateRecentSwatches = function(self)
        for i = 1, MAX_RECENT_COLORS do
            local button = self.recentButtons[i]
            local color = sessionRecentColors[i]
            if color then
                button.tex:SetVertexColor(color.r, color.g, color.b, color.a)
                button:Show()
            else
                button:Hide()
            end
        end
    end

    f.RefreshPickerVisuals = function(self)
        if not self.picker:IsShown() then
            return
        end
        local activeColor = self:GetWorkingColor()
        self:UpdateHueBase()
        self:UpdateAlphaGradient()
        self:UpdatePickerMarkers()
        self.currentSwatchTex:SetVertexColor(activeColor.r, activeColor.g, activeColor.b, activeColor.a)
        local previous = self.previousColor or self.color
        self.prevSwatchTex:SetVertexColor(previous.r, previous.g, previous.b, previous.a)
        self.alphaFrame:SetShown(self.hasOpacity)
        self:UpdateHexText()
        self:UpdateChannelInputs()
        self:UpdateRecentSwatches()
    end

    f.SetPendingColor = function(self, color)
        self.pendingColor = CopyColor(color)
        if not self.hasOpacity then
            self.pendingColor.a = 1
        end
        local h, s, v = C_ColorUtil.ConvertRGBToHSV(
            self.pendingColor.r,
            self.pendingColor.g,
            self.pendingColor.b
        )
        local nextS = Clamp01(s or 0)
        local nextV = Clamp01(v or 0)

        -- Keep the previously selected hue when color is grayscale (S ~= 0),
        -- otherwise WoW returns hue=0 and the picker appears to snap to red.
        if nextS <= 0.0001 then
            self.hsv.h = Clamp01(self.hsv.h or 0)
        else
            self.hsv.h = NormalizeHueFromRGB(h)
        end

        self.hsv.s = nextS
        self.hsv.v = nextV
        self:RefreshPickerVisuals()
        self:PreviewPendingColor()
    end

    f.ApplyHSV = function(self, h, s, v)
        self.hsv.h = Clamp01(h)
        self.hsv.s = Clamp01(s)
        self.hsv.v = Clamp01(v)
        local r, g, b = C_ColorUtil.ConvertHSVToRGB(
            HueToColorUtilRange(self.hsv.h),
            self.hsv.s,
            self.hsv.v
        )
        local activeColor = self:GetWorkingColor()
        self:SetPendingColor({
            r = r,
            g = g,
            b = b,
            a = self.hasOpacity and Clamp01(activeColor.a or 1) or 1,
        })
    end

    f.UpdateFromCursor = function(self, targetFrame)
        local scale = targetFrame:GetEffectiveScale()
        local cursorX, cursorY = GetCursorPosition()
        cursorX = cursorX / scale
        cursorY = cursorY / scale
        local localX = cursorX - targetFrame:GetLeft()
        local localY = targetFrame:GetTop() - cursorY
        local width = targetFrame:GetWidth()
        local height = targetFrame:GetHeight()
        localX = math.max(0, math.min(width, localX))
        localY = math.max(0, math.min(height, localY))

        if targetFrame == self.svFrame then
            local sat = width > 0 and localX / width or 0
            local val = height > 0 and 1 - (localY / height) or 0
            self:ApplyHSV(self.hsv.h, sat, val)
            return
        end

        if targetFrame == self.hueFrame then
            local hue = height > 0 and localY / height or 0
            self:ApplyHSV(hue, self.hsv.s, self.hsv.v)
            return
        end

        if targetFrame == self.alphaFrame and self.hasOpacity then
            local alpha = height > 0 and 1 - (localY / height) or 1
            local activeColor = self:GetWorkingColor()
            self:SetPendingColor({
                r = activeColor.r,
                g = activeColor.g,
                b = activeColor.b,
                a = Clamp01(alpha),
            })
        end
    end

    f.SetOptionData = function(self, option)
        self.optionData = option
        self.onChange = option.onChange
        self.hasOpacity = option.hasOpacity ~= false and option.disableAlpha ~= true
        self:SetLabel(option.label)
        self:SetValue("color", option.currentValue and option.currentValue() or { r = 1, g = 1, b = 1, a = 1 })
    end

    f:SetScript('OnClick', function(self)
        self:TogglePicker()
    end)

    overlay:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" and button ~= "RightButton" then
            return
        end
        if f.picker:IsMouseOver() or f:IsMouseOver() then
            return
        end
        f:ClosePicker()
    end)

    picker:SetScript("OnMouseDown", function() end)

    local function StartDrag(target)
        f.dragTarget = target
        f.isDragging = true
        f:UpdateFromCursor(target)
    end

    svFrame:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            StartDrag(svFrame)
        end
    end)
    hueFrame:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            StartDrag(hueFrame)
        end
    end)
    alphaFrame:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and f.hasOpacity then
            StartDrag(alphaFrame)
        end
    end)

    overlay:SetScript("OnUpdate", function()
        if not f.isDragging or not f.dragTarget then
            return
        end
        if not IsMouseButtonDown("LeftButton") then
            f.isDragging = false
            f.dragTarget = nil
            return
        end
        f:UpdateFromCursor(f.dragTarget)
    end)

    prevSwatch:SetScript("OnClick", function()
        if f.previousColor then
            f:SetPendingColor(CopyColor(f.previousColor))
        end
    end)

    copyBtn:SetScript("OnClick", function()
        colorClipboard = ColorToHex(f:GetWorkingColor(), f.hasOpacity)
    end)

    pasteBtn:SetScript("OnClick", function()
        local parsed = ParseHex(colorClipboard)
        if not parsed then
            return
        end
        local color = parsed
        if not f.hasOpacity then
            color.a = 1
        end
        f:SetPendingColor(color)
    end)

    for i = 1, MAX_RECENT_COLORS do
        local button = recentButtons[i]
        button:SetScript("OnClick", function()
            local color = sessionRecentColors[i]
            if color then
                f:SetPendingColor(CopyColor(color))
            end
        end)
    end

    hexInput:SetScript("OnEditFocusLost", function(self)
        if f.hexUpdating then
            return
        end
        local parsed = ParseHex(self:GetText())
        if parsed then
            if not f.hasOpacity then
                parsed.a = 1
            elseif parsed.a == nil then
                parsed.a = (f.pendingColor and f.pendingColor.a) or f.color.a or 1
            end
            f:SetPendingColor(parsed)
        else
            f:UpdateHexText()
        end
    end)
    hexInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    hexInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:UpdateHexText()
    end)

    local function ApplyChannelInput(channelKey)
        if f.numericUpdating then
            return
        end
        local active = CopyColor(f:GetWorkingColor())
        local value = tonumber(f.channelInputs[channelKey]:GetText())
        if not value then
            f:UpdateChannelInputs()
            return
        end

        if channelKey == "a" then
            if not f.hasOpacity then
                active.a = 1
            else
                active.a = Clamp01(value / 100)
            end
        else
            active[channelKey] = Clamp01(value / 255)
        end
        f:SetPendingColor(active)
    end

    for key, input in pairs(channelInputs) do
        input:SetScript("OnEnterPressed", function(self)
            ApplyChannelInput(key)
            self:ClearFocus()
        end)
        input:SetScript("OnEditFocusLost", function()
            ApplyChannelInput(key)
        end)
        input:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            f:UpdateChannelInputs()
        end)
    end

    confirmBtn:SetScript("OnClick", function()
        f:ConfirmSelection()
    end)

    f:Observe('color', function(color, _, _, self)
        local normalized = CopyColor(color)
        if not self.hasOpacity then
            normalized.a = 1
        end
        self.color = normalized
        local h, s, v = C_ColorUtil.ConvertRGBToHSV(
            normalized.r,
            normalized.g,
            normalized.b
        )
        self.hsv.h = NormalizeHueFromRGB(h)
        self.hsv.s = Clamp01(s or 0)
        self.hsv.v = Clamp01(v or 0)

        self.colorBox:SetVertexColor(normalized.r, normalized.g, normalized.b, normalized.a)
        self.currentSwatchTex:SetVertexColor(normalized.r, normalized.g, normalized.b, normalized.a)
        self:RefreshPickerVisuals()
        if (self.onChange) then
            self.onChange(normalized)
        end
    end)

    f.configured = true
end

---Create/Get Color Picker element
---@param self ExalityFramesColorPicker
---@return Frame
colorPicker.Create = function(self)
    local f = self.pool:Acquire()
    if (not f.configured) then
        ConfigureFrame(f)
    end

    f.Destroy = function(self)
        self:ClosePicker()
        self.onChange = nil
        self.previousColor = nil
        self.color = { r = 1, g = 1, b = 1, a = 1 }
        colorPicker.pool:Release(self)
    end

    f:Show()
    return f
end
