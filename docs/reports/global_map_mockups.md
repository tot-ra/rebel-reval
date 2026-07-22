# Estonia global-map mockup portfolio

Recorded: 2026-07-22  
Scope: developer traversal only (`release=false`)

## Selection

The active product sources (`README.md`, `docs/CANON.md`, and ADR 0008) identify the campaign locations needed beyond Reval. Four were already available as playable mockups: Harju Village, Sacred Grove, Padise Monastery, and Saaremaa. This pass adds the missing campaign nodes that already had an outdoor prototype or are explicitly required by the accepted campaign plan:

- Rebel Kings' Camp - Act 2 Harju command hub.
- Kanavere Bog - attested May 11 battlefield.
- Sõjamäe - attested May 14 battlefield near Reval.
- Paide Castle - Act 2 finale and fate of the Four Kings.
- Pärnu - southern campaign town named in the campaign overview.
- Pöide Castle - Act 3 Saaremaa objective.

Haapsalu, Viljandi, Paldiski, Karja, Maasilinna, Swedish/Pskov event shells, and other archived concepts remain inactive. They are not named as required traversal nodes in the current three-act campaign outline, or require a later authored mission decision rather than another generic map marker.

## Developer route graph

The global layer is a graph, not unrestricted teleportation. Every edge has reciprocal map doors and stable manifest spawn IDs. The additional edges are Harju-Sacred Grove, Harju-Rebel Kings, Harju-Kanavere, Harju-Sõjamäe, Rebel Kings-Kanavere, Kanavere-Paide, Sõjamäe-Paide, Paide-Pärnu, Padise-Pärnu, Pärnu-Saaremaa, and Saaremaa-Pöide. Existing direct Reval links remain through Karja Gate, Viru road, the western Toompea road, and the harbour.

```text
Reval -- Sacred Grove -- Harju -- Rebel Kings' Camp
   |                         \       /
   +-- Harju ---------------- Kanavere -- Paide -- Pärnu -- Padise -- Reval
   |                           /          /          |
   +-- Harju -- Sõjamäe ------          /           ferry
   |                                               |
   +---------------- harbour ------------------ Saaremaa -- Pöide
```

## Implementation contract

- `GlobalMapCatalog` owns marker positions, adjacency, and travel planning.
- `content/maps/world_*.rrmap` owns the visible greybox geometry, working dimensions, landmarks, and reciprocal transition doors.
- `DistantLocationDefinitions` parses those same sources for scene assembly, preventing Map Alignment and developer traversal from drifting apart.
- `DoorNavigator` remains the sole scene/spawn registry through `content/transitions/active_destinations.json`.
- All world scenes are `release=false`; release Start flow is unchanged.
- Tests verify adjacency-only travel, reciprocal definition doors, manifest spawns, transition clearance, and a traversable route from each inspection spawn to its exits.

## Map Alignment authoring baseline

The ten accepted global nodes now have compact `.rrmap` sources under
`content/maps`, with working bounds of 46-54 by 28-30 cells. Each source includes
terrain regions, at least three named landmarks, a traversable inspection route,
and the accepted road/ferry exits. These are planning greyboxes, not final mission
layouts, and all remain `scope=prototype`, `active=false`, and `release=false`.

St. Olaf's Guild Hall is also represented as a 32 x 20 interior source because it
is an accepted Act 1 developer destination. Archive-only Haapsalu, Viljandi,
Paldiski, Karja, Maasilinna, Swedish/Pskov shells, and other legacy concepts remain
outside the editor portfolio until a later accepted scope decision promotes them.
