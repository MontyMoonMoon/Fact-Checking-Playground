extends Node
class_name SoundManager

static var instance: SoundManager

@export_group("Audio Tracks")
@export var sound_effects: Dictionary[String, AudioStream]
@export var music: Dictionary[String, AudioStream]
@export var playback_volume: Dictionary[String, float] = {}

var looping_sounds: Dictionary[String, AudioStreamPlayer] = {}
var current_music: String = ""

# ---------- PERCEPTUAL VOLUME ----------
func perceptual_volume(v: float) -> float:
	# Exponential curve to make linear volume changes more audible
	return pow(clamp(v, 0.0, 1.0), 2.2)

# ---------- PLAY SOUND: ONE SHOT ----------
func play_sound(sound_name: String) -> AudioStreamPlayer:
	if not sound_effects.has(sound_name):
		push_warning("Sound '%s' not found in sound_effects" % sound_name)
		return null
	
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = sound_effects[sound_name]
	player.volume_linear = perceptual_volume(_get_adjusted_volume(sound_name, false))
	add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())
	return player

# ---------- PLAY SOUND: LOOPING ----------
func play_loop(sound_name: String):
	if not music.has(sound_name):
		push_warning("Sound '%s' not found in music dictionary. Available: %s" % [sound_name, music.keys()])
		return
	
	if looping_sounds.has(sound_name) and current_music == sound_name:
		print("[SoundManager] Music '%s' already playing, skipping" % sound_name)
		return
	
	if looping_sounds.has(sound_name):
		stop_loop(sound_name)
	
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	var stream: AudioStream = music[sound_name]
	if not stream:
		push_warning("Music stream '%s' is null!" % sound_name)
		return
	
	var final_volume: float = _get_adjusted_volume(sound_name, true)
	player.stream = stream
	player.volume_linear = perceptual_volume(final_volume)
	add_child(player)
	player.play()
	
	looping_sounds[sound_name] = player
	current_music = sound_name
	
	await get_tree().process_frame
	if not player.playing:
		push_error("[SoundManager] '%s' failed to play!" % sound_name)

# ---------- STOP LOOP ----------
func stop_loop(sound_name: String):
	if looping_sounds.has(sound_name):
		var p: AudioStreamPlayer = looping_sounds[sound_name]
		p.stop()
		p.queue_free()
		looping_sounds.erase(sound_name)
		if current_music == sound_name:
			current_music = ""

# ---------- PLAY MUSIC (stops previous) ----------
func play_music(music_name: String):
	for name in looping_sounds.keys():
		stop_loop(name)
	_load_music_tracks()
	play_loop(music_name)

# ---------- UPDATE ALL LOOPING VOLUMES ----------
func update_all_volumes():
	for sound_name in looping_sounds.keys():
		var p: AudioStreamPlayer = looping_sounds[sound_name]
		var final_volume: float = _get_adjusted_volume(sound_name, true)
		p.volume_linear = perceptual_volume(final_volume)
	print("[SoundManager] Updated looped volumes")

# ---------- VOLUME CALC ----------
func _get_adjusted_volume(sound_name: String, is_music: bool) -> float:
	var base_volume: float = playback_volume.get(sound_name, 1.0)
	
	var master: float = SettingsManager.master_vol / 100.0
	var music_v: float = SettingsManager.music_vol / 100.0
	var sfx_v: float = SettingsManager.sfx_vol / 100.0
	
	var final_volume: float = base_volume * master * (music_v if is_music else sfx_v)
	return final_volume

# ---------- LOAD MUSIC ----------
func _load_music_tracks() -> void:
	if not music.has("mainmenu"):
		var s: AudioStream = ResourceLoader.load("res://Assets/Music/mainmenu.mp3")
		if s: music["mainmenu"] = s
	
	if not music.has("stage1"):
		var s: AudioStream = ResourceLoader.load("res://Assets/Music/stage1.mp3")
		if s: music["stage1"] = s

	if not music.has("stage2"):
		var s: AudioStream = ResourceLoader.load("res://Assets/Music/stage2.mp3")
		if s: music["stage2"] = s
	
	if not music.has("stage3"):
		var s: AudioStream = ResourceLoader.load("res://Assets/Music/stage3.mp3")
		if s: music["stage3"] = s

# ---------- GODOT CALLBACKS ----------
func _ready():
	SoundManager.instance = self
	_load_music_tracks()
	print("[SoundManager] Instance set and sounds loaded!")

func _exit_tree():
	if SoundManager.instance == self:
		SoundManager.instance = null
