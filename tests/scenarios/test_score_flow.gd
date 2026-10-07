extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const COLLISION_RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const INPUT_ROUTER_SCRIPT: Script = preload("res://scripts/autoload/InputRouter.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const SCORE_MANAGER_SCRIPT: Script = preload("res://scripts/core/ScoreManager.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const BEST_SAVE_PATH: String = "res://tests/test_score_flow_best.tmp.cfg"
const CORRUPT_SAVE_PATH: String = "res://tests/test_score_flow_corrupt.tmp.cfg"


func test_same_turn_merges_score_twenty_and_track_combo_two() -> void:
	var fixture: Dictionary = await _create_reaction_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	var score_manager: ScoreManager = fixture["score_manager"] as ScoreManager
	var first: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(-120.0, 0.0))
	var second: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2.ZERO)
	var next: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2(120.0, 0.0))

	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "first merge count")
	var merge_result: Orb = _find_active_level(board, 2, next)
	assert_true(merge_result != null, "first merge result")
	if merge_result != null:
		next.position = merge_result.position
		next.exit_ghost_state()
		resolver.report_contact(merge_result, next)
		assert_eq(resolver.flush(), 0, "second merge waits for result lock")
		var tick: float = 1.0 / float(Engine.physics_ticks_per_second)
		var delay_frames: int = roundi(Config.data.chain_reaction_delay / tick)
		for frame_index: int in range(delay_frames):
			var applied: int = resolver.flush(tick)
			if frame_index < delay_frames - 1:
				assert_eq(applied, 0, "score chain remains locked")
			else:
				assert_eq(applied, 1, "second merge count")

	assert_eq(score_manager.score, 20, "merge chain score")
	assert_eq(score_manager.best_score, 20, "merge chain best score")
	assert_eq(manager.max_combo, 2, "merge combo maximum")
	assert_eq(score_manager.max_level_reached, 3, "merge chain maximum level")
	await _cleanup_fixture(fixture)


func test_combo_pipeline_is_independent_of_resolver_subscriber_order() -> void:
	var fixture: Dictionary = await _create_reaction_fixture(true)
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	var score_manager: ScoreManager = fixture["score_manager"] as ScoreManager
	for pair_index: int in range(3):
		var pair_x: float = float(pair_index - 1) * 240.0
		var first: Orb = board.spawn_orb(
			OrbTypes.OrbColor.YELLOW,
			1,
			Vector2(pair_x - 24.0, 0.0)
		)
		var second: Orb = board.spawn_orb(
			OrbTypes.OrbColor.YELLOW,
			1,
			Vector2(pair_x + 24.0, 0.0)
		)
		resolver.report_contact(first, second)
		assert_eq(resolver.flush(), 1, "ordered reaction %d" % (pair_index + 1))
	assert_eq(manager.turn_combo, 3, "turn manager observes all three reactions")
	assert_eq(manager.max_combo, 3, "single combo source tracks the maximum")
	assert_eq(score_manager.score, 28, "score uses combo one, two, three")
	assert_true(
		not resolver.reaction_applied.is_connected(score_manager.on_reaction),
		"score manager is not a resolver subscriber"
	)
	await _cleanup_fixture(fixture)


func test_waiting_input_reaction_scores_immediately() -> void:
	var fixture: Dictionary = await _create_reaction_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var score_manager: ScoreManager = fixture["score_manager"] as ScoreManager
	var first: Orb = board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, Vector2(-60.0, 0.0))
	var second: Orb = board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, Vector2(60.0, 0.0))

	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "waiting-input reaction count")
	assert_eq(score_manager.score, 4, "score updates in reaction flush")
	await _cleanup_fixture(fixture)


