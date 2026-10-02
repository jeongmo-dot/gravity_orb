class_name Spawner3D
extends Node

signal next_batch_changed(batch: Array[Dictionary])
signal orb_spawned(level: int)

var seed_used: int = 0

var _rng_logic: Spawner = Spawner.new()
var _next_batch: Array[Dictionary] = []


func _ready() -> void:
	if _rng_logic.get_parent() == null:
		add_child(_rng_logic)


func init_rng(seed: int) -> int:
	_next_batch.clear()
	seed_used = _rng_logic.init_rng(seed)
	return seed_used


func spawn_initial(board: Board3D, gravity: Vector2i) -> void:
	board.set_gravity(gravity)
	var count: int = Config.data.initial_orb_count
	var half: float = board.half_size()
	for index: int in range(count):
		var candidate: Dictionary = _draw_candidate()
		var level: int = int(candidate["level"])
		var radius: float = Config.data.radius_for_level(level)
		var fraction: float = float(index + 1) / float(count + 1)
		var spawn_position: Vector2 = Vector2(
			lerpf(-half, half, fraction),
			half - radius - Config.data.spawn_margin
		)
		board.spawn_orb(int(candidate["color"]), level, spawn_position)
		orb_spawned.emit(level)
	_draw_and_publish_next_batch(1)


func try_spawn(
	board: Board3D,
	gravity: Vector2i,
	turn_index: int = 1
) -> Array[Orb3D]:
	if _next_batch.is_empty():
		_draw_and_publish_next_batch(turn_index)

	var spawned: Array[Orb3D] = []
	var placed: Array[Dictionary] = []
	for candidate: Dictionary in _next_batch:
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
		var spawn_position: Vector2 = (
			slot["position"] as Vector2
			if has_free_slot
			else preferred_position
		)
		var orb: Orb3D = board.spawn_orb(
			int(candidate["color"]),
			level,
			spawn_position
		)
		if has_free_slot:
			placed.append({"position": spawn_position, "radius": radius})
		else:
			orb.enter_entrance_wait(preferred_position, gravity)
		spawned.append(orb)
		orb_spawned.emit(level)
	_draw_and_publish_next_batch(turn_index + 1)
	return spawned


func peek_next() -> Array[Dictionary]:
	return _public_batch(_next_batch)


func sync_next_batch_size(next_turn_index: int = 1) -> void:
	var target_size: int = maxi(Config.data.spawn_count_for_turn(next_turn_index), 1)
	while _next_batch.size() < target_size:
		_next_batch.append(_draw_candidate())
	if _next_batch.size() > target_size:
		_next_batch.resize(target_size)
	next_batch_changed.emit(peek_next())


func _draw_candidate() -> Dictionary:
	var value: Variant = _rng_logic.call("_draw_candidate")
	return value as Dictionary


func _draw_batch(turn_index: int) -> Array[Dictionary]:
	var batch: Array[Dictionary] = []
	var count: int = maxi(Config.data.spawn_count_for_turn(turn_index), 1)
	for _index: int in range(count):
		batch.append(_draw_candidate())
	return batch


func _draw_and_publish_next_batch(turn_index: int) -> void:
	_next_batch = _draw_batch(turn_index)
	next_batch_changed.emit(peek_next())


func _public_batch(batch: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate: Dictionary in batch:
		result.append(
			{
				"color": int(candidate["color"]),
				"level": int(candidate["level"]),
			}
		)
	return result
