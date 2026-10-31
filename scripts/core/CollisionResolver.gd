class_name CollisionResolver
extends Node

signal reaction_applied(reaction: Dictionary)

const GEOMETRIC_CONTACT_TOLERANCE: float = 2.0
const FORWARD_CELL_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]

@onready var _board: Variant = %Board

var _pending: Array[Array] = []
var _reaction_locks: Dictionary = {}
var _active_jelly_merges: Array[Dictionary] = []
var _merge_reserved: Dictionary = {}
var _accepting_new_jelly_merges: bool = true
var max_concurrent_jelly_merges: int = 0
var deferred_jelly_merge_count: int = 0
var _deferred_jelly_merge_pairs: Dictionary = {}
var _spawner: Spawner = null
var proximity_reaction_scan_enabled: bool = true
var latency_measurement_enabled: bool = false
var _measurement_tick: int = 0
var _measurement_active_contacts: Dictionary = {}
var _measurement_records: Array[Dictionary] = []


func _ready() -> void:
	_board.orb_contact.connect(report_contact)
	_spawner = get_node_or_null("%Spawner") as Spawner


func report_contact(a: Variant, b: Variant, path: String = "body_entered") -> void:
	if a.stable_spawn_id <= b.stable_spawn_id:
		_pending.append([a, b, path])
	else:
		_pending.append([b, a, path])


func sweep_resting_contacts() -> int:
	for a: Variant in _board.get_orbs():
		for b: Variant in a.get_colliding_orbs():
			if b == null or b.consumed:
				continue
			if a.stable_spawn_id < b.stable_spawn_id:
				report_contact(a, b, "sweep")
	return flush()


