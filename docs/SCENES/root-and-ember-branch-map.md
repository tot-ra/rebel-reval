# Branch Map: Root and Ember

**Quest:** `quest.root_and_ember`  
**Package:** `package.root_and_ember`  
**Owner:** P4-007

## Required systems (no new major framework)

* Ellen Luik character introduction via authored dialogue
* Forge **Ember** and **Root** technique equipment paths
* Hingepuu reflection marks via mechanism install
* Journal facts and investigation interactables on Lower Town slice
* Materialist `iron_bracket` branch without literal magic vocabulary

## Branch families

| Branch id | Transitions | Ellen / household flags | Reflection |
| :--- | :--- | :--- | :--- |
| `ember_song_peace` | `complete_investigation`, `commit_ember_forge` | `flag.ellen.belief_honored`, `flag.household.hearth_peace` | Mercy |
| `root_ward_peace` | `complete_investigation`, `commit_root_forge` | `flag.ellen.remedy_trusted`, `flag.household.hearth_peace` | Mercy |
| `iron_bracket_practical` | `complete_investigation`, `commit_iron_forge` | `flag.ellen.skepticism_respected`, `flag.household.hearth_practical` | Duty |

## Unlock chain

* Unlocks when `quest.price_of_a_name` reaches a terminal aftermath state (`flag.act1_root_and_ember_unlocked` set on Price of a Name mechanism commit).
* Does not block P4-008 St. George's Night climax.

## Verification

* `python3 -m unittest tests.python.test_root_and_ember_branch_map -v`
* `python3 tools/verify_quest_packages.py content/packages/root_and_ember`
* `--filter=test_quest_package_root_and_ember`
* `--filter=test_root_and_ember_cycle`
