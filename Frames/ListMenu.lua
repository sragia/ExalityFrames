local addonName, ns = ...

---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesListMenu
local listMenu = EXFrames:GetFrame('list-menu-frame')

local HEADER_HEIGHT = 16
local DIVIDER_HEIGHT = 9
local PADDING = 6
local ROW_GAP = 2
local HEADER_GAP = 8
local MAX_WIDTH = 320
local ICON_COLUMN = 28
local ROW_TEXT_INSET = 6
local ANCHOR_GAP = 4

local STYLES = {
    default = { rowHeight = 24, minWidth = 140, iconSize = 18, iconLeft = 4 },
    drawer = { rowHeight = 26, minWidth = 180, iconSize = 16, iconLeft = 6, atlas = true },
}

local PANEL_SLICE = 6
local GLOW_ALPHA = 0.65
local GLOW_HOVER_ALPHA = 0.8
local ROW_ATLAS_W, ROW_ATLAS_H = 472, 329
local ROW_ATLAS_SLICE = 4
local ROW_ATLAS_RECTS = {
    simpleBg = { 6, 117, 199, 140 },
    simpleBorderOff = { 6, 144, 199, 167 },
    simpleGlowOff = { 6, 171, 135, 194 },
    simpleGlowOn = { 6, 225, 135, 248 },
}

local function applyRowAtlas(tex, key)
    local rect = ROW_ATLAS_RECTS[key]
    tex:SetTexture(EXFrames.assets.textures.splitOptions.atlas)
    EXFrames.utils.texture.applySlice(tex, ROW_ATLAS_SLICE, tex:GetParent(), Enum.UITextureSliceMode.Stretched)
    tex:SetTexCoord(rect[1] / ROW_ATLAS_W, (rect[3] + 1) / ROW_ATLAS_W, rect[2] / ROW_ATLAS_H,
        (rect[4] + 1) / ROW_ATLAS_H)
end

local function applyPanelSlice(tex, texturePath, color)
    tex:SetTexture(texturePath)
    tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    tex:SetTextureSliceMargins(PANEL_SLICE, PANEL_SLICE, PANEL_SLICE, PANEL_SLICE)
    tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    tex:SetAllPoints()
end

local function unpackColor(color, fallback)
    if color then
        return color[1], color[2], color[3], color[4] or 1
    end
    if fallback then
        return fallback[1], fallback[2], fallback[3], fallback[4] or 1
    end
    return 1, 1, 1, 1
end

local function setRowIcon(texture, icon)
    if not texture then return end
    if not icon then
        texture:Hide()
        return
    end
    texture:Show()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(icon) then
        texture:SetAtlas(icon)
    else
        texture:SetTexture(icon)
    end
    local inset = 0.125
    texture:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
end

local function entriesHaveIcon(entries)
    for _, entry in ipairs(entries) do
        if entry.icon then
            return true
        end
    end
    return false
end

local function measureWidth(panel, entries)
    if not panel.measureFont then
        panel.measureFont = panel:CreateFontString(nil, 'ARTWORK')
        panel.measureFont:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
        panel.measureFont:Hide()
    end

    local maxText = 0
    for _, entry in ipairs(entries) do
        panel.measureFont:SetText(entry.text or entry.label or '')
        maxText = math.max(maxText, panel.measureFont:GetStringWidth())
    end

    local minWidth = panel.style.minWidth
    local anchorWidth = panel.anchorWidth or minWidth
    local hasIcon = entriesHaveIcon(entries)
    local horizontalPadding = hasIcon and (ICON_COLUMN + ROW_TEXT_INSET) or (ROW_TEXT_INSET * 2)
    local contentWidth = maxText + horizontalPadding
    return math.min(MAX_WIDTH, math.max(minWidth, anchorWidth, contentWidth))
end

