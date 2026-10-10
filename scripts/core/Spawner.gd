class_name Spawner
extends Node

signal next_batch_changed(batch: Array[Dictionary])
signal preview_changed(batches: Array)
signal orb_spawned(level: int)

const EFFECT_SEED_SALT: int = 0x25C01A
const BOT_SEED_SALT: int = 0x31B117
const BLITZ_FILL_MAX_ATTEMPTS: int = 20000
const MAX_DISPLAY_SEED: int = 2147483647

var seed_used: int = 0
var last_blitz_initial_count: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _effect_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _preview_batches: Array[Array] = []
var _blitz_mode: bool = false
var _blitz_candidate_queue: Array[Dictionary] = []
var _blitz_next_batch_size: int = 1
var _blitz_preview_publish_scheduled: bool = false


func init_rng(seed: int) -> int:
	_preview_batches.clear()
	_blitz_candidate_queue.clear()
	_blitz_next_batch_size = 1
	if seed == 0:
		_rng.randomize()
		seed_used = _rng.randi_range(1, MAX_DISPLAY_SEED)
	else:
		seed_used = _normalize_seed(seed)
	_rng.seed = seed_used
	_effect_rng.seed = seed_used ^ EFFECT_SEED_SALT
	_bot_rng.seed = seed_used ^ BOT_SEED_SALT
	return seed_used


func _normalize_seed(seed: int) -> int:
	if seed > 0:
		return seed
	var normalized: int = seed & MAX_DISPLAY_SEED
	return normalized if normalized > 0 else 1


func set_blitz_mode(enabled: bool) -> void:
	_blitz_mode = enabled
	_preview_batches.clear()
	_blitz_candidate_queue.clear()
	_blitz_next_batch_size = 1


func next_blitz_direction(previous: Vector2i) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for direction: Vector2i in OrbTypes.DIRECTIONS:
		if direction != previous:
			candidates.append(direction)
	var index: int = _bot_rng.randi_range(0, candidates.size() - 1)
	return candidates[index]


func choose_blitz_direction(candidates: Array[Vector2i]) -> Vector2i:
	if candidates.is_empty():
		return Vector2i.DOWN
	var index: int = _bot_rng.randi_range(0, candidates.size() - 1)
	return candidates[index]


func next_shake_direction() -> Vector2:
	var angle: float = _effect_rng.randf_range(-PI, PI)
	return Vector2.from_angle(angle)


func spawn_initial(board: Variant, gravity: Vector2i) -> void:
	board.set_gravity(gravity)
	last_blitz_initial_count = 0
	if _blitz_mode:
		_spawn_blitz_initial(board)
		_sync_preview_count(1)
		_publish_preview()
		return
	var count: int = Config.data.initial_orb_count
	var half: float = board.half_size()
	for index: int in range(count):
		var candidate: Dictionary = _draw_candidate()
		var level: int = int(candidate["level"])
		var radius: float = Config.data.radius_for_level(level)
		var fraction: float = float(index + 1) / float(count + 1)
		var position: Vector2 = Vector2(
			lerpf(-half, half, fraction),
			half - radius - Config.data.spawn_margin
		)
		var orb: Variant = board.spawn_orb(int(candidate["color"]), level, position)
		orb.exit_ghost_state()
		orb_spawned.emit(level)
	_sync_preview_count(1)
	_publish_preview()


func _spawn_blitz_initial(board: Variant) -> void:
	var board_area: float = Config.data.board_size * Config.data.board_size
	var target_area: float = board_area * Config.data.blitz_initial_occupancy
	var occupied_area: float = 0.0
	var half: float = board.half_size()
	var placed: Array[Dictionary] = []
	var attempts: int = 0
	while occupied_area < target_area and attempts < BLITZ_FILL_MAX_ATTEMPTS:
		attempts += 1
		var candidate: Dictionary = _draw_candidate()
		var level: int = int(candidate["level"])
		var radius: float = Config.data.radius_for_level(level)
		var limit: float = half - radius - Config.data.spawn_margin
		var position: Vector2 = Vector2(
			_rng.randf_range(-limit, limit),
			_rng.randf_range(-limit, limit)
		)
		if not _blitz_fill_position_is_clear(position, radius, placed):
			continue
		var orb: Variant = board.spawn_orb(
			int(candidate["color"]),
			level,
			position
		)
		orb.exit_ghost_state()
		placed.append({"position": position, "radius": radius})
		occupied_area += PI * radius * radius
		last_blitz_initial_count += 1
		orb_spawned.emit(level)
	if occupied_area < target_area:
		push_warning(
			"BLITZ initial fill stopped at %.3f after %d attempts"
			% [occupied_area / board_area, attempts]
		)


func _blitz_fill_position_is_clear(
	position: Vector2,
	radius: float,
	placed: Array[Dictionary]
) -> bool:
	for item: Dictionary in placed:
		var minimum_distance: float = radius + float(item["radius"])
		if position.distance_squared_to(item["position"] as Vector2) < minimum_distance * minimum_distance:
			return false
	return true


