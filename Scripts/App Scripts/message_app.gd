extends Panel

var master: Master
var sound_manager: SoundManager
var json_manager: JSONManager = null
var notes_app_ref: Node = null  
var todo_section_ref: Node = null 

@export var phone: Control

@export_group("Mesages: App")
@export var message_app: Panel
@export var chat_preview: MarginContainer
@export var chat_content: MarginContainer
@export var chats_scroll_container: VBoxContainer

@export_group("Chat Content")
@export var chat_name_label: Label = null
@export var messages_container: VBoxContainer = null  
@export var save_to_notes_button: Button = null 

signal call_spawn_notes

# ---------- PREFAB ----------
var message_chats = preload("res://Prefabs/Components/message_chat.tscn")
var chat_bubble_prefab = preload("res://Prefabs/Components/chat_bubble.tscn")

# ---------- DATA ----------
var messages_data: Array = []
var current_chat_data: Dictionary = {}
var current_message_type: String = ""
var saved_tip_content: String = ""

# ---------- HELPER METHODS ----------
func _extract_message_content(message_data: Dictionary) -> String:
	"""Extract content from message data checking multiple possible fields"""
	for field in ["content", "text", "message", "body", "preview", "main_text", "message_text"]:
		if message_data.has(field):
			var field_value = message_data.get(field)
			if field_value and str(field_value).length() > 0:
				return str(field_value)
	
	for key in message_data.keys():
		var value = message_data.get(key)
		if value is String and value.length() > 10:
			return value
	
	return "No content available."

func _extract_tip_content(chat_data: Dictionary) -> String:
	"""Extract tip content from chat data"""
	for field in ["content", "text", "message", "body"]:
		var content = chat_data.get(field, "")
		if not content.is_empty():
			return content
	return "Tip information"

# ---------- METHODS ----------
func _on_open_messages_app() -> void:
	master.sound_manager.play_sound("phone_click")
	spawn_messages_preview() 
	set_ui(true, 1)
	set_ui(true, 2)

func reset_for_new_game() -> void:
	"""Reset messages for new game - clear ALL messages, start empty"""
	messages_data.clear()
	current_chat_data.clear()
	current_message_type = ""
	
	if chats_scroll_container:
		for child in chats_scroll_container.get_children():
			child.queue_free()
	
	if messages_container:
		for child in messages_container.get_children():
			child.queue_free()
	
	# Clear JSONManager cache
	var json_manager = JSONManager.get_instance()
	if json_manager:
		json_manager.messages_cache = []
	
	# Ensure messages.json is empty
	JSONManager.save_json("user://messages.json", [])
	
	# Reload messages (will be empty now)
	_load_messages()

func spawn_messages_preview() -> void:
	# Clear existing messages
	if chats_scroll_container:
		for child in chats_scroll_container.get_children():
			child.queue_free()
	
	# Load messages from JSON
	_load_messages()
	
	if not chats_scroll_container:
		push_warning("[Message_app] chats_scroll_container is null!")
		return
	
	# Show all messages
	for i in range(messages_data.size()):
		var message = messages_data[i]
		
		var content = _extract_message_content(message)
		if content.is_empty():
			continue
		message["content"] = content
		
		# Create chat preview
		var chat_instance = message_chats.instantiate()
		chats_scroll_container.add_child(chat_instance)
		
		# Store message_data directly on the instance
		chat_instance.message_data = message.duplicate()
		
		# Setup chat preview with message data
		if chat_instance.has_method("setup_message"):
			chat_instance.setup_message(message)
		
		# Connect signal for opening chat
		if not chat_instance.is_connected("open_chat", _on_chat_opened):
			chat_instance.connect("open_chat", _on_chat_opened)
		
		# Add discard button to each message
		_add_discard_button_to_message(chat_instance, message)

func _load_messages() -> void:
	"""Load messages from JSONManager"""
	if not json_manager:
		json_manager = JSONManager.get_instance()
	
	if json_manager:
		messages_data = json_manager.get_all_messages()
	else:
		push_warning("[Message_app] JSONManager not found!")
		messages_data = []

func _extract_message_data_from_instance(message_instance: Node) -> Dictionary:
	"""Helper to extract message data from instance using multiple methods"""
	var data = {}
	if "message_data" in message_instance:
		data = message_instance.message_data
	if data.is_empty():
		var msg_data = message_instance.get("message_data")
		if msg_data != null and msg_data is Dictionary:
			data = msg_data
	if data.is_empty():
		data = message_instance.get_meta("message_data", {})
	if data.is_empty():
		var props = message_instance.get_property_list()
		for prop in props:
			if prop.name == "message_data":
				data = message_instance.get(prop.name)
				break
	return data

