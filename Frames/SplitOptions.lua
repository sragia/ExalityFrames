local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesSplitOptionsScrollFrame
local scrollFrame = EXFrames:GetFrame('smooth-scroll-frame')

---@class ExalityFramesListMenu
local listMenu = EXFrames:GetFrame('list-menu-frame')

--- @class ExalityFramesSplitOptionsFrame
local splitOptions = EXFrames:GetFrame('split-options-frame')

splitOptions.Init = function(self)
    splitOptions.pool = CreateFramePool('Frame', UIParent)
end

local ATLAS_W, ATLAS_H = 472, 329
local SLICE = 4

-- Inclusive pixel rects: left, top, right, bottom.
local RECTS = {
    eyeOff = { 1, 1, 52, 52 },
    eye = { 55, 5, 112, 48 },
    plus = { 112, 1, 165, 54 },
    folderPlus = { 166, 2, 223, 51 },
    chevronUp = { 226, 14, 263, 39 },
    chevronDown = { 266, 15, 303, 40 },
    groupIconBg = { 306, 8, 339, 41 },
    groupIconMask = { 346, 14, 367, 35 },
    itemIconBg = { 375, 2, 421, 48 },
    itemIconMask = { 429, 8, 463, 42 },
    lock = { 415, 58, 464, 111 },
    unlock = { 415, 114, 464, 167 },
    inactive = { 418, 179, 461, 222 },

    actionBg = { 6, 61, 199, 85 },
    actionBorder = { 6, 89, 199, 113 },

    simpleBg = { 6, 117, 199, 140 },
    simpleBorderOff = { 6, 144, 199, 167 },
    simpleGlowOff = { 6, 171, 135, 194 },
    simpleBorderOn = { 6, 198, 199, 221 },
    simpleGlowOn = { 6, 225, 135, 248 },

    advancedBg = { 205, 61, 398, 110 },
    advancedBorderOff = { 205, 114, 398, 163 },
    advancedGlowOff = { 205, 167, 316, 216 },
    advancedBorderOn = { 205, 220, 398, 269 },
    advancedGlowOn = { 205, 273, 345, 322 },
}

local STYLE_KEYS = {
    simple = {
        bg = 'simpleBg',
        borderOff = 'simpleBorderOff',
        borderOn = 'simpleBorderOn',
        glowOff = 'simpleGlowOff',
        glowOn = 'simpleGlowOn',
    },
    advanced = {
        bg = 'advancedBg',
        borderOff = 'advancedBorderOff',
        borderOn = 'advancedBorderOn',
        glowOff = 'advancedGlowOff',
        glowOn = 'advancedGlowOn',
    },
}

local SIMPLE_ROW = 24
local ADVANCED_ROW = 50
local GROUP_ROW = 24
local ACTION_ROW = 25
local DEFAULT_LEFT_WIDTH = 180
local PAD_LEFT = 8
local SIMPLE_PAD_LEFT = 4
local PAD_RIGHT = 6
-- Eye states share a width so swapping them does not shift the label.
local PREVIEW_ICON = {
    eye = { 16, 12 },
    eyeOff = { 16, 16 },
}
local STATUS_ICON = 12
local ACTION_ICON = {
    eye = { 18, 14 },
    eyeOff = { 18, 18 },
    plus = { 18, 18 },
    folderPlus = { 18, 16 },
    lock = { 14, 15 },
    unlock = { 14, 15 },
}
local PREVIEW_GAP = 4
local ICON_GAP = 6
local ADV_WELL = 44
local ADV_WELL_LEFT = 2
local GROUP_WELL_SIMPLE = 22
local GROUP_WELL_LEFT = 2
local GROUP_TEXT_LEFT = 26
local CHEVRON_W = 14
local CHEVRON_H = 10
local GROUP_INDENT = 8
local SCROLL_FIT_EPSILON = 1

local DEFAULT_CATEGORY_BG = { 0.18, 0.18, 0.18, 0.7 }
local DEFAULT_CATEGORY_TEXT = { 0.65, 0.65, 0.65, 1 }

local function ApplyAtlas(tex, key, sliced)
    local rect = RECTS[key]
    local left, top, right, bottom = rect[1], rect[2], rect[3], rect[4]
    tex:SetTexture(EXFrames.assets.textures.splitOptions.atlas)
    if sliced then
        EXFrames.utils.texture.applySlice(tex, SLICE, tex:GetParent(), Enum.UITextureSliceMode.Stretched)
    end
    tex:SetTexCoord(left / ATLAS_W, (right + 1) / ATLAS_W, top / ATLAS_H, (bottom + 1) / ATLAS_H)
    tex:SetVertexColor(1, 1, 1, 1)
end

