class_name TestCase
extends RefCounted

var tree: SceneTree
var failures: Array[String] = []
var _motion_bounds_reported: Dictionary = {}


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


func assert_board_motion_bounds(board: Node, context: String = "") -> void:
	var maximum_extent: float = float(board.call("half_size")) * 2.0
	var orbs: Array = board.call("get_orbs") as Array
	var board_id: int = board.get_instance_id()
	var already_reported: bool = _motion_bounds_reported.has(board_id)
	var violated: bool = false
	for orb_value: Variant in orbs:
		var orb: RigidBody2D = orb_value as RigidBody2D
		var center_extent: float = maxf(absf(orb.position.x), absf(orb.position.y))
		var speed: float = orb.linear_velocity.length()
		if center_extent > maximum_extent:
			violated = true
			if not already_reported:
				assert_true(
					false,
					"%s orb %d center extent %.3f must be at most %.3f" % [
						context,
						orb.get_instance_id(),
						center_extent,
						maximum_extent,
					]
				)
				already_reported = true
		if speed > 10000.0:
			violated = true
			if not already_reported:
				assert_true(
					false,
					"%s orb %d speed %.3f must be at most 10000.000" % [
						context,
						orb.get_instance_id(),
						speed,
					]
				)
				already_reported = true
	if violated:
		_motion_bounds_reported[board_id] = true


func _record_failure(message: String) -> void:
	failures.append(message)


func _with_context(context: String, detail: String) -> String:
	if context.is_empty():
		return detail
	return "%s: %s" % [context, detail]
