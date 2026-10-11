class_name StartScreen
extends Control

signal mode_selected(mode: GameConfig.GameMode)
signal ranking_requested(mode: GameConfig.GameMode)
signal settings_requested

const TRANSITION_SECONDS: float = 0.25
const CYAN: Color = Color("#BFE9FF")
const AMBER: Color = Color("#FFB020")
const SPEAKER_ON: Texture2D = preload("res://assets/ui/speaker_on.svg")
const SPEAKER_OFF: Texture2D = preload("res://assets/ui/speaker_off.svg")

@onready var _title_label: Label = $Content/Title
@onready var _orb_title_label: Label = %OrbTitle
@onready var _subtitle_label: Label = $Content/Prompt
@onready var _blitz_button: Button = %BlitzButton
@onready var _classic_button: Button = %ClassicButton
@onready var _blitz_best_label: Label = %BlitzBestLabel
@onready var _classic_best_label: Label = %ClassicBestLabel
@onready var _ranking_button: Button = %StartRankingButton
@onready var _sound_button: Button = %StartSoundButton
@onready var _settings_button: Button = %StartSettingsButton
@onready var _orbit_stage: OrbitStage = %OrbitStage

var _sfx_bank: SfxBank
var _last_mode: GameConfig.GameMode = GameConfig.GameMode.TURN
var _transitioning: bool = false


func _ready() -> void:
	_blitz_button.pressed.connect(
		func() -> void: _begin_mode_transition(GameConfig.GameMode.BLITZ)
	)
	_classic_button.pressed.connect(
		func() -> void: _begin_mode_transition(GameConfig.GameMode.TURN)
	)
	_ranking_button.pressed.connect(func() -> void: ranking_requested.emit(_last_mode))
	_settings_button.pressed.connect(func() -> void: settings_requested.emit())
	_sound_button.pressed.connect(_on_sound_pressed)
	for button: Button in [
		_blitz_button,
		_classic_button,
		_ranking_button,
		_sound_button,
		_settings_button,
	]:
		ButtonMotion.bind(button)
	if not resized.is_connected(_apply_layout):
		resized.connect(_apply_layout)
	_apply_layout()


func bind(save_path: String, sfx_bank: SfxBank) -> void:
	_sfx_bank = sfx_bank
	_blitz_button.text = "BLITZ\n시간 버티기"
	_classic_button.text = "CLASSIC\n턴제 퍼즐"
	_blitz_best_label.text = _best_text(
		SaveStore.load_best_score(save_path, GameConfig.GameMode.BLITZ)
	)
	_classic_best_label.text = _best_text(
		SaveStore.load_best_score(save_path, GameConfig.GameMode.TURN)
	)
	_last_mode = SaveStore.load_last_mode(save_path, Config.data.game_mode)
	_apply_mode_selection()
	if not _sfx_bank.mute_changed.is_connected(_on_mute_changed):
		_sfx_bank.mute_changed.connect(_on_mute_changed)
	_on_mute_changed(_sfx_bank.is_muted())
	_orbit_stage.set_symbols_enabled(Config.data.orb_symbols_enabled)


func prepare_to_show() -> void:
	_transitioning = false
	modulate.a = 1.0
	_blitz_button.disabled = false
	_classic_button.disabled = false
	visible = true


func set_symbols_enabled(enabled: bool) -> void:
	_orbit_stage.set_symbols_enabled(enabled)


func is_transitioning() -> bool:
	return _transitioning


