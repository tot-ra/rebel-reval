extends RefCounted

var _failures: Array[String] = []

func before_each() -> void:
	_failures.clear()

func after_each() -> void:
	pass

func assert_true(condition: bool, message: String = "Expected condition to be true") -> void:
	if not condition:
		fail(message)

func assert_false(condition: bool, message: String = "Expected condition to be false") -> void:
	if condition:
		fail(message)

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		var detail := "Expected <%s> but got <%s>" % [str(expected), str(actual)]
		fail(_format_message(message, detail))

func assert_ne(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual == expected:
		var detail := "Expected value different from <%s>" % str(expected)
		fail(_format_message(message, detail))

func assert_array_contains(values: Array, expected: Variant, message: String = "") -> void:
	if not values.has(expected):
		var detail := "Expected array to contain <%s>; values were <%s>" % [str(expected), str(values)]
		fail(_format_message(message, detail))

func fail(message: String) -> void:
	_failures.append(message)

func _get_failures() -> Array[String]:
	return _failures.duplicate()

func _format_message(message: String, detail: String) -> String:
	if message.is_empty():
		return detail
	return "%s - %s" % [message, detail]
