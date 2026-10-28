extends CharacterBody3D

const SPEED := 5.0
const GRAVITY := 20.0
const TURN_SPEED := 20.0
# The camera looks along (-1, 0, -1), so input is turned 45 degrees to match the screen.
const CAMERA_YAW := 45.0
const AIM_HEIGHT := 1.3
const FIRE_INTERVAL := 0.25
const RANGE := 40.0
# The gun is a placeholder box (actors/placeholder_gun.tscn), because the original weapon models can't be redistributed.
# To use your own model, point "path" at it. A spec says, in the skeleton space of the skinned mesh (not the raw vertex
# data, which the skin rotates): which way the barrel points (forward) and which way is up (both unit vectors that must
# be at right angles), where the hand holds it (grip), and the tip of the barrel (muzzle). Parts are painted by
# material name through "colors", and "metals" lists the ones that look metallic.
const WEAPON := "placeholder"
const WEAPONS := {
	"placeholder": {
		"path": "res://actors/placeholder_gun.tscn", "scale": 1.0,
		"forward": Vector3(0, 0, 1), "up": Vector3(0, 1, 0),
		"grip": Vector3(0.0, 0.0, -0.1), "muzzle": Vector3(0.0, 0.0, 0.15),
		"metals": ["Metal"],
		"colors": {"Metal": Color(0.3, 0.31, 0.34)},
	},
}
const MAX_HEALTH := 3
const MAG_SIZE := 6
const START_RESERVE := 24
const RELOAD_TIME := 1.5

signal health_changed(health: int)
signal died
signal ammo_changed(mag: int, reserve: int)
signal reloading_changed(active: bool)

@onready var model: Node3D = $Hunter
@onready var anim: AnimationPlayer = $Hunter/AnimationPlayer
@onready var skeleton: Skeleton3D = $Hunter/CharacterArmature/Skeleton3D
@onready var _wrist := skeleton.find_bone("Wrist.R")

# Set by the touch overlay on a touch screen. Aim is a screen-space direction from the right stick.
# Held still (the title screen is up).
var locked := false
var touch_mode := false
var touch_aim := Vector2.ZERO
var health := MAX_HEALTH
var mag := MAG_SIZE
var reserve := START_RESERVE
var _reloading := false
var _step_timer := 0.0
var _interactables: Array[Area3D] = []
var _cooldown := 0.0
var weapon: Node3D
var weapon_mesh: MeshInstance3D
var _spec: Dictionary


func _ready() -> void:
	for clip in ["Idle_Gun_Pointing", "Run", "Run_Back", "Run_Left", "Run_Right"]:
		anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	anim.play("Idle_Gun_Pointing")
	add_to_group("player")
	_equip(WEAPON)


func _physics_process(delta: float) -> void:
	if locked:
		velocity = Vector3(0.0, 0.0 if is_on_floor() else velocity.y - GRAVITY * delta, 0.0)
		move_and_slide()
		anim_for(Vector3.ZERO)
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, deg_to_rad(CAMERA_YAW))
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	# A footstep every third of a second while running.
	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 1.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			Sfx.play("footstep", Vector3.INF, -9.0)
			_step_timer = 0.34
	else:
		_step_timer = 0.0

	# Face the mouse. Without an aim point, face the way we are walking.
	var aim := _aim_direction()
	if aim == Vector3.ZERO:
		aim = dir
	if aim != Vector3.ZERO:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(aim.x, aim.z), TURN_SPEED * delta)

	anim_for(dir)

	_cooldown = maxf(_cooldown - delta, 0.0)
	if Input.is_action_just_pressed("reload"):
		_start_reload()
	if Input.is_action_just_pressed("interact"):
		var target := nearest_interactable()
		if target:
			target.used.emit(self)
	if Input.is_action_pressed("shoot") and _cooldown == 0.0 and not _reloading:
		if mag > 0:
			_shoot()
		else:
			_start_reload()


# Swap the gun that came with the hunter scene for the chosen one.
func _equip(weapon_name: String) -> void:
	_spec = WEAPONS[weapon_name]
	var mount := skeleton.get_node("RifleMount")
	for child in mount.get_children():
		child.queue_free()
	weapon = (load(_spec.path) as PackedScene).instantiate()
	mount.add_child(weapon)
	weapon.top_level = true  # placed by _process, not by the wrist bone
	weapon_mesh = weapon.find_children("*", "MeshInstance3D", true, false)[0]
	for i in weapon_mesh.mesh.get_surface_count():
		var source := weapon_mesh.mesh.surface_get_material(i)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _spec.colors.get(source.resource_name, Color(0.4, 0.4, 0.4))
		mat.metallic = 0.6 if source.resource_name in _spec.metals else 0.0
		mat.roughness = 0.45 if mat.metallic > 0.0 else 0.8
		weapon_mesh.set_surface_override_material(i, mat)


