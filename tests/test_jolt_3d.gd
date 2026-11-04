extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")


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


func test_jelly_and_classic_orbs_keep_plane_rotation_unlocked() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var jelly_board: Board3D = await _create_board()
	var jelly_orb: Orb3D = jelly_board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2.ZERO
	)
	var jelly_body: RigidBody3D = jelly_orb.get_physics_body()
	assert_true(
		not jelly_body.axis_lock_angular_z,
		"JELLY bodies roll in the play plane"
	)
	assert_near(jelly_body.angular_damp, 15.0, 0.001, "JELLY angular damp")
	_cleanup(jelly_board)

	Config.data.game_mode = GameConfig.GameMode.TURN
	var classic_board: Board3D = await _create_board()
	var classic_orb: Orb3D = classic_board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2.ZERO
	)
	assert_true(
		not classic_orb.get_physics_body().axis_lock_angular_z,
		"classic bodies retain plane rotation"
	)
	_cleanup(classic_board)
	Config.data.game_mode = original_mode


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
		var material: ShaderMaterial = (
			orb._mesh.material_override as ShaderMaterial
		)
		assert_true(material != null, "new color uses a 3D material")
		if material != null:
			assert_eq(
				material.get_shader_parameter("base_color"),
				Config.data.color_display[color],
				"3D material uses configured new color"
			)
			assert_eq(
				material.get_shader_parameter("level_id"),
				1,
				"3D material uses the spawned level art"
			)
	_cleanup(board)


func test_3d_blast_armed_orb_keeps_readiness_without_outline() -> void:
	var board: Board3D = await _create_board()
	var level_four: Orb3D = board.spawn_orb(0, 4, Vector2(-100.0, 0.0))
	var level_five: Orb3D = board.spawn_orb(1, 5, Vector2(100.0, 0.0))
	var level_six: Orb3D = board.spawn_orb(2, 6, Vector2(0.0, 150.0))
	assert_true(level_four.is_blast_armed(), "3D L4 is armed")
	assert_true(level_five.is_blast_armed(), "3D L5 is armed")
	assert_true(level_six.is_blast_armed(), "3D L6 is armed")
	_cleanup(board)


func test_classic_3d_blast_readiness_starts_at_level_four() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	for mode: GameConfig.GameMode in [GameConfig.GameMode.TURN]:
		Config.data.game_mode = mode
		var board: Board3D = await _create_board()
		var level_three: Orb3D = board.spawn_orb(0, 3, Vector2(-180.0, 0.0))
		var level_four: Orb3D = board.spawn_orb(1, 4, Vector2(180.0, 0.0))
		assert_true(not level_three.is_blast_armed(), "L3 is not armed in mode %d" % mode)
		assert_true(level_four.is_blast_armed(), "L4 is armed in mode %d" % mode)
		_cleanup(board)
	Config.data.game_mode = original_mode


func test_jelly_default_l8_blast_readiness_follows_mass_without_outline_geometry() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_jelly_minimum: int = Config.data.jelly_blast_min_level
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_blast_min_level = 8
	var board: Board3D = await _create_board()
	var level_seven: Orb3D = board.spawn_orb(0, 7, Vector2(-300.0, 0.0))
	var level_eight: Orb3D = board.spawn_orb(1, 8, Vector2(-100.0, 0.0))
	var level_nine: Orb3D = board.spawn_orb(2, 9, Vector2(100.0, 0.0))
	var level_ten: Orb3D = board.spawn_orb(3, 10, Vector2(300.0, 0.0))
	assert_true(not level_seven.is_blast_armed(), "L7 remains unarmed")
	assert_true(level_eight.is_blast_armed(), "L8 arms BLAST")
	assert_true(level_nine.is_blast_armed(), "L9 arms BLAST")
	assert_true(level_ten.is_blast_armed(), "L10 arms BLAST")
	assert_true(
		bool((level_eight._face.material_override as ShaderMaterial).get_shader_parameter("is_blast_ready")),
		"L8 uses the blast-ready face"
	)
	assert_true(
		bool((level_nine._face.material_override as ShaderMaterial).get_shader_parameter("is_blast_ready")),
		"L9 uses the blast-ready face"
	)
	level_nine.set_jelly_mass(64.0, Config.data)
	assert_eq(level_nine.level, 10, "mass update reaches displayed L10")
	assert_true(level_nine.is_blast_armed(), "mass-updated displayed L10 arms BLAST")
	assert_true(
		bool((level_nine._face.material_override as ShaderMaterial).get_shader_parameter("is_max")),
		"mass-updated L10 keeps the MAX face"
	)
	assert_true(
		not bool((level_nine._face.material_override as ShaderMaterial).get_shader_parameter("is_blast_ready")),
		"mass-updated L10 does not replace MAX with blast-ready face"
	)
	_cleanup(board)
	Config.data.jelly_blast_min_level = original_jelly_minimum
	Config.data.game_mode = original_mode


func test_jelly_level_friction_updates_with_mass_and_falls_back_to_single_value() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_by_level: PackedFloat32Array = Config.data.orb_friction_by_level.duplicate()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var board: Board3D = await _create_board()
	var level_three: Orb3D = board.spawn_orb(0, 3, Vector2(-250.0, 0.0))
	var level_four: Orb3D = board.spawn_orb(1, 4, Vector2.ZERO)
	var level_eight: Orb3D = board.spawn_orb(2, 8, Vector2(250.0, 0.0))
	var level_three_material: PhysicsMaterial = level_three.get_physics_body().physics_material_override
	var level_four_material: PhysicsMaterial = level_four.get_physics_body().physics_material_override
	var level_eight_material: PhysicsMaterial = level_eight.get_physics_body().physics_material_override
	assert_near(level_three_material.friction, 0.3, 0.0001, "L3 friction")
	assert_near(level_four_material.friction, 0.4, 0.0001, "L4 friction")
	assert_near(level_eight_material.friction, 0.5, 0.0001, "L8 friction")
	assert_true(not level_three_material.rough, "default material uses lower-friction mixing")
	assert_true(not level_four_material.rough, "mid material uses lower-friction mixing")
	assert_true(not level_eight_material.rough, "high material uses lower-friction mixing")
	level_three.set_jelly_mass(Config.data.jelly_mass_for_level(4), Config.data)
	assert_near(
		(level_three.get_physics_body().physics_material_override as PhysicsMaterial).friction,
		0.4,
		0.0001,
		"level-up absorption updates friction material"
	)
	Config.data.orb_friction_by_level = PackedFloat32Array()
	var fallback: Orb3D = board.spawn_orb(3, 10, Vector2(400.0, 0.0))
	assert_near(
		(fallback.get_physics_body().physics_material_override as PhysicsMaterial).friction,
		Config.data.orb_friction,
		0.0001,
		"empty per-level table falls back to shared friction"
	)
	_cleanup(board)
	Config.data.orb_friction_by_level = original_by_level
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


