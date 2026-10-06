class_name KHold
extends Node2D

## One grip on the mountain. Pure presentation + a little state (reachable,
## hovered, crumbling). Gameplay rules live in main.gd; layout in MountainGen.

const TEX_ROCK: Texture2D = preload("res://assets/sprites/rock.png")
const TEX_SMALL: Texture2D = preload("res://assets/sprites/brick_grey.png")
const TEX_CRUMBLE: Texture2D = preload("res://assets/sprites/block_empty_warning.png")
const TEX_GLOW: Texture2D = preload("res://assets/fx/glow.png")
const TEX_TORCH_OFF: Texture2D = preload("res://assets/sprites/torch_off.png")
const TEX_TORCH_A: Texture2D = preload("res://assets/sprites/torch_on_a.png")
const TEX_TORCH_B: Texture2D = preload("res://assets/sprites/torch_on_b.png")
const TEX_FLAG_A: Texture2D = preload("res://assets/sprites/flag_yellow_a.png")
const TEX_FLAG_B: Texture2D = preload("res://assets/sprites/flag_yellow_b.png")
const TEX_STAR: Texture2D = preload("res://assets/sprites/star.png")
const TEX_HEART: Texture2D = preload("res://assets/sprites/heart.png")
const GEMS: Array[Texture2D] = [
	preload("res://assets/sprites/gem_blue.png"),
	preload("res://assets/sprites/gem_green.png"),
	preload("res://assets/sprites/gem_yellow.png"),
	preload("res://assets/sprites/gem_red.png"),
]
const DECOR: Array[Texture2D] = [
	preload("res://assets/sprites/bush.png"),
	preload("res://assets/sprites/grass.png"),
	preload("res://assets/sprites/mushroom_red.png"),
	preload("res://assets/sprites/mushroom_brown.png"),
	preload("res://assets/sprites/grass_purple.png"),
]
const ZONE_TERRAIN: Array[String] = ["grass", "dirt", "stone", "snow", "purple"]

var index: int = 0
var kind: int = MountainGen.Kind.NORMAL
var item: int = MountainGen.Item.NONE
var zone: int = 0
var reachable: bool = false
var hovered: bool = false
var key_hint: String = ""
var lit: bool = false
var broken: bool = false
var crumble_left: float = -1.0 ## seconds until a touched crumble hold gives way

var _glow: Sprite2D
var _body: Node2D
var _item_sprite: Sprite2D
var _torch: Sprite2D
var _flag: Sprite2D
var _hint_label: Label
var _t: float = 0.0
var _rng_phase: float = 0.0

func setup(i: int, data: Dictionary) -> void:
	index = i
	kind = data["kind"]
	item = data["item"]
	position = data["pos"]
	zone = MountainGen.zone_of(position.y)
	_rng_phase = float(i) * 1.7

func _ready() -> void:
	_glow = Sprite2D.new()
	_glow.texture = TEX_GLOW
	_glow.modulate = Color(0.75, 1.0, 0.85, 0.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.scale = Vector2.ONE * (1.6 if is_platform() else 0.9)
	add_child(_glow)

	_body = Node2D.new()
	add_child(_body)
	match kind:
		MountainGen.Kind.NORMAL:
			_add_sprite(_body, TEX_ROCK, Vector2(0, -6), 0.72)
		MountainGen.Kind.SMALL:
			_add_sprite(_body, TEX_SMALL, Vector2(0, 0), 1.0)
		MountainGen.Kind.CRUMBLE:
			_add_sprite(_body, TEX_CRUMBLE, Vector2(0, 0), 0.6)
		MountainGen.Kind.LEDGE:
			_build_platform(3)
			_torch = _add_sprite(_body, TEX_TORCH_OFF, Vector2(-58, -30), 0.85)
		MountainGen.Kind.SUMMIT:
			_build_platform(5)
			_flag = _add_sprite(_body, TEX_FLAG_A, Vector2(70, -40), 1.1)
		MountainGen.Kind.START:
			pass # the trailhead ground is drawn by the wall

	if item != MountainGen.Item.NONE:
		_item_sprite = Sprite2D.new()
		match item:
			MountainGen.Item.STAR:
				_item_sprite.texture = TEX_STAR
				_item_sprite.scale = Vector2.ONE * 0.6
			MountainGen.Item.GEM:
				_item_sprite.texture = GEMS[index % GEMS.size()]
				_item_sprite.scale = Vector2.ONE * 0.6
			MountainGen.Item.HEART:
				_item_sprite.texture = TEX_HEART
				_item_sprite.scale = Vector2.ONE * 0.6
		_item_sprite.position = Vector2(0, -44)
		add_child(_item_sprite)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 22)
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_hint_label.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.16))
	_hint_label.add_theme_constant_override("outline_size", 8)
	_hint_label.position = Vector2(-14, 18)
	_hint_label.size = Vector2(28, 28)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint_label)

