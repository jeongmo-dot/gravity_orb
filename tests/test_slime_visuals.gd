extends TestCase

const CONFIG: SlimeConfig = preload("res://config/slime_config.tres")


func test_original_korean_messages_and_merge_visual_state() -> void:
	var sim := SlimeSim.new(CONFIG, 801, true, false)
	sim.turn = 1
	_add_touching_pair(sim, Vector2(200.0, 430.0), 0, 1)
	sim.resolve_pairs()
	assert_eq(sim.message, "흡수!  +50", "single merge message")
	assert_eq(sim.slimes.size(), 1, "merge result exists")
	assert_true(sim.slimes[0].visual_scale >= 0.68 and sim.slimes[0].visual_scale <= 0.88, "merge starts from source-size scale")
	assert_near(sim.slimes[0].merge_glow, 1.0, 1.0e-6, "merge glow starts full")
	assert_near(sim.slimes[0].impact, 0.0, 1.0e-6, "merge does not fake an impact")
	var events: Array[Dictionary] = sim.drain_events()
	var absorbed: Dictionary = _first_event(events, "absorbed")
	assert_true(not absorbed.is_empty(), "merge event emitted")
	assert_true(absorbed.has("source_a_position") and absorbed.has("source_b_position"), "merge event keeps source visuals")
	assert_eq(int(absorbed.get("gained_score", 0)), 50, "merge event score")

	_add_touching_pair(sim, Vector2(450.0, 650.0), 1, 1)
	sim.resolve_pairs()
	assert_eq(sim.message, "2 CHAIN!  +63", "chain message")


func test_max_clear_unlock_and_turn_messages_use_spec_text() -> void:
	var max_sim := SlimeSim.new(CONFIG, 802, true, false)
	max_sim.turn = 1
	var radius: float = max_sim.radius_for_mass(32)
	max_sim.add_slime(Vector2(220.0, 520.0), 5, 2, Vector2.ZERO, 32)
	max_sim.add_slime(Vector2(220.0 + radius * 2.0, 520.0), 5, 2, Vector2.ZERO, 32)
	max_sim.resolve_pairs()
	assert_eq(max_sim.message, "MAX 슬라임 완성!  +4100", "max completion message")
	var chained_max := SlimeSim.new(CONFIG, 8021, true, false)
	chained_max.turn = 1
	chained_max.chain = 1
	chained_max.add_slime(Vector2(220.0, 520.0), 5, 2, Vector2.ZERO, 32)
	chained_max.add_slime(Vector2(220.0 + radius * 2.0, 520.0), 5, 2, Vector2.ZERO, 32)
	chained_max.resolve_pairs()
	assert_true(chained_max.message.begins_with("2 CHAIN!  +"), "chain message has priority over max message")

	var legacy_score_config: SlimeConfig = CONFIG.duplicate(true) as SlimeConfig
	legacy_score_config.color_unlock_mode = "score"
	legacy_score_config.color_unlock_turns = []
	legacy_score_config.turn_floor_steps = [Vector2i(30, 2), Vector2i(60, 3)]
	var unlock_sim := SlimeSim.new(legacy_score_config, 803, true, false)
	unlock_sim.turn = 1
	unlock_sim.score = 49950
	_add_touching_pair(unlock_sim, Vector2(250.0, 420.0), 0, 1)
	unlock_sim.resolve_pairs()
	assert_eq(unlock_sim.message, "새로운 색상 해금!  4 / 7", "unlock message has priority")

	var turn_sim := SlimeSim.new(CONFIG, 804, false, false)
	turn_sim.set_next_slimes([{"level": 0, "color": 0}, {"level": 1, "color": 1}])
	turn_sim.start_turn(Vector2i.LEFT)
	assert_eq(turn_sim.message, "중력 전환 · 슬라임 2마리 등장", "turn admission message")
	turn_sim.moving = false
	turn_sim.final_move_pending = true
	turn_sim.start_turn(Vector2i.DOWN)
	assert_eq(turn_sim.message, "FINAL MOVE · 공간을 다시 여세요", "final move start message")


