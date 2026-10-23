extends SceneTree
## Audio behavior suite; no audio device, imported assets, worker, or output file.
## Run: godot --headless --path . --script tests/test_music.gd
## Full PCM rendering is intentionally bounded: sparse samples of all 128 score
## positions per theme, plus at most 1.3 seconds for each short sound effect.

const MusicSource = preload("res://scripts/music.gd")
const THEMES: Array[String] = ["title", "village", "wild", "battle", "gym", "victory"]
const EFFECTS: Array[String] = ["confirm", "step", "hit", "heal", "capture", "win", "lose"]

var checks: int = 0
var failures: int = 0
var rendered_frames: int = 0
var measured_peak: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(DisplayServer.get_name() == "headless", "Music suite runs without a display or audio player")
	if failures > 0:
		_finish()
		return
	_test_headless_contract()
	_test_buffer_bounds()
	_test_composed_themes()
	_test_effects()
	_test_transitions_and_mute()
	_test_voice_envelope()
	_finish()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _finish() -> void:
	print("MUSIC TESTS: %d checks, %d failures; %d frames, peak %.6f" % [checks, failures, rendered_frames, measured_peak])
	quit(1 if failures > 0 else 0)


func _test_headless_contract() -> void:
	var service: ProceduralMusic = MusicSource.new()
	for theme: String in THEMES:
		service.set_theme(theme)
		_check(service._theme == theme, "Theme can be selected before ready: " + theme)
	for effect: String in EFFECTS:
		service.sfx(effect)
	service.set_muted(true)
	_check(service.muted, "Mute can be set before ready")
	root.add_child(service)
	_check(service.is_node_ready(), "Service reaches ready in the scene tree")
	_check(service.muted and service._theme == "victory", "Ready preserves requested mute and theme")
	_check(not service.is_processing(), "Headless ready disables incremental audio generation")
	_check(service.get_child_count() == 0 and service._player == null and service._playback == null,
		"Headless ready creates no audio player or playback")
	_check(service._waves.is_empty() and service._music_voices.is_empty() and service._effect_voices.is_empty(),
		"Headless ready performs no wavetable or voice allocation")
	service.set_muted(false)
	_check(not service.muted, "Headless service can be unmuted after ready")
	for theme: String in THEMES:
		service.set_theme(theme)
		for effect: String in EFFECTS:
			service.sfx(effect)
		_check(service._theme == theme and not service.is_processing(), "Headless API remains usable: " + theme)
	service.set_theme("unknown")
	service.sfx("unknown")
	_check(service._theme == "victory", "Unknown theme leaves the previous theme intact")
	service.set_muted(true)
	_check(service.muted, "Headless service can be muted after ready")
	service.free()


func _make_synth() -> ProceduralMusic:
	# Exercise production synthesis without entering the tree or opening audio.
	var synth: ProceduralMusic = MusicSource.new()
	synth._build_waves()
	for _index: int in range(4):
		synth._music_voices.append(MusicSource.Voice.new())
	for _index: int in range(MusicSource.MAX_EFFECT_VOICES):
		synth._effect_voices.append(MusicSource.Voice.new())
	synth._initialized = true
	synth._apply_theme("title")
	return synth


func _measure(frames: PackedVector2Array) -> Dictionary:
	var finite: bool = true
	var peak: float = 0.0
	var energy: float = 0.0
	for value: Vector2 in frames:
		finite = finite and is_finite(value.x) and is_finite(value.y)
		peak = maxf(peak, maxf(absf(value.x), absf(value.y)))
		energy += value.length_squared()
	rendered_frames += frames.size()
	measured_peak = maxf(measured_peak, peak)
	return {"finite": finite, "peak": peak, "energy": energy}


func _test_buffer_bounds() -> void:
	var synth: ProceduralMusic = _make_synth()
	_check(synth._render_frames(0).is_empty(), "Zero requested frames produce an empty buffer")
	_check(synth._render_frames(-7).is_empty(), "Negative frame requests produce an empty buffer")
	_check(synth._render_frames(1).size() == 1, "A one-frame request is honored")
	var bounded: PackedVector2Array = synth._render_frames(1000000)
	_check(bounded.size() == 2048, "An oversized request cannot exceed 2,048 frames")
	var metrics: Dictionary = _measure(bounded)
	_check(metrics.finite and metrics.peak < 0.4, "Bounded renderer emits finite, softly limited samples")
	synth.free()


