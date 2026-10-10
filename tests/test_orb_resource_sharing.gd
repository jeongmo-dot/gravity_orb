extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")


func test_one_hundred_orbs_share_level_color_and_physics_resources() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.TURN
	Orb3D.clear_shared_resource_cache()
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	var meshes: Dictionary = {}
	var shapes: Dictionary = {}
	var materials: Dictionary = {}
	var physics_materials: Dictionary = {}
	for index: int in range(100):
		var ordinary_level_count: int = Config.data.active_blast_min_level() - 1
		var level: int = index % ordinary_level_count + 1
		var color: int = index % Config.data.color_display.size()
		var orb: Orb3D = board.spawn_orb(color, level, Vector2.ZERO)
		meshes[orb.mesh_resource().get_instance_id()] = true
		shapes[orb.shape_resource().get_instance_id()] = true
		materials[orb.visual_material_resource().get_instance_id()] = true
		physics_materials[
			orb.get_physics_body().physics_material_override.get_instance_id()
		] = true
	assert_true(meshes.size() <= Config.data.orb_max_level, "mesh count stays level-bounded")
	assert_true(shapes.size() <= Config.data.orb_max_level, "shape count stays level-bounded")
	assert_true(
		materials.size() <= Config.data.color_display.size(),
		"base material count stays color-bounded"
	)
	assert_eq(physics_materials.size(), 1, "all orbs share one physics material")
	board.queue_free()
	await tree.process_frame
	Config.data.game_mode = original_mode


func test_blink_and_radius_mutation_use_copy_on_write() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	Orb3D.clear_shared_resource_cache()
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	var first: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2.ZERO)
	var second: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2.ZERO)
	var blinking: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		Config.data.active_blast_min_level(),
		Vector2.ZERO
	)
	assert_eq(
		first.visual_material_resource(),
		second.visual_material_resource(),
		"ordinary same-color orbs share material"
	)
	assert_true(
		blinking.visual_material_resource() != first.visual_material_resource(),
		"blinking orb owns its material"
	)
	var shared_mesh: SphereMesh = second.mesh_resource()
	var shared_shape: SphereShape3D = second.shape_resource()
	first._set_current_radius(first.get_radius() * 0.5)
	assert_true(first.mesh_resource() != shared_mesh, "radius-changing orb owns mesh")
	assert_true(first.shape_resource() != shared_shape, "radius-changing orb owns shape")
	assert_eq(second.mesh_resource(), shared_mesh, "unchanged orb keeps shared mesh")
	assert_eq(second.shape_resource(), shared_shape, "unchanged orb keeps shared shape")
	board.queue_free()
	await tree.process_frame
	Config.data.game_mode = original_mode
