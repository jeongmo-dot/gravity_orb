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
	var original_scale: float = Config.data.gravity_level_scale
	Config.data.gravity_level_scale = 0.1
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		7,
		Vector2.ZERO
	)
	var body: RigidBody3D = orb.get_physics_body()
	assert_near(
		(body.constant_force / body.mass).y,
		-Config.data.gravity_strength * 1.6 / Orb3D.PIXELS_PER_METER,
		0.001,
		"level seven scaled gravity"
	)
	_cleanup(board)
	Config.data.gravity_level_scale = original_scale


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
