class_name EstoniaStarCatalog
extends RefCounted

## Hipparcos stars with apparent magnitude <= 5.0, converted from the
## d3-celestial stars.6 catalog. Entries are J2000 (right ascension degrees,
## declination degrees, visual magnitude, B-V color index). SkyWeather3D
## precesses them to 1343 before rendering the sky above medieval Reval.
## Source and BSD-3-Clause attribution:
## res://scripts/map/view3d/third_party/d3_celestial_BSD_3_CLAUSE.txt

const CATALOG_EPOCH := 2000.0
const LIMITING_MAGNITUDE := 5.0

const _RA_000_090 := preload("res://scripts/map/view3d/estonia_star_catalog_ra_000_090.gd")
const _RA_090_180 := preload("res://scripts/map/view3d/estonia_star_catalog_ra_090_180.gd")
const _RA_180_270 := preload("res://scripts/map/view3d/estonia_star_catalog_ra_180_270.gd")
const _RA_270_360 := preload("res://scripts/map/view3d/estonia_star_catalog_ra_270_360.gd")

## Kept as one ordered array so catalog consumers retain the original API.
const STARS: Array[Vector4] = (
	_RA_000_090.STARS
	+ _RA_090_180.STARS
	+ _RA_180_270.STARS
	+ _RA_270_360.STARS
)
