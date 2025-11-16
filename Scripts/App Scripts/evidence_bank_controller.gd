extends MarginContainer
class_name EvidenceBankController

# References
@onready var scroll_area: ScrollContainer = $ScrollableArea
@onready var content_container: VBoxContainer = $ScrollableArea/ContentContainer
@onready var info_list_container: VBoxContainer = $ScrollableArea/ContentContainer/InfoListSection/InfoListContainer
@onready var selected_title_label: Label = $ScrollableArea/ContentContainer/SelectedSection/TitleLabel
@onready var selected_content_label: RichTextLabel = $ScrollableArea/ContentContainer/SelectedSection/ContentLabel
@onready var add_button: Button = $ScrollableArea/ContentContainer/ButtonSection/AddButton
@onready var trash_button: Button = $ScrollableArea/ContentContainer/ButtonSection/TrashButton
@onready var refresh_button: Button = $ScrollableArea/ContentContainer/ButtonSection/RefreshButton

# Data
var stored_infos: Array = []
var trashed_infos: Array = []  # Store trashed articles
var selected_info: Dictionary = {}
var ai_analysis_ref: Node = null
var game_manager: Node = null
var trash_popup: Control = null  # Reference to the TrashPopup in the scene



func _ready():
	# Load collected infos
	_load_collected_infos()
	_load_trashed_infos()  # Load trashed articles
	_display_info_buttons()
	
	# Connect buttons
	if add_button:
		add_button.pressed.connect(_on_add_pressed)
	if trash_button:
		trash_button.pressed.connect(_on_trash_pressed)
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_pressed)
	
	# Enable BBCode
	if selected_content_label:
		selected_content_label.bbcode_enabled = true
	
	# Find TrashPopup in the scene (similar to GameFailedPopup)
	call_deferred("_find_and_hide_trash_popup")
	
	# Start hidden
	visible = false

func set_ai_analysis_ref(ref: Node):
	ai_analysis_ref = ref

func set_game_manager(manager: Node):
	game_manager = manager

