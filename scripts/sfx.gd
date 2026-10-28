extends Node
## Plays the game's sound effects. One-shots use small pools of players. Positional sounds fade with distance
## from the hunter (level.gd puts the audio listener on him), and sounds with no position play flat.

const SOUNDS := {
	"shot": ["shot"],
	"reload": ["reload"],
	"footstep": ["footstep1", "footstep2", "footstep3"],
	"hurt": ["hurt"],
	"pickup": ["pickup"],
	"impact": ["impact"],
	"stag_bellow": ["stag_bellow"],
	"stag_hit": ["stag_hit"],
	"stag_die": ["stag_die"],
	"stag_snort": ["stag_snort"],
	"critter_hit": ["critter_hit"],
	"win": ["win"],
	"lose": ["lose"],
	"door_open": ["door_open"],
	"door_close": ["door_close"],
	"rest": ["rest"],
}
const POOL_2D := 6
const POOL_3D := 12

var _streams := {}
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _next_2d := 0
var _next_3d := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the win and lose stings play while the game is paused
	for key in SOUNDS:
		var list: Array[AudioStream] = []
		for file in SOUNDS[key]:
			list.append(load("res://audio/%s.wav" % file))
		_streams[key] = list
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool_2d.append(p)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 8.0
		p.max_distance = 60.0
		add_child(p)
		_pool_3d.append(p)


## Play a sound. Give a position for a sound in the world, or leave it out for one that belongs to the hunter or UI.
func play(sound: String, at := Vector3.INF, volume_db := 0.0) -> void:
	var list: Array = _streams.get(sound, [])
	if list.is_empty():
		return
	var stream: AudioStream = list.pick_random()
	var pitch := randf_range(0.95, 1.05)
	if at.is_finite():
		var p := _pool_3d[_next_3d]
		_next_3d = (_next_3d + 1) % POOL_3D
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.global_position = at
		p.play()
	else:
		var p := _pool_2d[_next_2d]
		_next_2d = (_next_2d + 1) % POOL_2D
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.play()


## A copy of a sound that repeats forever, for the caller to put in its own player.
func looped(sound: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = (load("res://audio/%s.wav" % sound) as AudioStreamWAV).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream
