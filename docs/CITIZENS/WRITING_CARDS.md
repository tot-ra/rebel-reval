# Writing citizen cards

Status: normative for every file under `docs/CITIZENS/people/`. Method and numbers: [`CENSUS.md`](./CENSUS.md). Structure to copy: [`TEMPLATE.md`](./TEMPLATE.md). Validator: `python3 tools/validate_citizen_cards.py`.

A card turns one **census seed** (age, sex, ethnicity, trade, household, faction, appearance numbers) into a person. The seed is law; the person is yours. A reader should be able to pick any card and know exactly who they would meet in Reval on a April morning in 1343, and no other card should read like it.

## What a writer receives

Per card: the census record, the appearance seed, the household (every member, carded or not, with relative links), nearby households, and every planned social edge with an **agreed fact** (one sentence both sides must honour). Output goes to the `write_to` path of the batch.

## Seed rules (do not break)

1. **Keep:** name, age, sex, ethnicity, trade, household role, household members, faction and role, languages, literacy, height, build, hair colour and greying, eye colour, complexion, every mark, facial hair, handedness, voice. You may add detail and explain them; never contradict or drop one. If the name carries an epithet (`the Lame`, `Nine-fingers`, `Crow`), earn it in the biography and make the appearance agree.
2. **May change:** nothing in the seed. If a seed combination looks odd (a lame porter, a sober innkeeper), that is a feature: explain it.
3. **Edges:** every planned edge appears in `Relationships > Network` with a link to the other card and the agreed fact reproduced in substance. The other writer is doing the same from the other side. Do not add contradictory facts. You may add colour that does not clash.
4. **Household:** link every member who has a card. Link members without a card to the ledger anchor. Mention infants and children by name. Do not kill, marry off, or invent household members; you may name a dead spouse, parent, or child who is not in the census (they are the past, not residents).
5. **Other people:** you may name further townsfolk only through `nearby_households` (link their ledger or card). Do not invent new named residents of the plot or street.
6. **No new factions or offices.** Use the faction in the seed. `none` means they stay out of politics by choice or necessity; give the reason.

## Canon quick sheet (spring 1343)

