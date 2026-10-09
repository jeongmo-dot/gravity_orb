extends TestCase

const BOARD_2D_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const BOARD_3D_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const MAIN_2D_SCENE: PackedScene = preload("res://scenes/Main.tscn")


func test_debug_hud_displays_positive_replayable_random_seed() -> void:
	var original_seed: int = Config.data.rng_seed
	Config.data.rng_seed = 0
	var main: Main = MAIN_2D_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.TURN)
	(main.get_node("ScoreManager") as ScoreManager).save_path = ""
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	var spawner: Spawner = main.get_node("Spawner") as Spawner
	var debug_label: Label = main.get_node("UI/DebugLabel") as Label
	assert_true(spawner.seed_used >= 1, "runtime random seed is positive")
	assert_true(
		debug_label.text.contains("Seed: %d" % spawner.seed_used),
		"debug HUD displays the reusable seed"
	)
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.rng_seed = original_seed


func test_2d_render_clamp_keeps_physics_state_unchanged() -> void:
	var board: Board = BOARD_2D_SCENE.instantiate() as Board
	tree.root.add_child(board)
	await tree.process_frame
	var spawn_radius: float = Config.data.radius_for_level(1)
	var spawn_limit: float = board.half_size() - spawn_radius
	var orb: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(spawn_limit, -spawn_limit))
	var radius: float = orb.get_current_radius()
	var limit: float = board.half_size() - radius
	var physics_position: Vector2 = Vector2(limit + 10.0, -limit - 10.0)
	orb.position = physics_position
	orb.freeze = true
	orb.linear_velocity = Vector2(120.0, -80.0)
	orb.angular_velocity = 2.5
	var before: Dictionary = _physics_state_2d(orb)

	orb.set_render_clamp_enabled(true)
	orb._process(0.0)
	var visual: OrbVisual = orb.get_node("Visual") as OrbVisual
	var clamped_position: Vector2 = board.to_local(visual.global_position)
	assert_near(clamped_position.x, limit, 0.001, "2D visual clamps right edge")
	assert_near(clamped_position.y, -limit, 0.001, "2D visual clamps top edge")
	assert_eq(_physics_state_2d(orb), before, "2D clamp does not alter physics state")

	orb.set_render_clamp_enabled(false)
	orb._process(0.0)
	var unclamped_position: Vector2 = board.to_local(visual.global_position)
	assert_near(unclamped_position.x, physics_position.x, 0.001, "2D disabled clamp shows physics x")
	assert_near(unclamped_position.y, physics_position.y, 0.001, "2D disabled clamp shows physics y")
	assert_eq(_physics_state_2d(orb), before, "2D clamp toggle keeps state hash")
	board.queue_free()
	await tree.process_frame


