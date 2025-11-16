extends Node
class_name SettingsManager

static var master_vol: int = 100
static  var music_vol: int = 100
static  var sfx_vol: int = 100

static func save_settings(volumes: Dictionary = {}) -> void:
	if volumes.has("master_volume"):
		master_vol = volumes["master_volume"]
	if volumes.has("music_volume"):
		music_vol = volumes["music_volume"]
	if volumes.has("sfx_volume"):
		sfx_vol = volumes["sfx_volume"]
	
	DataManager.master_vol = master_vol
	DataManager.music_vol = music_vol
	DataManager.sfx_vol = sfx_vol
	DataManager.save_data()
	
	if SoundManager.instance:
		SoundManager.instance.update_all_volumes()
	
	print("[SettingsManager.save_settings] Settings saved successfully!")

static func load_settings() -> void:
	master_vol = DataManager.master_vol
	music_vol = DataManager.music_vol
	sfx_vol = DataManager.sfx_vol
	print("[SettingsManager.load_settings] Loaded settings from DataManager!")
