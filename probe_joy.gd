extends SceneTree

func _init() -> void:
	print("--- joypad constant probe v2 ---")
	var names = ClassDB.class_get_integer_constant_list("Input")
	var joy = []
	for n in names:
		if String(n).begins_with("JOY"):
			joy.append(n)
	joy.sort()
	print("Input class JOY* constants:")
	for n in joy:
		print("  ", n)
	print("count: ", joy.size())
	quit(0)
