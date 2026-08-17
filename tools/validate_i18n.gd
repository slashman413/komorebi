extends SceneTree

## i18n Runtime Validation — headless.
##
## Run with:  godot --headless --path . --script res://tools/validate_i18n.gd
## Exits 0 when every key resolves to its CSV value in every supported locale.
##
## This validates the *imported* .translation resources (what the game actually
## loads at runtime via project.godot [internationalization]) against the
## source-of-truth locale_table.csv. A key that resolves to its own name means
## the translation did not load — that is treated as a failure, not a pass.
##
## Supported locales are the CSV header columns after `id`. The game must
## register a .translation for each of them in project.godot.

const CSV_PATH := "res://src/locale/locale_table.csv"

var _errors: int = 0
var _rows: Array[PackedStringArray] = []
var _locales: Array[String] = []


func _init() -> void:
	print("== i18n Runtime Validation ==")
	if not _load_csv():
		printerr("FAIL: cannot load %s" % CSV_PATH)
		quit(1)
		return

	print("  Supported locales: ", _locales)
	var loaded := TranslationServer.get_loaded_locales()
	print("  Loaded translations: ", loaded)

	for locale in _locales:
		if not loaded.has(locale):
			printerr("  FAIL: locale `%s` has CSV data but no loaded .translation" % locale)
			_errors += 1

	for locale in _locales:
		_check_locale(locale)

	print("-----------------------------------")
	if _errors == 0:
		print("PASS — %d keys × %d locales all resolve" % [_rows.size(), _locales.size()])
		quit(0)
	else:
		printerr("FAIL — %d i18n issue(s)" % _errors)
		quit(1)


func _load_csv() -> bool:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return false
	var headers := file.get_csv_line()
	if headers.size() < 3 or headers[0] != "id":
		file.close()
		return false
	for i in range(1, headers.size()):
		_locales.append(headers[i])
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		if row.size() >= 3 and not row[0].is_empty():
			_rows.append(row)
	file.close()
	return true


func _check_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
	print("  [%s] resolving %d keys..." % [locale, _rows.size()])
	var col := _locales.find(locale) + 1
	for row in _rows:
		var key := row[0]
		var expected := row[col]
		var actual: String = TranslationServer.translate(key)
		if actual == key:
			printerr("  FAIL [%s] `%s` did not translate (resolves to its own key)" % [locale, key])
			_errors += 1
		elif actual != expected:
			printerr("  FAIL [%s] `%s` = \"%s\", expected \"%s\"" % [locale, key, actual, expected])
			_errors += 1
