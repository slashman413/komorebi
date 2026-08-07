extends SceneTree

const ClimbSystemScript = preload("res://src/systems/climb_system.gd")

var _failures: int = 0
var _checks: int = 0

func _init() -> void:
	print("== HoldGraph Validator ==")
	var scene = load("res://src/level/greybox_wall.tscn")
	if not scene:
		printerr("FAIL: Could not load res://src/level/greybox_wall.tscn")
		quit(1)
		return
		
	var root = scene.instantiate()
	_validate_graph(root)
	
	print("-----------------------------------")
	if _failures == 0:
		print("PASS — %d checks, 0 failures" % _checks)
		quit(0)
	else:
		printerr("FAIL — %d checks, %d failure(s)" % [_checks, _failures])
		quit(1)

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok  : %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)

func _validate_graph(root: Node) -> void:
	var holds = _find_all_holds(root)
	_check(holds.size() > 0, "Scene contains at least one ClimbHold")
	
	var rest_points = 0
	for hold in holds:
		if hold.is_rest_point:
			rest_points += 1
			
		var connections = hold.get_connected_nodes()
		if connections.is_empty():
			# It's possible for an endpoint to have no OUTGOING connections,
			# but we should ensure at least one incoming or outgoing if we want a fully connected graph.
			pass
			
		for target in connections:
			var dist = hold.global_position.distance_to(target.global_position)
			_check(dist <= 2.5, "Hold %s connected to %s is within MAX_REACH (dist: %.2f)" % [hold.name, target.name, dist])

	_check(rest_points >= 2, "Scene contains at least 2 rest points (found %d)" % rest_points)

const ClimbHold = preload("res://src/nodes/climb_hold.gd")

func _find_all_holds(node: Node) -> Array:
	var result = []
	if node is ClimbHold:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_holds(child))
	return result
