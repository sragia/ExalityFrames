local _, EXUI = ...

---@class ExalityFrames
local EXFrames = EXUI.EXFrames

---@class ExalityFramesSpellIdInput
local spellIdInput = EXFrames:GetFrame('spell-id-input')

spellIdInput.pool = {}

local SEARCH_DEBOUNCE = 0.2
local INPUT_HEIGHT = 28
local SUBMIT_SIZE = 14
local SUBMIT_INSET = 6
local BUTTON_HEIGHT = 24
local ROW_HEIGHT = 24
local ROW_GAP = 2
local SECTION_GAP = 6
local LABEL_HEIGHT = 12

local SPELL_TOOLTIP =
    'Enter a spell ID, or search by spell name. Name lookup only works for exact matches and is not guaranteed.'

local function trim(text)
    if not text then
        return ''
    end
    return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function getSpellIndex()
    if not EXUI or not EXUI.GetModule then
        return nil
    end
    return EXUI:GetModule('aura-displays-spell-index')
end

local function relayoutOptionsGrid()
    C_Timer.After(0, function()
        local optionsFields = EXUI:GetModule('options-fields')
        if optionsFields and optionsFields.fields and optionsFields.container then
            EXUI.utils.organizeFramesInGrid('fields', optionsFields.fields, 10, optionsFields.container, 10, 10)
            if optionsFields.splitView and optionsFields.container == optionsFields.splitView.container and optionsFields.splitView.UpdateScroll then
                optionsFields.splitView:UpdateScroll()
            elseif optionsFields.innerTabs and optionsFields.innerTabs.scrollable and optionsFields.innerTabs.UpdateScroll and optionsFields.container == optionsFields.innerTabs.container then
                optionsFields.innerTabs:UpdateScroll()
            elseif optionsFields.tabs and optionsFields.tabs.scrollable and optionsFields.tabs.UpdateScroll and optionsFields.container == optionsFields.tabs.container then
                optionsFields.tabs:UpdateScroll()
            end
        end

        -- Unit Frame Aura Editor hosts its own field grid outside options-fields.
        local auraEditor = EXUI:GetModule('uf-aura-editor')
        if auraEditor and auraEditor.RelayoutFields then
            auraEditor:RelayoutFields()
        end
    end)
end

local function cancelSearchTimer(frame)
    if frame.searchTimer then
        frame.searchTimer:Cancel()
        frame.searchTimer = nil
    end
end

local function hideAutocomplete(frame)
    cancelSearchTimer(frame)
    local listMenu = EXFrames:GetFrame('list-menu-frame')
    if listMenu and listMenu:IsOpen() and listMenu:GetAnchor() == frame.autocompleteAnchor then
        listMenu:Hide()
    end
end

local function setRowIcon(texture, icon)
    if not texture then
        return
    end
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
    local inset = 0.08
    texture:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
end

local function persistIds(frame, ids)
    frame.spellIds = ids
    local spellIndex = getSpellIndex()
    local text = spellIndex and spellIndex:FormatSpellIDList(ids) or ''
    if frame.onChange and not frame.suppressOnChange then
        frame.onChange(text)
    end
end

local function computeHeight(spellCount)
    local height = LABEL_HEIGHT + SECTION_GAP
    height = height + LABEL_HEIGHT + 2 + INPUT_HEIGHT + SECTION_GAP
    height = height + BUTTON_HEIGHT + SECTION_GAP
    if spellCount > 0 then
        height = height + (spellCount * (ROW_HEIGHT + ROW_GAP)) - ROW_GAP
    end
    return height + 4
end

local function updateFrameHeight(frame)
    local count = frame.spellIds and #frame.spellIds or 0
    local listHeight = count > 0 and ((count * (ROW_HEIGHT + ROW_GAP)) - ROW_GAP) or 0
    frame.listContainer:SetHeight(listHeight)
    frame:SetHeight(computeHeight(count))
    relayoutOptionsGrid()
end

local function updateSubmitState(frame)
    local spellIndex = getSpellIndex()
    local text = trim(frame:GetEditorValue())
    local spellID = spellIndex and spellIndex:ResolveInput(text)
    local canSubmit = spellIndex and spellID ~= nil and spellIndex:GetSpellInfo(spellID) ~= nil

    frame.canSubmit = canSubmit
    frame.submitCheck:SetAlpha(canSubmit and 1 or 0.5)
    frame.submitCheck.Mark:SetAlpha(canSubmit and 0.9 or 0.25)
    if canSubmit then
        frame.submitCheck:Enable()
    else
        frame.submitCheck:Disable()
    end
