class_name SfxBank
extends Node

signal mute_changed(muted: bool)
signal play_called(
	kind: String,
	reaction_usec: int,
	play_usec: int,
	reaction_physics_frame: int,
	play_physics_frame: int,
	reaction_process_frame: int,
	play_process_frame: int
)

const SAMPLE_RATE: int = 44100
const POP_DURATION: float = 0.045
const BLAST_DURATION: float = 0.460
const CHIME_DURATION: float = 0.340
const FEVER_SWEEP_DURATION: float = 0.400
const TIMER_TICK_DURATION: float = 0.060
const TIME_UP_DURATION: float = 0.520
const SWIPE_DURATION: float = 0.120
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
const CALLOUT_ASSET_PATHS: Array[String] = [
	"res://assets/sfx/callout.wav",
	"res://assets/sfx/callout.ogg",
]
const FEVER_START_ASSET_PATHS: Array[String] = [
	"res://assets/sfx/fever_start.wav",
	"res://assets/sfx/fever_start.ogg",
]
const FEVER_END_ASSET_PATHS: Array[String] = [
	"res://assets/sfx/fever_end.wav",
	"res://assets/sfx/fever_end.ogg",
]
const TIMER_TICK_ASSET_PATHS: Array[String] = [
	"res://assets/sfx/timer_tick.wav",
	"res://assets/sfx/timer_tick.ogg",
]
const TIME_UP_ASSET_PATHS: Array[String] = [
	"res://assets/sfx/time_up.wav",
	"res://assets/sfx/time_up.ogg",
]
const SWIPE_ASSET_PATHS: Array[String] = [
	"res://assets/sfx/swipe.wav",
	"res://assets/sfx/swipe.ogg",
]
const BLAST_POP_OFFSETS: Array[float] = [
	0.000,
	0.012,
	0.028,
	0.045,
	0.063,
	0.081,
	0.100,
]
const BLAST_POP_GAINS: Array[float] = [1.00, 0.76, 0.64, 0.55, 0.47, 0.40, 0.34]
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
var _callout_stream: AudioStream
var _fever_start_stream: AudioStream
var _fever_end_stream: AudioStream
var _timer_tick_stream: AudioStream
var _time_up_stream: AudioStream
var _swipe_stream: AudioStream
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
	_callout_stream = _load_first(CALLOUT_ASSET_PATHS)
	if _callout_stream == null:
		_callout_stream = _synthesize_callout_chime()
	_fever_start_stream = _load_first(FEVER_START_ASSET_PATHS)
	if _fever_start_stream == null:
		_fever_start_stream = _synthesize_fever_sweep(true)
	_fever_end_stream = _load_first(FEVER_END_ASSET_PATHS)
	if _fever_end_stream == null:
		_fever_end_stream = _synthesize_fever_sweep(false)
	_timer_tick_stream = _load_first(TIMER_TICK_ASSET_PATHS)
	if _timer_tick_stream == null:
		_timer_tick_stream = _synthesize_timer_tick()
	_time_up_stream = _load_first(TIME_UP_ASSET_PATHS)
	if _time_up_stream == null:
		_time_up_stream = _synthesize_time_up_buzzer()
	_swipe_stream = _load_first(SWIPE_ASSET_PATHS)
	if _swipe_stream == null:
		_swipe_stream = _synthesize_swipe()
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
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null
	_voices.clear()
	_last_voice = null
	_pop_stream = null
	_blast_stream = null
	_callout_stream = null
	_fever_start_stream = null
	_fever_end_stream = null
	_timer_tick_stream = null
	_time_up_stream = null
	_swipe_stream = null


func play_merge(
	result_level: int,
	chain: int,
	stable_spawn_id: int,
	reaction_usec: int = 0,
	reaction_physics_frame: int = -1,
	reaction_process_frame: int = -1
) -> void:
	if not Config.data.sfx_enabled:
		return
	_play(
		_pop_stream,
		merge_pitch(result_level, chain, stable_spawn_id),
		Config.data.sfx_volume_db,
		"merge",
		reaction_usec,
		reaction_physics_frame,
		reaction_process_frame
	)