func is_platform() -> bool:
	return kind == MountainGen.Kind.LEDGE or kind == MountainGen.Kind.SUMMIT or kind == MountainGen.Kind.START

func is_rest() -> bool:
	return is_platform()

## Radius used for mouse/touch picking.
func pick_radius() -> float:
	return 70.0 if is_platform() else 46.0

func _build_platform(tiles: int) -> void:
	var terrain: String = ZONE_TERRAIN[zone]
	var s: float = 0.72
	var w: float = 64.0 * s
	var x0: float = -w * (tiles - 1) * 0.5
	for i in tiles:
		var part: String = "middle"
		if i == 0:
			part = "left"
		elif i == tiles - 1:
			part = "right"
		var tex: Texture2D = load("res://assets/sprites/terrain_%s_cloud_%s.png" % [terrain, part])
		_add_sprite(_body, tex, Vector2(x0 + w * i, w * 0.5 - 4.0), s)
	# A little life on the ledge.
	var d: Texture2D = DECOR[(index * 7) % DECOR.size()]
	var deco := _add_sprite(_body, d, Vector2(x0 + w * (tiles - 1) - 4.0, -18.0), 0.55)
	deco.z_index = -1

func _add_sprite(parent: Node2D, tex: Texture2D, pos: Vector2, s: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.position = pos
	sp.scale = Vector2.ONE * s
	parent.add_child(sp)
	return sp

func light_lantern() -> void:
	lit = true

func take_item() -> int:
	var it: int = item
	item = MountainGen.Item.NONE
	if _item_sprite:
		var tw := create_tween()
		tw.tween_property(_item_sprite, "position", _item_sprite.position + Vector2(0, -50), 0.35)
		tw.parallel().tween_property(_item_sprite, "modulate:a", 0.0, 0.35)
		tw.tween_callback(_item_sprite.queue_free)
		_item_sprite = null
	return it

func touch_crumble() -> void:
	if kind == MountainGen.Kind.CRUMBLE and crumble_left < 0.0 and not broken:
		crumble_left = 1.6

func break_away() -> void:
	broken = true
	crumble_left = -1.0
	reachable = false
	var tw := create_tween()
	tw.tween_property(_body, "position", Vector2(0, 260), 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(_body, "rotation", 1.4, 0.7)
	tw.parallel().tween_property(_body, "modulate:a", 0.0, 0.7)

func restore() -> void:
	if not broken and crumble_left < 0.0:
		return
	broken = false
	crumble_left = -1.0
	_body.position = Vector2.ZERO
	_body.rotation = 0.0
	_body.modulate = Color.WHITE

func _process(delta: float) -> void:
	_t += delta
	# Reachable holds breathe softly; the hovered one glows bright.
	var target_a: float = 0.0
	if reachable and not broken:
		target_a = 0.85 if hovered else 0.35 + 0.18 * sin(_t * 2.4 + _rng_phase)
	_glow.modulate.a = lerpf(_glow.modulate.a, target_a, clampf(delta * 10.0, 0.0, 1.0))
	var s: float = 1.12 if (hovered and reachable) else 1.0
	_body.scale = _body.scale.lerp(Vector2.ONE * s, clampf(delta * 12.0, 0.0, 1.0))
	_hint_label.text = key_hint if reachable else ""

	if crumble_left >= 0.0:
		_body.position = Vector2(randf_range(-2.5, 2.5), randf_range(-1.5, 1.5))
	if _item_sprite:
		_item_sprite.position.y = -44.0 + sin(_t * 3.0 + _rng_phase) * 4.0
		_item_sprite.rotation = sin(_t * 1.5 + _rng_phase) * 0.12
	if _torch:
		if lit:
			_torch.texture = TEX_TORCH_A if int(_t * 6.0) % 2 == 0 else TEX_TORCH_B
		else:
			_torch.texture = TEX_TORCH_OFF
	if _flag:
		_flag.texture = TEX_FLAG_A if int(_t * 4.0) % 2 == 0 else TEX_FLAG_B
