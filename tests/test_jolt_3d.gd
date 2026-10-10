extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")


func test_project_uses_jolt_with_3d_main_and_keeps_2d_scene() -> void:
	assert_eq(
		str(ProjectSettings.get_setting("physics/3d/physics_engine", "")),
		"Jolt Physics",
		"3D engine"
	)
	assert_eq(
		str(ProjectSettings.get_setting("application/run/main_scene", "")),
		"res://scenes/Main3D.tscn",
		"3D scene is the project entry point"
	)
	assert_true(ResourceLoader.exists("res://scenes/Main.tscn"), "2D scene remains available")
	assert_eq(
		int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 0)),
		120,
		"adopted Jolt tick rate"
	)
	assert_eq(
		int(ProjectSettings.get_setting(
			"physics/jolt_physics_3d/simulation/position_steps",
			2
		)),
		4,
		"second-round position solver steps"
	)
	assert_eq(
		int(ProjectSettings.get_setting("threading/worker_pool/max_threads", -1)),
		1,
		"single worker avoids Jolt job queue warning"
	)


func test_main_3d_camera_fits_vertical_board_mockup() -> void:
	var main_scene: PackedScene = load("res://scenes/Main3D.tscn") as PackedScene
	var main: Main = main_scene.instantiate() as Main
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	assert_near(camera.fov, 25.0, 0.001, "reduced perspective FOV")
	assert_near(camera.position.z, 42.0, 0.001, "board and tilt margin distance")
	main.free()


func test_orb_3d_exposes_pixel_plane_api_and_locks_depth() -> void:
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(125.0, -75.0),
		Vector2(40.0, 20.0)
	)
	assert_near(orb.position.x, 125.0, 0.001, "plane x remains in pixels")
	assert_near(orb.position.y, -75.0, 0.001, "plane y remains in pixels")
	assert_near(orb.get_radius(), 25.0, 0.001, "radius remains in pixels")
	var body: RigidBody3D = orb.get_physics_body()
	assert_near(body.position.x, 1.25, 0.001, "plane x converts to world x")
	assert_near(body.position.y, 0.75, 0.001, "screen-up converts to world positive y")
	assert_near(body.linear_velocity.x, 0.4, 0.001, "plane velocity x converts to m/s")
	assert_near(body.linear_velocity.y, -0.2, 0.001, "screen-down velocity flips world y")
	assert_true(body.axis_lock_linear_z, "depth axis is locked")
	assert_true(body.axis_lock_angular_x, "x rotation is locked")
	assert_true(body.axis_lock_angular_y, "y rotation is locked")
	assert_near(
		(body.constant_force / body.mass).y,
		-Config.data.gravity_strength / Orb3D.PIXELS_PER_METER,
		0.001,
		"screen-down gravity converts to negative world y"
	)
	_cleanup(board)


func test_level_gravity_scale_accelerates_large_orbs() -> void:
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		7,
		Vector2.ZERO
	)
	var body: RigidBody3D = orb.get_physics_body()
	assert_near(
		(body.constant_force / body.mass).y,
		-Config.data.gravity_for_level(7) / Orb3D.PIXELS_PER_METER,
		0.001,
		"level seven scaled gravity"
	)
	_cleanup(board)


func test_merged_result_uses_new_level_gravity() -> void:
	var fixture_root: Node = Node.new()
	fixture_root.name = "JoltMergedGravityFixture"
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	fixture_root.add_child(board)
	board.owner = fixture_root
	var resolver: CollisionResolver = RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	fixture_root.add_child(resolver)
	resolver.owner = fixture_root
	tree.root.add_child(fixture_root)
	await tree.process_frame
	var control: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(300.0, -300.0)
	)
	var first: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2(-25.0, 0.0)
	)
	var second: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2(25.0, 0.0)
	)
	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "L1 pair merges once")
	var merged: Orb3D
	for orb: Orb3D in board.get_orbs():
		if orb.level == 2:
			merged = orb
	assert_true(merged != null, "merge creates L2 result")
	if merged != null:
		var merged_body: RigidBody3D = merged.get_physics_body()
		assert_near(
			merged_body.constant_force.length(),
			merged_body.mass
			* Config.data.gravity_strength
			* (1.0 + Config.data.gravity_level_scale)
			/ Orb3D.PIXELS_PER_METER,
			0.001,
			"merged L2 force uses the 1.25 level multiplier"
		)
	var control_body: RigidBody3D = control.get_physics_body()
	assert_near(
		control_body.constant_force.length(),
		control_body.mass * Config.data.gravity_strength / Orb3D.PIXELS_PER_METER,
		0.001,
		"same-board L1 force uses the 1.0 multiplier"
	)
	_cleanup(fixture_root)