local function positionPanel(panel, anchorBtn)
    panel:ClearAllPoints()
    panel:SetClampedToScreen(true)

    local panelHeight = panel:GetHeight() * panel:GetEffectiveScale()
    local screenW = GetScreenWidth()
    local screenH = GetScreenHeight()

    local left, bottom, width, height = anchorBtn:GetRect()
    local anchorTop = bottom + height
    local anchorCenterX = left + (width / 2)

    local spaceBelow = bottom - ANCHOR_GAP - panelHeight
    local spaceAbove = screenH - anchorTop - ANCHOR_GAP - panelHeight
    local placeBelow = spaceBelow >= 0 or spaceBelow >= spaceAbove

    local panelPoint, anchorPoint, yOff
    if placeBelow then
        panelPoint, anchorPoint, yOff = 'TOP', 'BOTTOM', -ANCHOR_GAP
    else
        panelPoint, anchorPoint, yOff = 'BOTTOM', 'TOP', ANCHOR_GAP
    end

    if (anchorCenterX / screenW) > 0.5 then
        panel:SetPoint(panelPoint .. 'RIGHT', anchorBtn, anchorPoint .. 'RIGHT', 0, yOff)
    else
        panel:SetPoint(panelPoint .. 'LEFT', anchorBtn, anchorPoint .. 'LEFT', 0, yOff)
    end

    -- Anchors can land between pixels, which drops the unsnapped 1px border lines.
    EXFrames:SnapFrameToPixels(panel)
    if panel.PPBorder then
        panel.PPBorder:SetBorderThickness(1)
    end
end

local function rowExtent(entry, style)
    if entry.isDivider then
        return DIVIDER_HEIGHT
    end
    if entry.isHeader then
        return HEADER_HEIGHT
    end
    return style.rowHeight
end

local function gapBefore(entry, previous)
    if not previous then
        return 0
    end
    if entry.isHeader then
        return HEADER_GAP
    end
    return ROW_GAP
end

local function setRowHighlight(row, hovered, bgColor, hoverColor)
    if row.glow then
        applyRowAtlas(row.glow, hovered and 'simpleGlowOn' or 'simpleGlowOff')
        row.glow:SetAlpha(hovered and GLOW_HOVER_ALPHA or GLOW_ALPHA)
    else
        row.bg:SetVertexColor(unpack(hovered and hoverColor or bgColor))
    end
end

local function configureRow(row, entry, theme, parentPanel)
    row.listEntry = entry
    row.label:ClearAllPoints()
    row.label:SetPoint('RIGHT', row, 'RIGHT', -ROW_TEXT_INSET, 0)
    row.divider:SetShown(entry.isDivider == true)

    if entry.isHeader or entry.isDivider then
        row:EnableMouse(false)
        row.bg:Hide()
        if row.glow then
            row.glow:Hide()
            row.border:Hide()
        end
        row.icon:Hide()
        row.label:SetPoint('LEFT', row, 'LEFT', ROW_TEXT_INSET, 0)
        row.label:SetText(entry.text or entry.label or '')
        row.label:SetTextColor(unpackColor(entry.color, theme.textMuted))
        row:SetScript('OnEnter', nil)
        row:SetScript('OnLeave', nil)
        row:SetScript('OnClick', nil)
        return
    end

    local bgColor = { unpackColor(nil, theme.backgroundLight) }
    local hoverColor
    if entry.hoverColor then
        hoverColor = { unpackColor(entry.hoverColor, theme.backgroundPanel) }
    else
        local panel = theme.backgroundPanel
        hoverColor = { panel[1], panel[2], panel[3], 1 }
    end
    local textR, textG, textB, textA = unpackColor(entry.color, theme.text)

    row:EnableMouse(true)
    row.bg:Show()
    if row.glow then
        row.glow:Show()
        row.border:Show()
    end
    setRowIcon(row.icon, entry.icon)
    if entry.icon then
        row.label:SetPoint('LEFT', row.icon, 'RIGHT', 6, 0)
    else
        row.label:SetPoint('LEFT', row, 'LEFT', ROW_TEXT_INSET, 0)
    end
    row.label:SetText(entry.text or entry.label or '')
    row.label:SetTextColor(textR, textG, textB, textA)

    setRowHighlight(row, false, bgColor, hoverColor)
    row:SetScript('OnEnter', function(btn)
        setRowHighlight(btn, true, bgColor, hoverColor)
        if btn.listEntry and btn.listEntry.onEnter then
            pcall(btn.listEntry.onEnter, btn)
        end
    end)
    row:SetScript('OnLeave', function(btn)
        setRowHighlight(btn, false, bgColor, hoverColor)
        if btn.listEntry and btn.listEntry.onLeave then
            pcall(btn.listEntry.onLeave, btn)
        end
    end)
    row:SetScript('OnClick', function(btn, button)
        local clicked = btn.listEntry
        local keepOpen = false
        if clicked and clicked.onClick then
            local ok, result = pcall(clicked.onClick, btn, button)
            keepOpen = ok and result == false
        end
        if keepOpen or not clicked or not clicked.onClick then
            return
        end
        if parentPanel then
            parentPanel:Hide()
        end
    end)