func test_collision_sound_event_is_pair_only_and_strictly_above_threshold() -> void:
	var wall_sim := SlimeSim.new(CONFIG, 805, false, false)
	var wall_slime: SlimeSim.SlimeBody = wall_sim.add_slime(Vector2(10.0, 400.0), 0, 0, Vector2(-1000.0, 0.0))
	wall_sim._resolve_wall(wall_slime)
	assert_true(_first_event(wall_sim.drain_events(), "collision").is_empty(), "wall impact emits no collision sound")

	var pair_sim := SlimeSim.new(CONFIG, 806, false, false)
	var slime_radius: float = pair_sim.radius_for_level(0)
	var a: SlimeSim.SlimeBody = pair_sim.add_slime(Vector2(200.0, 500.0), 0, 0, Vector2(93.5, 0.0))
	var b: SlimeSim.SlimeBody = pair_sim.add_slime(Vector2(200.0 + slime_radius * 2.0 - 1.0, 500.0), 0, 1, Vector2(-93.5, 0.0))
	pair_sim.resolve_pairs()
	assert_true(_first_event(pair_sim.drain_events(), "collision").is_empty(), "exact 0.22 is silent")
	a.position = Vector2(200.0, 500.0)
	b.position = Vector2(200.0 + slime_radius * 2.0 - 1.0, 500.0)
	a.velocity = Vector2(100.0, 0.0)
	b.velocity = Vector2(-100.0, 0.0)
	pair_sim.resolve_pairs()
	assert_true(not _first_event(pair_sim.drain_events(), "collision").is_empty(), "above 0.22 emits pair collision sound")


func test_material_hud_entry_lengths_and_effect_lifetime_match_spec() -> void:
	var texture: Texture2D = SlimeView.material_texture(CONFIG, 0, 0)
	assert_eq(texture.get_width(), 384, "material texture width")
	assert_eq(texture.get_height(), 384, "material texture height")
	assert_true(texture == SlimeView.material_texture(CONFIG, 0, 0), "material texture is cached")
	var max_texture: Texture2D = SlimeView.material_texture(CONFIG, 0, CONFIG.radii.size() - 1)
	assert_eq(max_texture.get_width(), 512, "max material texture width")
	assert_eq(max_texture.get_height(), 512, "max material texture height")

	var sim := SlimeSim.new(CONFIG, 807, true, false)
	sim.score = 125
	sim.turn = 4
	sim.active_color_count = 5
	sim.completed_colors = {0: true, 2: true}
	sim.add_slime(Vector2(250.0, 500.0), 0, 0)
	var hud := SlimeHud.new()
	tree.root.add_child(hud)
	hud.bind(sim)
	var status: Dictionary = hud.status_texts()
	assert_eq(str(status["best"]), "BEST 000125", "best zero padding")
	assert_eq(str(status["score"]), "SCORE 000125", "score zero padding")
	assert_eq(str(status["turn"]), "TURN 04", "turn zero padding")
	assert_eq(str(status["info"]), "SLIME 1 · C 5/7 · MAX 2/7", "info line")

	var view := SlimeView.new()
	tree.root.add_child(view)
	view.bind(sim)
	assert_near(view.entry_bar_half_length(Vector2i.DOWN), 35.0, 1.0e-6, "current gravity bar length")
	assert_near(view.entry_bar_half_length(Vector2i.LEFT), 27.0, 1.0e-6, "other gravity bar length")
	view.handle_events([{
		"type": "absorbed",
		"position": Vector2(300.0, 500.0),
		"source_a_position": Vector2(270.0, 500.0),
		"source_b_position": Vector2(330.0, 500.0),
		"source_a_radius": 31.5,
		"source_b_radius": 31.5,
		"color": 0,
		"gained_score": 50,
	}])
	assert_eq(view.active_effect_count(), 1, "reaction effect starts")
	view.advance_visuals(0.86)
	assert_eq(view.active_effect_count(), 0, "reaction effect expires")
	view.queue_free()
	hud.queue_free()
	await tree.process_frame


