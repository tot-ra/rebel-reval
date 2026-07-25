---
name: icon-generator
description: Generate consistent 2D item icons for game inventory using Leonardo AI, with proper file format handling for Godot engine.
---

# 2D Inventory Icon Generation

## Goal

Generate consistent, high-quality 2D pixel art icons for game inventory items using Leonardo AI. Maintain a unified visual style across all icons for a cohesive inventory UI.

## Prompt Template

Use this exact prompt structure for all inventory icons. Replace `[OBJECT]` with the item description:

```
2D pixel art game inventory icon, [OBJECT], centered on solid dark brown background, 32-bit style, clean edges, no text, no shadows on ground
```

### Examples

| Item | Prompt |
|------|--------|
| Forge Hammer | `2D pixel art game inventory icon, medieval blacksmith forge hammer, iron head wooden handle, centered on solid dark brown background, 32-bit style, clean edges, no text, no shadows on ground` |
| Spearhead | `2D pixel art game inventory icon, medieval iron spearhead blade, pointed silver metal, centered on solid dark brown background, 32-bit style, clean edges, no text, no shadows on ground` |
| Watch Buckle | `2D pixel art game inventory icon, brass circular watch buckle, ornate golden metal clasp, centered on solid dark brown background, 32-bit style, clean edges, no text, no shadows on ground` |
| Hood | `2D pixel art game inventory icon, medieval brown leather hood hat, stitched leather cap, centered on solid dark brown background, 32-bit style, clean edges, no text, no shadows on ground` |
| Backpack | `2D pixel art game inventory icon, medieval canvas backpack with leather straps, brown fabric sack, centered on solid dark brown background, 32-bit style, clean edges, no text, no shadows on ground` |
| Combat Stick | `2D pixel art game inventory icon, simple wooden stick club with rope wrapping, centered on solid dark brown background, 32-bit style, clean edges, no text, no shadows on ground` |

### Style Keywords

- `2D pixel art` - Ensures flat, non-3D appearance
- `game inventory icon` - Signals game asset context
- `centered on solid dark brown background` - Consistent placement and background
- `32-bit style` - Retro game aesthetic
- `clean edges` - Sharp pixel art look
- `no text, no shadows on ground` - Clean icon without artifacts

### Prompt Variations

For different art styles, replace the style keywords:

| Style | Keywords |
|-------|----------|
| Realistic | `realistic medieval item, detailed textures, photorealistic` |
| Hand-drawn | `hand-drawn sketch style, ink lines, parchment texture` |
| Minimalist | `minimalist flat design, simple shapes, bold colors` |
| Dark fantasy | `dark fantasy style, moody lighting, gothic aesthetic` |

## Generation Settings

- **Tool**: `leonardo_generate_image`
- **Resolution**: 128x128 pixels (optimal for inventory icons)
- **Count**: 1 image per request (for consistency, regenerate if needed)

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
