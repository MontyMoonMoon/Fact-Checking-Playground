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
var selected_button: Button = null  # Track selected button for highlighting
var info_to_button: Dictionary = {}  # Map info to button for highlighting
var ai_analysis_ref: Node = null
var game_manager: Node = null
var laptop_ref: Node = null  # Reference to laptop for app switching
var trash_controller_ref: Node = null  # Reference to trash controller
var article_publisher_ref: Node = null  # Reference to article publisher controller



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
	# Get JSONManager instance
	var json_manager = JSONManager.get_instance()
	if not json_manager:
		# Fallback to static methods
		_load_collected_infos_fallback()
		return
	
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
	var saved_data = json_manager.load_collected_infos()
	var loaded_from_saved = false
	
	if saved_data.size() > 0:
		# Filter out trashed items
		stored_infos = []
		for info in saved_data:
			var case_data = info.get("case_data", {})
			var article_text = case_data.get("article_text", "")
			if article_text != "" and not trashed_article_texts.has(article_text):
				stored_infos.append(info)
		loaded_from_saved = true
		print("Evidence Bank: Loaded %d cases from saved file (after filtering trashed)" % stored_infos.size())
	
	# If not loaded from saved file, load from dataset.json and additions
	if not loaded_from_saved:
		# Use JSONManager to get all cases (dataset + additions, excluding trashed)
		var all_cases = json_manager.get_all_cases(true)
		
		# Convert cases to info format
		stored_infos = []
		for case in all_cases:
			var info = {
				"title": "Case: " + case.get("stance", "Unknown"),
				"content": _format_case_content(case),
				"case_data": case
			}
			stored_infos.append(info)
		print("Evidence Bank: Total %d cases loaded (after filtering trashed)" % stored_infos.size())

func _load_collected_infos_fallback():
	"""Fallback method using static JSONManager methods"""
	_load_trashed_infos()
	
	var trashed_article_texts = {}
	for trashed in trashed_infos:
		var case_data = trashed.get("case_data", {})
		if not case_data.is_empty():
			var article_text = case_data.get("article_text", "")
			if article_text != "":
				trashed_article_texts[article_text] = true
	
	var saved_data = JSONManager.load_json("user://collected_infos.json", [])
	if saved_data.size() > 0:
		stored_infos = []
		for info in saved_data:
			var case_data = info.get("case_data", {})
			var article_text = case_data.get("article_text", "")
			if article_text != "" and not trashed_article_texts.has(article_text):
				stored_infos.append(info)
		print("Evidence Bank: Loaded %d cases from saved file (fallback)" % stored_infos.size())
		return
	
	# Load from dataset
	var dataset = JSONManager.load_json("res://JSONs/dataset.json", {})
	var all_cases = []
	if typeof(dataset) == TYPE_DICTIONARY and dataset.has("cases"):
		all_cases = dataset["cases"].duplicate()
	elif typeof(dataset) == TYPE_ARRAY:
		all_cases = dataset
	
	# Load additions
	var additions = JSONManager.load_json("user://dataset_additions.json", [])
	var existing_texts = {}
	for case in all_cases:
		var article_text = case.get("article_text", "")
		if article_text != "":
			existing_texts[article_text] = true
	
	for addition in additions:
		var article_text = addition.get("article_text", "")
		if article_text != "" and not existing_texts.has(article_text):
			all_cases.append(addition)
			existing_texts[article_text] = true
	
	# Convert and filter
	stored_infos = []
	for case in all_cases:
		var article_text = case.get("article_text", "")
		if article_text != "" and not trashed_article_texts.has(article_text):
			var info = {
				"title": "Case: " + case.get("stance", "Unknown"),
				"content": _format_case_content(case),
				"case_data": case
			}
			stored_infos.append(info)
	print("Evidence Bank: Total %d cases loaded (fallback)" % stored_infos.size())

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
	
	# Clear existing buttons and mappings
	for child in info_list_container.get_children():
		child.queue_free()
	info_to_button.clear()
	selected_button = null

	# Create buttons for each info
	for info in stored_infos:
		var btn = Button.new()
		btn.text = info.get("title", "Untitled Info")
		btn.custom_minimum_size = Vector2(0, 30)
		btn.connect("pressed", Callable(self, "_on_info_selected").bind(info, btn))
		info_list_container.add_child(btn)
		info_to_button[info] = btn

