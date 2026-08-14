extends Spatial

onready var ecology_system = $EcologySystem
onready var soundscape_system = $SoundscapeSystem
onready var audio_director = $AudioDirector

func _ready() -> void:
	print("[VerticalSlice] Level loaded.")
	
	# Wire up AudioDirector to EcologySystem
	audio_director.bind_ecology_system(ecology_system)
	
	# Initial tests
	soundscape_system.start_spirit_puzzle()
	ecology_system.update_vitality(0.2)

	var tel = get_node_or_null("/root/TelemetryService")
	if tel:
		tel.enable_telemetry(true)
		tel.track_onboarding_completed()

	var spike_scene = load("res://spike/breathing_spike.tscn")
	if spike_scene:
		var canvas = CanvasLayer.new()
		var spike_node = spike_scene.instance()
		canvas.add_child(spike_node)
		add_child(canvas)
		if tel:
			tel.track_breathing_engaged()

	var cta_canvas = CanvasLayer.new()
	cta_canvas.layer = 100
	var cta_box = HBoxContainer.new()
	cta_box.set_anchors_and_margins_preset(Control.PRESET_BOTTOM_RIGHT)
	cta_box.margin_bottom = -20
	cta_box.margin_right = -20
	cta_box.alignment = BoxContainer.ALIGN_END

	var wishlist_btn = Button.new()
	wishlist_btn.text = "Wishlist on Steam"
	wishlist_btn.connect("pressed", self, "_on_wishlist_pressed")

	var itch_btn = Button.new()
	itch_btn.text = "Demo on itch.io"
	itch_btn.connect("pressed", self, "_on_itch_pressed")

	cta_box.add_child(wishlist_btn)
	cta_box.add_child(itch_btn)
	cta_canvas.add_child(cta_box)
	add_child(cta_canvas)

func _on_wishlist_pressed() -> void:
	OS.shell_open("steam://store/APPID")

func _on_itch_pressed() -> void:
	OS.shell_open("https://slashman413.itch.io/komorebi")
