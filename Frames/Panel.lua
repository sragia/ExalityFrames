local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

--- @class ExalityFramesPanelFrame
local panel = EXFrames:GetFrame('panel-frame')

panel.Init = function(self)
    panel.pool = CreateFramePool('Frame', UIParent)
end

local configure = function(frame)
    local bg = frame:CreateTexture(nil, 'BACKGROUND')
    frame.Texture = bg
    bg:SetTexture(EXFrames.assets.textures.ui.panelBg)
    bg:SetVertexColor(unpack(EXFrames.Theme.background))
    bg:SetTextureSliceMargins(8, 8, 8, 8)
    bg:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    bg:SetAllPoints()

    local border = frame:CreateTexture(nil, 'OVERLAY', nil, 1)
    border:SetTexture(EXFrames.assets.textures.ui.panelBorder)
    border:SetVertexColor(unpack(EXFrames.Theme.border))
    border:SetTextureSliceMargins(8, 8, 8, 8)
    border:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    border:SetAllPoints()
    frame.Border = border

    frame.Destroy = function(self)
        panel.pool:Release(self)
    end

    frame.SetBackgroundColor = function(self, r, g, b, a)
        a = a or 1
        self.Texture:SetVertexColor(r, g, b, a)
        self.Texture:SetShown(a > 0)
        if self.Border then
            self.Border:SetShown(a > 0)
        end
    end

    frame.SetBorderColor = function(self, r, g, b, a)
        if not self.Border then
            return
        end
        a = a or 1
        self.Border:SetVertexColor(r, g, b, a)
        self.Border:SetShown(a > 0)
    end

    frame.SetSubtleChrome = function(self)
        local fill = EXFrames.Theme.backgroundDeep
        self:SetBackgroundColor(fill[1], fill[2], fill[3], 0.16)
        self:SetBorderColor(0, 0, 0, 0.34)
    end

    frame.configured = true
end

---@param self ExalityFramesPanelFrame
---@return Frame
panel.Create = function(self)
    local f = self.pool:Acquire()
    if not f.configured then
        configure(f)
    end

    f:Show()
    return f
end

EXFrames.FrameBase.StandardizeCreate(panel)
