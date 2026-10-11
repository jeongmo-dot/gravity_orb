extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const MAIN_3D_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const HUD_THEME: Theme = preload("res://assets/ui/gravity_orb_theme.tres")
const VIEWPORT_CASES: Array[Dictionary] = [
	{
		"output": Vector2(540.0, 960.0),
		"logical": Vector2(1080.0, 1920.0),
		"safe": Rect2(0.0, 0.0, 1080.0, 1920.0),
	},
	{
		"output": Vector2(540.0, 1170.0),
		"logical": Vector2(1080.0, 2340.0),
		"safe": Rect2(24.0, 64.0, 1032.0, 2212.0),
	},
]
const FONT_PATHS: Array[String] = [
	"res://assets/fonts/Orbitron[wght].ttf",
	"res://assets/fonts/NotoSansKR-Regular-KSX1001.ttf",
	"res://assets/fonts/NotoSansKR-Medium-KSX1001.ttf",
]


func test_busy_blitz_hud_regions_do_not_overlap_at_supported_sizes() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var main: Main = await _create_blitz_main()
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var spawner: Spawner = main.get_node("Spawner") as Spawner
	var manager: BlitzManager = main.get_node("BlitzManager") as BlitzManager
	hud._on_combo_changed(8, 8.0, 8)
	hud._on_fever_changed(true, 3.0)
	hud._set_danger_badge(0.70, 4.0)
	spawner.sync_blitz_next_batch_size(8)
	manager.play_time_elapsed = 120.0
	hud._on_time_changed(manager.remaining_time)
	hud._on_time_bonus_awarded(0.3, "MERGE_L4")
	hud._process(Config.data.blitz_time_bonus_display_window)
	await tree.process_frame

	var score: Label = main.get_node("UI/Hud/ScoreLabel") as Label
	var multiplier: Label = main.get_node("UI/Hud/MultiplierLabel") as Label
	var danger: Label = main.get_node("UI/Hud/DangerLabel") as Label
	var timer: Label = main.get_node("UI/Hud/TimerLabel") as Label
	score.scale = Vector2.ONE
	multiplier.scale = Vector2.ONE
	danger.scale = Vector2.ONE
	timer.scale = Vector2.ONE

	var regions: Dictionary = {
		"score_title": main.get_node("UI/Hud/ScoreTitleLabel") as Control,
		"score": score,
		"best_title": main.get_node("UI/Hud/BestTitleLabel") as Control,
		"best": main.get_node("UI/Hud/BestLabel") as Control,
		"max_chain": main.get_node("UI/Hud/MaxComboLabel") as Control,
		"multiplier": multiplier,
		"chain_fever": main.get_node("UI/Hud/ComboLabel") as Control,
		"danger": danger,
		"next": main.get_node("UI/Hud/NextPreviewRegion") as Control,
		"then": main.get_node("UI/Hud/ThenPreviewRegion") as Control,
		"timer": timer,
		"time_bar": main.get_node("UI/Hud/TimeBarTrack") as Control,
		"drain_rate": main.get_node("UI/Hud/DrainRateLabel") as Control,
		"time_bonus": main.get_node("UI/Hud/BonusLabel") as Control,
		"sound": main.get_node("UI/Hud/HudSoundButton") as Control,
	}
	_assert_regions_do_not_overlap(regions, "540x960")

	await _destroy_main(main)
	Config.data.game_mode = original_mode


