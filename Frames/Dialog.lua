local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesSimpleButton
local simpleButton = EXFrames:GetFrame('simple-button')

---@class ExalityFramesDialogFrame
local dialog = EXFrames:GetFrame('dialog-frame')

local PAD = 16
local GAP = 12
local BUTTON_H = 28
local BUTTON_GAP = 8
local CLOSE_SIZE = 22
local MAX_BUTTONS = 3
local DEFAULT_WIDTH = 420

dialog.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local function ConfigureFrame(f)
    f:SetSize(DEFAULT_WIDTH, 120)
    f:SetPoint('TOP', UIParent, 'TOP', 0, -160)
    f:SetFrameStrata('DIALOG')
    f:SetFrameLevel(20)
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
    title:SetWordWrap(false)
    f.title = title

    local close = CreateFrame('Button', nil, f)
    close:SetSize(CLOSE_SIZE, CLOSE_SIZE)
    local closeIcon = close:CreateTexture(nil, 'ARTWORK')
    closeIcon:SetTexture(EXFrames.assets.textures.icon.close)
    closeIcon:SetSize(12, 12)
    closeIcon:SetPoint('CENTER')
    closeIcon:SetVertexColor(unpack(EXFrames.Theme.textMuted))
    close:SetScript('OnEnter', function()
        closeIcon:SetVertexColor(unpack(EXFrames.Theme.dangerHover))
    end)
    close:SetScript('OnLeave', function()
        closeIcon:SetVertexColor(unpack(EXFrames.Theme.textMuted))
    end)
    close:SetScript('OnClick', function()
        if f.closeClick then
            f.closeClick()
        end
    end)
    close:Hide()
    f.close = close

    local text = f:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 12, 'OUTLINE')
    text:SetTextColor(unpack(EXFrames.Theme.text))
    text:SetJustifyH('LEFT')
    text:SetJustifyV('TOP')
    text:SetWordWrap(true)
    f.text = text

    local content = CreateFrame('Frame', nil, f)
    content:SetHeight(0.01)
    content:Hide()
    f.content = content
    f.contentHeight = 0
    f.titleText = ''
    f.bodyText = ''
    f.buttonConfigs = {}

    f.buttons = {}
    for _ = 1, MAX_BUTTONS do
        local button = simpleButton:Create(f)
        button:SetHeight(BUTTON_H)
        button:SetFrameLevel(f:GetFrameLevel() + 10)
        button:Hide()
        f.buttons[#f.buttons + 1] = button
    end

    function f:GetContentWidth()
        return math.max(1, self:GetWidth() - PAD * 2)
    end

    function f:Layout()
        if self.layouting then
            return
        end
        self.layouting = true

        local width = self:GetWidth()
        if width < 2 then
            width = DEFAULT_WIDTH
        end
        local closeShown = self.close:IsShown()
        self.close:ClearAllPoints()
        self.close:SetPoint('TOPRIGHT', -PAD, -PAD)

        local y = PAD
        local hasTitle = self.titleText and self.titleText ~= ''
        self.title:SetShown(hasTitle)
        if hasTitle then
            local titleWidth = width - PAD * 2
            if closeShown then
                titleWidth = titleWidth - CLOSE_SIZE - 8
            end
            self.title:ClearAllPoints()
            self.title:SetWidth(math.max(1, titleWidth))
            self.title:SetText(self.titleText)
            self.title:SetPoint('TOPLEFT', PAD, -y)
            local titleHeight = self.title:GetStringHeight()
            if not titleHeight or titleHeight < 1 then
                titleHeight = 16
            end
            y = y + titleHeight
        end

        local hasBody = self.bodyText and self.bodyText ~= ''
        self.text:SetShown(hasBody)
        if hasBody then
            if y > PAD then
                y = y + GAP
            end
            self.text:ClearAllPoints()
            self.text:SetWidth(self:GetContentWidth())
            self.text:SetText(self.bodyText)
            self.text:SetPoint('TOPLEFT', PAD, -y)
            local bodyHeight = self.text:GetStringHeight()
            if not bodyHeight or bodyHeight < 1 then
                bodyHeight = 16
            end
            y = y + bodyHeight
        end

        local contentHeight = self.contentHeight or 0
        self.content:ClearAllPoints()
        if contentHeight > 0 then
            if y > PAD then
                y = y + GAP
            end
            self.content:SetPoint('TOPLEFT', PAD, -y)
            self.content:SetPoint('TOPRIGHT', -PAD, -y)
            self.content:SetHeight(contentHeight)
            self.content:Show()
            y = y + contentHeight
        else
            self.content:Hide()
        end

        local configs = self.buttonConfigs or {}
        local count = #configs
        if count > MAX_BUTTONS then
            count = MAX_BUTTONS
        end
        if count > 0 then
            if y > PAD then
                y = y + GAP
            end
            local inner = width - PAD * 2
            local buttonWidth = (inner - BUTTON_GAP * (count - 1)) / count
            for index, button in ipairs(self.buttons) do
                button:ClearAllPoints()
                local config = index <= count and configs[index] or nil
                if not config then
                    button:Hide()
                else
                    button:SetSize(buttonWidth, BUTTON_H)
                    button:SetPoint('TOPLEFT', PAD + (index - 1) * (buttonWidth + BUTTON_GAP), -y)
                    button:SetOptionData({
                        label = config.text,
                        color = config.color,
                        borderColor = config.borderColor,
                        hoverColor = config.hoverColor,
                        hoverBorderColor = config.hoverBorderColor,
                        onClick = config.onClick,
                    })
                    button:SetFrameLevel(self:GetFrameLevel() + 10)
                    button:Show()
                end
            end
            y = y + BUTTON_H
        else
            for _, button in ipairs(self.buttons) do
                button:Hide()
            end
        end

        self:SetHeight(y + PAD)
        self.layouting = false
    end

    function f:SetTitle(text)
        self.titleText = text or ''
        self:Layout()
    end

    function f:SetText(text)
        self.bodyText = text or ''
        self:Layout()
    end

    function f:SetButtons(buttons)
        self.buttonConfigs = buttons or {}
        self:Layout()
    end

    function f:SetContentHeight(height)
        self.contentHeight = height or 0
        self:Layout()
    end

    function f:ShowClose(onClick)
        self.closeClick = onClick
        self.close:Show()
        self:Layout()
    end

    function f:ShowDialog()
        self._closeToken = (self._closeToken or 0) + 1
        if self.fadeOut:IsPlaying() then
            self.fadeOut:Stop()
        end
        self:Layout()
        self:SetAlpha(0)
        self:Show()
        self.fadeIn:Play()
    end

    function f:HideDialog()
        if not self:IsShown() then
            return
        end
        if self.fadeOut:IsPlaying() then
            return
        end
        if self.fadeIn:IsPlaying() then
            self.fadeIn:Stop()
        end
        self._hideToken = self._closeToken
        self:SetAlpha(1)
        self.fadeOut:Play()
    end

    f:Layout()
    f.configured = true
end

---Create Dialog Frame
---@param self ExalityFramesDialogFrame
---@return Frame
dialog.Create = function(self)
    local frame = self.pool:Acquire()
    if not frame.configured then
        ConfigureFrame(frame)
    end
    frame:Hide()
    return frame
end

EXFrames.FrameBase.StandardizeCreate(dialog)
