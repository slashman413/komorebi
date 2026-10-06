extends Node2D

## Komorebi — breathe & climb.
##
## Pick your way up a procedurally generated mountain, hold by hold. Every grip
## drains your Calm; run out and you slip back to the last lantern you lit.
## Lantern ledges are where you rest: hold to breathe in, keep holding, let go to
## breathe out — one real 4-7-8 cycle — and the mountain gives your calm back
## (plus Focus, which slows the drain for a while). Side routes hold sunlight,
## gems and hearts; bees, flies and falling rocks keep you honest.

enum State { TITLE, PLAY, SUMMIT }

const REACH: float = MountainGen.REACH
const LEAP_COST: float = 4.0
const DRAIN: Array[float] = [1.6, 2.2, 2.8, 3.4, 4.0] ## calm/sec while hanging, per zone
const SMALL_MULT: float = 1.6
const FOCUS_MULT: float = 0.4
const SAFE_START_PX: float = 320.0
const ZONE_TERRAIN: Array[String] = ["grass", "dirt", "stone", "snow", "purple"]
const LOCALES: Array[String] = ["en", "zh", "ja"]
const KOFI_URL: String = "https://ko-fi.com/ytstories0413?utm_source=komorebi-game"
## Per-zone rock tint so each band reads differently (and the face cools toward dusk).
const WALL_TINT: Array[Color] = [Color(0.82, 0.8, 0.82), Color(0.78, 0.86, 0.78), Color(0.9, 0.84, 0.74), Color(0.8, 0.86, 0.96), Color(0.72, 0.66, 0.9)]
const WALL_X0: float = 256.0
const WALL_X1: float = 1024.0

const SFX_FILES: Dictionary = {
	"jump": "res://assets/sfx/sfx_jump.ogg",
	"coin": "res://assets/sfx/sfx_coin.ogg",
	"gem": "res://assets/sfx/sfx_gem.ogg",
	"hurt": "res://assets/sfx/sfx_hurt.ogg",
	"magic": "res://assets/sfx/sfx_magic.ogg",
	"select": "res://assets/sfx/sfx_select.ogg",
	"bump": "res://assets/sfx/sfx_bump.ogg",
	"disappear": "res://assets/sfx/sfx_disappear.ogg",
	"high": "res://assets/sfx/sfx_jump-high.ogg",
}
const TEX_STAR_FX: Texture2D = preload("res://assets/fx/star_06.png")
const TEX_SMOKE: Texture2D = preload("res://assets/fx/smoke_04.png")
const TEX_LEAF: Texture2D = preload("res://assets/fx/leaf.png")
const TEX_CIRCLE: Texture2D = preload("res://assets/fx/circle_05.png")
const TEX_SPARK: Texture2D = preload("res://assets/fx/star_04.png")
const TEX_GLOW: Texture2D = preload("res://assets/fx/glow.png")

var state: int = State.TITLE
var layout: Array = []
var holds: Array[KHold] = []
var cur_index: int = 0
var checkpoint_index: int = 0
var calm: float = 100.0
var focus_t: float = 0.0
var light: int = 0
var breaths: int = 0
var slips: int = 0
var run_time: float = 0.0
var max_zone_seen: int = -1
var pointer_breath: bool = false
var keyboard_mode: bool = false
var hazard_t: float = 6.0
var best_alt_this_run: float = 0.0
var sound_on: bool = true
var locale_i: int = 0

var backdrop: KBackdrop
var world: Node2D
var wall_layer: Node2D
var hold_layer: Node2D
var fx_layer: Node2D
var hazard_layer: Node2D
var climber: KClimber
var camera: Camera2D
var ui: KUI
var breath: KBreathSession
var music: AudioStreamPlayer
var weather: CPUParticles2D
var _sfx: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_i: int = 0
var _cam_y: float = -300.0
var _shake: float = 0.0
## `godot -- --autoplay` climbs by itself (used to render/verify the game headlessly).
var _autoplay: bool = false
var _auto_t: float = 0.0
var _auto_breathed: Dictionary = {}
var _auto_shot_t: float = 0.0
var _auto_shot_n: int = 0
var _auto_shot_dir: String = ""
var _title_shot: String = ""

# ------------------------------------------------------------------ lifecycle

