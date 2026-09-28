class_name TestCase
extends RefCounted

var tree: SceneTree
var failures: Array[String] = []


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual == expected:
		return
	_record_failure(_with_context(message, "Expected %s, got %s" % [str(expected), str(actual)]))


func assert_true(condition: bool, message: String = "") -> void:
	if condition:
		return
	_record_failure(_with_context(message, "Expected condition to be true"))


func assert_near(actual: float, expected: float, epsilon: float, message: String = "") -> void:
	if absf(actual - expected) <= epsilon:
		return
	_record_failure(
		_with_context(
			message,
			"Expected %s to be within %s of %s" % [str(actual), str(epsilon), str(expected)]
		)
	)


func get_failure_count() -> int:
	return failures.size()


func _record_failure(message: String) -> void:
	failures.append(message)


func _with_context(context: String, detail: String) -> String:
	if context.is_empty():
		return detail
	return "%s: %s" % [context, detail]