func flush(delta: float = 0.0) -> int:
	_measurement_tick += 1
	if proximity_reaction_scan_enabled:
		_scan_reaction_proximity_groups(true)
	if latency_measurement_enabled:
		_scan_geometric_contacts(false, true)
	_advance_reaction_locks(delta)
	var applied: int = _advance_active_jelly_merges(delta)
	_queue_released_reaction_contacts()
	var pending: Array[Array] = _pending
	_pending = []
	pending.sort_custom(_pair_less)
	var visited_pairs: Dictionary = {}
	var occupied_area: float = _board_occupied_area()
	for pair: Array in pending:
		var a: Variant = pair[0]
		var b: Variant = pair[1]
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		if a.consumed or b.consumed:
			continue
		if _is_reaction_locked(a) or _is_reaction_locked(b):
			continue
		var pair_key: int = (
			(int(a.stable_spawn_id) << 32) | int(b.stable_spawn_id)
		)
		if visited_pairs.has(pair_key):
			continue
		visited_pairs[pair_key] = true

		var classified: Dictionary = ReactionRules.classify(
			a.color,
			a.level,
			b.color,
			b.level,
			Config.data,
			float(a.get("jelly_mass")),
			float(b.get("jelly_mass"))
		)
		var reaction_type: ReactionRules.Type = classified["type"] as ReactionRules.Type
		if reaction_type == ReactionRules.Type.NONE:
			continue
		var contact_path: String = str(pair[2])

		var chain: int = maxi(a.generation, b.generation) + 1
		var levels: Array[int] = [a.level, b.level]
		var colors: Array[int] = [a.color, b.color]
		var stable_spawn_ids: Array[int] = [a.stable_spawn_id, b.stable_spawn_id]
		var position_a: Vector2 = a.position
		var position_b: Vector2 = b.position
		var source_radii: Array[float] = [a.get_current_radius(), b.get_current_radius()]
		var velocity_a: Vector2 = a.linear_velocity
		var velocity_b: Vector2 = b.linear_velocity
		var reaction_position: Vector2 = (position_a + position_b) * 0.5
		var result_level: int = int(classified["result_level"])
		var result_color: int = int(classified["result_color"])
		var survivor: int = int(classified["survivor"])
		var result_orb: Variant = null
		var occupancy: float = occupied_area / (
			Config.data.board_size * Config.data.board_size
		)
		var result_mass: float = float(classified.get("result_mass", 0.0))
		var jelly_absorption: bool = bool(classified.get("jelly_absorption", false))
		var absorber: int = int(classified.get("absorber", 0))
		if absorber == 1:
			reaction_position = position_a
		elif absorber == 2:
			reaction_position = position_b

		if (
			Config.data.game_mode == GameConfig.GameMode.JELLY
			and Config.data.jelly_merge_duration > 0.0
			and _board.has_method("detach_orb_for_merge_visual")
			and reaction_type in [ReactionRules.Type.MERGE, ReactionRules.Type.MAX_CLEAR]
		):
			if not _accepting_new_jelly_merges:
				_deferred_jelly_merge_pairs[pair_key] = true
				continue
			_start_delayed_jelly_merge(
				a,
				b,
				classified,
				contact_path,
				chain,
				levels,
				colors,
				stable_spawn_ids,
				position_a,
				position_b,
				source_radii,
				velocity_a,
				velocity_b,
				reaction_position,
				result_level,
				result_color,
				result_mass,
				jelly_absorption,
				absorber,
				occupancy
			)
			occupied_area = _board_occupied_area()
			continue

		_board.remove_orb(a)
		_board.remove_orb(b)
		occupied_area -= PI * (
			source_radii[0] * source_radii[0]
			+ source_radii[1] * source_radii[1]
		)
		if reaction_type == ReactionRules.Type.MERGE:
			var result_radius: float = (
				Config.data.jelly_radius_for_mass(result_mass)
				if Config.data.game_mode == GameConfig.GameMode.JELLY
				else Config.data.radius_for_level(result_level)
			)
			reaction_position = _clamp_inside(reaction_position, result_radius)
			var result_velocity: Vector2 = (velocity_a + velocity_b) * 0.5
			if absorber == 1:
				result_velocity = velocity_a
			elif absorber == 2:
				result_velocity = velocity_b
			result_orb = _board.spawn_orb(
				result_color,
				result_level,
				reaction_position,
				result_velocity,
				chain
			)
			if Config.data.game_mode == GameConfig.GameMode.JELLY:
				var growth_start_radius: float = -1.0
				if jelly_absorption and absorber >= 1 and absorber <= source_radii.size():
					growth_start_radius = source_radii[absorber - 1]
				if result_orb is Orb3D:
					result_orb.set_jelly_mass(
						result_mass,
						Config.data,
						growth_start_radius
					)
				else:
					result_orb.set_jelly_mass(result_mass, Config.data)
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
			var current_result_radius: float = _orb_contact_radius(result_orb)
			occupied_area += PI * current_result_radius * current_result_radius
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
			blast_targets = _board.apply_blast(reaction_position, levels[0])

		var reaction: Dictionary = {
			"type": reaction_type,
			"chain": chain,
			"occupancy": occupancy,
			"levels": levels,
			"colors": colors,
			"stable_spawn_ids": stable_spawn_ids,
			"position": reaction_position,
			"source_positions": [position_a, position_b],
			"source_radii": source_radii,
			"result_level": result_level,
			"result_color": result_color,
			"result_orb": result_orb,
			"result_mass": result_mass,
			"jelly_absorption": jelly_absorption,
			"absorbed_level": int(classified.get("absorbed_level", 0)),
			"absorber": absorber,
			"shock_level": shock_level,
			"shock_targets": shock_targets,
			"blast_targets": blast_targets,
			"contact_path": contact_path,
			"reaction_applied_usec": Time.get_ticks_usec(),
			"reaction_physics_frame": Engine.get_physics_frames(),
			"reaction_process_frame": Engine.get_process_frames(),
		}
		_record_measured_reaction(a, b, contact_path)
		reaction_applied.emit(reaction)
		applied += 1
	return applied


func set_accepting_new_jelly_merges(accepting: bool) -> void:
	if accepting and not _accepting_new_jelly_merges:
		deferred_jelly_merge_count += _deferred_jelly_merge_pairs.size()
		_deferred_jelly_merge_pairs.clear()
	elif not accepting and _accepting_new_jelly_merges:
		_deferred_jelly_merge_pairs.clear()
	_accepting_new_jelly_merges = accepting


func active_jelly_merge_count() -> int:
	return _active_jelly_merges.size()


func cancel_active_jelly_merges() -> void:
	for entry: Dictionary in _active_jelly_merges:
		var reaction: Dictionary = entry.get("reaction", {}) as Dictionary
		var result_orb: Variant = reaction.get("result_orb")
		if is_instance_valid(result_orb):
			result_orb.finish_radius_growth()
		for source_value: Variant in entry.get("visual_sources", []) as Array:
			var source_entry: Dictionary = source_value as Dictionary
			var source: Variant = source_entry.get("orb")
			if is_instance_valid(source):
				source.queue_free()
	_active_jelly_merges.clear()
	_merge_reserved.clear()
	_pending.clear()
	_reaction_locks.clear()
	_accepting_new_jelly_merges = true
	max_concurrent_jelly_merges = 0
	deferred_jelly_merge_count = 0
	_deferred_jelly_merge_pairs.clear()