end

local function clearInput(frame)
    frame.suppressInputChange = true
    frame:SetEditorValue('')
    frame.suppressInputChange = false
    updateSubmitState(frame)
end

local function releaseListRows(frame)
    if not frame.listRows then
        return
    end
    for _, row in ipairs(frame.listRows) do
        row:Hide()
        row:ClearAllPoints()
        frame.listRowPool:Release(row)
    end
    wipe(frame.listRows)
end

local function removeSpellAt(frame, index)
    if not frame.spellIds or not frame.spellIds[index] then
        return
    end
    table.remove(frame.spellIds, index)
    persistIds(frame, frame.spellIds)
    frame:RefreshList()
end

local function addSpellId(frame, spellID)
    if not spellID then
        return
    end
    frame.spellIds = frame.spellIds or {}
    for _, existing in ipairs(frame.spellIds) do
        if existing == spellID then
            clearInput(frame)
            return
        end
    end
    table.insert(frame.spellIds, spellID)
    local spellIndex = getSpellIndex()
    if spellIndex then
        spellIndex:RegisterSpellID(spellID)
    end
    persistIds(frame, frame.spellIds)
    clearInput(frame)
    hideAutocomplete(frame)
    frame:RefreshList()
end

local function submitInput(frame)
    if not frame.canSubmit then
        return
    end
    local spellIndex = getSpellIndex()
    if not spellIndex then
        return
    end
    local spellID = spellIndex:ResolveInput(frame:GetEditorValue())
    if spellID then
        addSpellId(frame, spellID)
    end
end

local function runAutocompleteSearch(frame)
    local spellIndex = getSpellIndex()
    if not spellIndex or not frame.editBox:HasFocus() then
        return
    end

    local text = trim(frame:GetEditorValue())
    if text == '' then
        hideAutocomplete(frame)
        return
    end

    local results = spellIndex:GetAutocompleteResults(text)
    if #results == 0 then
        hideAutocomplete(frame)
        return
    end

    local listMenu = EXFrames:GetFrame('list-menu-frame')
    local entries = spellIndex:BuildSearchMenuEntries(results, function(selectedID)
        addSpellId(frame, selectedID)
    end)
    listMenu:ShowAt(frame.autocompleteAnchor, entries)
end

local function scheduleAutocompleteSearch(frame)
    cancelSearchTimer(frame)
    frame.searchTimer = C_Timer.NewTimer(SEARCH_DEBOUNCE, function()
        frame.searchTimer = nil
        runAutocompleteSearch(frame)
    end)
end

local function showFromTargetPicker(frame)
    local spellIndex = getSpellIndex()
    if not spellIndex then
        return
    end

    local filterString = 'HELPFUL|HARMFUL'
    if frame.optionData and frame.optionData.getFilterString then
        filterString = frame.optionData.getFilterString() or filterString
    end

    local auraEntries, reason = spellIndex:GetUnitAuraEntries('target', filterString)
    if #auraEntries == 0 then
        if reason and EXUI.utils and EXUI.utils.printOut then
            EXUI.utils.printOut(reason)
        end
        return
    end

    local listMenu = EXFrames:GetFrame('list-menu-frame')
    local entries = spellIndex:BuildPickerMenuEntries(auraEntries, function(selectedID)
        addSpellId(frame, selectedID)
    end)
    listMenu:ShowAt(frame.pickerAnchor, entries)
end

