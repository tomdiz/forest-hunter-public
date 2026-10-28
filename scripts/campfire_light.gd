extends OmniLight3D

@export var base_energy := 2.5

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	light_energy = base_energy + sin(_t * 13.0) * 0.25 + sin(_t * 7.3) * 0.2 + randf() * 0.15
