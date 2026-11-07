extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const EXPECTED_M_DELAYED_HASH: String = "ee67b19ca82ddb2e35ea7a5ed605e83eedbae4d0c044106ec5b86622a21ac45d"
const EXPECTED_B_DELAYED_HASH: String = "5a525e46718f3befc3c4101e5a4fe1c3b392fc1c172f7166ed0b0517f6d74dc7"
const EXPECTED_C8_LEGACY_HASH: String = "8c1a02e9dfa345a31828276e917dad0f8dda35282a34cb5a0ced15a670752184"
const EXPECTED_D_DEFAULT_HASH: String = "2cdf79475d340e34252a3d295ccc23e092c719038e2362f5df6ac80dc8e5979f"
const EXPECTED_ST_DEFAULT_HASH: String = "f3ff93474eb3765cdc611ae941c89ec96052a20f16fff75efe8ad6a6c8fb816c"
const EXPECTED_JACKPOT_DEFAULT_HASH: String = "3254c77f2bcf478239f023f08af2bae5f48bc68aee56aa246894908d0b9ab5e7"
const EXPECTED_F2_DEFAULT_HASH: String = "4c4ab4aa9cf014d4d266a6fdfd75a03bbd4f40c5e9a540bd6f682da3c0835974"
const EXPECTED_G1_DEFAULT_HASH: String = "d5175565a24fa4d0e00e1eb3ccbd5529a0c489852c00437fed58197bd20e4c7d"


