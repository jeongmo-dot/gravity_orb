class_name CollisionResolver
extends Node

signal reaction_applied(reaction: Dictionary)

@onready var _board: Variant = %Board

var _pending: Array[Array] = []


func _ready() -> void:
	_board.orb_contact.connect(report_contact)


func report_contact(a: Variant, b: Variant) -> void:
	if a.stable_spawn_id <= b.stable_spawn_id:
		_pending.append([a, b])
	else:
		_pending.append([b, a])


func sweep_resting_contacts() -> int:
	for a: Variant in _board.get_orbs():
		for b: Variant in a.get_colliding_orbs():
			if b == null or b.consumed:
				continue
			if a.stable_spawn_id < b.stable_spawn_id:
				report_contact(a, b)
	return flush()


func flush() -> int:
	var pending: Array[Array] = _pending
	_pending = []
	pending.sort_custom(_pair_less)
	var applied: int = 0
	var visited_pairs: Dictionary = {}
	for pair: Array in pending:
		var a: Variant = pair[0]
		var b: Variant = pair[1]
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		if a.consumed or b.consumed:
			continue
		var pair_key: String = "%d:%d" % [a.stable_spawn_id, b.stable_spawn_id]
		if visited_pairs.has(pair_key):
			continue
		visited_pairs[pair_key] = true

		var classified: Dictionary = ReactionRules.classify(
			a.color,
			a.level,
			b.color,
			b.level,
			Config.data
		)
		var reaction_type: ReactionRules.Type = classified["type"] as ReactionRules.Type
		if reaction_type == ReactionRules.Type.NONE:
			continue

		var chain: int = maxi(a.generation, b.generation) + 1
		var levels: Array[int] = [a.level, b.level]
		var colors: Array[int] = [a.color, b.color]
		var position_a: Vector2 = a.position
		var position_b: Vector2 = b.position
		var velocity_a: Vector2 = a.linear_velocity
		var velocity_b: Vector2 = b.linear_velocity
		var reaction_position: Vector2 = (position_a + position_b) * 0.5
		var result_level: int = int(classified["result_level"])
		var result_color: int = int(classified["result_color"])
		var survivor: int = int(classified["survivor"])
		var result_orb: Variant = null
		var occupancy: float = _board_occupancy()

		_board.remove_orb(a)
		_board.remove_orb(b)
		if reaction_type == ReactionRules.Type.MERGE:
			var result_radius: float = Config.data.radius_for_level(result_level)
			reaction_position = _clamp_inside(reaction_position, result_radius)
			result_orb = _board.spawn_orb(
				result_color,
				result_level,
				reaction_position,
				(velocity_a + velocity_b) * 0.5,
				chain
			)
			result_orb.note_diagnostic_event("merge_result")
			if _board.should_ghost_reaction_results():
				result_orb.enter_ghost_state(Config.data.ghost_alpha)
		elif reaction_type == ReactionRules.Type.ANNIHILATE and survivor != 0:
			reaction_position = position_a if survivor == 1 else position_b
			var survivor_velocity: Vector2 = velocity_a if survivor == 1 else velocity_b
			result_orb = _board.spawn_orb(
				result_color,
				result_level,
				reaction_position,
				survivor_velocity,
				chain
			)
			result_orb.note_diagnostic_event("annihilate_survivor")
			if _board.should_ghost_reaction_results():
				result_orb.enter_ghost_state(Config.data.ghost_alpha)

		var reaction: Dictionary = {
			"type": reaction_type,
			"chain": chain,
			"occupancy": occupancy,
			"levels": levels,
			"colors": colors,
			"position": reaction_position,
			"result_level": result_level,
			"result_color": result_color,
			"result_orb": result_orb,
		}
		reaction_applied.emit(reaction)
		applied += 1
	return applied


func _board_occupancy() -> float:
	var occupied_area: float = 0.0
	for orb: Variant in _board.get_orbs():
		var radius: float = Config.data.radius_for_level(orb.level)
		occupied_area += PI * radius * radius
	return occupied_area / (Config.data.board_size * Config.data.board_size)


func _pair_less(first: Array, second: Array) -> bool:
	var first_a: Variant = first[0]
	var first_b: Variant = first[1]
	var second_a: Variant = second[0]
	var second_b: Variant = second[1]
	if first_a.stable_spawn_id != second_a.stable_spawn_id:
		return first_a.stable_spawn_id < second_a.stable_spawn_id
	return first_b.stable_spawn_id < second_b.stable_spawn_id


func _clamp_inside(position: Vector2, radius: float) -> Vector2:
	var extent: float = _board.half_size() - radius
	return Vector2(
		clampf(position.x, -extent, extent),
		clampf(position.y, -extent, extent)
	)
