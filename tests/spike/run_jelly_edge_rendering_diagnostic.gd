extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const DEFAULT_OUTPUT_DIRECTORY: String = "res://artifacts/measurements/jelly_edge_rendering"
const OUTPUT_PREFIX: String = "--jelly-edge-output-directory="
const TEMP_SAVE_PATH: String = "res://artifacts/measurements/jelly_edge_rendering_save.tmp.cfg"
const SAMPLE_COLOR: int = OrbTypes.OrbColor.GREEN
const SAMPLE_LEVEL: int = 3
const EDGE_POSITION: float = 405.0
const OUTER_DARK_DELTA: float = 0.003
const OUTER_COLOR_DELTA: float = 0.06
const MOTION_FRAME_COUNT: int = 120
const MOTION_SPEED: float = 720.0
const FIXED_DELTA: float = 1.0 / 120.0
const CASE_NAMES: Array[String] = [
	"baseline",
	"board_planes_off",
	"body_opaque",
	"body_priority_behind",
	"body_priority_front",
	"body_priority_default",
	"shadows_off",
	"wall_glows_off",
	"overlays_off",
	"orthographic",
	"rim_off",
]
const STATIONARY_SPECS: Array[Dictionary] = [
	{"label": "center", "position": Vector2.ZERO},
	{"label": "left", "position": Vector2(-EDGE_POSITION, 0.0)},
	{"label": "right", "position": Vector2(EDGE_POSITION, 0.0)},
	{"label": "top", "position": Vector2(0.0, -EDGE_POSITION)},
	{"label": "bottom", "position": Vector2(0.0, EDGE_POSITION)},
	{"label": "top_left", "position": Vector2(-EDGE_POSITION, -EDGE_POSITION)},
	{"label": "top_right", "position": Vector2(EDGE_POSITION, -EDGE_POSITION)},
	{"label": "bottom_left", "position": Vector2(-EDGE_POSITION, EDGE_POSITION)},
	{"label": "bottom_right", "position": Vector2(EDGE_POSITION, EDGE_POSITION)},
]
const MOTION_DIRECTIONS: Array[Vector2i] = [
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
]

var _output_directory: String = DEFAULT_OUTPUT_DIRECTORY
var _failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	_parse_arguments()
	if DisplayServer.get_name() == "headless":
		_fail("JELLY edge rendering diagnostic requires an actual graphics window")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_directory))
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.rng_seed = 111
	JellyOrbArt.freeze_animation_for_capture()
	var case_reports: Array[Dictionary] = []
	for case_name: String in CASE_NAMES:
		case_reports.append(await _run_stationary_case(case_name))
	var motion_before_alignment: Array[Dictionary] = await _run_motion_cases(true)
	var motion_reports: Array[Dictionary] = await _run_motion_cases(false)
	var motion_rim_off: Dictionary = await _run_motion_case(Vector2i.RIGHT, false, true)
	var report: Dictionary = {
		"commit": _commit_hash(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"display_server": DisplayServer.get_name(),
		"window_size": DisplayServer.window_get_size(),
		"cases": case_reports,
		"motion_before_frame_alignment": motion_before_alignment,
		"motion": motion_reports,
		"motion_rim_off": motion_rim_off,
	}
	_write_report(report)
	print("JELLY_EDGE_RENDERING %s" % JSON.stringify(report))
	JellyOrbArt.unfreeze_animation()
	_remove_file(TEMP_SAVE_PATH)
	get_tree().quit(1 if _failed else 0)


func _run_stationary_case(case_name: String) -> Dictionary:
	var main: Main = await _create_main()
	var board: Board3D = main.get_node("Board") as Board3D
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	_apply_scene_candidate(main, board, camera, case_name)
	await _settle_frames(3)
	var reference: Image = await _capture("%s_reference.png" % case_name)
	var entries: Array[Dictionary] = _spawn_stationary_orbs(board, case_name)
	await _settle_frames(4)
	var image: Image = await _capture("%s.png" % case_name)
	var samples: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var orb: Orb3D = entry["orb"] as Orb3D
		var label: String = str(entry["label"])
		samples.append(_measure_stationary_sample(
			image,
			reference,
			camera,
			orb,
			label
		))
		if case_name in ["baseline", "rim_off"] and label in ["center", "bottom_right"]:
			var image_scale: Vector2 = Vector2(image.get_size()) / get_viewport().get_visible_rect().size
			var zoom_center: Vector2 = camera.unproject_position(orb._mesh.global_position) * image_scale
			_save_centered_crop(image, zoom_center, "%s_%s_zoom.png" % [case_name, label])
	var key_light: DirectionalLight3D = main.get_node("KeyLight") as DirectionalLight3D
	var body_shadow_count: int = 0
	for entry: Dictionary in entries:
		var orb: Orb3D = entry["orb"] as Orb3D
		if orb._mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			body_shadow_count += 1
	var result: Dictionary = {
		"case": case_name,
		"key_shadow_enabled": key_light.shadow_enabled,
		"body_shadow_count": body_shadow_count,
		"camera_projection": "orthographic" if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else "perspective",
		"samples": samples,
		"dark_outer_pixels_total": _sum_int_field(samples, "outer_dark_pixels"),
		"changed_outer_pixels_total": _sum_int_field(samples, "outer_changed_pixels"),
	}
	main.queue_free()
	await get_tree().process_frame
	return result


func _create_main() -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.JELLY)
	(main.get_node("ScoreManager") as ScoreManager).save_path = TEMP_SAVE_PATH
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = TEMP_SAVE_PATH
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	if not await _wait_until_ready(manager):
		_fail("Diagnostic main did not reach WAITING_INPUT")
	manager.set_physics_process(false)
	var board: Board3D = main.get_node("Board") as Board3D
	board.clear()
	board.set_turn_resting(true)
	var ui_root: Node = main.get_node("UI")
	for canvas_item: Node in ui_root.find_children("*", "CanvasItem", true, false):
		(canvas_item as CanvasItem).visible = false
	return main