func test_hud_layout_stays_in_safe_area_and_clear_of_board_at_both_ratios() -> void:
	var base_board_rect: Rect2 = Rect2()
	for viewport_case: Dictionary in VIEWPORT_CASES:
		var output: Vector2 = viewport_case["output"] as Vector2
		var logical: Vector2 = viewport_case["logical"] as Vector2
		var safe: Rect2 = viewport_case["safe"] as Rect2
		var layout: Dictionary = Hud.hud_layout(logical, safe)
		var region_names: Array[String] = [
			"score_title", "score", "best_title", "best", "sound", "danger",
			"multiplier", "combo",
			"max_combo", "timer", "time_bar", "drain_rate", "time_bonus",
			"blocked", "next_label", "next", "then_label", "then",
		]
		for region_name: String in region_names:
			var rect: Rect2 = layout[region_name] as Rect2
			assert_true(
				safe.encloses(rect),
				"%dx%d %s stays inside safe area (%s / %s)" % [
					roundi(output.x), output.y, region_name, str(rect), str(safe)
				]
			)
		_assert_layout_rects_do_not_overlap(layout, region_names, output)
		assert_near((layout["sound"] as Rect2).position.x, safe.position.x + 24.0, 0.01,
			"%dx%d sound keeps left margin" % [roundi(output.x), roundi(output.y)])
		assert_near((layout["danger_panel"] as Rect2).position.x, safe.position.x + 24.0,
			0.01, "%dx%d danger keeps left margin" % [roundi(output.x), roundi(output.y)])
		assert_near((layout["best_panel"] as Rect2).end.x, safe.end.x - 24.0, 0.01,
			"%dx%d BEST keeps right margin" % [roundi(output.x), roundi(output.y)])
		assert_near((layout["max_combo"] as Rect2).end.x, safe.end.x - 24.0, 0.01,
			"%dx%d MAX COMBO keeps right margin" % [roundi(output.x), roundi(output.y)])
		assert_true(
			(layout["next_count"] as Rect2).end.y
			<= (layout["next"] as Rect2).position.y - 4.0,
			"%dx%d NEXT count stays four pixels above orb region" % [
				roundi(output.x), roundi(output.y)
			]
		)
		assert_true(
			(layout["then_count"] as Rect2).end.y
			<= (layout["then"] as Rect2).position.y - 4.0,
			"%dx%d THEN count stays four pixels above orb region" % [
				roundi(output.x), roundi(output.y)
			]
		)

		var setup: Dictionary = await _create_3d_main_in_viewport(logical)
		var main: Main = setup["main"] as Main
		var camera: Camera3D = main.get_node("Camera3D") as Camera3D
		var board: Board3D = main.get_node("Board") as Board3D
		var board_rect: Rect2 = _project_board_outer_rect(camera, board)
		assert_true(board_rect.position.x >= 16.0,
			"%dx%d projected board keeps left margin (%s)" % [
				roundi(output.x), roundi(output.y), str(board_rect)
			])
		assert_true(board_rect.end.x <= logical.x - 16.0,
			"%dx%d projected board keeps right margin (%s)" % [
				roundi(output.x), roundi(output.y), str(board_rect)
			])
		var top_hud_names: Array[String] = [
			"score_panel", "best_panel", "sound", "danger_panel", "multiplier",
			"combo", "max_combo", "timer", "drain_rate", "time_bonus", "time_bar",
		]
		for top_hud_name: String in top_hud_names:
			assert_true(
				(layout[top_hud_name] as Rect2).end.y <= board_rect.position.y,
				"%dx%d %s stays above projected board" % [
					roundi(output.x), roundi(output.y), top_hud_name
				]
			)
		assert_true(
			(layout["preview_shelf"] as Rect2).position.y >= board_rect.end.y,
			"%dx%d preview shelf stays below board" % [roundi(output.x), roundi(output.y)]
		)
		if base_board_rect.size.x > 0.0:
			assert_near(
				board_rect.size.x,
				base_board_rect.size.x,
				base_board_rect.size.x * 0.01,
				"projected board widths differ by no more than one percent"
			)
			assert_eq(camera.keep_aspect, Camera3D.KEEP_WIDTH,
				"taller-than-9:16 viewport keeps horizontal FOV")
			assert_near(camera.fov, Main.base_horizontal_fov_degrees(), 0.001,
				"tall viewport uses calculated 9:16 horizontal FOV")
		else:
			base_board_rect = board_rect
			assert_eq(camera.keep_aspect, Camera3D.KEEP_HEIGHT,
				"9:16 viewport preserves vertical FOV mode")
			assert_near(camera.fov, Main.BASE_VERTICAL_FOV_DEGREES, 0.001,
				"9:16 viewport preserves 25 degree vertical FOV")
		await _destroy_3d_setup(setup)