func test_jelly_mixed_level_blast_uses_larger_level_for_effect() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_requires_same: bool = Config.data.jelly_blast_requires_same_level
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_blast_requires_same_level = false
	var fixture: Dictionary = await _create_turn_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	resolver.proximity_reaction_scan_enabled = false
	var level_eight: Orb3D = board.spawn_orb(0, 8, Vector2(-100.0, 0.0))
	var level_nine: Orb3D = board.spawn_orb(1, 9, Vector2(100.0, 0.0))
	level_eight.disable_physics()
	level_nine.disable_physics()
	var reactions: Array[Dictionary] = []
	resolver.reaction_applied.connect(func(reaction: Dictionary) -> void: reactions.append(reaction))
	resolver.report_contact(level_eight, level_nine, "mixed_level_test")
	assert_eq(resolver.flush(), 1, "mixed L8+L9 resolves once")
	assert_eq(reactions.size(), 1, "mixed blast emits one reaction")
	if reactions.size() == 1:
		assert_eq(reactions[0]["type"], ReactionRules.Type.BLAST, "mixed pair is BLAST")
		assert_eq(reactions[0]["levels"], [8, 9], "reaction keeps both source levels")
		assert_eq(reactions[0]["shock_level"], 9, "larger source level drives effect")
	await _cleanup(fixture["root"] as Node)
	Config.data.jelly_blast_requires_same_level = original_requires_same
	Config.data.game_mode = original_mode


func test_jelly_equal_merge_fills_new_level_belly() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_merge_duration: float = Config.data.jelly_merge_duration
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_merge_duration = 0.0
	var fixture_root: Node = Node.new()
	fixture_root.name = "JellySameLevelAbsorptionFixture"
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
	var larger: Orb3D = board.spawn_orb(2, 3, Vector2(-30.0, 0.0))
	var smaller: Orb3D = board.spawn_orb(2, 3, Vector2(30.0, 0.0))
	resolver.report_contact(larger, smaller)
	assert_eq(resolver.flush(), 1, "L3 pair merges once")
	var active: Array[Orb3D] = board.get_orbs()
	assert_eq(active.size(), 1, "same-level absorption leaves one orb")
	if active.size() == 1:
		var result: Orb3D = active[0]
		assert_eq(result.level, 4, "mass six reaches L4")
		assert_near(result.jelly_mass, 6.0, 0.001, "absorbed mass is preserved")
		assert_near(result.get_radius(), 68.0, 0.001, "partial L4 target radius")
		assert_near(result.get_current_radius(), 68.0, 0.001, "zero-duration merge reaches L4 radius")
		result._physics_process(0.1)
		assert_near(result.shape_resource().radius * Orb3D.PIXELS_PER_METER, 68.0, 0.001, "collision reaches L4")
		assert_near(result._jelly_belly_target, 0.5, 0.001, "mass six targets half-full belly")
		result._process(0.15)
		assert_near(result._jelly_belly_fraction, 0.5, 0.001, "belly fills over 0.15 seconds")
	await _cleanup(fixture_root)
	Config.data.game_mode = original_mode
	Config.data.jelly_merge_duration = original_merge_duration


func test_jelly_level_up_absorption_grows_from_old_to_new_level_radius() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_merge_duration: float = Config.data.jelly_merge_duration
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_merge_duration = 0.0
	var fixture_root: Node = Node.new()
	fixture_root.name = "JellyAbsorptionFixture"
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
	board.set_gravity(Vector2i.LEFT)
	var larger_position: Vector2 = Vector2(-120.0, 25.0)
	var larger: Orb3D = board.spawn_orb(2, 3, larger_position, Vector2(30.0, 0.0))
	assert_near(larger.get_radius(), 52.0, 0.001, "L3 absorber radius")
	var smaller: Orb3D = board.spawn_orb(2, 2, Vector2(-60.0, 25.0), Vector2.ZERO)
	resolver.report_contact(larger, smaller)
	assert_eq(resolver.flush(), 1, "JELLY adjacent levels absorb once")
	var active: Array[Orb3D] = board.get_orbs()
	assert_eq(active.size(), 1, "absorption leaves one orb")
	if active.size() == 1:
		assert_eq(active[0].level, 4, "mass eight reaches level four")
		assert_near(active[0].jelly_mass, 5.0, 0.001, "absorbed mass is preserved")
		assert_near(active[0].get_radius(), 68.0, 0.001, "mass five uses the L4 radius")
		assert_near(
			active[0].get_current_radius(),
			52.0,
			0.001,
			"level-up absorption starts from the fixed L3 absorber radius"
		)
		active[0]._physics_process(0.05)
		assert_near(
			active[0].get_current_radius(),
			(52.0 + 68.0) * 0.5,
			0.001,
			"absorption radius is halfway after 0.05 seconds"
		)
		active[0]._physics_process(0.05)
		assert_near(
			active[0].get_current_radius(),
			68.0,
			0.001,
			"absorption reaches the target radius after 0.10 seconds"
		)
		assert_true(
			active[0].position.distance_to(larger_position) < 0.001,
			"larger orb position survives"
		)
		assert_true(not active[0].is_blast_armed(), "JELLY result never arms BLAST")
		assert_near(
			active[0]._jelly_frame_rotation,
			-PI * 0.25,
			0.0001,
			"absorption result keeps the active left-down diagonal frame"
		)
		var result_body: RigidBody3D = active[0].get_physics_body()
		var acceleration: Vector2 = Orb3D.world_vector_to_plane(
			result_body.constant_force / result_body.mass
		)
		var expected_acceleration: Vector2 = Vector2(-1.0, 1.0).normalized() \
			* Config.data.gravity_for_level(4)
		assert_near(
			acceleration.x,
			expected_acceleration.x,
			0.001,
			"interpolated physical mass keeps level-four diagonal gravity x acceleration"
		)
		assert_near(
			acceleration.y,
			expected_acceleration.y,
			0.001,
			"interpolated physical mass keeps level-four diagonal gravity y acceleration"
		)
	_cleanup(fixture_root)
	Config.data.game_mode = original_mode
	Config.data.jelly_merge_duration = original_merge_duration


