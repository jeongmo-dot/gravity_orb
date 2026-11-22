extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const JUA_FONT: FontFile = preload("res://assets/fonts/Jua-Regular.ttf")
const HUD_THEME: Theme = preload("res://assets/ui/gravity_orb_theme.tres")


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


func test_turn_panel_fills_sound_to_score_gap_without_moving_existing_hud() -> void:
	for viewport_size: Vector2 in [Vector2(1080.0, 1920.0), Vector2(1080.0, 2340.0)]:
		var layout: Dictionary = Hud.hud_layout(
			viewport_size,
			Rect2(Vector2.ZERO, viewport_size)
		)
		var sound: Rect2 = layout["sound"] as Rect2
		var score: Rect2 = layout["score_panel"] as Rect2
		var turn_panel: Rect2 = layout["turn_panel"] as Rect2
		assert_near(turn_panel.position.x, sound.end.x + 12.0, 0.001, "turn starts after sound")
		assert_near(turn_panel.end.x, score.position.x - 12.0, 0.001, "turn ends before score")
		assert_near(turn_panel.position.y, score.position.y, 0.001, "turn shares top row")
		assert_near(turn_panel.size.y, score.size.y, 0.001, "turn shares top-row height")
		assert_true(turn_panel.encloses(layout["turn_title"] as Rect2), "TURN title fits panel")
		assert_true(turn_panel.encloses(layout["turn"] as Rect2), "turn number fits panel")
		assert_eq((layout["score_panel"] as Rect2), Rect2(300.0, 24.0, 480.0, 150.0), "score unchanged")
		assert_eq((layout["best_panel"] as Rect2), Rect2(820.0, 24.0, 236.0, 150.0), "best unchanged")


func test_preview_orbs_match_board_scale_and_count_uses_actual_jelly_items() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.JELLY)
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var board_rect: Rect2 = hud._projected_board_rect()
	var expected_scale: float = board_rect.size.x / Config.data.board_size
	for count: int in [1, 2, 5, 6]:
		var next_batch: Array = []
		for index: int in range(count):
			next_batch.append({"color": index % 4, "level": 2})
		hud._on_preview_changed([next_batch, next_batch])
		var rendered_count: int = mini(count, Hud.MAX_PREVIEW_COUNT)
		assert_eq(hud._next_preview.get_child_count(), rendered_count, "NEXT rendered item count")
		assert_eq(hud._then_preview.get_child_count(), rendered_count, "THEN rendered item count")
		assert_eq(hud._next_count_label.text, "×%d" % count, "NEXT actual jelly count")
		assert_eq(hud._then_count_label.text, "×%d" % count, "THEN actual jelly count")
		assert_eq(hud._next_count_label.visible, count > Hud.MAX_PREVIEW_COUNT, "NEXT count visibility")
		assert_eq(hud._then_count_label.visible, count > Hud.MAX_PREVIEW_COUNT, "THEN count visibility")
		for preview_root: Node2D in [hud._next_preview, hud._then_preview]:
			for child: Node in preview_root.get_children():
				var visual: OrbVisual = child as OrbVisual
				assert_near(
					visual.scale.x,
					expected_scale,
					0.001,
					"preview scale matches projected board for %d items" % count
				)
	assert_eq(hud._then_preview.scale, Vector2.ONE, "THEN no longer scales previews down")
	assert_near(hud._then_preview.modulate.a, 0.5, 0.001, "THEN remains half alpha")
	var camera: Camera3D = tree.root.get_viewport().get_camera_3d()
	var original_fov: float = camera.fov
	camera.fov = original_fov + 8.0
	hud._apply_responsive_layout()
	var changed_scale: float = hud._projected_board_rect().size.x / Config.data.board_size
	assert_true(not is_equal_approx(changed_scale, expected_scale), "projection change alters preview scale")
	for child: Node in hud._next_preview.get_children():
		assert_near(
			(child as OrbVisual).scale.x,
			changed_scale,
			0.001,
			"stored preview rerenders when projected board size changes"
		)
	camera.fov = original_fov
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.game_mode = GameConfig.GameMode.TURN


func test_preview_spacing_reduces_then_overlaps_without_changing_size() -> void:
	var radii: Array[float] = []
	for _index: int in range(5):
		radii.append(Config.data.radius_for_level(2))
	var scale: float = Hud.preview_scale_for_width(499.2, Config.data.board_size)
	var diameter_total: float = radii[0] * 2.0 * scale * float(radii.size())
	var reduced_width: float = diameter_total + 12.0
	var reduced_spacing: float = Hud.preview_item_spacing(radii, scale, reduced_width)
	assert_true(reduced_spacing >= 0.0, "spacing stays nonnegative while diameters fit")
	assert_true(reduced_spacing < Hud.PREVIEW_GAP * scale, "spacing shrinks before overlap")

	var overlap_width: float = diameter_total - 28.0
	var overlap_spacing: float = Hud.preview_item_spacing(radii, scale, overlap_width)
	assert_true(overlap_spacing < 0.0, "items overlap evenly when diameters exceed region")
	var centers: PackedFloat32Array = Hud.preview_item_centers(radii, scale, overlap_width)
	var radius_px: float = radii[0] * scale
	assert_true(centers[0] - radius_px >= -overlap_width * 0.5 - 0.001, "first item stays in region")
	assert_true(centers[4] + radius_px <= overlap_width * 0.5 + 0.001, "last item stays in region")
	for index: int in range(1, centers.size()):
		assert_near(
			centers[index] - centers[index - 1],
			radius_px * 2.0 + overlap_spacing,
			0.001,
			"overlap is distributed equally"
		)


