class_name ProceduralMusic
extends Node
## Original, runtime-only Lanternwake score. No samples, MIDI, or imported audio.
## Four musical voices and four short effect voices share a small wavetable bank.
## Synthesis stays on the main thread, with a bounded amount of work per frame.

const SAMPLE_RATE: float = 22050.0
const BUFFER_SECONDS: float = 0.15
const MAX_FRAMES_PER_TICK: int = 2048
const TABLE_SIZE: int = 2048
const TABLE_MASK: int = TABLE_SIZE - 1
const MAX_EFFECT_VOICES: int = 4
const THEME_NAMES: Array[String] = ["title", "village", "wild", "battle", "gym", "victory"]
const MAJOR_SCALE: Array[int] = [0, 2, 4, 5, 7, 9, 11]
const MINOR_SCALE: Array[int] = [0, 2, 3, 5, 7, 8, 10]

# "A Light to Return To": an original eight-bar melody, in 4/4.
# Vector3 = onset in eighth notes, diatonic degree above D4, eighth-note duration.
# Its opening D5-A4-D5-F#5-E5 is the recurring lantern call. The second four
# bars answer it with an ascending D5-E5-F#5-A5 phrase and a suspended cadence.
# Bar 1: D5(2), A4(1), D5(1), F#5(2), E5(2)
# Bar 2: D5(3), A4(1), B4(2), F#4(2)
# Bar 3: G5(2), F#5(1), D5(1), B4(2), D5(2)
# Bar 4: C#5(2), E5(2), D5(3), rest(1)
# Bar 5: D5(2), E5(1), F#5(1), A5(2), F#5(2)
# Bar 6: G5(3), F#5(1), D5(2), B4(2)
# Bar 7: E5(2), D5(1), B4(1), C#5(2), A4(2)
# Bar 8: C#5(2), E5(2), D5(3), rest(1)
# Harmony: Dmaj7 | Bm7 | Gmaj7 | A7 | D/F# | Gmaj7 | Em7 | A7(sus).
# Battle/gym: Dm | Bbmaj7 | Gm | A7 | Dm/F | Bbmaj7 | Gm | A7.
# A second eight-bar pass adds a higher response in the last two bars, creating
# a sixteen-bar arrangement. Theme changes preserve the composed note rhythm.
const MELODY: Array[Vector3] = [
	Vector3(0, 7, 2), Vector3(2, 4, 1), Vector3(3, 7, 1), Vector3(4, 9, 2), Vector3(6, 8, 2),
	Vector3(8, 7, 3), Vector3(11, 4, 1), Vector3(12, 5, 2), Vector3(14, 2, 2),
	Vector3(16, 10, 2), Vector3(18, 9, 1), Vector3(19, 7, 1), Vector3(20, 5, 2), Vector3(22, 7, 2),
	Vector3(24, 6, 2), Vector3(26, 8, 2), Vector3(28, 7, 3),
	Vector3(32, 7, 2), Vector3(34, 8, 1), Vector3(35, 9, 1), Vector3(36, 11, 2), Vector3(38, 9, 2),
	Vector3(40, 10, 3), Vector3(43, 9, 1), Vector3(44, 7, 2), Vector3(46, 5, 2),
	Vector3(48, 8, 2), Vector3(50, 7, 1), Vector3(51, 5, 1), Vector3(52, 6, 2), Vector3(54, 4, 2),
	Vector3(56, 6, 2), Vector3(58, 8, 2), Vector3(60, 7, 3),
]
const MAJOR_CHORDS: Array = [
	[62, 66, 69, 73], [59, 62, 66, 69], [55, 59, 62, 66], [57, 61, 64, 67],
	[62, 66, 69, 73], [55, 59, 62, 66], [52, 55, 59, 62], [57, 61, 64, 67],
]
const MINOR_CHORDS: Array = [
	[62, 65, 69, 72], [58, 62, 65, 69], [55, 58, 62, 65], [57, 61, 64, 67],
	[62, 65, 69, 72], [58, 62, 65, 69], [55, 58, 62, 65], [57, 61, 64, 67],
]
const MAJOR_BASS: Array[int] = [38, 35, 43, 33, 42, 43, 40, 33]
const MINOR_BASS: Array[int] = [38, 34, 43, 33, 41, 34, 43, 33]
const ARPEGGIO: Array[int] = [0, 2, 1, 2, 3, 2, 1, 2]

