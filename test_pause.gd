extends Node

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[Test] Started")
	print("[Test] Initial pause state: ", get_tree().paused)
	
	InputRouter.pause_requested.connect(_on_pause_requested)
	
	var main_scene = load("res://src/level/vertical_slice.tscn")
	var instance = main_scene.instantiate()
	add_child(instance)
	
	# Wait a bit for autoloads and scene to settle
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("[Test] Simulating PAUSE press...")
	var ev = InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("[Test] After PAUSE press, tree paused state: ", get_tree().paused)
	
	ev = InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = false
	Input.parse_input_event(ev)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("[Test] Simulating PAUSE press again to resume...")
	ev = InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("[Test] After second PAUSE press, tree paused state: ", get_tree().paused)
	get_tree().quit()

func _on_pause_requested():
	print("[Test] pause_requested signal received! Current tree paused: ", get_tree().paused)
