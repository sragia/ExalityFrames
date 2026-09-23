local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesTooltipOptions : {text: string}

---@class ExalityFramesTooltipInput
local tooltip = EXFrames:GetFrame('tooltip')
tooltip.pool = {}

tooltip.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local TOOLTIP_FRAME_LEVEL = 1000

local function PositionTooltip(tooltip, anchor)
    if not anchor or not anchor.IsShown then
        return
    end
    tooltip:SetParent(UIParent)
    tooltip:SetFrameStrata('TOOLTIP')
    tooltip:SetFrameLevel(TOOLTIP_FRAME_LEVEL)
    tooltip:ClearAllPoints()
    tooltip:SetPoint('BOTTOM', anchor, 'TOP', 0, 15)
end

---@param f Frame
local function ConfigureFrame(f)
    EXFrames.utils.addObserver(f)
    f:SetSize(1, 1)
    f:SetFrameStrata('TOOLTIP')
    local text = f:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
    text:SetVertexColor(1, 1, 1, 1)
    text:SetPoint('CENTER')
    text:SetWidth(0)
    f.text = text

    f.SetText = function(self, value)
        text:SetText(value)
    end

    f.SetFontSize = function(self, size)
        text:SetFont(EXFrames.assets.font.default(), size or 10, 'OUTLINE')
    end

    local bg = f:CreateTexture()
    bg:SetTexture(EXFrames.assets.textures.window.bg)
    bg:SetTexCoord(7 / 512, 505 / 512, 7 / 512, 505 / 512)
    bg:SetTextureSliceMargins(15, 15, 15, 15)
    bg:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    bg:SetPoint('TOPLEFT', text, -5, 10)
    bg:SetPoint('BOTTOMRIGHT', text, 5, -10)
    bg:SetVertexColor(0, 0, 0, 0.8)

    local showAG = EXFrames.utils.animation.getAnimationGroup(f)
    EXFrames.utils.animation.diveIn(f, 0.2, 0, 10, 'IN', showAG)
    EXFrames.utils.animation.fade(f, 0.2, 0.2, 1, showAG)
    local hideAG = EXFrames.utils.animation.getAnimationGroup(f)
    EXFrames.utils.animation.diveIn(f, 0.2, 0, -10, 'OUT', hideAG)
    EXFrames.utils.animation.fade(f, 0.2, 1, 0, hideAG)
    hideAG:SetScript('OnFinished', function() f:Hide() end)

    f.ShowTooltip = function(self)
        if self.anchor then
            PositionTooltip(self, self.anchor)
        end
        self:Show()
        showAG:Play()
    end

    f.HideTooltip = function(self)
        hideAG:Play()
    end

    f:Hide()
    f.isConfigured = true
end

---@param self ExalityFramesTooltipInput
---@param options ExalityFramesTooltipOptions
---@param parent FRAME
---@return FRAME
tooltip.Get = function(self, options, parent)
    ---@type Frame
    local tooltip = self.pool:Acquire()
    if (not tooltip.isConfigured) then
        ConfigureFrame(tooltip)
    end

    tooltip.anchor = parent
    if parent then
        PositionTooltip(tooltip, parent)
    end

    tooltip:SetText(options.text)

    tooltip.Destroy = function(self)
        self.anchor = nil
        tooltip.pool:Release(self)
    end

    return tooltip
end

tooltip.Create = tooltip.Get
EXFrames.FrameBase.StandardizeCreate(tooltip, 'no-parent')