func test_hud_theme_fonts_panel_tokens_and_extreme_values_fit() -> void:
	var total_font_bytes: int = 0
	for path: String in FONT_PATHS:
		assert_true(FileAccess.file_exists(path), "%s exists" % path)
		total_font_bytes += FileAccess.get_file_as_bytes(path).size()
	assert_true(total_font_bytes <= 3 * 1024 * 1024, "font bundle stays within 3 MiB")
	assert_true(
		HUD_THEME.get_color(&"text_primary", &"GravityOrb").is_equal_approx(
			Color("#E8EEFF")
		),
		"primary text token"
	)
	assert_true(
		HUD_THEME.get_color(&"danger", &"GravityOrb").is_equal_approx(
			Color("#FF3B30")
		),
		"danger token"
	)
	var panel_style: StyleBoxFlat = HUD_THEME.get_stylebox(
		&"panel", &"HudPanel"
	) as StyleBoxFlat
	assert_true(panel_style != null, "shared HUD panel style exists")
	assert_eq(panel_style.corner_radius_top_left, 12, "HUD panel radius")
	assert_eq(panel_style.border_width_left, 2, "HUD panel border")

	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var main: Main = await _create_blitz_main()
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var score_title: Label = main.get_node("UI/Hud/ScoreTitleLabel") as Label
	var score: Label = main.get_node("UI/Hud/ScoreLabel") as Label
	var best_title: Label = main.get_node("UI/Hud/BestTitleLabel") as Label
	var best: Label = main.get_node("UI/Hud/BestLabel") as Label
	var then_title: Label = main.get_node("UI/Hud/ThenLabel") as Label
	var sound: Button = main.get_node("UI/Hud/HudSoundButton") as Button
	var timer: Label = main.get_node("UI/Hud/TimerLabel") as Label
	var time_track: Panel = main.get_node("UI/Hud/TimeBarTrack") as Panel
	var time_fill: ColorRect = main.get_node("UI/Hud/TimeBarFill") as ColorRect
	var spawner: Spawner = main.get_node("Spawner") as Spawner
	hud._on_score_changed(0, 9_999_999)
	hud._set_displayed_score(9_999_999)
	hud._on_time_changed(45.0)
	spawner.sync_blitz_next_batch_size(8)
	await tree.process_frame
	assert_eq(score_title.text, "SCORE", "score title is a separate fixed label")
	assert_eq(score.text, "9999999", "seven-digit score text")
	assert_eq(best_title.text, "BEST", "BEST title is a separate fixed label")
	assert_eq(best.text, "9999999", "BEST numeric label contains only digits")
	var score_font_size: int = score.get_theme_font_size("font_size")
	var best_font_size: int = best.get_theme_font_size("font_size")
	assert_true(score_font_size >= Hud.SCORE_FONT_MIN, "score respects minimum font size")
	assert_true(best_font_size >= Hud.BEST_FONT_MIN, "BEST respects minimum font size")
	var score_font: FontVariation = score.get_theme_font("font") as FontVariation
	var best_font: FontVariation = best.get_theme_font("font") as FontVariation
	assert_true(
		score_font.get_string_size(
			score.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, score_font_size
		).x <= score.size.x - Hud.NUMERIC_SIDE_PADDING * 2.0,
		"9,999,999 measured width fits score panel with eight pixels on each side"
	)
	assert_true(
		best_font.get_string_size(
			best.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, best_font_size
		).x <= best.size.x - Hud.NUMERIC_SIDE_PADDING * 2.0,
		"9,999,999 measured width fits BEST panel with eight pixels on each side"
	)
	if score_font_size < Hud.SCORE_FONT_MAX:
		assert_true(
			score_font.get_string_size(
				score.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, score_font_size + 1
			).x > score.size.x - Hud.NUMERIC_SIDE_PADDING * 2.0,
			"score uses the largest measured font size that fits"
		)
	if best_font_size < Hud.BEST_FONT_MAX:
		assert_true(
			best_font.get_string_size(
				best.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, best_font_size + 1
			).x > best.size.x - Hud.NUMERIC_SIDE_PADDING * 2.0,
			"BEST uses the largest measured font size that fits"
		)
	assert_eq(timer.text, "45.0", "45-second timer text")
	assert_near(
		time_fill.size.x,
		time_track.size.x - Hud.TIME_BAR_INSET * 2.0,
		0.01,
		"45 seconds fills the complete time bar"
	)
	var next_count: Label = main.get_node("UI/Hud/NextCountLabel") as Label
	assert_eq(next_count.text, "×8", "NEXT eight-count text")
	assert_true(next_count.get_global_rect().size.x >= 80.0, "NEXT count is not clipped")
	var score_title_font: FontVariation = score_title.get_theme_font("font") as FontVariation
	assert_true(score_font != null, "score uses Orbitron FontVariation")
	assert_true(best_font != null, "BEST uses Orbitron FontVariation")
	assert_true(score_title_font != null, "score title uses Orbitron FontVariation")
	assert_true(
		score_font.base_font.resource_path.ends_with("Orbitron[wght].ttf"),
		"score uses bundled unmodified Orbitron variable font"
	)
	var text_server: TextServer = TextServerManager.get_primary_interface()
	var weight_tag: int = text_server.name_to_tag("wght")
	assert_eq(weight_tag, 2003265652, "OpenType wght tag is the serialized numeric key")
	assert_near(float(score_font.variation_opentype.get(weight_tag, 0.0)), 700.0, 0.01,
		"score selects Orbitron weight 700")
	assert_near(float(score_title_font.variation_opentype.get(weight_tag, 0.0)), 500.0, 0.01,
		"score title selects Orbitron weight 500")
	var medium_rid: RID = score_title_font.get_rids()[0]
	var bold_rid: RID = score_font.get_rids()[0]
	var medium_glyph: int = text_server.font_get_glyph_index(
		medium_rid, 64, "9".unicode_at(0), 0
	)
	var bold_glyph: int = text_server.font_get_glyph_index(
		bold_rid, 64, "9".unicode_at(0), 0
	)
	var medium_contours: Dictionary = text_server.font_get_glyph_contours(
		medium_rid, 64, medium_glyph
	)
	var bold_contours: Dictionary = text_server.font_get_glyph_contours(
		bold_rid, 64, bold_glyph
	)
	var medium_points: PackedVector3Array = medium_contours["points"]
	var bold_points: PackedVector3Array = bold_contours["points"]
	assert_true(medium_rid != bold_rid, "Orbitron 500 and 700 use distinct font variations")
	assert_true(medium_points != bold_points, "Orbitron 500 and 700 glyph outlines differ")
	assert_true(
		float(score_title.get_theme_font_size("font_size"))
		<= float(Hud.SCORE_FONT_MAX) * 0.42,
		"score title is about forty percent of numeric maximum"
	)
	assert_eq(best_title.get_theme_font_size("font_size"), 22,
		"BEST title uses the same fixed size as SCORE")
	assert_eq(best_title.get_theme_font_size("font_size"),
		score_title.get_theme_font_size("font_size"), "SCORE and BEST title sizes match")
	assert_true(score_title.get_theme_color("font_color").is_equal_approx(Color("#8EA3C8")),
		"score title uses opaque secondary color")
	assert_true(best_title.get_theme_color("font_color").is_equal_approx(Color("#8EA3C8")),
		"BEST title uses opaque secondary color")
	assert_true(then_title.get_theme_color("font_color").is_equal_approx(Color("#8EA3C8")),
		"THEN title uses opaque secondary color")
	assert_near(then_title.modulate.a, 1.0, 0.001, "THEN title is opaque")
	assert_eq(sound.icon_alignment, HORIZONTAL_ALIGNMENT_CENTER,
		"speaker icon is centered")
	assert_near(
		float(sound.get_theme_constant("icon_max_width")),
		sound.size.y * 0.45,
		0.01,
		"speaker icon is forty-five percent of button height"
	)
	var regular_font: Font = load(FONT_PATHS[1]) as Font
	var medium_font: Font = load(FONT_PATHS[2]) as Font
	assert_eq(regular_font.get_font_name(), "Noto Sans KR", "Noto regular family name")
	assert_eq(regular_font.get_font_style_name(), "Regular", "Noto regular style name")
	assert_eq(medium_font.get_font_name(), "Noto Sans KR", "Noto medium family name")
	assert_eq(medium_font.get_font_style_name(), "Medium", "Noto medium style name")
	var license_text: String = FileAccess.get_file_as_string("res://assets/fonts/OFL.txt")
	assert_true(
		license_text.contains(
			"(c) 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'."
		),
		"OFL includes exact Noto Sans KR copyright"
	)
	await _destroy_main(main)
	Config.data.game_mode = original_mode


