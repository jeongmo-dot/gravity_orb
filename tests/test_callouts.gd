extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const TOLERANCE: float = 1.0e-3


func test_turn_and_blitz_callout_stages_fire_once_per_chain() -> void:
	var original_enabled: bool = Config.data.fx_callouts_enabled
	Config.data.fx_callouts_enabled = true
	var turn_main: Main = await _create_main(GameConfig.GameMode.TURN)
	var turn_hud: Hud = turn_main.get_node("UI/Hud") as Hud
	for combo: int in range(1, 13):
		turn_hud._on_combo_changed(combo, 1.0, combo)
	turn_hud._on_combo_changed(12, 1.0, 12)
	assert_eq(turn_hud.callout_history(), [3, 5, 8, 12], "turn callout stages once")
	turn_hud._on_combo_changed(0, 1.0, 12)
	turn_hud._on_combo_changed(3, 1.0, 12)
	assert_eq(
		turn_hud.callout_history(),
		[3, 5, 8, 12, 3],
		"new turn can call the same stage again"
	)
	await _destroy_main(turn_main)

	var blitz_main: Main = await _create_main(GameConfig.GameMode.BLITZ)
	var blitz_hud: Hud = blitz_main.get_node("UI/Hud") as Hud
	for chain: int in range(1, 31):
		blitz_hud._on_combo_changed(chain, 1.0, chain)
	blitz_hud._on_combo_changed(30, 1.0, 30)
	assert_eq(
		blitz_hud.callout_history(),
		[5, 10, 15, 20, 30],
		"BLITZ callout stages once"
	)
	var callout_label: Label = blitz_main.get_node("UI/Hud/CalloutLabel") as Label
	assert_eq(callout_label.text, "UNSTOPPABLE!", "chain thirty uses final callout")
	blitz_hud._on_combo_changed(0, 1.0, 30)
	blitz_hud._on_combo_changed(5, 1.0, 30)
	assert_eq(blitz_hud.callout_history().count(5), 2, "new chain resets stage guard")
	await _destroy_main(blitz_main)
	Config.data.fx_callouts_enabled = original_enabled


func test_fever_vignette_only_lives_during_fever_and_uses_reusable_nodes() -> void:
	var original_enabled: bool = Config.data.fx_callouts_enabled
	Config.data.fx_callouts_enabled = true
	var main: Main = await _create_main(GameConfig.GameMode.BLITZ)
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var vignette: ColorRect = main.get_node("UI/Hud/FeverVignette") as ColorRect
	var band: ColorRect = main.get_node("UI/Hud/FeverBand") as ColorRect
	var band_label: Label = main.get_node("UI/Hud/FeverBand/FeverBandLabel") as Label
	var combo_label: Label = main.get_node("UI/Hud/ComboLabel") as Label
	assert_true(not vignette.visible, "vignette starts hidden")
	hud._on_fever_changed(true, 3.0)
	assert_true(vignette.visible and band.visible, "fever shows reusable overlay")
	assert_eq(band_label.text, "FEVER ×2", "fever entry band names multiplier")
	assert_true(band_label.get_theme_constant("outline_size") > 0, "fever band text has outline")
	assert_true(band.color.a <= 0.55 + TOLERANCE, "fever band alpha cap")
	assert_near(band.size.y, 80.0, TOLERANCE, "fever band uses half-height strip")
	assert_true(combo_label.text.contains("FEVER ×2  3.0s"), "fever time uses top badge")
	assert_true(not main.has_node("UI/Hud/FeverLabel"), "legacy centered fever label removed")
	assert_true(hud.fever_vignette_max_alpha() <= 0.12, "vignette edge alpha cap")
	var first_band_id: int = band.get_instance_id()
	hud._process(0.125)
	assert_true(vignette.modulate.a > 0.0, "fever vignette pulses")
	await tree.create_timer(1.2, true, false, true).timeout
	assert_true(not band.visible, "fever entry band hides after entry hold and exit")
	assert_true(vignette.visible, "fever vignette remains for active fever")
	assert_true(combo_label.text.contains("FEVER ×2"), "top fever badge remains after band exits")
	hud._on_fever_changed(true, 2.0)
	assert_eq(band.get_instance_id(), first_band_id, "fever refresh reuses overlay node")
	assert_true(not band.visible, "fever refresh does not replay entry band")
	hud._on_fever_changed(false, 0.0)
	await tree.create_timer(0.31, true, false, true).timeout
	assert_true(not vignette.visible and not band.visible, "fever end fades overlay")
	assert_eq(band.get_instance_id(), first_band_id, "hidden fever node remains pooled")
	await _destroy_main(main)
	Config.data.fx_callouts_enabled = original_enabled


