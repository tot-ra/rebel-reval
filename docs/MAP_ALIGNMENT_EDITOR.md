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

## Inspect and adjust layers

1. Select a loaded layer from the sidebar or click its map rectangle on the canvas.
2. Toggle layer visibility and adjust its opacity, or use **Blink selected layer**.
3. Toggle the grid, walls/buildings, and stable IDs as needed.
4. Drag to pan and use the mouse wheel to zoom.
5. Use arrow keys or toolbar arrow buttons to move the selected layer by one cell. Shift+arrow moves it by ten cells.
6. The status line reports loaded maps, reciprocal seams, transition-width mismatches, and the selected map offset.
7. Use **Export PNG** to save the visible multi-map canvas for review.

The workspace never rewrites a map. Apply intended coordinate or width changes to the authoritative `.rrmap`, reload the maps, and rerun the normal parser, audit, parity, route, and visual checks. This avoids creating a second map contract or treating editor-generated pixels as source data.