func _on_chat_opened(message_instance: Node) -> void:
	master.sound_manager.play_sound("phone_click")
	
	if message_instance:
		current_chat_data = _extract_message_data_from_instance(message_instance)
		if current_chat_data.is_empty():
			return
		current_message_type = current_chat_data.get("type", "")
		_display_chat_content()
	else:
		return
	
	set_ui(false, 2)
	set_ui(true, 3)

func _find_messages_container() -> VBoxContainer:
	"""Helper to find messages container"""
	var container = get_node_or_null("Chats/VBoxContainer/Scrollable/MessagesContainer")
	if container:
		return container
	container = find_child("MessagesContainer", true, false)
	if container:
		return container
	var chat_content_node = get_node_or_null("Chats")
	if chat_content_node:
		return chat_content_node.find_child("MessagesContainer", true, false)
	return null

func _create_chat_bubble(content: String) -> Control:
	if not chat_bubble_prefab:
		push_warning("chat_bubble_prefab is not assigned!")
		return Label.new()  # fallback

	var chat_bubble = chat_bubble_prefab.instantiate() as Control

	if chat_bubble.has_method("set_text"):
		chat_bubble.set_text(content)
	else:
		push_warning("Chat bubble instance has no set_text method!")
		var fallback = Label.new()
		fallback.text = content
		return fallback

	return chat_bubble

func _ensure_container_visibility() -> void:
	"""Helper to ensure message container and parents are visible"""
	if not messages_container:
		return
	
	messages_container.visible = true
	messages_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var parent = messages_container.get_parent()
	var depth = 0
	while parent and depth < 5:
		if parent is Control:
			parent.visible = true
			parent.mouse_filter = Control.MOUSE_FILTER_PASS
		parent = parent.get_parent()
		depth += 1

func _update_save_button_state() -> void:
	"""Helper to update save to notes button state"""
	if save_to_notes_button:
		save_to_notes_button.visible = (current_message_type == "tip")
		if current_message_type == "tip":
			save_to_notes_button.disabled = false
			save_to_notes_button.text = "Save to Notes"
			saved_tip_content = ""
	elif current_message_type == "tip":
		_create_save_to_notes_button()

func _display_chat_content() -> void:
	"""Display the content of the selected message"""
	saved_tip_content = ""
	
	if not messages_container:
		messages_container = _find_messages_container()
	
	if not messages_container:
		push_error("[Message_app] MessagesContainer not found!")
		return
	
	for child in messages_container.get_children():
		child.queue_free()
	
	if chat_name_label:
		chat_name_label.text = current_chat_data.get("sender", "Unknown")
	
	var message_text = _extract_message_content(current_chat_data)
	var chat_bubble = _create_chat_bubble(message_text)
	
	_ensure_container_visibility()
	messages_container.add_child(chat_bubble)
	
	if messages_container.has_method("queue_sort"):
		messages_container.call_deferred("queue_sort")
	
	_update_save_button_state()

func _add_discard_button_to_message(chat_instance: Node, message_data: Dictionary) -> void:
	"""Add a discard button to a message preview item"""
	# Find the Preview container in the chat instance
	var preview_container = chat_instance.get_node_or_null("Preview")
	if not preview_container:
		return
	
	# Check if discard button already exists
	var existing_discard = chat_instance.get_node_or_null("Preview/DiscardButton")
	if existing_discard:
		return
	
	# Create discard button as a child of Preview/Chat (to position it on the right side)
	var chat_button = chat_instance.get_node_or_null("Preview/Chat")
	if not chat_button:
		return
	
	# Create HBoxContainer to hold chat content and discard button
	var chat_contents = chat_button.get_node_or_null("Contents")
	if not chat_contents:
		return
	
	# Add discard button as an overlay or as part of the chat button
	var discard_button = Button.new()
	discard_button.name = "DiscardButton"
	discard_button.text = "x"
	discard_button.custom_minimum_size = Vector2(15, 15)
	discard_button.flat = true
	discard_button.focus_mode = Control.FOCUS_NONE

	# Set text color for all states
	var text_color := Color("#2b3931")
	discard_button.add_theme_color_override("font_color", text_color)
	discard_button.add_theme_color_override("font_color_hover", text_color)
	discard_button.add_theme_color_override("font_color_pressed", text_color)

	# Position button on the right side of the chat button
	chat_button.add_child(discard_button)
	
	# Set anchors manually for right-top positioning (anchor to right and top)
	discard_button.anchor_left = 1.0
	discard_button.anchor_top = 0.0
	discard_button.offset_left = -40
	
	# Connect button to discard function
	discard_button.pressed.connect(func(): _on_discard_message_pressed(message_data, chat_instance))