func test_best_score_is_saved_immediately_and_loaded_by_new_manager() -> void:
	_remove_test_file(BEST_SAVE_PATH)
	var first: ScoreManager = await _create_score_manager(BEST_SAVE_PATH)
	first.on_reaction(_reaction(ReactionRules.Type.MERGE, 1, [2, 2], 3))
	assert_eq(first.score, 8, "first manager score")
	assert_eq(first.best_score, 8, "first manager best")
	first.queue_free()
	await tree.process_frame

	var second: ScoreManager = await _create_score_manager(BEST_SAVE_PATH)
	assert_eq(second.score, 0, "new manager score starts at zero")
	assert_eq(second.best_score, 8, "new manager loads best")
	second.queue_free()
	await tree.process_frame
	_remove_test_file(BEST_SAVE_PATH)


func test_large_int64_score_is_saved_and_loaded() -> void:
	_remove_test_file(BEST_SAVE_PATH)
	var first: ScoreManager = await _create_score_manager(BEST_SAVE_PATH)
	var levels: Array[int] = [Config.data.orb_max_level, Config.data.orb_max_level]
	first.on_reaction(_reaction(ReactionRules.Type.MAX_CLEAR, 31, levels, 0))
	var expected: int = 687194767360
	assert_eq(first.score, expected, "large score")
	assert_eq(first.best_score, expected, "large best score")
	first.queue_free()
	await tree.process_frame

	var second: ScoreManager = await _create_score_manager(BEST_SAVE_PATH)
	assert_eq(second.best_score, expected, "large best restored")
	second.queue_free()
	await tree.process_frame
	_remove_test_file(BEST_SAVE_PATH)


func test_corrupt_save_starts_at_zero_without_stopping() -> void:
	_remove_test_file(CORRUPT_SAVE_PATH)
	var file: FileAccess = FileAccess.open(CORRUPT_SAVE_PATH, FileAccess.WRITE)
	assert_true(file != null, "corrupt save fixture opens")
	if file != null:
		file.store_string("[records\nbest_score=this is not valid")
		file.close()
	var score_manager: ScoreManager = await _create_score_manager(CORRUPT_SAVE_PATH)
	assert_eq(score_manager.score, 0, "corrupt save score")
	assert_eq(score_manager.best_score, 0, "corrupt save best")
	score_manager.queue_free()
	await tree.process_frame
	_remove_test_file(CORRUPT_SAVE_PATH)


func test_restart_request_resets_score_and_preserves_best_and_rule() -> void:
	var original_rule: GameConfig.AnnihilationRule = Config.data.annihilation_rule
	var score_manager: ScoreManager = await _create_score_manager("")
	score_manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 1, [2, 2], 3))
	Config.data.annihilation_rule = GameConfig.AnnihilationRule.C_REMAINDER
	var router: Variant = INPUT_ROUTER_SCRIPT.new()
	router.restart_requested.connect(score_manager.reset)
	router.set_locked(true)
	router._handle_event(_restart_key_event())

	assert_eq(score_manager.score, 0, "restart score reset")
	assert_eq(score_manager.best_score, 8, "restart best preserved")
	assert_eq(
		Config.data.annihilation_rule,
		GameConfig.AnnihilationRule.C_REMAINDER,
		"restart rule preserved"
	)
	router.free()
	score_manager.queue_free()
	await tree.process_frame
	Config.data.annihilation_rule = original_rule


