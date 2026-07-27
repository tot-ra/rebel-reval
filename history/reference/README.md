# Reference plates

Visual evidence for the research dossiers: garment cuts, floor plans, facades, doors and ironwork,
interiors, tools, ships, seals. Owned by the
[researcher work loop](../../agents/rebel-researcher/skills/work-loop/SKILL.md); the plate rules
live in the [dossier standard](../../agents/rebel-researcher/skills/dossier-standard/SKILL.md).

- `plates.csv` is the manifest - one row per plate, whether or not a copy is stored.
- `<domain>/<slug>/` holds the fetched files, named by `plate_id`.

These are **evidence, not assets**. `history/.gdignore` keeps them out of Godot import and export,
`.gitattributes` puts `history/**/*.jpg|png` in Git LFS, and no plate belongs in
`assets/SOURCES.csv`. When art derives a shipped asset from a plate, that role records its own
provenance row.

Only `public domain`, `CC0`, `CC BY`, and `CC BY-SA` plates are downloaded. Anything else stays a
link-only row (`status: linked`) that still records where the evidence is and what it shows.

```bash
python3 tools/research/fetch_reference_plates.py --slug burgher-house-plan   # fetch one dossier
python3 tools/research/fetch_reference_plates.py --dry-run                   # report only
python3 tools/research/fetch_reference_plates.py --verify                    # QA: files + checksums
```

| Column | Meaning |
|--------|---------|
| `plate_id` | `<domain>.<slug>.<nn>`, never reused |
| `shows` | what a producing role can read off the image |
| `source` | holding institution, publication, or `history/<file>.pdf` |
| `dated`, `origin` | date and place of the depicted object; later or non-Baltic material is a comparandum and is labelled as such in the dossier |
| `page_url` | citable landing page, required for every row |
| `image_url` | direct file URL, needed only for downloadable licences |
| `license`, `license_url` | rights as stated by the holder |
| `status` | `pending`, `fetched`, `linked`, `failed` |
| `local_path`, `sha256` | written by the fetch script |