func try_spawn(board: Variant, gravity: Vector2i, turn_index: int = 1) -> Array:
	_sync_preview_count(turn_index)
	var next_batch: Array = _preview_batches[0]

	var spawned: Array = []
	var placed: Array[Dictionary] = []
	for candidate: Dictionary in next_batch:
		var level: int = int(candidate["level"])
		var radius: float = Config.data.radius_for_level(level)
		var line: Dictionary = board.spawn_line(gravity, radius)
		var offset: float = 0.0
		if Config.data.spawn_position_mode == GameConfig.SpawnPositionMode.RANDOM:
			offset = lerpf(
				-float(line["extent"]),
				float(line["extent"]),
				float(candidate["t"])
			)
		var preferred_position: Vector2 = (
			line["origin"] as Vector2
			+ (line["axis"] as Vector2) * offset
		)
		var slot: Dictionary = board.find_free_spawn_slot(
			gravity,
			radius,
			placed,
			preferred_position
		)
		var has_free_slot: bool = bool(slot["found"])
		var position: Vector2 = (
			slot["position"] as Vector2
			if has_free_slot
			else preferred_position
		)
		var orb: Variant = board.spawn_orb(
			int(candidate["color"]),
			level,
			position,
			Vector2.ZERO,
			0
		)
		if has_free_slot:
			placed.append({"position": position, "radius": radius})
		else:
			orb.enter_entrance_wait(preferred_position, gravity)
		spawned.append(orb)
		orb_spawned.emit(level)
	if _blitz_mode:
		for _index: int in range(next_batch.size()):
			_blitz_candidate_queue.pop_front()
	else:
		_preview_batches.pop_front()
	_sync_preview_count(turn_index + 1)
	_publish_preview()
	return spawned


func peek_next() -> Array[Dictionary]:
	if _preview_batches.is_empty():
		return []
	return _public_batch(_preview_batches[0])


func peek_preview() -> Array:
	var result: Array = []
	for batch: Array in _preview_batches:
		result.append(_public_batch(batch))
	return result


func peek_blitz_candidates(count: int) -> Array[Dictionary]:
	if not _blitz_mode:
		return []
	var requested_count: int = maxi(count, 0)
	while _blitz_candidate_queue.size() < requested_count:
		_blitz_candidate_queue.append(_draw_candidate())
	var result: Array[Dictionary] = []
	for index: int in range(requested_count):
		result.append(
			{
				"color": int(_blitz_candidate_queue[index]["color"]),
				"level": int(_blitz_candidate_queue[index]["level"]),
			}
		)
	return result


func sync_next_batch_size(next_turn_index: int = 1) -> void:
	if _blitz_mode:
		_sync_blitz_preview()
		_publish_preview()
		return
	_sync_preview_count(next_turn_index)
	for turn_offset: int in range(_preview_batches.size()):
		var batch: Array = _preview_batches[turn_offset]
		var target_size: int = _batch_size_for_index(next_turn_index + turn_offset)
		while batch.size() < target_size:
			batch.append(_draw_candidate())
		if batch.size() > target_size:
			batch.resize(target_size)
	_publish_preview()


func sync_blitz_next_batch_size(batch_size: int) -> void:
	if not _blitz_mode:
		return
	_blitz_next_batch_size = maxi(batch_size, 1)
	_sync_blitz_preview()
	_publish_preview()


func _draw_candidate() -> Dictionary:
	var level_weights: PackedFloat32Array = (
		Config.data.blitz_spawn_level_weights
		if _blitz_mode
		else Config.data.spawn_level_weights
	)
	var level: int = _rng.rand_weighted(level_weights) + 1
	var color_weights: PackedFloat32Array = (
		Config.data.blitz_spawn_color_weights
		if _blitz_mode
		else Config.data.spawn_color_weights
	)
	var color: int = _rng.rand_weighted(color_weights)
	var position_t: float = _rng.randf()
	return {"level": level, "color": color, "t": position_t}


func _draw_batch(turn_index: int = 1) -> Array[Dictionary]:
	var batch: Array[Dictionary] = []
	var count: int = _batch_size_for_index(turn_index)
	for _index: int in range(count):
		batch.append(_draw_candidate())
	return batch


func _sync_preview_count(next_turn_index: int) -> void:
	if _blitz_mode:
		_sync_blitz_preview()
		return
	var target_count: int = maxi(Config.data.preview_turns, 1)
	if _preview_batches.size() > target_count:
		_preview_batches.resize(target_count)
	while _preview_batches.size() < target_count:
		var turn_offset: int = _preview_batches.size()
		_preview_batches.append(_draw_batch(next_turn_index + turn_offset))


func _sync_blitz_preview() -> void:
	var required_count: int = _blitz_next_batch_size + 1
	while _blitz_candidate_queue.size() < required_count:
		_blitz_candidate_queue.append(_draw_candidate())
	var next_batch: Array[Dictionary] = []
	for index: int in range(_blitz_next_batch_size):
		next_batch.append(_blitz_candidate_queue[index])
	var then_batch: Array[Dictionary] = [_blitz_candidate_queue[_blitz_next_batch_size]]
	_preview_batches.clear()
	_preview_batches.append(next_batch)
	_preview_batches.append(then_batch)


func _batch_size_for_index(turn_index: int) -> int:
	if _blitz_mode:
		return 1
	return maxi(Config.data.spawn_count_for_turn(turn_index), 1)


func _publish_preview() -> void:
	if _blitz_mode:
		if _blitz_preview_publish_scheduled:
			return
		_blitz_preview_publish_scheduled = true
		call_deferred("_flush_blitz_preview")
		return
	_emit_preview()


func _flush_blitz_preview() -> void:
	_blitz_preview_publish_scheduled = false
	if _blitz_mode:
		_emit_preview()


func _emit_preview() -> void:
	next_batch_changed.emit(peek_next())
	preview_changed.emit(peek_preview())


func _public_batch(batch: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate: Dictionary in batch:
		result.append(
			{
				"color": int(candidate["color"]),
				"level": int(candidate["level"]),
			}
		)
	return result