func _start_delayed_jelly_merge(
	a: Variant,
	b: Variant,
	classified: Dictionary,
	contact_path: String,
	chain: int,
	levels: Array[int],
	colors: Array[int],
	stable_spawn_ids: Array[int],
	position_a: Vector2,
	position_b: Vector2,
	source_radii: Array[float],
	velocity_a: Vector2,
	velocity_b: Vector2,
	reaction_position: Vector2,
	result_level: int,
	result_color: int,
	result_mass: float,
	jelly_absorption: bool,
	absorber: int,
	occupancy: float
) -> void:
	var reaction_type: ReactionRules.Type = classified["type"] as ReactionRules.Type
	var duration: float = maxf(Config.data.jelly_merge_duration, 0.0)
	var result_orb: Variant = null
	var visual_sources: Array[Dictionary] = []
	if reaction_type == ReactionRules.Type.MAX_CLEAR:
		_board.detach_orb_for_merge_visual(a)
		_board.detach_orb_for_merge_visual(b)
		visual_sources = [
			{"orb": a, "start": position_a},
			{"orb": b, "start": position_b},
		]
	else:
		if jelly_absorption:
			var absorber_orb: Variant = a if absorber == 1 else b
			var absorbed_orb: Variant = b if absorber == 1 else a
			var absorbed_position: Vector2 = position_b if absorber == 1 else position_a
			var start_radius: float = source_radii[absorber - 1]
			_board.detach_orb_for_merge_visual(absorbed_orb)
			visual_sources = [{"orb": absorbed_orb, "start": absorbed_position}]
			result_orb = absorber_orb
			result_orb.generation = chain
			result_orb.set_jelly_mass(
				result_mass,
				Config.data,
				start_radius,
				duration,
				true
			)
		else:
			_board.detach_orb_for_merge_visual(a)
			_board.detach_orb_for_merge_visual(b)
			visual_sources = [
				{"orb": a, "start": position_a},
				{"orb": b, "start": position_b},
			]
			var result_radius: float = Config.data.jelly_radius_for_mass(result_mass)
			reaction_position = _clamp_inside(reaction_position, result_radius)
			result_orb = _board.spawn_orb(
				result_color,
				result_level,
				reaction_position,
				(velocity_a + velocity_b) * 0.5,
				chain
			)
			result_orb.set_jelly_mass(
				result_mass,
				Config.data,
				Config.data.radius_for_level(levels[0]),
				duration,
				true
			)
		if result_orb != null:
			result_orb.note_diagnostic_event("merge_result")
			if _board.should_ghost_reaction_results():
				result_orb.enter_ghost_state(Config.data.ghost_alpha)
			_merge_reserved[result_orb.get_instance_id()] = result_orb
			_lock_reaction_result(result_orb)
	var shock_level: int = (
		Config.data.orb_max_level
		if reaction_type == ReactionRules.Type.MAX_CLEAR
		else result_level
	)
	var reaction: Dictionary = {
		"type": reaction_type,
		"chain": chain,
		"occupancy": occupancy,
		"levels": levels,
		"colors": colors,
		"stable_spawn_ids": stable_spawn_ids,
		"position": reaction_position,
		"source_positions": [position_a, position_b],
		"source_radii": source_radii,
		"result_level": result_level,
		"result_color": result_color,
		"result_orb": result_orb,
		"result_mass": result_mass,
		"jelly_absorption": jelly_absorption,
		"absorbed_level": int(classified.get("absorbed_level", 0)),
		"absorber": absorber,
		"shock_level": shock_level,
		"shock_targets": [],
		"blast_targets": [],
		"contact_path": contact_path,
	}
	_record_measured_reaction(a, b, contact_path)
	_active_jelly_merges.append({
		"elapsed": 0.0,
		"duration": duration,
		"reaction": reaction,
		"visual_sources": visual_sources,
		"fixed_target": reaction_position,
	})
	max_concurrent_jelly_merges = maxi(
		max_concurrent_jelly_merges,
		_active_jelly_merges.size()
	)
	_update_active_jelly_merge_visual(_active_jelly_merges[-1], 0.0)


func _advance_active_jelly_merges(delta: float) -> int:
	if _active_jelly_merges.is_empty():
		return 0
	var completed: int = 0
	var remaining_entries: Array[Dictionary] = []
	for entry: Dictionary in _active_jelly_merges:
		var duration: float = maxf(float(entry["duration"]), 0.000001)
		entry["elapsed"] = minf(float(entry["elapsed"]) + maxf(delta, 0.0), duration)
		var progress: float = float(entry["elapsed"]) / duration
		_update_active_jelly_merge_visual(entry, progress)
		if progress < 1.0:
			remaining_entries.append(entry)
			continue
		_complete_active_jelly_merge(entry)
		completed += 1
	_active_jelly_merges = remaining_entries
	return completed


