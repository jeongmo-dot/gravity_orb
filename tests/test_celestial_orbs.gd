extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")


func test_all_levels_keep_celestial_art_inside_collision_radius() -> void:
	var board: Board3D = await _create_board()
	var expected_names: Array[String] = [
		"planet_l1",
		"planet_l2",
		"planet_l3",
		"planet_l4",
		"planet_l5",
		"planet_l6",
		"planet_l7",
	]
	for level: int in range(1, Config.data.orb_max_level + 1):
		var orb: Orb3D = board.spawn_orb(
			level % Config.data.color_display.size(),
			level,
			Vector2.ZERO
		)
		var collision_radius: float = orb.shape_resource().radius
		assert_eq(CelestialOrbArt.level_name(level), expected_names[level - 1], "L%d art" % level)
		assert_true(
			orb.mesh_resource().radius <= collision_radius,
			"L%d body stays inside collision radius" % level
		)
		var expected_ratio: float = 0.94 if level <= 5 else (0.86 if level == 6 else 0.82)
		assert_near(CelestialOrbArt.body_radius_ratio(level), expected_ratio, 0.0001, "L%d body ratio" % level)
		assert_true(
			orb._adornment.visible == (level >= 6),
			"L%d camera-fixed planet glow visibility" % level
		)
		if orb._adornment.visible:
			assert_true(
				orb._adornment.scale.x <= collision_radius,
				"L%d adornment stays inside collision radius" % level
			)
	await _cleanup(board)


func test_body_shader_uses_six_seamless_planet_patterns() -> void:
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 5, Vector2.ZERO)
	var material: ShaderMaterial = orb.visual_material_resource()
	var shader_code: String = material.shader.code
	assert_true(
		shader_code.contains("value_noise3(body_position"),
		"body patterns sample local 3D surface position"
	)
	assert_true(
		not shader_code.contains("value_noise(art_uv"),
		"body patterns do not sample the UV seam"
	)
	assert_true(
		shader_code.contains("sphere_spot(body_position"),
		"craters and storms follow the sphere surface"
	)
	for color_id: int in range(Config.data.color_display.size()):
		assert_true(
			shader_code.contains("color_id == %d" % color_id) or color_id == 5,
			"planet color %d has a shader branch" % color_id
		)
	await _cleanup(board)


func test_reviewed_planets_use_soft_surface_landmarks() -> void:
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 5, Vector2.ZERO)
	var shader_code: String = orb.visual_material_resource().shader.code
	assert_true(
		shader_code.contains("float fractal_noise3(vec3 p)"),
		"reviewed surfaces blend multiple scales of smoothly interpolated 3D noise"
	)
	assert_true(
		shader_code.contains("continent_primary")
		and shader_code.contains("continent_secondary")
		and shader_code.contains("cloud_filament"),
		"Earth uses large continent masses and flowing cloud filaments"
	)
	assert_true(
		shader_code.contains("dust_zone")
		and shader_code.contains("canyon_path")
		and shader_code.contains("canyon_tilt = 0.268")
		and shader_code.contains("canyon_end_fade")
		and shader_code.contains("canyon_branch")
		and shader_code.contains("canyon_half_width = 0.028 + canyon_noise * 0.044")
		and shader_code.contains("canyon_branch_one_side")
		and shader_code.contains("canyon_branch_half_width")
		and shader_code.contains("polar_boundary_noise")
		and shader_code.contains("polar_tilt = radians(35.0)")
		and shader_code.contains("normalize(vec3(0.0, cos(polar_tilt), sin(polar_tilt)))")
		and shader_code.contains("dot(body_position, polar_axis)")
		and shader_code.contains("polar_boundary_noise - 0.5) * 0.060")
		and shader_code.contains("smoothstep(0.866, 0.914, polar)")
		and shader_code.contains("crater_d")
		and not shader_code.contains("abs(n2 - 0.52)"),
		"Mars uses a broad one-sided Y canyon, tilted polar cap, and asymmetric craters"
	)
	assert_true(
		shader_code.contains("uranus_band_contrast = 0.05")
		and shader_code.contains("ring_radius - 0.78")
		and not shader_code.contains("vertical_bands"),
		"Uranus uses subtle atmosphere bands and a tilted ellipse ring"
	)
	await _cleanup(board)