end

local function createRowArt(row, style, theme)
    local rowBg = row:CreateTexture(nil, 'BACKGROUND')
    rowBg:SetAllPoints()
    row.bg = rowBg

    if style.atlas then
        applyRowAtlas(rowBg, 'simpleBg')

        local glow = row:CreateTexture(nil, 'BACKGROUND', nil, 1)
        glow:SetAllPoints()
        row.glow = glow

        local border = row:CreateTexture(nil, 'OVERLAY')
        border:SetAllPoints()
        applyRowAtlas(border, 'simpleBorderOff')
        row.border = border
    else
        rowBg:SetTexture(EXFrames.assets.textures.solidWhite)
        rowBg:SetVertexColor(unpackColor(nil, theme.backgroundLight))
    end
end

local function createPanel(frameName, styleKey)
    local theme = EXFrames.Theme
    local style = STYLES[styleKey]
    local panel = CreateFrame('Frame', frameName, UIParent)
    panel:SetFrameStrata('TOOLTIP')
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()
    panel.style = style

    if style.atlas then
        local textures = EXFrames.assets.textures.ui
        local bg = panel:CreateTexture(nil, 'BACKGROUND')
        applyPanelSlice(bg, textures.panelBg, theme.backgroundDeep)
        panel.bg = bg

        local border = panel:CreateTexture(nil, 'OVERLAY', nil, 1)
        applyPanelSlice(border, textures.panelBorder, theme.border)
    else
        EXFrames:ApplyPanelChrome(panel, {
            fillColor = theme.backgroundDeep,
            borderColor = theme.border,
            borderShown = true,
        })
        panel.bg = panel.PanelFill
    end

    panel.rows = {}
    panel.rowPool = CreateFramePool('Button', panel)

    panel.SetEntries = function(f, entries, anchorBtn)
        for _, row in ipairs(f.rows) do
            row:Hide()
            f.rowPool:Release(row)
        end
        wipe(f.rows)

        f.anchorBtn = anchorBtn
        f.anchorWidth = anchorBtn and anchorBtn:GetWidth() or style.minWidth

        local count = #entries
        if count == 0 then
            f:SetSize(style.minWidth, style.rowHeight)
            return
        end

        local width = measureWidth(f, entries)
        local height = PADDING * 2
        for index, entry in ipairs(entries) do
            height = height + gapBefore(entry, entries[index - 1]) + rowExtent(entry, style)
        end
        f:SetSize(width + (PADDING * 2), height)

        local previous
        for index, entry in ipairs(entries) do
            local row = f.rowPool:Acquire()
            row:SetParent(f)
            row:SetSize(width, rowExtent(entry, style))
            row:SetFrameLevel(f:GetFrameLevel() + 1)
            row:RegisterForClicks('AnyUp')

            if not row.bg then
                createRowArt(row, style, theme)

                local icon = row:CreateTexture(nil, 'ARTWORK')
                icon:SetSize(style.iconSize, style.iconSize)
                icon:SetPoint('LEFT', row, 'LEFT', style.iconLeft, 0)
                row.icon = icon

                local label = row:CreateFontString(nil, 'OVERLAY')
                label:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
                label:SetPoint('LEFT', icon, 'RIGHT', 6, 0)
                label:SetPoint('RIGHT', row, 'RIGHT', -6, 0)
                label:SetJustifyH('LEFT')
                row.label = label

                local divider = row:CreateTexture(nil, 'ARTWORK')
                divider:SetTexture(EXFrames.assets.textures.solidWhite)
                divider:SetVertexColor(unpackColor(nil, theme.border))
                divider:SetHeight(EXFrames:ScalePixels(1, row))
                divider:SetPoint('LEFT', row, 'LEFT', ROW_TEXT_INSET, 0)
                divider:SetPoint('RIGHT', row, 'RIGHT', -ROW_TEXT_INSET, 0)
                divider:SetSnapToPixelGrid(true)
                divider:SetTexelSnappingBias(0)
                row.divider = divider
            end

            configureRow(row, entry, theme, f)

            if previous then
                row:SetPoint('TOPLEFT', previous, 'BOTTOMLEFT', 0, -gapBefore(entry, entries[index - 1]))
            else
                row:SetPoint('TOPLEFT', f, 'TOPLEFT', PADDING, -PADDING)
            end

            row:Show()
            f.rows[index] = row
            previous = row
        end
    end

    panel.ShowAt = function(f, anchorBtn, entries)
        if not anchorBtn or #entries == 0 then return end
        f:SetEntries(entries, anchorBtn)
        f:Show()
        positionPanel(f, anchorBtn)
    end

    if not panel.dismissSetup then
        panel.dismissSetup = true
        panel:SetScript('OnShow', function(f)
            f:SetScript('OnUpdate', function(frame)
                if not IsMouseButtonDown('LeftButton') and not IsMouseButtonDown('RightButton') then
                    return
                end
                if frame:IsMouseOver() then return end
                if frame.anchorBtn and frame.anchorBtn:IsMouseOver() then return end
                frame:Hide()
            end)
        end)
        panel:SetScript('OnHide', function(f)
            f:SetScript('OnUpdate', nil)
            f.anchorBtn = nil
            if f.onHideCallback then
                f.onHideCallback()
                f.onHideCallback = nil
            end
        end)
    end

    return panel
