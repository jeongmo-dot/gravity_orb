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


func test_jelly_blast_ready_face_matches_mockup_c_without_outline() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_jelly_minimum: int = Config.data.jelly_blast_min_level
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_blast_min_level = 5
	var board: Board3D = await _create_board()
	var level_four: Orb3D = board.spawn_orb(0, 4, Vector2(-270.0, 0.0))
	var level_five: Orb3D = board.spawn_orb(3, 5, Vector2(-90.0, 0.0))
	var level_six: Orb3D = board.spawn_orb(4, 6, Vector2(110.0, 0.0))
	var level_seven: Orb3D = board.spawn_orb(1, 7, Vector2(310.0, 0.0))
	var regular_material: ShaderMaterial = level_four._face.material_override as ShaderMaterial
	var blast_material: ShaderMaterial = level_five._face.material_override as ShaderMaterial
	var level_six_material: ShaderMaterial = level_six._face.material_override as ShaderMaterial
	var max_material: ShaderMaterial = level_seven._face.material_override as ShaderMaterial

	assert_true(not bool(regular_material.get_shader_parameter("is_blast_ready")), "L4 keeps normal face")
	assert_true(bool(blast_material.get_shader_parameter("is_blast_ready")), "L5 uses blast-ready face")
	assert_true(bool(level_six_material.get_shader_parameter("is_blast_ready")), "L6 uses blast-ready face")
	assert_true(not bool(max_material.get_shader_parameter("is_blast_ready")), "L7 keeps MAX face")
	assert_true(bool(max_material.get_shader_parameter("is_max")), "L7 remains MAX")
	assert_near(
		level_four._face.scale.x / (level_four.get_current_radius() / Orb3D.PIXELS_PER_METER),
		0.62,
		0.001,
		"L4 normal face scale stays unchanged"
	)
	for orb: Orb3D in [level_five, level_six, level_seven]:
		assert_near(
			orb._face.scale.x / (orb.get_current_radius() / Orb3D.PIXELS_PER_METER),
			1.0,
			0.001,
			"L%d face uses full body-radius plate" % orb.level
		)

	assert_eq(blast_material.get_shader_parameter("blast_eye_outer_top"), Vector2(0.32, -0.16), "blast eye outer top")
	assert_eq(blast_material.get_shader_parameter("blast_eye_inner"), Vector2(0.16, -0.04), "blast eye inner corner")
	assert_eq(blast_material.get_shader_parameter("blast_eye_outer_bottom"), Vector2(0.32, 0.08), "blast eye outer bottom")
	assert_near(float(blast_material.get_shader_parameter("blast_eye_stroke_width")), 0.064, 0.0001, "blast eye stroke")
	assert_eq(blast_material.get_shader_parameter("blast_mouth_center"), Vector2(0.0, 0.22), "blast mouth center")
	assert_eq(blast_material.get_shader_parameter("blast_mouth_radii"), Vector2(0.064, 0.076), "blast mouth radii")
	assert_eq(blast_material.get_shader_parameter("blast_mouth_color"), Color("3a1530"), "blast mouth color")
	assert_eq(blast_material.get_shader_parameter("blast_blush_center"), Vector2(0.48, 0.18), "blast blush center")
	assert_eq(blast_material.get_shader_parameter("blast_blush_radii"), Vector2(0.16, 0.10), "blast blush radii")
	assert_near(float(blast_material.get_shader_parameter("blast_blush_alpha")), 0.60, 0.0001, "blast blush alpha")
	assert_true(
		blast_material.shader.code.contains(
			"face_color = mix(face_color, max_blush_color.rgb, blush_color_mask);"
		),
		"blast and MAX blush keep the source pink and use alpha only"
	)
	for orb: Orb3D in [level_four, level_five, level_six, level_seven]:
		assert_true(not orb._blast_outline.visible, "JELLY L%d always hides BlastOutline" % orb.level)

	await _cleanup(board)
	Config.data.jelly_blast_min_level = original_jelly_minimum
	Config.data.game_mode = original_mode


