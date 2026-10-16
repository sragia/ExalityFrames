local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesIconInput
local iconInput = EXFrames:GetFrame('icon-input')

iconInput.pool = {}
iconInput.DEFAULT_ICON = 134400 -- INV_Misc_QuestionMark

iconInput.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

local QUESTION_MARK = iconInput.DEFAULT_ICON
local ICON_SIZE = 28
local ICON_PAD = 4
local ICON_COLUMNS = 8
local ICON_POOL_EXTRA_ROWS = 2

local popup = nil

local function CellSize()
    return ICON_SIZE + ICON_PAD
end

local function NormalizeIcon(icon)
    if type(icon) == 'number' and icon > 0 then
        return math.floor(icon)
    end
    if type(icon) == 'string' then
        local asNumber = tonumber(icon)
        if asNumber and asNumber > 0 then
            return math.floor(asNumber)
        end
        local path = icon
        local lower = path:lower():gsub('/', '\\')
        if lower:find('inv_misc_questionmark', 1, true) then
            return QUESTION_MARK
        end
        if not lower:find('\\', 1, true) then
            path = 'Interface\\Icons\\' .. path
        end
        if GetFileIDFromPath then
            local fileID = GetFileIDFromPath(path)
            if type(fileID) == 'number' and fileID > 0 then
                return fileID
            end
        end
    end
    return QUESTION_MARK
end

local function SelectorAvailable()
    return type(IconDataProviderMixin) == 'table' and type(CreateAndInitFromMixin) == 'function'
end

local function ReleaseProvider(frame)
    if frame.iconProvider then
        frame.iconProvider:Release()
        frame.iconProvider = nil
    end
    frame.iconCount = 0
    frame.totalIconCount = 0
    frame.indexMap = nil
    frame.iconNames = nil
    frame.lastStartRow = -1
    frame.lastViewHeight = nil
end

local function AcquireIconButton(frame, index)
    local button = frame.iconButtons[index]
    if button then
        return button
    end
    button = CreateFrame('Button', nil, frame.iconScroll.child)
    button:SetSize(ICON_SIZE, ICON_SIZE)
    button.Texture = button:CreateTexture(nil, 'ARTWORK')
    button.Texture:SetAllPoints()
    button.border = EXFrames:AddPixelPerfectBorder(button, 1, { register = false })
    button.border:SetBorderColor(unpack(EXFrames.Theme.border))
    button:SetScript('OnClick', function(btn)
        local accept = frame.onAccept
        frame.onAccept = nil
        frame.owner = nil
        frame:Hide()
        if accept then
            accept(NormalizeIcon(btn.iconValue))
        end
    end)
    frame.iconButtons[index] = button
    return button
end

local function CompactSearch(text)
    return (text or ''):lower():gsub('[%s_%-\\/%.]+', '')
end