func test_jelly_gap_two_absorption_preserves_larger_body_and_partial_mass() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_merge_duration: float = Config.data.jelly_merge_duration
	var original_level_gap: int = Config.data.jelly_merge_level_gap
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_merge_duration = 0.3
	Config.data.jelly_merge_level_gap = 2
	var fixture_root: Node = Node.new()
	fixture_root.name = "JellyGapTwoFixture"
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
	var larger: Orb3D = board.spawn_orb(2, 7, Vector2(-60.0, 0.0))
	var smaller: Orb3D = board.spawn_orb(2, 5, Vector2(60.0, 0.0))
	var larger_id: int = larger.stable_spawn_id
	resolver.report_contact(larger, smaller)
	assert_eq(resolver.flush(), 0, "gap-two L7+L5 starts its visible merge")
	assert_eq(resolver.flush(0.3), 1, "gap-two L7+L5 resolves once after the merge duration")
	var active: Array[Orb3D] = board.get_orbs()
	assert_eq(active.size(), 1, "gap-two absorption leaves one orb")
	if active.size() == 1:
		assert_eq(active[0].stable_spawn_id, larger_id, "larger physical body survives")
		assert_eq(active[0].level, 7, "mass 24 remains L7")
		assert_near(active[0].jelly_mass, 24.0, 0.001, "L7+L5 mass is preserved")
		assert_near(active[0]._jelly_belly_target, 0.7, 0.001, "mass 24 is seventy percent full")
	await _cleanup(fixture_root)
	Config.data.game_mode = original_mode
	Config.data.jelly_merge_duration = original_merge_duration
	Config.data.jelly_merge_level_gap = original_level_gap


func test_delayed_jelly_merge_reserves_sources_grows_and_emits_on_completion() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_duration: float = Config.data.jelly_merge_duration
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_merge_duration = 0.3
	var fixture_root: Node = Node.new()
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
	resolver.proximity_reaction_scan_enabled = false
	var first: Orb3D = board.spawn_orb(2, 2, Vector2(-35.0, 0.0))
	var second: Orb3D = board.spawn_orb(2, 2, Vector2(35.0, 0.0))
	var reactions: Array[Dictionary] = []
	resolver.reaction_applied.connect(
		func(reaction: Dictionary) -> void: reactions.append(reaction)
	)
	resolver.report_contact(first, second, "delayed_test")
	assert_eq(resolver.flush(), 0, "touch starts a process without applying the reaction")
	assert_eq(resolver.active_jelly_merge_count(), 1, "one merge process is active")
	assert_eq(reactions.size(), 0, "reaction signal waits for completion")
	assert_true(first.consumed and second.consumed, "both equal-level sources are reserved")
	assert_eq(first.get_physics_body().collision_layer, 0, "first source collision is disabled")
	assert_eq(second.get_physics_body().collision_layer, 0, "second source collision is disabled")
	var active: Array[Orb3D] = board.get_orbs()
	assert_eq(active.size(), 1, "result exists immediately")
	var result: Orb3D = active[0]
	assert_near(result.get_current_radius(), 40.0, 0.001, "result starts at source radius")
	var merge_tick: float = Config.data.jelly_merge_duration / 36.0
	for frame_index: int in range(18):
		assert_eq(resolver.flush(merge_tick), 0, "first-half frame %d emits nothing" % frame_index)
		result._physics_process(merge_tick)
		_assert_orb_visual_and_collision_radius(result, "equal merge frame %d" % frame_index)
	assert_near(result.get_current_radius(), 46.0, 0.001, "smoothstep midpoint is half grown")
	assert_near(first.merge_visual_scale().x, 0.9, 0.001, "source shrinks and stretches along pull")
	assert_near(first.merge_visual_scale().y, 0.74, 0.001, "source narrows across pull")
	var third: Orb3D = board.spawn_orb(2, 3, Vector2(300.0, 0.0))
	resolver.report_contact(result, third, "reserved_test")
	assert_eq(resolver.flush(), 0, "reserved result cannot join another reaction")
	var capped_first: Orb3D = board.spawn_orb(1, 1, Vector2(-300.0, 250.0))
	var capped_second: Orb3D = board.spawn_orb(1, 1, Vector2(-250.0, 250.0))
	resolver.set_accepting_new_jelly_merges(false)
	resolver.report_contact(capped_first, capped_second, "after_cap_test")
	assert_eq(resolver.flush(), 0, "turn cap rejects a new merge process")
	assert_eq(resolver.active_jelly_merge_count(), 1, "only the pre-cap process remains")
	var completion_count: int = 0
	for frame_index: int in range(18, 36):
		completion_count += resolver.flush(merge_tick)
		result._physics_process(merge_tick)
		_assert_orb_visual_and_collision_radius(result, "equal merge frame %d" % frame_index)
	assert_eq(completion_count, 1, "completion applies exactly one reaction")
	assert_eq(reactions.size(), 1, "reaction signal emits once at completion")
	assert_eq(resolver.active_jelly_merge_count(), 0, "process is removed after completion")
	assert_near(result.get_current_radius(), 52.0, 0.001, "physical and visual radius finish together")
	await tree.process_frame
	assert_true(not is_instance_valid(first), "first pulled visual is removed")
	assert_true(not is_instance_valid(second), "second pulled visual is removed")
	resolver.set_accepting_new_jelly_merges(true)
	assert_eq(resolver.deferred_jelly_merge_count, 1, "one post-cap merge is counted as deferred")
	board.clear()
	await tree.process_frame
	var absorber: Orb3D = board.spawn_orb(3, 3, Vector2(-30.0, 0.0))
	var absorbed: Orb3D = board.spawn_orb(3, 2, Vector2(30.0, 0.0))
	resolver.report_contact(absorber, absorbed, "absorption_growth_test")
	assert_eq(resolver.flush(), 0, "level-up absorption starts a delayed process")
	assert_eq(absorbed.get_physics_body().collision_layer, 0, "absorbed source collision is disabled")
	var absorption_completion_count: int = 0
	for frame_index: int in range(36):
		absorption_completion_count += resolver.flush(merge_tick)
		absorber._physics_process(merge_tick)
		_assert_orb_visual_and_collision_radius(
			absorber,
			"level-up absorption frame %d" % frame_index
		)
	assert_eq(absorption_completion_count, 1, "level-up absorption completes once")
	assert_eq(reactions.size(), 2, "absorption emits once after its process")
	board.clear()
	await tree.process_frame
	var max_first: Orb3D = board.spawn_orb(4, 10, Vector2(-60.0, 0.0))
	var max_second: Orb3D = board.spawn_orb(4, 10, Vector2(60.0, 0.0))
	resolver.report_contact(max_first, max_second, "max_clear_completion_test")
	assert_eq(resolver.flush(), 0, "MAX clear also starts as a process")
	assert_eq(resolver.active_jelly_merge_count(), 1, "MAX process is active")
	assert_eq(resolver.flush(Config.data.jelly_merge_duration), 1, "MAX clear completes after its process")
	assert_eq(reactions.size(), 3, "MAX clear emits its jackpot reaction once")
	assert_eq(reactions[-1]["type"], ReactionRules.Type.MAX_CLEAR, "completed MAX process is jackpot")
	await tree.process_frame
	var restart_first: Orb3D = board.spawn_orb(5, 10, Vector2(-60.0, 0.0))
	var restart_second: Orb3D = board.spawn_orb(5, 10, Vector2(60.0, 0.0))
	resolver.report_contact(restart_first, restart_second, "restart_cleanup_test")
	assert_eq(resolver.flush(), 0, "restart fixture starts another MAX process")
	assert_eq(resolver.active_jelly_merge_count(), 1, "restart MAX process is active")
	resolver.cancel_active_jelly_merges()
	await tree.process_frame
	assert_eq(resolver.active_jelly_merge_count(), 0, "restart clears active process state")
	assert_true(not is_instance_valid(restart_first), "restart removes first MAX visual")
	assert_true(not is_instance_valid(restart_second), "restart removes second MAX visual")
	assert_eq(reactions.size(), 3, "cancelled process emits no reaction")
	_cleanup(fixture_root)
	Config.data.game_mode = original_mode
	Config.data.jelly_merge_duration = original_duration


