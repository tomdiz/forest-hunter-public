extends Node
## The player's audio settings. Music and effects each get their own audio bus, so one slider moves every sound
## of that kind. The values are remembered between runs.

const FILE := "user://settings.cfg"

var music_volume := 1.0  # 0 to 1
var sfx_volume := 1.0


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	var config := ConfigFile.new()
	if config.load(FILE) == OK:
		music_volume = clampf(config.get_value("audio", "music", 1.0), 0.0, 1.0)
		sfx_volume = clampf(config.get_value("audio", "sfx", 1.0), 0.0, 1.0)
	_apply()


func set_music(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	_apply()


func set_sfx(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	_apply()


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(FILE)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _apply() -> void:
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


# A slider value is a straight 0 to 1 amount. Turn it into decibels, and switch the bus off at zero.
func _set_bus(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))
