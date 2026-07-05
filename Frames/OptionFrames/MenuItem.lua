local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesMenuItemOptions : {onClick: function}

---@class ExalityFramesMenuItem
local menuItem = EXFrames:GetFrame('menu-item')

menuItem.pool = {}

menuItem.Init = function(self)
    self.pool = CreateFramePool('Button', UIParent)
end

local function StyleButton(f, isMain)
    local th = EXFrames.Theme

    local bg = f:CreateTexture(nil, 'BACKGROUND', nil, 1)
    bg:SetTexture(EXFrames.assets.textures.ui.menuItemBg)
    bg:SetVertexColor(unpack(th.backgroundDeep))
    bg:SetTextureSliceMargins(6, 6, 6, 6)
    bg:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    bg:SetAllPoints()
    f.bg = bg

    local bg2 = f:CreateTexture(nil, 'BACKGROUND', nil, 0)
    bg2:SetTexture(EXFrames.assets.textures.ui.menuItemBg)
    bg2:SetVertexColor(unpack(th.accent))
    bg2:SetTextureSliceMargins(27, 27, 27, 27)
    bg2:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    bg2:SetAllPoints()
    f.bg2 = bg2
    bg2:Hide()

    local borderOverlay = f:CreateTexture(nil, 'OVERLAY', nil, 1)
    borderOverlay:SetTexture(EXFrames.assets.textures.ui.menuItemBorder)
    borderOverlay:SetVertexColor(unpack(th.border))
    borderOverlay:SetTextureSliceMargins(6, 6, 6, 6)
    borderOverlay:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    borderOverlay:SetPoint('TOPLEFT', bg, 'TOPLEFT')
    borderOverlay:SetPoint('BOTTOMRIGHT', bg, 'BOTTOMRIGHT')

    local border = f:CreateTexture(nil, 'ARTWORK')
    border:SetTexture(EXFrames.assets.textures.menuItem.border)
    border:SetTextureSliceMargins(6, 6, 0, 6)
    border:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    border:SetVertexColor(unpack(th.border))
    border:SetPoint('TOPLEFT', bg, 'TOPLEFT')
    border:SetPoint('BOTTOM', bg, 'BOTTOM')
    border:SetWidth(EXFrames:ScalePixel(5, f))
    f.border = border

    local glow = f:CreateTexture(nil, 'BORDER')
    glow:SetTexture(EXFrames.assets.textures.menuItem.glow)
    glow:SetVertexColor(unpack(th.accent))
    glow:SetTextureSliceMargins(10, 10, 10, 10)
    glow:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    glow:SetPoint('TOPLEFT', bg, 'TOPLEFT')
    glow:SetPoint('BOTTOM', bg, 'BOTTOM')
    glow:SetWidth(EXFrames:ScalePixel(60, f))
    glow:Hide()
    f.glow = glow

    local text = f:CreateFontString(nil, 'OVERLAY')
    text:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    text:SetPoint('LEFT', bg, 'LEFT', 10, 0)
    text:SetWidth(0)
    f.text = text

    if (isMain) then
        local expand = CreateFrame('Button', nil, f)
        expand:SetPropagateMouseClicks(true)
        expand:SetPropagateMouseMotion(true)
        expand:EnableMouse(false)
        expand:SetSize(16, 16)
        expand:SetPoint('RIGHT', bg, 'RIGHT', -10, 0)

        local expandBg = expand:CreateTexture(nil, 'BACKGROUND')
        expandBg:SetTexture(EXFrames.assets.textures.solidWhite)
        expandBg:SetVertexColor(unpack(EXFrames.Theme.backgroundPanel))
        expandBg:SetAllPoints()
        expand.bg = expandBg

        local expandIcon = expand:CreateTexture(nil, 'ARTWORK')
        expandIcon:SetTexture(EXFrames.assets.textures.menuItem.plus)
        expandIcon:SetSize(8, 8)
        expandIcon:SetPoint('CENTER')
        expand.icon = expandIcon

        f.expand = expand

        expand:Hide()
    end

    f:SetScript('OnEnter', function(self)
        self.bg:ClearAllPoints()
        self.bg:SetPoint('TOPLEFT', -2, 2)
        self.bg:SetPoint('BOTTOMRIGHT', -2, 2)
        self.bg2:Show()
    end)

    f:SetScript('OnLeave', function(self)
        self.bg:ClearAllPoints()
        self.bg:SetAllPoints()
        self.bg2:Hide()
    end)
end