func _update_active_jelly_merge_visual(entry: Dictionary, progress: float) -> void:
	var reaction: Dictionary = entry["reaction"] as Dictionary
	var result_orb: Variant = reaction.get("result_orb")
	var target: Vector2 = entry["fixed_target"] as Vector2
	if is_instance_valid(result_orb):
		target = result_orb.position
	var eased: float = progress * progress
	for source_value: Variant in entry["visual_sources"] as Array:
		var source_entry: Dictionary = source_value as Dictionary
		var source: Variant = source_entry.get("orb")
		if not is_instance_valid(source):
			continue
		var start: Vector2 = source_entry["start"] as Vector2
		var direction: Vector2 = target - start
		source.update_merge_visual(start.lerp(target, eased), direction, progress)


func _complete_active_jelly_merge(entry: Dictionary) -> void:
	var reaction: Dictionary = entry["reaction"] as Dictionary
	var result_orb: Variant = reaction.get("result_orb")
	if is_instance_valid(result_orb):
		result_orb.finish_radius_growth()
		_merge_reserved.erase(result_orb.get_instance_id())
		reaction["position"] = result_orb.position
	for source_value: Variant in entry["visual_sources"] as Array:
		var source_entry: Dictionary = source_value as Dictionary
		var source: Variant = source_entry.get("orb")
		if is_instance_valid(source):
			source.queue_free()
	var shock_targets: Array[Dictionary] = _board.apply_shockwave(
		reaction["position"] as Vector2,
		int(reaction["shock_level"]),
		result_orb,
		reaction["type"] == ReactionRules.Type.MAX_CLEAR,
		int(reaction["result_color"]),
		Callable(_spawner, "next_shake_direction") if _spawner != null else Callable()
	)
	reaction["shock_targets"] = shock_targets
	reaction["reaction_applied_usec"] = Time.get_ticks_usec()
	reaction["reaction_physics_frame"] = Engine.get_physics_frames()
	reaction["reaction_process_frame"] = Engine.get_process_frames()
	reaction_applied.emit(reaction)


func configure_latency_measurement(enabled: bool) -> void:
	latency_measurement_enabled = enabled
	_measurement_tick = 0
	_measurement_active_contacts.clear()
	_measurement_records.clear()


func finish_latency_measurement() -> Array[Dictionary]:
	if latency_measurement_enabled:
		for pair_key_value: Variant in _measurement_active_contacts.keys():
			var pair_key: String = str(pair_key_value)
			var entry: Dictionary = _measurement_active_contacts[pair_key] as Dictionary
			_record_missed_measurement(entry, "missed_at_end")
		_measurement_active_contacts.clear()
	return _measurement_records.duplicate(true)


func measure_proximity_scan_usec() -> int:
	var started_usec: int = Time.get_ticks_usec()
	_scan_reaction_proximity_groups(false)
	return Time.get_ticks_usec() - started_usec


func has_pending_reactions() -> bool:
	if not _active_jelly_merges.is_empty():
		return true
	if _reaction_locks.is_empty():
		return false
	var active_orbs: Array = _board.get_orbs()
	if Config.data.game_mode == GameConfig.GameMode.JELLY:
		return _has_pending_jelly_reactions(active_orbs)
	for lock_id_value: Variant in _reaction_locks.keys():
		var lock_id: int = int(lock_id_value)
		var entry: Dictionary = _reaction_locks[lock_id] as Dictionary
		var orb: Variant = entry.get("orb")
		if not _is_valid_reaction_orb(orb):
			continue
		if _has_current_reaction_partner(orb, active_orbs):
			return true
	return false