func test_turn_manager_stable_sweep_waits_for_delayed_merge_completion() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_duration: float = Config.data.jelly_merge_duration
	var original_stable_duration: float = Config.data.stable_duration
	var original_max_settle_time: float = Config.data.max_settle_time
	var original_linear_speed: float = Config.data.stable_linear_speed
	var original_angular_speed: float = Config.data.stable_angular_speed
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_merge_duration = 0.3
	Config.data.stable_duration = 0.001
	Config.data.max_settle_time = 1.5
	Config.data.stable_linear_speed = 1.0e9
	Config.data.stable_angular_speed = 1.0e9
	var fixture: Dictionary = await _create_turn_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	resolver.proximity_reaction_scan_enabled = false
	manager.set_physics_process(false)
	board.set_gravity(Vector2i.ZERO)
	var first: Orb3D = board.spawn_orb(2, 2, Vector2(-39.5, 0.0))
	var second: Orb3D = board.spawn_orb(2, 2, Vector2(39.5, 0.0))
	first.linear_velocity = Vector2.ZERO
	second.linear_velocity = Vector2.ZERO
	await tree.physics_frame
	await tree.physics_frame
	resolver._pending.clear()
	assert_true(
		not first.get_colliding_orbs().is_empty(),
		"stable-path fixture exposes the pair only through the resting sweep"
	)
	var order: Array[String] = []
	resolver.reaction_applied.connect(
		func(_reaction: Dictionary) -> void: order.append("reaction")
	)
	manager.turn_finished.connect(
		func(_turn: int, _combo: int) -> void: order.append("finished")
	)
	manager.state = TurnManager.State.SIMULATING
	manager._is_initial_settle = false
	manager._begin_settle()
	manager.set_physics_process(true)
	await tree.physics_frame
	assert_eq(manager.state, TurnManager.State.SIMULATING, "sweep-started merge keeps the turn active")
	assert_eq(resolver.active_jelly_merge_count(), 1, "resting sweep starts one delayed process")
	for _frame: int in range(120):
		if manager.state == TurnManager.State.WAITING_INPUT:
			break
		await tree.physics_frame
	assert_eq(manager.state, TurnManager.State.WAITING_INPUT, "stable path ends after merge completion")
	assert_eq(order, ["reaction", "finished"], "completion signal precedes settled turn")
	Config.data.game_mode = original_mode
	Config.data.jelly_merge_duration = original_duration
	Config.data.stable_duration = original_stable_duration
	Config.data.max_settle_time = original_max_settle_time
	Config.data.stable_linear_speed = original_linear_speed
	Config.data.stable_angular_speed = original_angular_speed
	await _cleanup(fixture["root"] as Node)


func test_turn_manager_cap_finishes_active_merge_without_starting_a_new_one() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_duration: float = Config.data.jelly_merge_duration
	var original_stable_duration: float = Config.data.stable_duration
	var original_max_settle_time: float = Config.data.max_settle_time
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_merge_duration = 0.3
	Config.data.stable_duration = 10.0
	Config.data.max_settle_time = 0.05
	var fixture: Dictionary = await _create_turn_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	resolver.proximity_reaction_scan_enabled = false
	manager.set_physics_process(false)
	var first: Orb3D = board.spawn_orb(2, 2, Vector2(-35.0, 0.0))
	var second: Orb3D = board.spawn_orb(2, 2, Vector2(35.0, 0.0))
	var order: Array[String] = []
	resolver.reaction_applied.connect(
		func(_reaction: Dictionary) -> void: order.append("reaction")
	)
	manager.turn_finished.connect(
		func(_turn: int, _combo: int) -> void: order.append("finished")
	)
	manager.state = TurnManager.State.SIMULATING
	manager._is_initial_settle = false
	manager._begin_settle()
	resolver.report_contact(first, second, "cap_active")
	assert_eq(resolver.flush(), 0, "pre-cap merge starts")
	manager.set_physics_process(true)
	for _frame: int in range(30):
		if not resolver._accepting_new_jelly_merges:
			break
		await tree.physics_frame
	assert_true(not resolver._accepting_new_jelly_merges, "settle cap stops new delayed merges")
	var deferred_first: Orb3D = board.spawn_orb(1, 1, Vector2(-325.0, 250.0))
	var deferred_second: Orb3D = board.spawn_orb(1, 1, Vector2(-275.0, 250.0))
	resolver.report_contact(deferred_first, deferred_second, "after_cap")
	for _frame: int in range(120):
		if manager.state == TurnManager.State.WAITING_INPUT:
			break
		await tree.physics_frame
	assert_eq(manager.state, TurnManager.State.WAITING_INPUT, "cap path waits for the active process")
	assert_eq(order, ["reaction", "finished"], "cap path completes reaction before turn end")
	assert_true(is_instance_valid(deferred_first), "post-cap first source is not consumed")
	assert_true(is_instance_valid(deferred_second), "post-cap second source is not consumed")
	assert_eq(resolver.active_jelly_merge_count(), 0, "no post-cap process starts")
	Config.data.game_mode = original_mode
	Config.data.jelly_merge_duration = original_duration
	Config.data.stable_duration = original_stable_duration
	Config.data.max_settle_time = original_max_settle_time
	await _cleanup(fixture["root"] as Node)


