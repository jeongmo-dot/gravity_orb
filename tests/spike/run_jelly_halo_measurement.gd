extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const DEFAULT_OUTPUT_DIRECTORY: String = "res://artifacts/measurements/jelly_halo"
const TEMP_SAVE_PATH: String = "res://artifacts/measurements/jelly_halo_save.tmp.cfg"
const OUTPUT_PREFIX: String = "--halo-output-directory="
const CASE_COUNT: int = 20
const RING_COLORS: Array[int] = [
	OrbTypes.OrbColor.RED,
	OrbTypes.OrbColor.BLUE,
	OrbTypes.OrbColor.GREEN,
	OrbTypes.OrbColor.CYAN,
]
const POST_REACTION_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
]

var _output_directory: String = DEFAULT_OUTPUT_DIRECTORY
var _failed: bool = false
var _normal_ring_occurrences: int = 0
var _before_ring_pixels: int = 0
var _after_repeat_pixels: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	_parse_arguments()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_directory))
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.rng_seed = 109
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
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	if not await _wait_until_ready(manager, director):
		_fail("Initial game did not reach WAITING_INPUT")
	manager.set_physics_process(false)
	for case_index: int in range(CASE_COUNT):
		await _run_case(case_index, manager, board, resolver, director, camera)
	print(
		"JELLY_HALO_MEASUREMENT cases=%d post_turn_samples=%d normal_ring_occurrences=%d before_ring_pixels=%d after_repeat_pixels=%d"
		% [
			CASE_COUNT,
			CASE_COUNT * POST_REACTION_DIRECTIONS.size(),
			_normal_ring_occurrences,
			_before_ring_pixels,
			_after_repeat_pixels,
		]
	)
	main.queue_free()
	await get_tree().process_frame
	_remove_file(TEMP_SAVE_PATH)
	get_tree().quit(1 if _failed else 0)


func _run_case(
	case_index: int,
	manager: TurnManager,
	board: Board3D,
	resolver: CollisionResolver,
	director: FeedbackDirector,
	camera: Camera3D
) -> void:
	board.clear()
	director.clear_effects()
	director.set_process(true)
	JellyOrbArt.unfreeze_animation()
	var color_index: int = RING_COLORS[case_index % RING_COLORS.size()]
	var absorption: bool = case_index % 2 == 1
	var first_level: int = 3 if absorption else 2
	var second_level: int = 2
	var first: Orb3D = board.spawn_orb(color_index, first_level, Vector2(-40.0, 80.0))
	var second: Orb3D = board.spawn_orb(color_index, second_level, Vector2(40.0, 80.0))
	first.disable_physics()
	second.disable_physics()
	resolver.report_contact(first, second, "halo_measurement")
	var applied: int = resolver.flush(1.0 / 120.0)
	if applied != 1:
		_fail("Case %d expected one reaction, got %d" % [case_index, applied])
		return
	await get_tree().process_frame
	await get_tree().create_timer(0.02).timeout
	get_tree().paused = true
	director.set_process(false)
	JellyOrbArt.freeze_animation_for_capture()
	var effects: Array[ColorEffectVisual] = director.active_color_effects()
	if effects.size() != 1:
		_fail("Case %d expected one color effect, got %d" % [case_index, effects.size()])
		return
	var effect: ColorEffectVisual = effects[0]
	if effect.ring_layer_count() != 0:
		_normal_ring_occurrences += 1
	var result_orb: Orb3D = _single_result_orb(board)
	if result_orb == null:
		_fail("Case %d has no single result orb" % case_index)
		return
	result_orb.disable_physics()
	result_orb.set_process(false)
	var center_and_radius: Dictionary = _screen_center_and_radius(camera, result_orb)
	var normal_image: Image = await _capture(
		"case_%02d_after.png" % (case_index + 1) if case_index == 0 else ""
	)
	effect.set_ring_enabled(true)
	var before_image: Image = await _capture(
		"case_%02d_before.png" % (case_index + 1) if case_index == 0 else ""
	)
	effect.set_ring_enabled(false)
	var repeat_image: Image = await _capture(
		"case_%02d_after_repeat.png" % (case_index + 1) if case_index == 0 else ""
	)
	var sample_center: Vector2 = center_and_radius["center"] as Vector2
	var sample_radius: float = float(center_and_radius["radius"])
	var before_metrics: Dictionary = _difference_metrics(
		normal_image, before_image, sample_center, sample_radius
	)
	var repeat_metrics: Dictionary = _difference_metrics(
		normal_image, repeat_image, sample_center, sample_radius
	)
	var before_pixels: int = int(before_metrics["pixels"])
	var repeat_pixels: int = int(repeat_metrics["pixels"])
	_before_ring_pixels += before_pixels
	_after_repeat_pixels += repeat_pixels
	if before_pixels <= repeat_pixels + 8:
		_fail("Case %d did not reproduce the old ring in the annulus" % case_index)
	if case_index == 0:
		print(
			"JELLY_HALO_PIXEL_REGION center=%s radius=%.3f before_bbox=%s repeat_bbox=%s"
			% [
				center_and_radius["center"],
				float(center_and_radius["radius"]),
				before_metrics["bbox"],
				repeat_metrics["bbox"],
			]
		)
	JellyOrbArt.unfreeze_animation()
	get_tree().paused = false
	result_orb.set_process(true)
	director.set_process(true)
	manager.set_physics_process(true)
	for direction: Vector2i in POST_REACTION_DIRECTIONS:
		if manager.state != TurnManager.State.WAITING_INPUT:
			_fail("Case %d was not ready before post-reaction turn" % case_index)
			break
		manager.on_swipe(direction)
		if not await _wait_until_ready(manager, director):
			_fail("Case %d post-reaction turn did not settle" % case_index)
			break
	manager.set_physics_process(false)
	print(
		"JELLY_HALO_CASE index=%d kind=%s color=%d before_ring_pixels=%d after_ring_pixels=%d post_turns=3"
		% [
			case_index + 1,
			"absorption" if absorption else "merge",
			color_index,
			before_pixels,
			repeat_pixels,
		]
	)


