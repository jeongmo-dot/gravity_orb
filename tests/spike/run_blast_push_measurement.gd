extends Node

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const OUTPUT_PATH: String = "res://artifacts/measurements/blast_push_k0_k4_lift.json"
const TICKS_PER_SECOND: int = 120
const SAMPLE_FRAMES: Dictionary = {12: "0.1", 24: "0.2", 48: "0.4", 96: "0.8"}
const PROFILES: Array[Dictionary] = [
	{"name": "K0", "common": false, "speed": 900.0, "far": 0.4, "pause": 0.0, "lift": 0.0},
	{"name": "K1", "common": true, "speed": 900.0, "far": 0.4, "pause": 0.0, "lift": 0.0},
	{"name": "K2", "common": true, "speed": 1350.0, "far": 0.5, "pause": 0.0, "lift": 0.0},
	{"name": "K3", "common": true, "speed": 900.0, "far": 0.4, "pause": 0.2, "lift": 0.0},
	{"name": "K4", "common": true, "speed": 1350.0, "far": 0.5, "pause": 0.2, "lift": 0.0},
]
const LIFT_PROFILES: Array[Dictionary] = [
	{"name": "lift_0", "common": true, "speed": 1350.0, "far": 0.5, "pause": 0.2, "lift": 0.0},
	{"name": "lift_600", "common": true, "speed": 1350.0, "far": 0.5, "pause": 0.2, "lift": 600.0},
	{"name": "lift_900", "common": true, "speed": 1350.0, "far": 0.5, "pause": 0.2, "lift": 900.0},
	{"name": "lift_1200", "common": true, "speed": 1350.0, "far": 0.5, "pause": 0.2, "lift": 1200.0},
]

var _output_path: String = OUTPUT_PATH


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output_path = argument.trim_prefix("--output=")
	Engine.physics_ticks_per_second = TICKS_PER_SECOND
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.sfx_enabled = false
	var report: Dictionary = {
		"engine": Engine.get_version_info(),
		"physics_ticks_per_second": TICKS_PER_SECOND,
		"profiles": {},
		"lift_profiles": {},
	}
	for profile: Dictionary in PROFILES:
		_apply_profile(profile)
		var scenes: Dictionary = {}
		scenes["center_big_blast"] = await _measure_scene("big", -1)
		for color: int in range(6):
			scenes["center_tap_color_%d" % color] = await _measure_scene("tap", color)
		scenes["yellow_floor_pile_tap"] = await _measure_scene(
			"floor_tap",
			OrbTypes.OrbColor.YELLOW
		)
		(report["profiles"] as Dictionary)[str(profile["name"])] = {
			"values": profile.duplicate(true),
			"scenes": scenes,
		}
	for profile: Dictionary in LIFT_PROFILES:
		_apply_profile(profile)
		(report["lift_profiles"] as Dictionary)[str(profile["name"])] = {
			"values": profile.duplicate(true),
			"scenes": {
				"center_tap_yellow": await _measure_scene(
					"tap", OrbTypes.OrbColor.YELLOW
				),
				"yellow_floor_pile_tap": await _measure_scene(
					"floor_tap", OrbTypes.OrbColor.YELLOW
				),
			},
		}
	_restore_config(snapshot)
	_write_report(report)
	print("BLAST_PUSH_MEASUREMENT %s" % JSON.stringify(report))
	get_tree().quit(0)


