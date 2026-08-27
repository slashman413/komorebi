extends Node3D

@onready var ecology_system = $EcologySystem
@onready var soundscape_system = $SoundscapeSystem
@onready var audio_director = $AudioDirector
@onready var climb_system = $ClimbSystem
@onready var greybox_wall = $GreyboxWall

var ending_canvas: CanvasLayer

func _ready() -> void:
	print("[VerticalSlice] Level loaded.")
	
	audio_director.bind_ecology_system(ecology_system)
	soundscape_system.start_spirit_puzzle()
	ecology_system.update_vitality(0.2)

	var tel = get_node_or_null("/root/TelemetryService")
	if tel:
		tel.enable_telemetry(true)
		tel.track_onboarding_completed()

	var spike_scene = load("res://spike/breathing_spike.tscn")
	if spike_scene:
		var canvas = CanvasLayer.new()
		var spike_node = spike_scene.instantiate()
		canvas.add_child(spike_node)
		add_child(canvas)
		if tel:
			tel.track_breathing_engaged()

	_setup_ctas()
	
	if climb_system and greybox_wall:
		climb_system.climb_finished.connect(_on_climb_finished)
		var start_hold = greybox_wall.get_node_or_null("Hold1")
		if start_hold:
			climb_system.start_climb(start_hold)

func _setup_ctas() -> void:
	var cta_canvas = CanvasLayer.new()
	cta_canvas.layer = 100
	var cta_box = HBoxContainer.new()
	cta_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cta_box.offset_bottom = -20
	cta_box.offset_right = -20
	cta_box.alignment = BoxContainer.ALIGNMENT_END

	var wishlist_btn = Button.new()
	wishlist_btn.text = "ui_wishlist"
	wishlist_btn.pressed.connect(_on_wishlist_pressed)

	var itch_btn = Button.new()
	itch_btn.text = "ui_demo"
	itch_btn.pressed.connect(_on_itch_pressed)

	cta_box.add_child(wishlist_btn)
	cta_box.add_child(itch_btn)
	cta_canvas.add_child(cta_box)
	add_child(cta_canvas)

func _on_wishlist_pressed() -> void:
	OS.shell_open("steam://store/APPID")

func _on_itch_pressed() -> void:
	OS.shell_open("https://slashman413.itch.io/komorebi")

func _on_climb_finished() -> void:
	if not ending_canvas:
		ending_canvas = CanvasLayer.new()
		ending_canvas.layer = 150
		var color_rect = ColorRect.new()
		color_rect.color = Color(0, 0, 0, 0.7)
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		ending_canvas.add_child(color_rect)
		
		var center_container = CenterContainer.new()
		center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var end_label = Label.new()
		end_label.text = "ending_text"
		end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var end_sublabel = Label.new()
		end_sublabel.text = "ending_subtext"
		end_sublabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		vbox.add_child(end_label)
		vbox.add_child(end_sublabel)
		center_container.add_child(vbox)
		ending_canvas.add_child(center_container)
		add_child(ending_canvas)