func _on_info_selected(info: Dictionary, button: Button):
	# Clear previous button highlight
	if selected_button:
		selected_button.modulate = Color.WHITE
	
	# Set new selection
	selected_info = info
	selected_button = button
	
	# Highlight selected button
	if selected_button:
		selected_button.modulate = Color(0.5, 0.8, 1.0, 1.0)  # Light blue highlight
	
	if selected_title_label:
		selected_title_label.text = info.get("title", "Untitled Info")
	if selected_content_label:
		selected_content_label.text = info.get("content", "No content available.")

func _on_add_pressed():
	if selected_info.is_empty():
		return
	
	print("Added to AI Analysis:", selected_info.get("title", ""))
	
	# Just add to AI Analysis pool without switching apps
	if ai_analysis_ref and ai_analysis_ref.has_method("add_article_to_pool"):
		var case_data = selected_info.get("case_data", {})
		if not case_data.is_empty():
			ai_analysis_ref.add_article_to_pool(case_data)
			print("Evidence Bank: Article added to AI Analysis pool")
			
			# Remove from evidence bank after adding to analysis
			var selected_case_data = selected_info.get("case_data", {})
			var selected_article_text = selected_case_data.get("article_text", "")
			var removed = false
			
			if selected_article_text != "":
				for i in range(stored_infos.size() - 1, -1, -1):
					var stored = stored_infos[i]
					var stored_case_data = stored.get("case_data", {})
					var stored_article_text = stored_case_data.get("article_text", "")
					
					if stored_article_text == selected_article_text:
						stored_infos.remove_at(i)
						removed = true
						print("Evidence Bank: Removed from stored_infos after adding to analysis")
						break
			
			if removed:
				_save_updated_infos()
				_display_info_buttons()
				
				# Clear selection and button highlight
				if selected_button:
					selected_button.modulate = Color.WHITE
				selected_button = null
				selected_info = {}
				if selected_title_label:
					selected_title_label.text = "No selection"
				if selected_content_label:
					selected_content_label.text = "Select an item from the list to view details."
		else:
			push_warning("No case data in selected info")
	else:
		push_warning("AI Analysis controller not available or missing add_article_to_pool method")

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
	
	# Remove from stored_infos by finding matching entry using article_text from case_data
	var removed = false
	var selected_case_data = selected_info.get("case_data", {})
	var selected_article_text = selected_case_data.get("article_text", "")
	
	if selected_article_text != "":
		for i in range(stored_infos.size() - 1, -1, -1):
			var stored = stored_infos[i]
			var stored_case_data = stored.get("case_data", {})
			var stored_article_text = stored_case_data.get("article_text", "")
			
			if stored_article_text == selected_article_text:
				stored_infos.remove_at(i)
				removed = true
				print("Evidence Bank: Removed from stored_infos by article_text: %s" % selected_article_text)
				break
	else:
		# Fallback to title/content matching if no article_text
		for i in range(stored_infos.size() - 1, -1, -1):
			var stored = stored_infos[i]
			if stored.get("title", "") == selected_info.get("title", "") and \
			   stored.get("content", "") == selected_info.get("content", ""):
				stored_infos.remove_at(i)
				removed = true
				print("Evidence Bank: Removed from stored_infos by title/content")
				break
	
	if not removed:
		print("Evidence Bank: WARNING - Could not find matching entry in stored_infos to remove")
	
	# Save both lists
	_save_updated_infos()
	_save_trashed_infos()
	
	# Refresh JSONManager cache so trash controller gets updated data
	var json_manager = JSONManager.get_instance()
	if json_manager:
		# Force refresh the trashed_infos cache
		if json_manager.has_method("refresh_caches"):
			json_manager.refresh_caches()
		# Also ensure cache is updated by reloading
		json_manager.load_trashed_infos(true)
	
	_display_info_buttons()
	
	# Notify trash controller to refresh if it exists
	if trash_controller_ref:
		print("Evidence Bank: Notifying trash controller to refresh...")
		# Use call_deferred to ensure save completes first
		call_deferred("_notify_trash_refresh")
	else:
		print("Evidence Bank: WARNING - trash_controller_ref is null!")
	
	# Clear selection and button highlight
	if selected_button:
		selected_button.modulate = Color.WHITE
	selected_button = null
	selected_info = {}
	if selected_title_label:
		selected_title_label.text = "No selection"
	if selected_content_label:
		selected_content_label.text = "Select an item from the list to view details."

