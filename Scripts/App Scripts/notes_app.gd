extends Panel

var master: Master
var sound_manager: SoundManager
var json_manager: JSONManager = null
var game_manager: Node = null  

@export var phone: Control

@export_group("App Navigation")
@export var notes_app: Panel
@export var notes_button: Button
@export var todo_button: Button
@export var bottom_bar: Panel

@export_subgroup("Notes")
@export var notes_section: MarginContainer
@export var notes_preview: MarginContainer
@export var notes_scroll_container: VBoxContainer
@export var notes_content_container: MarginContainer
@export var new_note_container: MarginContainer

@export_subgroup("To-do")
@export var to_do_preview: MarginContainer

# ---------- PREFAB ----------
var note_prefab = preload("res://Prefabs/Components/note.tscn")

# ---------- DATA ----------
var notes_data: Array = []
var viewed_note_ids: Array = []  # Track which notes have been viewed for integrity

# ---------- METHODS ----------
func _open_notes_app() -> void:
	set_ui(true, "app")
	
	set_ui(true, "notes_main")
	set_ui(false, "todo_main")
	set_ui(false, "notes_opened")
	set_ui(false, "new_note")
	
	notes_button.button_pressed = true
	todo_button.button_pressed = false

func spawn_notes() -> void:
	"""Load and display notes from JSON"""
	# Get notes_scroll_container from notes_preview if not directly assigned
	if not notes_scroll_container:
		if notes_preview:
			notes_scroll_container = notes_preview.get_node_or_null("NotesContainer/Scrollable/Container/NotesContainer")
		# If still not found, try finding the Notes Preview node
		if not notes_scroll_container:
			var notes_preview_node = get_node_or_null("Notes Preview")
			if notes_preview_node:
				notes_scroll_container = notes_preview_node.get_node_or_null("NotesContainer/Scrollable/Container/NotesContainer")
	
	# Clear existing notes
	if not notes_scroll_container:
		push_warning("[Notes_app] notes_scroll_container is null! Cannot spawn notes.")
		return
	
	for child in notes_scroll_container.get_children():
		child.queue_free()
	
	# Load notes from JSON
	_load_notes()
	
	# Display notes in grid (2 per row)
	var hbox: HBoxContainer = null
	
	for i in range(notes_data.size()):
		if i % 2 == 0:
			hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 10)
			notes_scroll_container.add_child(hbox)
		
		var note_instance = note_prefab.instantiate()
		note_instance.name = "Note_%d" % i
		hbox.add_child(note_instance)
		
		# Setup note with data - setup_note will find labels if not already set
		if note_instance.has_method("setup_note"):
			note_instance.setup_note(notes_data[i])
		
		note_instance.connect("open_note", _on_notes_opened)
	
	print("[Notes_app] Spawned %d notes" % notes_data.size())

func _load_notes() -> void:
	"""Load notes from JSONManager"""
	if not json_manager:
		json_manager = JSONManager.get_instance()
	
	if json_manager:
		notes_data = json_manager.load_notes()
		print("[Notes_app] Loaded %d notes" % notes_data.size())
	else:
		push_warning("[Notes_app] JSONManager not found!")
		notes_data = []

func _on_notes_opened(note_instance: Node) -> void:
	master.sound_manager.play_sound("phone_click")
	
	# Get note data from the clicked instance
	var note_data: Dictionary = {}
	if note_instance:
		# Try to get from note_data property (from note_content.gd)
		if "note_data" in note_instance:
			note_data = note_instance.note_data
		else:
			note_data = note_instance.get_meta("note_data", {})
	
	# Apply integrity changes if note hasn't been viewed yet
	var note_id = note_data.get("id", "")
	if note_id != "":
		# Check if note has been viewed (persistent check via note data)
		var has_been_viewed = note_data.get("viewed", false)
		if not has_been_viewed:
			_apply_note_integrity(note_data)
			# Mark as viewed in the note data and save
			note_data["viewed"] = true
			# Update in notes_data array
			for i in range(notes_data.size()):
				if notes_data[i].get("id", "") == note_id:
					notes_data[i]["viewed"] = true
					break
			# Save to JSON
			if json_manager:
				json_manager.save_notes(notes_data)
	
	# Remove the note from the UI and data (just make it disappear)
	if note_instance and note_id != "":
		# Remove from notes_data array
		for i in range(notes_data.size() - 1, -1, -1):
			if notes_data[i].get("id", "") == note_id:
				notes_data.remove_at(i)
				break
		
		# Save updated notes to JSON
		if json_manager:
			json_manager.save_notes(notes_data)
		
		# Remove the note instance from UI
		var parent = note_instance.get_parent()
		if parent:
			# Remove the note instance
			note_instance.queue_free()
			
			# Check if parent HBoxContainer should be removed after a frame
			# (when queue_free has processed)
			await get_tree().process_frame
			if parent.get_child_count() == 0:
				parent.queue_free()

