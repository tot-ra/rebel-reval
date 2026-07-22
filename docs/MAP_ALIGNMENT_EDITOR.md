# RRMap Alignment workspace

The `RRMap Alignment` Godot editor plugin provides a read-only visual workspace for checking whether streets, walls, shoreline, buildings, and transition openings continue correctly across any number of `.rrmap` files.

## Open the workspace

1. Open the project in Godot 4.7.1.
2. If needed, enable **RRMap Alignment** in **Project > Project Settings > Plugins**.
3. Open the **Map Alignment** main-screen tab at the top of the editor.
4. Collapse the bottom Output panel or use Godot's distraction-free mode if more vertical canvas space is needed. The workspace itself expands to all space available to the main-screen tab.

## Load and arrange maps

- **Load all maps** parses every source under `content/maps` and displays all of them on one canvas.
- To load a subset, use Cmd/Ctrl-click or Shift-click in **Map sources**, then click **Load selected**.
- Choose a **Layout root** before loading or auto-layout. **Auto-layout** follows reciprocal transitions and places linked map boundaries edge-to-edge.
- Maps without a reciprocal link, such as interiors or isolated prototypes, remain visible on a separate shelf below the connected graph.
- **Fit all** frames every visible layer. Fit is reapplied after the Godot main screen receives its final size, avoiding the small top-of-canvas result caused by fitting during plugin construction.

## Add a reference background

1. Click **Add background** in the toolbar or **Choose image** under **Reference background**.
2. Choose a PNG, JPEG, WebP, SVG, or BMP image. It is rendered below every loaded map, so the `.rrmap` layers remain visible on top.
3. Adjust **BG opacity** and **Scale**, then use the numeric **X** and **Y** fields for exact placement in world pixels.
4. Enable **Move background** to left-drag the image or move it with the arrow keys. Shift+arrow moves it by ten pixels. While this mode is enabled, middle-drag still pans the complete canvas.
5. Toggle **Background visible** to compare with and without the target, or click **Clear** to remove it.
6. **Fit all** frames the visible background together with all visible maps. **Export PNG** includes the background.

The selected image and its transform are temporary workspace state and are not copied into the project or written to `.rrmap` sources.

## Inspect and adjust layers

1. Select a loaded layer from the sidebar or click its map rectangle on the canvas.
2. Toggle layer visibility and adjust its opacity, or use **Blink selected layer**.
3. Toggle the grid, walls/buildings, and stable IDs as needed.
4. Drag to pan and use the mouse wheel to zoom.
5. Use arrow keys or toolbar arrow buttons to move the selected layer by one cell. Shift+arrow moves it by ten cells.
6. The status line reports loaded maps, reciprocal seams, transition-width mismatches, and the selected map offset.
7. Use **Export PNG** to save the visible multi-map canvas for review.

The workspace never rewrites a map. Apply intended coordinate or width changes to the authoritative `.rrmap`, reload the maps, and rerun the normal parser, audit, parity, route, and visual checks. This avoids creating a second map contract or treating editor-generated pixels as source data.

## Authored location portfolio

`content/maps` is the editor-facing source portfolio. In addition to the Reval
districts, harbour, Pirita, and Kalev's smithy, it contains these developer-only
greyboxes derived from the accepted campaign documents:

| RRMap | Working size (cells) | Main layout cues |
|---|---:|---|
| `st_olafs_guild_hall` | 32 x 20 | guild dais, long tables, hearth, return door |
| `world_sacred_grove` | 46 x 28 | oak ring, offering stone, bog spring |
| `world_harju` | 52 x 30 | split fields, farmsteads, well, road junction |
| `world_padise` | 50 x 30 | church, cloister, gatehouse, work yard |
| `world_saaremaa` | 50 x 28 | coastal water, camps, ferry/road junction |
| `world_rebel_kings` | 50 x 28 | council camp, supply shelter, two roads |
| `world_kanavere` | 54 x 30 | bog causeway, fieldworks, May 11 battlefield |
| `world_sojamae` | 54 x 30 | battle ridge, fieldworks, May 14 battlefield |
| `world_paide` | 50 x 30 | curtain walls, passable gatehouse, keep |
| `world_parnu` | 50 x 28 | town barricade, road and ferry junction |
| `world_poide` | 50 x 30 | curtain walls, passable gatehouse, island chapel |

The world transitions use `alignment=travel`. They remain visible as map exits,
but auto-layout does not pretend distant campaign locations physically touch one
another. Consequently **Load all maps** places these maps on the disconnected
prototype shelf; select the `world_*` sources together for a focused review.

This portfolio follows `docs/reports/global_map_mockups.md` and ADR 0008. Haapsalu,
Viljandi, Paldiski, Karja, Maasilinna, Swedish/Pskov event shells, and other legacy
concepts are intentionally not added to Map Alignment until an accepted campaign
or mission document promotes them.
