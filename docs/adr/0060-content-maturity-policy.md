# ADR 0060: Content maturity policy: rating target, violence, adult sexuality and nudity, sexual violence, evidence

- **Status:** Proposed (2026-10-17). Needs maintainer approval (**R-2181**). Until it is accepted, no task may author, stage, generate or enable sexual content, nudity beyond what already ships, sexual violence, or graphic violence; existing content and runtime protections stay exactly as they are.
- **Follows:** [ADR 0058](0058-protagonist-age-18.md) decision 3: the protagonist being 18 is an *age* decision, not a *content* decision. This ADR is the separate content decision it names.
- **Fills:** ADR 0059 *Staged scenes in the live world* §4 (Proposed, being drafted in parallel; link it here once its file lands): ADR 0059 gives the grammar for violent and intimate beats; this ADR says what may be shown and how explicitly.
- **Applies to:** every authored medium: staged scenes (ADR 0059), memory / vision cutscenes ([ADR 0034](0034-cutscene-mode-and-cinematic-prologue.md)), dialogue and spirit duels, quest text, barks, item and codex text, character art and portraits, generated stills and video prompts, audio, and systemic behaviour (citizen brawls, spirit sight, the undress test).
- **Does not change:** [ADR 0003](0003-authored-offline-dialogue-and-prohibit-runtime-llm.md) (all content authored offline, no runtime generation), the asset freeze (P0-040), [ADR 0041](0041-spirit-sight-auras-and-soul-lights.md) and R-1870 (adult citizens nude in spirit sight, minors never), the test-only undress interaction and its scope ([`UNDRESS_INTERACTION.md`](../SYSTEMS/UNDRESS_INTERACTION.md)), ADR 0058 decision 4 (the player stays excluded from the undress test), or any stable ID.

## Context

The maintainer wants story scenes that play like film (ADR 0059), with everyday danger, casual violence and adult sexuality, grounded in 1343 Reval: a town under Lübeck law, the Order's and the bishop's courts, bathhouses, beer-shops, the night watch, and the St George's Night uprising of 1343 whose chronicles report killings of whole households.

ADR 0058 made the protagonist an adult so these themes can be *considered*. It explicitly refused to set a rating or approve any scene. Today the project has:

- no stated rating target;
- one hard content rule, held in code and two feature pages: minors are never shown nude (`SpiritUndress.is_protected` refuses `child`, `apprentice`, `boy`, `girl` bodies and the player rig; child bodies have no `layers/nude.glb` twin and `build_human.py --nude-only` exits for them);
- non-sexual adult nudity already shipping in spirit sight, and a test-only undress gesture on adult citizens with no reaction, consent model or save;
- systemic violence already shipping (citizen brawls, weapons, bandits, an injury and pain model) with no written limit on how it is shown;
- canon confidence labels (`attested`, `plausible`, `folklore`, `invented`) and the period rule for later evidence, but no rule that a mature beat must carry them.

Without a policy, each scene author would decide these limits alone, and "historical realism" could be used to justify anything.

## Decision

### 1. Rating target

1. The game is authored for an **adult rating: PEGI 18 / USK 18 / ESRB Mature 17+**, the band of The Witcher 3 and Kingdom Come: Deliverance II. It is **not** authored for ESRB Adults Only or an equivalent "explicit sexual content" band. The rating boards decide the final rating; this is the authoring ceiling, and content that would push the game past it is out of scope.
2. The game shows a content notice before New Game: violence, blood, adult sexuality and nudity, historical brutality, references to sexual violence.

### 2. Absolute exclusions (no option, no exception, no "realism" override)