func _apply_note_integrity(note_data: Dictionary) -> void:
	"""Apply integrity changes based on note legitimacy"""
	if not game_manager:
		return
	
	var is_legit = note_data.get("is_legit", false)
	var integrity_change: float = 0.0
	
	if is_legit:
		# Legit info: add small amount of integrity
		integrity_change = 0.2
		print("[Notes_app] Legit note viewed: +%.2f integrity" % integrity_change)
	else:
		# Suspicious info: reduce small amount of integrity
		integrity_change = -0.2
		print("[Notes_app] Suspicious note viewed: %.2f integrity" % integrity_change)
	
	# Apply integrity change
	if game_manager.has_method("add_integrity_score"):
		game_manager.add_integrity_score(integrity_change, "correct_messages")
	else:
		push_warning("[Notes_app] GameManager doesn't have add_integrity_score method!")

func add_note(note_data: Dictionary) -> void:
	"""Add a note (called from message app when saving tips)"""
	if not json_manager:
		json_manager = JSONManager.get_instance()
	
	if json_manager:
		json_manager.add_note(note_data)
		# Refresh if app is open
		if notes_app.visible:
			spawn_notes()

func set_game_manager(manager: Node) -> void:
	"""Set reference to GameManager for integrity changes"""
	game_manager = manager

# ---------- UI MANAGER ----------
func set_ui(visibility: bool, target: String) -> void:
	match target:
		"app": notes_app.visible = visibility
		"bar": bottom_bar.visible = visibility
		"notes_main": notes_preview.visible = visibility
		"notes_opened": notes_content_container.visible = visibility
		"new_note": new_note_container.visible = visibility
		"todo_main": to_do_preview.visible = visibility

# ---------- BUTTONS: NOTES  ----------
func _on_all_notes_pressed() -> void:
	set_ui(true, "notes_main")
	set_ui(false, "todo_main")
	
	todo_button.button_pressed = false

func _on_notes_main_pressed() -> void:
	set_ui(false, "app")

func _on_note_open_pressed() -> void: 
	set_ui(false, "notes_main")
	set_ui(true, "notes_opened")
	
func _on_new_note_pressed() -> void:
	set_ui(false, "notes_main")
	set_ui(true, "new_note")
	set_ui(false, "bar")

func _on_notes_list_pressed() -> void:
	set_ui(true, "notes_main")
	set_ui(false, "new_note")
	set_ui(false, "notes_opened")
	set_ui(true, "bar")

# ---------- BUTTONS: TO-DO ----------
func _on_todo_pressed() -> void:
	set_ui(true, "todo_main")
	set_ui(false, "notes_main")
	
	notes_button.button_pressed = false

func _on_todo_main_pressed() -> void:
	set_ui(false, "todo_main")
	set_ui(true, "notes_main")
	
# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[WARN: Notes_app._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	json_manager = JSONManager.get_instance()
		
	if phone:
		phone.connect("open_notes_app", Callable(self, "_open_notes_app"))
		phone.connect("close_all_apps", Callable(self, "close_notes"))
	else:
		push_warning("[Notes_app.ready] Phone is kinda missing...")
	
	# Hide new note creation elements
	_hide_new_note_elements()
	
	spawn_notes()
	
	notes_button.button_pressed = true
	set_ui(true, "bar")
	set_ui(false, "app")
	set_ui(true, "notes_main")
	set_ui(false, "todo_main")

func _hide_new_note_elements() -> void:
	"""Hide the new note button and UI elements"""
	# Hide the "New_note" button in Notes Preview TopBar
	var new_note_button = get_node_or_null("Notes Preview/TopBar/HBoxContainer/New_note")
	if new_note_button:
		new_note_button.visible = false
		print("[Notes_app] Hid New_note button")
	else:
		# Try alternative path
		new_note_button = find_child("New_note", true, false)
		if new_note_button:
			new_note_button.visible = false
			print("[Notes_app] Hid New_note button (found via search)")
	
	# Ensure "New Note" container is hidden
	var new_note_container = get_node_or_null("New Note")
	if new_note_container:
		new_note_container.visible = false
		print("[Notes_app] Hid New Note container")
	else:
		new_note_container = find_child("New Note", true, false)
		if new_note_container:
			new_note_container.visible = false
			print("[Notes_app] Hid New Note container (found via search)")
	
	# Hide "Note Content" container (contains NewNoteContainer)
	var note_content = get_node_or_null("Note Content")
	if note_content:
		note_content.visible = false
		print("[Notes_app] Hid Note Content container")
	else:
		note_content = find_child("Note Content", true, false)
		if note_content:
			note_content.visible = false
			print("[Notes_app] Hid Note Content container (found via search)")
