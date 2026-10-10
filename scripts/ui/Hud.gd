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
const CALLOUT_POP_DURATION: float = 0.12
const CALLOUT_TOTAL_DURATION: float = 0.80
const FEVER_ENTRY_DURATION: float = 0.30
const FEVER_BAND_HOLD_DURATION: float = 0.50
const FEVER_EXIT_DURATION: float = 0.30
const FEVER_VIGNETTE_MAX_ALPHA: float = 0.12
const TIME_BONUS_TRAVEL_DURATION: float = 0.50
const TURN_CALLOUT_STEPS: Array[int] = [3, 5, 8, 12]
const BLITZ_CALLOUT_STEPS: Array[int] = [5, 10, 15, 20, 30]
const CALLOUT_WORDS: Array[String] = [
	"NICE!", "GREAT!", "AMAZING!", "INCREDIBLE!", "UNSTOPPABLE!"
]
const TIMER_NORMAL_COLOR: Color = Color.WHITE
const TIMER_DANGER_COLOR: Color = Color("#FF3B30")
const TIMER_BONUS_COLOR: Color = Color("#30D158")

@onready var _next_preview: Node2D = %NextPreview
@onready var _then_preview: Node2D = %ThenPreview
@onready var _then_label: Label = %ThenLabel
@onready var _next_count_label: Label = %NextCountLabel
@onready var _then_count_label: Label = %ThenCountLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _best_label: Label = %BestLabel
@onready var _max_combo_label: Label = %MaxComboLabel
@onready var _multiplier_label: Label = %MultiplierLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _danger_label: Label = %DangerLabel
@onready var _score_popup_layer: Control = %ScorePopupLayer
@onready var _fever_vignette: ColorRect = %FeverVignette
@onready var _fever_band: ColorRect = %FeverBand
@onready var _fever_band_label: Label = %FeverBandLabel
@onready var _callout_label: Label = %CalloutLabel
@onready var _time_up_label: Label = %TimeUpLabel
@onready var _blocked_label: Label = %BlockedLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _bonus_label: Label = %BonusLabel
@onready var _game_over_panel: GameOverPanel = %GameOverPanel
@onready var _sound_button: Button = %HudSoundButton

var _spawner: Spawner
var _score_manager: ScoreManager
var _bonus_tween: Tween
var _callout_tween: Tween
var _fever_tween: Tween
var _timer_punch_tween: Tween
var _timer_flash_tween: Tween
var _time_up_tween: Tween
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
var _fever_active: bool = false
var _fever_remaining: float = 0.0
var _fever_band_base_position: Vector2 = Vector2.ZERO
var _current_combo: int = 0
var _previous_time_remaining: float = -1.0
var _timer_flashing: bool = false
var _callout_seen: Dictionary = {}
var _callout_history: Array[int] = []
var _timer_tick_history: Array[int] = []
var _urgent_timer_tick_history: Array[int] = []
var _timer_tick_seen: Dictionary = {}
var _pending_time_bonuses: Array[Dictionary] = []
var _last_bonus_target: Vector2 = Vector2.ZERO
var _time_up_count: int = 0


func _ready() -> void:
	_sound_button.pressed.connect(_on_sound_pressed)
	_fever_band_base_position = _fever_band.position
	_configure_fever_vignette()
	set_process(true)


