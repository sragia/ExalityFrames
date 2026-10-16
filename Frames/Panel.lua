local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

--- @class ExalityFramesPanelFrame
local panel = EXFrames:GetFrame('panel-frame')

panel.Init = function(self)
    panel.pool = CreateFramePool('Frame', UIParent)
end

local PANEL_SLICE = 5

local function ApplyPanelTexture(tex, path)
    tex:SetTexture(path)
    tex:SetTextureSliceMargins(PANEL_SLICE, PANEL_SLICE, PANEL_SLICE, PANEL_SLICE)
    tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:Show()
end

local function ApplyPanelArt(frame)
    local textures = EXFrames.assets.textures.panel
    local fill = frame.PanelFill or frame.Texture
    if fill then
        ApplyPanelTexture(fill, textures.background)
    end

    if not frame.PanelBorder then
        local border = frame:CreateTexture(nil, 'BORDER')
        border:SetAllPoints()
        frame.PanelBorder = border
    end
    ApplyPanelTexture(frame.PanelBorder, textures.border)

    if frame.PPBorder then
        frame.PPBorder:Hide()
    end
end

local configure = function(frame)
    EXFrames:ApplyPanelChrome(frame, {
        borderShown = false,
    })
    ApplyPanelArt(frame)

    frame.Destroy = function(self)
        panel.pool:Release(self)
    end

    frame.SetBackgroundColor = function(self, r, g, b, a)
        a = a or 1
        if self.SetPanelFillColor then
            self:SetPanelFillColor(r, g, b, a)
        else
            local tex = self.PanelFill or self.Texture
            if tex then
                tex:SetVertexColor(r, g, b, a)
                tex:SetShown(a > 0)
            end
        end
    end

    frame.SetBorderColor = function(self, r, g, b, a)
        a = a or 1
        if self.PanelBorder then
            self.PanelBorder:SetVertexColor(r, g, b, a)
            self.PanelBorder:SetShown(a > 0)
        end
    end

    frame.SetSubtleChrome = function(self)
        ApplyPanelArt(self)
    end

    frame.configured = true
end

---@param self ExalityFramesPanelFrame
---@return Frame
panel.Create = function(self)
    local f = self.pool:Acquire()
    if not f.configured or not f.SetPanelFillColor then
        configure(f)
    end

    f:Show()
    return f
end

EXFrames.FrameBase.StandardizeCreate(panel)
