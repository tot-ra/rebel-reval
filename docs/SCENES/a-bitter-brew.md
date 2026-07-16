# Scene Outline: A Bitter Brew

## Context
**Type:** Cycle 1 Quest / Vertical Slice Component  
**Timeline:** Pre-April 23, 1343  
**Canon status:** active outline, reconciled with README Campaign outline

## Investigation Evidence
During the day phase, Kalev gathers the following evidence to understand the sickness in the lower town:
- **Afflicted Townspeople:** Symptoms align with tainted water (fever, stomach cramps), not magical curses or supernatural blight.
- **Aita's Vats:** The ale itself is fine, but the water drawn from the municipal supply is tainted. Aita is being used as a scapegoat.
- **Henning's Cistern (Checkpoint):** The primary municipal water source is neglected, cracked, and contaminated by runoff.
- **Rebel Traces:** Marks near the cistern suggest it may have been intentionally sabotaged by Kaja's faction to sow unrest (or simply exacerbated by sheer negligence).
- **Jürgen's Offer:** Documents showing Jürgen is ready to step in with an exclusive, expensive clean-water contract, giving him an economic motive to let the crisis happen.

## Forging Options (The Choice)
Kalev must commit to one smithing action before the night phase, determining his approach to the crisis:
1. **Brewery Bands (Secure the Truth):** Forge heavy reinforced bands for Aita's vats, physically preventing the watch or Jürgen from confiscating or destroying her uncontaminated supply.
2. **Tampered Inspection Seal (Redirect Authority):** Forge a replica of Henning's inspection seal to falsely certify Aita's brewery as clean, or condemn Jürgen's imported barrels, manipulating the watch's bureaucracy.
3. **Detention-Cart Lock (Sabotage Authority):** Accept the commission to build the lock for Aita's detention cart, but build in a hidden mechanical flaw that allows her to break out during transport.

## Resolution Paths (Night Phase)
The night encounter at the watch checkpoint or brewery depends on the daytime forging choice:
* **Non-combat resolution:** If Kalev tampered with the inspection seal, he can present it (or plant it) to bypass the checkpoint guards without drawing a weapon. If he built the faulty lock, Aita frees herself quietly while Kalev provides a stealthy distraction.
* **Combat resolution:** If Kalev tries to secure the brewery bands while watchmen are actively seizing the property, or if he is caught planting evidence or aiding the escape, he must fight (or evade) the watchmen archetypes.

## Aftermath States
The resolution leads to one of three distinct world states for Cycle 2:

### State 1: Aita Exonerated (Truth & Independence)
* **Brewery State:** Open, operating independently, serving as a safe haven.
* **Aita State:** Free, continuing her work, provides healing items.
* **Mart Reaction:** Respects Kalev for defending the innocent against authority.
* **Patrol Barks:** Watchmen grumble about cistern duty, cleaning runoff, and Henning's administrative embarrassment.

### State 2: Authority Sabotaged (Rebel Escape)
* **Brewery State:** Confiscated, boarded up, or burned by the watch.
* **Aita State:** Fugitive, joins Kaja's rebel network in the shadows.
* **Mart Reaction:** Emboldened by the direct defiance of the watch; pushes further toward violent rebellion.
* **Patrol Barks:** Watchmen are on high alert, complaining about witches, fugitives, and rebel sympathizers in the shadows.

### State 3: Economic Surrender (Jürgen's Monopoly)
* **Brewery State:** Operating under Jürgen's banners, producing generic, expensive ale.
* **Aita State:** Arrested or forced into indentured servitude under Jürgen's contract.
* **Mart Reaction:** Disgusted by Kalev's complicity and the city's corruption; loses faith in Kalev's moral compass.
* **Patrol Barks:** Watchmen praise the new clean water but complain about Jürgen's prices and the merchants' growing influence.

## State Table

| Variable | State 1 (Exonerated) | State 2 (Sabotaged) | State 3 (Monopoly) |
| :--- | :--- | :--- | :--- |
| `bitter_brew_outcome` | `exonerated` | `escaped` | `monopolized` |
| `aita_status` | `free` | `fugitive` | `indentured` |
| `brewery_status` | `independent` | `confiscated` | `corporatized` |
| `jurgen_contract` | `rejected` | `rejected` | `active` |
| `night_resolution` | `non-combat/combat` | `stealth/escape` | `bribe/bureaucracy` |
| `evidence_surviving` | `cistern_flaw` | `none` | `inspection_seal` |