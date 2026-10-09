extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const TOLERANCE: float = 1.0e-3


func test_tilt_reaches_six_degrees_returns_by_point_three_and_continues_smoothly() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_degrees: float = Config.data.fx_tilt_degrees
	var original_duration: float = Config.data.fx_tilt_duration
	Config.data.fx_enabled = true
	Config.data.fx_tilt_degrees = 6.0
	Config.data.fx_tilt_duration = 0.3
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var frame: Node3D = board.get_node("VisualTilt") as Node3D
	board.play_visual_tilt(Vector2i.RIGHT)
	var maximum_angle: float = 0.0
	for _sample: int in range(9):
		await tree.create_timer(0.015, true, false, true).timeout
		maximum_angle = maxf(maximum_angle, frame.rotation_degrees.length())
	assert_near(maximum_angle, 6.0, 0.20, "tilt reaches configured maximum")
	var before_switch: Vector3 = frame.rotation_degrees
	board.play_visual_tilt(Vector2i.UP)
	assert_near(
		frame.rotation_degrees.distance_to(before_switch),
		0.0,
		TOLERANCE,
		"continuous swipe retains the current angle"
	)
	await tree.create_timer(0.31, true, false, true).timeout
	assert_near(frame.rotation_degrees.length(), 0.0, 0.03, "tilt returns by 0.3 seconds")
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_enabled = original_fx
	Config.data.fx_tilt_degrees = original_degrees
	Config.data.fx_tilt_duration = original_duration


func test_swipe_trails_cover_four_directions_and_return_to_pool() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_trail: bool = Config.data.fx_swipe_trail_enabled
	var original_sfx: bool = Config.data.sfx_enabled
	Config.data.fx_enabled = true
	Config.data.fx_swipe_trail_enabled = true
	Config.data.sfx_enabled = false
	var fixture: Dictionary = await _create_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	for direction: Vector2i in OrbTypes.DIRECTIONS:
		director._on_turn_started(1, direction)
		assert_eq(director.active_swipe_trail_count(), 1, "one trail for %s" % direction)
		assert_eq(
			director.active_swipe_trails()[0].swipe_direction(),
			direction,
			"trail arrow follows %s" % direction
		)
		director._process(SwipeTrail.DURATION)
		assert_eq(director.active_swipe_trail_count(), 0, "trail clears at 0.2 seconds")
		assert_eq(director.swipe_trail_pool_count(), 1, "trail is pooled")
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_enabled = original_fx
	Config.data.fx_swipe_trail_enabled = original_trail
	Config.data.sfx_enabled = original_sfx