func _has_pending_jelly_reactions(active_orbs: Array) -> bool:
	var level_stride: int = Config.data.orb_max_level + 1
	var groups: Array = []
	groups.resize(Config.data.color_display.size() * level_stride)
	for candidate: Variant in active_orbs:
		if not _is_valid_reaction_orb(candidate):
			continue
		if candidate.is_ghost or candidate.is_waiting_at_entrance:
			continue
		var group_index: int = int(candidate.color) * level_stride + int(candidate.level)
		if groups[group_index] == null:
			groups[group_index] = []
		(groups[group_index] as Array).append(candidate)
	for lock_id_value: Variant in _reaction_locks.keys():
		var lock_id: int = int(lock_id_value)
		var entry: Dictionary = _reaction_locks[lock_id] as Dictionary
		var orb: Variant = entry.get("orb")
		if not _is_valid_reaction_orb(orb) or orb.is_waiting_at_entrance:
			continue
		var orb_radius: float = _orb_contact_radius(orb)
		for candidate_level: int in range(
			maxi(int(orb.level) - 1, 1),
			mini(int(orb.level) + 1, Config.data.orb_max_level) + 1
		):
			var same_color_index: int = int(orb.color) * level_stride + candidate_level
			if _group_has_touching_partner(
				orb,
				orb_radius,
				groups[same_color_index]
			):
				return true
		if not Config.data.blast_enabled_for_level(int(orb.level)):
			continue
		for color: int in range(Config.data.color_display.size()):
			if color == int(orb.color):
				continue
			var blast_index: int = color * level_stride + int(orb.level)
			if _group_has_touching_partner(
				orb,
				orb_radius,
				groups[blast_index]
			):
				return true
	return false


func _group_has_touching_partner(
	orb: Variant,
	orb_radius: float,
	group_value: Variant
) -> bool:
	if group_value == null:
		return false
	for candidate: Variant in group_value as Array:
		if candidate == orb:
			continue
		var contact_distance: float = (
			orb_radius
			+ _orb_contact_radius(candidate)
			+ Config.data.ghost_exit_overlap
		)
		if orb.position.distance_squared_to(candidate.position) <= (
			contact_distance * contact_distance
		):
			return true
	return false


func _has_current_reaction_partner(orb: Variant, active_orbs: Array) -> bool:
	if not _is_valid_reaction_orb(orb) or orb.is_waiting_at_entrance:
		return false
	var orb_radius: float = _orb_contact_radius(orb)
	for candidate: Variant in active_orbs:
		if candidate == orb or not _is_valid_reaction_orb(candidate):
			continue
		if candidate.is_ghost or candidate.is_waiting_at_entrance:
			continue
		var contact_distance: float = (
			orb_radius
			+ _orb_contact_radius(candidate)
			+ Config.data.ghost_exit_overlap
		)
		if orb.position.distance_squared_to(candidate.position) > (
			contact_distance * contact_distance
		):
			continue
		if _pair_can_react(orb, candidate):
			return true
	return false


func _is_reaction_locked(orb: Variant) -> bool:
	if not is_instance_valid(orb):
		return false
	var lock_id: int = orb.get_instance_id()
	if _merge_reserved.has(lock_id):
		return true
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
		if not _is_existing_reaction_orb(orb):
			_reaction_locks.erase(lock_id)
			continue
		var remaining: float = float(entry["remaining"]) - delta
		entry["remaining"] = 0.0 if remaining <= 0.000001 else remaining
		_reaction_locks[lock_id] = entry


func _queue_released_reaction_contacts() -> void:
	if _reaction_locks.is_empty():
		return
	var released_ids: Array[int] = []
	var active_orbs: Array = _board.get_orbs()
	for lock_id_value: Variant in _reaction_locks.keys():
		var lock_id: int = int(lock_id_value)
		var entry: Dictionary = _reaction_locks[lock_id] as Dictionary
		var orb: Variant = entry.get("orb")
		if not _is_existing_reaction_orb(orb):
			released_ids.append(lock_id)
			continue
		if _merge_reserved.has(lock_id):
			continue
		if float(entry.get("remaining", 0.0)) > 0.0:
			continue
		for partner: Variant in _current_reaction_partners(orb, active_orbs):
			report_contact(orb, partner, "lock_release")
		released_ids.append(lock_id)
	for lock_id: int in released_ids:
		_reaction_locks.erase(lock_id)


func _current_reaction_partners(orb: Variant, active_orbs: Array) -> Array:
	var partners: Array = []
	if not _is_valid_reaction_orb(orb):
		return partners
	if orb.is_waiting_at_entrance:
		return partners
	var orb_radius: float = _orb_contact_radius(orb)
	for candidate: Variant in active_orbs:
		if candidate == orb or not _is_valid_reaction_orb(candidate):
			continue
		if candidate.is_ghost or candidate.is_waiting_at_entrance:
			continue
		var contact_distance: float = (
			orb_radius
			+ _orb_contact_radius(candidate)
			+ Config.data.ghost_exit_overlap
		)
		if orb.position.distance_squared_to(candidate.position) > (
			contact_distance * contact_distance
		):
			continue
		if not _pair_can_react(orb, candidate):
			continue
		partners.append(candidate)
	return partners


func _pair_can_react(a: Variant, b: Variant) -> bool:
	return ReactionRules.can_react(
		a.color,
		a.level,
		b.color,
		b.level,
		Config.data
	)


