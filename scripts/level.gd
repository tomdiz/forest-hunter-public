extends Node3D
## Sets up the look and the sound of the level when it starts.
##
## Look: the Kenney models are imported with metallic = 1 (the glTF default), which renders black without
## reflections. Make them matte so they take the sun and ambient light like the rest of the scene. Their colours are
## Kenney's teal palette, so swap the greens and browns for a pine forest.

const COLORS := {
	"leafsDark": Color(0.14, 0.36, 0.21),
	"grass": Color(0.28, 0.52, 0.2),
	"woodBarkDark": Color(0.34, 0.2, 0.12),
	"woodBark": Color(0.4, 0.25, 0.15),
	"woodInner": Color(0.72, 0.58, 0.42),
}


func _ready() -> void:
	_make_matte()
	_start_sounds()
	Music.start()


# Matte, pine-green trees. The water is one shared material, and rougher water keeps the campfire light from
# showing as a white blob.
func _make_matte() -> void:
	for segment in $World/River.get_children():
		((segment as MeshInstance3D).mesh as BoxMesh).material.roughness = 0.5
	var fixed := {}  # original material -> matte copy, so each material is copied once
	for node in $World.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if material == null or material.metallic < 0.5:
				continue
			if not fixed.has(material):
				var matte: StandardMaterial3D = material.duplicate()
				matte.metallic = 0.0
				if COLORS.has(material.resource_name):
					matte.albedo_color = COLORS[material.resource_name]
				fixed[material] = matte
			mesh_instance.set_surface_override_material(surface, fixed[material])


# Forest ambience everywhere, the campfire crackling where it is, and ears on the hunter (not the far-off camera).
func _start_sounds() -> void:
	var ambience := AudioStreamPlayer.new()
	ambience.bus = &"SFX"
	ambience.stream = Sfx.looped("ambience")
	ambience.volume_db = -12.0
	add_child(ambience)
	ambience.play()
	var fire := AudioStreamPlayer3D.new()
	fire.bus = &"SFX"
	fire.stream = Sfx.looped("fire_loop")
	fire.volume_db = -3.0
	fire.unit_size = 4.0
	fire.max_distance = 30.0
	$World/Cabin/Campfire.add_child(fire)
	fire.play()
	var ears := AudioListener3D.new()
	$Player.add_child(ears)
	ears.position = Vector3(0.0, 1.5, 0.0)
	ears.make_current()
