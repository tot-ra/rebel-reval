# Animal models and source manifest

Runtime birds and mammals live here in species-specific folders with their models, textures, and Godot `.import` sidecars. Existing animal sources (including fish and authored livestock) share the same library. The animation adapter and shared bird-plumage shader are animal-specific assets; fitted weapons and armor remain in [`../storybook/`](../storybook/README.md).

Animal model provenance and source URLs are recorded in [`../SOURCES.csv`](../SOURCES.csv). The mammal source manifest is `mammal_sources.json`. Rebuilds that publish runtime models write under `assets/animals/`.
