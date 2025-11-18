extends Node
class_name JSONManager

# Singleton for managing all JSON file operations
# This centralizes all JSON loading/saving to reduce code duplication

## Get JSONManager instance from scene tree
static func get_instance() -> JSONManager:
	# Try to get from Master node
	var master = Engine.get_main_loop().root.get_node_or_null("Master")
	if master:
		# Try accessing via property (Master has @export var json_manager)
		var json_mgr = master.get("json_manager")
		if json_mgr:
			return json_mgr as JSONManager
		# Try direct path
		var json_manager = master.get_node_or_null("JSON Manager")
		if json_manager:
			return json_manager as JSONManager
	# Try direct root path
	return Engine.get_main_loop().root.get_node_or_null("Master/JSON Manager") as JSONManager

# ---------- FILE PATHS ----------
const DATASET_PATH = "res://dataset.json"
const MAIL_TEXTS_PATH = "res://JSONs/mail_texts.json"
const COLLECTED_INFOS_PATH = "user://collected_infos.json"
const DATASET_ADDITIONS_PATH = "user://dataset_additions.json"
const TRASHED_INFOS_PATH = "user://trashed_infos.json"

# ---------- CACHED DATA ----------
var mails: Dictionary = {}
var dataset_cache: Dictionary = {}
var collected_infos_cache: Array = []
var dataset_additions_cache: Array = []
var trashed_infos_cache: Array = []

# ---------- GENERIC JSON OPERATIONS ----------

## Load JSON from file path (res:// or user://)
## Returns the parsed data or null if failed
static func load_json(file_path: String, default_value = null):
	if not FileAccess.file_exists(file_path):
		if default_value != null:
			return default_value
		push_warning("JSONManager: File not found: %s" % file_path)
		return null
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("JSONManager: Could not open file for reading: %s" % file_path)
		return default_value
	
	var file_text = file.get_as_text()
	file.close()
	
	if file_text.strip_edges().is_empty():
		if default_value != null:
			return default_value
		return null
	
	var parsed = JSON.parse_string(file_text)
	if parsed == null:
		push_error("JSONManager: Failed to parse JSON from: %s" % file_path)
		return default_value
	
	return parsed

