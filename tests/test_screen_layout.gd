extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")


func test_single_jelly_start_layout_fits_both_supported_ratios() -> void:
	for viewport_size: Vector2 in [Vector2(540.0, 960.0), Vector2(540.0, 1170.0)]:
		var layout: Dictionary = StartScreen.layout_for_viewport(viewport_size)
		var jelly: Rect2 = layout["jelly"] as Rect2
		assert_true(jelly.position.x >= 0.0, "JELLY action starts inside viewport")
		assert_true(jelly.end.x <= viewport_size.x, "JELLY action ends inside viewport")
		assert_near(jelly.size.y, 100.0, 0.01, "200px baseline height scales at 540px")
		assert_near(jelly.size.x, 468.0, 0.01, "old two-card width scales at 540px")
		for key: String in ["jelly_icon", "jelly_name", "jelly_description", "jelly_best"]:
			assert_true(jelly.encloses(layout[key] as Rect2), "%s stays inside action" % key)
		for key: String in ["ranking", "sound", "settings"]:
			var action: Rect2 = layout[key] as Rect2
			assert_true(action.position.x >= 0.0 and action.end.x <= viewport_size.x, "%s fits" % key)
			assert_true(action.position.y >= 0.0 and action.end.y <= viewport_size.y, "%s fits" % key)


func test_jelly_hud_layout_stays_in_safe_area_at_both_ratios() -> void:
	for viewport_size: Vector2 in [Vector2(540.0, 960.0), Vector2(540.0, 1170.0)]:
		var safe: Rect2 = Rect2(Vector2.ZERO, viewport_size)
		var layout: Dictionary = Hud.hud_layout(viewport_size, safe)
		for key: String in ["score_panel", "best_panel", "danger_panel", "preview_shelf"]:
			assert_true(safe.encloses(layout[key] as Rect2), "%s fits safe area" % key)


func test_scene_has_only_jelly_frontend_controls() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	tree.root.add_child(main)
	await tree.process_frame
	var start: StartScreen = main.get_node("UI/StartScreen") as StartScreen
	assert_true(start.get_node_or_null("Content/JellyButton") != null, "JELLY action exists")
	assert_true(start.get_node_or_null("Content/ClassicButton") == null, "CLASSIC action absent")
	var ranking: RankingPanel = main.get_node("UI/RankingPanel") as RankingPanel
	assert_true(ranking.get_node_or_null("Panel/Content/Tabs") == null, "ranking tabs absent")
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.game_mode = GameConfig.GameMode.TURN
