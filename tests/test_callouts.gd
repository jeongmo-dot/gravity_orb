extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")


func test_jelly_turn_callout_stages_fire_once_per_chain() -> void:
	var original_enabled: bool = Config.data.fx_callouts_enabled
	var original_sfx_enabled: bool = Config.data.sfx_enabled
	Config.data.fx_callouts_enabled = true
	Config.data.sfx_enabled = false
	var main: Main = await _create_main()
	var hud: Hud = main.get_node("UI/Hud") as Hud
	for combo: int in range(1, 13):
		hud._on_combo_changed(combo, 1.0, combo)
	hud._on_combo_changed(12, 1.0, 12)
	assert_eq(hud.callout_history(), [3, 5, 8, 12], "JELLY turn callout stages fire once")
	hud._on_combo_changed(0, 1.0, 12)
	hud._on_combo_changed(3, 1.0, 12)
	assert_eq(
		hud.callout_history(),
		[3, 5, 8, 12, 3],
		"a new JELLY turn can use the same stage again"
	)
	await _destroy_main(main)
	Config.data.fx_callouts_enabled = original_enabled
	Config.data.sfx_enabled = original_sfx_enabled


func test_jelly_preview_and_unlock_use_jelly_art_and_names() -> void:
	var original_enabled: bool = Config.data.fx_callouts_enabled
	var original_sfx_enabled: bool = Config.data.sfx_enabled
	Config.data.fx_callouts_enabled = true
	Config.data.sfx_enabled = false
	var main: Main = await _create_main()
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var callout: Label = main.get_node("UI/Hud/CalloutLabel") as Label
	var unlock_visual: OrbVisual = main.get_node("UI/Hud/PlanetUnlockVisual") as OrbVisual
	var then_flash: ReferenceRect = (
		main.get_node("UI/Hud/ThenPreviewRegion/ThenUnlockFlash") as ReferenceRect
	)
	hud._on_planet_unlocked(OrbTypes.OrbColor.PURPLE)
	assert_eq(callout.text, "새 젤리 — 보라", "JELLY unlock uses jelly wording")
	assert_eq(unlock_visual.jelly_level(), 2, "JELLY unlock uses L2 jelly art")
	assert_eq(unlock_visual.celestial_level(), 0, "JELLY unlock has no planet art")
	assert_eq(
		unlock_visual.display_color(),
		JellyOrbArt.color_for(OrbTypes.OrbColor.PURPLE, 2),
		"JELLY unlock uses the level-lightened jelly color"
	)

	hud._on_preview_changed([
		[{"color": OrbTypes.OrbColor.RED, "level": 2}],
		[{"color": OrbTypes.OrbColor.CYAN, "level": 7}],
	])
	var next_visual: OrbVisual = hud._next_preview.get_child(0) as OrbVisual
	var then_visual: OrbVisual = hud._then_preview.get_child(0) as OrbVisual
	assert_eq(next_visual.jelly_level(), 2, "JELLY NEXT uses jelly preview")
	assert_eq(then_visual.jelly_level(), 7, "JELLY THEN uses MAX jelly face")
	assert_eq(next_visual.celestial_level(), 0, "JELLY NEXT does not use planet art")
	assert_eq(
		then_flash.border_color,
		JellyOrbArt.color_for(OrbTypes.OrbColor.CYAN, 7),
		"JELLY preview border uses the jelly level color"
	)
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()
	hud._show_planet_unlock(OrbTypes.OrbColor.CYAN)
	assert_eq(callout.text, "새 젤리 — 주황", "second JELLY unlock uses orange wording")
	assert_eq(
		unlock_visual.display_color(),
		JellyOrbArt.color_for(OrbTypes.OrbColor.CYAN, 2),
		"orange unlock uses the JELLY palette"
	)
	await _destroy_main(main)
	Config.data.fx_callouts_enabled = original_enabled
	Config.data.sfx_enabled = original_sfx_enabled


func test_callout_sound_uses_sfx_mute_and_stage_pitch() -> void:
	var original_sfx_enabled: bool = Config.data.sfx_enabled
	Config.data.sfx_enabled = true
	var main: Main = await _create_main()
	var sfx: SfxBank = main.get_node("FeedbackDirector/SfxBank") as SfxBank
	sfx.play_callout_chime(0)
	var low_pitch: float = sfx.last_voice().pitch_scale
	sfx.play_callout_chime(3)
	var high_pitch: float = sfx.last_voice().pitch_scale
	assert_true(high_pitch > low_pitch, "higher callout stage raises the chime pitch")
	sfx.set_muted(true, false)
	var bus_index: int = AudioServer.get_bus_index(SfxBank.SFX_BUS)
	assert_true(bus_index >= 0 and AudioServer.is_bus_mute(bus_index), "callout uses SFX mute")
	sfx.set_muted(false, false)
	for voice_index: int in range(sfx.voice_count()):
		var voice: AudioStreamPlayer = sfx.get_node("Voice%d" % voice_index) as AudioStreamPlayer
		voice.stop()
		voice.stream = null
	await tree.process_frame
	await tree.process_frame
	await _destroy_main(main)
	Config.data.sfx_enabled = original_sfx_enabled


