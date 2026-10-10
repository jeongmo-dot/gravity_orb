extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const TOLERANCE: float = 1.0e-3


func test_six_colors_map_to_configured_visual_modes() -> void:
	var fixture: Dictionary = await _create_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	var expected: Array[GameConfig.ShockMode] = [
		GameConfig.ShockMode.PUSH,
		GameConfig.ShockMode.PULL,
		GameConfig.ShockMode.SHAKE,
		GameConfig.ShockMode.LIFT,
		GameConfig.ShockMode.PUSH,
		GameConfig.ShockMode.PUSH,
	]
	for color: int in range(expected.size()):
		assert_eq(
			director.color_effect_mode_for_color(color),
			expected[color],
			"color %d visual mode" % color
		)
	await _cleanup(fixture["root"] as Node)


func test_push_expands_pull_contracts_and_push_has_six_rays() -> void:
	var fixture: Dictionary = await _create_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	director.play_reaction_visuals(_merge_reaction(OrbTypes.OrbColor.RED))
	var push: ColorEffectVisual = director.active_color_effects()[0]
	var push_start: float = push.current_radius_px
	assert_eq(push.push_ray_count(), 6, "PUSH has six outward rays")
	assert_near(push_start, Config.data.radius_for_level(2), TOLERANCE, "PUSH starts at result radius")
	assert_near(
		push.intensity,
		Config.data.shock_color_impulse_scale[OrbTypes.OrbColor.RED]
			* (1.0 + Config.data.shock_level_scale),
		TOLERANCE,
		"red PUSH uses physical strength and level scales"
	)
	director._process(0.15)
	assert_true(push.current_radius_px > push_start, "PUSH ring expands")
	var red_inner_radius: float = push._ring_mesh.inner_radius
	director.clear_effects()

	director.play_reaction_visuals(_merge_reaction(OrbTypes.OrbColor.PURPLE))
	var purple: ColorEffectVisual = director.active_color_effects()[0]
	assert_true(red_inner_radius < purple._ring_mesh.inner_radius, "red ring is thicker than default PUSH")
	director.clear_effects()

	director.play_reaction_visuals(_merge_reaction(OrbTypes.OrbColor.BLUE))
	var pull: ColorEffectVisual = director.active_color_effects()[0]
	var pull_start: float = pull.current_radius_px
	assert_near(
		pull_start,
		Config.data.radius_for_level(2) * Config.data.shock_color_radius_factor[OrbTypes.OrbColor.BLUE],
		TOLERANCE,
		"PULL starts at effect radius"
	)
	director._process(0.15)
	assert_true(pull.current_radius_px < pull_start, "PULL ring contracts")
	await _cleanup(fixture["root"] as Node)


func test_pull_shrinks_only_result_mesh_before_punching() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	board.set_gravity(Vector2i.ZERO)
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 2, Vector2.ZERO)
	var collision: SphereShape3D = orb._collision_shape.shape as SphereShape3D
	var collision_radius: float = collision.radius
	var reaction: Dictionary = _merge_reaction(OrbTypes.OrbColor.BLUE)
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
		director.clear_effects()
	await _cleanup(fixture["root"] as Node)


func test_shake_moves_board_visual_frame_not_camera_and_restores() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	var camera: Camera3D = fixture["camera"] as Camera3D
	var visual_frame: Node3D = board.get_node("VisualTilt") as Node3D
	director.play_reaction_visuals(_merge_reaction(OrbTypes.OrbColor.GREEN))
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


func test_color_effect_toggle_preserves_turn_and_blitz_state_hashes() -> void:
	var original_enabled: bool = Config.data.fx_color_effect_visuals_enabled
	var original_fx: bool = Config.data.fx_enabled
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	Config.data.fx_enabled = true
	Config.data.fx_hitstop_enabled = false
	var turn_off: String = await _scripted_state_hash(false, false)
	var turn_on: String = await _scripted_state_hash(true, false)
	var blitz_off: String = await _scripted_state_hash(false, true)
	var blitz_on: String = await _scripted_state_hash(true, true)
	assert_eq(turn_on, turn_off, "20-turn color visual state hash")
	assert_eq(blitz_on, blitz_off, "20-second BLITZ color visual state hash")
	Config.data.fx_color_effect_visuals_enabled = original_enabled
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop


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


func _scripted_state_hash(enabled: bool, blitz: bool) -> String:
	Config.data.fx_color_effect_visuals_enabled = enabled
	var fixture: Dictionary = await _create_fixture()
	var root: Node3D = fixture["root"] as Node3D
	var board: Board3D = fixture["board"] as Board3D
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	for index: int in range(20):
		var direction: Vector2i = OrbTypes.DIRECTIONS[index % OrbTypes.DIRECTIONS.size()]
		board.set_gravity(direction)
		var color: int = (index + (2 if blitz else 0)) % Config.data.color_display.size()
		var level: int = 1 + index % (3 if blitz else 2)
		var position: Vector2 = Vector2(float(index % 5) * 100.0, float(index / 5) * 100.0)
		var orb: Orb3D = board.spawn_orb(color, level, position)
		orb.get_physics_body().freeze = true
		director.play_reaction_visuals({
			"type": ReactionRules.Type.MERGE,
			"result_orb": orb,
			"result_level": level,
			"result_color": color,
			"position": position,
			"shock_targets": [{"position": position + Vector2(50.0, 0.0)}],
		})
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
	await _cleanup(root)
	return hash_value


func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await tree.process_frame
