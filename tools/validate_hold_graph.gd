extends SceneTree
## HoldGraph Validator — headless validation of climbing hold graphs.
##
## Timing contract (why this is safe):
##   Distances are computed from `global_transform` ONLY after the instanced
##   scene has been added to the SceneTree (see the _process() staging below).
##   A detached subtree has no live transforms, so any pre-tree measurement
##   collapses every distance to 0.00 — which silently passes every
##   reachability / breath-cycle check and conceals unreachable-hold
##   soft-locks. We never measure before the tree exists:
##     * frame 1: scene_root is added to the tree (nodes become
##       is_inside_tree() == true);
##     * frame 2: every check runs against valid global_transform values.
##   As a belt-and-braces guard, each edge is also required to have a
##   non-trivial distance (> MIN_MEANINGFUL_DIST), so a future regression to
##   pre-tree math fails loudly instead of passing vacuously.
##
## Usage:
##   godot --headless --path . --script res://tools/validate_hold_graph.gd
##   godot --headless --path . --script res://tools/validate_hold_graph.gd -- <scene_path>
##
## Exit code: 0 = all checks passed, 1 = any check failed.

const ClimbHoldScript = preload("res://src/nodes/climb_hold.gd")

const DEFAULT_SCENE_PATH := "res://src/level/greybox_wall.tscn"
const MAX_REACH := 2.5
const MIN_MEANINGFUL_DIST := 0.01
const WORLD_ORIGIN_TOLERANCE := 0.001
const CLIMB_SPEED_UNITS_PER_SEC = 1.2
const MAX_BREATH_TIME_SEC = 19.0 # 4+7+8

const _STAGE_ADD_TO_TREE := 0
const _STAGE_VALIDATE := 1
const _STAGE_DONE := 2

var _failures: int = 0
var _checks: int = 0
var _stage: int = _STAGE_ADD_TO_TREE
var _scene_path: String = DEFAULT_SCENE_PATH
var _scene_root: Node3D = null

func _init() -> void:
	print("== HoldGraph Validator ==")
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() > 0:
		_scene_path = user_args[0]
	print("Scene: %s" % _scene_path)

	var scene: PackedScene = load(_scene_path)
	if scene == null:
		printerr("Could not load %s" % _scene_path)
		_failures += 1
		_stage = _STAGE_DONE
		return
	_scene_root = scene.instantiate() as Node3D
	if _scene_root == null:
		printerr("%s does not have a Node3D root" % _scene_path)
		_failures += 1
		_stage = _STAGE_DONE

# MainLoop callback: once per frame. Returning true ends the main loop.
func _process(_delta: float) -> bool:
	match _stage:
		_STAGE_ADD_TO_TREE:
			# Frame 1 — put the scene into the tree. From the next frame on
			# every node is_inside_tree() and global_transform is live.
			root.add_child(_scene_root)
			_stage = _STAGE_VALIDATE
			return false
		_STAGE_VALIDATE:
			# Frame 2 — all transforms are valid; measure and report.
			_validate_graph(_scene_root)
			_scene_root.queue_free()
			_stage = _STAGE_DONE
			_finish()
			return true
		_:
			return true

func _finish() -> void:
	print("-----------------------------------")
	if _failures == 0:
		print("PASS — %d checks, 0 failures" % _checks)
		quit(0)
	else:
		printerr("FAIL — %d checks, %d failure(s)" % [_checks, _failures])
		quit(1)

# World-space origin of a Node3D, composed from local transforms up to the
# highest Node3D ancestor. Kept as a cross-check: it must agree with the live
# tree global_transform (WORLD_ORIGIN_TOLERANCE), proving both measurement
# paths agree on the same coordinates.
func _world_origin(node: Node3D) -> Vector3:
	var t := Transform3D()
	var n: Node = node
	while n != null and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t.origin

# Primary distance source — valid only while the scene is inside the tree.
func _distance_between(a: Node3D, b: Node3D) -> float:
	return a.global_transform.origin.distance_to(b.global_transform.origin)

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok  : %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)

func _validate_graph(root: Node) -> void:
	# This is the whole point of the refactor: refuse to validate a scene that
	# is not inside the tree, because pre-tree global_transform reads 0.00.
	_check(root.is_inside_tree(), "Validated scene is inside the tree (global transforms are live)")

	var holds := _find_all_holds(root)
	_check(holds.size() > 0, "Scene contains at least one ClimbHold")

	var rest_nodes: Array[Node3D] = []
	# Incoming edges per hold, so a terminal rest (end of a climb route, e.g.
	# greybox_wall's Hold5) still counts as connected to the graph.
	var incoming := {}
	for hold in holds:
		for target in hold.get_connected_nodes():
			if not incoming.has(target):
				incoming[target] = []
			incoming[target].append(hold)

	for hold in holds:
		if hold.is_rest_point:
			rest_nodes.append(hold)

		var connections := hold.get_connected_nodes()
		for target in connections:
			var dist := _distance_between(hold, target)
			_check(dist > MIN_MEANINGFUL_DIST,
				"Hold %s connected to %s has a non-trivial distance (got %.2f — pre-tree measurement?)" %
				[hold.name, target.name, dist])
			_check(dist <= MAX_REACH,
				"Hold %s connected to %s is within MAX_REACH (dist: %.2f)" % [hold.name, target.name, dist])
			var composed_dist := _world_origin(hold).distance_to(_world_origin(target))
			_check(absf(composed_dist - dist) <= WORLD_ORIGIN_TOLERANCE,
				"Composed world origin matches tree global_transform for %s -> %s (composed: %.3f, tree: %.3f)" %
				[hold.name, target.name, composed_dist, dist])

	_check(rest_nodes.size() >= 2, "Scene contains at least 2 rest points (found %d)" % rest_nodes.size())

	var max_distance := CLIMB_SPEED_UNITS_PER_SEC * MAX_BREATH_TIME_SEC
	for rest_node in rest_nodes:
		# A rest point with no incident edges at all is isolated: the player can
		# never leave it and never arrive at it — an unreachable hold that the
		# old 0.00-distance bug would have silently papered over. A terminal
		# rest (incoming edge only) is fine — it is the end of a climb route.
		var has_edge: bool = rest_node.get_connected_nodes().size() > 0 or incoming.has(rest_node)
		_check(has_edge,
			"Rest point %s is connected to the hold graph (has at least one connection)" % rest_node.name)

		var reachable_rests := _find_paths_to_other_rests(rest_node)
		for target_rest in reachable_rests:
			var path_dist: float = reachable_rests[target_rest]
			_check(path_dist <= max_distance,
				"Path from %s to %s is possible within a breath cycle (dist: %.2f, max: %.2f)" %
				[rest_node.name, target_rest.name, path_dist, max_distance])

func _find_paths_to_other_rests(start_node: Node) -> Dictionary:
	var distances := {}
	var unvisited := []
	distances[start_node] = 0.0
	unvisited.append(start_node)

	var reachable_rests := {}

	while unvisited.size() > 0:
		var current_node = null
		var current_dist := INF
		var current_idx := -1

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
			var edge_dist := _distance_between(current_node, target)
			var new_dist := current_dist + edge_dist

			if not distances.has(target) or new_dist < distances[target]:
				distances[target] = new_dist
				if not unvisited.has(target):
					unvisited.append(target)

	return reachable_rests

func _find_all_holds(node: Node) -> Array[ClimbHoldScript]:
	var result: Array[ClimbHoldScript] = []
	if node is ClimbHoldScript:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_holds(child))
	return result