func _load_collected_infos():
	var file_path = "res://dataset.json"
	if not FileAccess.file_exists(file_path):
		push_warning("Collected infos not found at %s" % file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	var all_cases = []
	if typeof(data) == TYPE_DICTIONARY and data.has("cases"):
		all_cases = data["cases"].duplicate()
		print("Evidence Bank: Loaded %d cases from dataset.json" % all_cases.size())
	elif typeof(data) == TYPE_ARRAY:
		all_cases = data
	else:
		push_error("Invalid JSON format")
		return
	
	# Also load additions from user file (emails added during runtime)
	var additions_path = "user://dataset_additions.json"
	if FileAccess.file_exists(additions_path):
		var additions_file = FileAccess.open(additions_path, FileAccess.READ)
		if additions_file:
			var additions_data = JSON.parse_string(additions_file.get_as_text())
			additions_file.close()
			if typeof(additions_data) == TYPE_ARRAY:
				# Merge additions, avoiding duplicates
				for addition in additions_data:
					var article_text = addition.get("article_text", "")
					var exists = false
					for case in all_cases:
						if case.get("article_text", "") == article_text:
							exists = true
							break
					if not exists:
						all_cases.append(addition)
				print("Evidence Bank: Loaded %d additional cases from user file" % additions_data.size())
	
	# Convert cases to info format
	stored_infos = []
	for case in all_cases:
		var info = {
			"title": "Case: " + case.get("stance", "Unknown"),
			"content": _format_case_content(case),
			"case_data": case
		}
		stored_infos.append(info)
	print("Evidence Bank: Total %d cases loaded" % stored_infos.size())

func _format_case_content(case: Dictionary) -> String:
	var content = "[b]Article:[/b] " + case.get("article_text", "") + "\n\n"
	content += "[b]Tip:[/b] " + case.get("tip_text", "") + "\n\n"
	content += "[b]Facts:[/b]\n" + _format_facts(case.get("facts", [])) + "\n"
	content += "[b]Integrity Score:[/b] %.2f" % case.get("integrity_score", 0.0)
	return content

func _format_facts(facts: Array) -> String:
	var out = ""
	for f in facts:
		out += "- %s (%s): %s\n" % [f.get("category", ""), f.get("source", ""), f.get("value", "")]
	return out.strip_edges()

func _display_info_buttons():
	if not info_list_container:
		return
	
	# Clear existing buttons
	for child in info_list_container.get_children():
		child.queue_free()

	# Create buttons for each info
	for info in stored_infos:
		var btn = Button.new()
		btn.text = info.get("title", "Untitled Info")
		btn.custom_minimum_size = Vector2(0, 30)
		btn.connect("pressed", Callable(self, "_on_info_selected").bind(info))
		info_list_container.add_child(btn)

func _on_info_selected(info: Dictionary):
	selected_info = info
	if selected_title_label:
		selected_title_label.text = info.get("title", "Untitled Info")
	if selected_content_label:
		selected_content_label.text = info.get("content", "No content available.")

func _on_add_pressed():
	if selected_info.is_empty():
		return
	
	print("Added to AI Analysis:", selected_info.get("title", ""))
	if ai_analysis_ref and ai_analysis_ref.has_method("load_article"):
		var case_data = selected_info.get("case_data", {})
		if not case_data.is_empty():
			ai_analysis_ref.load_article(case_data)
		else:
			push_warning("No case data in selected info")

func _on_trash_pressed():
	if selected_info.is_empty():
		# If no selection, show trash popup to view trashed articles
		_show_trash_popup()
		return
	
	print("Moved to Trash:", selected_info.get("title", ""))
	
	# Move to trash
	trashed_infos.append(selected_info.duplicate())
	stored_infos.erase(selected_info)
	
	# Save both lists
	_save_updated_infos()
	_save_trashed_infos()
	_display_info_buttons()
	
	# Clear selection
	selected_info = {}
	if selected_title_label:
		selected_title_label.text = "No selection"
	if selected_content_label:
		selected_content_label.text = "Select an item from the list to view details."

var trash_popup_scene := preload("res://Prefabs/Components/TrashPopup.tscn")

func _find_and_hide_trash_popup() -> void:
	var scene_root = get_tree().current_scene
	if not scene_root:
		push_warning("[TRASH DEBUG] No current scene to search for TrashPopup")
		return

	# Try to find an existing popup (if placed manually)
	trash_popup = scene_root.find_child("TrashPopup", true, false)

	if trash_popup:
		trash_popup.visible = false
		trash_popup.hide()
		trash_popup.process_mode = Node.PROCESS_MODE_ALWAYS

		# Connect signals safely
		if not trash_popup.restore_requested.is_connected(_on_restore_article_from_popup):
			trash_popup.restore_requested.connect(_on_restore_article_from_popup)
		if not trash_popup.closed.is_connected(_on_trash_popup_closed):
			trash_popup.closed.connect(_on_trash_popup_closed)

		print("[TRASH DEBUG] Found existing TrashPopup, hidden and connected.")
	else:
		print("[TRASH DEBUG] No existing TrashPopup found (will create one when needed).")



func _show_trash_popup():
	print("[TRASH DEBUG] Showing trash popup. Trashed items: %d" % trashed_infos.size())

	if not trash_popup or not is_instance_valid(trash_popup):
		print("[TRASH DEBUG] Creating new TrashPopup instance...")
		trash_popup = trash_popup_scene.instantiate()

		var scene_root = get_tree().current_scene
		var ui_layer = scene_root.find_child("UI", true, false)
		if ui_layer:
			ui_layer.add_child(trash_popup)
		else:
			scene_root.add_child(trash_popup)
			trash_popup.z_index = 999  # Make sure it's visually on top or sum crap

		# Ensure popup has top-level rendering
		trash_popup.top_level = true
		trash_popup.z_as_relative = false
		trash_popup.z_index = 100

		# signals
		if not trash_popup.restore_requested.is_connected(_on_restore_article_from_popup):
			trash_popup.restore_requested.connect(_on_restore_article_from_popup)
		if not trash_popup.closed.is_connected(_on_trash_popup_closed):
			trash_popup.closed.connect(_on_trash_popup_closed)

		print("[TRASH DEBUG] Instantiated and added TrashPopup to scene.")

	# Setup and show
	if trash_popup.has_method("setup"):
		trash_popup.setup(trashed_infos)

	trash_popup.show()
	trash_popup.visible = true
	trash_popup.move_to_front()
	print("[TRASH DEBUG] TrashPopup shown successfully and brought to front.")



func _on_trash_popup_closed():
	"""Handle trash popup being closed"""
	print("[TRASH DEBUG] Trash popup closed")
	if trash_popup:
		trash_popup.visible = false
		trash_popup.hide()



func _on_restore_article_from_popup(info: Dictionary):
	print("[TRASH DEBUG] Restoring article: %s" % info.get("title", "Unknown"))
	trashed_infos.erase(info)
	stored_infos.append(info)
	_save_updated_infos()
	_save_trashed_infos()
	_display_info_buttons()
	print("[TRASH DEBUG] Article restored. Trashed: %d, Stored: %d" % [trashed_infos.size(), stored_infos.size()])
	
	# Refresh the popup if it's still open
	if trash_popup and is_instance_valid(trash_popup):
		if trash_popup.has_method("setup"):
			trash_popup.setup(trashed_infos)


func _load_trashed_infos():
	"""Load trashed articles from JSON"""
	var file_path = "user://trashed_infos.json"
	if not FileAccess.file_exists(file_path):
		trashed_infos = []
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		trashed_infos = []
		return
	
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if typeof(data) == TYPE_ARRAY:
		trashed_infos = data
		print("Evidence Bank: Loaded %d trashed articles" % trashed_infos.size())
	else:
		trashed_infos = []

func _save_trashed_infos():
	"""Save trashed articles to JSON"""
	var file = FileAccess.open("user://trashed_infos.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(trashed_infos, "\t"))
		file.close()
		print("Evidence Bank: Saved %d trashed articles" % trashed_infos.size())

func _on_refresh_pressed():
	_load_collected_infos()
	_display_info_buttons()
	print("Evidence Bank refreshed")

func _save_updated_infos():
	# Save to a separate file if needed
	var file = FileAccess.open("user://collected_infos.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(stored_infos, "\t"))
		file.close()

func _add_info_directly(info: Dictionary):
	"""Add info directly to evidence bank (used by emails) and save to dataset.json"""
	if info.is_empty():
		push_warning("Cannot add empty info to evidence bank")
		return
	
	# Add to stored_infos
	stored_infos.append(info)
	
	# Save to dataset.json if case_data exists
	var case_data = info.get("case_data", {})
	if not case_data.is_empty():
		_save_to_dataset_json(case_data)
	
	# Also save to user file
	_save_updated_infos()
	_display_info_buttons()
	print("Evidence Bank: Added info directly - %s" % info.get("title", "Untitled"))

func _save_to_dataset_json(case_data: Dictionary):
	"""Append case data to dataset.json"""
	var file_path = "res://dataset.json"
	
	# Read existing dataset
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Could not open dataset.json for reading")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(json_text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid dataset.json format")
		return
	
	# Ensure cases array exists
	if not data.has("cases"):
		data["cases"] = []
	
	# Check if case already exists (by article_text)
	var article_text = case_data.get("article_text", "")
	var exists = false
	for case in data["cases"]:
		if case.get("article_text", "") == article_text:
			exists = true
			break
	
	# Add new case if it doesn't exist
	if not exists:
		data["cases"].append(case_data)
		print("Evidence Bank: Added case to dataset.json - %s" % article_text)
		
		# Write back to file
		# Note: In Godot, we can't directly write to res:// at runtime
		# So we'll save to user://dataset_additions.json and note it
		var user_file = FileAccess.open("user://dataset_additions.json", FileAccess.WRITE)
		if user_file:
			# Store all additions in user file
			var additions = []
			if FileAccess.file_exists("user://dataset_additions.json"):
				var existing_file = FileAccess.open("user://dataset_additions.json", FileAccess.READ)
				if existing_file:
					var existing_data = JSON.parse_string(existing_file.get_as_text())
					existing_file.close()
					if typeof(existing_data) == TYPE_ARRAY:
						additions = existing_data
			
			additions.append(case_data)
			user_file.store_string(JSON.stringify(additions, "\t"))
			user_file.close()
			print("Evidence Bank: Saved addition to user://dataset_additions.json")
	else:
		print("Evidence Bank: Case already exists in dataset.json, skipping")
