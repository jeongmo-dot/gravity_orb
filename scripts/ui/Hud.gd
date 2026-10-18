class_name Hud
extends Control

const MAX_PREVIEW_COUNT: int = 5
const PREVIEW_REGION_SIZE: Vector2 = Vector2(480.0, 180.0)
const PREVIEW_GAP: float = 16.0
const DANGER_REFRESH_INTERVAL: float = 0.25
const SCORE_ROLL_DURATION: float = 0.30
const BADGE_PUNCH_DURATION: float = 0.15
const BEST_FLASH_DURATION: float = 0.42
const POPUP_MERGE_DISTANCE: float = 40.0
const GOLD_COLOR: Color = Color("#FFD54A")
const CALLOUT_TOTAL_DURATION: float = 0.80
const CALLOUT_COSMIC_DURATION: float = 1.00
const PLANET_UNLOCK_CALLOUT_DURATION: float = 1.20
const PREVIEW_UNLOCK_FLASH_DURATION: float = 0.60
const PLANET_UNLOCK_ORB_LEVEL: int = 2
const CALLOUT_RISE_DISTANCE: float = 8.0
const FEVER_ENTRY_DURATION: float = 0.30
const FEVER_BAND_HOLD_DURATION: float = 0.50
const FEVER_EXIT_DURATION: float = 0.30
const FEVER_STREAK_DURATION: float = 0.40
const FEVER_VIGNETTE_MAX_ALPHA: float = 0.12
const TIME_BONUS_TRAVEL_DURATION: float = 0.50
const TURN_CALLOUT_STEPS: Array[int] = [3, 5, 8, 12]
const BLITZ_CALLOUT_STEPS: Array[int] = [5, 10, 15, 20, 30]
const CALLOUT_WORDS: Array[String] = [
	"NICE!", "GREAT!", "AMAZING!", "INCREDIBLE!", "UNSTOPPABLE!"
]
const CALLOUT_COLORS: Array[Color] = [
	Color("#BFE9FF"),
	Color("#E8EEFF"),
	Color("#FFB020"),
	Color("#FFD54A"),
	Color("#FFD54A"),
]
const PLANET_NAMES: Dictionary = {
	OrbTypes.OrbColor.PURPLE: "해왕성",
	OrbTypes.OrbColor.CYAN: "수성",
}
const TIMER_NORMAL_COLOR: Color = Color("#E8EEFF")
const TIMER_DANGER_COLOR: Color = Color("#FF3B30")
const TIMER_BONUS_COLOR: Color = Color("#30D158")
const HUD_ACCENT_COLOR: Color = Color("#BFE9FF")
const HUD_AMBER_COLOR: Color = Color("#FFB020")
const HUD_PANEL_COLOR: Color = Color(0.0431373, 0.0941176, 0.2, 0.60)
const SCORE_FONT_MAX: int = 54
const SCORE_FONT_MIN: int = 32
const BEST_FONT_MAX: int = 40
const BEST_FONT_MIN: int = 18
const NUMERIC_SIDE_PADDING: float = 8.0
const HUD_MARGIN: float = 24.0
const PREVIEW_SHELF_HEIGHT: float = 340.0
const TIME_BAR_INSET: float = 4.0
const HUD_THEME: Theme = preload("res://assets/ui/gravity_orb_theme.tres")
const SPEAKER_ON_ICON: Texture2D = preload("res://assets/ui/speaker_on.svg")
const SPEAKER_OFF_ICON: Texture2D = preload("res://assets/ui/speaker_off.svg")

@onready var _next_preview: Node2D = %NextPreview
@onready var _then_preview: Node2D = %ThenPreview
@onready var _next_label: Label = %NextLabel
@onready var _then_label: Label = %ThenLabel
@onready var _next_preview_region: Control = %NextPreviewRegion
@onready var _then_preview_region: Control = %ThenPreviewRegion
@onready var _next_count_label: Label = %NextCountLabel
@onready var _then_count_label: Label = %ThenCountLabel
@onready var _score_title_label: Label = %ScoreTitleLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _best_title_label: Label = %BestTitleLabel
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
@onready var _drain_rate_label: Label = %DrainRateLabel
@onready var _bonus_label: Label = %BonusLabel
@onready var _game_over_panel: GameOverPanel = %GameOverPanel
@onready var _sound_button: Button = %HudSoundButton
@onready var _score_panel: PanelContainer = %ScorePanel
@onready var _best_panel: PanelContainer = %BestPanel
@onready var _danger_panel: PanelContainer = %DangerPanel
@onready var _preview_shelf: PanelContainer = %PreviewShelf
@onready var _blocked_panel: PanelContainer = %BlockedPanel
@onready var _time_bar_track: Panel = %TimeBarTrack
@onready var _time_bar_fill: BlitzTimeBar = %TimeBarFill
@onready var _turn_input_indicator: TurnInputIndicator = %TurnInputIndicator

var _spawner: Spawner
var _score_manager: ScoreManager
var _blitz_manager: BlitzManager
var _bonus_tween: Tween
var _callout_tween: Tween
var _next_preview_flash_tween: Tween
var _then_preview_flash_tween: Tween
var _fever_tween: Tween
var _fever_streak_tween: Tween
var _timer_punch_tween: Tween
var _timer_flash_tween: Tween
var _time_up_tween: Tween
var _blitz_mode: bool = false
var _sfx_bank: SfxBank
var _board: Variant
var _active_popups: Array[ScorePopup] = []
var _popup_pool: Array[ScorePopup] = []
var _next_preview_pool: Array[OrbVisual] = []
var _then_preview_pool: Array[OrbVisual] = []
var _score_tween: Tween
var _score_punch_tween: Tween
var _best_flash_tween: Tween
var _badge_punch_tween: Tween
var _displayed_score: int = 0
var _score_target: int = 0
var _best_target: int = 0
var _best_initialized: bool = false
var _best_flash_count: int = 0
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
var _planet_unlock_seen: Dictionary = {}
var _planet_unlock_history: Array[int] = []
var _pending_planet_unlocks: Array[int] = []
var _preview_unlock_seen: Dictionary = {}
var _preview_unlock_flash_history: Array[int] = []
var _timer_tick_history: Array[int] = []
var _urgent_timer_tick_history: Array[int] = []
var _timer_tick_seen: Dictionary = {}
var _pending_time_bonuses: Array[Dictionary] = []
var _time_bonus_accumulator: float = 0.0
var _time_bonus_window_remaining: float = 0.0
var _time_bonus_segment_start: float = 0.0
var _last_bonus_target: Vector2 = Vector2.ZERO
var _time_up_count: int = 0
var _callout_base_position: Vector2 = Vector2.ZERO
var _planet_callout_visual: OrbVisual
var _planet_callout_base_position: Vector2 = Vector2.ZERO
var _next_preview_flash: ReferenceRect
var _then_preview_flash: ReferenceRect
var _callout_sparkles: Array[CosmicSparkle] = []
var _fever_sparkles: Array[CosmicSparkle] = []
var _fever_streak: ColorRect
var _time_up_ring: CosmicRing2D


