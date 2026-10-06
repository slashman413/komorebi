class_name KBreathOrb
extends Control

## The breathing guide drawn on the HUD: an orb that swells with the breath,
## a phase ring that fills over the current phase, and a halo that turns
## mint when your hand matches the breath (warm red when it doesn't).

const COLOR_INHALE := Color(0.50, 0.82, 0.76)
const COLOR_HOLD := Color(0.95, 0.82, 0.45)
const COLOR_EXHALE := Color(0.56, 0.64, 0.92)

var phase: int = BreathModel.Phase.INHALE
var phase_progress: float = 0.0
var amplitude: float = 0.0
var matching: bool = true
var armed: bool = true   ## waiting for the first press
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var max_r: float = minf(size.x, size.y) * 0.46
	var min_r: float = max_r * 0.32
	var tint: Color = _tint()
	var amp: float = amplitude
	if armed:
		amp = 0.08 + 0.06 * sin(_t * 2.0)
	var r: float = lerpf(min_r, max_r * 0.86, amp)

	# Dark disc behind for legibility over any sky.
	draw_circle(c, max_r + 8.0, Color(0.03, 0.08, 0.12, 0.45))
	# Guide ring = full breath.
	draw_arc(c, max_r * 0.86, 0.0, TAU, 96, Color(1, 1, 1, 0.18), 2.0, true)
	# Feedback halo.
	var halo: Color = Color(0.5, 1.0, 0.8, 0.35) if matching else Color(1.0, 0.45, 0.4, 0.4)
	if armed:
		halo = Color(1, 1, 1, 0.15)
	draw_circle(c, r + 10.0, halo)
	draw_circle(c, r, Color(tint.r, tint.g, tint.b, 0.75))
	draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.18))
	# Phase progress ring.
	if not armed:
		draw_arc(c, max_r, -PI * 0.5, -PI * 0.5 + TAU * phase_progress, 96, tint, 8.0, true)
		draw_arc(c, max_r, 0.0, TAU, 96, Color(1, 1, 1, 0.12), 8.0, true)

func _tint() -> Color:
	match phase:
		BreathModel.Phase.INHALE:
			return COLOR_INHALE
		BreathModel.Phase.HOLD:
			return COLOR_HOLD
		_:
			return COLOR_EXHALE