func test_merge_trails_use_each_source_radius_for_absorb_and_max_clear() -> void:
	var sim := SlimeSim.new(CONFIG, 8071, true, false)
	var view := SlimeView.new()
	tree.root.add_child(view)
	view.bind(sim)
	view.handle_events([
		{
			"type": "absorbed",
			"position": Vector2(300.0, 500.0),
			"source_a_radius": 165.0,
			"source_b_radius": 31.5,
			"color": 0,
		},
		{
			"type": "max_clear",
			"position": Vector2(320.0, 520.0),
			"source_a_radius": 112.0,
			"source_b_radius": 42.0,
			"color_a": 1,
			"color_b": 2,
		},
	])
	var effects: Array = view.get("_effects") as Array
	assert_eq(effects.size(), 2, "absorb and MAX CLEAR each create one visual effect")
	var absorbed_radii: Vector2 = view._merge_trail_radii(
		effects[0] as Dictionary,
		0.0
	)
	assert_eq(
		absorbed_radii,
		Vector2(165.0, 31.5),
		"absorb trails start at each source radius"
	)
	var clear_radii: Vector2 = view._merge_trail_radii(
		effects[1] as Dictionary,
		0.5
	)
	var clear_radius_scale: float = lerpf(1.0, 0.04, 0.5)
	assert_near(
		clear_radii.x,
		112.0 * clear_radius_scale,
		1.0e-5,
		"MAX CLEAR A trail shrinks from source A radius"
	)
	assert_near(
		clear_radii.y,
		42.0 * clear_radius_scale,
		1.0e-5,
		"MAX CLEAR B trail shrinks from source B radius"
	)
	view.queue_free()
	await tree.process_frame


func test_rendered_entry_bars_and_max_clear_waves_stay_in_board_coordinates() -> void:
	# The headless display uses the dummy renderer and cannot return SubViewport pixels.
	# This regression is exercised by the dedicated windowed invocation documented for #80.
	if DisplayServer.get_name() == "headless":
		return
	var sim := SlimeSim.new(CONFIG, 808, true, false)
	sim.moving = false
	sim.gravity_direction = Vector2i.DOWN
	var last_slime: SlimeSim.SlimeBody = sim.add_slime(Vector2(485.0, 730.0), 2, 2)
	last_slime.rotation = 0.63
	last_slime.roll = 0.19
	last_slime.deform = Vector2(1.27, 0.72)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 920)
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var view := SlimeView.new()
	viewport.add_child(view)
	view.bind(sim)
	var effect_center := Vector2(320.0, 500.0)
	view.handle_events([{
		"type": "max_clear",
		"position": effect_center,
		"source_a_position": effect_center,
		"source_b_position": effect_center,
		"source_a_radius": 0.0,
		"source_b_radius": 0.0,
		"color_a": 0,
		"color_b": 1,
		"gained_score": 7500,
		"tick": 80,
	}])
	view.advance_visuals(0.17)
	view.refresh()
	await tree.process_frame
	await tree.process_frame
	RenderingServer.force_draw(true)
	var image: Image = viewport.get_texture().get_image()
	assert_eq(image.get_size(), Vector2i(640, 920), "offscreen render size")

	var board: Rect2 = CONFIG.board_rect
	var bar_samples: Dictionary = {
		Vector2i.DOWN: Vector2i(roundi(board.get_center().x), roundi(board.position.y)),
		Vector2i.UP: Vector2i(roundi(board.get_center().x), roundi(board.end.y)),
		Vector2i.RIGHT: Vector2i(roundi(board.position.x), roundi(board.get_center().y)),
		Vector2i.LEFT: Vector2i(roundi(board.end.x), roundi(board.get_center().y)),
	}
	for direction: Vector2i in bar_samples:
		var actual: Color = image.get_pixelv(bar_samples[direction] as Vector2i)
		var expected: Color = _entry_stage_color(sim.entry_stage_for(direction))
		assert_true(_color_distance(actual, expected) < 0.10, "entry bar %s stays centered on its board wall" % direction)

	var clear_radius: float = lerpf(16.0, 112.0, 0.25) * 1.65
	var right_pixel: Color = image.get_pixelv(Vector2i(roundi(effect_center.x + clear_radius), roundi(effect_center.y)))
	var left_pixel: Color = image.get_pixelv(Vector2i(roundi(effect_center.x - clear_radius), roundi(effect_center.y)))
	var color_a: Color = CONFIG.slime_colors[0].lightened(6.0 * CONFIG.level_lighten).lightened(0.30)
	var color_b: Color = CONFIG.slime_colors[1].lightened(6.0 * CONFIG.level_lighten).lightened(0.30)
	assert_true(_color_distance(right_pixel, color_a) < _color_distance(right_pixel, color_b), "MAX CLEAR right half uses color A at the reaction point")
	assert_true(_color_distance(left_pixel, color_b) < _color_distance(left_pixel, color_a), "MAX CLEAR left half uses color B at the reaction point")
	viewport.queue_free()
	await tree.process_frame