func test_callout_toggle_hides_callout_and_preserves_jelly_state_hash() -> void:
	var original_enabled: bool = Config.data.fx_callouts_enabled
	var original_seed: int = Config.data.rng_seed
	var original_sfx_enabled: bool = Config.data.sfx_enabled
	Config.data.rng_seed = 4701
	Config.data.fx_callouts_enabled = false
	Config.data.sfx_enabled = false
	var main: Main = await _create_main()
	var hud: Hud = main.get_node("UI/Hud") as Hud
	for combo: int in [3, 5, 8, 12]:
		hud._on_combo_changed(combo, 1.0, combo)
	assert_eq(hud.callout_history(), [], "disabled callouts do not fire")
	assert_true(not (main.get_node("UI/Hud/CalloutLabel") as Label).visible, "callout hidden")
	await _destroy_main(main)

	var disabled_hash: String = await _presentation_state_hash(false)
	var enabled_hash: String = await _presentation_state_hash(true)
	assert_eq(enabled_hash, disabled_hash, "JELLY callout rendering preserves game state")
	Config.data.fx_callouts_enabled = original_enabled
	Config.data.rng_seed = original_seed
	Config.data.sfx_enabled = original_sfx_enabled


func test_jelly_callout_sits_between_combo_and_board() -> void:
	var original_sfx_enabled: bool = Config.data.sfx_enabled
	Config.data.sfx_enabled = false
	var main: Main = await _create_main()
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var callout: Label = main.get_node("UI/Hud/CalloutLabel") as Label
	var combo: Label = main.get_node("UI/Hud/ComboLabel") as Label
	hud._show_callout("INCREDIBLE!", 3)
	var callout_path: Rect2 = Rect2(
		hud._callout_base_position + Vector2.UP * Hud.CALLOUT_RISE_DISTANCE,
		callout.size + Vector2(0.0, Hud.CALLOUT_RISE_DISTANCE)
	)
	var board_rect: Rect2 = hud._projected_board_rect()
	assert_true(
		callout_path.position.y >= combo.get_global_rect().end.y,
		"callout rise path starts below the combo label"
	)
	assert_true(
		callout_path.end.y <= board_rect.position.y,
		"callout rise path ends above the board"
	)
	assert_true(
		not callout_path.intersects(board_rect),
		"callout never overlays the board"
	)
	assert_true(
		callout.get_theme_font_size("font_size") <= Hud.CALLOUT_FONT_MAX,
		"callout font shrinks to the available gap"
	)
	await _destroy_main(main)
	Config.data.sfx_enabled = original_sfx_enabled


func test_callout_frame_cost_report() -> void:
	var original_enabled: bool = Config.data.fx_callouts_enabled
	var original_sfx_enabled: bool = Config.data.sfx_enabled
	Config.data.fx_callouts_enabled = true
	Config.data.sfx_enabled = false
	var main: Main = await _create_main()
	var hud: Hud = main.get_node("UI/Hud") as Hud
	hud._on_combo_changed(12, 1.0, 12)
	var samples: Array[int] = []
	for _sample_index: int in range(400):
		var started_usec: int = Time.get_ticks_usec()
		hud._process(0.000001)
		samples.append(Time.get_ticks_usec() - started_usec)
	samples.sort()
	var p50: int = samples[samples.size() / 2]
	var p95: int = samples[floori(float(samples.size() - 1) * 0.95)]
	print("CALLOUT_FRAME_COST active=jelly_callout samples=400 p50_us=%d p95_us=%d" % [p50, p95])
	assert_true((main.get_node("UI/Hud/CalloutLabel") as Label).visible, "measurement keeps callout active")
	await _destroy_main(main)
	Config.data.fx_callouts_enabled = original_enabled
	Config.data.sfx_enabled = original_sfx_enabled


func _create_main() -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.JELLY)
	(main.get_node("ScoreManager") as ScoreManager).save_path = ""
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	(main.get_node("TurnManager") as TurnManager).set_physics_process(false)
	var board: Board3D = main.get_node("Board") as Board3D
	board.set_physics_process(false)
	for orb: Orb3D in board.get_orbs():
		orb.disable_physics()
	return main


func _destroy_main(main: Main) -> void:
	main.queue_free()
	await tree.process_frame
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.game_mode = GameConfig.GameMode.JELLY


func _presentation_state_hash(enabled: bool) -> String:
	Config.data.fx_callouts_enabled = enabled
	var main: Main = await _create_main()
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var board: Board3D = main.get_node("Board") as Board3D
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	for combo: int in range(1, 13):
		hud._on_combo_changed(combo, 1.0, combo)
	var orb_state: Array[Dictionary] = []
	for orb: Orb3D in board.get_orbs():
		orb_state.append({
			"id": orb.stable_spawn_id,
			"color": orb.color,
			"level": orb.level,
			"mass": orb.jelly_mass,
			"position": orb.position,
			"velocity": orb.linear_velocity,
		})
	var state_hash: String = JSON.stringify({
		"mode": Config.data.game_mode,
		"state": int(manager.state),
		"turn": manager.turn_index,
		"combo": manager.turn_combo,
		"orbs": orb_state,
	})
	await _destroy_main(main)
	return state_hash
