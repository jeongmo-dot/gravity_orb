class_name Spawner
extends Node

signal next_batch_changed(batch: Array[Dictionary])
signal preview_changed(batches: Array)
signal orb_spawned(level: int)

const EFFECT_SEED_SALT: int = 0x25C01A

var seed_used: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _effect_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _preview_batches: Array[Array] = []


func init_rng(seed: int) -> int:
	_preview_batches.clear()
	if seed == 0:
		_rng.randomize()
		while _rng.seed == 0:
			_rng.randomize()
	else:
		_rng.seed = seed
	seed_used = _rng.seed
	_effect_rng.seed = seed_used ^ EFFECT_SEED_SALT
	return seed_used


func next_shake_direction() -> Vector2:
	var angle: float = _effect_rng.randf_range(-PI, PI)
	return Vector2.from_angle(angle)


func spawn_initial(board: Variant, gravity: Vector2i) -> void:
	board.set_gravity(gravity)
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


func sync_next_batch_size(next_turn_index: int = 1) -> void:
	_sync_preview_count(next_turn_index)
	for turn_offset: int in range(_preview_batches.size()):
		var batch: Array = _preview_batches[turn_offset]
		var target_size: int = maxi(
			Config.data.spawn_count_for_turn(next_turn_index + turn_offset),
			1
		)
		while batch.size() < target_size:
			batch.append(_draw_candidate())
		if batch.size() > target_size:
			batch.resize(target_size)
	_publish_preview()


func _draw_candidate() -> Dictionary:
	var level: int = _rng.rand_weighted(Config.data.spawn_level_weights) + 1
	var color: int = _rng.rand_weighted(Config.data.spawn_color_weights)
	var position_t: float = _rng.randf()
	return {"level": level, "color": color, "t": position_t}


func _draw_batch(turn_index: int = 1) -> Array[Dictionary]:
	var batch: Array[Dictionary] = []
	var count: int = maxi(Config.data.spawn_count_for_turn(turn_index), 1)
	for _index: int in range(count):
		batch.append(_draw_candidate())
	return batch


func _sync_preview_count(next_turn_index: int) -> void:
	var target_count: int = maxi(Config.data.preview_turns, 1)
	if _preview_batches.size() > target_count:
		_preview_batches.resize(target_count)
	while _preview_batches.size() < target_count:
		var turn_offset: int = _preview_batches.size()
		_preview_batches.append(_draw_batch(next_turn_index + turn_offset))


func _publish_preview() -> void:
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
