class_name KBreathSession
extends Node

## The rest-ledge breathing mini-game, built on the same single BreathClock and
## procedural BreathAudio as the original spike — so the orb, the tones and the
## scoring all read one clock and cannot drift.
##
## Rule: hold the button through INHALE and HOLD, let go for EXHALE.
## Accuracy = share of the cycle where your hand matched the breath
## (with a short grace window after each phase change).

signal tick(phase: int, phase_progress: float, amplitude: float, seconds_left: float)
signal finished(accuracy: float)

const GRACE: float = 0.45

var active: bool = false   ## a ledge session is open (armed or running)
var running: bool = false  ## a cycle is in progress
var audio_enabled: bool = true

var _clock: BreathClock
var _audio: BreathAudio
var _good: float = 0.0
var _total: float = 0.0
var _since_change: float = 0.0
var _phase: int = BreathModel.Phase.INHALE

func _ready() -> void:
	_clock = BreathClock.new()
	_clock.name = "BreathClock"
	_clock.running = false
	add_child(_clock)
	_audio = BreathAudio.new()
	_audio.clock_path = NodePath("../BreathClock")
	_audio.volume_db = -6.0
	add_child(_audio)
	_clock.breath_tick.connect(_on_tick)
	_clock.phase_changed.connect(_on_phase_changed)
	_clock.cycle_completed.connect(_on_cycle_completed)

func open() -> void:
	active = true
	running = false
	_clock.running = false

func close() -> void:
	active = false
	running = false
	_clock.running = false

## Call every frame while active with whether the player is "breathing in".
func feed(pressed: bool, delta: float) -> void:
	if not active:
		return
	_audio.enabled = audio_enabled
	if not running:
		if pressed:
			_begin()
		return
	_since_change += delta
	if _since_change > GRACE:
		_total += delta
		var want: bool = _phase != BreathModel.Phase.EXHALE
		if pressed == want:
			_good += delta

func _begin() -> void:
	running = true
	_good = 0.0
	_total = 0.0
	_since_change = 0.0
	_phase = BreathModel.Phase.INHALE
	_clock.reset()
	_clock.running = true
	# The clock only signals *changes*; cue the opening inhale ourselves.
	_audio.enabled = audio_enabled
	_audio._on_phase_changed(BreathModel.Phase.INHALE)

func _on_tick(phase: int, pp: float, amp: float, cycle_time: float) -> void:
	var left: float = 0.0
	match phase:
		BreathModel.Phase.INHALE:
			left = BreathModel.get_inhale_sec() - cycle_time
		BreathModel.Phase.HOLD:
			left = BreathModel.get_inhale_sec() + BreathModel.get_hold_sec() - cycle_time
		_:
			left = BreathModel.get_cycle_sec() - cycle_time
	tick.emit(phase, pp, amp, maxf(left, 0.0))

func _on_phase_changed(phase: int) -> void:
	_phase = phase
	_since_change = 0.0

func _on_cycle_completed(cycle_seconds: float) -> void:
	if not running:
		return
	running = false
	_clock.running = false
	var acc: float = _good / maxf(_total, 0.001)
	if GameDirector:
		GameDirector.record_session(cycle_seconds)
	finished.emit(clampf(acc, 0.0, 1.0))