var muted: bool = false

var _theme: String = "title"
var _pending_theme: String = ""
var _headless: bool = false
var _initialized: bool = false
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _waves: Dictionary = {}
var _music_voices: Array[Voice] = []
var _effect_voices: Array[Voice] = []
var _effect_cursor: int = 0
var _samples_per_step: float = SAMPLE_RATE * 30.0 / 76.0
var _samples_until_step: float = 0.0
var _step: int = 0
var _phrase: int = 0
var _melody_index: int = 0
var _minor: bool = false
var _active_rhythm: bool = false
var _lead_wave: String = "flute"
var _music_gain: float = 0.0
var _music_target: float = 1.0
var _master_gain: float = 1.0
var _theme_level: float = 0.85
var _step_cooldown: float = 0.0


class Voice extends RefCounted:
	var wave: PackedFloat32Array = PackedFloat32Array()
	var active: bool = false
	var phase: float = 0.0
	var increment: float = 0.0
	var sweep: float = 1.0
	var frame: int = 0
	var delay: int = 0
	var gate: int = 1
	var attack: int = 1
	var decay: int = 1
	var release: int = 1
	var sustain: float = 0.6
	var amplitude: float = 0.0
	var left: float = 0.7071
	var right: float = 0.7071
	var last_value: float = 0.0
	var carry: float = 0.0
	var carry_frames: int = 0

	func trigger(table: PackedFloat32Array, hz: float, duration: float,
			volume: float, pan: float, attack_seconds: float = 0.008,
			release_seconds: float = 0.05, sustain_level: float = 0.62,
			delay_seconds: float = 0.0, end_hz: float = 0.0) -> void:
		# Voice stealing is bounded and keeps a 12 ms release of the old sample.
		# Repeated UI actions therefore cannot introduce a discontinuity.
		carry = last_value if active else 0.0
		carry_frames = int(SAMPLE_RATE * 0.012) if active else 0
		wave = table
		phase = 0.0
		increment = hz * float(TABLE_SIZE) / SAMPLE_RATE
		frame = 0
		delay = maxi(0, int(delay_seconds * SAMPLE_RATE))
		gate = maxi(4, int(duration * SAMPLE_RATE))
		attack = maxi(2, mini(int(attack_seconds * SAMPLE_RATE), int(float(gate) / 3.0)))
		decay = maxi(2, mini(int(0.065 * SAMPLE_RATE), int(float(gate) / 3.0)))
		release = maxi(2, int(release_seconds * SAMPLE_RATE))
		sustain = sustain_level
		amplitude = volume
		left = sqrt((1.0 - clampf(pan, -1.0, 1.0)) * 0.5)
		right = sqrt((1.0 + clampf(pan, -1.0, 1.0)) * 0.5)
		sweep = pow(end_hz / hz, 1.0 / float(gate + release)) if end_hz > 0.0 else 1.0
		active = true


	func sample() -> float:
		if not active:
			return 0.0
		var tail: float = 0.0
		if carry_frames > 0:
			tail = carry * float(carry_frames) / float(int(SAMPLE_RATE * 0.012))
			carry_frames -= 1
		if delay > 0:
			delay -= 1
			last_value = tail
			return tail
		var envelope: float
		if frame < attack:
			envelope = float(frame) / float(attack)
		elif frame < attack + decay:
			envelope = lerpf(1.0, sustain, float(frame - attack) / float(decay))
		elif frame < gate:
			envelope = sustain
		else:
			envelope = sustain * (1.0 - float(frame - gate) / float(release))
		# A 2048-sample periodic wavetable removes trigonometry from the audio loop.
		# Linear interpolation keeps high, quiet flute tones smooth at 22.05 kHz.
		var index: int = int(phase)
		var value: float = lerpf(wave[index & TABLE_MASK], wave[(index + 1) & TABLE_MASK], phase - float(index))
		phase += increment
		if phase >= float(TABLE_SIZE):
			phase -= float(TABLE_SIZE)
		increment *= sweep
		frame += 1
		if frame >= gate + release:
			active = false
		last_value = value * envelope * amplitude + tail
		return last_value


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		set_process(false)
		return
	_build_waves()
	for _index: int in range(4):
		_music_voices.append(Voice.new())
	for _index: int in range(MAX_EFFECT_VOICES):
		_effect_voices.append(Voice.new())
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	stream.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = BUFFER_SECONDS
	_player = AudioStreamPlayer.new()
	_player.name = "LanternwakeSynth"
	_player.stream = stream
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_initialized = _playback != null
	_apply_theme(_theme)
	_master_gain = 0.0 if muted else 1.0
	set_process(_initialized)
	if _initialized:
		_fill_buffer()


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	set_process(false)
	_initialized = false
	# Stop the AudioServer playback before dropping either owning reference.
	# Relying on child destruction alone can retain the generator until shutdown.
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null
	_playback = null
	_player = null


