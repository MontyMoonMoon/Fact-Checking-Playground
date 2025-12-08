extends Panel

var master: Master
var sound_manager: SoundManager

@export var phone: Control

@export_group("App Navigation")
@export var notes_app: Panel
@export var notes_button: Button
@export var todo_button: Button
@export var bottom_bar: Panel

@export_subgroup("Notes")
@export var notes_section: MarginContainer
@export var notes_preview: MarginContainer
@export var notes_content_container: MarginContainer
@export var new_note_container: MarginContainer

@export_subgroup("To-do")
@export var to_do_preview: MarginContainer

# ---------- UI MANAGER ----------
func set_ui(visibility: bool, target: String) -> void:
	match target:
		"app": notes_app.visible = visibility
		"bar": bottom_bar.visible = visibility
		"notes_main": notes_preview.visible = visibility
		"notes_opened": notes_content_container.visible = visibility
		"new_note": new_note_container.visible = visibility
		"todo_main": to_do_preview.visible = visibility

# ---------- OPEN APP ----------
func _open_notes_app(open_app: bool) -> void:
	master.sound_manager.play_sound("phone_click")
	if open_app:
		set_ui(true, "app")
	else:
		set_ui(false, "app")
	
	set_ui(true, "notes_main")
	set_ui(false, "todo_main")
	set_ui(false, "notes_opened")
	set_ui(false, "new_note")
	
	notes_button.button_pressed = true
	todo_button.button_pressed = false

# ---------- NOTES METHODS ----------
func _on_all_notes_pressed() -> void:
	set_ui(true, "notes_main")
	set_ui(false, "todo_main")
	
	todo_button.button_pressed = false

func _on_notes_main_pressed(sound_on := true) -> void:
	if sound_on == true:
		master.sound_manager.play_sound("phone_click")
	
	set_ui(false, "app")

func _on_note_open_pressed() -> void: 
	master.sound_manager.play_sound("phone_click")
	set_ui(false, "notes_main")
	set_ui(true, "notes_opened")
	
func _on_new_note_pressed() -> void:
	master.sound_manager.play_sound("phone_click")
	set_ui(false, "notes_main")
	set_ui(true, "new_note")
	set_ui(false, "bar")

func _on_notes_list_pressed() -> void:
	master.sound_manager.play_sound("phone_click")
	set_ui(true, "notes_main")
	set_ui(false, "new_note")
	set_ui(false, "notes_opened")
	set_ui(false, "bar")

# ---------- TODOS METHODS ----------
func _on_todo_pressed() -> void:
	set_ui(true, "todo_main")
	set_ui(false, "notes_main")
	
	notes_button.button_pressed = false

func _on_todo_main_pressed() -> void:
	_open_notes_app(false)
 
# ---------- GODOT CALBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[Notes_app._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	notes_section.connect("open_note_window", Callable(self, "_on_note_open_pressed"))
	notes_section.connect("list_modified", Callable(self, "_on_notes_list_pressed"))
	
	if phone:
		phone.connect("open_notes_app", Callable(self, "_open_notes_app"))
		phone.connect("close_all_apps", Callable(self, "_on_notes_main_pressed").bind(false))
	else:
		push_warning("[Notes_app.ready] Phone is kinda missing...")
	
	notes_button.button_pressed = true
	set_ui(false, "bar")
	set_ui(true, "notes_main")
	set_ui(false, "todo_main")
