extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const MAIN_3D_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const TOLERANCE: float = 1.0e-3


func test_each_scored_reaction_shows_matching_popup_and_conditional_formula() -> void:
	var original_enabled: bool = Config.data.fx_score_popups_enabled
	Config.data.fx_score_popups_enabled = true
	var main: Main = await _create_main(GameConfig.GameMode.TURN)
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	var combo_reaction: Dictionary = _reaction(Vector2(-100.0, 0.0), 4.0, 0.20)
	score.on_reaction(combo_reaction)
	assert_eq(hud.active_score_popup_count(), 1, "one popup for one scored reaction")
	var combo_popup: ScorePopup = hud.active_score_popups()[0]
	assert_eq(combo_popup.score_text(), "+512", "popup uses awarded points")
	assert_eq(combo_popup.formula_text(), "128 ×4", "combo ×4 shows calculation")
	var danger_reaction: Dictionary = _reaction(Vector2(100.0, 0.0), 1.0, 0.50)
	score.on_reaction(danger_reaction)
	assert_eq(hud.active_score_popup_count(), 2, "separate reaction position gets popup")
	var danger_popup: ScorePopup = hud.active_score_popups()[1]
	assert_eq(danger_popup.score_text(), "+256", "danger popup uses awarded points")
	assert_eq(danger_popup.formula_text(), "128 ×2", "danger ×2 shows calculation")
	assert_eq(ScorePopup.popup_font_size(10), 34, "base popup font size")
	assert_true(
		ScorePopup.popup_font_size(1000) > ScorePopup.popup_font_size(10),
		"popup font grows logarithmically"
	)
	await _destroy_main(main)
	Config.data.fx_score_popups_enabled = original_enabled


func test_popup_capacity_evicts_oldest_and_same_frame_nearby_scores_merge() -> void:
	var original_enabled: bool = Config.data.fx_score_popups_enabled
	var original_max: int = Config.data.fx_popup_max
	Config.data.fx_score_popups_enabled = true
	Config.data.fx_popup_max = 16
	var main: Main = await _create_main(GameConfig.GameMode.TURN)
	var hud: Hud = main.get_node("UI/Hud") as Hud
	for index: int in range(16):
		hud._on_reaction_scored(_display_reaction(
			Vector2(-400.0 + float(index) * 50.0, 0.0), index + 1
		))
	var oldest: ScorePopup = hud.active_score_popups()[0]
	hud._on_reaction_scored(_display_reaction(Vector2(400.0, 0.0), 17))
	assert_eq(hud.active_score_popup_count(), 16, "seventeenth popup keeps cap at sixteen")
	assert_true(oldest.score_text() != "+1", "seventeenth popup evicts oldest content")
	assert_true(oldest.active, "evicted popup node is immediately reused from pool")
	await _destroy_main(main)

	main = await _create_main(GameConfig.GameMode.TURN)
	hud = main.get_node("UI/Hud") as Hud
	hud._on_reaction_scored(_display_reaction(Vector2.ZERO, 100))
	hud._on_reaction_scored(_display_reaction(Vector2(30.0, 0.0), 60))
	assert_eq(hud.active_score_popup_count(), 1, "same-frame reactions within 40 px merge")
	assert_eq(hud.active_score_popups()[0].score_text(), "+160", "merged popup sums scores")
	await _destroy_main(main)
	Config.data.fx_score_popups_enabled = original_enabled
	Config.data.fx_popup_max = original_max


func test_multiplier_has_four_color_stages() -> void:
	assert_eq(Hud.multiplier_stage_color(1.0), Color.WHITE, "×1 white")
	assert_eq(Hud.multiplier_stage_color(2.0), Color.YELLOW, "×2 yellow")
	assert_eq(Hud.multiplier_stage_color(4.0), Color.ORANGE, "×4 orange")
	assert_eq(Hud.multiplier_stage_color(8.0), Color.RED, "×8 red")


