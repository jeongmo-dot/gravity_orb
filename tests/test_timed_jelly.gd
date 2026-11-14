extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const EXPECTED_H8_HASH: String = "790bb962860e741976447a88c3a0635b556ec4b47613ee84ea3743fa8d1f0fd0"
const EXPECTED_K5_8_HASH: String = "3b814220f95318056b5665a591fdd9c4289a9bb5646cc818cab44efac208cb42"
const EXPECTED_K5_4_HASH: String = "bc86d2571e89ed78fcb10d0fb69d03c33048f362ea8395d164605e3d7e21dab7"
const EXPECTED_K5_4_STONE_HASH: String = "463995c4a2188c1639fcc7efaa9e0ce0c294a0b3633ae1c859d7b98eec0ff390"
const EXPECTED_RANDOM_PERMANENT_HASH: String = "83e4f6c8de772cd3a0ff5c6d0853a0ca74996572b45019541c08be9eb1affb91"
const EXPECTED_EARLY_DEFAULT_HASH: String = "8c6eb2f7c241b8d2e94f2f977083ebf084428e91ce4bdc0920e898ae2484921a"


func test_h8_marker_countdown_success_and_failure_hash() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_enabled = true
	Config.data.jelly_timed_turns = 8
	Config.data.jelly_timed_turns_min = 0
	Config.data.jelly_timed_fail_mode = 0
	Config.data.jelly_timed_level = 3
	Config.data.jelly_timed_burst_count = 6
	Config.data.jelly_timed_stone_enabled = true
	var spawner: Spawner = Spawner.new()
	spawner.init_rng(14308)
	var scheduled_rows: Array[Dictionary] = []
	for turn_index: int in range(1, 45):
		var batch: Array[Dictionary] = spawner._draw_batch(turn_index)
		if bool(batch[0].get("timed", false)):
			scheduled_rows.append({
				"turn": turn_index,
				"drawn_level": int(batch[0]["level"]),
				"preview": spawner._public_batch(batch)[0],
			})
	var base: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.RED,
		3,
		OrbTypes.OrbColor.RED,
		3,
		Config.data,
		Config.data.jelly_mass_for_level(3),
		Config.data.jelly_mass_for_level(3)
	)
	var bonus_level: int = mini(
		int(base["result_level"]) + Config.data.jelly_timed_bonus_levels,
		Config.data.orb_max_level
	)
	var state: Dictionary = {
		"scheduled": scheduled_rows,
		"countdown": [8, 7, 6, 5, 4, 3, 2, 1, 0],
		"success": {
			"base_level": int(base["result_level"]),
			"result_level": bonus_level,
			"result_mass": Config.data.jelly_mass_for_level(bonus_level),
			"timed_after": false,
		},
		"failure": {
			"source_level": Config.data.jelly_timed_level,
			"stone_turns": Config.data.jelly_timed_stone_turns,
			"preserves_level_radius_mass": true,
			"score": 0,
		},
	}
	var hash_value: String = JSON.stringify(state).sha256_text()
	print("JELLY_H8_TIMED_HASH hash=%s" % hash_value)
	assert_eq(hash_value, EXPECTED_H8_HASH, "H8 timed rule hash")
	spawner.free()
	_restore_config(snapshot)


func test_k5_8_marker_countdown_success_and_failure_hash() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_enabled = true
	Config.data.jelly_timed_turns = 8
	Config.data.jelly_timed_turns_min = 0
	Config.data.jelly_timed_fail_mode = 0
	Config.data.jelly_timed_level = 5
	Config.data.jelly_timed_burst_count = 10
	Config.data.jelly_timed_stone_enabled = true
	var spawner: Spawner = Spawner.new()
	spawner.init_rng(14408)
	var scheduled_rows: Array[Dictionary] = []
	for turn_index: int in range(1, 45):
		var batch: Array[Dictionary] = spawner._draw_batch(turn_index)
		if bool(batch[0].get("timed", false)):
			scheduled_rows.append({
				"turn": turn_index,
				"drawn_level": int(batch[0]["level"]),
				"preview": spawner._public_batch(batch)[0],
			})
	var base: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.RED,
		Config.data.jelly_timed_level,
		OrbTypes.OrbColor.RED,
		Config.data.jelly_timed_level,
		Config.data,
		Config.data.jelly_mass_for_level(Config.data.jelly_timed_level),
		Config.data.jelly_mass_for_level(Config.data.jelly_timed_level)
	)
	var bonus_level: int = mini(
		int(base["result_level"]) + Config.data.jelly_timed_bonus_levels,
		Config.data.orb_max_level
	)
	var state: Dictionary = {
		"scheduled": scheduled_rows,
		"countdown": [8, 7, 6, 5, 4, 3, 2, 1, 0],
		"success": {
			"base_level": int(base["result_level"]),
			"result_level": bonus_level,
			"result_mass": Config.data.jelly_mass_for_level(bonus_level),
			"timed_after": false,
		},
		"failure": {
			"source_level": Config.data.jelly_timed_level,
			"stone_turns": Config.data.jelly_timed_stone_turns,
			"preserves_level_radius_mass": true,
			"score": 0,
		},
	}
	var hash_value: String = JSON.stringify(state).sha256_text()
	print("JELLY_K5_8_TIMED_HASH hash=%s" % hash_value)
	assert_eq(hash_value, EXPECTED_K5_8_HASH, "K5-8 timed rule hash")
	spawner.free()
	_restore_config(snapshot)


