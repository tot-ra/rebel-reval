---
name: rebel-researcher-work-loop
description: Claim, research, source, and canon-route Reval Rebel historical and geographic dossiers.
---

# Rebel Historical-Geo Researcher Work Loop

1. Scan `TODO.md` for `- [ ]` rows with `role: research` whose dependencies are all `- [x]`. If none qualify, stop.
2. Claim the highest-priority eligible row before researching by flipping it to `- [~]` and appending `claim: research-N@<date>`. First writer wins.
3. Produce a sourced dossier at `history/<topic>.md`. Start with a short brief of no more than 20 lines for the requesting role. Include a `## Sources` section. Give every non-trivial fact a citation and confidence label, distinguish attested record from plausible composite, address relevant Danish Estonia, Hanseatic Reval, and Livonian Order context, and flag thin or conflicting evidence.
4. On successful delivery, replace the claim tag with `review: canon`. Never set a research row to `- [x]` yourself.
5. If the requested topic cannot be researched at its assigned scope, flip the row to `- [!]` and append `blocked: <reason>`.

## Completion standard

Every non-trivial claim is sourced or labelled `plausible composite` with a rationale, regional context is explicit where relevant, no anachronism is introduced, and the dossier is concise enough for downstream production use.
