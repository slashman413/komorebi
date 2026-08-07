class_name AudioDirector
extends Node

## AudioDirector: handles adaptive layering on vitality_changed

func _ready() -> void:
	print("[AudioDirector] Initialized.")

func bind_ecology_system(ecology_system: Node) -> void:
	if ecology_system.has_signal("vitality_changed"):
		ecology_system.vitality_changed.connect(_on_vitality_changed)
		print("[AudioDirector] Bound to EcologySystem vitality_changed signal.")

func _on_vitality_changed(vitality: float) -> void:
	print("[AudioDirector] Adapting audio layers for vitality: ", vitality)
	# For now just output adaptive layering logs
	var base_layer_volume = lerp(-20.0, 0.0, vitality)
	var melody_layer_volume = lerp(-40.0, 0.0, vitality)
	print(" -> Base layer volume: ", base_layer_volume, " dB")
	print(" -> Melody layer volume: ", melody_layer_volume, " dB")