func test_level_eight_tap_blast_is_turn_free_and_settles_back_to_input() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_tap_modes: PackedInt32Array = Config.data.jelly_tap_effect_modes.duplicate()
	var original_clean_max: int = Config.data.jelly_tap_clean_max_level
	var original_uses_turn: bool = Config.data.jelly_tap_blast_uses_turn
	var original_stable_duration: float = Config.data.stable_duration
	var original_linear_speed: float = Config.data.stable_linear_speed
	var original_angular_speed: float = Config.data.stable_angular_speed
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_tap_effect_modes = PackedInt32Array()
	Config.data.jelly_tap_clean_max_level = 0
	Config.data.jelly_tap_blast_uses_turn = false
	Config.data.stable_duration = 0.001
	Config.data.stable_linear_speed = 1.0e9
	Config.data.stable_angular_speed = 1.0e9
	var fixture: Dictionary = await _create_turn_fixture()
	var root: Node3D = fixture["root"] as Node3D
	var board: Board3D = fixture["board"] as Board3D
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 42.0)
	camera.current = true
	root.add_child(camera)
	spawner.init_rng(128)
	manager.state = TurnManager.State.WAITING_INPUT
	manager.final_move_pending = true
	InputRouter.set_locked(false)
	var tapped: Orb3D = board.spawn_orb(2, 8, Vector2.ZERO)
	var nearby: Orb3D = board.spawn_orb(1, 1, Vector2(200.0, 0.0))
	var reactions: Array[Dictionary] = []
	var turn_starts: int = 0
	var turn_finishes: int = 0
	manager.reaction_ready.connect(func(reaction: Dictionary) -> void: reactions.append(reaction))
	manager.turn_started.connect(func(_turn: int, _dir: Vector2i) -> void: turn_starts += 1)
	manager.turn_finished.connect(func(_turn: int, _combo: int) -> void: turn_finishes += 1)
	await tree.process_frame
	manager.on_tap(camera.unproject_position(Orb3D.plane_position_to_world(Vector2.ZERO)))
	assert_true(tapped.consumed, "tap removes selected L8")
	assert_eq(manager.state, TurnManager.State.SIMULATING, "tap enters settling")
	assert_eq(manager.turn_index, 0, "tap consumes no turn")
	assert_eq(manager.gravity, Vector2i.DOWN, "tap preserves gravity")
	assert_eq(turn_starts, 0, "tap emits no turn_started")
	assert_eq(turn_finishes, 0, "tap emits no turn_finished")
	assert_eq(reactions.size(), 1, "tap uses reaction pipeline")
	if reactions.size() == 1:
		assert_eq(reactions[0]["type"], ReactionRules.Type.TAP_BLAST, "tap reaction type")
		assert_eq(reactions[0]["combo"], 1, "tap combo starts at one")
		assert_eq(reactions[0]["levels"], [8], "tap reaction keeps source level")
		assert_eq(reactions[0]["shock_level"], 8, "tap effect keeps source level")
	if reactions.size() == 1:
		var blast_targets: Array = reactions[0]["blast_targets"] as Array
		var nearby_was_pushed: bool = false
		for target_value: Variant in blast_targets:
			var target: Dictionary = target_value as Dictionary
			if (
				int(target["stable_spawn_id"]) == nearby.stable_spawn_id
				and (target["velocity_change"] as Vector2).x > 0.0
			):
				nearby_was_pushed = true
		assert_true(nearby_was_pushed, "nearby orb is pushed outward")
	for _frame: int in range(30):
		if manager.state == TurnManager.State.WAITING_INPUT:
			break
		await tree.physics_frame
	assert_eq(manager.state, TurnManager.State.WAITING_INPUT, "tap returns to input")
	assert_true(manager.final_move_pending, "tap preserves FINAL MOVE pending")
	Config.data.game_mode = original_mode
	Config.data.jelly_tap_effect_modes = original_tap_modes
	Config.data.jelly_tap_clean_max_level = original_clean_max
	Config.data.jelly_tap_blast_uses_turn = original_uses_turn
	Config.data.stable_duration = original_stable_duration
	Config.data.stable_linear_speed = original_linear_speed
	Config.data.stable_angular_speed = original_angular_speed
	await _cleanup(fixture["root"] as Node)


func test_level_eight_tap_blast_consumes_turn_spawns_next_and_keeps_gravity() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_tap_modes: PackedInt32Array = Config.data.jelly_tap_effect_modes.duplicate()
	var original_clean_max: int = Config.data.jelly_tap_clean_max_level
	var original_uses_turn: bool = Config.data.jelly_tap_blast_uses_turn
	var original_stable_duration: float = Config.data.stable_duration
	var original_linear_speed: float = Config.data.stable_linear_speed
	var original_angular_speed: float = Config.data.stable_angular_speed
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_tap_effect_modes = PackedInt32Array()
	Config.data.jelly_tap_clean_max_level = 0
	Config.data.jelly_tap_blast_uses_turn = true
	Config.data.stable_duration = 0.001
	Config.data.stable_linear_speed = 1.0e9
	Config.data.stable_angular_speed = 1.0e9
	var fixture: Dictionary = await _create_turn_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	spawner.init_rng(130)
	spawner.sync_next_batch_size(1)
	var preview_before: Array = spawner.peek_preview()
	var orb_count_before: int = board.get_orbs().size()
	manager.state = TurnManager.State.WAITING_INPUT
	InputRouter.set_locked(false)
	var tapped: Orb3D = board.spawn_orb(2, 8, Vector2.ZERO)
	var turn_starts: Array[int] = [0]
	var turn_finishes: Array[int] = [0]
	var gravity_changes: Array[int] = [0]
	manager.turn_started.connect(func(_turn: int, _dir: Vector2i) -> void: turn_starts[0] += 1)
	manager.turn_finished.connect(func(_turn: int, _combo: int) -> void: turn_finishes[0] += 1)
	manager.gravity_changed.connect(func(_dir: Vector2i) -> void: gravity_changes[0] += 1)
	assert_true(manager.try_tap_blast_orb(tapped), "L8 tap blast starts the turn")
	assert_eq(manager.state, TurnManager.State.SPAWNING, "tap waits for current NEXT spawn")
	assert_eq(manager.turn_index, 1, "tap consumes one turn")
	assert_eq(manager.gravity, Vector2i.DOWN, "tap keeps gravity")
	assert_eq(turn_starts[0], 1, "tap emits turn_started")
	assert_eq(gravity_changes[0], 0, "tap does not emit gravity_changed")
	for _frame: int in range(60):
		if manager.state == TurnManager.State.WAITING_INPUT:
			break
		await tree.physics_frame
	assert_eq(manager.state, TurnManager.State.WAITING_INPUT, "tap turn settles back to input")
	assert_eq(turn_finishes[0], 1, "tap emits turn_finished")
	assert_true(board.get_orbs().size() > orb_count_before, "tap turn spawns the current NEXT batch")
	assert_true(spawner.peek_preview() != preview_before, "tap turn advances NEXT and THEN")
	Config.data.game_mode = original_mode
	Config.data.jelly_tap_effect_modes = original_tap_modes
	Config.data.jelly_tap_clean_max_level = original_clean_max
	Config.data.jelly_tap_blast_uses_turn = original_uses_turn
	Config.data.stable_duration = original_stable_duration
	Config.data.stable_linear_speed = original_linear_speed
	Config.data.stable_angular_speed = original_angular_speed
	await _cleanup(fixture["root"] as Node)


