extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")


func test_all_levels_keep_celestial_art_inside_collision_radius() -> void:
	var board: Board3D = await _create_board()
	var expected_names: Array[String] = [
		"meteor",
		"moon",
		"rocky_planet",
		"ringed_planet",
		"gas_giant",
		"star",
		"sun",
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
		assert_true(
			orb._adornment.visible == (level == 4 or level >= 6),
			"L%d camera-fixed ring or halo visibility" % level
		)
		if orb._adornment.visible:
			assert_true(
				orb._adornment.scale.x <= collision_radius,
				"L%d adornment stays inside collision radius" % level
			)
	await _cleanup(board)


func test_body_rolls_while_ring_halo_symbol_and_outline_face_camera() -> void:
	var board: Board3D = await _create_board()
	var ringed: Orb3D = board.spawn_orb(OrbTypes.OrbColor.PURPLE, 4, Vector2.ZERO)
	var body: RigidBody3D = ringed.get_physics_body()
	body.rotation = Vector3(0.0, 0.0, 1.1)
	ringed._process(0.0)
	assert_eq(ringed._mesh.rotation, body.rotation, "body art follows physical roll")
	assert_near(
		ringed._adornment.rotation.z,
		CelestialOrbArt.RING_TILT_RADIANS,
		0.0001,
		"L4 ring keeps camera-fixed tilt"
	)
	assert_eq(ringed._symbol_mesh.rotation, Vector3.ZERO, "symbol faces camera")
	assert_eq(ringed._blast_outline.rotation, Vector3.ZERO, "pulse outline faces camera")
	var star: Orb3D = board.spawn_orb(OrbTypes.OrbColor.CYAN, 6, Vector2.ZERO)
	star.get_physics_body().rotation = Vector3(0.0, 0.0, 0.9)
	star._process(0.0)
	assert_eq(star._adornment.rotation, Vector3.ZERO, "L6 halo does not roll")
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
		if orb._blast_outline.visible:
			var before: float = orb.blast_outline_strength()
			orb._physics_process(Config.data.blast_blink_period * 0.25)
			assert_true(
				not is_equal_approx(orb.blast_outline_strength(), before),
				"L%d outline pulses" % level
			)
	await _cleanup(board)


func test_visual_layers_preserve_turn_and_blitz_state_hashes() -> void:
	var turn_hidden: String = await _scripted_state_hash(false, false)
	var turn_visible: String = await _scripted_state_hash(true, false)
	var blitz_hidden: String = await _scripted_state_hash(false, true)
	var blitz_visible: String = await _scripted_state_hash(true, true)
	assert_eq(turn_visible, turn_hidden, "20-turn celestial visual state hash")
	assert_eq(blitz_visible, blitz_hidden, "20-second BLITZ celestial visual state hash")
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
