extends Panel

var master: Master
var sound_manager: SoundManager
var json_manager: JSONManager = null
var notes_app_ref: Node = null  # Reference to notes app for saving tips

@export var phone: Control

@export_group("Mesages: App")
@export var message_app: Panel
@export var chat_preview: MarginContainer
@export var chat_content: MarginContainer
@export var chats_scroll_container: VBoxContainer

@export_group("Chat Content")
@export var chat_name_label: Label = null
@export var messages_container: VBoxContainer = null  # Container for individual messages in chat view
@export var save_to_notes_button: Button = null  # Button to save tip to notes (only visible for tips)

# ---------- PREFAB ----------
var message_chats = preload("res://Prefabs/Components/message_chat.tscn")

# ---------- DATA ----------
var messages_data: Array = []
var current_chat_data: Dictionary = {}
var current_message_type: String = ""  # "lyra_taunt", "threat", "trash", "tip"

# ---------- METHODS ----------
func _on_open_messages_app() -> void:
	master.sound_manager.play_sound("phone_click")
	spawn_messages_preview()  # Refresh messages when opening
	set_ui(true, 1)
	set_ui(true, 2)

func spawn_messages_preview() -> void:
	print("[Message_app] Spawning messages preview...")
	
	# Clear existing messages
	for child in chats_scroll_container.get_children():
		child.queue_free()
	
	# Load messages from JSON
	_load_messages()
	
	# Show all messages - no artificial limits
	for message in messages_data:
		# Create chat preview
		var chat_instance = message_chats.instantiate()
		chats_scroll_container.add_child(chat_instance)
		
		# Setup chat preview with message data
		if chat_instance.has_method("setup_message"):
			chat_instance.setup_message(message)
		else:
			push_warning("[Message_app] Chat instance doesn't have setup_message method!")
		
		chat_instance.connect("open_chat", _on_chat_opened)
	
	print("[Message_app] Spawned %d message previews (total messages: %d)" % [chats_scroll_container.get_child_count(), messages_data.size()])

func _load_messages() -> void:
	"""Load messages from JSONManager"""
	if not json_manager:
		json_manager = JSONManager.get_instance()
	
	if json_manager:
		messages_data = json_manager.get_all_messages()
		print("[Message_app] Loaded %d messages from JSON" % messages_data.size())
		
		# Debug: print message types
		var type_counts = {}
		for msg in messages_data:
			var msg_type = msg.get("type", "unknown")
			if not type_counts.has(msg_type):
				type_counts[msg_type] = 0
			type_counts[msg_type] += 1
		print("[Message_app] Message breakdown: %s" % str(type_counts))
	else:
		push_warning("[Message_app] JSONManager not found!")
		messages_data = []

func _on_chat_opened(message_instance: Node) -> void:
	master.sound_manager.play_sound("phone_click")
	
	# Get message data from the clicked instance
	if message_instance:
		# Try to get from message_data property (from chats_content.gd)
		if "message_data" in message_instance:
			current_chat_data = message_instance.message_data
		else:
			current_chat_data = message_instance.get_meta("message_data", {})
		
		current_message_type = current_chat_data.get("type", "")
		_display_chat_content()
	
	set_ui(false, 2)
	set_ui(true, 3)

func _display_chat_content() -> void:
	"""Display the content of the selected message"""
	if not messages_container:
		# Try to find it
		messages_container = get_node_or_null("Chats/VBoxContainer/Scrollable/MessagesContainer")
	
	if not messages_container:
		push_warning("[Message_app] MessagesContainer not found!")
		return
	
	# Clear existing messages
	for child in messages_container.get_children():
		child.queue_free()
	
	# Set chat name
	if chat_name_label:
		var sender = current_chat_data.get("sender", "Unknown")
		chat_name_label.text = sender
	
	# Create message content label
	var message_label = RichTextLabel.new()
	message_label.bbcode_enabled = true
	message_label.fit_content = true
	message_label.scroll_following = true
	message_label.custom_minimum_size = Vector2(220, 0)
	
	var message_text = current_chat_data.get("content", "")
	message_label.text = message_text
	messages_container.add_child(message_label)
	
	# Show "Save to Notes" button only for tips
	if save_to_notes_button:
		save_to_notes_button.visible = (current_message_type == "tip")
	elif current_message_type == "tip":
		# Create button if it doesn't exist
		_create_save_to_notes_button()

