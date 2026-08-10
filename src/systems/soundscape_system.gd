class_name SoundscapeSystem
extends Node

signal puzzle_solved
signal waveform_updated(data)

var is_puzzle_active: bool = false
var target_frequency: float = 432.0
var current_frequency: float = 400.0

func _ready() -> void:
	print("[SoundscapeSystem] Initialized.")

func start_spirit_puzzle() -> void:
	is_puzzle_active = true
	print("[SoundscapeSystem] Spirit puzzle started. Target freq: ", target_frequency)

func update_frequency(freq: float) -> void:
	if not is_puzzle_active:
		return
		
	current_frequency = freq
	
	# Generate mock waveform data based on current frequency
	var data = []
	for i in range(64):
		data.append(sin(i * current_frequency * 0.01))
	emit_signal("waveform_updated", data)
	
	if abs(current_frequency - target_frequency) < 5.0:
		print("[SoundscapeSystem] Target frequency matched! Puzzle solved.")
		is_puzzle_active = false
		emit_signal("puzzle_solved")