func test_legacy_fever_label_is_absent_and_time_stays_in_top_badge() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var main: Main = await _create_blitz_main()
	var hud: Hud = main.get_node("UI/Hud") as Hud
	assert_true(not main.has_node("UI/Hud/FeverLabel"), "legacy fever label node removed")
	hud._on_combo_changed(8, 2.0, 8)
	hud._on_fever_changed(true, 2.5)
	var combo_label: Label = main.get_node("UI/Hud/ComboLabel") as Label
	assert_true(combo_label.text.contains("CHAIN 8"), "chain remains in top badge")
	assert_true(combo_label.text.contains("FEVER ×2  2.5s"), "fever time joins top badge")
	assert_true(hud.fever_vignette_max_alpha() <= 0.12, "vignette alpha cap")
	var vignette: ColorRect = main.get_node("UI/Hud/FeverVignette") as ColorRect
	var material: ShaderMaterial = vignette.material as ShaderMaterial
	assert_true(material.shader.code.contains("edge * 0.12"), "shader uses capped edge alpha")

	await _destroy_main(main)
	Config.data.game_mode = original_mode


func test_debug_hud_starts_hidden_and_f1_signal_toggles_it() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var main: Main = await _create_blitz_main()
	var debug_hud: DebugHud = main.get_node("UI") as DebugHud
	assert_true(not debug_hud.is_debug_hud_visible(), "debug HUD defaults hidden")
	InputRouter.debug_toggle_hud.emit()
	assert_true(debug_hud.is_debug_hud_visible(), "F1 signal shows debug HUD")
	InputRouter.debug_toggle_hud.emit()
	assert_true(not debug_hud.is_debug_hud_visible(), "second F1 signal hides debug HUD")

	await _destroy_main(main)
	Config.data.game_mode = original_mode