func _ready() -> void:
	randomize()
	_setup_input()
	_load_settings()

	backdrop = KBackdrop.new()
	add_child(backdrop)

	world = Node2D.new()
	add_child(world)
	wall_layer = Node2D.new()
	world.add_child(wall_layer)
	hold_layer = Node2D.new()
	world.add_child(hold_layer)
	climber = KClimber.new()
	climber.leap_finished.connect(_on_landed)
	world.add_child(climber)
	hazard_layer = Node2D.new()
	world.add_child(hazard_layer)
	fx_layer = Node2D.new()
	world.add_child(fx_layer)

	camera = Camera2D.new()
	camera.position = Vector2(640, _cam_y)
	add_child(camera)
	camera.make_current()

	weather = CPUParticles2D.new()
	weather.amount = 28
	weather.lifetime = 9.0
	weather.preprocess = 6.0
	weather.texture = TEX_LEAF
	weather.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	weather.emission_rect_extents = Vector2(900, 10)
	weather.direction = Vector2(0.3, 1)
	weather.spread = 25.0
	weather.gravity = Vector2(0, 18)
	weather.initial_velocity_min = 30.0
	weather.initial_velocity_max = 70.0
	weather.angular_velocity_min = -90.0
	weather.angular_velocity_max = 90.0
	weather.scale_amount_min = 0.5
	weather.scale_amount_max = 0.9
	weather.color = Color(0.55, 0.85, 0.45, 0.9)
	camera.add_child(weather)
	weather.position = Vector2(0, -460)

	ui = KUI.new()
	ui.sound_on = sound_on
	add_child(ui)
	ui.play_pressed.connect(_start_run)
	ui.again_pressed.connect(func() -> void:
		_build_mountain(randi())
		_start_run())
	ui.resume_pressed.connect(func() -> void: GameDirector.set_paused(false))
	ui.restart_pressed.connect(func() -> void:
		GameDirector.set_paused(false)
		_build_mountain(randi())
		_start_run())
	ui.title_pressed.connect(func() -> void:
		GameDirector.set_paused(false)
		_to_title())
	ui.sound_pressed.connect(_toggle_sound)
	ui.lang_pressed.connect(_cycle_language)
	ui.support_pressed.connect(func() -> void:
		_play("select")
		OS.shell_open(KOFI_URL))
	GameDirector.state_changed.connect(_on_director_state)

	breath = KBreathSession.new()
	add_child(breath)
	breath.audio_enabled = sound_on
	breath.tick.connect(_on_breath_tick)
	breath.finished.connect(_on_breath_finished)

	_setup_audio()
	if InputRouter:
		InputRouter.confirm_pressed.connect(func() -> void:
			if state == State.PLAY:
				keyboard_mode = true
				_leap_dir(Vector2(0, -1)))

	_autoplay = OS.get_cmdline_user_args().has("--autoplay")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_auto_shot_dir = a.substr(8)
		elif a.begins_with("--title-shot="):
			_title_shot = a.substr(13)
	_build_mountain(413 if _autoplay else randi())
	_to_title()

