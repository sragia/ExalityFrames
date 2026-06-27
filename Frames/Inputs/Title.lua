local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesTitle
local title = EXFrames:GetFrame('title')

title.pool = {}

title.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local function ConfigureFrame(f)
    f:SetSize(100, 34)
    f.SetFrameWidth = function(self, width)
        f:SetWidth(width)
    end
    f.SetOptionData = function(self, option)
        self.optionData = option
        self.titleText:SetText(option.label)
        if (option.size) then
            self.titleText:SetFont(EXFrames.assets.font.default(), option.size, 'OUTLINE')
            self:SetHeight(option.size + 16)
        else
            self:SetHeight(34)
            self.titleText:SetFont(EXFrames.assets.font.default(), 18, 'OUTLINE')
        end

        if (option.background) then
            self.bg:SetVertexColor(unpack(option.background))
        else
            self.bg:SetVertexColor(0.15, 0.15, 0.15, 1)
        end

        if (option.accent) then
            self.bg2:SetVertexColor(unpack(option.accent))
        else
            self.bg2:SetVertexColor(unpack(EXFrames.Theme.accent))
        end
    end

    local titleText = f:CreateFontString(nil, 'OVERLAY')
    titleText:SetFont(EXFrames.assets.font.default(), 18, 'OUTLINE')
    titleText:SetVertexColor(1, 1, 1)
    titleText:SetPoint('LEFT', 5, 0)
    titleText:SetWidth(0)
    f.titleText = titleText

    local bg = f:CreateTexture(nil, 'ARTWORK')
    bg:SetTexture(EXFrames.assets.textures.ui.buttonBg)
    bg:SetVertexColor(unpack(EXFrames.Theme.backgroundPanel))
    bg:SetTextureSliceMargins(6, 6, 6, 6)
    bg:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    bg:SetAllPoints()
    f.bg = bg

    local bg2 = f:CreateTexture(nil, 'BACKGROUND')
    bg2:SetTexture(EXFrames.assets.textures.ui.panelBg)
    bg2:SetTextureSliceMargins(20, 20, 20, 20)
    bg2:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    bg2:SetVertexColor(unpack(EXFrames.Theme.accent))
    bg2:SetPoint('TOPLEFT', bg, 'TOPLEFT', 2, -2)
    bg2:SetPoint('BOTTOMRIGHT', bg, 'BOTTOMRIGHT', 2, -2)
    f.bg2 = bg2

    f.configured = true
end

---Create/Get Title element
---@param self ExalityFramesTitle
---@return Frame
title.Create = function(self)
    local f = self.pool:Acquire()
    if (not f.configured) then
        ConfigureFrame(f)
    end
    f.Destroy = function(self)
        title.pool:Release(self)
    end

    f:Show()
    return f
end