func test_main_scene_binds_score_hud_and_restart() -> void:
	var original_spawn_count: int = Config.data.spawn_count_per_turn
	var original_preview_turns: int = Config.data.preview_turns
	Config.data.spawn_count_per_turn = 1
	Config.data.preview_turns = 2
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.TURN)
	var score_manager: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	score_manager.save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	assert_true(
		InputRouter.restart_requested.is_connected(Callable(main, "restart")),
		"main restart binding"
	)
	var score_label: Label = main.get_node("UI/Hud/ScoreLabel") as Label
	var best_label: Label = main.get_node("UI/Hud/BestLabel") as Label
	var max_combo_label: Label = main.get_node("UI/Hud/MaxComboLabel") as Label
	var combo_label: Label = main.get_node("UI/Hud/ComboLabel") as Label
	var danger_label: Label = main.get_node("UI/Hud/DangerLabel") as Label
	var spawner: Spawner = main.get_node("Spawner") as Spawner
	var hud: Control = main.get_node("UI/Hud") as Control
	var next_label: Label = main.get_node("UI/Hud/NextLabel") as Label
	var next_preview: Node2D = main.get_node("UI/Hud/NextPreview") as Node2D
	var then_label: Label = main.get_node("UI/Hud/ThenLabel") as Label
	var then_preview: Node2D = main.get_node("UI/Hud/ThenPreview") as Node2D
	_assert_combo_labels(main, 0, 0, "x1")
	main._cycle_spawn_count()
	var two_item_preview: Array = spawner.peek_preview()
	for batch_value: Variant in two_item_preview:
		assert_eq((batch_value as Array).size(), 2, "F3 updates every batch to two")
	main._cycle_spawn_count()

	manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 0, [1, 1], 2))
	_assert_combo_labels(main, 1, 1, "x1")
	assert_eq(danger_label.visible, false, "danger hidden below threshold")
	manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 0, [1, 1], 2))
	_assert_combo_labels(main, 2, 2, "x2")
	manager.on_reaction(
		_reaction(ReactionRules.Type.MERGE, 0, [1, 1], 2, 0.50)
	)
	_assert_combo_labels(main, 3, 3, "x4")
	assert_eq(score_label.text, "SCORE\n44", "score HUD text")
	assert_eq(best_label.text, "BEST\n44", "best HUD text")
	assert_eq(danger_label.text, "DANGER x2.0", "danger multiplier text")
	assert_true(danger_label.visible, "danger visible at threshold")

	manager._set_state(TurnManager.State.WAITING_INPUT)
	InputRouter.set_locked(false)
	manager.on_swipe(Vector2i.RIGHT)
	_assert_combo_labels(main, 0, 3, "x1")
	manager._set_state(TurnManager.State.WAITING_INPUT)
	manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 0, [1, 1], 2))
	_assert_combo_labels(main, 1, 3, "x1")
	assert_eq(score_label.text, "SCORE\n48", "waiting-input reaction score")
	assert_eq(max_combo_label.text, "MAX COMBO 3", "maximum survives swipe reset")
	assert_eq(combo_label.text, "COMBO 1 (x1)", "waiting-input combo text")
	assert_eq(score_label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "score ignores pointer")
	assert_eq(best_label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "best ignores pointer")
	assert_eq(max_combo_label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "combo ignores pointer")
	var preview_batches: Array = spawner.peek_preview()
	assert_eq(preview_batches.size(), 2, "NEXT and THEN batches")
	var next_batch: Array = preview_batches[0] as Array
	var then_batch: Array = preview_batches[1] as Array
	assert_eq(next_batch.size(), 3, "three-item next batch")
	assert_eq(then_batch.size(), 3, "three-item then batch")
	assert_eq(next_preview.get_child_count(), 3, "three preview visuals")
	assert_eq(then_preview.get_child_count(), 3, "three THEN visuals")
	_assert_preview_visuals(next_preview, next_batch, "NEXT")
	_assert_preview_visuals(then_preview, then_batch, "THEN")
	assert_eq(next_label.text, "NEXT", "next label")
	assert_eq(then_label.text, "THEN", "then label")
	assert_near(then_preview.scale.x, 0.6, 0.001, "THEN horizontal scale")
	assert_near(then_preview.scale.y, 0.6, 0.001, "THEN vertical scale")
	assert_near(then_preview.modulate.a, 0.5, 0.001, "THEN preview alpha")
	assert_near(then_label.modulate.a, 0.5, 0.001, "THEN label alpha")
	assert_eq(hud.mouse_filter, Control.MOUSE_FILTER_IGNORE, "HUD ignores pointer")
	assert_eq(next_label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "NEXT ignores pointer")
	assert_eq(then_label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "THEN ignores pointer")
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.spawn_count_per_turn = original_spawn_count
	Config.data.preview_turns = original_preview_turns