func test_k5_4_default_marker_countdown_success_and_failure_hash() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_enabled = true
	Config.data.jelly_timed_turns = 4
	Config.data.jelly_timed_turns_min = 0
	Config.data.jelly_timed_fail_mode = 0
	Config.data.jelly_timed_level = 5
	Config.data.jelly_timed_burst_count = 10
	Config.data.jelly_timed_stone_enabled = false
	var spawner: Spawner = Spawner.new()
	spawner.init_rng(14504)
	var scheduled_rows: Array[Dictionary] = []
	for turn_index: int in range(1, 45):
		var batch: Array[Dictionary] = spawner._draw_batch(turn_index)
		if bool(batch[0].get("timed", false)):
			scheduled_rows.append({
				"turn": turn_index,
				"drawn_level": int(batch[0]["level"]),
				"preview": spawner._public_batch(batch)[0],
			})
	var base: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.RED,
		Config.data.jelly_timed_level,
		OrbTypes.OrbColor.RED,
		Config.data.jelly_timed_level,
		Config.data,
		Config.data.jelly_mass_for_level(Config.data.jelly_timed_level),
		Config.data.jelly_mass_for_level(Config.data.jelly_timed_level)
	)
	var bonus_level: int = mini(
		int(base["result_level"]) + Config.data.jelly_timed_bonus_levels,
		Config.data.orb_max_level
	)
	var state: Dictionary = {
		"scheduled": scheduled_rows,
		"countdown": [4, 3, 2, 1, 0],
		"success": {
			"base_level": int(base["result_level"]),
			"result_level": bonus_level,
			"result_mass": Config.data.jelly_mass_for_level(bonus_level),
			"timed_after": false,
		},
		"failure": {
			"source_level": Config.data.jelly_timed_level,
			"burst_level": 1,
			"burst_count": Config.data.jelly_timed_burst_count,
			"burst_layout": "compact_hex_fill",
			"score": 0,
		},
	}
	var hash_value: String = JSON.stringify(state).sha256_text()
	print("JELLY_K5_4_TIMED_HASH hash=%s" % hash_value)
	assert_eq(hash_value, EXPECTED_K5_4_HASH, "K5-4 default timed rule hash")
	spawner.free()
	_restore_config(snapshot)


func test_k5_4_default_stone_hash() -> void:
	var snapshot: Dictionary = _snapshot_config()
	assert_true(Config.data.jelly_timed_stone_enabled, "timed stone defaults on")
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_enabled = true
	Config.data.jelly_timed_turns = 4
	Config.data.jelly_timed_turns_min = 0
	Config.data.jelly_timed_fail_mode = 0
	Config.data.jelly_timed_level = 5
	Config.data.jelly_timed_stone_enabled = true
	var state: Dictionary = {
		"turns": Config.data.jelly_timed_turns,
		"source_level": Config.data.jelly_timed_level,
		"stone_turns": Config.data.jelly_timed_stone_turns,
		"preserves_level_radius_mass": true,
		"reaction_enabled": false,
		"score": 0,
	}
	var hash_value: String = JSON.stringify(state).sha256_text()
	print("JELLY_K5_4_STONE_HASH hash=%s" % hash_value)
	assert_eq(hash_value, EXPECTED_K5_4_STONE_HASH, "K5-4 stone rule hash")
	_restore_config(snapshot)


func test_random_timed_permanent_stone_default_hash() -> void:
	_assert_random_timed_permanent_stone_hash(100, "JELLY_EARLY_DEFAULT_HASH", EXPECTED_EARLY_DEFAULT_HASH)


func test_random_timed_permanent_stone_limit_zero_hash() -> void:
	_assert_random_timed_permanent_stone_hash(0, "JELLY_RANDOM_PERMANENT_HASH", EXPECTED_RANDOM_PERMANENT_HASH)


func _assert_random_timed_permanent_stone_hash(
	early_limit: int,
	hash_label: String,
	expected_hash: String
) -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_early_turn_limit = early_limit
	var spawner: Spawner = Spawner.new()
	spawner.init_rng(150510)
	var scheduled: Array[Dictionary] = []
	for turn_index: int in range(1, 57):
		var batch: Array[Dictionary] = spawner._draw_batch(turn_index)
		if bool((batch[0] as Dictionary).get("timed", false)):
			scheduled.append({
				"turn": turn_index,
				"turns": int((batch[0] as Dictionary)["timed_turns"]),
				"rng_row": _enabled_candidate_rng_row(batch[0] as Dictionary),
			})
	var state: Dictionary = {
		"scheduled": scheduled,
		"turns_min": Config.data.jelly_timed_turns_min,
		"turns_max": Config.data.jelly_timed_turns_max,
		"fail_mode": Config.data.jelly_timed_fail_mode,
		"stone_level": Config.data.jelly_timed_level,
		"stone_permanent": true,
		"stone_label": false,
		"breaks_to_remove": Config.data.jelly_timed_level - 1,
		"score": 0,
	}
	var hash_value: String = JSON.stringify(state).sha256_text()
	print("%s hash=%s" % [hash_label, hash_value])
	assert_eq(hash_value, expected_hash, "%s timed rule hash" % hash_label)
	spawner.free()
	_restore_config(snapshot)