func _ready() -> void:
	_create_v4_ui_effects()
	_prewarm_score_popups()
	_sound_button.pressed.connect(_on_sound_pressed)
	_sound_button.text = ""
	_sound_button.icon = SPEAKER_ON_ICON
	_fever_band_base_position = _fever_band.position
	_configure_fever_vignette()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	set_process(true)


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.disconnect(_apply_responsive_layout)
	for tween: Tween in [
		_callout_tween,
		_next_preview_flash_tween,
		_then_preview_flash_tween,
		_fever_tween,
		_fever_streak_tween,
		_time_up_tween,
		_bonus_tween,
		_timer_punch_tween,
		_timer_flash_tween,
	]:
		if tween != null and tween.is_valid():
			tween.kill()
	_stop_sparkles(_callout_sparkles)
	_stop_sparkles(_fever_sparkles)
	if is_instance_valid(_time_up_ring):
		_time_up_ring.stop()
	_free_preview_pool(_next_preview_pool)
	_free_preview_pool(_then_preview_pool)


func _create_v4_ui_effects() -> void:
	_planet_callout_visual = OrbVisual.new()
	_planet_callout_visual.name = "PlanetUnlockVisual"
	_planet_callout_visual.z_index = 31
	_planet_callout_visual.visible = false
	add_child(_planet_callout_visual)
	_next_preview_flash = _create_preview_flash("NextUnlockFlash", _next_preview_region)
	_then_preview_flash = _create_preview_flash("ThenUnlockFlash", _then_preview_region)
	for index: int in range(5):
		var callout_sparkle: CosmicSparkle = CosmicSparkle.new()
		callout_sparkle.name = "CalloutSparkle%d" % index
		callout_sparkle.z_index = 32
		add_child(callout_sparkle)
		_callout_sparkles.append(callout_sparkle)
	for index: int in range(3):
		var fever_sparkle: CosmicSparkle = CosmicSparkle.new()
		fever_sparkle.name = "FeverSparkle%d" % index
		fever_sparkle.z_index = 30
		add_child(fever_sparkle)
		_fever_sparkles.append(fever_sparkle)
	_time_up_ring = CosmicRing2D.new()
	_time_up_ring.name = "TimeUpRing"
	_time_up_ring.z_index = 30
	add_child(_time_up_ring)
	_fever_streak = ColorRect.new()
	_fever_streak.name = "FeverStreak"
	_fever_streak.z_index = 26
	_fever_streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var streak_shader: Shader = Shader.new()
	streak_shader.code = "\n".join([
		"shader_type canvas_item;",
		"render_mode unshaded;",
		"void fragment() {",
		"  float tail = smoothstep(0.0, 0.72, UV.x);",
		"  float head = 1.0 - smoothstep(0.80, 1.0, UV.x);",
		"  float core = sin(UV.y * 3.14159265);",
		"  float alpha = tail * head * core * 0.72;",
		"  COLOR = vec4(1.0, 0.66, 0.18, alpha);",
		"}",
	])
	var streak_material: ShaderMaterial = ShaderMaterial.new()
	streak_material.shader = streak_shader
	_fever_streak.material = streak_material
	_fever_streak.color = Color.WHITE
	add_child(_fever_streak)
	_fever_streak.visible = false


func _create_preview_flash(flash_name: String, region: Control) -> ReferenceRect:
	var flash: ReferenceRect = ReferenceRect.new()
	flash.name = flash_name
	flash.editor_only = false
	flash.border_width = float(_callout_label.get_theme_constant("outline_size"))
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.visible = false
	region.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return flash


func _layout_fever_streak(viewport_size: Vector2) -> void:
	if not is_instance_valid(_fever_streak):
		return
	_fever_streak.size = Vector2(viewport_size.x * 0.72, 12.0)
	_fever_streak.pivot_offset = _fever_streak.size * 0.5
	if not _fever_streak.visible:
		_fever_streak.position = Vector2(
			-_fever_streak.size.x,
			viewport_size.y * 0.5 + 48.0
		)


func _prewarm_score_popups() -> void:
	for index: int in range(maxi(Config.data.fx_popup_max, 0)):
		_popup_pool.append(_create_score_popup(index))


func _create_score_popup(index: int) -> ScorePopup:
	var popup: ScorePopup = ScorePopup.new()
	popup.name = "ScorePopup%d" % index
	popup.finished.connect(_on_score_popup_finished)
	_score_popup_layer.add_child(popup)
	return popup


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var layout: Dictionary = hud_layout(viewport_size, _logical_safe_area(viewport_size))
	_set_control_rect(_score_panel, layout["score_panel"] as Rect2)
	_set_control_rect(_score_title_label, layout["score_title"] as Rect2)
	_set_control_rect(_score_label, layout["score"] as Rect2)
	_set_control_rect(_best_panel, layout["best_panel"] as Rect2)
	_set_control_rect(_best_title_label, layout["best_title"] as Rect2)
	_set_control_rect(_best_label, layout["best"] as Rect2)
	_set_control_rect(_sound_button, layout["sound"] as Rect2)
	_set_control_rect(_danger_panel, layout["danger_panel"] as Rect2)
	_set_control_rect(_danger_label, layout["danger"] as Rect2)
	_set_control_rect(_multiplier_label, layout["multiplier"] as Rect2)
	_set_control_rect(_combo_label, layout["combo"] as Rect2)
	_set_control_rect(_max_combo_label, layout["max_combo"] as Rect2)
	_set_control_rect(_timer_label, layout["timer"] as Rect2)
	_set_control_rect(_drain_rate_label, layout["drain_rate"] as Rect2)
	_set_control_rect(_bonus_label, layout["time_bonus"] as Rect2)
	_set_control_rect(_time_bar_track, layout["time_bar"] as Rect2)
	_layout_time_bar_fill()
	_set_control_rect(_preview_shelf, layout["preview_shelf"] as Rect2)
	_set_control_rect(_blocked_panel, layout["blocked_panel"] as Rect2)
	_set_control_rect(_blocked_label, layout["blocked"] as Rect2)
	_set_control_rect(_next_label, layout["next_label"] as Rect2)
	_set_control_rect(_next_preview_region, layout["next"] as Rect2)
	_set_control_rect(_next_count_label, layout["next_count"] as Rect2)
	_set_control_rect(_then_label, layout["then_label"] as Rect2)
	_set_control_rect(_then_preview_region, layout["then"] as Rect2)
	_set_control_rect(_then_count_label, layout["then_count"] as Rect2)
	_next_preview.position = (layout["next"] as Rect2).get_center() + Vector2(0.0, 8.0)
	_then_preview.position = (layout["then"] as Rect2).get_center() + Vector2(0.0, 8.0)
	var center_y: float = viewport_size.y * 0.5
	_set_control_rect(_fever_band, Rect2(0.0, center_y - 40.0, viewport_size.x, 80.0))
	_fever_band.pivot_offset = _fever_band.size * 0.5
	_fever_band_base_position = _fever_band.position
	_set_control_rect(
		_callout_label,
		Rect2(40.0, center_y - 120.0, viewport_size.x - 80.0, 200.0)
	)
	_callout_base_position = _callout_label.position
	_set_control_rect(
		_time_up_label,
		Rect2(40.0, center_y - 130.0, viewport_size.x - 80.0, 260.0)
	)
	_layout_fever_streak(viewport_size)
	_score_label.pivot_offset = _score_label.size * 0.5
	_best_label.pivot_offset = _best_label.size * 0.5
	_multiplier_label.pivot_offset = _multiplier_label.size * 0.5
	_combo_label.pivot_offset = _combo_label.size * 0.5
	_danger_label.pivot_offset = _danger_label.size * 0.5
	_timer_label.pivot_offset = _timer_label.size * 0.5
	_fit_timer_label_to_text()
	_fit_numeric_label(_score_label, _displayed_score, SCORE_FONT_MAX, SCORE_FONT_MIN)
	_fit_numeric_label(_best_label, _best_target, BEST_FONT_MAX, BEST_FONT_MIN)
	_update_time_bar(_previous_time_remaining if _previous_time_remaining >= 0.0 else 0.0)


