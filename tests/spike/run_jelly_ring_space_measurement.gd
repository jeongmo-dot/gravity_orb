extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const DEFAULT_OUTPUT_DIRECTORY: String = "res://artifacts/measurements/jelly_ring_space"
const TEMP_SAVE_PATH: String = "res://artifacts/measurements/jelly_ring_space_save.tmp.cfg"
const OUTPUT_PREFIX: String = "--ring-space-output-directory="
const POST_REACTION_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.RIGHT,
]
const RING_SETTLED_FRAMES: int = 8
const MAX_EFFECT_FRAMES: int = 300
const MAX_TURN_FRAMES: int = 720
const PIXEL_TOLERANCE: float = 1.0

var _output_directory: String = DEFAULT_OUTPUT_DIRECTORY
var _failed: bool = false
var _geometry: Dictionary = {
	"sample_frames": 0,
	"radius_mismatch_frames": 0,
	"max_radius_mismatch_px": 0.0,
	"radius_undersize_frames": 0,
	"max_radius_undersize_px": 0.0,
	"max_radius_oversize_px": 0.0,
	"contact_pair_samples": 0,
	"gap_frames": 0,
	"max_contact_gap_px": 0.0,
	"overlap_frames": 0,
	"overlap_pair_samples": 0,
	"max_contact_overlap_px": 0.0,
	"max_overlap_duration_msec": 0.0,
}
var _overlap_started_usec: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	_parse_arguments()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_directory))
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.rng_seed = 110
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.JELLY)
	(main.get_node("ScoreManager") as ScoreManager).save_path = TEMP_SAVE_PATH
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = TEMP_SAVE_PATH
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var board: Board3D = main.get_node("Board") as Board3D
	var resolver: CollisionResolver = main.get_node("CollisionResolver") as CollisionResolver
	var director: FeedbackDirector = main.get_node("FeedbackDirector") as FeedbackDirector
	if not await _wait_until_ready(manager):
		_fail("Initial game did not reach WAITING_INPUT")
	manager.set_physics_process(false)
	var reaction_reports: Array[Dictionary] = []
	reaction_reports.append(await _measure_reaction(
		"merge",
		2,
		2,
		OrbTypes.OrbColor.BLUE,
		manager,
		board,
		resolver,
		director
	))
	reaction_reports.append(await _measure_reaction(
		"absorption",
		3,
		2,
		OrbTypes.OrbColor.GREEN,
		manager,
		board,
		resolver,
		director
	))
	board.clear()
	director.clear_effects()
	_seed_contact_grid(board)
	manager.set_physics_process(true)
	var turn_reports: Array[Dictionary] = []
	for turn_index: int in range(POST_REACTION_DIRECTIONS.size()):
		turn_reports.append(await _run_turn(
			turn_index,
			POST_REACTION_DIRECTIONS[turn_index],
			manager,
			board,
			director
		))
		if turn_index == POST_REACTION_DIRECTIONS.size() - 1:
			await _capture("after_turn_5.png")
	var report: Dictionary = {
		"commit": _commit_hash(),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"window_size": DisplayServer.window_get_size(),
		"reactions": reaction_reports,
		"turns": turn_reports,
		"geometry": _geometry,
		"ring_node_count_after": _ring_node_count(director),
		"torus_mesh_count_after": _torus_mesh_count(main),
	}
	_write_report(report)
	print("JELLY_RING_SPACE %s" % JSON.stringify(report))
	main.queue_free()
	await get_tree().process_frame
	_remove_file(TEMP_SAVE_PATH)
	get_tree().quit(1 if _failed else 0)