func _create_save_to_notes_button() -> void:
	"""Create a button to save tip to notes"""
	if not messages_container:
		return
	
	var button = Button.new()
	button.text = "Save to Notes"
	button.custom_minimum_size = Vector2(200, 40)
	button.pressed.connect(_on_save_to_notes_pressed)
	messages_container.add_child(button)
	save_to_notes_button = button

func _on_save_to_notes_pressed() -> void:
	"""Save the current tip to notes"""
	if current_message_type != "tip":
		return
	
	if not notes_app_ref:
		push_warning("[Message_app] Notes app reference not set!")
		return
	
	# Create note data from tip
	var note_data = {
		"id": "tip_%d" % Time.get_unix_time_from_system(),
		"title": current_chat_data.get("title", "Tip"),
		"content": current_chat_data.get("content", ""),
		"is_legit": current_chat_data.get("is_legit", false),  # Some tips are legit, some are suspicious
		"date": Time.get_datetime_string_from_system()
	}
	
	# Add to notes via notes app
	if notes_app_ref.has_method("add_note"):
		notes_app_ref.add_note(note_data)
		print("[Message_app] Saved tip to notes: %s" % note_data.title)
	else:
		# Fallback: add directly via JSONManager
		if json_manager:
			json_manager.add_note(note_data)
			print("[Message_app] Saved tip to notes via JSONManager")
	
	# Show feedback
	if save_to_notes_button:
		save_to_notes_button.text = "Saved!"
		await get_tree().create_timer(1.0).timeout
		save_to_notes_button.text = "Save to Notes"

# -------- UI HANDLER ----------
func set_ui(visibility: bool, target: int) -> void:
	match target:
		1: message_app.visible = visibility
		2: chat_preview.visible = visibility
		3: chat_content.visible = visibility

# ---------- BUTTONS ----------
func _on_messages_main_pressed() -> void:
	set_ui(false, 1)
	set_ui(false, 2)

func _on_chat_closed_pressed() -> void:
	master.sound_manager.play_sound("phone_click")
	set_ui(true, 2)
	set_ui(false, 3)

func set_notes_app_ref(notes_app: Node) -> void:
	"""Set reference to notes app for saving tips"""
	notes_app_ref = notes_app

func add_message(message_data: Dictionary) -> void:
	"""Add a new message (called by Lyra or other systems)"""
	if not json_manager:
		json_manager = JSONManager.get_instance()
	
	if json_manager:
		json_manager.add_message(message_data)
		# Refresh if app is open
		if message_app.visible:
			spawn_messages_preview()

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[WARN: Message_app._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	json_manager = JSONManager.get_instance()
	
	# Try to find chat content nodes
	if not chat_name_label:
		chat_name_label = get_node_or_null("Chats/VBoxContainer/Chat Closed/Name")
	if not messages_container:
		messages_container = get_node_or_null("Chats/VBoxContainer/Scrollable/MessagesContainer")
	if not save_to_notes_button:
		save_to_notes_button = get_node_or_null("Chats/VBoxContainer/SaveToNotesButton")
		
	if phone:
		phone.connect("open_message_app", Callable(self, "_on_open_messages_app"))
		phone.connect("close_all_apps", Callable(self, "_on_messages_main_pressed"))
	else:
		push_warning("[Messaging_app.ready] Phone is kinda missing...")
	
	spawn_messages_preview()
	
	# Default UI
	set_ui(false, 3)
