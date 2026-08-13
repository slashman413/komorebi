@tool
class_name ClimbHold
extends Node3D

@export var is_rest_point: bool = false
@export var connected_holds: Array[NodePath] = []

func get_connected_nodes() -> Array:
	var nodes: Array = []
	for path in connected_holds:
		var node = get_node_or_null(path)
		# Godot 3.x: a class file cannot reference its own class_name (cyclic
		# reference at compile time), so compare scripts instead of `is ClimbHold`.
		if node != null and node.get_script() == get_script():
			nodes.append(node)
	return nodes

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if connected_holds.is_empty():
		warnings.append("Hold is not connected to any other holds.")
	return warnings