func _measure_scene(kind: String, tap_color: int) -> Dictionary:
	var fixture: Dictionary = await _create_fixture()
	var root_node: Node3D = fixture["root"] as Node3D
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	resolver.proximity_reaction_scan_enabled = false
	var origin: Vector2 = Vector2.ZERO
	var targets: Array[Orb3D] = (
		_spawn_floor_pile(board, tap_color)
		if kind == "floor_tap"
		else _spawn_center_field(board, tap_color, 1 if kind == "big" else 3)
	)
	if kind == "floor_tap":
		origin = Vector2(0.0, board.half_size() - 52.0 - 8.0 * 84.0)
	var initial: Dictionary = {}
	for orb: Orb3D in targets:
		initial[orb.stable_spawn_id] = {
			"position": orb.position,
			"radius": orb.get_current_radius(),
		}
	var reactions: Array[Dictionary] = []
	resolver.reaction_applied.connect(
		func(reaction: Dictionary) -> void: reactions.append(reaction.duplicate(false))
	)
	var trigger_rows: Array[Dictionary] = []
	if kind == "big":
		var first: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 8, Vector2(-4.0, 0.0))
		var second: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 8, Vector2(4.0, 0.0))
		resolver.report_contact(first, second, "blast_push_measurement")
		resolver.flush()
		if not reactions.is_empty():
			trigger_rows = reactions[-1].get("blast_targets", []) as Array[Dictionary]
	else:
		var source: Orb3D = board.spawn_orb(tap_color, 10, origin)
		resolver.apply_jelly_tap_blast(source)
		if not reactions.is_empty():
			trigger_rows = reactions[-1].get("blast_targets", []) as Array[Dictionary]
	var initial_reaction_count: int = reactions.size()
	var pushed_ids: Dictionary = {}
	for row: Dictionary in trigger_rows:
		if not (row["velocity_change"] as Vector2).is_zero_approx():
			pushed_ids[int(row["stable_spawn_id"])] = true
	var samples: Dictionary = {}
	var maximum_speed: float = 0.0
	var maximum_penetration: float = 0.0
	var departed_ids: Dictionary = {}
	for frame: int in range(1, SAMPLE_FRAMES.keys().max() + 1):
		await get_tree().physics_frame
		resolver.flush(1.0 / float(TICKS_PER_SECOND))
		for orb: Orb3D in board.get_orbs():
			maximum_speed = maxf(maximum_speed, orb.linear_velocity.length())
			maximum_penetration = maxf(
				maximum_penetration,
				_wall_penetration(board, orb)
			)
			if _is_departed(board, orb):
				departed_ids[orb.stable_spawn_id] = true
		if SAMPLE_FRAMES.has(frame):
			samples[str(SAMPLE_FRAMES[frame])] = _displacement_sample(
				board,
				initial,
				origin,
				pushed_ids,
				board.actual_gravity_direction()
			)
	var followup_merges: int = 0
	var followup_blasts: int = 0
	for index: int in range(initial_reaction_count, reactions.size()):
		var reaction_type: int = int(reactions[index]["type"])
		if reaction_type == int(ReactionRules.Type.MERGE):
			followup_merges += 1
		elif reaction_type == int(ReactionRules.Type.BLAST):
			followup_blasts += 1
	var result: Dictionary = {
		"initial_target_count": initial.size(),
		"pushed_target_count": pushed_ids.size(),
		"samples": samples,
		"max_speed_px_s": maximum_speed,
		"max_wall_penetration_px": maximum_penetration,
		"departures": departed_ids.size(),
		"followup_within_0_8_seconds": {
			"merges": followup_merges,
			"blasts": followup_blasts,
		},
	}
	root_node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return result


func _spawn_center_field(
	board: Board3D,
	excluded_color: int,
	level: int
) -> Array[Orb3D]:
	var result: Array[Orb3D] = []
	for row: int in range(8):
		for column: int in range(10):
			var position: Vector2 = Vector2(
				(float(column) - 4.5) * 84.0,
				(float(row) - 3.5) * 84.0
			)
			result.append(
				board.spawn_orb(_field_color(column, row, excluded_color), level, position)
			)
	return result


func _spawn_floor_pile(board: Board3D, excluded_color: int) -> Array[Orb3D]:
	var result: Array[Orb3D] = []
	var floor_y: float = board.half_size() - 52.0
	for row: int in range(8):
		for column: int in range(10):
			var position: Vector2 = Vector2(
				(float(column) - 4.5) * 84.0 + (42.0 if row % 2 == 1 else 0.0),
				floor_y - float(row) * 84.0
			)
			result.append(
				board.spawn_orb(_field_color(column, row, excluded_color), 3, position)
			)
	return result


func _field_color(column: int, row: int, excluded_color: int) -> int:
	var available: Array[int] = []
	for color: int in range(6):
		if color != excluded_color:
			available.append(color)
	return available[(column + row * 2) % available.size()]


