extends SceneTree

## Dependency-free headless test runner.
##
## Run with:  godot --headless --path . --script res://tests/run_tests.gd
## Exits 0 when every assertion passes, 1 otherwise — so CI gates on the exit code
## with no third-party test framework (GUT etc.) to install or pin.
##
## Tests instantiate the units directly (no autoload singletons, no scene tree)
## so each is validated in isolation, per the project's composition/testability
## rules. SaveService is preloaded as a typed class so its constants and methods
## resolve statically.

const SaveServiceScript := preload("res://autoload/save_service.gd")
const BreathModel := preload("res://spike/breath_model.gd")

var _failures: int = 0
var _checks: int = 0

func _init() -> void:
	print("== Komorebi test run ==")
	_test_breath_model()
	_test_save_service_roundtrip()
	_test_save_service_fixture()

	print("-----------------------------------")
	if _failures == 0:
		print("PASS — %d checks, 0 failures" % _checks)
		quit(0)
	else:
		printerr("FAIL — %d checks, %d failure(s)" % [_checks, _failures])
		quit(1)

# ---- assertion helpers -------------------------------------------------------

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok  : %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)

func _about(a: float, b: float, eps: float = 0.0001) -> bool:
	return abs(a - b) <= eps

func _parse_json(text: String):
	var result = JSON.parse_string(text)
	return result

# ---- BreathModel (pure math) -------------------------------------------------

func _test_breath_model() -> void:
	print("[BreathModel]")
	_check(_about(BreathModel.get_cycle_sec(), 19.0), "cycle length is 4+7+8 = 19s")

	_check(BreathModel.phase_at(0.0) == BreathModel.Phase.INHALE, "t=0 -> INHALE")
	_check(BreathModel.phase_at(3.9) == BreathModel.Phase.INHALE, "t=3.9 -> INHALE")
	_check(BreathModel.phase_at(4.0) == BreathModel.Phase.HOLD, "t=4.0 -> HOLD")
	_check(BreathModel.phase_at(10.9) == BreathModel.Phase.HOLD, "t=10.9 -> HOLD")
	_check(BreathModel.phase_at(11.0) == BreathModel.Phase.EXHALE, "t=11.0 -> EXHALE")
	_check(BreathModel.phase_at(18.99) == BreathModel.Phase.EXHALE, "t=18.99 -> EXHALE")
	_check(BreathModel.phase_at(19.0) == BreathModel.Phase.INHALE, "t=19.0 wraps -> INHALE")

	_check(_about(BreathModel.amplitude(0.0), 0.0), "amplitude at cycle start is 0 (empty)")
	_check(_about(BreathModel.amplitude(4.0), 1.0), "amplitude at inhale->hold is 1 (full)")
	_check(_about(BreathModel.amplitude(7.5), 1.0), "amplitude mid-hold is 1 (full)")
	_check(_about(BreathModel.amplitude(11.0), 1.0), "amplitude at hold->exhale is still 1")
	_check(BreathModel.amplitude(18.5) < 0.2, "amplitude near exhale end is nearly empty")

	# Monotonic rise across inhale, monotonic fall across exhale.
	_check(BreathModel.amplitude(1.0) < BreathModel.amplitude(3.0), "inhale amplitude rises")
	_check(BreathModel.amplitude(12.0) > BreathModel.amplitude(17.0), "exhale amplitude falls")

# ---- SaveService: atomic write + schema versioning --------------------------

func _test_save_service_roundtrip() -> void:
	print("[SaveService round-trip]")
	_reset_user_save()
	var svc := SaveServiceScript.new()

	var data: Dictionary = SaveServiceScript.default_save()
	data["progress"]["sessions_completed"] = 42
	var err: int = svc.write_save(data)
	_check(err == OK, "write_save returns OK")

	# Atomic invariant: the temp file must not survive a successful write.
	_check(not FileAccess.file_exists(SaveServiceScript.TEMP_PATH), "temp file removed after atomic rename")
	_check(FileAccess.file_exists(SaveServiceScript.SAVE_PATH), "save file exists after write")

	var loaded: Dictionary = svc.read_save()
	_check(int(loaded.get("schema_version", -1)) == SaveServiceScript.SCHEMA_VERSION, "loaded schema_version == 1")
	_check(int(loaded["progress"]["sessions_completed"]) == 42, "round-trips written value (42)")

	svc = null

func _test_save_service_fixture() -> void:
	print("[SaveService fixture]")
	_reset_user_save()
	var svc := SaveServiceScript.new()

	# 1) The committed fixture parses and is a valid v1 save.
	var f = FileAccess.open("res://tests/fixtures/save_v1.json", FileAccess.READ)
	_check(f != null, "fixture file opens")
	if f == null:
		svc = null
		return
	var parsed = _parse_json(f.get_as_text())
	f.close()
	_check(typeof(parsed) == TYPE_DICTIONARY, "fixture is a JSON object")
	var fixture: Dictionary = parsed
	_check(int(fixture.get("schema_version", -1)) == 1, "fixture schema_version == 1")
	_check(int(fixture["progress"]["sessions_completed"]) == 7, "fixture sessions_completed == 7")

	# 2) The load path accepts the fixture and preserves its data.
	var out = FileAccess.open(SaveServiceScript.SAVE_PATH, FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(fixture, "	"))
		out.close()
	var loaded: Dictionary = svc.read_save()
	_check(int(loaded.get("schema_version", -1)) == 1, "fixture loads as v1 via read_save")
	_check(int(loaded["progress"]["sessions_completed"]) == 7, "fixture value preserved through load")

	svc = null

func _reset_user_save() -> void:
	for path in [SaveServiceScript.SAVE_PATH, SaveServiceScript.TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
