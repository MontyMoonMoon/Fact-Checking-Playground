extends Node
class_name JSONManager

static func get_instance() -> JSONManager:
	# get from Master node
	var master = Engine.get_main_loop().root.get_node_or_null("Master")
	if master:
		
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
const DATASET_PATH = "res://JSONs/dataset.json"
const MAIL_TEXTS_PATH = "res://JSONs/mail_texts.json"
const COLLECTED_INFOS_PATH = "user://collected_infos.json"
const DATASET_ADDITIONS_PATH = "user://dataset_additions.json"
const TRASHED_INFOS_PATH = "user://trashed_infos.json"
const MESSAGES_PATH = "user://messages.json"
const NOTES_PATH = "user://notes.json"
const TODOS_PATH = "res://JSONs/todos_texts.json"
# Initial/default data paths (read-only)
const MESSAGES_INITIAL_PATH = "res://JSONs/messages.json"
const NOTES_INITIAL_PATH = "res://JSONs/notes.json"

const TUTORIAL_TEXTS_PATH = "res://JSONs/tutorial_texts.json"
const NOTEBOOK_TEXT_PATH = "res://JSONs/notebook.json"

# ---------- CACHED DATA ----------
var mails: Dictionary = {}
var dataset_cache: Dictionary = {}
var collected_infos_cache: Array = []
var dataset_additions_cache: Array = []
var trashed_infos_cache: Array = []
var messages_cache: Array = []
var notes_cache: Array = []
var todos_cache: Array = []

var tutorial_steps_cache: Array = []
var notebook_contents_cache: Array = []

# ---------- GENERIC JSON OPERATIONS ----------

# Load JSON from file path (res:// or user://)
# Returns the parsed data or null if failed
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

# Save JSON to file path (user:// only, res:// is read-only)
# Returns true if successful, false otherwise

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

# Clear a JSON file by writing empty array
static func clear_json_file(file_path: String) -> bool:
	return save_json(file_path, [])

# Check if file exists
static func file_exists(file_path: String) -> bool:
	return FileAccess.file_exists(file_path)
	
# ---------- TUTORIAL JSON OPERATIONS ----------
# Load tutorial_steps.json
func load_tutorial_steps() -> Array:
	if tutorial_steps_cache.is_empty():
		var data = load_json(TUTORIAL_TEXTS_PATH, [])
		if typeof(data) == TYPE_DICTIONARY and data.has("tutorial_steps"):
			tutorial_steps_cache = data["tutorial_steps"].duplicate(true)
		elif typeof(data) == TYPE_ARRAY:
			# fallback if file is just an array
			tutorial_steps_cache = data.duplicate(true)
		else:
			tutorial_steps_cache = []
	return tutorial_steps_cache.duplicate(true)

func get_tutorial_step(step_id: String) -> Dictionary:
	var steps = load_tutorial_steps()
	for step in steps:
		if step.get("id", "") == step_id:
			return step.duplicate(true)
	return {}

# ---------- NOTEBOOK JSON OPERATIONS ----------
func load_notebook_content() -> Array:
	if notebook_contents_cache.is_empty():
		var data = load_json(NOTEBOOK_TEXT_PATH, [])
		if typeof(data) == TYPE_DICTIONARY and data.has("notebook_content"):
			notebook_contents_cache = data["notebook_content"].duplicate(true)
		elif typeof(data) == TYPE_ARRAY:
			notebook_contents_cache = data.duplicate(true)
		else:
			notebook_contents_cache = []
	return notebook_contents_cache.duplicate(true)

func get_notebook_content(page_id: String) -> Dictionary:
	var pages = load_notebook_content()
	for page in pages:
		if page.get("id", "") == page_id:
			return page.duplicate(true)
	return {}

# ---------- DATASET.JSON OPERATIONS ----------

# Load dataset.json (res://dataset.json)
# Returns dictionary with "cases" array or null
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

# Get cases array from dataset
func get_dataset_cases() -> Array:
	var dataset = load_dataset()
	if dataset.has("cases"):
		return dataset["cases"].duplicate()
	return []

# Get a specific case by article_text
func get_case_by_article_text(article_text: String) -> Dictionary:
	
	var cases = get_dataset_cases()
	for case in cases:
		if case.get("article_text", "") == article_text:
			return case.duplicate(true)
	return {}

# ---------- MAIL_TEXTS.JSON OPERATIONS ----------

# Load mail texts
func load_mails() -> void:
	var data = load_json(MAIL_TEXTS_PATH, {})
	if typeof(data) == TYPE_DICTIONARY:
		mails = data
	else:
		mails = {}

# Get mails dictionary
func get_mails() -> Dictionary:
	if mails.is_empty():
		load_mails()
	return mails

# ---------- COLLECTED_INFOS.JSON OPERATIONS ----------

# Load collected_infos.json
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

