extends SceneTree

## Headless gameplay probe: boots the real main scene and drives it with real
## input events (mouse click on a hold, arrow key, held breath) to prove the
## core loop works end to end — not just that the scripts parse.
##
## Run with:  godot --headless --path . --script res://tests/gameplay_probe.gd

var _failures: int = 0
var _checks: int = 0
var _main: Node

func _check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  ok  : %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	print("== Komorebi gameplay probe ==")
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(5)
	_check(_main.state == 0, "boots to the title screen")
	_main._build_mountain(413) # fixed seed: deterministic layout
	await _frames(1)
	_main._start_run()
	await _frames(3)
	_check(_main.state == 1, "Begin the climb -> playing")
	_check(_main.cur_index == 0, "starts at the trailhead")

	# --- mouse: click the highest reachable hold where it is drawn on screen.
	await _frames(2)
	var target: KHold = null
	for h in _main.holds:
		if h.reachable and (target == null or h.position.y < target.position.y):
			target = h
	_check(target != null, "holds within reach glow as reachable")
	if target != null:
		# World -> viewport -> window (the headless window is tiny, so the
		# stretch transform matters).
		var screen: Vector2 = root.get_final_transform() * (_main.get_canvas_transform() * target.position)
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = screen
			ev.global_position = screen
			root.push_input(ev)
			await _frames(1)
		await _frames(40)
		_check(_main.cur_index == target.index, "clicking a glowing hold leaps to it")
		_check(_main.calm < 100.0, "leaping costs calm")

	# --- keyboard: ArrowUp climbs higher.
	var y_before: float = _main.climber.position.y
	var key := InputEventKey.new()
	key.physical_keycode = KEY_UP
	key.keycode = KEY_UP
	key.pressed = true
	root.push_input(key)
	await _frames(1)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)
	await _frames(40)
	_check(_main.climber.position.y < y_before, "ArrowUp climbs higher")

	# --- breathing: stand on the first lantern ledge and do one 4-7-8 breath.
	var ledge: KHold = null
	for h in _main.holds:
		if h.kind == MountainGen.Kind.LEDGE:
			ledge = h
			break
	_main.cur_index = ledge.index
	_main.climber.position = _main._stand_pos(ledge)
	_main._on_landed()
	_main.calm = 40.0
	_check(_main.checkpoint_index == ledge.index, "landing on a ledge lights the lantern checkpoint")
	_check(_main.breath.active, "the breathing orb opens on a ledge")
	Engine.time_scale = 6.0
	var t0: int = Time.get_ticks_msec()
	while _main.breaths == 0 and Time.get_ticks_msec() - t0 < 20000:
		if _main.breath.running and _main.ui.orb.phase == BreathModel.Phase.EXHALE:
			Input.action_release("k_breathe")
		else:
			Input.action_press("k_breathe")
		await process_frame
	Input.action_release("k_breathe")
	Engine.time_scale = 1.0
	_check(_main.breaths == 1, "holding/releasing with the breath completes a cycle")
	_check(_main.calm >= 99.0, "a completed breath restores calm")
	_check(_main.focus_t > 20.0, "a well-matched breath grants long Focus")

	# --- slipping returns you to the lantern.
	var above: KHold = null
	for h in _main.holds:
		if h.position.y < ledge.position.y - 50.0 and not h.is_platform():
			above = h
			break
	_main.cur_index = above.index
	_main.climber.position = above.position
	_main.climber.set_pose_hang()
	_main.focus_t = 0.0
	_main.calm = 0.5
	await _frames(5)
	await _frames(150)
	_check(_main.slips == 1, "running out of calm slips")
	_check(_main.cur_index == ledge.index, "a slip returns you to the last lantern")

	print("-----------------------------------")
	if _failures == 0:
		print("PASS — %d checks, 0 failures" % _checks)
		quit(0)
	else:
		printerr("FAIL — %d checks, %d failure(s)" % [_checks, _failures])
		quit(1)
