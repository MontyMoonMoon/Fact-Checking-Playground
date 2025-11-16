extends Control

var master: Master
var data_manager: DataManager
var receiver_name: String = "" 

@onready var mail: Control = $"."

@export_group("Mail Texts")
@export var receiver: Label
@export var subject: Label
@export var main_text: Label

@export_subgroup("Button")
@export var confirm_button: Button

var is_dragging := false
var drag_offset := Vector2.ZERO

func load_mail(mail_dict: Dictionary) -> void:
	if receiver_name != "":
		receiver.text = receiver_name
	else:
		receiver.text = master.data_manager.player_name  
		
	subject.text = mail_dict.get("subject", "")
	main_text.text = mail_dict.get("main_text", "")

# ---------- BUTTONS ----------
func _on_show_confirm() -> void:
	confirm_button.visible = true
	confirm_button.connect("pressed", Callable(get_parent(), "_on_confirm_pressed"))
	
func _on_exit_pressed() -> void:
	queue_free()

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	receiver.text = receiver_name
	subject.text = ""
	main_text.text = ""
	confirm_button.visible = false

# ---------- MAKE DRAGGABLE ----------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = mail.global_position - get_global_mouse_position()
			else:
				is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		mail.global_position = get_global_mouse_position() + drag_offset
