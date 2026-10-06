class_name KUI
extends CanvasLayer

## All screen-space UI: HUD, breathing orb, toasts, and the title / pause /
## summit screens. Emits intent signals; main.gd owns the rules.

signal play_pressed
signal resume_pressed
signal restart_pressed
signal title_pressed
signal sound_pressed
signal lang_pressed
signal again_pressed
signal support_pressed

const TEX_HEART: Texture2D = preload("res://assets/sprites/hud_heart.png")
const TEX_STAR: Texture2D = preload("res://assets/sprites/star.png")
const TEX_CLIMBER: Texture2D = preload("res://assets/sprites/character_green_front.png")

const FONT_DISPLAY: Font = preload("res://assets/fonts/kenney_future.ttf")
const C_INK := Color("f4f8f6")
const C_SHADOW := Color(0.04, 0.1, 0.14, 0.85)
const C_MINT := Color("7fd1b9")
const C_GOLD := Color("ffd166")
const C_PANEL := Color(0.05, 0.11, 0.16, 0.82)

var hud: Control
var calm_bar: ProgressBar
var focus_label: Label
var alt_label: Label
var zone_label: Label
var light_label: Label
var hint_label: Label
var toast_label: Label
var banner_label: Label
var banner_sub: Label
var vignette: ColorRect
var orb: KBreathOrb
var orb_title: Label
var orb_sub: Label
var progress_track: Control
var progress_dot: TextureRect

var title_screen: Control
var title_best: Label
var title_howto: Array[Label] = []
var btn_play: Button
var btn_lang_t: Button
var btn_sound_t: Button

var pause_screen: Control
var btn_sound_p: Button
var btn_lang_p: Button

var summit_screen: Control
var summit_title: Label
var summit_stats: Label
var summit_best: Label
var summit_tip: Label

var _toast_t: float = 0.0
var _banner_t: float = 0.0
var _t: float = 0.0
var sound_on: bool = true

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_title()
	_build_pause()
	_build_summit()
	refresh_texts()

# --------------------------------------------------------------------- builders

func _label(parent: Node, size_px: int, color: Color = C_INK, outline: int = 8) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", C_SHADOW)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _button(parent: Node, primary: bool = false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(300, 58) if primary else Vector2(220, 46)
	b.add_theme_font_size_override("font_size", 26 if primary else 19)
	var base := StyleBoxFlat.new()
	base.bg_color = C_MINT if primary else Color(1, 1, 1, 0.12)
	base.set_corner_radius_all(14)
	base.content_margin_left = 22
	base.content_margin_right = 22
	base.border_color = Color(1, 1, 1, 0.25)
	base.set_border_width_all(0 if primary else 2)
	var hover: StyleBoxFlat = base.duplicate()
	hover.bg_color = Color("9ee6cf") if primary else Color(1, 1, 1, 0.22)
	var pressed: StyleBoxFlat = base.duplicate()
	pressed.bg_color = Color("5fb89e") if primary else Color(1, 1, 1, 0.3)
	var focus: StyleBoxFlat = hover.duplicate()
	focus.border_color = C_GOLD
	focus.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	var ink: Color = Color("06232a") if primary else C_INK
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink)
	b.add_theme_color_override("font_pressed_color", ink)
	b.add_theme_color_override("font_focus_color", ink)
	parent.add_child(b)
	return b