func test_six_slime_synths_share_sfx_bus_and_pitch_rules() -> void:
	var original_enabled: bool = Config.data.sfx_enabled
	Config.data.sfx_enabled = true
	var bank := SfxBank.new()
	bank.save_path = ""
	tree.root.add_child(bank)
	await tree.process_frame
	var expected: Dictionary = {
		"impact": 0.10,
		"gravity": 0.14,
		"merge": 0.20,
		"max": 0.34,
		"clear": 0.48,
		"game_over": 0.52,
	}
	for kind: String in expected:
		var stream: AudioStreamWAV = bank.slime_stream(kind)
		assert_true(stream != null and not stream.data.is_empty(), "%s synth exists" % kind)
		assert_eq(stream.mix_rate, 22050, "%s sample rate" % kind)
		assert_near(stream.get_length(), float(expected[kind]), 0.002, "%s duration" % kind)
	assert_true(bank.slime_impact_pitch(1.0) < bank.slime_impact_pitch(0.0), "strong impact lowers pitch")
	assert_true(bank.slime_chain_pitch(8) > bank.slime_chain_pitch(1), "chain raises merge pitch")
	bank.set_muted(true, false)
	var bus_index: int = AudioServer.get_bus_index(SfxBank.SFX_BUS)
	assert_true(bus_index >= 0 and AudioServer.is_bus_mute(bus_index), "slime sounds share SFX mute")
	bank.set_muted(false, false)
	bank.queue_free()
	await tree.process_frame
	Config.data.sfx_enabled = original_enabled


func _add_touching_pair(sim: SlimeSim, center: Vector2, color_index: int, mass_value: int) -> void:
	var radius: float = sim.radius_for_mass(mass_value)
	var level_value: int = sim.level_for_mass(mass_value)
	sim.add_slime(center - Vector2(radius, 0.0), level_value, color_index, Vector2.ZERO, mass_value)
	sim.add_slime(center + Vector2(radius, 0.0), level_value, color_index, Vector2.ZERO, mass_value)


func _first_event(events: Array[Dictionary], event_type: String) -> Dictionary:
	for event: Dictionary in events:
		if str(event.get("type", "")) == event_type:
			return event
	return {}


func _entry_stage_color(stage: int) -> Color:
	if stage == 2:
		return Color("ff5878")
	if stage == 1:
		return Color("ffd166")
	return Color("55e0bc")


func _color_distance(a: Color, b: Color) -> float:
	return Vector4(a.r - b.r, a.g - b.g, a.b - b.b, a.a - b.a).length()
