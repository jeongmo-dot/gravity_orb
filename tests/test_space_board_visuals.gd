extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")


func test_space_backdrop_has_three_star_depths_nebula_and_timed_meteor() -> void:
	var backdrop: SpaceBackdrop = SpaceBackdrop.new()
	tree.root.add_child(backdrop)
	await tree.process_frame
	var material: ShaderMaterial = backdrop.shader_material()
	var shader_code: String = material.shader.code
	assert_true(shader_code.contains("far_stars"), "space has a far star layer")
	assert_true(shader_code.contains("middle_stars"), "space has a middle star layer")
	assert_true(shader_code.contains("near_stars"), "space has a near star layer")
	assert_true(shader_code.contains("violet"), "space has a violet nebula layer")
	assert_true(shader_code.contains("teal"), "space has a teal nebula layer")
	assert_true(shader_code.contains("magenta"), "space has a magenta nebula layer")
	assert_eq(SpaceBackdrop.FAR_PARALLAX_PIXELS, 2.0, "far parallax is two pixels")
	assert_eq(SpaceBackdrop.NEAR_PARALLAX_PIXELS, 8.0, "near parallax is eight pixels")
	assert_true(
		SpaceBackdrop.METEOR_INTERVAL_SECONDS >= 20.0
		and SpaceBackdrop.METEOR_INTERVAL_SECONDS <= 40.0,
		"meteor interval stays within the specified range"
	)
	assert_eq(SpaceBackdrop.METEOR_DURATION_SECONDS, 0.6, "meteor lasts 0.6 seconds")
	backdrop.queue_free()
	await tree.process_frame


func test_space_parallax_moves_toward_gravity_and_returns_in_point_three_seconds() -> void:
	var backdrop: SpaceBackdrop = SpaceBackdrop.new()
	tree.root.add_child(backdrop)
	await tree.process_frame
	backdrop.set_gravity_direction(Vector2i.RIGHT)
	backdrop._process(SpaceBackdrop.PARALLAX_DURATION * 0.5)
	var middle_offset: Vector2 = backdrop.current_parallax_uv()
	assert_true(middle_offset.x > 0.0, "right gravity moves stars right")
	assert_near(middle_offset.y, 0.0, 0.00001, "horizontal parallax has no vertical drift")
	backdrop._process(SpaceBackdrop.PARALLAX_DURATION * 0.5)
	assert_near(
		backdrop.current_parallax_uv().length(),
		0.0,
		0.00001,
		"parallax returns after the board tilt duration"
	)
	backdrop.queue_free()
	await tree.process_frame


func test_board_uses_glass_gravity_field_and_layered_metal_frame() -> void:
	var board: Board3D = await _create_board()
	var backing: MeshInstance3D = board.get_node("VisualTilt/Backing") as MeshInstance3D
	var backing_material: ShaderMaterial = backing.material_override as ShaderMaterial
	assert_true(backing_material != null, "board backing uses a glass shader")
	assert_true(
		backing_material.shader.code.contains("ALPHA = mix(0.65, 0.78"),
		"glass reveals thirty to forty percent of the background"
	)
	var gravity_field: MeshInstance3D = board.get_node(
		"VisualTilt/GravityField"
	) as MeshInstance3D
	var field_material: ShaderMaterial = gravity_field.material_override as ShaderMaterial
	assert_true(field_material != null, "board has a gravity field layer")
	assert_true(
		float(field_material.get_shader_parameter("maximum_alpha")) <= 0.12,
		"gravity field opacity stays at or below 0.12"
	)
	for wall_name: String in ["VisualTop", "VisualBottom", "VisualLeft", "VisualRight"]:
		var wall: MeshInstance3D = board.get_node("VisualTilt/%s" % wall_name) as MeshInstance3D
		var material: StandardMaterial3D = wall.material_override as StandardMaterial3D
		assert_true(material.metallic >= 0.75, "%s uses a metallic frame" % wall_name)
		assert_true(wall.has_node("InnerGlow"), "%s has inner glass light" % wall_name)
		assert_true(wall.has_node("OuterGlow"), "%s has outer state glow" % wall_name)
	assert_true(board.has_node("VisualTilt/BeveledCorners"), "frame corners are beveled")
	await _cleanup(board)


