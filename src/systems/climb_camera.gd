extends Camera3D
class_name ClimbCamera

@export var climb_system: ClimbSystem
@export var follow_speed: float = 5.0

func _ready() -> void:
	if climb_system:
		climb_system.hold_reached.connect(_on_hold_reached)

func _process(delta: float) -> void:
	if climb_system and climb_system.current_hold:
		var target_pos = climb_system.current_hold.global_position
		# Offset slightly back for read-line camera perspective
		target_pos.z += 5.0
		global_position = global_position.lerp(target_pos, delta * follow_speed)

func _on_hold_reached(hold: ClimbHold) -> void:
	pass
