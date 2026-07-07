local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesLuaEditor
local luaEditor = EXFrames:GetFrame('frame-input-lua')

luaEditor.Init = function(self)
    self.pool = CreateFramePool('EditBox', UIParent, 'BackdropTemplate')
end

local function ConfigureFrame(f)
    EXFrames.utils.addObserver(f)
    f:SetMultiLine(true)
    f:SetAutoFocus(false)
    f:SetTextInsets(10, 10, 10, 10)
    Mixin(f, BackdropTemplateMixin)
    EXFrames:RegisterPixelPerfectBackdrop(f, 1)
    f:SetBackdropColor(.1, .1, .1, .8)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f:SetFont(EXFrames.assets.font.default(), 10, "OUTLINE")
    f:SetCursorPosition(0)
    f:SetScript('OnMouseDown', function(self) self:SetFocus() end)
    f:Show()

    f.isConfigured = true
end

local function UpdateEditorScrollHeight(scrollFrame, input)
    local contentHeight = math.max(input:GetHeight(), input:GetStringHeight() + 20)
    scrollFrame:UpdateScrollChild(scrollFrame:GetWidth(), contentHeight)
end

---Create Lua Editor
---@param self ExalityFramesLuaEditor
---@param options any
---@param parent Frame
---@return Frame
luaEditor.Create = function(self, options, parent)
    local scrollFrame = EXFrames:GetFrame('smooth-scroll-frame'):Create()
    local input = self.pool:Acquire()
    input:SetParent(scrollFrame.child)
    input:SetPoint('TOPLEFT', scrollFrame.child, 'TOPLEFT', 0, 0)
    input:SetPoint('TOPRIGHT', scrollFrame.child, 'TOPRIGHT', 0, 0)
    scrollFrame.input = input
    scrollFrame.GetText = function(self)
        return input:GetText()
    end
    scrollFrame.SetText = function(self, text)
        input:SetText(text)
        UpdateEditorScrollHeight(scrollFrame, input)
    end
    if (not input.isConfigured) then
        ConfigureFrame(input)
    end
    input:SetScript('OnTextChanged', function()
        UpdateEditorScrollHeight(scrollFrame, input)
    end)
    if (parent) then
        scrollFrame:SetParent(parent)
    else
        scrollFrame:SetParent(nil)
    end
    scrollFrame.Destroy = function(self)
        if self.input then
            luaEditor.pool:Release(self.input)
            self.input = nil
        end
        if self.Reset then
            self:Reset()
        end
        self:Hide()
        EXFrames:GetFrame('smooth-scroll-frame').pool:Release(self)
    end
    if (options and options.text) then
        input:SetText(options.text)
    end
    UpdateEditorScrollHeight(scrollFrame, input)

    scrollFrame:Show()
    return scrollFrame
end
