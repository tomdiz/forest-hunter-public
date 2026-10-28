extends CharacterBody3D
## A harmless wandering animal. It strolls to random spots near its home, pauses, and runs from the hunter.
## Animated models play their clips. A static model (the rabbit) hops instead.

enum State { IDLE, WANDER, FLEE }

@export var idle_clips: PackedStringArray = ["Idle", "Eating"]
@export var walk_clip := "Walk"
@export var run_clip := "Gallop"
@export var death_clip := "Death"
@export var walk_speed := 1.4
@export var run_speed := 5.0
@export var wander_radius := 8.0
@export var flee_range := 7.0
@export var calm_range := 11.0
@export var hops := false

const GRAVITY := 20.0
const TURN_SPEED := 8.0
const HOP_HEIGHT := 0.18

var state := State.IDLE
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _timer := 0.0
var _hop_time := 0.0
var _dead := false
var _player: Node3D

@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = get_node_or_null("Model/AnimationPlayer")
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var _model_y := model.position.y


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_home = global_position
	if anim:
		for clip in idle_clips + PackedStringArray([walk_clip, run_clip]):
			if anim.has_animation(clip):
				anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if anim.has_animation(death_clip):
			anim.get_animation(death_clip).loop_mode = Animation.LOOP_NONE
	_timer = randf_range(0.5, 3.0)
	_play_idle()


func _physics_process(delta: float) -> void:
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	if _dead or _player == null:
		move_and_slide()
		return

	var away := _flat(global_position - _player.global_position)
	if state != State.FLEE and away.length() < flee_range:
		_set_state(State.FLEE)
	elif state == State.FLEE and away.length() > calm_range:
		_set_state(State.IDLE)

	var move := Vector3.ZERO
	var speed := 0.0
	match state:
		State.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_target = _home + Vector3(randf_range(-wander_radius, wander_radius), 0.0, randf_range(-wander_radius, wander_radius))
				_set_state(State.WANDER)
		State.WANDER:
			_timer -= delta
			move = _steer(_target)
			speed = walk_speed
			if _flat(_target - global_position).length() < 0.7 or _timer <= 0.0:
				_set_state(State.IDLE)
		State.FLEE:
			move = _steer(global_position + away.normalized() * 10.0)
			speed = run_speed

	var dir := move.normalized() * speed
	velocity.x = dir.x
	velocity.z = dir.z
	move_and_slide()
	if move != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(move.x, move.z), TURN_SPEED * delta)
	_animate(delta, move != Vector3.ZERO and state != State.IDLE)


func take_damage(_amount: int) -> void:
	if _dead:
		return
	_dead = true
	Sfx.play("critter_hit", global_position + Vector3.UP * 0.5, -2.0)
	$Collision.set_deferred("disabled", true)
	if anim and anim.has_animation(death_clip):
		anim.play(death_clip, 0.1)
		get_tree().create_timer(3.0).timeout.connect(queue_free)
	else:
		queue_free()


func _set_state(new_state: State) -> void:
	state = new_state
	if new_state == State.IDLE:
		_timer = randf_range(2.0, 6.0)
		_play_idle()
	elif new_state == State.WANDER:
		_timer = 10.0


func _animate(delta: float, moving: bool) -> void:
	if hops:
		_hop_time += delta * (14.0 if state == State.FLEE else 9.0)
		model.position.y = _model_y + (absf(sin(_hop_time)) * HOP_HEIGHT if moving else 0.0)
		return
	if not moving:
		return
	var clip := run_clip if state == State.FLEE else walk_clip
	if anim.current_animation != clip:
		anim.play(clip, 0.2)


func _play_idle() -> void:
	if anim and not idle_clips.is_empty():
		anim.play(idle_clips[randi() % idle_clips.size()], 0.2)


# Next step along the navigation path, or straight at the target if there is no path yet.
func _steer(target: Vector3) -> Vector3:
	agent.target_position = target
	var step := _flat(agent.get_next_path_position() - global_position)
	return step if step.length() > 0.05 else _flat(target - global_position)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
