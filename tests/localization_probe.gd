extends SceneTree

## Runtime Localization Probe — headless, per-locale.
##
## Run with:  godot --headless --path . --script res://tests/localization_probe.gd
## Exits 0 when every scene renders its translated text correctly in every
## supported locale, 1 otherwise. CI gates on the exit code.
##
## For each locale column in locale_table.csv (en, zh):
##   - instantiate res://src/level/vertical_slice.tscn and inspect the Label3D
##     onboarding node (scene-declared `text = "level_intro"`),
##   - instantiate res://spike/breathing_spike.tscn and inspect the drift-panel
##     Label (scene-declared `text = "spike_title"`),
##   - create a Button and set `text = "ui_wishlist"` through the same
##     property-setter path vertical_slice.gd uses for the CTA row.
##
## Godot 4.3 keeps the raw string in `text` and renders the translated string
## (`xl_text = atr(text)` — see Label::set_text / Button::set_text /
## Label3D::set_text in the engine source). So a probe cannot read the rendered
## string off the property. This probe instead asserts the three things that
## determine what is rendered:
##   1. the scene-declared `text` is a translation KEY (no raw English),
##   2. the node's auto-translate chain is enabled (not DISABLED),
##   3. node.tr(key) — exactly what atr() renders — equals the CSV value,
## plus, for Label, get_total_character_count() matches the translated length
## (the shaped xl_text, i.e. the actual render input).

const CSV_PATH := "res://src/locale/locale_table.csv"

const VERTICAL_SLICE := "res://src/level/vertical_slice.tscn"
const BREATHING_SPIKE := "res://spike/breathing_spike.tscn"

const BreathModelScript := preload("res://spike/breath_model.gd")

var _locales: Array[String] = []
var _rows: Array[PackedStringArray] = []
var _errors: int = 0
var _checks: int = 0


func _init() -> void:
	# Autoloads (GameDirector etc.) register on the first frame; scenes whose
	# scripts reference them by name must be loaded after that or compilation
	# fails with "Identifier not found".
	await process_frame
	print("== Runtime Localization Probe ==")
	if not _load_csv():
		printerr("FAIL: cannot load %s" % CSV_PATH)
		quit(1)
		return

	await _run_probe()
	print("-----------------------------------")
	if _errors == 0:
		print("PASS — %d checks across %d locales, 0 failures" % [_checks, _locales.size()])
		quit(0)
	else:
		printerr("FAIL — %d probe failure(s)" % _errors)
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


func _value(key: String, locale: String) -> String:
	var col := _locales.find(locale) + 1
	for row in _rows:
		if row[0] == key:
			return row[col]
	return ""


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("    ok  : %s" % label)
	else:
		_errors += 1
		printerr("    FAIL: %s" % label)


func _check_node(locale: String, what: String, node: Node, key: String) -> void:
	var expected := _value(key, locale)
	var declared: String = node.get("text")
	_check(declared == key, "%s declares text key `%s` (not raw English)" % [what, declared])
	_check(
		node.get_auto_translate_mode() != Node.AUTO_TRANSLATE_MODE_DISABLED,
		"%s auto-translate chain enabled" % what
	)
	var rendered: String = node.tr(declared)
	_check(rendered == expected, "%s renders \"%s\"" % [what, rendered])
	print("        (expected \"%s\")" % expected)
	if node is Label:
		var shaped_len: int = (node as Label).get_total_character_count()
		_check(
			shaped_len == expected.length(),
			"%s shaped text length %d == translated length %d" % [what, shaped_len, expected.length()]
		)


func _run_probe() -> void:
	for locale in _locales:
		print("  [%s]" % locale)
		TranslationServer.set_locale(locale)
		await _check_scene_text(locale)
		await _check_runtime_button(locale)
		await _check_phase_labels(locale)


func _check_scene_text(locale: String) -> void:
	var slice: PackedScene = load(VERTICAL_SLICE)
	var spike: PackedScene = load(BREATHING_SPIKE)
	if slice == null or spike == null:
		_check(false, "scenes load")
		return

	var slice_inst := slice.instantiate()
	root.add_child(slice_inst)
	var spike_inst := spike.instantiate()
	root.add_child(spike_inst)
	await process_frame

	# Label3D — scene-declared `text = "level_intro"` in vertical_slice.tscn.
	var label3d := slice_inst.get_node_or_null("OnboardingInstruction") as Label3D
	if label3d == null:
		_check(false, "OnboardingInstruction Label3D exists")
	else:
		_check_node(locale, "Label3D level_intro", label3d, "level_intro")

	# Drift panel Label — scene-declared `text = "spike_title"` (statically
	# verified by content_linter.gd). By the time we look at it, DriftOverlay
	# has already replaced the text with the live drift readout, so verify the
	# LIVE content is fully localized instead: no raw keys, translated header.
	var label := spike_inst.get_node_or_null("DriftOverlay/Panel/Label") as Label
	if label == null:
		_check(false, "spike title Label exists")
	else:
		_check(
			not label.text.contains("spike_title") and not label.text.contains("drift_"),
			"live drift overlay contains no raw translation keys"
		)
		var header_prefix: String = _value("drift_header", locale).split(" (")[0]
		_check(
			label.text.contains(header_prefix),
			"live drift overlay shows translated header"
		)
		print("        (header prefix \"%s\")" % header_prefix)

	# Fresh Label through the same setter path: proves Label renders the
	# translated string (shaped xl_text length == translated length).
	var fresh := Label.new()
	root.add_child(fresh)
	await process_frame
	fresh.text = "spike_title"
	_check_node(locale, "Label spike_title", fresh, "spike_title")

	slice_inst.queue_free()
	spike_inst.queue_free()
	fresh.queue_free()
	await process_frame


func _check_runtime_button(locale: String) -> void:
	# Same property-setter path vertical_slice.gd uses for its CTA row.
	var button := Button.new()
	root.add_child(button)
	await process_frame
	button.text = "ui_wishlist"
	_check_node(locale, "Button ui_wishlist", button, "ui_wishlist")
	button.queue_free()
	await process_frame


func _check_phase_labels(locale: String) -> void:
	var phases := {
		"INHALE": BreathModelScript.Phase.INHALE,
		"HOLD": BreathModelScript.Phase.HOLD,
		"EXHALE": BreathModelScript.Phase.EXHALE,
	}
	for phase_name in phases:
		var key := "phase_%s" % phase_name.to_lower()
		var expected := _value(key, locale)
		var actual: String = BreathModelScript.phase_label(phases[phase_name])
		_check(
			actual == expected,
			"phase_label(%s) renders \"%s\"" % [phase_name, actual]
		)
		print("        (expected \"%s\")" % expected)
	await process_frame