func _orb_contact_radius(orb: Variant) -> float:
	if orb.has_method("get_current_radius"):
		return float(orb.get_current_radius())
	return float(orb.get_radius())


func _is_valid_reaction_orb(orb: Variant) -> bool:
	return (
		is_instance_valid(orb)
		and not orb.consumed
		and not _merge_reserved.has(orb.get_instance_id())
	)


func _is_existing_reaction_orb(orb: Variant) -> bool:
	return is_instance_valid(orb) and not orb.consumed


func _board_occupied_area() -> float:
	var occupied_area: float = 0.0
	for orb: Variant in _board.get_orbs():
		var radius: float = (
			_orb_contact_radius(orb)
			if Config.data.game_mode == GameConfig.GameMode.JELLY
			else Config.data.radius_for_level(orb.level)
		)
		occupied_area += PI * radius * radius
	return occupied_area


func _pair_less(first: Array, second: Array) -> bool:
	var first_a: Variant = first[0]
	var first_b: Variant = first[1]
	var second_a: Variant = second[0]
	var second_b: Variant = second[1]
	if first_a.stable_spawn_id != second_a.stable_spawn_id:
		return first_a.stable_spawn_id < second_a.stable_spawn_id
	if first_b.stable_spawn_id != second_b.stable_spawn_id:
		return first_b.stable_spawn_id < second_b.stable_spawn_id
	return _path_priority(str(first[2])) < _path_priority(str(second[2]))


func _path_priority(path: String) -> int:
	match path:
		"body_entered":
			return 0
		"proximity":
			return 1
		"lock_release":
			return 2
		"sweep":
			return 3
	return 3


func _scan_geometric_contacts(queue_reactions: bool, measure_contacts: bool) -> void:
	var orbs: Array = []
	for orb: Variant in _board.get_orbs():
		if not _is_valid_reaction_orb(orb):
			continue
		if orb.is_ghost or orb.is_waiting_at_entrance:
			continue
		orbs.append(orb)
	orbs.sort_custom(_orb_less)
	var positions: PackedVector2Array = PackedVector2Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var colors: PackedInt32Array = PackedInt32Array()
	var levels: PackedInt32Array = PackedInt32Array()
	var stable_ids: PackedInt64Array = PackedInt64Array()
	var max_radius: float = 0.0
	for orb: Variant in orbs:
		var radius: float = _orb_contact_radius(orb)
		positions.append(orb.position)
		radii.append(radius)
		colors.append(int(orb.color))
		levels.append(int(orb.level))
		stable_ids.append(int(orb.stable_spawn_id))
		max_radius = maxf(max_radius, radius)
	var cell_size: float = maxf(
		max_radius * 2.0 + GEOMETRIC_CONTACT_TOLERANCE,
		GEOMETRIC_CONTACT_TOLERANCE
	)
	var buckets: Dictionary = {}
	var cells: Array[Vector2i] = []
	for orb_index: int in range(orbs.size()):
		var cell: Vector2i = Vector2i(
			floori(positions[orb_index].x / cell_size),
			floori(positions[orb_index].y / cell_size)
		)
		cells.append(cell)
		var cell_key: Vector2i = cell
		if not buckets.has(cell_key):
			buckets[cell_key] = []
		var bucket: Array = buckets[cell_key] as Array
		bucket.append(orb_index)
	var contact_counts: Dictionary = {}
	var current_contacts: Dictionary = {}
	if measure_contacts:
		for stable_id: int in stable_ids:
			contact_counts[stable_id] = 0
	for orb_index: int in range(orbs.size()):
		var cell: Vector2i = cells[orb_index]
		for offset: Vector2i in FORWARD_CELL_OFFSETS:
				var neighbor_key: Vector2i = cell + offset
				if not buckets.has(neighbor_key):
					continue
				for candidate_index_value: Variant in buckets[neighbor_key] as Array:
					var candidate_index: int = int(candidate_index_value)
					if offset == Vector2i.ZERO and (
						stable_ids[candidate_index] <= stable_ids[orb_index]
					):
						continue
					var contact_distance: float = (
						radii[orb_index]
						+ radii[candidate_index]
						+ GEOMETRIC_CONTACT_TOLERANCE
					)
					if positions[orb_index].distance_squared_to(positions[candidate_index]) > (
						contact_distance * contact_distance
					):
						continue
					if measure_contacts:
						contact_counts[stable_ids[orb_index]] = (
							int(contact_counts[stable_ids[orb_index]]) + 1
						)
						contact_counts[stable_ids[candidate_index]] = (
							int(contact_counts[stable_ids[candidate_index]]) + 1
						)
					if not ReactionRules.can_react(
						colors[orb_index],
						levels[orb_index],
						colors[candidate_index],
						levels[candidate_index],
						Config.data
					):
						continue
					var orb: Variant = orbs[orb_index]
					var candidate: Variant = orbs[candidate_index]
					if queue_reactions:
						report_contact(orb, candidate, "proximity")
					if measure_contacts:
						var pair_key: String = _pair_key(orb, candidate)
						current_contacts[pair_key] = [orb, candidate]
	if not measure_contacts:
		return
	for pair_key_value: Variant in current_contacts.keys():
		var pair_key: String = str(pair_key_value)
		if _measurement_active_contacts.has(pair_key):
			continue
		var pair: Array = current_contacts[pair_key] as Array
		var first: Variant = pair[0]
		var second: Variant = pair[1]
		_measurement_active_contacts[pair_key] = {
			"pair_key": pair_key,
			"first": first,
			"second": second,
			"start_tick": _measurement_tick,
			"contact_count": maxi(
				int(contact_counts[first.stable_spawn_id]),
				int(contact_counts[second.stable_spawn_id])
			),
			"locked": _is_reaction_locked(first) or _is_reaction_locked(second),
		}
	for pair_key_value: Variant in _measurement_active_contacts.keys():
		var pair_key: String = str(pair_key_value)
		if current_contacts.has(pair_key):
			continue
		var entry: Dictionary = _measurement_active_contacts[pair_key] as Dictionary
		var first: Variant = entry.get("first")
		var second: Variant = entry.get("second")
		var outcome: String = (
			"missed_end"
			if _is_measurement_contact_orb(first) and _is_measurement_contact_orb(second)
			else "preempted"
		)
		_record_missed_measurement(entry, outcome)
		_measurement_active_contacts.erase(pair_key)


