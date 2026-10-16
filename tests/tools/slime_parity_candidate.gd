extends SceneTree

const CONFIG: SlimeConfig = preload("res://config/slime_config.tres")
const DT: float = 1.0 / 60.0
const OUTPUT_PREFIX: String = "--output="


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
		var sim := SlimeSim.new(CONFIG, 8062 + scenario, false, false)
		_setup_scenario(sim, scenario)
		_write_snapshot(output, scenario, 0, sim)
		var local_tick: int = 0
		while sim.moving and local_tick < 180:
			sim.step(DT)
			local_tick += 1
			_write_snapshot(output, scenario, local_tick, sim)
		output.store_line(JSON.stringify({"scenario": scenario, "end_tick": local_tick}))
	output.close()
	quit(0)


func _setup_scenario(sim: SlimeSim, scenario: int) -> void:
	sim.turn = 1
	match scenario:
		1:
			_add_fixed_twelve(sim)
			_start_without_spawn(sim, Vector2i.DOWN)
		2:
			_add_fixed_twelve(sim)
			_start_without_spawn(sim, Vector2i.LEFT)
		3:
			sim.add_slime(Vector2(260.0, 420.0), 0, 1)
			sim.add_slime(Vector2(323.0, 420.0), 0, 1)
			sim.add_slime(Vector2(386.0, 420.0), 0, 1)
			_start_without_spawn(sim, Vector2i.DOWN)
		4:
			var center := Vector2(320.0, 520.0)
			sim.add_slime(center - Vector2(112.0, 0.0), 6, 0, Vector2.ZERO, 64)
			sim.add_slime(center + Vector2(112.0, 0.0), 6, 4, Vector2.ZERO, 64)
			for index: int in range(6):
				var angle: float = TAU * float(index) / 6.0
				sim.add_slime(center + Vector2.from_angle(angle) * 140.0, 0, index % 3)
			_start_without_spawn(sim, Vector2i.DOWN)
		5:
			for index: int in range(4):
				var velocity := Vector2(1200.0, -80.0) if index == 0 else Vector2.ZERO
				sim.add_slime(Vector2(560.0, 310.0 + float(index) * 62.0), 0, index, velocity)
			_start_without_spawn(sim, Vector2i.DOWN)
		6:
			var radius: float = sim.radius_for_level(0)
			var entry: Vector2 = sim.entry_position_for(Vector2i.DOWN, radius)
			sim.add_slime(entry, 0, 0)
			sim.set_next_slimes([
				{"level": 0, "color": 0},
				{"level": 1, "color": 1},
				{"level": 0, "color": 2},
			])
			sim.start_turn(Vector2i.DOWN)


func _add_fixed_twelve(sim: SlimeSim) -> void:
	for index: int in range(12):
		var column: int = index % 4
		var row: int = index / 4
		sim.add_slime(
			Vector2(120.0 + float(column) * 125.0, 300.0 + float(row) * 130.0),
			index % 3,
			index % 3,
			Vector2(float(column - 2) * 18.0, float(row) * -12.0)
		)


func _start_without_spawn(sim: SlimeSim, direction: Vector2i) -> void:
	sim.next_slimes.clear()
	sim.start_turn(direction)


func _write_snapshot(output: FileAccess, scenario: int, local_tick: int, sim: SlimeSim) -> void:
	var bodies: Array[Variant] = []
	for slime: SlimeSim.SlimeBody in sim.slimes:
		bodies.append([
			slime.position.x,
			slime.position.y,
			slime.velocity.x,
			slime.velocity.y,
			slime.mass,
			slime.level,
			slime.color_index,
		])
	output.store_line(JSON.stringify({
		"scenario": scenario,
		"tick": local_tick,
		"bodies": bodies,
		"score": sim.score,
		"chain": sim.chain,
		"moving": sim.moving,
	}))


func _argument_value(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
