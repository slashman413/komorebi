class_name KClimber
extends Node2D

## The little climber. Owns only animation; main.gd decides where it goes.
## Origin = the point where hands grip (hanging) or feet stand (on a ledge).

signal leap_finished

const TEX: Dictionary = {
	"climb_a": preload("res://assets/sprites/character_green_climb_a.png"),
	"climb_b": preload("res://assets/sprites/character_green_climb_b.png"),
	"idle": preload("res://assets/sprites/character_green_idle.png"),
	"front": preload("res://assets/sprites/character_green_front.png"),
	"jump": preload("res://assets/sprites/character_green_jump.png"),
	"hit": preload("res://assets/sprites/character_green_hit.png"),
	"duck": preload("res://assets/sprites/character_green_duck.png"),
}
const TEX_AURA: Texture2D = preload("res://assets/fx/glow.png")
const SCALE: float = 0.6

var standing: bool = true
var busy: bool = false
var focus: float = 0.0       ## 0..1 — drives the golden aura
var breath_amp: float = 0.0  ## 0..1 — chest rise while breathing on a ledge
var shaking: float = 0.0     ## low-calm tremble amount

var _sprite: Sprite2D
var _aura: Sprite2D
var _t: float = 0.0
var _grip_alt: bool = false

func _ready() -> void:
	_aura = Sprite2D.new()
	_aura.texture = TEX_AURA
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_aura.material = mat
	_aura.modulate = Color(1.0, 0.85, 0.4, 0.0)
	_aura.position = Vector2(0, -36)
	_aura.scale = Vector2.ONE * 1.1
	add_child(_aura)

	_sprite = Sprite2D.new()
	_sprite.scale = Vector2.ONE * SCALE
	add_child(_sprite)
	set_pose_stand()

func set_pose_stand() -> void:
	standing = true
	_sprite.texture = TEX["front"]
	# Frame bottom = feet.
	_sprite.offset = Vector2(0, -64)
	_sprite.flip_h = false

func set_pose_hang() -> void:
	standing = false
	_grip_alt = not _grip_alt
	_sprite.texture = TEX["climb_b"] if _grip_alt else TEX["climb_a"]
	# Hands sit ~30 px below the top of the 128 px frame.
	_sprite.offset = Vector2(0, 34)

func set_pose_hit() -> void:
	_sprite.texture = TEX["hit"]

func leap_to(target: Vector2, land_standing: bool, duration: float = 0.34) -> void:
	busy = true
	_sprite.texture = TEX["jump"]
	_sprite.offset = Vector2(0, -20)
	_sprite.flip_h = target.x < position.x
	var start: Vector2 = position
	var arc: float = clampf(start.distance_to(target) * 0.25, 20.0, 60.0)
	var tw := create_tween()
	tw.tween_method(func(p: float) -> void:
		var q: float = ease(p, -1.8)
		position = start.lerp(target, q) + Vector2(0, -sin(q * PI) * arc), 0.0, 1.0, duration)
	tw.tween_callback(func() -> void:
		busy = false
		if land_standing:
			set_pose_stand()
		else:
			set_pose_hang()
		_sprite.scale = Vector2(SCALE * 1.12, SCALE * 0.9)
		leap_finished.emit())

## Slip and tumble down to [param target], then stand up there.
func fall_to(target: Vector2, duration: float) -> void:
	busy = true
	set_pose_hit()
	_sprite.offset = Vector2(0, -40)
	var tw := create_tween()
	tw.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(_sprite, "rotation", TAU * 2.0, duration)
	tw.tween_callback(func() -> void:
		_sprite.rotation = 0.0
		busy = false
		set_pose_stand()
		leap_finished.emit())

func flash_hit() -> void:
	var prev: Texture2D = _sprite.texture
	_sprite.texture = TEX["hit"]
	_sprite.modulate = Color(1, 0.6, 0.6)
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		_sprite.modulate = Color.WHITE
		if not busy:
			_sprite.texture = prev)

func _process(delta: float) -> void:
	_t += delta
	# Squash recovers to rest scale; breathing gently swells the chest.
	var breath_s: float = 1.0 + breath_amp * 0.07
	var rest := Vector2(SCALE * breath_s, SCALE * breath_s)
	_sprite.scale = _sprite.scale.lerp(rest, clampf(delta * 10.0, 0.0, 1.0))
	if not busy:
		if standing:
			_sprite.position = Vector2.ZERO
		else:
			# A tiny sway while hanging, more tremble when calm runs low.
			_sprite.position = Vector2(sin(_t * 1.7) * 1.5, 0) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shaking * 3.0
	_aura.modulate.a = lerpf(_aura.modulate.a, focus * (0.55 + 0.15 * sin(_t * 3.0)), clampf(delta * 4.0, 0.0, 1.0))
	_aura.position = Vector2(0, -36) if standing else Vector2(0, 30)