func _notify_trash_refresh():
	"""Notify trash controller to refresh (called deferred)"""
	if trash_controller_ref:
		if trash_controller_ref.has_method("_load_trashed_infos"):
			trash_controller_ref._load_trashed_infos(true)  # Force reload
		if trash_controller_ref.has_method("_refresh_list"):
			trash_controller_ref._refresh_list()
		print("Evidence Bank: Trash controller notified to refresh")

func set_trash_controller_ref(ref: Node):
	trash_controller_ref = ref
	print("Evidence Bank: trash_controller_ref set to: %s" % (ref.name if ref else "null"))

func set_article_publisher_ref(ref: Node):
	article_publisher_ref = ref
	print("Evidence Bank: article_publisher_ref set to: %s" % (ref.name if ref else "null"))

func restore_from_trash(info: Dictionary):
	# Remove from trashed_infos by finding matching entry using article_text from case_data
	var removed = false
	var info_case_data = info.get("case_data", {})
	var info_article_text = info_case_data.get("article_text", "")
	
	if info_article_text != "":
		for i in range(trashed_infos.size() - 1, -1, -1):
			var trashed = trashed_infos[i]
			var trashed_case_data = trashed.get("case_data", {})
			var trashed_article_text = trashed_case_data.get("article_text", "")
			
			if trashed_article_text == info_article_text:
				trashed_infos.remove_at(i)
				removed = true
				print("Evidence Bank: Restored from trash by article_text: %s" % info_article_text)
				break
	else:
		# Fallback to title/content matching if no article_text
		for i in range(trashed_infos.size() - 1, -1, -1):
			var trashed = trashed_infos[i]
			if trashed.get("title", "") == info.get("title", "") and \
			   trashed.get("content", "") == info.get("content", ""):
				trashed_infos.remove_at(i)
				removed = true
				print("Evidence Bank: Restored from trash by title/content")
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
	var json_manager = JSONManager.get_instance()
	if json_manager:
		trashed_infos = json_manager.load_trashed_infos(true)  # Force reload to get latest data
		print("Evidence Bank: Loaded %d trashed articles" % trashed_infos.size())
	else:
		trashed_infos = JSONManager.load_json("user://trashed_infos.json", [])
		print("Evidence Bank: Loaded %d trashed articles (fallback)" % trashed_infos.size())

func _save_trashed_infos():
	"""Save trashed articles to JSON"""
	var json_manager = JSONManager.get_instance()
	if json_manager:
		if json_manager.save_trashed_infos(trashed_infos):
			print("Evidence Bank: Saved %d trashed articles to trashed_infos.json" % trashed_infos.size())
		else:
			push_error("Evidence Bank: Could not save trashed_infos.json")
	else:
		if JSONManager.save_json("user://trashed_infos.json", trashed_infos):
			print("Evidence Bank: Saved %d trashed articles to trashed_infos.json" % trashed_infos.size())
		else:
			push_error("Evidence Bank: Could not save trashed_infos.json")

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
	var json_manager = JSONManager.get_instance()
	if json_manager:
		json_manager.save_collected_infos(stored_infos)
	else:
		JSONManager.save_json("user://collected_infos.json", stored_infos)

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
	
	# Notify article publisher to refresh
	if article_publisher_ref and article_publisher_ref.has_method("refresh_articles"):
		article_publisher_ref.refresh_articles()
		print("Evidence Bank: Notified article publisher to refresh")
	
	print("Evidence Bank: Added info directly - %s" % info.get("title", "Untitled"))

func _save_to_dataset_json(case_data: Dictionary):
	"""Append case data to dataset_additions.json (can't write to res:// at runtime)"""
	var json_manager = JSONManager.get_instance()
	if json_manager:
		if json_manager.add_to_dataset_additions(case_data):
			print("Evidence Bank: Added case to dataset_additions.json - %s" % case_data.get("article_text", ""))
			
	else:
		# Fallback: manual save
		var additions = JSONManager.load_json("user://dataset_additions.json", [])
		var article_text = case_data.get("article_text", "")
		
		# Check if already exists
		var exists = false
		for addition in additions:
			if addition.get("article_text", "") == article_text:
				exists = true
				break
		
		if not exists:
			additions.append(case_data.duplicate(true))
			JSONManager.save_json("user://dataset_additions.json", additions)
			print("Evidence Bank: Added case to dataset_additions.json - %s" % article_text)