func test_turn_blocked_label_only_shows_for_blocked_directions() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var main: Main = await _create_turn_main()
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var blocked_label: Label = main.get_node("UI/Hud/BlockedLabel") as Label
	var no_directions: Array[Vector2i] = []
	var left_blocked: Array[Vector2i] = [Vector2i.LEFT]

	hud._on_warning_changed(no_directions)
	assert_true(not blocked_label.visible, "empty blocked directions hide warning")
	hud._on_warning_changed(left_blocked)
	assert_true(blocked_label.visible, "blocked direction shows warning")
	assert_eq(blocked_label.text, "BLOCKED: LEFT", "blocked warning names direction")
	var warning_color: Color = blocked_label.get_theme_color("font_color")
	assert_true(warning_color.r > warning_color.g, "blocked warning uses red warning color")
	hud._on_warning_changed(no_directions)
	assert_true(not blocked_label.visible, "cleared blocked directions hide warning again")

	await _destroy_main(main)
	Config.data.game_mode = original_mode


func test_then_count_is_readable_and_contained_in_lower_preview_shelf() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_ramp: int = Config.data.spawn_count_ramp_turns
	var original_max: int = Config.data.spawn_count_max
	var main: Main = await _create_turn_main()
	var spawner: Spawner = main.get_node("Spawner") as Spawner
	Config.data.spawn_count_ramp_turns = 20
	Config.data.spawn_count_max = 0
	spawner.sync_next_batch_size(101)
	await tree.process_frame
	var next_count: Label = main.get_node("UI/Hud/NextCountLabel") as Label
	var then_count: Label = main.get_node("UI/Hud/ThenCountLabel") as Label
	var then_region: Control = main.get_node("UI/Hud/ThenPreviewRegion") as Control
	var preview_shelf: PanelContainer = main.get_node("UI/Hud/PreviewShelf") as PanelContainer
	assert_true(then_count.visible, "THEN count is visible for six orbs")
	assert_eq(next_count.text, "×6", "NEXT count follows selected ramp")
	assert_eq(then_count.text, "×6", "THEN count follows selected ramp")
	assert_true(
		then_count.get_theme_font_size("font_size")
		>= ceili(float(next_count.get_theme_font_size("font_size")) * 0.8),
		"THEN count font is at least 80 percent of NEXT"
	)
	assert_true(
		preview_shelf.get_global_rect().encloses(then_region.get_global_rect()),
		"THEN region stays inside the lower preview shelf"
	)
	assert_true(
		then_count.get_global_rect().end.y <= then_region.get_global_rect().position.y - 4.0,
		"THEN count stays at least four logical pixels above orb region"
	)
	await _destroy_main(main)
	Config.data.game_mode = original_mode
	Config.data.spawn_count_ramp_turns = original_ramp
	Config.data.spawn_count_max = original_max


