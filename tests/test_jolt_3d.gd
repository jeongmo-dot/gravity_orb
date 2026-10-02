extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const RESOLVER_SCRIPT: Script = preload("res://scripts/spike/CollisionResolver3D.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/spike/Spawner3D.gd")


func test_project_uses_jolt_without_changing_2d_main_scene() -> void:
	assert_eq(
		str(ProjectSettings.get_setting("physics/3d/physics_engine", "")),
		"Jolt Physics",
		"3D engine"
	)
	assert_eq(
		str(ProjectSettings.get_setting("application/run/main_scene", "")),
		"res://scenes/Main.tscn",
		"2D main scene remains default"
	)


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
	assert_true(body.axis_lock_linear_z, "depth axis is locked")
	assert_true(body.axis_lock_angular_x, "x rotation is locked")
	assert_true(body.axis_lock_angular_y, "y rotation is locked")
	assert_near(
		(body.constant_force / body.mass).y,
		Config.data.gravity_strength / Orb3D.PIXELS_PER_METER,
		0.001,
		"gravity converts px/s^2 to m/s^2"
	)
	_cleanup(board)


func test_jolt_reaction_uses_shared_rules_and_spawns_3d_result() -> void:
	var fixture_root: Node = Node.new()
	fixture_root.name = "JoltReactionFixture"
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	fixture_root.add_child(board)
	board.owner = fixture_root
	var resolver: CollisionResolver3D = RESOLVER_SCRIPT.new() as CollisionResolver3D
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
	_cleanup(fixture_root)


func test_spawner_3d_reuses_spawner_rng_sequence() -> void:
	var first: Spawner3D = SPAWNER_SCRIPT.new() as Spawner3D
	var second: Spawner3D = SPAWNER_SCRIPT.new() as Spawner3D
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
