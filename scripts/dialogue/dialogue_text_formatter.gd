class_name DialogueTextFormatter
extends RefCounted

## Expands authored dialogue tokens from runtime economy and location state.

const DistrictPressureModelScript := preload("res://scripts/faction/district_pressure_model.gd")
const TradePriceModelScript := preload("res://scripts/economy/trade_price_model.gd")

static var _token_pattern: RegEx


static func format(text: String, state: GameState, location_id: StringName = &"") -> String:
	if text.is_empty() or not text.contains("{trade_price:"):
		return text
	if state == null:
		return text

	var district_id := DistrictPressureModelScript.district_for_location(location_id)
	if district_id.is_empty():
		district_id = DistrictPressureModelScript.DISTRICT_LOWER_TOWN

	var regex := _pattern()
	var cursor := 0
	var output := ""
	for match_data: RegExMatch in regex.search_all(text):
		var start := match_data.get_start()
		var end := match_data.get_end()
		output += text.substr(cursor, start - cursor)
		var good_id := StringName(match_data.get_string(1))
		if TradePriceModelScript.is_valid_good_id(good_id):
			var quote := TradePriceModelScript.resolve(good_id, district_id, state)
			output += TradePriceModelScript.format_pfennigs(int(quote.get("price_pfennigs", 0)))
		else:
			output += match_data.get_string()
		cursor = end
	output += text.substr(cursor)
	return output


static func _pattern() -> RegEx:
	if _token_pattern == null:
		_token_pattern = RegEx.new()
		_token_pattern.compile("\\{trade_price:([a-z0-9_.]+)\\}")
	return _token_pattern
