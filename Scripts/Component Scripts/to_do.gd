extends Control

@export_group("To-do Contents")
@export var check_box: CheckBox
@export var input_line: LineEdit

var todo_id: String = "" 

signal todo_added(todo_id: String, text: String, completed: bool)
signal todo_deleted(todo_id: String)
signal todo_updated(todo_id: String, text: String, completed: bool)

func set_editable(disable: bool) -> void:
	check_box.disabled = not disable
	input_line.editable = disable

func _on_text_submitted(new_text: String) -> void:
	new_text = new_text.strip_edges()
	
	if new_text == "":
		if todo_id != "":
			DataManager.delete_todo_by_id(todo_id) 
			emit_signal("todo_deleted", todo_id)
			queue_free()
	else:
		if todo_id == "":
			todo_id = DataManager.add_todo_runtime(new_text, check_box.button_pressed)
			emit_signal("todo_added", todo_id, new_text, check_box.button_pressed)
		else:
			for t in DataManager.todos_data:
				if t.get("todo_id", "") == todo_id:
					t["todo_text"] = new_text
					t["todo_completed"] = check_box.button_pressed
					break
			DataManager.save_data()  
	emit_signal("todo_updated", todo_id, new_text, check_box.button_pressed)

func _on_check_box_toggled(button_pressed: bool) -> void:
	if todo_id == "":
		return
	
	for todo in DataManager.todos_data:
		if todo.get("todo_id", "") == todo_id:
			todo["todo_completed"] = button_pressed
			break
	
	DataManager.save_data()
	emit_signal("todo_updated", todo_id, input_line.text, button_pressed)

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	input_line.text_submitted.connect(_on_text_submitted)
	check_box.toggled.connect(_on_check_box_toggled)
