class_name KHazard
extends Node2D

## Something to keep an eye on while you hang there: a bee (or fly, or
## ladybug) drifting across the face, or a rock tumbling from above after a
## short warning. Touching one costs calm — it never kills you outright.

enum Type { FLYER, ROCK }

const FLYERS: Array = [
	[preload("res://assets/sprites/bee_a.png"), preload("res://assets/sprites/bee_b.png")],
	[preload("res://assets/sprites/fly_a.png"), preload("res://assets/sprites/fly_b.png")],
	[preload("res://assets/sprites/ladybug_fly.png"), preload("res://assets/sprites/ladybug_rest.png")],
]
const TEX_ROCK: Texture2D = preload("res://assets/sprites/rock.png")
const TEX_WARN: Texture2D = preload("res://assets/sprites/block_empty_warning.png")

var type: int = Type.FLYER
var velocity := Vector2.ZERO
var radius: float = 30.0
var damage: float = 22.0
var armed: bool = true
var warn_left: float = 0.0

var _sprite: Sprite2D
var _warn: Sprite2D
var _frames: Array = []
var _t: float = 0.0
var _base_y: float = 0.0

func setup_flyer(variant: int, from_left: bool, y: float, speed: float) -> void:
	type = Type.FLYER
	_frames = FLYERS[clampi(variant, 0, FLYERS.size() - 1)]
	position = Vector2(-80.0 if from_left else 1360.0, y)
	_base_y = y
	velocity = Vector2(speed if from_left else -speed, 0)
	radius = 34.0
	damage = 22.0

func setup_rock(x: float, top_y: float, warn_time: float) -> void:
	type = Type.ROCK
	position = Vector2(x, top_y)
	warn_left = warn_time
	velocity = Vector2(0, 0)
	radius = 34.0
	damage = 28.0

func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	if type == Type.FLYER:
		_sprite.texture = _frames[0]
		_sprite.scale = Vector2.ONE * 0.8
		_sprite.flip_h = velocity.x > 0.0
	else:
		_sprite.texture = TEX_ROCK
		_sprite.scale = Vector2.ONE * 0.9
		_sprite.visible = false
		_warn = Sprite2D.new()
		_warn.texture = TEX_WARN
		_warn.scale = Vector2.ONE * 0.5
		add_child(_warn)

## Screen-top y for the warning marker; main.gd keeps it pinned to the camera.
func pin_warning(top_y: float) -> void:
	if type == Type.ROCK and warn_left > 0.0:
		position.y = top_y

func _process(delta: float) -> void:
	_t += delta
	if type == Type.FLYER:
		position += velocity * delta
		position.y = _base_y + sin(_t * 3.0) * 18.0
		_sprite.texture = _frames[int(_t * 10.0) % 2]
		if position.x < -140.0 or position.x > 1420.0:
			queue_free()
	else:
		if warn_left > 0.0:
			warn_left -= delta
			_warn.visible = int(_t * 8.0) % 2 == 0
			if warn_left <= 0.0:
				_warn.queue_free()
				_warn = null
				_sprite.visible = true
				velocity = Vector2(0, 120)
		else:
			velocity.y = minf(velocity.y + 1400.0 * delta, 900.0)
			position += velocity * delta
			_sprite.rotation += delta * 5.0

func is_dangerous() -> bool:
	return armed and not (type == Type.ROCK and warn_left > 0.0)