end

listMenu.Init = function(self)
    self.panels = { default = createPanel(addonName .. 'ListMenu', 'default') }
    self.panel = self.panels.default
end

---@param styleKey? 'default'|'drawer'
listMenu.GetPanel = function(self, styleKey)
    if not self.panels then
        self:Init()
    end
    styleKey = STYLES[styleKey] and styleKey or 'default'
    if not self.panels[styleKey] then
        self.panels[styleKey] = createPanel(addonName .. 'ListMenu_' .. styleKey, styleKey)
    end
    return self.panels[styleKey]
end

listMenu.GetOpenPanel = function(self)
    for _, panel in pairs(self.panels or {}) do
        if panel:IsShown() then
            return panel
        end
    end
end

listMenu.IsOpen = function(self)
    return self:GetOpenPanel() ~= nil
end

listMenu.GetAnchor = function(self)
    local panel = self:GetOpenPanel()
    return panel and panel.anchorBtn
end

listMenu.Hide = function(self)
    for _, panel in pairs(self.panels or {}) do
        panel:Hide()
    end
end

---@param itemID any passed to each menu item's onClick
---@param menuItems table[] items can set isVisible and getLabel to resolve on open
listMenu.BuildContextEntries = function(self, itemID, menuItems)
    local entries = {}
    for _, menuItem in ipairs(menuItems) do
        if not menuItem.isVisible or menuItem.isVisible(itemID) then
            table.insert(entries, {
                text = menuItem.getLabel and menuItem.getLabel(itemID) or menuItem.label or menuItem.text,
                icon = menuItem.icon,
                color = menuItem.color,
                hoverColor = menuItem.hoverColor,
                onClick = function(_, button)
                    if menuItem.onClick then
                        menuItem.onClick(itemID, button)
                    end
                end,
            })
        end
    end
    return entries
end

---@param styleKey? 'default'|'drawer'
listMenu.ShowAt = function(self, anchorBtn, entries, styleKey)
    local target = self:GetPanel(styleKey)
    for _, panel in pairs(self.panels) do
        if panel ~= target then
            panel:Hide()
        end
    end
    target:ShowAt(anchorBtn, entries)
end

---@param styleKey? 'default'|'drawer'
listMenu.ToggleAt = function(self, anchorBtn, entries, styleKey)
    if self:IsOpen() and self:GetAnchor() == anchorBtn then
        self:Hide()
        return
    end
    self:ShowAt(anchorBtn, entries, styleKey)
end
