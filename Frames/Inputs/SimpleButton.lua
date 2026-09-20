local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesSimpleButton
local simpleButton = EXFrames:GetFrame('simple-button')

simpleButton.pool = {}

simpleButton.Init = function(self)
    self.pool = CreateFramePool('Button', UIParent)
end

local CONTENT_PAD = 8
local ICON_TEXT_GAP = 6

local function ApplyContentLayout(f)
    local hasIcon = f.icon:IsShown() and f.icon:GetWidth() > 0
    local label = f.text:GetText()
    local hasText = label and label ~= ''

    f.text:ClearAllPoints()
    f.icon:ClearAllPoints()

    if hasIcon and hasText then
        f.icon:SetPoint('LEFT', CONTENT_PAD, 0)
        f.text:SetPoint('LEFT', f.icon, 'RIGHT', ICON_TEXT_GAP, 0)
        f.text:SetJustifyH('LEFT')
    elseif hasIcon then
        f.icon:SetPoint('CENTER')
    else
        f.text:SetPoint('CENTER')
        f.text:SetJustifyH('CENTER')
    end
end

local function ApplyNormalColors(f)
    f.bg:SetVertexColor(unpack(f.normalBg))
    if f.PPBorder then
        f.PPBorder:SetBorderColor(unpack(f.normalBorder))
    end
end

local function ApplyHoverColors(f)
    f.bg:SetVertexColor(unpack(f.hoverBg))
    if f.PPBorder then
        f.PPBorder:SetBorderColor(unpack(f.hoverBorder))
    end
end

local function ResolveColors(f, option)
    local th = EXFrames.Theme
    option = option or {}

    f.normalBg = option.color or th.backgroundDeep
    f.normalBorder = option.borderColor or th.border
    f.hoverBg = option.hoverBg or option.hoverColor or th.backgroundLight
    f.hoverBorder = option.hoverBorderColor or th.accent
end

local function ConfigureFrame(f)
    EXFrames.utils.addObserver(f)

    local bg = f:CreateTexture(nil, 'BACKGROUND')
    bg:SetTexture(EXFrames.assets.textures.solidWhite)
    bg:SetAllPoints()
    f.bg = bg

    EXFrames:ApplyInputBorder(f, 1)

    f:HookScript('OnSizeChanged', function()
        if f.PPBorder then
            f.PPBorder:SetBorderThickness(f.PPBorder.thicknessPixels or 1)
        end
    end)

    local text = f:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    text:SetTextColor(unpack(EXFrames.Theme.text))
    text:SetWidth(0)
    f.text = text

    local icon = f:CreateTexture(nil, 'OVERLAY')
    icon:SetSize(16, 16)
    icon:Hide()
    f.icon = icon

    f.normalBg = EXFrames.Theme.backgroundDeep
    f.normalBorder = EXFrames.Theme.border
    f.hoverBg = EXFrames.Theme.backgroundLight
    f.hoverBorder = EXFrames.Theme.accent

    f:SetScript('OnEnter', function(self)
        ApplyHoverColors(self)
    end)

    f:SetScript('OnLeave', function(self)
        ApplyNormalColors(self)
    end)

    f:SetScript('OnClick', function(self)
        if self.onClick then
            self:onClick(self)
        end
    end)

    f.SetText = function(self, label)
        self.text:SetText(label or '')
        ApplyContentLayout(self)
    end

    f.SetOnClick = function(self, onClick)
        self.onClick = onClick
    end

    f.SetIcon = function(self, texture, width, height)
        if texture then
            self.icon:SetTexture(texture)
            self.icon:SetSize(width or 14, height or 14)
            self.icon:Show()
        else
            self.icon:SetTexture(nil)
            self.icon:SetSize(0, 0)
            self.icon:Hide()
        end
        ApplyContentLayout(self)
    end

    f.SetOptionData = function(self, option)
        self.optionData = option
        ResolveColors(self, option)
        ApplyNormalColors(self)

        self:SetText(option.label or option.buttonText or option.text or '')
        self.onClick = option.onClick

        if option.icon then
            local path = option.icon.file or option.icon.texture
            self:SetIcon(path, option.icon.width or 14, option.icon.height or 14)
        else
            self:SetIcon(nil)
        end

        self:ApplyLayoutWidth(self:GetWidth())

        ApplyContentLayout(self)
    end

    f.ApplyLayoutWidth = function(self, width)
        local option = self.optionData
        if option and option.squareSize then
            self:SetSize(option.squareSize, option.squareSize)
            return
        end
        self:SetWidth(width)
        if option and option.square then
            self:SetHeight(width)
        end
    end

    f.SetFrameWidth = function(self, width)
        self:ApplyLayoutWidth(width)
    end

    f.configured = true
end

---@param self ExalityFramesSimpleButton
---@param parent? Frame
---@return Frame
simpleButton.Create = function(self, parent)
    local f = self.pool:Acquire()
    if not f.configured then
        ConfigureFrame(f)
    end

    if parent then
        f:SetParent(parent)
    else
        f:SetParent(nil)
    end

    f.optionData = nil
    f.onClick = nil
    f:SetSize(95, 29)
    f:SetText('')
    f:SetIcon(nil)
    ResolveColors(f, nil)
    ApplyNormalColors(f)

    f.Destroy = function(self)
        self:ClearObservable()
        self.onClick = nil
        self.optionData = nil
        self:SetText('')
        self:SetIcon(nil)
        ResolveColors(self, nil)
        ApplyNormalColors(self)
        simpleButton.pool:Release(self)
    end

    f:Show()
    return f
end

EXFrames.FrameBase.StandardizeCreate(simpleButton, 'parent-only')