func test_timed_batches_preserve_rng_and_mark_only_scheduled_first_orb() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_enabled = true
	var enabled: Spawner = Spawner.new()
	enabled.init_rng(14320)
	var repeated: Spawner = Spawner.new()
	repeated.init_rng(14320)
	var enabled_rows: Array[Array] = []
	for turn_index: int in range(1, 46):
		enabled_rows.append(enabled._draw_batch(turn_index))
		var repeated_batch: Array[Dictionary] = repeated._draw_batch(turn_index)
		if bool((repeated_batch[0] as Dictionary).get("timed", false)):
			assert_eq(
				int((repeated_batch[0] as Dictionary)["timed_turns"]),
				int((enabled_rows[-1][0] as Dictionary)["timed_turns"]),
				"same seed reproduces the timed number"
			)
			assert_true(
				int((repeated_batch[0] as Dictionary)["timed_turns"]) in range(10, 16),
				"early timed number is between ten and fifteen"
			)
	Config.data.jelly_timed_enabled = false
	var disabled: Spawner = Spawner.new()
	disabled.init_rng(14320)
	for turn_index: int in range(1, 46):
		var enabled_batch: Array = enabled_rows[turn_index - 1]
		var disabled_batch: Array[Dictionary] = disabled._draw_batch(turn_index)
		assert_eq(enabled_batch.size(), disabled_batch.size(), "turn %d batch size" % turn_index)
		for index: int in range(disabled_batch.size()):
			assert_eq(
				_enabled_candidate_rng_row(enabled_batch[index] as Dictionary),
				_enabled_candidate_rng_row(disabled_batch[index]),
				"turn %d candidate %d RNG row" % [turn_index, index]
			)
		var scheduled: bool = turn_index in [20, 32, 44]
		assert_eq(
			bool((enabled_batch[0] as Dictionary).get("timed", false)),
			scheduled,
			"turn %d timed marker" % turn_index
		)
		for index: int in range(1, enabled_batch.size()):
			assert_true(
				not bool((enabled_batch[index] as Dictionary).get("timed", false)),
				"only first candidate is timed at turn %d" % turn_index
			)
	enabled.free()
	repeated.free()
	disabled.free()
	_restore_config(snapshot)


func test_timed_preview_uses_configured_level_and_count_without_changing_budget() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_enabled = true
	var spawner: Spawner = Spawner.new()
	spawner.init_rng(14321)
	spawner.sync_next_batch_size(20)
	var internal_batch: Array = spawner._preview_batches[0]
	var preview_batch: Array = spawner.peek_preview()[0] as Array
	assert_true(bool((internal_batch[0] as Dictionary)["timed"]), "internal marker")
	assert_eq(int((preview_batch[0] as Dictionary)["level"]), Config.data.jelly_timed_level, "preview level")
	assert_true(
		int((preview_batch[0] as Dictionary)["timed_turns"]) in range(10, 16),
		"preview uses the selected random count"
	)
	assert_eq(
		spawner._batch_cost(internal_batch),
		Config.data.spawn_count_for_turn(20),
		"drawn level still owns the spawn budget"
	)
	var before: Array = spawner.peek_preview().duplicate(true)
	spawner.sync_next_batch_size(20)
	assert_eq(spawner.peek_preview(), before, "deferred preview keeps its marker")
	spawner.free()
	_restore_config(snapshot)


func test_early_timed_ranges_boundary_and_rng_sequence() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_enabled = true
	for seed_value: int in [14320, 150510, 154100]:
		for early_limit: int in [100, 32]:
			Config.data.jelly_timed_early_turn_limit = early_limit
			var early: Spawner = Spawner.new()
			var repeated: Spawner = Spawner.new()
			var legacy: Spawner = Spawner.new()
			early.init_rng(seed_value)
			repeated.init_rng(seed_value)
			legacy.init_rng(seed_value)
			var scheduled_turns: Array[int] = []
			for turn_index: int in range(1, 141):
				Config.data.jelly_timed_early_turn_limit = early_limit
				var batch: Array[Dictionary] = early._draw_batch(turn_index)
				var repeated_batch: Array[Dictionary] = repeated._draw_batch(turn_index)
				assert_eq(batch, repeated_batch, "same seed reproduces complete batch")
				Config.data.jelly_timed_early_turn_limit = 0
				var legacy_batch: Array[Dictionary] = legacy._draw_batch(turn_index)
				assert_eq(batch.size(), legacy_batch.size(), "early range preserves batch size")
				for index: int in range(batch.size()):
					assert_eq(
						_enabled_candidate_rng_row(batch[index]),
						_enabled_candidate_rng_row(legacy_batch[index]),
						"early range preserves level color and position sequence"
					)
				if not bool(batch[0].get("timed", false)):
					continue
				scheduled_turns.append(turn_index)
				var turns: int = int(batch[0]["timed_turns"])
				if turn_index < early_limit:
					assert_true(turns >= 10 and turns <= 15, "early range at turn %d" % turn_index)
				else:
					assert_true(turns >= 5 and turns <= 10, "late range at turn %d" % turn_index)
					assert_eq(turns, int(legacy_batch[0]["timed_turns"]), "one timed draw per scheduled jelly")
			assert_eq(scheduled_turns, [20, 32, 44, 56, 68, 80, 92, 104, 116, 128, 140], "schedule unchanged")
			early.free()
			repeated.free()
			legacy.free()
	_restore_config(snapshot)


func test_early_timed_fallbacks_and_fixed_precedence() -> void:
	var snapshot: Dictionary = _snapshot_config()
	var spawner: Spawner = Spawner.new()
	spawner.init_rng(154100)
	Config.data.jelly_timed_early_turn_limit = 100
	Config.data.jelly_timed_turns_min = 0
	var timed_state: int = spawner._timed_rng.state
	assert_eq(spawner._draw_timed_turns(20), Config.data.jelly_timed_turns, "fixed count precedes early range")
	assert_eq(spawner._timed_rng.state, timed_state, "fixed count consumes no timed draw")
	Config.data.jelly_timed_turns_min = 5
	for early_minimum: int in [0, -1]:
		Config.data.jelly_timed_early_turns_min = early_minimum
		var turns: int = spawner._draw_timed_turns(20)
		assert_true(turns >= 5 and turns <= 10, "nonpositive early minimum uses late range")
	Config.data.jelly_timed_early_turns_min = 10
	Config.data.jelly_timed_early_turns_max = 9
	assert_eq(spawner._draw_timed_turns(20), 10, "early maximum clamps to minimum")
	Config.data.jelly_timed_early_turn_limit = -1
	var late_turns: int = spawner._draw_timed_turns(20)
	assert_true(late_turns >= 5 and late_turns <= 10, "negative limit disables early range")
	spawner.free()
	_restore_config(snapshot)