func _scan_reaction_proximity_groups(queue_contacts: bool) -> void:
	var config: GameConfig = Config.data
	if config.game_mode == GameConfig.GameMode.JELLY:
		_scan_geometric_contacts(queue_contacts, false)
		return
	var level_stride: int = config.orb_max_level + 1
	var exact_group_count: int = config.color_display.size() * level_stride
	var blast_group_offset: int = exact_group_count
	var opposite_group_offset: int = blast_group_offset + level_stride
	var group_count: int = opposite_group_offset + config.opposite_pairs.size()
	var groups: Array = []
	groups.resize(group_count)
	var group_max_radii: PackedFloat32Array = PackedFloat32Array()
	group_max_radii.resize(group_count)
	var orbs: Array = []
	var positions: PackedVector2Array = PackedVector2Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var stable_ids: PackedInt64Array = PackedInt64Array()
	for orb: Variant in _board.get_orbs():
		if not _is_valid_reaction_orb(orb):
			continue
		if orb.is_ghost or orb.is_waiting_at_entrance:
			continue
		var orb_index: int = orbs.size()
		var radius: float = _orb_contact_radius(orb)
		orbs.append(orb)
		positions.append(orb.position)
		radii.append(radius)
		stable_ids.append(orb.stable_spawn_id)
		var primary_group_index: int
		if config.blast_enabled and orb.level >= config.active_blast_min_level():
			primary_group_index = blast_group_offset + orb.level
		else:
			primary_group_index = orb.color * level_stride + orb.level
		if groups[primary_group_index] == null:
			groups[primary_group_index] = []
		var primary_group: Array = groups[primary_group_index] as Array
		primary_group.append(orb_index)
		group_max_radii[primary_group_index] = maxf(
			group_max_radii[primary_group_index],
			radius
		)
		for opposite_index: int in range(config.opposite_pairs.size()):
			var opposite: Vector2i = config.opposite_pairs[opposite_index]
			if orb.color == opposite.x or orb.color == opposite.y:
				var opposite_key: int = opposite_group_offset + opposite_index
				if groups[opposite_key] == null:
					groups[opposite_key] = []
				var opposite_group: Array = groups[opposite_key] as Array
				opposite_group.append(orb_index)
				group_max_radii[opposite_key] = maxf(
					group_max_radii[opposite_key],
					radius
				)
	var needs_deduplication: bool = not config.opposite_pairs.is_empty()
	var queued_pairs: Dictionary = {}
	for group_key: int in range(group_count):
		if groups[group_key] == null:
			continue
		var group: Array = groups[group_key] as Array
		var reaction_guaranteed: bool = group_key < opposite_group_offset
		if group.size() < 2:
			continue
		var cell_size: float = maxf(
			group_max_radii[group_key] * 2.0 + GEOMETRIC_CONTACT_TOLERANCE,
			GEOMETRIC_CONTACT_TOLERANCE
		)
		var buckets: Dictionary = {}
		var cells: PackedVector2Array = PackedVector2Array()
		for group_index: int in range(group.size()):
			var orb_index: int = int(group[group_index])
			var cell: Vector2i = Vector2i(
				floori(positions[orb_index].x / cell_size),
				floori(positions[orb_index].y / cell_size)
			)
			cells.append(cell)
			var cell_key: int = cell.x * 65536 + cell.y
			var bucket_value: Variant = buckets.get(cell_key)
			if bucket_value == null:
				bucket_value = []
				buckets[cell_key] = bucket_value
			var bucket: Array = bucket_value as Array
			bucket.append(group_index)
		for group_index: int in range(group.size()):
			var orb_index: int = int(group[group_index])
			var cell: Vector2i = cells[group_index]
			for offset: Vector2i in FORWARD_CELL_OFFSETS:
				var neighbor_key: int = (
					(cell.x + offset.x) * 65536 + cell.y + offset.y
				)
				var neighbor_bucket_value: Variant = buckets.get(neighbor_key)
				if neighbor_bucket_value == null:
					continue
				for candidate_group_index_value: Variant in neighbor_bucket_value as Array:
					var candidate_group_index: int = int(candidate_group_index_value)
					var candidate_index: int = int(group[candidate_group_index])
					if offset == Vector2i.ZERO and (
						stable_ids[candidate_index] <= stable_ids[orb_index]
					):
						continue
					var first_id: int = mini(
						stable_ids[orb_index],
						stable_ids[candidate_index]
					)
					var second_id: int = maxi(
						stable_ids[orb_index],
						stable_ids[candidate_index]
					)
					var pair_key: int = (first_id << 32) | second_id
					if needs_deduplication and queued_pairs.has(pair_key):
						continue
					var contact_distance: float = (
						radii[orb_index]
						+ radii[candidate_index]
						+ GEOMETRIC_CONTACT_TOLERANCE
					)
					if positions[orb_index].distance_squared_to(positions[candidate_index]) > (
						contact_distance * contact_distance
					):
						continue
					var orb: Variant = orbs[orb_index]
					var candidate: Variant = orbs[candidate_index]
					if not reaction_guaranteed and not _pair_can_react(orb, candidate):
						continue
					if needs_deduplication:
						queued_pairs[pair_key] = true
					if queue_contacts:
						report_contact(orb, candidate, "proximity")


