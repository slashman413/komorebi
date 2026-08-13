extends Node2D

## Breathing Spike root. Pure composition: it centers the visual on the viewport
## and lets the child components wire themselves to the single BreathClock via
## their exported clock paths. No breathing logic lives here.

@onready var _visual: BreathVisual = $BreathVisual

func _ready() -> void:
	_center_visual()
	get_viewport().size_changed.connect(_center_visual)

func _center_visual() -> void:
	if _visual != null:
		_visual.position = get_viewport_rect().size * 0.5
