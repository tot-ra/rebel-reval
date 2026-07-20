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