func test_jelly_belly_uses_mass_fraction_and_transitions_over_point_fifteen_seconds() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var board: Board3D = await _create_board()
	board.set_gravity(Vector2i.RIGHT)
	var orb: Orb3D = board.spawn_orb(2, 3, Vector2.ZERO)
	var belly_material: ShaderMaterial = orb._belly.material_override as ShaderMaterial
	assert_true(not orb._belly.visible, "base L3 mass has no belly jelly")
	assert_eq(belly_material.get_shader_parameter("belly_center"), Vector2(0.12, 0.44), "belly position")
	assert_near(float(belly_material.get_shader_parameter("belly_radius_scale")), 0.54, 0.0001, "belly radius scale")
	assert_eq(
		belly_material.get_shader_parameter("belly_color"),
		JellyOrbArt.color_for(2, 3).lightened(0.35),
		"belly color is body color lightened by 0.35"
	)
	assert_near(float(belly_material.get_shader_parameter("belly_alpha")), 0.85, 0.0001, "belly alpha")
	assert_near(
		float(belly_material.get_shader_parameter("highlight_alpha")),
		0.70,
		0.0001,
		"belly highlight alpha"
	)
	assert_true(belly_material.shader.code.contains("sqrt(fraction)"), "belly radius uses square-root fill")

	orb.set_jelly_mass(6.0, Config.data)
	assert_near(orb._jelly_belly_target, 0.5, 0.0001, "mass six targets half-full belly")
	assert_near(orb.get_radius(), Config.data.radius_for_level(3), 0.001, "partial L3 keeps L3 radius")
	orb._process(0.075)
	assert_near(orb._jelly_belly_fraction, 0.25, 0.0001, "belly reaches midpoint after 0.075 seconds")
	assert_true(orb._belly.visible, "belly appears during fill transition")
	orb._process(0.075)
	assert_near(orb._jelly_belly_fraction, 0.5, 0.0001, "belly reaches target after 0.15 seconds")
	assert_near(orb._belly.rotation.z, orb._jelly_frame_rotation, 0.0001, "belly follows gravity frame")
	assert_true(orb._belly.position.z < orb._face.position.z, "belly stays behind face")
	assert_true(orb._belly.position.z > orb._mesh.position.z, "belly stays in front of body center")

	orb.set_jelly_mass(8.0, Config.data)
	assert_near(orb.get_current_radius(), Config.data.radius_for_level(3), 0.001, "level-up starts at old level radius")
	orb._physics_process(0.05)
	assert_near(orb.get_current_radius(), 72.5, 0.001, "level-up radius is halfway after 0.05 seconds")
	orb._physics_process(0.05)
	assert_near(orb.get_current_radius(), Config.data.radius_for_level(4), 0.001, "level-up radius finishes at 0.10 seconds")
	orb._process(0.15)
	assert_near(orb._jelly_belly_fraction, 0.0, 0.0001, "new exact level clears belly over 0.15 seconds")
	assert_true(not orb._belly.visible, "zero fill hides belly mesh")
	orb.set_jelly_mass(64.0, Config.data)
	assert_eq(orb.level, Config.data.orb_max_level, "mass cap displays L7")
	assert_near(orb._jelly_belly_target, 0.0, 0.0001, "L7 mass cap always has zero belly fill")
	await _cleanup(board)
	Config.data.game_mode = original_mode


