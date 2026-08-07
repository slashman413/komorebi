extends SceneTree

func _init() -> void:
	print("Running Content Linter...")
	var file = FileAccess.open("res://src/locale/locale_table.csv", FileAccess.READ)
	if not file:
		printerr("Failed to open locale_table.csv")
		quit(1)
		return
		
	var headers = file.get_csv_line()
	if headers.size() < 3 or headers[0] != "id" or headers[1] != "en" or headers[2] != "zh":
		printerr("Invalid locale_table.csv headers. Expected id, en, zh")
		quit(1)
		return
		
	var line_count = 1
	var has_error = false
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() <= 1 and row[0].is_empty():
			continue # skip empty trailing line
			
		line_count += 1
		if row.size() != 3:
			printerr("Line ", line_count, " does not have 3 columns: ", row)
			has_error = true
			
		if row[0].is_empty():
			printerr("Line ", line_count, " missing ID.")
			has_error = true
			
	if has_error:
		printerr("Content Linter failed.")
		quit(1)
	else:
		print("Content Linter passed successfully. Checked ", line_count - 1, " keys.")
		quit(0)
