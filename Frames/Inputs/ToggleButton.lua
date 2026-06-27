local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesToggleButtonOptions : {text: string, onClick: function, size?: table<number>, color?: table<number>}

---@class ExalityFramesToggleButton
local button = EXFrames:GetFrame('toggle-button')

button.pool = {}

button.Init = function(self)
    self.pool = CreateFramePool('Button', UIParent)
end

local function ConfigureFrame(f)
    EXFrames.utils.addObserver(f)

    f.selected = false

    local text = f:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    text:SetPoint('CENTER')
    text:SetWidth(0)
    f.text = text

    local bg = f:CreateTexture(nil, 'BACKGROUND')
    bg:SetTexture(EXFrames.assets.textures.ui.buttonBg)
    bg:SetVertexColor(unpack(EXFrames.Theme.accent))
    bg:SetTextureSliceMargins(6, 6, 6, 6)
    bg:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    bg:SetAllPoints()
    f.bg = bg

    f.SetColor = function(self, r, g, b, a)
        self.bg:SetVertexColor(r, g, b, a)
    end

    local hoverTex = f:CreateTexture(nil, 'BORDER')
    hoverTex:SetTexture(EXFrames.assets.textures.ui.buttonBg)
    hoverTex:SetVertexColor(unpack(EXFrames.Theme.accentLight))
    hoverTex:SetTextureSliceMargins(6, 6, 6, 6)
    hoverTex:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    hoverTex:SetAllPoints()
    hoverTex:SetAlpha(0)

    local onHover = EXFrames.utils.animation.fade(hoverTex, 0.1, 0, 1)
    local onLeave = EXFrames.utils.animation.fade(hoverTex, 0.1, 1, 0)

    f:SetScript('OnEnter', function(self)
        if (not self.selected) then
            onHover:Play()
        end
    end)

    f:SetScript('OnLeave', function(self)
        if (not self.selected) then
            onLeave:Play()
        end
    end)

    f.SetText = function(self, text)
        self.text:SetText(text)
    end

    f:SetScript('OnClick', function(self)
        if (self.onClick) then
            self:onClick()
            hoverTex:SetAlpha(1)
            self.selected = true
        end
    end)

    f.Deactivate = function(self)
        hoverTex:SetAlpha(0)
        self.selected = false
    end

    f.configured = true
end

---Create/Get Button element
---@param self ExalityFramesToggleButton
---@param options ExalityFramesToggleButtonOptions
---@param parent Frame
---@return Frame
button.Create = function(self, options, parent)
    local f = self.pool:Acquire()
    if (not f.configured) then
        ConfigureFrame(f)
    end

    if (parent) then
        f:SetParent(parent)
    else
        f:SetParent(nil)
    end

    if (options.size) then
        f:SetSize(unpack(options.size))
    else
        f:SetSize(95, 29)
    end

    if (options.text) then
        f:SetText(options.text)
    end

    if (options.color) then
        f:SetColor(unpack(options.color))
    else
        f:SetColor(unpack(EXFrames.Theme.accent))
    end

    if (options.onClick) then
        f.onClick = options.onClick
    end

    f.Destroy = function(self)
        self:ClearObservable()
        self:Deactivate()
        button.pool:Release(self)
    end

    f:Show()
    return f
end