func play_blast(
	finale: bool = false,
	finale_index: int = 1,
	reaction_usec: int = 0,
	reaction_physics_frame: int = -1,
	reaction_process_frame: int = -1
) -> void:
	if not Config.data.sfx_enabled:
		return
	var pitch: float = 1.0
	var volume_db: float = Config.data.sfx_volume_db + 4.0
	if finale:
		pitch = pow(2.0, float(maxi(finale_index - 1, 0)) / 12.0)
		volume_db = Config.data.sfx_volume_db - 2.0
	_play(
		_blast_stream,
		pitch,
		volume_db,
		"blast",
		reaction_usec,
		reaction_physics_frame,
		reaction_process_frame
	)


func play_callout_chime(stage_index: int) -> void:
	if not Config.data.sfx_enabled:
		return
	var pitch: float = pow(2.0, float(maxi(stage_index, 0) * 2) / 12.0)
	_play(_callout_stream, pitch, Config.data.sfx_volume_db, "callout", 0, -1, -1)


func play_fever_sweep(starting: bool) -> void:
	if not Config.data.sfx_enabled:
		return
	_play(
		_fever_start_stream if starting else _fever_end_stream,
		1.0,
		Config.data.sfx_volume_db,
		"fever_start" if starting else "fever_end",
		0,
		-1,
		-1
	)


func play_timer_tick(urgent: bool) -> void:
	if not Config.data.sfx_enabled:
		return
	_play(
		_timer_tick_stream,
		1.28 if urgent else 1.0,
		Config.data.sfx_volume_db + (3.0 if urgent else 0.0),
		"timer_tick_urgent" if urgent else "timer_tick",
		0,
		-1,
		-1
	)


func play_time_up_buzzer() -> void:
	if not Config.data.sfx_enabled:
		return
	_play(_time_up_stream, 1.0, Config.data.sfx_volume_db + 2.0, "time_up", 0, -1, -1)


func play_swipe() -> void:
	if not Config.data.sfx_enabled:
		return
	_play(_swipe_stream, 1.0, Config.data.sfx_volume_db, "swipe", 0, -1, -1)


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


func swipe_stream() -> AudioStream:
	return _swipe_stream


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


func _play(
	stream_value: AudioStream,
	pitch: float,
	volume_db: float,
	kind: String,
	reaction_usec: int,
	reaction_physics_frame: int,
	reaction_process_frame: int
) -> void:
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
	play_called.emit(
		kind,
		reaction_usec,
		Time.get_ticks_usec(),
		reaction_physics_frame,
		Engine.get_physics_frames(),
		reaction_process_frame,
		Engine.get_process_frames()
	)


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
				) * 0.34 * BLAST_POP_GAINS[pop_index]
		if time < 0.015:
			var attack_envelope: float = 1.0 - time / 0.015
			value += _high_pass_noise(index + 4049) * attack_envelope * 0.90
		var mid_progress: float = minf(time / 0.12, 1.0)
		var mid_frequency: float = lerpf(150.0, 90.0, mid_progress)
		var mid_attack: float = 1.0 - exp(-time / 0.0005)
		value += (
			sin(TAU * mid_frequency * time)
			* mid_attack
			* exp(-time / 0.12)
			* 0.72
		)
		var sub_progress: float = minf(time / 0.30, 1.0)
		var sub_frequency: float = lerpf(70.0, 45.0, sub_progress)
		var sub_phase: float = TAU * sub_frequency * time
		value += (
			(
				sin(sub_phase)
				+ sin(sub_phase * 2.0) * 0.32
				+ sin(sub_phase * 3.0) * 0.18
			)
			* exp(-time / 0.18)
			* 0.44
		)
		samples[index] = clampf(value, -1.0, 1.0)
	return _make_wav(samples)


