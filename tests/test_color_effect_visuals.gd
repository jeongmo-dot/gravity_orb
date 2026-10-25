extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const TOLERANCE: float = 1.0e-3


func test_six_colors_map_to_configured_visual_modes() -> void:
	var fixture: Dictionary = await _create_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	var expected: Array[GameConfig.ShockMode] = [
		GameConfig.ShockMode.PUSH,
		GameConfig.ShockMode.SHAKE,
		GameConfig.ShockMode.PUSH,
		GameConfig.ShockMode.LIFT,
		GameConfig.ShockMode.PULL,
		GameConfig.ShockMode.PUSH,
	]
	for color: int in range(expected.size()):
		assert_eq(
			director.color_effect_mode_for_color(color),
			expected[color],
			"color %d visual mode" % color
		)
	await _cleanup(fixture["root"] as Node)


func test_push_and_pull_keep_directional_stardust_without_ring_geometry() -> void:
	var fixture: Dictionary = await _create_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	director.play_reaction_visuals(_merge_reaction(OrbTypes.OrbColor.RED))
	var push: ColorEffectVisual = director.active_color_effects()[0]
	var push_start: float = push.current_radius_px
	assert_eq(push.push_ray_count(), 0, "PUSH removes the old six rays")
	assert_eq(push.stardust_count(), 12, "PUSH has outward stardust")
	assert_eq(_forbidden_ring_geometry_count(fixture["root"] as Node), 0, "PUSH has no ring geometry")
	assert_near(push_start, Config.data.radius_for_level(2), TOLERANCE, "PUSH starts at result radius")
	assert_near(
		push.intensity,
		Config.data.shock_color_impulse_scale[OrbTypes.OrbColor.RED]
			* (1.0 + Config.data.shock_level_scale),
		TOLERANCE,
		"red PUSH uses physical strength and level scales"
	)
	director._process(0.15)
	assert_true(push.current_radius_px > push_start, "PUSH stardust radius expands")
	director.clear_effects()

	director.play_reaction_visuals(_merge_reaction(OrbTypes.OrbColor.GREEN))
	var green: ColorEffectVisual = director.active_color_effects()[0]
	assert_eq(green.stardust_count(), 12, "green PUSH keeps outward stardust")
	assert_eq(_forbidden_ring_geometry_count(fixture["root"] as Node), 0, "pooled PUSH has no ring geometry")
	director.clear_effects()

	director.play_reaction_visuals(_merge_reaction(OrbTypes.OrbColor.PURPLE))
	var pull: ColorEffectVisual = director.active_color_effects()[0]
	var pull_start: float = pull.current_radius_px
	assert_eq(pull.stardust_count(), 12, "PULL has inward spiral stardust")
	assert_near(
		pull_start,
		Config.data.radius_for_level(2) * Config.data.shock_color_radius_factor[OrbTypes.OrbColor.PURPLE],
		TOLERANCE,
		"PULL starts at effect radius"
	)
	director._process(0.15)
	assert_true(pull.current_radius_px < pull_start, "PULL stardust radius contracts")
	assert_eq(_forbidden_ring_geometry_count(fixture["root"] as Node), 0, "PULL has no ring geometry")
	await _cleanup(fixture["root"] as Node)


func test_jelly_keeps_color_feedback_without_ring_geometry() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var fixture: Dictionary = await _create_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	director.play_reaction_visuals(_merge_reaction(OrbTypes.OrbColor.GREEN))
	var push: ColorEffectVisual = director.active_color_effects()[0]
	assert_eq(push.stardust_count(), 12, "JELLY PUSH keeps directional stardust")
	assert_eq(director.active_particle_count(), 1, "JELLY merge keeps merge stardust")
	director.clear_effects()
	director.play_reaction_visuals(_merge_reaction(OrbTypes.OrbColor.BLUE))
	var shake: ColorEffectVisual = director.active_color_effects()[0]
	assert_eq(director.active_color_frame_shake_count(), 1, "JELLY SHAKE keeps board motion")
	director.clear_effects()
	Config.data.game_mode = GameConfig.GameMode.TURN
	director.play_reaction_visuals(_merge_reaction(OrbTypes.OrbColor.GREEN))
	assert_eq(_forbidden_ring_geometry_count(fixture["root"] as Node), 0, "all modes remain ring-free")
	await _cleanup(fixture["root"] as Node)
	Config.data.game_mode = original_mode