func _set_control_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.size = rect.size
	# Some full-width controls grow from both sides. Set the final position after size so
	# their grow direction cannot shift a responsive rect away from its requested origin.
	control.position = rect.position


func _logical_safe_area(viewport_size: Vector2) -> Rect2:
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, viewport_size)
	if not OS.has_feature("mobile"):
		return viewport_rect
	var window_size: Vector2i = DisplayServer.window_get_size()
	var pixel_safe_area: Rect2i = DisplayServer.get_display_safe_area()
	if window_size.x <= 0 or window_size.y <= 0 or pixel_safe_area.size == Vector2i.ZERO:
		return viewport_rect
	var scale: Vector2 = viewport_size / Vector2(window_size)
	var logical_safe_area: Rect2 = Rect2(
		Vector2(pixel_safe_area.position) * scale,
		Vector2(pixel_safe_area.size) * scale
	)
	return logical_safe_area.intersection(viewport_rect)


static func hud_layout(viewport_size: Vector2, safe_area: Rect2 = Rect2()) -> Dictionary:
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, viewport_size)
	var safe: Rect2 = safe_area.intersection(viewport_rect)
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		safe = viewport_rect
	var center_x: float = safe.get_center().x
	var top: float = safe.position.y + HUD_MARGIN
	var bottom: float = safe.end.y - 40.0
	var shelf_top: float = bottom - PREVIEW_SHELF_HEIGHT
	var shelf: Rect2 = Rect2(
		safe.position.x + 40.0,
		shelf_top,
		maxf(safe.size.x - 80.0, 1.0),
		PREVIEW_SHELF_HEIGHT
	)
	var next_width: float = shelf.size.x * 0.55
	var then_x: float = shelf.position.x + shelf.size.x * 0.60
	var then_width: float = shelf.end.x - 30.0 - then_x
	return {
		"safe": safe,
		"score_panel": Rect2(center_x - 240.0, top, 480.0, 150.0),
		"score_title": Rect2(center_x - 224.0, top + 12.0, 448.0, 30.0),
		"score": Rect2(center_x - 224.0, top + 42.0, 448.0, 96.0),
		"best_panel": Rect2(safe.end.x - HUD_MARGIN - 236.0, top, 236.0, 150.0),
		"best_title": Rect2(safe.end.x - HUD_MARGIN - 224.0, top + 12.0, 212.0, 30.0),
		"best": Rect2(safe.end.x - HUD_MARGIN - 224.0, top + 42.0, 212.0, 94.0),
		"sound": Rect2(safe.position.x + HUD_MARGIN, top + 8.0, 120.0, 120.0),
		"danger_panel": Rect2(safe.position.x + HUD_MARGIN, top + 166.0, 256.0, 62.0),
		"danger": Rect2(safe.position.x + HUD_MARGIN + 12.0, top + 172.0, 232.0, 50.0),
		"multiplier": Rect2(center_x - 220.0, top + 160.0, 440.0, 66.0),
		"combo": Rect2(center_x - 220.0, top + 226.0, 440.0, 46.0),
		"max_combo": Rect2(safe.end.x - HUD_MARGIN - 236.0, top + 162.0, 236.0, 46.0),
		"timer": Rect2(center_x - 150.0, top + 292.0, 300.0, 80.0),
		"drain_rate": Rect2(safe.end.x - 88.0, top + 386.0, 72.0, 36.0),
		"time_bonus": Rect2(center_x + 170.0, top + 308.0, 190.0, 50.0),
		"time_bar": Rect2(
			safe.position.x + 96.0,
			top + 396.0,
			maxf(safe.size.x - 192.0, 1.0),
			26.0
		),
		"preview_shelf": shelf,
		"blocked_panel": Rect2(center_x - 210.0, shelf_top + 8.0, 420.0, 56.0),
		"blocked": Rect2(center_x - 198.0, shelf_top + 12.0, 396.0, 48.0),
		"next_label": Rect2(shelf.position.x + 30.0, shelf_top + 76.0, next_width, 40.0),
		"next": Rect2(shelf.position.x + 30.0, shelf_top + 116.0, next_width, 194.0),
		"next_count": Rect2(
			shelf.position.x + next_width - 50.0,
			shelf_top + 72.0,
			80.0,
			40.0
		),
		"then_label": Rect2(then_x, shelf_top + 84.0, then_width, 40.0),
		"then": Rect2(then_x, shelf_top + 124.0, then_width, 176.0),
		"then_count": Rect2(shelf.end.x - 110.0, shelf_top + 80.0, 80.0, 40.0),
	}


func _process(delta: float) -> void:
	_danger_refresh_elapsed += delta
	_pulse_elapsed += delta
	_advance_time_bonus_display(delta)
	_time_bar_fill.advance_bonus(maxf(delta, 0.0) / maxf(Engine.time_scale, 0.001))
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
	_blitz_manager = game_manager as BlitzManager if _blitz_mode else null
	if not _blitz_mode:
		_turn_input_indicator.bind(game_manager, board)
		var turn_manager: TurnManager = game_manager as TurnManager
		if not turn_manager.planet_unlocked.is_connected(_on_planet_unlocked):
			turn_manager.planet_unlocked.connect(_on_planet_unlocked)
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
	_time_bar_track.visible = _blitz_mode
	_time_bar_fill.visible = _blitz_mode
	_drain_rate_label.visible = false
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
	else:
		_update_time_bar(0.0)
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
	_track_preview_unlocks(batches)


