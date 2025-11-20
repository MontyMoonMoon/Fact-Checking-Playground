extends Control

@export_group("Preview Info")
@export var contact_name: Label
@export var preview_msg: Label

# ---------- SIGNAL ----------
signal open_chat(message_instance: Node)

# ---------- DATA ----------
var message_data: Dictionary = {}

# ---------- CHAT BUTTONS ----------
func _on_chat_pressed() -> void:
	emit_signal("open_chat", self)

func setup_message(msg_data: Dictionary) -> void:
	"""Setup the message preview with data"""
	message_data = msg_data
	
	# Ensure labels are found (in case setup_message is called before _ready)
	if not contact_name:
		contact_name = get_node_or_null("Preview/Chat/Contents/VBoxContainer/Header")
	if not preview_msg:
		preview_msg = get_node_or_null("Preview/Chat/Contents/VBoxContainer/Preview")
	
	var sender = msg_data.get("sender", "Unknown")
	var preview_text = msg_data.get("preview", msg_data.get("content", ""))
	
	# Truncate preview if too long
	if preview_text.length() > 30:
		preview_text = preview_text.substr(0, 27) + "..."
	
	if contact_name:
		contact_name.text = sender
	else:
		push_warning("[Chats_content] contact_name label not found!")
	
	if preview_msg:
		preview_msg.text = preview_text
	else:
		push_warning("[Chats_content] preview_msg label not found!")

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	# Auto-find labels if not set via export
	if not contact_name:
		contact_name = get_node_or_null("Preview/Chat/Contents/VBoxContainer/Header")
	if not preview_msg:
		preview_msg = get_node_or_null("Preview/Chat/Contents/VBoxContainer/Preview")