func test_mars_preview_polar_cap_is_an_inset_flattened_round_piece() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/core/OrbVisual.gd")
	assert_true(
		source.contains("x * 0.36")
		and source.contains("-0.60 + sin(angle) * 0.20 + boundary_noise")
		and source.contains("sin(x * 10.0 + 0.35) * 0.024")
		and source.contains("sin(x * 21.0 - 0.80) * 0.016"),
		"Mars preview uses the specified inset 0.36 by 0.20 noisy polar piece"
	)
	assert_true(
		not source.contains("lerpf(-0.70, 0.70, progress)"),
		"Mars preview no longer draws a full-width polar band"
	)


func test_l6_l7_shader_uses_deterministic_planet_glow() -> void:
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.YELLOW, 7, Vector2.ZERO)
	var shader_code: String = orb.visual_material_resource().shader.code
	assert_true(
		shader_code.contains("uniform float animation_time"),
		"animated planet patterns use a script-controlled time uniform"
	)
	assert_true(
		not shader_code.contains("TIME"),
		"planet shader has no nondeterministic engine TIME dependency"
	)
	assert_true(
		shader_code.contains("level_id == 7 ? 0.96 : 0.78"),
		"L7 outline glow is brighter than L6"
	)
	CelestialOrbArt.freeze_animation_for_capture()
	assert_near(
		float(orb.visual_material_resource().get_shader_parameter("animation_time")),
		CelestialOrbArt.CAPTURE_ANIMATION_TIME,
		0.0001,
		"capture shader time is fixed"
	)
	CelestialOrbArt.unfreeze_animation()
	await _cleanup(board)


func test_body_rolls_while_glow_symbol_and_outline_face_camera() -> void:
	var board: Board3D = await _create_board()
	var planet: Orb3D = board.spawn_orb(OrbTypes.OrbColor.PURPLE, 4, Vector2.ZERO)
	var body: RigidBody3D = planet.get_physics_body()
	body.rotation = Vector3(0.0, 0.0, 1.1)
	planet._process(0.0)
	assert_eq(planet._mesh.rotation, body.rotation, "body art follows physical roll")
	assert_true(not planet._adornment.visible, "L4 no longer uses a planetary ring adornment")
	assert_eq(planet._symbol_mesh.rotation, Vector3.ZERO, "symbol faces camera")
	assert_eq(planet._blast_outline.rotation, Vector3.ZERO, "pulse outline faces camera")
	var star: Orb3D = board.spawn_orb(OrbTypes.OrbColor.CYAN, 6, Vector2.ZERO)
	star.get_physics_body().rotation = Vector3(0.0, 0.0, 0.9)
	star._process(0.0)
	assert_eq(star._adornment.rotation, Vector3.ZERO, "L6 planet glow does not roll")
	await _cleanup(board)


func test_celestial_materials_and_adornments_remain_shared() -> void:
	Orb3D.clear_shared_resource_cache()
	var board: Board3D = await _create_board()
	var materials: Dictionary = {}
	var adornment_meshes: Dictionary = {}
	for color: int in range(Config.data.color_display.size()):
		for level: int in range(1, Config.data.orb_max_level + 1):
			var first: Orb3D = board.spawn_orb(color, level, Vector2.ZERO)
			var second: Orb3D = board.spawn_orb(color, level, Vector2.ZERO)
			assert_eq(
				first.visual_material_resource(),
				second.visual_material_resource(),
				"color %d L%d shares material" % [color, level]
			)
			materials[first.visual_material_resource().get_instance_id()] = true
			adornment_meshes[first.adornment_mesh_resource().get_instance_id()] = true
	assert_true(
		materials.size() <= Config.data.color_display.size() * Config.data.orb_max_level,
		"celestial materials are bounded by color times level"
	)
	assert_eq(adornment_meshes.size(), 1, "all camera-fixed layers share one mesh")
	await _cleanup(board)