static func layout_for_viewport(viewport_size: Vector2) -> Dictionary:
	var width: float = maxf(viewport_size.x, 540.0)
	var height: float = maxf(viewport_size.y, 960.0)
	var scale_factor: float = width / 1080.0
	var extra_height: float = maxf(height - 1920.0 * scale_factor, 0.0)
	var side: float = 72.0 * scale_factor
	var gap: float = 28.0 * scale_factor
	var card_width: float = (width - side * 2.0 - gap) * 0.5
	var card_y: float = 780.0 * scale_factor + extra_height * 0.36
	var card_height: float = 350.0 * scale_factor
	var bottom_y: float = height - 170.0 * scale_factor
	var icon_size: float = 104.0 * scale_factor
	return {
		"orbit": Rect2(0.0, 75.0 * scale_factor + extra_height * 0.04, width, 520.0 * scale_factor),
		"gravity": Rect2(side, 355.0 * scale_factor + extra_height * 0.10, width - side * 2.0, 112.0 * scale_factor),
		"orb": Rect2(side, 450.0 * scale_factor + extra_height * 0.10, width - side * 2.0, 112.0 * scale_factor),
		"subtitle": Rect2(side, 575.0 * scale_factor + extra_height * 0.14, width - side * 2.0, 60.0 * scale_factor),
		"blitz": Rect2(side, card_y, card_width, card_height),
		"classic": Rect2(side + card_width + gap, card_y, card_width, card_height),
		"blitz_best": Rect2(side + 20.0 * scale_factor, card_y + card_height - 76.0 * scale_factor, card_width - 40.0 * scale_factor, 48.0 * scale_factor),
		"classic_best": Rect2(side + card_width + gap + 20.0 * scale_factor, card_y + card_height - 76.0 * scale_factor, card_width - 40.0 * scale_factor, 48.0 * scale_factor),
		"ranking": Rect2(width * 0.5 - icon_size * 1.75, bottom_y, icon_size, icon_size),
		"sound": Rect2(width * 0.5 - icon_size * 0.5, bottom_y, icon_size, icon_size),
		"settings": Rect2(width * 0.5 + icon_size * 0.75, bottom_y, icon_size, icon_size),
	}


func _apply_layout() -> void:
	var layout: Dictionary = layout_for_viewport(size)
	_set_rect(_orbit_stage, layout["orbit"] as Rect2)
	_set_rect(_title_label, layout["gravity"] as Rect2)
	_set_rect(_orb_title_label, layout["orb"] as Rect2)
	_set_rect(_subtitle_label, layout["subtitle"] as Rect2)
	_set_rect(_blitz_button, layout["blitz"] as Rect2)
	_set_rect(_classic_button, layout["classic"] as Rect2)
	_set_rect(_blitz_best_label, layout["blitz_best"] as Rect2)
	_set_rect(_classic_best_label, layout["classic_best"] as Rect2)
	_set_rect(_ranking_button, layout["ranking"] as Rect2)
	_set_rect(_sound_button, layout["sound"] as Rect2)
	_set_rect(_settings_button, layout["settings"] as Rect2)


func _begin_mode_transition(mode: GameConfig.GameMode) -> void:
	if _transitioning:
		return
	_transitioning = true
	_last_mode = mode
	_apply_mode_selection()
	_blitz_button.disabled = true
	_classic_button.disabled = true
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate:a", 0.0, TRANSITION_SECONDS)
	await tween.finished
	mode_selected.emit(mode)


func _apply_mode_selection() -> void:
	var blitz_selected: bool = _last_mode == GameConfig.GameMode.BLITZ
	_blitz_button.set_pressed_no_signal(blitz_selected)
	_classic_button.set_pressed_no_signal(not blitz_selected)
	_apply_selected_style(_blitz_button, AMBER)
	_apply_selected_style(_classic_button, CYAN)


func _apply_selected_style(button: Button, color: Color) -> void:
	var source: StyleBoxFlat = button.get_theme_stylebox("pressed") as StyleBoxFlat
	if source == null:
		return
	var selected: StyleBoxFlat = source.duplicate() as StyleBoxFlat
	selected.border_color = color
	selected.bg_color = Color(color.r * 0.13, color.g * 0.13, color.b * 0.13, 0.96)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("hover_pressed", selected)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_hover_pressed_color", color.lightened(0.12))


func _on_sound_pressed() -> void:
	if _sfx_bank != null:
		_sfx_bank.toggle_mute()


func _on_mute_changed(muted: bool) -> void:
	_sound_button.icon = SPEAKER_OFF if muted else SPEAKER_ON
	_sound_button.text = ""
	_sound_button.tooltip_text = "소리 켜기" if muted else "소리 끄기"


func _best_text(score: int) -> String:
	return "BEST —" if score <= 0 else "BEST %s" % _format_score(score)


func _format_score(score: int) -> String:
	var digits: String = str(maxi(score, 0))
	var formatted: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]
	return formatted


func _set_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