func _process(delta: float) -> void:
	_danger_refresh_elapsed += delta
	_pulse_elapsed += delta
	_update_fever_pulse()
	if not Config.data.fx_callouts_enabled:
		_hide_callout_visuals()
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
	_reset_callout_tracking()
	_blitz_mode = game_manager is BlitzManager
	game_manager.warning_changed.connect(_on_warning_changed)
	game_manager.combo_changed.connect(_on_combo_changed)
	_game_over_panel.bind(game_manager, score_manager)
	_on_warning_changed(game_manager.blocked_directions)
	_on_combo_changed(
		game_manager.turn_combo,
		game_manager.current_combo_multiplier(),
		game_manager.max_combo
	)
	board.set_warning_directions(game_manager.blocked_directions)
	_timer_label.visible = _blitz_mode
	_bonus_label.visible = false
	if _blitz_mode:
		game_manager.time_changed.connect(_on_time_changed)
		game_manager.ready_changed.connect(_on_ready_changed)
		game_manager.fever_changed.connect(_on_fever_changed)
		game_manager.time_bonus_awarded.connect(_on_time_bonus_awarded)
		game_manager.finale_started.connect(_on_finale_started)
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
	_then_count_label.visible = has_then and then_batch.size() > MAX_PREVIEW_COUNT
	_then_count_label.text = "×%d" % then_batch.size()


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
	_current_combo = combo
	_current_multiplier = multiplier
	_update_callout(combo)
	_refresh_combo_badge()
	if combo <= 0:
		_multiplier_label.scale = Vector2.ONE
		_combo_label.scale = Vector2.ONE
		return
	_multiplier_label.text = "×%s" % _format_multiplier(multiplier)
	_multiplier_label.add_theme_color_override("font_color", multiplier_stage_color(multiplier))
	_combo_label.add_theme_color_override("font_color", multiplier_stage_color(multiplier))
	if multiplier > previous_multiplier and Config.data.fx_score_popups_enabled:
		_punch_multiplier_badge()


func _refresh_combo_badge() -> void:
	_multiplier_label.visible = _current_combo > 0
	_combo_label.visible = _current_combo > 0 or (_blitz_mode and _fever_active)
	if not _combo_label.visible:
		return
	var combo_text: String = (
		"%s %d" % ["CHAIN" if _blitz_mode else "COMBO", _current_combo]
		if _current_combo > 0
		else ""
	)
	if _blitz_mode and _fever_active:
		var fever_text: String = "FEVER ×%s  %.1fs" % [
			_format_multiplier(Config.data.blitz_fever_multiplier),
			_fever_remaining,
		]
		combo_text = (
			"%s  ·  %s" % [combo_text, fever_text]
			if not combo_text.is_empty()
			else fever_text
		)
	_combo_label.text = combo_text


func _on_reaction_scored(reaction: Dictionary) -> void:
	_play_pending_time_bonus(reaction)
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
	_badge_punch_tween = create_tween()
	_badge_punch_tween.tween_property(
		_multiplier_label, "scale", Vector2.ONE * 1.35, BADGE_PUNCH_DURATION * 0.5
	)
	_badge_punch_tween.tween_property(
		_multiplier_label, "scale", Vector2.ONE, BADGE_PUNCH_DURATION * 0.5
	)
	_badge_punch_tween.tween_callback(func() -> void: _badge_punching = false)


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
	_blocked_label.visible = not _blitz_mode and not names.is_empty()
	_blocked_label.text = "" if names.is_empty() else "BLOCKED: %s" % ", ".join(names)


func _on_time_changed(remaining: float) -> void:
	var clamped_remaining: float = maxf(remaining, 0.0)
	_timer_label.text = "%.1f" % clamped_remaining
	if not _timer_flashing:
		_timer_label.modulate = _timer_color_for(clamped_remaining)
	_record_timer_ticks(_previous_time_remaining, clamped_remaining)
	_previous_time_remaining = clamped_remaining


func _on_ready_changed(active: bool, remaining: float) -> void:
	if active:
		_timer_label.text = "READY %.1f" % remaining
		if not _timer_flashing:
			_timer_label.modulate = TIMER_NORMAL_COLOR


func _on_fever_changed(active: bool, remaining: float) -> void:
	var was_active: bool = _fever_active
	_fever_active = active
	_fever_remaining = maxf(remaining, 0.0)
	_refresh_combo_badge()
	if active:
		if not was_active:
			if Config.data.fx_callouts_enabled:
				_start_fever_presentation()
		return
	if not was_active:
		return
	if Config.data.fx_callouts_enabled:
		_end_fever_presentation()
	else:
		_hide_fever_visuals()


