class_name SfxBank
extends Node

signal mute_changed(muted: bool)

const SAMPLE_RATE: int = 44100
const POP_DURATION: float = 0.060
const BLAST_DURATION: float = 0.460
const VOICE_COUNT: int = 12
const SFX_BUS: StringName = &"SFX"
const POP_ASSET_PATHS: Array[String] = [
	"res://assets/sfx/pop.wav",
	"res://assets/sfx/pop.ogg",
]
const BLAST_ASSET_PATHS: Array[String] = [
	"res://assets/sfx/blast.wav",
	"res://assets/sfx/blast.ogg",
]
const BLAST_POP_OFFSETS: Array[float] = [
	0.000,
	0.027,
	0.058,
	0.096,
	0.132,
	0.173,
	0.218,
]
const BLAST_POP_PITCHES: Array[float] = [
	1.00,
	0.88,
	1.12,
	0.94,
	1.15,
	0.90,
	1.05,
]

@export var save_path: String = ""

var _pop_stream: AudioStream
var _blast_stream: AudioStream
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _muted: bool = false
var _last_voice: AudioStreamPlayer


func _ready() -> void:
	_ensure_sfx_bus()
	set_muted(SaveStore.load_sfx_muted(save_path), false)
	_pop_stream = _load_first(POP_ASSET_PATHS)
	if _pop_stream == null:
		_pop_stream = _synthesize_pop()
	_blast_stream = _load_first(BLAST_ASSET_PATHS)
	if _blast_stream == null:
		_blast_stream = _synthesize_blast()
	for voice_index: int in range(VOICE_COUNT):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = "Voice%d" % voice_index
		voice.bus = SFX_BUS
		add_child(voice)
		_voices.append(voice)
	if not InputRouter.debug_toggle_sfx_mute.is_connected(toggle_mute):
		InputRouter.debug_toggle_sfx_mute.connect(toggle_mute)


func _exit_tree() -> void:
	if InputRouter.debug_toggle_sfx_mute.is_connected(toggle_mute):
		InputRouter.debug_toggle_sfx_mute.disconnect(toggle_mute)


func play_merge(result_level: int, chain: int, stable_spawn_id: int) -> void:
	if not Config.data.sfx_enabled:
		return
	_play(
		_pop_stream,
		merge_pitch(result_level, chain, stable_spawn_id),
		Config.data.sfx_volume_db
	)


func play_blast(finale: bool = false, finale_index: int = 1) -> void:
	if not Config.data.sfx_enabled:
		return
	var pitch: float = 1.0
	var volume_db: float = Config.data.sfx_volume_db + 4.0
	if finale:
		pitch = pow(2.0, float(maxi(finale_index - 1, 0)) / 12.0)
		volume_db = Config.data.sfx_volume_db - 2.0
	_play(_blast_stream, pitch, volume_db)


func merge_pitch(result_level: int, chain: int, stable_spawn_id: int) -> float:
	var clamped_level: int = clampi(result_level, 2, 7)
	var level_ratio: float = float(clamped_level - 2) / 5.0
	var level_pitch: float = lerpf(1.35, 0.75, level_ratio)
	var semitones: int = mini(
		maxi(chain - 1, 0),
		Config.data.sfx_chain_semitones_max
	)
	var chain_pitch: float = pow(2.0, float(semitones) / 12.0)
	return level_pitch * chain_pitch * (1.0 + pitch_jitter(stable_spawn_id))


func pitch_jitter(stable_spawn_id: int) -> float:
	var mixed: int = (
		abs(stable_spawn_id) * 1103515245 + 12345
	) & 0x7fffffff
	var centered: float = float(mixed % 20001) / 10000.0 - 1.0
	return centered * Config.data.sfx_pitch_jitter


func pop_stream() -> AudioStream:
	return _pop_stream


func blast_stream() -> AudioStream:
	return _blast_stream


func voice_count() -> int:
	return _voices.size()


func active_voice_count() -> int:
	var count: int = 0
	for voice: AudioStreamPlayer in _voices:
		if voice.playing:
			count += 1
	return count


func next_voice_index() -> int:
	return _next_voice


func last_voice() -> AudioStreamPlayer:
	return _last_voice


func is_muted() -> bool:
	return _muted


func toggle_mute() -> void:
	set_muted(not _muted)


func set_muted(muted: bool, persist: bool = true) -> void:
	_muted = muted
	var bus_index: int = AudioServer.get_bus_index(SFX_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, _muted)
	if persist and not save_path.is_empty():
		SaveStore.save_sfx_muted(save_path, _muted)
	mute_changed.emit(_muted)


func _play(stream_value: AudioStream, pitch: float, volume_db: float) -> void:
	if stream_value == null or _voices.is_empty():
		return
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_last_voice = voice
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stop()
	voice.stream = stream_value
	voice.pitch_scale = pitch
	voice.volume_db = volume_db
	voice.play()


func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index(SFX_BUS) >= 0:
		return
	AudioServer.add_bus()
	var bus_index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, SFX_BUS)
	AudioServer.set_bus_send(bus_index, &"Master")


func _load_first(paths: Array[String]) -> AudioStream:
	for path: String in paths:
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


func _synthesize_pop() -> AudioStreamWAV:
	var sample_count: int = ceili(POP_DURATION * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		samples[index] = _pop_sample(time, 1.0, index) * 0.82
	return _make_wav(samples)


func _synthesize_blast() -> AudioStreamWAV:
	var sample_count: int = ceili(BLAST_DURATION * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var value: float = 0.0
		for pop_index: int in range(BLAST_POP_OFFSETS.size()):
			var pop_time: float = time - BLAST_POP_OFFSETS[pop_index]
			if pop_time >= 0.0 and pop_time < POP_DURATION:
				value += _pop_sample(
					pop_time,
					BLAST_POP_PITCHES[pop_index],
					index + pop_index * 7919
				) * 0.30
		var bass_progress: float = minf(time / 0.30, 1.0)
		var bass_frequency: float = lerpf(70.0, 45.0, bass_progress)
		value += sin(TAU * bass_frequency * time) * exp(-time / 0.18) * 0.62
		value += _deterministic_noise(index + 4049) * exp(-time / 0.25) * 0.22
		samples[index] = clampf(value, -1.0, 1.0)
	return _make_wav(samples)


func _pop_sample(time: float, pitch: float, noise_index: int) -> float:
	if time < 0.0 or time >= POP_DURATION:
		return 0.0
	var value: float = 0.0
	if time < 0.0015:
		value += _deterministic_noise(noise_index) * (1.0 - time / 0.0015)
	var chirp_progress: float = minf(time / 0.008, 1.0)
	var frequency: float = lerpf(1800.0, 900.0, chirp_progress) * pitch
	value += sin(TAU * frequency * time) * exp(-time / 0.018)
	return value


func _deterministic_noise(index: int) -> float:
	var mixed: int = (abs(index) * 1664525 + 1013904223) & 0x7fffffff
	return float(mixed % 65536) / 32767.5 - 1.0


func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index: int in range(samples.size()):
		var encoded: int = roundi(clampf(samples[index], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(index * 2, encoded)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