func _measure_reaction(
	label: String,
	first_level: int,
	second_level: int,
	color_index: int,
	_manager: TurnManager,
	board: Board3D,
	resolver: CollisionResolver,
	director: FeedbackDirector
) -> Dictionary:
	board.clear()
	director.clear_effects()
	var first: Orb3D = board.spawn_orb(color_index, first_level, Vector2(-40.0, 80.0))
	var second: Orb3D = board.spawn_orb(color_index, second_level, Vector2(40.0, 80.0))
	first.disable_physics()
	second.disable_physics()
	var started_usec: int = Time.get_ticks_usec()
	resolver.report_contact(first, second, "ring_space_measurement")
	var applied: int = resolver.flush(1.0 / 120.0)
	if applied != 1:
		_fail("%s expected one reaction, got %d" % [label, applied])
	await get_tree().process_frame
	var visible_frames: int = 0
	var first_visible_usec: int = -1
	var last_visible_usec: int = -1
	var max_visible_rings: int = 0
	var stable_hidden_frames: int = 0
	var captured_visible: bool = false
	for _frame_index: int in range(MAX_EFFECT_FRAMES):
		_sample_geometry(board)
		var visible_rings: int = _visible_ring_count(director)
		max_visible_rings = maxi(max_visible_rings, visible_rings)
		if visible_rings > 0:
			visible_frames += 1
			stable_hidden_frames = 0
			if first_visible_usec < 0:
				first_visible_usec = Time.get_ticks_usec()
			last_visible_usec = Time.get_ticks_usec()
			if not captured_visible:
				await _capture("%s_ring_visible.png" % label)
				captured_visible = true
		else:
			stable_hidden_frames += 1
			if captured_visible and stable_hidden_frames >= RING_SETTLED_FRAMES:
				break
		await get_tree().process_frame
	await _capture("%s_ring_gone.png" % label)
	var lifetime_msec: float = 0.0
	if first_visible_usec >= 0 and last_visible_usec >= first_visible_usec:
		lifetime_msec = float(last_visible_usec - first_visible_usec) / 1000.0
	return {
		"label": label,
		"applied": applied,
		"visible_frames": visible_frames,
		"lifetime_msec": lifetime_msec,
		"first_visible_after_msec": (
			float(first_visible_usec - started_usec) / 1000.0
			if first_visible_usec >= 0
			else -1.0
		),
		"max_visible_rings": max_visible_rings,
		"ring_nodes_in_tree": _ring_node_count(director),
		"torus_meshes_in_tree": _torus_mesh_count(director),
	}


func _run_turn(
	turn_index: int,
	direction: Vector2i,
	manager: TurnManager,
	board: Board3D,
	director: FeedbackDirector
) -> Dictionary:
	if manager.state != TurnManager.State.WAITING_INPUT:
		_fail("Turn %d did not start in WAITING_INPUT" % (turn_index + 1))
		return {}
	manager.on_swipe(direction)
	var sampled_frames: int = 0
	var ring_visible_frames: int = 0
	var reached_non_waiting: bool = false
	for _frame_index: int in range(MAX_TURN_FRAMES):
		await get_tree().process_frame
		sampled_frames += 1
		_sample_geometry(board)
		if _visible_ring_count(director) > 0:
			ring_visible_frames += 1
		if manager.state != TurnManager.State.WAITING_INPUT:
			reached_non_waiting = true
		elif reached_non_waiting:
			break
	if not reached_non_waiting or manager.state != TurnManager.State.WAITING_INPUT:
		_fail("Turn %d did not settle" % (turn_index + 1))
	return {
		"turn": turn_index + 1,
		"direction": OrbTypes.dir_name(direction),
		"sampled_frames": sampled_frames,
		"ring_visible_frames": ring_visible_frames,
		"ring_visible_at_boundary": _visible_ring_count(director),
	}


