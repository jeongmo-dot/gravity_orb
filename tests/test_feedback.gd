extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const TOLERANCE: float = 1.0e-3


func test_blast_feedback_creates_and_cleans_all_effects() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	var original_sfx: bool = Config.data.sfx_enabled
	Config.data.fx_enabled = true
	Config.data.fx_hitstop_enabled = false
	Config.data.sfx_enabled = false
	var fixture: Dictionary = await _create_director_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	var camera: Camera3D = fixture["camera"] as Camera3D
	director.play_reaction({
		"type": ReactionRules.Type.BLAST,
		"levels": [4, 4],
		"colors": [OrbTypes.OrbColor.RED, OrbTypes.OrbColor.BLUE],
		"position": Vector2.ZERO,
	})
	assert_eq(director.active_ring_count(), 2, "blast ring count")
	assert_eq(director.active_particle_count(), 3, "two debris colors plus white sparks")
	assert_eq(director.active_light_count(), 1, "blast light count")
	assert_eq(director.active_flash_count(), 1, "screen flash count")
	await tree.process_frame
	assert_true(
		absf(camera.h_offset) > 0.0 or absf(camera.v_offset) > 0.0,
		"camera shake offsets are applied"
	)
	await tree.create_timer(1.1, true, false, true).timeout
	assert_eq(director.active_ring_count(), 0, "rings clean before 1.5 seconds")
	assert_eq(director.active_particle_count(), 0, "particles clean before 1.5 seconds")
	assert_eq(director.active_light_count(), 0, "light cleans before 1.5 seconds")
	assert_eq(director.active_flash_count(), 0, "flash cleans before 1.5 seconds")
	assert_near(camera.h_offset, 0.0, TOLERANCE, "camera horizontal offset resets")
	assert_near(camera.v_offset, 0.0, TOLERANCE, "camera vertical offset resets")
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop
	Config.data.sfx_enabled = original_sfx


func test_feedback_toggle_preserves_turn_and_blitz_state_hashes() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	var original_sfx: bool = Config.data.sfx_enabled
	Config.data.fx_hitstop_enabled = false
	Config.data.sfx_enabled = false
	var turn_without_fx: String = await _scripted_state_hash(false, false)
	var turn_with_fx: String = await _scripted_state_hash(true, false)
	var blitz_without_fx: String = await _scripted_state_hash(false, true)
	var blitz_with_fx: String = await _scripted_state_hash(true, true)
	assert_eq(turn_with_fx, turn_without_fx, "20-turn state hash")
	assert_eq(blitz_with_fx, blitz_without_fx, "20-second BLITZ state hash")
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop
	Config.data.sfx_enabled = original_sfx


func test_hitstop_uses_real_time_and_disabled_mode_does_not_change_scale() -> void:
	var original_enabled: bool = Config.data.fx_hitstop_enabled
	var original_scale: float = Engine.time_scale
	var fixture: Dictionary = await _create_director_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	Config.data.fx_hitstop_enabled = true
	director.begin_hitstop(0.03)
	assert_near(Engine.time_scale, Config.data.fx_hitstop_scale, TOLERANCE, "hitstop scale")
	await tree.create_timer(0.08, true, false, true).timeout
	assert_near(Engine.time_scale, 1.0, TOLERANCE, "hitstop restores real-time scale")
	Config.data.fx_hitstop_enabled = false
	director.begin_hitstop(0.03)
	assert_near(Engine.time_scale, 1.0, TOLERANCE, "disabled hitstop leaves scale unchanged")
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_hitstop_enabled = original_enabled
	Engine.time_scale = original_scale


func test_merge_punch_only_scales_visual_and_emits_ten_particles() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_sfx: bool = Config.data.sfx_enabled
	Config.data.fx_enabled = true
	Config.data.sfx_enabled = false
	var root: Node3D = Node3D.new()
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	root.add_child(camera)
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	root.add_child(board)
	var director: FeedbackDirector = FeedbackDirector.new()
	root.add_child(director)
	tree.root.add_child(root)
	await tree.process_frame
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 2, Vector2.ZERO)
	var collision: SphereShape3D = orb._collision_shape.shape as SphereShape3D
	var collision_radius: float = collision.radius
	director.play_reaction({
		"type": ReactionRules.Type.MERGE,
		"result_orb": orb,
		"result_level": 2,
		"result_color": OrbTypes.OrbColor.GREEN,
		"position": Vector2.ZERO,
		"chain": 1,
	})
	assert_eq(director.active_particle_count(), 1, "one ten-particle merge emitter")
	var particles: CPUParticles3D = (
		tree.get_nodes_in_group(&"feedback_particles")[0] as CPUParticles3D
	)
	assert_eq(particles.amount, 10, "merge particle amount")
	await tree.create_timer(0.05, true, false, true).timeout
	assert_true(orb._mesh.scale.x > 1.0, "visual mesh punches outward")
	assert_near(collision.radius, collision_radius, TOLERANCE, "collision radius is unchanged")
	await tree.create_timer(0.15, true, false, true).timeout
	assert_near(orb._mesh.scale.x, 1.0, TOLERANCE, "visual mesh returns to base scale")
	assert_near(collision.radius, collision_radius, TOLERANCE, "collision remains unchanged")
	await _cleanup(root)
	Config.data.fx_enabled = original_fx
	Config.data.sfx_enabled = original_sfx


