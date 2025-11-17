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
var laptop_ref: Node = null  # Reference to laptop for app switching
var trash_controller_ref: Node = null  # Reference to trash controller



func _ready():
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
	
	# Load collected infos (this also loads trashed items to filter them out)
	_load_collected_infos()
	_display_info_buttons()
	
	# Start hidden
	visible = false

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_load_collected_infos()
		_display_info_buttons()

func set_ai_analysis_ref(ref: Node):
	ai_analysis_ref = ref

func set_game_manager(manager: Node):
	game_manager = manager

func set_laptop_ref(laptop: Node):
	"""Set reference to laptop for app switching"""
	laptop_ref = laptop

func _load_collected_infos():
	# First, load trashed items to know what to exclude
	_load_trashed_infos()
	
	# Create a set of trashed article texts for quick lookup
	var trashed_article_texts = {}
	for trashed in trashed_infos:
		var case_data = trashed.get("case_data", {})
		if not case_data.is_empty():
			var article_text = case_data.get("article_text", "")
			if article_text != "":
				trashed_article_texts[article_text] = true
	
	# Always try to load from saved collected_infos first (preserves runtime additions)
	var saved_infos_path = "user://collected_infos.json"
	var loaded_from_saved = false
	
	if FileAccess.file_exists(saved_infos_path):
		var saved_file = FileAccess.open(saved_infos_path, FileAccess.READ)
		if saved_file:
			var file_text = saved_file.get_as_text()
			saved_file.close()
			
			if file_text.strip_edges().length() > 0:
				var saved_data = JSON.parse_string(file_text)
				if saved_data != null and typeof(saved_data) == TYPE_ARRAY:
					# Filter out trashed items
					stored_infos = []
					for info in saved_data:
						var case_data = info.get("case_data", {})
						var article_text = case_data.get("article_text", "")
						if article_text != "" and not trashed_article_texts.has(article_text):
							stored_infos.append(info)
					loaded_from_saved = true
					print("Evidence Bank: Loaded %d cases from saved file (after filtering trashed)" % stored_infos.size())
	
	# If not loaded from saved file, load from dataset.json
	if not loaded_from_saved:
		var file_path = "res://dataset.json"
		if not FileAccess.file_exists(file_path):
			push_warning("Collected infos not found at %s" % file_path)
			stored_infos = []
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
			stored_infos = []
			return
		
		# Also load additions from user file (emails added during runtime)
		var additions_path = "user://dataset_additions.json"
		if FileAccess.file_exists(additions_path):
			var additions_file = FileAccess.open(additions_path, FileAccess.READ)
			if additions_file:
				var file_text = additions_file.get_as_text()
				additions_file.close()
				
				if file_text.strip_edges().length() > 0:
					var additions_data = JSON.parse_string(file_text)
					if additions_data != null and typeof(additions_data) == TYPE_ARRAY:
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
		
		# Convert cases to info format and filter out trashed items
		stored_infos = []
		for case in all_cases:
			var article_text = case.get("article_text", "")
			# Skip if this article is trashed
			if article_text != "" and trashed_article_texts.has(article_text):
				continue
			
			var info = {
				"title": "Case: " + case.get("stance", "Unknown"),
				"content": _format_case_content(case),
				"case_data": case
			}
			stored_infos.append(info)
		print("Evidence Bank: Total %d cases loaded (after filtering trashed)" % stored_infos.size())

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
	
	# Switch to AI Analysis app first
	if laptop_ref and laptop_ref.has_method("set_app") and laptop_ref.has_method("set_text"):
		laptop_ref.set_text("AI Analysis")
		laptop_ref.set_app("ai_analysis")
		print("Evidence Bank: Switched to AI Analysis app")
	
	# Then load the article
	if ai_analysis_ref and ai_analysis_ref.has_method("load_article"):
		var case_data = selected_info.get("case_data", {})
		if not case_data.is_empty():
			# Use call_deferred to ensure app switch completes first
			call_deferred("_load_article_to_analysis", case_data)
		else:
			push_warning("No case data in selected info")
	else:
		push_warning("AI Analysis controller not available")

func _load_article_to_analysis(case_data: Dictionary):
	"""Load article to AI Analysis (called deferred after app switch)"""
	if ai_analysis_ref and ai_analysis_ref.has_method("load_article"):
		ai_analysis_ref.load_article(case_data)
		print("Evidence Bank: Article loaded into AI Analysis")

