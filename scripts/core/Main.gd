class_name Main
extends Node2D

const BACKGROUND_COLOR: Color = Color.BLACK


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
