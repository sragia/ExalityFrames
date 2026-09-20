local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesSimpleButton
local simpleButton = EXFrames:GetFrame('simple-button')

---@class ExalityFramesDialogFrame
local dialog = EXFrames:GetFrame('dialog-frame')

dialog.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local function ConfigureFrame(f)
    f:SetSize(400, 80)
    f:SetPoint('TOP', 0, -200)
    f:SetFrameStrata('DIALOG')
    f:SetFrameLevel(10)
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

    f.fadeIn = EXFrames.utils.animation.fade(f, 0.2, 0, 1)
    f.fadeOut = EXFrames.utils.animation.fade(f, 0.2, 1, 0)
    f.fadeOut:SetScript('OnFinished', function() f:Hide() end)
    EXFrames.utils.animation.diveIn(f, 0.2, 0, 20, 'IN', f.fadeIn)
    EXFrames.utils.animation.diveIn(f, 0.2, 0, -20, 'OUT', f.fadeOut)

    EXFrames:ApplyPanelChrome(f, {
        fillColor = EXFrames.Theme.backgroundDeep,
        borderColor = EXFrames.Theme.border,
        borderShown = true,
    })

    local text = f:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    text:SetPoint('TOPLEFT', 5, -5)
    text:SetPoint('BOTTOMRIGHT', -5, 40)
    text:SetWidth(0)
    text:SetText('Placeholder')
    f.text = text

    f.ShowDialog = function(self)
        self:Show()
        self.fadeIn:Play()
    end

    f.HideDialog = function(self)
        self.fadeOut:Play()
    end

    f.SetText = function(self, text)
        self.text:SetText(text)
    end

    f.SetButtons = function(self, buttons)
        self.buttonConfigs = buttons
        self:OrganizeButtons()
    end

    f.buttons = { simpleButton:Create(f), simpleButton:Create(f), simpleButton:Create(f) }

    f.OrganizeButtons = function(self)
        local prev = nil
        for _, btn in ipairs(self.buttons) do
            btn:ClearAllPoints()
        end

        for indx, btnConfig in ipairs(self.buttonConfigs) do
            local btn = self.buttons[indx]
            btn:SetOptionData({
                label = btnConfig.text,
                color = btnConfig.color,
                hoverColor = btnConfig.hoverColor,
                hoverBorderColor = btnConfig.hoverBorderColor,
                onClick = btnConfig.onClick,
            })
            if (prev) then
                btn:SetPoint('BOTTOMLEFT', prev, 'BOTTOMRIGHT', 5, 0)
            else
                btn:SetPoint('LEFT', 5, 0)
                btn:SetPoint('BOTTOMRIGHT', self, 'BOTTOM', 0, 5)
            end
            prev = btn
        end
        prev:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -5, 5)
    end

    f.configured = true
end

---Create Dialog Frame
---@param self ExalityFramesDialogFrame
---@return Frame
dialog.Create = function(self)
    local f = self.pool:Acquire()
    if not f.configured then
        ConfigureFrame(f)
    end

    f:Hide()

    return f
end

EXFrames.FrameBase.StandardizeCreate(dialog)
