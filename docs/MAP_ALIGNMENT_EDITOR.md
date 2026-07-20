# RRMap Alignment workspace

The `RRMap Alignment` Godot editor plugin provides a read-only visual workspace for checking whether streets, walls, shoreline, buildings, and transition openings continue correctly across two `.rrmap` files.

## Open the workspace

1. Open the project in Godot 4.7.1.
2. If needed, enable **RRMap Alignment** in **Project > Project Settings > Plugins**.
3. Open the **Map Alignment** main-screen tab at the top of the editor.

## Compare neighboring maps

1. Choose a **Base map** and **Neighbor**, then click **Load maps**.
2. Select a reciprocal **Linked seam** and click **Auto-align**. The workspace places the maps edge-to-edge and aligns the centers of their reciprocal transitions.
3. Use the opacity slider or **Blink neighbor** to compare features.
4. Toggle the grid, walls/buildings, and stable IDs as needed.
5. Drag to pan and use the mouse wheel to zoom.
6. Use arrow keys or the arrow buttons to move the neighbor by one cell. Shift+arrow moves it by ten cells.
7. Review the reported offset and transition span. `WIDTH MISMATCH` means the paired transition openings have different widths and need an explicit map-authoring decision.
8. Use **Export PNG** to save the current canvas for review.

The workspace never rewrites a map. Apply intended coordinate or width changes to the authoritative `.rrmap`, reload the pair, and rerun the normal parser, audit, parity, route, and visual checks. This avoids creating a second map contract or treating editor-generated pixels as source data.
