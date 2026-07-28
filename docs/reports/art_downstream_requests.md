# Art downstream requests

Needs discovered by the Art loop that belong to another role: runtime wiring for a delivered mesh,
missing historical evidence for a period-visible asset, a map that must place a new prop, a character
brief that must exist before a body can be built.

The Producer reads this file on its reconcile tick
([producer work loop](../../agents/rebel-producer/skills/work-loop/SKILL.md)) and turns open entries
into task rows. The Art loop never authors rows for another role
([art work loop](../../agents/rebel-art/skills/work-loop/SKILL.md)); it records the need here.

Close an entry by setting its status to `rowed: <ID>` once the Producer has created the row, or
`dropped: <reason>` when it is superseded. Keep resolved entries for one milestone, then prune.

| Raised | For role | Need | Source asset or audit | Status |
|--------|----------|------|-----------------------|--------|
| - | - | - | - | - |
