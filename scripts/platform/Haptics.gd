class_name Haptics
extends Node

const SWIPE_DURATION_MS: int = 8
const BLAST_DURATION_MS: int = 25

var _request_count: int = 0
var _platform_vibration_count: int = 0
var _last_duration_ms: int = 0


func play_swipe() -> void:
	_vibrate(SWIPE_DURATION_MS)


func play_blast() -> void:
	_vibrate(BLAST_DURATION_MS)


func request_count() -> int:
	return _request_count


func platform_vibration_count() -> int:
	return _platform_vibration_count


func last_duration_ms() -> int:
	return _last_duration_ms


func is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _vibrate(duration_ms: int) -> void:
	if not Config.data.haptics_enabled:
		return
	_request_count += 1
	_last_duration_ms = duration_ms
	if not is_mobile_platform():
		return
	Input.vibrate_handheld(duration_ms)
	_platform_vibration_count += 1
