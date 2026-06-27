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

    frame.Destroy = function(self)
        panel.pool:Release(self)
    end

    frame.SetBackgroundColor = function(self, r, g, b, a)
        self.Texture:SetVertexColor(r, g, b, a)
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
