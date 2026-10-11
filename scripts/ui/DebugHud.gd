class_name DebugHud
extends CanvasLayer

const TURN_STATE_NAMES: Array[String] = [
	"WAITING_INPUT",
	"SIMULATING",
	"SPAWNING",
	"CHECK_GAMEOVER",
	"GAME_OVER",
]
const BLITZ_STATE_NAMES: Array[String] = [
	"IDLE", "READY", "RUNNING", "FINALE", "FINISHED"
]
const ANNIHILATION_RULE_NAMES: Array[String] = ["A", "B", "C"]

@onready var _turn_manager: TurnManager = %TurnManager
@onready var _blitz_manager: BlitzManager = %BlitzManager
@onready var _spawner: Spawner = %Spawner
@onready var _score_manager: ScoreManager = %ScoreManager
@onready var _board: Variant = %Board
@onready var _label: Label = %DebugLabel
@onready var _hud: Hud = %Hud
@onready var _game_over_panel: GameOverPanel = %GameOverPanel
@onready var _start_screen: StartScreen = %StartScreen
@onready var _ranking_panel: RankingPanel = %RankingPanel
@onready var _settings_panel: SettingsPanel = %SettingsPanel
@onready var _sfx_bank: SfxBank = %SfxBank

var _game_manager: Variant
var _state: int = 0
var _gravity: Vector2i = Vector2i.DOWN
var _turn_index: int = 0
var _turn_combo: int = 0
var _combo_multiplier: float = 1.0
var _max_combo: int = 0
var _debug_visible: bool = false
var _ranking_return_to_start: bool = true


func _ready() -> void:
	_game_manager = (
		_blitz_manager
		if Config.data.game_mode == GameConfig.GameMode.BLITZ
		else _turn_manager
	)
	_hud.bind_spawner(_spawner)
	_hud.bind_score_manager(_score_manager)
	_hud.bind_game_state(_game_manager, _board, _score_manager)
	_hud.bind_sfx_bank(_sfx_bank)
	_state = int(_game_manager.state)
	_gravity = _game_manager.gravity
	_turn_index = _game_manager.turn_index
	_turn_combo = _game_manager.turn_combo
	_combo_multiplier = _game_manager.current_combo_multiplier()
	_max_combo = _game_manager.max_combo
	_game_manager.state_changed.connect(_on_state_changed)
	_game_manager.gravity_changed.connect(_on_gravity_changed)
	_game_manager.turn_started.connect(_on_turn_started)
	_game_manager.turn_finished.connect(_on_turn_finished)
	_game_manager.combo_changed.connect(_on_combo_changed)
	InputRouter.debug_toggle_hud.connect(_toggle_debug_hud)
	_label.visible = false
	_update_label()


func bind_start_screen(save_path: String) -> void:
	_start_screen.bind(save_path, _sfx_bank)
	_ranking_panel.bind(save_path)
	_settings_panel.bind(save_path, _sfx_bank)
	_on_symbols_changed(_settings_panel.symbols_enabled())
	if not _ranking_panel.closed.is_connected(_on_ranking_closed):
		_ranking_panel.closed.connect(_on_ranking_closed)
	if not _start_screen.settings_requested.is_connected(show_settings):
		_start_screen.settings_requested.connect(show_settings)
	if not _settings_panel.symbols_changed.is_connected(_on_symbols_changed):
		_settings_panel.symbols_changed.connect(_on_symbols_changed)


func show_start_screen() -> void:
	_start_screen.prepare_to_show()
	_hud.visible = false
	if _board != null:
		_board.set("visible", false)
	_label.visible = false


func show_gameplay() -> void:
	_start_screen.visible = false
	_hud.visible = true
	if _board != null:
		_board.set("visible", true)
	_label.visible = OS.is_debug_build() and _debug_visible


func start_screen() -> StartScreen:
	return _start_screen


func ranking_panel() -> RankingPanel:
	return _ranking_panel


func settings_panel() -> SettingsPanel:
	return _settings_panel


func show_settings() -> void:
	_label.visible = false
	_settings_panel.open()


func show_ranking(mode: GameConfig.GameMode, highlight_rank: int = 0) -> void:
	if not _ranking_panel.visible:
		_ranking_return_to_start = _start_screen.visible
	_start_screen.visible = false
	_hud.visible = false
	_label.visible = false
	_ranking_panel.open(mode, highlight_rank)


func _on_ranking_closed() -> void:
	if _ranking_return_to_start:
		show_start_screen()
	else:
		show_gameplay()
		_game_over_panel.restore_actions_after_ranking()


func _on_symbols_changed(enabled: bool) -> void:
	Config.data.orb_symbols_enabled = enabled
	_start_screen.set_symbols_enabled(enabled)
	_hud.set_symbols_enabled(enabled)
	if _board != null and _board.has_method("get_orbs"):
		for orb: Variant in _board.get_orbs():
			if orb != null and orb.has_method("set_symbols_enabled"):
				orb.call("set_symbols_enabled", enabled)


func _toggle_debug_hud() -> void:
	if not OS.is_debug_build() or not _hud.visible:
		return
	_debug_visible = not _debug_visible
	_label.visible = _debug_visible


func is_debug_hud_visible() -> bool:
	return _label.visible


func _process(_delta: float) -> void:
	_update_label()


func _on_state_changed(next_state: int) -> void:
	_state = int(next_state)


func _on_gravity_changed(direction: Vector2i) -> void:
	_gravity = direction


func _on_turn_started(next_turn_index: int, _direction: Vector2i) -> void:
	_turn_index = next_turn_index


func _on_turn_finished(finished_turn_index: int, _combo: int) -> void:
	_turn_index = finished_turn_index


func _on_combo_changed(combo: int, multiplier: float, max_combo: int) -> void:
	_turn_combo = combo
	_combo_multiplier = multiplier
	_max_combo = max_combo


func _update_label() -> void:
	var blitz_mode: bool = Config.data.game_mode == GameConfig.GameMode.BLITZ
	var state_names: Array[String] = BLITZ_STATE_NAMES if blitz_mode else TURN_STATE_NAMES
	var spawn_amount: int = 1 if blitz_mode else Config.data.spawn_count_for_turn(
		_game_manager.turn_index + 1
	)
	_label.text = "Mode: %s\nState: %s\nGravity: %s\n%s: %d\n%s: %d (x%s)\n%s: %d\nRule: %s\nSpawn: %d\nElapsed: %.2f s\nSeed: %d" % [
		"BLITZ" if blitz_mode else "TURN",
		state_names[_state],
		OrbTypes.dir_name(_gravity),
		"Swipes" if blitz_mode else "Turn",
		_turn_index,
		"Chain" if blitz_mode else "Combo",
		_turn_combo,
		_format_multiplier(_combo_multiplier),
		"Max Chain" if blitz_mode else "Max Combo",
		_max_combo,
		(
			"off"
			if Config.data.opposite_pairs.is_empty()
			else ANNIHILATION_RULE_NAMES[Config.data.annihilation_rule]
		),
		spawn_amount,
		_game_manager.settle_elapsed,
		_spawner.seed_used,
	]


func _format_multiplier(multiplier: float) -> String:
	if is_equal_approx(multiplier, float(roundi(multiplier))):
		return str(roundi(multiplier))
	return "%.2f" % multiplier
