class_name Hud
extends Control

const MAX_PREVIEW_COUNT: int = 5
const PREVIEW_REGION_SIZE: Vector2 = Vector2(280.0, 150.0)
const PREVIEW_GAP: float = 16.0
const DANGER_REFRESH_INTERVAL: float = 0.25
const SCORE_ROLL_DURATION: float = 0.25
const BADGE_PUNCH_DURATION: float = 0.15
const POPUP_MERGE_DISTANCE: float = 40.0
const GOLD_COLOR: Color = Color("#FFD54A")

@onready var _next_preview: Node2D = %NextPreview
@onready var _then_preview: Node2D = %ThenPreview
@onready var _then_label: Label = %ThenLabel
@onready var _next_count_label: Label = %NextCountLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _best_label: Label = %BestLabel
@onready var _max_combo_label: Label = %MaxComboLabel
@onready var _multiplier_label: Label = %MultiplierLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _danger_label: Label = %DangerLabel
@onready var _score_popup_layer: Control = %ScorePopupLayer
@onready var _blocked_label: Label = %BlockedLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _fever_label: Label = %FeverLabel
@onready var _bonus_label: Label = %BonusLabel
@onready var _game_over_panel: GameOverPanel = %GameOverPanel
@onready var _sound_button: Button = %HudSoundButton

var _spawner: Spawner
var _score_manager: ScoreManager
var _bonus_tween: Tween
var _blitz_mode: bool = false
var _sfx_bank: SfxBank
var _board: Variant
var _active_popups: Array[ScorePopup] = []
var _popup_pool: Array[ScorePopup] = []
var _score_tween: Tween
var _score_punch_tween: Tween
var _badge_punch_tween: Tween
var _displayed_score: int = 0
var _score_target: int = 0
var _current_multiplier: float = 1.0
var _danger_multiplier: float = 1.0
var _danger_refresh_elapsed: float = 0.0
var _pulse_elapsed: float = 0.0
var _badge_punching: bool = false


func _ready() -> void:
	_sound_button.pressed.connect(_on_sound_pressed)
	set_process(true)


func _process(delta: float) -> void:
	_danger_refresh_elapsed += delta
	_pulse_elapsed += delta
	if _board != null and _danger_refresh_elapsed >= DANGER_REFRESH_INTERVAL:
		_danger_refresh_elapsed = fmod(_danger_refresh_elapsed, DANGER_REFRESH_INTERVAL)
		_refresh_danger_badge()
	if not Config.data.fx_score_popups_enabled:
		_multiplier_label.scale = Vector2.ONE
		_combo_label.scale = Vector2.ONE
		_danger_label.scale = Vector2.ONE
		return
	if not _badge_punching and _current_multiplier >= 8.0:
		var multiplier_pulse: float = 1.0 + 0.03 * sin(_pulse_elapsed * TAU * 2.0)
		_multiplier_label.scale = Vector2.ONE * multiplier_pulse
		_combo_label.scale = Vector2.ONE * multiplier_pulse
	elif not _badge_punching:
		_multiplier_label.scale = Vector2.ONE
		_combo_label.scale = Vector2.ONE
	if _danger_label.visible:
		var danger_pulse: float = 1.0 + 0.04 * sin(
			_pulse_elapsed * TAU * maxf(_danger_multiplier, 1.0)
		)
		_danger_label.scale = Vector2.ONE * danger_pulse
	else:
		_danger_label.scale = Vector2.ONE


func bind_sfx_bank(sfx_bank: SfxBank) -> void:
	_sfx_bank = sfx_bank
	if not _sfx_bank.mute_changed.is_connected(_on_mute_changed):
		_sfx_bank.mute_changed.connect(_on_mute_changed)
	_on_mute_changed(_sfx_bank.is_muted())


func bind_spawner(spawner: Spawner) -> void:
	_spawner = spawner
	_spawner.preview_changed.connect(_on_preview_changed)
	_on_preview_changed(_spawner.peek_preview())