local function IconSearchText(icon)
    local parts = {}
    if type(icon) == 'number' then
        parts[#parts + 1] = tostring(icon)
        if GetFilenameFromFileDataID then
            local filename = GetFilenameFromFileDataID(icon)
            if type(filename) == 'string' and filename ~= '' then
                parts[#parts + 1] = filename
            end
        end
    elseif type(icon) == 'string' then
        parts[#parts + 1] = icon
    end
    return CompactSearch(table.concat(parts, ' '))
end

local function EnsureSearchNames(frame)
    if frame.iconNames or not frame.iconProvider then
        return
    end
    local names = {}
    local total = frame.totalIconCount or 0
    for index = 1, total do
        names[index] = IconSearchText(frame.iconProvider:GetIconByIndex(index))
    end
    frame.iconNames = names
end

local function ProviderIndex(frame, visualIndex)
    if frame.indexMap then
        return frame.indexMap[visualIndex]
    end
    return visualIndex
end

local function UpdateIconExtent(frame, scrollToSelected)
    local cell = CellSize()
    local count = frame.iconCount or 0
    local rows = math.max(1, math.ceil(count / ICON_COLUMNS))
    local contentHeight = count > 0 and (rows * cell) or 1
    local scroll = frame.iconScroll
    if not scroll.iconExtent then
        local extent = CreateFrame('Frame', nil, scroll.child)
        extent:SetWidth(1)
        scroll.iconExtent = extent
    end
    scroll:Reset()
    scroll.iconExtent:ClearAllPoints()
    scroll.iconExtent:SetPoint('TOPLEFT', scroll.child, 'TOPLEFT', 0, 0)
    scroll.iconExtent:SetHeight(contentHeight)
    scroll.iconExtent:Show()
    scroll.child:SetHeight(contentHeight)
    scroll:UpdateScrollChild(ICON_COLUMNS * cell, contentHeight)

    if scrollToSelected and count > 0 then
        local selected = frame.selectedIcon
        local total = frame.indexMap and #frame.indexMap or count
        for visualIndex = 1, total do
            local icon = frame.iconProvider:GetIconByIndex(ProviderIndex(frame, visualIndex))
            if NormalizeIcon(icon) == selected then
                local row = math.floor((visualIndex - 1) / ICON_COLUMNS)
                scroll:SetVerticalScroll(row * cell)
                break
            end
        end
    end
    frame.lastStartRow = -1
    frame.lastViewHeight = nil
end

local RefreshVisibleIcons

local function ApplyIconFilter(frame)
    local query = CompactSearch(frame.searchBox and frame.searchBox:GetText())
    local total = frame.totalIconCount or 0
    if query == '' then
        frame.indexMap = nil
        frame.iconCount = total
    else
        EnsureSearchNames(frame)
        local map = {}
        local names = frame.iconNames or {}
        for index = 1, total do
            local name = names[index]
            if name and name:find(query, 1, true) then
                map[#map + 1] = index
            end
        end
        frame.indexMap = map
        frame.iconCount = #map
    end
    UpdateIconExtent(frame, false)
    RefreshVisibleIcons(frame, true)
end

RefreshVisibleIcons = function(frame, force)
    local scroll = frame.iconScroll
    if not scroll or not frame.iconProvider then
        return
    end
    if frame.iconCount <= 0 then
        for _, button in ipairs(frame.iconButtons) do
            button:Hide()
        end
        return
    end
    local viewHeight = scroll:GetHeight()
    if viewHeight < 1 and scroll.content then
        viewHeight = scroll.content:GetHeight()
    end
    if viewHeight < 1 then
        viewHeight = 1
    end
    local cell = CellSize()
    local offset = scroll.scrollOffset or 0
    local startRow = math.max(0, math.floor(offset / cell) - 1)
    if not force and startRow == frame.lastStartRow and viewHeight == frame.lastViewHeight then
        return
    end
    frame.lastStartRow = startRow
    frame.lastViewHeight = viewHeight
    local visibleRows = math.ceil(viewHeight / cell) + ICON_POOL_EXTRA_ROWS
    local startIndex = startRow * ICON_COLUMNS + 1
    local endIndex = math.min(frame.iconCount, (startRow + visibleRows) * ICON_COLUMNS)
    local poolSize = visibleRows * ICON_COLUMNS

    for poolIndex = 1, poolSize do
        local iconIndex = startIndex + poolIndex - 1
        local button = AcquireIconButton(frame, poolIndex)
        if iconIndex <= endIndex then
            local icon = frame.iconProvider:GetIconByIndex(ProviderIndex(frame, iconIndex))
            button.iconValue = icon
            button.Texture:SetTexture(icon)
            local col = (iconIndex - 1) % ICON_COLUMNS
            local row = math.floor((iconIndex - 1) / ICON_COLUMNS)
            button:ClearAllPoints()
            button:SetPoint('TOPLEFT', scroll.child, 'TOPLEFT', col * cell, -row * cell)
            button:Show()
            local selected = NormalizeIcon(icon) == frame.selectedIcon
            button.border:SetBorderColor(unpack(selected and EXFrames.Theme.accent or EXFrames.Theme.border))
        else
            button:Hide()
        end
    end
    for index = poolSize + 1, #frame.iconButtons do
        frame.iconButtons[index]:Hide()
    end
end

local function BuildIcons(frame, selectedIcon)
    ReleaseProvider(frame)
    if not SelectorAvailable() then
        return
    end
    local provider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.None)
    frame.iconProvider = provider
    frame.totalIconCount = provider:GetNumIcons()
    frame.iconCount = frame.totalIconCount
    frame.indexMap = nil
    frame.iconNames = nil
    frame.selectedIcon = NormalizeIcon(selectedIcon)
    if frame.searchBox then
        frame.suppressSearch = true
        frame.searchBox:SetText('')
        frame.suppressSearch = false
    end
    UpdateIconExtent(frame, true)
    RefreshVisibleIcons(frame, true)
end

local function EnsurePopup()
    if popup ~= nil then
        return popup or nil
    end
    if not SelectorAvailable() then
        popup = false
        return nil
    end

    local function ClosePopup(target)
        target.onAccept = nil
        target.owner = nil
        target:Hide()
    end

    local overlay = CreateFrame('Button', nil, UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata('FULLSCREEN_DIALOG')
    overlay:SetFrameLevel(1)
    overlay:EnableMouse(true)
    overlay:RegisterForClicks('AnyUp')
    overlay:Hide()

    local frame = CreateFrame('Frame', 'EXUIIconSelectorPopup', overlay)
    frame:SetSize(300, 392)
    frame:SetPoint('CENTER')
    frame:SetFrameStrata('FULLSCREEN_DIALOG')
    frame:SetFrameLevel(overlay:GetFrameLevel() + 20)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    frame.iconButtons = {}
    frame.overlay = overlay

    overlay:SetScript('OnClick', function()
        ClosePopup(frame)
    end)

    local bg = frame:CreateTexture(nil, 'BACKGROUND')
    bg:SetTexture(EXFrames.assets.textures.ui.panelBg)
    bg:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))
    bg:SetTextureSliceMargins(8, 8, 8, 8)
    bg:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    bg:SetAllPoints()

    local border = frame:CreateTexture(nil, 'OVERLAY', nil, 1)
    border:SetTexture(EXFrames.assets.textures.ui.panelBorder)
    border:SetVertexColor(unpack(EXFrames.Theme.border))
    border:SetTextureSliceMargins(8, 8, 8, 8)
    border:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    border:SetAllPoints()

    local title = frame:CreateFontString(nil, 'OVERLAY')
    title:SetFont(EXFrames.assets.font.default(), 14, 'OUTLINE')
    title:SetPoint('TOPLEFT', 14, -14)
    title:SetPoint('TOPRIGHT', -32, -14)
    title:SetJustifyH('LEFT')
    title:SetText('Choose Icon')
    title:SetTextColor(unpack(EXFrames.Theme.text))

    local close = CreateFrame('Button', nil, frame)
    close:SetSize(16, 16)
    close:SetPoint('TOPRIGHT', -12, -14)
    local closeIcon = close:CreateTexture(nil, 'OVERLAY')
    closeIcon:SetAllPoints()
    closeIcon:SetTexture(EXFrames.assets.textures.icon.close)
    closeIcon:SetVertexColor(unpack(EXFrames.Theme.textMuted))
    close:SetScript('OnClick', function()
        ClosePopup(frame)
    end)
    close:SetScript('OnEnter', function()
        closeIcon:SetVertexColor(unpack(EXFrames.Theme.danger))
    end)
    close:SetScript('OnLeave', function()
        closeIcon:SetVertexColor(unpack(EXFrames.Theme.textMuted))
    end)

    local searchArea = CreateFrame('Frame', nil, frame)
    searchArea:SetHeight(24)
    searchArea:SetPoint('TOPLEFT', 14, -36)
    searchArea:SetPoint('TOPRIGHT', -14, -36)
    local searchBg = searchArea:CreateTexture(nil, 'BACKGROUND')
    searchBg:SetTexture(EXFrames.assets.textures.ui.inputBg)
    searchBg:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))
    searchBg:SetAllPoints()
    EXFrames:ApplyInputBorder(searchArea, 1)

    local searchBox = CreateFrame('EditBox', nil, searchArea)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(64)
    searchBox:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    searchBox:SetTextColor(unpack(EXFrames.Theme.text))
    searchBox:SetPoint('TOPLEFT', 1, -1)
    searchBox:SetPoint('BOTTOMRIGHT', -1, 1)
    searchBox:SetTextInsets(8, 8, 0, 0)
    frame.searchBox = searchBox

    local placeholder = searchArea:CreateFontString(nil, 'OVERLAY')
    placeholder:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    placeholder:SetTextColor(unpack(EXFrames.Theme.textMuted))
    placeholder:SetPoint('LEFT', 9, 0)
    placeholder:SetText('Search')
    searchBox:SetScript('OnTextChanged', function(box)
        placeholder:SetShown(box:GetText() == '')
        if frame.suppressSearch or not frame.iconProvider then
            return
        end
        ApplyIconFilter(frame)
    end)
    searchBox:SetScript('OnEscapePressed', function(box)
        if box:GetText() ~= '' then
            box:SetText('')
            return
        end
        box:ClearFocus()
        ClosePopup(frame)
    end)
    searchBox:SetScript('OnEnterPressed', function(box)
        box:ClearFocus()
    end)
    searchBox:SetScript('OnEditFocusGained', function()
        searchArea:SetInputBorderActive(true)
    end)
    searchBox:SetScript('OnEditFocusLost', function()
        searchArea:SetInputBorderActive(false)
    end)

    local iconScroll = EXFrames:GetFrame('smooth-scroll-frame'):Create()
    iconScroll:SetParent(frame)
    iconScroll:SetPoint('TOPLEFT', 14, -68)
    iconScroll:SetPoint('BOTTOMRIGHT', -14, 14)
    frame.iconScroll = iconScroll
    iconScroll.onScroll = function()
        if frame.iconProvider then
            RefreshVisibleIcons(frame, false)
        end
    end

    local watcher = CreateFrame('Frame', nil, frame)
    watcher:SetScript('OnUpdate', function()
        if frame:IsShown() and frame.iconProvider then
            RefreshVisibleIcons(frame, false)
        end
    end)

    frame:SetScript('OnKeyDown', function(self, key)
        if key == 'ESCAPE' then
            self:SetPropagateKeyboardInput(false)
            ClosePopup(self)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    frame:SetScript('OnShow', function(self)
        self.overlay:Show()
        BuildIcons(self, self.pendingIcon)
    end)

    frame:SetScript('OnHide', function(self)
        self.overlay:Hide()
        ReleaseProvider(self)
    end)

    popup = frame
    return popup
end

local function OpenSelector(owner, iconID)
    local frame = EnsurePopup()
    if not frame then
        return
    end
    frame.owner = owner
    frame.onAccept = function(id)
        if owner.SetIconID then
            owner:SetIconID(id, true)
        end
    end
    frame.pendingIcon = NormalizeIcon(iconID)
    if frame:IsShown() then
        frame:Hide()
    end
    frame.overlay:Show()
    frame:Show()
end

local function ConfigureFrame(f)
    local labelOffset = EXFrames:ScalePixel(12, f)
    local labelGap = EXFrames:ScalePixel(2, f)
    local iconSize = EXFrames:ScalePixel(28, f)
    local gap = EXFrames:ScalePixel(6, f)

    local iconButton = CreateFrame('Button', nil, f)
    iconButton:SetSize(iconSize, iconSize)
    iconButton:SetPoint('TOPLEFT', 0, -labelOffset)
    f.iconButton = iconButton

    local iconBg = iconButton:CreateTexture(nil, 'BACKGROUND')
    iconBg:SetTexture(EXFrames.assets.textures.ui.inputBg)
    iconBg:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))
    iconBg:SetAllPoints()

    EXFrames:ApplyInputBorder(iconButton, 1)

    local preview = iconButton:CreateTexture(nil, 'ARTWORK')
    local inset = EXFrames:ScalePixel(1, iconButton)
    preview:SetPoint('TOPLEFT', inset, -inset)
    preview:SetPoint('BOTTOMRIGHT', -inset, inset)
    preview:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    preview:SetTexture(QUESTION_MARK)
    f.preview = preview

    local inputArea = CreateFrame('Frame', nil, f)
    inputArea:SetPoint('TOPLEFT', iconButton, 'TOPRIGHT', gap, 0)
    inputArea:SetPoint('BOTTOMLEFT', iconButton, 'BOTTOMRIGHT', gap, 0)
    inputArea:SetPoint('RIGHT', 0, 0)
    f.inputArea = inputArea

    local bgTex = inputArea:CreateTexture(nil, 'BACKGROUND')
    bgTex:SetTexture(EXFrames.assets.textures.ui.inputBg)
    bgTex:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))
    bgTex:SetTextureSliceMargins(6, 6, 6, 6)
    bgTex:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    bgTex:SetAllPoints()

    EXFrames:ApplyInputBorder(inputArea, 1)

    local inputInset = EXFrames:ScalePixels(1, inputArea)
    local input = CreateFrame('EditBox', nil, inputArea)
    f.editBox = input
    input:SetAutoFocus(false)
    input:SetNumeric(true)
    input:SetMaxLetters(10)
    input:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    input:SetTextColor(unpack(EXFrames.Theme.text))
    input:SetPoint('TOPLEFT', inputInset, -inputInset)
    input:SetPoint('BOTTOMRIGHT', -inputInset, inputInset)
    input:SetTextInsets(8, 8, 0, 0)
    input:SetText(tostring(QUESTION_MARK))

    local label = f:CreateFontString(nil, 'OVERLAY')
    label:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
    label:SetPoint('BOTTOMLEFT', iconButton, 'TOPLEFT', 0, labelGap)
    label:SetText('Icon')
    f.label = label

    f.iconID = QUESTION_MARK

    local function setBorderActive(active)
        iconButton:SetInputBorderActive(active)
        inputArea:SetInputBorderActive(active)
    end

    f.SetLabel = function(self, text)
        self.label:SetText(text or 'Icon')
    end

    f.SetIconID = function(self, iconID, notify)
        iconID = NormalizeIcon(iconID)
        self.iconID = iconID
        self.preview:SetTexture(iconID)
        self.editBox:SetText(tostring(iconID))
        if notify and self.onChange and not self.suppressOnChange then
            self.onChange(iconID)
        end
    end

    f.SetEditorValue = function(self, value)
        self:SetIconID(value, false)
    end

    f.GetEditorValue = function(self)
        return self.iconID
    end

    f.SetOptionData = function(self, option)
        self.optionData = option
        self:SetLabel(option.label)
        self.onChange = option.onChange
        local value = option.currentValue and option.currentValue() or QUESTION_MARK
        self:SetIconID(value, false)
    end

    local function commitIconText()
        local id = tonumber(input:GetText())
        if not id or id <= 0 then
            input:SetText(tostring(f.iconID or QUESTION_MARK))
            f.preview:SetTexture(f.iconID or QUESTION_MARK)
            return
        end
        id = math.floor(id)
        f.preview:SetTexture(id)
        if id == f.iconID then
            return
        end
        f.iconID = id
        if f.onChange and not f.suppressOnChange then
            f.onChange(id)
        end
    end

    input:SetScript('OnTextChanged', function(editbox, userInput)
        if not userInput then
            return
        end
        local id = tonumber(editbox:GetText())
        if id and id > 0 then
            f.preview:SetTexture(math.floor(id))
        end
    end)

    input:SetScript('OnEscapePressed', function(editbox)
        editbox:SetText(tostring(f.iconID or QUESTION_MARK))
        f.preview:SetTexture(f.iconID or QUESTION_MARK)
        editbox:ClearFocus()
    end)

    input:SetScript('OnEnterPressed', function(editbox)
        commitIconText()
        editbox:ClearFocus()
    end)

    input:SetScript('OnEditFocusLost', function(editbox)
        if not editbox:IsMouseOver() then
            setBorderActive(false)
        end
        commitIconText()
    end)

    input:SetScript('OnEditFocusGained', function()
        setBorderActive(true)
    end)

    input:SetScript('OnEnter', function()
        setBorderActive(true)
    end)

    input:SetScript('OnLeave', function(editbox)
        if not editbox:HasFocus() and not iconButton:IsMouseOver() then
            setBorderActive(false)
        end
    end)

    iconButton:SetScript('OnEnter', function()
        setBorderActive(true)
    end)

    iconButton:SetScript('OnLeave', function()
        if not input:HasFocus() and not input:IsMouseOver() then
            setBorderActive(false)
        end
    end)

    iconButton:SetScript('OnClick', function()
        OpenSelector(f, f.iconID)
    end)

    f:SetHeight(labelOffset + iconSize)
    f.configured = true
end

iconInput.Create = function(self, options, parent)
    options = options or {}
    local f = self.pool:Acquire()
    if not f.configured then
        ConfigureFrame(f)
    end
    if parent then
        f:SetParent(parent)
    end
    if options.label then
        f:SetLabel(options.label)
    end
    if options.onChange then
        f.onChange = options.onChange
    end
    if options.initial ~= nil then
        f:SetIconID(options.initial, false)
    end

    f.Destroy = function(self)
        if popup and popup.owner == self and popup:IsShown() then
            popup.onAccept = nil
            popup.owner = nil
            popup:Hide()
        end
        self:SetIconID(QUESTION_MARK, false)
        self.onChange = nil
        iconInput.pool:Release(self)
    end

    f:Show()
    return f
end

EXFrames.FrameBase.StandardizeCreate(iconInput)
