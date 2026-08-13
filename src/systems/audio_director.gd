class_name AudioDirector
extends Node

## AudioDirector: handles adaptive layering on vitality_changed

@export var haptics_enabled: bool = true

func _ready() -> void:
	print("[AudioDirector] Initialized.")
	var clock = get_node_or_null("/root/BreathClock")
	if clock:
		clock.phase_changed.connect(_on_phase_changed)

func bind_ecology_system(ecology_system: Node) -> void:
	if ecology_system.has_signal("vitality_changed"):
		ecology_system.connect("vitality_changed", self, "_on_vitality_changed")
		print("[AudioDirector] Bound to EcologySystem vitality_changed signal.")

func _on_vitality_changed(vitality: float) -> void:
	print("[AudioDirector] Adapting audio layers for vitality: ", vitality)
	# For now just output adaptive layering logs
	var base_layer_volume = lerp(-20.0, 0.0, vitality)
	var melody_layer_volume = lerp(-40.0, 0.0, vitality)
	print(" -> Base layer volume: ", base_layer_volume, " dB")
	print(" -> Melody layer volume: ", melody_layer_volume, " dB")

func _on_phase_changed(phase: int) -> void:
	if not haptics_enabled: return
	
	# Steam Deck corresponds to device 0
	match phase:
		0: # INHALE (4s)
			Input.start_joy_vibration(0, 0.2, 0.0, 4.0)
		1: # HOLD (7s) - Heartbeat pulse effect
			Input.start_joy_vibration(0, 0.0, 0.1, 7.0)
		2: # EXHALE (8s) - Smooth fade out
			Input.start_joy_vibration(0, 0.5, 0.5, 8.0)
