class_name Spawner
extends Node

signal next_changed(color: int, level: int)

var seed_used: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next: Dictionary = {}


func init_rng(seed: int) -> int:
	_next.clear()
	if seed == 0:
		_rng.randomize()
		while _rng.seed == 0:
			_rng.randomize()
	else:
		_rng.seed = seed
	seed_used = _rng.seed
	return seed_used


func spawn_initial(board: Board, gravity: Vector2i) -> void:
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
		var orb: Orb = board.spawn_orb(int(candidate["color"]), level, position)
		orb.exit_ghost_state()
	_draw_and_publish_next()


func try_spawn(board: Board, gravity: Vector2i) -> Orb:
	if _next.is_empty():
		_draw_and_publish_next()

	var candidate: Dictionary = _next
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
	var position: Vector2 = (
		line["origin"] as Vector2
		+ (line["axis"] as Vector2) * offset
	)
	var orb: Orb = board.spawn_orb(int(candidate["color"]), level, position)
	_draw_and_publish_next()
	return orb


func peek_next() -> Dictionary:
	if _next.is_empty():
		return {}
	return {"color": int(_next["color"]), "level": int(_next["level"])}


func _draw_candidate() -> Dictionary:
	var level: int = _rng.rand_weighted(Config.data.spawn_level_weights) + 1
	var color: int = _rng.rand_weighted(Config.data.spawn_color_weights)
	var position_t: float = _rng.randf()
	return {"level": level, "color": color, "t": position_t}


func _draw_and_publish_next() -> void:
	_next = _draw_candidate()
	next_changed.emit(int(_next["color"]), int(_next["level"]))
