class_name StartScreen
extends Control

signal mode_selected(mode: GameConfig.GameMode)
signal ranking_requested(mode: GameConfig.GameMode)
signal settings_requested

const TRANSITION_SECONDS: float = 0.25
const JELLY_PINK: Color = Color("#FF7595")
const SPEAKER_ON: Texture2D = preload("res://assets/ui/speaker_on.svg")
const SPEAKER_OFF: Texture2D = preload("res://assets/ui/speaker_off.svg")

@onready var _title_label: Label = $Content/Title
@onready var _orb_title_label: Label = %OrbTitle
@onready var _subtitle_label: Label = $Content/Prompt
@onready var _jelly_button: Button = %JellyButton
@onready var _jelly_icon: Control = %JellyIcon
@onready var _jelly_name_label: Label = %JellyNameLabel
@onready var _jelly_description_label: Label = %JellyDescriptionLabel
@onready var _jelly_best_label: Label = %JellyBestLabel
@onready var _ranking_button: Button = %StartRankingButton
@onready var _sound_button: Button = %StartSoundButton
@onready var _settings_button: Button = %StartSettingsButton
@onready var _orbit_stage: OrbitStage = %OrbitStage

var _sfx_bank: SfxBank
var _transitioning: bool = false


func _ready() -> void:
	_jelly_button.pressed.connect(_begin_jelly_transition)
	_ranking_button.pressed.connect(
		func() -> void: ranking_requested.emit(GameConfig.GameMode.JELLY)
	)
	_settings_button.pressed.connect(func() -> void: settings_requested.emit())
	_sound_button.pressed.connect(_on_sound_pressed)
	for button: Button in [
		_jelly_button, _ranking_button, _sound_button, _settings_button
	]:
		ButtonMotion.bind(button)
	if not resized.is_connected(_apply_layout):
		resized.connect(_apply_layout)
	_apply_jelly_style()
	_apply_layout()


func bind(save_path: String, sfx_bank: SfxBank) -> void:
	_sfx_bank = sfx_bank
	_jelly_button.tooltip_text = "JELLY — 작은 것도 먹고 자라요"
	_jelly_best_label.text = _best_text(
		SaveStore.load_best_score(save_path, GameConfig.GameMode.JELLY)
	)
	if not _sfx_bank.mute_changed.is_connected(_on_mute_changed):
		_sfx_bank.mute_changed.connect(_on_mute_changed)
	_on_mute_changed(_sfx_bank.is_muted())
	_orbit_stage.set_symbols_enabled(Config.data.orb_symbols_enabled)


func prepare_to_show() -> void:
	_transitioning = false
	modulate.a = 1.0
	_jelly_button.disabled = false
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
	var card_y: float = 1030.0 * scale_factor + extra_height * 0.50
	var card_height: float = 200.0 * scale_factor
	var card_width: float = width - side * 2.0
	var icon_size: float = 128.0 * scale_factor
	var bottom_y: float = 1480.0 * scale_factor + extra_height * 0.76
	var action_size: float = 112.0 * scale_factor
	var orbit_rect: Rect2 = Rect2(
		0.0,
		185.0 * scale_factor + extra_height * 0.15,
		width,
		450.0 * scale_factor
	)
	var hero_size: float = OrbitStage.HERO_DIAMETER * scale_factor
	var hero_rect: Rect2 = Rect2(
		orbit_rect.get_center() - Vector2.ONE * hero_size * 0.5,
		Vector2.ONE * hero_size
	)
	var unscaled_sweep: Rect2 = OrbitStage.orbiters_sweep_rect(Vector2.ZERO)
	var orbiter_sweep: Rect2 = Rect2(
		orbit_rect.get_center() + unscaled_sweep.position * scale_factor,
		unscaled_sweep.size * scale_factor
	)
	return {
		"orbit": orbit_rect,
		"hero": hero_rect,
		"hero_body_diameter": OrbitStage.hero_body_diameter() * scale_factor,
		"orbiter_sweep": orbiter_sweep,
		"gravity": Rect2(side, 630.0 * scale_factor + extra_height * 0.18, card_width, 92.0 * scale_factor),
		"orb": Rect2(side, 730.0 * scale_factor + extra_height * 0.18, card_width, 92.0 * scale_factor),
		"subtitle": Rect2(side, 830.0 * scale_factor + extra_height * 0.18, card_width, 52.0 * scale_factor),
		"jelly": Rect2(side, card_y, card_width, card_height),
		"jelly_icon": Rect2(side + 38.0 * scale_factor, card_y + 36.0 * scale_factor, icon_size, icon_size),
		"jelly_name": Rect2(side + 200.0 * scale_factor, card_y + 22.0 * scale_factor, card_width - 240.0 * scale_factor, 58.0 * scale_factor),
		"jelly_description": Rect2(side + 200.0 * scale_factor, card_y + 76.0 * scale_factor, card_width - 240.0 * scale_factor, 58.0 * scale_factor),
		"jelly_best": Rect2(side + 200.0 * scale_factor, card_y + 136.0 * scale_factor, card_width - 240.0 * scale_factor, 40.0 * scale_factor),
		"ranking": Rect2(width * 0.5 - action_size * 1.75, bottom_y, action_size, action_size),
		"sound": Rect2(width * 0.5 - action_size * 0.5, bottom_y, action_size, action_size),
		"settings": Rect2(width * 0.5 + action_size * 0.75, bottom_y, action_size, action_size),
	}


func _apply_layout() -> void:
	var layout: Dictionary = layout_for_viewport(size)
	_set_rect(_orbit_stage, layout["orbit"] as Rect2)
	_set_rect(_title_label, layout["gravity"] as Rect2)
	_set_rect(_orb_title_label, layout["orb"] as Rect2)
	_set_rect(_subtitle_label, layout["subtitle"] as Rect2)
	_set_rect(_jelly_button, layout["jelly"] as Rect2)
	_set_rect(_jelly_icon, layout["jelly_icon"] as Rect2)
	_set_rect(_jelly_name_label, layout["jelly_name"] as Rect2)
	_set_rect(_jelly_description_label, layout["jelly_description"] as Rect2)
	_set_rect(_jelly_best_label, layout["jelly_best"] as Rect2)
	_set_rect(_ranking_button, layout["ranking"] as Rect2)
	_set_rect(_sound_button, layout["sound"] as Rect2)
	_set_rect(_settings_button, layout["settings"] as Rect2)


func _begin_jelly_transition() -> void:
	if _transitioning:
		return
	_transitioning = true
	_jelly_button.disabled = true
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate:a", 0.0, TRANSITION_SECONDS)
	await tween.finished
	mode_selected.emit(GameConfig.GameMode.JELLY)


func _apply_jelly_style() -> void:
	var source: StyleBoxFlat = _jelly_button.get_theme_stylebox("pressed") as StyleBoxFlat
	if source == null:
		return
	var selected: StyleBoxFlat = source.duplicate() as StyleBoxFlat
	selected.border_color = JELLY_PINK
	selected.bg_color = Color(
		JELLY_PINK.r * 0.13,
		JELLY_PINK.g * 0.13,
		JELLY_PINK.b * 0.13,
		0.96
	)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		_jelly_button.add_theme_stylebox_override(state, selected)


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