func test_pull_shrinks_only_result_mesh_before_punching() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	board.set_gravity(Vector2i.ZERO)
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.PURPLE, 2, Vector2.ZERO)
	var collision: SphereShape3D = orb._collision_shape.shape as SphereShape3D
	var collision_radius: float = collision.radius
	var reaction: Dictionary = _merge_reaction(OrbTypes.OrbColor.PURPLE)
	reaction["result_orb"] = orb
	director.play_reaction_visuals(reaction)
	await tree.create_timer(0.05, true, false, true).timeout
	assert_true(orb._mesh.scale.x < 1.0, "PULL result mesh shrinks first")
	assert_near(collision.radius, collision_radius, TOLERANCE, "PULL collision radius unchanged")
	await tree.create_timer(0.30, true, false, true).timeout
	assert_near(orb._mesh.scale.x, 1.0, 0.01, "PULL result mesh returns after punch")
	await _cleanup(fixture["root"] as Node)


func test_lift_direction_opposes_each_gravity_direction() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	for direction: Vector2i in OrbTypes.DIRECTIONS:
		board.set_gravity(direction)
		var reaction: Dictionary = _merge_reaction(OrbTypes.OrbColor.YELLOW)
		reaction["shock_targets"] = [
			{"position": Vector2(80.0, 40.0)},
			{"position": Vector2(-60.0, -20.0)},
		]
		director.play_reaction_visuals(reaction)
		var lift: ColorEffectVisual = director.active_color_effects()[0]
		assert_near(
			lift.lift_direction.x,
			-Vector2(direction).normalized().x,
			TOLERANCE,
			"%s LIFT x" % OrbTypes.dir_name(direction)
		)
		assert_near(
			lift.lift_direction.y,
			-Vector2(direction).normalized().y,
			TOLERANCE,
			"%s LIFT y" % OrbTypes.dir_name(direction)
		)
		assert_eq(lift.lift_target_count(), 2, "LIFT uses shock target positions")
		assert_true(not lift.uses_light_beam(), "LIFT has no beam")
		assert_eq(lift.stardust_count(), 6, "LIFT has three upward stars per target")
		assert_eq(_forbidden_ring_geometry_count(fixture["root"] as Node), 0, "LIFT has no ring geometry")
		director.clear_effects()
	await _cleanup(fixture["root"] as Node)


func test_shake_moves_board_visual_frame_not_camera_and_restores() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	var camera: Camera3D = fixture["camera"] as Camera3D
	var visual_frame: Node3D = board.get_node("VisualTilt") as Node3D
	director.play_reaction_visuals(_merge_reaction(OrbTypes.OrbColor.BLUE))
	var shake: ColorEffectVisual = director.active_color_effects()[0]
	assert_eq(shake.stardust_count(), 0, "SHAKE adds no duplicate particles")
	assert_eq(_forbidden_ring_geometry_count(fixture["root"] as Node), 0, "SHAKE has no ring geometry")
	assert_eq(director.active_color_frame_shake_count(), 1, "SHAKE starts frame shake")
	director._process(0.05)
	assert_true(visual_frame.position.length() > 0.0, "board visual frame moves")
	assert_true(
		visual_frame.position.length() <= 6.0 / Orb3D.PIXELS_PER_METER + TOLERANCE,
		"board frame movement is bounded by 6px"
	)
	assert_near(camera.h_offset, 0.0, TOLERANCE, "SHAKE leaves camera horizontal offset")
	assert_near(camera.v_offset, 0.0, TOLERANCE, "SHAKE leaves camera vertical offset")
	director._process(0.20)
	assert_eq(director.active_color_frame_shake_count(), 0, "frame shake ends at 0.25s")
	assert_near(visual_frame.position.length(), 0.0, TOLERANCE, "board frame restores")
	await _cleanup(fixture["root"] as Node)


