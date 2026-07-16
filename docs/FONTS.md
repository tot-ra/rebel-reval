# Font and diacritic decision

**Reference:** TODO P0-014  
**Status:** Accepted  
**Date:** 2026-07-16

## Decision

Reval Rebel uses **Noto Sans Regular** as the baseline UI and dialogue font for the current Godot project. The font is stored at:

- `assets/fonts/NotoSans-Regular.ttf`
- `assets/fonts/NotoSans-OFL-1.1.txt`

Noto Sans is selected because it covers the Latin and Latin Extended characters needed by active canon names, Estonian text, Low German names, and short Latin church or legal phrases while remaining neutral enough for prototype UI. Later art direction may add a more historical display face, but it must keep Noto Sans or an equivalent high-coverage font as fallback for body text and accessibility settings.

## Required character coverage

The baseline font must render the following without missing glyph boxes:

- Estonian vowels and uppercase forms: `õ ä ö ü Õ Ä Ö Ü`
- Canon place and event names: `Jüriöö`, `Sõjamäe`, `Ülemiste`, `Harjumaa`, `Kanavere`, `Reval`
- Slice character names: `Kalev`, `Mart`, `Aita`, `Kaja`, `Henning`, `Jürgen Witte`
- Low German and wider Baltic name support candidates: `ß`, `ł Ł`, `þ Þ`, `ð Ð`, `č Č`, `š Š`, `ž Ž`, `ů Ů`
- Wider Latin fallback sanity set for names and loanwords: `á é í ó ú Á É Í Ó Ú`, `ñ Ñ`, `ø Ø`, `æ Æ`, `œ Œ`
- Latin text samples and macrons for church or chronicle text: `Domine miserere nobis`, `Anno Domini MCCCXLIII`, `Pax vobiscum`, `ā ē ī ō ū ȳ Ā Ē Ī Ō Ū Ȳ`

The Godot render artifact for this coverage is `scenes/tests/font_glyph_render_test.tscn`.

## Source and license

- Font: Noto Sans Regular
- Upstream repository: <https://github.com/notofonts/noto-fonts>
- Source file: `hinted/ttf/NotoSans/NotoSans-Regular.ttf`
- Pinned upstream revision: `8f9bf04503f257b1f19bb472e9b8a06cae1caa60`
- Bundled font SHA-256: `9cb49a54e520423033f9727be2e53e4805a60656deb09c219740d8e5f3e033ac`
- Godot import sidecar: `assets/fonts/NotoSans-Regular.ttf.import`
- License: SIL Open Font License 1.1, copied in `assets/fonts/NotoSans-OFL-1.1.txt`
- Commercial use: permitted by SIL OFL 1.1, including bundling and embedding with the game, as long as the font is not sold by itself and derivative font naming follows OFL rules.

`assets/SOURCES.csv` includes a row for `assets/fonts/NotoSans-Regular.ttf` with this source URL, pinned revision, license, and approval status.

## Implementation guidance

- Use `assets/fonts/NotoSans-Regular.ttf` for UI, dialogue, subtitles, menus, and validation scenes that contain player-facing text.
- Do not rely on Godot's default font for approved text content, because default fallback can vary by platform and may hide missing glyph regressions.
- Keep names exactly as canon records them in `docs/CANON.md`, including diacritics such as `Jürgen`, `Jüriöö`, `Sõjamäe`, and `Ülemiste`.
- If a future display font is added, verify it against the same character set and keep Noto Sans as fallback for accessibility and any unsupported glyphs.
- Fonts are not part of the P0-040 visual art freeze's blocked isometric, pixel-frame, or superseded HUD classes, but they still follow `docs/ASSET_STORAGE_POLICY.md`: font files under 10 MB may be stored in standard Git and must retain license/provenance documentation.

## Verification performed

Verification used Godot 4.4 stable to load and instantiate `scenes/tests/font_glyph_render_test.tscn`. A temporary script resolved `assets/fonts/NotoSans-Regular.ttf` from the scene and confirmed that the font reports every required character listed above via `Font.has_char()`. A separate local TTF `cmap` coverage check also confirmed the same character coverage.