func _sample_geometry(board: Board3D) -> void:
	var orbs: Array[Orb3D] = board.get_orbs()
	_geometry["sample_frames"] = int(_geometry["sample_frames"]) + 1
	var frame_mismatch: bool = false
	var frame_undersize: bool = false
	var frame_gap: bool = false
	var frame_overlap: bool = false
	var active_overlap_keys: Dictionary = {}
	var sample_usec: int = Time.get_ticks_usec()
	for orb: Orb3D in orbs:
		if not is_instance_valid(orb) or orb.consumed:
			continue
		var shape: SphereShape3D = orb.shape_resource()
		var mesh: SphereMesh = orb._mesh.mesh as SphereMesh
		if shape == null or mesh == null:
			continue
		var physical_radius_px: float = shape.radius * Orb3D.PIXELS_PER_METER
		var drawn_x_px: float = mesh.radius * absf(orb._mesh.scale.x) * Orb3D.PIXELS_PER_METER
		var drawn_y_px: float = mesh.radius * absf(orb._mesh.scale.y) * Orb3D.PIXELS_PER_METER
		var mismatch_px: float = maxf(
			absf(physical_radius_px - drawn_x_px),
			absf(physical_radius_px - drawn_y_px)
		)
		_geometry["max_radius_mismatch_px"] = maxf(
			float(_geometry["max_radius_mismatch_px"]),
			mismatch_px
		)
		var undersize_px: float = maxf(
			physical_radius_px - minf(drawn_x_px, drawn_y_px),
			0.0
		)
		var oversize_px: float = maxf(
			maxf(drawn_x_px, drawn_y_px) - physical_radius_px,
			0.0
		)
		_geometry["max_radius_undersize_px"] = maxf(
			float(_geometry["max_radius_undersize_px"]),
			undersize_px
		)
		_geometry["max_radius_oversize_px"] = maxf(
			float(_geometry["max_radius_oversize_px"]),
			oversize_px
		)
		if mismatch_px > PIXEL_TOLERANCE:
			frame_mismatch = true
		if undersize_px > PIXEL_TOLERANCE:
			frame_undersize = true
	for first_index: int in range(orbs.size()):
		var first: Orb3D = orbs[first_index]
		if not is_instance_valid(first) or first.consumed:
			continue
		for second_index: int in range(first_index + 1, orbs.size()):
			var second: Orb3D = orbs[second_index]
			if not is_instance_valid(second) or second.consumed:
				continue
			var first_shape: SphereShape3D = first.shape_resource()
			var second_shape: SphereShape3D = second.shape_resource()
			if first_shape == null or second_shape == null:
				continue
			var first_center: Vector2 = _mesh_center_px(first)
			var second_center: Vector2 = _mesh_center_px(second)
			var delta: Vector2 = second_center - first_center
			var physical_sum_px: float = (
				first_shape.radius + second_shape.radius
			) * Orb3D.PIXELS_PER_METER
			if delta.length() > physical_sum_px:
				continue
			_geometry["contact_pair_samples"] = int(_geometry["contact_pair_samples"]) + 1
			var direction: Vector2 = delta.normalized() if not delta.is_zero_approx() else Vector2.RIGHT
			var drawn_sum_px: float = (
				_drawn_radius_in_direction(first, direction)
				+ _drawn_radius_in_direction(second, -direction)
			)
			var gap_px: float = maxf(delta.length() - drawn_sum_px, 0.0)
			_geometry["max_contact_gap_px"] = maxf(
				float(_geometry["max_contact_gap_px"]),
				gap_px
			)
			if gap_px > PIXEL_TOLERANCE:
				frame_gap = true
			var overlap_px: float = maxf(drawn_sum_px - delta.length(), 0.0)
			_geometry["max_contact_overlap_px"] = maxf(
				float(_geometry["max_contact_overlap_px"]),
				overlap_px
			)
			if overlap_px > PIXEL_TOLERANCE:
				frame_overlap = true
				_geometry["overlap_pair_samples"] = int(
					_geometry["overlap_pair_samples"]
				) + 1
				var pair_key: String = _pair_key(first, second)
				active_overlap_keys[pair_key] = true
				if not _overlap_started_usec.has(pair_key):
					_overlap_started_usec[pair_key] = sample_usec
				var duration_msec: float = float(
					sample_usec - int(_overlap_started_usec[pair_key])
				) / 1000.0
				_geometry["max_overlap_duration_msec"] = maxf(
					float(_geometry["max_overlap_duration_msec"]),
					duration_msec
				)
	for pair_key: Variant in _overlap_started_usec.keys():
		if not active_overlap_keys.has(pair_key):
			_overlap_started_usec.erase(pair_key)
	if frame_mismatch:
		_geometry["radius_mismatch_frames"] = int(_geometry["radius_mismatch_frames"]) + 1
	if frame_undersize:
		_geometry["radius_undersize_frames"] = int(_geometry["radius_undersize_frames"]) + 1
	if frame_gap:
		_geometry["gap_frames"] = int(_geometry["gap_frames"]) + 1
	if frame_overlap:
		_geometry["overlap_frames"] = int(_geometry["overlap_frames"]) + 1