func test_preview_uses_same_level_and_color_art_profile() -> void:
	var board: Board3D = await _create_board()
	var preview: OrbVisual = OrbVisual.new()
	tree.root.add_child(preview)
	for color: int in range(Config.data.color_display.size()):
		for level: int in range(1, Config.data.orb_max_level + 1):
			var orb: Orb3D = board.spawn_orb(color, level, Vector2.ZERO)
			preview.setup_celestial_preview(
				Config.data.color_display[color],
				Config.data.radius_for_level(level),
				level,
				color,
				true
			)
			assert_eq(preview.celestial_art_key(), orb.celestial_art_key(), "preview art key")
			assert_true(preview.has_symbol(), "preview symbol is enabled")
			preview.set_symbols_enabled(false)
			assert_true(not preview.has_symbol(), "preview symbol toggle is retained")
	preview.queue_free()
	await _cleanup(board)


func test_pulse_outline_is_only_visible_for_level_four_and_above() -> void:
	var board: Board3D = await _create_board()
	for level: int in range(1, Config.data.orb_max_level + 1):
		var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, level, Vector2.ZERO)
		assert_true(
			orb._blast_outline.visible == (level >= Config.data.active_blast_min_level()),
			"L%d outline visibility" % level
		)
		assert_eq(
			CelestialOrbArt.blast_pulse_style(level),
			"" if level < 4 else ("rim" if level <= 5 else "glow"),
			"L%d uses the specified integrated pulse style" % level
		)
		if orb._blast_outline.visible:
			var before: float = orb.blast_outline_strength()
			var scale_before: float = orb.blast_pulse_scale()
			orb._physics_process(Config.data.blast_blink_period * 0.25)
			assert_true(
				not is_equal_approx(orb.blast_outline_strength(), before),
				"L%d outline pulses" % level
			)
			if level >= 6:
				assert_true(
					not is_equal_approx(orb.blast_pulse_scale(), scale_before),
					"L%d glow size pulses" % level
				)
			else:
				assert_eq(orb.blast_pulse_scale(), 1.0, "L%d rim does not detach" % level)
	await _cleanup(board)


func test_visual_layers_preserve_turn_and_blitz_state_hashes() -> void:
	var turn_hidden: String = await _scripted_state_hash(false, false)
	var turn_visible: String = await _scripted_state_hash(true, false)
	var blitz_hidden: String = await _scripted_state_hash(false, true)
	var blitz_visible: String = await _scripted_state_hash(true, true)
	assert_eq(turn_visible, turn_hidden, "20-turn celestial visual state hash")
	assert_eq(blitz_visible, blitz_hidden, "20-second BLITZ celestial visual state hash")
	assert_eq(
		turn_visible.sha256_text(),
		"a27323b13e998dd0f41ff351aec47262dbe08108184d2d988af79aa829e8a724",
		"turn state hash remains identical to #74"
	)
	assert_eq(
		blitz_visible.sha256_text(),
		"92eedf120de217f8760de532bd55bf12ad1ae82dff9bd4bc218e42a553ccbc80",
		"BLITZ state hash remains identical to #74"
	)
	print("CELESTIAL_PHYSICS_HASH turn=%s blitz=%s" % [turn_visible.sha256_text(), blitz_visible.sha256_text()])


func _create_board() -> Board3D:
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	return board


func _scripted_state_hash(visuals_visible: bool, blitz: bool) -> String:
	var board: Board3D = await _create_board()
	for index: int in range(20):
		var direction: Vector2i = OrbTypes.DIRECTIONS[index % OrbTypes.DIRECTIONS.size()]
		board.set_gravity(direction)
		var color: int = (index + (2 if blitz else 0)) % Config.data.color_display.size()
		var level: int = 1 + index % Config.data.orb_max_level
		var position: Vector2 = Vector2(float(index % 5) * 100.0, float(index / 5) * 100.0)
		var orb: Orb3D = board.spawn_orb(color, level, position)
		orb.get_physics_body().freeze = true
		orb._mesh.visible = visuals_visible
		orb._adornment.visible = visuals_visible and CelestialOrbArt.has_adornment(level)
		orb._blast_outline.visible = visuals_visible and orb.is_blast_armed()
		orb._symbol_mesh.visible = visuals_visible and Config.data.orb_symbols_enabled
	var state: Array[Dictionary] = []
	for orb: Orb3D in board.get_orbs():
		state.append({
			"id": orb.stable_spawn_id,
			"color": orb.color,
			"level": orb.level,
			"position": orb.position,
			"velocity": orb.linear_velocity,
		})
	var hash_value: String = JSON.stringify(state)
	await _cleanup(board)
	return hash_value


func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await tree.process_frame