func bind_score_manager(score_manager: ScoreManager) -> void:
	_score_manager = score_manager
	_score_manager.score_changed.connect(_on_score_changed)
	_score_manager.reaction_scored.connect(_on_reaction_scored)
	_on_score_changed(_score_manager.score, _score_manager.best_score)


func bind_game_state(
	game_manager: Variant,
	board: Variant,
	score_manager: ScoreManager
) -> void:
	_board = board
	game_manager.warning_changed.connect(_on_warning_changed)
	game_manager.combo_changed.connect(_on_combo_changed)
	_game_over_panel.bind(game_manager, score_manager)
	_blitz_mode = game_manager is BlitzManager
	_on_warning_changed(game_manager.blocked_directions)
	_on_combo_changed(
		game_manager.turn_combo,
		game_manager.current_combo_multiplier(),
		game_manager.max_combo
	)
	board.set_warning_directions(game_manager.blocked_directions)
	_timer_label.visible = _blitz_mode
	_fever_label.visible = false
	_bonus_label.visible = false
	_blocked_label.visible = not _blitz_mode
	if _blitz_mode:
		game_manager.time_changed.connect(_on_time_changed)
		game_manager.ready_changed.connect(_on_ready_changed)
		game_manager.fever_changed.connect(_on_fever_changed)
		game_manager.time_bonus_awarded.connect(_on_time_bonus_awarded)
		_on_time_changed(game_manager.remaining_time)
		if game_manager.state == BlitzManager.State.READY:
			_on_ready_changed(true, game_manager.ready_remaining)
	_refresh_danger_badge()


func _on_preview_changed(batches: Array) -> void:
	var next_batch: Array = batches[0] if not batches.is_empty() else []
	_render_preview(_next_preview, next_batch)
	_next_count_label.visible = next_batch.size() > MAX_PREVIEW_COUNT
	_next_count_label.text = "×%d" % next_batch.size()
	var has_then: bool = batches.size() > 1
	_then_label.visible = has_then
	_then_preview.visible = has_then
	var then_batch: Array = batches[1] if has_then else []
	_render_preview(_then_preview, then_batch)


func _render_preview(preview_root: Node2D, batch: Array) -> void:
	for child: Node in preview_root.get_children():
		preview_root.remove_child(child)
		child.queue_free()

	var preview_count: int = mini(batch.size(), MAX_PREVIEW_COUNT)
	if preview_count == 0:
		return

	var radii: Array[float] = []
	var natural_width: float = 0.0
	var natural_height: float = 0.0
	for index: int in range(preview_count):
		var candidate: Dictionary = batch[index] as Dictionary
		var level: int = int(candidate["level"])
		var radius: float = Config.data.radius_for_level(level)
		radii.append(radius)
		natural_width += radius * 2.0
		natural_height = maxf(natural_height, radius * 2.0)
	if preview_count > 1:
		natural_width += PREVIEW_GAP * float(preview_count - 1)

	var preview_scale: float = minf(
		1.0,
		minf(
			PREVIEW_REGION_SIZE.x / natural_width,
			PREVIEW_REGION_SIZE.y / natural_height
		)
	)
	var cursor_x: float = -natural_width * preview_scale * 0.5
	for index: int in range(preview_count):
		var candidate: Dictionary = batch[index] as Dictionary
		var radius: float = radii[index]
		var visual: OrbVisual = OrbVisual.new()
		preview_root.add_child(visual)
		visual.setup(
			Config.data.color_display[int(candidate["color"])],
			radius,
			int(candidate["color"]),
			Config.data.orb_symbols_enabled
		)
		visual.scale = Vector2.ONE * preview_scale
		visual.position = Vector2(
			cursor_x + radius * preview_scale,
			0.0
		)
		cursor_x += (radius * 2.0 + PREVIEW_GAP) * preview_scale


