extends Node

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const SAMPLE_SEED: int = 101
const SAMPLE_TURNS: int = 120
const WAIT_TIMEOUT_SECONDS: float = 3.5
const OUTPUT_PATH: String = "res://artifacts/physics2d_profile_seed101_240hz.json"
const DIRECTION_PATTERN: Array[Vector2i] = [
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.RIGHT,
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.physics_ticks_per_second = 240
	InputRouter.set_locked(false)
	var fixture_root: Node = Node.new()
	fixture_root.name = "Physics2DProfileFixture"
	var board: Board = BOARD_SCENE.instantiate() as Board
	board.name = "Board"
	board.unique_name_in_owner = true
	board.diagnostic_warnings_enabled = false
	fixture_root.add_child(board)
	board.owner = fixture_root
	var resolver: CollisionResolver = RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	fixture_root.add_child(resolver)
	resolver.owner = fixture_root
	var spawner: Spawner = SPAWNER_SCRIPT.new() as Spawner
	spawner.name = "Spawner"
	spawner.unique_name_in_owner = true
	fixture_root.add_child(spawner)
	spawner.owner = fixture_root
	var manager: TurnManager = TURN_MANAGER_SCRIPT.new() as TurnManager
	manager.name = "TurnManager"
	fixture_root.add_child(manager)
	manager.owner = fixture_root
	get_tree().root.add_child(fixture_root)
	await get_tree().process_frame
	spawner.init_rng(SAMPLE_SEED)
	spawner.spawn_initial(board, Vector2i.DOWN)
	manager.start_game()
	await _wait_for_ready(manager)

	var step_ms: Array[float] = []
	var max_penetration: float = 0.0
	var departures: int = 0
	var divergences: int = 0
	var completed_turns: int = 0
	for turn_offset: int in range(SAMPLE_TURNS):
		manager.on_swipe(DIRECTION_PATTERN[turn_offset % DIRECTION_PATTERN.size()])
		var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
		for _frame: int in range(max_frames):
			var started_usec: int = Time.get_ticks_usec()
			await get_tree().physics_frame
			step_ms.append(float(Time.get_ticks_usec() - started_usec) / 1000.0)
			for orb: Orb in board.get_orbs():
				var finite: bool = orb.position.is_finite() and orb.linear_velocity.is_finite()
				var extent: float = maxf(absf(orb.position.x), absf(orb.position.y)) if finite else INF
				if finite:
					max_penetration = maxf(
						max_penetration,
						maxf(extent + orb.get_radius() - board.half_size(), 0.0)
					)
				if extent - orb.get_radius() > board.half_size():
					departures += 1
				if not finite or orb.linear_velocity.length() > 5000.0:
					divergences += 1
			if manager.state == TurnManager.State.WAITING_INPUT or manager.state == TurnManager.State.GAME_OVER:
				break
		completed_turns = turn_offset + 1
		if manager.state == TurnManager.State.GAME_OVER or divergences > 0:
			break

	var report: Dictionary = {
		"seed": SAMPLE_SEED,
		"requested_turns": SAMPLE_TURNS,
		"completed_turns": completed_turns,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"physics_step_wall_ms_mean": _mean(step_ms),
		"physics_step_wall_ms_p50": _percentile(step_ms, 0.5),
		"physics_step_wall_ms_p95": _percentile(step_ms, 0.95),
		"max_wall_penetration_px": max_penetration,
		"departures": departures,
		"divergences": divergences,
		"game_over": manager.state == TurnManager.State.GAME_OVER,
		"final_orb_count": board.get_orbs().size(),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("PHYSICS2D_PROFILE %s" % JSON.stringify(report))
	fixture_root.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if file != null else 1)


func _wait_for_ready(manager: TurnManager) -> void:
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		if manager.state == TurnManager.State.WAITING_INPUT:
			return
		await get_tree().physics_frame


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var index: int = clampi(roundi(float(sorted.size() - 1) * ratio), 0, sorted.size() - 1)
	return sorted[index]
