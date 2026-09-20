local _, ns = ...

---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesListMenu
local listMenu = EXFrames:GetFrame('list-menu-frame')

local ROW_HEIGHT = 24
local PADDING = 6
local ROW_GAP = 2
local MIN_WIDTH = 140
local MAX_WIDTH = 320
local ICON_COLUMN = 28
local ROW_TEXT_INSET = 6
local ANCHOR_GAP = 4

local function unpackColor(color, fallback)
    if color then
        return color[1], color[2], color[3], color[4] or 1
    end
    if fallback then
        return fallback[1], fallback[2], fallback[3], fallback[4] or 1
    end
    return 1, 1, 1, 1
end

local function getBgTexture()
    return EXFrames.assets.textures.ui.panelBg
        or EXFrames.assets.textures.ui.inputBg
        or EXFrames.assets.textures.solidWhite
end

local function getBorderTexture()
    return EXFrames.assets.textures.ui.panelBorder or getBgTexture()
end

local function applySliceTexture(tex, texturePath, r, g, b, a)
    tex:SetTexture(texturePath)
    tex:SetVertexColor(r, g, b, a)
    if tex.SetTextureSliceMargins then
        tex:SetTextureSliceMargins(6, 6, 6, 6)
        tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    end
    tex:SetAllPoints()
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

    local anchorWidth = panel.anchorWidth or MIN_WIDTH
    local hasIcon = entriesHaveIcon(entries)
    local horizontalPadding = hasIcon and (ICON_COLUMN + ROW_TEXT_INSET) or (ROW_TEXT_INSET * 2)
    local contentWidth = maxText + horizontalPadding
    return math.min(MAX_WIDTH, math.max(MIN_WIDTH, anchorWidth, contentWidth))
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
end

local function configureRow(row, entry, theme, parentPanel)
    local bgR, bgG, bgB, bgA = unpackColor(nil, theme.backgroundLight)
    local hoverR, hoverG, hoverB, hoverA
    if entry.hoverColor then
        hoverR, hoverG, hoverB, hoverA = unpackColor(entry.hoverColor, theme.backgroundPanel)
    else
        local panel = theme.backgroundPanel
        hoverR, hoverG, hoverB, hoverA = panel[1], panel[2], panel[3], 1
    end
    local textR, textG, textB, textA = unpackColor(entry.color, theme.text)

    setRowIcon(row.icon, entry.icon)
    row.label:ClearAllPoints()
    if entry.icon then
        row.label:SetPoint('LEFT', row.icon, 'RIGHT', 6, 0)
    else
        row.label:SetPoint('LEFT', row, 'LEFT', ROW_TEXT_INSET, 0)
    end
    row.label:SetPoint('RIGHT', row, 'RIGHT', -ROW_TEXT_INSET, 0)
    row.label:SetText(entry.text or entry.label or '')
    row.label:SetTextColor(textR, textG, textB, textA)
    row.listEntry = entry

    row.bg:SetVertexColor(bgR, bgG, bgB, bgA)
    row:SetScript('OnEnter', function(btn)
        btn.bg:SetVertexColor(hoverR, hoverG, hoverB, hoverA)
        if btn.listEntry and btn.listEntry.onEnter then
            pcall(btn.listEntry.onEnter, btn)
        end
    end)
    row:SetScript('OnLeave', function(btn)
        btn.bg:SetVertexColor(bgR, bgG, bgB, bgA)
        if btn.listEntry and btn.listEntry.onLeave then
            pcall(btn.listEntry.onLeave, btn)
        end
    end)
    row:SetScript('OnClick', function(btn, button)
        if btn.listEntry and btn.listEntry.onClick then
            pcall(btn.listEntry.onClick, btn, button)
        end
        if parentPanel then
            parentPanel:Hide()
        end
    end)
end

local function createPanel(frameName)
    local theme = EXFrames.Theme
    local panel = CreateFrame('Frame', frameName, UIParent)
    panel:SetFrameStrata('TOOLTIP')
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()

    local bg = panel:CreateTexture(nil, 'BACKGROUND')
    applySliceTexture(bg, getBgTexture(), unpackColor(nil, theme.backgroundDeep))
    panel.bg = bg

    local border = panel:CreateTexture(nil, 'OVERLAY', nil, 1)
    applySliceTexture(border, getBorderTexture(), unpackColor(nil, theme.border))
    panel.border = border

    panel.rows = {}
    panel.rowPool = CreateFramePool('Button', panel)

    panel.SetEntries = function(f, entries, anchorBtn)
        for _, row in ipairs(f.rows) do
            row:Hide()
            f.rowPool:Release(row)
        end
        wipe(f.rows)

        f.anchorBtn = anchorBtn
        f.anchorWidth = anchorBtn and anchorBtn:GetWidth() or MIN_WIDTH

        local count = #entries
        if count == 0 then
            f:SetSize(MIN_WIDTH, ROW_HEIGHT)
            return
        end

        local width = measureWidth(f, entries)
        local height = count * (ROW_HEIGHT + ROW_GAP) - ROW_GAP + (PADDING * 2)
        f:SetSize(width + (PADDING * 2), height)

        local previous
        for index, entry in ipairs(entries) do
            local row = f.rowPool:Acquire()
            row:SetParent(f)
            row:SetSize(width, ROW_HEIGHT)
            row:SetFrameLevel(f:GetFrameLevel() + 1)
            row:RegisterForClicks('AnyUp')

            if not row.bg then
                local rowBg = row:CreateTexture(nil, 'BACKGROUND')
                applySliceTexture(rowBg, getBgTexture(), unpackColor(nil, theme.backgroundLight))
                row.bg = rowBg

                local icon = row:CreateTexture(nil, 'ARTWORK')
                icon:SetSize(18, 18)
                icon:SetPoint('LEFT', row, 'LEFT', 4, 0)
                row.icon = icon

                local label = row:CreateFontString(nil, 'OVERLAY')
                label:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
                label:SetPoint('LEFT', icon, 'RIGHT', 6, 0)
                label:SetPoint('RIGHT', row, 'RIGHT', -6, 0)
                label:SetJustifyH('LEFT')
                row.label = label
            end

            configureRow(row, entry, theme, f)

            if previous then
                row:SetPoint('TOPLEFT', previous, 'BOTTOMLEFT', 0, -ROW_GAP)
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
    self.panel = createPanel('ExalityUIListMenu')
end

listMenu.IsOpen = function(self)
    return self.panel and self.panel:IsShown()
end

listMenu.GetAnchor = function(self)
    return self.panel and self.panel.anchorBtn
end

listMenu.Hide = function(self)
    if self.panel then
        self.panel:Hide()
    end
end

listMenu.ShowAt = function(self, anchorBtn, entries)
    if not self.panel then
        self:Init()
    end
    self.panel:ShowAt(anchorBtn, entries)
end

listMenu.ToggleAt = function(self, anchorBtn, entries)
    if self:IsOpen() and self:GetAnchor() == anchorBtn then
        self:Hide()
        return
    end
    self:ShowAt(anchorBtn, entries)
end