# Clear collected_infos.json
func clear_collected_infos() -> bool:
	collected_infos_cache.clear()
	var result = clear_json_file(COLLECTED_INFOS_PATH)
	# Verify file is actually empty
	var verify = load_json(COLLECTED_INFOS_PATH, [])
	if typeof(verify) == TYPE_ARRAY and verify.size() > 0:
		push_warning("[JSONManager] clear_collected_infos: File still has data after clear! Forcing empty write.")
		save_json(COLLECTED_INFOS_PATH, [])
	print("[JSONManager] clear_collected_infos: cleared cache and file")
	return result

# ---------- DATASET_ADDITIONS.JSON OPERATIONS ----------

# Load dataset_additions.json
func load_dataset_additions() -> Array:
	if dataset_additions_cache.is_empty():
		var data = load_json(DATASET_ADDITIONS_PATH, [])
		if typeof(data) == TYPE_ARRAY:
			dataset_additions_cache = data
			print("[JSONManager] load_dataset_additions: loaded %d items from file" % data.size())
		else:
			dataset_additions_cache = []
			print("[JSONManager] load_dataset_additions: file is empty or invalid")
	
	return dataset_additions_cache.duplicate(true)

# Save dataset_additions.json
func save_dataset_additions(data: Array) -> bool:
	dataset_additions_cache = data.duplicate(true)
	return save_json(DATASET_ADDITIONS_PATH, data)

# Add a case to dataset_additions (checks for duplicates)
func add_to_dataset_additions(case_data: Dictionary) -> bool:
	var additions = load_dataset_additions()
	var article_text = case_data.get("article_text", "")
	
	# Check if already exists
	for addition in additions:
		if addition.get("article_text", "") == article_text:
			return false  # Already exists
	
	additions.append(case_data.duplicate(true))
	return save_dataset_additions(additions)

# Clear dataset_additions.json
func clear_dataset_additions() -> bool:
	dataset_additions_cache.clear()
	var result = clear_json_file(DATASET_ADDITIONS_PATH)
	# Verify file is actually empty
	var verify = load_json(DATASET_ADDITIONS_PATH, [])
	if typeof(verify) == TYPE_ARRAY and verify.size() > 0:
		push_warning("[JSONManager] clear_dataset_additions: File still has data after clear! Forcing empty write.")
		save_json(DATASET_ADDITIONS_PATH, [])
	print("[JSONManager] clear_dataset_additions: cleared cache and file")
	return result

# ---------- TRASHED_INFOS.JSON OPERATIONS ----------

# Load trashed_infos.json
func load_trashed_infos(force_reload: bool = false) -> Array:
	if force_reload or trashed_infos_cache.is_empty():
		var data = load_json(TRASHED_INFOS_PATH, [])
		if typeof(data) == TYPE_ARRAY:
			trashed_infos_cache = data
		else:
			trashed_infos_cache = []
	
	return trashed_infos_cache.duplicate(true)

# Save trashed_infos.json
func save_trashed_infos(data: Array) -> bool:
	trashed_infos_cache = data.duplicate(true)
	return save_json(TRASHED_INFOS_PATH, data)

## Clear trashed_infos.json
func clear_trashed_infos() -> bool:
	trashed_infos_cache.clear()
	return clear_json_file(TRASHED_INFOS_PATH)

# ---------- COMBINED OPERATIONS ----------

# Get all cases (dataset + additions, excluding trashed)
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

# Clear all game data files (FOR RESET || NEW GAME)

func clear_all_game_data() -> void:
	clear_collected_infos()
	clear_dataset_additions()
	clear_trashed_infos()
	clear_messages()
	clear_notes()
	print("JSONManager: Cleared all game data files")

# ---------- MESSAGES.JSON OPERATIONS ----------

# Load messages.json
func load_messages() -> Array:
	if messages_cache.is_empty():
		# Check if user:// file exists, if not, initialize from res://
		if not FileAccess.file_exists(MESSAGES_PATH):
			print("JSONManager: user://messages.json doesn't exist, initializing from res://...")
			_initialize_messages_from_res()
		
		var data = load_json(MESSAGES_PATH, [])
		if typeof(data) == TYPE_ARRAY:
			messages_cache = data
			print("JSONManager: Loaded %d messages from user://messages.json" % messages_cache.size())
		else:
			messages_cache = []
			push_warning("JSONManager: Failed to load messages.json or invalid format")
	
	return messages_cache.duplicate(true)

func _initialize_messages_from_res() -> void:
	"""Initialize messages.json from res:// if user:// doesn't exist"""
	print("JSONManager: Attempting to initialize messages from res://...")
	var initial_data = load_json(MESSAGES_INITIAL_PATH, [])
	print("JSONManager: Loaded from res://: %d messages" % (initial_data.size() if typeof(initial_data) == TYPE_ARRAY else 0))
	if typeof(initial_data) == TYPE_ARRAY and initial_data.size() > 0:
		if save_json(MESSAGES_PATH, initial_data):
			print("JSONManager: Successfully initialized messages.json from res:// (%d messages)" % initial_data.size())
		else:
			push_error("JSONManager: Failed to save messages.json to user://")
	else:
		push_warning("JSONManager: No initial messages found in res:// or invalid format")

# Get all messages
func get_all_messages() -> Array:
	return load_messages()

