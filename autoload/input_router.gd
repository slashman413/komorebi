extends Node

## InputRouter (Autoload singleton)
## ------------------------------------------------------------------
## Single choke point for high-level input intents, so gameplay code listens to
## semantic signals ("pause", "confirm") instead of scattering raw key/pad checks
## everywhere. On the Steam Deck this is also where Steam Input action sets will
## eventually bind. For Increment 0 it maps a small set of built-in actions and
## tracks the active input device (keyboard vs. gamepad) — the latter feeds the
## haptics capability probe.

signal pause_requested
signal confirm_pressed
signal device_kind_changed(using_gamepad: bool)

var using_gamepad: bool = false

func _ready() -> void:
	# Register fallback actions if the project didn't define them, so the spike
	# runs standalone (F6) and in a fresh checkout without an InputMap.
	_ensure_action("komorebi_pause", KEY_ESCAPE, JOY_BUTTON_START)
	_ensure_action("komorebi_confirm", KEY_ENTER, JOY_BUTTON_A)
	using_gamepad = not Input.get_connected_joypads().is_empty()

func _unhandled_input(event: InputEvent) -> void:
	_update_device_kind(event)
	if event.is_action_pressed("komorebi_pause"):
		pause_requested.emit()
	elif event.is_action_pressed("komorebi_confirm"):
		confirm_pressed.emit()

func _update_device_kind(event: InputEvent) -> void:
	var now_gamepad: bool = using_gamepad
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		now_gamepad = true
	elif event is InputEventKey or event is InputEventMouse:
		now_gamepad = false
	if now_gamepad != using_gamepad:
		using_gamepad = now_gamepad
		device_kind_changed.emit(using_gamepad)

func _ensure_action(action: StringName, key: Key, pad_button: JoyButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = key
	InputMap.action_add_event(action, key_event)
	var pad_event: InputEventJoypadButton = InputEventJoypadButton.new()
	pad_event.button_index = pad_button
	InputMap.action_add_event(action, pad_event)
