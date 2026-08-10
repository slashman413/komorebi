class_name HapticProbe
extends Node

## Capability-probed haptics. Godot has no direct "does this pad support rumble?"
## query, so we probe by connectivity: if a joypad is connected we assume rumble
## (the Steam Deck's built-in controller reports as device 0) and expose
## `has_haptics`. Everything degrades gracefully to silence when no pad is present
## — headless CI, keyboard-only, etc. — so the spike never hard-depends on haptics.
##
## Event-driven: it listens to BreathClock.phase_changed (NOT per frame), so the
## rumble pattern is locked to the same clock as the visual and audio.

export var clock_path: NodePath

var has_haptics: bool = false
var enabled: bool = true

var _device: int = -1

onready var _clock: BreathClock = get_node(clock_path) as BreathClock

func _ready() -> void:
	_probe()
	Input.connect("joy_connection_changed", self, "_on_joy_connection_changed")
	if _clock != null:
		_clock.connect("phase_changed", self, "_on_phase_changed")
	else:
		push_error("HapticProbe: clock_path did not resolve to a BreathClock.")

func _probe() -> void:
	var pads: PoolIntArray = Input.get_connected_joypads()
	if pads.empty():
		has_haptics = false
		_device = -1
	else:
		_device = pads[0]
		has_haptics = true
	print("[HapticProbe] has_haptics=%s device=%d" % [has_haptics, _device])

func _on_joy_connection_changed(_device_id: int, _connected: bool) -> void:
	_probe()

func _on_phase_changed(phase: int) -> void:
	# Distinct, gentle rumble signature per phase so the body can follow the breath
	# without looking at the screen. Durations align with each phase length.
	match phase:
		BreathModel.Phase.INHALE:
			pulse(0.15, 0.25, BreathModel.get_inhale_sec())
		BreathModel.Phase.HOLD:
			pulse(0.05, 0.05, 0.25) # brief "hold now" tap, then quiet
		BreathModel.Phase.EXHALE:
			pulse(0.25, 0.10, BreathModel.get_exhale_sec())

## Fire a rumble if we have (and want) haptics. No-op otherwise.
func pulse(weak: float, strong: float, duration: float) -> void:
	if not enabled or not has_haptics or _device < 0:
		return
	Input.start_joy_vibration(_device, clamp(weak, 0.0, 1.0), clamp(strong, 0.0, 1.0), duration)

func stop() -> void:
	if _device >= 0:
		Input.stop_joy_vibration(_device)
