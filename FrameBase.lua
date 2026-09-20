local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

local FrameBase = {}
EXFrames.FrameBase = FrameBase

function FrameBase.IsRegion(value)
    return type(value) == 'table' and value.GetObjectType ~= nil
end

function FrameBase.ResolveCreateArgs(parent, options)
    if parent == nil then
        if FrameBase.IsRegion(options) then
            return options, {}
        end
        return nil, options
    end
    if FrameBase.IsRegion(parent) then
        return parent, options
    end
    if options ~= nil and FrameBase.IsRegion(options) then
        return options, parent
    end
    return nil, parent
end

function FrameBase.BindInputAPI(f)
    if f._inputAPI then
        return
    end
    f._inputAPI = true

    if not f.GetValue then
        f.GetValue = function(self)
            if self.GetEditorValue then
                return self:GetEditorValue()
            end
            if self.GetState then
                return self:GetState()
            end
            return self.value
        end
    end

    local observeSet = f.SetValue
    if not f.SetInputValue then
        f.SetInputValue = f.SetEditorValue or function(self, value)
            if observeSet then
                observeSet(self, 'value', value)
            else
                self.value = value
            end
        end
    end

    f.SetValue = function(self, a, b)
        if b ~= nil and observeSet then
            return observeSet(self, a, b)
        end
        return self:SetInputValue(a)
    end

    if not f.SetOnChange then
        f.SetOnChange = function(self, fn)
            self.onChange = fn
            self.OnChange = fn
        end
    else
        local existing = f.SetOnChange
        f.SetOnChange = function(self, fn)
            self.onChange = fn
            self.OnChange = fn
            return existing(self, fn)
        end
    end

    if not f.SetLabel then
        f.SetLabel = function(self, text)
            if self.label and self.label.SetText then
                self.label:SetText(text or '')
            elseif self.Label and self.Label.SetText then
                self.Label:SetText(text or '')
            elseif self.SetText then
                self:SetText(text or '')
            end
        end
    end

    if not f.SetFrameWidth then
        f.SetFrameWidth = function(self, width)
            self:SetWidth(width)
        end
    end
end

function FrameBase.StandardizeCreate(proto, argStyle)
    local oldCreate = proto.Create
    if not oldCreate or proto._standardizedCreate then
        return
    end
    proto._standardizedCreate = true

    proto.Create = function(self, parent, options)
        local resolvedParent, resolvedOptions = FrameBase.ResolveCreateArgs(parent, options)
        resolvedOptions = resolvedOptions or {}
        local f
        if argStyle == 'parent-only' then
            f = oldCreate(self, resolvedParent)
        elseif argStyle == 'options-only' then
            f = oldCreate(self, resolvedOptions)
        else
            f = oldCreate(self, resolvedOptions, resolvedParent)
        end
        if not f then
            return f
        end
        if resolvedParent and f.SetParent and argStyle ~= 'no-parent' then
            f:SetParent(resolvedParent)
        end
        if not f.Configure then
            f.Configure = function(self, opts)
                if opts and self.SetOptionData then
                    self:SetOptionData(opts)
                end
            end
        end
        FrameBase.BindInputAPI(f)
        return f
    end
end