func _assert_regions_do_not_overlap(regions: Dictionary, output_label: String) -> void:
	var names: Array = regions.keys()
	for first_index: int in range(names.size()):
		for second_index: int in range(first_index + 1, names.size()):
			var first_name: String = str(names[first_index])
			var second_name: String = str(names[second_index])
			var first_control: Control = regions[first_name] as Control
			var second_control: Control = regions[second_name] as Control
			if not first_control.visible or not second_control.visible:
				continue
			var first_rect: Rect2 = first_control.get_global_rect()
			var second_rect: Rect2 = second_control.get_global_rect()
			assert_true(
				not first_rect.intersects(second_rect),
				"%s %s %s do not overlap (%s / %s)" % [
					output_label,
					first_name,
					second_name,
					str(first_rect),
					str(second_rect),
				]
			)


func _assert_layout_rects_do_not_overlap(
	layout: Dictionary,
	region_names: Array[String],
	output_size: Vector2
) -> void:
	for first_index: int in range(region_names.size()):
		for second_index: int in range(first_index + 1, region_names.size()):
			var first_name: String = region_names[first_index]
			var second_name: String = region_names[second_index]
			var first_rect: Rect2 = layout[first_name] as Rect2
			var second_rect: Rect2 = layout[second_name] as Rect2
			assert_true(
				not first_rect.intersects(second_rect),
				"%dx%d %s %s do not overlap (%s / %s)" % [
					roundi(output_size.x),
					roundi(output_size.y),
					first_name,
					second_name,
					str(first_rect),
					str(second_rect),
				]
			)


func _create_blitz_main() -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.BLITZ)
	(main.get_node("ScoreManager") as ScoreManager).save_path = ""
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	(main.get_node("TurnManager") as TurnManager).set_physics_process(false)
	(main.get_node("BlitzManager") as BlitzManager).set_physics_process(false)
	return main


func _create_turn_main() -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.TURN)
	(main.get_node("ScoreManager") as ScoreManager).save_path = ""
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	(main.get_node("TurnManager") as TurnManager).set_physics_process(false)
	(main.get_node("BlitzManager") as BlitzManager).set_physics_process(false)
	return main


func _create_3d_main_in_viewport(viewport_size: Vector2) -> Dictionary:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(roundi(viewport_size.x), roundi(viewport_size.y))
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var main: Main = MAIN_3D_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.TURN)
	(main.get_node("ScoreManager") as ScoreManager).save_path = ""
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = ""
	viewport.add_child(main)
	await tree.process_frame
	await tree.process_frame
	(main.get_node("TurnManager") as TurnManager).set_physics_process(false)
	(main.get_node("BlitzManager") as BlitzManager).set_physics_process(false)
	return {"viewport": viewport, "main": main}


func _project_board_outer_rect(camera: Camera3D, board: Board3D) -> Rect2:
	var outer_half_m: float = (
		board.half_size() / Board3D.PIXELS_PER_METER
		+ Board3D.OUTER_GLOW_WIDTH_M * 0.5
	)
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	var corners: Array[Vector2] = [
		Vector2(-outer_half_m, -outer_half_m),
		Vector2(outer_half_m, -outer_half_m),
		Vector2(outer_half_m, outer_half_m),
		Vector2(-outer_half_m, outer_half_m),
	]
	for corner: Vector2 in corners:
		var projected: Vector2 = camera.unproject_position(
			board.to_global(Vector3(corner.x, corner.y, 0.0))
		)
		minimum = minimum.min(projected)
		maximum = maximum.max(projected)
	return Rect2(minimum, maximum - minimum)


func _destroy_3d_setup(setup: Dictionary) -> void:
	var viewport: SubViewport = setup["viewport"] as SubViewport
	viewport.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)


func _destroy_main(main: Main) -> void:
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
