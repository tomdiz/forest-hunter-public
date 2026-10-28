extends CharacterBody3D

signal health_changed(health: int)
signal died

enum State { HIDDEN, PEEK, STALK, CHARGE, RETREAT, DEAD }

const MAX_HEALTH := 5
const WALK_SPEED := 2.0
const GALLOP_SPEED := 7.0
const GRAVITY := 20.0
const TURN_SPEED := 8.0
const PEEK_RANGE := 12.0
const CHARGE_RANGE := 5.0
const HIT_RANGE := 2.0
const HIDE_TIME := 2.0
const PEEK_TIME := 3.0
const STUN_TIME := 0.5
const SAFE_DISTANCE := 10.0
const CHARGE_GIVE_UP := 6.0

var health := MAX_HEALTH
var state := State.HIDDEN
var _state_time := 0.0
var _stun := 0.0
var _spot := Vector3.ZERO
var _player: Node3D

@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var head: Node3D = $Model/AnimalArmature/Skeleton3D/Head
@onready var agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	for clip in ["Idle", "Idle_Headlow", "Walk", "Gallop"]:
		anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	anim.get_animation("Death").loop_mode = Animation.LOOP_NONE
	add_to_group("stag")
	_player = get_tree().get_first_node_in_group("player")
	_spot = global_position
	_play(_clip_for_state())


func _physics_process(delta: float) -> void:
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	if state == State.DEAD or _player == null:
		move_and_slide()
		return

	_state_time += delta
	_stun = maxf(_stun - delta, 0.0)
	var to_player := _flat(_player.global_position - global_position)
	var move := Vector3.ZERO
	var speed := 0.0

	if _stun == 0.0:
		match state:
			State.HIDDEN:
				if _state_time > HIDE_TIME and to_player.length() < PEEK_RANGE:
					_set_state(State.PEEK)
			State.PEEK:
				move = to_player
				if _state_time > PEEK_TIME:
					_set_state(State.STALK)
			State.STALK:
				move = _steer(_player.global_position, to_player)
				speed = WALK_SPEED
				if to_player.length() < CHARGE_RANGE:
					_set_state(State.CHARGE)
			State.CHARGE:
				move = _steer(_player.global_position, to_player)
				speed = GALLOP_SPEED
				if _state_time > CHARGE_GIVE_UP:
					_set_state(State.RETREAT)  # blocked, for instance by a closed door
				if to_player.length() < HIT_RANGE:
					_player.take_hit()
					_set_state(State.RETREAT)
			State.RETREAT:
				var to_spot := _flat(_spot - global_position)
				move = _steer(_spot, to_spot)
				speed = GALLOP_SPEED
				if to_spot.length() < 0.6:
					_set_state(State.HIDDEN)
		_play(_clip_for_state())

	if move != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(move.x, move.z), TURN_SPEED * delta)
	var dir := move.normalized() * speed if state != State.PEEK else Vector3.ZERO
	velocity.x = dir.x
	velocity.z = dir.z
	move_and_slide()


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	health -= amount
	health_changed.emit(health)
	if health <= 0:
		_die()
		return
	Sfx.play("stag_hit", global_position + Vector3.UP * 1.5)
	_stun = STUN_TIME
	_play("Idle_HitReact1" if health % 2 == 0 else "Idle_HitReact2")
	if state == State.CHARGE:
		_set_state(State.RETREAT)
	elif state == State.HIDDEN or state == State.PEEK:
		_set_state(State.STALK)


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	Music.set_tension(new_state == State.STALK or new_state == State.CHARGE)
	if new_state == State.PEEK:
		Sfx.play("stag_snort", global_position + Vector3.UP * 1.5)
	elif new_state == State.CHARGE:
		Sfx.play("stag_bellow", global_position + Vector3.UP * 1.5, 3.0)
	if new_state == State.RETREAT:
		_spot = _pick_spot()


func _die() -> void:
	state = State.DEAD
	Music.set_tension(false)
	Sfx.play("stag_die", global_position + Vector3.UP * 1.5, 3.0)
	_play("Death")
	$Collision.set_deferred("disabled", true)
	for node_name in ["EyeL", "EyeR", "EyeGlow"]:
		head.get_node(node_name).hide()
	died.emit()
	print("The stag is dead")


# A hiding spot far from the hunter, other than the one we are at.
func _pick_spot() -> Vector3:
	var far: Array[Vector3] = []
	var best := global_position
	var best_distance := -1.0
	for spot: Node3D in get_tree().get_nodes_in_group("hide_spots"):
		var p := spot.global_position
		if p.distance_to(global_position) < 0.5:
			continue
		var d := _flat(p - _player.global_position).length()
		if d > SAFE_DISTANCE:
			far.append(p)
		if d > best_distance:
			best_distance = d
			best = p
	return far.pick_random() if not far.is_empty() else best


func _clip_for_state() -> String:
	match state:
		State.HIDDEN:
			return "Idle_Headlow"
		State.PEEK:
			return "Idle"
		State.STALK:
			return "Walk"
		State.CHARGE, State.RETREAT:
			return "Gallop"
	return "Death"


func _play(clip: String) -> void:
	if anim.current_animation != clip:
		anim.play(clip, 0.15)


# Next step along the navigation path. Falls back to a straight line if there is no path yet.
func _steer(target: Vector3, straight: Vector3) -> Vector3:
	agent.target_position = target
	var step := _flat(agent.get_next_path_position() - global_position)
	return step if step.length() > 0.05 else straight


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
