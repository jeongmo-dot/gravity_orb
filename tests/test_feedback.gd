extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const TOLERANCE: float = 1.0e-3

var _observed_play_calls: Array[Dictionary] = []


func test_blast_feedback_creates_and_cleans_non_ring_effects() -> void:
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
	assert_eq(director.active_particle_count(), 3, "two debris colors plus white sparks")
	assert_eq(director.active_light_count(), 1, "blast light count")
	assert_eq(director.active_glow_count(), 1, "L4 local nebula count")
	assert_eq(director.active_flash_count(), 0, "L4 has no full-screen flash")
	assert_eq(_forbidden_geometry_count(fixture["root"] as Node), 0, "blast creates no ring geometry")
	await tree.process_frame
	assert_true(
		absf(camera.h_offset) > 0.0 or absf(camera.v_offset) > 0.0,
		"camera shake offsets are applied"
	)
	await tree.create_timer(1.1, true, false, true).timeout
	assert_eq(director.active_particle_count(), 0, "particles clean before 1.5 seconds")
	assert_eq(director.active_light_count(), 0, "light cleans before 1.5 seconds")
	assert_eq(director.active_flash_count(), 0, "flash cleans before 1.5 seconds")
	assert_near(camera.h_offset, 0.0, TOLERANCE, "camera horizontal offset resets")
	assert_near(camera.v_offset, 0.0, TOLERANCE, "camera vertical offset resets")
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop
	Config.data.sfx_enabled = original_sfx


func test_merge_birth_blast_jackpot_and_max_create_no_ring_geometry() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	Config.data.fx_enabled = true
	Config.data.fx_hitstop_enabled = false
	var fixture: Dictionary = await _create_director_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	var reactions: Array[Dictionary] = [
		{
			"type": ReactionRules.Type.MERGE,
			"result_level": 3,
			"result_color": OrbTypes.OrbColor.CYAN,
			"position": Vector2.ZERO,
		},
		{
			"type": ReactionRules.Type.MERGE,
			"result_level": 6,
			"result_color": OrbTypes.OrbColor.YELLOW,
			"position": Vector2.ZERO,
		},
		_blast_reaction_for_level(6),
		{
			"type": ReactionRules.Type.MAX_CLEAR,
			"levels": [7, 7],
			"colors": [OrbTypes.OrbColor.RED, OrbTypes.OrbColor.RED],
			"result_color": OrbTypes.OrbColor.RED,
			"position": Vector2.ZERO,
			"shock_targets": [],
		},
	]
	for reaction: Dictionary in reactions:
		director.play_reaction_visuals(reaction)
		assert_eq(_forbidden_geometry_count(fixture["root"] as Node), 0, "reaction creates no ring geometry")
		director.clear_effects()
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop


func test_supernova_soft_cloud_is_mottled_and_rendered_behind_orbs() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	Config.data.fx_enabled = true
	Config.data.fx_hitstop_enabled = false
	var fixture: Dictionary = await _create_director_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	director.play_reaction_visuals(_blast_reaction_for_level(6))
	var glow_count: int = 0
	for effect: Dictionary in director._effects:
		if str(effect.get("kind", "")) != "glow":
			continue
		glow_count += 1
		var glow: MeshInstance3D = effect["node"] as MeshInstance3D
		assert_true(glow.position.z < 0.0, "supernova glow is behind the orb plane")
		assert_true(glow.position.z > -0.31, "supernova glow stays above board glass")
	var shader_code: String = director._effect_glow_shader.code
	assert_true(shader_code.contains("mottle"), "supernova cloud mixes colors with mottle noise")
	assert_true(shader_code.contains("soft_cloud"), "supernova keeps a soft cloud")
	assert_true(not shader_code.contains("float shell"), "supernova has no shell band")
	assert_true(not shader_code.contains("atan("), "supernova has no angle-based pinwheel")
	assert_eq(glow_count, 2, "L6 keeps the supernova and core as soft clouds behind orbs")
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop


