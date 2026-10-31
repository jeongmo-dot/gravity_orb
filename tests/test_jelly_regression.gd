extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const EXPECTED_REGRESSION_HASH: String = "5656ac3c91d2ff9c828e0c6e7505e24d2ab8f8a189437f4b7927fa372e0c9781"


func test_jelly_full_rule_path_has_stable_render_independent_hash() -> void:
	var original_seed: int = Config.data.rng_seed
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_sfx_enabled: bool = Config.data.sfx_enabled
	Config.data.rng_seed = 1085050
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.sfx_enabled = false
	var visible_result: Dictionary = await _run_rule_path(true)
	var hidden_result: Dictionary = await _run_rule_path(false)
	assert_eq(
		visible_result["hash"],
		hidden_result["hash"],
		"JELLY rule regression hash is independent of rendering"
	)
	assert_eq(
		visible_result["events"],
		{
			"absorption_same_level": 1,
			"absorption_level_up": 1,
			"blast": 1,
			"final_move_failure": 1,
			"final_move_success": 1,
			"l7_eats_l6": 1,
			"max_clear": 1,
		},
		"the fixed board crosses every required JELLY event"
	)
	print(
		"JELLY_REGRESSION_HASH seed=1085050 hash=%s events=%s" % [
			str(visible_result["hash"]),
			JSON.stringify(visible_result["events"]),
		]
	)
	assert_eq(
		visible_result["hash"],
		EXPECTED_REGRESSION_HASH,
		"JELLY full-rule regression baseline"
	)
	Config.data.rng_seed = original_seed
	Config.data.game_mode = original_mode
	Config.data.sfx_enabled = original_sfx_enabled