func test_popup_colors_follow_merge_blast_and_finale_rules() -> void:
	var main: Main = await _create_main(GameConfig.GameMode.TURN)
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var merge: Dictionary = hud._popup_appearance({
		"type": ReactionRules.Type.MERGE,
		"result_color": OrbTypes.OrbColor.BLUE,
	})
	var source_color: Color = Config.data.color_display[OrbTypes.OrbColor.BLUE]
	var expected_merge: Color = Color.from_hsv(
		source_color.h, source_color.s, 1.0, source_color.a
	)
	assert_eq(merge["color"], expected_merge, "merge uses bright result-orb color")
	var blast: Dictionary = hud._popup_appearance({"type": ReactionRules.Type.BLAST})
	assert_eq(blast["color"], Color.WHITE, "blast uses white text")
	assert_eq(blast["outline_color"], Hud.GOLD_COLOR, "blast uses gold outline")
	assert_true(int(blast["outline_size"]) > 0, "blast outline is visible")
	var finale: Dictionary = hud._popup_appearance({
		"type": ReactionRules.Type.BLAST,
		"finale": true,
	})
	assert_eq(finale["color"], Hud.GOLD_COLOR, "finale uses gold text")
	await _destroy_main(main)


func test_score_rolls_to_target_in_a_quarter_second() -> void:
	var original_enabled: bool = Config.data.fx_score_popups_enabled
	Config.data.fx_score_popups_enabled = true
	var main: Main = await _create_main(GameConfig.GameMode.TURN)
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	var score_label: Label = main.get_node("UI/Hud/ScoreLabel") as Label
	score.on_reaction(_reaction(Vector2.ZERO, 4.0, 0.20))
	assert_true(score_label.text != "SCORE\n512", "score does not jump immediately")
	await tree.create_timer(0.26, true, false, true).timeout
	assert_eq(score_label.text, "SCORE\n512", "score reaches target after 0.25 seconds")
	await _destroy_main(main)
	Config.data.fx_score_popups_enabled = original_enabled


func test_danger_refreshes_from_board_without_reaction() -> void:
	var main: Main = await _create_main(GameConfig.GameMode.TURN)
	var board: Board = main.get_node("Board") as Board
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var danger_label: Label = main.get_node("UI/Hud/DangerLabel") as Label
	for index: int in range(5):
		board.spawn_orb(
			index % Config.data.color_display.size(),
			Config.data.orb_max_level,
			Vector2(float(index - 2) * 150.0, 0.0)
		)
	hud._process(0.25)
	assert_true(danger_label.visible, "30 percent occupancy shows DANGER without reaction")
	assert_true(danger_label.text.begins_with("DANGER ×"), "danger badge shows multiplier")
	await _destroy_main(main)


func test_3d_reaction_position_is_unprojected_to_popup_anchor() -> void:
	var main: Main = MAIN_3D_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.TURN)
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	score.save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var projected_center: Vector2 = hud._reaction_screen_position(Vector2.ZERO)
	assert_near(projected_center.x, 540.0, 0.1, "3D board center projects to viewport center x")
	assert_near(projected_center.y, 960.0, 0.1, "3D board center projects to viewport center y")
	hud._on_reaction_scored(_display_reaction(Vector2.ZERO, 64))
	assert_eq(hud.active_score_popup_count(), 1, "3D reaction creates popup")
	var popup: ScorePopup = hud.active_score_popups()[0]
	assert_near(popup.anchor_position.x, projected_center.x, TOLERANCE, "popup anchor x")
	assert_near(popup.anchor_position.y, projected_center.y, TOLERANCE, "popup anchor y")
	await _destroy_main(main)


func test_score_popup_nodes_return_to_pool_before_one_point_five_seconds() -> void:
	var original_enabled: bool = Config.data.fx_score_popups_enabled
	Config.data.fx_score_popups_enabled = true
	var main: Main = await _create_main(GameConfig.GameMode.TURN)
	var hud: Hud = main.get_node("UI/Hud") as Hud
	hud._on_reaction_scored(_display_reaction(Vector2.ZERO, 1000))
	assert_eq(hud.active_score_popup_count(), 1, "large popup starts active")
	await tree.create_timer(1.0, true, false, true).timeout
	assert_eq(hud.active_score_popup_count(), 0, "large popup cleans within 1.5 seconds")
	assert_eq(hud._popup_pool.size(), 1, "finished popup remains in reuse pool")
	await _destroy_main(main)
	Config.data.fx_score_popups_enabled = original_enabled