local function ApplyMask(mask, key)
    -- Mask textures ignore tex coords and sample the whole file, so these are standalone crops.
    local path = EXFrames.assets.textures.splitOptions[key]
    mask:SetTexture(path, 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')
end

local function InnerSize(well, bgKey, maskKey)
    local bg = RECTS[bgKey]
    local mask = RECTS[maskKey]
    local bgW = bg[3] - bg[1] + 1
    local maskW = mask[3] - mask[1] + 1
    return well * (maskW / bgW)
end

local function ForwardMouseWheel(row)
    row:EnableMouseWheel(true)
    row:SetScript('OnMouseWheel', function(self, delta)
        local scroll = self.scrollFrame
        if not scroll and self.GetParent then
            local parent = self:GetParent()
            scroll = parent and parent.scrollFrame
        end
        if not scroll then
            return
        end
        local handler = scroll.HandleMouseWheel or scroll:GetScript('OnMouseWheel')
        if handler then
            handler(scroll, delta)
        end
    end)
end

local function IsSelectable(item)
    if item.type == 'category' then
        return false
    end
    if item.type == 'group' then
        return item.selectable and true or false
    end
    return true
end

local function GroupKey(item)
    if item.ID ~= nil then
        return item.ID
    end
    return item.label or ''
end

local function RowHeight(parent, kind, style)
    local height
    if kind == 'category' then
        height = 20
    elseif kind == 'group' then
        height = GROUP_ROW
    else
        height = style == 'advanced' and ADVANCED_ROW or SIMPLE_ROW
    end
    return EXFrames:ScalePixel(height, parent)
end

local function ApplyItemVisual(button, active, hovered)
    local keys = STYLE_KEYS[button.itemStyle] or STYLE_KEYS.simple
    local useActive = active or hovered
    ApplyAtlas(button.bg, keys.bg, true)
    ApplyAtlas(button.border, useActive and keys.borderOn or keys.borderOff, true)
    ApplyAtlas(button.glow, useActive and keys.glowOn or keys.glowOff, true)
    local alpha = (hovered and not active) and 0.5 or 1
    local glowAlpha = active and 0.8 or 0.65
    if hovered and not active then
        glowAlpha = 0.45
    end
    button.bg:SetAlpha(1)
    button.border:SetAlpha(alpha)
    button.glow:SetAlpha(glowAlpha)
end

local function CreateChrome(frame)
    local bg = frame:CreateTexture(nil, 'BACKGROUND')
    bg:SetAllPoints()
    frame.bg = bg

    local glow = frame:CreateTexture(nil, 'ARTWORK')
    glow:SetAllPoints()
    frame.glow = glow

    local border = frame:CreateTexture(nil, 'OVERLAY')
    border:SetAllPoints()
    frame.border = border
end

local function LayoutItemContents(button)
    local previewShown = button.previewButton and button.previewButton:IsShown()
    local edgePad = EXFrames:ScalePixel(PAD_RIGHT, button)
    local rightPad = edgePad
    local previewReserve = 0
    if previewShown then
        local iconKey = button.previewEnabled and 'eye' or 'eyeOff'
        local iconSize = PREVIEW_ICON[iconKey]
        local previewW = EXFrames:ScalePixel(iconSize[1], button)
        local previewH = EXFrames:ScalePixel(iconSize[2], button)
        previewReserve = previewW + EXFrames:ScalePixel(PREVIEW_GAP, button)
        rightPad = edgePad + previewReserve
        button.previewButton:ClearAllPoints()
        button.previewButton:SetSize(previewW, previewH)
        if button.itemStyle == 'advanced' then
            local slotH = EXFrames:ScalePixel(PREVIEW_ICON.eyeOff[2], button)
            local drop = (slotH - previewH) / 2
            button.previewButton:SetPoint('TOPRIGHT', -edgePad, EXFrames:ScalePixel(-4, button) - drop)
        else
            button.previewButton:SetPoint('RIGHT', -edgePad, 0)
        end
        button.previewButton:SetFrameLevel(button:GetFrameLevel() + 5)
    end

    local statusShown = button.statusIcon and button.statusIcon:IsShown()
    if statusShown then
        local statusSize = EXFrames:ScalePixel(STATUS_ICON, button)
        local statusReserve = statusSize + EXFrames:ScalePixel(PREVIEW_GAP, button)
        if statusReserve > previewReserve then
            rightPad = edgePad + statusReserve
        end
        button.statusIcon:ClearAllPoints()
        button.statusIcon:SetSize(statusSize, statusSize)
        button.statusIcon:SetPoint('BOTTOMRIGHT', -edgePad, EXFrames:ScalePixel(5, button))
    end

    local leftPad = EXFrames:ScalePixel(button.itemStyle == 'advanced' and PAD_LEFT or SIMPLE_PAD_LEFT, button)
    if button.itemStyle == 'advanced' then
        local well = EXFrames:ScalePixel(ADV_WELL, button)
        local inner = EXFrames:ScalePixel(InnerSize(ADV_WELL, 'itemIconBg', 'itemIconMask'), button)
        button.iconShadow:ClearAllPoints()
        button.iconShadow:SetSize(well, well)
        button.iconShadow:SetPoint('LEFT', EXFrames:ScalePixel(ADV_WELL_LEFT, button), 0)
        button.iconShadow:Show()
        ApplyAtlas(button.iconShadow, 'itemIconBg', false)
        button.iconHolder:SetFrameLevel(button:GetFrameLevel() + 6)
        button.iconHolder:ClearAllPoints()
        button.iconHolder:SetSize(inner, inner)
        button.iconHolder:SetPoint('CENTER', button.iconShadow, 'CENTER', 0, 0)
        button.iconHolder:SetShown(button.icon:IsShown())
        button.iconMask:SetAllPoints(button.icon)
        leftPad = EXFrames:ScalePixel(ADV_WELL_LEFT, button) + well + EXFrames:ScalePixel(ICON_GAP, button)
    elseif button.iconShadow then
        button.iconShadow:Hide()
        button.icon:Hide()
        button.iconHolder:Hide()
    end

    button.text:ClearAllPoints()
    button.subtext:ClearAllPoints()
    local hasSub = button.itemStyle == 'advanced' and button.subtext:IsShown()
    if hasSub then
        local top = EXFrames:ScalePixel(-14, button)
        button.text:SetPoint('TOPLEFT', leftPad, top)
        button.text:SetPoint('TOPRIGHT', -rightPad, top)
        button.subtext:SetPoint('TOPLEFT', button.text, 'BOTTOMLEFT', 0, -1)
        button.subtext:SetPoint('TOPRIGHT', button.text, 'BOTTOMRIGHT', 0, -1)
    elseif button.itemStyle == 'advanced' then
        button.text:SetPoint('LEFT', leftPad, EXFrames:ScalePixel(-4, button))
        button.text:SetPoint('RIGHT', -rightPad, EXFrames:ScalePixel(-4, button))
    else
        button.text:SetPoint('LEFT', leftPad, 0)
        button.text:SetPoint('RIGHT', -rightPad, 0)
    end
end

local function CreateItem(parent, style)
    local button = CreateFrame('Button', nil, parent)
    button:SetHeight(RowHeight(parent, 'item', style))
    button.isCategory = false
    button.isGroup = false
    button.itemStyle = style
    button.isActive = false
    button.previewEnabled = false

    CreateChrome(button)

    local iconShadow = button:CreateTexture(nil, 'ARTWORK', nil, 1)
    button.iconShadow = iconShadow
    iconShadow:Hide()

    -- The well art is opaque in the center, so the icon has to live above that texture.
    local iconHolder = CreateFrame('Frame', nil, button)
    iconHolder:SetFrameLevel(button:GetFrameLevel() + 6)
    iconHolder:Hide()
    button.iconHolder = iconHolder
    local icon = iconHolder:CreateTexture(nil, 'ARTWORK')
    icon:SetAllPoints()
    button.icon = icon
    icon:Hide()
    local iconMask = iconHolder:CreateMaskTexture()
    ApplyMask(iconMask, 'itemIconMask')
    icon:AddMaskTexture(iconMask)
    button.iconMask = iconMask

    local text = button:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    text:SetTextColor(unpack(EXFrames.Theme.text))
    text:SetJustifyH('LEFT')
    text:SetWordWrap(false)
    text:SetMaxLines(1)
    button.text = text

    local subtext = button:CreateFontString(nil, 'OVERLAY')
    subtext:SetFont(EXFrames.assets.font.default(), 9, 'OUTLINE')
    subtext:SetTextColor(0.55, 0.55, 0.55, 1)
    subtext:SetJustifyH('LEFT')
    subtext:SetWordWrap(false)
    subtext:SetMaxLines(1)
    subtext:Hide()
    button.subtext = subtext

    local previewButton = CreateFrame('Button', nil, button)
    previewButton:SetSize(EXFrames:ScalePixel(PREVIEW_ICON.eyeOff[1], parent), EXFrames:ScalePixel(PREVIEW_ICON.eyeOff[2], parent))
    previewButton:Hide()
    local previewIcon = previewButton:CreateTexture(nil, 'ARTWORK')
    previewIcon:SetAllPoints()
    previewButton.icon = previewIcon
    button.previewButton = previewButton

    local statusIcon = button:CreateTexture(nil, 'OVERLAY')
    statusIcon:Hide()
    button.statusIcon = statusIcon

    button.SetStatusIcon = function(self, key)
        if key and RECTS[key] then
            ApplyAtlas(self.statusIcon, key, false)
            self.statusIcon:Show()
        else
            self.statusIcon:Hide()
        end
        LayoutItemContents(self)
    end

    button.RefreshChrome = function(self)
        ApplyItemVisual(self, self.isActive, self:IsMouseOver())
    end

    button.SetActive = function(self, active)
        self.isActive = active and true or false
        self:RefreshChrome()
    end

    button.SetText = function(self, value)
        self.text:SetText(value or '')
    end

    button.SetSubText = function(self, value)
        if self.itemStyle == 'advanced' then
            self.subtext:SetText(value or '')
            self.subtext:SetShown(value ~= nil and value ~= '')
        else
            self.subtext:Hide()
        end
        LayoutItemContents(self)
    end

    button.SetIcon = function(self, icon)
        self.iconPath = icon
        if self.itemStyle ~= 'advanced' then
            self.iconShadow:Hide()
            self.icon:Hide()
            self.iconHolder:Hide()
            return
        end
        if icon ~= nil and icon ~= '' then
            self.icon:SetTexture(icon)
            self.icon:SetTexCoord(0, 1, 0, 1)
            self.icon:Show()
            self.iconHolder:Show()
        else
            self.icon:SetTexture(nil)
            self.icon:Hide()
            self.iconHolder:Hide()
        end
        LayoutItemContents(self)
    end

    button.SetPreviewEnabled = function(self, enabled)
        self.previewEnabled = enabled and true or false
        ApplyAtlas(self.previewButton.icon, self.previewEnabled and 'eye' or 'eyeOff', false)
        LayoutItemContents(self)
    end

    button.SetPreview = function(self, config)
        if not config then
            self.previewButton:Hide()
            self.onPreviewToggle = nil
            self.previewEnabled = false
            LayoutItemContents(self)
            return
        end
        self.onPreviewToggle = config.onToggle
        self.previewButton:Show()
        self:SetPreviewEnabled(config.enabled)
        LayoutItemContents(self)
    end

    previewButton:SetScript('OnEnter', function()
        button:RefreshChrome()
    end)

    previewButton:SetScript('OnLeave', function()
        button:RefreshChrome()
    end)

    previewButton:SetScript('OnClick', function()
        local enabled = not button.previewEnabled
        button:SetPreviewEnabled(enabled)
        if button.onPreviewToggle then
            button.onPreviewToggle(button.ID, enabled)
        end
    end)

    ForwardMouseWheel(previewButton)

    button:SetScript('OnEnter', function(self)
        self:RefreshChrome()
    end)

    button:SetScript('OnLeave', function(self)
        self:RefreshChrome()
    end)

    button:SetScript('OnMouseDown', function(self, mouseButton)
        if mouseButton ~= 'LeftButton' or not self.owner or not self.owner.reorderEnabled then
            return
        end
        if self.owner.ArmDrag then
            self.owner:ArmDrag(self)
        end
    end)

    button:SetScript('OnClick', function(self, mouseButton)
        if self.owner and (self.owner.dragging or self.owner.suppressClick) then
            return
        end
        if mouseButton == 'RightButton' then
            if self.contextMenuItems and #self.contextMenuItems > 0 and self.onShowContextMenu then
                self:onShowContextMenu()
            end
            return
        end
        if self.onItemClick then
            self:onItemClick(self.ID)
        end
    end)

    button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    button:HookScript('OnSizeChanged', function(self)
        if self:GetWidth() <= 1 then
            return
        end
        LayoutItemContents(self)
        self:RefreshChrome()
    end)

    ForwardMouseWheel(button)
    button:SetActive(false)
    LayoutItemContents(button)

    return button
end

local function LayoutGroupContents(header)
    local wellSize = GROUP_WELL_SIMPLE
    local rightPad = EXFrames:ScalePixel(PAD_RIGHT, header) + EXFrames:ScalePixel(CHEVRON_W, header) + EXFrames:ScalePixel(PREVIEW_GAP, header)
    header.chevronButton:ClearAllPoints()
    header.chevronButton:SetSize(EXFrames:ScalePixel(CHEVRON_W, header), EXFrames:ScalePixel(CHEVRON_H, header))
    header.chevronButton:SetPoint('RIGHT', EXFrames:ScalePixel(-PAD_RIGHT, header), 0)
    if header.statusIcon and header.statusIcon:IsShown() then
        local statusSize = EXFrames:ScalePixel(STATUS_ICON, header)
        header.statusIcon:ClearAllPoints()
        header.statusIcon:SetSize(statusSize, statusSize)
        header.statusIcon:SetPoint('RIGHT', header.chevronButton, 'LEFT', EXFrames:ScalePixel(-2, header), 0)
        rightPad = rightPad + statusSize + EXFrames:ScalePixel(2, header)
    end

    local leftPad = EXFrames:ScalePixel(SIMPLE_PAD_LEFT, header)
    if header.iconShadow:IsShown() then
        local well = EXFrames:ScalePixel(wellSize, header)
        local inner = EXFrames:ScalePixel(InnerSize(wellSize, 'groupIconBg', 'groupIconMask'), header)
        header.iconShadow:ClearAllPoints()
        header.iconShadow:SetSize(well, well)
        header.iconShadow:SetPoint('LEFT', EXFrames:ScalePixel(GROUP_WELL_LEFT, header), 0)
        ApplyAtlas(header.iconShadow, 'groupIconBg', false)
        header.iconHolder:SetFrameLevel(header:GetFrameLevel() + 6)
        header.iconHolder:ClearAllPoints()
        header.iconHolder:SetSize(inner, inner)
        header.iconHolder:SetPoint('CENTER', header.iconShadow, 'CENTER', 0, 0)
        header.iconHolder:SetShown(header.icon:IsShown())
        header.iconMask:SetAllPoints(header.icon)
        leftPad = EXFrames:ScalePixel(GROUP_TEXT_LEFT, header)
    end

    header.text:ClearAllPoints()
    header.text:SetPoint('LEFT', leftPad, 0)
    header.text:SetPoint('RIGHT', -rightPad, 0)
end

local function CreateGroupHeader(parent, style)
    local header = CreateFrame('Button', nil, parent)
    header:SetHeight(RowHeight(parent, 'group', style))
    header.isCategory = false
    header.isGroup = true
    header.itemStyle = style
    header.isActive = false

    CreateChrome(header)

    local iconShadow = header:CreateTexture(nil, 'ARTWORK', nil, 1)
    header.iconShadow = iconShadow
    iconShadow:Hide()

    local iconHolder = CreateFrame('Frame', nil, header)
    iconHolder:SetFrameLevel(header:GetFrameLevel() + 6)
    iconHolder:Hide()
    header.iconHolder = iconHolder
    local icon = iconHolder:CreateTexture(nil, 'ARTWORK')
    icon:SetAllPoints()
    header.icon = icon
    icon:Hide()
    local iconMask = iconHolder:CreateMaskTexture()
    ApplyMask(iconMask, 'groupIconMask')
    icon:AddMaskTexture(iconMask)
    header.iconMask = iconMask

    local text = header:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    text:SetTextColor(unpack(EXFrames.Theme.text))
    text:SetJustifyH('LEFT')
    text:SetWordWrap(false)
    text:SetMaxLines(1)
    header.text = text

    local chevronButton = CreateFrame('Button', nil, header)
    chevronButton:SetFrameLevel(header:GetFrameLevel() + 6)
    header.chevronButton = chevronButton
    local chevron = chevronButton:CreateTexture(nil, 'OVERLAY')
    chevron:SetAllPoints()
    header.chevron = chevron

    local statusIcon = header:CreateTexture(nil, 'OVERLAY')
    statusIcon:Hide()
    header.statusIcon = statusIcon

    header.SetStatusIcon = function(self, key)
        if key and RECTS[key] then
            ApplyAtlas(self.statusIcon, key, false)
            self.statusIcon:Show()
        else
            self.statusIcon:Hide()
        end
        LayoutGroupContents(self)
    end

    local function ToggleCollapsed(self)
        local owner = self.owner
        if not owner or not self.groupKey then
            return
        end
        owner.groupCollapsed[self.groupKey] = not owner.groupCollapsed[self.groupKey]
        if owner.itemData then
            owner:AddItems(owner.itemData)
        end
    end

    chevronButton:SetScript('OnClick', function(_, mouseButton)
        if header.owner and (header.owner.dragging or header.owner.suppressClick) then
            return
        end
        if mouseButton == 'RightButton' then
            if header.contextMenuItems and #header.contextMenuItems > 0 and header.onShowContextMenu then
                header:onShowContextMenu()
            end
            return
        end
        ToggleCollapsed(header)
    end)
    chevronButton:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

    header.RefreshChrome = function(self)
        ApplyItemVisual(self, self.isActive, self:IsMouseOver())
    end

    header.SetActive = function(self, active)
        self.isActive = active and true or false
        self:RefreshChrome()
    end

    header.SetText = function(self, value)
        self.text:SetText(value or '')
    end

    header.SetExpanded = function(self, expanded)
        ApplyAtlas(self.chevron, expanded and 'chevronUp' or 'chevronDown', false)
    end

    header.SetGroupIcon = function(self, icon)
        if icon ~= nil and icon ~= '' then
            self.icon:SetTexture(icon)
            self.icon:SetTexCoord(0, 1, 0, 1)
            self.icon:Show()
            self.iconHolder:Show()
            self.iconShadow:Show()
        else
            self.icon:SetTexture(nil)
            self.icon:Hide()
            self.iconHolder:Hide()
            self.iconShadow:Hide()
        end
        LayoutGroupContents(self)
    end

    header:SetScript('OnEnter', function(self)
        self:RefreshChrome()
    end)

    header:SetScript('OnLeave', function(self)
        self:RefreshChrome()
    end)

    header:SetScript('OnMouseDown', function(self, mouseButton)
        if mouseButton ~= 'LeftButton' or not self.owner or not self.owner.reorderEnabled then
            return
        end
        if self.owner.ArmDrag then
            self.owner:ArmDrag(self)
        end
    end)

    header:SetScript('OnClick', function(self, mouseButton)
        if self.owner and (self.owner.dragging or self.owner.suppressClick) then
            return
        end
        if mouseButton == 'RightButton' then
            if self.contextMenuItems and #self.contextMenuItems > 0 and self.onShowContextMenu then
                self:onShowContextMenu()
            end
            return
        end
        if self.selectable and self.onItemClick and self.ID then
            self:onItemClick(self.ID)
            return
        end
        ToggleCollapsed(self)
    end)

    header:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    header:HookScript('OnSizeChanged', function(self)
        if self:GetWidth() <= 1 then
            return
        end
        LayoutGroupContents(self)
        self:RefreshChrome()
    end)

    ForwardMouseWheel(header)
    header:RefreshChrome()
    LayoutGroupContents(header)

    return header
end

local function CreateCategoryLabel(parent)
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetHeight(EXFrames:ScalePixel(20, parent))
    frame.isCategory = true

    local bg = frame:CreateTexture(nil, 'BACKGROUND')
    bg:SetTexture(EXFrames.assets.textures.solidWhite)
    bg:SetAllPoints()
    bg:SetVertexColor(unpack(DEFAULT_CATEGORY_BG))
    frame.bg = bg

    local text = frame:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
    text:SetTextColor(unpack(DEFAULT_CATEGORY_TEXT))
    text:SetJustifyH('LEFT')
    text:SetPoint('LEFT', 6, 0)
    text:SetPoint('RIGHT', -6, 0)
    frame.text = text

    frame.SetText = function(self, value)
        self.text:SetText(value or '')
    end

    frame.SetColors = function(self, bgColor, textColor)
        self.bg:SetVertexColor(unpack(bgColor or DEFAULT_CATEGORY_BG))
        self.text:SetTextColor(unpack(textColor or DEFAULT_CATEGORY_TEXT))
    end

    frame.SetActive = function() end

    ForwardMouseWheel(frame)

    return frame
end

local function LayoutActionButtonContents(button, pad)
    local hasIcon = button.icon:IsShown()
    local label = button.text:GetText()
    local hasText = label and label ~= ''
    local iconSize = ACTION_ICON[button.iconKey] or ACTION_ICON.plus
    local iconW = EXFrames:ScalePixel(iconSize[1], button)
    local iconH = EXFrames:ScalePixel(iconSize[2], button)
    button.icon:ClearAllPoints()
    button.text:ClearAllPoints()
    button.icon:SetSize(iconW, iconH)
    if hasIcon and hasText then
        button.icon:SetPoint('LEFT', pad, 0)
        button.text:SetPoint('LEFT', button.icon, 'RIGHT', pad, 0)
        button.text:SetPoint('RIGHT', -pad, 0)
        button.text:SetJustifyH('LEFT')
    elseif hasIcon then
        button.icon:SetPoint('CENTER')
    else
        button.text:SetPoint('LEFT', pad, 0)
        button.text:SetPoint('RIGHT', -pad, 0)
        button.text:SetJustifyH('LEFT')
    end
end

local function SetActionIcon(button, icon)
    button.icon:SetVertexColor(1, 1, 1, 1)
    button.iconKey = nil
    if icon == nil or icon == '' then
        button.icon:Hide()
        return
    end
    if type(icon) == 'table' then
        local path = icon.file or icon.texture
        if path then
            button.icon:SetTexture(path)
            button.icon:SetTexCoord(0, 1, 0, 1)
            button.icon:Show()
        else
            button.icon:Hide()
        end
        return
    end
    if type(icon) == 'string' and RECTS[icon] then
        button.iconKey = icon
        ApplyAtlas(button.icon, icon, false)
        button.icon:Show()
        return
    end
    button.icon:SetTexture(icon)
    button.icon:SetTexCoord(0, 1, 0, 1)
    button.icon:Show()
end

local function CreateActionButton(parent)
    local button = CreateFrame('Button', nil, parent)
    button:SetHeight(EXFrames:ScalePixel(ACTION_ROW, parent))
    button:SetFrameLevel(parent:GetFrameLevel() + 5)

    local icon = button:CreateTexture(nil, 'OVERLAY')
    icon:SetSize(EXFrames:ScalePixel(16, parent), EXFrames:ScalePixel(16, parent))
    icon:Hide()
    button.icon = icon

    local text = button:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    text:SetTextColor(unpack(EXFrames.Theme.textMuted))
    text:SetJustifyH('LEFT')
    text:SetWordWrap(false)
    text:SetMaxLines(1)
    button.text = text

    button.SetText = function(self, label)
        self.text:SetText(label or '')
        local row = self:GetParent()
        if row and row.LayoutButtons then
            row:LayoutButtons()
        end
    end

    button.SetOnClick = function(self, onClick)
        self.onClick = onClick
    end

    button.textColor = EXFrames.Theme.textMuted
    button.textHoverColor = EXFrames.Theme.white

    local function ApplyActionTextColor(self, hovered)
        local color = hovered and self.textHoverColor or self.textColor
        if color then
            self.text:SetTextColor(unpack(color))
        end
    end

    button.SetTextColor = function(self, color)
        if type(color) == 'table' then
            self.textColor = color
            ApplyActionTextColor(self, self:IsMouseOver())
        end
    end

    local function ShowActionTooltip(self)
        local label = self.text:GetText()
        if (label and label ~= '') or not self.tooltipText or self.tooltipText == '' then
            return
        end
        if not self.tooltip then
            self.tooltip = EXFrames:GetFrame('tooltip'):Create(self, { text = self.tooltipText })
        else
            self.tooltip.anchor = self
            self.tooltip:SetText(self.tooltipText)
        end
        self.tooltip:ShowTooltip()
    end

    local function HideActionTooltip(self)
        if self.tooltip then
            self.tooltip:HideTooltip()
        end
    end

    button.SetTooltip = function(self, text)
        self.tooltipText = text
        if self:IsMouseOver() then
            HideActionTooltip(self)
            ShowActionTooltip(self)
        end
    end

    button:SetScript('OnEnter', function(self)
        ApplyActionTextColor(self, true)
        ShowActionTooltip(self)
    end)

    button:SetScript('OnLeave', function(self)
        ApplyActionTextColor(self, false)
        HideActionTooltip(self)
    end)

    button.SetIcon = function(self, icon)
        SetActionIcon(self, icon)
        local row = self:GetParent()
        if row and row.LayoutButtons then
            row:LayoutButtons()
        end
    end

    button:SetScript('OnClick', function(self)
        if self.onClick then
            self:onClick(self)
        end
    end)

    ForwardMouseWheel(button)
    return button
end

local function CreateActionRow(parent)
    local row = CreateFrame('Frame', nil, parent)
    row:SetHeight(EXFrames:ScalePixel(ACTION_ROW, parent))
    row:Hide()
    row.buttons = {}

    local bg = row:CreateTexture(nil, 'BACKGROUND')
    bg:SetAllPoints()
    row.bg = bg

    local border = row:CreateTexture(nil, 'OVERLAY')
    border:SetAllPoints()
    row.border = border

    row.RefreshChrome = function(self)
        if self:GetWidth() <= 1 then
            return
        end
        ApplyAtlas(self.bg, 'actionBg', true)
        ApplyAtlas(self.border, 'actionBorder', true)
    end

    local function ActionButtonWidth(button, pad, height)
        local label = button.text:GetText()
        if not label or label == '' then
            return height
        end
        local iconW = 0
        if button.icon:IsShown() then
            local iconSize = ACTION_ICON[button.iconKey] or ACTION_ICON.plus
            iconW = EXFrames:ScalePixel(iconSize[1], button)
        end
        local width = pad + (iconW > 0 and (iconW + pad) or 0) + button.text:GetStringWidth() + pad
        return math.max(width, height)
    end

    row.LayoutButtons = function(self)
        local left, right = {}, {}
        for _, button in ipairs(self.buttons) do
            if button:IsShown() then
                if button.align == 'right' then
                    table.insert(right, button)
                else
                    table.insert(left, button)
                end
            end
        end
        if #left == 0 and #right == 0 then
            return
        end

        local pad = EXFrames:ScalePixel(6, self)
        local gap = EXFrames:ScalePixel(4, self)
        local rightGap = EXFrames:ScalePixel(1, self)
        local height = self:GetHeight()
        if height < 1 then
            height = EXFrames:ScalePixel(ACTION_ROW, self)
        end

        local level = self:GetFrameLevel() + 5
        if #left == 1 and #right == 0 then
            local button = left[1]
            local label = button.text:GetText()
            local hasText = label and label ~= ''
            button:SetFrameLevel(level)
            button:ClearAllPoints()
            if hasText then
                button:SetPoint('TOPLEFT', self, 'TOPLEFT', 0, 0)
                button:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', 0, 0)
            else
                button:SetPoint('LEFT', self, 'LEFT', 0, 0)
                button:SetSize(height, height)
            end
            LayoutActionButtonContents(button, pad)
            return
        end

        local x = 0
        for _, button in ipairs(left) do
            button:SetFrameLevel(level)
            button:ClearAllPoints()
            button:SetPoint('LEFT', self, 'LEFT', x, 0)
            button:SetSize(ActionButtonWidth(button, pad, height), height)
            LayoutActionButtonContents(button, pad)
            x = x + button:GetWidth() + gap
        end

        local rightX = pad
        for i = #right, 1, -1 do
            local button = right[i]
            local label = button.text:GetText()
            local hasText = label and label ~= ''
            local width = ActionButtonWidth(button, pad, height)
            if not hasText then
                local iconSize = ACTION_ICON[button.iconKey]
                if iconSize then
                    width = EXFrames:ScalePixel(iconSize[1] + 2, button)
                end
            end
            button:SetFrameLevel(level)
            button:ClearAllPoints()
            button:SetPoint('RIGHT', self, 'RIGHT', -rightX, 0)
            button:SetSize(width, height)
            LayoutActionButtonContents(button, pad)
            rightX = rightX + width + rightGap
        end
    end

    row:HookScript('OnSizeChanged', function(self)
        self:RefreshChrome()
        self:LayoutButtons()
    end)
    ForwardMouseWheel(row)
    return row
end

local function GetScrollbarGutter(scroll)
    local width = scroll.scrollbarWidth or 0
    local padding = scroll.scrollbarPadding or 0
    return width + padding * 2
end

local function ListNeedsScroll(viewport, listHeight)
    return viewport > 1 and (listHeight - viewport) > SCROLL_FIT_EPSILON
end

local function ListUsesDepth(items)
    for _, item in ipairs(items) do
        if item.depth ~= nil then
            return true
        end
    end
    return false
end

local function SameParent(a, b)
    return a == b or (not a and not b)
end

local function RevealActiveGroup(self, items)
    if not self.activeID then
        return
    end
    if ListUsesDepth(items) then
        local byID = {}
        for _, item in ipairs(items) do
            if item.ID then
                byID[item.ID] = item
            end
        end
        local current = byID[self.activeID]
        local seen = {}
        while current and current.parentID and not seen[current.parentID] do
            seen[current.parentID] = true
            self.groupCollapsed[current.parentID] = false
            current = byID[current.parentID]
        end
        return
    end
    local key
    for _, item in ipairs(items) do
        if item.type == 'group' then
            key = GroupKey(item)
        elseif item.ungrouped or item.type == 'category' then
            key = nil
        elseif item.ID == self.activeID and key then
            self.groupCollapsed[key] = false
            return
        end
    end
end

local function BuildExplicitRows(self, items)
    local rows = {}
    local hiddenParent = {}
    for _, item in ipairs(items) do
        local parentID = item.parentID
        local hidden = parentID and hiddenParent[parentID]
        if item.type == 'group' then
            local key = GroupKey(item)
            if hidden then
                hiddenParent[item.ID] = true
            else
                local collapsed = self.groupCollapsed[key] and true or false
                if collapsed then
                    hiddenParent[item.ID] = true
                end
                table.insert(rows, {
                    item = item,
                    kind = 'group',
                    key = key,
                    collapsed = collapsed,
                    indent = GROUP_INDENT * (item.depth or 0),
                    spacingAbove = item.spacingAbove or 0,
                })
            end
        elseif item.type == 'category' then
            if not hidden then
                table.insert(rows, {
                    item = item,
                    kind = 'category',
                    indent = GROUP_INDENT * (item.depth or 0),
                    spacingAbove = item.spacingAbove or 0,
                })
            end
        elseif not hidden then
            table.insert(rows, {
                item = item,
                kind = 'item',
                indent = GROUP_INDENT * (item.depth or 0),
                spacingAbove = item.spacingAbove or 0,
            })
        end
    end
    return rows
end

local function BuildVisibleRows(self, items)
    if ListUsesDepth(items) then
        return BuildExplicitRows(self, items)
    end
    local rows = {}
    local currentKey = nil
    local collapsed = false
    for _, item in ipairs(items) do
        if item.type == 'group' then
            currentKey = GroupKey(item)
            collapsed = self.groupCollapsed[currentKey] and true or false
            table.insert(rows, {
                item = item,
                kind = 'group',
                key = currentKey,
                collapsed = collapsed,
                indent = 0,
                spacingAbove = item.spacingAbove or 0,
            })
        elseif item.type == 'category' then
            currentKey = nil
            collapsed = false
            table.insert(rows, {
                item = item,
                kind = 'category',
                indent = 0,
                spacingAbove = item.spacingAbove or 0,
            })
        elseif item.ungrouped then
            currentKey = nil
            collapsed = false
            table.insert(rows, {
                item = item,
                kind = 'item',
                indent = 0,
                spacingAbove = item.spacingAbove or 0,
            })
        elseif not collapsed then
            table.insert(rows, {
                item = item,
                kind = 'item',
                indent = currentKey and GROUP_INDENT or 0,
                spacingAbove = 0,
            })
        end
    end
    return rows
end

local function MeasureRows(parent, rows, itemGap, itemInsetTop, style)
    local contentHeight = itemInsetTop
    local hasPrev = false
    for _, row in ipairs(rows) do
        local rowHeight = RowHeight(parent, row.kind, style)
        local spacing = EXFrames:ScalePixel(row.spacingAbove or 0, parent)
        if not hasPrev then
            contentHeight = contentHeight + rowHeight + spacing
        else
            contentHeight = contentHeight + rowHeight + itemGap + spacing
        end
        hasPrev = true
    end
    return contentHeight
end

local function firstSelectableID(items)
    for _, item in ipairs(items) do
        if IsSelectable(item) and item.ID then
            return item.ID
        end
    end
    return nil
end

local function buildContextMenuEntries(itemID, menuItems)
    local entries = {}
    for _, menuItem in ipairs(menuItems) do
        table.insert(entries, {
            text = menuItem.label or menuItem.text,
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
    return entries
end

local configure = function(f)
    f.items = {}
    f.groupHeaders = {}
    f.categoryLabels = {}
    f.groupCollapsed = {}
    f.onItemClick = nil
    f.activeID = nil
    f.leftWidth = DEFAULT_LEFT_WIDTH
    f.itemStyle = 'simple'

    local leftPanel = EXFrames:GetFrame('panel-frame'):Create()
    leftPanel:SetSubtleChrome()
    leftPanel:SetParent(f)
    f.leftPanel = leftPanel

    local rightPanel = EXFrames:GetFrame('panel-frame'):Create()
    rightPanel:SetSubtleChrome()
    rightPanel:SetParent(f)
    f.rightPanel = rightPanel

    local leftScroll = scrollFrame:Create()
    leftScroll:SetParent(leftPanel)
    -- Rows pad themselves for the bar, so the scroll child stays full width.
    leftScroll.scrollbarOverlay = true
    leftScroll.hideScrollbar = true
    leftScroll:HookScript('OnSizeChanged', function()
        if f.RefreshItemScrollLayout then
            f:RefreshItemScrollLayout()
        end
    end)
    f.leftScroll = leftScroll
    f.leftContainer = leftScroll.child

    local rightScroll = scrollFrame:Create()
    rightScroll:SetParent(rightPanel)
    f.scrollFrame = rightScroll
    f.container = rightScroll.child

    local actionRow = CreateActionRow(leftPanel)
    actionRow.scrollFrame = leftScroll
    f.actionRow = actionRow

    f.ApplyPanelLayout = function(self)
        local panelInset = EXFrames:ScalePixel(5, self)
        local leftWidth = EXFrames:ScalePixel(self.leftWidth or DEFAULT_LEFT_WIDTH, self)
        local scrollTopInset = EXFrames:ScalePixel(15, self.rightPanel)
        local scrollBottomInset = EXFrames:ScalePixel(8, self.rightPanel)
        local scrollSideInset = EXFrames:ScalePixel(5, self.rightPanel)
        local leftScrollInset = EXFrames:ScalePixel(3, self.leftPanel)
        local rowInset = leftScrollInset + EXFrames:ScalePixel(3, self.leftPanel)
        local actionShown = self.actionRow:IsShown()
        local actionHeight = actionShown and EXFrames:ScalePixel(ACTION_ROW, self.leftPanel) or 0
        local actionGap = actionShown and EXFrames:ScalePixel(4, self.leftPanel) or 0
        local listTop = leftScrollInset + actionHeight + actionGap

        self.leftPanel:ClearAllPoints()
        self.leftPanel:SetPoint('TOPLEFT', panelInset, -panelInset)
        self.leftPanel:SetPoint('BOTTOMRIGHT', self, 'BOTTOMLEFT', leftWidth, panelInset)

        self.rightPanel:ClearAllPoints()
        self.rightPanel:SetPoint('TOPLEFT', self.leftPanel, 'TOPRIGHT', panelInset, 0)
        self.rightPanel:SetPoint('BOTTOMRIGHT', -panelInset, panelInset)

        self.scrollFrame:ClearAllPoints()
        self.scrollFrame:SetPoint('TOPLEFT', scrollSideInset, -scrollTopInset)
        self.scrollFrame:SetPoint('BOTTOMRIGHT', -scrollSideInset, scrollBottomInset)

        self.actionRow:ClearAllPoints()
        self.actionRow:SetPoint('TOPLEFT', rowInset, -leftScrollInset)
        self.actionRow:SetPoint('TOPRIGHT', -rowInset, -leftScrollInset)
        self.actionRow:SetHeight(actionShown and actionHeight or EXFrames:ScalePixel(ACTION_ROW, self.leftPanel))

        self.leftScroll:ClearAllPoints()
        self.leftScroll:SetPoint('TOPLEFT', leftScrollInset, -listTop)
        self.leftScroll:SetPoint('TOPRIGHT', -leftScrollInset, -listTop)
        self.leftScroll:SetPoint('BOTTOMLEFT', leftScrollInset, leftScrollInset)
        self.leftScroll:SetPoint('BOTTOMRIGHT', -leftScrollInset, leftScrollInset)
    end

    f:ApplyPanelLayout()

    f.UpdateScroll = function(self)
        local width = math.max(1, EXFrames:ScalePixel(self.rightPanel:GetWidth() - 15, self.rightPanel))
        local viewportHeight = math.max(1, EXFrames:ScalePixel(self.rightPanel:GetHeight() - 25, self.rightPanel))
        local contentHeight = self.container:GetHeight()
        if self.container.exuiAutoSizeHeight and contentHeight > 0 then
            -- Use real content height only; padding to the viewport falsely enables the scrollbar after resizes.
            self.scrollFrame:UpdateScrollChild(width, contentHeight)
        else
            self.scrollFrame:UpdateScrollChild(width, viewportHeight)
        end
    end

    f.UpdateLeftScroll = function(self)
        -- Use the scroll frame viewport width, not the child (child is often 0 before sizing).
        local width = math.max(1, self.leftScroll:GetWidth())
        if width <= 1 then
            local inset = EXFrames:ScalePixel(6, self.leftPanel)
            width = math.max(1, EXFrames:ScalePixel(self.leftWidth or DEFAULT_LEFT_WIDTH, self) - inset)
        end
        -- Actual list height only — do not pad to the viewport or the bar can stick after layout changes.
        local contentHeight = math.max(1, self.leftContainer:GetHeight() or 0)
        self.leftScroll:UpdateScrollChild(width, contentHeight)
    end

    f.SetLeftWidth = function(self, width)
        self.leftWidth = width or DEFAULT_LEFT_WIDTH
        self:ApplyPanelLayout()
    end

    f.SetItemStyle = function(self, style)
        self.itemStyle = style == 'advanced' and 'advanced' or 'simple'
    end

    local function SyncActiveRows(id)
        for _, item in ipairs(f.items) do
            if item:IsShown() and not item.isCategory and not item.isGroup then
                item:SetActive(item.ID == id)
            end
        end
        for _, header in ipairs(f.groupHeaders) do
            if header:IsShown() then
                header:SetActive(header.selectable and header.ID == id)
            end
        end
    end

    f.onItemClick = function(self, id)
        listMenu:Hide()
        f.activeID = id
        SyncActiveRows(id)
        if f.onItemChange then
            f.onItemChange(id)
        end
    end

    f.ShowItemContextMenu = function(self, button)
        if not button or not button.contextMenuItems or #button.contextMenuItems == 0 then
            return
        end
        local entries = buildContextMenuEntries(button.ID, button.contextMenuItems)
        listMenu:ToggleAt(button, entries)
    end

    f.RefreshItemScrollLayout = function(self)
        if self.refreshingItemScroll or not self.itemData then
            return
        end
        local viewport = self.leftScroll:GetHeight() or 0
        local needsScroll = ListNeedsScroll(viewport, self.itemListHeight or 0)
        if needsScroll == self.itemsNeedScroll then
            return
        end
        self:AddItems(self.itemData)
    end

    f.AddItems = function(self, items)
        self.refreshingItemScroll = true
        self.itemData = items
        self.dragRows = {}
        self.placedRows = {}
        self.groupCollapsed = self.groupCollapsed or {}
        if self.HideDropMark then
            self:HideDropMark()
        end

        if not self.activeID or not self:_hasItemID(self.activeID, items) then
            self.activeID = firstSelectableID(items)
        end
        RevealActiveGroup(self, items)

        local style = self.itemStyle == 'advanced' and 'advanced' or 'simple'
        local rows = BuildVisibleRows(self, items)

        self:ApplyPanelLayout()
        -- Size the scroll child before anchoring items so TOPLEFT/TOPRIGHT stretch works.
        self:UpdateLeftScroll()

        for _, item in ipairs_reverse(self.items) do
            item:ClearAllPoints()
            item:Hide()
        end
        for _, header in ipairs_reverse(self.groupHeaders) do
            header:ClearAllPoints()
            header:Hide()
        end
        for _, label in ipairs_reverse(self.categoryLabels) do
            label:ClearAllPoints()
            label:Hide()
        end

        local prev = nil
        local prevIndent = 0
        local itemGap = EXFrames:ScalePixel(3, self.leftPanel)
        local itemInsetX = EXFrames:ScalePixel(3, self.leftPanel)
        local itemInsetTop = EXFrames:ScalePixel(5, self.leftPanel)
        local viewport = self.leftScroll:GetHeight() or 0
        local needsScroll = ListNeedsScroll(viewport, MeasureRows(self.leftPanel, rows, itemGap, itemInsetTop, style))
        local rightInset = itemInsetX + (needsScroll and GetScrollbarGutter(self.leftScroll) or 0)
        local firstRow, firstRowY, firstIndent
        local itemIndex = 0
        local groupIndex = 0
        local categoryIndex = 0
        local contentHeight = itemInsetTop

        local function Place(row, indent, spacingAbove)
            local spacing = EXFrames:ScalePixel(spacingAbove or 0, self.leftPanel)
            row:ClearAllPoints()
            if not prev then
                local topOffset = itemInsetTop + spacing
                firstRow = row
                firstRowY = -topOffset
                firstIndent = indent
                local left = itemInsetX + EXFrames:ScalePixel(indent, self.leftPanel)
                row:SetPoint('TOPLEFT', self.leftContainer, 'TOPLEFT', left, firstRowY)
                row:SetPoint('TOPRIGHT', self.leftContainer, 'TOPRIGHT', -rightInset, firstRowY)
                row.layoutFirst = true
                row.layoutLeft = left
                row.layoutRight = -rightInset
                row.layoutY = firstRowY
                contentHeight = contentHeight + row:GetHeight() + spacing
            else
                local gap = itemGap + spacing
                local leftDelta = EXFrames:ScalePixel(indent - prevIndent, self.leftPanel)
                row:SetPoint('TOPLEFT', prev, 'BOTTOMLEFT', leftDelta, -gap)
                row:SetPoint('TOPRIGHT', prev, 'BOTTOMRIGHT', 0, -gap)
                row.layoutFirst = false
                row.layoutPrev = prev
                row.layoutLeftDelta = leftDelta
                row.layoutGap = gap
                contentHeight = contentHeight + row:GetHeight() + gap
            end
            table.insert(self.placedRows, row)
            prev = row
            prevIndent = indent
        end

        for _, row in ipairs(rows) do
            local item = row.item
            if row.kind == 'category' then
                categoryIndex = categoryIndex + 1
                if not self.categoryLabels[categoryIndex] then
                    self.categoryLabels[categoryIndex] = CreateCategoryLabel(self.leftContainer)
                end
                local label = self.categoryLabels[categoryIndex]
                label.scrollFrame = self.leftScroll
                label:SetText(item.label)
                label:SetColors(item.bgColor, item.textColor)
                label:SetHeight(RowHeight(self.leftPanel, 'category', style))
                label:Show()
                Place(label, 0, row.spacingAbove)
            elseif row.kind == 'group' then
                groupIndex = groupIndex + 1
                if not self.groupHeaders[groupIndex] or self.groupHeaders[groupIndex].itemStyle ~= 'simple' then
                    if self.groupHeaders[groupIndex] then
                        self.groupHeaders[groupIndex]:Hide()
                        self.groupHeaders[groupIndex]:SetParent(nil)
                    end
                    self.groupHeaders[groupIndex] = CreateGroupHeader(self.leftContainer, 'simple')
                end
                local header = self.groupHeaders[groupIndex]
                header.scrollFrame = self.leftScroll
                header.owner = self
                header.groupKey = row.key
                header.ID = item.ID
                header.selectable = item.selectable and true or false
                header.onItemClick = self.onItemClick
                header:SetHeight(RowHeight(self.leftPanel, 'group', 'simple'))
                header:SetText(item.label)
                header:SetGroupIcon(item.icon)
                header:SetStatusIcon(item.statusIcon)
                header.contextMenuItems = item.contextMenuItems
                header.onShowContextMenu = function()
                    self:ShowItemContextMenu(header)
                end
                header:SetExpanded(not row.collapsed)
                header:SetActive(header.selectable and self.activeID ~= nil and self.activeID == item.ID)
                header.reorderItem = item
                header:Show()
                Place(header, row.indent or 0, row.spacingAbove)
                if item.depth ~= nil then
                    table.insert(self.dragRows, header)
                end
            else
                itemIndex = itemIndex + 1
                if not self.items[itemIndex] or self.items[itemIndex].itemStyle ~= style then
                    if self.items[itemIndex] then
                        self.items[itemIndex]:Hide()
                        self.items[itemIndex]:SetParent(nil)
                    end
                    self.items[itemIndex] = CreateItem(self.leftContainer, style)
                end
                local button = self.items[itemIndex]
                button.scrollFrame = self.leftScroll
                button.owner = self
                button.reorderItem = item
                button.ID = item.ID
                button:SetHeight(RowHeight(self.leftPanel, 'item', style))
                button:SetText(item.label)
                button:SetIcon(item.icon)
                button:SetSubText(item.sublabel)
                button:SetPreview(item.preview)
                button:SetStatusIcon(item.statusIcon)
                button.contextMenuItems = item.contextMenuItems
                button.onItemClick = self.onItemClick
                button.onShowContextMenu = function()
                    self:ShowItemContextMenu(button)
                end
                button:SetActive(self.activeID ~= nil and self.activeID == item.ID)
                button:Show()
                Place(button, row.indent, 0)
                if item.depth ~= nil then
                    table.insert(self.dragRows, button)
                end
            end
        end

        for i = itemIndex + 1, #self.items do
            self.items[i]:Hide()
            self.items[i].contextMenuItems = nil
            self.items[i].onShowContextMenu = nil
            self.items[i]:SetPreview(nil)
        end
        for i = groupIndex + 1, #self.groupHeaders do
            self.groupHeaders[i]:Hide()
            self.groupHeaders[i].owner = nil
        end
        for i = categoryIndex + 1, #self.categoryLabels do
            self.categoryLabels[i]:Hide()
        end

        local actualNeedsScroll = ListNeedsScroll(viewport, contentHeight)
        if actualNeedsScroll ~= needsScroll and firstRow then
            needsScroll = actualNeedsScroll
            rightInset = itemInsetX + (needsScroll and GetScrollbarGutter(self.leftScroll) or 0)
            local left = itemInsetX + EXFrames:ScalePixel(firstIndent or 0, self.leftPanel)
            firstRow:ClearAllPoints()
            firstRow:SetPoint('TOPLEFT', self.leftContainer, 'TOPLEFT', left, firstRowY)
            firstRow:SetPoint('TOPRIGHT', self.leftContainer, 'TOPRIGHT', -rightInset, firstRowY)
            firstRow.layoutLeft = left
            firstRow.layoutRight = -rightInset
            firstRow.layoutY = firstRowY
        end

        self.itemListHeight = contentHeight
        self.itemsNeedScroll = needsScroll
        self.leftScroll.hideScrollbar = not needsScroll

        -- Bottom padding must not by itself turn the bar on. Clamp when every row already fits.
        local childHeight = contentHeight + itemInsetTop
        if not needsScroll and viewport > 1 then
            childHeight = math.min(childHeight, viewport)
        end
        self.layoutChildHeight = math.max(childHeight, 1)
        self.leftContainer:SetHeight(self.layoutChildHeight)
        self:UpdateLeftScroll()
        self.refreshingItemScroll = false

        if not self.itemScrollRefreshQueued then
            self.itemScrollRefreshQueued = true
            C_Timer.After(0, function()
                self.itemScrollRefreshQueued = false
                if self:IsShown() and self.RefreshItemScrollLayout then
                    self:RefreshItemScrollLayout()
                end
            end)
        end

        if EXFrames.RefreshPixelPerfect then
            EXFrames:RefreshPixelPerfect()
        end
    end

    f._hasItemID = function(self, id, items)
        for _, item in ipairs(items) do
            if IsSelectable(item) and item.ID == id then
                return true
            end
        end
        return false
    end

    f.SetActiveItem = function(self, id)
        self.activeID = id
        local needsLayout = false
        if self.itemData then
            if ListUsesDepth(self.itemData) then
                local byID = {}
                for _, item in ipairs(self.itemData) do
                    if item.ID then
                        byID[item.ID] = item
                    end
                end
                local current = byID[id]
                local seen = {}
                while current and current.parentID and not seen[current.parentID] do
                    seen[current.parentID] = true
                    if self.groupCollapsed[current.parentID] then
                        needsLayout = true
                        break
                    end
                    current = byID[current.parentID]
                end
            else
                local key
                for _, item in ipairs(self.itemData) do
                    if item.type == 'group' then
                        key = GroupKey(item)
                    elseif item.ungrouped or item.type == 'category' then
                        key = nil
                    elseif item.ID == id and key and self.groupCollapsed[key] then
                        needsLayout = true
                        break
                    end
                end
            end
        end
        if needsLayout then
            self:AddItems(self.itemData)
        else
            SyncActiveRows(id)
        end
        if self.onItemChange then
            self.onItemChange(id)
        end
    end

    f.SetOnItemChange = function(self, callback)
        self.onItemChange = callback
    end

    f.SyncPreviewToggles = function(self, isEnabled)
        for _, item in ipairs(self.items) do
            if not item.isCategory and not item.isGroup and item.previewButton and item.previewButton:IsShown() then
                item:SetPreviewEnabled(isEnabled(item.ID))
            end
        end
    end

    f.SetContentActionButton = function(self, buttonOptions)
        if not buttonOptions then
            if self.contentActionButton then
                self.contentActionButton:Hide()
            end
            return
        end
        if not self.contentActionButton then
            local btn = EXFrames:GetFrame('simple-button'):Create(self.container)
            btn:SetHeight(EXFrames:ScalePixel(30, self))
            btn:SetFrameWidth(EXFrames:ScalePixel(140, self))
            btn:SetPoint('TOPRIGHT', self.container, 'TOPRIGHT', -EXFrames:ScalePixel(5, self.container), -EXFrames:ScalePixel(5, self.container))
            self.contentActionButton = btn
        end
        self.contentActionButton:Show()
        self.contentActionButton:SetOptionData({
            label = buttonOptions.text or buttonOptions.label,
            onClick = buttonOptions.onClick,
        })
    end

    f.SetActions = function(self, actions)
        actions = actions or {}
        if #actions == 0 then
            self:DisableExtraButton()
            return
        end
        for i, def in ipairs(actions) do
            local button = self.actionRow.buttons[i]
            if not button then
                button = CreateActionButton(self.actionRow)
                self.actionRow.buttons[i] = button
            end
            button:Show()
            button.align = def.align
            SetActionIcon(button, def.icon)
            button:SetText(def.text or def.label or '')
            button.tooltipText = def.tooltip
            button.textHoverColor = def.textHoverColor or EXFrames.Theme.white
            button:SetTextColor(def.textColor or EXFrames.Theme.textMuted)
            button:SetOnClick(def.onClick)
        end
        for i = #actions + 1, #self.actionRow.buttons do
            self.actionRow.buttons[i]:Hide()
            self.actionRow.buttons[i].align = nil
            self.actionRow.buttons[i].tooltipText = nil
            if self.actionRow.buttons[i].tooltip then
                self.actionRow.buttons[i].tooltip:HideTooltip()
            end
            self.actionRow.buttons[i]:SetOnClick(nil)
        end
        self.extraButton = self.actionRow.buttons[1]
        self.actionRow:Show()
        self:ApplyPanelLayout()
        self.actionRow:RefreshChrome()
        self.actionRow:LayoutButtons()
    end

    f.AddExtraButton = function(self, buttonOptions)
        if not buttonOptions then
            self:DisableExtraButton()
            return
        end
        if buttonOptions.actions then
            self:SetActions(buttonOptions.actions)
            return
        end
        self:SetActions({ buttonOptions })
    end

    f.DisableExtraButton = function(self)
        self.actionRow:Hide()
        for _, button in ipairs(self.actionRow.buttons) do
            button:Hide()
            button.tooltipText = nil
            if button.tooltip then
                button.tooltip:HideTooltip()
            end
            button:SetOnClick(nil)
        end
        self.extraButton = nil
        self:ApplyPanelLayout()
    end

    local DRAG_THRESHOLD = 8
    local EXPAND_HOVER_DELAY = 0.4

    local function CursorPoint(region)
        local x, y = GetCursorPosition()
        local scale = region:GetEffectiveScale()
        if not scale or scale == 0 then
            scale = 1
        end
        return x / scale, y / scale
    end

    local function NextSiblingID(items, item)
        local found = false
        for _, other in ipairs(items) do
            if not found then
                if other.ID == item.ID and SameParent(other.parentID, item.parentID) then
                    found = true
                end
            elseif other.depth ~= nil and other.type ~= 'category' and SameParent(other.parentID, item.parentID) then
                return other.ID
            end
        end
        return nil
    end

    local function FrameForID(rows, id)
        for _, frame in ipairs(rows) do
            if frame.reorderItem and frame.reorderItem.ID == id then
                return frame
            end
        end
        return nil
    end

    local function LastVisibleInSubtree(rows, groupID, items)
        local last = nil
        local inside = false
        local parentOf = {}
        for _, item in ipairs(items) do
            if item.ID then
                parentOf[item.ID] = item.parentID
            end
        end
        local function under(id)
            local seen = {}
            local current = id
            while current do
                if current == groupID then
                    return true
                end
                if seen[current] then
                    return false
                end
                seen[current] = true
                current = parentOf[current]
            end
            return false
        end
        for _, frame in ipairs(rows) do
            local item = frame.reorderItem
            if item and item.ID == groupID then
                inside = true
                last = frame
            elseif inside and item and under(item.ID) then
                last = frame
            elseif inside then
                break
            end
        end
        return last
    end

    local function DropIndex(items, dragID, parentID, beforeID)
        if beforeID == dragID then
            local saw = false
            for _, item in ipairs(items) do
                if not saw then
                    if item.ID == dragID and SameParent(item.parentID, parentID) then
                        saw = true
                    end
                elseif item.depth ~= nil and item.type ~= 'category' and SameParent(item.parentID, parentID) then
                    beforeID = item.ID
                    break
                end
            end
            if saw and beforeID == dragID then
                beforeID = nil
            end
        end
        local siblings = {}
        for _, item in ipairs(items) do
            if item.ID and item.ID ~= dragID and item.depth ~= nil and item.type ~= 'category' and SameParent(item.parentID, parentID) then
                siblings[#siblings + 1] = item.ID
            end
        end
        if not beforeID then
            return #siblings + 1
        end
        for index, id in ipairs(siblings) do
            if id == beforeID then
                return index
            end
        end
        return #siblings + 1
    end

    local function IsUnderGroup(items, ancestorID, nodeID)
        if not ancestorID or not nodeID then
            return false
        end
        local parentOf = {}
        for _, item in ipairs(items) do
            if item.ID then
                parentOf[item.ID] = item.parentID
            end
        end
        local seen = {}
        local current = nodeID
        while current do
            if current == ancestorID then
                return true
            end
            if seen[current] then
                return false
            end
            seen[current] = true
            current = parentOf[current]
        end
        return false
    end

    local dropLine = f.leftContainer:CreateTexture(nil, 'OVERLAY', nil, 7)
    dropLine:SetHeight(2)
    dropLine:SetColorTexture(unpack(EXFrames.Theme.accent))
    dropLine:Hide()
    f.dropLine = dropLine

    local dropHighlight = f.leftContainer:CreateTexture(nil, 'OVERLAY', nil, 6)
    local accent = EXFrames.Theme.accent
    dropHighlight:SetColorTexture(accent[1], accent[2], accent[3], 0.35)
    dropHighlight:Hide()
    f.dropHighlight = dropHighlight

    local ghost = CreateFrame('Frame', nil, UIParent)
    ghost:SetFrameStrata('TOOLTIP')
    ghost:SetHeight(32)
    ghost:Hide()
    local ghostBg = ghost:CreateTexture(nil, 'BACKGROUND')
    ghostBg:SetAllPoints()
    ghostBg:SetColorTexture(0.08, 0.08, 0.08, 0.92)
    local ghostText = ghost:CreateFontString(nil, 'OVERLAY')
    ghostText:SetFont(EXFrames.assets.font.default(), 13, 'OUTLINE')
    ghostText:SetTextColor(unpack(EXFrames.Theme.text))
    ghostText:SetPoint('LEFT', 10, 0)
    ghostText:SetPoint('RIGHT', -10, 0)
    ghostText:SetJustifyH('LEFT')
    ghost.text = ghostText
    f.dragGhost = ghost

    local watcher = CreateFrame('Frame', nil, f)
    watcher:Hide()
    f.dragWatcher = watcher

    f.ClearDropGap = function(self)
        self.dropGapFrame = nil
        for _, row in ipairs(self.placedRows or {}) do
            if row.layoutFirst then
                row:SetPoint('TOPLEFT', self.leftContainer, 'TOPLEFT', row.layoutLeft, row.layoutY)
                row:SetPoint('TOPRIGHT', self.leftContainer, 'TOPRIGHT', row.layoutRight, row.layoutY)
            elseif row.layoutPrev then
                row:SetPoint('TOPLEFT', row.layoutPrev, 'BOTTOMLEFT', row.layoutLeftDelta, -row.layoutGap)
                row:SetPoint('TOPRIGHT', row.layoutPrev, 'BOTTOMRIGHT', 0, -row.layoutGap)
            end
        end
        if self.layoutChildHeight then
            self.leftContainer:SetHeight(self.layoutChildHeight)
        end
    end

    f.HideDropMark = function(self)
        self.dropLine:Hide()
        self.dropHighlight:Hide()
        if self.ClearDropGap then
            self:ClearDropGap()
        end
    end

    f.CancelDrag = function(self)
        self.dragging = nil
        self.dragArm = nil
        self.dropTarget = nil
        self.expandHoverID = nil
        self.dragGhost:Hide()
        self:HideDropMark()
        self.dragWatcher:Hide()
    end

    f.SetReorderEnabled = function(self, enabled)
        self.reorderEnabled = enabled and true or false
        if not self.reorderEnabled then
            self:CancelDrag()
        end
    end

    f.IsReorderEnabled = function(self)
        return self.reorderEnabled and true or false
    end

    f.SetOnReorder = function(self, callback)
        self.onReorder = callback
    end

    f.ArmDrag = function(self, row)
        if self.dragging or self.dragArm or not self.reorderEnabled then
            return
        end
        local item = row.reorderItem
        if not item or item.depth == nil or not item.ID or item.type == 'category' then
            return
        end
        local x, y = GetCursorPosition()
        self.dragArm = {
            id = item.ID,
            isGroup = item.type == 'group',
            label = item.label,
            startX = x,
            startY = y,
        }
        self.dragWatcher:Show()
    end

    f.HitDropTarget = function(self)
        local rows = self.dragRows
        local items = self.itemData
        if not rows or not items or #rows == 0 then
            return nil
        end
        local _, cursorY = CursorPoint(rows[1])
        local firstTop = rows[1]:GetTop()
        if firstTop and cursorY >= firstTop then
            local item = rows[1].reorderItem
            return {
                parentID = item.parentID,
                beforeID = item.ID,
                lineFrame = rows[1],
                lineAt = 'top',
            }
        end

        for _, frame in ipairs(rows) do
            local top, bottom = frame:GetTop(), frame:GetBottom()
            local item = frame.reorderItem
            if top and bottom and item and cursorY <= top and cursorY >= bottom then
                local height = top - bottom
                if item.type == 'group' and height > 0 then
                    local fromTop = top - cursorY
                    if fromTop > height * 0.28 and fromTop < height * 0.72 then
                        return {
                            intoGroup = true,
                            parentID = item.ID,
                            beforeID = nil,
                            highlight = frame,
                        }
                    end
                end
                if cursorY >= (top + bottom) / 2 then
                    return {
                        parentID = item.parentID,
                        beforeID = item.ID,
                        lineFrame = frame,
                        lineAt = 'top',
                    }
                end
                local nextID = NextSiblingID(items, item)
                local nextFrame = nextID and FrameForID(rows, nextID)
                if nextFrame then
                    return {
                        parentID = item.parentID,
                        beforeID = nextID,
                        lineFrame = nextFrame,
                        lineAt = 'top',
                    }
                end
                local anchor = frame
                if item.type == 'group' then
                    anchor = LastVisibleInSubtree(rows, item.ID, items) or frame
                end
                return {
                    parentID = item.parentID,
                    beforeID = nextID,
                    lineFrame = anchor,
                    lineAt = 'bottom',
                }
            end
        end

        for index = 1, #rows - 1 do
            local bottom = rows[index]:GetBottom()
            local nextTop = rows[index + 1]:GetTop()
            if bottom and nextTop and cursorY < bottom and cursorY > nextTop then
                local item = rows[index + 1].reorderItem
                return {
                    parentID = item.parentID,
                    beforeID = item.ID,
                    lineFrame = rows[index + 1],
                    lineAt = 'top',
                }
            end
        end

        local last = rows[#rows].reorderItem
        local nextID = NextSiblingID(items, last)
        local anchor = rows[#rows]
        if last.type == 'group' then
            anchor = LastVisibleInSubtree(rows, last.ID, items) or anchor
        end
        return {
            parentID = last.parentID,
            beforeID = nextID,
            lineFrame = anchor,
            lineAt = 'bottom',
        }
    end

    local function NextPlacedRow(rows, frame)
        for index, row in ipairs(rows or {}) do
            if row == frame then
                return rows[index + 1]
            end
        end
        return nil
    end

    f.ShowDropMark = function(self, target)
        self.dropLine:Hide()
        self.dropHighlight:Hide()
        self:ClearDropGap()
        if not target then
            return
        end
        if target.highlight then
            self.dropHighlight:ClearAllPoints()
            self.dropHighlight:SetAllPoints(target.highlight)
            self.dropHighlight:Show()
            return
        end
        local frame = target.lineFrame
        if not frame then
            return
        end
        local extra = EXFrames:ScalePixel(8, self.leftPanel)
        local shiftFrame = frame
        if target.lineAt == 'bottom' then
            shiftFrame = NextPlacedRow(self.placedRows, frame)
        end
        if shiftFrame then
            if shiftFrame.layoutFirst then
                shiftFrame:SetPoint('TOPLEFT', self.leftContainer, 'TOPLEFT', shiftFrame.layoutLeft, shiftFrame.layoutY - extra)
                shiftFrame:SetPoint('TOPRIGHT', self.leftContainer, 'TOPRIGHT', shiftFrame.layoutRight, shiftFrame.layoutY - extra)
            elseif shiftFrame.layoutPrev then
                local gap = (shiftFrame.layoutGap or 0) + extra
                shiftFrame:SetPoint('TOPLEFT', shiftFrame.layoutPrev, 'BOTTOMLEFT', shiftFrame.layoutLeftDelta, -gap)
                shiftFrame:SetPoint('TOPRIGHT', shiftFrame.layoutPrev, 'BOTTOMRIGHT', 0, -gap)
            end
            self.dropGapFrame = shiftFrame
            self.dropLine:ClearAllPoints()
            self.dropLine:SetPoint('BOTTOMLEFT', shiftFrame, 'TOPLEFT', 0, extra * 0.5)
            self.dropLine:SetPoint('BOTTOMRIGHT', shiftFrame, 'TOPRIGHT', 0, extra * 0.5)
        else
            self.dropLine:ClearAllPoints()
            self.dropLine:SetPoint('TOPLEFT', frame, 'BOTTOMLEFT', 0, -extra * 0.5)
            self.dropLine:SetPoint('TOPRIGHT', frame, 'BOTTOMRIGHT', 0, -extra * 0.5)
        end
        if self.layoutChildHeight then
            self.leftContainer:SetHeight(self.layoutChildHeight + extra)
        end
        self.dropLine:Show()
    end

    f.UpdateDrag = function(self)
        local arm = self.dragArm
        if not self.dragging then
            if not arm then
                return
            end
            local x, y = GetCursorPosition()
            local dx = x - arm.startX
            local dy = y - arm.startY
            if dx * dx + dy * dy < DRAG_THRESHOLD * DRAG_THRESHOLD then
                return
            end
            self.dragging = arm
            self.dragGhost.text:SetText(arm.label or '')
            self.dragGhost:SetWidth(math.max(96, self.dragGhost.text:GetStringWidth() + 28))
            self.dragGhost:Show()
        end

        local cursorX, cursorY = CursorPoint(UIParent)
        self.dragGhost:ClearAllPoints()
        self.dragGhost:SetPoint('LEFT', UIParent, 'BOTTOMLEFT', cursorX + 28, cursorY)

        local target = self:HitDropTarget()
        local drag = self.dragging
        if target and drag.isGroup and (target.parentID == drag.id or IsUnderGroup(self.itemData, drag.id, target.parentID)) then
            target = nil
        end
        if target and target.intoGroup and self.groupCollapsed[target.parentID] then
            if self.expandHoverID ~= target.parentID then
                self.expandHoverID = target.parentID
                self.expandHoverAt = GetTime()
            elseif GetTime() - (self.expandHoverAt or 0) >= EXPAND_HOVER_DELAY then
                self.groupCollapsed[target.parentID] = false
                self.expandHoverID = nil
                self:AddItems(self.itemData)
                target = self:HitDropTarget()
                if target and drag.isGroup and (target.parentID == drag.id or IsUnderGroup(self.itemData, drag.id, target.parentID)) then
                    target = nil
                end
            end
        else
            self.expandHoverID = nil
        end
        self.dropTarget = target
        self:ShowDropMark(target)
    end

    f.CommitDrag = function(self)
        local drag = self.dragging
        local target = self.dropTarget
        self.dragging = nil
        self.dragArm = nil
        self.dropTarget = nil
        self.expandHoverID = nil
        self.suppressClick = true
        self.dragGhost:Hide()
        self:HideDropMark()
        if not drag or not target or not self.onReorder or not self.itemData then
            return
        end
        if drag.isGroup and (target.parentID == drag.id or IsUnderGroup(self.itemData, drag.id, target.parentID)) then
            return
        end
        local index = DropIndex(self.itemData, drag.id, target.parentID, target.beforeID)
        self.onReorder(drag.id, drag.isGroup, target.parentID, index)
    end

    watcher:SetScript('OnUpdate', function()
        if IsMouseButtonDown('LeftButton') then
            f:UpdateDrag()
            return
        end
        if f.dragging then
            f:CommitDrag()
            return
        end
        f.dragArm = nil
        f.suppressClick = nil
        watcher:Hide()
    end)

    f:HookScript('OnHide', function(self)
        self:CancelDrag()
    end)

    f.Destroy = function(self)
        listMenu:Hide()
        self:CancelDrag()
        self.reorderEnabled = false
        self.onReorder = nil
        self.suppressClick = nil
        self:DisableExtraButton()
        if self.contentActionButton then
            self.contentActionButton:Hide()
        end
        self.activeID = nil
        self.itemData = nil
        self.groupCollapsed = {}
        self.itemStyle = 'simple'
        self.refreshingItemScroll = false
        if self.scrollFrame then
            self.scrollFrame:Reset()
        end
        if self.leftScroll then
            self.leftScroll:Reset()
        end
        self:ClearAllPoints()
        self:Hide()
        splitOptions.pool:Release(self)
    end

    f.configured = true
end

---@param self ExalityFramesSplitOptionsFrame
---@return Frame
splitOptions.Create = function(self)
    local f = self.pool:Acquire()
    if not f.configured then
        configure(f)
    end

    f.itemStyle = 'simple'
    f.groupCollapsed = {}
    f.leftWidth = DEFAULT_LEFT_WIDTH
    f.reorderEnabled = false
    f.dragging = nil
    f.dragArm = nil
    f.dropTarget = nil
    f.suppressClick = nil
    f.onReorder = nil
    f.dragRows = {}
    if f.dragGhost then
        f.dragGhost:Hide()
    end
    if f.HideDropMark then
        f:HideDropMark()
    end
    if f.dragWatcher then
        f.dragWatcher:Hide()
    end
    f:DisableExtraButton()

    if f.scrollFrame then
        f.scrollFrame:Reset()
    end
    if f.leftScroll then
        f.leftScroll:Reset()
    end

    f:Show()
    return f
end

EXFrames.FrameBase.StandardizeCreate(splitOptions)
