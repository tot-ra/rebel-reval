"""Landmarks for the north, south, and east quarters of medieval Tallinn."""

from __future__ import annotations

from .catalog_types import LandmarkCatalog

TALLINN_QUARTERS: LandmarkCatalog = {
    "North Quarter (Pikk and Merchant Street)": [
        (
            "St. Olaf's Church (Oleviste kirik)",
            "Famous spire once among the world's tallest; rebuilt after fires.",
            "Active 13th-century church; west tower and vaulting reflect 1330-era work without the later giant spire.",
            "Mart meets contacts in Oleviste courtyard to trade whispers on the rural rebellion.",
        ),
        (
            "Pikk Street (Pikk tänav)",
            "Long merchant street of guild houses and cafés.",
            "Main Hanseatic artery lined with workshops and stone merchant houses.",
            "Jürgen Witte's warehouses dominate the harbor end.",
        ),
        (
            "St. Olaf's guild workshops",
            "Craft shops in church shadow today.",
            "Metalworkers and ship chandlers under guild regulation.",
            "Kalev competes for city contracts against wealthier masters here.",
        ),
        (
            "Coastal Gate (Suur Rannavärav)",
            "Grand barbican and Fat Margaret not yet built.",
            "Primary sea gate with timber palisades and a simpler stone portal.",
            "Harbor tolls are collected here; rebel scouts note guard rotations.",
        ),
        (
            "Harbor crane site",
            "Reconstructed harbor crane.",
            "Wooden treadwheel crane unloading cogs and barges.",
            "Salt and tar from Novgorod pass through Kalev's forged hooks and chains.",
        ),
        (
            "Pikk Street salt warehouses",
            "Restored merchant storerooms.",
            "Long narrow warehouses for Hanseatic salt and herring.",
            "Kaja hides dispatches between salt barrels.",
        ),
        (
            "Ropewalk lane",
            "Harbor-side service alleys.",
            "Long ropewalk supplying ship rigging.",
            "Captain Henning requisitions rope for watch boats here.",
        ),
        (
            "Shipwright's yard",
            "Maritime museum fringe today.",
            "Boat repair slips for coastal traders.",
            "Forge nails and cleats are steady work for Kalev.",
        ),
        (
            "Novgorod merchant compound",
            "Historic trade ties marked by street names.",
            "Eastern traders maintain a fenced yard near the harbor.",
            "Language and custom friction with Hanseatic Germans.",
        ),
        (
            "Fish market landing",
            "Outdoor harbor market stalls.",
            "Morning herring and dried fish trade.",
            "Lower-town women barter news with fishermen from Viimsi.",
        ),
        (
            "Pikk Street chapel niche",
            "Small street shrine restored for tourists.",
            "Stone niche with votive candles for sailors.",
            "Sailors vow offerings if they survive spring storms.",
        ),
        (
            "Merchant counting house",
            "Banking museum sites nearby.",
            "Timber hall where factors settle letters of credit.",
            "Jürgen Witte ruins smaller rivals with delayed payments.",
        ),
        (
            "Harbor watch tower (early)",
            "Later towers rebuilt; harbor lookout remains.",
            "Low stone lookout over the roadstead.",
            "First sight of rebel campfires is reported from here.",
        ),
        (
            "Packhouse lane",
            "Service road behind Pikk frontages.",
            "Cart access for barrel and crate loading.",
            "Smuggled spearheads travel in 'empty' barrel returns.",
        ),
        (
            "Pikk Street well",
            "Covered well near guild houses.",
            "Fresh water for brewers and dyers.",
            "Aita draws water when her own well runs brackish.",
        ),
    ],
    "South Quarter (Knights and Karja Gate)": [
        (
            "Rataskaevu Street well",
            "Famous 'wishing well' on a picturesque street.",
            "Functioning public well with local superstitions.",
            "Ellen Luik hears old songs whispered here at dusk.",
        ),
        (
            "Karja Gate (Karja värav)",
            "Southern gate toward the mainland road.",
            "Active gate in the Margaret Wall controlling exodus to Harju villages.",
            "Rebel couriers test Henning's patrol gaps at Karja.",
        ),
        (
            "Knights' quarter lanes",
            "Quiet streets with craft shops today.",
            "Houses of lesser knights and armorer workshops.",
            "Order retainers demand rush repairs before the siege.",
        ),
        (
            "St. Michael's convent site",
            "Cistercian convent ruins in the south ward.",
            "Active convent precinct with church and cloister gardens.",
            "Aita trades ale for medicinal herbs from lay sisters.",
        ),
        (
            "South wall tower (early)",
            "Part of the preserved wall ring.",
            "Timber-roofed tower on the Margaret Wall.",
            "Archers rotate here when rural signal fires are reported.",
        ),
        (
            "Karja Street smithies",
            "Tourist craft quarter.",
            "Several competing smithies south of the market.",
            "Kalev undercuts rivals but refuses Order sword orders.",
        ),
        (
            "South quarter tannery row",
            "Boutiques in restored yards.",
            "Smelly but essential leather production downwind of residences.",
            "Mart hates delivering goods through the tannin stench.",
        ),
        (
            "Stable yards near Karja",
            "Hotels in converted barns.",
            "Horse hire for messengers riding to Paide and Harju.",
            "Kaja requisitions a nag for a midnight run to the rebel camp.",
        ),
        (
            "Lay brother dormitory lane",
            "Guesthouse street today.",
            "Lodging for traveling clerics and poor pilgrims.",
            "Rural priests bring word of oath gatherings in Harju.",
        ),
        (
            "South gate guardhouse",
            "Museum display of weapons.",
            "Barracks for the Karja watch shift.",
            "Henning inspects this post personally after St. George's Night.",
        ),
        (
            "Village road milestone",
            "Stone marker toward Ülemiste.",
            "Wooden post naming distances to Harju villages.",
            "Last point inside the wall where peasants may legally gather.",
        ),
        (
            "Knight's chapel (minor)",
            "Small house chapel restored.",
            "Private oratory for Order-affiliated households.",
            "Confession rumors leak to the lower town within a day.",
        ),
    ],
    "East Quarter (Lower Town East and Viru Gate)": [
        (
            "Viru Gate (Viru värav)",
            "Romantic twin towers from the 15th century.",
            "Functional gate in a shorter wall without elaborate foreworks.",
            "Captain Henning patrols this sector; Kaja smuggles messages past his watch.",
        ),
        (
            "Viru Street (Viru tänav)",
            "Shopping artery from gate to square.",
            "Busy retail lane with cloth and spice stalls.",
            "Ellen Luik buys linen here for birthing kits.",
        ),
        (
            "Eastern granary row",
            "Cafés in converted storehouses.",
            "Municipal grain stores against famine.",
            "Bread riots loom when granaries are rumored empty.",
        ),
        (
            "Viru barracks",
            "Historic guard building footprint.",
            "Barracks for the eastern watch company.",
            "Henning's sergeants drill recruits before the uprising.",
        ),
        (
            "Eastern market hall",
            "Weekend market space.",
            "Covered stalls for pottery and coarse cloth.",
            "Mart picks up gossip from upland peddlers.",
        ),
        (
            "Coopers' lane",
            "Craft shops near the gate.",
            "Barrel makers supplying brewers and shippers.",
            "Aita's brewery depends on coopers for export ale.",
        ),
        (
            "Weavers' collective yard",
            "Boutique textiles today.",
            "Shared loom house for lower-status weavers.",
            "Women trade route news while beating wool.",
        ),
        (
            "Eastern tenement courts",
            "Hostel courtyards.",
            "Dense timber housing for laborers and apprentices.",
            "Overcrowding fuels sympathy for the rural rebels.",
        ),
        (
            "Viru Gate foreland",
            "Park outside the walls.",
            "Open marshy ground before the eastern approach road.",
            "Rebel envoys camp here under truce flags during parley.",
        ),
        (
            "Müürivahe (Wall Street)",
            "Craft market along the wall.",
            "Saddlers and furriers in stalls hugging the curtain wall.",
            "Kalev buys leather here when Hanseatic stock is hoarded.",
        ),
        (
            "Eastern chapel of St. Bridget (lay)",
            "Small shrine near Viru.",
            "Lay devotional house, not the later Pirita convent.",
            "Pilgrims bring tales of burned manor houses in Harju.",
        ),
        (
            "Gate tax office",
            "Historic customs footprint.",
            "Clerks record tolls on incoming carts.",
            "Jürgen Witte bribes clerks to undervalue his imports.",
        ),
    ],
}