local function ConfigureFrame(f)
    EXFrames.utils.addObserver(f)
    f.isSelected = false
    f.isExpanded = false
    f.isExpandable = false
    f.subMenuItems = {}
    f.subButtons = {}
    f.data = nil

    local mainButton = CreateFrame('Button', nil, f)
    mainButton:SetHeight(30)
    mainButton:SetPoint('TOPLEFT')
    mainButton:SetPoint('RIGHT')
    StyleButton(mainButton, true)
    f.main = mainButton
    mainButton.__owner = f

    mainButton:SetScript('OnClick', function(self)
        if (self.__owner.onClick) then
            self.__owner:onClick()
        end

        if (self.__owner.isExpandable) then
            self.__owner:SetValue('isExpanded', not self.__owner.isExpanded)
        end

        EXFrames:Callback('menuItemClick')
    end)

    f.SetText = function(self, text)
        self.main.text:SetText(text)
    end

    f.SetSelected = function(self, value)
        if (self.isExpandable) then
            local found = false
            for _, btn in ipairs(self.subButtons) do
                local eq = btn.data:GetName() == value
                btn:SetValue('isSelected', eq)
                if (eq) then
                    self:SetValue('isSelected', true)
                    found = true
                end
            end
            if (not found) then
                self:SetValue('isSelected', false)
            end
        else
            self:SetValue('isSelected', self.data:GetName() == value)
        end
    end

    local function CreateSubButton(f)
        local subButton = CreateFrame('Button', nil, f)
        EXFrames.utils.addObserver(subButton)
        subButton.data = {}
        subButton:SetHeight(30)
        subButton:SetPoint('RIGHT')
        StyleButton(subButton, false)
        subButton.__owner = f
        subButton.onClick = nil
        subButton.isSelected = false

        subButton.bg:SetVertexColor(unpack(EXFrames.Theme.backgroundLight))

        subButton:Observe('isSelected', function(selected, _, _, self)
            if (selected) then
                self.glow:Show()
                self.border:SetVertexColor(unpack(EXFrames.Theme.borderActive))
            else
                self.glow:Hide()
                self.border:SetVertexColor(unpack(EXFrames.Theme.border))
            end
        end)

        subButton:SetScript('OnClick', function(self)
            if (self.onClick) then
                self:onClick()
            end
            EXFrames:Callback('menuItemClick')
        end)

        return subButton
    end

    f.Expand = function(self)
        for _, btn in ipairs(self.subButtons) do
            btn:ClearPoint('TOPLEFT')
            btn.onClick = nil
        end
        table.sort(self.subMenuItems, function(a, b) return a.order < b.order end)

        for idx, item in ipairs(self.subMenuItems) do
            if (not self.subButtons[idx]) then
                self.subButtons[idx] = CreateSubButton(self)
            end
            self.subButtons[idx].text:SetText(item.name)
            self.subButtons[idx].onClick = item.onClick
            self.subButtons[idx].data = item.data

            local prev = self.subButtons[idx - 1]
            if (prev) then
                self.subButtons[idx]:SetPoint('TOPLEFT', prev, 'BOTTOMLEFT', 0, -3)
            else
                self.subButtons[idx]:SetPoint('TOPLEFT', self.main, 'BOTTOMLEFT', 15, -3)
            end
        end

        self:SetHeight(30 * (#self.subMenuItems + 1) + (#self.subMenuItems) * 3)
    end

    f.Collapse = function(self)
        for _, btn in ipairs(self.subButtons) do
            btn:ClearPoint('TOPLEFT')
            btn.onClick = nil
        end
        self:SetHeight(30)
    end

    f.SetExpandable = function(self, expandable)
        self.isExpandable = expandable
        self.main.expand:SetShown(expandable)
    end

    f:Observe('isSelected', function(selected, _, _, self)
        if (selected) then
            self.main.glow:Show()
            self.main.border:SetVertexColor(unpack(EXFrames.Theme.borderActive))
        else
            self.main.glow:Hide()
            self.main.border:SetVertexColor(unpack(EXFrames.Theme.border))
        end
    end)

    f:Observe('isExpanded', function(expanded, _, _, self)
        if (expanded) then
            self:Expand()
            self.main.expand.icon:SetTexture(EXFrames.assets.textures.menuItem.minus)
        else
            self:Collapse()
            self.main.expand.icon:SetTexture(EXFrames.assets.textures.menuItem.plus)
        end
    end)

    f.SetSubMenuItems = function(self, items)
        self.subMenuItems = items
    end

    f.SetOnClick = function(self, onClick)
        f.onClick = onClick
    end

    f.SetData = function(self, data)
        self.data = data
    end

    f:SetHeight(30) -- TODO: need to calculate this when expanded

    f.configured = true
end

---@param self ExalityFramesMenuItem
---@param parent Frame
---@return Frame
menuItem.Create = function(self, parent)
    local f = self.pool:Acquire()
    if (not f.configured) then
        ConfigureFrame(f)
    end

    f.Destroy = function(self)
        self.data = nil
        menuItem.pool:Release(self)
    end

    if (parent) then
        f:SetParent(parent)
    else
        f:SetParent(nil)
    end

    f:Show()
    return f
end
