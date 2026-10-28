extends Control
## Two floating thumb sticks and a reload button for touch screens.
## Left half of the screen moves the hunter. Right half aims, and firing starts when the stick is pushed out.
## It feeds the same input actions the keyboard uses, so the player script needs no separate path for movement.

@export var always_show := false  # show on a computer too, for testing

const STICK_RADIUS := 90.0
const KNOB_RADIUS := 38.0
const DEADZONE := 0.2
const FIRE_THRESHOLD := 0.4
const RELOAD_RADIUS := 46.0
const MARGIN := 80.0

var _move_id := -1
var _move_origin := Vector2.ZERO
var _move_pos := Vector2.ZERO
var _aim_id := -1
var _aim_origin := Vector2.ZERO
var _aim_pos := Vector2.ZERO
var _reload_id := -1
var _has_prompt := false  # something is in reach, so show the E button
var _player: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player = get_tree().get_first_node_in_group("player")
	_set_active(DisplayServer.is_touchscreen_available() or always_show)


func _set_active(on: bool) -> void:
	visible = on
	if _player:
		_player.touch_mode = on
	set_process_input(on)
	queue_redraw()


func _reload_center() -> Vector2:
	return Vector2(size.x - MARGIN, size.y - MARGIN)


func _interact_center() -> Vector2:
	return Vector2(size.x - MARGIN, size.y - MARGIN - RELOAD_RADIUS * 2.6)


func _process(_delta: float) -> void:
	var has := _player != null and _player.nearest_interactable() != null
	if has != _has_prompt:
		_has_prompt = has
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _move_id:
			_move_pos = event.position
		elif event.index == _aim_id:
			_aim_pos = event.position
		_apply()


func _press(index: int, pos: Vector2) -> void:
	if Rect2(size.x - 190.0, 0.0, 190.0, 80.0).has_point(pos):
		# The Options button lives in this corner.
		var menu := get_tree().get_first_node_in_group("options_menu")
		if menu:
			menu.open(true)
	elif _has_prompt and pos.distance_to(_interact_center()) < RELOAD_RADIUS * 1.4:
		_tap_interact()
	elif pos.distance_to(_reload_center()) < RELOAD_RADIUS * 1.4:
		_reload_id = index
		_tap_reload()
	elif pos.x < size.x * 0.5:
		if _move_id == -1:
			_move_id = index
			_move_origin = pos
			_move_pos = pos
	elif _aim_id == -1:
		_aim_id = index
		_aim_origin = pos
		_aim_pos = pos
	_apply()


func _release(index: int) -> void:
	if index == _move_id:
		_move_id = -1
	elif index == _aim_id:
		_aim_id = -1
	elif index == _reload_id:
		_reload_id = -1
	_apply()


func _tap_reload() -> void:
	Input.action_press("reload")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("reload")


func _tap_interact() -> void:
	Input.action_press("interact")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("interact")


func _stick(origin: Vector2, pos: Vector2) -> Vector2:
	var v := (pos - origin) / STICK_RADIUS
	return v.limit_length(1.0)


# Turn the finger positions into input actions and the aim direction.
func _apply() -> void:
	var move := _stick(_move_origin, _move_pos) if _move_id != -1 else Vector2.ZERO
	if move.length() < DEADZONE:
		move = Vector2.ZERO
	_set_action("move_left", maxf(-move.x, 0.0))
	_set_action("move_right", maxf(move.x, 0.0))
	_set_action("move_up", maxf(-move.y, 0.0))
	_set_action("move_down", maxf(move.y, 0.0))

	var aim := _stick(_aim_origin, _aim_pos) if _aim_id != -1 else Vector2.ZERO
	if _player:
		_player.touch_aim = aim.normalized() if aim.length() >= DEADZONE else Vector2.ZERO
	_set_action("shoot", 1.0 if aim.length() >= FIRE_THRESHOLD else 0.0)
	queue_redraw()


func _set_action(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _draw() -> void:
	var ring := Color(1, 1, 1, 0.28)
	var fill := Color(1, 1, 1, 0.1)
	var knob := Color(1, 1, 1, 0.5)
	# Resting hints, so a new player sees where the sticks go.
	var hint_left := Vector2(MARGIN + STICK_RADIUS, size.y - MARGIN - STICK_RADIUS * 0.6)
	var hint_right := Vector2(size.x - MARGIN - STICK_RADIUS * 2.4, size.y - MARGIN - STICK_RADIUS * 0.6)
	if _move_id == -1:
		draw_arc(hint_left, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.14), 3.0)
	if _aim_id == -1:
		draw_arc(hint_right, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.14), 3.0)
	if _move_id != -1:
		draw_circle(_move_origin, STICK_RADIUS, fill)
		draw_arc(_move_origin, STICK_RADIUS, 0.0, TAU, 48, ring, 3.0)
		draw_circle(_move_origin + (_move_pos - _move_origin).limit_length(STICK_RADIUS), KNOB_RADIUS, knob)
	if _aim_id != -1:
		draw_circle(_aim_origin, STICK_RADIUS, fill)
		draw_arc(_aim_origin, STICK_RADIUS, 0.0, TAU, 48, ring, 3.0)
		draw_circle(_aim_origin + (_aim_pos - _aim_origin).limit_length(STICK_RADIUS), KNOB_RADIUS, Color(1.0, 0.7, 0.3, 0.6) if _stick(_aim_origin, _aim_pos).length() >= FIRE_THRESHOLD else knob)
	var c := _reload_center()
	draw_circle(c, RELOAD_RADIUS, Color(0, 0, 0, 0.35))
	draw_arc(c, RELOAD_RADIUS, 0.0, TAU, 32, ring, 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, c + Vector2(-9, 9), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.8))
	if _has_prompt:
		var e := _interact_center()
		draw_circle(e, RELOAD_RADIUS, Color(0.96, 0.78, 0.3, 0.45))
		draw_arc(e, RELOAD_RADIUS, 0.0, TAU, 32, Color(0.96, 0.78, 0.3, 0.9), 3.0)
		draw_string(font, e + Vector2(-9, 9), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.95))
