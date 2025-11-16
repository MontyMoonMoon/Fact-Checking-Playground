extends Panel

var master: Master
var sound_manager: SoundManager

@export var phone: Control

@export_group("App")
@export var notes_app: Panel
@export var bottom_bar: Panel

@export_subgroup("Notes")
@export var notes_preview: MarginContainer
@export var notes_content: MarginContainer
@export var notes_scroll_container: VBoxContainer

@export_subgroup("To-do")
@export var to_do_preview: MarginContainer
@export var to_do_scroll_container: VBoxContainer

# ---------- PREFAB ----------
var message_chats = preload("res://Prefabs/Components/note.tscn")

# ---------- METHODS ----------
func _on_open_notes_app() -> void:
	#master.sound_manager.play_sound("phone_click")
	set_ui(true, 0)
	set_ui(true, 1)
	set_ui(true, 2)

func spawn_notes() -> void:
	var hbox: HBoxContainer = null
	var total_notes := 12
	
	for i in range(total_notes):
		if i % 2 == 0:
			hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 10) 
			notes_scroll_container.add_child(hbox)  
		
		var note_instance = message_chats.instantiate()
		note_instance.name = "Note_%d" % i
		hbox.add_child(note_instance)
		
		note_instance.connect("open_note", Callable(self, "_on_notes_opened"))

func spawn_to_do() -> void:
	pass

func _on_notes_opened() -> void:
	master.sound_manager.play_sound("phone_click")
	set_ui(false, 0)
	set_ui(false, 2)
	#set_ui(true, 3)

# -------- UI HANDLER ----------
func set_ui(visibility: bool, target: int) -> void:
	match target:
		0: bottom_bar.visible = visibility
		# Notes section
		1: notes_app.visible = visibility
		2: notes_preview.visible = visibility
		3: notes_content.visible = visibility
		# To-do section

# ---------- BUTTONS: NOTES  ----------
func _on_notes_main_pressed() -> void:
	#master.sound_manager.play_sound("phone_click")
	set_ui(false, 1)
	set_ui(false, 2)
	set_ui(false, 3)

func _on_new_note_pressed() -> void:
	master.sound_manager.play_sound("phone_click")
	set_ui(false, 0)
	set_ui(false, 2)
	set_ui(true, 3)

func _on_chats_closed_pressed() -> void:
	master.sound_manager.play_sound("phone_click")
	set_ui(true, 0)
	set_ui(false, 3)
	set_ui(true, 2)

# ---------- BUTTONS: TO-DO ----------

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[WARN: Notes_app._ready] Master is still null. Calling members from this object may cause issues.")
		return
		
	if phone:
		phone.connect("open_notes_app", Callable(self, "_on_open_notes_app"))
		phone.connect("close_all_apps", Callable(self, "_on_notes_main_pressed"))
	else:
		push_warning("[Notes_app.ready] Phone is kinda missing...")
	
	spawn_notes()
