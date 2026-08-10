extends Camera
class_name ClimbCamera

export(NodePath) var climb_system_path
export var follow_speed: float = 5.0

onready var climb_system: ClimbSystem = get_node_or_null(climb_system_path) if not climb_system_path.is_empty() else null

func _ready() -> void:
	if climb_system:
		climb_system.hold_reached.connect(self, "_on_hold_reached")

func _process(delta: float) -> void:
	if climb_system and climb_system.current_hold:
		var target_pos = climb_system.current_hold.global_transform.origin
		# Offset slightly back for read-line camera perspective
		target_pos.z += 5.0
		var t: Transform = global_transform
		t.origin = t.origin.lerp(target_pos, delta * follow_speed)
		global_transform = t

func _on_hold_reached(hold: ClimbHold) -> void:
	pass
