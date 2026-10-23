extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")


func test_jelly_palette_matches_classic_color_indices_and_level_lightening() -> void:
	var expected: Array[Color] = [
		Color("ff7595"), Color("72a7ff"), Color("59e2ab"),
		Color("ffe77a"), Color("bc86ff"), Color("ffad63"),
	]
	for color_index: int in range(expected.size()):
		assert_eq(JellyOrbArt.PALETTE[color_index], expected[color_index], "JELLY color %d" % color_index)
		assert_eq(
			JellyOrbArt.color_for(color_index, 4),
			expected[color_index].lightened(4.0 * 0.018),
			"JELLY color %d L4 lightening" % color_index
		)


func test_jelly_orb_uses_face_shader_without_planet_adornment() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(2, 7, Vector2.ZERO)
	assert_true(orb._face.visible, "JELLY face billboard visible")
	assert_true(not orb._adornment.visible, "JELLY hides planet halo and prominence")
	assert_true(orb.visual_material_resource().shader.code.contains("lower_scatter"), "JELLY body shader")
	assert_true(
		(orb._face.material_override as ShaderMaterial).shader.code.contains("capsule"),
		"JELLY capsule-eye face shader"
	)
	assert_near(orb.mesh_resource().radius, orb.shape_resource().radius, 0.0001, "JELLY body fills radius")
	await _cleanup(board)
	Config.data.game_mode = original_mode


func test_jelly_max_face_uses_body_radius_while_regular_faces_keep_original_scale() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var board: Board3D = await _create_board()
	var regular: Orb3D = board.spawn_orb(0, 3, Vector2(-100.0, 0.0))
	var maximum: Orb3D = board.spawn_orb(0, 7, Vector2(100.0, 0.0))
	var regular_radius_m: float = Config.data.radius_for_level(3) / Orb3D.PIXELS_PER_METER
	var maximum_radius_m: float = Config.data.radius_for_level(7) / Orb3D.PIXELS_PER_METER
	assert_near(regular._face.scale.x / regular_radius_m, 0.62, 0.001, "regular face scale unchanged")
	assert_near(maximum._face.scale.x / maximum_radius_m, 1.0, 0.001, "MAX face matches body radius")
	await _cleanup(board)
	Config.data.game_mode = original_mode


func test_max_face_projects_smile_below_eyes_and_rotates_with_gravity() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(0, 7, Vector2.ZERO)
	var material: ShaderMaterial = orb._face.material_override as ShaderMaterial
	var eye_center: Vector2 = Vector2(
		0.0,
		float(material.get_shader_parameter("max_eye_y"))
	)
	var left_eye_center: Vector2 = Vector2(
		-float(material.get_shader_parameter("max_eye_x")),
		float(material.get_shader_parameter("max_eye_y"))
	)
	var smile_center: Vector2 = Vector2(
		0.0,
		float(material.get_shader_parameter("max_mouth_y"))
	)
	var highlight_offset: Vector2 = material.get_shader_parameter(
		"max_highlight_large_offset"
	)
	orb.set_gravity(Vector2i.DOWN, Config.data.gravity_strength)
	var down_eyes: Vector2 = _face_point_on_screen(
		eye_center,
		orb._jelly_face_target_rotation
	)
	var down_smile: Vector2 = _face_point_on_screen(
		smile_center,
		orb._jelly_face_target_rotation
	)
	var down_highlight: Vector2 = _face_point_on_screen(
		left_eye_center + highlight_offset,
		orb._jelly_face_target_rotation
	)
	var down_left_eye: Vector2 = _face_point_on_screen(
		left_eye_center,
		orb._jelly_face_target_rotation
	)
	assert_true(down_smile.y > down_eyes.y, "down gravity puts MAX smile below eyes")
	assert_true(
		down_highlight.y < down_left_eye.y,
		"down gravity keeps reflection above the eyes"
	)
	assert_true(down_highlight.x < down_left_eye.x, "reflection stays on the left")
	orb.set_gravity(Vector2i.RIGHT, Config.data.gravity_strength)
	var right_eyes: Vector2 = _face_point_on_screen(
		eye_center,
		orb._jelly_face_target_rotation
	)
	var right_smile: Vector2 = _face_point_on_screen(
		smile_center,
		orb._jelly_face_target_rotation
	)
	assert_true(
		right_smile.x > right_eyes.x,
		"right gravity rotates the smile to the right of the eyes"
	)

	assert_near(
		float(material.get_shader_parameter("max_eye_y")),
		JellyOrbArt.MAX_EYE_CENTER_Y,
		0.0001,
		"MAX shader uses tested eye center"
	)
	assert_near(
		float(material.get_shader_parameter("max_mouth_y")),
		JellyOrbArt.MAX_MOUTH_CENTER_Y,
		0.0001,
		"MAX shader uses tested cat-mouth center"
	)
	assert_eq(
		material.get_shader_parameter("max_face_color"),
		JellyOrbArt.MAX_FACE_COLOR,
		"MAX eyes and cat mouth use the mockup C dark purple"
	)
	assert_eq(
		material.get_shader_parameter("max_eye_radii"),
		Vector2(0.09, 0.13),
		"MAX eye radii match mockup C"
	)
	assert_eq(
		material.get_shader_parameter("max_highlight_large_offset"),
		Vector2(-0.03, -0.06),
		"both MAX eyes share the upper-left large reflection"
	)
	assert_near(
		float(material.get_shader_parameter("max_highlight_large_radius")),
		0.04,
		0.0001,
		"MAX large reflection radius matches mockup C"
	)
	assert_eq(
		material.get_shader_parameter("max_highlight_small_offset"),
		Vector2(0.04, 0.06),
		"both MAX eyes share the lower-right small reflection"
	)
	assert_near(
		float(material.get_shader_parameter("max_highlight_small_radius")),
		0.02,
		0.0001,
		"MAX small reflection radius matches mockup C"
	)
	assert_near(
		float(material.get_shader_parameter("max_mouth_radius")),
		0.06,
		0.0001,
		"MAX omega mouth uses two specified arcs"
	)
	assert_eq(
		material.get_shader_parameter("max_blush_radii"),
		Vector2(0.12, 0.07),
		"MAX blush ellipse matches mockup C"
	)
	assert_near(
		float(material.get_shader_parameter("max_blush_alpha")),
		0.45,
		0.0001,
		"MAX blush alpha matches mockup C"
	)
	await _cleanup(board)
	Config.data.game_mode = original_mode


