"""Map bindings and curated metadata for the landmark catalog."""

from __future__ import annotations

from .catalog_types import ExcludedLandmark, FeaturedLandmark

EXCLUDED: list[ExcludedLandmark] = [
    (
        "Alexander Nevsky Cathedral",
        "Built 1900 on Toompea.",
        "Orthodox cathedral absent; castle courtyard occupies the site.",
    ),
    (
        "Kiek in de Kök artillery tower",
        "15th-century cannon tower museum.",
        "Tower not built; standard curtain wall only.",
    ),
    (
        "Fat Margaret (Paks Margareeta)",
        "16th-century harbor artillery tower.",
        "Harbor barbican not yet constructed.",
    ),
    (
        "Kadriorg Palace and Park",
        "Baroque palace of Peter the Great.",
        "Forest and streams; no palace or formal park.",
    ),
    (
        "Pirita St. Bridget's Convent",
        "Ruins of a 1407 convent.",
        "Founded 1407; site is coastal forest in 1343.",
    ),
    (
        "Great Guild Hall (monumental building)",
        "Current hall from 1407-1410.",
        "Guild functions exist in simpler rooms; monumental hall not built.",
    ),
    (
        "House of the Blackheads (ornate house)",
        "Façade from 1597.",
        "Brotherhood exists; grand house not yet built.",
    ),
    (
        "Tallinn TV Tower",
        "20th-century broadcast tower.",
        "No structure; open landscape.",
    ),
    (
        "Linnahall",
        "1970s concert hall on the harbor.",
        "Rocky foreshore and working quays only.",
    ),
    (
        "Song Festival Grounds (Lauluväljak)",
        "Modern amphitheatre.",
        "Open fields outside the wall.",
    ),
]

# Default blueprint / location bindings for each catalog section.
DISTRICT_MAP_LOCATION: dict[str, str] = {
    "Toompea (Upper Town)": "`toompea_quarter` (`loc.toompea.quarter`, inactive prototype)",
    "Market and Civic Quarter": "`market_civic_quarter` (`loc.lower_town.market_civic`, inactive prototype)",
    "North Quarter (Pikk and Merchant Street)": "`north_quarter` (`loc.lower_town.north`, inactive prototype)",
    "South Quarter (Knights and Karja Gate)": "`south_quarter` (`loc.lower_town.south`, inactive prototype)",
    "East Quarter (Lower Town East and Viru Gate)": "`lower_town_slice` (`loc.lower_town.slice`, active slice); foreland `viru_gate_foreland`",
    "Monastery Quarter (Dominican and St. Catherine's)": "`monastery_quarter` (inactive prototype); playable anchors on `lower_town_slice` (`katariina_kaik`, `monastery_gate`)",
    "Harbor and Foreshore": "`reval_harbor_north`, `reval_harbor_east` (inactive harbour prototypes)",
    "City Walls, Towers, and Gates": "Wall registry on `lower_town_slice` and district prototypes (`viru_gate_arch`, `karja_gate_south`, tower IDs in `content/maps/*.rrmap`)",
}

REGION_MAP_LOCATION: dict[str, str] = {
    "Harju County (Reval hinterland)": "World-travel placeholders (`world_harju`, `world_sojamae`, `world_kanavere`) and foreland `viru_gate_foreland`",
    "Northern Estonia (Viru and Lääne)": "Distant placeholders (`world_padise`, `world_rakvere`) on the Estonia global map (`release=false`)",
    "Central Estonia (Järvamaa and Paide)": "`world_paide` placeholder and Järvamaa road nodes on the global map",
    "Southern Estonia (Tartu, Viljandi, Pärnu)": "`world_parnu` and southern placeholders on the global map",
    "Western Islands (Saaremaa and Hiiumaa)": "`world_poide` placeholder; full island campaign in Act 3 (**P6-004**)",
    "Eastern borderlands and Narva region": "Eastern global-map nodes (Narva, Peipus shore); no seamless border play",
    "Sacred sites, forests, and natural landmarks": "Foreland margins, `world_harju`, and narrative-only hiis references (**P1-037a**)",
}

# Featured tourist landmarks for quick CANON / map cross-reference (P0-113 verify).
FEATURED_LANDMARKS: list[FeaturedLandmark] = [
    (
        "Toompea Castle",
        "Danish stone keep; Tall Hermann tower not built",
        "`toompea_quarter`",
        "Siege objective during [St. George's Night](./CANON.md#timeline-aprilmay-1343)",
    ),
    (
        "Tallinn Town Hall",
        "Smaller 1322-era civic hall; no 1404 tower",
        "`market_civic_quarter`",
        "Hanseatic politics via [Jürgen Witte](./CHARACTERS/jurgen.md)",
    ),
    (
        "St. Olaf's Church",
        "1330-era west tower without later spire",
        "`north_quarter` (`st_olaf_silhouette`)",
        "Mart's courtyard contacts in the catalog entry",
    ),
    (
        "Viru Gate",
        "Functional gate without 15th-century twin towers",
        "`lower_town_slice` (`viru_gate_arch`, `checkpoint_east`)",
        "[Captain Henning](./CHARACTERS/henning.md) patrol sector",
    ),
    (
        "Coastal Gate (Suur Rannavärav)",
        "Simpler stone sea gate; no Fat Margaret barbican",
        "`reval_harbor_north` (`great_coast_gate`)",
        "Harbor tolls and [Kalev](./CHARACTERS/kalev.md) forge commissions",
    ),
    (
        "Dominican Monastery (St. Catherine's)",
        "Active 1246 monastery with brewery and school",
        "`monastery_quarter`; `lower_town_slice` (`katariina_kaik`)",
        "[Aita](./CHARACTERS/aita.md) trades ale for medicinal herbs",
    ),
    (
        "Rataskaevu Street well",
        "Public well with local superstitions",
        "`south_quarter`",
        "[Ellen Luik](./CHARACTERS/ellen.md) hears old songs at dusk",
    ),
    (
        "Holy Spirit Church",
        "1316 chapel-almshouse; no public clock yet",
        "`market_civic_quarter`",
        "Ellen's charity network beside formal almshouse rules",
    ),
    (
        "Ülemiste Lake / Sõjamäe",
        "Freshwater lake and May 14 battlefield shore",
        "`world_sojamae` placeholder",
        "Attested [Battle of Sõjamäe](./CANON.md#timeline-aprilmay-1343)",
    ),
    (
        "Paide Castle",
        "Order stronghold in central Estonia",
        "`world_paide` placeholder",
        "Four Kings execution site per [canon timeline](./CANON.md#timeline-aprilmay-1343)",
    ),
    (
        "Kanavere Bog",
        "May 11 rebel victory marsh",
        "`world_kanavere` placeholder",
        "Attested [Battle of Kanavere Bog](./CANON.md#timeline-aprilmay-1343)",
    ),
    (
        "Padise Cistercian Monastery",
        "Wealthy abbey with farm and mill rights",
        "`world_padise` placeholder",
        "Neutral clergy when manors burn in Harju",
    ),
]