func test_timed_merge_bonus_applies_for_absorber_and_absorbed_sources() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_merge_duration = 0.0
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var first: Dictionary = await _resolve_timed_pair(board, resolver, 3, true, 2, false)
	assert_eq(int(first["result_level"]), 5, "timed L3 absorber gets bonus")
	assert_near(float(first["result_mass"]), Config.data.jelly_mass_for_level(5), 0.0001, "bonus mass")
	assert_true(bool(first["timed_success"]), "success marker")
	assert_true(not bool((first["result_orb"] as Orb3D).is_timed), "result is normal")
	var second: Dictionary = await _resolve_timed_pair(board, resolver, 2, true, 3, false)
	assert_eq(int(second["result_level"]), 5, "timed absorbed source gets bonus")
	assert_near(float(second["result_mass"]), Config.data.jelly_mass_for_level(5), 0.0001, "absorbed bonus mass")
	assert_true(not bool((second["result_orb"] as Orb3D).is_timed), "absorber result is normal")
	await _cleanup(fixture["root"] as Node)
	_restore_config(snapshot)


func test_countdown_hardens_in_place_and_waits_an_extra_settle() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_enabled = true
	Config.data.jelly_timed_turns = 1
	Config.data.jelly_timed_fail_mode = 0
	Config.data.jelly_timed_stone_enabled = true
	Config.data.jelly_timed_stone_turns = 6
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var manager: TurnManager = fixture["manager"] as TurnManager
	var score: ScoreManager = fixture["score"] as ScoreManager
	var source_position: Vector2 = Vector2(31.0, -27.0)
	var source: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 5, source_position)
	source.set_timed(1, 20)
	var source_radius: float = source.get_current_radius()
	var source_mass: float = source.jelly_mass
	source.disable_physics()
	var waiter: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 3, Vector2(0.0, -300.0))
	waiter.set_timed(4, 20)
	waiter.enter_entrance_wait(waiter.position, Vector2i.DOWN)
	manager._is_initial_settle = false
	manager.turn_index = 21
	manager._set_state(TurnManager.State.SIMULATING)
	manager._on_settled()
	assert_eq(manager.state, TurnManager.State.SIMULATING, "timeout starts another settle")
	assert_true(manager._is_timed_burst_settle, "extra settle flag")
	assert_eq(waiter.timed_turns_remaining, 4, "entrance waiter does not count down")
	assert_eq(board.get_orbs().size(), 2, "hardening creates no L1 jellies")
	assert_true(source.is_timed_stone, "expired timed jelly becomes a stone")
	assert_true(not source.is_timed, "stone clears timed marker")
	assert_eq(source.timed_stone_turns_remaining, 6, "stone starts at configured turns")
	assert_eq(source.level, 5, "stone preserves level")
	assert_eq(source.color, OrbTypes.OrbColor.GREEN, "stone preserves logical color")
	assert_near(source.position.distance_to(source_position), 0.0, 0.001, "stone preserves position")
	assert_near(source.get_current_radius(), source_radius, 0.0001, "stone preserves radius")
	assert_near(source.jelly_mass, source_mass, 0.0001, "stone preserves mass")
	assert_eq(score.score, 0, "timeout has no score")
	assert_eq(manager.timed_jelly_failure_count, 1, "failure measurement")
	assert_eq(manager.timed_stone_created_count, 1, "stone creation measurement")
	assert_eq(manager.timed_stone_max_concurrent, 1, "stone maximum measurement")
	manager._on_settled()
	assert_true(manager.state != TurnManager.State.SIMULATING, "second settle reaches entrance check")
	assert_eq(source.timed_stone_turns_remaining, 6, "hardening settle does not decrement stone")
	board.remove_orb(waiter)
	var turn_path: Orb3D = board.spawn_orb(OrbTypes.OrbColor.YELLOW, 3, Vector2.ZERO)
	turn_path.set_timed(3, 21)
	turn_path.disable_physics()
	manager._is_tap_blast_settle = false
	manager._set_state(TurnManager.State.SIMULATING)
	manager._on_settled()
	assert_eq(turn_path.timed_turns_remaining, 2, "turn-consuming settle decrements timer")
	assert_eq(source.timed_stone_turns_remaining, 5, "next turn decrements stone")
	manager._is_tap_blast_settle = true
	manager._set_state(TurnManager.State.SIMULATING)
	manager._on_settled()
	assert_eq(turn_path.timed_turns_remaining, 2, "non-turn tap settle does not decrement timer")
	assert_eq(source.timed_stone_turns_remaining, 5, "non-turn tap settle skips stone")
	await _cleanup(fixture["root"] as Node)
	_restore_config(snapshot)


func test_first_placement_callout_is_queued_once() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_fail_mode = 0
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.JELLY)
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var hud: Hud = main.get_node("UI/Hud") as Hud
	hud._on_timed_jelly_placed(8, 1)
	hud._on_timed_jelly_placed(8, 1)
	assert_eq(hud.timed_jelly_callout_history().size(), 1, "one first-placement callout")
	assert_eq(
		hud.timed_jelly_callout_history()[0],
		"시한 젤리: 8턴 안에 합치면 한 단계 더",
		"configured callout text"
	)
	hud._hide_callout_label()
	hud._on_timed_stone_created(6)
	hud._on_timed_stone_created(6)
	assert_eq(hud.timed_stone_callout_history().size(), 1, "one first-stone callout")
	assert_eq(
		hud.timed_stone_callout_history()[0],
		"굳은 젤리: 6턴 동안 합칠 수 없음",
		"configured stone callout text"
	)
	hud._hide_callout_label()
	hud._timed_stone_callout_seen = false
	hud._timed_stone_callout_pending = false
	hud._timed_stone_callout_history.clear()
	Config.data.jelly_timed_fail_mode = 2
	hud._on_timed_stone_created(0)
	assert_eq(
		hud.timed_stone_callout_history()[0],
		"굳은 젤리: 폭발로만 깰 수 있음",
		"mode two callout explains the permanent stone"
	)
	hud._hide_callout_label()
	hud._timed_stone_callout_seen = false
	hud._timed_stone_callout_pending = false
	hud._timed_stone_callout_history.clear()
	Config.data.jelly_timed_fail_mode = 1
	hud._on_timed_stone_created(0)
	assert_eq(
		hud.timed_stone_callout_history()[0],
		"회색 공: 폭발로만 깰 수 있음",
		"mode one callout explains the scattered stones"
	)
	await _cleanup(main)
	_restore_config(snapshot)


