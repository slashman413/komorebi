extends SceneTree

## Content Linter — static localization hygiene gate (CI).
##
## Run with:  godot --headless --path . --script res://tools/content_linter.gd
## Exits 0 when everything passes, 1 otherwise. CI gates on the exit code.
##
## Checks, in order:
##   1. locale_table.csv structure: header `id,en,zh`, 3 columns per row,
##      unique non-empty keys, no empty en/zh translations.
##   2. Every .tscn `text="..."` value must be a known translation key
##      (scenes must never carry raw player-visible strings).
##   3. Every tr("...") / TranslationServer.translate("...") literal in
##      .gd files must reference a key that exists in the CSV.
##   4. A blocklist of previously-externalized player-visible strings must not
##      appear as raw literals in .gd or .tscn files.

const CSV_PATH := "res://src/locale/locale_table.csv"

var _csv_keys: Array[String] = []
var _errors: int = 0


func _init() -> void:
	print("== Content Linter ==")
	_check_csv()
	_check_tscn_text()
	_check_gd_tr_keys()
	_check_gd_hardcoded_strings()

	print("-----------------------------------")
	if _errors == 0:
		print("PASS — content linter: %d keys, 0 issues" % _csv_keys.size())
		quit(0)
	else:
		printerr("FAIL — content linter: %d issue(s) found" % _errors)
		quit(1)


func _fail(what: String) -> void:
	_errors += 1
	printerr("  FAIL: %s" % what)


# ---- 1. CSV structure -------------------------------------------------------

func _check_csv() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		_fail("cannot open %s" % CSV_PATH)
		return

	var headers := file.get_csv_line()
	if headers.size() < 3 or headers[0] != "id" or headers[1] != "en" or headers[2] != "zh":
		_fail("CSV header must be `id,en,zh`, got: %s" % [headers])
		file.close()
		return

	var line_no := 1
	var seen: Dictionary = {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		line_no += 1
		# get_csv_line returns one empty field for a blank trailing line.
		if row.size() == 1 and row[0].is_empty():
			continue
		if row.size() < 3:
			_fail("CSV line %d has %d column(s), expected 3: %s" % [line_no, row.size(), row])
			continue
		var key := row[0]
		if key.is_empty():
			_fail("CSV line %d has an empty key" % line_no)
			continue
		if seen.has(key):
			_fail("CSV line %d: duplicate key `%s`" % [line_no, key])
			continue
		seen[key] = true
		_csv_keys.append(key)
		if row[1].is_empty():
			_fail("CSV line %d: empty English translation for `%s`" % [line_no, key])
		if row[2].is_empty():
			_fail("CSV line %d: empty Chinese translation for `%s`" % [line_no, key])
	file.close()

	if _csv_keys.is_empty():
		_fail("CSV contains no keys")
	else:
		print("  CSV: %d keys parsed" % _csv_keys.size())


# ---- 2. .tscn text= values --------------------------------------------------

func _check_tscn_text() -> void:
	var files := _collect_files(".tscn")
	var regex := RegEx.new()
	regex.compile('text\\s*=\\s*"([^"]*)"')

	var checked := 0
	for path in files:
		var content := FileAccess.get_file_as_string(path)
		if content.is_empty():
			continue
		for m in regex.search_all(content):
			var value := m.get_string(1)
			if value.is_empty():
				continue
			checked += 1
			if not _csv_keys.has(value):
				_fail("%s: text=\"%s\" is not a translation key" % [path, value])
	print("  .tscn: %d text= values checked across %d scenes" % [checked, files.size()])


# ---- 3. .gd tr() / translate_text() keys ------------------------------------

func _check_gd_tr_keys() -> void:
	var files := _collect_files(".gd")
	var regex_tr := RegEx.new()
	regex_tr.compile('tr\\(\\s*["\']([^"\']+)["\']')
	var regex_ts := RegEx.new()
	regex_ts.compile('TranslationServer\\.(?:translate_text|translate)\\(\\s*["\']([^"\']+)["\']')

	var keys_used := {}
	for path in files:
		if path == "res://tools/content_linter.gd":
			continue  # a linter does not lint itself
		var content := FileAccess.get_file_as_string(path)
		if content.is_empty():
			continue
		for m in regex_tr.search_all(content):
			keys_used[m.get_string(1)] = path
		for m in regex_ts.search_all(content):
			keys_used[m.get_string(1)] = path

	for key in keys_used:
		if not _csv_keys.has(key):
			_fail("%s: tr(\"%s\") references a key missing from %s" % [keys_used[key], key, CSV_PATH])
	print("  .gd: %d unique translation keys referenced" % keys_used.size())


# ---- 4. Hardcoded player-visible strings -------------------------------------

# Strings that used to be hardcoded and are now externalized. If any of these
# appears as a raw literal in code or scenes, the localization regression is
# real. Matches are skipped when the line already routes through tr() /
# translate_text().
const _BLOCKLIST: Array[String] = [
	"Breathe in. Breathe out.",
	"KOMOREBI · Breathing Spike (drift overlay",
	"FPS          :",
	"phase        :",
	"amplitude    :",
	"clock (frame):",
	"clock (wall) :",
	"drift        :",
	"haptics      :",
]


func _check_gd_hardcoded_strings() -> void:
	var files := _collect_files(".gd")
	var regex_tr := RegEx.new()
	regex_tr.compile('tr\\(\\s*["\']')
	var regex_ts := RegEx.new()
	regex_ts.compile('TranslationServer\\.(?:translate_text|translate)\\(\\s*["\']')

	for path in files:
		if path == "res://tools/content_linter.gd":
			continue  # a linter does not lint itself
		var content := FileAccess.get_file_as_string(path)
		if content.is_empty():
			continue
		var lines := content.split("\n")
		for i in lines.size():
			var line := lines[i].strip_edges()
			if line.begins_with("#"):
				continue
			if regex_tr.search(line) != null or regex_ts.search(line) != null:
				continue
			for banned in _BLOCKLIST:
				if banned in line:
					_fail("%s:%d hardcoded player-visible string: %s" % [path, i + 1, line])
	print("  .gd: %d files scanned for hardcoded strings" % files.size())


# ---- helpers ----------------------------------------------------------------

func _collect_files(suffix: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("res://")
	if dir == null:
		_fail("cannot open res://")
		return out
	_walk(dir, "res://", suffix, out)
	return out


func _walk(dir: DirAccess, base: String, suffix: String, out: Array[String]) -> void:
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := base.path_join(name)
		if dir.current_is_dir():
			if name == ".godot":
				name = dir.get_next()
				continue
			var sub := DirAccess.open(full)
			if sub != null:
				_walk(sub, full, suffix, out)
		elif name.ends_with(suffix):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
