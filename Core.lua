local addonName, ns = ...

---@class ExalityFrames
ns.EXFrames = {}

local BASE_PATH = 'Interface\\Addons\\' .. addonName .. '\\ExalityFrames\\'

local initIndx = 0
ns.EXFrames.frames = {}

ns.EXFrames.config = {}

ns.EXFrames.pixelPerfectBackdrops = {}
ns.EXFrames.inputBorders = {}

local function resolveScale(region)
  if region and region.GetEffectiveScale then
    return region:GetEffectiveScale()
  end
  return UIParent:GetEffectiveScale()
end

local function scalePixel(value, region, minPixels)
  if ns.EXFrames.config.scalePixel then
    return ns.EXFrames.config.scalePixel(value, region, minPixels)
  end
  return PixelUtil.GetNearestPixelSize(value, resolveScale(region), minPixels)
end

ns.EXFrames.ScalePixel = function(self, value, region, minPixels)
  return scalePixel(value, region, minPixels)
end

ns.EXFrames.ScalePixels = function(self, pixelCount, region)
  local scale = resolveScale(region)
  return (pixelCount * PixelUtil.GetPixelToUIUnitFactor()) / scale
end

ns.EXFrames.RegisterPixelPerfectBackdrop = function(self, frame, borderSize)
  borderSize = borderSize or 1
  table.insert(self.pixelPerfectBackdrops, { frame = frame, borderSize = borderSize })
  frame:SetBackdrop(self.assets.backdrop.pixelPerfect(borderSize, frame))
end

ns.EXFrames.RefreshPixelPerfect = function(self)
  for i = #self.pixelPerfectBackdrops, 1, -1 do
    local entry = self.pixelPerfectBackdrops[i]
    if entry.frame and entry.frame.SetBackdrop then
      if self.config.snapFrame then
        self.config.snapFrame(entry.frame)
      end
      entry.frame:SetBackdrop(self.assets.backdrop.pixelPerfect(entry.borderSize, entry.frame))
    else
      table.remove(self.pixelPerfectBackdrops, i)
    end
  end
  self:RefreshInputBorders()
end

ns.EXFrames.ApplyInputBorder = function(self, frame, borderSize)
  borderSize = borderSize or 1
  if not frame.PPBorder and self.config.addPixelPerfectBorder then
    frame.PPBorder = self.config.addPixelPerfectBorder(frame, borderSize, { register = false })
    if frame.PPBorder then
      table.insert(self.inputBorders, frame)
    end
  end
  if frame.PPBorder then
    frame.PPBorder:SetBorderThickness(borderSize)
    frame.PPBorder:SetBorderColor(unpack(self.Theme.border))
  end
  if not frame.SetInputBorderActive then
    local theme = self.Theme
    frame.SetInputBorderActive = function(activeFrame, active)
      if not activeFrame.PPBorder then return end
      if active then
        activeFrame.PPBorder:SetBorderColor(unpack(theme.accent))
      else
        activeFrame.PPBorder:SetBorderColor(unpack(theme.border))
      end
    end
  end
  return frame.PPBorder
end

ns.EXFrames.RefreshInputBorders = function(self)
  for i = #self.inputBorders, 1, -1 do
    local frame = self.inputBorders[i]
    if frame and frame.PPBorder then
      frame.PPBorder:SetBorderThickness(frame.PPBorder.thicknessPixels or 1)
    else
      table.remove(self.inputBorders, i)
    end
  end
end

