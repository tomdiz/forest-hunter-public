extends CanvasLayer
## The title screen. It sits over the live level (the forest ambience and the campfire keep going behind it) and
## holds the hunter still until the player starts. After a restart it is skipped.

const GOLD := Color(0.96, 0.78, 0.3)

var _player: Node
var _hud: CanvasLayer
var _touch_overlay: Control
var _rig: Node3D
var _panel: Control
var _prompt: Label
var _start: Button
var _options: Button
var _started := false
var _blink := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Game.title_seen:
		queue_free()
		return
	_build()
	_player = get_tree().get_first_node_in_group("player")
	_hud = get_parent().get_node_or_null("HUD")
	var touch := get_parent().get_node_or_null("TouchControls")
	if touch:
		_touch_overlay = touch.get_node_or_null("Overlay")
	_rig = get_parent().get_node_or_null("CameraRig")
	if _player:
		_player.locked = true
	if _rig:
		_rig.offset = Vector3(-2.2, 0.0, 2.2)  # hunter sits right of centre, clear of the text
	if _hud:
		_hud.visible = false
	if _touch_overlay:
		_touch_overlay.set_process_input(false)
	_start.grab_focus()


func _process(delta: float) -> void:
	_blink += delta
	_prompt.modulate.a = 0.55 + 0.45 * sin(_blink * 3.0)


func _input(event: InputEvent) -> void:
	if _started:
		return
	var menu := get_tree().get_first_node_in_group("options_menu")
	if menu and menu.is_open():
		return
	if event is InputEventScreenTouch and event.pressed:
		if _options.get_global_rect().has_point(event.position):
			_open_options()
		else:
			_begin()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		_begin()


func _build() -> void:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# A dark wash on the left, fading out toward the right where the hunter stands.
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.02, 0.05, 0.04, 0.82), Color(0.02, 0.05, 0.04, 0.0)])
	grad.offsets = PackedFloat32Array([0.25, 0.85])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	tex.width = 512
	tex.height = 8
	var wash := TextureRect.new()
	wash.texture = tex
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_right", 72)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	column.add_child(_label("A HUNT IN THE PINES", 20, Color(0.8, 0.88, 0.82)))
	column.add_child(_label("FOREST HUNTER", 84, GOLD))
	column.add_child(_label("Follow the river. Find the stag with the red eyes.", 24, Color(0.92, 0.94, 0.9)))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	_start = Button.new()
	_start.text = "Play"
	_start.custom_minimum_size = Vector2(220, 54)
	_start.add_theme_font_size_override("font_size", 26)
	_start.pressed.connect(_begin)
	buttons.add_child(_start)
	_options = Button.new()
	_options.text = "Options"
	_options.custom_minimum_size = Vector2(160, 54)
	_options.add_theme_font_size_override("font_size", 22)
	_options.pressed.connect(_open_options)
	buttons.add_child(_options)

	_prompt = _label("Press Enter or tap to start", 18, Color(0.85, 0.9, 0.85))
	column.add_child(_prompt)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 10)
	column.add_child(gap2)
	for line in [
		"MAC     WASD or arrows move  \u00b7  mouse aims  \u00b7  click or Space fires  \u00b7  R reloads",
		"IPHONE  left thumb moves  \u00b7  right thumb aims and fires  \u00b7  R button reloads",
		"The stag hides, stalks and charges. Five hits bring it down. Three hits bring you down.",
		"E uses things, like the cabin door and bed. M mutes the music.",
	]:
		var l := _label(line, 16, Color(0.78, 0.84, 0.8))
		l.add_theme_constant_override("outline_size", 4)
		column.add_child(l)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	return l


func _open_options() -> void:
	var menu := get_tree().get_first_node_in_group("options_menu")
	if menu:
		menu.open(false)


func _begin() -> void:
	if _started:
		return
	_started = true
	Game.title_seen = true
	Sfx.play("pickup", Vector3.INF, -8.0)
	if _player:
		_player.locked = false
	if _hud:
		_hud.visible = true
	if _touch_overlay:
		_touch_overlay.set_process_input(_touch_overlay.visible)
	if _rig:
		create_tween().tween_property(_rig, "offset", Vector3.ZERO, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var fade := create_tween()
	fade.tween_property(_panel, "modulate:a", 0.0, 0.45)
	fade.tween_callback(queue_free)
