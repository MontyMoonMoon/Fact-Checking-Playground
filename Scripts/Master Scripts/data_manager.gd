extends Node
class_name DataManager

const FILE_PATH: String = "user://save_data.json"

static var player_data: Dictionary = {}
static var settings_data: Dictionary = {}

static var player_name: String = ""
static var player_integrity: int = 100
static var current_act: int = 1

static var master_vol: int = 100
static var music_vol: int = 100
static var sfx_vol: int = 100

const player_data_template: Dictionary = {
	"player_name": "",
	"integrity": 100,
	"current_act": 1
}

const settings_data_template: Dictionary = {
	"master_vol": 100,
	"music_vol": 100,
	"sfx_vol": 100
}

static func save_data() -> void:
	player_data = player_data.duplicate(true)
	settings_data = settings_data.duplicate(true)

	player_data["player_name"] = player_name
	player_data["integrity"] = player_integrity
	player_data["current_act"] = current_act
	
	settings_data["master_vol"] = master_vol
	settings_data["music_vol"] = music_vol
	settings_data["sfx_vol"] = sfx_vol
	
	var combined_data: Dictionary = {
		"player_data": player_data,
		"settings_data": settings_data
	}
	
	var file = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(combined_data, "\t"))
		file.close()
		print("[DataManager.save_data] All data saved successfully!")
	else:
		push_error("[DataManager.save_data] Failed to save data.")

static func load_data() -> void:
	if not FileAccess.file_exists(FILE_PATH):
		print("[DataManager.load_data] Creating default save data...")
		player_data = player_data_template.duplicate(true)
		settings_data = settings_data_template.duplicate(true)
		save_data()
		return
	
	var file = FileAccess.open(FILE_PATH, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
	
		var parsed = JSON.parse_string(json_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			var player_dict = parsed.get("player_data", player_data_template).duplicate(true)
			var settings_dict = parsed.get("settings_data", settings_data_template).duplicate(true)
		
			player_data = player_dict
			settings_data = settings_dict
		
			player_name = player_dict.get("player_name", "")
			player_integrity = player_dict.get("integrity", 100)
			current_act = player_dict.get("current_act", 1)
		
			master_vol = settings_dict.get("master_vol", 100)
			music_vol = settings_dict.get("music_vol", 100)
			sfx_vol = settings_dict.get("sfx_vol", 100)
		
			print("[DataManager.load_data] Data loaded successfully :D")
		else:
			push_error("[DataManager.load_data] Data loaded not so successfully D:.")
	else:
		push_error("[DataManager.load_data] Yeah... no")

# ---------- RESET PLAYER DATA ----------
func reset_player_data() -> void:
	player_data = player_data_template.duplicate(true)
	player_name = ""
	player_integrity = 100
	current_act = 1
	save_data()

# ---------- RESET SETTINGS ----------
func reset_settings_data() -> void:
	settings_data = settings_data_template.duplicate(true)
	master_vol = 100
	music_vol = 100
	sfx_vol = 100
	save_data()

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	load_data()