func _process(delta: float) -> void:
	_step_cooldown = maxf(0.0, _step_cooldown - delta)
	_fill_buffer()


func set_theme(theme: String) -> void:
	if not THEME_NAMES.has(theme):
		return
	if not _initialized:
		_theme = theme
		return
	if theme == _theme:
		# A quick return to the current scene cancels an unfinished transition.
		_pending_theme = ""
		_music_target = 1.0
		return
	_pending_theme = theme
	_music_target = 0.0


func set_muted(value: bool) -> void:
	muted = value


func sfx(kind: String) -> void:
	if not _initialized or _headless or muted:
		return
	match kind:
		"confirm":
			_effect_note(81, 0.0, 0.085, "pluck", 0.068)
			_effect_note(86, 0.075, 0.13, "flute", 0.065)
		"step":
			if _step_cooldown <= 0.0:
				_effect_note(36, 0.0, 0.022, "noise", 0.022)
				_step_cooldown = 0.12
		"hit":
			_effect_note(50, 0.0, 0.055, "bass", 0.11, 0.0, 32)
			_effect_note(43, 0.012, 0.045, "noise", 0.038)
		"heal":
			_effect_note(74, 0.0, 0.20, "flute", 0.065, -0.2)
			_effect_note(78, 0.10, 0.20, "flute", 0.065, 0.2)
			_effect_note(81, 0.20, 0.23, "flute", 0.065, -0.1)
			_effect_note(86, 0.30, 0.34, "flute", 0.065, 0.1)
		"capture":
			_effect_note(69, 0.0, 0.10, "pluck", 0.075, -0.3)
			_effect_note(74, 0.11, 0.10, "pluck", 0.075, 0.3)
			_effect_note(78, 0.22, 0.10, "pluck", 0.075, -0.2)
			_effect_note(86, 0.38, 0.40, "flute", 0.085, 0.2)
		"win":
			_effect_note(74, 0.0, 0.16, "pluck", 0.075, -0.2)
			_effect_note(78, 0.13, 0.16, "pluck", 0.075, 0.2)
			_effect_note(81, 0.26, 0.18, "pluck", 0.075, -0.1)
			_effect_note(86, 0.46, 0.48, "flute", 0.085, 0.1)
		"lose":
			_effect_note(69, 0.0, 0.23, "flute", 0.070)
			_effect_note(65, 0.19, 0.25, "flute", 0.065)
			_effect_note(62, 0.41, 0.42, "flute", 0.060)
		"tide_wind":
			# The shore objects answer fragments of the original lantern call.
			_effect_note(74, 0.0, 0.23, "flute", 0.060, -0.25)
			_effect_note(69, 0.19, 0.28, "flute", 0.055, 0.25)
		"tide_water":
			_effect_note(74, 0.0, 0.14, "sine", 0.068, -0.15)
			_effect_note(76, 0.13, 0.23, "sine", 0.062, 0.15)
		"tide_brass":
			_effect_note(78, 0.0, 0.17, "pluck", 0.065, 0.20)
			_effect_note(76, 0.15, 0.26, "pluck", 0.060, -0.20)
		"tide_song":
			# D5-A4-D5-F#5: four notes fit the existing four-voice effect pool.
			_effect_note(74, 0.0, 0.16, "flute", 0.065, -0.20)
			_effect_note(69, 0.16, 0.12, "pluck", 0.060, 0.20)
			_effect_note(74, 0.28, 0.14, "flute", 0.065, -0.10)
			_effect_note(78, 0.42, 0.30, "pluck", 0.065, 0.10)