func _run_rule_path(visuals_enabled: bool) -> Dictionary:
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.JELLY)
	(main.get_node("ScoreManager") as ScoreManager).save_path = ""
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var board: Board3D = main.get_node("Board") as Board3D
	var resolver: CollisionResolver = main.get_node("CollisionResolver") as CollisionResolver
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var hud: Hud = main.get_node("UI/Hud") as Hud
	manager.set_physics_process(false)
	board.set_physics_process(false)
	resolver.proximity_reaction_scan_enabled = false
	board.visible = visuals_enabled
	hud.visible = visuals_enabled
	board.clear()
	await tree.process_frame
	var reactions: Array[Dictionary] = []
	resolver.reaction_applied.connect(
		func(reaction: Dictionary) -> void:
			reactions.append(reaction.duplicate(false))
	)
	var events: Dictionary = {
		"absorption_same_level": 0,
		"absorption_level_up": 0,
		"blast": 0,
		"final_move_failure": 0,
		"final_move_success": 0,
		"l7_eats_l6": 0,
		"max_clear": 0,
	}

	var result: Dictionary = await _apply_pair(
		board, resolver, OrbTypes.OrbColor.GREEN, 3, 4.0, OrbTypes.OrbColor.GREEN, 2, 2.0
	)
	assert_eq(int(result["type"]), int(ReactionRules.Type.MERGE), "same-level absorption merges")
	assert_eq(int(result["result_level"]), 3, "first absorption keeps L3")
	assert_near(float(result["result_mass"]), 6.0, 0.0001, "first absorption reaches mass six")
	events["absorption_same_level"] = int(events["absorption_same_level"]) + 1

	result = await _apply_pair(
		board, resolver, OrbTypes.OrbColor.GREEN, 3, 6.0, OrbTypes.OrbColor.GREEN, 2, 2.0
	)
	assert_eq(int(result["result_level"]), 4, "second absorption raises L3 to L4")
	assert_near(float(result["result_mass"]), 8.0, 0.0001, "level-up absorption reaches mass eight")
	events["absorption_level_up"] = int(events["absorption_level_up"]) + 1

	result = await _apply_pair(
		board, resolver, OrbTypes.OrbColor.RED, 7, 64.0, OrbTypes.OrbColor.BLUE, 7, 64.0
	)
	assert_eq(int(result["type"]), int(ReactionRules.Type.BLAST), "different L7 colors blast")
	events["blast"] = int(events["blast"]) + 1

	result = await _apply_pair(
		board, resolver, OrbTypes.OrbColor.PURPLE, 7, 64.0, OrbTypes.OrbColor.PURPLE, 6, 32.0
	)
	assert_eq(int(result["type"]), int(ReactionRules.Type.MERGE), "L7 consumes adjacent L6")
	assert_eq(int(result["result_level"]), 7, "L7 eating L6 remains MAX")
	events["l7_eats_l6"] = int(events["l7_eats_l6"]) + 1

	result = await _apply_pair(
		board, resolver, OrbTypes.OrbColor.YELLOW, 7, 64.0, OrbTypes.OrbColor.YELLOW, 7, 64.0
	)
	assert_eq(int(result["type"]), int(ReactionRules.Type.MAX_CLEAR), "two L7 jelly trigger MAX clear")
	events["max_clear"] = int(events["max_clear"]) + 1

	board.clear()
	await tree.process_frame
	manager._is_initial_settle = false
	manager.final_move_pending = false
	manager.final_move_active = true
	manager.final_move_count = 1
	manager.final_move_success_count = 0
	manager._set_state(TurnManager.State.SIMULATING)
	manager._on_settled()
	assert_eq(manager.final_move_success_count, 1, "an open entrance succeeds FINAL MOVE")
	events["final_move_success"] = int(events["final_move_success"]) + 1

	var waiting_orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2(0.0, -420.0))
	waiting_orb.disable_physics()
	waiting_orb.is_waiting_at_entrance = true
	manager.final_move_active = true
	manager.final_move_pending = false
	manager.final_move_count = 2
	manager._set_state(TurnManager.State.SIMULATING)
	manager._on_settled()
	assert_eq(manager.state, TurnManager.State.GAME_OVER, "a blocked entrance fails FINAL MOVE")
	events["final_move_failure"] = int(events["final_move_failure"]) + 1

	var reaction_rows: Array[Dictionary] = []
	for reaction: Dictionary in reactions:
		reaction_rows.append({
			"type": int(reaction["type"]),
			"levels": reaction["levels"],
			"colors": reaction["colors"],
			"result_level": int(reaction["result_level"]),
			"result_color": int(reaction["result_color"]),
			"result_mass": snappedf(float(reaction["result_mass"]), 0.001),
			"absorption": bool(reaction["jelly_absorption"]),
		})
	var orb_rows: Array[Dictionary] = []
	for orb: Orb3D in board.get_orbs():
		orb_rows.append({
			"id": orb.stable_spawn_id,
			"color": orb.color,
			"level": orb.level,
			"mass": snappedf(orb.jelly_mass, 0.001),
			"waiting": orb.is_waiting_at_entrance,
		})
	var state_json: String = JSON.stringify({
		"seed": Config.data.rng_seed,
		"allow_same_direction_swipe": Config.data.allow_same_direction_swipe,
		"physics": {
			"gravity_strength": Config.data.gravity_strength,
			"gravity_level_scale": Config.data.gravity_level_scale,
			"gravity_turn_diagonal_time": Config.data.gravity_turn_diagonal_time,
			"orb_friction": Config.data.orb_friction,
			"orb_bounce": Config.data.orb_bounce,
			"wall_friction": Config.data.wall_friction,
			"wall_bounce": Config.data.wall_bounce,
			"orb_angular_damp": Config.data.orb_angular_damp,
			"jelly_axis_lock_angular_z": waiting_orb.get_physics_body().axis_lock_angular_z,
		},
		"events": events,
		"reactions": reaction_rows,
		"orbs": orb_rows,
		"manager": {
			"state": int(manager.state),
			"turn": manager.turn_index,
			"combo": manager.turn_combo,
			"max_combo": manager.max_combo,
			"final_move_count": manager.final_move_count,
			"final_move_success_count": manager.final_move_success_count,
		},
	})
	var hash_context: HashingContext = HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(state_json.to_utf8_buffer())
	var hash: String = hash_context.finish().hex_encode()
	main.queue_free()
	await tree.process_frame
	await tree.process_frame
	InputRouter.set_locked(false)
	return {"hash": hash, "events": events}


func _apply_pair(
	board: Board3D,
	resolver: CollisionResolver,
	first_color: int,
	first_level: int,
	first_mass: float,
	second_color: int,
	second_level: int,
	second_mass: float
) -> Dictionary:
	board.clear()
	await tree.process_frame
	var first: Orb3D = board.spawn_orb(first_color, first_level, Vector2(-10.0, 0.0))
	var second: Orb3D = board.spawn_orb(second_color, second_level, Vector2(10.0, 0.0))
	first.set_jelly_mass(first_mass, Config.data)
	second.set_jelly_mass(second_mass, Config.data)
	first.disable_physics()
	second.disable_physics()
	var captured: Array[Dictionary] = []
	var capture: Callable = func(reaction: Dictionary) -> void:
		captured.append(reaction.duplicate(false))
	resolver.reaction_applied.connect(capture, CONNECT_ONE_SHOT)
	resolver.report_contact(first, second, "jelly_regression")
	assert_eq(resolver.flush(), 1, "fixed JELLY pair resolves exactly once")
	await tree.process_frame
	return captured[0]