func test_new_color_3d_materials_match_display_table() -> void:
	var board: Board3D = await _create_board()
	var colors: Array[int] = [
		OrbTypes.OrbColor.PURPLE,
		OrbTypes.OrbColor.CYAN,
	]
	for index: int in range(colors.size()):
		var color: int = colors[index]
		var orb: Orb3D = board.spawn_orb(
			color,
			1,
			Vector2(float(index * 100), 0.0)
		)
		var material: StandardMaterial3D = (
			orb._mesh.material_override as StandardMaterial3D
		)
		assert_true(material != null, "new color uses a 3D material")
		if material != null:
			assert_eq(
				material.albedo_color,
				Config.data.color_display[color],
				"3D material uses configured new color"
			)
	_cleanup(board)


func test_3d_blast_armed_orb_blinks_emission_by_level() -> void:
	var board: Board3D = await _create_board()
	var level_four: Orb3D = board.spawn_orb(0, 4, Vector2(-100.0, 0.0))
	var level_five: Orb3D = board.spawn_orb(1, 5, Vector2(100.0, 0.0))
	var level_six: Orb3D = board.spawn_orb(2, 6, Vector2(0.0, 150.0))
	assert_true(not level_four.is_blast_armed(), "3D L4 is not armed")
	assert_true(not level_five.is_blast_armed(), "3D L5 is not armed")
	assert_true(level_six.is_blast_armed(), "3D L6 is armed")
	var initial_strength: float = level_six.blast_emission_strength()
	level_six._physics_process(Config.data.blast_blink_period * 0.25)
	assert_true(
		not is_equal_approx(level_six.blast_emission_strength(), initial_strength),
		"3D armed emission oscillates"
	)
	_cleanup(board)


func test_3d_blitz_blink_starts_at_level_four() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	var board: Board3D = await _create_board()
	var level_three: Orb3D = board.spawn_orb(0, 3, Vector2(-100.0, 0.0))
	var level_four: Orb3D = board.spawn_orb(1, 4, Vector2(100.0, 0.0))
	assert_true(not level_three.is_blast_armed(), "BLITZ L3 is not armed")
	assert_true(level_four.is_blast_armed(), "BLITZ L4 is armed")
	_cleanup(board)
	Config.data.game_mode = original_mode


func test_jolt_reaction_uses_shared_rules_and_spawns_3d_result() -> void:
	var fixture_root: Node = Node.new()
	fixture_root.name = "JoltReactionFixture"
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	fixture_root.add_child(board)
	board.owner = fixture_root
	var resolver: CollisionResolver = RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	fixture_root.add_child(resolver)
	resolver.owner = fixture_root
	tree.root.add_child(fixture_root)
	await tree.process_frame
	var first: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, Vector2(-25.0, 0.0))
	var second: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, Vector2(25.0, 0.0))
	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "one shared rule reaction")
	var active: Array[Orb3D] = board.get_orbs()
	assert_eq(active.size(), 1, "two inputs replaced by one result")
	assert_eq(active[0].level, 2, "shared ReactionRules level")
	assert_eq(active[0].color, OrbTypes.OrbColor.GREEN, "shared ReactionRules color")
	var result: Orb3D = active[0]
	var partner: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		2,
		result.position
	)
	resolver.report_contact(result, partner)
	assert_eq(resolver.flush(), 0, "shared 3D result lock defers the next reaction")
	var tick: float = 1.0 / float(Engine.physics_ticks_per_second)
	var delay_frames: int = roundi(Config.data.chain_reaction_delay / tick)
	for frame_index: int in range(delay_frames):
		var applied: int = resolver.flush(tick)
		if frame_index < delay_frames - 1:
			assert_eq(applied, 0, "shared 3D lock remains active")
		else:
			assert_eq(applied, 1, "shared 3D lock releases on the configured tick")
	active = board.get_orbs()
	assert_eq(active.size(), 1, "shared 3D chain leaves one result")
	if active.size() == 1:
		assert_eq(active[0].level, 3, "shared 3D delayed result level")
	_cleanup(fixture_root)


func test_spawner_3d_reuses_spawner_rng_sequence() -> void:
	var first: Spawner = SPAWNER_SCRIPT.new() as Spawner
	var second: Spawner = SPAWNER_SCRIPT.new() as Spawner
	tree.root.add_child(first)
	tree.root.add_child(second)
	await tree.process_frame
	first.init_rng(101)
	second.init_rng(101)
	first.sync_next_batch_size(1)
	second.sync_next_batch_size(1)
	assert_eq(first.peek_next(), second.peek_next(), "same shared RNG seed")
	_cleanup(first)
	_cleanup(second)


func _create_board() -> Board3D:
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	return board


func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await tree.process_frame