func test_gravity_wall_light_and_field_move_to_the_new_direction() -> void:
	var board: Board3D = await _create_board()
	board.set_gravity(Vector2i.LEFT)
	board._process(Board3D.GRAVITY_LIGHT_DURATION)
	var left_glow: MeshInstance3D = board.get_node(
		"VisualTilt/VisualLeft/InnerGlow"
	) as MeshInstance3D
	var right_glow: MeshInstance3D = board.get_node(
		"VisualTilt/VisualRight/InnerGlow"
	) as MeshInstance3D
	var left_material: StandardMaterial3D = left_glow.material_override as StandardMaterial3D
	var right_material: StandardMaterial3D = right_glow.material_override as StandardMaterial3D
	assert_true(
		left_material.emission_energy_multiplier > right_material.emission_energy_multiplier,
		"new gravity wall is brighter after 0.25 seconds"
	)
	assert_near(
		right_material.emission_energy_multiplier,
		0.0,
		0.0001,
		"old gravity wall is dark after 0.25 seconds"
	)
	board._process(Board3D.GRAVITY_FIELD_DURATION - Board3D.GRAVITY_LIGHT_DURATION)
	var gravity_field: MeshInstance3D = board.get_node(
		"VisualTilt/GravityField"
	) as MeshInstance3D
	var field_material: ShaderMaterial = gravity_field.material_override as ShaderMaterial
	assert_eq(
		field_material.get_shader_parameter("gravity_to") as Vector2,
		Vector2.LEFT,
		"field targets the new gravity direction"
	)
	assert_near(
		float(field_material.get_shader_parameter("gravity_mix")),
		1.0,
		0.0001,
		"field finishes bending in 0.3 seconds"
	)
	await _cleanup(board)


func test_blocked_fever_and_danger_keep_distinct_frame_states() -> void:
	var board: Board3D = await _create_board()
	board.set_warning_directions([Vector2i.DOWN])
	board._process(0.1)
	var top_wall: MeshInstance3D = board.get_node("VisualTilt/VisualTop") as MeshInstance3D
	var top_material: StandardMaterial3D = top_wall.material_override as StandardMaterial3D
	assert_true(top_material.albedo_color.r > top_material.albedo_color.b, "blocked edge is red")
	board.set_warning_directions([])
	board.set_fever_active(true)
	board._process(0.1)
	for wall_name: String in ["VisualTop", "VisualBottom", "VisualLeft", "VisualRight"]:
		var wall: MeshInstance3D = board.get_node("VisualTilt/%s" % wall_name) as MeshInstance3D
		var material: StandardMaterial3D = wall.material_override as StandardMaterial3D
		assert_true(
			material.albedo_color.r > material.albedo_color.b,
			"%s warms during fever" % wall_name
		)
	board.set_fever_active(false)
	board.set_danger_state(Config.data.danger_start, 1.0)
	board._process(0.1)
	var threshold_glow: MeshInstance3D = board.get_node(
		"VisualTilt/VisualBottom/OuterGlow"
	) as MeshInstance3D
	var threshold_material: StandardMaterial3D = (
		threshold_glow.material_override as StandardMaterial3D
	)
	assert_true(
		threshold_material.emission_energy_multiplier > 0.0,
		"danger threshold starts with a sky-blue outer glow"
	)
	assert_true(
		threshold_material.emission.b > threshold_material.emission.r,
		"danger threshold outer glow is sky blue"
	)
	var danger_signal: Dictionary = {}
	board.danger_visual_changed.connect(
		func(intensity: float, pulsing: bool) -> void:
			danger_signal["intensity"] = intensity
			danger_signal["pulsing"] = pulsing
	)
	board.set_danger_state(0.70, 4.0)
	board._process(0.1)
	assert_near(float(danger_signal.get("intensity", 0.0)), 1.0, 0.0001, "danger x4 is red")
	assert_true(bool(danger_signal.get("pulsing", false)), "danger x4 pulses")
	var outer_glow: MeshInstance3D = board.get_node(
		"VisualTilt/VisualBottom/OuterGlow"
	) as MeshInstance3D
	var outer_material: StandardMaterial3D = outer_glow.material_override as StandardMaterial3D
	assert_true(outer_material.emission.r > outer_material.emission.b, "danger outer glow is red")
	await _cleanup(board)


func _create_board() -> Board3D:
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	return board


func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await tree.process_frame
