extends MarginContainer

var master: Master

@export var message_app: Panel
@export var notes_scroll_container: VBoxContainer

@export_subgroup("Note Content")
@export var note_title: TextEdit
@export var note_content: TextEdit
@export var note_date_time: Label

@export_subgroup("Add New")
@export var new_note_title: TextEdit
@export var new_note_content: TextEdit
@export var new_note_date_time: Label

signal open_note_window
signal list_modified

# ---------- PREFAB ----------
var notes = preload("res://Prefabs/Components/note.tscn")

# ---------- NOTES METHODS ----------
func spawn_notes() -> void:
	for child in notes_scroll_container.get_children():
		child.queue_free()

	var all_notes: Array = []
	
	var json_notes = master.json_manager.load_notes()
	if json_notes and not json_notes.is_empty():
		all_notes.append_array(json_notes)
	
	if DataManager.notes_data and not DataManager.notes_data.is_empty():
		all_notes.append_array(DataManager.notes_data)
	
	if all_notes.is_empty():
		push_warning("No notes found in either JSONManager or DataManager.")
		return
	
	var hbox: HBoxContainer = null
	var notes_in_hbox = 0
	
	for i in range(all_notes.size()):
		var note_data: Dictionary = all_notes[i]
		
		if note_data.is_empty():
			continue
		if note_data.get("note_header", "").strip_edges() == "" and note_data.get("note_content", "").strip_edges() == "":
			continue
		
		if hbox == null or notes_in_hbox >= 2:
			hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 10)
			notes_scroll_container.add_child(hbox)
			notes_in_hbox = 0  # reset counter
		
		var note_instance = notes.instantiate()
		note_instance.name = note_data.get("noteid", "note_%d" % i)
		note_instance.note_data = note_data
		
		if note_instance.title:
			note_instance.title.text = note_data.get("note_header", "")
		if note_instance.preview:
			note_instance.preview.text = note_data.get("note_content", "")
		
		if note_instance.has_signal("open_note"):
			note_instance.connect("open_note", Callable(self, "_on_notes_opened"))
		
		hbox.add_child(note_instance)
		notes_in_hbox += 1

func _on_notes_opened(note_data: Dictionary) -> void:
	master.sound_manager.play_sound("phone_click")
	
	note_title.text = note_data.get("note_header", "")
	note_content.text = note_data.get("note_content", "")
	note_date_time.text = note_data.get("note_date_time", "")
	
	emit_signal("open_note_window")

# ---------- NOTES: ADD NEW AND DELETE ----------
func _on_add_pressed() -> void:
	master.sound_manager.play_sound("phone_click")
	
	if new_note_title.text != "" && new_note_content.text != "":
		DataManager.add_note_runtime(new_note_title.text, new_note_content.text)  
		spawn_notes() 
	
	emit_signal("list_modified")

func _on_delete_pressed() -> void:
	master.sound_manager.play_sound("phone_click")
	
	var current_note_id = ""
	for note in DataManager.notes_data:
		if note.get("note_header", "") == note_title.text and note.get("note_content", "") == note_content.text:
			current_note_id = note.get("noteid", "")
			break
	
	if current_note_id != "":
		DataManager.delete_note_by_id(current_note_id)
		spawn_notes()
	else:
		push_warning("[NotesApp] Could not find note to delete.")
	
	emit_signal("list_modified")

# ---------- GODOT CALLBACKS ----------
func _ready() -> void: 
	master = get_node("/root/Master")
	
	if master == null:
		print("[WARN: Notes_app._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	message_app.connect("call_spawn_notes", Callable(self, "spawn_notes"))

	master.json_manager.load_notes()
	
	spawn_notes()