func test_game_over_panel_shows_scores_direction_and_restart_button() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.TURN)
	var score_manager: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	score_manager.save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 0, [3, 3], 4))
	manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 0, [3, 3], 4))
	manager.gravity = Vector2i.LEFT
	manager._set_state(TurnManager.State.GAME_OVER)
	manager.game_over.emit()

	var panel: GameOverPanel = main.get_node("UI/Hud/GameOverPanel") as GameOverPanel
	var score_label: Label = panel.get_node("Margin/Content/GameOverScore") as Label
	var best_label: Label = panel.get_node("Margin/Content/GameOverBest") as Label
	var combo_label: Label = panel.get_node("Margin/Content/GameOverMaxCombo") as Label
	var blocked_label: Label = panel.get_node("Margin/Content/GameOverBlocked") as Label
	var restart_button: Button = panel.get_node("Margin/Content/RestartButton") as Button
	var dimmer: ColorRect = main.get_node("UI/Hud/ResultDimmer") as ColorRect
	var panel_style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(panel.visible, "game-over panel visible")
	assert_true(dimmer.visible, "game-over dims the whole screen")
	assert_near(dimmer.color.a, 0.6, 0.001, "game-over dim alpha")
	assert_true(panel_style != null, "game-over panel has a flat opaque style")
	if panel_style != null:
		assert_true(panel_style.bg_color.a >= 0.92, "game-over panel opacity")
	assert_eq(score_label.text, "SCORE  48", "game-over score")
	assert_eq(best_label.text, "BEST  48", "game-over best")
	assert_eq(combo_label.text, "MAX COMBO 2", "game-over max combo")
	assert_eq(blocked_label.text, "BLOCKED: LEFT", "game-over blocked direction")
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "panel ignores pointer")
	assert_eq(restart_button.mouse_filter, Control.MOUSE_FILTER_STOP, "restart consumes pointer")

	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)


func test_new_main_resets_combo_ui_after_restart_reload() -> void:
	var first_main: Main = MAIN_SCENE.instantiate() as Main
	first_main.launch_immediately(GameConfig.GameMode.TURN)
	var first_score: ScoreManager = first_main.get_node("ScoreManager") as ScoreManager
	first_score.save_path = ""
	tree.root.add_child(first_main)
	await tree.process_frame
	var first_manager: TurnManager = first_main.get_node("TurnManager") as TurnManager
	for _reaction_index: int in range(3):
		first_manager.on_reaction(
			_reaction(ReactionRules.Type.MERGE, 0, [1, 1], 2)
		)
	_assert_combo_labels(first_main, 3, 3, "x4")
	first_main.queue_free()
	await tree.process_frame

	var restarted_main: Main = MAIN_SCENE.instantiate() as Main
	restarted_main.launch_immediately(GameConfig.GameMode.TURN)
	var restarted_score: ScoreManager = restarted_main.get_node("ScoreManager") as ScoreManager
	restarted_score.save_path = ""
	tree.root.add_child(restarted_main)
	await tree.process_frame
	var restarted_manager: TurnManager = restarted_main.get_node("TurnManager") as TurnManager
	assert_eq(restarted_manager.turn_combo, 0, "restarted current combo")
	assert_eq(restarted_manager.max_combo, 0, "restarted maximum combo")
	_assert_combo_labels(restarted_main, 0, 0, "x1")
	restarted_main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)


