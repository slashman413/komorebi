extends Node2D

## Breathing Spike root. Pure composition: it centers the visual on the viewport
## and lets the child components wire themselves to the single BreathClock via
## their exported clock paths. No breathing logic lives here.

@onready var _visual: BreathVisual = $BreathVisual

func _ready() -> void:
	_center_visual()
	get_viewport().size_changed.connect(_center_visual)
	
	var clock: BreathClock = get_node_or_null("BreathClock") as BreathClock
	if clock != null:
		clock.cycle_completed.connect(_on_cycle_completed)

func _center_visual() -> void:
	if _visual != null:
		_visual.position = get_viewport_rect().size * 0.5

func _on_cycle_completed(cycle_seconds: float) -> void:
	GameDirector.record_session(cycle_seconds)