local function ensureListRowLayout(row)
    if row.layoutConfigured then
        return
    end

    row:SetHeight(ROW_HEIGHT)

    local bg = row:CreateTexture(nil, 'BACKGROUND')
    bg:SetTexture(EXFrames.assets.textures.ui.inputBg)
    bg:SetVertexColor(unpack(EXFrames.Theme.backgroundLight))
    bg:SetTextureSliceMargins(4, 4, 4, 4)
    bg:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    bg:SetAllPoints()
    row.bg = bg

    local icon = row:CreateTexture(nil, 'ARTWORK')
    icon:SetSize(18, 18)
    icon:SetPoint('LEFT', 4, 0)
    row.icon = icon

    local nameText = row:CreateFontString(nil, 'OVERLAY')
    nameText:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
    nameText:SetPoint('LEFT', icon, 'RIGHT', 6, 0)
    nameText:SetJustifyH('LEFT')
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local idText = row:CreateFontString(nil, 'OVERLAY')
    idText:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
    idText:SetTextColor(unpack(EXFrames.Theme.textMuted))
    idText:SetWidth(64)
    idText:SetJustifyH('RIGHT')
    row.idText = idText

    local removeBtn = CreateFrame('Button', nil, row)
    removeBtn:SetSize(16, 16)
    removeBtn:SetPoint('RIGHT', -4, 0)
    local removeLabel = removeBtn:CreateFontString(nil, 'OVERLAY')
    removeLabel:SetFont(EXFrames.assets.font.default(), 12, 'OUTLINE')
    removeLabel:SetPoint('CENTER')
    removeLabel:SetText('×')
    removeLabel:SetTextColor(unpack(EXFrames.Theme.danger))
    removeBtn:SetScript('OnClick', function(btn)
        local parentRow = btn:GetParent()
        local owner = parentRow.ownerFrame
        if owner and parentRow.rowIndex then
            removeSpellAt(owner, parentRow.rowIndex)
        end
    end)
    row.removeBtn = removeBtn
    row.layoutConfigured = true
end

local function createListRow(frame, index, entry)
    local row = frame.listRowPool:Acquire()
    row:SetParent(frame.listContainer)
    row.ownerFrame = frame
    row:ClearAllPoints()
    ensureListRowLayout(row)

    row.rowIndex = index
    setRowIcon(row.icon, entry.icon)
    row.nameText:SetText(entry.name or tostring(entry.spellID))
    row.idText:SetText(tostring(entry.spellID))
    row.idText:SetWidth(64)
    row.idText:ClearAllPoints()
    row.idText:SetPoint('RIGHT', row.removeBtn, 'LEFT', -4, 0)
    row.nameText:ClearAllPoints()
    row.nameText:SetPoint('LEFT', row.icon, 'RIGHT', 6, 0)
    row.nameText:SetPoint('RIGHT', row.idText, 'LEFT', -6, 0)
    row:Show()
    return row
end