func test_max_face_projects_smile_below_eyes_and_stays_upright() -> void:
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
	var down_eyes: Vector2 = eye_center
	var down_smile: Vector2 = smile_center
	var down_highlight: Vector2 = left_eye_center + highlight_offset
	var down_left_eye: Vector2 = left_eye_center
	assert_true(down_smile.y > down_eyes.y, "down gravity puts MAX smile below eyes")
	assert_true(
		down_highlight.y < down_left_eye.y,
		"down gravity keeps reflection above the eyes"
	)
	assert_true(down_highlight.x < down_left_eye.x, "reflection stays on the left")
	orb.set_gravity(Vector2i.RIGHT, Config.data.gravity_strength)
	assert_true(
		smile_center.y > eye_center.y,
		"right gravity keeps the MAX smile below the eyes"
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


func test_jelly_deform_follows_gravity_smoothly_and_squashes_on_speed_loss() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_stretch: bool = Config.data.fx_orb_stretch_enabled
	var original_fx: bool = Config.data.fx_enabled
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.fx_enabled = true
	Config.data.fx_orb_stretch_enabled = false
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(0, 3, Vector2.ZERO)
	orb.set_gravity(Vector2i.DOWN, Config.data.gravity_strength)
	orb.linear_velocity = Vector2(0.0, 1100.0)
	orb._process(1.0 / 120.0)
	var falling_deform: Vector2 = orb._jelly_deform
	assert_true(falling_deform.x < 1.0, "falling JELLY narrows across gravity")
	assert_true(falling_deform.y > 1.0, "falling JELLY stretches along gravity")
	assert_true(
		falling_deform.y < 1.19,
		"deform follows the target instead of jumping there in one frame"
	)
	orb.linear_velocity = Vector2(0.0, 1100.0)
	orb.get_physics_body().linear_velocity = Vector3.ZERO
	orb._physics_process(1.0 / 120.0)
	assert_near(orb._jelly_impact, 1.0, 0.001, "speed loss drives impact without contact event")
	orb._process(1.0 / 120.0)
	assert_true(orb._jelly_deform.x > falling_deform.x, "impact widens across gravity")
	assert_true(orb._jelly_deform.y < falling_deform.y, "impact flattens along gravity")
	var face_radius_m: float = orb.get_current_radius() / Orb3D.PIXELS_PER_METER * 0.62
	assert_near(
		orb._face.scale.x / face_radius_m,
		orb._mesh.scale.x / orb._visual_punch_scale.x,
		0.001,
		"face and body share horizontal deform"
	)
	assert_near(
		orb._face.scale.y / face_radius_m,
		orb._mesh.scale.y / orb._visual_punch_scale.y,
		0.001,
		"face and body share gravity-axis deform"
	)
	await _cleanup(board)
	Config.data.game_mode = original_mode
	Config.data.fx_orb_stretch_enabled = original_stretch
	Config.data.fx_enabled = original_fx


func test_jelly_face_and_symbol_stay_in_front_of_deformed_body() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(0, 7, Vector2.ZERO)
	var body_mesh: SphereMesh = orb._mesh.mesh as SphereMesh

	orb._jelly_deform = Vector2(1.18, 0.80)
	orb._update_visual_transform()
	var squash_front_z: float = orb._mesh.position.z + body_mesh.radius * orb._mesh.scale.z
	assert_true(orb._face.position.z > squash_front_z, "face stays ahead at maximum squash")
	assert_true(orb._symbol_mesh.position.z > squash_front_z, "symbol stays ahead at maximum squash")

	orb._jelly_deform = Vector2.ONE
	orb._jelly_breath_weight = 1.0
	orb._jelly_idle_elapsed = PI / (2.0 * 1.8)
	orb._update_visual_transform()
	var breath_front_z: float = orb._mesh.position.z + body_mesh.radius * orb._mesh.scale.z
	assert_true(orb._face.position.z > breath_front_z, "face stays ahead at L7 breath peak")
	assert_true(orb._symbol_mesh.position.z > breath_front_z, "symbol stays ahead at L7 breath peak")

	orb._visual_punch_scale = Vector3.ONE * 1.18
	var punch_front_z: float = orb._mesh.position.z + body_mesh.radius * orb._mesh.scale.z
	assert_true(orb._face.position.z > punch_front_z, "face stays ahead during merge punch")
	assert_true(orb._symbol_mesh.position.z > punch_front_z, "symbol stays ahead during merge punch")
	await _cleanup(board)
	Config.data.game_mode = original_mode


func test_new_jelly_frame_starts_at_first_gravity_then_turns_smoothly() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var board: Board3D = await _create_board()
	var directions: Array[Vector2i] = [
		Vector2i.UP,
		Vector2i.LEFT,
		Vector2i.RIGHT,
	]
	for direction: Vector2i in directions:
		board.set_gravity(direction)
		var orb: Orb3D = board.spawn_orb(0, 3, Vector2.ZERO)
		assert_near(
			orb._jelly_frame_rotation,
			orb._jelly_frame_target_rotation,
			0.0001,
			"new JELLY starts at %s gravity angle" % direction
		)
		board.remove_orb(orb)

	board.set_gravity(Vector2i.DOWN)
	var turning: Orb3D = board.spawn_orb(0, 3, Vector2.ZERO)
	board.set_gravity(Vector2i.RIGHT)
	turning._process(1.0 / 120.0)
	assert_true(turning._jelly_frame_rotation > 0.0, "existing JELLY begins turning")
	assert_true(
		turning._jelly_frame_rotation < turning._jelly_frame_target_rotation,
		"existing JELLY does not jump when gravity changes"
	)
	await _cleanup(board)
	Config.data.game_mode = original_mode


func test_jelly_frame_rotation_and_breath_weight_change_without_jumps() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(0, 3, Vector2.ZERO)
	orb.set_gravity(Vector2i.RIGHT, Config.data.gravity_strength)
	orb._process(1.0 / 120.0)
	assert_true(orb._jelly_frame_rotation > 0.0, "JELLY frame begins turning toward gravity")
	assert_true(
		orb._jelly_frame_rotation < orb._jelly_frame_target_rotation,
		"JELLY frame does not jump to the target rotation"
	)
	assert_near(orb._mesh.rotation.z, orb._jelly_frame_rotation, 0.0001, "body uses frame rotation")
	var expected_face_basis: Basis = Orb3D.jelly_upright_deform_basis(
		orb._jelly_frame_rotation,
		orb._jelly_render_deform(),
		orb.get_current_radius() / Orb3D.PIXELS_PER_METER * 0.62
	)
	_assert_basis_near(orb._face.basis, expected_face_basis, 0.0001, "face counter-rotates frame")
	board.set_turn_resting(true)
	orb._process(1.0 / 120.0)
	assert_near(
		orb._jelly_breath_weight,
		1.0 / 30.0,
		0.0001,
		"breathing fades in at delta times four"
	)
	board.set_turn_resting(false)
	orb._process(1.0 / 120.0)
	assert_near(orb._jelly_breath_weight, 0.0, 0.0001, "breathing fades back out")
	await _cleanup(board)
	Config.data.game_mode = original_mode


func test_all_jelly_faces_and_symbols_stay_upright_with_screen_axis_deform() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_minimum: int = Config.data.jelly_blast_min_level
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_blast_min_level = 5
	var board: Board3D = await _create_board()
	var directions: Array[Vector2i] = [
		Vector2i.DOWN,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.LEFT,
	]
	for direction: Vector2i in directions:
		board.set_gravity(direction)
		var orb: Orb3D = board.spawn_orb(3, 5, Vector2.ZERO)
		orb._jelly_deform = Vector2(0.82, 1.16)
		orb._update_visual_transform()
		assert_near(orb._face.rotation.z, 0.0, 0.0001, "%s face remains upright" % direction)
		assert_near(orb._symbol_mesh.rotation.z, 0.0, 0.0001, "%s symbol remains upright" % direction)
		var face_radius_m: float = orb.get_current_radius() / Orb3D.PIXELS_PER_METER
		var expected_basis: Basis = Orb3D.jelly_upright_deform_basis(
			orb._jelly_frame_rotation,
			orb._jelly_render_deform(),
			face_radius_m
		)
		_assert_basis_near(orb._face.basis, expected_basis, 0.0001, "%s face deform" % direction)
		if direction == Vector2i.RIGHT:
			assert_near(
				Vector2(orb._face.basis.x.x, orb._face.basis.x.y).length() / face_radius_m,
				1.16,
				0.001,
				"right gravity maps gravity-axis deform to screen horizontal"
			)
			assert_near(
				Vector2(orb._face.basis.y.x, orb._face.basis.y.y).length() / face_radius_m,
				0.82,
				0.001,
				"right gravity maps cross-axis deform to screen vertical"
			)
		board.remove_orb(orb)
	await _cleanup(board)
	Config.data.jelly_blast_min_level = original_minimum
	Config.data.game_mode = original_mode


func test_jelly_impact_ignores_small_speed_loss_and_decays_per_step() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(0, 3, Vector2.ZERO)
	orb.linear_velocity = Vector2(1000.0, 0.0)
	orb.get_physics_body().linear_velocity = Orb3D.plane_vector_to_world(Vector2(950.0, 0.0))
	orb._physics_process(1.0 / 120.0)
	assert_near(orb._jelly_impact, 0.0, 0.0001, "speed loss below 0.06 is ignored")
	orb.linear_velocity = Vector2(1000.0, 0.0)
	orb.get_physics_body().linear_velocity = Orb3D.plane_vector_to_world(Vector2(900.0, 0.0))
	orb._physics_process(1.0 / 120.0)
	assert_near(orb._jelly_impact, 0.1, 0.0001, "speed loss divided by 1000 starts impact")
	orb._physics_process(1.0 / 120.0)
	assert_near(orb._jelly_impact, 0.06, 0.0001, "impact decays by 4.8 per second")
	await _cleanup(board)
	Config.data.game_mode = original_mode


func test_jelly_landing_deform_uses_gravity_frame_in_all_four_directions() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var board: Board3D = await _create_board()
	var directions: Array[Vector2i] = [
		Vector2i.DOWN,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.LEFT,
	]
	for direction: Vector2i in directions:
		var orb: Orb3D = board.spawn_orb(0, 3, Vector2.ZERO)
		orb.set_gravity(direction, Config.data.gravity_strength)
		orb.linear_velocity = Vector2(direction) * 1100.0
		orb._process(1.0 / 120.0)
		assert_true(orb._jelly_deform.x < 1.0, "%s fall narrows across gravity" % direction)
		assert_true(orb._jelly_deform.y > 1.0, "%s fall stretches along gravity" % direction)
		orb.linear_velocity = Vector2(direction) * 1100.0
		orb.get_physics_body().linear_velocity = Vector3.ZERO
		orb._physics_process(1.0 / 120.0)
		orb._process(1.0 / 120.0)
		assert_true(orb._jelly_deform.x > 1.0, "%s landing widens across gravity" % direction)
		assert_true(orb._jelly_deform.y < 1.0, "%s landing flattens along gravity" % direction)
		board.remove_orb(orb)
	await _cleanup(board)
	Config.data.game_mode = original_mode


func test_interpolation_smooths_120hz_physics_for_164hz_rendering() -> void:
	var velocity: float = 900.0
	var physics_hz: float = 120.0
	var render_hz: float = 164.0
	var physics_step_distance: float = velocity / physics_hz
	var raw_positions: Array[float] = []
	var interpolated_positions: Array[float] = []
	for render_frame: int in range(1, 165):
		var physics_time: float = float(render_frame) / render_hz * physics_hz
		var current_tick: int = floori(physics_time)
		var fraction: float = physics_time - float(current_tick)
		raw_positions.append(float(current_tick) * physics_step_distance)
		interpolated_positions.append(
			(float(current_tick - 1) + fraction) * physics_step_distance
		)
	var raw_variation: float = _step_variation_ratio(raw_positions)
	var interpolated_variation: float = _step_variation_ratio(interpolated_positions)
	assert_true(raw_variation > 0.25, "120-to-164Hz raw positions have visibly uneven steps")
	assert_true(
		interpolated_variation < 0.001,
		"interpolated render movement has near-zero step variation"
	)
	assert_true(
		interpolated_variation < raw_variation,
		"interpolation reduces frame-to-frame movement variation"
	)


func test_visual_position_interpolates_and_teleport_resets_history() -> void:
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(0, 1, Vector2.ZERO)
	orb._previous_physics_position = Vector3(0.0, 0.0, 0.0)
	orb._current_physics_position = Vector3(2.0, -1.0, 0.0)
	orb._physics_position_initialized = true
	assert_eq(orb.interpolated_body_position(0.0), Vector3.ZERO, "fraction zero uses previous position")
	assert_eq(
		orb.interpolated_body_position(0.5),
		Vector3(1.0, -0.5, 0.0),
		"fraction half uses midpoint"
	)
	assert_eq(
		orb.interpolated_body_position(1.0),
		Vector3(2.0, -1.0, 0.0),
		"fraction one uses current position"
	)
	orb.position = Vector2(250.0, -150.0)
	assert_eq(
		orb._previous_physics_position,
		orb._current_physics_position,
		"teleport resets interpolation history"
	)
	assert_eq(
		orb.interpolated_body_position(0.0),
		Orb3D.plane_position_to_world(Vector2(250.0, -150.0)),
		"first frame after teleport does not drag from the old position"
	)
	await _cleanup(board)


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


func _assert_basis_near(actual: Basis, expected: Basis, tolerance: float, context: String) -> void:
	assert_true(actual.x.distance_to(expected.x) <= tolerance, "%s x basis" % context)
	assert_true(actual.y.distance_to(expected.y) <= tolerance, "%s y basis" % context)
	assert_true(actual.z.distance_to(expected.z) <= tolerance, "%s z basis" % context)


func _step_variation_ratio(positions: Array[float]) -> float:
	var steps: Array[float] = []
	for index: int in range(1, positions.size()):
		steps.append(positions[index] - positions[index - 1])
	var mean: float = 0.0
	for step: float in steps:
		mean += step
	mean /= float(steps.size())
	var variance: float = 0.0
	for step: float in steps:
		variance += (step - mean) * (step - mean)
	variance /= float(steps.size())
	return sqrt(variance) / maxf(absf(mean), 0.000001)
