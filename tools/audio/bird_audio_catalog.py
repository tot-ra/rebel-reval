"""Shared catalog and pure helpers for the bird-audio toolchain.

Keeping this module free of network and file-system effects lets validation and
processing tools share the catalog without importing the downloader CLI.
"""

from __future__ import annotations

# Runtime bird id -> scientific name. Matches map_view_bird_species.gd. Estonia
# hosts the thrush nightingale (Luscinia luscinia), which is what ships in-game.
SPECIES = {
    "herring_gull": "Larus argentatus",
    "common_gull": "Larus canus",
    "common_tern": "Sterna hirundo",
    "mute_swan": "Cygnus olor",
    "mallard": "Anas platyrhynchos",
    "greylag_goose": "Anser anser",
    "great_cormorant": "Phalacrocorax carbo",
    "grey_heron": "Ardea cinerea",
    "northern_lapwing": "Vanellus vanellus",
    "common_snipe": "Gallinago gallinago",
    "white_tailed_eagle": "Haliaeetus albicilla",
    "osprey": "Pandion haliaetus",
    "common_buzzard": "Buteo buteo",
    "common_kestrel": "Falco tinnunculus",
    "tawny_owl": "Strix aluco",
    "house_sparrow": "Passer domesticus",
    "hooded_crow": "Corvus cornix",
    "rook": "Corvus frugilegus",
    "western_jackdaw": "Coloeus monedula",
    "eurasian_magpie": "Pica pica",
    "barn_swallow": "Hirundo rustica",
    "skylark": "Alauda arvensis",
    "yellowhammer": "Emberiza citrinella",
    "common_chaffinch": "Fringilla coelebs",
    "great_tit": "Parus major",
    "european_robin": "Erithacus rubecula",
    "common_blackbird": "Turdus merula",
    "song_thrush": "Turdus philomelos",
    "common_nightingale": "Luscinia luscinia",
    "great_spotted_woodpecker": "Dendrocopos major",
}

# Species whose catalog cue is a true `*.song` (melodic).
SONGBIRDS = {
    "barn_swallow", "skylark", "yellowhammer", "common_chaffinch", "great_tit",
    "european_robin", "common_blackbird", "song_thrush", "common_nightingale",
}

QUALITY_GRADES = "ABCDE"

# xeno-canto explore/API tag tokens that restrict to commercial-friendly licenses.
COMMERCIAL_LICENSE_TAGS = ("lic:by", "lic:by-sa", "lic:zero")

BALTIC_COUNTRIES = frozenset({
    "Estonia", "Latvia", "Lithuania", "Finland", "Sweden",
})


def is_commercial_license(lic_url: str) -> bool:
    """Accept only CC0 / CC BY / CC BY-SA, rejecting -NC and -ND variants."""
    normalized_url = lic_url.lower()
    if "-nc" in normalized_url or "-nd" in normalized_url:
        return False
    return (
        "publicdomain/zero" in normalized_url
        or "/by/" in normalized_url
        or "/by-sa/" in normalized_url
    )


def parse_len_seconds(length: str) -> int:
    """Parse API mm:ss, scrape '106.5 (s)', or plain second counts."""
    if not length:
        return -1
    if ":" in length:
        try:
            parts = [int(part) for part in length.split(":")]
        except ValueError:
            return -1
        seconds = 0
        for part in parts:
            seconds = seconds * 60 + part
        return seconds
    try:
        return int(float(length.split()[0]))
    except (ValueError, IndexError):
        return -1


def species_slug(scientific_name: str) -> str:
    """Return the xeno-canto species-page slug for a scientific name."""
    return scientific_name.replace(" ", "-")


def country_rank(country: str, preferred: list[str]) -> int:
    """Rank preferred countries before other Baltic countries and global results."""
    if country in preferred:
        return preferred.index(country)
    if country in BALTIC_COUNTRIES:
        return len(preferred) + list(BALTIC_COUNTRIES).index(country)
    return 99
