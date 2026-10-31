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


func test_preview_orbs_match_board_scale_for_one_two_and_five_items() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.JELLY)
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var board_rect: Rect2 = hud._projected_board_rect()
	var expected_scale: float = board_rect.size.x / Config.data.board_size
	for count: int in [1, 2, 5]:
		var next_batch: Array = []
		for index: int in range(count):
			next_batch.append({"color": index % 4, "level": 2})
		hud._on_preview_changed([next_batch, next_batch])
		assert_eq(hud._next_preview.get_child_count(), count, "NEXT item count")
		assert_eq(hud._then_preview.get_child_count(), count, "THEN item count")
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
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.game_mode = GameConfig.GameMode.TURN
