local addonName, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class WindowOptions : {size?: table<number>, title?: string, hideVersion?: boolean}

--- @class ExalityFramesWindowFrame
local window = EXFrames:GetFrame('window-frame')

---@class ExalityFramesWindowManager
local windowManager = EXFrames:GetFrame('window-manager')

local addonVersion = C_AddOns.GetAddOnMetadata(addonName, "version")
--@debug@
if addonVersion == '@project-version@' then
    addonVersion = '1.0.0-dev'
end
--@end-debug@

window.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local DEFAULT_CHROME = {
    backgroundTexture = [[Interface/Addons/ExalityUI/Options/Assets/main-bg_2.png]],
    headerTexture = [[Interface/Addons/ExalityUI/Options/Assets/top-bar.png]],
    closeIcon = [[Interface/Addons/ExalityUI/Options/Assets/icon-close.png]],
}

local configure = function(frame)
    frame:SetSize(500, 500)
    frame.windowId = EXFrames.utils.generateRandomString(10)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(true)
    frame:SetScript("OnDragStart", function(self)
        windowManager:RaiseWindow(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self._userPlaced = true
        if EXFrames.RefreshPixelPerfect then
            EXFrames:RefreshPixelPerfect()
        end
    end)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(windowManager.baseFrameLevel)
    frame:SetResizable(true)

    frame:HookScript('OnShow', function(self)
        windowManager:RaiseWindow(self)
    end)

    frame.fadeIn = EXFrames.utils.animation.fade(frame, 0.2, 0, 1)
    frame.fadeOut = EXFrames.utils.animation.fade(frame, 0.2, 1, 0)
    frame.fadeOut:SetScript('OnFinished', function() frame:Hide() end)
    EXFrames.utils.animation.diveIn(frame, 0.2, 0, 20, 'IN', frame.fadeIn)
    EXFrames.utils.animation.diveIn(frame, 0.2, 0, -20, 'OUT', frame.fadeOut)

    frame.ShowWindow = function(self, hideAfter)
        self:Show()
        if (self.StaticAnchor) then
            self:ClearAllPoints()
            self:SetPoint(unpack(self.StaticAnchor))
        elseif not self._userPlaced then
            windowManager:SetValidCenterPosition(self)
        end
        self.fadeIn:Play()
        if (hideAfter) then
            self.timerContainer:Show();
            self.timer:SetMinMaxValues(0, hideAfter)
            self.timer:SetValue(hideAfter)
            self:SetScript('OnUpdate', function(self, elapsed)
                self.timer:SetValue(self.timer:GetValue() - elapsed)
                if (self.timer:GetValue() <= 0) then
                    self:HideWindow()
                end
            end)
        end
    end

    frame.HideWindow = function(self)
        self.fadeOut:Play()
        if (self.onClose) then
            self.onClose()
        end
        self:SetScript('OnUpdate', nil)
        EXFrames:Callback('windowClose', self.windowId)
    end

    frame.HideWindowImmediate = function(self)
        self:Hide()
        if (self.onClose) then
            self.onClose()
        end
        EXFrames:Callback('windowClose', self.windowId)
    end

    frame.showHeader = true
    frame.headerHeight = 40
    frame.headerInset = 5
    frame.headerButtonGap = 5
    frame.headerButtons = {}

    if (not frame.Texture) then
        local th = EXFrames.Theme

        local bg = frame:CreateTexture(nil, 'BACKGROUND')
        frame.Texture = bg
        bg:SetTexture(EXFrames.assets.textures.ui.panelBg)
        bg:SetVertexColor(unpack(th.backgroundDeep))
        bg:SetTextureSliceMargins(8, 8, 8, 8)
        bg:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
        bg:SetAllPoints()

        local borderOverlay = frame:CreateTexture(nil, 'OVERLAY', nil, 7)
        borderOverlay:SetTexture(EXFrames.assets.textures.ui.panelBorder)
        borderOverlay:SetVertexColor(unpack(th.border))
        borderOverlay:SetTextureSliceMargins(8, 8, 8, 8)
        borderOverlay:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
        borderOverlay:SetAllPoints()
        borderOverlay:SetAlpha(0)
        frame.borderOverlay = borderOverlay
    end

    if (not frame.header) then
        local th = EXFrames.Theme
        local header = CreateFrame('Frame', nil, frame)
        header:SetHeight(frame.headerHeight)
        frame.header = header

        local titleBar = CreateFrame('Frame', nil, header)
        titleBar:SetPoint('TOPLEFT')
        titleBar:SetPoint('BOTTOMLEFT')
        frame.titleBar = titleBar

        local headerTex = titleBar:CreateTexture(nil, 'BACKGROUND')
        headerTex:SetTexture(EXFrames.assets.textures.ui.buttonBg)
        headerTex:SetVertexColor(unpack(th.backgroundDeep))
        headerTex:SetTextureSliceMargins(16, 16, 16, 16)
        headerTex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        headerTex:SetAllPoints()
        frame.headerTex = headerTex
    end

    if (not frame.logo) then
        local logo = CreateFrame('Frame', nil, frame.titleBar)
        logo:SetSize(25, 25)
        logo:SetPoint('LEFT', frame.headerButtonGap, 0)

        local texture = logo:CreateTexture(nil, 'OVERLAY')
        texture:SetTexture(EXFrames.config.logoPath)
        texture:SetVertexColor(1, 1, 1, 1)
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetAllPoints()

        local version = logo:CreateFontString(nil, 'OVERLAY')
        version:SetPoint('LEFT', logo, 'RIGHT', 3, 0)
        version:SetVertexColor(.8, .8, .8, 1)
        version:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
        version:SetText(addonVersion)
        logo.version = version

        frame.logo = logo

        frame.HideVersion = function(self, hide)
            if (hide) then
                version:Hide()
            else
                version:Show()
            end
            if self.UpdateTitleAnchor then
                self:UpdateTitleAnchor()
            end
        end
    end

    if (not frame.resizeBtn) then
        local resizeBtn = CreateFrame("Button", nil, frame, "PanelResizeButtonTemplate");
        frame.resizeBtn = resizeBtn
        resizeBtn:SetPoint("BOTTOM", 0, -15)
        resizeBtn:SetSize(40, 10)
        resizeBtn:SetNormalTexture(EXFrames.assets.textures.window.resizeBtn)
        resizeBtn:SetHighlightTexture(EXFrames.assets.textures.window.resizeBtnHighlight)
        resizeBtn:Init(frame, 500, 500, 500, 1200);
        resizeBtn:SetOnResizeStoppedCallback(function(target)
            target._userPlaced = true
            if EXFrames.RefreshPixelPerfect then
                EXFrames:RefreshPixelPerfect()
            end
        end)
    end

    if (not frame.close) then
        local th = EXFrames.Theme
        local closeContainer = CreateFrame("Button", nil, frame.header)
        closeContainer:SetSize(frame.headerHeight, frame.headerHeight)

        local texture = closeContainer:CreateTexture(nil, "BACKGROUND")
        texture:SetTexture(EXFrames.assets.textures.ui.buttonBg)
        texture:SetTextureSliceMargins(16, 16, 16, 16)
        texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        texture:SetVertexColor(unpack(th.faded))
        texture:SetAllPoints()

        local closeIcon = closeContainer:CreateTexture(nil, "OVERLAY")
        closeIcon:SetTexture(EXFrames.assets.textures.icon.close)
        closeIcon:SetVertexColor(1, 1, 1, 1)
        closeIcon:SetPoint("CENTER")
        closeIcon:SetSize(16, 16)

        closeContainer:EnableMouse(true)
        closeContainer:SetMouseClickEnabled()
        closeContainer:SetScript("OnClick", function()
            if (frame:IsShown()) then
                frame:HideWindow()
            end
        end)
        closeContainer:SetScript("OnEnter", function(_)
            texture:SetVertexColor(unpack(th.dangerHover))
        end)
        closeContainer:SetScript("OnLeave", function(_)
            texture:SetVertexColor(unpack(th.faded))
        end)

        frame.close = closeContainer
        frame.close.bg = texture
        frame.close.icon = closeIcon
    end

    if (not frame.timer) then
        frame.timerContainer = CreateFrame("Frame", nil, frame)
        frame.timerContainer:SetHeight(12)
        frame.timerContainer:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 20, 15)
        frame.timerContainer:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -20, 15)
        local timerBg = frame.timerContainer:CreateTexture(nil, "BACKGROUND")
        timerBg:SetTexture(EXFrames.assets.textures.solidWhite)
        timerBg:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))
        timerBg:SetAllPoints()

        frame.timer = CreateFrame("StatusBar", nil, frame.timerContainer)
        frame.timer:SetAllPoints()
        frame.timer:SetStatusBarTexture(EXFrames.assets.textures.solidWhite)
        frame.timer:SetStatusBarColor(unpack(EXFrames.Theme.accent))
        frame.timer:SetMinMaxValues(0, 1)
        frame.timer:SetValue(0)
        frame.timerContainer:Hide();
    end

    if not frame.title then
        local title = frame.titleBar:CreateFontString(nil, "OVERLAY")
        frame.title = title
        title:SetFont(EXFrames.assets.font.default(), 12, 'OUTLINE')
        title:SetTextColor(1, 1, 1)
        title:SetJustifyH('LEFT')
        title:SetWidth(0)
        title:SetText(addonName)
    end

    frame.UpdateTitleAnchor = function(self)
        self.title:ClearAllPoints()
        if self.logo and self.logo:IsShown() then
            local version = self.logo.version
            if version and version:IsShown() then
                self.title:SetPoint('LEFT', version, 'RIGHT', 8, 0)
            else
                self.title:SetPoint('LEFT', self.logo, 'RIGHT', 8, 0)
            end
        else
            self.title:SetPoint('LEFT', self.titleBar, 'LEFT', self.headerButtonGap, 0)
        end
    end

    frame.ApplyChromeLayout = function(self)
        local inset = self.headerInset or 0
        local headerH = self.headerHeight or 40
        local gap = self.headerButtonGap or 5

        if self.Texture then
            self.Texture:ClearAllPoints()
            self.Texture:SetAllPoints()
        end

        if self.header then
            self.header:SetHeight(headerH)
            self.header:ClearAllPoints()
            if self.showHeader ~= false then
                self.header:SetPoint('TOPLEFT', inset, -inset)
                self.header:SetPoint('TOPRIGHT', -inset, -inset)
                self.header:Show()
            else
                self.header:Hide()
            end
        end

        if self.container then
            self.container:ClearAllPoints()
            if self.showHeader ~= false then
                self.container:SetPoint('TOPLEFT', inset, -(inset + headerH))
            else
                self.container:SetPoint('TOPLEFT', inset, -inset)
            end
            self.container:SetPoint('BOTTOMRIGHT', -inset, inset)
        end

        if self.logo then
            self.logo:ClearAllPoints()
            self.logo:SetPoint('LEFT', self.titleBar, 'LEFT', gap, 0)
        end

        self:UpdateTitleAnchor()
        self:LayoutHeaderButtons()
    end

    frame.SetHeaderShown = function(self, shown)
        self.showHeader = shown ~= false
        self:ApplyChromeLayout()
    end

    frame.SetHeaderInset = function(self, inset)
        self.headerInset = inset or 0
        self:ApplyChromeLayout()
    end

    frame.SetHeaderHeight = function(self, height)
        self.headerHeight = height or 40
        self:ApplyChromeLayout()
    end

    frame.SetHeaderButtonGap = function(self, gap)
        self.headerButtonGap = gap or 5
        self:ApplyChromeLayout()
    end

    frame.SetTitle = function(self, text)
        self.title:SetText(text or '')
    end

    frame.LayoutHeaderButtons = function(self)
        local size = self.headerHeight or 40
        local gap = self.headerButtonGap or 5
        if self.close then
            self.close:SetSize(size, size)
            self.close:ClearAllPoints()
            self.close:SetPoint('RIGHT', self.header, 'RIGHT', 0, 0)
        end
        local prev = self.close
        for i = #self.headerButtons, 1, -1 do
            local btn = self.headerButtons[i]
            btn:SetSize(size, size)
            btn:ClearAllPoints()
            btn:SetPoint('RIGHT', prev, 'LEFT', -gap, 0)
            prev = btn
        end
        if self.titleBar then
            self.titleBar:ClearAllPoints()
            self.titleBar:SetPoint('TOPLEFT')
            self.titleBar:SetPoint('BOTTOMLEFT')
            if prev then
                self.titleBar:SetPoint('RIGHT', prev, 'LEFT', -gap, 0)
            else
                self.titleBar:SetPoint('RIGHT')
            end
        end
    end

    frame.AddHeaderButton = function(self, spec)
        spec = spec or {}
        local size = self.headerHeight or 40
        local btn = EXFrames:GetFrame('button'):Create(self.header, {
            text = spec.text or '',
            onClick = spec.onClick,
            size = spec.size or { size, size },
            color = spec.color or EXFrames.Theme.faded,
            icon = spec.icon,
        })
        table.insert(self.headerButtons, btn)
        self:LayoutHeaderButtons()
        return btn
    end

    frame.SetHeaderTexture = function(self, path)
        if not self.headerTex then
            return
        end
        self.headerTex:SetTexture(path)
        self.headerTex:SetVertexColor(1, 1, 1, 1)
        self.headerTex:SetTextureSliceMargins(20, 20, 20, 20)
        self.headerTex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        self.headerTex:Show()
        self:ApplyChromeLayout()
    end

    frame.SetBackgroundTexture = function(self, path)
        if not self.Texture then
            return
        end
        self.Texture:SetTexture(path)
        self.Texture:SetVertexColor(1, 1, 1, 1)
        self.Texture:SetTexCoord(0, 1, 0, 1)
        self.Texture:SetTextureSliceMargins(24, 24, 24, 24)
        self.Texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        self.Texture:SetAllPoints()
    end

    frame.SetCloseIcon = function(self, path)
        if self.close and self.close.icon then
            self.close.icon:SetTexture(path)
        end
    end

    if not frame.container then
        local container = CreateFrame("Frame", nil, frame)
        frame.container = container
    end

    frame:ApplyChromeLayout()

    frame.DisableResize = function(self)
        -- It's still resizeable but button to do it is not there so basically disabled
        self.resizeBtn:Hide()
    end

    frame.SetTitleSize = function(self, size)
        self.title:SetFont(EXFrames.assets.font.default(), size, 'OUTLINE')
    end

    frame.DisableLogoAndVersion = function(self)
        self.logo:Hide()
        self:HideVersion(true)
        self:UpdateTitleAnchor()
    end

    ---@param options {staticAnchor?: table, disableResize?: boolean, disableLogoAndVersion?: boolean, titleSize?: number, headerTexture?: string, backgroundTexture?: string, closeIcon?: string, showHeader?: boolean, headerHeight?: number, headerInset?: number, headerButtonGap?: number}
    frame.Configure = function(self, options)
        if (options) then
            if (options.disableResize) then
                self:DisableResize()
            end
            if (options.staticAnchor) then
                self.StaticAnchor = options.staticAnchor
            end
            if (options.disableLogoAndVersion) then
                self:DisableLogoAndVersion()
            end
            if (options.titleSize) then
                self:SetTitleSize(options.titleSize)
            end
            if (options.headerHeight) then
                self.headerHeight = options.headerHeight
            end
            if (options.headerInset ~= nil) then
                self.headerInset = options.headerInset
            end
            if (options.headerButtonGap ~= nil) then
                self.headerButtonGap = options.headerButtonGap
            end
            if (options.showHeader ~= nil) then
                self.showHeader = options.showHeader
            end
            if (options.headerTexture) then
                self:SetHeaderTexture(options.headerTexture)
            end
            if (options.backgroundTexture) then
                self:SetBackgroundTexture(options.backgroundTexture)
            end
            if (options.closeIcon) then
                self:SetCloseIcon(options.closeIcon)
            end
            self:ApplyChromeLayout()
        end
    end

    windowManager:RegisterWindow(frame)
    frame.configured = true
end

---@param self ExalityFramesWindowFrame
---@param options WindowOptions
---@return Frame
window.Create = function(self, options)
    local f = self.pool:Acquire()
    if not f.configured then
        configure(f)
    end

    if (options and options.size) then
        f:SetSize(options.size[1], options.size[2])
        f.resizeBtn:Init(f, options.size[1], options.size[2], options.size[1], options.size[2] + 1000)
    end

    if (options and options.title) then
        f:SetTitle(options.title)
    end

    if (options and options.hideVersion) then
        f:HideVersion(options.hideVersion)
    end

    if (options and options.onClose) then
        f.onClose = options.onClose
    end

    f:SetBackgroundTexture(DEFAULT_CHROME.backgroundTexture)
    f:SetHeaderTexture(DEFAULT_CHROME.headerTexture)
    f:SetCloseIcon(DEFAULT_CHROME.closeIcon)

    if options then
        f:Configure(options)
    end

    return f
end

EXFrames.FrameBase.StandardizeCreate(window, 'options-only')
