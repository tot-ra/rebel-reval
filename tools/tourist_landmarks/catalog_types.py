"""Shared type aliases for the tourist landmark catalog."""

Landmark = tuple[str, str, str, str]
LandmarkCatalog = dict[str, list[Landmark]]
ExcludedLandmark = tuple[str, str, str]
FeaturedLandmark = tuple[str, str, str, str]
