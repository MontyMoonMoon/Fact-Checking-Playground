extends Panel

var master: Master
var sound_manager: SoundManager
var json_manager: JSONManager = null
var notes_app_ref: Node = null  # Reference to notes app for saving tips
var todo_section_ref: Node = null  # Reference to todo section for saving tips to to-do

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
	spawn_messages_preview()  # Refresh messages when opening
	set_ui(true, 1)
	set_ui(true, 2)

func reset_for_new_game() -> void:
	"""Reset messages for new game - clear ALL messages, start empty"""
	print("[Message App] Resetting messages for NEW GAME - starting empty...")
	
	# Clear local data
	messages_data.clear()
	current_chat_data.clear()
	current_message_type = ""
	
	# Clear UI
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
	
	# Ensure messages.json is empty (file already cleared by map_0)
	# Save empty array to prevent JSONManager from auto-initializing
	JSONManager.save_json("user://messages.json", [])
	
	# Reload messages (will be empty now)
	_load_messages()
	
	print("[Message App] Reset complete - messages EMPTY (loaded %d)" % messages_data.size())
	
	if messages_data.size() > 0:
		push_warning("[Message App] ERROR - Still have %d messages after reset!" % messages_data.size())

func spawn_messages_preview() -> void:
	print("[Message_app.spawn_messages_preview] Starting...")
	
	# Clear existing messages
	if chats_scroll_container:
		for child in chats_scroll_container.get_children():
			child.queue_free()
	
	# Load messages from JSON
	_load_messages()
	
	if not chats_scroll_container:
		push_warning("[Message_app.spawn_messages_preview] chats_scroll_container is null! Cannot spawn messages.")
		return
	
	print("[Message_app.spawn_messages_preview] Spawning %d messages..." % messages_data.size())
	
	# Show all messages - no artificial limits
	for i in range(messages_data.size()):
		var message = messages_data[i]
		
		var content = _extract_message_content(message)
		if content.is_empty():
			push_warning("[Message_app.spawn_messages_preview] Message %d has no content!" % i)
		message["content"] = content
		
		# Create chat preview
		var chat_instance = message_chats.instantiate()
		chats_scroll_container.add_child(chat_instance)
		
		# Store message_data directly on the instance BEFORE setup_message
		# This ensures it's accessible when clicked
		chat_instance.message_data = message.duplicate()
		print("[Message_app.spawn_messages_preview] Message %d: Stored message_data with content: %s" % [i, message.get("content", "").substr(0, 30)])
		
		# Setup chat preview with message data
		if chat_instance.has_method("setup_message"):
			chat_instance.setup_message(message)
		else:
			push_warning("[Message_app.spawn_messages_preview] Chat instance doesn't have setup_message method!")
		
		# Connect signal for opening chat
		if not chat_instance.is_connected("open_chat", _on_chat_opened):
			chat_instance.connect("open_chat", _on_chat_opened)
		
		# Add discard button to each message
		_add_discard_button_to_message(chat_instance, message)
	
	print("[Message_app.spawn_messages_preview] Spawned %d message previews" % chats_scroll_container.get_child_count())

func _load_messages() -> void:
	"""Load messages from JSONManager"""
	if not json_manager:
		json_manager = JSONManager.get_instance()
	
	if json_manager:
		messages_data = json_manager.get_all_messages()
		print("[Message_app] Loaded %d messages from JSON" % messages_data.size())
		
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
			push_warning("[Message_app._on_chat_opened] current_chat_data is empty!")
		current_message_type = current_chat_data.get("type", "")
		_display_chat_content()
	else:
		push_warning("[Message_app._on_chat_opened] message_instance is null!")
	
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

func _create_chat_bubble(content: String) -> Node:
	"""Helper to create chat bubble with content"""
	var chat_bubble = chat_bubble_prefab.instantiate()
	var paragraph_label = chat_bubble.get_node_or_null("Content/TextsContainer/Paragraph")
	
	if not paragraph_label:
		paragraph_label = chat_bubble.find_child("Paragraph", true, false)
	
	if paragraph_label and paragraph_label is Label:
		paragraph_label.text = content
		paragraph_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		paragraph_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		paragraph_label.visible = true
		return chat_bubble
	
	var fallback_label = Label.new()
	fallback_label.text = content
	fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fallback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fallback_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return fallback_label

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
	discard_button.text = "X"
	discard_button.custom_minimum_size = Vector2(30, 30)
	discard_button.flat = true
	
	# Position button on the right side of the chat button
	chat_button.add_child(discard_button)
	# Set anchors manually for right-top positioning (anchor to right and top)
	discard_button.anchor_left = 1.0
	discard_button.anchor_top = 0.0
	discard_button.anchor_right = 1.0
	discard_button.anchor_bottom = 0.0
	discard_button.offset_left = -35
	discard_button.offset_top = 5
	discard_button.offset_right = -5
	discard_button.offset_bottom = 35
	
	# Connect button to discard function
	discard_button.pressed.connect(func(): _on_discard_message_pressed(message_data, chat_instance))