func test_toggle_blast_exclusion_jackpot_intensity_and_pool_cleanup() -> void:
	var original_enabled: bool = Config.data.fx_color_effect_visuals_enabled
	var fixture: Dictionary = await _create_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	Config.data.fx_color_effect_visuals_enabled = false
	director.play_reaction_visuals(_merge_reaction(OrbTypes.OrbColor.RED))
	assert_eq(director.active_color_effect_count(), 0, "disabled color visuals create nothing")
	Config.data.fx_color_effect_visuals_enabled = true
	director.play_reaction_visuals({
		"type": ReactionRules.Type.BLAST,
		"levels": [6, 6],
		"colors": [OrbTypes.OrbColor.RED, OrbTypes.OrbColor.BLUE],
		"position": Vector2.ZERO,
	})
	assert_eq(director.active_color_effect_count(), 0, "BLAST excludes color-mode visual")
	director.clear_effects()
	director.play_reaction_visuals({
		"type": ReactionRules.Type.MAX_CLEAR,
		"levels": [7, 7],
		"colors": [OrbTypes.OrbColor.RED, OrbTypes.OrbColor.RED],
		"result_color": OrbTypes.OrbColor.RED,
		"position": Vector2.ZERO,
		"shock_targets": [],
	})
	assert_eq(director.active_color_effect_count(), 1, "MAX_CLEAR adds color-mode visual")
	assert_near(
		director.active_color_effects()[0].intensity,
		1.5
			* Config.data.shock_color_impulse_scale[OrbTypes.OrbColor.RED]
			* (
				1.0
				+ Config.data.shock_level_scale
				* float(Config.data.orb_max_level - 1)
			),
		TOLERANCE,
		"MAX_CLEAR color visual intensity"
	)
	director._process(0.5)
	assert_eq(director.active_color_effect_count(), 0, "color visual cleans before 1.5s")
	assert_eq(director.color_effect_pool_count(), 1, "color visual returns to pool")
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_color_effect_visuals_enabled = original_enabled


func test_color_effect_frame_cost_report() -> void:
	var original_enabled: bool = Config.data.fx_color_effect_visuals_enabled
	Config.data.fx_color_effect_visuals_enabled = true
	var fixture: Dictionary = await _create_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	for index: int in range(16):
		var reaction: Dictionary = _merge_reaction(index % Config.data.color_display.size())
		reaction["position"] = Vector2(float(index % 4) * 120.0, float(index / 4) * 120.0)
		reaction["shock_targets"] = [
			{"position": Vector2(float(index) * 10.0, 40.0)},
			{"position": Vector2(-float(index) * 8.0, -40.0)},
		]
		director._play_color_effect_visual(reaction)
	assert_eq(director.active_color_effect_count(), 16, "measurement has sixteen effects")
	var samples: Array[int] = []
	for _sample_index: int in range(400):
		var started_usec: int = Time.get_ticks_usec()
		director._process(0.000001)
		samples.append(Time.get_ticks_usec() - started_usec)
	samples.sort()
	var p50: int = samples[samples.size() / 2]
	var p95: int = samples[floori(float(samples.size() - 1) * 0.95)]
	print("COLOR_EFFECT_FRAME_COST active=16 samples=400 p50_us=%d p95_us=%d" % [p50, p95])
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_color_effect_visuals_enabled = original_enabled


func _merge_reaction(color: int) -> Dictionary:
	return {
		"type": ReactionRules.Type.MERGE,
		"result_level": 2,
		"result_color": color,
		"position": Vector2.ZERO,
		"shock_targets": [],
	}


func _create_fixture() -> Dictionary:
	var root: Node3D = Node3D.new()
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	root.add_child(camera)
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	root.add_child(board)
	var director: FeedbackDirector = FeedbackDirector.new()
	director.name = "FeedbackDirector"
	root.add_child(director)
	tree.root.add_child(root)
	await tree.process_frame
	director._board = board
	return {"root": root, "camera": camera, "board": board, "director": director}


func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await tree.process_frame


func _forbidden_ring_geometry_count(root: Node) -> int:
	var count: int = 0
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var lowered_name: String = node.name.to_lower()
		if lowered_name.contains("ring") or lowered_name.contains("adornment"):
			count += 1
		if node is MeshInstance3D:
			var mesh: Mesh = (node as MeshInstance3D).mesh
			if mesh != null and mesh.get_class() == "Torus" + "Mesh":
				count += 1
		for child: Node in node.get_children():
			pending.append(child)
	return count