func _track_preview_unlocks(batches: Array) -> void:
	if Config.data.game_mode != GameConfig.GameMode.TURN:
		return
	for batch_index: int in range(mini(batches.size(), 2)):
		var batch: Array = batches[batch_index] as Array
		for candidate: Dictionary in batch:
			var color_index: int = int(candidate.get("color", -1))
			if color_index < Config.data.turn_start_colors:
				continue
			if _preview_unlock_seen.has(color_index):
				continue
			_preview_unlock_seen[color_index] = true
			_preview_unlock_flash_history.append(color_index)
			if Config.data.fx_callouts_enabled:
				_flash_preview_slot(batch_index, color_index)
			break


func _flash_preview_slot(batch_index: int, color_index: int) -> void:
	var flash: ReferenceRect = (
		_next_preview_flash if batch_index == 0 else _then_preview_flash
	)
	var active_tween: Tween = (
		_next_preview_flash_tween if batch_index == 0 else _then_preview_flash_tween
	)
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	flash.border_color = Config.data.color_display[color_index]
	flash.modulate = Color.WHITE
	flash.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(
		flash, "modulate:a", 0.0, PREVIEW_UNLOCK_FLASH_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(flash.hide)
	if batch_index == 0:
		_next_preview_flash_tween = tween
	else:
		_then_preview_flash_tween = tween


func _render_preview(preview_root: Node2D, batch: Array) -> void:
	var preview_count: int = mini(batch.size(), MAX_PREVIEW_COUNT)
	while preview_root.get_child_count() > preview_count:
		var visual_to_pool: OrbVisual = preview_root.get_child(
			preview_root.get_child_count() - 1
		) as OrbVisual
		preview_root.remove_child(visual_to_pool)
		visual_to_pool.visible = false
		_preview_pool_for(preview_root).append(visual_to_pool)
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
		2.0,
		minf(
			PREVIEW_REGION_SIZE.x / natural_width,
			PREVIEW_REGION_SIZE.y / natural_height
		)
	)
	var cursor_x: float = -natural_width * preview_scale * 0.5
	for index: int in range(preview_count):
		var candidate: Dictionary = batch[index] as Dictionary
		var radius: float = radii[index]
		var visual: OrbVisual
		if index < preview_root.get_child_count():
			visual = preview_root.get_child(index) as OrbVisual
		else:
			visual = _acquire_preview_visual(preview_root)
			preview_root.add_child(visual)
		visual.visible = true
		var preview_level: int = int(candidate["level"])
		visual.setup_celestial_preview(
			Config.data.color_display[int(candidate["color"])],
			radius,
			preview_level,
			int(candidate["color"]),
			Config.data.orb_symbols_enabled
		)
		visual.set_blast_armed(
			Config.data.blast_enabled
			and preview_level >= Config.data.active_blast_min_level(),
			Config.data.blast_blink_period
		)
		visual.scale = Vector2.ONE * preview_scale
		visual.position = Vector2(
			cursor_x + radius * preview_scale,
			0.0
		)
		cursor_x += (radius * 2.0 + PREVIEW_GAP) * preview_scale


func set_symbols_enabled(enabled: bool) -> void:
	for preview_root: Node2D in [_next_preview, _then_preview]:
		for child: Node in preview_root.get_children():
			var visual: OrbVisual = child as OrbVisual
			if visual != null:
				visual.set_symbols_enabled(enabled)


func _preview_pool_for(preview_root: Node2D) -> Array[OrbVisual]:
	return _next_preview_pool if preview_root == _next_preview else _then_preview_pool


func _acquire_preview_visual(preview_root: Node2D) -> OrbVisual:
	var pool: Array[OrbVisual] = _preview_pool_for(preview_root)
	if not pool.is_empty():
		return pool.pop_back()
	return OrbVisual.new()


func _free_preview_pool(pool: Array[OrbVisual]) -> void:
	for visual: OrbVisual in pool:
		if is_instance_valid(visual):
			visual.free()
	pool.clear()


func _on_score_changed(score: int, best: int) -> void:
	_best_label.text = str(best)
	_fit_numeric_label(_best_label, best, BEST_FONT_MAX, BEST_FONT_MIN)
	if _best_initialized and best > _best_target:
		_flash_best_label()
	_best_target = best
	_best_initialized = true
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
	if (
		(gained >= 1000 or _current_multiplier >= 8.0)
		and Config.data.fx_score_popups_enabled
	):
		_punch_score_label()


func _set_displayed_score(value: int) -> void:
	_displayed_score = value
	_score_label.text = str(value)
	_fit_numeric_label(_score_label, value, SCORE_FONT_MAX, SCORE_FONT_MIN)


func _fit_numeric_label(label: Label, value: int, preferred_size: int, minimum_size: int) -> void:
	var available_width: float = maxf(label.size.x - NUMERIC_SIDE_PADDING * 2.0, 1.0)
	var font: Font = label.get_theme_font(&"font")
	var fitted_size: int = numeric_font_size_for_width(
		value,
		available_width,
		preferred_size,
		minimum_size,
		font
	)
	label.add_theme_font_size_override("font_size", fitted_size)


static func numeric_font_size_for_width(
	value: int,
	available_width: float,
	preferred_size: int,
	minimum_size: int,
	font: Font
) -> int:
	var text: String = str(value)
	for font_size: int in range(preferred_size, minimum_size - 1, -1):
		var text_width: float = font.get_string_size(
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size
		).x
		if text_width <= available_width:
			return font_size
	return minimum_size


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
	screen_position = _clamp_popup_position(screen_position)
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
		process_frame,
		bool(appearance["cosmic"])
	)
	_active_popups.append(popup)


func _acquire_popup() -> ScorePopup:
	if not _popup_pool.is_empty():
		return _popup_pool.pop_back()
	return _create_score_popup(_active_popups.size() + _popup_pool.size())


func _on_score_popup_finished(popup: ScorePopup) -> void:
	_active_popups.erase(popup)
	if not _popup_pool.has(popup):
		_popup_pool.append(popup)


func _popup_formula(reaction: Dictionary) -> String:
	var combo_multiplier: float = float(reaction.get("combo_multiplier", 1.0))
	var danger_multiplier: float = float(reaction.get("danger_multiplier", 1.0))
	if combo_multiplier < 4.0 and danger_multiplier < 2.0:
		return ""
	var factors: Array[String] = [
		ScorePopup.format_number(int(reaction.get("base_points", 0)))
	]
	if combo_multiplier > 1.0:
		factors.append("×%s" % _format_multiplier(combo_multiplier))
	if danger_multiplier > 1.0:
		factors.append("×%s" % _format_multiplier(danger_multiplier))
	var fever_multiplier: float = float(reaction.get("fever_multiplier", 1.0))
	if fever_multiplier > 1.0:
		factors.append("×%s" % _format_multiplier(fever_multiplier))
	return " ".join(factors)


