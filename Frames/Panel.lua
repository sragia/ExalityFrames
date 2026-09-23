local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

--- @class ExalityFramesPanelFrame
local panel = EXFrames:GetFrame('panel-frame')

panel.Init = function(self)
    panel.pool = CreateFramePool('Frame', UIParent)
end

local configure = function(frame)
    EXFrames:ApplyPanelChrome(frame, {
        fillColor = EXFrames.Theme.background,
        borderColor = EXFrames.Theme.border,
        borderShown = true,
    })

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
        if self.PPBorder then
            if a > 0 then
                self.PPBorder:Show()
            else
                self.PPBorder:Hide()
            end
        end
    end

    frame.SetBorderColor = function(self, r, g, b, a)
        self:SetPanelBorderColor(r, g, b, a)
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
    if not f.configured or not f.SetPanelFillColor then
        configure(f)
    end

    f:Show()
    return f
end

EXFrames.FrameBase.StandardizeCreate(panel)