func test_score_popup_toggle_preserves_turn_and_blitz_state_hashes() -> void:
	var original_enabled: bool = Config.data.fx_score_popups_enabled
	var original_seed: int = Config.data.rng_seed
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	Config.data.rng_seed = 4501
	Config.data.fx_hitstop_enabled = false
	var turn_off: String = await _scripted_state_hash(false, GameConfig.GameMode.TURN)
	var turn_on: String = await _scripted_state_hash(true, GameConfig.GameMode.TURN)
	var blitz_off: String = await _scripted_state_hash(false, GameConfig.GameMode.BLITZ)
	var blitz_on: String = await _scripted_state_hash(true, GameConfig.GameMode.BLITZ)
	assert_eq(turn_on, turn_off, "20-turn score popup state hash")
	assert_eq(blitz_on, blitz_off, "20-second BLITZ score popup state hash")
	Config.data.fx_score_popups_enabled = original_enabled
	Config.data.rng_seed = original_seed
	Config.data.fx_hitstop_enabled = original_hitstop


func test_score_popup_frame_cost_report() -> void:
	var original_enabled: bool = Config.data.fx_score_popups_enabled
	var original_max: int = Config.data.fx_popup_max
	Config.data.fx_score_popups_enabled = true
	Config.data.fx_popup_max = 16
	var main: Main = await _create_main(GameConfig.GameMode.TURN)
	var hud: Hud = main.get_node("UI/Hud") as Hud
	for index: int in range(16):
		hud._on_reaction_scored(_display_reaction(
			Vector2(-400.0 + float(index) * 50.0, 0.0), 1000 + index
		))
	var samples: Array[int] = []
	for _sample_index: int in range(400):
		var started_usec: int = Time.get_ticks_usec()
		hud._process(0.000001)
		for popup: ScorePopup in hud.active_score_popups():
			popup._process(0.000001)
		samples.append(Time.get_ticks_usec() - started_usec)
	samples.sort()
	var p50: int = samples[samples.size() / 2]
	var p95: int = samples[floori(float(samples.size() - 1) * 0.95)]
	print("SCORE_POPUP_FRAME_COST active=16 samples=400 p50_us=%d p95_us=%d" % [p50, p95])
	assert_eq(hud.active_score_popup_count(), 16, "measurement keeps sixteen active popups")
	await _destroy_main(main)
	Config.data.fx_score_popups_enabled = original_enabled
	Config.data.fx_popup_max = original_max


func _reaction(position: Vector2, combo_multiplier: float, occupancy: float) -> Dictionary:
	return {
		"type": ReactionRules.Type.MERGE,
		"levels": [6, 6],
		"result_level": 7,
		"result_color": OrbTypes.OrbColor.YELLOW,
		"position": position,
		"combo": 1,
		"combo_multiplier": combo_multiplier,
		"occupancy": occupancy,
	}


func _display_reaction(position: Vector2, points: int) -> Dictionary:
	return {
		"type": ReactionRules.Type.MERGE,
		"result_color": OrbTypes.OrbColor.GREEN,
		"position": position,
		"points": points,
		"base_points": points,
		"combo_multiplier": 1.0,
		"danger_multiplier": 1.0,
		"occupancy": 0.0,
	}


func _create_main(mode: GameConfig.GameMode) -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(mode)
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	score.save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	return main


func _destroy_main(main: Main) -> void:
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)


func _scripted_state_hash(enabled: bool, mode: GameConfig.GameMode) -> String:
	Config.data.fx_score_popups_enabled = enabled
	var main: Main = await _create_main(mode)
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	var board: Board = main.get_node("Board") as Board
	var initial_orbs: Array[Orb] = board.get_orbs()
	for orb_index: int in range(initial_orbs.size()):
		var initial_orb: Orb = initial_orbs[orb_index]
		initial_orb.freeze = true
		initial_orb.position = Vector2(float(orb_index) * 120.0 - 60.0, 300.0)
		initial_orb.linear_velocity = Vector2.ZERO
	for index: int in range(20):
		var occupancy: float = 0.50 if index % 5 == 0 else 0.20
		var reaction: Dictionary = {
			"type": ReactionRules.Type.MERGE,
			"levels": [1, 1],
			"result_level": 2,
			"result_color": index % Config.data.color_display.size(),
			"position": Vector2(float(index % 5) * 90.0 - 180.0, float(index / 5) * 90.0),
			"combo": 1,
			"combo_multiplier": 1.0 + float(index % 4),
			"occupancy": occupancy,
		}
		score.on_reaction(reaction)
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
		"score": score.score,
		"orbs": orb_state,
	})
	await _destroy_main(main)
	return state_hash
