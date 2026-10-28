extends CanvasLayer
## Hearts, ammo and stag health, plus the win and lose screens. The UI is built in code.

const HEART_ON := Color(0.86, 0.16, 0.16)
const HEART_OFF := Color(0.22, 0.22, 0.22, 0.85)
const END_DELAY := 1.6

var _player: Node
var _stag: Node
var _hearts: Array[ColorRect] = []
var _stag_bar: ProgressBar
var _ammo_label: Label
var _end_panel: Control
var _end_title: Label
var _end_subtitle: Label
var _restart: Button
var _prompt: Label
var _toast_label: Label
var _blink_rect: ColorRect
var _toast_tween: Tween
var _reloading := false
var _ended := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	add_to_group("hud")
	_build()
	_player = get_tree().get_first_node_in_group("player")
	_stag = get_tree().get_first_node_in_group("stag")
	if _player:
		_player.health_changed.connect(_on_player_health)
		_player.ammo_changed.connect(_on_ammo)
		_player.reloading_changed.connect(_on_reloading)
		_player.died.connect(_end.bind(false))
		_on_player_health(_player.health)
		_on_ammo(_player.mag, _player.reserve)
	if _stag:
		_stag.health_changed.connect(_on_stag_health)
		_stag.died.connect(_end.bind(true))
		_stag_bar.max_value = _stag.MAX_HEALTH
		_stag_bar.value = _stag.health


func _build() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var hearts := HBoxContainer.new()
	hearts.add_theme_constant_override("separation", 6)
	root.add_child(hearts)
	hearts.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	for i in 3:
		var heart := ColorRect.new()
		heart.custom_minimum_size = Vector2(28, 28)
		heart.color = HEART_ON
		hearts.add_child(heart)
		_hearts.append(heart)

	var stag_box := VBoxContainer.new()
	stag_box.add_theme_constant_override("separation", 4)
	root.add_child(stag_box)
	stag_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 20)
	var stag_name := _label("THE STAG", 18)
	stag_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stag_box.add_child(stag_name)
	_stag_bar = ProgressBar.new()
	_stag_bar.custom_minimum_size = Vector2(320, 16)
	_stag_bar.show_percentage = false
	_stag_bar.max_value = 5
	_stag_bar.value = 5
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.12, 0.12)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	_stag_bar.add_theme_stylebox_override("fill", fill)
	_stag_bar.add_theme_stylebox_override("background", back)
	stag_box.add_child(_stag_bar)

	var options := Button.new()
	options.text = "Options"
	options.custom_minimum_size = Vector2(120, 40)
	options.add_theme_font_size_override("font_size", 18)
	options.pressed.connect(_open_options)
	root.add_child(options)
	options.anchor_left = 1.0
	options.anchor_right = 1.0
	options.offset_left = -140.0
	options.offset_right = -20.0
	options.offset_top = 20.0
	options.offset_bottom = 60.0

	_prompt = _label("", 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	_bottom_centre(root, _prompt, 110.0)
	_toast_label = _label("", 22)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.modulate.a = 0.0
	_bottom_centre(root, _toast_label, 170.0)
	_blink_rect = ColorRect.new()
	_blink_rect.color = Color.BLACK
	_blink_rect.modulate.a = 0.0
	_blink_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_blink_rect)
	_blink_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_ammo_label = _label("", 26)
	root.add_child(_ammo_label)
	_ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)

	_end_panel = Control.new()
	_end_panel.visible = false
	root.add_child(_end_panel)
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	_end_panel.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_end_panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	_end_title = _label("", 64)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_end_title)
	_end_subtitle = _label("", 24)
	_end_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_end_subtitle)
	_restart = Button.new()
	_restart.text = "Play again"
	_restart.custom_minimum_size = Vector2(200, 48)
	_restart.add_theme_font_size_override("font_size", 22)
	_restart.pressed.connect(_on_restart)
	column.add_child(_restart)


# A label across the bottom of the screen, centred, this many pixels above the bottom edge.
func _bottom_centre(root: Control, label: Label, above: float) -> void:
	root.add_child(label)
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = -above
	label.offset_bottom = -above + 40.0


# Shown while the hunter stands next to something he can use.
func _process(_delta: float) -> void:
	if _player == null:
		return
	var target: Area3D = _player.nearest_interactable()
	_prompt.visible = target != null and not _ended and not get_tree().paused
	if _prompt.visible:
		_prompt.text = ("Tap E   " if _player.touch_mode else "E   ") + target.prompt


## A short message near the bottom of the screen that fades away.
func toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.8)


## Fade to black and back, over this many seconds.
func blink(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_blink_rect, "modulate:a", 1.0, seconds * 0.35)
	tween.tween_interval(seconds * 0.3)
	tween.tween_property(_blink_rect, "modulate:a", 0.0, seconds * 0.35)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


func _open_options() -> void:
	var menu := get_tree().get_first_node_in_group("options_menu")
	if menu and not _end_panel.visible:
		menu.open(true)


# On a touch screen, tapping anywhere on the end screen plays again.
func _input(event: InputEvent) -> void:
	if _end_panel.visible and event is InputEventScreenTouch and event.pressed:
		_on_restart()


func _on_player_health(health: int) -> void:
	for i in _hearts.size():
		_hearts[i].color = HEART_ON if i < health else HEART_OFF


func _on_stag_health(health: int) -> void:
	_stag_bar.value = health


func _on_ammo(mag: int, reserve: int) -> void:
	_ammo_label.text = "AMMO  %d / %d" % [mag, reserve]
	if _reloading:
		_ammo_label.text += "   RELOADING"


func _on_reloading(active: bool) -> void:
	_reloading = active
	_on_ammo(_player.mag, _player.reserve)


func _end(won: bool) -> void:
	if _ended:
		return
	_ended = true
	Music.stop(1.0)
	await get_tree().create_timer(END_DELAY).timeout
	_end_title.text = "YOU GOT IT" if won else "GAME OVER"
	_end_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3) if won else Color(0.9, 0.25, 0.25))
	_end_subtitle.text = "The stag is down." if won else "The stag got you."
	_end_panel.visible = true
	Sfx.play("win" if won else "lose", Vector3.INF, -3.0)
	get_tree().paused = true
	_restart.grab_focus()


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