func _pair_key(first: Orb3D, second: Orb3D) -> String:
	var first_id: int = first.get_instance_id()
	var second_id: int = second.get_instance_id()
	return "%d:%d" % [mini(first_id, second_id), maxi(first_id, second_id)]


func _drawn_radius_in_direction(orb: Orb3D, world_direction: Vector2) -> float:
	var mesh: SphereMesh = orb._mesh.mesh as SphereMesh
	if mesh == null:
		return 0.0
	var local_angle: float = world_direction.angle() - orb._mesh.global_rotation.z
	var scale_x: float = maxf(absf(orb._mesh.scale.x), 0.000001)
	var scale_y: float = maxf(absf(orb._mesh.scale.y), 0.000001)
	var denominator: float = sqrt(
		pow(cos(local_angle) / scale_x, 2.0)
		+ pow(sin(local_angle) / scale_y, 2.0)
	)
	return mesh.radius * Orb3D.PIXELS_PER_METER / maxf(denominator, 0.000001)


func _mesh_center_px(orb: Orb3D) -> Vector2:
	return Vector2(
		orb._mesh.global_position.x,
		orb._mesh.global_position.y
	) * Orb3D.PIXELS_PER_METER


func _seed_contact_grid(board: Board3D) -> void:
	for row: int in range(4):
		for column: int in range(5):
			var orb: Orb3D = board.spawn_orb(
				(row + column) % JellyOrbArt.PALETTE.size(),
				2,
				Vector2(-158.0 + float(column) * 79.0, -118.5 + float(row) * 79.0)
			)
			orb.set_jelly_mass(2.0, Config.data)


func _visible_ring_count(director: FeedbackDirector) -> int:
	var count: int = 0
	for node: Node in director.find_children("*", "", true, false):
		var ring_named: bool = "ring" in String(node.name).to_lower()
		var torus: bool = (
			node is MeshInstance3D
			and (node as MeshInstance3D).mesh != null
			and (node as MeshInstance3D).mesh.get_class() == "Torus" + "Mesh"
		)
		if not ring_named and not torus:
			continue
		if node is Node3D and (node as Node3D).is_visible_in_tree():
			count += 1
		elif node is CanvasItem and (node as CanvasItem).is_visible_in_tree():
			count += 1
	return count


func _ring_node_count(root: Node) -> int:
	var count: int = 0
	for node: Node in root.find_children("*", "", true, false):
		if "ring" in String(node.name).to_lower():
			count += 1
	return count


func _torus_mesh_count(root: Node) -> int:
	var count: int = 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		if (
			node is MeshInstance3D
			and (node as MeshInstance3D).mesh != null
			and (node as MeshInstance3D).mesh.get_class() == "Torus" + "Mesh"
		):
			count += 1
	return count


func _wait_until_ready(manager: TurnManager) -> bool:
	for _frame_index: int in range(720):
		if manager.state == TurnManager.State.WAITING_INPUT:
			return true
		if manager.state == TurnManager.State.GAME_OVER:
			return false
		await get_tree().process_frame
	return false


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _output_directory.path_join(file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		_fail("Could not save %s: %s" % [path, error_string(error)])
	else:
		print("JELLY_RING_SPACE_CAPTURE file=%s size=%dx%d" % [
			path, image.get_width(), image.get_height()
		])


func _write_report(report: Dictionary) -> void:
	var path: String = _output_directory.path_join("report.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write %s" % path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()


func _commit_hash() -> String:
	var output: Array = []
	var exit_code: int = OS.execute("git", PackedStringArray(["rev-parse", "HEAD"]), output, true)
	return str(output[0]).strip_edges() if exit_code == 0 and not output.is_empty() else "unknown"


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(OUTPUT_PREFIX):
			_output_directory = argument.trim_prefix(OUTPUT_PREFIX)


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