func test_timed_burst_uses_compact_hex_fill_inside_source_and_board() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_stone_enabled = false
	Config.data.jelly_timed_burst_count = 14
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var manager: TurnManager = fixture["manager"] as TurnManager
	var source_radius: float = Config.data.radius_for_level(6)
	var level_one_radius: float = Config.data.radius_for_level(1)
	var offsets: Array[Vector2] = manager._timed_burst_offsets(
		14,
		source_radius,
		level_one_radius
	)
	assert_eq(offsets.size(), 14, "K6 burst offset count")
	assert_eq(offsets[0], Vector2.ZERO, "compact fill starts at the source center")
	var radial_bands: Dictionary = {}
	for offset: Vector2 in offsets:
		assert_true(
			offset.length() <= source_radius + level_one_radius + 0.001,
			"burst center stays within the source circle plus one L1 radius"
		)
		radial_bands[roundi(offset.length())] = true
	assert_true(radial_bands.size() >= 3, "burst is a filled cluster rather than one ring")
	var source_center: Vector2 = Vector2(350.0, 350.0)
	var source: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		6,
		source_center
	)
	source.set_timed(1, 20)
	source.disable_physics()
	manager._spawn_timed_burst(source)
	var half_board: float = Config.data.board_size * 0.5
	var burst_orbs: Array[Orb3D] = board.get_orbs()
	assert_eq(burst_orbs.size(), 14, "K6 timeout spawns fourteen L1 jellies")
	for orb: Orb3D in burst_orbs:
		assert_eq(orb.level, 1, "cluster member is L1")
		assert_eq(orb.color, OrbTypes.OrbColor.BLUE, "cluster keeps source color")
		assert_true(orb.is_ghost, "cluster member starts ghosted")
		assert_true(
			absf(orb.position.x) + level_one_radius <= half_board + 0.001,
			"cluster member stays inside horizontal board bounds"
		)
		assert_true(
			absf(orb.position.y) + level_one_radius <= half_board + 0.001,
			"cluster member stays inside vertical board bounds"
		)
	await _cleanup(fixture["root"] as Node)
	_restore_config(snapshot)


func test_timed_stone_blocks_reactions_and_cleaning_but_keeps_physical_push() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_merge_duration = 0.0
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var stone: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 5, Vector2.ZERO)
	stone.set_timed_stone(6)
	stone.disable_physics()
	for row: Array in [
		[OrbTypes.OrbColor.RED, 4],
		[OrbTypes.OrbColor.RED, 5],
		[OrbTypes.OrbColor.RED, 6],
		[OrbTypes.OrbColor.BLUE, 6],
	]:
		var other: Orb3D = board.spawn_orb(row[0], row[1], Vector2(10.0, 0.0))
		other.disable_physics()
		resolver.report_contact(stone, other, "stone_test")
		assert_eq(resolver.flush(), 0, "stone contact never reacts")
		board.remove_orb(other)
		await tree.process_frame
	assert_true(not resolver.is_jelly_tap_blast_candidate(stone), "stone is not touch source")
	var clean_source: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		Config.data.jelly_tap_blast_min_level,
		Vector2(30.0, 0.0)
	)
	clean_source.disable_physics()
	var low_stone: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2(35.0, 0.0))
	low_stone.set_timed_stone(6)
	low_stone.disable_physics()
	assert_true(
		not resolver._jelly_tap_clean_targets(
			clean_source,
			GameConfig.JellyTapEffect.BOMB
		).has(low_stone),
		"stone is excluded from tap and color cleaning"
	)
	var push_rows: Array[Dictionary] = board.apply_blast_with_radius_factor(
		Vector2(-20.0, 0.0),
		1.0,
		clean_source,
		true
	)
	var stone_was_pushed: bool = false
	for push_row: Dictionary in push_rows:
		if int(push_row["stable_spawn_id"]) == stone.stable_spawn_id:
			stone_was_pushed = true
			break
	assert_true(stone_was_pushed, "stone still receives ordinary physical blast push")
	await _cleanup(fixture["root"] as Node)
	_restore_config(snapshot)


func test_timed_stone_expires_without_score_and_waits_for_settle() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_enabled = true
	Config.data.jelly_timed_fail_mode = 0
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	var score: ScoreManager = fixture["score"] as ScoreManager
	var stone: Orb3D = board.spawn_orb(OrbTypes.OrbColor.YELLOW, 5, Vector2.ZERO)
	stone.set_timed_stone(1)
	stone.disable_physics()
	manager.turn_index = 22
	manager._set_state(TurnManager.State.SIMULATING)
	manager._on_settled()
	assert_eq(manager.state, TurnManager.State.SIMULATING, "stone removal starts one settle")
	assert_true(manager._is_timed_burst_settle, "stone removal uses timeout settle path")
	assert_eq(board.get_orbs().size(), 0, "expired stone leaves the board")
	assert_eq(score.score, 0, "stone removal has no score")
	assert_eq(resolver._active_tap_clean_visuals.size(), 1, "existing clean disappearance is reused")
	resolver.flush(Config.data.jelly_tap_clean_visual_time + 0.01)
	await tree.process_frame
	assert_true(not is_instance_valid(stone), "stone visual is removed after disappearance")
	manager._on_settled()
	assert_true(manager.state != TurnManager.State.SIMULATING, "one extra settle completes")
	await _cleanup(fixture["root"] as Node)
	_restore_config(snapshot)


