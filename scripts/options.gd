extends CanvasLayer
## The options menu: a slider for the music and one for the sound effects.
## Esc or the Options button opens it over the game (which pauses). The title screen opens it without pausing.

var _panel: Control
var _music_slider: HSlider
var _sfx_slider: HSlider
var _music_value: Label
var _sfx_value: Label
var _close: Button
var _pausing := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("options_menu")
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func open(pause_game := true) -> void:
	_pausing = pause_game
	_music_slider.set_value_no_signal(Settings.music_volume * 100.0)
	_sfx_slider.set_value_no_signal(Settings.sfx_volume * 100.0)
	_refresh_labels()
	_panel.visible = true
	if pause_game:
		get_tree().paused = true
	_close.grab_focus()


func close() -> void:
	if not _panel.visible:
		return
	_panel.visible = false
	if _pausing:
		get_tree().paused = false
	Settings.save()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if is_open():
			close()
		elif Game.title_seen and not get_tree().paused:
			open(true)
		get_viewport().set_input_as_handled()
		return
	if not is_open():
		return
	# Touch screens: mouse emulation is off, so drive the sliders and the button from the touches directly.
	if event is InputEventScreenTouch and event.pressed:
		if _close.get_global_rect().has_point(event.position):
			close()
		else:
			_touch_slider(event.position)
	elif event is InputEventScreenDrag:
		_touch_slider(event.position)


func _touch_slider(pos: Vector2) -> void:
	for slider in [_music_slider, _sfx_slider]:
		var rect: Rect2 = slider.get_global_rect().grow_individual(12, 18, 12, 18)
		if rect.has_point(pos):
			var amount := clampf((pos.x - slider.global_position.x) / slider.size.x, 0.0, 1.0)
			slider.value = amount * 100.0


func _build() -> void:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	_panel.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.11, 0.09, 0.96)
	style.border_color = Color(0.96, 0.78, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.custom_minimum_size = Vector2(440, 0)
	card.add_child(column)

	column.add_child(_label("OPTIONS", 34, Color(0.96, 0.78, 0.3)))

	var music_row := _slider_row("Music")
	_music_slider = music_row[0]
	_music_value = music_row[1]
	column.add_child(music_row[2])
	var sfx_row := _slider_row("Effects")
	_sfx_slider = sfx_row[0]
	_sfx_value = sfx_row[1]
	column.add_child(sfx_row[2])

	_music_slider.value_changed.connect(func(v: float) -> void:
		Settings.set_music(v / 100.0)
		_refresh_labels())
	_sfx_slider.value_changed.connect(func(v: float) -> void:
		Settings.set_sfx(v / 100.0)
		_refresh_labels())
	# Let the player hear the new effects level when they let go.
	_sfx_slider.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("shot", Vector3.INF, -6.0))

	_close = Button.new()
	_close.text = "Done"
	_close.custom_minimum_size = Vector2(180, 48)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.add_theme_font_size_override("font_size", 22)
	_close.pressed.connect(close)
	column.add_child(_close)
	column.add_child(_label("Esc opens this menu. M mutes the music.", 15, Color(0.7, 0.78, 0.72)))


func _slider_row(title: String) -> Array:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	var name_label := _label(title, 22, Color(0.92, 0.94, 0.9))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var value_label := _label("100%", 22, Color(0.96, 0.78, 0.3))
	head.add_child(value_label)
	box.add_child(head)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = 100.0
	slider.custom_minimum_size = Vector2(0, 32)
	box.add_child(slider)
	return [slider, value_label, box]


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _refresh_labels() -> void:
	_music_value.text = "%d%%" % roundi(_music_slider.value)
	_sfx_value.text = "%d%%" % roundi(_sfx_slider.value)