func _apply_theme(theme: String) -> void:
	_theme = theme
	_pending_theme = ""
	_music_target = 1.0
	_step = 0
	_phrase = 0
	_melody_index = 0
	_samples_until_step = 0.0
	_minor = theme == "battle" or theme == "gym"
	_active_rhythm = _minor or theme == "victory"
	var bpm: float = 92.0
	_theme_level = 0.85
	_lead_wave = "flute"
	match theme:
		"title":
			bpm = 76.0
			_theme_level = 0.80
		"village":
			bpm = 94.0
			_lead_wave = "pluck"
		"wild":
			bpm = 106.0
		"battle":
			bpm = 134.0
			_lead_wave = "lead"
		"gym":
			bpm = 146.0
			_lead_wave = "lead"
			_theme_level = 0.90
		"victory":
			bpm = 116.0
			_lead_wave = "pluck"
	_samples_per_step = SAMPLE_RATE * 30.0 / bpm
	for voice: Voice in _music_voices:
		voice.active = false


func _fill_buffer() -> void:
	if _playback == null:
		return
	var count: int = mini(MAX_FRAMES_PER_TICK, _playback.get_frames_available())
	if count <= 0:
		return
	_playback.push_buffer(_render_frames(count))


func _render_frames(requested_frames: int) -> PackedVector2Array:
	# Device-independent rendering also supports offline validation of actual PCM.
	# The cap belongs here as well, so every caller has the same CPU work limit.
	var count: int = clampi(requested_frames, 0, MAX_FRAMES_PER_TICK)
	var frames: PackedVector2Array = PackedVector2Array()
	frames.resize(count)
	var fade_step: float = 1.0 / (SAMPLE_RATE * 0.11)
	var mute_step: float = 1.0 / (SAMPLE_RATE * 0.025)
	for frame: int in range(count):
		_music_gain = move_toward(_music_gain, _music_target, fade_step)
		_master_gain = move_toward(_master_gain, 0.0 if muted else 1.0, mute_step)
		if _music_gain <= 0.0 and not _pending_theme.is_empty():
			_apply_theme(_pending_theme)
		if _samples_until_step <= 0.0:
			_schedule_step(_step)
			_samples_until_step += _samples_per_step
			_step = (_step + 1) % 64
			if _step == 0:
				_phrase += 1
		_samples_until_step -= 1.0
		var music_left: float = 0.0
		var music_right: float = 0.0
		for voice: Voice in _music_voices:
			if voice.active:
				var value: float = voice.sample()
				music_left += value * voice.left
				music_right += value * voice.right
		var left: float = music_left * _music_gain * _theme_level
		var right: float = music_right * _music_gain * _theme_level
		for voice: Voice in _effect_voices:
			if voice.active:
				var value: float = voice.sample()
				left += value * voice.left
				right += value * voice.right
		# Soft saturation bounds each channel below 0.4 without a hard clip edge.
		left = 0.4 * left / (0.4 + absf(left))
		right = 0.4 * right / (0.4 + absf(right))
		frames[frame] = Vector2(left, right) * _master_gain
	return frames


