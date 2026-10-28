extends Area3D
## Something the hunter can use with E while he stands close. The prop's own script listens for `used`.

signal used(player: Node)

@export var prompt := "Use"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("add_interactable"):
		body.add_interactable(self)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("remove_interactable"):
		body.remove_interactable(self)
