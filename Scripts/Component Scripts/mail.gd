extends Control

var master: Master
var data_manager: DataManager
var receiver_name: String = "" 

@onready var mail: Control = $"."

@export_group("Mail Texts")
@export var receiver: Label
@export var sender: Label
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
		# Get master if not already set
		if not master:
			master = get_node("/root/Master")
		
		# Get player name from master or DataManager
		if master and master.has_method("get_data_manager"):
			var dm = master.get_data_manager()
			if dm and dm.player_name:
				receiver.text = dm.player_name
		elif master and "data_manager" in master:
			var dm = master.data_manager
			if dm and dm.player_name:
				receiver.text = dm.player_name
		elif master and "player_name" in master:
			receiver.text = master.player_name
		else:
			# Fallback to DataManager static method
			receiver.text = DataManager.player_name if DataManager.player_name else "Player"
		
	subject.text = mail_dict.get("subject", "")
	main_text.text = mail_dict.get("main_text", "")
	
	# Set sender (from)
	if sender:
		var sender_text = mail_dict.get("sender", mail_dict.get("from", "Unknown Sender"))
		sender.text = sender_text

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
