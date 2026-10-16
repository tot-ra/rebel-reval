# ADR 0058: The Apprentice is 18

- **Status:** Accepted (maintainer-directed, 2026-10-16). Implementation and presentation updates remain gated by the named task and the asset freeze.
- **Amends:** [ADR 0033](0033-teen-protagonist-and-spirit-dialogue-combat.md), decision 1, only as to the protagonist's exact age and minor status; [ADR 0052](0052-healer-apprentice-and-family-cure-loop.md) only where it describes the protagonist as a teen.
- **Task:** **R-2158** updates the active canon and age-related descriptions.
- **Does not change:** The protagonist's orphan background, clairvoyance, healer's apprenticeship, stable character ID, campaign dates, or any other decision in ADR 0033 or ADR 0052. Other characters' ages are unchanged.

## Context

The maintainer wants the protagonist to be an adult so mature themes can be considered for the story. The prior age of 15 made him a minor. The setting and story already place him in adult work as an apprentice healer; a young adult can preserve that role and the existing narrative while making his age unambiguous.

## Decision

1. The Apprentice is **18 years old at the start of the story in 1342** and remains 18 during the 1343 events. No birthday or age progression is implied.
2. He remains the orphaned, clairvoyant healer's apprentice introduced by ADR 0033 and developed by ADR 0052. All of ADR 0033 remains in force except for its age/minor-status statement.
3. This age decision makes the protagonist an adult character; it does **not** set the game's content rating or approve any particular sexual, nude, or violent scene. Those require a separate content-maturity decision. No minor may be sexualized or placed in a sexual or nude context.
4. Existing prototype protections remain unchanged. In particular, the player character stays excluded from the test-only undress interaction until a separately approved content and interaction task changes that scope. Adult age alone must not silently enable new behavior.
5. Existing combat/build tuning remains as-is. The apprentice's lighter, less practiced movement/combat preset describes his physique and training, not minority status.
6. Existing generated character art and meshes were authored under the 15-year-old specification. The source age may be updated, but generated assets are not replaced under this ADR because of the asset freeze. Their visual age must be audited and any replacement must be authorized as a separate asset task with exact files and provenance entries.

## Alternatives considered

- **Set the age to 16.** Rejected: the protagonist would still be a minor, so this would not achieve the maintainer's stated adult-character goal.
- **Change the protagonist's role or rewrite ADR 0033.** Rejected: changing age alone preserves the accepted story frame and stable character identity.

## Consequences

- Active canon, scope summaries, character briefs, and age-related source metadata now say 18; ADR 0033 remains an accurate historical record of the decision it originally captured.
- The adult-character/content policy and the visual audit of the existing model/portraits remain separate follow-up work.
- No new sexual content, nudity, animation, or runtime behavior is introduced by this ADR.
