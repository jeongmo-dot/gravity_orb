class_name StartScreen
extends Control

signal mode_selected(mode: GameConfig.GameMode)

@onready var _blitz_button: Button = %BlitzButton
@onready var _classic_button: Button = %ClassicButton
@onready var _blitz_best_label: Label = %BlitzBestLabel
@onready var _classic_best_label: Label = %ClassicBestLabel
@onready var _sound_button: Button = %StartSoundButton

var _sfx_bank: SfxBank


func _ready() -> void:
	_blitz_button.pressed.connect(
		func() -> void: mode_selected.emit(GameConfig.GameMode.BLITZ)
	)
	_classic_button.pressed.connect(
		func() -> void: mode_selected.emit(GameConfig.GameMode.TURN)
	)
	_sound_button.pressed.connect(_on_sound_pressed)


func bind(save_path: String, sfx_bank: SfxBank) -> void:
	_sfx_bank = sfx_bank
	_blitz_best_label.text = "BEST  %d" % SaveStore.load_best_score(
		save_path,
		GameConfig.GameMode.BLITZ
	)
	_classic_best_label.text = "BEST  %d" % SaveStore.load_best_score(
		save_path,
		GameConfig.GameMode.TURN
	)
	var last_mode: GameConfig.GameMode = SaveStore.load_last_mode(
		save_path,
		Config.data.game_mode
	)
	_blitz_button.set_pressed_no_signal(last_mode == GameConfig.GameMode.BLITZ)
	_classic_button.set_pressed_no_signal(last_mode == GameConfig.GameMode.TURN)
	if not _sfx_bank.mute_changed.is_connected(_on_mute_changed):
		_sfx_bank.mute_changed.connect(_on_mute_changed)
	_on_mute_changed(_sfx_bank.is_muted())


func _on_sound_pressed() -> void:
	if _sfx_bank != null:
		_sfx_bank.toggle_mute()


func _on_mute_changed(muted: bool) -> void:
	_sound_button.text = "🔇" if muted else "🔊"
	_sound_button.tooltip_text = "소리 켜기" if muted else "소리 끄기"