# The weapon always points the way the hunter faces, with its grip in the right hand.
func _process(_delta: float) -> void:
	if weapon == null:
		return
	var facing := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	# Turn the mesh so its barrel axis lies along the facing direction and its up axis points up.
	var forward: Vector3 = _spec.forward
	var up: Vector3 = _spec.up
	var mesh_frame := Basis(forward, up, forward.cross(up))
	var world_frame := Basis(facing, Vector3.UP, facing.cross(Vector3.UP))
	var armature: Node3D = weapon.get_child(0)
	var armature_basis := armature.transform.basis.orthonormalized()
	weapon.global_basis = (world_frame * mesh_frame.inverse() * armature_basis.inverse()).scaled(Vector3.ONE * _spec.scale)
	var hand := (skeleton.global_transform * skeleton.get_bone_global_pose(_wrist)).origin
	weapon.global_position += hand - weapon_mesh.global_transform * _spec.grip


# Picks the run clip that matches the walking direction relative to where the hunter faces.
func anim_for(dir: Vector3) -> void:
	var clip := "Idle_Gun_Pointing"
	if dir != Vector3.ZERO:
		var local := model.global_basis.inverse() * dir
		# Within 60 degrees of facing is forward, beyond 120 is backward, the rest is a side step.
		var angle := absf(rad_to_deg(atan2(local.x, local.z)))
		if angle <= 60.0:
			clip = "Run"
		elif angle >= 120.0:
			clip = "Run_Back"
		else:
			clip = "Run_Left" if local.x > 0.0 else "Run_Right"
	if anim.current_animation != clip:
		anim.play(clip, 0.15)


# Flat direction the hunter should face: the right stick on a touch screen, else the mouse cursor
# (found on a plane at chest height).
func _aim_direction() -> Vector3:
	if touch_mode:
		return Vector3(touch_aim.x, 0.0, touch_aim.y).rotated(Vector3.UP, deg_to_rad(CAMERA_YAW))
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var mouse := get_viewport().get_mouse_position()
	var hit = Plane(Vector3.UP, global_position.y + AIM_HEIGHT).intersects_ray(
		cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
	if hit == null:
		return Vector3.ZERO
	var d: Vector3 = hit - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.1 else Vector3.ZERO


# Hitscan: one ray from the muzzle along the facing direction.
func _shoot() -> void:
	_cooldown = FIRE_INTERVAL
	mag -= 1
	ammo_changed.emit(mag, reserve)
	Sfx.play("shot", Vector3.INF, -3.0)
	var facing := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	var muzzle: Vector3 = _spec.muzzle
	var from: Vector3 = weapon_mesh.global_transform * muzzle
	var to := from + facing * RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.position if hit else to
	_spawn_tracer(from, end)
	_spawn_flash(from)
	if hit:
		Sfx.play("impact", hit.position, -4.0)
		if hit.collider.has_method("take_damage"):
			hit.collider.take_damage(1)


# Refill the magazine from the reserve. Shooting is locked while it runs.
func _start_reload() -> void:
	if _reloading or mag == MAG_SIZE or reserve == 0 or health <= 0:
		return
	_reloading = true
	reloading_changed.emit(true)
	Sfx.play("reload", Vector3.INF, -5.0)
	await get_tree().create_timer(RELOAD_TIME).timeout
	var taken := mini(MAG_SIZE - mag, reserve)
	mag += taken
	reserve -= taken
	_reloading = false
	reloading_changed.emit(false)
	ammo_changed.emit(mag, reserve)


# Things the hunter can use (see interactable.gd) register here while he stands in their area.
func add_interactable(area: Area3D) -> void:
	if not _interactables.has(area):
		_interactables.append(area)


func remove_interactable(area: Area3D) -> void:
	_interactables.erase(area)


func nearest_interactable() -> Area3D:
	var best: Area3D = null
	var best_distance := INF
	for area in _interactables:
		var d := global_position.distance_to(area.global_position)
		if d < best_distance:
			best_distance = d
			best = area
	return best


func heal(amount: int) -> void:
	health = mini(health + amount, MAX_HEALTH)
	health_changed.emit(health)


func add_ammo(amount: int) -> void:
	reserve += amount
	ammo_changed.emit(mag, reserve)


# Called by enemies. At zero health the hunter stops responding.
func take_hit() -> void:
	if health <= 0:
		return
	health -= 1
	health_changed.emit(health)
	Sfx.play("hurt")
	print("Hunter hit, health ", health)
	if health == 0:
		died.emit()
		set_physics_process(false)
		anim.play("Death")


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var tracer := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.03, from.distance_to(to))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	box.material = mat
	tracer.mesh = box
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(tracer)
	tracer.global_position = (from + to) * 0.5
	tracer.look_at(to)
	get_tree().create_timer(0.05).timeout.connect(tracer.queue_free)


func _spawn_flash(at: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.3)
	flash.light_energy = 4.0
	flash.omni_range = 4.0
	get_parent().add_child(flash)
	flash.global_position = at
	get_tree().create_timer(0.05).timeout.connect(flash.queue_free)