func _on_discard_message_pressed(message_data: Dictionary, chat_instance: Node) -> void:
	"""Discard/remove a message"""
	if not json_manager:
		json_manager = JSONManager.get_instance()
	
	if json_manager and json_manager.has_method("remove_message"):
		if json_manager.remove_message(message_data):
			# Remove from local data
			for i in range(messages_data.size() - 1, -1, -1):
				var msg = messages_data[i]
				if msg.get("content", "") == message_data.get("content", "") and msg.get("sender", "") == message_data.get("sender", ""):
					messages_data.remove_at(i)
					break
			
			# Remove from UI
			chat_instance.queue_free()
			
			# Refresh message list
			spawn_messages_preview()
		else:
			push_warning("[Message_app] Failed to remove message from JSONManager")
	else:
		push_warning("[Message_app] JSONManager not found or missing remove_message method")

func _messages_match(message_a: Dictionary, message_b: Dictionary) -> bool:
	if message_a.is_empty() or message_b.is_empty():
		return false
	return message_a.get("content", "") == message_b.get("content", "") and message_a.get("sender", "") == message_b.get("sender", "")

func _remove_message_from_system(message_data: Dictionary) -> void:
	if message_data.is_empty():
		return
	
	if not json_manager:
		json_manager = JSONManager.get_instance()
	
	if json_manager and json_manager.has_method("remove_message"):
		json_manager.remove_message(message_data)
	
	for i in range(messages_data.size() - 1, -1, -1):
		if _messages_match(messages_data[i], message_data):
			messages_data.remove_at(i)
			break

func _remove_current_message_after_save() -> void:
	if current_chat_data.is_empty():
		return
	
	_remove_message_from_system(current_chat_data)
	spawn_messages_preview()
	current_chat_data.clear()
	set_ui(true, 2)
	set_ui(false, 3)

func _create_save_to_notes_button() -> void:
	"""Create a button to save tip to notes - positioned BEFORE ScrollContainer to stay visible"""
	# Find the SaveToNotesButton node or create it in the proper location
	if not save_to_notes_button:
		save_to_notes_button = get_node_or_null("Chats/VBoxContainer/SaveToNotesButton")
	
	if not save_to_notes_button and chat_content:
		# Find the VBoxContainer inside chat_content (Chats/VBoxContainer)
		var vbox_container = chat_content.get_node_or_null("Chats/VBoxContainer/Scrollable/SaveSpawn")
		
		if not vbox_container:
			# Fallback: try to find it via path
			vbox_container = get_node_or_null("Chats/VBoxContainer/Scrollable/SaveSpawn")
		
		# Create button
		var tahoma_font := preload("res://Assets/Fonts/BMmini.TTF")
		var button := Button.new()
		button.name = "SaveToNotesButton"
		button.text = "Save to Notes"
		button.custom_minimum_size = Vector2(180, 35)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_save_to_notes_pressed)
		
		# --- APPLY FONT ---
		var font_override := FontFile.new()
		font_override = tahoma_font
		button.add_theme_font_override("font", font_override)
		
		# --- APPLY FONT COLOR & SIZE ---
		button.add_theme_color_override("font_color", Color("2b3931"))
		var font_with_size := FontVariation.new()
		font_with_size.base_font = tahoma_font
		button.add_theme_font_size_override("font_size", 16)

		button.add_theme_font_override("font", font_with_size)
		
		var color := Color("aabab1")
		
		var sb_normal := StyleBoxFlat.new()
		sb_normal.bg_color = color
		sb_normal.corner_radius_top_left = 5
		sb_normal.corner_radius_top_right = 5
		sb_normal.corner_radius_bottom_left = 5
		sb_normal.corner_radius_bottom_right = 5
		button.add_theme_stylebox_override("normal", sb_normal)

		# HOVER
		var sb_hover := StyleBoxFlat.new()
		sb_hover.bg_color = color
		sb_hover.corner_radius_top_left = 5
		sb_hover.corner_radius_top_right = 5
		sb_hover.corner_radius_bottom_left = 5
		sb_hover.corner_radius_bottom_right = 5
		button.add_theme_stylebox_override("hover", sb_hover)

		# PRESSED
		var sb_pressed := StyleBoxFlat.new()
		sb_pressed.bg_color = color
		sb_pressed.corner_radius_top_left = 5
		sb_pressed.corner_radius_top_right = 5
		sb_pressed.corner_radius_bottom_left = 5
		sb_pressed.corner_radius_bottom_right = 5
		button.add_theme_stylebox_override("pressed", sb_pressed)

		if vbox_container and vbox_container is VBoxContainer:
			# Always add to bottom
			vbox_container.add_child(button)

			save_to_notes_button = button
		else:
			push_warning("[Message_app] Could not find VBoxContainer for save button!")