func test_visual_prewarm_stops_when_director_leaves_tree() -> void:
	var root: Node3D = Node3D.new()
	var director: FeedbackDirector = FeedbackDirector.new()
	root.add_child(director)
	tree.root.add_child(root)
	await tree.process_frame
	director._resources_prewarmed = false
	director._prewarm_visual_resources_offscreen(true)
	root.remove_child(director)
	await tree.process_frame
	assert_true(
		not director._resources_prewarmed,
		"visual prewarm stops when its director leaves the scene tree"
	)
	director.free()
	await _cleanup(root)


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


func test_blast_effect_nodes_return_to_pool_and_are_reused() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	Config.data.fx_enabled = true
	Config.data.fx_hitstop_enabled = false
	var fixture: Dictionary = await _create_director_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	var initial_pool_count: int = director.blast_effect_pool_count()
	director.play_reaction_visuals(_blast_reaction())
	var first_ids: Array[int] = _active_blast_effect_ids(director)
	await tree.create_timer(1.1, true, false, true).timeout
	assert_eq(
		director.blast_effect_pool_count(),
		initial_pool_count,
		"completed blast returns all prewarmed nodes"
	)
	director.play_reaction_visuals(_blast_reaction())
	var second_ids: Array[int] = _active_blast_effect_ids(director)
	first_ids.sort()
	second_ids.sort()
	assert_eq(second_ids, first_ids, "second blast reuses the same effect nodes")
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop


func test_merge_punch_scales_visual_and_emits_stardust() -> void:
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
	board.set_gravity(Vector2i.ZERO)
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
	assert_eq(director.active_particle_count(), 1, "one stardust merge emitter")
	assert_eq(director.active_color_effect_count(), 1, "one color-mode merge effect")
	assert_eq(_forbidden_geometry_count(root), 0, "merge has no ring geometry")
	var particles: CPUParticles3D = (
		tree.get_nodes_in_group(&"feedback_particles")[0] as CPUParticles3D
	)
	assert_eq(particles.amount, 12, "merge stardust amount")
	assert_eq(
		((particles.mesh as QuadMesh).material as ShaderMaterial).render_priority,
		14,
		"merge and MAX foreground stars render after JELLY overlays"
	)
	assert_true(
		((particles.mesh as QuadMesh).material as ShaderMaterial).shader.code.contains(
			"depth_test_disabled"
		),
		"merge and MAX foreground stars stay visible across JELLY bodies"
	)
	await tree.create_timer(0.05, true, false, true).timeout
	assert_true(orb._mesh.scale.x > 1.0, "visual mesh punches outward")
	assert_near(collision.radius, collision_radius, TOLERANCE, "collision radius is unchanged")
	await tree.create_timer(0.15, true, false, true).timeout
	assert_near(orb._mesh.scale.x, 1.0, TOLERANCE, "visual mesh returns to base scale")
	assert_near(collision.radius, collision_radius, TOLERANCE, "collision remains unchanged")
	await _cleanup(root)
	Config.data.fx_enabled = original_fx
	Config.data.sfx_enabled = original_sfx


func test_l6_l7_birth_effects_keep_particles_and_cloud_without_ring_geometry() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	var original_sfx: bool = Config.data.sfx_enabled
	Config.data.fx_enabled = true
	Config.data.fx_hitstop_enabled = false
	Config.data.sfx_enabled = false
	var fixture: Dictionary = await _create_director_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	for level: int in [6, 7]:
		director.play_reaction_visuals({
			"type": ReactionRules.Type.MERGE,
			"result_level": level,
			"result_color": OrbTypes.OrbColor.YELLOW,
			"position": Vector2.ZERO,
		})
		assert_eq(director.active_particle_count(), 2, "L%d color+white accretion" % level)
		assert_eq(director.active_color_effect_count(), 1, "L%d uses color effect" % level)
		assert_eq(director.active_glow_count(), 1, "L%d nova" % level)
		assert_eq(_forbidden_geometry_count(fixture["root"] as Node), 0, "L%d birth has no ring geometry" % level)
		director.clear_effects()
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop
	Config.data.sfx_enabled = original_sfx