func _synthesize_callout_chime() -> AudioStreamWAV:
	var sample_count: int = ceili(CHIME_DURATION * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	var note_offsets: Array[float] = [0.0, 0.075, 0.150]
	var note_ratios: Array[float] = [1.0, 1.259921, 1.498307]
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var value: float = 0.0
		for note_index: int in range(note_offsets.size()):
			var note_time: float = time - note_offsets[note_index]
			if note_time < 0.0 or note_time >= 0.19:
				continue
			var attack: float = minf(note_time / 0.008, 1.0)
			var envelope: float = attack * exp(-note_time / 0.085)
			var frequency: float = 523.25 * note_ratios[note_index]
			value += (
				sin(TAU * frequency * note_time)
				+ 0.24 * sin(TAU * frequency * 2.0 * note_time)
			) * envelope * 0.42
		samples[index] = clampf(value, -1.0, 1.0)
	return _make_wav(samples)


func _synthesize_fever_sweep(rising: bool) -> AudioStreamWAV:
	var sample_count: int = ceili(FEVER_SWEEP_DURATION * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	var phase: float = 0.0
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / FEVER_SWEEP_DURATION
		var shaped: float = progress * progress * (3.0 - 2.0 * progress)
		var frequency: float = (
			lerpf(220.0, 960.0, shaped)
			if rising
			else lerpf(720.0, 150.0, shaped)
		)
		phase += TAU * frequency / float(SAMPLE_RATE)
		var envelope: float = sin(PI * progress)
		var shimmer: float = _high_pass_noise(index + (1709 if rising else 2909)) * 0.12
		samples[index] = clampf((sin(phase) * 0.58 + shimmer) * envelope, -1.0, 1.0)
	return _make_wav(samples)


func _synthesize_timer_tick() -> AudioStreamWAV:
	var sample_count: int = ceili(TIMER_TICK_DURATION * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var attack: float = minf(time / 0.0015, 1.0)
		var envelope: float = attack * exp(-time / 0.014)
		var value: float = (
			sin(TAU * 920.0 * time)
			+ 0.62 * sin(TAU * 1380.0 * time)
		) * envelope * 0.56
		samples[index] = clampf(value, -1.0, 1.0)
	return _make_wav(samples)


func _synthesize_time_up_buzzer() -> AudioStreamWAV:
	var sample_count: int = ceili(TIME_UP_DURATION * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / TIME_UP_DURATION
		var attack: float = minf(time / 0.008, 1.0)
		var envelope: float = attack * (1.0 - smoothstep(0.72, 1.0, progress))
		var pulse: float = 1.0 if sin(TAU * 110.0 * time) >= 0.0 else -1.0
		var wobble: float = sin(TAU * 7.0 * time) * 0.16
		samples[index] = clampf((pulse * 0.55 + wobble) * envelope, -1.0, 1.0)
	return _make_wav(samples)


func _synthesize_swipe() -> AudioStreamWAV:
	var sample_count: int = ceili(SWIPE_DURATION * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	var filtered_noise: float = 0.0
	var phase: float = 0.0
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / SWIPE_DURATION
		var envelope: float = sin(PI * progress)
		var cutoff_blend: float = lerpf(0.38, 0.08, progress)
		var noise: float = _high_pass_noise(index + 8117)
		filtered_noise += (noise - filtered_noise) * cutoff_blend
		var frequency: float = lerpf(760.0, 260.0, progress)
		phase += TAU * frequency / float(SAMPLE_RATE)
		var value: float = (filtered_noise * 0.72 + sin(phase) * 0.16) * envelope
		samples[index] = clampf(value, -1.0, 1.0)
	return _make_wav(samples)


func _pop_sample(time: float, pitch: float, noise_index: int) -> float:
	if time < 0.0 or time >= POP_DURATION:
		return 0.0
	var value: float = 0.0
	if time < 0.003:
		value += (
			_high_pass_noise(noise_index)
			* (1.0 - time / 0.003)
			* 1.6
		)
	var chirp_progress: float = minf(time / 0.005, 1.0)
	var frequency: float = lerpf(2400.0, 1200.0, chirp_progress) * pitch
	value += sin(TAU * frequency * time) * exp(-time / 0.010)
	return value


func _high_pass_noise(index: int) -> float:
	return _deterministic_noise(index) - _deterministic_noise(index - 1)


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