func test_timed_stone_body_is_gray_with_face_and_label_preserved() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 5, Vector2.ZERO)
	var face_material: Material = orb._face.material_override
	orb.set_timed_stone(12)
	await tree.process_frame
	var body_material: ShaderMaterial = orb._mesh.material_override as ShaderMaterial
	assert_eq(
		body_material.get_shader_parameter("base_color"),
		JellyOrbArt.STONE_BODY_COLOR,
		"stone body uses specified gray sRGB color"
	)
	assert_eq(orb._face.material_override, face_material, "stone preserves face material")
	assert_eq((orb.get_node("TimedLabel") as Label3D).text, "12", "stone label shows turns")
	await _cleanup(fixture["root"] as Node)
	_restore_config(snapshot)


func test_fail_mode_two_creates_permanent_unlabelled_stone() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_fail_mode = 2
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var manager: TurnManager = fixture["manager"] as TurnManager
	var source: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 5, Vector2.ZERO)
	source.set_timed(1, 20)
	source.disable_physics()
	assert_true(manager._advance_timed_jellies(), "timeout starts a transition")
	assert_true(source.is_timed_stone, "mode two hardens in place")
	assert_true(source.timed_stone_permanent, "mode two stone is permanent")
	assert_eq(source.level, 5, "mode two preserves L5")
	assert_eq(source.timed_stone_turns_remaining, 0, "permanent stone has no timer")
	assert_true(not (source.get_node("TimedLabel") as Label3D).visible, "permanent stone has no number")
	for _turn: int in range(30):
		manager._advance_timed_jellies()
	assert_true(board.get_orbs().has(source), "permanent stone remains after thirty turns")
	assert_eq(source.level, 5, "time does not break a permanent stone")
	await _cleanup(fixture["root"] as Node)
	_restore_config(snapshot)


func test_stone_hardening_signal_batches_and_excludes_burst_and_expiry() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_enabled = true
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	var hardening_calls: Array[int] = []
	manager.timed_stone_hardened.connect(func() -> void: hardening_calls.append(1))

	Config.data.jelly_timed_fail_mode = 2
	for position: Vector2 in [Vector2(-80.0, 0.0), Vector2(80.0, 0.0)]:
		var timed: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 5, position)
		timed.set_timed(1, 20)
		timed.disable_physics()
	manager._advance_timed_jellies()
	assert_eq(hardening_calls.size(), 1, "two mode-two failures in one turn emit once")

	board.clear()
	await tree.process_frame
	Config.data.jelly_timed_fail_mode = 1
	var scatter: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 5, Vector2.ZERO)
	scatter.set_timed(1, 20)
	scatter.disable_physics()
	manager._advance_timed_jellies()
	assert_eq(hardening_calls.size(), 2, "mode one emits one hardening event")
	resolver.cancel_active_jelly_merges()
	board.clear()
	await tree.process_frame

	Config.data.jelly_timed_fail_mode = 0
	Config.data.jelly_timed_stone_enabled = true
	var temporary: Orb3D = board.spawn_orb(OrbTypes.OrbColor.YELLOW, 5, Vector2.ZERO)
	temporary.set_timed(1, 20)
	temporary.disable_physics()
	manager._advance_timed_jellies()
	assert_eq(hardening_calls.size(), 3, "mode zero temporary stone emits once")
	temporary.set_timed_stone(1)
	manager._advance_timed_jellies()
	assert_eq(hardening_calls.size(), 3, "temporary stone expiry is silent")
	resolver.cancel_active_jelly_merges()
	board.clear()
	await tree.process_frame

	Config.data.jelly_timed_stone_enabled = false
	var burst: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 5, Vector2.ZERO)
	burst.set_timed(1, 20)
	burst.disable_physics()
	manager._advance_timed_jellies()
	assert_eq(hardening_calls.size(), 3, "legacy L1 burst is silent")
	await _cleanup(fixture["root"] as Node)
	_restore_config(snapshot)


func test_permanent_stones_break_once_per_explosion_and_only_in_range() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var inside: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 5, Vector2.ZERO)
	inside.set_timed_stone(0, true)
	inside.disable_physics()
	var outside: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		5,
		Vector2(400.0, 400.0)
	)
	outside.set_timed_stone(0, true)
	outside.disable_physics()
	var tap_rows: Array[Dictionary] = board.apply_blast_with_radius_factor(
		Vector2.ZERO,
		0.3
	)
	assert_eq(
		resolver._break_timed_stones_from_explosion(tap_rows, tap_rows),
		1,
		"duplicate target rows still break once"
	)
	assert_eq(inside.level, 4, "tap blast lowers an in-range L5 to L4")
	assert_eq(outside.level, 5, "tap blast leaves an out-of-range stone unchanged")
	var blast_rows: Array[Dictionary] = board.apply_blast(Vector2.ZERO, 8)
	assert_eq(
		resolver._break_timed_stones_from_explosion([], blast_rows),
		2,
		"full-board blast reaches both stones"
	)
	assert_eq(inside.level, 3, "large blast lowers the inside stone once")
	assert_eq(outside.level, 4, "large blast lowers the distant stone once")
	var jackpot_rows: Array[Dictionary] = board.apply_shockwave(
		Vector2.ZERO,
		Config.data.orb_max_level,
		null,
		true,
		OrbTypes.OrbColor.RED
	)
	assert_eq(
		resolver._break_timed_stones_from_explosion(jackpot_rows, []),
		1,
		"jackpot breaks only its shockwave targets"
	)
	assert_eq(inside.level, 2, "jackpot lowers the nearby stone")
	assert_eq(outside.level, 4, "jackpot leaves a stone outside its range unchanged")
	var removal_rows: Array[Dictionary] = board.apply_blast_with_radius_factor(
		Vector2.ZERO,
		0.3
	)
	assert_eq(
		resolver._break_timed_stones_from_explosion([], removal_rows),
		1,
		"breaking L2 removes the L1 result"
	)
	assert_true(not board.get_orbs().has(inside), "broken-to-L1 stone leaves the board")
	assert_eq(resolver._active_tap_clean_visuals.size(), 1, "existing clean visual is reused")
	await _cleanup(fixture["root"] as Node)
	_restore_config(snapshot)


