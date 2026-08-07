extends Node
class_name ClimbSystem

signal hold_reached(hold: ClimbHold)

var current_hold: ClimbHold
const MAX_REACH = 2.5

func start_climb(start_hold: ClimbHold):
	current_hold = start_hold
	hold_reached.emit(current_hold)
	
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
		if current_hold.global_position.distance_to(target_hold.global_position) <= MAX_REACH:
			current_hold = target_hold
			hold_reached.emit(current_hold)
			
			if current_hold.is_rest_point:
				_trigger_breathing(current_hold)
			return true
	return false

func _trigger_breathing(hold: ClimbHold):
	# Usually we would inform the game director or breath clock here.
	# For the greybox, we just toggle onboarding if it's the first rest point.
	pass
