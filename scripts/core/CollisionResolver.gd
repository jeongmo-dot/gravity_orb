class_name CollisionResolver
extends Node

signal reaction_applied(reaction: Dictionary)

@onready var _board: Variant = %Board

var _pending: Array[Array] = []
var _reaction_locks: Dictionary = {}
var _spawner: Spawner = null


func _ready() -> void:
	_board.orb_contact.connect(report_contact)
	_spawner = get_node_or_null("%Spawner") as Spawner


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


func flush(delta: float = 0.0) -> int:
	_advance_reaction_locks(delta)
	_queue_released_reaction_contacts()
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
		if _is_reaction_locked(a) or _is_reaction_locked(b):
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
		var stable_spawn_ids: Array[int] = [a.stable_spawn_id, b.stable_spawn_id]
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

		if result_orb != null:
			_lock_reaction_result(result_orb)

		var shock_level: int = (
			Config.data.orb_max_level
			if reaction_type == ReactionRules.Type.MAX_CLEAR
			else result_level
		)
		var shock_targets: Array[Dictionary] = []
		var blast_targets: Array[Dictionary] = []
		if (
			reaction_type == ReactionRules.Type.MERGE
			or reaction_type == ReactionRules.Type.MAX_CLEAR
		):
			shock_targets = _board.apply_shockwave(
				reaction_position,
				shock_level,
				result_orb,
				reaction_type == ReactionRules.Type.MAX_CLEAR,
				result_color,
				(
					Callable(_spawner, "next_shake_direction")
					if _spawner != null
					else Callable()
				)
			)
		elif reaction_type == ReactionRules.Type.BLAST:
			blast_targets = _board.apply_blast(reaction_position)

		var reaction: Dictionary = {
			"type": reaction_type,
			"chain": chain,
			"occupancy": occupancy,
			"levels": levels,
			"colors": colors,
			"stable_spawn_ids": stable_spawn_ids,
			"position": reaction_position,
			"result_level": result_level,
			"result_color": result_color,
			"result_orb": result_orb,
			"shock_level": shock_level,
			"shock_targets": shock_targets,
			"blast_targets": blast_targets,
		}
		reaction_applied.emit(reaction)
		applied += 1
	return applied


func has_pending_reactions() -> bool:
	for lock_id_value: Variant in _reaction_locks.keys():
		var lock_id: int = int(lock_id_value)
		var entry: Dictionary = _reaction_locks[lock_id] as Dictionary
		var orb: Variant = entry.get("orb")
		if not _is_valid_reaction_orb(orb):
			continue
		if not _current_reaction_partners(orb).is_empty():
			return true
	return false


func _is_reaction_locked(orb: Variant) -> bool:
	if not is_instance_valid(orb):
		return false
	var lock_id: int = orb.get_instance_id()
	if not _reaction_locks.has(lock_id):
		return false
	var entry: Dictionary = _reaction_locks[lock_id] as Dictionary
	return float(entry.get("remaining", 0.0)) > 0.0
func _lock_reaction_result(orb: Variant) -> void:
	var delay: float = maxf(Config.data.chain_reaction_delay, 0.0)
	if delay <= 0.0:
		return
	_reaction_locks[orb.get_instance_id()] = {
		"orb": orb,
		"remaining": delay,
	}


func _advance_reaction_locks(delta: float) -> void:
	if delta <= 0.0:
		return
	for lock_id_value: Variant in _reaction_locks.keys():
		var lock_id: int = int(lock_id_value)
		var entry: Dictionary = _reaction_locks[lock_id] as Dictionary
		var orb: Variant = entry.get("orb")
		if not _is_valid_reaction_orb(orb):
			_reaction_locks.erase(lock_id)
			continue
		var remaining: float = float(entry["remaining"]) - delta
		entry["remaining"] = 0.0 if remaining <= 0.000001 else remaining
		_reaction_locks[lock_id] = entry


func _queue_released_reaction_contacts() -> void:
	var released_ids: Array[int] = []
	for lock_id_value: Variant in _reaction_locks.keys():
		var lock_id: int = int(lock_id_value)
		var entry: Dictionary = _reaction_locks[lock_id] as Dictionary
		var orb: Variant = entry.get("orb")
		if not _is_valid_reaction_orb(orb):
			released_ids.append(lock_id)
			continue
		if float(entry.get("remaining", 0.0)) > 0.0:
			continue
		for partner: Variant in _current_reaction_partners(orb):
			report_contact(orb, partner)
		released_ids.append(lock_id)
	for lock_id: int in released_ids:
		_reaction_locks.erase(lock_id)


func _current_reaction_partners(orb: Variant) -> Array:
	var partners: Array = []
	if not _is_valid_reaction_orb(orb):
		return partners
	if orb.is_waiting_at_entrance:
		return partners
	var orb_radius: float = _orb_contact_radius(orb)
	for candidate: Variant in _board.get_orbs():
		if candidate == orb or not _is_valid_reaction_orb(candidate):
			continue
		if candidate.is_ghost or candidate.is_waiting_at_entrance:
			continue
		var contact_distance: float = (
			orb_radius
			+ _orb_contact_radius(candidate)
			+ Config.data.ghost_exit_overlap
		)
		if orb.position.distance_to(candidate.position) > contact_distance:
			continue
		if not _pair_can_react(orb, candidate):
			continue
		partners.append(candidate)
	return partners


func _pair_can_react(a: Variant, b: Variant) -> bool:
	var classified: Dictionary = ReactionRules.classify(
		a.color,
		a.level,
		b.color,
		b.level,
		Config.data
	)
	return int(classified["type"]) != ReactionRules.Type.NONE


func _orb_contact_radius(orb: Variant) -> float:
	if orb.has_method("get_current_radius"):
		return float(orb.get_current_radius())
	return float(orb.get_radius())


func _is_valid_reaction_orb(orb: Variant) -> bool:
	return is_instance_valid(orb) and not orb.consumed


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
