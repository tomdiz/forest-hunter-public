extends Area3D
## A box of ammo. The first time the hunter walks in, it adds rounds to the reserve and disappears.

@export var amount := 12
@export var box_path: NodePath


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("add_ammo"):
		return
	body.add_ammo(amount)
	Sfx.play("pickup")
	var box := get_node_or_null(box_path)
	if box:
		box.hide()
	queue_free()