# Add a message
func add_message(message_data: Dictionary) -> bool:
	var messages = load_messages()
	messages.append(message_data.duplicate(true))
	messages_cache = messages
	return save_json(MESSAGES_PATH, messages)

# Remove a message by matching data
func remove_message(message_data: Dictionary) -> bool:
	var messages = load_messages()
	var filtered = []
	var removed = false
	
	for msg in messages:
		# Match by content and sender (unique enough identifier)
		var msg_content = msg.get("content", "")
		var msg_sender = msg.get("sender", "")
		var data_content = message_data.get("content", "")
		var data_sender = message_data.get("sender", "")
		
		if msg_content == data_content and msg_sender == data_sender:
			removed = true
			continue  
		
		filtered.append(msg)
	
	if removed:
		messages_cache = filtered
		return save_json(MESSAGES_PATH, filtered)
	
	return false

# Clear messages.json
func clear_messages() -> bool:
	messages_cache.clear()
	var result = clear_json_file(MESSAGES_PATH)
	# Force refresh cache
	messages_cache = []
	return result

# ---------- NOTES.JSON OPERATIONS ----------

# Load notes.json
func load_notes() -> Array:
	if notes_cache.is_empty():
		# Check if user:// file exists, if not, initialize from res://
		if not FileAccess.file_exists(NOTES_PATH):
			_initialize_notes_from_res()
		
		var data = load_json(NOTES_PATH, [])
		if typeof(data) == TYPE_ARRAY:
			notes_cache = data
		else:
			notes_cache = []
	
	return notes_cache.duplicate(true)

func _initialize_notes_from_res() -> void:
	"""Initialize notes.json from res:// if user:// doesn't exist"""
	print("JSONManager: Attempting to initialize notes from res://...")
	var initial_data = load_json(NOTES_INITIAL_PATH, [])
	print("JSONManager: Loaded from res://: %d notes" % (initial_data.size() if typeof(initial_data) == TYPE_ARRAY else 0))
	if typeof(initial_data) == TYPE_ARRAY and initial_data.size() > 0:
		if save_json(NOTES_PATH, initial_data):
			print("JSONManager: Successfully initialized notes.json from res:// (%d notes)" % initial_data.size())
		else:
			push_error("JSONManager: Failed to save notes.json to user://")
	else:
		push_warning("JSONManager: No initial notes found in res:// or invalid format")

# Save notes.json
func save_notes(notes_data: Array) -> bool:
	notes_cache = notes_data.duplicate(true)
	return save_json(NOTES_PATH, notes_data)

# Add a note
func add_note(note_data: Dictionary) -> bool:
	var notes = load_notes()
	notes.append(note_data.duplicate(true))
	notes_cache = notes
	return save_json(NOTES_PATH, notes)

# Remove a note by ID
func remove_note(note_id: String) -> bool:
	var notes = load_notes()
	var filtered = []
	for note in notes:
		if note.get("id", "") != note_id:
			filtered.append(note)
	notes_cache = filtered
	return save_json(NOTES_PATH, filtered)

# Clear notes.json
func clear_notes() -> bool:
	notes_cache.clear()
	return clear_json_file(NOTES_PATH)

# ---------- TODOS.JSON OPERATIONS ----------

# Load todos from res://todos_texts.json (read-only game todos)
func load_todos() -> Array:
	if todos_cache.is_empty():
		var data = load_json(TODOS_PATH, {})
		if typeof(data) == TYPE_DICTIONARY and data.has("todos"):
			todos_cache = data["todos"].duplicate(true)
		elif typeof(data) == TYPE_ARRAY:
			todos_cache = data.duplicate(true)
		else:
			todos_cache = []
	
	return todos_cache.duplicate(true)

# Property accessor for todos (for compatibility with old code)
var todos: Array:
	get:
		return load_todos()

# Refresh all caches (useful after external changes)
func refresh_caches() -> void:
	dataset_cache.clear()
	collected_infos_cache.clear()
	dataset_additions_cache.clear()
	trashed_infos_cache.clear()
	messages_cache.clear()
	notes_cache.clear()
	todos_cache.clear()
	mails.clear()

# ---------- GODOT CALLBACKS ----------
func _ready():
	load_mails()
	if not FileAccess.file_exists(MESSAGES_PATH):
		print("JSONManager: messages.json doesn't exist, initializing...")
		_initialize_messages_from_res()
	else:
		var existing = load_json(MESSAGES_PATH, [])
		if typeof(existing) == TYPE_ARRAY:
			if existing.size() == 0:
				print("JSONManager: messages.json exists but is empty (likely new game) - NOT auto-initializing")
			else:
				print("JSONManager: messages.json already exists with %d messages" % existing.size())
	
	if not FileAccess.file_exists(NOTES_PATH):
		print("JSONManager: notes.json doesn't exist, initializing...")
		_initialize_notes_from_res()
	else:
		var existing = load_json(NOTES_PATH, [])
		if typeof(existing) == TYPE_ARRAY:
			if existing.size() == 0:
				print("JSONManager: notes.json exists but is empty (likely new game) - NOT auto-initializing")
			else:
				print("JSONManager: notes.json already exists with %d notes" % existing.size())