func _displacement_sample(
	board: Board3D,
	initial: Dictionary,
	origin: Vector2,
	pushed_ids: Dictionary,
	gravity_direction: Vector2
) -> Dictionary:
	var outward: Array[float] = []
	var opposite_gravity: Array[float] = []
	var outward_fifty: int = 0
	var opposite_gravity_fifty: int = 0
	var opposite_direction: Vector2 = -gravity_direction.normalized()
	for orb: Orb3D in board.get_orbs():
		if not initial.has(orb.stable_spawn_id) or not pushed_ids.has(orb.stable_spawn_id):
			continue
		var start: Vector2 = initial[orb.stable_spawn_id]["position"] as Vector2
		var radial: Vector2 = start - origin
		var direction: Vector2 = Vector2.RIGHT if radial.is_zero_approx() else radial.normalized()
		var delta: Vector2 = orb.position - start
		var outward_displacement: float = delta.dot(direction)
		var lift_displacement: float = delta.dot(opposite_direction)
		outward.append(outward_displacement)
		opposite_gravity.append(lift_displacement)
		if outward_displacement >= 50.0:
			outward_fifty += 1
		if lift_displacement >= 50.0:
			opposite_gravity_fifty += 1
	outward.sort()
	opposite_gravity.sort()
	return {
		"surviving_targets": outward.size(),
		"outward_median_px": _percentile(outward, 0.5),
		"outward_p90_px": _percentile(outward, 0.9),
		"at_least_50_px_ratio": (
			float(outward_fifty) / float(outward.size()) if not outward.is_empty() else 0.0
		),
		"opposite_gravity_median_px": _percentile(opposite_gravity, 0.5),
		"opposite_gravity_p90_px": _percentile(opposite_gravity, 0.9),
		"opposite_gravity_at_least_50_px_ratio": (
			float(opposite_gravity_fifty) / float(opposite_gravity.size())
			if not opposite_gravity.is_empty()
			else 0.0
		),
	}


func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var index: int = clampi(ceili(ratio * float(values.size())) - 1, 0, values.size() - 1)
	return values[index]


func _wall_penetration(board: Board3D, orb: Orb3D) -> float:
	var radius: float = orb.get_current_radius()
	var half: float = board.half_size()
	return maxf(
		maxf(absf(orb.position.x) + radius - half, 0.0),
		maxf(absf(orb.position.y) + radius - half, 0.0)
	)


func _is_departed(board: Board3D, orb: Orb3D) -> bool:
	var limit: float = board.half_size() + orb.get_current_radius()
	return absf(orb.position.x) > limit or absf(orb.position.y) > limit


func _create_fixture() -> Dictionary:
	var root_node: Node3D = Node3D.new()
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	root_node.add_child(board)
	board.owner = root_node
	var resolver: CollisionResolver = RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	root_node.add_child(resolver)
	resolver.owner = root_node
	get_tree().root.add_child(root_node)
	await get_tree().process_frame
	return {"root": root_node, "board": board, "resolver": resolver}


func _snapshot_config() -> Dictionary:
	return {
		"game_mode": Config.data.game_mode,
		"sfx_enabled": Config.data.sfx_enabled,
		"common": Config.data.jelly_tap_common_push,
		"speed": Config.data.blast_speed,
		"far": Config.data.blast_far_factor,
		"pause": Config.data.blast_gravity_pause_time,
		"lift": Config.data.jelly_tap_lift_speed,
	}


func _restore_config(snapshot: Dictionary) -> void:
	Config.data.game_mode = int(snapshot["game_mode"]) as GameConfig.GameMode
	Config.data.sfx_enabled = bool(snapshot["sfx_enabled"])
	Config.data.jelly_tap_common_push = bool(snapshot["common"])
	Config.data.blast_speed = float(snapshot["speed"])
	Config.data.blast_far_factor = float(snapshot["far"])
	Config.data.blast_gravity_pause_time = float(snapshot["pause"])
	Config.data.jelly_tap_lift_speed = float(snapshot["lift"])


func _apply_profile(profile: Dictionary) -> void:
	Config.data.jelly_tap_common_push = bool(profile["common"])
	Config.data.blast_speed = float(profile["speed"])
	Config.data.blast_far_factor = float(profile["far"])
	Config.data.blast_gravity_pause_time = float(profile["pause"])
	Config.data.jelly_tap_lift_speed = float(profile["lift"])


func _write_report(report: Dictionary) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write blast push report: %s" % _output_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
