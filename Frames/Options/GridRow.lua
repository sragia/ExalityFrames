local _, ns = ...
---@class ExalityFrames
local EXFrames = ns.EXFrames

---@class ExalityFramesOptionsGridRow
local gridRow = EXFrames:GetFrame('options-grid-row')

local MAX_CELLS = 4
local CELL_GAP = 10

local function EnsureCells(rowFrame)
    if (rowFrame.cells) then
        return
    end

    rowFrame.cells = {}
    rowFrame.cellWidgets = {}

    for i = 1, MAX_CELLS do
        local cell = CreateFrame('Frame', nil, rowFrame)
        cell:Hide()
        rowFrame.cells[i] = cell
    end
end

gridRow.Configure = function(self, rowFrame)
    EnsureCells(rowFrame)
    rowFrame:SetClipsChildren(false)
end

gridRow.Reset = function(self, rowFrame, fieldPools)
    if (not rowFrame.cellWidgets) then
        return
    end

    for i = 1, MAX_CELLS do
        local widget = rowFrame.cellWidgets[i]
        if (widget) then
            fieldPools:Release(widget)
            rowFrame.cellWidgets[i] = nil
        end
        if (rowFrame.cells[i]) then
            rowFrame.cells[i]:Hide()
        end
    end
end

gridRow.Bind = function(self, rowFrame, rowPlan, rowWidth, fieldPools, bindTooltip)
    EnsureCells(rowFrame)
    self:Reset(rowFrame, fieldPools)

    rowFrame:SetWidth(rowWidth)
    rowFrame:SetHeight(rowPlan.height)

    local cells = rowPlan.cells
    local numCells = #cells
    local rowMaxWidth = math.max(1, rowWidth - (numCells * CELL_GAP))
    local rowMaxHeight = rowPlan.height
    local prevCell = nil

    for i = 1, numCells do
        local cellPlan = cells[i]
        local cell = rowFrame.cells[i]
        local widget = fieldPools:Acquire(cellPlan.descriptor)
        if (not widget) then
            cell:Hide()
        else
            bindTooltip(widget, cellPlan.descriptor.tooltip)
            rowFrame.cellWidgets[i] = widget

            local width = EXFrames:ScalePixel((cellPlan.widthPercent / 100) * rowMaxWidth, rowFrame)
            cell:SetSize(width, rowMaxHeight)
            cell:ClearAllPoints()
            if (prevCell) then
                cell:SetPoint('LEFT', prevCell, 'RIGHT', CELL_GAP, 0)
                cell:SetPoint('TOP', rowFrame, 'TOP', 0, 0)
            else
                cell:SetPoint('LEFT', rowFrame, 'LEFT', 0, 0)
                cell:SetPoint('TOP', rowFrame, 'TOP', 0, 0)
            end
            cell:Show()

            widget:SetParent(cell)
            widget:ClearAllPoints()
            if (widget.SetFrameWidth) then
                widget:SetFrameWidth(width)
            else
                widget:SetWidth(width)
            end

            local widgetHeight = widget:GetHeight() or rowMaxHeight
            local topPad = math.max(0, (rowMaxHeight - widgetHeight) / 2)
            local usesIntrinsicWidth = widget.usesIntrinsicWidth
                or cellPlan.descriptor.type == 'toggle'
                or cellPlan.descriptor.type == 'spacer'

            if (usesIntrinsicWidth) then
                widget:SetPoint('LEFT', cell, 'LEFT', 0, 0)
                widget:SetPoint('TOP', cell, 'TOP', 0, -topPad)
            else
                widget:SetPoint('TOPLEFT', cell, 'TOPLEFT', 0, -topPad)
                widget:SetPoint('TOPRIGHT', cell, 'TOPRIGHT', 0, -topPad)
            end
            widget:Show()

            prevCell = cell
        end
    end

    for i = numCells + 1, MAX_CELLS do
        rowFrame.cells[i]:Hide()
    end
end
