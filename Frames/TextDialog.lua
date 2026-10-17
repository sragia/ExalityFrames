local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesSimpleButton
local simpleButton = EXFrames:GetFrame('simple-button')

---@class ExalityFramesTextDialog
local textDialog = EXFrames:GetFrame('text-dialog-frame')

local WIDTH = 500
local HEIGHT = 300
local PAD = 16
local BUTTON_H = 28
local BUTTON_GAP = 8
local MAX_BUTTONS = 3
local MAX_LETTERS = 200000
local BUTTON_ATLAS_W, BUTTON_ATLAS_H = 128, 212
local BUTTON_SLICE = 5
local BUTTON_RECTS = {
    bg = { 8, 8, 107, 62 },
    border = { 8, 76, 107, 130 },
    shadow = { 3, 139, 112, 203 },
}

local function ApplyButtonSprite(tex, key)
    local rect = BUTTON_RECTS[key]
    local left, top, right, bottom = rect[1], rect[2], rect[3], rect[4]
    tex:SetTexture(EXFrames.assets.textures.button.sprite)
    tex:SetTexCoord(left / BUTTON_ATLAS_W, (right + 1) / BUTTON_ATLAS_W, top / BUTTON_ATLAS_H, (bottom + 1) / BUTTON_ATLAS_H)
end

local function MeasureTextHeight(dialog, text)
    local probe = dialog.probe
    local editBox = dialog.editBox
    local font, size, flags = editBox:GetFont()
    if probe and font then
        probe:SetFont(font, size, flags)
        probe:SetWordWrap(false)
        probe:SetWidth(0)
        probe:SetText((text and text ~= '') and text or ' ')
        local height = probe:GetStringHeight()
        probe:SetText('')
        if height and height > 1 then
            return height
        end
    end
    local lineHeight = (size or 11) + 4
    local lines = 1
    if text and text ~= '' then
        local _, breaks = text:gsub('\n', '')
        lines = breaks + 1
    end
    return lines * lineHeight
end

