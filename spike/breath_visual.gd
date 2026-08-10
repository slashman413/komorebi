class_name BreathVisual
extends Node2D

## Visual breath curve: a circle that expands on inhale, holds, and contracts on
## exhale, with a phase-tinted ring. It is a pure consumer of BreathClock — it
## owns NO timer and reads NO delta. Give it the clock via the exported NodePath
## and it draws whatever the single clock says. This is the "visual breath curve"
## half of the fan-out.

export var clock_path: NodePath
export var min_radius: float = 60.0
export var max_radius: float = 240.0

const COLOR_INHALE: Color = Color(0.50, 0.82, 0.76) # calm teal
const COLOR_HOLD: Color = Color(0.85, 0.78, 0.45)   # warm amber
const COLOR_EXHALE: Color = Color(0.52, 0.60, 0.86) # soft indigo

var _amplitude: float = 0.0
var _phase: int = BreathModel.Phase.INHALE

onready var _clock: BreathClock = get_node(clock_path) as BreathClock

func _ready() -> void:
	if _clock == null:
		push_error("BreathVisual: clock_path did not resolve to a BreathClock.")
		return
	_clock.connect("breath_tick", self, "_on_breath_tick")

func _on_breath_tick(phase: int, _phase_progress: float, amplitude: float, _cycle_time: float) -> void:
	_amplitude = amplitude
	_phase = phase
	update()

func _draw() -> void:
	var radius: float = lerp(min_radius, max_radius, _amplitude)
	var tint: Color = _phase_color(_phase)
	# Filled breathing orb + a brighter guide ring.
	draw_circle(Vector2.ZERO, radius, Color(tint, 0.35))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, tint, 4.0, true)
	draw_arc(Vector2.ZERO, max_radius, 0.0, TAU, 96, Color(1, 1, 1, 0.08), 2.0, true)

func _phase_color(phase: int) -> Color:
	match phase:
		BreathModel.Phase.INHALE:
			return COLOR_INHALE
		BreathModel.Phase.HOLD:
			return COLOR_HOLD
		_:
			return COLOR_EXHALE