func test_tap_blast_spends_pending_final_move_without_spawning() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_tap_modes: PackedInt32Array = Config.data.jelly_tap_effect_modes.duplicate()
	var original_clean_max: int = Config.data.jelly_tap_clean_max_level
	var original_uses_turn: bool = Config.data.jelly_tap_blast_uses_turn
	var original_stable_duration: float = Config.data.stable_duration
	var original_linear_speed: float = Config.data.stable_linear_speed
	var original_angular_speed: float = Config.data.stable_angular_speed
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_tap_effect_modes = PackedInt32Array()
	Config.data.jelly_tap_clean_max_level = 0
	Config.data.jelly_tap_blast_uses_turn = true
	Config.data.stable_duration = 0.001
	Config.data.stable_linear_speed = 1.0e9
	Config.data.stable_angular_speed = 1.0e9
	var fixture: Dictionary = await _create_turn_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	spawner.init_rng(131)
	spawner.sync_next_batch_size(1)
	var preview_before: Array = spawner.peek_preview()
	manager.state = TurnManager.State.WAITING_INPUT
	manager.final_move_pending = true
	InputRouter.set_locked(false)
	var tapped: Orb3D = board.spawn_orb(2, 8, Vector2.ZERO)
	var orb_count_before: int = board.get_orbs().size()
	assert_true(manager.try_tap_blast_orb(tapped), "tap spends FINAL MOVE")
	assert_eq(manager.state, TurnManager.State.SIMULATING, "FINAL MOVE tap skips SPAWNING")
	assert_true(manager.final_move_active, "FINAL MOVE becomes active")
	assert_true(not manager.final_move_pending, "FINAL MOVE pending is consumed")
	assert_eq(spawner.peek_preview(), preview_before, "FINAL MOVE keeps NEXT and THEN")
	for _frame: int in range(60):
		if manager.state == TurnManager.State.WAITING_INPUT:
			break
		await tree.physics_frame
	assert_eq(manager.state, TurnManager.State.WAITING_INPUT, "open entrance succeeds FINAL MOVE")
	assert_eq(manager.final_move_success_count, 1, "tap FINAL MOVE success is counted")
	assert_true(board.get_orbs().size() < orb_count_before, "FINAL MOVE tap removes source and spawns nothing")
	Config.data.game_mode = original_mode
	Config.data.jelly_tap_effect_modes = original_tap_modes
	Config.data.jelly_tap_clean_max_level = original_clean_max
	Config.data.jelly_tap_blast_uses_turn = original_uses_turn
	Config.data.stable_duration = original_stable_duration
	Config.data.stable_linear_speed = original_linear_speed
	Config.data.stable_angular_speed = original_angular_speed
	await _cleanup(fixture["root"] as Node)


func test_tap_blast_pending_final_move_fails_if_entrance_stays_blocked() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_tap_modes: PackedInt32Array = Config.data.jelly_tap_effect_modes.duplicate()
	var original_clean_max: int = Config.data.jelly_tap_clean_max_level
	var original_uses_turn: bool = Config.data.jelly_tap_blast_uses_turn
	var original_stable_duration: float = Config.data.stable_duration
	var original_stable_linear_speed: float = Config.data.stable_linear_speed
	var original_stable_angular_speed: float = Config.data.stable_angular_speed
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_tap_effect_modes = PackedInt32Array()
	Config.data.jelly_tap_clean_max_level = 0
	Config.data.jelly_tap_blast_uses_turn = true
	Config.data.stable_duration = 0.001
	Config.data.stable_linear_speed = 1.0e9
	Config.data.stable_angular_speed = 1.0e9
	var fixture: Dictionary = await _create_turn_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	resolver.proximity_reaction_scan_enabled = false
	spawner.init_rng(132)
	spawner.sync_next_batch_size(1)
	var preview_before: Array = spawner.peek_preview()
	manager.state = TurnManager.State.WAITING_INPUT
	manager.final_move_pending = true
	InputRouter.set_locked(false)
	var radius: float = Config.data.radius_for_level(1)
	var line: Dictionary = board.spawn_line(Vector2i.DOWN, radius)
	var origin: Vector2 = line["origin"] as Vector2
	var axis: Vector2 = line["axis"] as Vector2
	var extent: float = float(line["extent"])
	var offset: float = -extent
	var blocker_index: int = 0
	while offset <= extent:
		var blocker: Orb3D = board.spawn_orb(
			blocker_index % OrbTypes.OrbColor.size(),
			1,
			origin + axis * offset
		)
		blocker.get_physics_body().freeze = true
		blocker_index += 1
		offset += 45.0
	var tapped: Orb3D = board.spawn_orb(2, 8, Vector2.ZERO)
	var waiting: Orb3D = board.spawn_orb(1, 1, Vector2.ZERO)
	waiting.enter_entrance_wait(origin, Vector2i.DOWN)
	var orb_count_before: int = board.get_orbs().size()
	assert_true(manager.try_tap_blast_orb(tapped), "tap spends blocked FINAL MOVE")
	assert_eq(manager.state, TurnManager.State.SIMULATING, "blocked FINAL MOVE skips SPAWNING")
	assert_eq(spawner.peek_preview(), preview_before, "blocked FINAL MOVE keeps NEXT and THEN")
	for _frame: int in range(60):
		if manager.state == TurnManager.State.GAME_OVER:
			break
		await tree.physics_frame
	assert_eq(manager.state, TurnManager.State.GAME_OVER, "blocked entrance fails FINAL MOVE")
	assert_eq(manager.final_move_success_count, 0, "failed FINAL MOVE is not counted as success")
	assert_true(board.get_orbs().size() < orb_count_before, "failed FINAL MOVE removes source and spawns nothing")
	Config.data.game_mode = original_mode
	Config.data.jelly_tap_effect_modes = original_tap_modes
	Config.data.jelly_tap_clean_max_level = original_clean_max
	Config.data.jelly_tap_blast_uses_turn = original_uses_turn
	Config.data.stable_duration = original_stable_duration
	Config.data.stable_linear_speed = original_stable_linear_speed
	Config.data.stable_angular_speed = original_stable_angular_speed
	await _cleanup(fixture["root"] as Node)


