extends CanvasLayer

## Drift overlay — the measurement instrument this spike exists to produce.
##
## It reads BreathClock and shows, live at 60 FPS:
##   - FPS vs. the 60 target,
##   - frame clock (delta-accumulated) vs. wall clock (Time.get_ticks_usec),
##   - the signed drift between them in ms (the number we care about on the Deck),
##   - current phase / amplitude and haptic capability.
##
## If the frame clock and wall clock diverge under load, we see it here instead of
## discovering desynced breathing months later. Toggle with F3.

@export var clock_path: NodePath
@export var haptic_path: NodePath

var _peak_drift_ms: float = 0.0

@onready var _clock: BreathClock = get_node(clock_path) as BreathClock
@onready var _haptics: HapticProbe = get_node(haptic_path) as HapticProbe if not haptic_path.is_empty() else null
@onready var _label: Label = $Panel/Label

func _ready() -> void:
	if _clock == null:
		push_error("DriftOverlay: clock_path did not resolve to a BreathClock.")
		return
	_clock.breath_tick.connect(_on_breath_tick)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and event.keycode == KEY_F3:
		visible = not visible

func _on_breath_tick(phase: int, phase_progress: float, amplitude: float, _cycle_time: float) -> void:
	var drift_ms: float = _clock.drift_seconds() * 1000.0
	if abs(drift_ms) > abs(_peak_drift_ms):
		_peak_drift_ms = drift_ms

	var haptic_label: String = tr("drift_haptics_available") if _haptics != null and _haptics.has_haptics else tr("drift_haptics_unavailable")

	_label.text = "\n".join([
		tr("drift_header"),
		"",
		"%s          : %5.1f%s" % [tr("drift_fps"), Engine.get_frames_per_second(), tr("drift_fps_target")],
		"%s        : %-6s  %3d%%" % [tr("drift_phase"), BreathModel.phase_label(phase), int(phase_progress * 100.0)],
		"%s    : %4.2f" % [tr("drift_amplitude"), amplitude],
		"%s: %8.3f s" % [tr("drift_clock_frame"), _clock.elapsed()],
		"%s : %8.3f s" % [tr("drift_clock_wall"), _clock.real_seconds()],
		"%s        : %+7.2f ms   %s %+7.2f ms)" % [tr("drift_drift"), drift_ms, tr("drift_drift_peak"), _peak_drift_ms],
		"%s      : %s" % [tr("drift_haptics"), haptic_label],
	])