func test_orb_stretch_smoothly_interpolates_only_the_mesh() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_stretch: bool = Config.data.fx_orb_stretch_enabled
	Config.data.fx_enabled = true
	Config.data.fx_orb_stretch_enabled = true
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2(120.0, -80.0))
	var body: RigidBody3D = orb.get_physics_body()
	body.freeze = true
	var collision: SphereShape3D = orb._collision_shape.shape as SphereShape3D
	var collision_radius: float = collision.radius
	var physics_position: Vector3 = body.position
	var symbol_scale: Vector3 = orb._symbol_mesh.scale
	body.rotation = Vector3(0.0, 0.0, 0.25)
	orb.linear_velocity = Vector2(699.0, 0.0)
	orb._update_visual_transform()
	assert_near(
		orb.visual_mesh_scale().distance_to(Vector3.ONE),
		0.0,
		TOLERANCE,
		"699 px/s keeps original scale"
	)
	assert_near(orb._mesh.rotation.z, body.rotation.z, TOLERANCE, "zero ratio keeps body rotation")
	orb.linear_velocity = Vector2(900.0, 0.0)
	orb._update_visual_transform()
	assert_near(orb.visual_mesh_scale().x, 1.075, TOLERANCE, "900 px/s along midpoint")
	assert_near(orb.visual_mesh_scale().y, 0.96, TOLERANCE, "900 px/s perpendicular midpoint")
	assert_near(orb._mesh.rotation.z, 0.0, TOLERANCE, "stretch aligns with right velocity")
	orb.linear_velocity = Vector2(0.0, 900.0)
	orb._update_visual_transform()
	assert_near(orb._mesh.rotation.z, -PI * 0.5, TOLERANCE, "stretch follows plane velocity")
	orb.linear_velocity = Vector2(1101.0, 0.0)
	orb._update_visual_transform()
	assert_near(orb.visual_mesh_scale().x, 1.15, TOLERANCE, "1101 px/s along maximum")
	assert_near(orb.visual_mesh_scale().y, 0.92, TOLERANCE, "1101 px/s perpendicular maximum")
	orb.linear_velocity = Vector2(890.0, 0.0)
	orb._update_visual_transform()
	var scale_890: Vector3 = orb.visual_mesh_scale()
	orb.linear_velocity = Vector2(910.0, 0.0)
	orb._update_visual_transform()
	var scale_910: Vector3 = orb.visual_mesh_scale()
	var average_axis_change: float = (
		absf(scale_910.x - scale_890.x)
		+ absf(scale_910.y - scale_890.y)
		+ absf(scale_910.z - scale_890.z)
	) / 3.0
	assert_true(average_axis_change < 0.01, "890 to 910 px/s changes average scale by under 0.01")
	assert_near(collision.radius, collision_radius, TOLERANCE, "collision radius unchanged")
	assert_near(body.position.distance_to(physics_position), 0.0, TOLERANCE, "physics position unchanged")
	assert_near(orb._symbol_mesh.scale.distance_to(symbol_scale), 0.0, TOLERANCE, "symbol unchanged")
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_enabled = original_fx
	Config.data.fx_orb_stretch_enabled = original_stretch


func test_tilt_rotation_and_green_frame_shake_position_coexist_and_restore() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	Config.data.fx_enabled = true
	Config.data.fx_hitstop_enabled = false
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	var frame: Node3D = board.get_node("VisualTilt") as Node3D
	board.play_visual_tilt(Vector2i.RIGHT)
	director.play_reaction_visuals(_green_merge_reaction())
	await tree.create_timer(0.12, true, false, true).timeout
	assert_true(frame.rotation_degrees.length() > 0.0, "tilt owns frame rotation")
	assert_true(frame.position.length() > 0.0, "SHAKE owns frame position")
	await tree.create_timer(0.25, true, false, true).timeout
	assert_near(frame.rotation_degrees.length(), 0.0, 0.03, "tilt restores rotation")
	assert_near(frame.position.length(), 0.0, TOLERANCE, "SHAKE restores position")
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop


func test_swipe_sfx_and_pc_haptics_use_specified_durations() -> void:
	var original_sfx: bool = Config.data.sfx_enabled
	var original_haptics: bool = Config.data.haptics_enabled
	Config.data.sfx_enabled = true
	Config.data.haptics_enabled = true
	var fixture: Dictionary = await _create_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	var bank: SfxBank = director.sfx_bank()
	var haptics: Haptics = director.haptics()
	var swipe: AudioStreamWAV = bank.swipe_stream() as AudioStreamWAV
	assert_true(swipe != null and not swipe.data.is_empty(), "swipe synth is nonempty")
	assert_near(swipe.get_length(), 0.120, 0.002, "swipe synth duration")
	director._on_turn_started(1, Vector2i.RIGHT)
	assert_true(bank.last_voice().stream == swipe, "accepted swipe plays swipe stream")
	assert_eq(haptics.last_duration_ms(), 8, "swipe haptic duration")
	director.play_reaction({
		"type": ReactionRules.Type.BLAST,
		"levels": [4, 4],
		"colors": [OrbTypes.OrbColor.RED, OrbTypes.OrbColor.BLUE],
		"position": Vector2.ZERO,
	})
	assert_eq(haptics.last_duration_ms(), 25, "blast haptic duration")
	assert_eq(haptics.request_count(), 2, "one swipe and one blast haptic request")
	if not haptics.is_mobile_platform():
		assert_eq(haptics.platform_vibration_count(), 0, "PC performs no vibration call")
	await _cleanup(fixture["root"] as Node)
	Config.data.sfx_enabled = original_sfx
	Config.data.haptics_enabled = original_haptics