func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_PANEL
	s.set_corner_radius_all(24)
	s.content_margin_left = 40
	s.content_margin_right = 40
	s.content_margin_top = 30
	s.content_margin_bottom = 30
	s.border_color = Color(1, 1, 1, 0.12)
	s.set_border_width_all(2)
	return s

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.8, 0.15, 0.2, 0.0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(vignette)

	# Top-left: calm.
	var heart := TextureRect.new()
	heart.texture = TEX_HEART
	heart.position = Vector2(18, 14)
	heart.size = Vector2(44, 44)
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(heart)
	calm_bar = ProgressBar.new()
	calm_bar.position = Vector2(70, 22)
	calm_bar.size = Vector2(260, 26)
	calm_bar.max_value = 100.0
	calm_bar.show_percentage = false
	calm_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.35)
	bg.set_corner_radius_all(13)
	bg.border_color = Color(1, 1, 1, 0.5)
	bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_MINT
	fill.set_corner_radius_all(13)
	calm_bar.add_theme_stylebox_override("background", bg)
	calm_bar.add_theme_stylebox_override("fill", fill)
	hud.add_child(calm_bar)
	focus_label = _label(hud, 18, C_GOLD, 6)
	focus_label.position = Vector2(72, 52)

	# Top-centre: altitude + zone.
	alt_label = _label(hud, 34)
	_place(alt_label, Control.PRESET_CENTER_TOP, Vector2(-200, 8), Vector2(400, 40))
	alt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_label = _label(hud, 18, Color(1, 1, 1, 0.85), 6)
	_place(zone_label, Control.PRESET_CENTER_TOP, Vector2(-200, 50), Vector2(400, 26))
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Top-right: sunlight collected.
	var star := TextureRect.new()
	star.texture = TEX_STAR
	_place(star, Control.PRESET_TOP_RIGHT, Vector2(-170, 12), Vector2(46, 46))
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(star)
	light_label = _label(hud, 32)
	_place(light_label, Control.PRESET_TOP_RIGHT, Vector2(-118, 12), Vector2(100, 40))

	# Right edge: a vertical trail showing how far up the mountain you are.
	progress_track = Control.new()
	progress_track.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	progress_track.offset_top = 110
	progress_track.offset_bottom = -110
	progress_track.offset_left = -30
	progress_track.offset_right = -22
	progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track_bg := ColorRect.new()
	track_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	track_bg.color = Color(1, 1, 1, 0.25)
	track_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.add_child(track_bg)
	progress_dot = TextureRect.new()
	progress_dot.texture = TEX_CLIMBER
	progress_dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	progress_dot.size = Vector2(34, 34)
	progress_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.add_child(progress_dot)
	hud.add_child(progress_track)

	# Breathing orb (only while resting on a lantern ledge).
	orb = KBreathOrb.new()
	_place(orb, Control.PRESET_CENTER_LEFT, Vector2(60, -150), Vector2(300, 300))
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.visible = false
	hud.add_child(orb)
	orb_title = _label(orb, 30)
	orb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orb_title.position = Vector2(-50, 310)
	orb_title.size = Vector2(400, 40)
	orb_sub = _label(orb, 18, Color(1, 1, 1, 0.9), 6)
	orb_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orb_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	orb_sub.position = Vector2(-50, 350)
	orb_sub.size = Vector2(400, 60)

	hint_label = _label(hud, 22, C_INK, 8)
	_place(hint_label, Control.PRESET_CENTER_BOTTOM, Vector2(-420, -96), Vector2(840, 64))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	toast_label = _label(hud, 34, C_GOLD, 10)
	_place(toast_label, Control.PRESET_CENTER, Vector2(-380, -230), Vector2(760, 90))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	banner_label = _label(hud, 56, C_INK, 12)
	_place(banner_label, Control.PRESET_CENTER, Vector2(-500, -140), Vector2(1000, 70))
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub = _label(hud, 22, Color(1, 1, 1, 0.9), 8)
	_place(banner_sub, Control.PRESET_CENTER, Vector2(-500, -66), Vector2(1000, 30))
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var pause_btn := _button(hud)
	pause_btn.text = "II"
	pause_btn.custom_minimum_size = Vector2(52, 46)
	_place(pause_btn, Control.PRESET_TOP_RIGHT, Vector2(-70, 70), Vector2(52, 46))
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(func() -> void: GameDirector.toggle_pause())
	hud.visible = false

func _screen(dim: float) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.06, 0.09, dim)
	root.add_child(shade)
	return root

