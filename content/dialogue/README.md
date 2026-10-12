# City conversations (R-1887, R-1889, ADR 0047)

Generic dialogue records spoken by any census resident or named NPC in the seamless city ([`DIALOGUE.md`](../../docs/SYSTEMS/DIALOGUE.md#talk-to-anyone-r-1887)). The speaker is the placeholder `char.interlocutor`; `CharacterConversation` shows the real person's name and portrait and fills the `{interlocutor_*}` tokens.

| ID | File | Role |
|---|---|---|
| `dialogue.city.small_talk` | `dialogue.city.small_talk.json` | Peaceful click or interact on a person: who are you, news, the inner eye (choice `inner_eye` turns the talk into a spirit duel), farewell |
| `dialogue.city.spirit_duel` | `dialogue.city.spirit_duel.json` | Spirit duel on anyone (from spirit sight or the inner-eye reply); topic `daily_burden`; resolutions `resolved_eased`, `resolved_broken`, `resolved_left`; sets no flags |
| `char.interlocutor` | `character.interlocutor.json` | The placeholder speaker record |

Tokens: `{interlocutor_name}`, `{interlocutor_title}` (trade or registry title), `{interlocutor_side}` (a spoken line naming the person's faction).

```bash
python3 tools/validate_content.py content/dialogue content/prologue content/examples/support content/examples/valid
```