func _setup_input() -> void:
	_bind("k_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT])
	_bind("k_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT])
	_bind("k_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP])
	_bind("k_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN])
	_bind("k_breathe", [KEY_SPACE], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_X])

func _bind(action: String, keys: Array, pads: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in pads:
		var p := InputEventJoypadButton.new()
		p.button_index = b
		InputMap.action_add_event(action, p)

func _setup_audio() -> void:
	for k in SFX_FILES:
		_sfx[k] = load(SFX_FILES[k])
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		_sfx_pool.append(p)
	music = AudioStreamPlayer.new()
	var m: AudioStreamOggVorbis = load("res://assets/music/komorebi_ambient.ogg")
	if m:
		m.loop = true
	music.stream = m
	music.volume_db = -8.0
	add_child(music)
	AudioServer.set_bus_mute(0, not sound_on)

func _play(name_key: String, pitch: float = 1.0) -> void:
	if not _sfx.has(name_key):
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_pool.size()
	p.stream = _sfx[name_key]
	p.pitch_scale = pitch
	p.play()

# ------------------------------------------------------------------ settings

func _load_settings() -> void:
	var settings: Dictionary = GameDirector.save_data.get("settings", {})
	sound_on = bool(settings.get("audio_enabled", true))
	var loc: String = str(settings.get("locale", ""))
	if loc == "":
		var os_lang: String = OS.get_locale_language()
		loc = os_lang if LOCALES.has(os_lang) else "en"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			loc = a.substr(7)
	locale_i = maxi(LOCALES.find(loc), 0)
	TranslationServer.set_locale(LOCALES[locale_i])

func _save_settings() -> void:
	var settings: Dictionary = GameDirector.save_data.get("settings", {})
	settings["audio_enabled"] = sound_on
	settings["locale"] = LOCALES[locale_i]
	GameDirector.save_data["settings"] = settings
	SaveService.write_save(GameDirector.save_data)

func _toggle_sound() -> void:
	sound_on = not sound_on
	ui.sound_on = sound_on
	breath.audio_enabled = sound_on
	AudioServer.set_bus_mute(0, not sound_on)
	if sound_on and not music.playing:
		music.play()
	ui.refresh_texts()
	_save_settings()
	_play("select")

func _cycle_language() -> void:
	locale_i = (locale_i + 1) % LOCALES.size()
	TranslationServer.set_locale(LOCALES[locale_i])
	ui.refresh_texts()
	if state == State.TITLE:
		ui.show_title(_best_text())
	_save_settings()
	_play("select")

func _progress() -> Dictionary:
	return GameDirector.save_data.get("progress", {})

func _best_text() -> String:
	var p := _progress()
	var best: float = float(p.get("best_time", 0.0))
	var summits: int = int(p.get("summits", 0))
	var alt: int = int(p.get("best_alt_m", 0))
	if summits > 0:
		return tr("title_best") % [_fmt_time(best), summits]
	if alt > 0:
		return tr("title_best_alt") % alt
	return ""

static func _fmt_time(t: float) -> String:
	var s: int = int(t)
	return "%d:%02d" % [s / 60, s % 60]

# ------------------------------------------------------------------ world build

func _build_mountain(seed_value: int) -> void:
	for c in wall_layer.get_children():
		c.queue_free()
	for c in hold_layer.get_children():
		c.queue_free()
	for c in hazard_layer.get_children():
		c.queue_free()
	holds.clear()
	layout = MountainGen.generate(seed_value)
	var summit_y: float = -MountainGen.SUMMIT_HEIGHT
	for h in layout:
		if h["kind"] == MountainGen.Kind.SUMMIT:
			summit_y = h["pos"].y

	# The cliff face, one band per zone.
	var top: float = summit_y - 4.0
	for z in MountainGen.ZONE_COUNT:
		var y1: float = -z * MountainGen.ZONE_HEIGHT
		var y0: float = maxf(-(z + 1) * MountainGen.ZONE_HEIGHT, top + 64.0)
		if y0 >= y1:
			continue
		var t: String = ZONE_TERRAIN[z]
		var shade: Color = WALL_TINT[z]
		_tile(wall_layer, "terrain_%s_block_center" % t, Rect2(WALL_X0, y0, WALL_X1 - WALL_X0, y1 - y0 + 2.0), shade)
		_tile(wall_layer, "terrain_%s_block_left" % t, Rect2(WALL_X0 - 64.0, y0, 64.0, y1 - y0 + 2.0), shade)
		_tile(wall_layer, "terrain_%s_block_right" % t, Rect2(WALL_X1, y0, 64.0, y1 - y0 + 2.0), shade)
	var tz: String = ZONE_TERRAIN[MountainGen.ZONE_COUNT - 1]
	_tile(wall_layer, "terrain_%s_block_top" % tz, Rect2(WALL_X0, top, WALL_X1 - WALL_X0, 64.0), WALL_TINT[4])
	_tile(wall_layer, "terrain_%s_block_top_left" % tz, Rect2(WALL_X0 - 64.0, top, 64.0, 64.0), WALL_TINT[4])
	_tile(wall_layer, "terrain_%s_block_top_right" % tz, Rect2(WALL_X1, top, 64.0, 64.0), WALL_TINT[4])

	# Sunbeams through the canopy at the foot of the mountain — komorebi.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 6:
		var beam := Polygon2D.new()
		var x: float = rng.randf_range(150.0, 1150.0)
		var w: float = rng.randf_range(40.0, 110.0)
		beam.polygon = PackedVector2Array([Vector2(x, -1500), Vector2(x + w, -1500), Vector2(x + w - 380, 40), Vector2(x - 380 - w * 0.4, 40)])
		beam.vertex_colors = PackedColorArray([Color(1, 0.95, 0.7, 0.0), Color(1, 0.95, 0.7, 0.0), Color(1, 0.95, 0.7, 0.16), Color(1, 0.95, 0.7, 0.16)])
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		beam.material = mat
		beam.set_meta("beam", rng.randf_range(0.0, TAU))
		wall_layer.add_child(beam)

	# Trailhead meadow.
	_tile(wall_layer, "terrain_grass_block_top", Rect2(-700.0, -10.0, 2700.0, 64.0), Color.WHITE)
	_tile(wall_layer, "terrain_grass_block_center", Rect2(-700.0, 54.0, 2700.0, 2400.0), Color.WHITE)
	var deco: Array = [["bush", 140.0], ["bush", 470.0], ["sign_right", 540.0], ["mushroom_red", 760.0], ["grass", 820.0], ["bush", 1110.0], ["fence", 1220.0], ["fence", 1284.0], ["grass", 300.0], ["mushroom_brown", 980.0]]
	for d in deco:
		var s := Sprite2D.new()
		s.texture = load("res://assets/sprites/%s.png" % d[0])
		s.position = Vector2(float(d[1]), -40.0)
		wall_layer.add_child(s)

	# Life on the rock face: tufts, mushrooms, snow, kept clear of the holds.
	var wall_deco: Array = [["grass", "bush", "mushroom_red"], ["grass", "mushroom_brown", "grass"], ["rock", "grass", "rock"], ["snow", "snow", "rock"], ["grass_purple", "snow", "grass_purple"]]
	for z in MountainGen.ZONE_COUNT:
		for k in 16:
			var p := Vector2(rng.randf_range(WALL_X0 + 30.0, WALL_X1 - 30.0), -z * MountainGen.ZONE_HEIGHT - rng.randf_range(40.0, MountainGen.ZONE_HEIGHT - 40.0))
			if p.y < top + 80.0 or MountainGen._too_close(layout, p):
				continue
			var names: Array = wall_deco[z]
			var ds := Sprite2D.new()
			ds.texture = load("res://assets/sprites/%s.png" % names[k % names.size()])
			ds.position = p
			ds.scale = Vector2.ONE * rng.randf_range(0.4, 0.6)
			ds.modulate = Color(0.85, 0.85, 0.9, 0.85)
			wall_layer.add_child(ds)

	for i in layout.size():
		var hold := KHold.new()
		hold.setup(i, layout[i])
		hold_layer.add_child(hold)
		holds.append(hold)

func _tile(parent: Node, tex_name: String, rect: Rect2, tint: Color) -> TextureRect:
	var tr_node := TextureRect.new()
	tr_node.texture = load("res://assets/sprites/%s.png" % tex_name)
	tr_node.stretch_mode = TextureRect.STRETCH_TILE
	tr_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr_node.position = rect.position
	tr_node.size = rect.size
	tr_node.modulate = tint
	tr_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr_node)
	return tr_node

# ------------------------------------------------------------------ flow

func _to_title() -> void:
	state = State.TITLE
	GameDirector.pause_enabled = false
	breath.close()
	ui.orb.visible = false
	cur_index = 0
	climber.position = holds[0].position
	climber.set_pose_stand()
	for h in holds:
		h.reachable = false
	ui.refresh_texts()
	ui.show_title(_best_text())
	if sound_on and not music.playing:
		music.play()

func _start_run() -> void:
	state = State.PLAY
	GameDirector.pause_enabled = true
	cur_index = 0
	checkpoint_index = 0
	calm = 100.0
	focus_t = 0.0
	light = 0
	breaths = 0
	slips = 0
	run_time = 0.0
	max_zone_seen = -1
	hazard_t = 5.0
	best_alt_this_run = 0.0
	for c in hazard_layer.get_children():
		c.queue_free()
	for h in holds:
		h.restore()
	climber.position = holds[0].position
	climber.set_pose_stand()
	breath.close()
	ui.orb.visible = false
	ui.show_game()
	if sound_on and not music.playing:
		music.play()
	_play("select")

func _on_director_state(_s: int) -> void:
	ui.set_paused(GameDirector.state == GameDirector.State.PAUSED)

# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAY or get_tree().paused:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		keyboard_mode = false
		if event.pressed:
			# Use the event's own position (works for touch-emulated clicks too).
			var target: KHold = _hold_under(get_canvas_transform().affine_inverse() * event.position)
			if target != null:
				_leap(target.index)
			elif _on_rest():
				pointer_breath = true
		else:
			pointer_breath = false
	elif event is InputEventMouseMotion:
		if keyboard_mode and event.relative.length() > 4.0:
			keyboard_mode = false
	elif event.is_action_pressed("k_up"):
		keyboard_mode = true
		_leap_dir(Vector2(0, -1))
	elif event.is_action_pressed("k_left"):
		keyboard_mode = true
		_leap_dir(Vector2(-0.8, -0.6))
	elif event.is_action_pressed("k_right"):
		keyboard_mode = true
		_leap_dir(Vector2(0.8, -0.6))
	elif event.is_action_pressed("k_down"):
		keyboard_mode = true
		_leap_dir(Vector2(0, 1))

func _hold_under(world_pos: Vector2) -> KHold:
	var best: KHold = null
	var best_d: float = INF
	for h in holds:
		if not h.reachable:
			continue
		var d: float = h.position.distance_to(world_pos)
		if d < h.pick_radius() and d < best_d:
			best = h
			best_d = d
	return best

func _best_in_dir(dir: Vector2) -> KHold:
	var from: Vector2 = holds[cur_index].position
	var best: KHold = null
	var best_score: float = -INF
	for h in holds:
		if not h.reachable:
			continue
		var delta: Vector2 = h.position - from
		var dot: float = delta.normalized().dot(dir.normalized())
		if dot < 0.45:
			continue
		# Prefer well-aligned holds, then the ones that gain the most height.
		var score: float = dot * 2.0 + (-delta.y if dir.y < 0.0 else delta.y) / REACH
		if score > best_score:
			best_score = score
			best = h
	if best == null and dir.x == 0.0 and dir.y < 0.0:
		# Nothing straight up: "up" still means "gain height" if any hold does.
		var best_gain: float = 10.0
		for h in holds:
			if h.reachable and from.y - h.position.y > best_gain:
				best_gain = from.y - h.position.y
				best = h
	return best

func _leap_dir(dir: Vector2) -> void:
	var h: KHold = _best_in_dir(dir)
	if h != null:
		_leap(h.index)
	elif not climber.busy:
		_play("bump", 0.8)

func _on_rest() -> bool:
	return not climber.busy and holds[cur_index].is_rest()

func _breath_pressed() -> bool:
	return pointer_breath or Input.is_action_pressed("k_breathe")

# ------------------------------------------------------------------ climbing

func _stand_pos(h: KHold) -> Vector2:
	return h.position + Vector2(0, -4) if h.is_platform() else h.position

func _leap(index: int) -> void:
	if climber.busy or index == cur_index:
		return
	var h: KHold = holds[index]
	if h.broken:
		return
	breath.close()
	ui.orb.visible = false
	pointer_breath = false
	calm -= LEAP_COST * (FOCUS_MULT if focus_t > 0.0 else 1.0)
	cur_index = index
	for o in holds:
		o.reachable = false
	climber.leap_to(_stand_pos(h), h.is_platform())
	_play("jump", randf_range(0.92, 1.08))

func _on_landed() -> void:
	if state != State.PLAY:
		return
	var h: KHold = holds[cur_index]
	_burst(_stand_pos(h) + Vector2(0, 10), TEX_SMOKE, Color(1, 1, 1, 0.5), 6, 60.0, 0.5, 0.12)
	match h.take_item():
		MountainGen.Item.STAR:
			light += 1
			calm = minf(100.0, calm + 6.0)
			_play("coin")
			_burst(h.position + Vector2(0, -44), TEX_STAR_FX, Color(1, 0.9, 0.4), 10, 160.0, 0.6, 0.18)
		MountainGen.Item.GEM:
			light += 5
			calm = minf(100.0, calm + 10.0)
			_play("gem")
			_burst(h.position + Vector2(0, -44), TEX_SPARK, Color(0.6, 0.9, 1.0), 14, 180.0, 0.7, 0.2)
			ui.toast(tr("msg_gem"), Color("9fe6ff"))
		MountainGen.Item.HEART:
			calm = minf(100.0, calm + 40.0)
			_play("magic")
			_burst(h.position + Vector2(0, -44), TEX_GLOW, Color(1, 0.5, 0.6), 8, 120.0, 0.7, 0.3)
			ui.toast(tr("msg_heart"), Color("ff8fa3"))
	if h.kind == MountainGen.Kind.CRUMBLE:
		h.touch_crumble()
		_play("bump", 0.7)
		ui.toast(tr("msg_crumble"), Color("ffb36b"), 1.2)
	if h.kind == MountainGen.Kind.LEDGE:
		if not h.lit:
			h.light_lantern()
			checkpoint_index = cur_index
			_play("magic", 1.1)
			_burst(h.position + Vector2(-58, -40), TEX_GLOW, Color(1, 0.8, 0.4), 10, 120.0, 0.9, 0.3)
			ui.toast(tr("msg_lantern"), Color("ffd166"), 1.8)
		_open_breath()
	elif h.kind == MountainGen.Kind.START:
		_open_breath()
	elif h.kind == MountainGen.Kind.SUMMIT:
		_finish()

func _open_breath() -> void:
	breath.open()
	ui.orb.visible = true
	ui.orb.armed = true
	ui.orb.amplitude = 0.0
	ui.orb_title.text = tr("breath_ready")
	ui.orb_sub.text = tr("breath_press")

func _slip() -> void:
	if climber.busy:
		return
	slips += 1
	_play("hurt")
	_shake = 10.0
	breath.close()
	ui.orb.visible = false
	pointer_breath = false
	ui.toast(tr("msg_slip"), Color("ffb3b3"), 2.4)
	var target: KHold = holds[checkpoint_index]
	cur_index = checkpoint_index
	for o in holds:
		o.reachable = false
	var dist: float = climber.position.distance_to(target.position)
	climber.fall_to(_stand_pos(target), clampf(dist / 900.0, 0.6, 2.2))
	for h in holds:
		h.restore()
	for c in hazard_layer.get_children():
		c.queue_free()
	calm = 70.0
	hazard_t = 6.0

func _finish() -> void:
	state = State.SUMMIT
	GameDirector.pause_enabled = false
	breath.close()
	ui.orb.visible = false
	_play("magic", 0.9)
	_play("high")
	for i in 4:
		_burst(holds[cur_index].position + Vector2(randf_range(-120, 120), -60), TEX_STAR_FX, Color.from_hsv(randf(), 0.5, 1.0), 16, 260.0, 1.4, 0.2)
	var p := _progress()
	var best: float = float(p.get("best_time", 0.0))
	var new_best: bool = best <= 0.0 or run_time < best
	if new_best:
		p["best_time"] = run_time
	p["summits"] = int(p.get("summits", 0)) + 1
	p["best_light"] = maxi(int(p.get("best_light", 0)), light)
	p["best_alt_m"] = maxi(int(p.get("best_alt_m", 0)), int(MountainGen.SUMMIT_HEIGHT / 10.0))
	GameDirector.save_data["progress"] = p
	SaveService.write_save(GameDirector.save_data)
	var stats: String = tr("summit_stats") % [_fmt_time(run_time), light, breaths, slips]
	var best_line: String = tr("summit_new_best") if new_best else (tr("summit_best") % _fmt_time(best))
	ui.show_summit(stats, best_line)

# ------------------------------------------------------------------ breathing

func _on_breath_tick(phase: int, pp: float, amp: float, left: float) -> void:
	ui.orb.armed = false
	ui.orb.phase = phase
	ui.orb.phase_progress = pp
	ui.orb.amplitude = amp
	climber.breath_amp = amp
	ui.orb_title.text = "%s  %d" % [BreathModel.phase_label(phase), int(ceil(left))]
	match phase:
		BreathModel.Phase.INHALE:
			ui.orb_sub.text = tr("breath_in_sub")
		BreathModel.Phase.HOLD:
			ui.orb_sub.text = tr("breath_hold_sub")
		_:
			ui.orb_sub.text = tr("breath_out_sub")

func _on_breath_finished(acc: float) -> void:
	breaths += 1
	calm = 100.0
	focus_t = 8.0 + 22.0 * acc
	var gained: int = int(round(3.0 + 7.0 * acc))
	light += gained
	climber.breath_amp = 0.0
	var key: String = "breath_ok"
	if acc >= 0.85:
		key = "breath_perfect"
	elif acc >= 0.6:
		key = "breath_good"
	ui.toast("%s  ·  %d%%" % [tr(key), int(round(acc * 100.0))], Color("ffd166"), 2.4)
	ui.set_hint(tr("breath_result") % [int(focus_t), gained])
	_play("magic", 1.2)
	_burst(climber.position + Vector2(0, -40), TEX_STAR_FX, Color(1, 0.85, 0.5), 18, 200.0, 1.0, 0.16)
	_open_breath()

# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_beams()
	if _autoplay:
		_autopilot(delta)
	elif _title_shot != "":
		_auto_t += delta
		if _auto_t > 1.5:
			get_viewport().get_texture().get_image().save_png(_title_shot)
			get_tree().quit()
	if state != State.PLAY:
		return
	run_time += delta
	var here: KHold = holds[cur_index]
	var zone: int = MountainGen.zone_of(climber.position.y)
	best_alt_this_run = maxf(best_alt_this_run, -climber.position.y)

	if zone > max_zone_seen:
		max_zone_seen = zone
		ui.banner(tr(_zone_key(zone)), tr(_zone_key(zone) + "_sub"))
		_set_weather(zone)
		if zone > 0:
			_play("high", 0.8)

	# Reachability + picking.
	var mouse_hold: KHold = null
	if not climber.busy:
		for h in holds:
			h.reachable = h.index != cur_index and not h.broken and h.position.distance_to(here.position) <= REACH
		if not keyboard_mode:
			mouse_hold = _hold_under(get_global_mouse_position())
	for h in holds:
		h.hovered = h == mouse_hold
		h.key_hint = ""
	if keyboard_mode and not climber.busy:
		var hints: Array = [[Vector2(-0.8, -0.6), "←"], [Vector2(0, -1), "↑"], [Vector2(0.8, -0.6), "→"], [Vector2(0, 1), "↓"]]
		for pair in hints:
			var c: KHold = _best_in_dir(pair[0])
			if c != null and c.key_hint == "":
				c.key_hint = pair[1]
				c.hovered = pair[1] == "↑"

	# Calm.
	if focus_t > 0.0:
		focus_t = maxf(0.0, focus_t - delta)
	if not climber.busy:
		if here.is_rest():
			calm = minf(100.0, calm + 3.0 * delta)
			breath.feed(_breath_pressed(), delta)
			ui.orb.matching = (_breath_pressed() == (ui.orb.phase != BreathModel.Phase.EXHALE))
		else:
			var rate: float = DRAIN[zone]
			if here.kind == MountainGen.Kind.SMALL:
				rate *= SMALL_MULT
			if focus_t > 0.0:
				rate *= FOCUS_MULT
			calm -= rate * delta
	climber.focus = 1.0 if focus_t > 0.0 else 0.0
	climber.shaking = clampf((30.0 - calm) / 30.0, 0.0, 1.0) if not here.is_rest() else 0.0
	if not here.is_rest():
		climber.breath_amp = 0.0

	# Crumbling holds.
	for h in holds:
		if h.crumble_left >= 0.0:
			h.crumble_left -= delta
			if h.crumble_left <= 0.0:
				h.break_away()
				_play("disappear")
				_burst(h.position, TEX_SMOKE, Color(0.8, 0.7, 0.6, 0.7), 8, 80.0, 0.6, 0.15)
				if h.index == cur_index and not climber.busy:
					_slip()
					return

	if calm <= 0.0 and not climber.busy:
		calm = 0.0
		_slip()
		return

	_update_hazards(delta, zone)

	# Hints.
	var hint: String = ""
	if here.kind == MountainGen.Kind.START and run_time < 12.0:
		hint = tr("hint_start")
	elif here.is_rest() and not breath.running:
		hint = tr("hint_rest") if run_time > 3.0 else ""
	elif not here.is_rest() and calm < 30.0:
		hint = tr("hint_low")
	if hint != "" or not here.is_rest() or breath.running:
		ui.set_hint(hint)

	var prog: float = clampf(-climber.position.y / MountainGen.SUMMIT_HEIGHT, 0.0, 1.0)
	ui.set_hud(calm, focus_t, int(maxf(0.0, -climber.position.y) / 10.0), tr(_zone_key(zone)), light, prog)

static func _zone_key(zone: int) -> String:
	return "zone_" + str(zone)

func _update_camera(delta: float) -> void:
	var target_y: float = climber.position.y - 130.0
	if state == State.TITLE:
		target_y = climber.position.y - 260.0
	elif state == State.SUMMIT:
		target_y = climber.position.y - 200.0
	target_y = minf(target_y, -120.0)
	_cam_y = lerpf(_cam_y, target_y, clampf(delta * 3.0, 0.0, 1.0))
	_shake = maxf(0.0, _shake - delta * 25.0)
	camera.position = Vector2(640, _cam_y) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	backdrop.altitude = maxf(0.0, -_cam_y - 120.0)
	backdrop.progress = clampf(-climber.position.y / MountainGen.SUMMIT_HEIGHT, 0.0, 1.0)

func _update_beams() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	for c in wall_layer.get_children():
		if c is Polygon2D and c.has_meta("beam"):
			(c as Polygon2D).modulate.a = 0.6 + 0.4 * sin(t * 0.6 + float(c.get_meta("beam")))

func _set_weather(zone: int) -> void:
	match zone:
		0, 1:
			weather.texture = TEX_LEAF
			weather.color = Color(0.55, 0.85, 0.45, 0.9) if zone == 0 else Color(0.95, 0.7, 0.35, 0.9)
			weather.gravity = Vector2(0, 18)
			weather.amount = 24
		2:
			weather.texture = TEX_LEAF
			weather.color = Color(1.0, 0.75, 0.85, 0.9) # drifting blossom petals
			weather.gravity = Vector2(10, 14)
			weather.amount = 30
		_:
			weather.texture = TEX_CIRCLE
			weather.color = Color(1, 1, 1, 0.85)
			weather.scale_amount_min = 0.04
			weather.scale_amount_max = 0.1
			weather.gravity = Vector2(14, 30)
			weather.amount = 70 if zone == 3 else 40

func _autopilot(delta: float) -> void:
	_auto_t += delta
	_auto_shot_t += delta
	if _auto_shot_t >= 6.0 and _auto_shot_dir != "":
		_auto_shot_t = 0.0
		_auto_shot_n += 1
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%03d.png" % [_auto_shot_dir, _auto_shot_n])
		print("[autoplay] shot %d state=%d alt=%dm calm=%d light=%d slips=%d breaths=%d t=%.1f" % [_auto_shot_n, state, int(-climber.position.y / 10.0), int(calm), light, slips, breaths, run_time])
	if state == State.TITLE and _auto_t > 2.0:
		_auto_t = 0.0
		_start_run()
		return
	if state != State.PLAY or climber.busy or get_tree().paused:
		return
	var here: KHold = holds[cur_index]
	if here.kind == MountainGen.Kind.LEDGE and not _auto_breathed.has(cur_index):
		pointer_breath = (not breath.running) or ui.orb.phase != BreathModel.Phase.EXHALE
		if breath.running:
			_auto_breathed[-1] = true
		elif _auto_breathed.has(-1):
			_auto_breathed.erase(-1)
			_auto_breathed[cur_index] = true
			pointer_breath = false
		return
	if _auto_t < 0.7:
		return
	_auto_t = 0.0
	var best: KHold = null
	for h in holds:
		if h.reachable and (best == null or h.position.y + (60.0 if h.item != MountainGen.Item.NONE else 0.0) * -1.0 < best.position.y):
			best = h
	if best != null:
		_leap(best.index)

# ------------------------------------------------------------------ hazards

func _update_hazards(delta: float, zone: int) -> void:
	var climbed: float = -climber.position.y
	if climbed > SAFE_START_PX and not holds[cur_index].is_rest():
		hazard_t -= delta
	if hazard_t <= 0.0:
		_spawn_hazard(zone)
		hazard_t = randf_range(9.0, 13.0) - zone * 1.2
	var body: Vector2 = climber.position + (Vector2(0, -36) if climber.standing else Vector2(0, 30))
	var view_top: float = _cam_y - get_viewport_rect().size.y * 0.5
	for c in hazard_layer.get_children():
		var hz: KHazard = c as KHazard
		if hz == null:
			continue
		hz.pin_warning(view_top + 40.0)
		if hz.position.y > _cam_y + 900.0:
			hz.queue_free()
			continue
		if hz.is_dangerous() and not holds[cur_index].is_rest() and hz.position.distance_to(body) < hz.radius + 24.0:
			hz.armed = false
			calm -= hz.damage
			_shake = 8.0
			_play("hurt", 1.15)
			climber.flash_hit()
			ui.toast(tr("msg_ouch"), Color("ff8f8f"), 1.0)

func _spawn_hazard(zone: int) -> void:
	var hz := KHazard.new()
	var rock_zone: bool = zone >= 2
	if rock_zone and randf() < 0.55:
		var x: float = clampf(climber.position.x + randf_range(-40.0, 40.0), MountainGen.X_MIN, MountainGen.X_MAX)
		hz.setup_rock(x, _cam_y - 400.0, 1.5)
	else:
		var variant: int = 0 if zone <= 1 else (1 if zone <= 3 else 2)
		var y: float = climber.position.y + randf_range(-200.0, 10.0)
		hz.setup_flyer(variant, randf() < 0.5, y, randf_range(110.0, 150.0) + zone * 12.0)
	hazard_layer.add_child(hz)

# ------------------------------------------------------------------ fx

func _burst(pos: Vector2, tex: Texture2D, color: Color, amount: int, speed: float, life: float, scale_amt: float) -> void:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 220)
	p.scale_amount_min = scale_amt * 0.6
	p.scale_amount_max = scale_amt
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.position = pos
	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)