func _popup_appearance(reaction: Dictionary) -> Dictionary:
	var reaction_type: ReactionRules.Type = reaction.get(
		"type", ReactionRules.Type.NONE
	) as ReactionRules.Type
	var cosmic: bool = (
		bool(reaction.get("finale", false))
		or reaction_type in [ReactionRules.Type.BLAST, ReactionRules.Type.MAX_CLEAR]
		or float(reaction.get("combo_multiplier", 1.0)) >= 8.0
	)
	if cosmic:
		return {
			"color": GOLD_COLOR,
			"outline_color": Color(0.05, 0.025, 0.0, 0.92),
			"outline_size": 3,
			"cosmic": true,
		}
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
		return {
			"color": bright_color,
			"outline_color": Color(0.02, 0.03, 0.06, 0.92),
			"outline_size": 3,
			"cosmic": false,
		}
	return {
		"color": Color.WHITE,
		"outline_color": Color(0.02, 0.03, 0.06, 0.92),
		"outline_size": 3,
		"cosmic": false,
	}


func _clamp_popup_position(screen_position: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var layout: Dictionary = hud_layout(viewport_size, _logical_safe_area(viewport_size))
	var half_size: Vector2 = ScorePopup.POPUP_SIZE * 0.5
	var top_hud_end: float = (layout["time_bar"] as Rect2).end.y
	var preview_top: float = (layout["preview_shelf"] as Rect2).position.y
	var minimum_y: float = top_hud_end + half_size.y + ScorePopup.RISE_DISTANCE + 12.0
	var maximum_y: float = preview_top - half_size.y - 12.0
	if maximum_y < minimum_y:
		var fallback_y: float = (top_hud_end + preview_top) * 0.5
		minimum_y = fallback_y
		maximum_y = fallback_y
	return Vector2(
		clampf(screen_position.x, half_size.x, viewport_size.x - half_size.x),
		clampf(screen_position.y, minimum_y, maximum_y)
	)


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
	_danger_panel.visible = _danger_label.visible
	if _danger_label.visible:
		_danger_label.text = "DANGER ×%s" % _format_multiplier(multiplier)
		var danger_color: Color = (
			TIMER_DANGER_COLOR if multiplier >= 4.0 else HUD_AMBER_COLOR
		)
		_danger_label.add_theme_color_override("font_color", danger_color)
		_apply_danger_panel_color(danger_color)
	if _board != null and _board.has_method("set_danger_state"):
		_board.call("set_danger_state", occupancy, multiplier)


func _apply_danger_panel_color(border_color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HUD_PANEL_COLOR
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	_danger_panel.add_theme_stylebox_override("panel", style)


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


func _flash_best_label() -> void:
	if _best_flash_tween != null and _best_flash_tween.is_valid():
		_best_flash_tween.kill()
	_best_flash_count += 1
	_best_label.pivot_offset = _best_label.size * 0.5
	_best_label.scale = Vector2.ONE
	_best_label.modulate = HUD_ACCENT_COLOR
	_best_flash_tween = create_tween()
	_best_flash_tween.set_parallel(true)
	_best_flash_tween.tween_property(
		_best_label,
		"scale",
		Vector2.ONE * 1.10,
		BEST_FLASH_DURATION * 0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_best_flash_tween.tween_property(
		_best_label,
		"modulate",
		Color.WHITE,
		BEST_FLASH_DURATION
	)
	_best_flash_tween.chain().tween_property(
		_best_label,
		"scale",
		Vector2.ONE,
		BEST_FLASH_DURATION * 0.55
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func best_flash_count() -> int:
	return _best_flash_count


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
	var symbols: Array[String] = []
	for direction: Vector2i in directions:
		symbols.append(_direction_symbol(direction))
	_blocked_label.visible = not _blitz_mode and not symbols.is_empty()
	_blocked_panel.visible = _blocked_label.visible
	_blocked_label.text = "" if symbols.is_empty() else "%s 막힘" % " ".join(symbols)


func _direction_symbol(direction: Vector2i) -> String:
	if direction == Vector2i.LEFT:
		return "←"
	if direction == Vector2i.RIGHT:
		return "→"
	if direction == Vector2i.UP:
		return "↑"
	if direction == Vector2i.DOWN:
		return "↓"
	return "?"


func _on_time_changed(remaining: float) -> void:
	var clamped_remaining: float = maxf(remaining, 0.0)
	_timer_label.text = "%.1f" % clamped_remaining
	_fit_timer_label_to_text()
	_update_time_bar(clamped_remaining)
	if not _timer_flashing:
		_timer_label.modulate = _timer_color_for(clamped_remaining)
	_record_timer_ticks(_previous_time_remaining, clamped_remaining)
	_previous_time_remaining = clamped_remaining
	_update_drain_rate_label()


func _on_ready_changed(active: bool, remaining: float) -> void:
	if active:
		_drain_rate_label.visible = false
		_timer_label.text = "READY %.1f" % remaining
		_fit_timer_label_to_text()
		if not _timer_flashing:
			_timer_label.modulate = TIMER_NORMAL_COLOR


func _update_time_bar(remaining: float) -> void:
	if not is_instance_valid(_time_bar_track) or not is_instance_valid(_time_bar_fill):
		return
	_layout_time_bar_fill()
	_time_bar_fill.set_time(remaining, Config.data.blitz_time_bar_reference)
	_update_drain_rate_label()


func _layout_time_bar_fill() -> void:
	if not is_instance_valid(_time_bar_track) or not is_instance_valid(_time_bar_fill):
		return
	_set_control_rect(
		_time_bar_fill,
		Rect2(
			_time_bar_track.position + Vector2(TIME_BAR_INSET, TIME_BAR_INSET),
			Vector2(
				maxf(_time_bar_track.size.x - TIME_BAR_INSET * 2.0, 0.0),
				maxf(_time_bar_track.size.y - TIME_BAR_INSET * 2.0, 0.0)
			)
		)
	)


func _fit_timer_label_to_text() -> void:
	if not is_instance_valid(_timer_label):
		return
	var font: Font = _timer_label.get_theme_font("font")
	var font_size: int = _timer_label.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(
		_timer_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x
	var center_x: float = _timer_label.position.x + _timer_label.size.x * 0.5
	var fitted_width: float = maxf(180.0, ceilf(text_width + NUMERIC_SIDE_PADDING * 4.0))
	_timer_label.size.x = fitted_width
	_timer_label.position.x = center_x - fitted_width * 0.5
	_timer_label.pivot_offset = _timer_label.size * 0.5


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
	if Config.data.blitz_survival_enabled:
		var added_seconds: float = maxf(seconds, 0.0)
		if added_seconds <= 0.0:
			return
		if _time_bonus_window_remaining <= 0.0:
			_time_bonus_segment_start = maxf(_previous_time_remaining - added_seconds, 0.0)
		_time_bonus_accumulator += added_seconds
		_time_bar_fill.show_bonus(
			_time_bonus_segment_start,
			_previous_time_remaining,
			_fever_active
		)
		if _time_bonus_window_remaining <= 0.0:
			_time_bonus_window_remaining = maxf(
				Config.data.blitz_time_bonus_display_window,
				0.0
			)
		if _time_bonus_window_remaining <= 0.0:
			_flush_time_bonus_display()
		return
	_pending_time_bonuses.append({"seconds": seconds, "source": source})


func _advance_time_bonus_display(delta: float) -> void:
	if not Config.data.blitz_survival_enabled or _time_bonus_window_remaining <= 0.0:
		return
	var real_delta: float = maxf(delta, 0.0) / maxf(Engine.time_scale, 0.001)
	_time_bonus_window_remaining = maxf(_time_bonus_window_remaining - real_delta, 0.0)
	if _time_bonus_window_remaining <= 0.0:
		_flush_time_bonus_display()


func _flush_time_bonus_display() -> void:
	var total: float = _time_bonus_accumulator
	_time_bonus_accumulator = 0.0
	_time_bonus_window_remaining = 0.0
	if total < 0.1 or not Config.data.fx_callouts_enabled:
		return
	_show_survival_time_bonus(total)


func _show_survival_time_bonus(seconds: float) -> void:
	if _bonus_tween != null and _bonus_tween.is_valid():
		_bonus_tween.kill()
	_bonus_label.text = "+%.1fs" % seconds
	_bonus_label.visible = true
	_bonus_label.modulate = Color.WHITE
	_bonus_label.scale = Vector2.ONE
	_last_bonus_target = _bonus_label.position
	_flash_timer_green()
	_bonus_tween = create_tween()
	_bonus_tween.tween_interval(0.45)
	_bonus_tween.tween_property(_bonus_label, "modulate:a", 0.0, 0.20)
	_bonus_tween.tween_callback(_hide_bonus_label)


func _update_drain_rate_label() -> void:
	if (
		_blitz_manager == null
		or not Config.data.blitz_survival_enabled
		or _blitz_manager.state != BlitzManager.State.RUNNING
	):
		_drain_rate_label.visible = false
		return
	var layers: int = _time_bar_fill.layer_count()
	if layers >= 2:
		_drain_rate_label.visible = true
		_drain_rate_label.text = "×%d" % layers
		_drain_rate_label.add_theme_color_override(
			"font_color",
			BlitzTimeBar.color_for_layer(layers - 1)
		)
		return
	var multiplier: float = _blitz_manager.current_drain_multiplier()
	_drain_rate_label.visible = multiplier >= 1.1
	if _drain_rate_label.visible:
		_drain_rate_label.text = "×%.1f" % multiplier
		_drain_rate_label.add_theme_color_override("font_color", TIMER_NORMAL_COLOR)


func _on_finale_started() -> void:
	if not Config.data.fx_callouts_enabled:
		return
	_time_up_count += 1
	if _sfx_bank != null:
		_sfx_bank.play_time_up_buzzer()
	if _time_up_tween != null and _time_up_tween.is_valid():
		_time_up_tween.kill()
	_time_up_label.add_theme_color_override("font_color", TIMER_DANGER_COLOR)
	_time_up_label.add_theme_color_override(
		"font_outline_color",
		Color(0.08, 0.01, 0.01, 0.92)
	)
	_time_up_label.add_theme_color_override(
		"font_shadow_color",
		Color(TIMER_DANGER_COLOR.r, TIMER_DANGER_COLOR.g, TIMER_DANGER_COLOR.b, 0.24)
	)
	_time_up_label.add_theme_constant_override("outline_size", 4)
	_time_up_label.add_theme_constant_override("shadow_outline_size", 14)
	_time_up_label.visible = true
	_time_up_label.modulate = Color.WHITE
	_time_up_label.scale = Vector2.ONE * 0.90
	_time_up_ring.play(
		_time_up_label.position + _time_up_label.size * 0.5,
		TIMER_DANGER_COLOR,
		82.0,
		220.0,
		0.65,
		3.0
	)
	_time_up_tween = create_tween()
	_time_up_tween.set_parallel(true)
	_time_up_tween.tween_property(
		_time_up_label, "scale", Vector2.ONE, 0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_time_up_tween.tween_property(
		_time_up_label, "modulate:a", 0.0, 0.25
	).set_delay(0.75)
	_time_up_tween.chain().tween_callback(_hide_time_up_label)


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
	_show_callout(CALLOUT_WORDS[stage_index], stage_index)
	if _sfx_bank != null:
		_sfx_bank.play_callout_chime(stage_index)


func _show_callout(text: String, stage_index: int = 0) -> void:
	if _callout_tween != null and _callout_tween.is_valid():
		_callout_tween.kill()
	_stop_sparkles(_callout_sparkles)
	_planet_callout_visual.visible = false
	var clamped_stage: int = clampi(stage_index, 0, CALLOUT_WORDS.size() - 1)
	var cosmic: bool = clamped_stage >= 3
	var duration: float = CALLOUT_COSMIC_DURATION if cosmic else CALLOUT_TOTAL_DURATION
	_callout_label.text = text
	_callout_label.add_theme_color_override("font_color", CALLOUT_COLORS[clamped_stage])
	_callout_label.add_theme_color_override(
		"font_outline_color",
		Color(0.02, 0.035, 0.07, 0.92)
	)
	_callout_label.add_theme_constant_override("outline_size", 4)
	var glow_color: Color = GOLD_COLOR
	glow_color.a = 0.30 if cosmic else 0.0
	_callout_label.add_theme_color_override("font_shadow_color", glow_color)
	_callout_label.add_theme_constant_override("shadow_outline_size", 20 if cosmic else 0)
	_callout_label.visible = true
	_callout_label.modulate = Color.WHITE
	_callout_label.position = _callout_base_position
	_callout_label.scale = Vector2.ONE * 0.90
	if cosmic:
		_show_callout_sparkles(clamped_stage, duration)
	_callout_tween = create_tween()
	_callout_tween.set_parallel(true)
	_callout_tween.tween_property(
		_callout_label, "scale", Vector2.ONE, duration * 0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_callout_tween.tween_property(
		_callout_label,
		"position",
		_callout_base_position + Vector2.UP * CALLOUT_RISE_DISTANCE,
		duration * 0.72
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_callout_tween.tween_property(
		_callout_label, "modulate:a", 0.0, 0.25
	).set_delay(duration - 0.25)
	_callout_tween.chain().tween_callback(_complete_callout)


func _on_planet_unlocked(color_index: int) -> void:
	if not PLANET_NAMES.has(color_index) or _planet_unlock_seen.has(color_index):
		return
	_planet_unlock_seen[color_index] = true
	_planet_unlock_history.append(color_index)
	if not Config.data.fx_callouts_enabled:
		return
	_pending_planet_unlocks.append(color_index)
	if not _callout_label.visible:
		_show_next_planet_unlock()


func _show_next_planet_unlock() -> void:
	if _pending_planet_unlocks.is_empty() or _callout_label.visible:
		return
	var color_index: int = _pending_planet_unlocks.pop_front()
	_show_planet_unlock(color_index)


func _show_planet_unlock(color_index: int) -> void:
	if _callout_tween != null and _callout_tween.is_valid():
		_callout_tween.kill()
	_stop_sparkles(_callout_sparkles)
	var text: String = "새 행성 — %s" % str(PLANET_NAMES[color_index])
	var display_color: Color = Config.data.color_display[color_index]
	_callout_label.text = text
	_callout_label.add_theme_color_override("font_color", display_color)
	_callout_label.add_theme_color_override(
		"font_outline_color", Color(0.02, 0.035, 0.07, 0.92)
	)
	_callout_label.add_theme_constant_override("outline_size", 4)
	_callout_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	_callout_label.add_theme_constant_override("shadow_outline_size", 0)
	_callout_label.visible = true
	_callout_label.modulate = Color.WHITE
	_callout_label.position = _callout_base_position
	_callout_label.scale = Vector2.ONE * 0.90
	_planet_callout_visual.setup_celestial_preview(
		display_color,
		Config.data.radius_for_level(PLANET_UNLOCK_ORB_LEVEL),
		PLANET_UNLOCK_ORB_LEVEL,
		color_index,
		Config.data.orb_symbols_enabled
	)
	_layout_planet_callout_visual(text)
	_planet_callout_visual.visible = true
	_planet_callout_visual.modulate = Color.WHITE
	_planet_callout_visual.scale = Vector2.ONE * 0.90
	if _sfx_bank != null:
		_sfx_bank.play_callout_chime(0)
	_callout_tween = create_tween()
	_callout_tween.set_parallel(true)
	_callout_tween.tween_property(
		_callout_label, "scale", Vector2.ONE, PLANET_UNLOCK_CALLOUT_DURATION * 0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_callout_tween.tween_property(
		_planet_callout_visual,
		"scale",
		Vector2.ONE,
		PLANET_UNLOCK_CALLOUT_DURATION * 0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_callout_tween.tween_property(
		_callout_label,
		"position",
		_callout_base_position + Vector2.UP * CALLOUT_RISE_DISTANCE,
		PLANET_UNLOCK_CALLOUT_DURATION * 0.72
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_callout_tween.tween_property(
		_planet_callout_visual,
		"position",
		_planet_callout_base_position + Vector2.UP * CALLOUT_RISE_DISTANCE,
		PLANET_UNLOCK_CALLOUT_DURATION * 0.72
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_callout_tween.tween_property(
		_callout_label, "modulate:a", 0.0, 0.25
	).set_delay(PLANET_UNLOCK_CALLOUT_DURATION - 0.25)
	_callout_tween.tween_property(
		_planet_callout_visual, "modulate:a", 0.0, 0.25
	).set_delay(PLANET_UNLOCK_CALLOUT_DURATION - 0.25)
	_callout_tween.chain().tween_callback(_complete_callout)


func _layout_planet_callout_visual(text: String) -> void:
	var font: Font = _callout_label.get_theme_font("font")
	var font_size: int = _callout_label.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x
	var radius: float = Config.data.radius_for_level(PLANET_UNLOCK_ORB_LEVEL)
	_planet_callout_base_position = Vector2(
		_callout_label.position.x + (_callout_label.size.x - text_width) * 0.5
		- radius - PREVIEW_GAP,
		_callout_label.position.y + _callout_label.size.y * 0.5
	)
	_planet_callout_visual.position = _planet_callout_base_position


func _complete_callout() -> void:
	_hide_callout_label()
	_callout_tween = null
	if not _pending_planet_unlocks.is_empty():
		call_deferred("_show_next_planet_unlock")


func _show_callout_sparkles(stage_index: int, duration: float) -> void:
	var center: Vector2 = _callout_label.position + _callout_label.size * 0.5
	var offsets: Array[Vector2] = [
		Vector2(-260.0, -42.0),
		Vector2(-145.0, 70.0),
		Vector2(18.0, -84.0),
		Vector2(166.0, 62.0),
		Vector2(270.0, -28.0),
	]
	var count: int = 5 if stage_index >= 4 else 3
	for index: int in range(count):
		var turns: float = 1.0 if stage_index >= 4 else 0.0
		var end_offset: Vector2 = offsets[index] * (1.38 if stage_index >= 4 else 1.10)
		_callout_sparkles[index].play(
			center,
			GOLD_COLOR,
			duration,
			offsets[index],
			end_offset,
			turns,
			14.0 + float(index % 2) * 3.0
		)


func _start_fever_presentation() -> void:
	if _fever_tween != null and _fever_tween.is_valid():
		_fever_tween.kill()
	_fever_band_label.text = "FEVER ×%s" % _format_multiplier(
		Config.data.blitz_fever_multiplier
	)
	_fever_band_label.add_theme_color_override("font_color", HUD_AMBER_COLOR)
	_fever_band_label.add_theme_color_override(
		"font_outline_color",
		Color(0.08, 0.035, 0.0, 0.94)
	)
	_fever_band_label.add_theme_constant_override("outline_size", 4)
	_fever_band.color = Color(0.0, 0.0, 0.0, 0.0)
	_fever_band.position = _fever_band_base_position
	_fever_band.modulate = Color.WHITE
	_fever_band.scale = Vector2.ONE * 0.90
	_fever_vignette.modulate = Color.WHITE
	_fever_band.visible = true
	_fever_vignette.visible = true
	_play_fever_streak()
	_show_fever_sparkles()
	_fever_tween = create_tween()
	_fever_tween.tween_property(
		_fever_band, "scale", Vector2.ONE, FEVER_ENTRY_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fever_tween.tween_interval(FEVER_BAND_HOLD_DURATION)
	_fever_tween.tween_property(
		_fever_band, "modulate:a", 0.0, FEVER_EXIT_DURATION
	)
	_fever_tween.tween_callback(_hide_fever_band)
	if _sfx_bank != null:
		_sfx_bank.play_fever_sweep(true)


func _play_fever_streak() -> void:
	if _fever_streak_tween != null and _fever_streak_tween.is_valid():
		_fever_streak_tween.kill()
	var viewport_size: Vector2 = get_viewport_rect().size
	_layout_fever_streak(viewport_size)
	_fever_streak.position = Vector2(
		-_fever_streak.size.x,
		viewport_size.y * 0.5 + 48.0
	)
	_fever_streak.rotation = -0.045
	_fever_streak.modulate = Color.WHITE
	_fever_streak.visible = true
	_fever_streak_tween = create_tween()
	_fever_streak_tween.set_parallel(true)
	_fever_streak_tween.tween_property(
		_fever_streak,
		"position:x",
		viewport_size.x,
		FEVER_STREAK_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fever_streak_tween.tween_property(
		_fever_streak, "modulate:a", 0.0, FEVER_STREAK_DURATION
	).set_delay(FEVER_STREAK_DURATION * 0.55)
	_fever_streak_tween.chain().tween_callback(func() -> void:
		_fever_streak.visible = false
	)


func _show_fever_sparkles() -> void:
	_stop_sparkles(_fever_sparkles)
	var center: Vector2 = _fever_band.position + _fever_band.size * 0.5
	var offsets: Array[Vector2] = [
		Vector2(-150.0, -36.0),
		Vector2(0.0, 50.0),
		Vector2(154.0, -30.0),
	]
	for index: int in range(_fever_sparkles.size()):
		_fever_sparkles[index].play(
			center,
			HUD_AMBER_COLOR,
			0.85,
			offsets[index],
			offsets[index] * 1.16,
			0.0,
			13.0 + float(index)
		)


func _end_fever_presentation() -> void:
	if _fever_tween != null and _fever_tween.is_valid():
		_fever_tween.kill()
	if _fever_streak_tween != null and _fever_streak_tween.is_valid():
		_fever_streak_tween.kill()
	_fever_tween = create_tween()
	_fever_tween.set_parallel(true)
	_fever_tween.tween_property(_fever_band, "modulate:a", 0.0, FEVER_EXIT_DURATION)
	_fever_tween.tween_property(_fever_vignette, "modulate:a", 0.0, FEVER_EXIT_DURATION)
	_fever_tween.tween_property(_fever_streak, "modulate:a", 0.0, FEVER_EXIT_DURATION)
	_fever_tween.chain().tween_callback(_hide_fever_visuals)
	if _sfx_bank != null:
		_sfx_bank.play_fever_sweep(false)


func _update_fever_pulse() -> void:
	if not _fever_active or not Config.data.fx_callouts_enabled:
		return
	_fever_vignette.modulate.a = 1.0


func _stop_sparkles(sparkles: Array[CosmicSparkle]) -> void:
	for sparkle: CosmicSparkle in sparkles:
		sparkle.stop()


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
	if Config.data.blitz_survival_enabled:
		return
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
		"float hash21(vec2 p) {",
		"  p = fract(p * vec2(123.34, 456.21));",
		"  p += dot(p, p + 45.32);",
		"  return fract(p.x * p.y);",
		"}",
		"float noise21(vec2 p) {",
		"  vec2 i = floor(p);",
		"  vec2 f = fract(p);",
		"  f = f * f * (3.0 - 2.0 * f);",
		"  return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),",
		"    mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);",
		"}",
		"void fragment() {",
		"  vec2 edge_distance = abs(UV - vec2(0.5)) * 2.0;",
		"  float edge = smoothstep(0.66, 1.0, max(edge_distance.x, edge_distance.y));",
		"  vec2 drift = vec2(TIME * 0.018, -TIME * 0.012);",
		"  float cloud = noise21(UV * vec2(5.0, 8.0) + drift);",
		"  cloud = mix(cloud, noise21(UV * vec2(10.0, 16.0) - drift), 0.35);",
		"  float alpha = edge * (0.045 + cloud * 0.065);",
		"  COLOR = vec4(1.0, 0.57, 0.12, alpha);",
		"}",
	])
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = shader
	_fever_vignette.material = shader_material


func _reset_callout_tracking() -> void:
	_callout_seen.clear()
	_callout_history.clear()
	_planet_unlock_seen.clear()
	_planet_unlock_history.clear()
	_pending_planet_unlocks.clear()
	_preview_unlock_seen.clear()
	_preview_unlock_flash_history.clear()
	_timer_tick_seen.clear()
	_timer_tick_history.clear()
	_urgent_timer_tick_history.clear()
	_pending_time_bonuses.clear()
	_time_bonus_accumulator = 0.0
	_time_bonus_window_remaining = 0.0
	_drain_rate_label.visible = false
	_previous_time_remaining = -1.0
	_fever_active = false
	_fever_remaining = 0.0
	_time_up_count = 0
	_hide_callout_visuals()


func _hide_callout_visuals() -> void:
	_hide_callout_label()
	_hide_time_up_label()
	_bonus_label.visible = false
	_hide_fever_visuals()


func _hide_callout_label() -> void:
	_callout_label.visible = false
	_callout_label.scale = Vector2.ONE
	_callout_label.position = _callout_base_position
	_planet_callout_visual.visible = false
	_planet_callout_visual.scale = Vector2.ONE
	_planet_callout_visual.position = _planet_callout_base_position
	_stop_sparkles(_callout_sparkles)


func _hide_time_up_label() -> void:
	_time_up_label.visible = false
	_time_up_label.scale = Vector2.ONE
	_time_up_ring.stop()


func _hide_bonus_label() -> void:
	_bonus_label.visible = false
	_bonus_label.scale = Vector2.ONE


func _hide_fever_visuals() -> void:
	_fever_vignette.visible = false
	_fever_vignette.modulate = Color.WHITE
	_fever_streak.visible = false
	_fever_streak.modulate = Color.WHITE
	_stop_sparkles(_fever_sparkles)
	_hide_fever_band()


func _hide_fever_band() -> void:
	_fever_band.visible = false
	_fever_band.modulate = Color.WHITE
	_fever_band.scale = Vector2.ONE
	_fever_band.position = _fever_band_base_position


func fever_vignette_max_alpha() -> float:
	return FEVER_VIGNETTE_MAX_ALPHA


func active_ui_sparkle_count() -> int:
	return CosmicSparkle.visible_count(get_tree())


func fever_vignette_shader_code() -> String:
	var shader_material: ShaderMaterial = _fever_vignette.material as ShaderMaterial
	return shader_material.shader.code


func callout_history() -> Array[int]:
	return _callout_history.duplicate()


func planet_unlock_history() -> Array[int]:
	return _planet_unlock_history.duplicate()


func preview_unlock_flash_history() -> Array[int]:
	return _preview_unlock_flash_history.duplicate()


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
	_sound_button.text = ""
	_sound_button.icon = SPEAKER_OFF_ICON if muted else SPEAKER_ON_ICON
	_sound_button.tooltip_text = "소리 켜기" if muted else "소리 끄기"
