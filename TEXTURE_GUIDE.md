# ExalityFrames Texture Guide

All textures live in `ExalityFrames/Assets/`. The code references named slots in `EXFrames.assets.textures.ui.*` and `EXFrames.assets.textures.icon.*`. Swap the paths there once art is ready; 9-slice margins are already wired in each component.

---

## General rules

- **Format:** TGA (preferred) or PNG with alpha channel.
- **2× rule — for flat/icon textures only.** A close icon rendered at 10px → make the source 20–32px. This rule does NOT mean a panel texture needs to be 2× the panel's in-game size.
- **Solid white + alpha, not colored.** Every texture is tinted at runtime via `SetVertexColor`. Make the shape white/gray, use transparency for rounded corners.
- **Power-of-2 canvas.** WoW's sampler works best with 16, 32, 64, 128, 256, 512 px sides.
- **9-slice canvas ≠ panel size.** For a 9-slice texture the canvas only needs to be large enough to hold quality corner art. The center tiles/stretches to any size. Use **128×128** for all UI backgrounds.
- **Margin = corner pixel count in source.** `SetTextureSliceMargins(20, 20, 20, 20)` on a 128×128 canvas means the outer 20px on each side form the corners. Design your corner radius to match.

---

## UI background slots (`textures.ui.*`)

All textures: **128×128 canvas**, white fill on transparent background.
The margin in `SetTextureSliceMargins` must equal the corner radius in source pixels.

| Group | Radius | Margin | Elements |
|---|---|---|---|
| **8px** | 8px | 8 | Panel, Window, Dialog |
| **6px** | 6px | 6 | Button, Dropdown, EditBox, Title, MenuItem, Tab |

Fill textures and border textures within the same group share the same corner radius — **they must align pixel-perfectly**.

### `ui.panelBg` — panels, window background, dialogs
- **File:** `Assets/UI/panel-bg.png`
- **Canvas:** 128×128, **Code margins:** 8px, **Corner radius:** 8px
- **Content:** Rounded rectangle, white fill, transparent outside.
- **Used by:** Window, Panel, Dialog, InputDialog

### `ui.panelBorder` — border overlay for panels/window
- **File:** `Assets/UI/panel-border.png`
- **Canvas:** 128×128, **Code margins:** 8px, **Corner radius:** 8px (must match `panelBg`)
- **Content:** Transparent fill, 1–2px white border ring only.
- **Used by:** Panel (always visible), Window (enable by setting `borderOverlay:SetAlpha(1)`)

### `ui.buttonBg` — buttons, close button, title backgrounds
- **File:** `Assets/UI/button-bg.png`
- **Canvas:** 128×128, **Code margins:** 6px, **Corner radius:** 6px
- **Content:** Rounded rectangle, white fill, transparent corners.
- **Used by:** Button, ToggleButton, Title background

### `ui.inputBg` — edit boxes, dropdowns
- **File:** `Assets/UI/input-bg.png`
- **Canvas:** 128×128, **Code margins:** 6px, **Corner radius:** 6px
- **Content:** Same shape as `buttonBg` — can be the same file if you want identical rounding.
- **Used by:** EditBox bg, Dropdown bg

### `ui.inputBorder` — edit box border overlay
- **File:** `Assets/UI/input-border.png`
- **Canvas:** 128×128, **Code margins:** 6px, **Corner radius:** 6px (must match `inputBg`)
- **Content:** Transparent fill, 1–2px white border ring. Tinted `border` color normally, `accent` on hover/focus.
- **Used by:** EditBox border

### `ui.menuItemBg` — nav menu rows
- **File:** `Assets/UI/menu-item-bg.png`
- **Canvas:** 128×128, **Code margins:** 6px, **Corner radius:** 6px
- **Content:** Rounded rectangle, white fill, transparent corners.
- **Used by:** MenuItem, ModuleItem

### Tabs — underline + glow (not 9-slice pills)

Tabs no longer use filled `ui.tabActive` / `ui.tabInactive` backgrounds. Chrome is:

- **1px underline** — solid color via `SetColorTexture` (`Theme.accent` when active, `Theme.border` otherwise)
- **`tabs.glow`** — soft glow strip above the underline, accent-tinted, shown only on the active tab

| Slot | File | Notes |
|---|---|---|
| `textures.tabs.glow` | `Assets/Tabs/glow-bottom.png` | White on transparent; tinted with `Theme.accent` at runtime. Height ~20px in UI. |

`ui.tabActive` / `ui.tabInactive` slots remain in Core for legacy paths but are **unused** by `tabs-frame`.

---

## Icon slots (`textures.icon.*`)

Icons are rendered at 10–16 px, so source them at 32×32 minimum. Keep them **white on transparent** — `SetVertexColor` handles tinting.

Export from Lucide (https://lucide.dev) at 32 px stroke width 2, then:
1. Rasterize to 32×32 PNG.
2. Invert colors (black → white).
3. Save as TGA with alpha.

| Slot | File | Lucide icon | Display size |
|---|---|---|---|
| `icon.close` | `Assets/Icon/close.tga` | `x` | 10×10 |
| `icon.chevronDown` | `Assets/Icon/chevron-down.tga` | `chevron-down` | 12×12 |

---

## Other textures still using custom files

These are **not** replaced by the theme system and keep their original atlas-based design. They only need to be redrawn in the new color palette.

### Toggle atlas (`Assets/Inputs/Toggle/toggle.tga`)
- Single 256×256 atlas containing all toggle states (base, border-enabled, border-disabled, thumb-enabled, thumb-disabled).
- Current layout (texCoords are hardcoded in Toggle.lua). When remaking, keep the exact pixel positions or update the texCoords.
- Color: track background → `#292224`, enabled border → `#AB2346`, disabled border → `#5b626e`, thumb → `#EEEEEE`.

### Checkbox (`Assets/Inputs/Checkbox/`)
- `base.tga` — unchecked box outline, 20×20 source.
- `hover.tga` — same with lighter border.
- `mark.tga` — checkmark, white on transparent, 12×12 source.

### Range input (`Assets/Inputs/Range/`)
- `dot.tga`, `dot-active.tga` — slider thumb, 30×30 source, circular, white on transparent.
- `track.tga` — horizontal track background, 8 px tall, any width, can be a flat solid bar.
- `left-arrow.tga`, `right-arrow.tga`, `left-arrow-active.tga`, `right-arrow-active.tga` — 24×24 source, Lucide `chevron-left`/`chevron-right`.

### Anchor point selector (`Assets/Inputs/Anchor/`)
- `point-inactive.tga`, `point-active.tga` — 32×32 source, small dot or diamond shape.

---

## Resize button (`Assets/Window/`)
- `resize-btn.tga` — drag handle shown at window bottom, ~80×20 source. A simple row of dots or a grip line.
- `resize-btn-highlight.tga` — same with brighter color for hover.

---

## Quick checklist before delivering textures

- [ ] All files are TGA or PNG with alpha.
- [ ] Each file is at least 2× its in-game display size.
- [ ] Canvas dimensions are power-of-2.
- [ ] Colors are white (or neutral gray) so `SetVertexColor` tinting works correctly.
- [ ] 9-slice content fits inside the margin specified in the table above.