func _create_reaction_fixture(resolver_observer_first: bool = false) -> Dictionary:
	var fixture_root: Node = Node.new()
	fixture_root.name = "ScoreFlowFixture"
	var board: Board = BOARD_SCENE.instantiate() as Board
	board.name = "Board"
	board.unique_name_in_owner = true
	fixture_root.add_child(board)
	board.owner = fixture_root
	var resolver: CollisionResolver = COLLISION_RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	fixture_root.add_child(resolver)
	resolver.owner = fixture_root
	var score_manager: ScoreManager = SCORE_MANAGER_SCRIPT.new() as ScoreManager
	score_manager.name = "ScoreManager"
	score_manager.save_path = ""
	fixture_root.add_child(score_manager)
	score_manager.owner = fixture_root
	if resolver_observer_first:
		resolver.reaction_applied.connect(
			func(_reaction: Dictionary) -> void:
				pass
		)
	var spawner: Spawner = SPAWNER_SCRIPT.new() as Spawner
	spawner.name = "Spawner"
	spawner.unique_name_in_owner = true
	fixture_root.add_child(spawner)
	spawner.owner = fixture_root
	var manager: TurnManager = TURN_MANAGER_SCRIPT.new() as TurnManager
	manager.name = "TurnManager"
	fixture_root.add_child(manager)
	manager.owner = fixture_root
	tree.root.add_child(fixture_root)
	await tree.process_frame
	board.set_gravity(Vector2i.ZERO)
	manager.reaction_ready.connect(score_manager.on_reaction)
	return {
		"root": fixture_root,
		"board": board,
		"resolver": resolver,
		"score_manager": score_manager,
		"manager": manager,
	}


func _create_score_manager(path: String) -> ScoreManager:
	var score_manager: ScoreManager = SCORE_MANAGER_SCRIPT.new() as ScoreManager
	score_manager.save_path = path
	tree.root.add_child(score_manager)
	await tree.process_frame
	return score_manager


func _cleanup_fixture(fixture: Dictionary) -> void:
	var fixture_root: Node = fixture["root"] as Node
	fixture_root.queue_free()
	await tree.process_frame


func _find_active_level(board: Board, level: int, excluded: Orb) -> Orb:
	for orb: Orb in board.get_orbs():
		if orb != excluded and orb.level == level:
			return orb
	return null


func _assert_preview_visuals(
	preview_root: Node2D,
	batch: Array,
	label: String
) -> void:
	assert_eq(preview_root.get_child_count(), batch.size(), "%s visual count" % label)
	for index: int in range(mini(batch.size(), preview_root.get_child_count())):
		var candidate: Dictionary = batch[index] as Dictionary
		var visual: OrbVisual = preview_root.get_child(index) as OrbVisual
		assert_near(
			visual.get_radius(),
			Config.data.radius_for_level(int(candidate["level"])),
			0.001,
			"%s radius %d" % [label, index]
		)
		assert_eq(
			visual._display_color,
			Config.data.color_display[int(candidate["color"])],
			"%s color %d" % [label, index]
		)


func _assert_combo_labels(
	main: Main,
	combo: int,
	max_combo: int,
	expected_multiplier: String
) -> void:
	var combo_label: Label = main.get_node("UI/Hud/ComboLabel") as Label
	var max_combo_label: Label = main.get_node("UI/Hud/MaxComboLabel") as Label
	var debug_hud: DebugHud = main.get_node("UI") as DebugHud
	var debug_label: Label = main.get_node("UI/DebugLabel") as Label
	debug_hud._update_label()
	assert_eq(combo_label.visible, combo > 0, "combo visibility")
	if combo > 0:
		assert_eq(
			combo_label.text,
			"COMBO %d (%s)" % [combo, expected_multiplier],
			"current combo HUD text"
		)
	assert_eq(max_combo_label.text, "MAX COMBO %d" % max_combo, "maximum combo HUD text")
	assert_true(
		debug_label.text.contains("Combo: %d (%s)" % [combo, expected_multiplier]),
		"debug current combo text"
	)
	assert_true(
		debug_label.text.contains("Max Combo: %d" % max_combo),
		"debug maximum combo text"
	)
	assert_true(debug_label.text.contains("Rule: off"), "debug shows disabled opposites")


func _reaction(
	type: ReactionRules.Type,
	combo: int,
	levels: Array[int],
	result_level: int = 0,
	occupancy: float = 0.20
) -> Dictionary:
	return {
		"type": type,
		"combo": combo,
		"levels": levels,
		"result_level": result_level,
		"occupancy": occupancy,
	}


func _restart_key_event() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_R
	event.pressed = true
	return event


func _remove_test_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