func _on_score_changed(score: int, best: int) -> void:
	_best_label.text = "BEST\n%d" % best
	var gained: int = score - _score_target
	_score_target = score
	if (
		not Config.data.fx_score_popups_enabled
		or score <= _displayed_score
		or not is_inside_tree()
	):
		if _score_tween != null and _score_tween.is_valid():
			_score_tween.kill()
		_displayed_score = score
		_set_displayed_score(score)
	else:
		if _score_tween != null and _score_tween.is_valid():
			_score_tween.kill()
		_score_tween = create_tween()
		_score_tween.tween_method(
			_set_displayed_score,
			_displayed_score,
			score,
			SCORE_ROLL_DURATION
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if gained >= 1000 and Config.data.fx_score_popups_enabled:
		_punch_score_label()


func _set_displayed_score(value: int) -> void:
	_displayed_score = value
	_score_label.text = "SCORE\n%d" % value


func _on_combo_changed(combo: int, multiplier: float, max_combo: int) -> void:
	_max_combo_label.text = "%s %d" % [
		"MAX CHAIN" if _blitz_mode else "MAX COMBO",
		max_combo,
	]
	var previous_multiplier: float = _current_multiplier
	_current_multiplier = multiplier
	_multiplier_label.visible = combo > 0
	_combo_label.visible = combo > 0
	if combo <= 0:
		_multiplier_label.scale = Vector2.ONE
		_combo_label.scale = Vector2.ONE
		return
	_multiplier_label.text = "×%s" % _format_multiplier(multiplier)
	_multiplier_label.add_theme_color_override("font_color", multiplier_stage_color(multiplier))
	_combo_label.add_theme_color_override("font_color", multiplier_stage_color(multiplier))
	_combo_label.text = "%s %d" % [
		"CHAIN" if _blitz_mode else "COMBO",
		combo,
	]
	if multiplier > previous_multiplier and Config.data.fx_score_popups_enabled:
		_punch_multiplier_badge()


func _on_reaction_scored(reaction: Dictionary) -> void:
	var occupancy: float = float(reaction.get("occupancy", 0.0))
	_set_danger_badge(
		occupancy,
		float(reaction.get(
			"danger_multiplier",
			ScoreManager.danger_multiplier_for(occupancy, Config.data)
		))
	)
	if not Config.data.fx_score_popups_enabled:
		return
	_show_score_popup(reaction)


func _show_score_popup(reaction: Dictionary) -> void:
	var points: int = int(reaction.get("points", 0))
	if points <= 0 or Config.data.fx_popup_max <= 0:
		return
	var screen_position: Vector2 = _reaction_screen_position(
		reaction.get("position", Vector2.ZERO) as Vector2
	)
	var process_frame: int = Engine.get_process_frames()
	for popup: ScorePopup in _active_popups:
		if (
			popup.started_process_frame == process_frame
			and popup.anchor_position.distance_to(screen_position) <= POPUP_MERGE_DISTANCE
		):
			popup.merge_score(points)
			return
	while _active_popups.size() >= Config.data.fx_popup_max:
		_active_popups[0].deactivate()
	var popup: ScorePopup = _acquire_popup()
	var appearance: Dictionary = _popup_appearance(reaction)
	popup.activate(
		screen_position,
		points,
		_popup_formula(reaction),
		appearance["color"] as Color,
		appearance["outline_color"] as Color,
		int(appearance["outline_size"]),
		process_frame
	)
	_active_popups.append(popup)


func _acquire_popup() -> ScorePopup:
	if not _popup_pool.is_empty():
		return _popup_pool.pop_back()
	var popup: ScorePopup = ScorePopup.new()
	popup.name = "ScorePopup%d" % (_active_popups.size() + _popup_pool.size())
	popup.finished.connect(_on_score_popup_finished)
	_score_popup_layer.add_child(popup)
	return popup


func _on_score_popup_finished(popup: ScorePopup) -> void:
	_active_popups.erase(popup)
	if not _popup_pool.has(popup):
		_popup_pool.append(popup)


func _popup_formula(reaction: Dictionary) -> String:
	var combo_multiplier: float = float(reaction.get("combo_multiplier", 1.0))
	var danger_multiplier: float = float(reaction.get("danger_multiplier", 1.0))
	if combo_multiplier < 4.0 and danger_multiplier < 2.0:
		return ""
	var factors: Array[String] = [str(int(reaction.get("base_points", 0)))]
	if combo_multiplier > 1.0:
		factors.append("×%s" % _format_multiplier(combo_multiplier))
	if danger_multiplier > 1.0:
		factors.append("×%s" % _format_multiplier(danger_multiplier))
	var fever_multiplier: float = float(reaction.get("fever_multiplier", 1.0))
	if fever_multiplier > 1.0:
		factors.append("×%s" % _format_multiplier(fever_multiplier))
	return " ".join(factors)


func _popup_appearance(reaction: Dictionary) -> Dictionary:
	if bool(reaction.get("finale", false)):
		return {"color": GOLD_COLOR, "outline_color": GOLD_COLOR, "outline_size": 0}
	var reaction_type: ReactionRules.Type = reaction.get(
		"type", ReactionRules.Type.NONE
	) as ReactionRules.Type
	if reaction_type in [ReactionRules.Type.BLAST, ReactionRules.Type.MAX_CLEAR]:
		return {"color": Color.WHITE, "outline_color": GOLD_COLOR, "outline_size": 6}
	if reaction_type == ReactionRules.Type.MERGE:
		var color_index: int = clampi(
			int(reaction.get("result_color", OrbTypes.OrbColor.RED)),
			0,
			Config.data.color_display.size() - 1
		)
		var base_color: Color = Config.data.color_display[color_index]
		var bright_color: Color = Color.from_hsv(
			base_color.h, base_color.s, 1.0, base_color.a
		)
		return {"color": bright_color, "outline_color": Color.BLACK, "outline_size": 3}
	return {"color": Color.WHITE, "outline_color": Color.BLACK, "outline_size": 3}


func _reaction_screen_position(local_position: Vector2) -> Vector2:
	if _board is Node3D:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			var world_position: Vector3 = (_board as Node3D).to_global(
				Orb3D.plane_position_to_world(local_position)
			)
			return camera.unproject_position(world_position)
	elif _board is Node2D:
		return (_board as Node2D).get_global_transform_with_canvas() * local_position
	return get_viewport_rect().size * 0.5


func _refresh_danger_badge() -> void:
	var occupancy: float = _board_occupancy()
	_set_danger_badge(
		occupancy,
		ScoreManager.danger_multiplier_for(occupancy, Config.data)
	)


func _board_occupancy() -> float:
	if _board == null or not _board.has_method("get_orbs"):
		return 0.0
	var occupied_area: float = 0.0
	var orbs: Array = _board.call("get_orbs") as Array
	for orb: Variant in orbs:
		if is_instance_valid(orb):
			var radius: float = Config.data.radius_for_level(int(orb.level))
			occupied_area += PI * radius * radius
	return occupied_area / (Config.data.board_size * Config.data.board_size)


func _set_danger_badge(occupancy: float, multiplier: float) -> void:
	_danger_multiplier = multiplier
	_danger_label.visible = occupancy >= Config.data.danger_start
	if _danger_label.visible:
		_danger_label.text = "DANGER ×%s" % _format_multiplier(multiplier)


func _punch_multiplier_badge() -> void:
	if _badge_punch_tween != null and _badge_punch_tween.is_valid():
		_badge_punch_tween.kill()
	_badge_punching = true
	_multiplier_label.scale = Vector2.ONE
	_combo_label.scale = Vector2.ONE
	_badge_punch_tween = create_tween()
	_badge_punch_tween.set_parallel(true)
	_badge_punch_tween.tween_property(
		_multiplier_label, "scale", Vector2.ONE * 1.35, BADGE_PUNCH_DURATION * 0.5
	)
	_badge_punch_tween.tween_property(
		_combo_label, "scale", Vector2.ONE * 1.35, BADGE_PUNCH_DURATION * 0.5
	)
	_badge_punch_tween.chain().set_parallel(true)
	_badge_punch_tween.tween_property(
		_multiplier_label, "scale", Vector2.ONE, BADGE_PUNCH_DURATION * 0.5
	)
	_badge_punch_tween.tween_property(
		_combo_label, "scale", Vector2.ONE, BADGE_PUNCH_DURATION * 0.5
	)
	_badge_punch_tween.chain().tween_callback(func() -> void: _badge_punching = false)


func _punch_score_label() -> void:
	if _score_punch_tween != null and _score_punch_tween.is_valid():
		_score_punch_tween.kill()
	_score_label.pivot_offset = _score_label.size * 0.5
	_score_label.scale = Vector2.ONE
	_score_punch_tween = create_tween()
	_score_punch_tween.tween_property(
		_score_label, "scale", Vector2.ONE * 1.15, BADGE_PUNCH_DURATION * 0.5
	)
	_score_punch_tween.tween_property(
		_score_label, "scale", Vector2.ONE, BADGE_PUNCH_DURATION * 0.5
	)


func active_score_popup_count() -> int:
	return _active_popups.size()


func active_score_popups() -> Array[ScorePopup]:
	return _active_popups.duplicate()


static func multiplier_stage_color(multiplier: float) -> Color:
	if multiplier >= 8.0:
		return Color.RED
	if multiplier >= 4.0:
		return Color.ORANGE
	if multiplier >= 2.0:
		return Color.YELLOW
	return Color.WHITE


func _format_multiplier(multiplier: float) -> String:
	if is_equal_approx(multiplier, float(roundi(multiplier))):
		return str(roundi(multiplier))
	return "%.2f" % multiplier


func _on_warning_changed(directions: Array[Vector2i]) -> void:
	var names: Array[String] = []
	for direction: Vector2i in directions:
		names.append(OrbTypes.dir_name(direction))
	_blocked_label.text = (
		"BLOCKED: NONE"
		if names.is_empty()
		else "BLOCKED: %s" % ", ".join(names)
	)


func _on_time_changed(remaining: float) -> void:
	_timer_label.text = "%.1f" % maxf(remaining, 0.0)
	_timer_label.modulate = Color("#FF3B30") if remaining <= 10.0 else Color.WHITE


func _on_ready_changed(active: bool, remaining: float) -> void:
	if active:
		_timer_label.text = "READY %.1f" % remaining
		_timer_label.modulate = Color.WHITE


func _on_fever_changed(active: bool, remaining: float) -> void:
	_fever_label.visible = active
	_fever_label.text = "FEVER x%.0f  %.1fs" % [
		Config.data.blitz_fever_multiplier,
		remaining,
	]


func _on_time_bonus_awarded(seconds: float, source: String) -> void:
	if _bonus_tween != null and _bonus_tween.is_valid():
		_bonus_tween.kill()
	_bonus_label.visible = true
	_bonus_label.modulate = Color.WHITE
	_bonus_label.text = "+%gs  %s" % [seconds, source]
	_bonus_tween = create_tween()
	_bonus_tween.tween_interval(0.7)
	_bonus_tween.tween_property(_bonus_label, "modulate:a", 0.0, 0.3)
	_bonus_tween.tween_callback(func() -> void: _bonus_label.visible = false)


func _on_sound_pressed() -> void:
	if _sfx_bank != null:
		_sfx_bank.toggle_mute()


func _on_mute_changed(muted: bool) -> void:
	_sound_button.text = "🔇" if muted else "🔊"
	_sound_button.tooltip_text = "소리 켜기" if muted else "소리 끄기"