func test_blitz_timer_ticks_exactly_ten_times_with_urgent_last_three() -> void:
	var original_enabled: bool = Config.data.fx_callouts_enabled
	Config.data.fx_callouts_enabled = true
	var main: Main = await _create_main(GameConfig.GameMode.BLITZ)
	var hud: Hud = main.get_node("UI/Hud") as Hud
	hud._on_time_changed(10.1)
	for second: int in range(10, 0, -1):
		hud._on_time_changed(float(second) - 0.1)
	hud._on_time_changed(6.2)
	hud._on_time_changed(5.8)
	assert_eq(
		hud.timer_tick_history(),
		[10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
		"timer ticks once for every final second"
	)
	assert_eq(hud.urgent_timer_tick_history(), [3, 2, 1], "last three use urgent tick")
	await _destroy_main(main)
	Config.data.fx_callouts_enabled = original_enabled


func test_time_bonus_flies_to_timer_flashes_green_and_time_up_cleans() -> void:
	var original_enabled: bool = Config.data.fx_callouts_enabled
	Config.data.fx_callouts_enabled = true
	var main: Main = await _create_main(GameConfig.GameMode.BLITZ)
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var bonus_label: Label = main.get_node("UI/Hud/BonusLabel") as Label
	var timer_label: Label = main.get_node("UI/Hud/TimerLabel") as Label
	var time_up_label: Label = main.get_node("UI/Hud/TimeUpLabel") as Label
	hud._on_time_changed(8.0)
	hud._on_time_bonus_awarded(1.0, "BLAST")
	hud._on_reaction_scored({
		"type": ReactionRules.Type.BLAST,
		"position": Vector2(120.0, -80.0),
		"occupancy": 0.0,
		"points": 0,
	})
	assert_true(bonus_label.visible, "time bonus starts at reaction")
	assert_eq(bonus_label.text, "+1s", "time bonus text")
	await tree.create_timer(0.56, true, false, true).timeout
	await tree.process_frame
	assert_near(bonus_label.position.x, hud.timer_bonus_target().x, 0.5, "bonus ends at timer x")
	assert_near(bonus_label.position.y, hud.timer_bonus_target().y, 0.5, "bonus ends at timer y")
	assert_near(hud.last_bonus_target().x, hud.timer_bonus_target().x, 0.5, "recorded target x")
	assert_near(hud.last_bonus_target().y, hud.timer_bonus_target().y, 0.5, "recorded target y")
	assert_true(timer_label.modulate.g > timer_label.modulate.r, "timer flashes green")
	hud._on_finale_started()
	assert_true(time_up_label.visible, "TIME UP appears before finale")
	assert_eq(hud.time_up_count(), 1, "time up fires once")
	await tree.create_timer(1.1, true, false, true).timeout
	assert_true(not bonus_label.visible, "bonus visual cleans before 1.5 seconds")
	assert_true(not time_up_label.visible, "time up visual cleans before 1.5 seconds")
	await _destroy_main(main)
	Config.data.fx_callouts_enabled = original_enabled


func test_new_sounds_share_sfx_mute_and_raise_callout_pitch() -> void:
	var main: Main = await _create_main(GameConfig.GameMode.TURN)
	var sfx: SfxBank = main.get_node("FeedbackDirector/SfxBank") as SfxBank
	sfx.play_callout_chime(0)
	var low_pitch: float = sfx.last_voice().pitch_scale
	sfx.play_callout_chime(4)
	var high_pitch: float = sfx.last_voice().pitch_scale
	assert_true(high_pitch > low_pitch, "higher callout stage raises chime")
	sfx.play_fever_sweep(true)
	assert_true(sfx.last_voice().stream != null, "fever sweep is synthesized")
	sfx.play_timer_tick(false)
	var normal_tick_volume: float = sfx.last_voice().volume_db
	sfx.play_timer_tick(true)
	assert_true(sfx.last_voice().pitch_scale > 1.0, "urgent tick is higher")
	assert_true(sfx.last_voice().volume_db > normal_tick_volume, "urgent tick is louder")
	sfx.play_time_up_buzzer()
	assert_true(sfx.last_voice().stream != null, "time-up buzzer is synthesized")
	sfx.set_muted(true, false)
	var bus_index: int = AudioServer.get_bus_index(SfxBank.SFX_BUS)
	assert_true(bus_index >= 0 and AudioServer.is_bus_mute(bus_index), "new sounds share mute")
	sfx.set_muted(false, false)
	for voice_index: int in range(sfx.voice_count()):
		var voice: AudioStreamPlayer = sfx.get_node("Voice%d" % voice_index) as AudioStreamPlayer
		voice.stop()
		voice.stream = null
	await tree.create_timer(0.05, true, false, true).timeout
	await _destroy_main(main)


func test_callout_toggle_hides_all_effects_and_preserves_state_hashes() -> void:
	var original_enabled: bool = Config.data.fx_callouts_enabled
	var original_seed: int = Config.data.rng_seed
	Config.data.rng_seed = 4701
	Config.data.fx_callouts_enabled = false
	var main: Main = await _create_main(GameConfig.GameMode.BLITZ)
	var hud: Hud = main.get_node("UI/Hud") as Hud
	hud._on_combo_changed(5, 1.0, 5)
	hud._on_fever_changed(true, 3.0)
	hud._on_time_changed(10.1)
	hud._on_time_changed(9.9)
	hud._on_time_bonus_awarded(1.0, "BLAST")
	hud._on_finale_started()
	assert_eq(hud.callout_history(), [], "disabled callouts do not fire")
	assert_eq(hud.timer_tick_history(), [], "disabled timer does not tick")
	assert_true(not (main.get_node("UI/Hud/CalloutLabel") as Label).visible, "callout hidden")
	assert_true(not (main.get_node("UI/Hud/FeverVignette") as ColorRect).visible, "fever hidden")
	assert_true(not (main.get_node("UI/Hud/TimeUpLabel") as Label).visible, "time up hidden")
	await _destroy_main(main)

	var turn_off: String = await _presentation_state_hash(false, GameConfig.GameMode.TURN)
	var turn_on: String = await _presentation_state_hash(true, GameConfig.GameMode.TURN)
	var blitz_off: String = await _presentation_state_hash(false, GameConfig.GameMode.BLITZ)
	var blitz_on: String = await _presentation_state_hash(true, GameConfig.GameMode.BLITZ)
	assert_eq(turn_on, turn_off, "20-turn callout state hash")
	assert_eq(blitz_on, blitz_off, "20-second BLITZ callout state hash")
	Config.data.fx_callouts_enabled = original_enabled
	Config.data.rng_seed = original_seed


func test_callout_frame_cost_report() -> void:
	var original_enabled: bool = Config.data.fx_callouts_enabled
	Config.data.fx_callouts_enabled = true
	var main: Main = await _create_main(GameConfig.GameMode.BLITZ)
	var hud: Hud = main.get_node("UI/Hud") as Hud
	hud._on_combo_changed(5, 1.0, 5)
	hud._on_fever_changed(true, 3.0)
	hud._on_time_changed(2.9)
	var samples: Array[int] = []
	for _sample_index: int in range(400):
		var started_usec: int = Time.get_ticks_usec()
		hud._process(0.000001)
		samples.append(Time.get_ticks_usec() - started_usec)
	samples.sort()
	var p50: int = samples[samples.size() / 2]
	var p95: int = samples[floori(float(samples.size() - 1) * 0.95)]
	print("CALLOUT_FRAME_COST active=callout+fever+timer samples=400 p50_us=%d p95_us=%d" % [p50, p95])
	await _destroy_main(main)
	Config.data.fx_callouts_enabled = original_enabled


func _create_main(mode: GameConfig.GameMode) -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(mode)
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	score.save_path = ""
	var sfx: SfxBank = main.get_node("FeedbackDirector/SfxBank") as SfxBank
	sfx.save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	(main.get_node("TurnManager") as TurnManager).set_physics_process(false)
	(main.get_node("BlitzManager") as BlitzManager).set_physics_process(false)
	var board: Board = main.get_node("Board") as Board
	board.set_physics_process(false)
	for orb: Orb in board.get_orbs():
		orb.freeze = true
		orb.linear_velocity = Vector2.ZERO
	return main


func _destroy_main(main: Main) -> void:
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.game_mode = GameConfig.GameMode.TURN


func _presentation_state_hash(enabled: bool, mode: GameConfig.GameMode) -> String:
	Config.data.fx_callouts_enabled = enabled
	var main: Main = await _create_main(mode)
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var board: Board = main.get_node("Board") as Board
	var manager: Variant = (
		main.get_node("BlitzManager")
		if mode == GameConfig.GameMode.BLITZ
		else main.get_node("TurnManager")
	)
	for orb: Orb in board.get_orbs():
		orb.freeze = true
		orb.linear_velocity = Vector2.ZERO
	for index: int in range(20):
		var combo: int = index + 1
		hud._on_combo_changed(combo, 1.0, combo)
		if mode == GameConfig.GameMode.BLITZ:
			hud._on_time_changed(20.5 - float(index))
			if index == 5:
				hud._on_fever_changed(true, 3.0)
			elif index == 8:
				hud._on_fever_changed(false, 0.0)
	var orb_state: Array[Dictionary] = []
	for orb: Orb in board.get_orbs():
		orb_state.append({
			"id": orb.stable_spawn_id,
			"color": orb.color,
			"level": orb.level,
			"position": orb.position,
			"velocity": orb.linear_velocity,
		})
	var state_hash: String = JSON.stringify({
		"mode": mode,
		"state": int(manager.state),
		"turn": int(manager.turn_index),
		"combo": int(manager.turn_combo),
		"orbs": orb_state,
	})
	await _destroy_main(main)
	return state_hash