-- Color palette. Override per-project with EXFrames:SetTheme().
ns.EXFrames.Theme = {
  white           = { 237 / 255, 237 / 255, 237 / 255, 1 }, -- #ededed
  backgroundLight = { 36 / 255, 31 / 255, 32 / 255, 1 },    -- #332b2d
  background      = { 25 / 255, 21 / 255, 22 / 255, 1 },    -- #191516  main window bg
  backgroundDeep  = { 0.059, 0.059, 0.059, 1 },             -- #0f0f0f  deepest dark
  backgroundPanel = { 40 / 255, 34 / 255, 35 / 255, 0.4 },  -- #282223  panels / header
  accent          = { 0.671, 0.137, 0.275, 1 },             -- #AB2346
  accentLight     = { 0.906, 0.200, 0.380, 1 },             -- #e73361
  accentDark      = { 135 / 255, 24 / 255, 51 / 255, 1 },   -- #871833
  border          = { 0.161, 0.133, 0.141, 1 },             -- #292224
  borderActive    = { 245 / 255, 7 / 255, 68 / 255, 1 },    -- #f50744  selected border
  text            = { 0.933, 0.933, 0.933, 1 },             -- #EEEEEE
  textMuted       = { 0.357, 0.384, 0.431, 1 },             -- #5b626e
  danger          = { 0.502, 0.067, 0.000, 1 },             -- close / destructive
  dangerHover     = { 0.671, 0.090, 0.000, 1 },
  success         = { 0.173, 0.569, 0.000, 1 },
  successDark     = { 0.125, 0.412, 0.000, 1 },
  inProgress      = { 242 / 255, 109 / 255, 0, 1 },      -- #f26d00
  faded           = { 28 / 255, 28 / 255, 28 / 255, 1 }, -- #1c1c1c
  gray            = { 74 / 255, 61 / 255, 65 / 255, 1 }, -- #4a3d41
}

ns.EXFrames.SetTheme = function(self, overrides)
  for k, v in pairs(overrides) do
    self.Theme[k] = v
  end
end

ns.EXFrames.GetFrame = function(self, id)
  if (not self.frames[id]) then
    initIndx = initIndx + 1
    self.frames[id] = {
      _index = initIndx
    }
  end

  return self.frames[id]
end

ns.EXFrames.InitFrames = function(self)
  for _, frame in self.utils.spairs(self.frames, function(t, a, b) return t[a]._index < t[b]._index end) do
    if (frame.Init) then
      frame:Init()
    end
  end
end

---@param self ExalityFrames
---@param config {logoPath?: string, defaultFontPath?: string}
ns.EXFrames.Configure = function(self, config)
  self.config = config
end

local randCharSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
ns.EXFrames.utils = {
  spairs = function(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do
      keys[#keys + 1] = k
    end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
      table.sort(
        keys,
        function(a, b)
          return order(t, a, b)
        end
      )
    else
      table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
      i = i + 1
      if keys[i] then
        return keys[i], t[keys[i]]
      end
    end
  end,
  generateRandomString = function(length)
    length = length or 10
    local output = ""
    for i = 1, length do
      local rand = math.random(#randCharSet)
      output = output .. string.sub(randCharSet, rand, rand)
    end
    return output
  end,
  animation = {
    getAnimationGroup = function(f)
      return f:CreateAnimationGroup();
    end,
    fade = function(f, duration, from, to, ag)
      ag = ag or f:CreateAnimationGroup()
      local fade = ag:CreateAnimation('Alpha')
      fade:SetFromAlpha(from or 0)
      fade:SetToAlpha(to or 1)
      fade:SetDuration(duration or 1)
      fade:SetSmoothing((from > to) and 'OUT' or 'IN')
      local finishScript = ag:GetScript('OnFinished')
      ag:SetScript(
        'OnFinished',
        function(...)
          if (finishScript) then finishScript(...) end
          f:SetAlpha(to)
        end
      )
      return ag
    end,
    diveIn = function(f, duration, xOff, yOff, smoothing, ag)
      ag = ag or f:CreateAnimationGroup()
      local translate = ag:CreateAnimation('Translation')
      translate:SetOffset(xOff, -yOff)
      translate:SetDuration(duration)
      translate:SetSmoothing(smoothing)
      ag:SetScript('OnPlay', function()
        if (smoothing == 'OUT') then
          return
        end

        for i = 1, f:GetNumPoints() do
          local point, relativeTo, relativePoint, xOfs, yOfs = f:GetPoint(i)
          f:SetPoint(point, relativeTo, relativePoint, xOfs + xOff, yOfs + yOff)
        end
      end)
      local finishScript = ag:GetScript('OnFinished')
      ag:SetScript('OnFinished', function(...)
        if (finishScript) then finishScript(...) end

        if (smoothing == 'OUT') then
          return
        end

        for i = 1, f:GetNumPoints() do
          local point, relativeTo, relativePoint, xOfs, yOfs = f:GetPoint(i)
          f:SetPoint(point, relativeTo, relativePoint, xOfs - xOff, yOfs - yOff)
        end
      end)

      return ag
    end,
    move = function(f, duration, xOff, yOff, ag)
      ag = ag or f:CreateAnimationGroup()
      local translate = ag:CreateAnimation('Translation')
      translate:SetOffset(xOff, yOff)
      translate:SetDuration(duration)
      local finishScript = ag:GetScript('OnFinished')
      ag:SetScript('OnFinished', function(...)
        if (finishScript) then finishScript(...) end

        for i = 1, f:GetNumPoints() do
          local point, relativeTo, relativePoint, xOfs, yOfs = f:GetPoint(i)
          f:SetPoint(point, relativeTo, relativePoint, xOfs + xOff, yOfs + yOff)
        end
      end)

      return ag
    end,
    lerpSize = function(frame, duration, toW, toH, onFinished, onUpdate)
      local fromW = frame:GetWidth()
      local fromH = frame:GetHeight()
      local elapsed = 0
      local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
      local startX = xOfs or 0
      local startY = yOfs or 0

      frame:SetScript('OnUpdate', function(self, dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / duration, 1)
        local w = fromW + (toW - fromW) * t
        local h = fromH + (toH - fromH) * t

        self:SetSize(w, h)
        if (point == 'CENTER') then
          self:SetPoint(point, relativeTo, relativePoint, startX - (w - fromW) / 2, startY)
        end

        if (onUpdate) then
          onUpdate(t, w, h)
        end

        if (t >= 1) then
          self:SetScript('OnUpdate', nil)
          self:SetSize(toW, toH)
          if (point == 'CENTER') then
            self:SetPoint(point, relativeTo, relativePoint, startX - (toW - fromW) / 2, startY)
          end
          if (onFinished) then
            onFinished()
          end
        end
      end)
    end,
  },
  texture = {
    clampSliceMargins = function(left, top, right, bottom, width, height, minCenter)
      minCenter = minCenter or 1
      if (not width or not height or width <= 0 or height <= 0) then
        return left, top, right, bottom
      end

      local horizontal = left + right
      local maxHorizontal = width - minCenter
      if (horizontal > maxHorizontal and horizontal > 0) then
        local scale = maxHorizontal / horizontal
        left = left * scale
        right = right * scale
      end

      local vertical = top + bottom
      local maxVertical = height - minCenter
      if (vertical > maxVertical and vertical > 0) then
        local scale = maxVertical / vertical
        top = top * scale
        bottom = bottom * scale
      end

      return left, top, right, bottom
    end,
    applySlice = function(tex, margins, region, sliceMode)
      local left, top, right, bottom

      -- Support both static numbers and dynamic functions
      if (type(margins) == 'function') then
        -- Call the function with width and height to get adaptive margins
        margins = margins(region:GetWidth(), region:GetHeight())
      end

      if (type(margins) == 'number') then
        left, top, right, bottom = margins, margins, margins, margins
      else
        left, top, right, bottom = margins[1], margins[2], margins[3], margins[4]
      end

      left, top, right, bottom = ns.EXFrames.utils.texture.clampSliceMargins(
        left, top, right, bottom,
        region:GetWidth(),
        region:GetHeight()
      )

      tex:SetTextureSliceMargins(left, top, right, bottom)
      if (sliceMode) then
        tex:SetTextureSliceMode(sliceMode)
      end
    end,
    bindSliceToRegion = function(region, entries)
      local function update()
        if (region:GetWidth() <= 0 or region:GetHeight() <= 0) then
          return
        end
        for _, entry in ipairs(entries) do
          ns.EXFrames.utils.texture.applySlice(entry.tex, entry.margins, region, entry.mode)
        end
      end

      region:HookScript('OnSizeChanged', update)
      region:HookScript('OnShow', update)
      update()
    end,
  },
  addObserver = function(t, force)
    if (t.observable and not force) then
      return t
    end

    t.observable = {}
    t.Observe = function(_, key, onChangeFunc)
      if (type(key) == 'table') then
        for _, k in ipairs(key) do
          t.observable[k] = t.observable[k] or {}
          table.insert(t.observable[k], onChangeFunc)
        end
      else
        t.observable[key] = t.observable[key] or {}
        table.insert(t.observable[key], onChangeFunc)
      end
    end
    t.SetValue = function(self, key, value)
      local oldValue = t[key]
      t[key] = value
      if (t.observable[key]) then
        for _, func in ipairs(t.observable[key]) do
          func(value, oldValue, key, self)
        end
      end
      if (t.observable['']) then
        for _, func in ipairs(t.observable['']) do
          func(value, oldValue, key, self)
        end
      end
    end
    t.ObserveAll = function(_, onChangeFunc)
      t.observable[''] = t.observable[''] or {}
      table.insert(t.observable[''], onChangeFunc)
    end

    t.ClearObservable = function(self)
      self.observable = {}
    end

    return t
  end,
}

ns.EXFrames.assets = {
  textures = {
    solidWhite = "Interface\\Buttons\\WHITE8X8.blp",
    solidWhiteTexture = BASE_PATH .. "Assets\\white-textured.png",

    -- Swap these for proper 9-slice PNGs when ready. See TEXTURE_GUIDE.md.
    ui = {
      panelBg        = BASE_PATH .. "Assets\\UI\\panel-bg.png",         -- fill,   margins 20
      panelBorder    = BASE_PATH .. "Assets\\UI\\panel-border.png",     -- border, margins 20
      buttonBg       = BASE_PATH .. "Assets\\UI\\button-bg.png",        -- fill,   margins 6
      inputBg        = BASE_PATH .. "Assets\\UI\\button-bg.png",        -- fill,   margins 40
      inputBorder    = BASE_PATH .. "Assets\\UI\\input-border.png",     -- border, margins 40
      menuItemBg     = BASE_PATH .. "Assets\\UI\\menu-item-bg.png",     -- fill,   margins 6
      menuItemBorder = BASE_PATH .. "Assets\\UI\\menu-item-border.png", -- border, margins 6
      tabActive      = "Interface\\Buttons\\WHITE8X8.blp",              -- margins 12
      tabInactive    = "Interface\\Buttons\\WHITE8X8.blp",              -- margins 12
    },

    window = {
      bg = BASE_PATH .. 'Assets\\Window\\bg',
      resizeBtn = BASE_PATH .. 'Assets\\Window\\resize-btn',
      resizeBtnHighlight = BASE_PATH .. 'Assets\\Window\\resize-btn-highlight',
    },
    input = {
      buttonBg = BASE_PATH .. 'Assets\\Inputs\\button-bg.png',
      buttonHover = BASE_PATH .. 'Assets\\Inputs\\button-hover.png',
      editBoxBg = BASE_PATH .. 'Assets\\Inputs\\editbox-bg',
      editBoxHover = BASE_PATH .. 'Assets\\Inputs\\editbox-hover',
      toggle = BASE_PATH .. 'Assets\\Inputs\\Toggle\\toggle',
      range = {
        dot = BASE_PATH .. 'Assets\\Inputs\\Range\\dot.png',
        dotActive = BASE_PATH .. 'Assets\\Inputs\\Range\\dot-active.png',
        editBox = BASE_PATH .. 'Assets\\Inputs\\Range\\editbox.png',
        leftArrow = BASE_PATH .. 'Assets\\Inputs\\Range\\left-arrow.png',
        leftArrowActive = BASE_PATH .. 'Assets\\Inputs\\Range\\left-arrow-active.png',
        rightArrow = BASE_PATH .. 'Assets\\Inputs\\Range\\right-arrow.png',
        rightArrowActive = BASE_PATH .. 'Assets\\Inputs\\Range\\right-arrow-active.png',
        track = BASE_PATH .. 'Assets\\Inputs\\Range\\track.png',
      },
      anchorPoint = {
        active = BASE_PATH .. 'Assets\\Inputs\\Anchor\\point-active.png',
        inactive = BASE_PATH .. 'Assets\\Inputs\\Anchor\\point-inactive.png',
      },
      checkbox = {
        base = BASE_PATH .. 'Assets\\Inputs\\Checkbox\\base.png',
        hover = BASE_PATH .. 'Assets\\Inputs\\Checkbox\\hover.png',
        mark = BASE_PATH .. 'Assets\\Inputs\\Checkbox\\mark.png',
      }
    },
    icon = {
      close = BASE_PATH .. 'Assets\\Icon\\close.png',
      chevronDown = BASE_PATH .. 'Assets\\Icon\\chevronDown',
    },
    tabs = {
      active = BASE_PATH .. 'Assets\\Tabs\\active.png',
      inactive = BASE_PATH .. 'Assets\\Tabs\\inactive.png',
    },
    menuItem = {
      bg = BASE_PATH .. 'Assets\\MenuItem\\bg.png',
      border = BASE_PATH .. 'Assets\\MenuItem\\border.png',
      expandBg = BASE_PATH .. 'Assets\\MenuItem\\expand-bg.png',
      glow = BASE_PATH .. 'Assets\\MenuItem\\glow.png',
      minus = BASE_PATH .. 'Assets\\MenuItem\\minus.png',
      plus = BASE_PATH .. 'Assets\\MenuItem\\plus.png',
    },
    titleBg = BASE_PATH .. 'Assets\\title-bg.png',
    statusBar = BASE_PATH .. 'Assets\\StatusBar\\statusBar',
    solidBg = BASE_PATH .. 'Assets\\white.png',
  },
  backdrop = {
    DEFAULT = {
      bgFile = "Interface\\BUTTONS\\WHITE8X8.blp",
      edgeFile = "Interface\\BUTTONS\\WHITE8X8.blp",
      tile = false,
      tileSize = 0,
      edgeSize = 1,
      insets = { left = 0, right = 0, top = 0, bottom = 0 }
    },
    pixelPerfect = function(borderSize, region)
      borderSize = borderSize or 1
      local edge = ns.EXFrames:ScalePixels(borderSize, region)
      return {
        bgFile = "Interface\\BUTTONS\\WHITE8X8.blp",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8.blp",
        tile = false,
        tileSize = 0,
        edgeSize = edge,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
      }
    end
  },
  font = {
    default = function()
      return ns.EXFrames.config.defaultFontPath or BASE_PATH .. 'Assets\\Font\\DMSans.ttf'
    end,
  }
}

ns.EXFrames.handler = CreateFrame('Frame')
ns.EXFrames.handler:RegisterEvent('ADDON_LOADED')

ns.EXFrames.handler.eventHandlers = {
  --[[
    [event] = {
        [id] = function(event, ...)
    }
    ]]
}

ns.EXFrames.handler:SetScript('OnEvent', function(self, event, ...)
  if (event == 'ADDON_LOADED' and ... == addonName) then
    ns.EXFrames:InitFrames()
  end
end)

--- Callbacks
--[[
    {
        events = { 'event1', 'event2' },
        func = function(event, ...)
    }
]]
ns.EXFrames.callbacks = {}

ns.EXFrames.RegisterCallback = function(self, config)
  table.insert(ns.EXFrames.callbacks, config)
end

ns.EXFrames.Callback = function(self, event, ...)
  for _, callback in ipairs(self.callbacks) do
    if (FindInTable(callback.events, event)) then
      callback.func(event, ...)
    end
  end
end