func _on_trash_pressed():
	if selected_info.is_empty():
		# If no selection, open trash app
		if laptop_ref and laptop_ref.has_method("set_app") and laptop_ref.has_method("set_text"):
			laptop_ref.set_text("Trash")
			laptop_ref.set_app("trash")
		return
	
	# Move to trash
	var info_copy = selected_info.duplicate(true)  # Deep copy
	trashed_infos.append(info_copy)
	print("Evidence Bank: Added to trash - Title: %s, Total trashed: %d" % [info_copy.get("title", "Unknown"), trashed_infos.size()])
	
	# Remove from stored_infos by finding matching entry
	var removed = false
	for i in range(stored_infos.size() - 1, -1, -1):
		var stored = stored_infos[i]
		if stored.get("title", "") == selected_info.get("title", "") and \
		   stored.get("content", "") == selected_info.get("content", ""):
			stored_infos.remove_at(i)
			removed = true
			print("Evidence Bank: Removed from stored_infos")
			break
	
	if not removed:
		print("Evidence Bank: WARNING - Could not find matching entry in stored_infos to remove")
	
	# Save both lists
	_save_updated_infos()
	_save_trashed_infos()
	_display_info_buttons()
	
	# Notify trash controller to refresh if it exists
	if trash_controller_ref:
		print("Evidence Bank: Notifying trash controller to refresh...")
		if trash_controller_ref.has_method("_load_trashed_infos"):
			trash_controller_ref._load_trashed_infos()
		if trash_controller_ref.has_method("_refresh_list"):
			trash_controller_ref._refresh_list()
	else:
		print("Evidence Bank: WARNING - trash_controller_ref is null!")
	
	# Clear selection
	selected_info = {}
	if selected_title_label:
		selected_title_label.text = "No selection"
	if selected_content_label:
		selected_content_label.text = "Select an item from the list to view details."

func set_trash_controller_ref(ref: Node):
	trash_controller_ref = ref
	print("Evidence Bank: trash_controller_ref set to: %s" % (ref.name if ref else "null"))

func restore_from_trash(info: Dictionary):
	# Remove from trashed_infos by finding matching entry
	var removed = false
	for i in range(trashed_infos.size() - 1, -1, -1):
		var trashed = trashed_infos[i]
		if trashed.get("title", "") == info.get("title", "") and \
		   trashed.get("content", "") == info.get("content", ""):
			trashed_infos.remove_at(i)
			removed = true
			break
	
	if removed:
		stored_infos.append(info)
		_save_updated_infos()
		_save_trashed_infos()
		_display_info_buttons()
		print("Evidence Bank: Restored item from trash - %s" % info.get("title", "Unknown"))
	
	# Notify trash controller to refresh
	if trash_controller_ref and trash_controller_ref.has_method("_load_trashed_infos"):
		trash_controller_ref._load_trashed_infos()
		if trash_controller_ref.has_method("_refresh_list"):
			trash_controller_ref._refresh_list()

func restore_all_from_trash():
	for info in trashed_infos.duplicate():
		restore_from_trash(info)


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
		var json_string = JSON.stringify(trashed_infos, "\t")
		file.store_string(json_string)
		file.close()
		print("Evidence Bank: Saved %d trashed articles to trashed_infos.json" % trashed_infos.size())
	else:
		push_error("Evidence Bank: Could not open trashed_infos.json for writing")

func _on_refresh_pressed():
	_load_collected_infos()
	_display_info_buttons()
	print("Evidence Bank refreshed")


func reset_evidence_bank():
	"""Reset evidence bank data for new game"""
	# Clear in-memory data
	stored_infos.clear()
	trashed_infos.clear()
	selected_info = {}
	
	# Clear selection display
	if selected_title_label:
		selected_title_label.text = "No selection"
	if selected_content_label:
		selected_content_label.text = "Select an item from the list to view details."
	
	# Reload from dataset.json (which will be fresh since JSON files were cleared by GameManager)
	_load_collected_infos()
	_display_info_buttons()
	
	print("Evidence Bank: Reset for new game")

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
		
		# First, read existing additions (if file exists)
		var additions = []
		var additions_path = "user://dataset_additions.json"
		if FileAccess.file_exists(additions_path):
			var existing_file = FileAccess.open(additions_path, FileAccess.READ)
			if existing_file:
				var file_text = existing_file.get_as_text()
				existing_file.close()
				
				# Only parse if file has content
				if file_text.strip_edges().length() > 0:
					var existing_data = JSON.parse_string(file_text)
					if existing_data != null and typeof(existing_data) == TYPE_ARRAY:
						additions = existing_data
					else:
						push_warning("Evidence Bank: Could not parse existing additions file, starting fresh")
		
		# Add new case to additions
		additions.append(case_data)
		
		# Write updated additions back to file
		var user_file = FileAccess.open(additions_path, FileAccess.WRITE)
		if user_file:
			user_file.store_string(JSON.stringify(additions, "\t"))
			user_file.close()
			print("Evidence Bank: Saved addition to user://dataset_additions.json")
		else:
			push_error("Evidence Bank: Could not open user://dataset_additions.json for writing")
	else:
		print("Evidence Bank: Case already exists in dataset.json, skipping")