func _wait_until_ready(manager: TurnManager, director: FeedbackDirector) -> bool:
	for _frame: int in range(360):
		for active_effect: ColorEffectVisual in director.active_color_effects():
			if active_effect.ring_layer_count() != 0:
				_normal_ring_occurrences += 1
		if manager.state == TurnManager.State.WAITING_INPUT:
			return true
		if manager.state == TurnManager.State.GAME_OVER:
			return false
		await get_tree().physics_frame
	return false


func _single_result_orb(board: Board3D) -> Orb3D:
	var orbs: Array[Orb3D] = board.get_orbs()
	if orbs.size() != 1:
		return null
	return orbs[0]


func _screen_center_and_radius(camera: Camera3D, orb: Orb3D) -> Dictionary:
	var center_world: Vector3 = orb._mesh.global_position
	var center: Vector2 = camera.unproject_position(center_world)
	var radius_m: float = orb.get_current_radius() / Orb3D.PIXELS_PER_METER
	var edge: Vector2 = camera.unproject_position(center_world + Vector3(radius_m, 0.0, 0.0))
	var render_size: Vector2 = Vector2(get_viewport().get_texture().get_size())
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var render_scale: Vector2 = render_size / window_size
	center *= render_scale
	edge *= render_scale
	return {"center": center, "radius": center.distance_to(edge)}


func _capture(file_name: String) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if file_name.is_empty():
		return image
	var path: String = _output_directory.path_join(file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		_fail("Could not save %s: %s" % [path, error_string(error)])
	else:
		print("JELLY_HALO_CAPTURE file=%s size=%dx%d" % [path, image.get_width(), image.get_height()])
	return image


func _difference_metrics(
	first: Image,
	second: Image,
	center: Vector2,
	radius: float
) -> Dictionary:
	var changed: int = 0
	var outer_radius: float = radius * 1.35
	var scan_min_x: int = maxi(floori(center.x - outer_radius), 0)
	var scan_max_x: int = mini(ceili(center.x + outer_radius), first.get_width() - 1)
	var scan_min_y: int = maxi(floori(center.y - outer_radius), 0)
	var scan_max_y: int = mini(ceili(center.y + outer_radius), first.get_height() - 1)
	var min_x: int = first.get_width()
	var max_x: int = -1
	var min_y: int = first.get_height()
	var max_y: int = -1
	for y: int in range(scan_min_y, scan_max_y + 1):
		for x: int in range(scan_min_x, scan_max_x + 1):
			var distance: float = Vector2(float(x), float(y)).distance_to(center)
			if distance < radius or distance > outer_radius:
				continue
			var a: Color = first.get_pixel(x, y)
			var b: Color = second.get_pixel(x, y)
			var channel_delta: float = maxf(
				absf(a.r - b.r),
				maxf(absf(a.g - b.g), absf(a.b - b.b))
			)
			if channel_delta > 2.0 / 255.0:
				changed += 1
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	var bbox: Rect2i = Rect2i()
	if changed > 0:
		bbox = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	return {"pixels": changed, "bbox": bbox}


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