func _record_measured_reaction(a: Variant, b: Variant, path: String) -> void:
	if not latency_measurement_enabled:
		return
	var pair_key: String = _pair_key(a, b)
	var entry: Dictionary = (
		_measurement_active_contacts[pair_key]
		if _measurement_active_contacts.has(pair_key)
		else {
			"pair_key": pair_key,
			"first": a,
			"second": b,
			"start_tick": _measurement_tick,
			"contact_count": 0,
			"locked": _is_reaction_locked(a) or _is_reaction_locked(b),
		}
	)
	_measurement_records.append({
		"outcome": "reaction",
		"path": path,
		"delay_ticks": maxi(_measurement_tick - int(entry["start_tick"]), 0),
		"contact_count": int(entry["contact_count"]),
		"locked": bool(entry["locked"]),
	})
	_measurement_active_contacts.erase(pair_key)


func _record_missed_measurement(entry: Dictionary, outcome: String) -> void:
	_measurement_records.append({
		"outcome": outcome,
		"path": "none",
		"delay_ticks": maxi(_measurement_tick - int(entry["start_tick"]), 0),
		"contact_count": int(entry["contact_count"]),
		"locked": bool(entry["locked"]),
	})


func _is_measurement_contact_orb(orb: Variant) -> bool:
	return (
		_is_valid_reaction_orb(orb)
		and not orb.is_ghost
		and not orb.is_waiting_at_entrance
	)


func _pair_key(a: Variant, b: Variant) -> String:
	var first_id: int = mini(a.stable_spawn_id, b.stable_spawn_id)
	var second_id: int = maxi(a.stable_spawn_id, b.stable_spawn_id)
	return "%d:%d" % [first_id, second_id]


func _orb_less(a: Variant, b: Variant) -> bool:
	return a.stable_spawn_id < b.stable_spawn_id


func _clamp_inside(position: Vector2, radius: float) -> Vector2:
	var extent: float = _board.half_size() - radius
	return Vector2(
		clampf(position.x, -extent, extent),
		clampf(position.y, -extent, extent)
	)
