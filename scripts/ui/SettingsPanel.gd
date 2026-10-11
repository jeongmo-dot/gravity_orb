class_name SettingsPanel
extends Control

signal closed
signal symbols_changed(enabled: bool)

const TRANSITION_SECONDS: float = 0.25
const SLIDE_OFFSET: float = 180.0

@onready var _panel: PanelContainer = %SettingsPanelBody
@onready var _sound_toggle: Button = %SettingsSoundToggle
@onready var _symbols_toggle: Button = %SettingsSymbolsToggle
@onready var _close_button: Button = %SettingsCloseButton

var _save_path: String = ""
var _sfx_bank: SfxBank
var _symbols_enabled: bool = true
var _transitioning: bool = false
var _rest_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_sound_toggle.pressed.connect(_on_sound_pressed)
	_symbols_toggle.pressed.connect(_on_symbols_pressed)
	_close_button.pressed.connect(close)
	for button: Button in [_sound_toggle, _symbols_toggle, _close_button]:
		ButtonMotion.bind(button)
	visible = false


func bind(save_path: String, sfx_bank: SfxBank) -> void:
	_save_path = save_path
	_sfx_bank = sfx_bank
	_symbols_enabled = SaveStore.load_orb_symbols_enabled(
		_save_path,
		Config.data.orb_symbols_enabled
	)
	Config.data.orb_symbols_enabled = _symbols_enabled
	if not _sfx_bank.mute_changed.is_connected(_on_mute_changed):
		_sfx_bank.mute_changed.connect(_on_mute_changed)
	_on_mute_changed(_sfx_bank.is_muted())
	_refresh_symbols()


func open() -> void:
	if _transitioning or visible:
		return
	visible = true
	_transitioning = true
	_rest_position = _panel.position
	_panel.position = _rest_position + Vector2(0.0, SLIDE_OFFSET)
	_panel.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "position", _rest_position, TRANSITION_SECONDS)
	tween.tween_property(_panel, "modulate:a", 1.0, TRANSITION_SECONDS)
	await tween.finished
	_transitioning = false


func close() -> void:
	if _transitioning or not visible:
		return
	_transitioning = true
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(
		_panel,
		"position",
		_rest_position + Vector2(0.0, SLIDE_OFFSET),
		TRANSITION_SECONDS
	)
	tween.tween_property(_panel, "modulate:a", 0.0, TRANSITION_SECONDS)
	await tween.finished
	_panel.position = _rest_position
	_panel.modulate.a = 1.0
	visible = false
	_transitioning = false
	closed.emit()


func symbols_enabled() -> bool:
	return _symbols_enabled


func _on_sound_pressed() -> void:
	if _sfx_bank != null:
		_sfx_bank.toggle_mute()


func _on_symbols_pressed() -> void:
	_symbols_enabled = not _symbols_enabled
	Config.data.orb_symbols_enabled = _symbols_enabled
	SaveStore.save_orb_symbols_enabled(_save_path, _symbols_enabled)
	_refresh_symbols()
	symbols_changed.emit(_symbols_enabled)


func _on_mute_changed(muted: bool) -> void:
	_sound_toggle.text = "효과음    %s" % ("끔" if muted else "켬")
	_sound_toggle.set_pressed_no_signal(not muted)


func _refresh_symbols() -> void:
	_symbols_toggle.text = "색상 기호    %s" % ("켬" if _symbols_enabled else "끔")
	_symbols_toggle.set_pressed_no_signal(_symbols_enabled)
