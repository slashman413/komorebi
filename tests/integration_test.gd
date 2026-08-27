extends SceneTree

var frames = 0

func _process(delta):
	frames += 1
	if frames == 2:
		run_integration()
		quit(0)

func run_integration():
	print("== Komorebi Integration Test ==")
	var game_director = root.get_node_or_null("GameDirector")
	var save_service = root.get_node_or_null("SaveService")
	
	if game_director == null or save_service == null:
		printerr("FAIL: Autoloads not found")
		quit(1)
		return
		
	# Setup fake spike and connect
	var BreathClockScript = preload("res://spike/breath_clock.gd")
	var clock = BreathClockScript.new()
	root.add_child(clock)
	clock.cycle_completed.connect(func(sec): game_director.record_session(sec))
	
	var initial_sessions = game_director.save_data.get("progress", {}).get("sessions_completed", 0)
	
	# Run a cycle
	clock._process(4.0)
	clock._process(7.0)
	clock._process(8.0)
	
	var new_sessions = game_director.save_data.get("progress", {}).get("sessions_completed", 0)
	if new_sessions != initial_sessions + 1:
		printerr("FAIL: Sessions not incremented. Expected %d, got %d" % [initial_sessions + 1, new_sessions])
		quit(1)
		return
		
	# Verify persistence
	var loaded = save_service.read_save()
	var loaded_sessions = loaded.get("progress", {}).get("sessions_completed", 0)
	
	if loaded_sessions != new_sessions:
		printerr("FAIL: Saved data not persisted. Expected %d, got %d" % [new_sessions, loaded_sessions])
		quit(1)
		return
		
	print("PASS: Cycle completed event correctly persisted and loaded")
