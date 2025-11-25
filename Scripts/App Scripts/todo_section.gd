extends MarginContainer

var master: Master
var sound_manager: SoundManager

@export_group("Todo Contents")
@export var container: VBoxContainer
@export var game_task_button: Button
@export var player_task_button: Button

var personal_tasks: Array = []
var game_tasks: Array = []

# ---------- PREFAB ----------
var todo = preload("res://Prefabs/Components/to-do.tscn")

# ---------- TODOS METHODS ----------
func spawn_game_tasks() -> void:
	var game_todos = master.json_manager.load_todos()
	for i in range(game_todos.size()):
		var todo_data = game_todos[i] 
		var todo_instance = todo.instantiate()
		container.add_child(todo_instance)
		container.move_child(todo_instance, 1)
		todo_instance.visible = false
		game_tasks.append(todo_instance)
		
		todo_instance.input_line.text = todo_data.get("todo_content", "")
		todo_instance.check_box.button_pressed = todo_data.get("todo_state", false)
		todo_instance.set_editable(false)

func spawn_personal_tasks() -> void:
	for t in personal_tasks:
		if t and is_instance_valid(t):
			t.queue_free()
	personal_tasks.clear()
	
	for i in range(DataManager.todos_data.size()):
		var todo_data = DataManager.todos_data[i]
		var todo_instance = todo.instantiate()
		todo_instance.todo_id = todo_data["todo_id"] 
		todo_instance.input_line.text = todo_data["todo_text"]
		todo_instance.check_box.button_pressed = todo_data["todo_completed"]
		container.add_child(todo_instance)
		todo_instance.visible = false
		personal_tasks.append(todo_instance)
		
		todo_instance.connect("todo_added", Callable(self, "_on_personal_task_changed"))
		todo_instance.connect("todo_deleted", Callable(self, "_on_personal_task_changed"))
		todo_instance.connect("todo_updated", Callable(self, "_on_personal_task_changed"))
	
	var empty_todo = todo.instantiate()
	empty_todo.input_line.text = ""
	empty_todo.check_box.button_pressed = false
	container.add_child(empty_todo)
	personal_tasks.append(empty_todo)
	empty_todo.visible = false
	
	empty_todo.connect("todo_added", Callable(self, "_on_personal_task_changed"))
	empty_todo.connect("todo_deleted", Callable(self, "_on_personal_task_changed"))
	empty_todo.connect("todo_updated", Callable(self, "_on_personal_task_changed"))

func _on_personal_task_changed(_id = "", _text = "", _state = false) -> void:
	await get_tree().process_frame
	spawn_personal_tasks()
	
	_on_personal_tasks_pressed()

func set_to_do_visibility(target: int, visibility: bool) -> void:
	match target:
		1:
			for t in game_tasks:
				t.visible = visibility
		2:
			for t in personal_tasks:
				t.visible = visibility

# ---------- TO_DO: NAV BUTTONS ----------
func _on_game_tasks_pressed() -> void:
	master.sound_manager.play_sound("phone_click")
	if game_task_button.button_pressed:
		set_to_do_visibility(1, true)
	else:
		set_to_do_visibility(1, false)

func _on_personal_tasks_pressed() -> void:
	master.sound_manager.play_sound("phone_click")
	if player_task_button.button_pressed:
		set_to_do_visibility(2, true)
	else: 
		set_to_do_visibility(2, false)

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[Todo_section._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	DataManager.load_data() 
	
	spawn_game_tasks()
	spawn_personal_tasks()
	
	set_to_do_visibility(1, false)
	set_to_do_visibility(2, false)
