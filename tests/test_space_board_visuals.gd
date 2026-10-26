extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")


func test_space_backdrop_has_three_star_depths_nebula_and_no_meteor() -> void:
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
		not shader_code.to_lower().contains("meteor"),
		"space backdrop removes the meteor shader code"
	)
	assert_true(
		shader_code.contains("vec3(0.120, 0.0, 0.0) * danger_tint"),
		"danger state adds a visible red nebula tint"
	)
	backdrop.set_danger_state(1.0, true)
	backdrop._process(0.625)
	assert_true(
		float(material.get_shader_parameter("danger_tint")) >= 0.70,
		"danger nebula tint stays visible at the pulse minimum"
	)
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
	var wall_by_direction: Dictionary = {
		Vector2i.UP: "VisualTop",
		Vector2i.RIGHT: "VisualRight",
		Vector2i.DOWN: "VisualBottom",
		Vector2i.LEFT: "VisualLeft",
	}
	for direction: Vector2i in wall_by_direction:
		board.set_gravity(direction)
		board._process(Board3D.GRAVITY_LIGHT_DURATION)
		for checked_direction: Vector2i in wall_by_direction:
			var wall_name: String = String(wall_by_direction[checked_direction])
			var glow: MeshInstance3D = board.get_node(
				"VisualTilt/%s/InnerGlow" % wall_name
			) as MeshInstance3D
			var material: ShaderMaterial = glow.material_override as ShaderMaterial
			var strength: float = float(material.get_shader_parameter("strength"))
			if checked_direction == direction:
				assert_true(strength >= 0.85, "%s gravity wall is fully lit" % wall_name)
				assert_near(
					float(material.get_shader_parameter("highlight_center")),
					0.5,
					0.0001,
					"%s wall is brightest at its center" % wall_name
				)
			else:
				assert_near(strength, 0.0, 0.0001, "%s non-gravity wall is dark" % wall_name)

	board.set_gravity(Vector2i.DOWN)
	board._process(Board3D.GRAVITY_LIGHT_DURATION)
	board.set_gravity(Vector2i.RIGHT)
	board._process(Board3D.GRAVITY_LIGHT_DURATION * 0.5)
	var corner_highlight_by_wall: Dictionary = {
		"VisualBottom": 1.0,
		"VisualRight": 1.0,
	}
	for corner_wall_name: String in corner_highlight_by_wall:
		var corner_glow: MeshInstance3D = board.get_node(
			"VisualTilt/%s/InnerGlow" % corner_wall_name
		) as MeshInstance3D
		var corner_material: ShaderMaterial = corner_glow.material_override as ShaderMaterial
		assert_true(
			float(corner_material.get_shader_parameter("strength")) >= 0.89,
			"adjacent walls share a strong light at the bottom-right corner"
		)
		assert_near(
			float(corner_material.get_shader_parameter("highlight_center")),
			float(corner_highlight_by_wall[corner_wall_name]),
			0.0001,
			"gravity light reaches the shared bottom-right corner"
		)

	board.set_gravity(Vector2i.LEFT)
	board._process(Board3D.GRAVITY_FIELD_DURATION)
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


func test_blocked_and_danger_keep_distinct_frame_states() -> void:
	var board: Board3D = await _create_board()
	board.set_warning_directions([Vector2i.DOWN])
	board._process(0.1)
	var top_wall: MeshInstance3D = board.get_node("VisualTilt/VisualTop") as MeshInstance3D
	var top_material: StandardMaterial3D = top_wall.material_override as StandardMaterial3D
	assert_eq(
		top_material.albedo_color,
		Board3D.METAL_FRAME_COLOR,
		"blocked direction leaves the frame at its normal metal color"
	)
	var blocked_outer: MeshInstance3D = board.get_node(
		"VisualTilt/VisualTop/OuterGlow"
	) as MeshInstance3D
	var blocked_outer_material: StandardMaterial3D = (
		blocked_outer.material_override as StandardMaterial3D
	)
	assert_near(
		blocked_outer_material.emission_energy_multiplier,
		0.0,
		0.0001,
		"blocked direction does not add an outer warning band"
	)
	board.set_warning_directions([])
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
	board.set_danger_state(0.70, 1.5)
	board._process(0.1)
	assert_near(
		threshold_material.emission.r,
		Board3D.DANGER_AMBER_COLOR.r,
		0.0001,
		"danger x1.5 uses the specified amber"
	)
	assert_near(
		threshold_material.emission.g,
		Board3D.DANGER_AMBER_COLOR.g,
		0.0001,
		"danger x1.5 keeps the specified amber green channel"
	)
	var danger_signal: Dictionary = {}
	board.danger_visual_changed.connect(
		func(intensity: float, pulsing: bool) -> void:
			danger_signal["intensity"] = intensity
			danger_signal["pulsing"] = pulsing
	)
	board.set_danger_state(0.70, 4.0)
	board._process(0.625)
	assert_near(float(danger_signal.get("intensity", 0.0)), 1.0, 0.0001, "danger x4 is red")
	assert_true(bool(danger_signal.get("pulsing", false)), "danger x4 pulses")
	var outer_glow: MeshInstance3D = board.get_node(
		"VisualTilt/VisualBottom/OuterGlow"
	) as MeshInstance3D
	var outer_material: StandardMaterial3D = outer_glow.material_override as StandardMaterial3D
	assert_true(outer_material.emission.r > outer_material.emission.b, "danger outer glow is red")
	assert_true(
		outer_material.albedo_color.a >= 0.46,
		"danger outer band keeps at least sixty percent pulse brightness"
	)
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