func _test_composed_themes() -> void:
	var synth: ProceduralMusic = _make_synth()
	for theme: String in THEMES:
		synth._apply_theme(theme)
		synth._music_gain = 1.0
		var finite: bool = true
		var peak: float = 0.0
		for phrase: int in range(2):
			synth._phrase = phrase
			for step: int in range(64):
				# Sampling each composed onset avoids rendering six complete tracks.
				synth._schedule_step(step)
				synth._samples_until_step = 100000.0
				var metrics: Dictionary = _measure(synth._render_frames(128))
				finite = finite and bool(metrics.finite)
				peak = maxf(peak, float(metrics.peak))
			_check(synth._melody_index == MusicSource.MELODY.size(), "Every melody event is reachable: %s phrase %d" % [theme, phrase])
		_check(finite and peak < 0.4, "Both phrases render finite, bounded audio: " + theme)
		_check(peak > 0.01, "Composed theme is audible: " + theme)
		_check(synth._music_voices.size() == 4, "Score never allocates additional musical voices: " + theme)
	synth.free()


func _test_effects() -> void:
	var synth: ProceduralMusic = _make_synth()
	synth._music_gain = 0.0
	synth._music_target = 0.0
	for effect: String in EFFECTS:
		synth._samples_until_step = 100000.0
		synth._step_cooldown = 0.0
		synth.sfx(effect)
		_check(_any_effect_active(synth), "Sound effect starts a bounded voice: " + effect)
		var finite: bool = true
		var peak: float = 0.0
		for _block: int in range(14):
			var metrics: Dictionary = _measure(synth._render_frames(2048))
			finite = finite and bool(metrics.finite)
			peak = maxf(peak, float(metrics.peak))
		_check(finite and peak < 0.4 and peak > 0.001, "Effect is audible, finite, and limited: " + effect)
		_check(not _any_effect_active(synth), "Effect including delayed notes fully releases: " + effect)
	synth.set_muted(true)
	synth.sfx("heal")
	_check(not _any_effect_active(synth), "Muted effects do not queue delayed notes")
	synth.set_muted(false)
	for index: int in range(32):
		synth.sfx(EFFECTS[index % EFFECTS.size()])
		var metrics: Dictionary = _measure(synth._render_frames(64))
		_check(metrics.finite and metrics.peak < 0.4, "Rapid overlapping effects stay finite and limited")
	_check(synth._effect_voices.size() == 4, "Repeated actions never grow the effect voice pool")
	synth.free()


func _any_effect_active(synth: ProceduralMusic) -> bool:
	for voice: ProceduralMusic.Voice in synth._effect_voices:
		if voice.active:
			return true
	return false


func _test_transitions_and_mute() -> void:
	var synth: ProceduralMusic = _make_synth()
	synth._music_gain = 1.0
	_measure(synth._render_frames(1024))
	synth.set_theme("battle")
	_check(synth._theme == "title" and synth._pending_theme == "battle", "A theme request preserves current music until its fade")
	for _block: int in range(3):
		var metrics: Dictionary = _measure(synth._render_frames(2048))
		_check(metrics.finite and metrics.peak < 0.4, "Transition renders finite, bounded samples")
	_check(synth._theme == "battle" and synth._pending_theme.is_empty() and is_equal_approx(synth._music_gain, 1.0),
		"Theme transition reaches its requested scene after fade out and fade in")
	synth.set_theme("gym")
	synth.set_theme("battle")
	_check(synth._pending_theme.is_empty() and synth._music_target == 1.0, "Returning to the current theme cancels a pending switch")
	synth.set_muted(true)
	var quiet: PackedVector2Array = synth._render_frames(1024)
	_measure(quiet)
	_check(synth.muted and is_zero_approx(synth._master_gain), "Mute ramp reaches silence within 25 ms")
	_check(quiet[-1] == Vector2.ZERO and quiet[-128] == Vector2.ZERO, "Muted PCM reaches actual digital silence")
	synth.set_muted(false)
	var audible: Dictionary = _measure(synth._render_frames(1024))
	_check(not synth.muted and is_equal_approx(synth._master_gain, 1.0) and audible.energy > 0.001,
		"Unmuting restores the existing score through a ramp")
	synth.free()


func _test_voice_envelope() -> void:
	var synth: ProceduralMusic = _make_synth()
	var voice: ProceduralMusic.Voice = MusicSource.Voice.new()
	voice.trigger(synth._waves["sine"], 440.0, 0.03, 0.15, 0.0, 0.004, 0.01, 0.5)
	_check(voice.sample() == 0.0, "A fresh note starts at zero amplitude")
	var finite: bool = true
	var peak: float = 0.0
	for _frame: int in range(1000):
		var value: float = voice.sample()
		finite = finite and is_finite(value)
		peak = maxf(peak, absf(value))
	_check(finite and peak > 0.05 and peak <= 0.15, "Voice envelope preserves finite, bounded oscillation")
	_check(not voice.active and voice.sample() == 0.0, "A completed release deactivates the voice and returns silence")
	synth.free()