func test_blast_flash_levels_and_rolling_rate_limit() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	Config.data.fx_enabled = true
	Config.data.fx_hitstop_enabled = false
	var fixture: Dictionary = await _create_director_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	for level: int in [4, 5]:
		director.play_reaction_visuals(_blast_reaction_for_level(level))
	assert_eq(director.active_flash_count(), 0, "L4/L5 do not use full-screen flash")
	director.clear_effects()
	for _index: int in range(5):
		director.play_reaction_visuals(_blast_reaction_for_level(6))
	assert_eq(director.active_flash_count(), 3, "only three L6 flashes are accepted")
	assert_eq(director.full_screen_flash_count_last_second(), 3, "rolling window caps at three")
	assert_eq(director.full_screen_flash_accepted_total(), 3, "accepted flash diagnostics")
	assert_eq(director.full_screen_flash_skipped_total(), 2, "excess flash diagnostics")
	for flash_node: Node in tree.get_nodes_in_group(&"feedback_flash"):
		var flash: ColorRect = flash_node as ColorRect
		assert_true(flash.color.a <= 0.1501, "full-screen flash alpha is capped")
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop


func test_maximum_reaction_burst_uses_only_prewarmed_nodes() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	var original_color_visuals: bool = Config.data.fx_color_effect_visuals_enabled
	Config.data.fx_enabled = true
	Config.data.fx_hitstop_enabled = false
	Config.data.fx_color_effect_visuals_enabled = false
	var fixture: Dictionary = await _create_director_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	var totals_before: Dictionary = {}
	for kind: String in ["particles", "light", "flash", "glow"]:
		totals_before[kind] = director.blast_effect_pool_count(kind)
	for blast_level: int in [4, 5, 6]:
		director.play_reaction_visuals(_blast_reaction_for_level(blast_level))
	for merge_index: int in range(10):
		director.play_reaction_visuals({
			"type": ReactionRules.Type.MERGE,
			"result_level": 2 + merge_index % 6,
			"result_color": merge_index % 6,
			"position": Vector2.ZERO,
		})
	var active_by_kind: Dictionary = {
		"particles": director.active_particle_count(),
		"light": director.active_light_count(),
		"flash": director.active_flash_count(),
		"glow": director.active_glow_count(),
	}
	for kind: String in totals_before:
		assert_eq(
			director.blast_effect_pool_count(kind) + int(active_by_kind[kind]),
			int(totals_before[kind]),
			"maximum burst does not allocate %s nodes" % kind
		)
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop
	Config.data.fx_color_effect_visuals_enabled = original_color_visuals


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
	assert_near(pop.get_length(), 0.045, 0.002, "pop synth duration")
	assert_near(blast.get_length(), 0.460, 0.002, "blast synth duration")
	var pop_metrics: Dictionary = _waveform_metrics(pop)
	var blast_metrics: Dictionary = _waveform_metrics(blast)
	assert_true(float(pop_metrics["peak_time_ms"]) <= 5.0, "pop peak is within first 5ms")
	assert_true(
		float(blast_metrics["peak_time_ms"]) <= 10.0,
		"blast peak is within first 10ms"
	)
	print("SFX_WAVEFORM pop=%s blast=%s" % [
		JSON.stringify(pop_metrics),
		JSON.stringify(blast_metrics),
	])
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


func test_reaction_signal_calls_sfx_play_synchronously_once() -> void:
	var original_fx: bool = Config.data.fx_enabled
	var original_sfx: bool = Config.data.sfx_enabled
	Config.data.fx_enabled = false
	Config.data.sfx_enabled = true
	var fixture: Dictionary = await _create_director_fixture()
	var director: FeedbackDirector = fixture["director"] as FeedbackDirector
	var bank: SfxBank = director.sfx_bank()
	_observed_play_calls.clear()
	bank.play_called.connect(_record_play_called)
	var reaction_usec: int = Time.get_ticks_usec()
	var reaction_physics_frame: int = Engine.get_physics_frames()
	var reaction_process_frame: int = Engine.get_process_frames()
	director._on_reaction_ready({
		"type": ReactionRules.Type.MERGE,
		"result_level": 2,
		"chain": 1,
		"reaction_applied_usec": reaction_usec,
		"reaction_physics_frame": reaction_physics_frame,
		"reaction_process_frame": reaction_process_frame,
	})
	assert_eq(_observed_play_calls.size(), 1, "SFX play is called inside reaction handler")
	var call: Dictionary = _observed_play_calls[0]
	assert_eq(int(call["reaction_usec"]), reaction_usec, "reaction timestamp reaches play")
	assert_eq(int(call["play_physics_frame"]), reaction_physics_frame, "same physics frame")
	assert_eq(int(call["play_process_frame"]), reaction_process_frame, "same process frame")
	await tree.process_frame
	assert_eq(_observed_play_calls.size(), 1, "deferred VFX does not replay SFX")
	await _cleanup(fixture["root"] as Node)
	Config.data.fx_enabled = original_fx
	Config.data.sfx_enabled = original_sfx