func _apply_scene_candidate(
	main: Main,
	board: Board3D,
	camera: Camera3D,
	case_name: String
) -> void:
	if case_name == "board_planes_off":
		(board.get_node("VisualTilt/Backing") as Node3D).visible = false
		(board.get_node("VisualTilt/GravityField") as Node3D).visible = false
	if case_name == "shadows_off":
		(main.get_node("KeyLight") as DirectionalLight3D).shadow_enabled = false
	if case_name == "wall_glows_off":
		for node: Node in board.find_children("*Glow", "MeshInstance3D", true, false):
			(node as MeshInstance3D).visible = false
	if case_name == "orthographic":
		var distance: float = absf(camera.global_position.z)
		camera.size = 2.0 * distance * tan(deg_to_rad(camera.fov) * 0.5)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL


func _spawn_stationary_orbs(board: Board3D, case_name: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for spec: Dictionary in STATIONARY_SPECS:
		var orb: Orb3D = board.spawn_orb(
			SAMPLE_COLOR,
			SAMPLE_LEVEL,
			spec["position"] as Vector2
		)
		orb.disable_physics()
		orb.set_process(false)
		orb._jelly_deform = Vector2.ONE
		orb._jelly_breath_weight = 0.0
		orb._jelly_idle_elapsed = 0.0
		orb._update_visual_transform()
		_apply_orb_candidate(orb, case_name)
		entries.append({"label": spec["label"], "orb": orb})
	return entries


func _apply_orb_candidate(orb: Orb3D, case_name: String) -> void:
	if case_name == "shadows_off":
		orb._mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if case_name == "overlays_off":
		orb._face.visible = false
		orb._belly.visible = false
	if case_name not in [
		"body_opaque",
		"body_priority_behind",
		"body_priority_front",
		"body_priority_default",
		"rim_off",
	]:
		return
	var original: ShaderMaterial = orb._mesh.material_override as ShaderMaterial
	var material: ShaderMaterial = original.duplicate(false) as ShaderMaterial
	var shader: Shader = Shader.new()
	shader.code = original.shader.code
	if case_name == "body_opaque":
		shader.code = shader.code.replace(
			"ALPHA = mix(0.90, 1.0, smoothstep(0.0, 0.72, facing));",
			"ALPHA = 1.0;"
		)
	elif case_name == "rim_off":
		shader.code = shader.code.replace(
			"interior += mix(base, vec3(1.0), 0.44) * rim * 0.23;",
			""
		)
		shader.code = shader.code.replace(
			"interior += vec3(1.0) * rim * max_pulse * 0.30;",
			""
		)
		shader.code = shader.code.replace(
			"EMISSION = interior * (0.08 + rim * (0.08 + max_pulse * 0.32));",
			"EMISSION = interior * 0.08;"
		)
	material.shader = shader
	if case_name == "body_priority_behind":
		material.render_priority = -10
	elif case_name == "body_priority_front":
		material.render_priority = 10
	elif case_name == "body_priority_default":
		material.render_priority = 0
	orb._mesh.material_override = material


func _measure_stationary_sample(
	image: Image,
	reference: Image,
	camera: Camera3D,
	orb: Orb3D,
	label: String
) -> Dictionary:
	var projection: Dictionary = _projected_body_axes(camera, orb)
	var image_scale: Vector2 = Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var center: Vector2 = (projection["center"] as Vector2) * image_scale
	var axis_x: Vector2 = (projection["axis_x"] as Vector2) * image_scale
	var axis_y: Vector2 = (projection["axis_y"] as Vector2) * image_scale
	var determinant: float = axis_x.x * axis_y.y - axis_y.x * axis_x.y
	if absf(determinant) < 0.000001:
		_fail("Degenerate projected axes for %s" % label)
		return {"label": label}
	var inverse: Transform2D = Transform2D(axis_x, axis_y, center).affine_inverse()
	var extent: int = ceili(maxf(axis_x.length(), axis_y.length()) * 1.35)
	var outer_count: int = 0
	var outer_dark_pixels: int = 0
	var outer_changed_pixels: int = 0
	var outer_luminance: float = 0.0
	var outer_reference_luminance: float = 0.0
	var inner_count: int = 0
	var inner_luminance: float = 0.0
	var body_count: int = 0
	var body_luminance: float = 0.0
	for y: int in range(maxi(0, floori(center.y) - extent), mini(image.get_height(), ceili(center.y) + extent + 1)):
		for x: int in range(maxi(0, floori(center.x) - extent), mini(image.get_width(), ceili(center.x) + extent + 1)):
			var local: Vector2 = inverse * Vector2(float(x) + 0.5, float(y) + 0.5)
			var radial: float = local.length()
			var current_luma: float = image.get_pixel(x, y).get_luminance()
			var reference_luma: float = reference.get_pixel(x, y).get_luminance()
			if radial >= 1.0 and radial <= 1.3:
				outer_count += 1
				outer_luminance += current_luma
				outer_reference_luminance += reference_luma
				if (
					reference_luma - current_luma >= OUTER_DARK_DELTA
					and current_luma <= reference_luma * 0.85
				):
					outer_dark_pixels += 1
				var current_color: Color = image.get_pixel(x, y)
				var reference_color: Color = reference.get_pixel(x, y)
				var color_delta: float = (
					absf(current_color.r - reference_color.r)
					+ absf(current_color.g - reference_color.g)
					+ absf(current_color.b - reference_color.b)
				)
				if color_delta >= OUTER_COLOR_DELTA:
					outer_changed_pixels += 1
			elif radial >= 0.7 and radial < 1.0:
				inner_count += 1
				inner_luminance += current_luma
			elif radial < 0.6:
				body_count += 1
				body_luminance += current_luma
	return {
		"label": label,
		"screen_center": center,
		"screen_radius_x": axis_x.length(),
		"screen_radius_y": axis_y.length(),
		"outer_pixels": outer_count,
		"outer_dark_pixels": outer_dark_pixels,
		"outer_changed_pixels": outer_changed_pixels,
		"outer_dark_ratio": _safe_ratio(float(outer_dark_pixels), float(outer_count)),
		"outer_luminance": _safe_ratio(outer_luminance, float(outer_count)),
		"outer_reference_luminance": _safe_ratio(outer_reference_luminance, float(outer_count)),
		"inner_luminance": _safe_ratio(inner_luminance, float(inner_count)),
		"body_luminance": _safe_ratio(body_luminance, float(body_count)),
	}


func _run_motion_cases(simulate_smooth_frame_lag: bool) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	for direction: Vector2i in MOTION_DIRECTIONS:
		reports.append(await _run_motion_case(direction, simulate_smooth_frame_lag, false))
	return reports


func _run_motion_case(
	direction: Vector2i,
	simulate_smooth_frame_lag: bool,
	disable_rim: bool
) -> Dictionary:
	var main: Main = await _create_main()
	var board: Board3D = main.get_node("Board") as Board3D
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	board.set_gravity(Vector2i.DOWN)
	board.set_turn_resting(false)
	var start_position: Vector2 = -Vector2(direction) * 330.0
	var orb: Orb3D = board.spawn_orb(SAMPLE_COLOR, SAMPLE_LEVEL, start_position)
	orb.set_gravity(direction, Config.data.gravity_strength)
	if disable_rim:
		_apply_orb_candidate(orb, "rim_off")
	if simulate_smooth_frame_lag:
		orb._jelly_frame_rotation = 0.0
	orb.linear_velocity = Vector2(direction) * MOTION_SPEED
	var ratio_sum: float = 0.0
	var perspective_sum: float = 0.0
	var off_axis_sum: float = 0.0
	var active_frames: int = 0
	var maximum_ratio: float = 1.0
	var maximum_perspective_ratio: float = 1.0
	var maximum_off_axis_degrees: float = 0.0
	var maximum_face_offset: float = 0.0
	var maximum_belly_offset: float = 0.0
	var maximum_scale_ratio: float = 1.0
	var maximum_frame: int = 0
	var deformed_frames: int = 0
	var screen_scale: Vector2 = Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	for frame_index: int in range(MOTION_FRAME_COUNT):
		await get_tree().process_frame
		var projection: Dictionary = _projected_body_axes(camera, orb)
		var axis_x: Vector2 = projection["axis_x"] as Vector2
		var axis_y: Vector2 = projection["axis_y"] as Vector2
		var major_axis: Vector2 = axis_x if axis_x.length() >= axis_y.length() else axis_y
		var screen_ratio: float = _safe_ratio(
			maxf(axis_x.length(), axis_y.length()),
			minf(axis_x.length(), axis_y.length())
		)
		var perspective_ratio: float = _perspective_ratio(camera, orb)
		var body_scale: Vector3 = orb._jelly_body_scale()
		var scale_ratio: float = _safe_ratio(
			maxf(body_scale.x, body_scale.y),
			minf(body_scale.x, body_scale.y)
		)
		var expected_screen_direction: Vector2 = Vector2(direction).normalized()
		if body_scale.x > body_scale.y:
			expected_screen_direction = Vector2(
				-float(direction.y),
				float(direction.x)
			).normalized()
		var off_axis_degrees: float = (
			_acute_angle_degrees(major_axis, expected_screen_direction)
			if scale_ratio > 1.005
			else 0.0
		)
		var body_center: Vector2 = projection["center"] as Vector2
		var face_offset: float = body_center.distance_to(
			camera.unproject_position(orb._face.global_position)
		) * screen_scale.length() / sqrt(2.0)
		var belly_offset: float = body_center.distance_to(
			camera.unproject_position(orb._belly.global_position)
		) * screen_scale.length() / sqrt(2.0)
		ratio_sum += screen_ratio
		perspective_sum += perspective_ratio
		off_axis_sum += off_axis_degrees
		active_frames += 1
		maximum_perspective_ratio = maxf(maximum_perspective_ratio, perspective_ratio)
		maximum_off_axis_degrees = maxf(maximum_off_axis_degrees, off_axis_degrees)
		maximum_face_offset = maxf(maximum_face_offset, face_offset)
		maximum_belly_offset = maxf(maximum_belly_offset, belly_offset)
		maximum_scale_ratio = maxf(maximum_scale_ratio, scale_ratio)
		if scale_ratio > 1.01:
			deformed_frames += 1
		if screen_ratio > maximum_ratio:
			maximum_ratio = screen_ratio
			maximum_frame = frame_index
		if frame_index in [30, 60, 90]:
			var capture_name: String = "motion%s%s_%s_%03d.png" % [
				"_legacy" if simulate_smooth_frame_lag else "",
				"_rim_off" if disable_rim else "",
				OrbTypes.dir_name(direction).to_lower(),
				frame_index,
			]
			var motion_image: Image = await _capture(capture_name)
			if not simulate_smooth_frame_lag:
				var zoom_center: Vector2 = (projection["center"] as Vector2) * screen_scale
				_save_centered_crop(
					motion_image,
					zoom_center,
					capture_name.trim_suffix(".png") + "_zoom.png"
				)
	var result: Dictionary = {
		"direction": OrbTypes.dir_name(direction),
		"frames": active_frames,
		"screen_axis_ratio_average": _safe_ratio(ratio_sum, float(active_frames)),
		"screen_axis_ratio_maximum": maximum_ratio,
		"intended_body_scale_ratio_maximum": maximum_scale_ratio,
		"intended_deform_duration_frames": deformed_frames,
		"perspective_ratio_average": _safe_ratio(perspective_sum, float(active_frames)),
		"perspective_ratio_maximum": maximum_perspective_ratio,
		"off_axis_degrees_average": _safe_ratio(off_axis_sum, float(active_frames)),
		"off_axis_degrees_maximum": maximum_off_axis_degrees,
		"face_center_offset_px_maximum": maximum_face_offset,
		"belly_center_offset_px_maximum": maximum_belly_offset,
		"maximum_ratio_frame": maximum_frame,
	}
	main.queue_free()
	await get_tree().process_frame
	return result


func _projected_body_axes(camera: Camera3D, orb: Orb3D) -> Dictionary:
	var mesh: SphereMesh = orb._mesh.mesh as SphereMesh
	var center_world: Vector3 = orb._mesh.global_position
	var center: Vector2 = camera.unproject_position(center_world)
	var axis_x_world: Vector3 = orb._mesh.global_transform.basis.x * mesh.radius
	var axis_y_world: Vector3 = orb._mesh.global_transform.basis.y * mesh.radius
	return {
		"center": center,
		"axis_x": camera.unproject_position(center_world + axis_x_world) - center,
		"axis_y": camera.unproject_position(center_world + axis_y_world) - center,
	}


func _perspective_ratio(camera: Camera3D, orb: Orb3D) -> float:
	var mesh: SphereMesh = orb._mesh.mesh as SphereMesh
	var center: Vector3 = orb._mesh.global_position
	var screen_center: Vector2 = camera.unproject_position(center)
	var radius_x: float = screen_center.distance_to(
		camera.unproject_position(center + Vector3.RIGHT * mesh.radius)
	)
	var radius_y: float = screen_center.distance_to(
		camera.unproject_position(center + Vector3.UP * mesh.radius)
	)
	return _safe_ratio(maxf(radius_x, radius_y), minf(radius_x, radius_y))


func _acute_angle_degrees(first: Vector2, second: Vector2) -> float:
	if first.is_zero_approx() or second.is_zero_approx():
		return 0.0
	var value: float = absf(rad_to_deg(first.angle_to(second)))
	value = fmod(value, 180.0)
	return minf(value, 180.0 - value)


func _capture(file_name: String) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _output_directory.path_join(file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		_fail("Could not save %s: %s" % [path, error_string(error)])
	else:
		print("JELLY_EDGE_CAPTURE file=%s size=%dx%d" % [
			path,
			image.get_width(),
			image.get_height(),
		])
	return image


func _save_centered_crop(image: Image, center: Vector2, file_name: String) -> void:
	const ZOOM_SIZE: int = 160
	var x: int = clampi(roundi(center.x) - ZOOM_SIZE / 2, 0, image.get_width() - ZOOM_SIZE)
	var y: int = clampi(roundi(center.y) - ZOOM_SIZE / 2, 0, image.get_height() - ZOOM_SIZE)
	var crop: Image = image.get_region(Rect2i(x, y, ZOOM_SIZE, ZOOM_SIZE))
	var path: String = _output_directory.path_join(file_name)
	var error: Error = crop.save_png(path)
	if error != OK:
		_fail("Could not save zoom %s: %s" % [path, error_string(error)])


func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_until_ready(manager: TurnManager) -> bool:
	for _frame_index: int in range(720):
		if manager.state == TurnManager.State.WAITING_INPUT:
			return true
		if manager.state == TurnManager.State.GAME_OVER:
			return false
		await get_tree().process_frame
	return false


func _sum_int_field(rows: Array[Dictionary], field: String) -> int:
	var total: int = 0
	for row: Dictionary in rows:
		total += int(row.get(field, 0))
	return total


func _safe_ratio(numerator: float, denominator: float) -> float:
	return numerator / denominator if absf(denominator) > 0.000001 else 0.0


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