func test_tap_blast_candidate_accepts_l8_to_l10_and_rejects_l7_waiting_ghost_and_locked() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_tap_modes: PackedInt32Array = Config.data.jelly_tap_effect_modes.duplicate()
	var original_clean_max: int = Config.data.jelly_tap_clean_max_level
	var original_uses_turn: bool = Config.data.jelly_tap_blast_uses_turn
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_tap_effect_modes = PackedInt32Array()
	Config.data.jelly_tap_clean_max_level = 0
	Config.data.jelly_tap_blast_uses_turn = true
	var fixture: Dictionary = await _create_turn_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	var level_seven: Orb3D = board.spawn_orb(0, 7, Vector2(-400.0, 0.0))
	var level_eight: Orb3D = board.spawn_orb(1, 8, Vector2(-240.0, 0.0))
	var level_nine: Orb3D = board.spawn_orb(2, 9, Vector2(-80.0, 0.0))
	var level_ten: Orb3D = board.spawn_orb(3, 10, Vector2(80.0, 0.0))
	var waiting: Orb3D = board.spawn_orb(0, 8, Vector2(220.0, 0.0))
	var ghost: Orb3D = board.spawn_orb(0, 9, Vector2(360.0, 0.0))
	var locked: Orb3D = board.spawn_orb(0, 10, Vector2(480.0, 0.0))
	waiting.is_waiting_at_entrance = true
	ghost.is_ghost = true
	resolver._lock_reaction_result(locked)
	assert_true(not resolver.is_jelly_tap_blast_candidate(level_seven), "L7 rejected")
	assert_true(resolver.is_jelly_tap_blast_candidate(level_eight), "L8 accepted")
	assert_true(resolver.is_jelly_tap_blast_candidate(level_nine), "L9 accepted")
	assert_true(resolver.is_jelly_tap_blast_candidate(level_ten), "L10 accepted")
	assert_true(not resolver.is_jelly_tap_blast_candidate(waiting), "entrance waiter rejected")
	assert_true(not resolver.is_jelly_tap_blast_candidate(ghost), "ghost rejected")
	assert_true(not resolver.is_jelly_tap_blast_candidate(locked), "reaction lock rejected")
	manager.state = TurnManager.State.WAITING_INPUT
	InputRouter.set_locked(false)
	var turn_before: int = manager.turn_index
	assert_true(not manager.try_tap_blast_orb(level_seven), "L7 tap does not start a turn")
	assert_eq(manager.turn_index, turn_before, "rejected L7 tap keeps turn index")
	Config.data.game_mode = original_mode
	Config.data.jelly_tap_effect_modes = original_tap_modes
	Config.data.jelly_tap_clean_max_level = original_clean_max
	Config.data.jelly_tap_blast_uses_turn = original_uses_turn
	await _cleanup(fixture["root"] as Node)


func test_level_ten_tap_uses_sixteen_pixel_margin_and_rejects_simulating() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var fixture: Dictionary = await _create_turn_fixture()
	var root: Node3D = fixture["root"] as Node3D
	var board: Board3D = fixture["board"] as Board3D
	var manager: TurnManager = fixture["manager"] as TurnManager
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 42.0)
	camera.current = true
	root.add_child(camera)
	manager.state = TurnManager.State.WAITING_INPUT
	InputRouter.set_locked(false)
	var tapped: Orb3D = board.spawn_orb(2, Config.data.orb_max_level, Vector2.ZERO)
	await tree.process_frame
	var outer_point: Vector2 = Vector2(
		tapped.get_current_radius() + Config.data.jelly_tap_blast_touch_margin + 0.1,
		0.0
	)
	manager.on_tap(camera.unproject_position(Orb3D.plane_position_to_world(outer_point)))
	assert_true(not tapped.consumed, "point just outside touch margin is ignored")
	manager.state = TurnManager.State.SIMULATING
	var turn_before: int = manager.turn_index
	assert_true(not manager.try_tap_blast_orb(tapped), "SIMULATING rejects direct tap blast")
	assert_eq(manager.turn_index, turn_before, "rejected SIMULATING tap keeps turn index")
	manager.state = TurnManager.State.WAITING_INPUT
	var inner_point: Vector2 = Vector2(
		tapped.get_current_radius() + Config.data.jelly_tap_blast_touch_margin - 0.1,
		0.0
	)
	manager.on_tap(camera.unproject_position(Orb3D.plane_position_to_world(inner_point)))
	assert_true(tapped.consumed, "point just inside touch margin selects L10")
	Config.data.game_mode = original_mode
	await _cleanup(fixture["root"] as Node)


func test_tap_clean_removes_only_eligible_same_color_without_push() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_modes: PackedInt32Array = Config.data.jelly_tap_effect_modes.duplicate()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_tap_effect_modes = PackedInt32Array([1, 1, 1, 1, 1, 1])
	var fixture: Dictionary = await _create_turn_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var source: Orb3D = board.spawn_orb(0, 8, Vector2.ZERO)
	var clean_one: Orb3D = board.spawn_orb(0, 1, Vector2(-400.0, 0.0))
	var clean_three: Orb3D = board.spawn_orb(0, 3, Vector2(400.0, 0.0))
	var same_high: Orb3D = board.spawn_orb(0, 4, Vector2(100.0, 0.0))
	var other_low: Orb3D = board.spawn_orb(1, 1, Vector2(120.0, 0.0))
	var ghost: Orb3D = board.spawn_orb(0, 1, Vector2(180.0, 120.0))
	var waiting: Orb3D = board.spawn_orb(0, 1, Vector2(-180.0, 120.0))
	var locked: Orb3D = board.spawn_orb(0, 1, Vector2(0.0, -180.0))
	ghost.is_ghost = true
	waiting.is_waiting_at_entrance = true
	resolver._lock_reaction_result(locked)
	var reactions: Array[Dictionary] = []
	resolver.reaction_applied.connect(func(reaction: Dictionary) -> void: reactions.append(reaction))
	assert_true(resolver.apply_jelly_tap_blast(source), "NONE tap applies")
	assert_true(source.consumed, "source is removed")
	assert_true(clean_one.consumed and clean_three.consumed, "same color L1-L3 clean")
	assert_true(not same_high.consumed, "same color L4 remains")
	assert_true(not other_low.consumed, "other color remains")
	assert_true(not ghost.consumed, "ghost remains")
	assert_true(not waiting.consumed, "entrance waiter remains")
	assert_true(not locked.consumed, "merge-locked orb remains")
	assert_eq(reactions[0]["clean_levels"], [1, 3], "clean levels are deterministic")
	assert_true((reactions[0]["blast_targets"] as Array).is_empty(), "common clean does not push")
	assert_true(same_high.linear_velocity.is_zero_approx(), "remaining orb is not pushed")
	Config.data.game_mode = original_mode
	Config.data.jelly_tap_effect_modes = original_modes
	await _cleanup(fixture["root"] as Node)


