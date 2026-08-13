extends Node

## GameDirector (Autoload singleton)
## ------------------------------------------------------------------
## The top-level coordinator / service locator. It owns the coarse app state
## machine and is the one place that wires the other services together on boot.
## It deliberately contains NO breathing/gameplay math — that lives in components
## and the pure BreathModel. Loaded last (see project.godot [autoload]) so every
## other service exists when it runs.

signal state_changed(new_state)

enum State { BOOT, SPIKE, PAUSED }

var state = State.BOOT
var save_data: Dictionary = {}

func _ready() -> void:
	# Load persisted data through SaveService (autoload, loaded before us).
	save_data = SaveService.read_save()
	print("[GameDirector] boot. schema_version=%d sessions=%d" % [
		int(save_data.get("schema_version", -1)),
		int(save_data.get("progress", {}).get("sessions_completed", 0)),
	])

	# Wire cross-cutting input intents once, centrally.
	InputRouter.pause_requested.connect(_on_pause_requested)

	_set_state(State.SPIKE)

func _set_state(new_state) -> void:
	if new_state == state:
		return
	state = new_state
	emit_signal("state_changed", state)

func _on_pause_requested() -> void:
	_set_state(State.PAUSED if state != State.PAUSED else State.SPIKE)
	get_tree().paused = state == State.PAUSED

## Record a completed breathing session and persist atomically. Called by the
## spike; kept here so persistence policy lives in one place.
func record_session(breath_seconds: float) -> void:
	var progress: Dictionary = save_data.get("progress", {})
	progress["sessions_completed"] = int(progress.get("sessions_completed", 0)) + 1
	progress["total_breath_seconds"] = float(progress.get("total_breath_seconds", 0.0)) + breath_seconds
	save_data["progress"] = progress
	SaveService.write_save(save_data)