- **Date:** the card describes the person in the **week before 23 April 1343 (St George's Night)**. Easter was 13 April. The rising and siege (late April-May) are the horizon; the card says what they would do, not what already happened. The Livonian Order enters the story after the rising; only a few agents or merchants are in Reval before. The Danish crown holds Toompea (viceroy Konrad Preen). The city council (Rat) governs Lower Town under Lübeck law; two burgomasters, about 20 councillors, German burghers only.
- **Law and class:** only adult German burghers sit on the council and serve in the militia watch roll (with their household masters and journeymen standing in). Estonians in town are legally free but socially below; they are porters, masons, carters, fishers, servants, small craftspeople and an Estonian night-watch squad. Swedes and Finns work shoes, ships, haulage, fish. Russians are guests under Hanseatic practice. Peasants on Harju manors are being bound; escaped serfs hide in the lanes.
- **Languages:** Middle Low German is the town's tongue; Latin is for clergy and charters; Estonian is the street and labour tongue. Estonians have a forename, sometimes a patronymic (`poeg`/`tütar`), never a family name. German burghers carry hereditary or occupational bynames. Never use High German, modern Estonian slang, Early Modern English, or post-Reformation oaths.
- **Money:** no local coin since 1332. Silver by weight; accounts in marks, öre and örtug (8 öre = 24 örtug = 1 mark); Lübeck schillings and pfennigs for change; Hanseatic imports. **No artig.** Bulk goods by pfund, lispfund, schiffspfund.
- **Craft:** guilds are St Canute (smiths, bakers, shoemakers) and St Olaf (butchers, carpenters, coopers) umbrellas, Ämter fraternities from about 1335, merchants in the Kindergilde. No Great Guild hall, no Blackheads house, no council craft ordinances before 1363. Master / journeyman / apprentice is a household relationship.
- **Dress:** shirt (Hemd), braies, hose tied to the belt, tunic (Rock/Kirtel); rank shows in hem length, fabric, dye, fur trim, shoes, belt. Women: long gown, linen coif or veil (married women covered), apron for work. Estonians: shorter, coarser homespun, wooden shoes, scarf or bare head. No trousers, doublets, buttons-down-the-front shirts, cotton, glass spectacles, or plate armour on burghers. Watch: padded jack, iron cap, spear or crossbow.
- **Food and body:** rye bread, barley porridge, peas, salted herring, small beer, malt; fresh meat limited and status-sensitive; spring scarcity and Lent just ended. Weekly bath for German households, basin wash for most others. No tobacco, potatoes, tea, coffee, sugar sweets for the poor.
- **Religion:** parish of St Olaf (harbour, Estonians, Scandinavians), St Nicholas (merchants), Holy Spirit (hospital and poor), Dominican friary of St Catherine, Cistercian nuns of St Michael, Danish cathedral St Mary on Toompea. Folk practice (hearth rites, grove offerings, herb charms) lives alongside Christianity; the Cult of Metsik is a faction, not a joke.
- **Place:** Lower Town (All-linn) under the hill; streets include Pikk, Lai, Vene, Viru, Müürivahe, Sauna, Harju; gates are Coastal, Sand, Viru (clay), Cattle (Karja), Smiths' (Harju), and the hill gates. Distances are short; everyone hears the same bells. Use only street and place names that exist in the ledger and the plan; do not invent plot numbers.
- **Factions:** `hanseatic` (guilds and council money), `danish_crown` (Toompea and its dependants), `livonian_order`, `black_cloaks` (urban rebels: smiths, artisans, underclass), `harju_kings` (rural rising and its town sympathisers), `cult_metsik` (old ways), `pskov_novgorod` (emissaries and merchants), `vitalienbruder` (harbour raiders, plunder), `blackheads` (unmarried merchants, candidate seat), `church`. Roles in the seed: `core`, `active`, `sympathiser`, `secret_sympathiser`, `secret_cell_member`, `courier`, `informer`, `dependent`, `coerced_or_dependent`.

## What makes a card good

1. **One specific thing per section that only this person has.** A named object (a cracked mazer, a borrowed iron comb), a habit (always walks the long way to avoid a debtor), a grudge with a date, a smell, a sound.
2. **Ordinary lives are the point.** Most residents are not rebels or spies. A baker whose worry is the price of rye is as important as a courier. Give each a mundane engine (pride, shame, appetite, duty, a child, a debt) before any politics.
3. **Faction members share a root and differ in the branch.** Two Black Cloaks should both have a reason to resent the same thing (a flogging, a levy, a closed gate) but different reasons to act: one from love, one from boredom, one from faith. Two Hanseatic merchants differ in what they would sacrifice. Never write a faction slogan as a motivation.
4. **The economy is visible.** Say where grain, iron, charcoal, ale, wool, fish, or labour comes from and goes; what a month's rent or a bad harvest does. Use marks/schillings/pfennig credibly.
5. **Age and sex matter.** Children have chores, games, fears, and a worldview (a 7-year-old's feud with a goose); old people have injuries, memories (the 1313-1325 wars, the founding of the Dominicans), and quiet authority. Widows run businesses. Teenage servants gossip.
6. **Appearance for generation:** concrete geometry (height, shoulder width, jaw, nose bridge, eye spacing, brow weight, ear size, hairline), asymmetries, wear, and **different silhouettes**. No "weathered face with kind eyes". Describe what a modeller or portrait generator can draw. Make neighbours look different from each other.
7. **Routine is a table people can follow:** times (church bells, curfew bell in the evening), places that exist, tasks with tools. Show the Sunday and the spring-1343 disruption (rising tension, grain levy talk, gate closings).
8. **Voice sounds like speech, not a description.** Three sample lines with a distinct rhythm and vocabulary; add a Low German or Estonian fragment where natural. Children speak differently from servants from councillors.
9. **Honest confidence.** Use `plausible composite` for everyone except where noted (`invented` if the card contains a sensational secret that is plainly the game's own). Attested names (Dietrich Zierenberg) keep `plausible composite` for the person-level detail.
10. **Do not**: write modern psychology jargon, anachronistic words (okay, stress, teenager), gratuitous misery, "tragic orphan" defaults, uniform "secret rebel" secrets, or sexual violence. Keep sensitive trades (the licensed bath-girl, the executioner) factual and humane.

## Length and format

- **Length:** adults 600-850 words of prose (the whole file, tables and prompt included, stays under 1,300); children 14 and under 300-450. Brevity with specifics beats coverage. Do not pad `At a glance` with restatements.
- **Network:** one bullet per planned edge: `[Name](link), their trade or role: the agreed fact in your own words, how it began, what this person feels about it and does about it.` Do not run edges together in one paragraph.
- **Household:** one bullet naming every household member (link or ledger link) and what each means to this person.

- Follow [`TEMPLATE.md`](./TEMPLATE.md) exactly: title, hook blockquote, field table, then the H2 sections in order. Use plain Markdown; no images, no HTML.
- The `ID` is `char.<slug>` where `<slug>` is the file name. `Census ID` is the batch `id`. `Household` links to the ledger anchor given in the batch.
- Links to other cards and ledger anchors: paste the relative links from the batch exactly (`../../people/<district>/<slug>.md`, `../../ledger/<district>/<street>.md#<anchor>`); they are already correct for a file inside `people/<district>/`.
- Do not edit any file other than your own cards.