func test_bomb_quake_and_grow_tap_effects_follow_color_rules() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var fixture: Dictionary = await _create_turn_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	Config.data.game_mode = GameConfig.GameMode.JELLY

	var red: Orb3D = board.spawn_orb(0, 8, Vector2.ZERO)
	var red_far: Orb3D = board.spawn_orb(0, 1, Vector2(430.0, 0.0))
	var blue_near: Orb3D = board.spawn_orb(1, 2, Vector2(200.0, 0.0))
	var blue_far: Orb3D = board.spawn_orb(1, 2, Vector2(400.0, 0.0))
	var blue_high: Orb3D = board.spawn_orb(1, 4, Vector2(180.0, 0.0))
	var reactions: Array[Dictionary] = []
	resolver.reaction_applied.connect(func(reaction: Dictionary) -> void: reactions.append(reaction))
	assert_true(resolver.apply_jelly_tap_blast(red), "BOMB tap applies")
	assert_true(red_far.consumed, "same color clean is board-wide")
	assert_true(blue_near.consumed, "near other-color low orb is bomb-cleaned")
	assert_true(not blue_far.consumed, "far other-color orb remains")
	assert_true(not blue_high.consumed, "other-color L4 remains")
	var bomb_moved: bool = false
	for target_value: Variant in reactions[-1]["blast_targets"] as Array:
		var target_row: Dictionary = target_value as Dictionary
		if int(target_row["stable_spawn_id"]) == blue_high.stable_spawn_id:
			bomb_moved = (target_row["velocity_change"] as Vector2).x > 0.0
	assert_true(bomb_moved, "remaining near orb is pushed")

	board.clear()
	await tree.process_frame
	var quake: Orb3D = board.spawn_orb(1, 8, Vector2.ZERO)
	var light: Orb3D = board.spawn_orb(0, 4, Vector2(100.0, 0.0))
	var heavy: Orb3D = board.spawn_orb(3, 7, Vector2(-100.0, 0.0))
	assert_true(resolver.apply_jelly_tap_blast(quake), "QUAKE tap applies")
	var quake_speeds: Dictionary = {}
	for target_value: Variant in reactions[-1]["shock_targets"] as Array:
		var target_row: Dictionary = target_value as Dictionary
		quake_speeds[int(target_row["stable_spawn_id"])] = (
			target_row["velocity_change"] as Vector2
		).length()
	assert_near(float(quake_speeds[light.stable_spawn_id]), 900.0, 0.01, "light orb gets quake speed")
	assert_near(float(quake_speeds[heavy.stable_spawn_id]), 900.0, 0.01, "heavy orb gets same quake speed")

	board.clear()
	await tree.process_frame
	var empty_green: Orb3D = board.spawn_orb(2, 8, Vector2.ZERO)
	assert_true(not resolver.is_jelly_tap_blast_candidate(empty_green), "empty L8 green rejects tap")
	for index: int in range(5):
		board.spawn_orb(2, 3, Vector2(-300.0 + float(index) * 120.0, 200.0))
	assert_true(resolver.is_jelly_tap_blast_candidate(empty_green), "green accepts after clean target")
	assert_true(resolver.apply_jelly_tap_blast(empty_green), "GROW tap applies")
	assert_true(not empty_green.consumed, "L8 green source survives")
	assert_eq(empty_green.level, 9, "cleaned mass grows source to L9")
	assert_near(empty_green.jelly_mass, 42.0, 0.001, "growth uses cleaned jelly mass")
	var max_green: Orb3D = board.spawn_orb(2, 10, Vector2(350.0, -200.0))
	assert_true(resolver.is_jelly_tap_blast_candidate(max_green), "green L10 can tap empty")
	assert_true(resolver.apply_jelly_tap_blast(max_green), "green L10 tap applies")
	assert_true(max_green.consumed, "green L10 source is removed")

	Config.data.game_mode = original_mode
	await _cleanup(fixture["root"] as Node)


func test_magnet_and_rest_tap_effects_hold_gravity_and_skip_next_spawn() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var fixture: Dictionary = await _create_turn_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	var purple: Orb3D = board.spawn_orb(4, 8, Vector2.ZERO)
	var target: Orb3D = board.spawn_orb(0, 4, Vector2(200.0, 0.0))
	assert_true(resolver.apply_jelly_tap_blast(purple), "MAGNET tap applies")
	assert_true(board.tap_magnet_active(), "magnet window starts")
	assert_true(board.is_gravity_transition_active(), "magnet blocks settling")
	var magnet_direction: Vector2 = Orb3D.world_vector_to_plane(
		target.get_physics_body().constant_force
	).normalized()
	assert_true(magnet_direction.x < -0.99, "magnet gravity points to tap origin")
	board._advance_tap_magnet(0.5)
	var restored_direction: Vector2 = Orb3D.world_vector_to_plane(
		target.get_physics_body().constant_force
	).normalized()
	assert_true(restored_direction.y > 0.99, "magnet restores current gravity")

	board.clear()
	await tree.process_frame
	spawner.init_rng(133)
	spawner.sync_next_batch_size(1)
	var preview_before: Array = spawner.peek_preview()
	manager.state = TurnManager.State.WAITING_INPUT
	InputRouter.set_locked(false)
	var rest: Orb3D = board.spawn_orb(5, 8, Vector2.ZERO)
	assert_true(manager.try_tap_blast_orb(rest), "REST tap starts turn")
	assert_eq(manager.state, TurnManager.State.SIMULATING, "REST skips SPAWNING")
	assert_eq(manager.turn_index, 1, "REST consumes turn")
	assert_eq(spawner.peek_preview(), preview_before, "REST preserves NEXT and THEN")
	Config.data.game_mode = original_mode
	await _cleanup(fixture["root"] as Node)


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


func _create_turn_fixture() -> Dictionary:
	var root: Node3D = Node3D.new()
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	root.add_child(board)
	board.owner = root
	var resolver: CollisionResolver = RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	root.add_child(resolver)
	resolver.owner = root
	var spawner: Spawner = SPAWNER_SCRIPT.new() as Spawner
	spawner.name = "Spawner"
	spawner.unique_name_in_owner = true
	root.add_child(spawner)
	spawner.owner = root
	var manager: TurnManager = TURN_MANAGER_SCRIPT.new() as TurnManager
	manager.name = "TurnManager"
	root.add_child(manager)
	manager.owner = root
	tree.root.add_child(root)
	await tree.process_frame
	return {
		"root": root,
		"board": board,
		"resolver": resolver,
		"spawner": spawner,
		"manager": manager,
	}


func _assert_orb_visual_and_collision_radius(orb: Orb3D, context: String) -> void:
	var radius: float = orb.get_current_radius()
	assert_near(
		orb.shape_resource().radius * Orb3D.PIXELS_PER_METER,
		radius,
		0.001,
		"%s collision radius" % context
	)
	assert_near(
		orb.mesh_resource().radius * Orb3D.PIXELS_PER_METER,
		radius,
		0.001,
		"%s visual radius" % context
	)


func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await tree.process_frame