func test_gravity_switch_toggles_preserve_turn_and_blitz_state_hashes() -> void:
	var original_trail: bool = Config.data.fx_swipe_trail_enabled
	var original_stretch: bool = Config.data.fx_orb_stretch_enabled
	var original_haptics: bool = Config.data.haptics_enabled
	var original_sfx: bool = Config.data.sfx_enabled
	Config.data.sfx_enabled = false
	var turn_off: String = await _scripted_state_hash(false, false)
	var turn_on: String = await _scripted_state_hash(true, false)
	var blitz_off: String = await _scripted_state_hash(false, true)
	var blitz_on: String = await _scripted_state_hash(true, true)
	assert_eq(turn_on, turn_off, "20-turn state hash")
	assert_eq(blitz_on, blitz_off, "20-second BLITZ state hash")
	Config.data.fx_swipe_trail_enabled = original_trail
	Config.data.fx_orb_stretch_enabled = original_stretch
	Config.data.haptics_enabled = original_haptics
	Config.data.sfx_enabled = original_sfx


func test_gravity_switch_feedback_frame_cost_report() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	for index: int in range(16):
		director._on_turn_started(index, OrbTypes.DIRECTIONS[index % 4])
	for index: int in range(200):
		var orb: Orb3D = board.spawn_orb(
			index % Config.data.color_display.size(),
			1,
			Vector2(float(index % 20) * 4.0, float(index / 20) * 4.0)
		)
		orb.get_physics_body().freeze = true
		orb.linear_velocity = Vector2(900.0 + float(index), 0.0)
	var samples: Array[int] = []
	for _sample_index: int in range(200):
		var started_usec: int = Time.get_ticks_usec()
		director._process(0.000001)
		for orb: Orb3D in board.get_orbs():
			orb._update_visual_transform()
		samples.append(Time.get_ticks_usec() - started_usec)
	samples.sort()
	var p50: int = samples[samples.size() / 2]
	var p95: int = samples[floori(float(samples.size() - 1) * 0.95)]
	print("GRAVITY_SWITCH_FRAME_COST orbs=200 trails=16 samples=200 p50_us=%d p95_us=%d" % [p50, p95])
	await _cleanup(fixture["root"] as Node)


func _green_merge_reaction() -> Dictionary:
	return {
		"type": ReactionRules.Type.MERGE,
		"result_level": 2,
		"result_color": OrbTypes.OrbColor.GREEN,
		"position": Vector2.ZERO,
		"shock_targets": [],
	}


func _scripted_state_hash(enabled: bool, blitz: bool) -> String:
	Config.data.fx_swipe_trail_enabled = enabled
	Config.data.fx_orb_stretch_enabled = enabled
	Config.data.haptics_enabled = enabled
	var fixture: Dictionary = await _create_fixture()
	var root: Node3D = fixture["root"] as Node3D
	var board: Board3D = fixture["board"] as Board3D
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	for index: int in range(20):
		var direction: Vector2i = OrbTypes.DIRECTIONS[index % OrbTypes.DIRECTIONS.size()]
		board.set_gravity(direction)
		board.play_visual_tilt(direction)
		director._on_turn_started(index + 1, direction)
		var orb: Orb3D = board.spawn_orb(
			(index + (2 if blitz else 0)) % Config.data.color_display.size(),
			1 + index % (3 if blitz else 2),
			Vector2(float(index % 5) * 100.0, float(index / 5) * 100.0)
		)
		orb.get_physics_body().freeze = true
		orb.linear_velocity = Vector2(950.0 + float(index), 0.0)
		orb._update_visual_transform()
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
	return {"root": root, "board": board, "director": director}


func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await tree.process_frame
