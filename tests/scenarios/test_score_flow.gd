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
	var score_manager: ScoreManager = fixture["score_manager"] as ScoreManager
	var first: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(-120.0, 0.0))
	var second: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2.ZERO)
	var next: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2(120.0, 0.0))

	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "first merge count")
	var merge_result: Orb = _find_active_level(board, 2, next)
	assert_true(merge_result != null, "first merge result")
	if merge_result != null:
		resolver.report_contact(merge_result, next)
		assert_eq(resolver.flush(), 1, "second merge count")

	assert_eq(score_manager.score, 20, "merge chain score")
	assert_eq(score_manager.best_score, 20, "merge chain best score")
	assert_eq(score_manager.max_combo, 2, "merge combo maximum")
	assert_eq(score_manager.max_level_reached, 3, "merge chain maximum level")
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
	Config.data.spawn_count_per_turn = 3
	var main: Main = MAIN_SCENE.instantiate() as Main
	var score_manager: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	score_manager.save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	assert_true(
		InputRouter.restart_requested.is_connected(Callable(main, "restart")),
		"main restart binding"
	)
	score_manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 2, [3, 3], 4))
	var score_label: Label = main.get_node("UI/Hud/ScoreLabel") as Label
	var best_label: Label = main.get_node("UI/Hud/BestLabel") as Label
	var max_combo_label: Label = main.get_node("UI/Hud/MaxComboLabel") as Label
	var combo_label: Label = main.get_node("UI/Hud/ComboLabel") as Label
	var danger_label: Label = main.get_node("UI/Hud/DangerLabel") as Label
	var spawner: Spawner = main.get_node("Spawner") as Spawner
	var next_preview: Node2D = main.get_node("UI/Hud/NextPreview") as Node2D
	assert_eq(score_label.text, "SCORE\n32", "score HUD text")
	assert_eq(best_label.text, "BEST\n32", "best HUD text")
	assert_eq(max_combo_label.text, "MAX COMBO  2", "combo HUD text")
	assert_eq(combo_label.text, "COMBO x2", "current combo multiplier")
	assert_true(combo_label.visible, "current combo visible")
	assert_eq(danger_label.visible, false, "danger hidden below threshold")
	score_manager.on_reaction(
		_reaction(ReactionRules.Type.MERGE, 3, [1, 1], 2, 0.50)
	)
	assert_eq(combo_label.text, "COMBO x4", "updated combo multiplier")
	assert_eq(danger_label.text, "DANGER x2.0", "danger multiplier text")
	assert_true(danger_label.visible, "danger visible at threshold")
	assert_eq(score_label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "score ignores pointer")
	assert_eq(best_label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "best ignores pointer")
	assert_eq(max_combo_label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "combo ignores pointer")
	var next_batch: Array[Dictionary] = spawner.peek_next()
	assert_eq(next_batch.size(), 3, "three-item next batch")
	assert_eq(next_preview.get_child_count(), 3, "three preview visuals")
	for index: int in range(mini(next_batch.size(), next_preview.get_child_count())):
		var visual: OrbVisual = next_preview.get_child(index) as OrbVisual
		assert_near(
			visual.get_radius(),
			Config.data.radius_for_level(int(next_batch[index]["level"])),
			0.001,
			"preview radius %d" % index
		)
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.spawn_count_per_turn = original_spawn_count


func test_game_over_panel_shows_scores_direction_and_restart_button() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	var score_manager: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	score_manager.save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	score_manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 2, [3, 3], 4))
	manager.gravity = Vector2i.LEFT
	manager._set_state(TurnManager.State.GAME_OVER)
	manager.game_over.emit()

	var panel: GameOverPanel = main.get_node("UI/Hud/GameOverPanel") as GameOverPanel
	var score_label: Label = panel.get_node("Margin/Content/GameOverScore") as Label
	var best_label: Label = panel.get_node("Margin/Content/GameOverBest") as Label
	var combo_label: Label = panel.get_node("Margin/Content/GameOverMaxCombo") as Label
	var blocked_label: Label = panel.get_node("Margin/Content/GameOverBlocked") as Label
	var restart_button: Button = panel.get_node("Margin/Content/RestartButton") as Button
	assert_true(panel.visible, "game-over panel visible")
	assert_eq(score_label.text, "SCORE  32", "game-over score")
	assert_eq(best_label.text, "BEST  32", "game-over best")
	assert_eq(combo_label.text, "MAX COMBO  2", "game-over max combo")
	assert_eq(blocked_label.text, "BLOCKED: LEFT", "game-over blocked direction")
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "panel ignores pointer")
	assert_eq(restart_button.mouse_filter, Control.MOUSE_FILTER_STOP, "restart consumes pointer")

	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)


func _create_reaction_fixture() -> Dictionary:
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
	resolver.reaction_applied.connect(score_manager.on_reaction)
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
