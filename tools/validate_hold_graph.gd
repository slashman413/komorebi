extends SceneTree

const ClimbSystemScript = preload("res://src/systems/climb_system.gd")

var _failures: int = 0
var _checks: int = 0

func _init() -> void:
	print("== HoldGraph Validator ==")
	var scene_path = "res://src/level/greybox_wall.tscn"
	var scene = load(scene_path)
	if scene == null:
		printerr("Could not load %s" % scene_path)
		_failures += 1
		quit(1)
		return
		
	var scene_root = scene.instantiate()
	self.root.add_child(scene_root)
	_validate_graph(scene_root)
	scene_root.queue_free()
	
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

const ClimbHoldScript := preload("res://src/nodes/climb_hold.gd")
const CLIMB_SPEED_UNITS_PER_SEC = 1.2
const MAX_BREATH_TIME_SEC = 19.0 # 4+7+8

func _validate_graph(root: Node) -> void:
	var holds = _find_all_holds(root)
	_check(holds.size() > 0, "Scene contains at least one ClimbHold")
	
	var rest_nodes = []
	for hold in holds:
		if hold.is_rest_point:
			rest_nodes.append(hold)
			
		var connections = hold.get_connected_nodes()
		for target in connections:
			var dist = hold.global_transform.origin.distance_to(target.global_transform.origin)
			_check(dist <= 2.5, "Hold %s connected to %s is within MAX_REACH (dist: %.2f)" % [hold.name, target.name, dist])

	_check(rest_nodes.size() >= 2, "Scene contains at least 2 rest points (found %d)" % rest_nodes.size())

	var max_distance = CLIMB_SPEED_UNITS_PER_SEC * MAX_BREATH_TIME_SEC
	for rest_node in rest_nodes:
		var reachable_rests = _find_paths_to_other_rests(rest_node)
		for target_rest in reachable_rests:
			var path_dist = reachable_rests[target_rest]
			_check(path_dist <= max_distance, 
				"Path from %s to %s is possible within a breath cycle (dist: %.2f, max: %.2f)" % 
				[rest_node.name, target_rest.name, path_dist, max_distance])

func _find_paths_to_other_rests(start_node: Node) -> Dictionary:
	var distances = {}
	var unvisited = []
	distances[start_node] = 0.0
	unvisited.append(start_node)
	
	var reachable_rests = {}
	
	while unvisited.size() > 0:
		var current_node = null
		var current_dist = INF
		var current_idx = -1
		
		for i in range(unvisited.size()):
			var node = unvisited[i]
			if distances.has(node) and distances[node] < current_dist:
				current_dist = distances[node]
				current_node = node
				current_idx = i
				
		if current_node == null:
			break
			
		unvisited.remove_at(current_idx)
		
		if current_node != start_node and current_node.is_rest_point:
			reachable_rests[current_node] = current_dist
			continue
			
		var connections = current_node.get_connected_nodes()
		for target in connections:
			var edge_dist = current_node.global_transform.origin.distance_to(target.global_transform.origin)
			var new_dist = current_dist + edge_dist
			
			if not distances.has(target) or new_dist < distances[target]:
				distances[target] = new_dist
				if not unvisited.has(target):
					unvisited.append(target)
					
	return reachable_rests

func _find_all_holds(node: Node) -> Array:
	var result = []
	if node is ClimbHoldScript:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_holds(child))
	return result
