class_name EcologySystem
extends Node

signal vitality_changed(new_vitality: float)
signal node_restored(node_id: String)

enum PlantState { SEED, SPROUT, BLOOM, WITHERED }

class PlantNode:
	var id: String
	var state: int = PlantState.SEED
	var health: float = 1.0
	
	func _init(_id: String):
		id = _id
		
	func advance_state() -> bool:
		if state == PlantState.SEED:
			state = PlantState.SPROUT
			return true
		elif state == PlantState.SPROUT:
			state = PlantState.BLOOM
			return true
		return false
		
	func wither() -> void:
		state = PlantState.WITHERED

var global_vitality: float = 0.0
var _light_direction: Vector3 = Vector3(0.5, 1.0, 0.5).normalized()
var _water_direction: Vector3 = Vector3.DOWN
var _plants: Dictionary = {}

func _ready() -> void:
	print("[EcologySystem] Initialized.")

func update_vitality(delta_vitality: float) -> void:
	global_vitality = clamp(global_vitality + delta_vitality, 0.0, 1.0)
	vitality_changed.emit(global_vitality)
	print("[EcologySystem] Global vitality updated to: ", global_vitality)
	
func register_plant(node_id: String) -> void:
	if not _plants.has(node_id):
		_plants[node_id] = PlantNode.new(node_id)
		print("[EcologySystem] Plant registered: ", node_id)

func restore_node(node_id: String) -> void:
	if _plants.has(node_id):
		var plant = _plants[node_id]
		plant.advance_state()
		print("[EcologySystem] Node restored/advanced: ", node_id, " | New state: ", plant.state)
	
	node_restored.emit(node_id)
	update_vitality(0.1)

func get_light_direction() -> Vector3:
	return _light_direction

func get_water_direction() -> Vector3:
	return _water_direction