func test_scene_has_only_jelly_frontend_controls() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	tree.root.add_child(main)
	await tree.process_frame
	var start: StartScreen = main.get_node("UI/StartScreen") as StartScreen
	assert_true(start.get_node_or_null("Content/JellyButton") != null, "JELLY action exists")
	assert_true(start.get_node_or_null("Content/ClassicButton") == null, "CLASSIC action absent")
	var ranking: RankingPanel = main.get_node("UI/RankingPanel") as RankingPanel
	assert_true(ranking.get_node_or_null("Panel/Content/Tabs") == null, "ranking tabs absent")
	var hud: Hud = main.get_node("UI/Hud") as Hud
	assert_true(hud.get_node_or_null("TurnPanel") != null, "TURN panel exists")
	assert_true(hud.get_node_or_null("TurnTitleLabel") != null, "TURN title exists")
	assert_true(hud.get_node_or_null("TurnLabel") != null, "TURN value exists")
	assert_true(hud.get_node_or_null("BlockedPanel") == null, "blocked text panel removed")
	assert_true(hud.get_node_or_null("BlockedLabel") == null, "blocked text label removed")
	assert_true(hud.get_node_or_null("TurnInputIndicator") == null, "direction arrows are removed")
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.game_mode = GameConfig.GameMode.TURN


func test_warm_hud_theme_is_scoped_to_gameplay_and_result_controls() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.JELLY)
	tree.root.add_child(main)
	await tree.process_frame
	var hud: Hud = main.get_node("UI/Hud") as Hud
	assert_eq(
		(hud.get_node("TurnPanel") as PanelContainer).theme_type_variation,
		&"WarmCard",
		"TURN uses the warm card without changing shared HudPanel"
	)
	assert_eq(
		(hud.get_node("HudSoundButton") as Button).theme_type_variation,
		&"WarmSoundButton",
		"sound uses the warm pink button"
	)
	assert_eq(
		(hud.get_node("NextPreviewWell") as Panel).size,
		Vector2(200.0, 200.0),
		"NEXT well is 200 square"
	)
	assert_eq(
		(hud.get_node("ThenPreviewWell") as Panel).size,
		Vector2(152.0, 152.0),
		"THEN well is 152 square"
	)
	var result: GameOverPanel = hud.get_node("GameOverPanel") as GameOverPanel
	assert_eq(result.theme_type_variation, &"WarmResultPanel", "result uses warm card")
	assert_near(result.size.x, 880.0, 0.001, "result width is 880")
	assert_true(result.get_node_or_null("Margin/Content/StatWellTurn") != null, "turn well exists")
	assert_true(result.get_node_or_null("Margin/Content/StatWellFinal") != null, "final move well exists")
	var start: StartScreen = main.get_node("UI/StartScreen") as StartScreen
	assert_true(
		(start.get_node("Content/JellyButton") as Button).theme_type_variation != &"WarmPrimaryButton",
		"start screen keeps its pre-159 theme"
	)
	assert_true(FileAccess.file_exists("res://assets/fonts/Jua-Regular.ttf"), "Jua font is bundled")
	assert_true(not FileAccess.file_exists("res://scripts/ui/TurnInputIndicator.gd"), "arrow script is deleted")
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.game_mode = GameConfig.GameMode.TURN


func test_jua_font_uses_noto_fallback_for_missing_ui_characters() -> void:
	var ui_text: String = (
		"TURN SCORE BEST MAX COMBO DANGER NEXT THEN GAME OVER "
		+ "FINAL MOVE 최고 기록 새 기록 위 다시 하기 랭킹 처음 화면 "
		+ "턴 수 최대 콤보 최고 젤리 번 버팀 시한 굳은 폭발 청소"
	)
	var missing: String = ""
	for index: int in range(ui_text.length()):
		var character: String = ui_text[index]
		if not JUA_FONT.has_char(character.unicode_at(0)) and not missing.contains(character):
			missing += character
	var warm_font: Font = HUD_THEME.get_font(&"font", &"WarmText")
	assert_true(not warm_font.fallbacks.is_empty(), "WarmText configures a Noto fallback")
	print("JUA_FALLBACK_CHARACTERS=%s" % ("none" if missing.is_empty() else missing))
