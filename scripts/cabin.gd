extends Node3D
## The cabin's usable props: the door, the bed, the table and the fireplace. Each one is an Interactable under
## `Interactions`. Standing next to it and pressing E (or tapping the E button) fires its `used` signal.

const REST_TIME := 1.6
const CARTRIDGES := 6
const DOOR_OPEN_POSITION := Vector3(-1.45, 1.0, 2.65)
const DOOR_OPEN_YAW := 70.0
const DOOR_CLOSED_POSITION := Vector3(0.0, 1.0, 2.0)

var door_open := true
var bed_used := false
var cartridges_taken := false
var fire_lit := true
var _busy := false

@onready var door: Node3D = $DoorAndWindows/Door
@onready var door_block: CollisionShape3D = $DoorBlock/Shape
@onready var cartridges: Node3D = $Interior/Cartridges
@onready var embers: MeshInstance3D = $Interior/Embers
@onready var hearth_light: OmniLight3D = $Interior/HearthLight


func _ready() -> void:
	$Interactions/Door.used.connect(_use_door)
	$Interactions/Bed.used.connect(_use_bed)
	$Interactions/Table.used.connect(_use_table)
	$Interactions/Fireplace.used.connect(_use_fire)
	_refresh_prompts()


func _refresh_prompts() -> void:
	$Interactions/Door.prompt = "Close the door" if door_open else "Open the door"
	$Interactions/Bed.prompt = "The bed is made" if bed_used else "Rest in the bed"
	$Interactions/Table.prompt = "The table is bare" if cartridges_taken else "Take the cartridges"
	$Interactions/Fireplace.prompt = "Put out the fire" if fire_lit else "Light the fire"


func _toast(text: String) -> void:
	get_tree().call_group("hud", "toast", text)


func _use_door(player: Node3D) -> void:
	# Do not shut the door on the hunter.
	var local := to_local(player.global_position)
	if door_open and absf(local.x) < 1.1 and absf(local.z - 2.0) < 0.7:
		_toast("Something is in the way.")
		return
	door_open = not door_open
	door_block.set_deferred("disabled", door_open)
	Sfx.play("door_open" if door_open else "door_close", door.global_position)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(door, "position", DOOR_OPEN_POSITION if door_open else DOOR_CLOSED_POSITION, 0.45)
	tween.tween_property(door, "rotation_degrees:y", DOOR_OPEN_YAW if door_open else 0.0, 0.45)
	_refresh_prompts()


# Sleep for a moment to get all your hearts back. The bed can only be used once.
func _use_bed(player: Node3D) -> void:
	if _busy:
		return
	if bed_used:
		_toast("The bed has been slept in.")
		return
	if player.health >= player.MAX_HEALTH:
		_toast("You are not hurt.")
		return
	_busy = true
	bed_used = true
	player.locked = true
	get_tree().call_group("hud", "blink", REST_TIME)
	Sfx.play("rest")
	await get_tree().create_timer(REST_TIME * 0.5).timeout
	player.heal(player.MAX_HEALTH)
	await get_tree().create_timer(REST_TIME * 0.5).timeout
	player.locked = false
	_busy = false
	_toast("You rest. Your health is restored.")
	_refresh_prompts()


func _use_table(player: Node3D) -> void:
	if cartridges_taken:
		_toast("Nothing else on the table.")
		return
	cartridges_taken = true
	cartridges.hide()
	player.add_ammo(CARTRIDGES)
	Sfx.play("pickup")
	_toast("A box of cartridges. +%d rounds" % CARTRIDGES)
	_refresh_prompts()


func _use_fire(_player: Node3D) -> void:
	fire_lit = not fire_lit
	hearth_light.visible = fire_lit
	var material := (embers.mesh as BoxMesh).material as StandardMaterial3D
	material.emission_enabled = fire_lit
	material.albedo_color = Color(1.0, 0.45, 0.1) if fire_lit else Color(0.15, 0.1, 0.08)
	Sfx.play("door_close", embers.global_position)
	_refresh_prompts()
