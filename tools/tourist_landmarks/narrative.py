"""Narrative integration plan for every P0-113 tourist landmark.

The catalog remains the historical source. This module assigns each catalog row
an authored narrative parent and an existing delivery anchor without activating
prototype maps or creating runtime quest content ahead of its campaign task.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from typing import Iterable

from .catalog_types import LandmarkCatalog


@dataclass(frozen=True)
class SectionPlan:
    integration_kind: str
    parent_id: str
    owner_task: str
    map_id: str
    anchor_id: str
    anchor_source: str


SECTION_PLANS: dict[str, SectionPlan] = {
    "Toompea (Upper Town)": SectionPlan(
        "quest",
        "quest.bell_and_chain",
        "P4-001",
        "toompea_quarter",
        "castle_courtyard",
        "content/maps/toompea_quarter.rrmap",
    ),
    "Market and Civic Quarter": SectionPlan(
        "quest",
        "quest.bread_and_iron",
        "P4-003",
        "market_civic_quarter",
        "market_cross",
        "content/maps/market_civic_quarter.rrmap",
    ),
    "North Quarter (Pikk and Merchant Street)": SectionPlan(
        "quest",
        "quest.price_of_a_name",
        "P4-005",
        "north_quarter",
        "merchant_court",
        "content/maps/north_quarter.rrmap",
    ),
    "South Quarter (Knights and Karja Gate)": SectionPlan(
        "event",
        "event.act1.south_quarter_intelligence",
        "P4-018",
        "south_quarter",
        "karja_approach",
        "content/maps/south_quarter.rrmap",
    ),
    "East Quarter (Lower Town East and Viru Gate)": SectionPlan(
        "quest",
        "quest.bitter_brew",
        "P2-007",
        "lower_town_slice",
        "street_start",
        "content/maps/lower_town_slice.rrmap",
    ),
    "Monastery Quarter (Dominican and St. Catherine's)": SectionPlan(
        "quest",
        "quest.bitter_brew",
        "P2-007",
        "monastery_quarter",
        "monastery_close",
        "content/maps/monastery_quarter.rrmap",
    ),
    "Harbor and Foreshore": SectionPlan(
        "event",
        "event.act1.harbor_pressure",
        "P4-018",
        "reval_harbor_north",
        "quay_plaza",
        "content/maps/reval_harbor_north.rrmap",
    ),
    "City Walls, Towers, and Gates": SectionPlan(
        "quest",
        "quest.bell_and_chain",
        "P4-001",
        "lower_town_slice",
        "checkpoint_east",
        "content/maps/lower_town_slice.rrmap",
    ),
    "Harju County (Reval hinterland)": SectionPlan(
        "event",
        "event.act2.harju_uprising",
        "P5-001",
        "world_harju",
        "landmark_village_well",
        "scripts/map/definitions/outdoor/village_monastery_definitions.gd",
    ),
    "Northern Estonia (Viru and Lääne)": SectionPlan(
        "lore_fragment",
        "lore.northern_estonia_reports",
        "P5-001",
        "world_padise",
        "landmark_gatehouse",
        "scripts/map/definitions/outdoor/village_monastery_definitions.gd",
    ),
    "Central Estonia (Järvamaa and Paide)": SectionPlan(
        "event",
        "event.act2.four_kings",
        "P5-009",
        "world_paide",
        "landmark_central_keep",
        "scripts/map/definitions/outdoor/castle_definitions.gd",
    ),
    "Southern Estonia (Tartu, Viljandi, Pärnu)": SectionPlan(
        "lore_fragment",
        "lore.southern_estonia_trade_reports",
        "P5-001",
        "world_parnu",
        "landmark_primary",
        "scripts/map/definitions/outdoor/wilderness_event_definitions.gd",
    ),
    "Western Islands (Saaremaa and Hiiumaa)": SectionPlan(
        "event",
        "event.act3.saaremaa_campaign",
        "P6-004",
        "world_saaremaa",
        "landmark_primary",
        "scripts/map/definitions/outdoor/wilderness_event_definitions.gd",
    ),
    "Eastern borderlands and Narva region": SectionPlan(
        "lore_fragment",
        "lore.eastern_trade_reports",
        "P5-001",
        "north_quarter",
        "merchant_court",
        "content/maps/north_quarter.rrmap",
    ),
    "Sacred sites, forests, and natural landmarks": SectionPlan(
        "lore_fragment",
        "lore.hingepuu_traditions",
        "P4-007",
        "world_sacred_grove",
        "landmark_ancient_oak",
        "scripts/map/definitions/outdoor/wilderness_event_definitions.gd",
    ),
}

# A named cast member turns the catalog's existing lore hook into an explicit
# dialogue beat. Other local hooks are discoveries; distant reports are lore.
SPEAKERS: tuple[tuple[str, str], ...] = (
    ("kalev", "char.kalev"),
    ("mart", "char.mart"),
    ("aita", "char.aita"),
    ("kaja", "char.kaja"),
    ("henning", "char.henning"),
    ("jurgen", "char.jurgen"),
    ("ellen", "char.ellen"),
)


def slugify(value: str) -> str:
    ascii_value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", ascii_value.lower()).strip("_")


def _speaker_for(lore: str) -> str | None:
    normalized = slugify(lore).replace("_", " ")
    for name, speaker_id in SPEAKERS:
        if re.search(rf"\b{re.escape(name)}\b", normalized):
            return speaker_id
    return None


def _iter_catalogs(
    tallinn: LandmarkCatalog,
    estonia: LandmarkCatalog,
) -> Iterable[tuple[str, LandmarkCatalog]]:
    yield "tallinn", tallinn
    yield "estonia", estonia


def build_integrations(
    tallinn: LandmarkCatalog,
    estonia: LandmarkCatalog,
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for scope, catalog in _iter_catalogs(tallinn, estonia):
        for section, landmarks in catalog.items():
            plan = SECTION_PLANS[section]
            for name, _modern, status_1343, lore in landmarks:
                slug = slugify(name)
                speaker_id = _speaker_for(lore)
                if speaker_id:
                    channel = "npc_dialogue"
                    delivery_id = f"dialogue.landmark.{scope}.{slug}"
                elif plan.integration_kind == "lore_fragment":
                    channel = "lore_fragment"
                    delivery_id = f"lore.landmark.{scope}.{slug}"
                else:
                    channel = "discovery_event"
                    delivery_id = f"event.discovery.landmark.{scope}.{slug}"

                rows.append(
                    {
                        "catalog_key": f"{scope}|{section}|{name}",
                        "scope": scope,
                        "section": section,
                        "landmark": name,
                        "status_1343": status_1343,
                        "integration_kind": plan.integration_kind,
                        "parent_id": plan.parent_id,
                        "beat_id": f"beat.landmark.{scope}.{slug}",
                        "delivery_channel": channel,
                        "delivery_id": delivery_id,
                        "speaker_id": speaker_id,
                        "beat": lore,
                        "owner_task": plan.owner_task,
                        "map_anchor": {
                            "map_id": plan.map_id,
                            "anchor_id": plan.anchor_id,
                            "source": plan.anchor_source,
                            "status": "authored",
                        },
                    }
                )
    return rows