func test_fail_mode_one_scatters_five_deterministic_ghost_stones() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.jelly_timed_fail_mode = 1
	Config.data.jelly_timed_scatter_count = 5
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	var obstacle: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 4, Vector2.ZERO)
	obstacle.disable_physics()
	var source: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 5, Vector2(80.0, 40.0))
	source.set_timed(1, 20)
	source.disable_physics()
	manager._spawn_timed_scatter(source)
	var stones: Array[Orb3D] = []
	var occupied_positions: Dictionary = {}
	for orb: Orb3D in board.get_orbs():
		if not orb.is_timed_stone:
			continue
		stones.append(orb)
		occupied_positions[str(orb.position)] = true
		assert_eq(orb.level, 1, "scatter member is L1")
		assert_true(orb.timed_stone_permanent, "scatter member is permanent")
		assert_true(orb.is_ghost, "scatter member starts ghosted")
		assert_true(not (orb.get_node("TimedLabel") as Label3D).visible, "scatter member has no number")
	assert_eq(stones.size(), 5, "mode one creates five gray stones")
	assert_eq(occupied_positions.size(), 5, "scatter positions are distinct")
	assert_eq(manager.timed_jelly_failure_count, 1, "scatter records one failed timed jelly")
	assert_eq(manager.timed_stone_created_count, 5, "scatter records all five stones")
	var first: Orb3D = stones[0]
	first.exit_ghost_state()
	var rows: Array[Dictionary] = board.apply_blast_with_radius_factor(first.position, 0.05)
	assert_true(
		resolver._break_timed_stones_from_explosion([], rows) >= 1,
		"an in-range explosion breaks a scattered L1"
	)
	assert_true(not board.get_orbs().has(first), "scattered L1 disappears in one explosion")
	await _cleanup(fixture["root"] as Node)
	_restore_config(snapshot)


func test_board_timed_number_stays_below_eyes_inside_orb_with_visible_outline() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.YELLOW, 5, Vector2.ZERO)
	orb.set_timed_stone(18)
	orb.disable_physics()
	await tree.process_frame
	var label: Label3D = orb.get_node("TimedLabel") as Label3D
	assert_true(label.visible, "timed number is visible")
	assert_true(label.font is FontVariation, "timed number uses the HUD variable font")
	assert_eq(label.text, "18", "two-digit stone number exercises the widest required label")
	assert_eq(
		label.font_size,
		Orb3D.TIMED_LABEL_FONT_MIN,
		"default L5 timed number is rasterized near its screen size"
	)
	assert_near(
		label.pixel_size,
		Orb3D.TIMED_LABEL_PIXEL_SIZE,
		0.000001,
		"higher raster size is balanced by a smaller pixel size"
	)
	var target_white_height_px: float = 20.0
	var display_to_raster_ratio: float = target_white_height_px / float(label.font_size)
	assert_true(
		display_to_raster_ratio <= 1.2,
		"target screen height is not enlarged from the glyph raster"
	)
	var target_outline_px: float = float(label.outline_size) * display_to_raster_ratio
	assert_true(
		target_outline_px >= 2.0 and target_outline_px <= 3.0,
		"outline projects to the required two-to-three pixel range"
	)
	assert_true(
		label.outline_render_priority > 12,
		"outline renders in front of the jelly face material"
	)
	assert_true(
		label.outline_render_priority < label.render_priority,
		"outline remains directly behind the white glyph"
	)
	assert_eq(label.modulate, Color.WHITE, "timed number is white")
	var label_bounds: AABB = label.get_aabb()
	var label_top_y: float = label.position.y + label_bounds.end.y
	var label_bottom_y: float = label.position.y + label_bounds.position.y
	var label_left_x: float = label.position.x + label_bounds.position.x
	var label_right_x: float = label.position.x + label_bounds.end.x
	var face_scale_y: float = orb._face.basis.y.length()
	var normal_eye_bottom_y: float = orb._face.position.y - face_scale_y * (0.22 + 0.105)
	var radius_m: float = Config.data.radius_for_level(5) / Orb3D.PIXELS_PER_METER
	var orb_bottom_y: float = orb._mesh.position.y - radius_m * orb._mesh.scale.y
	var orb_left_x: float = orb._mesh.position.x - radius_m * orb._mesh.scale.x
	var orb_right_x: float = orb._mesh.position.x + radius_m * orb._mesh.scale.x
	var two_pixel_margin_m: float = 2.0 / Orb3D.PIXELS_PER_METER
	var three_pixel_margin_m: float = 3.0 / Orb3D.PIXELS_PER_METER
	assert_true(
		label_top_y <= normal_eye_bottom_y - two_pixel_margin_m,
		"number top stays at least two pixels below the resting eyes in world Y"
	)
	assert_true(
		label_bottom_y >= orb_bottom_y + two_pixel_margin_m,
		"number bottom stays at least two pixels inside the jelly contour in world Y"
	)
	assert_true(
		label_left_x >= orb_left_x + three_pixel_margin_m,
		"two-digit number left edge stays at least three pixels inside the contour"
	)
	assert_true(
		label_right_x <= orb_right_x - three_pixel_margin_m,
		"two-digit number right edge stays at least three pixels inside the contour"
	)
	await _cleanup(fixture["root"] as Node)
	_restore_config(snapshot)


