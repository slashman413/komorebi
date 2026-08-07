extends Node3D

@onready var ecology_system = $EcologySystem
@onready var soundscape_system = $SoundscapeSystem
@onready var audio_director = $AudioDirector

func _ready() -> void:
	print("[VerticalSlice] Level loaded.")
	
	# Wire up AudioDirector to EcologySystem
	audio_director.bind_ecology_system(ecology_system)
	
	# Initial tests
	soundscape_system.start_spirit_puzzle()
	ecology_system.update_vitality(0.2)
