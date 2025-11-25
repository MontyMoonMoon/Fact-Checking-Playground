extends Node
class_name SoundManager

static var instance: SoundManager

# ---------- EXPORTED VARIABLES ----------
@export_group("Audio Tracks")
@export var sound_effects: Dictionary[String, AudioStream]
@export var music: Dictionary[String, AudioStream]
@export var playback_volume: Dictionary[String, float] = {}

# ---------- INTERNAL VARIABLES ----------
var looping_sounds: Dictionary[String, AudioStreamPlayer] = {}

# ---------- PLAY SOUND: ONE SHOT ----------
## Usage: SoundManager.instance.play_sound("mouse_click")
func play_sound(sound_name: String) -> AudioStreamPlayer:
	if not sound_effects.has(sound_name):
		push_warning("Sound '%s' not found in sound_effects" % sound_name)
		return null
	
	var player := AudioStreamPlayer.new()
	player.stream = sound_effects[sound_name]
	player.volume_linear = _get_adjusted_volume(sound_name, false)
	add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())
	return player

# ---------- PLAY SOUND: LOOPING ----------
## Usage: SoundManager.instance.play_loop("bgm_menu")
func play_loop(sound_name: String):
	if not music.has(sound_name):
		push_warning("Sound '%s' not found in music" % sound_name)
		return
	if looping_sounds.has(sound_name):
		return
	
	var player := AudioStreamPlayer.new()
	player.stream = music[sound_name]
	player.volume_linear = _get_adjusted_volume(sound_name, true)
	player.loop = true
	add_child(player)
	player.play()
	looping_sounds[sound_name] = player

# ---------- STOP SOUND: LOOPING ----------
## Usage: SoundManager.instance.stop_loop("bgm_menu")
func stop_loop(sound_name: String):
	if looping_sounds.has(sound_name):
		looping_sounds[sound_name].stop()
		looping_sounds[sound_name].queue_free()
		looping_sounds.erase(sound_name)

# ---------- UPDATE VOLUMES ----------
## Usage: SoundManager.instance.update_all_volumes()
func update_all_volumes():
	for sound_name in looping_sounds.keys():
		var player = looping_sounds[sound_name]
		player.volume_linear = _get_adjusted_volume(sound_name, true)
	print("[SoundManager.update_all_volumes] Updated all volumes from SettingsManager")

# ---------- VOLUME CALCULATION ----------
func _get_adjusted_volume(sound_name: String, is_music: bool) -> float:
	var base_volume = playback_volume.get(sound_name, 1.0)
	
	var master = SettingsManager.master_vol / 100.0
	var music_v = SettingsManager.music_vol / 100.0
	var sfx_v = SettingsManager.sfx_vol / 100.0
	
	return base_volume * master * (music_v if is_music else sfx_v)
# ------------ GODOT CALLBACKS ----------
func _ready():
	SoundManager.instance = self
	print("[SoundManager] Instance set and sounds loaded!")

func _exit_tree() -> void:
	if SoundManager.instance == self:
		SoundManager.instance = null