func _on_discard_message_pressed(message_data: Dictionary, chat_instance: Node) -> void:
	"""Discard/remove a message"""
	if not json_manager:
		json_manager = JSONManager.get_instance()
	
	if json_manager and json_manager.has_method("remove_message"):
		if json_manager.remove_message(message_data):
			print("[Message_app] Discarded message: %s" % message_data.get("sender", "Unknown"))
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
		var vbox_container = chat_content.get_node_or_null("VBoxContainer")
		
		if not vbox_container:
			# Fallback: try to find it via path
			vbox_container = get_node_or_null("Chats/VBoxContainer")
		
		# Create button
		var button = Button.new()
		button.name = "SaveToNotesButton"
		button.text = "Save to Notes"
		button.custom_minimum_size = Vector2(180, 35)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_save_to_notes_pressed)
		
		# Add to VBoxContainer - place it BEFORE the ScrollContainer so it stays visible
		# Order: Control1 -> Chat Closed -> Panel -> SaveToNotesButton -> ScrollContainer
		if vbox_container and vbox_container is VBoxContainer:
			# Find the ScrollContainer to insert button BEFORE it
			var scrollable_index = -1
			for i in range(vbox_container.get_child_count()):
				var child = vbox_container.get_child(i)
				if child is ScrollContainer:
					scrollable_index = i
					break
			
			if scrollable_index >= 0:
				# Insert button BEFORE ScrollContainer (position will be scrollable_index)
				vbox_container.add_child(button)
				vbox_container.move_child(button, scrollable_index)
				save_to_notes_button = button
				print("[Message_app._create_save_to_notes_button] Created SaveToNotesButton BEFORE ScrollContainer at index %d" % scrollable_index)
			else:
				# Fallback: find Panel and add after it
				var panel_index = -1
				for i in range(vbox_container.get_child_count()):
					var child = vbox_container.get_child(i)
					if child is Panel:
						panel_index = i
						break
				
				vbox_container.add_child(button)
				if panel_index >= 0:
					vbox_container.move_child(button, panel_index + 1)
				save_to_notes_button = button
				print("[Message_app._create_save_to_notes_button] Created SaveToNotesButton (fallback: after Panel at index %d)" % (panel_index + 1))
		else:
			push_warning("[Message_app._create_save_to_notes_button] Could not find VBoxContainer!")
	elif save_to_notes_button:
		save_to_notes_button.pressed.disconnect(_on_save_to_notes_pressed)
		save_to_notes_button.pressed.connect(_on_save_to_notes_pressed)

func _on_save_to_notes_pressed() -> void:
	"""Save the current tip to notes system - prevents duplicates"""
	if current_message_type != "tip":
		return
	
	var tip_content = _extract_tip_content(current_chat_data)
	
	# Check if this tip has already been saved (prevent duplicates)
	if tip_content == saved_tip_content:
		if save_to_notes_button:
			save_to_notes_button.text = "Already Saved!"
			await get_tree().create_timer(1.0).timeout
			save_to_notes_button.text = "Save to Notes"
		return
	
	# Check if note with same content already exists in notes system
	if not json_manager:
		json_manager = JSONManager.get_instance()
	
	var existing_notes = []
	if json_manager:
		existing_notes = json_manager.load_notes()
	
	# Check for duplicate content
	for note in existing_notes:
		if note.get("content", "") == tip_content:
			if save_to_notes_button:
				save_to_notes_button.text = "Already Saved!"
				await get_tree().create_timer(1.0).timeout
				save_to_notes_button.text = "Save to Notes"
			return
	
	print("[Message_app._on_save_to_notes_pressed] Saving tip to notes...")
	
	# Get tip title/sender
	var tip_title = current_chat_data.get("title", current_chat_data.get("sender", "Tip"))
	
	# Create note data structure
	var note_data = {
		"id": "note_%d" % Time.get_ticks_msec(),
		"title": tip_title,
		"content": tip_content,
		"is_legit": current_chat_data.get("is_legit", false),  # Determine if tip is legitimate
		"viewed": false,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	# Add to notes via notes_app_ref
	if notes_app_ref and notes_app_ref.has_method("add_note"):
		notes_app_ref.add_note(note_data)
		print("[Message_app._on_save_to_notes_pressed] Added tip to notes: %s" % tip_title)
	else:
		# Fallback: add via JSONManager directly
		if json_manager:
			json_manager.add_note(note_data)
			print("[Message_app._on_save_to_notes_pressed] Added tip to notes via JSONManager: %s" % tip_title)
		else:
			push_warning("[Message_app._on_save_to_notes_pressed] Neither notes_app_ref nor json_manager available!")
			return
	
	# Mark this tip as saved to prevent duplicate saves in this session
	saved_tip_content = tip_content
	
	if save_to_notes_button:
		save_to_notes_button.disabled = true
		save_to_notes_button.text = "Saved!"
	
	_remove_current_message_after_save()

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

func set_notes_app_ref(notes_app: Node) -> void:
	"""Set reference to notes app for saving tips"""
	notes_app_ref = notes_app

func set_todo_section_ref(todo_section: Node) -> void:
	"""Set reference to todo section for saving tips to to-do"""
	todo_section_ref = todo_section
	print("[Message_app] Todo section reference set: %s" % (todo_section.name if todo_section else "null"))

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
		print("[WARN: Message_app._ready] Master is still null. Calling members from this object may cause issues.")
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
		phone.connect("close_all_apps", Callable(self, "_on_messages_main_pressed"))
	else:
		push_warning("[Messaging_app.ready] Phone is kinda missing...")
	
	# Don't spawn messages in _ready() - let reset_for_new_game() or map_01 handle it
	# This prevents messages from loading before reset happens on new game
	# Messages will be spawned when the app is opened for the first time
	# spawn_messages_preview()  # Commented out - will be called by reset or when opening app
	
	# Default UI
	set_ui(false, 3)
