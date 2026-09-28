extends Node

const DEFAULT_CONFIG: Resource = preload("res://config/default_config.tres")

var data: GameConfig = DEFAULT_CONFIG.duplicate(true) as GameConfig
