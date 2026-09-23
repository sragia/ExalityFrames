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
| **8px** | 8px | 8 | Legacy PNG paths only (see panel chrome note below) |
| **6px** | 6px | 6 | Button, Dropdown, EditBox, Title, MenuItem, Tab |

Fill textures and border textures within the same group share the same corner radius — **they must align pixel-perfectly**.

### Panel chrome (code — no PNG)

**Panel, Tabs content area, SplitOptions side panels, Window fill, Dialog, InputDialog, InputGroup, Disclaimer, ListMenu** use `EXFrames:ApplyPanelChrome`:

- **Fill:** `textures.solidWhite` + `SetVertexColor`
- **Border:** `ApplyInputBorder` (1px pixel-perfect edges, `Theme.border`)

### `ui.panelBg` / `ui.panelBorder` — legacy asset slots

- **Files:** `Assets/UI/panel-bg.png`, `Assets/UI/panel-border.png`
- **Status:** Registered in Core but **not used** by the components above after the rectangle chrome migration. Kept for optional art / other references.

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

Tab **labels** are unchanged: 1px underline + soft glow strip. Only the **content panel** below the tab bar uses rectangle panel chrome (`panel-frame`).

- **1px underline** — `SetColorTexture` (`Theme.accent` when active, `Theme.border` on hover, muted otherwise)
- **`tabs.glow`** — soft glow strip above the underline, accent-tinted at runtime

| Slot | File | Notes |
|---|---|---|
| `textures.tabs.glow` | `Assets/Tabs/glow-bottom.png` | White on transparent; tinted with `Theme.accent` at runtime. Height ~20px in UI. |

### SplitOptions list rows

- **Row fill:** `textures.solidWhite` + vertex color; **border:** `ApplyInputBorder`
- **`splitOptions.glow`** — full-row soft overlay on list items (same as before); side panels use rectangle `panel-frame` chrome only

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

### Toggle (`Assets/Inputs/Toggle/`)
- `toggle-bg.png` — track fill pill (@3x → 44×24 UI); tint `Theme.background`.
- `toggle-bg-border.png` — track outline pill; tint `border` / `accent`.
- `toggle-orb.png` — orb fill squircle (20×20); tint fill colors.
- `toggle-border.png` — orb ring squircle (20×20); tint border colors.
- No 9-slice; frames match 1× export size. Legacy `toggle.tga` unused.

### Checkbox (`Assets/Inputs/Checkbox/`)
- `checkbox-bg.png` — box fill (@2x → 18×18 UI); tint `Theme.background`.
- `checkbox-border.png` — box outline (18×18); tint `border` / `accent` when checked or tri-state include/negate.
- `checkbox-mark.png` — checkmark (~12×12 centered); tint `Theme.accent`.
- `checkbox-x.png` — close/X for tri-state negate (~11×11); tint `Theme.danger`.
- Legacy `base.png`, `hover.png`, `mark.png` — spell ID submit button only.

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
