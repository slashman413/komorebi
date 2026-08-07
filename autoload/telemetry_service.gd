extends Node

## Opt-in telemetry for Project Komorebi
## Tracks onboarding, breathing engagement, and session length for analysis.

var opt_in: bool = false
var session_start_time: int = 0
var breathing_sessions: int = 0

func _ready() -> void:
	print("[TelemetryService] Initialized.")
	session_start_time = Time.get_ticks_msec()

func enable_telemetry(enabled: bool) -> void:
	opt_in = enabled
	print("[TelemetryService] Opt-in status changed to: ", opt_in)

func track_onboarding_completed() -> void:
	if not opt_in: return
	print("[TelemetryService] EVENT: onboarding_completed")

func track_breathing_engaged() -> void:
	if not opt_in: return
	breathing_sessions += 1
	print("[TelemetryService] EVENT: breathing_engaged | Total: ", breathing_sessions)

func _exit_tree() -> void:
	if not opt_in: return
	var session_length = (Time.get_ticks_msec() - session_start_time) / 1000.0
	print("[TelemetryService] EVENT: session_ended | Length: ", session_length, "s")
