extends Node
## Background music: a calm loop while exploring and a tense one while the stag is hunting you.
## Both loops run together and the music fades between them. M mutes it.

const CALM_DB := -13.0
const TENSE_DB := -10.0
const QUIET_DB := -32.0   # the loop that is not being heard
const SILENT_DB := -60.0
const FADE := 1.6

var muted := false
var _calm: AudioStreamPlayer
var _tense: AudioStreamPlayer
var _tension := false
var _running := false
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep going through the pause on the end screens
	_calm = _make("music_calm")
	_tense = _make("music_tense")


func _make(sound: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Music"
	var stream: AudioStreamWAV = (load("res://audio/%s.wav" % sound) as AudioStreamWAV).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	p.stream = stream
	p.volume_db = SILENT_DB
	add_child(p)
	return p


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute_music"):
		muted = not muted
		_fade(0.3)


## Start the music from the calm loop. Safe to call again after a restart.
func start() -> void:
	_tension = false
	_running = true
	if not _calm.playing:
		_calm.play()
		_tense.play()
	_fade(FADE)


## Switch to the tense loop (or back to the calm one).
func set_tension(on: bool) -> void:
	if on == _tension or not _running:
		return
	_tension = on
	_fade(FADE if on else FADE * 2.0)


## Fade everything out, for the end screens, so their sting is heard.
func stop(seconds := 1.2) -> void:
	_running = false
	_fade(seconds)
	_tween.finished.connect(func() -> void:
		if not _running:
			_calm.stop()
			_tense.stop())


func _fade(seconds: float) -> void:
	var calm_target := CALM_DB if not _tension else QUIET_DB
	var tense_target := TENSE_DB if _tension else QUIET_DB
	if muted or not _running:
		calm_target = SILENT_DB
		tense_target = SILENT_DB
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_calm, "volume_db", calm_target, seconds)
	_tween.tween_property(_tense, "volume_db", tense_target, seconds)
