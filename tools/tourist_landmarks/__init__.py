"""Tourist landmark data composed in catalog display order."""

from .catalog_types import LandmarkCatalog
from .estonia_east_nature import ESTONIA_EAST_NATURE
from .estonia_north_central import ESTONIA_NORTH_CENTRAL
from .estonia_south_west import ESTONIA_SOUTH_WEST
from .metadata import (
    DISTRICT_MAP_LOCATION,
    EXCLUDED,
    FEATURED_LANDMARKS,
    REGION_MAP_LOCATION,
)
from .tallinn_monastery_harbor_walls import TALLINN_MONASTERY_HARBOR_WALLS
from .tallinn_quarters import TALLINN_QUARTERS
from .tallinn_upper_civic import TALLINN_UPPER_CIVIC

TALLINN: LandmarkCatalog = {
    **TALLINN_UPPER_CIVIC,
    **TALLINN_QUARTERS,
    **TALLINN_MONASTERY_HARBOR_WALLS,
}
ESTONIA: LandmarkCatalog = {
    **ESTONIA_NORTH_CENTRAL,
    **ESTONIA_SOUTH_WEST,
    **ESTONIA_EAST_NATURE,
}

__all__ = [
    "DISTRICT_MAP_LOCATION",
    "ESTONIA",
    "EXCLUDED",
    "FEATURED_LANDMARKS",
    "REGION_MAP_LOCATION",
    "TALLINN",
]
