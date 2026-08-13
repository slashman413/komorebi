extends SceneTree

func _init() -> void:
	print("--- try JSON.stringify ---")
	var s = JSON.stringify({"a": 1}, "\t")
	print("stringify result: ", s)
	print("--- try JSON.parse ---")
	var result = JSON.parse_string("{\"b\": 2}")
	print("parse result: ", result)
	quit(0)
