@tool
class_name ClimbHold
extends Node3D

@export var is_rest_point: bool = false
@export var connected_holds: Array[NodePath] = []

func get_connected_nodes() -> Array[ClimbHold]:
	var nodes: Array[ClimbHold] = []
	for path in connected_holds:
		var node = get_node_or_null(path)
		if node is ClimbHold:
			nodes.append(node)
	return nodes

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	if connected_holds.is_empty():
		warnings.append("Hold is not connected to any other holds.")
	return warnings