func test_jelly_full_rule_path_has_stable_render_independent_hash() -> void:
	var config_snapshot: Dictionary = _snapshot_level_profile()
	var original_seed: int = Config.data.rng_seed
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_sfx_enabled: bool = Config.data.sfx_enabled
	var original_merge_duration: float = Config.data.jelly_merge_duration
	Config.data.rng_seed = 1085050
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.sfx_enabled = false
	Config.data.jelly_merge_duration = 0.3
	_apply_m_profile()
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
	assert_eq(visible_result["hash"], EXPECTED_M_DELAYED_HASH, "M delayed hash")
	_restore_level_profile(config_snapshot)
	Config.data.jelly_merge_duration = 0.3
	_apply_d_profile()
	var legacy_d_visible_result: Dictionary = await _run_rule_path(true)
	var legacy_d_hidden_result: Dictionary = await _run_rule_path(false)
	assert_eq(
		legacy_d_visible_result["hash"],
		legacy_d_hidden_result["hash"],
		"legacy D rule hash is independent of rendering"
	)
	print(
		"JELLY_D_LEGACY_REGRESSION_HASH duration=0.3 hash=%s events=%s" % [
			str(legacy_d_visible_result["hash"]),
			JSON.stringify(legacy_d_visible_result["events"]),
		]
	)
	assert_eq(legacy_d_visible_result["hash"], EXPECTED_D_DEFAULT_HASH, "D legacy hash")
	_restore_level_profile(config_snapshot)
	Config.data.jelly_merge_duration = 0.3
	Config.data.max_merge_bonus_factor = 5.0
	_apply_legacy_tap_profile()
	var st_visible_result: Dictionary = await _run_rule_path(true)
	var st_hidden_result: Dictionary = await _run_rule_path(false)
	assert_eq(
		st_visible_result["hash"],
		st_hidden_result["hash"],
		"ST default rule hash is independent of rendering"
	)
	print(
		"JELLY_ST_DEFAULT_REGRESSION_HASH duration=0.3 hash=%s events=%s" % [
			str(st_visible_result["hash"]),
			JSON.stringify(st_visible_result["events"]),
		]
	)
	assert_eq(st_visible_result["hash"], EXPECTED_ST_DEFAULT_HASH, "ST default hash")
	_restore_level_profile(config_snapshot)
	Config.data.jelly_merge_duration = 0.3
	Config.data.max_merge_bonus_factor = 40.0
	_apply_legacy_tap_profile()
	var jackpot_visible_result: Dictionary = await _run_rule_path(true)
	var jackpot_hidden_result: Dictionary = await _run_rule_path(false)
	assert_eq(
		jackpot_visible_result["hash"],
		jackpot_hidden_result["hash"],
		"jackpot default rule hash is independent of rendering"
	)
	print(
		"JELLY_JACKPOT_DEFAULT_REGRESSION_HASH duration=0.3 hash=%s events=%s" % [
			str(jackpot_visible_result["hash"]),
			JSON.stringify(jackpot_visible_result["events"]),
		]
	)
	assert_eq(
		jackpot_visible_result["hash"],
		EXPECTED_JACKPOT_DEFAULT_HASH,
		"jackpot default hash"
	)
	_restore_level_profile(config_snapshot)
	Config.data.jelly_merge_duration = 0.3
	Config.data.max_merge_bonus_factor = 40.0
	Config.data.jelly_merge_level_gap = 2
	var f2_result: Dictionary = await _run_rule_path(false)
	print("JELLY_F2_DEFAULT_HASH hash=%s" % str(f2_result["hash"]))
	assert_eq(
		f2_result["hash"],
		EXPECTED_F2_DEFAULT_HASH,
		"F2 default hash"
	)
	Config.data.jelly_merge_level_gap = 1
	var g1_result: Dictionary = await _run_rule_path(false)
	print("JELLY_G1_DEFAULT_HASH hash=%s" % str(g1_result["hash"]))
	assert_eq(
		g1_result["hash"],
		EXPECTED_G1_DEFAULT_HASH,
		"G1 default hash"
	)
	_apply_c8_profile()
	var c8_result: Dictionary = await _run_rule_path(false)
	assert_eq(c8_result["hash"], EXPECTED_C8_LEGACY_HASH, "C8 legacy hash")
	_apply_b_profile()
	var b_result: Dictionary = await _run_rule_path(false)
	assert_eq(b_result["hash"], EXPECTED_B_DELAYED_HASH, "B delayed hash")
	_apply_a_profile()
	var a_result: Dictionary = await _run_rule_path(false)
	print("JELLY_A_DELAYED_REGRESSION_HASH duration=0.3 hash=%s" % str(a_result["hash"]))
	_restore_level_profile(config_snapshot)
	Config.data.rng_seed = original_seed
	Config.data.game_mode = original_mode
	Config.data.sfx_enabled = original_sfx_enabled
	Config.data.jelly_merge_duration = original_merge_duration


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
	if not Config.data.jelly_blast_requires_same_level:
		events["mixed_level_blast"] = 0
	var legacy_profile: bool = Config.data.orb_max_level == 7
	var profile_a: bool = not legacy_profile and Config.data.jelly_mass_for_level(10) > 100.0
	var first_large_mass: float = 4.0 if legacy_profile or profile_a else 3.0
	var first_small_mass: float = 2.0
	var first_result_level: int = 3 if legacy_profile or profile_a else 4
	var second_large_level: int = 3 if legacy_profile or profile_a else 4
	var second_large_mass: float = 6.0 if legacy_profile or profile_a else 5.0
	var second_small_level: int = 2 if legacy_profile or profile_a else 3
	var second_small_mass: float = 2.0 if legacy_profile or profile_a else 3.0
	var second_result_level: int = 4 if legacy_profile or profile_a else 5
	var top_level: int = Config.data.orb_max_level
	var below_top_level: int = top_level - 1
	var top_mass: float = Config.data.jelly_mass_for_level(top_level)
	var below_top_mass: float = Config.data.jelly_mass_for_level(below_top_level)
	var blast_level: int = Config.data.jelly_blast_min_level
	var blast_mass: float = Config.data.jelly_mass_for_level(blast_level)

	var result: Dictionary = await _apply_pair(
		board, resolver, OrbTypes.OrbColor.GREEN, 3, first_large_mass, OrbTypes.OrbColor.GREEN, 2, first_small_mass
	)
	assert_eq(int(result["type"]), int(ReactionRules.Type.MERGE), "same-level absorption merges")
	assert_eq(int(result["result_level"]), first_result_level, "first absorption level")
	assert_near(float(result["result_mass"]), first_large_mass + first_small_mass, 0.0001, "first absorption mass")
	events["absorption_same_level"] = int(events["absorption_same_level"]) + 1

	result = await _apply_pair(
		board, resolver, OrbTypes.OrbColor.GREEN, second_large_level, second_large_mass, OrbTypes.OrbColor.GREEN, second_small_level, second_small_mass
	)
	assert_eq(int(result["result_level"]), second_result_level, "second absorption levels up")
	assert_near(float(result["result_mass"]), second_large_mass + second_small_mass, 0.0001, "level-up absorption mass")
	events["absorption_level_up"] = int(events["absorption_level_up"]) + 1

	result = await _apply_pair(
		board, resolver, OrbTypes.OrbColor.RED, blast_level, blast_mass, OrbTypes.OrbColor.BLUE, blast_level, blast_mass
	)
	assert_eq(int(result["type"]), int(ReactionRules.Type.BLAST), "different L6 colors blast")
	events["blast"] = int(events["blast"]) + 1
	if not Config.data.jelly_blast_requires_same_level:
		result = await _apply_pair(
			board,
			resolver,
			OrbTypes.OrbColor.RED,
			blast_level,
			blast_mass,
			OrbTypes.OrbColor.BLUE,
			mini(blast_level + 1, top_level),
			Config.data.jelly_mass_for_level(mini(blast_level + 1, top_level))
		)
		assert_eq(int(result["type"]), int(ReactionRules.Type.BLAST), "mixed high levels blast")
		events["mixed_level_blast"] = 1

	result = await _apply_pair(
		board, resolver, OrbTypes.OrbColor.PURPLE, top_level, top_mass, OrbTypes.OrbColor.PURPLE, below_top_level, below_top_mass
	)
	assert_eq(int(result["type"]), int(ReactionRules.Type.MERGE), "L7 consumes adjacent L6")
	assert_eq(int(result["result_level"]), top_level, "top eating adjacent remains MAX")
	events["l7_eats_l6"] = int(events["l7_eats_l6"]) + 1

	if Config.data.jelly_merge_level_gap >= 2 and top_level >= 7:
		result = await _apply_pair(
			board,
			resolver,
			OrbTypes.OrbColor.RED,
			7,
			Config.data.jelly_mass_for_level(7),
			OrbTypes.OrbColor.RED,
			5,
			Config.data.jelly_mass_for_level(5)
		)
		assert_eq(int(result["type"]), int(ReactionRules.Type.MERGE), "gap two merges L7+L5")
		assert_eq(int(result["result_level"]), 7, "C L7+L5 remains L7")
		events["gap_two_absorption"] = 1

	result = await _apply_pair(
		board, resolver, OrbTypes.OrbColor.YELLOW, top_level, top_mass, OrbTypes.OrbColor.YELLOW, top_level, top_mass
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
	var state: Dictionary = {
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
	}
	if Config.data.jelly_tap_blast_uses_turn:
		state["tap_turn_rules"] = {
			"blast_score_factor": Config.data.blast_score_factor,
			"jelly_tap_blast_score_factor": Config.data.jelly_tap_blast_score_factor,
			"jelly_tap_blast_uses_turn": Config.data.jelly_tap_blast_uses_turn,
		}
		if Config.data.jelly_tap_clean_max_level > 0:
			state["tap_turn_rules"]["jelly_tap_clean_max_level"] = (
				Config.data.jelly_tap_clean_max_level
			)
			state["tap_turn_rules"]["jelly_tap_grow_min_clean"] = (
				Config.data.jelly_tap_grow_min_clean
			)
			state["tap_turn_rules"]["jelly_tap_effect_modes"] = Array(
				Config.data.jelly_tap_effect_modes
			)
	if not is_equal_approx(Config.data.max_merge_bonus_factor, 5.0):
		state["jackpot_score_factor"] = Config.data.max_merge_bonus_factor
	var state_json: String = JSON.stringify(state)
	var hash_context: HashingContext = HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(state_json.to_utf8_buffer())
	var hash: String = hash_context.finish().hex_encode()
	main.queue_free()
	await tree.process_frame
	await tree.process_frame
	InputRouter.set_locked(false)
	return {"hash": hash, "events": events}


func _snapshot_level_profile() -> Dictionary:
	return {
		"orb_max_level": Config.data.orb_max_level,
		"jelly_level_masses": Config.data.jelly_level_masses.duplicate(),
		"level_radii": Config.data.level_radii.duplicate(),
		"level_scores": Config.data.level_scores.duplicate(),
		"jelly_blast_min_level": Config.data.jelly_blast_min_level,
		"jelly_blast_requires_same_level": Config.data.jelly_blast_requires_same_level,
		"jelly_tap_blast_min_level": Config.data.jelly_tap_blast_min_level,
		"blast_score_factor": Config.data.blast_score_factor,
		"jelly_tap_blast_score_factor": Config.data.jelly_tap_blast_score_factor,
		"jelly_tap_blast_uses_turn": Config.data.jelly_tap_blast_uses_turn,
		"jelly_tap_clean_max_level": Config.data.jelly_tap_clean_max_level,
		"jelly_tap_grow_min_clean": Config.data.jelly_tap_grow_min_clean,
		"jelly_tap_effect_modes": Config.data.jelly_tap_effect_modes.duplicate(),
		"max_merge_bonus_factor": Config.data.max_merge_bonus_factor,
		"orb_friction_by_level": Config.data.orb_friction_by_level.duplicate(),
		"jelly_merge_level_gap": Config.data.jelly_merge_level_gap,
		"blast_push_radius_by_level": Config.data.blast_push_radius_by_level.duplicate(),
		"gravity_level_scale": Config.data.gravity_level_scale,
		"shock_level_scale": Config.data.shock_level_scale,
	}


func _restore_level_profile(snapshot: Dictionary) -> void:
	Config.data.orb_max_level = int(snapshot["orb_max_level"])
	Config.data.jelly_level_masses = snapshot["jelly_level_masses"] as PackedFloat32Array
	Config.data.level_radii = snapshot["level_radii"] as PackedFloat32Array
	Config.data.level_scores = snapshot["level_scores"] as PackedInt32Array
	Config.data.jelly_blast_min_level = int(snapshot["jelly_blast_min_level"])
	Config.data.jelly_blast_requires_same_level = bool(snapshot["jelly_blast_requires_same_level"])
	Config.data.jelly_tap_blast_min_level = int(snapshot["jelly_tap_blast_min_level"])
	Config.data.blast_score_factor = float(snapshot["blast_score_factor"])
	Config.data.jelly_tap_blast_score_factor = float(snapshot["jelly_tap_blast_score_factor"])
	Config.data.jelly_tap_blast_uses_turn = bool(snapshot["jelly_tap_blast_uses_turn"])
	Config.data.jelly_tap_clean_max_level = int(snapshot["jelly_tap_clean_max_level"])
	Config.data.jelly_tap_grow_min_clean = int(snapshot["jelly_tap_grow_min_clean"])
	Config.data.jelly_tap_effect_modes = snapshot["jelly_tap_effect_modes"] as PackedInt32Array
	Config.data.max_merge_bonus_factor = float(snapshot["max_merge_bonus_factor"])
	Config.data.orb_friction_by_level = snapshot["orb_friction_by_level"] as PackedFloat32Array
	Config.data.jelly_merge_level_gap = int(snapshot["jelly_merge_level_gap"])
	Config.data.blast_push_radius_by_level = snapshot["blast_push_radius_by_level"] as PackedFloat32Array
	Config.data.gravity_level_scale = float(snapshot["gravity_level_scale"])
	Config.data.shock_level_scale = float(snapshot["shock_level_scale"])


func _apply_m_profile() -> void:
	Config.data.orb_max_level = 7
	Config.data.jelly_level_masses = PackedFloat32Array()
	Config.data.level_radii = PackedFloat32Array([25, 40, 60, 85, 100, 120, 140])
	Config.data.level_scores = PackedInt32Array([2, 4, 8, 16, 32, 64, 128])
	Config.data.jelly_blast_min_level = 6
	Config.data.jelly_blast_requires_same_level = true
	Config.data.jelly_tap_blast_min_level = 7
	_apply_legacy_score_profile()
	Config.data.orb_friction_by_level = PackedFloat32Array()
	Config.data.blast_push_radius_by_level = PackedFloat32Array([0, 0, 0, 0.3, 0.55, 1, 1])
	Config.data.gravity_level_scale = 0.05
	Config.data.shock_level_scale = 0.3
	Config.data.jelly_merge_level_gap = 1


func _apply_a_profile() -> void:
	Config.data.orb_max_level = 10
	Config.data.jelly_level_masses = PackedFloat32Array([1, 2, 4, 8, 16, 32, 64, 128, 256, 512])
	Config.data.level_radii = PackedFloat32Array([25, 40, 47, 55, 64, 75, 88, 102, 120, 140])
	Config.data.level_scores = PackedInt32Array([2, 4, 8, 16, 32, 64, 128, 256, 512, 1024])
	Config.data.jelly_blast_min_level = 10
	Config.data.jelly_blast_requires_same_level = true
	Config.data.jelly_tap_blast_min_level = 10
	_apply_legacy_score_profile()
	Config.data.orb_friction_by_level = PackedFloat32Array()
	Config.data.blast_push_radius_by_level = PackedFloat32Array([0, 0, 0, 0.3, 0.55, 1, 1, 1, 1, 1])
	Config.data.gravity_level_scale = 0.0333
	Config.data.shock_level_scale = 0.2
	Config.data.jelly_merge_level_gap = 1


func _apply_b_profile() -> void:
	Config.data.orb_max_level = 10
	Config.data.jelly_level_masses = PackedFloat32Array([1, 2, 3, 5, 7, 11, 17, 27, 42, 64])
	Config.data.level_radii = PackedFloat32Array([25, 40, 52, 68, 80, 92, 102, 115, 128, 140])
	Config.data.level_scores = PackedInt32Array([2, 4, 6, 10, 14, 22, 34, 54, 84, 128])
	Config.data.jelly_blast_min_level = 10
	Config.data.jelly_blast_requires_same_level = true
	Config.data.jelly_tap_blast_min_level = 10
	_apply_legacy_score_profile()
	Config.data.orb_friction_by_level = PackedFloat32Array()
	Config.data.blast_push_radius_by_level = PackedFloat32Array([0, 0, 0, 0.3, 0.55, 1, 1, 1, 1, 1])
	Config.data.gravity_level_scale = 0.0333
	Config.data.shock_level_scale = 0.2
	Config.data.jelly_merge_level_gap = 1


func _apply_c8_profile() -> void:
	Config.data.orb_max_level = 10
	Config.data.jelly_level_masses = PackedFloat32Array([1, 2, 3, 5, 7, 11, 17, 27, 42, 64])
	Config.data.level_radii = PackedFloat32Array([25, 40, 52, 68, 80, 92, 102, 115, 128, 140])
	Config.data.level_scores = PackedInt32Array([2, 4, 6, 10, 14, 22, 34, 54, 84, 128])
	Config.data.jelly_blast_min_level = 8
	Config.data.jelly_blast_requires_same_level = true
	Config.data.jelly_tap_blast_min_level = 10
	_apply_legacy_score_profile()
	Config.data.orb_friction_by_level = PackedFloat32Array()
	Config.data.blast_push_radius_by_level = PackedFloat32Array([0, 0, 0, 0.3, 0.55, 1, 1, 1, 1, 1])
	Config.data.gravity_level_scale = 0.0333
	Config.data.shock_level_scale = 0.2
	Config.data.jelly_merge_level_gap = 2


func _apply_d_profile() -> void:
	_apply_legacy_score_profile()


func _apply_legacy_score_profile() -> void:
	Config.data.blast_score_factor = 5.0
	Config.data.jelly_tap_blast_score_factor = 1.0
	Config.data.jelly_tap_blast_uses_turn = false
	Config.data.max_merge_bonus_factor = 5.0
	_apply_legacy_tap_profile()


func _apply_legacy_tap_profile() -> void:
	Config.data.jelly_merge_level_gap = 2
	Config.data.jelly_tap_clean_max_level = 0
	Config.data.jelly_tap_grow_min_clean = 1
	Config.data.jelly_tap_effect_modes = PackedInt32Array()


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
	var applied_count: int = resolver.flush()
	if applied_count == 0 and Config.data.jelly_merge_duration > 0.0:
		var tick: float = 1.0 / 120.0
		for _step: int in range(ceili(Config.data.jelly_merge_duration / tick) + 1):
			applied_count += resolver.flush(tick)
	assert_eq(applied_count, 1, "fixed JELLY pair resolves exactly once")
	await tree.process_frame
	return captured[0]
