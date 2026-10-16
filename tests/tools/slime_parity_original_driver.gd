extends SceneTree

const DT: float = 1.0 / 60.0
const OUTPUT_PREFIX: String = "--output="

var _game_script: Script = preload("res://parity_original_game.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path: String = _argument_value(OUTPUT_PREFIX)
	if output_path.is_empty():
		push_error("Missing --output=<absolute path>")
		quit(2)
		return
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		push_error("Cannot open parity output: %s" % output_path)
		quit(2)
		return
	for scenario: int in range(1, 7):
		var game: Variant = _game_script.new()
		root.add_child(game)
		game.set_physics_process(false)
		game.set_process(false)
		_reset_game(game, 8062 + scenario)
		_setup_scenario(game, scenario)
		_write_snapshot(output, scenario, 0, game)
		var local_tick: int = 0
		while bool(game.moving) and local_tick < 180:
			game._physics_process(DT)
			local_tick += 1
			_write_snapshot(output, scenario, local_tick, game)
		output.store_line(JSON.stringify({"scenario": scenario, "end_tick": local_tick}))
		game.free()
	output.close()
	quit(0)


func _reset_game(game: Variant, seed_value: int) -> void:
	game.slimes.clear()
	game.next_slimes.clear()
	game.intro_queue.clear()
	game.merge_ghosts.clear()
	game.merge_rings.clear()
	game.merge_particles.clear()
	game.score_popups.clear()
	game.color_bag.clear()
	game.completed_colors.clear()
	game.rng.seed = seed_value
	game.gravity_dir = Vector2.DOWN
	game.turn = 1
	game.score = 0
	game.turn_chain = 0
	game.run_best_chain = 0
	game.active_color_count = 3
	game.pending_unlock_color = -1
	game.unlock_grace_waves = 0
	game.moving = false
	game.game_over = false
	game.final_move_pending = false
	game.final_move_active = false
	game.settle_time = 0.0
	game.simulation_time = 0.0
	game.intro_elapsed = 0.0
	game.collision_sound_cooldown = 0.0


func _setup_scenario(game: Variant, scenario: int) -> void:
	match scenario:
		1:
			_add_fixed_twelve(game)
			_start_without_spawn(game, Vector2.DOWN)
		2:
			_add_fixed_twelve(game)
			_start_without_spawn(game, Vector2.LEFT)
		3:
			game._add_slime(Vector2(260.0, 420.0), 0, 1)
			game._add_slime(Vector2(323.0, 420.0), 0, 1)
			game._add_slime(Vector2(386.0, 420.0), 0, 1)
			_start_without_spawn(game, Vector2.DOWN)
		4:
			var center := Vector2(320.0, 520.0)
			game._add_slime(center - Vector2(112.0, 0.0), 6, 0, Vector2.ZERO, 64)
			game._add_slime(center + Vector2(112.0, 0.0), 6, 4, Vector2.ZERO, 64)
			for index: int in range(6):
				var angle: float = TAU * float(index) / 6.0
				game._add_slime(center + Vector2.from_angle(angle) * 140.0, 0, index % 3)
			_start_without_spawn(game, Vector2.DOWN)
		5:
			for index: int in range(4):
				var velocity := Vector2(1200.0, -80.0) if index == 0 else Vector2.ZERO
				game._add_slime(Vector2(560.0, 310.0 + float(index) * 62.0), 0, index, velocity)
			_start_without_spawn(game, Vector2.DOWN)
		6:
			var radius: float = float(game._radius_for(0))
			var entry: Vector2 = game._entry_position_for(Vector2.DOWN, radius)
			game._add_slime(entry, 0, 0)
			game.next_slimes.clear()
			game.next_slimes.append({"level": 0, "color_id": 0})
			game.next_slimes.append({"level": 1, "color_id": 1})
			game.next_slimes.append({"level": 0, "color_id": 2})
			game._start_turn(Vector2.DOWN)


func _add_fixed_twelve(game: Variant) -> void:
	for index: int in range(12):
		var column: int = index % 4
		var row: int = index / 4
		game._add_slime(
			Vector2(120.0 + float(column) * 125.0, 300.0 + float(row) * 130.0),
			index % 3,
			index % 3,
			Vector2(float(column - 2) * 18.0, float(row) * -12.0)
		)


func _start_without_spawn(game: Variant, direction: Vector2) -> void:
	game.next_slimes.clear()
	game._start_turn(direction)


func _write_snapshot(output: FileAccess, scenario: int, local_tick: int, game: Variant) -> void:
	var bodies: Array[Variant] = []
	for slime: Dictionary in game.slimes:
		bodies.append([
			float(slime.position.x),
			float(slime.position.y),
			float(slime.velocity.x),
			float(slime.velocity.y),
			int(slime.mass),
			int(slime.level),
			int(slime.color_id),
		])
	output.store_line(JSON.stringify({
		"scenario": scenario,
		"tick": local_tick,
		"bodies": bodies,
		"score": int(game.score),
		"chain": int(game.turn_chain),
		"moving": bool(game.moving),
	}))


func _argument_value(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