## Save JSON to file path (user:// only, res:// is read-only)
## Returns true if successful, false otherwise
static func save_json(file_path: String, data, indent: String = "\t") -> bool:
	# Only allow saving to user:// paths for safety
	if not file_path.begins_with("user://"):
		push_error("JSONManager: Cannot save to non-user:// path: %s" % file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("JSONManager: Could not open file for writing: %s" % file_path)
		return false
	
	var json_string = JSON.stringify(data, indent)
	file.store_string(json_string)
	file.close()
	
	return true

## Clear a JSON file by writing empty array
static func clear_json_file(file_path: String) -> bool:
	return save_json(file_path, [])

## Check if file exists
static func file_exists(file_path: String) -> bool:
	return FileAccess.file_exists(file_path)

# ---------- DATASET.JSON OPERATIONS ----------

## Load dataset.json (res://dataset.json)
## Returns dictionary with "cases" array or null
func load_dataset() -> Dictionary:
	if dataset_cache.is_empty():
		var data = load_json(DATASET_PATH, {})
		if typeof(data) == TYPE_DICTIONARY:
			dataset_cache = data
		elif typeof(data) == TYPE_ARRAY:
			# Handle array format
			dataset_cache = {"cases": data}
		else:
			dataset_cache = {"cases": []}
	
	return dataset_cache

## Get cases array from dataset
func get_dataset_cases() -> Array:
	var dataset = load_dataset()
	if dataset.has("cases"):
		return dataset["cases"].duplicate()
	return []

## Get a specific case by article_text
func get_case_by_article_text(article_text: String) -> Dictionary:
	var cases = get_dataset_cases()
	for case in cases:
		if case.get("article_text", "") == article_text:
			return case.duplicate(true)
	return {}

# ---------- MAIL_TEXTS.JSON OPERATIONS ----------

## Load mail texts
func load_mails() -> void:
	var data = load_json(MAIL_TEXTS_PATH, {})
	if typeof(data) == TYPE_DICTIONARY:
		mails = data
	else:
		mails = {}

## Get mails dictionary
func get_mails() -> Dictionary:
	if mails.is_empty():
		load_mails()
	return mails

# ---------- COLLECTED_INFOS.JSON OPERATIONS ----------

## Load collected_infos.json
func load_collected_infos() -> Array:
	if collected_infos_cache.is_empty():
		var data = load_json(COLLECTED_INFOS_PATH, [])
		if typeof(data) == TYPE_ARRAY:
			collected_infos_cache = data
		else:
			collected_infos_cache = []
	
	return collected_infos_cache.duplicate(true)

## Save collected_infos.json
func save_collected_infos(data: Array) -> bool:
	collected_infos_cache = data.duplicate(true)
	return save_json(COLLECTED_INFOS_PATH, data)

## Clear collected_infos.json
func clear_collected_infos() -> bool:
	collected_infos_cache.clear()
	return clear_json_file(COLLECTED_INFOS_PATH)

# ---------- DATASET_ADDITIONS.JSON OPERATIONS ----------

## Load dataset_additions.json
func load_dataset_additions() -> Array:
	if dataset_additions_cache.is_empty():
		var data = load_json(DATASET_ADDITIONS_PATH, [])
		if typeof(data) == TYPE_ARRAY:
			dataset_additions_cache = data
		else:
			dataset_additions_cache = []
	
	return dataset_additions_cache.duplicate(true)

## Save dataset_additions.json
func save_dataset_additions(data: Array) -> bool:
	dataset_additions_cache = data.duplicate(true)
	return save_json(DATASET_ADDITIONS_PATH, data)

## Add a case to dataset_additions (checks for duplicates)
func add_to_dataset_additions(case_data: Dictionary) -> bool:
	var additions = load_dataset_additions()
	var article_text = case_data.get("article_text", "")
	
	# Check if already exists
	for addition in additions:
		if addition.get("article_text", "") == article_text:
			return false  # Already exists
	
	additions.append(case_data.duplicate(true))
	return save_dataset_additions(additions)

## Clear dataset_additions.json
func clear_dataset_additions() -> bool:
	dataset_additions_cache.clear()
	return clear_json_file(DATASET_ADDITIONS_PATH)

# ---------- TRASHED_INFOS.JSON OPERATIONS ----------

## Load trashed_infos.json
func load_trashed_infos(force_reload: bool = false) -> Array:
	if force_reload or trashed_infos_cache.is_empty():
		var data = load_json(TRASHED_INFOS_PATH, [])
		if typeof(data) == TYPE_ARRAY:
			trashed_infos_cache = data
		else:
			trashed_infos_cache = []
	
	return trashed_infos_cache.duplicate(true)

## Save trashed_infos.json
func save_trashed_infos(data: Array) -> bool:
	trashed_infos_cache = data.duplicate(true)
	return save_json(TRASHED_INFOS_PATH, data)

## Clear trashed_infos.json
func clear_trashed_infos() -> bool:
	trashed_infos_cache.clear()
	return clear_json_file(TRASHED_INFOS_PATH)

# ---------- COMBINED OPERATIONS ----------

## Get all cases (dataset + additions, excluding trashed)
func get_all_cases(exclude_trashed: bool = true) -> Array:
	var all_cases = []
	
	# Load from dataset
	var dataset_cases = get_dataset_cases()
	all_cases.append_array(dataset_cases)
	
	# Load additions
	var additions = load_dataset_additions()
	
	# Merge additions, avoiding duplicates
	var existing_texts = {}
	for case in all_cases:
		var article_text = case.get("article_text", "")
		if article_text != "":
			existing_texts[article_text] = true
	
	for addition in additions:
		var article_text = addition.get("article_text", "")
		if article_text != "" and not existing_texts.has(article_text):
			all_cases.append(addition)
			existing_texts[article_text] = true
	
	# Filter out trashed items if requested
	if exclude_trashed:
		var trashed = load_trashed_infos()
		var trashed_texts = {}
		for trashed_item in trashed:
			var case_data = trashed_item.get("case_data", {})
			if not case_data.is_empty():
				var article_text = case_data.get("article_text", "")
				if article_text != "":
					trashed_texts[article_text] = true
		
		var filtered_cases = []
		for case in all_cases:
			var article_text = case.get("article_text", "")
			if article_text != "" and not trashed_texts.has(article_text):
				filtered_cases.append(case)
		
		return filtered_cases
	
	return all_cases

## Clear all game data files (for new game)
func clear_all_game_data() -> void:
	clear_collected_infos()
	clear_dataset_additions()
	clear_trashed_infos()
	print("JSONManager: Cleared all game data files")

## Refresh all caches (useful after external changes)
func refresh_caches() -> void:
	dataset_cache.clear()
	collected_infos_cache.clear()
	dataset_additions_cache.clear()
	trashed_infos_cache.clear()
	mails.clear()

# ---------- GODOT CALLBACKS ----------
func _ready():
	load_mails()