1. **No minor may be sexualized or placed in a sexual or nude context.** This covers depiction, implication, dialogue, camera framing, clothing framing, innuendo, romance options, jokes, item text and generation prompts. A minor is any character whose canonical age is under 18, and any character whose age is not stated in canon. Eligibility is by stated age **and** visual read: a character who is 18 or older in canon but reads younger in their model, portrait or voice is treated as a minor until an asset audit clears them (ADR 0058 decision 6 already requires that audit for the protagonist's existing art). When in doubt, exclude.
2. **The protagonist is 18** (ADR 0058) and is eligible only under the rules for adults below; his eligibility does not extend to anyone he meets. His existing model and portraits were authored to the 15-year-old specification, so under §2.1 he is not eligible for any intimate or nude beat until the ADR 0058 visual-age audit clears or replaces that art. Historical marriage or betrothal ages of the period do **not** make a minor eligible.
3. **No sexual content** involving animals, the dead, spirits or creatures in human form whose apparent age is under 18, the unconscious, the intoxicated to incapacity, or anyone whose consent the scene does not establish.
4. **No sexual content involving real, named historical persons** of 1343 (attested individuals in [`CANON.md`](../CANON.md)). Invented characters only.
5. **No sexual violence on screen or in play** (see §5).
6. **Children are never harmed by the player** and never shown suffering graphic violence. Harm to children that the sources attest (the uprising) may exist only as off-screen fact or non-graphic aftermath (§4.4).

### 3. Violence and gore

Violence is part of the period's everyday life and is shown as **consequential, not spectacular**.

**Allowed:**

- Brawls, beatings, knife and weapon fights, ambushes, the watch subduing someone, a husband or master striking a dependant as visible world texture, hunting and slaughter as work.
- Blood on wounds, weapons and clothing; visible wounds from the injury model; pain reactions; death on screen.
- Judicial violence of the period, each form only where §6 evidence places it in Reval or comparable Lübeck-law towns of the 1340s (candidates: pillory, flogging, branding, hanging, beheading, a gallows outside the walls), shown at the distance a witness would stand.
- Aftermath of massacre and war (bodies, burned farmsteads) with restraint in framing.

**Limits:**

- No close-up lingering on dismemberment, evisceration or mutilation; a cut or reaction shot carries the moment. Severed parts appear only where the injury model or an attested execution needs them, never as a reward or trophy.
- No torture as gameplay or minigame. Interrogation under torture, only if §6 evidence shows it for the court and decade concerned (its use in fourteenth-century Lübeck-law towns is not assumed here), may be referenced or shown as a non-interactive scene ending before the act, or by its aftermath.
- No reward for cruelty for its own sake: the soul-light and sin systems ([ADR 0055](0055-soul-attachments-and-sin-inclinations.md)), guilt and reputation register violence as a cost. Choosing violence is allowed; the game never frames it as funny or free.
- Animal cruelty for spectacle is excluded; period work (slaughter, hunting, culling) is allowed and not dwelt on.
- Every violent beat in a staged scene uses the existing injury / pain / guilt state, not bespoke gore assets.
- A **blood and gore option** (on / reduced) may lower presentation; it never removes story beats.

### 4. Adult sexuality and nudity

1. **Participants:** only adults eligible under §2, in canon and in visual read.
2. **Consent is explicit state.** A sexual or intimate beat requires a deterministic consent flag set by authored choices on both sides, never inferred, never purchasable by a "romance meter" alone. Coercion, threat, payment under duress or abuse of power (master and servant, lord and serf, priest and penitent) is not consent; such situations fall under §5. Paid sex with an adult (attested bathhouse and prostitution trades) is allowed only as consenting adult content and may carry social and soul-light cost.
3. **Non-sexual adult nudity is allowed** where the period or an existing system puts it: the Saturday bath and sauna, washing, sickbed and healing work (the hero is a healer), the dead being washed, punishment that the sources show stripping for (§6), spirit sight (R-1870). It is framed matter-of-factly, not lingered on.
4. **Sexual nudity is partial and non-explicit:** bare backs, buttocks and breasts may be seen; genitals are not shown in a sexual beat, close-up or framed for attention. No depiction of intercourse or sex acts beyond the fade-to-black limit (§4.6).
5. **No sex as a reward loop:** no collectible partners, no sex unlocked by gifts or points, no sex minigame, no interactive camera control during an intimate beat.
6. **Fade-to-black limit.** A sexual beat may show, in order and no further: attraction and talk, a kiss, an embrace, undressing to the nudity of §4.4, the couple lying down together. The camera then cuts away (fade, cut to an object or the room, or to a later time). Audio ends at the cut; no explicit sexual sound. The scene may resume on aftermath: the couple lying covered, dressing, talking. Same-sex and opposite-sex adult relationships follow the same limit.
7. **Undress interaction and spirit sight are not sexual systems.** This ADR does not widen them. Any change to who can be undressed, any NPC reaction, or any sexual use of either requires its own task under this policy, and changes to the protections in §8 require their own ADR.

### 5. Sexual violence

1. **Never shown, never playable.** No scene depicts the act of rape or sexual assault, including in part, in silhouette, by sound, or in a memory / vision sequence. The player character can never commit it, attempt it, or choose it in any dialogue option.
2. **Never titillating:** no nudity, no sexual framing and no lingering in any beat that refers to sexual violence.
3. **May exist only as narrative fact,** where the story needs it and it is grounded (§6): referenced in dialogue, testimony, a court case, rumour or chronicle; or shown through non-sexual aftermath (a victim's grief, an accusation, a feud). An NPC threat of sexual violence, if used at all, ends before any contact and is not sexualized.
4. **Survivors keep agency:** a survivor is a character with choices and a voice, not a motive object for the protagonist. A quest may never rescue-reward the hero with the survivor's affection.
5. Every beat that touches sexual violence needs its own task tagged `#needs-approval`, named by the maintainer, and a second review against this section before done.

### 6. Historical-realism evidence

"Historical realism" is a reason to include something only when it is evidenced; it is never a reason to go past §§2-5.

1. **Every mature beat** (violence of §3 beyond a brawl, any nudity, any sexual beat, any reference to sexual violence) carries a canon confidence label from [`CANON.md`](../CANON.md): `attested`, `plausible`, `folklore` or `invented`.
2. `attested` and `plausible` claims cite a source in the task or the scene record's notes: a primary source (Lübeck law as used in Reval, Reval council and court records, Hermann von Wartberge's *Chronicon Livoniae* for 1343, church statutes) or a scholarly secondary source with page. Research dossiers go through the researcher role and its existing source-summary approval.
3. The **period rule** applies: evidence dated after 1343 shows a practice existed *later*; it supports `plausible` only with an argument for continuity, and anything first attested later is excluded.
4. **Invented content is labelled `invented`** and is never presented in game, codex or marketing as historical fact. The uprising's atrocities on both sides are `attested` in outline; specific victims, scenes and acts are `invented` unless sourced.
5. No modern stereotype, slur-as-flavour or "dark ages" cliché is passed off as period fact; the canon keeper may reject a beat whose only grounding is genre convention.

### 7. Process gate for content tasks

1. No content task under this policy is created or claimed until this ADR is **Accepted**.
2. After acceptance, each mature beat is its own task that names: the beat and its scene / dialogue ID, the participants and their canonical ages, the §3/§4/§5 rules it uses, its evidence (§6), and the files it may touch. Tasks with sexual content, nudity outside existing systems, or any reference to sexual violence carry `#needs-approval` and wait for the maintainer.
3. Review: a second agent or human checks every such task against this ADR before done, and the canon keeper checks §6.

### 8. Runtime protections stay as they are

This ADR loosens no protection. In particular:

- `SpiritUndress.is_protected` (`scripts/combat/spirit_undress.gd`) and its name refusals, the missing `layers/nude.glb` twins for child bodies, the `build_human.py --nude-only` refusal for child bodies, and the player-rig exclusion in spirit sight and `ClothingStrip` stay unchanged.
- Changing any of them needs its own ADR, and may only add protection for minors, never remove it.
- Once content work starts, the intended direction is *more* enforcement in data: a content descriptor on scene and dialogue records and a validator that rejects intimate or nude beats whose cast includes a minor or an unaged character (see Consequences).

## Alternatives considered

- **Teen rating (PEGI 16 / ESRB T), no sexuality.** Safer and simpler, but does not meet the maintainer's request for adult themes grounded in the period; kept as the fallback if this ADR is rejected.
- **Adults Only, explicit sex.** Rejected: outside the comparable games the maintainer cites, closes most storefronts, and adds explicit content the story does not need.
- **No written policy, judge case by case.** Rejected: AI agents author most content, and an unwritten line drifts with each author.
- **Content toggles instead of limits.** Rejected as the main mechanism: options can lower presentation (§3, open question 3) but never raise content past the ceiling; the absolute exclusions are not options.
- **Allow depicted sexual violence "because the sources attest it".** Rejected: the sources attest it as fact; showing it adds nothing the reference and aftermath cannot carry, and it is the beat most likely to be exploitative.

## Consequences

- When accepted, follow-up tasks (none created before acceptance):
  - a content descriptor (`violence`, `nudity`, `sexual`, `sexual_violence_reference`, evidence label) on `scene` and `dialogue` records, with a validator that rejects intimate or nude beats whose cast includes a character under 18 or without a canonical age;
  - a canonical age field audit for every named character in `docs/CHARACTERS/` (unaged characters are excluded until aged);
  - the visual-age audit of existing hero and named-character art that ADR 0058 decision 6 already requires;
  - a content notice at New Game and an options entry for blood / gore (and nudity, if open question 3 says so);
  - a content-review checklist in the QA and canon-keeper role playbooks.
- ADR 0059 §4 then points here instead of to "the content-maturity ADR (separate task)".
- Nothing ships, renders or changes at runtime because of this ADR.

## Open questions for the maintainer

1. Confirm the rating ceiling: PEGI 18 / ESRB M (proposed), or a lower or higher band.
2. May the protagonist have intimate scenes at all, or only other adult characters (on screen or by reference)?
3. Options: a blood / gore toggle only (proposed), or also a nudity toggle that keeps underlayers on?
4. Is on-screen judicial execution (hanging, beheading) acceptable at witness distance, or only its aftermath?
5. May references to sexual violence appear in Act 1, or only in the uprising acts where the sources put large-scale violence?
6. Same-sex adult relationships: allowed under the same rules (proposed)? The period's church and town law condemned them; the proposal is to show that as social risk and consequence for the characters, never as the game endorsing persecution.
