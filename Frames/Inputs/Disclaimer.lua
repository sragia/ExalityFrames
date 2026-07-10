local _, ns = ...

---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesDisclaimer
local disclaimer = EXFrames:GetFrame('disclaimer')

disclaimer.pool = {}

local ICON_SIZE = 16
local HORIZONTAL_PADDING = 10
local VERTICAL_PADDING = 8
local ICON_TEXT_GAP = 8
local MIN_HEIGHT = 32

local function unpackColor(color, fallback)
    if color then
        return color[1], color[2], color[3], color[4] or 1
    end
    if fallback then
        return fallback[1], fallback[2], fallback[3], fallback[4] or 1
    end
    return 1, 1, 1, 1
end

local function applySliceTexture(tex, texturePath, r, g, b, a)
    tex:SetTexture(texturePath)
    tex:SetVertexColor(r, g, b, a)
    if tex.SetTextureSliceMargins then
        tex:SetTextureSliceMargins(8, 8, 8, 8)
        tex:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    end
    tex:SetAllPoints()
end

disclaimer.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local function ConfigureFrame(f)
    f:SetHeight(MIN_HEIGHT)

    local bg = f:CreateTexture(nil, 'BACKGROUND')
    f.bg = bg

    local border = f:CreateTexture(nil, 'OVERLAY', nil, 1)
    f.border = border

    local icon = f:CreateTexture(nil, 'ARTWORK')
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint('TOPLEFT', HORIZONTAL_PADDING, -VERTICAL_PADDING)
    icon:SetTexture(EXFrames.assets.textures.icon.info)
    f.icon = icon

    local text = f:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
    text:SetPoint('TOPLEFT', icon, 'TOPRIGHT', ICON_TEXT_GAP, 0)
    text:SetPoint('TOPRIGHT', f, 'TOPRIGHT', -HORIZONTAL_PADDING, -VERTICAL_PADDING)
    text:SetJustifyH('LEFT')
    text:SetJustifyV('TOP')
    text:SetWordWrap(true)
    f.text = text

    f.ApplyColors = function(self, option)
        option = option or self.optionData or {}
        local theme = EXFrames.Theme

        applySliceTexture(
            self.bg,
            EXFrames.assets.textures.ui.panelBg,
            unpackColor(option.backgroundColor, theme.backgroundLight)
        )
        applySliceTexture(
            self.border,
            EXFrames.assets.textures.ui.panelBorder,
            unpackColor(option.borderColor, theme.border)
        )

        local textR, textG, textB, textA = unpackColor(option.textColor, theme.textMuted)
        self.text:SetTextColor(textR, textG, textB, textA)

        local iconR, iconG, iconB, iconA = unpackColor(option.iconColor, theme.inProgress)
        self.icon:SetVertexColor(iconR, iconG, iconB, iconA)
    end

    f.UpdateLayout = function(self, width)
        width = width or self:GetWidth()
        if width <= 0 then
            width = 200
        end
        self:SetWidth(width)

        local textWidth = width - HORIZONTAL_PADDING - ICON_SIZE - ICON_TEXT_GAP - HORIZONTAL_PADDING
        if textWidth < 1 then
            textWidth = 1
        end
        self.text:SetWidth(textWidth)

        local textHeight = self.text:GetStringHeight()
        local contentHeight = math.max(ICON_SIZE, textHeight)
        local height = math.max(MIN_HEIGHT, contentHeight + (VERTICAL_PADDING * 2))
        self:SetHeight(height)
    end

    f.SetFrameWidth = function(self, width)
        self:UpdateLayout(width)
    end

    f.SetOptionData = function(self, option)
        self.optionData = option
        self.text:SetText(option.label or option.text or '')
        self:ApplyColors(option)
        self:UpdateLayout(self:GetWidth())
    end

    f.SetText = function(self, value)
        self.text:SetText(value or '')
        self:UpdateLayout(self:GetWidth())
    end

    f.configured = true
end

disclaimer.Create = function(self)
    local f = self.pool:Acquire()
    if not f.configured then
        ConfigureFrame(f)
    end

    f.Destroy = function(self)
        disclaimer.pool:Release(self)
    end

    f:Show()
    return f
end
