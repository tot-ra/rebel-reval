# RRMap Editor workspace

The `RRMap Editor` Godot addon combines a visual map editor with the existing multi-map alignment workspace. Canonical `.rrmap` text remains authoritative, so humans can work visually while LLMs can make compact, deterministic, reviewable text changes. Every visual mutation is compiled by the normal map pipeline before preview and is saved through `MapRrmapSerializer`; the addon does not introduce a scene, TileMap, or editor-only map format.

The workspace has two focused modes so editing and multi-map alignment do not compete for the same crowded sidebar:

| Mode | Use when | Primary actions |
|---|---|---|
| **Edit map** | Authoring one `.rrmap` | Place terrain / buildings / props, select-move, Save / Revert |
| **Align maps** | Checking seams and neighbors | Load selected/all, auto-layout, layer opacity, reference background |

## Open the workspace

1. Open the project in Godot 4.7.1.
2. If needed, enable **RRMap Editor** in **Project > Project Settings > Plugins**.
3. Open the **RRMap Editor** main-screen tab at the top of the editor, or double-click any `.rrmap` resource in the FileSystem dock to load it directly in **Edit map** mode.
4. Collapse the bottom Output panel or use Godot's distraction-free mode if more vertical canvas space is needed. The workspace itself expands to all space available to the main-screen tab.

## Edit a map (default authoring path)

1. Double-click a source in **Map sources**, click **Open selected**, or open a `.rrmap` from the FileSystem dock.
2. Choose a tool with the sidebar buttons or keys **1-4**:
   - **Terrain (1)** - paints one semantic terrain cell
   - **Building (2)** - places the selected building kind with the W/H footprint
   - **Prop (3)** - places a compiler-supported prop; type in the filter box to narrow the list
   - **Select (4)** - selects the topmost authored primitive; arrow keys move it (Shift = 10 cells)
3. Right-click removes the topmost authored primitive under the cursor.
4. Props render as blue markers on the canvas; the current selection gets a yellow outline.
5. **Save map** compiles and writes canonical text back to the original source path. **Revert** discards the visual draft and reparses the file.
6. Enable **Show advanced** only when you need map size or ground height controls.

Visual edits currently operate on direct RRMap primitives. They preserve stable IDs and typed options when moving existing entries, but the compact controls do not yet expose every option or create complex multi-point primitives. Use the text source for styles, prefab instances, transition destinations, patrol paths, detailed overrides, and comments. Canonical save rewrites comments, so do not use visual Save when source comments must be retained verbatim.

Placement stays responsive on district maps because prop/building/move previews skip rebuilding the terrain texture; terrain paint and removals still rebuild it. The editor still compiles through the normal blueprint pipeline before accepting a mutation.

## Align maps

1. Switch to **Align maps**.
2. **Load all maps** parses every source under `content/maps` and displays all of them on one canvas.
3. To load a subset, use Cmd/Ctrl-click or Shift-click in **Map sources**, then click **Load selected**.
4. Choose a **Layout root** before loading or auto-layout. **Auto-layout** follows reciprocal transitions and places linked map boundaries edge-to-edge.
5. Maps without a reciprocal link, such as interiors or isolated prototypes, remain visible on a separate shelf below the connected graph.
6. **Fit all** frames every visible layer. Fit is reapplied after the Godot main screen receives its final size, avoiding the small top-of-canvas result caused by fitting during plugin construction.
7. Toggle layer visibility and opacity, or use **Blink selected layer**.
8. Use arrow keys or toolbar arrow buttons to move the selected layer by one cell. Shift+arrow moves it by ten cells.
9. The status line reports loaded maps, reciprocal seams, transition-width mismatches, and the selected map offset.
10. Use **Export PNG** to save the visible multi-map canvas for review.

## Add a reference background

Background controls live under **Show advanced** in Align mode (or **Add background** on the Align toolbar).

1. Choose a PNG, JPEG, WebP, SVG, or BMP image. It is rendered below every loaded map, so the `.rrmap` layers remain visible on top.
2. Adjust **BG opacity** and **Scale**, then use the numeric **X** and **Y** fields for exact placement in world pixels.
3. Enable **Move background** to left-drag the image or move it with the arrow keys. Shift+arrow moves it by ten pixels. While this mode is enabled, middle-drag still pans the complete canvas.
4. Toggle **Background visible** to compare with and without the target, or click **Clear** to remove it.
5. **Fit all** frames the visible background together with all visible maps. **Export PNG** includes the background.

The selected image and its transform are temporary workspace state and are not copied into the project or written to `.rrmap` sources.

Layer offsets and reference backgrounds are temporary alignment state and are not written to map sources. Map edits are written only when **Save map** is pressed. After saving, rerun the normal parser, audit, parity, route, and visual checks; the editor uses the same compiler contract but does not replace those production gates.

## Authored location portfolio

`content/maps` is the editor-facing source portfolio. In addition to the Reval
districts, harbour, Pirita, and Kalev's smithy, it contains these developer-only
greyboxes derived from the accepted campaign documents:

| RRMap | Working size (cells) | Main layout cues |
|---|---:|---|
| `st_olafs_guild_hall` | 32 x 20 | guild dais, long tables, hearth, return door |
| `world_sacred_grove` | 46 x 28 | oak ring, offering stone, bog spring |
| `world_harju` | 52 x 30 | split fields, farmsteads, well, road junction |
| `world_padise` | 140 x 90 | open pre-quadrangle estate: early western stone house, detached timber conventual buildings, grange, surrounding fields, river and ford |
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
