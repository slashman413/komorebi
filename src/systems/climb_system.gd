extends Node
class_name ClimbSystem

signal hold_reached(hold)
signal climb_finished()

var current_hold: ClimbHold
const MAX_REACH = 2.5

func _ready():
	if InputRouter:
		InputRouter.confirm_pressed.connect(_on_confirm)

func start_climb(start_hold: ClimbHold):
	current_hold = start_hold
	emit_signal("hold_reached", current_hold)
	
	if start_hold.is_rest_point:
		_trigger_breathing(start_hold)

func try_reach(target_hold: ClimbHold) -> bool:
	if current_hold == null:
		return false
		
	var is_connected = false
	var target_nodes = current_hold.get_connected_nodes()
	for node in target_nodes:
		if node == target_hold:
			is_connected = true
			break
			
	if not is_connected:
		# Also check reverse connection
		target_nodes = target_hold.get_connected_nodes()
		for node in target_nodes:
			if node == current_hold:
				is_connected = true
				break

	if is_connected:
		if current_hold.global_transform.origin.distance_to(target_hold.global_transform.origin) <= MAX_REACH:
			current_hold = target_hold
			emit_signal("hold_reached", current_hold)
			
			if current_hold.is_rest_point:
				_trigger_breathing(current_hold)
				
			if current_hold.get_connected_nodes().is_empty():
				emit_signal("climb_finished")
			return true
	return false

func _trigger_breathing(hold: ClimbHold):
	# Usually we would inform the game director or breath clock here.
	pass

func _on_confirm():
	if current_hold:
		var target_nodes = current_hold.get_connected_nodes()
		if target_nodes.size() > 0:
			try_reach(target_nodes[0])
