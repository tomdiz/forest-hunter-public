extends Node3D

@export var target_path: NodePath
@export var follow_speed := 8.0
## Shifts the view away from the target. The title screen uses it to put the hunter off to one side.
var offset := Vector3.ZERO
@onready var target: Node3D = get_node_or_null(target_path)


func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position + offset, 1.0 - exp(-follow_speed * delta))