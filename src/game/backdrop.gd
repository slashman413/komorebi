class_name KBackdrop
extends CanvasLayer

## Screen-space sky + parallax. The time of day follows your altitude:
## bright morning at the trailhead, golden afternoon on the stone spire,
## sunset on the snowfield, a starry dusk above the sea of clouds.

const TEX_HILLS: Texture2D = preload("res://assets/bg/layer_hills.png")
const TEX_TREES: Texture2D = preload("res://assets/bg/layer_trees.png")
const TEX_CLOUDS: Texture2D = preload("res://assets/bg/layer_clouds.png")
const TEX_GLOW: Texture2D = preload("res://assets/fx/glow.png")
const TEX_STAR: Texture2D = preload("res://assets/fx/star_04.png")

## Sky [top, bottom] colours per zone, plus one for the summit.
const SKY: Array = [
	[Color("8ecdf5"), Color("dff3ff")],
	[Color("7cc0ea"), Color("cdeef7")],
	[Color("79a9d9"), Color("f6dfae")],
	[Color("5a5f9e"), Color("f3a98f")],
	[Color("1d1f45"), Color("6a5a9a")],
	[Color("2a2e6a"), Color("ffcf8a")],
]
const SUN: Array = [
	Color(1.0, 0.97, 0.85, 0.75), Color(1.0, 0.95, 0.8, 0.75), Color(1.0, 0.85, 0.55, 0.85),
	Color(1.0, 0.6, 0.45, 0.9), Color(0.85, 0.88, 1.0, 0.55), Color(1.0, 0.8, 0.5, 1.0),
]

var altitude: float = 0.0   ## world px climbed (positive up)
var progress: float = 0.0   ## 0..1 of the whole mountain

var _sky_grad: Gradient
var _sky: TextureRect
var _sun: Sprite2D
var _stars: Array[Sprite2D] = []
var _ranges: Array[Polygon2D] = []
var _hills: TextureRect
var _trees: TextureRect
var _clouds: Array[TextureRect] = []
var _t: float = 0.0
var _size := Vector2(1280, 800)

func _ready() -> void:
	layer = -10
	_sky_grad = Gradient.new()
	var gt := GradientTexture2D.new()
	gt.gradient = _sky_grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	_sky = TextureRect.new()
	_sky.texture = gt
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_sky)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		var s := Sprite2D.new()
		s.texture = TEX_STAR
		s.scale = Vector2.ONE * rng.randf_range(0.05, 0.14)
		s.set_meta("norm", Vector2(rng.randf(), rng.randf() * 0.75))
		s.modulate = Color(1, 1, 1, 0)
		s.set_meta("tw", rng.randf_range(0, TAU))
		add_child(s)
		_stars.append(s)

	_sun = Sprite2D.new()
	_sun.texture = TEX_GLOW
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sun.material = add
	_sun.scale = Vector2.ONE * 3.2
	add_child(_sun)

	# Two procedural mountain ranges far away (they rise into view as you climb).
	for r in 2:
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		var x: float = -100.0
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.seed = 41 + r
		pts.append(Vector2(-100, 400))
		while x < 1500.0:
			pts.append(Vector2(x, seed_rng.randf_range(-40.0, 110.0) + r * 70.0))
			x += seed_rng.randf_range(60.0, 150.0)
		pts.append(Vector2(1500, 400))
		poly.polygon = pts
		add_child(poly)
		_ranges.append(poly)

	for i in 3:
		var c := TextureRect.new()
		c.texture = TEX_CLOUDS
		c.stretch_mode = TextureRect.STRETCH_TILE
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.modulate = Color(1, 1, 1, 0.55 - i * 0.12)
		add_child(c)
		_clouds.append(c)

	_hills = _tile_layer(TEX_HILLS)
	_trees = _tile_layer(TEX_TREES)

func _tile_layer(tex: Texture2D) -> TextureRect:
	var tr_node := TextureRect.new()
	tr_node.texture = tex
	tr_node.stretch_mode = TextureRect.STRETCH_TILE
	tr_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(tr_node)
	return tr_node

func _process(delta: float) -> void:
	_t += delta
	_size = get_viewport().get_visible_rect().size
	_sky.size = _size

	# Blend sky colours by continuous zone position.
	var zf: float = clampf(progress * 5.0, 0.0, 5.0)
	var i0: int = mini(int(floor(zf)), 4)
	var f: float = zf - float(i0)
	var top: Color = (SKY[i0][0] as Color).lerp(SKY[i0 + 1][0], f)
	var bot: Color = (SKY[i0][1] as Color).lerp(SKY[i0 + 1][1], f)
	_sky_grad.set_color(0, top)
	_sky_grad.set_color(1, bot)
	var sun_c: Color = (SUN[i0] as Color).lerp(SUN[i0 + 1], f)
	_sun.modulate = sun_c
	# The sun sinks as you climb, then a moonlit dusk, then sunrise at the top.
	var sun_y: float = lerpf(0.16, 0.72, clampf(progress * 1.25, 0.0, 1.0))
	if progress > 0.97:
		sun_y = lerpf(0.72, 0.45, (progress - 0.97) / 0.03)
	_sun.position = Vector2(_size.x * 0.78, _size.y * sun_y)

	var night: float = clampf((progress - 0.62) / 0.2, 0.0, 1.0)
	for s in _stars:
		var tw: float = float(s.get_meta("tw"))
		s.modulate.a = night * (0.55 + 0.45 * sin(_t * 1.3 + tw))
		var norm: Vector2 = s.get_meta("norm")
		s.position = norm * _size

	# Distant ranges rise from below the horizon as altitude grows.
	for r in _ranges.size():
		var poly: Polygon2D = _ranges[r]
		var rise: float = clampf(altitude / 2200.0, 0.0, 1.0)
		var base_y: float = _size.y * (1.05 - 0.38 * rise) + r * 60.0 + altitude * (0.004 + r * 0.004)
		poly.position = Vector2(0.0, base_y)
		poly.scale = Vector2(maxf(1.0, _size.x / 1400.0), 1.0)
		var tint: Color = bot.lerp(top, 0.55 - r * 0.25).darkened(0.12 + r * 0.1)
		poly.color = tint

	# Hills + trees sit at the trailhead and scroll away below.
	var hill_y: float = _size.y - 256.0 + altitude * 0.35
	_hills.position = Vector2(0.0, hill_y + 30.0)
	_hills.size = Vector2(_size.x + 256.0, 256.0)
	_hills.modulate = Color(1, 1, 1, 0.9)
	_trees.position = Vector2(-60.0, _size.y - 220.0 + altitude * 0.6)
	_trees.size = Vector2(_size.x + 256.0, 256.0)

	for i in _clouds.size():
		var c: TextureRect = _clouds[i]
		var speed: float = 6.0 + i * 5.0
		var band_y: float = fposmod(altitude * (0.08 + i * 0.05) + i * 260.0, _size.y + 400.0) - 300.0
		c.position = Vector2(-fposmod(_t * speed, 256.0), band_y)
		c.size = Vector2(_size.x + 512.0, 256.0)
		# Above the cloud sea the clouds glow warm with the sunset.
		c.modulate = Color(1, 1, 1, 0.55 - i * 0.12).lerp(Color(1.0, 0.8, 0.85, 0.5), clampf((progress - 0.55) * 2.0, 0.0, 0.6))