func test_synthesized_sfx_pitch_volume_jitter_and_voice_pool() -> void:
	var original_jitter: float = Config.data.sfx_pitch_jitter
	var original_enabled: bool = Config.data.sfx_enabled
	var original_volume: float = Config.data.sfx_volume_db
	Config.data.sfx_enabled = true
	Config.data.sfx_volume_db = 0.0
	var fixture: Dictionary = await _create_director_fixture()
	var bank: SfxBank = (fixture["director"] as FeedbackDirector).sfx_bank()
	var pop: AudioStreamWAV = bank.pop_stream() as AudioStreamWAV
	var blast: AudioStreamWAV = bank.blast_stream() as AudioStreamWAV
	assert_true(pop != null and not pop.data.is_empty(), "pop synth is nonempty")
	assert_true(blast != null and not blast.data.is_empty(), "blast synth is nonempty")
	assert_near(pop.get_length(), 0.060, 0.002, "pop synth duration")
	assert_near(blast.get_length(), 0.460, 0.002, "blast synth duration")
	Config.data.sfx_pitch_jitter = 0.0
	assert_near(bank.merge_pitch(2, 1, 1), 1.35, TOLERANCE, "L2 base pitch")
	assert_near(bank.merge_pitch(7, 1, 1), 0.75, TOLERANCE, "L7 base pitch")
	assert_near(
		bank.merge_pitch(2, 2, 1),
		1.35 * pow(2.0, 1.0 / 12.0),
		TOLERANCE,
		"chain two rises one semitone"
	)
	assert_near(bank.merge_pitch(2, 13, 1), 2.70, TOLERANCE, "chain thirteen caps at octave")
	assert_near(bank.merge_pitch(2, 30, 1), 2.70, TOLERANCE, "later chains stay capped")
	Config.data.sfx_pitch_jitter = 0.03
	var first_jitter: float = bank.pitch_jitter(37)
	assert_near(bank.pitch_jitter(37), first_jitter, TOLERANCE, "stable id jitter repeats")
	assert_true(absf(first_jitter) <= 0.03, "stable jitter is bounded")
	bank.play_merge(2, 1, 37)
	assert_near(bank.last_voice().volume_db, 0.0, TOLERANCE, "merge volume")
	bank.play_blast(false)
	assert_near(bank.last_voice().volume_db, 4.0, TOLERANCE, "blast volume")
	bank.play_blast(true, 3)
	assert_near(bank.last_voice().volume_db, -2.0, TOLERANCE, "finale volume")
	assert_near(
		bank.last_voice().pitch_scale,
		pow(2.0, 2.0 / 12.0),
		TOLERANCE,
		"finale pitch ascends by semitone"
	)
	for index: int in range(20):
		bank.play_merge(2, 1, index)
	assert_eq(bank.voice_count(), 12, "voice pool capacity")
	assert_true(bank.active_voice_count() <= 12, "voice pool never exceeds capacity")
	await _cleanup(fixture["root"] as Node)
	Config.data.sfx_pitch_jitter = original_jitter
	Config.data.sfx_enabled = original_enabled
	Config.data.sfx_volume_db = original_volume


func _create_director_fixture() -> Dictionary:
	var root: Node3D = Node3D.new()
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	root.add_child(camera)
	var director: FeedbackDirector = FeedbackDirector.new()
	director.name = "FeedbackDirector"
	root.add_child(director)
	tree.root.add_child(root)
	await tree.process_frame
	return {"root": root, "camera": camera, "director": director}


func _scripted_state_hash(fx_enabled: bool, blitz: bool) -> String:
	Config.data.fx_enabled = fx_enabled
	var root: Node3D = Node3D.new()
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	root.add_child(camera)
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	root.add_child(board)
	var director: FeedbackDirector = FeedbackDirector.new()
	root.add_child(director)
	tree.root.add_child(root)
	await tree.process_frame
	var steps: int = 20
	for index: int in range(steps):
		var direction: Vector2i = OrbTypes.DIRECTIONS[index % OrbTypes.DIRECTIONS.size()]
		board.set_gravity(direction)
		var color: int = (index * 5 + (2 if blitz else 0)) % 6
		var level: int = 1 + index % (3 if blitz else 2)
		var position: Vector2 = Vector2(
			float((index % 5) * 120 - 240),
			float((index / 5) * 120 - 180)
		)
		var orb: Orb3D = board.spawn_orb(color, level, position)
		if index % 4 == 0:
			director.play_reaction({
				"type": ReactionRules.Type.MERGE,
				"result_orb": orb,
				"result_level": level,
				"result_color": color,
				"position": position,
				"chain": 1 + index,
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