func _build_title() -> void:
	title_screen = _screen(0.25)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	var logo := _label(col, 96, C_INK, 18)
	logo.text = "KOMOREBI"
	logo.add_theme_font_override("font", FONT_DISPLAY)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var kanji := _label(col, 30, C_GOLD, 10)
	kanji.name = "Sub"
	kanji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var how := PanelContainer.new()
	how.add_theme_stylebox_override("panel", _panel_style())
	col.add_child(how)
	var how_col := VBoxContainer.new()
	how_col.add_theme_constant_override("separation", 8)
	how.add_child(how_col)
	for i in 4:
		var l := _label(how_col, 20, C_INK, 0)
		l.custom_minimum_size = Vector2(640, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_howto.append(l)

	btn_play = _button(col, true)
	btn_play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_play.pressed.connect(func() -> void: play_pressed.emit())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	btn_lang_t = _button(row)
	btn_lang_t.pressed.connect(func() -> void: lang_pressed.emit())
	btn_sound_t = _button(row)
	btn_sound_t.pressed.connect(func() -> void: sound_pressed.emit())
	title_best = _label(col, 18, Color(1, 1, 1, 0.85), 6)
	title_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var credit := _label(col, 14, Color(1, 1, 1, 0.7), 4)
	credit.text = "Built by @slashman413  ·  Art & sfx: Kenney.nl (CC0)"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_pause() -> void:
	pause_screen = _screen(0.6)
	pause_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_screen.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var t := _label(col, 44)
	t.name = "Title"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b1 := _button(col, true)
	b1.name = "Resume"
	b1.pressed.connect(func() -> void: resume_pressed.emit())
	var b2 := _button(col)
	b2.name = "Restart"
	b2.pressed.connect(func() -> void: restart_pressed.emit())
	btn_sound_p = _button(col)
	btn_sound_p.pressed.connect(func() -> void: sound_pressed.emit())
	btn_lang_p = _button(col)
	btn_lang_p.pressed.connect(func() -> void: lang_pressed.emit())
	var b3 := _button(col)
	b3.name = "ToTitle"
	b3.pressed.connect(func() -> void: title_pressed.emit())

func _build_summit() -> void:
	summit_screen = _screen(0.2)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Keep the panel in the upper part of the screen so the flag stays visible.
	center.anchor_bottom = 0.66
	summit_screen.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	summit_title = _label(col, 48, C_GOLD, 12)
	summit_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summit_stats = _label(col, 24)
	summit_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summit_best = _label(col, 20, C_MINT, 6)
	summit_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summit_tip = _label(col, 18, Color(1, 1, 1, 0.85), 4)
	summit_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summit_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summit_tip.custom_minimum_size = Vector2(560, 0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var again := _button(row, true)
	again.name = "Again"
	again.pressed.connect(func() -> void: again_pressed.emit())
	var sup := _button(row)
	sup.name = "Support"
	sup.custom_minimum_size = Vector2(240, 58)
	sup.pressed.connect(func() -> void: support_pressed.emit())

## Pin a control to a preset anchor point with an explicit offset rect, so it
## stays put however the browser window is resized.
func _place(c: Control, preset: int, pos: Vector2, sz: Vector2) -> void:
	var a := Vector2.ZERO
	match preset:
		Control.PRESET_CENTER_TOP:
			a = Vector2(0.5, 0.0)
		Control.PRESET_TOP_RIGHT:
			a = Vector2(1.0, 0.0)
		Control.PRESET_CENTER_LEFT:
			a = Vector2(0.0, 0.5)
		Control.PRESET_CENTER_BOTTOM:
			a = Vector2(0.5, 1.0)
		Control.PRESET_CENTER:
			a = Vector2(0.5, 0.5)
	c.anchor_left = a.x
	c.anchor_right = a.x
	c.anchor_top = a.y
	c.anchor_bottom = a.y
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + sz.x
	c.offset_bottom = pos.y + sz.y

# ------------------------------------------------------------------ text/state

func refresh_texts() -> void:
	(title_screen.find_child("Sub", true, false) as Label).text = tr("title_sub")
	for i in title_howto.size():
		var key: String = "howto_" + str(i + 1)
		title_howto[i].text = tr(key)
	btn_play.text = tr("btn_play")
	var lang_txt: String = tr("btn_lang")
	btn_lang_t.text = lang_txt
	btn_lang_p.text = lang_txt
	var snd: String = tr("btn_sound_on") if sound_on else tr("btn_sound_off")
	btn_sound_t.text = snd
	btn_sound_p.text = snd
	(pause_screen.find_child("Title", true, false) as Label).text = tr("pause_title")
	(pause_screen.find_child("Resume", true, false) as Button).text = tr("btn_resume")
	(pause_screen.find_child("Restart", true, false) as Button).text = tr("btn_restart")
	(pause_screen.find_child("ToTitle", true, false) as Button).text = tr("btn_title")
	(summit_screen.find_child("Again", true, false) as Button).text = tr("btn_again")
	(summit_screen.find_child("Support", true, false) as Button).text = tr("btn_support")
	summit_title.text = tr("summit_title")
	summit_tip.text = tr("summit_tip")

func show_title(best_text: String) -> void:
	title_best.text = best_text
	title_screen.visible = true
	hud.visible = false
	summit_screen.visible = false
	pause_screen.visible = false
	btn_play.grab_focus()

func show_game() -> void:
	title_screen.visible = false
	summit_screen.visible = false
	pause_screen.visible = false
	hud.visible = true

func set_paused(p: bool) -> void:
	pause_screen.visible = p
	if p:
		(pause_screen.find_child("Resume", true, false) as Button).grab_focus()

func show_summit(stats: String, best: String) -> void:
	hud.visible = false
	orb.visible = false
	summit_stats.text = stats
	summit_best.text = best
	summit_screen.visible = true
	summit_screen.modulate.a = 0.0
	create_tween().tween_property(summit_screen, "modulate:a", 1.0, 0.8)
	(summit_screen.find_child("Again", true, false) as Button).grab_focus()

func toast(text: String, color: Color = C_GOLD, seconds: float = 1.6) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	_toast_t = seconds

func banner(title: String, sub: String) -> void:
	banner_label.text = title
	banner_sub.text = sub
	_banner_t = 3.2

func set_hud(calm: float, focus_secs: float, altitude_m: int, zone_name: String, light: int, progress: float) -> void:
	calm_bar.value = calm
	var fill: StyleBoxFlat = calm_bar.get_theme_stylebox("fill")
	fill.bg_color = C_MINT.lerp(Color("ff6b6b"), clampf((35.0 - calm) / 35.0, 0.0, 1.0))
	focus_label.text = ("%s  %ds" % [tr("hud_focus"), int(ceil(focus_secs))]) if focus_secs > 0.0 else ""
	alt_label.text = "%d m" % altitude_m
	zone_label.text = zone_name
	light_label.text = str(light)
	var h: float = progress_track.size.y
	progress_dot.position = Vector2(-13, (1.0 - clampf(progress, 0.0, 1.0)) * h - 17.0)
	vignette.color.a = clampf((25.0 - calm) / 25.0, 0.0, 1.0) * (0.12 + 0.08 * sin(_t * 6.0))

func set_hint(text: String) -> void:
	hint_label.text = text

func _process(delta: float) -> void:
	_t += delta
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_label.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
		var rise: float = (1.6 - clampf(_toast_t, 0.0, 1.6)) * 12.0
		toast_label.offset_top = -230.0 - rise
		toast_label.offset_bottom = -140.0 - rise
	else:
		toast_label.modulate.a = 0.0
	if _banner_t > 0.0:
		_banner_t -= delta
		var a: float = clampf(minf(3.2 - _banner_t, _banner_t) * 1.5, 0.0, 1.0)
		banner_label.modulate.a = a
		banner_sub.modulate.a = a
	else:
		banner_label.modulate.a = 0.0
		banner_sub.modulate.a = 0.0