local function ConfigureFrame(f, options)
    EXFrames.utils.addObserver(f)
    f.onChange = options.onChange
    f.suppressOnChange = false
    f.spellIds = {}
    f.listRows = {}

    local sectionLabel = f:CreateFontString(nil, 'OVERLAY')
    sectionLabel:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    sectionLabel:SetPoint('TOPLEFT', 0, 0)
    sectionLabel:SetWidth(0)
    f.sectionLabel = sectionLabel

    local spellLabel = f:CreateFontString(nil, 'OVERLAY')
    spellLabel:SetFont(EXFrames.assets.font.default(), 10, 'OUTLINE')
    spellLabel:SetPoint('TOPLEFT', sectionLabel, 'BOTTOMLEFT', 0, -SECTION_GAP)
    spellLabel:SetText('Spell')
    spellLabel:SetWidth(0)
    f.spellLabel = spellLabel

    local tooltip = EXFrames:GetFrame('tooltip'):Get({ text = SPELL_TOOLTIP }, spellLabel)
    f.spellTooltip = tooltip
    spellLabel:EnableMouse(true)
    spellLabel:SetScript('OnEnter', function()
        tooltip:ShowTooltip()
    end)
    spellLabel:SetScript('OnLeave', function()
        tooltip:HideTooltip()
    end)

    local inputArea = CreateFrame('Frame', nil, f)
    inputArea:SetPoint('TOPLEFT', spellLabel, 'BOTTOMLEFT', 0, -2)
    inputArea:SetPoint('TOPRIGHT', f, 'TOPRIGHT', 0, 0)
    inputArea:SetHeight(INPUT_HEIGHT)
    f.inputArea = inputArea
    f.autocompleteAnchor = inputArea
    f.pickerAnchor = inputArea

    local bgTex = inputArea:CreateTexture(nil, 'BACKGROUND')
    bgTex:SetTexture(EXFrames.assets.textures.ui.inputBg)
    bgTex:SetVertexColor(unpack(EXFrames.Theme.backgroundDeep))
    bgTex:SetTextureSliceMargins(6, 6, 6, 6)
    bgTex:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
    bgTex:SetAllPoints()
    EXFrames:ApplyInputBorder(inputArea, 1)

    local submitCheck = CreateFrame('Button', nil, inputArea)
    submitCheck:SetSize(SUBMIT_SIZE, SUBMIT_SIZE)
    submitCheck:SetPoint('RIGHT', inputArea, 'RIGHT', -SUBMIT_INSET, 0)
    submitCheck:SetFrameLevel(inputArea:GetFrameLevel() + 2)

    local submitBase = submitCheck:CreateTexture(nil, 'ARTWORK')
    submitBase:SetTexture(EXFrames.assets.textures.input.checkbox.base)
    submitBase:SetSize(SUBMIT_SIZE, SUBMIT_SIZE)
    submitBase:SetPoint('CENTER')
    submitCheck.Base = submitBase

    local submitHover = submitCheck:CreateTexture(nil, 'HIGHLIGHT')
    submitHover:SetTexture(EXFrames.assets.textures.input.checkbox.hover)
    submitHover:SetSize(SUBMIT_SIZE, SUBMIT_SIZE)
    submitHover:SetPoint('CENTER')
    submitHover:SetAlpha(0.6)
    submitCheck.Hover = submitHover

    local submitMark = submitCheck:CreateTexture(nil, 'OVERLAY')
    submitMark:SetTexture(EXFrames.assets.textures.input.checkbox.mark)
    submitMark:SetSize(SUBMIT_SIZE + 2, SUBMIT_SIZE)
    submitMark:SetPoint('CENTER')
    submitMark:SetAlpha(0.25)
    submitCheck.Mark = submitMark

    submitCheck:SetScript('OnEnter', function(btn)
        if btn:IsEnabled() then
            btn.Hover:Show()
        end
    end)
    submitCheck:SetScript('OnLeave', function(btn)
        btn.Hover:Hide()
    end)
    submitCheck:SetScript('OnClick', function(btn)
        if f.canSubmit then
            submitInput(f)
        end
    end)
    f.submitCheck = submitCheck

    local inset = EXFrames:ScalePixels(1, inputArea)
    local input = CreateFrame('EditBox', nil, inputArea)
    f.editBox = input
    input:SetAutoFocus(false)
    input:SetFont(EXFrames.assets.font.default(), 11, 'OUTLINE')
    input:SetPoint('TOPLEFT', inset, -inset)
    input:SetPoint('BOTTOMRIGHT', inputArea, 'BOTTOMRIGHT', -(SUBMIT_SIZE + SUBMIT_INSET + 6), inset)
    input:SetTextInsets(10, SUBMIT_SIZE + SUBMIT_INSET + 4, 0, 0)

    input:SetScript('OnTextChanged', function(_, changed)
        if changed and not f.suppressInputChange then
            updateSubmitState(f)
            scheduleAutocompleteSearch(f)
        end
    end)

    input:SetScript('OnEscapePressed', function(self)
        hideAutocomplete(f)
        self:ClearFocus()
    end)

    input:SetScript('OnEnterPressed', function()
        if f.canSubmit then
            submitInput(f)
        end
    end)

    f.SetEditorValue = function(self, value)
        input:SetText(value or '')
    end

    f.GetEditorValue = function(self)
        return input:GetText()
    end

    local function setBorderActive(active)
        inputArea:SetInputBorderActive(active)
    end

    input:SetScript('OnEnter', function()
        setBorderActive(true)
    end)

    input:SetScript('OnLeave', function(self)
        if not self:HasFocus() and not submitCheck:IsMouseOver() then
            setBorderActive(false)
        end
    end)

    submitCheck:SetScript('OnEnter', function()
        setBorderActive(true)
    end)

    submitCheck:SetScript('OnLeave', function()
        if not input:HasFocus() and not input:IsMouseOver() then
            setBorderActive(false)
        end
    end)

    input:SetScript('OnEditFocusGained', function()
        setBorderActive(true)
        local spellIndex = getSpellIndex()
        if spellIndex then
            spellIndex:EnsureIndex()
        end
    end)

    input:SetScript('OnEditFocusLost', function(self)
        if not self:IsMouseOver() and not submitCheck:IsMouseOver() then
            setBorderActive(false)
        end
        C_Timer.After(0.05, function()
            if not f.editBox or f.editBox:HasFocus() then
                return
            end
            local listMenu = EXFrames:GetFrame('list-menu-frame')
            if listMenu:IsOpen() and (listMenu:GetAnchor() == f.autocompleteAnchor or listMenu:GetAnchor() == f.pickerAnchor) then
                return
            end
            hideAutocomplete(f)
        end)
    end)

    local fromTargetBtn = EXFrames:GetFrame('button'):Create({
        text = 'From Target',
        size = { 0, BUTTON_HEIGHT },
    }, f)
    fromTargetBtn:SetPoint('TOPLEFT', inputArea, 'BOTTOMLEFT', 0, -SECTION_GAP)
    fromTargetBtn:SetPoint('TOPRIGHT', inputArea, 'BOTTOMRIGHT', 0, -SECTION_GAP)
    fromTargetBtn:SetOnClick(function()
        showFromTargetPicker(f)
    end)
    f.fromTargetBtn = fromTargetBtn

    local listContainer = CreateFrame('Frame', nil, f)
    listContainer:SetPoint('TOPLEFT', fromTargetBtn, 'BOTTOMLEFT', 0, -SECTION_GAP)
    listContainer:SetPoint('TOPRIGHT', fromTargetBtn, 'BOTTOMRIGHT', 0, -SECTION_GAP)
    listContainer:SetHeight(0)
    f.listContainer = listContainer
    f.listRowPool = CreateFramePool('Frame', listContainer)

    f.RefreshList = function(self)
        releaseListRows(self)
        local spellIndex = getSpellIndex()
        if not spellIndex then
            updateFrameHeight(self)
            return
        end

        local previous
        for index, spellID in ipairs(self.spellIds or {}) do
            local entry = spellIndex:GetSpellEntry(spellID)
            if entry then
                local row = createListRow(self, index, entry)
                row:ClearAllPoints()
                if previous then
                    row:SetPoint('TOPLEFT', previous, 'BOTTOMLEFT', 0, -ROW_GAP)
                    row:SetPoint('TOPRIGHT', previous, 'BOTTOMRIGHT', 0, -ROW_GAP)
                else
                    row:SetPoint('TOPLEFT', self.listContainer, 'TOPLEFT', 0, 0)
                    row:SetPoint('TOPRIGHT', self.listContainer, 'TOPRIGHT', 0, 0)
                end
                table.insert(self.listRows, row)
                previous = row
            end
        end
        updateFrameHeight(self)
    end

    f.ScheduleRefreshList = function(self)
        if self.refreshTimer then
            self.refreshTimer:Cancel()
        end
        self.refreshTimer = C_Timer.NewTimer(0, function()
            self.refreshTimer = nil
            self:RefreshList()
        end)
    end

    f.SetSectionLabel = function(self, text)
        self.sectionLabel:SetText(text or '')
    end

    f.SetOptionData = function(self, option)
        self.optionData = option
        self:SetSectionLabel(option.label)
        self.onChange = option.onChange

        local spellIndex = getSpellIndex()
        self.suppressOnChange = true
        self.spellIds = spellIndex and spellIndex:ParseSpellIDList(option.currentValue and option.currentValue() or '') or {}
        self.suppressOnChange = false
        clearInput(self)
        self:ScheduleRefreshList()
    end

    f.GetState = function(self)
        local spellIndex = getSpellIndex()
        return spellIndex and spellIndex:FormatSpellIDList(self.spellIds or {}) or ''
    end

    f.SetState = function(self, value)
        local spellIndex = getSpellIndex()
        self.spellIds = spellIndex and spellIndex:ParseSpellIDList(value) or {}
        clearInput(self)
        self:ScheduleRefreshList()
    end

    f.SetFrameWidth = function(self, width)
        self:SetWidth(width)
    end

    f.configured = true
    f:SetHeight(computeHeight(0))
end

spellIdInput.Init = function(self)
    self.pool = CreateFramePool('Frame', UIParent)
end

spellIdInput.Create = function(self, options, parent)
    local f = self.pool:Acquire()
    if not f.configured then
        ConfigureFrame(f, options or {})
    end

    if options and options.label then
        f:SetSectionLabel(options.label)
    end

    if parent then
        f:SetParent(parent)
    end

    f.Destroy = function(self)
        hideAutocomplete(self)
        if self.refreshTimer then
            self.refreshTimer:Cancel()
            self.refreshTimer = nil
        end
        releaseListRows(self)
        if self.spellTooltip then
            self.spellTooltip:Hide()
        end
        self.spellIds = {}
        clearInput(self)
        spellIdInput.pool:Release(self)
    end

    f:Show()
    return f
end