func test_jelly_stretch_is_enabled_when_planet_stretch_setting_is_off() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_stretch: bool = Config.data.fx_orb_stretch_enabled
	var original_fx: bool = Config.data.fx_enabled
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.fx_enabled = true
	Config.data.fx_orb_stretch_enabled = false
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(0, 3, Vector2.ZERO, Vector2(1100.0, 0.0))
	assert_eq(
		orb.visual_stretch_scale(),
		Vector3(1.19, 0.90, 0.90),
		"JELLY uses its own falling stretch"
	)
	orb.play_jelly_impact(1.0)
	assert_eq(orb._jelly_impact_scale, Vector3(0.80, 1.18, 1.18), "JELLY collision squash")
	await _cleanup(board)
	Config.data.game_mode = original_mode
	Config.data.fx_orb_stretch_enabled = original_stretch
	Config.data.fx_enabled = original_fx


func test_non_jelly_modes_keep_planet_visuals_and_stretch_gate() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_stretch: bool = Config.data.fx_orb_stretch_enabled
	Config.data.game_mode = GameConfig.GameMode.TURN
	Config.data.fx_orb_stretch_enabled = false
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(1, 6, Vector2.ZERO, Vector2(1100.0, 0.0))
	assert_true(not orb._face.visible, "CLASSIC face hidden")
	assert_true(orb._adornment.visible, "CLASSIC planet glow remains")
	assert_eq(orb.visual_stretch_scale(), Vector3.ONE, "CLASSIC stretch setting remains off")
	await _cleanup(board)
	Config.data.game_mode = original_mode
	Config.data.fx_orb_stretch_enabled = original_stretch


func test_jelly_jackpot_uses_max_sparkle_without_planet_prominence() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_fx: bool = Config.data.fx_enabled
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.fx_enabled = true
	Config.data.fx_hitstop_enabled = false
	var root: Node3D = Node3D.new()
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	root.add_child(camera)
	var director: FeedbackDirector = FeedbackDirector.new()
	root.add_child(director)
	tree.root.add_child(root)
	await tree.process_frame
	director.play_reaction_visuals({
		"type": ReactionRules.Type.MAX_CLEAR,
		"position": Vector2.ZERO,
		"result_color": 4,
		"levels": [7, 7],
		"colors": [4, 4],
	})
	assert_eq(director.active_prominence_count(), 0, "JELLY jackpot has no planet prominence")
	assert_eq(director.active_glow_count(), 1, "JELLY jackpot has one MAX rim pulse")
	assert_eq(director.active_ring_count(), 1, "JELLY jackpot has one white ring")
	assert_eq(director.active_particle_count(), 1, "JELLY jackpot has white sparkles")
	await _cleanup(root)
	Config.data.game_mode = original_mode
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop


func test_jelly_visual_toggle_preserves_state_hash() -> void:
	var hidden: String = await _jelly_state_hash(false)
	var visible: String = await _jelly_state_hash(true)
	assert_eq(visible, hidden, "JELLY visual layers do not change state")
	print("JELLY_VISUAL_STATE_HASH hash=%s" % visible.sha256_text())


func _jelly_state_hash(visible: bool) -> String:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var board: Board3D = await _create_board()
	for index: int in range(14):
		var orb: Orb3D = board.spawn_orb(
			index % JellyOrbArt.PALETTE.size(),
			1 + index % Config.data.orb_max_level,
			Vector2(float(index % 4) * 90.0, float(index / 4) * 90.0)
		)
		orb.disable_physics()
		orb._mesh.visible = visible
		orb._face.visible = visible
		orb._blast_outline.visible = visible and orb.is_blast_armed()
		orb._symbol_mesh.visible = visible and Config.data.orb_symbols_enabled
	var state: Array[Dictionary] = []
	for orb: Orb3D in board.get_orbs():
		state.append({
			"id": orb.stable_spawn_id,
			"color": orb.color,
			"level": orb.level,
			"mass": orb.jelly_mass,
			"blast_armed": orb.is_blast_armed(),
			"position": orb.position,
			"velocity": orb.linear_velocity,
		})
	var result: String = JSON.stringify(state)
	await _cleanup(board)
	Config.data.game_mode = original_mode
	return result


func _create_board() -> Board3D:
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	return board


func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await tree.process_frame


func _face_point_on_screen(point: Vector2, face_rotation: float) -> Vector2:
	return point.rotated(-face_rotation)