func _on_time_bonus_awarded(seconds: float, source: String) -> void:
	if not Config.data.fx_callouts_enabled:
		return
	_pending_time_bonuses.append({"seconds": seconds, "source": source})


func _on_finale_started() -> void:
	if not Config.data.fx_callouts_enabled:
		return
	_time_up_count += 1
	if _sfx_bank != null:
		_sfx_bank.play_time_up_buzzer()
	if _time_up_tween != null and _time_up_tween.is_valid():
		_time_up_tween.kill()
	_time_up_label.visible = true
	_time_up_label.modulate = Color.WHITE
	_time_up_label.scale = Vector2.ONE * 0.60
	_time_up_tween = create_tween()
	_time_up_tween.tween_property(
		_time_up_label, "scale", Vector2.ONE * 1.15, CALLOUT_POP_DURATION
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_time_up_tween.tween_property(_time_up_label, "scale", Vector2.ONE, 0.10)
	_time_up_tween.tween_interval(0.48)
	_time_up_tween.tween_property(_time_up_label, "modulate:a", 0.0, 0.25)
	_time_up_tween.tween_callback(_hide_time_up_label)


func _update_callout(combo: int) -> void:
	if combo <= 0:
		_callout_seen.clear()
		return
	if not Config.data.fx_callouts_enabled:
		return
	var steps: Array[int] = BLITZ_CALLOUT_STEPS if _blitz_mode else TURN_CALLOUT_STEPS
	var stage_index: int = steps.find(combo)
	if stage_index < 0 or _callout_seen.has(combo):
		return
	_callout_seen[combo] = true
	_callout_history.append(combo)
	_show_callout(CALLOUT_WORDS[stage_index])
	if _sfx_bank != null:
		_sfx_bank.play_callout_chime(stage_index)


func _show_callout(text: String) -> void:
	if _callout_tween != null and _callout_tween.is_valid():
		_callout_tween.kill()
	_callout_label.text = text
	_callout_label.visible = true
	_callout_label.modulate = Color.WHITE
	_callout_label.scale = Vector2.ONE * 0.60
	_callout_tween = create_tween()
	_callout_tween.tween_property(
		_callout_label, "scale", Vector2.ONE * 1.15, CALLOUT_POP_DURATION
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_callout_tween.tween_property(_callout_label, "scale", Vector2.ONE, 0.10)
	_callout_tween.tween_interval(
		CALLOUT_TOTAL_DURATION - CALLOUT_POP_DURATION - 0.10 - 0.25
	)
	_callout_tween.tween_property(_callout_label, "modulate:a", 0.0, 0.25)
	_callout_tween.tween_callback(_hide_callout_label)


func _start_fever_presentation() -> void:
	if _fever_tween != null and _fever_tween.is_valid():
		_fever_tween.kill()
	var slide_distance: float = get_viewport_rect().size.x
	_fever_band_label.text = "FEVER ×%s" % _format_multiplier(
		Config.data.blitz_fever_multiplier
	)
	_fever_band.position = _fever_band_base_position + Vector2(slide_distance, 0.0)
	_fever_band.modulate = Color.WHITE
	_fever_vignette.modulate = Color.WHITE
	_fever_band.visible = true
	_fever_vignette.visible = true
	_fever_tween = create_tween()
	_fever_tween.tween_property(
		_fever_band, "position", _fever_band_base_position, FEVER_ENTRY_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fever_tween.tween_interval(FEVER_BAND_HOLD_DURATION)
	_fever_tween.tween_property(
		_fever_band, "modulate:a", 0.0, FEVER_EXIT_DURATION
	)
	_fever_tween.tween_callback(_hide_fever_band)
	if _sfx_bank != null:
		_sfx_bank.play_fever_sweep(true)


func _end_fever_presentation() -> void:
	if _fever_tween != null and _fever_tween.is_valid():
		_fever_tween.kill()
	_fever_tween = create_tween()
	_fever_tween.set_parallel(true)
	_fever_tween.tween_property(_fever_band, "modulate:a", 0.0, FEVER_EXIT_DURATION)
	_fever_tween.tween_property(_fever_vignette, "modulate:a", 0.0, FEVER_EXIT_DURATION)
	_fever_tween.chain().tween_callback(_hide_fever_visuals)
	if _sfx_bank != null:
		_sfx_bank.play_fever_sweep(false)


func _update_fever_pulse() -> void:
	if not _fever_active or not Config.data.fx_callouts_enabled:
		return
	var pulse: float = 0.74 + 0.26 * (
		0.5 + 0.5 * sin(_pulse_elapsed * TAU * 2.0)
	)
	_fever_vignette.modulate.a = pulse


func _record_timer_ticks(previous: float, current: float) -> void:
	if (
		not Config.data.fx_callouts_enabled
		or previous < 0.0
		or current >= previous
	):
		return
	for second: int in range(10, 0, -1):
		if previous < float(second) or current >= float(second):
			continue
		if _timer_tick_seen.has(second):
			continue
		_timer_tick_seen[second] = true
		_timer_tick_history.append(second)
		var urgent: bool = second <= 3
		if urgent:
			_urgent_timer_tick_history.append(second)
		_punch_timer(urgent)
		if _sfx_bank != null:
			_sfx_bank.play_timer_tick(urgent)


func _punch_timer(urgent: bool) -> void:
	if _timer_punch_tween != null and _timer_punch_tween.is_valid():
		_timer_punch_tween.kill()
	_timer_label.scale = Vector2.ONE
	_timer_punch_tween = create_tween()
	_timer_punch_tween.tween_property(
		_timer_label,
		"scale",
		Vector2.ONE * (1.32 if urgent else 1.18),
		0.08
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_timer_punch_tween.tween_property(_timer_label, "scale", Vector2.ONE, 0.10)


func _play_pending_time_bonus(reaction: Dictionary) -> void:
	if _pending_time_bonuses.is_empty() or not Config.data.fx_callouts_enabled:
		return
	var reaction_type: ReactionRules.Type = reaction.get(
		"type", ReactionRules.Type.NONE
	) as ReactionRules.Type
	if reaction_type not in [ReactionRules.Type.BLAST, ReactionRules.Type.MAX_CLEAR]:
		return
	var bonus: Dictionary = _pending_time_bonuses.pop_front() as Dictionary
	_show_time_bonus(
		_reaction_screen_position(reaction.get("position", Vector2.ZERO) as Vector2),
		float(bonus["seconds"])
	)


func _show_time_bonus(screen_position: Vector2, seconds: float) -> void:
	if _bonus_tween != null and _bonus_tween.is_valid():
		_bonus_tween.kill()
	_bonus_label.visible = true
	_bonus_label.modulate = Color.WHITE
	_bonus_label.scale = Vector2.ONE
	_bonus_label.text = (
		"+%ds" % roundi(seconds)
		if is_equal_approx(seconds, float(roundi(seconds)))
		else "+%.1fs" % seconds
	)
	_bonus_label.position = screen_position - _bonus_label.size * 0.5
	_last_bonus_target = (
		_timer_label.position
		+ _timer_label.size * 0.5
		- _bonus_label.size * 0.5
	)
	_bonus_tween = create_tween()
	_bonus_tween.tween_property(
		_bonus_label, "position", _last_bonus_target, TIME_BONUS_TRAVEL_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_bonus_tween.parallel().tween_property(
		_bonus_label, "scale", Vector2.ONE * 0.82, TIME_BONUS_TRAVEL_DURATION
	)
	_bonus_tween.tween_callback(_flash_timer_green)
	_bonus_tween.tween_interval(0.10)
	_bonus_tween.tween_property(_bonus_label, "modulate:a", 0.0, 0.20)
	_bonus_tween.tween_callback(_hide_bonus_label)


func _flash_timer_green() -> void:
	if _timer_flash_tween != null and _timer_flash_tween.is_valid():
		_timer_flash_tween.kill()
	_timer_flashing = true
	_timer_label.modulate = TIMER_BONUS_COLOR
	_timer_flash_tween = create_tween()
	_timer_flash_tween.tween_interval(0.12)
	_timer_flash_tween.tween_property(
		_timer_label, "modulate", _timer_color_for(_previous_time_remaining), 0.18
	)
	_timer_flash_tween.tween_callback(_finish_timer_flash)


func _finish_timer_flash() -> void:
	_timer_flashing = false
	_timer_label.modulate = _timer_color_for(_previous_time_remaining)


func _timer_color_for(remaining: float) -> Color:
	return TIMER_DANGER_COLOR if remaining <= 10.0 else TIMER_NORMAL_COLOR


func _configure_fever_vignette() -> void:
	var shader: Shader = Shader.new()
	shader.code = "\n".join([
		"shader_type canvas_item;",
		"render_mode unshaded;",
		"void fragment() {",
		"  vec2 edge_distance = abs(UV - vec2(0.5)) * 2.0;",
		"  float edge = smoothstep(0.70, 1.0, max(edge_distance.x, edge_distance.y));",
		"  float alpha = edge * 0.12;",
		"  COLOR = vec4(1.0, 0.30, 0.015, alpha);",
		"}",
	])
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = shader
	_fever_vignette.material = shader_material


func _reset_callout_tracking() -> void:
	_callout_seen.clear()
	_callout_history.clear()
	_timer_tick_seen.clear()
	_timer_tick_history.clear()
	_urgent_timer_tick_history.clear()
	_pending_time_bonuses.clear()
	_previous_time_remaining = -1.0
	_fever_active = false
	_fever_remaining = 0.0
	_time_up_count = 0
	_hide_callout_visuals()


func _hide_callout_visuals() -> void:
	_callout_label.visible = false
	_time_up_label.visible = false
	_bonus_label.visible = false
	_hide_fever_visuals()


func _hide_callout_label() -> void:
	_callout_label.visible = false
	_callout_label.scale = Vector2.ONE


func _hide_time_up_label() -> void:
	_time_up_label.visible = false
	_time_up_label.scale = Vector2.ONE


func _hide_bonus_label() -> void:
	_bonus_label.visible = false
	_bonus_label.scale = Vector2.ONE


func _hide_fever_visuals() -> void:
	_fever_vignette.visible = false
	_fever_vignette.modulate = Color.WHITE
	_hide_fever_band()


func _hide_fever_band() -> void:
	_fever_band.visible = false
	_fever_band.modulate = Color.WHITE
	_fever_band.position = _fever_band_base_position


func fever_vignette_max_alpha() -> float:
	return FEVER_VIGNETTE_MAX_ALPHA


func callout_history() -> Array[int]:
	return _callout_history.duplicate()


func timer_tick_history() -> Array[int]:
	return _timer_tick_history.duplicate()


func urgent_timer_tick_history() -> Array[int]:
	return _urgent_timer_tick_history.duplicate()


func last_bonus_target() -> Vector2:
	return _last_bonus_target


func timer_bonus_target() -> Vector2:
	return _timer_label.position + _timer_label.size * 0.5 - _bonus_label.size * 0.5


func time_up_count() -> int:
	return _time_up_count


func _on_sound_pressed() -> void:
	if _sfx_bank != null:
		_sfx_bank.toggle_mute()


func _on_mute_changed(muted: bool) -> void:
	_sound_button.text = "🔇" if muted else "🔊"
	_sound_button.tooltip_text = "소리 켜기" if muted else "소리 끄기"
