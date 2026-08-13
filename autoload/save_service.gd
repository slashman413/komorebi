extends Node

## SaveService (Autoload singleton)
## ------------------------------------------------------------------
## Owns persistence of player data. Two invariants this increment must nail:
##   1. ATOMIC WRITE — write to a temp file, fsync, then rename over the real
##      file. A crash mid-write can never leave a half-written / corrupt save.
##   2. SCHEMA VERSIONING — every save carries `schema_version`. Loads that see
##      an unknown/older version route through migration instead of blindly
##      trusting the shape. Increment 0 ships version 1.
##
## Lifetime: process-global. Holds no gameplay logic — pure data I/O so it can be
## instanced and tested without the tree (see tests/run_tests.gd).

signal save_completed(ok)
signal load_completed(ok, data)

const SCHEMA_VERSION: int = 1
const SAVE_PATH: String = "user://save.json"
const TEMP_PATH: String = "user://save.json.tmp"

## The canonical shape of a fresh v1 save. Keep this in sync with
## tests/fixtures/save_v1.json.
static func default_save() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"settings": {
			"haptics_enabled": true,
			"audio_enabled": true,
			"master_volume_db": 0.0,
		},
		"progress": {
			"sessions_completed": 0,
			"total_breath_seconds": 0.0,
		},
	}

## Atomically persist [param data] to disk. Returns OK or a FAILED error code.
## Emits [signal save_completed].
func write_save(data: Dictionary) -> int:
	var payload: Dictionary = data.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION # never trust the caller's version field

	var tmp = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if tmp == null:
		var open_err = FileAccess.get_open_error()
		push_error("SaveService: cannot open temp file: %s" % _error_name(open_err))
		emit_signal("save_completed", false)
		return FAILED

	tmp.store_string(JSON.stringify(payload, "	"))
	tmp.flush() # push to the OS before we hand off the handle
	tmp.close() # closing fsyncs and releases the handle so rename can succeed on Windows

	# Atomic swap: rename() on the same filesystem is atomic, so a reader either
	# sees the whole old file or the whole new one — never a torn write.
	var dir = DirAccess.open("user://")
	if dir == null:
		var dir_err = DirAccess.get_open_error()
		push_error("SaveService: cannot open user:// dir: %s" % _error_name(dir_err))
		emit_signal("save_completed", false)
		return FAILED

	var err: int = dir.rename(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		push_error("SaveService: atomic rename failed: %s" % _error_name(err))
		emit_signal("save_completed", false)
		return err

	emit_signal("save_completed", true)
	return OK

## Load and validate the save file. Missing file yields a fresh default (ok=true,
## first-run). Corrupt JSON or a bad schema yields ok=false + default data so the
## game can still boot. Emits [signal load_completed].
func read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		var fresh: Dictionary = default_save()
		emit_signal("load_completed", true, fresh)
		return fresh

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		var open_err = FileAccess.get_open_error()
		push_error("SaveService: cannot read save: %s" % _error_name(open_err))
		emit_signal("load_completed", false, default_save())
		return default_save()

	var text: String = file.get_as_text()
	file.close()

	var parsed = _parse_json(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveService: save is not a JSON object; ignoring.")
		emit_signal("load_completed", false, default_save())
		return default_save()

	var data: Dictionary = parsed
	var migrated: Dictionary = _migrate(data)
	var ok: bool = int(migrated.get("schema_version", -1)) == SCHEMA_VERSION
	emit_signal("load_completed", ok, migrated)
	return migrated

## Godot 3.x JSON.parse returns a JSONParseResult; unwrap .result (no JSON.new()).
func _parse_json(text: String):
	var result = JSON.parse_string(text)
	return result

## Godot 3.x has no global error_string(); map the codes this service can hit.
func _error_name(err: int) -> String:
	match err:
		OK: return "OK"
		FAILED: return "FAILED"
		ERR_FILE_NOT_FOUND: return "ERR_FILE_NOT_FOUND"
		ERR_FILE_ALREADY_IN_USE: return "ERR_FILE_ALREADY_IN_USE"
		ERR_CANT_OPEN: return "ERR_CANT_OPEN"
		ERR_CANT_CREATE: return "ERR_CANT_CREATE"
		ERR_FILE_CANT_WRITE: return "ERR_FILE_CANT_WRITE"
		ERR_FILE_CANT_READ: return "ERR_FILE_CANT_READ"
		ERR_INVALID_PARAMETER: return "ERR_INVALID_PARAMETER"
		ERR_UNAUTHORIZED: return "ERR_UNAUTHORIZED"
		_:
			return "ERR_%d" % err

## Forward-migrate an older save to the current schema. Increment 0 only knows
## version 1, so this is a guard + a hook for the next increment. Unknown/newer
## versions are refused (fall back to default) rather than silently mangled.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("schema_version", 0))
	if version == SCHEMA_VERSION:
		return data
	if version <= 0 or version > SCHEMA_VERSION:
		push_warning("SaveService: unknown schema_version %d; using defaults." % version)
		return default_save()
	# Future: step migrations v(n) -> v(n+1) go here.
	return data