func _blast_reaction() -> Dictionary:
	var levels: Array[int] = [4, 4]
	var colors: Array[int] = [OrbTypes.OrbColor.RED, OrbTypes.OrbColor.BLUE]
	return {
		"type": ReactionRules.Type.BLAST,
		"levels": levels,
		"colors": colors,
		"position": Vector2.ZERO,
	}


func _blast_reaction_for_level(level: int) -> Dictionary:
	var levels: Array[int] = [level, level]
	var colors: Array[int] = [OrbTypes.OrbColor.RED, OrbTypes.OrbColor.BLUE]
	return {
		"type": ReactionRules.Type.BLAST,
		"levels": levels,
		"colors": colors,
		"position": Vector2.ZERO,
	}


func _active_blast_effect_ids(director: FeedbackDirector) -> Array[int]:
	var result: Array[int] = []
	for effect: Dictionary in director._effects:
		var node: Node = effect.get("node") as Node
		if is_instance_valid(node):
			result.append(node.get_instance_id())
	return result


func _create_director_fixture() -> Dictionary:
	var root: Node3D = Node3D.new()
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 0.0, 42.0)
	camera.fov = 25.0
	camera.current = true
	root.add_child(camera)
	var director: FeedbackDirector = FeedbackDirector.new()
	director.name = "FeedbackDirector"
	root.add_child(director)
	tree.root.add_child(root)
	await tree.process_frame
	return {"root": root, "camera": camera, "director": director}


func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await tree.process_frame


func _forbidden_geometry_count(root: Node) -> int:
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


func _record_play_called(
	kind: String,
	reaction_usec: int,
	play_usec: int,
	reaction_physics_frame: int,
	play_physics_frame: int,
	reaction_process_frame: int,
	play_process_frame: int
) -> void:
	_observed_play_calls.append({
		"kind": kind,
		"reaction_usec": reaction_usec,
		"play_usec": play_usec,
		"reaction_physics_frame": reaction_physics_frame,
		"play_physics_frame": play_physics_frame,
		"reaction_process_frame": reaction_process_frame,
		"play_process_frame": play_process_frame,
	})


func _waveform_metrics(stream: AudioStreamWAV) -> Dictionary:
	var data: PackedByteArray = stream.data
	var sample_count: int = data.size() / 2
	var peak_index: int = 0
	var peak_amplitude: float = 0.0
	var first_ten_ms_energy: float = 0.0
	var total_energy: float = 0.0
	var first_ten_samples: int = roundi(float(stream.mix_rate) * 0.010)
	for sample_index: int in range(sample_count):
		var sample: float = float(data.decode_s16(sample_index * 2)) / 32767.0
		var amplitude: float = absf(sample)
		if amplitude > peak_amplitude:
			peak_amplitude = amplitude
			peak_index = sample_index
		var energy: float = sample * sample
		total_energy += energy
		if sample_index < first_ten_samples:
			first_ten_ms_energy += energy
	return {
		"peak_time_ms": float(peak_index) * 1000.0 / float(stream.mix_rate),
		"peak_amplitude": peak_amplitude,
		"first_10ms_energy_ratio": (
			first_ten_ms_energy / total_energy if total_energy > 0.0 else 0.0
		),
	}
