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

signal save_completed(ok: bool)
signal load_completed(ok: bool, data: Dictionary)

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
func write_save(data: Dictionary) -> Error:
	var payload: Dictionary = data.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION # never trust the caller's version field

	var tmp: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if tmp == null:
		push_error("SaveService: cannot open temp file: %s" % error_string(FileAccess.get_open_error()))
		save_completed.emit(false)
		return FAILED

	tmp.store_string(JSON.stringify(payload, "\t"))
	tmp.flush() # push to the OS before we hand off the handle
	tmp.close() # closing fsyncs and releases the handle so rename can succeed on Windows

	# Atomic swap: rename() on the same filesystem is atomic, so a reader either
	# sees the whole old file or the whole new one — never a torn write.
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("SaveService: cannot open user:// dir")
		save_completed.emit(false)
		return FAILED

	var err: Error = dir.rename(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("SaveService: atomic rename failed: %s" % error_string(err))
		save_completed.emit(false)
		return err

	save_completed.emit(true)
	return OK

## Load and validate the save file. Missing file yields a fresh default (ok=true,
## first-run). Corrupt JSON or a bad schema yields ok=false + default data so the
## game can still boot. Emits [signal load_completed].
func read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		var fresh: Dictionary = default_save()
		load_completed.emit(true, fresh)
		return fresh

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveService: cannot read save: %s" % error_string(FileAccess.get_open_error()))
		load_completed.emit(false, default_save())
		return default_save()

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveService: save is not a JSON object; ignoring.")
		load_completed.emit(false, default_save())
		return default_save()

	var data: Dictionary = parsed
	var migrated: Dictionary = _migrate(data)
	var ok: bool = int(migrated.get("schema_version", -1)) == SCHEMA_VERSION
	load_completed.emit(ok, migrated)
	return migrated

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