func _resolve_timed_pair(
	board: Board3D,
	resolver: CollisionResolver,
	first_level: int,
	first_timed: bool,
	second_level: int,
	second_timed: bool
) -> Dictionary:
	board.clear()
	await tree.process_frame
	var first: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, first_level, Vector2(-10.0, 0.0))
	var second: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, second_level, Vector2(10.0, 0.0))
	if first_timed:
		first.set_timed(8, 20)
	if second_timed:
		second.set_timed(8, 20)
	first.disable_physics()
	second.disable_physics()
	var captured: Array[Dictionary] = []
	resolver.reaction_applied.connect(
		func(reaction: Dictionary) -> void: captured.append(reaction.duplicate(false)),
		CONNECT_ONE_SHOT
	)
	resolver.report_contact(first, second, "timed_test")
	assert_eq(resolver.flush(), 1, "timed pair resolves")
	await tree.process_frame
	return captured[0]


func _create_fixture() -> Dictionary:
	var root: Node3D = Node3D.new()
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	root.add_child(board)
	board.owner = root
	var resolver: CollisionResolver = CollisionResolver.new()
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	root.add_child(resolver)
	resolver.owner = root
	var spawner: Spawner = Spawner.new()
	spawner.name = "Spawner"
	spawner.unique_name_in_owner = true
	root.add_child(spawner)
	spawner.owner = root
	var score: ScoreManager = ScoreManager.new()
	score.name = "ScoreManager"
	score.unique_name_in_owner = true
	score.save_path = ""
	root.add_child(score)
	score.owner = root
	var manager: TurnManager = TurnManager.new()
	manager.name = "TurnManager"
	root.add_child(manager)
	manager.owner = root
	tree.root.add_child(root)
	await tree.process_frame
	manager.set_physics_process(false)
	board.set_physics_process(false)
	resolver.proximity_reaction_scan_enabled = false
	return {
		"root": root,
		"board": board,
		"resolver": resolver,
		"spawner": spawner,
		"score": score,
		"manager": manager,
	}


func _enabled_candidate_rng_row(candidate: Dictionary) -> Array:
	return [int(candidate["level"]), int(candidate["color"]), float(candidate["t"])]


func _snapshot_config() -> Dictionary:
	return {
		"game_mode": Config.data.game_mode,
		"jelly_merge_duration": Config.data.jelly_merge_duration,
		"jelly_timed_enabled": Config.data.jelly_timed_enabled,
		"jelly_timed_first_turn": Config.data.jelly_timed_first_turn,
		"jelly_timed_interval_turns": Config.data.jelly_timed_interval_turns,
		"jelly_timed_level": Config.data.jelly_timed_level,
		"jelly_timed_turns": Config.data.jelly_timed_turns,
		"jelly_timed_turns_min": Config.data.jelly_timed_turns_min,
		"jelly_timed_turns_max": Config.data.jelly_timed_turns_max,
		"jelly_timed_early_turn_limit": Config.data.jelly_timed_early_turn_limit,
		"jelly_timed_early_turns_min": Config.data.jelly_timed_early_turns_min,
		"jelly_timed_early_turns_max": Config.data.jelly_timed_early_turns_max,
		"jelly_timed_burst_count": Config.data.jelly_timed_burst_count,
		"jelly_timed_stone_enabled": Config.data.jelly_timed_stone_enabled,
		"jelly_timed_stone_turns": Config.data.jelly_timed_stone_turns,
		"jelly_timed_fail_mode": Config.data.jelly_timed_fail_mode,
		"jelly_timed_scatter_count": Config.data.jelly_timed_scatter_count,
		"jelly_timed_bonus_levels": Config.data.jelly_timed_bonus_levels,
	}


func _restore_config(snapshot: Dictionary) -> void:
	Config.data.game_mode = int(snapshot["game_mode"]) as GameConfig.GameMode
	Config.data.jelly_merge_duration = float(snapshot["jelly_merge_duration"])
	Config.data.jelly_timed_enabled = bool(snapshot["jelly_timed_enabled"])
	Config.data.jelly_timed_first_turn = int(snapshot["jelly_timed_first_turn"])
	Config.data.jelly_timed_interval_turns = int(snapshot["jelly_timed_interval_turns"])
	Config.data.jelly_timed_level = int(snapshot["jelly_timed_level"])
	Config.data.jelly_timed_turns = int(snapshot["jelly_timed_turns"])
	Config.data.jelly_timed_turns_min = int(snapshot["jelly_timed_turns_min"])
	Config.data.jelly_timed_turns_max = int(snapshot["jelly_timed_turns_max"])
	Config.data.jelly_timed_early_turn_limit = int(snapshot["jelly_timed_early_turn_limit"])
	Config.data.jelly_timed_early_turns_min = int(snapshot["jelly_timed_early_turns_min"])
	Config.data.jelly_timed_early_turns_max = int(snapshot["jelly_timed_early_turns_max"])
	Config.data.jelly_timed_burst_count = int(snapshot["jelly_timed_burst_count"])
	Config.data.jelly_timed_stone_enabled = bool(snapshot["jelly_timed_stone_enabled"])
	Config.data.jelly_timed_stone_turns = int(snapshot["jelly_timed_stone_turns"])
	Config.data.jelly_timed_fail_mode = int(snapshot["jelly_timed_fail_mode"])
	Config.data.jelly_timed_scatter_count = int(snapshot["jelly_timed_scatter_count"])
	Config.data.jelly_timed_bonus_levels = int(snapshot["jelly_timed_bonus_levels"])


func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await tree.process_frame
	await tree.physics_frame
	InputRouter.set_locked(false)