func test_3d_render_clamp_keeps_mesh_symbol_and_physics_separate() -> void:
	var board: Board3D = BOARD_3D_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	var radius: float = Config.data.radius_for_level(1)
	var limit: float = board.half_size() - radius
	var physics_position: Vector2 = Vector2(limit + 10.0, limit + 10.0)
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.CYAN, 1, physics_position)
	var body: RigidBody3D = orb.get_physics_body()
	body.freeze = true
	body.linear_velocity = Orb3D.plane_vector_to_world(Vector2(120.0, -80.0))
	body.angular_velocity = Vector3(0.0, 0.0, 2.5)
	var before: Dictionary = _physics_state_3d(orb)
	var mesh: MeshInstance3D = orb.get_node("Mesh") as MeshInstance3D
	var symbol: MeshInstance3D = orb.get_node("Symbol") as MeshInstance3D

	orb.set_render_clamp_enabled(true)
	orb._process(0.0)
	var mesh_plane: Vector2 = Orb3D.world_position_to_plane(mesh.position)
	var symbol_plane: Vector2 = Orb3D.world_position_to_plane(symbol.position)
	assert_near(mesh_plane.x, limit, 0.001, "3D mesh clamps right edge")
	assert_near(mesh_plane.y, limit, 0.001, "3D mesh clamps bottom edge")
	assert_near(symbol_plane.x, mesh_plane.x, 0.001, "3D symbol uses mesh x")
	assert_near(symbol_plane.y, mesh_plane.y, 0.001, "3D symbol uses mesh y")
	assert_eq(_physics_state_3d(orb), before, "3D clamp does not alter physics state")

	orb.set_render_clamp_enabled(false)
	orb._process(0.0)
	mesh_plane = Orb3D.world_position_to_plane(mesh.position)
	symbol_plane = Orb3D.world_position_to_plane(symbol.position)
	assert_near(mesh_plane.x, physics_position.x, 0.001, "3D disabled clamp shows physics x")
	assert_near(mesh_plane.y, physics_position.y, 0.001, "3D disabled clamp shows physics y")
	assert_near(symbol_plane.x, mesh_plane.x, 0.001, "disabled symbol follows mesh x")
	assert_near(symbol_plane.y, mesh_plane.y, 0.001, "disabled symbol follows mesh y")
	assert_eq(_physics_state_3d(orb), before, "3D clamp toggle keeps state hash")
	board.queue_free()
	await tree.process_frame


func test_3d_symbol_uses_latest_fast_body_position_before_render() -> void:
	var board: Board3D = BOARD_3D_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.YELLOW, 1, Vector2.ZERO)
	orb.exit_ghost_state()
	var body: RigidBody3D = orb.get_physics_body()
	body.constant_force = Vector3.ZERO
	body.linear_velocity = Orb3D.plane_vector_to_world(Vector2(900.0, 0.0))
	body.angular_velocity = Vector3(0.0, 0.0, 3.0)
	body.sleeping = false
	var initial_x: float = body.position.x
	for _frame: int in range(3):
		await tree.physics_frame
	await tree.create_timer(0.0).timeout
	var mesh: MeshInstance3D = orb.get_node("Mesh") as MeshInstance3D
	var symbol: MeshInstance3D = orb.get_node("Symbol") as MeshInstance3D
	var mesh_plane: Vector2 = Orb3D.world_position_to_plane(mesh.position)
	var symbol_plane: Vector2 = Orb3D.world_position_to_plane(symbol.position)
	var body_plane: Vector2 = orb.position
	assert_true(body.position.x > initial_x, "900px/s body advances during physics")
	assert_true(
		mesh_plane.distance_to(body_plane) < 0.5,
		"3D mesh center follows latest body position within 0.5px"
	)
	assert_true(
		symbol_plane.distance_to(mesh_plane) < 0.5,
		"3D symbol center follows latest mesh position within 0.5px"
	)
	assert_eq(symbol.rotation, Vector3.ZERO, "3D symbol stays upright")
	assert_near(
		mesh.rotation.z,
		atan2(body.linear_velocity.y, body.linear_velocity.x),
		0.001,
		"stretched 3D mesh follows latest velocity direction"
	)
	board.queue_free()
	await tree.process_frame


func _physics_state_2d(orb: Orb) -> Dictionary:
	return {
		"position": orb.position,
		"linear_velocity": orb.linear_velocity,
		"angular_velocity": orb.angular_velocity,
		"mass": orb.mass,
		"collision_layer": orb.collision_layer,
		"collision_mask": orb.collision_mask,
		"radius": orb.get_current_radius(),
	}


func _physics_state_3d(orb: Orb3D) -> Dictionary:
	var body: RigidBody3D = orb.get_physics_body()
	return {
		"position": body.position,
		"linear_velocity": body.linear_velocity,
		"angular_velocity": body.angular_velocity,
		"mass": body.mass,
		"collision_layer": body.collision_layer,
		"collision_mask": body.collision_mask,
		"radius": orb.get_current_radius(),
	}
