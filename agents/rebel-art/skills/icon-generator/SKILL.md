---
name: icon-generator
description: Generate consistent 2D item icons for game inventory using Leonardo AI, with proper file format handling for Godot engine.
---

# 2D Inventory Icon Generation

## Goal

Generate consistent, historically grounded inventory icons using Leonardo AI under ADR 0018: saturated fantasy/anime painting, a crisp silhouette, material-specific high detail, and controlled HDR-range accents. Maintain one coherent visual language across the inventory UI.

## Prompt Template

Use this exact prompt structure for all inventory icons. Replace `[OBJECT]` with the item description:

```
2D game inventory icon, historically grounded medieval [OBJECT], high-detail fantasy/anime painterly rendering, rich controlled saturation, crisp expressive silhouette, material-specific meso and micro detail, controlled HDR-range rim and specular accents, three-quarter view, centered on transparent background, no text, no logo, no floor shadow, no bloom halo, no modern ornament
```

### Examples

| Item | Prompt |
|------|--------|
| Forge Hammer | `2D game inventory icon, historically grounded 1343 blacksmith hammer, iron head and polished oak handle, high-detail fantasy/anime painterly rendering, crimson reflected light and forge-amber rim, crisp three-quarter silhouette, hammered metal and wood-grain detail, transparent background, no text or bloom halo` |
| Spearhead | `2D game inventory icon, historically grounded forged iron spearhead, high-detail fantasy/anime painterly rendering, cool iron-blue body and controlled cyan edge, crisp three-quarter silhouette, hammer marks and sharpened bevel detail, transparent background, no text or bloom halo` |
| Watch Buckle | `2D game inventory icon, historically grounded medieval brass buckle, high-detail fantasy/anime painterly rendering, rich copper-gold color and controlled specular accent, crisp three-quarter silhouette, casting and wear detail, transparent background, no text or bloom halo` |
| Hood | `2D game inventory icon, historically grounded medieval wool hood, high-detail fantasy/anime painterly rendering, saturated indigo cloth and warm lining, crisp folded silhouette, seams, weave, and wear detail, transparent background, no text or bloom halo` |
| Backpack | `2D game inventory icon, historically grounded medieval satchel, high-detail fantasy/anime painterly rendering, rich ochre cloth and brown leather, crisp three-quarter silhouette, straps, stitching, and handling wear, transparent background, no text or bloom halo` |
| Combat Stick | `2D game inventory icon, historically grounded wooden cudgel with hemp grip, high-detail fantasy/anime painterly rendering, rich oak color and controlled rim light, crisp diagonal silhouette, grain, cut, and binding detail, transparent background, no text or bloom halo` |

### Style Keywords

- `historically grounded medieval` - Keeps form, construction, and material period-correct
- `high-detail fantasy/anime painterly rendering` - Applies the binding expressive finish
- `rich controlled saturation` - Avoids pale output without making every pixel equally loud
- `crisp expressive silhouette` - Preserves recognition at inventory scale
- `material-specific meso and micro detail` - Adds construction and close craft rather than random noise
- `transparent background` - Keeps the icon compatible with the ornate inventory frame
- `no text, no logo, no floor shadow, no bloom halo` - Prevents common generated artifacts

### Prompt Variations

For different art styles, replace the style keywords:

| Style | Keywords |
|-------|----------|
| Standard v1.1 | `high-detail fantasy/anime painterly item, rich controlled saturation, crisp silhouette` |
| Folklore | `Baltic folklore accent, luminous symbolic motif authorized by canon, painterly PBR material read` |
| Document | `illuminated manuscript influence, saturated mineral pigments, crisp period ink and parchment detail` |
| Ominous | `dark historical fantasy, cobalt shadows, selective crimson and amber accents, controlled glow` |

## Generation Settings

- **Tool**: `leonardo_generate_image`
- **Source resolution**: 512x512 pixels minimum; downscale to the runtime size after curation
- **Count**: 2 candidates per request, curate one; regenerate only for objective defects or style drift

## File Format Handling

### Why PNG Conversion is Required

Leonardo AI outputs JPEG files (.jpg). Godot engine requires proper PNG files for texture imports:

1. **File Headers**: Godot's resource loader checks file magic bytes, not extensions
2. **Transparency**: PNG supports alpha channel for transparent backgrounds
3. **Import Cache**: Godot caches imported resources in `.import` files

### Conversion Process

Always convert Leonardo outputs to PNG before placing in project:

```python
from PIL import Image

# Convert JPEG to PNG
img = Image.open('generated/leonardo/xxx.jpg')
img.save('assets/UI/inventory/item_name.png', 'PNG')
```

### Import Cache

After replacing icon files, delete `.import` files to force Godot re-import:

```bash
rm -f assets/UI/inventory/*.import
```

## Integration with Godot

### JSON Schema

Add `icon` field to item JSON files:

```json
{
  "type": "item",
  "id": "item.forge_hammer",
  "name": "Forge hammer",
  "icon": "res://assets/UI/inventory/forge_hammer.png",
  "category": "weapon"
}
```

### Schema Definition

Add to `schemas/item.schema.json`:

```json
"icon": {
  "type": "string",
  "description": "Relative path to the item icon texture (e.g. 'res://assets/UI/inventory/forge_hammer.png'). Optional."
}
```

### Code Pattern

In `inventory_overlay.gd`, load icons at runtime:

```gdscript
# Apply item icon texture if available, scaling to fit the cell.
# WHY: only the origin cell shows icon + label; multi-cell footprints stay
# as a tinted shape so the player can see the item footprint without
# cluttering every occupied cell with a duplicate icon.
if is_origin:
    var icon_path: String = record.get("icon", "")
    if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
        var icon_tex: Texture2D = ResourceLoader.load(icon_path) as Texture2D
        if icon_tex != null:
            button.icon = icon_tex
            button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
            button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
            button.expand_icon = true
            # Keep the short label visible alongside the icon.
            button.text = _short_label(record, placement.quantity)
```

### Key Points

- Use `ResourceLoader.load()` not bare `load()` for runtime texture loading
- Only show icon on origin cell (first cell) of multi-cell items
- Clear `button.icon = null` for empty cells
- `expand_icon = true` scales icon to fit cell

## Output Structure

```
assets/UI/inventory/
  forge_hammer.png
  spearhead.png
  watch_buckle.png
  combat_stick.png
  hood.png
  backpack.png
```

## Quality Checklist

- [ ] All icons use same prompt template structure
- [ ] All icons are 128x128 PNG files
- [ ] All icons have consistent dark brown background
- [ ] JSON files have `icon` field pointing to correct path
- [ ] `.import` files deleted after icon replacement
- [ ] Icons display correctly in Godot inventory UI

## Troubleshooting

### Icons Not Showing

1. **Check file format**: Run `file assets/UI/inventory/*.png` - should say "PNG image data"
2. **Check JSON paths**: Verify `icon` field exists and path is correct
3. **Clear import cache**: Delete `.import` files
4. **Restart Godot**: Force re-import of resources

### Inconsistent Style

1. Use exact same prompt template
2. Keep same resolution (128x128)
3. Use same Leonardo model/checkpoint
4. Regenerate all icons in same session for consistency