func _schedule_step(step: int) -> void:
	var bar: int = step >> 3
	var pulse: int = step % 8
	var eighth: float = _samples_per_step / SAMPLE_RATE
	var chords: Array = MINOR_CHORDS if _minor else MAJOR_CHORDS
	var bass_notes: Array[int] = MINOR_BASS if _minor else MAJOR_BASS
	var chord: Array = chords[bar]
	if step == 0:
		_melody_index = 0
	if _melody_index < MELODY.size() and int(MELODY[_melody_index].x) == step:
		var event: Vector3 = MELODY[_melody_index]
		var midi: int = _degree_note(int(event.y))
		if _minor and (bar == 3 or bar == 7) and int(event.y) == 6:
			midi += 1 # Raised leading tone belongs to the dominant A7.
		if _phrase % 2 == 1 and bar >= 6 and _theme != "title":
			midi += 12
		var gate: float = maxf(0.02, event.z * eighth - 0.065)
		_music_voices[0].trigger(_waves[_lead_wave], _hz(midi), gate, 0.105,
			-0.08, 0.014 if _lead_wave == "flute" else 0.007, 0.055,
			0.72 if _lead_wave == "flute" else 0.42)
		_melody_index += 1
	var play_arp: bool = _theme != "title" or pulse % 2 == 0
	if _theme == "wild" and (pulse == 1 or pulse == 5):
		play_arp = false
	if play_arp:
		var arp_note: int = int(chord[ARPEGGIO[pulse]])
		var arp_pan: float = -0.38 if pulse % 2 == 0 else 0.38
		_music_voices[1].trigger(_waves["pluck"], _hz(arp_note), eighth * 0.60,
			0.045 if _active_rhythm else 0.039, arp_pan, 0.006, eighth * 0.27, 0.26)
	var bass_pulse: bool = pulse == 0 or pulse == 4
	if _active_rhythm:
		bass_pulse = bass_pulse or pulse == 3 or pulse == 6
	if bass_pulse:
		var bass_midi: int = bass_notes[bar]
		if pulse == 4:
			bass_midi += 12
		var bass_length: float = eighth * (0.72 if _active_rhythm else 2.9)
		_music_voices[2].trigger(_waves["bass"], _hz(bass_midi), bass_length,
			0.082, 0.02, 0.011, eighth * 0.24, 0.70)
	if _theme == "title":
		return
	if pulse == 0 or pulse == 4:
		_music_voices[3].trigger(_waves["sine"], 105.0, 0.045,
			0.075 if _active_rhythm else 0.035, 0.0, 0.004, 0.08, 0.50, 0.0, 42.0)
	elif pulse == 2 or pulse == 6:
		_music_voices[3].trigger(_waves["noise"], 290.0, 0.030,
			0.030 if _active_rhythm else 0.012, 0.16, 0.004, 0.065, 0.22)
	elif _active_rhythm or (_theme == "wild" and pulse == 7):
		_music_voices[3].trigger(_waves["noise"], 780.0, 0.010,
			0.012, -0.20, 0.002, 0.023, 0.18)


func _effect_note(midi: int, delay: float, duration: float, wave: String,
		volume: float, pan: float = 0.0, end_midi: int = -1) -> void:
	var voice: Voice = _effect_voices[_effect_cursor]
	_effect_cursor = (_effect_cursor + 1) % MAX_EFFECT_VOICES
	voice.trigger(_waves[wave], _hz(midi), duration, volume, pan,
		0.009, 0.065, 0.40, delay, _hz(end_midi) if end_midi >= 0 else 0.0)


func _degree_note(degree: int) -> int:
	var scale: Array[int] = MINOR_SCALE if _minor else MAJOR_SCALE
	return 62 + scale[degree % 7] + int(float(degree) / 7.0) * 12


func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)


func _build_waves() -> void:
	var sine: PackedFloat32Array = PackedFloat32Array()
	var lead: PackedFloat32Array = PackedFloat32Array()
	var flute: PackedFloat32Array = PackedFloat32Array()
	var pluck: PackedFloat32Array = PackedFloat32Array()
	var bass: PackedFloat32Array = PackedFloat32Array()
	var noise: PackedFloat32Array = PackedFloat32Array()
	sine.resize(TABLE_SIZE)
	lead.resize(TABLE_SIZE)
	flute.resize(TABLE_SIZE)
	pluck.resize(TABLE_SIZE)
	bass.resize(TABLE_SIZE)
	noise.resize(TABLE_SIZE)
	var seed_value: int = 73471
	var filtered: float = 0.0
	for index: int in range(TABLE_SIZE):
		var angle: float = TAU * float(index) / float(TABLE_SIZE)
		var fundamental: float = sin(angle)
		sine[index] = fundamental
		lead[index] = 0.81 * fundamental + 0.14 * sin(2.0 * angle) + 0.05 * sin(3.0 * angle)
		flute[index] = 0.94 * fundamental + 0.06 * sin(3.0 * angle)
		pluck[index] = 0.72 * fundamental + 0.19 * sin(2.0 * angle) + 0.09 * sin(3.0 * angle)
		bass[index] = 0.87 * fundamental - 0.097 * sin(3.0 * angle) + 0.033 * sin(5.0 * angle)
		seed_value = (seed_value * 1664525 + 1013904223) & 0x7fffffff
		var white: float = float(seed_value) / 1073741824.0 - 1.0
		filtered = lerpf(filtered, white, 0.22)
		# Taper the periodic noise seam, avoiding a click on table wraparound.
		noise[index] = filtered * sin(PI * float(index) / float(TABLE_SIZE))
	_waves = {"sine": sine, "lead": lead, "flute": flute, "pluck": pluck, "bass": bass, "noise": noise}