func _on_save_to_notes_pressed() -> void:
	if current_message_type != "tip":
		return
	
	var tip_content = _extract_tip_content(current_chat_data)
	var tip_title = current_chat_data.get("title", current_chat_data.get("sender", "Tip"))
	
	if tip_content.strip_edges() == "" or tip_content == "Tip information":
		if save_to_notes_button:
			save_to_notes_button.text = "Nothing to Save"
			await get_tree().create_timer(1.0).timeout
			save_to_notes_button.text = "Save to Notes"
		return

	# Prevent duplicate saves in this session
	if tip_content == saved_tip_content:
		if save_to_notes_button:
			save_to_notes_button.text = "Already Saved!"
			await get_tree().create_timer(1.0).timeout
			save_to_notes_button.text = "Save to Notes"
		return
	
	DataManager.add_note_runtime(tip_title, tip_content)
	emit_signal("call_spawn_notes")
	saved_tip_content = tip_content
	
	if save_to_notes_button:
		save_to_notes_button.disabled = true
		save_to_notes_button.text = "Saved!"
	
	_remove_current_message_after_save()
	_on_chat_closed_pressed()

# -------- UI HANDLER ----------
func set_ui(visibility: bool, target: int) -> void:
	match target:
		1: message_app.visible = visibility
		2: chat_preview.visible = visibility
		3: chat_content.visible = visibility

# ---------- BUTTONS ----------
func _on_messages_main_pressed() -> void:
	master.sound_manager.play_sound("phone_click")
	set_ui(false, 1)
	set_ui(false, 2)
	
	# Hide app_container to show phone main menu again
	if phone and phone.app_container:
		phone.app_container.visible = false
	elif phone:
		# Try to find app_container directly via node path
		var app_container = phone.get_node_or_null("PhoneContainer/MainPhone/AppContainers")
		if app_container:
			app_container.visible = false

func close_messages() -> void:
	set_ui(false, 1)
	set_ui(false, 2)
	# Hide app_container to show phone main menu again
	if phone and phone.app_container:
		phone.app_container.visible = false
	elif phone:
		# Try to find app_container directly via node path
		var app_container = phone.get_node_or_null("PhoneContainer/MainPhone/AppContainers")
		if app_container:
			app_container.visible = false

func _on_chat_closed_pressed() -> void:
	master.sound_manager.play_sound("phone_click")
	set_ui(true, 2)
	set_ui(false, 3)

func set_todo_section_ref(todo_section: Node) -> void:
	"""Set reference to todo section for saving tips to to-do"""
	todo_section_ref = todo_section

func add_message(message_data: Dictionary) -> void:
	"""Add a new message (called by Lyra or other systems)"""
	if not json_manager:
		json_manager = JSONManager.get_instance()
	
	if json_manager:
		json_manager.add_message(message_data)
		_play_new_message_sound()
		# Refresh if app is open
		if message_app.visible:
			spawn_messages_preview()

func _play_new_message_sound() -> void:
	var sm: SoundManager = sound_manager
	if not sm and master and master.sound_manager:
		sm = master.sound_manager
	elif not sm:
		sm = SoundManager.instance
	
	if sm:
		sm.play_sound("NewMessage")

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		push_warning("[Message_app] Master is null!")
		return
	
	if master.sound_manager:
		sound_manager = master.sound_manager
	elif SoundManager.instance:
		sound_manager = SoundManager.instance
	
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
		phone.connect("close_all_apps", Callable(self, "close_messages"))
	else:
		push_warning("[Messaging_app.ready] Phone is kinda missing...")
	
	# Default UI
	set_ui(false, 3)
