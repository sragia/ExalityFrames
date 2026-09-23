local addonName, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class WindowDiscordLink : {label?: string, url: string, onClick?: fun(url: string, link: WindowDiscordLink)}
---@class LegacyCloseChromeOptions : { width?: number, height?: number, inset?: table<number>, buttonBg?: string, closeIcon?: string, iconSize?: number, normalColor?: table<number>, hoverColor?: table<number> }
---@class LegacyChromeOptions : { hideHeaderBar?: boolean, close?: LegacyCloseChromeOptions }
---@class WindowOptions : {size?: table<number>, title?: string, hideVersion?: boolean, showHeaderVersion?: boolean, versionBottom?: boolean, versionBottomOffset?: number, onVersionClick?: function, discordLink?: WindowDiscordLink, legacyChrome?: boolean|LegacyChromeOptions}

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
    frame.headerContentGap = 5
    frame.headerButtons = {}

    if (not frame.Texture) then
        local th = EXFrames.Theme
        EXFrames:ApplyPanelChrome(frame, {
            fillColor = th.backgroundDeep,
            borderColor = th.border,
            borderShown = false,
        })
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
                local contentGap = self.headerContentGap or 0
                self.container:SetPoint('TOPLEFT', inset, -(inset + headerH + contentGap))
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

    frame.ApplyDefaultCloseChrome = function(self)
        local th = EXFrames.Theme
        if not self.close or not self.close.bg then
            return
        end
        local close = self.close
        local bg = close.bg
        bg:SetTexture(EXFrames.assets.textures.ui.buttonBg)
        bg:SetTextureSliceMargins(16, 16, 16, 16)
        bg:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        bg:SetVertexColor(unpack(th.faded))
        close.icon:SetTexture(EXFrames.assets.textures.icon.close)
        close.icon:SetVertexColor(1, 1, 1, 1)
        close.icon:SetSize(16, 16)
        close:SetScript('OnEnter', function(_)
            bg:SetVertexColor(unpack(th.dangerHover))
        end)
        close:SetScript('OnLeave', function(_)
            bg:SetVertexColor(unpack(th.faded))
        end)
    end

    frame.ApplyLegacyCloseChrome = function(self)
        local spec = self.legacyCloseSpec
        if not spec or not self.close or not self.close.bg then
            return
        end
        local close = self.close
        local bg = close.bg
        bg:SetTexture(spec.buttonBg or EXFrames.assets.textures.ui.buttonBg)
        bg:SetTextureSliceMargins(20, 20, 20, 20)
        bg:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        if spec.normalColor then
            bg:SetVertexColor(unpack(spec.normalColor))
        end
        close.icon:SetTexture(spec.closeIcon or EXFrames.assets.textures.icon.close)
        close.icon:SetVertexColor(1, 1, 1, 1)
        local iconSize = spec.iconSize or 12
        close.icon:SetSize(iconSize, iconSize)
        local hover = spec.hoverColor
        local normal = spec.normalColor
        close:SetScript('OnEnter', function(_)
            if hover then
                bg:SetVertexColor(unpack(hover))
            end
        end)
        close:SetScript('OnLeave', function(_)
            if normal then
                bg:SetVertexColor(unpack(normal))
            end
        end)
    end

    frame.LayoutHeaderButtons = function(self)
        local size = self.headerHeight or 40
        local gap = self.headerButtonGap or 5
        if self.close then
            if self.legacyCloseLayout then
                local spec = self.legacyCloseSpec or {}
                local inset = spec.inset or { 8, 6 }
                self.close:SetSize(spec.width or 28, spec.height or 22)
                self.close:ClearAllPoints()
                self.close:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -inset[1], -inset[2])
            else
                self.close:SetSize(size, size)
                self.close:ClearAllPoints()
                self.close:SetPoint('RIGHT', self.header, 'RIGHT', 0, 0)
            end
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
            hoverColor = spec.hoverColor,
            icon = spec.icon,
        })
        table.insert(self.headerButtons, btn)
        self:LayoutHeaderButtons()
        return btn
    end

    frame.ApplyLegacyChrome = function(self, opts)
        opts = opts or {}
        local th = EXFrames.Theme
        if self.SetPanelFillColor then
            self:SetPanelFillColor(unpack(th.backgroundDeep))
        elseif self.Texture then
            self.Texture:SetVertexColor(unpack(th.backgroundDeep))
        end
        if self.headerTex then
            if opts.hideHeaderBar then
                self.headerTex:Hide()
            else
                self.headerTex:SetTexture(EXFrames.assets.textures.ui.buttonBg)
                self.headerTex:SetVertexColor(unpack(th.backgroundDeep))
                self.headerTex:SetTextureSliceMargins(16, 16, 16, 16)
                self.headerTex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
                self.headerTex:Show()
            end
        end
        if opts.close then
            self.legacyCloseLayout = true
            self.legacyCloseSpec = opts.close
            self:ApplyLegacyCloseChrome()
        else
            self.legacyCloseLayout = false
            self.legacyCloseSpec = nil
            if self.close and self.close.icon then
                self.close.icon:SetTexture(EXFrames.assets.textures.icon.close)
            end
        end
        self:ApplyChromeLayout()
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

    if not frame.versionFooter then
        local th = EXFrames.Theme
        local FOOTER_HEIGHT = 14
        local FOOTER_ITEM_GAP = 5

        local footer = CreateFrame('Frame', nil, frame)
        footer:Hide()
        footer:SetFrameLevel(frame:GetFrameLevel() + 2)

        local function BindFooterHover(button)
            button:SetScript('OnEnter', function(self)
                self.text:SetTextColor(unpack(th.accent))
            end)
            button:SetScript('OnLeave', function(self)
                self.text:SetTextColor(unpack(th.white))
            end)
        end

        local versionBtn = CreateFrame('Button', nil, footer)
        local versionText = versionBtn:CreateFontString(nil, 'OVERLAY')
        versionText:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
        versionText:SetTextColor(unpack(th.white))
        versionText:SetJustifyH('LEFT')
        versionText:SetText(addonVersion)
        versionText:SetPoint('LEFT')
        versionBtn.text = versionText
        BindFooterHover(versionBtn)

        local separator = footer:CreateFontString(nil, 'OVERLAY')
        separator:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
        separator:SetTextColor(unpack(th.textMuted))
        separator:SetText('/')
        separator:Hide()

        local discordBtn = CreateFrame('Button', nil, footer)
        discordBtn:Hide()
        local discordText = discordBtn:CreateFontString(nil, 'OVERLAY')
        discordText:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
        discordText:SetTextColor(unpack(th.white))
        discordText:SetJustifyH('LEFT')
        discordText:SetPoint('LEFT')
        discordBtn.text = discordText
        BindFooterHover(discordBtn)

        footer.versionBtn = versionBtn
        footer.separator = separator
        footer.discordBtn = discordBtn

        frame.versionFooter = footer
        frame.versionBottom = versionBtn
        frame.versionBottomOffset = -4
        frame.discordLink = nil

        frame.UpdateVersionFooterLayout = function(self)
            local bar = self.versionFooter
            if not bar or not bar:IsShown() then
                return
            end

            local x = 0
            local versionButton = bar.versionBtn
            if versionButton:IsShown() then
                local width = math.max(1, versionButton.text:GetStringWidth())
                versionButton:SetSize(width, FOOTER_HEIGHT)
                versionButton:ClearAllPoints()
                versionButton:SetPoint('TOPLEFT', bar, 'TOPLEFT', x, 0)
                x = x + width
            end

            if bar.separator:IsShown() then
                bar.separator:ClearAllPoints()
                bar.separator:SetPoint('LEFT', bar, 'LEFT', x + FOOTER_ITEM_GAP, 0)
                x = x + FOOTER_ITEM_GAP + bar.separator:GetStringWidth()
            end

            if bar.discordBtn:IsShown() then
                local width = math.max(1, bar.discordBtn.text:GetStringWidth())
                bar.discordBtn:SetSize(width, FOOTER_HEIGHT)
                bar.discordBtn:ClearAllPoints()
                bar.discordBtn:SetPoint('TOPLEFT', bar, 'TOPLEFT', x + FOOTER_ITEM_GAP, 0)
                x = x + FOOTER_ITEM_GAP + width
            end

            bar:SetSize(math.max(1, x), FOOTER_HEIGHT)
            bar:ClearAllPoints()
            bar:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', 0, self.versionBottomOffset or -4)
        end

        frame.UpdateBottomVersionLayout = frame.UpdateVersionFooterLayout

        frame.SetBottomVersionShown = function(self, shown)
            if not self.versionFooter then
                return
            end
            if shown then
                self.versionFooter:Show()
                self.versionFooter.versionBtn:Show()
                self:UpdateVersionFooterLayout()
            else
                self.versionFooter:Hide()
            end
        end

        frame.SetBottomVersionOffset = function(self, offsetY)
            self.versionBottomOffset = offsetY
            self:UpdateVersionFooterLayout()
        end

        frame.SetVersionClickHandler = function(self, onClick)
            if not self.versionFooter then
                return
            end
            local versionButton = self.versionFooter.versionBtn
            if onClick then
                versionButton:SetScript('OnClick', function()
                    onClick(self)
                end)
            else
                versionButton:SetScript('OnClick', nil)
            end
        end

        frame.SetDiscordLink = function(self, link)
            self.discordLink = link
            if not self.versionFooter then
                return
            end
            local bar = self.versionFooter
            local discordButton = bar.discordBtn
            if link and link.url and link.url ~= '' then
                discordButton.text:SetText(link.label or 'Discord')
                discordButton:Show()
                bar.separator:Show()
                discordButton:SetScript('OnClick', function()
                    if link.onClick then
                        link.onClick(link.url, link)
                    end
                end)
            else
                discordButton:Hide()
                bar.separator:Hide()
                discordButton:SetScript('OnClick', nil)
            end
            self:UpdateVersionFooterLayout()
        end
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

    ---@param options {staticAnchor?: table, disableResize?: boolean, disableLogoAndVersion?: boolean, titleSize?: number, headerTexture?: string, backgroundTexture?: string, closeIcon?: string, showHeader?: boolean, headerHeight?: number, headerInset?: number, headerButtonGap?: number, versionBottom?: boolean, versionBottomOffset?: number, onVersionClick?: function, discordLink?: WindowDiscordLink}
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
            if (options.versionBottom ~= nil) then
                self:SetBottomVersionShown(options.versionBottom)
            end
            if (options.versionBottomOffset ~= nil) then
                self:SetBottomVersionOffset(options.versionBottomOffset)
            end
            if (options.onVersionClick ~= nil) then
                self:SetVersionClickHandler(options.onVersionClick)
            end
            if (options.discordLink ~= nil) then
                self:SetDiscordLink(options.discordLink)
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

    f:HideVersion(true)
    if f.SetBottomVersionShown then
        f:SetBottomVersionShown(false)
    end
    if f.SetVersionClickHandler then
        f:SetVersionClickHandler(nil)
    end
    if f.SetDiscordLink then
        f:SetDiscordLink(nil)
    end

    if (options and options.showHeaderVersion) then
        f:HideVersion(false)
    end

    if (options and options.versionBottom) then
        f:HideVersion(true)
        f:SetBottomVersionShown(true)
        if (options.versionBottomOffset ~= nil) then
            f:SetBottomVersionOffset(options.versionBottomOffset)
        end
        if (options.onVersionClick) then
            f:SetVersionClickHandler(options.onVersionClick)
        end
        if (options.discordLink) then
            f:SetDiscordLink(options.discordLink)
        end
    end

    if (options and options.onClose) then
        f.onClose = options.onClose
    end

    if options and options.legacyChrome then
        local legacyOpts = options.legacyChrome == true and {} or options.legacyChrome
        f:ApplyLegacyChrome(legacyOpts)
    else
        f.legacyCloseLayout = false
        f.legacyCloseSpec = nil
        f:SetBackgroundTexture(DEFAULT_CHROME.backgroundTexture)
        f:SetHeaderTexture(DEFAULT_CHROME.headerTexture)
        f:SetCloseIcon(DEFAULT_CHROME.closeIcon)
        f:ApplyDefaultCloseChrome()
    end

    if options then
        f:Configure(options)
    end

    return f
end

EXFrames.FrameBase.StandardizeCreate(window, 'options-only')
