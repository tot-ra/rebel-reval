class_name MarketCivicQuarterDefinition
extends RefCounted

## Runtime adapter for the market-civic-quarter .rrmap source.
## WHY: the scene keeps its MapDefinition entry point while historical layout
## and reciprocal district edges remain reviewable as compact map data.


const RRMAP_PATH := "res://content/maps/market_civic_quarter.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
