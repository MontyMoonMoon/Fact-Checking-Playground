extends Node
class_name DataManager

const FILE_PATH: String = "user://save_data.json"

static var player_data: Dictionary = {}
static var settings_data: Dictionary = {}
static var notes_data: Array = []
static var todos_data: Array = []

static var player_name: String = ""
static var player_integrity: int = 100
static var current_act: int = 1
static var current_map: String = "map_01"  # Track current map/scene

static var master_vol: int = 100
static var music_vol: int = 100
static var sfx_vol: int = 100

const player_data_template: Dictionary = {
	"player_name": "",
	"integrity": 100,
	"current_act": 1,
	"current_map": "map_01"
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
	player_data["current_map"] = current_map
	
	settings_data["master_vol"] = master_vol
	settings_data["music_vol"] = music_vol
	settings_data["sfx_vol"] = sfx_vol
	
	var combined_data: Dictionary = {
		"player_data": player_data,
		"settings_data": settings_data,
		"notes_data": notes_data.duplicate(true),
		"todos_data": todos_data.duplicate(true)
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
		notes_data = []
		todos_data = []
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
			notes_data = parsed.get("notes_data", []).duplicate(true) if typeof(parsed.get("notes_data", [])) == TYPE_ARRAY else []
			todos_data = parsed.get("todos_data", []).duplicate(true) if typeof(parsed.get("todos_data", [])) == TYPE_ARRAY else []
		
			player_data = player_dict
			settings_data = settings_dict
		
			player_name = player_dict.get("player_name", "")
			player_integrity = player_dict.get("integrity", 100)
			current_act = player_dict.get("current_act", 1)
			current_map = player_dict.get("current_map", "map_01")
		
			master_vol = settings_dict.get("master_vol", 100)
			music_vol = settings_dict.get("music_vol", 100)
			sfx_vol = settings_dict.get("sfx_vol", 100)
		
			print("[DataManager.load_data] Data loaded successfully :D")
		else:
			push_error("[DataManager.load_data] Data loaded not so successfully D:.")
	else:
		push_error("[DataManager.load_data] Yeah... no")

# ---------- NOTES METHODS ----------
static func add_note_runtime(title: String, content: String) -> void:
	"""Add a runtime note (player-created)"""
	var note_id = "note_%d" % Time.get_unix_time_from_system()
	var datetime = Time.get_datetime_dict_from_system()
	var date_str = "%04d-%02d-%02d %02d:%02d" % [datetime.year, datetime.month, datetime.day, datetime.hour, datetime.minute]
	
	var note = {
		"noteid": note_id,
		"note_header": title,
		"note_content": content,
		"note_date_time": date_str
	}
	
	notes_data.append(note)
	save_data()

static func delete_note_by_id(note_id: String) -> void:
	"""Delete a note by its ID"""
	for i in range(notes_data.size() - 1, -1, -1):
		if notes_data[i].get("noteid", "") == note_id:
			notes_data.remove_at(i)
			save_data()
			return

# ---------- TODOS METHODS ----------
static func add_todo_runtime(text: String, completed: bool = false) -> String:
	"""Add a runtime todo (player-created) and return its ID"""
	var todo_id = "todo_%d" % Time.get_unix_time_from_system()
	
	var todo = {
		"todo_id": todo_id,
		"todo_text": text,
		"todo_completed": completed
	}
	
	todos_data.append(todo)
	save_data()
	return todo_id

static func update_todo(todo_id: String, text: String, completed: bool) -> void:
	"""Update a todo by its ID"""
	for todo in todos_data:
		if todo.get("todo_id", "") == todo_id:
			todo["todo_text"] = text
			todo["todo_completed"] = completed
			save_data()
			return

static func delete_todo_by_id(todo_id: String) -> void:
	"""Delete a todo by its ID"""
	for i in range(todos_data.size() - 1, -1, -1):
		if todos_data[i].get("todo_id", "") == todo_id:
			todos_data.remove_at(i)
			save_data()
			return

#CREATE NEW SAVE(error culprit1 ||fixed)
static func create_new_save(player_name_param: String) -> void:
	"""Create a new save file with the given player name"""
	player_name = player_name_param
	player_integrity = 100
	current_act = 1
	current_map = "map_01"
	notes_data = []
	todos_data = []
	
	# Initialize player_data and settings_data if needed
	if player_data.is_empty():
		player_data = player_data_template.duplicate(true)
	if settings_data.is_empty():
		settings_data = settings_data_template.duplicate(true)
	
	save_data()
	print("[DataManager.create_new_save] New save created for player: %s" % player_name)

# ---------- RESET PLAYER DATA ----------
func reset_player_data() -> void:
	player_data = player_data_template.duplicate(true)
	player_name = ""
	player_integrity = 100
	current_act = 1
	notes_data = []
	todos_data = []
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
