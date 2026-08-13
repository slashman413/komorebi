extends SceneTree

func _init() -> void:
	print("--- JSON API probe ---")
	var m = JSON.get_method_list()
	for d in m:
		print("  method: ", d["name"], " args=", d["args"].size())
	print("--- try JSON.stringify ---")
	var s = JSON.stringify({"a": 1}, "\t")
	print("stringify result: ", s)
	print("--- try JSON.parse ---")
	var err = JSON.parse("{\"b\": 2}")
	print("parse err: ", err, " result: ", JSON.result)
	quit(0)