local function ConfigureFrame(f)
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint('TOP', UIParent, 'TOP', 0, -140)
    f:SetFrameStrata('FULLSCREEN_DIALOG')
    f:SetFrameLevel(100)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag('LeftButton')
    f:SetScript('OnDragStart', function(self)
        self:StartMoving()
    end)
    f:SetScript('OnDragStop', function(self)
        self:StopMovingOrSizing()
    end)

    f.fadeIn = EXFrames.utils.animation.fade(f, 0.15, 0, 1)
    f.fadeOut = EXFrames.utils.animation.fade(f, 0.12, 1, 0)
    f.fadeIn:SetScript('OnFinished', function()
        f:SetAlpha(1)
    end)
    f.fadeOut:SetScript('OnFinished', function()
        f:SetAlpha(0)
        if f._hideToken ~= f._closeToken then
            return
        end
        f:Hide()
    end)

    EXFrames:ApplyDialogArt(f)

    local title = f:CreateFontString(nil, 'OVERLAY')
    title:SetFont(EXFrames.assets.font.default(), 14, 'OUTLINE')
    title:SetTextColor(unpack(EXFrames.Theme.text))
    title:SetJustifyH('LEFT')
    title:SetPoint('TOPLEFT', PAD, -PAD)
    f.title = title

    local hint = f:CreateFontString(nil, 'OVERLAY')
    hint:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    hint:SetTextColor(unpack(EXFrames.Theme.textMuted))
    hint:SetJustifyH('LEFT')
    hint:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -4)
    f.hint = hint

    local probe = f:CreateFontString(nil, 'OVERLAY')
    probe:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    probe:SetAlpha(0)
    f.probe = probe

    local well = CreateFrame('Frame', nil, f)
    well:SetClipsChildren(true)
    f.well = well

    local shadow = well:CreateTexture(nil, 'BACKGROUND')
    shadow:SetAllPoints()
    shadow:SetVertexColor(1, 1, 1, 1)
    ApplyButtonSprite(shadow, 'shadow')

    local bgTex = well:CreateTexture(nil, 'BACKGROUND')
    bgTex:SetAllPoints()
    ApplyButtonSprite(bgTex, 'bg')
    bgTex:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))

    local wellBorder = well:CreateTexture(nil, 'BORDER')
    wellBorder:SetAllPoints()
    ApplyButtonSprite(wellBorder, 'border')
    wellBorder:SetVertexColor(unpack(EXFrames.Theme.border))

    local buttonSlice = Enum.UITextureSliceMode.Stretched
    EXFrames.utils.texture.bindSliceToRegion(well, {
        { tex = shadow, margins = BUTTON_SLICE, mode = buttonSlice },
        { tex = bgTex, margins = BUTTON_SLICE, mode = buttonSlice },
        { tex = wellBorder, margins = BUTTON_SLICE, mode = buttonSlice },
    })

    local scroll = CreateFrame('ScrollFrame', nil, well)
    scroll:SetPoint('TOPLEFT', 8, -8)
    scroll:SetPoint('BOTTOMRIGHT', -8, 8)
    scroll:SetClipsChildren(true)
    f.scroll = scroll

    local child = CreateFrame('Frame', nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    f.scrollChild = child

    local editBox = CreateFrame('EditBox', nil, child)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(MAX_LETTERS)
    if editBox.SetMaxBytes then
        editBox:SetMaxBytes(MAX_LETTERS)
    end
    editBox:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    editBox:SetTextColor(unpack(EXFrames.Theme.text))
    editBox:SetTextInsets(2, 2, 2, 2)
    editBox:SetPoint('TOPLEFT')
    editBox:SetWidth(100)
    editBox:SetHeight(20)
    f.editBox = editBox

    local function setBorderActive(active)
        wellBorder:SetVertexColor(unpack(active and EXFrames.Theme.accent or EXFrames.Theme.border))
    end

    editBox:SetScript('OnEnter', function()
        setBorderActive(true)
    end)
    editBox:SetScript('OnLeave', function(self)
        if not self:HasFocus() then
            setBorderActive(false)
        end
    end)
    editBox:SetScript('OnEditFocusGained', function()
        setBorderActive(true)
    end)
    editBox:SetScript('OnEditFocusLost', function()
        setBorderActive(false)
    end)
    editBox:SetScript('OnEscapePressed', function(self)
        self:ClearFocus()
        f:Close()
    end)
    editBox:SetScript('OnTextChanged', function()
        f:FitEditor()
    end)

    local function onMouseWheel(_, delta)
        f:ScrollBy(delta)
    end
    editBox:SetScript('OnMouseWheel', onMouseWheel)
    scroll:SetScript('OnMouseWheel', onMouseWheel)
    scroll:SetScript('OnSizeChanged', function()
        f:FitEditor()
    end)

    well:EnableMouse(true)
    well:SetScript('OnMouseDown', function()
        editBox:SetFocus()
    end)
    well:SetScript('OnMouseWheel', onMouseWheel)

    f.buttons = {}
    for _ = 1, MAX_BUTTONS do
        local button = simpleButton:Create(f)
        button:SetHeight(BUTTON_H)
        button:SetFrameLevel(f:GetFrameLevel() + 10)
        button:Hide()
        f.buttons[#f.buttons + 1] = button
    end

    function f:FitEditor()
        if self.fitting then
            return
        end
        local editorScroll = self.scroll
        local editor = self.editBox
        local editorChild = self.scrollChild
        if not editorScroll or not editor or not editorChild or editorScroll:GetWidth() < 2 then
            return
        end
        self.fitting = true
        local width = math.max(1, editorScroll:GetWidth() - 4)
        editor:SetWidth(width)
        local textHeight = MeasureTextHeight(self, editor:GetText())
        local height = math.max(editorScroll:GetHeight(), textHeight + 8)
        editor:SetHeight(height)
        editorChild:SetWidth(editorScroll:GetWidth())
        editorChild:SetHeight(height)
        local maxScroll = math.max(0, height - editorScroll:GetHeight())
        if editorScroll:GetVerticalScroll() > maxScroll then
            editorScroll:SetVerticalScroll(maxScroll)
        end
        self.fitting = false
    end

    function f:ScrollBy(delta)
        local editorScroll = self.scroll
        local editorChild = self.scrollChild
        if not editorScroll or not editorChild then
            return
        end
        local maxScroll = math.max(0, editorChild:GetHeight() - editorScroll:GetHeight())
        local nextScroll = editorScroll:GetVerticalScroll() - delta * 28
        if nextScroll < 0 then
            nextScroll = 0
        elseif nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        editorScroll:SetVerticalScroll(nextScroll)
    end

    function f:LayoutButtons()
        local configs = self._buttons or {}
        local count = #configs
        if count > MAX_BUTTONS then
            count = MAX_BUTTONS
        end
        self._buttonCount = count
        local inner = self:GetWidth() - PAD * 2
        for index, button in ipairs(self.buttons) do
            button:ClearAllPoints()
            local config = index <= count and configs[index] or nil
            if not config then
                button:Hide()
            else
                local width
                local x
                if count == 1 then
                    width = math.min(160, inner)
                    x = self:GetWidth() - PAD - width
                else
                    width = (inner - BUTTON_GAP * (count - 1)) / count
                    x = PAD + (index - 1) * (width + BUTTON_GAP)
                end
                button:SetSize(width, BUTTON_H)
                button:SetPoint('BOTTOMLEFT', x, PAD)
                button:SetOptionData({
                    label = config.text,
                    onClick = config.onClick,
                })
                button:SetFrameLevel(self:GetFrameLevel() + 10)
                button:Show()
            end
        end
    end

    function f:Layout()
        if self.layouting then
            return
        end
        self.layouting = true
        local width = self:GetWidth()
        self.title:SetWidth(width - PAD * 2)
        self.hint:SetWidth(width - PAD * 2)
        local hintText = self.hint:GetText()
        local hintShown = hintText and hintText ~= ''
        self.hint:SetShown(hintShown)
        local hintHeight = hintShown and self.hint:GetStringHeight() or 0
        local titleHeight = self.title:GetStringHeight()
        if not titleHeight or titleHeight < 1 then
            titleHeight = 16
        end
        local top = PAD + titleHeight + (hintShown and (6 + hintHeight) or 0) + 12
        self:LayoutButtons()
        local buttonCount = self._buttonCount or 0
        local bottom = PAD
        if buttonCount > 0 then
            bottom = PAD + BUTTON_H + 10
        end
        self.well:ClearAllPoints()
        self.well:SetPoint('TOPLEFT', PAD, -top)
        self.well:SetPoint('BOTTOMRIGHT', -PAD, bottom)
        self.well:SetFrameLevel(self:GetFrameLevel() + 2)
        self:FitEditor()
        self.layouting = false
    end

    function f:SetText(text)
        self.editBox:SetText(text or '')
        self:FitEditor()
    end

    function f:GetText()
        return self.editBox:GetText() or ''
    end

    function f:GetEditorWidth()
        return self.editBox:GetWidth() or 0
    end

    function f:SetHint(text, color)
        self.hint:SetText(text or '')
        self.hint:SetTextColor(unpack(color or EXFrames.Theme.textMuted))
        self:Layout()
    end

    function f:WrapText(text)
        if not text or text == '' then
            return ''
        end
        local width = self:GetEditorWidth()
        local columns = 64
        if width > 40 and self.probe and self.editBox then
            local probe = self.probe
            probe:SetFont(self.editBox:GetFont())
            probe:SetWordWrap(false)
            probe:SetText('0')
            local charWidth = probe:GetStringWidth()
            if charWidth and charWidth > 1 then
                columns = math.floor((width - 4) / charWidth)
            end
        end
        if columns < 16 then
            columns = 64
        end
        if #text <= columns then
            return text
        end
        local lines = {}
        for index = 1, #text, columns do
            lines[#lines + 1] = text:sub(index, index + columns - 1)
        end
        return table.concat(lines, '\n')
    end

    function f:FocusEditor(highlight, onReady)
        self._focusToken = (self._focusToken or 0) + 1
        local token = self._focusToken
        C_Timer.After(0, function()
            if self._focusToken ~= token or not self:IsShown() then
                return
            end
            if onReady then
                onReady()
            end
            self.editBox:SetFocus()
            if highlight then
                self.editBox:HighlightText()
            else
                self.editBox:SetCursorPosition(0)
            end
        end)
    end

    function f:Open(options)
        options = options or {}
        self._closeToken = (self._closeToken or 0) + 1
        if self.fadeOut:IsPlaying() then
            self.fadeOut:Stop()
        end
        if self.fadeIn:IsPlaying() then
            self.fadeIn:Stop()
        end
        self.title:SetText(options.title or '')
        self._buttons = options.buttons or {}
        self:SetHint(options.hint, options.hintColor)
        self:SetText(options.text or '')
        self.scroll:SetVerticalScroll(0)
        self:SetAlpha(0)
        self:Show()
        self.fadeIn:Play()
        self:FocusEditor(options.highlight, options.onReady)
    end

    function f:Close()
        self._focusToken = (self._focusToken or 0) + 1
        if self.editBox then
            self.editBox:ClearFocus()
        end
        if not self:IsShown() then
            return
        end
        if self.fadeIn:IsPlaying() then
            self.fadeIn:Stop()
        end
        self._hideToken = self._closeToken
        self:SetAlpha(1)
        self.fadeOut:Play()
    end

    f:SetScript('OnSizeChanged', function(self)
        if self.configured then
            self:Layout()
        end
    end)

    f:Layout()
    f.configured = true
end

textDialog.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

---@param self ExalityFramesTextDialog
---@return Frame
textDialog.Create = function(self)
    local frame = self.pool:Acquire()
    if not frame.configured then
        ConfigureFrame(frame)
    end
    frame:Hide()
    return frame
end

EXFrames.FrameBase.StandardizeCreate(textDialog)
