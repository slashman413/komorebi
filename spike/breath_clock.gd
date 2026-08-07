class_name BreathClock
extends Node

## The ONE clock. Single-clock fan-out is the whole point of this spike: haptics,
## audio, and the visual can never drift *relative to each other* because they do
## not each run their own timer — they all read the same tick emitted here.
##
## - `breath_tick` fires every frame with the derived state (for the visual and
##   the drift overlay, which want continuous values).
## - `phase_changed` fires only on phase transitions (for audio cues and haptic
##   pulses, which are event-driven, not per-frame).
##
## We also expose `real_seconds` (wall clock, Time.get_ticks_usec based) alongside
## the delta-accumulated `elapsed`, so the drift overlay can measure how far the
## frame-driven clock diverges from real time at 60 FPS on the Deck.

signal breath_tick(phase: BreathModel.Phase, phase_progress: float, amplitude: float, cycle_time: float)
signal phase_changed(phase: BreathModel.Phase)

var running: bool = true

var _elapsed: float = 0.0 ## Accumulated from frame delta — the authoritative game clock.
var _start_usec: int = 0 ## Wall-clock anchor for drift measurement.
var _last_phase: BreathModel.Phase = BreathModel.Phase.INHALE
var _initialized: bool = false

func _ready() -> void:
	_start_usec = Time.get_ticks_usec()
	_initialized = true

func _process(delta: float) -> void:
	if not running:
		# Keep the wall anchor moving with game time so a pause doesn't register
		# as drift when we resume.
		_start_usec += int(delta * 1_000_000.0)
		return

	_elapsed += delta
	var cycle_time: float = fposmod(_elapsed, BreathModel.get_cycle_sec())
	var phase: BreathModel.Phase = BreathModel.phase_at(cycle_time)
	var amp: float = BreathModel.amplitude(cycle_time)
	var pp: float = BreathModel.phase_progress(cycle_time)

	if phase != _last_phase:
		_last_phase = phase
		phase_changed.emit(phase)

	breath_tick.emit(phase, pp, amp, cycle_time)

## Delta-accumulated clock time in seconds. This is the authoritative game time.
func elapsed() -> float:
	return _elapsed

## Real wall-clock seconds since the clock started (or resumed).
func real_seconds() -> float:
	if not _initialized:
		return 0.0
	return float(Time.get_ticks_usec() - _start_usec) / 1_000_000.0

## Signed drift in seconds: (frame clock) - (wall clock). ~0 means perfect sync.
func drift_seconds() -> float:
	return _elapsed - real_seconds()

func reset() -> void:
	_elapsed = 0.0
	_start_usec = Time.get_ticks_usec()
	_last_phase = BreathModel.Phase.INHALE
