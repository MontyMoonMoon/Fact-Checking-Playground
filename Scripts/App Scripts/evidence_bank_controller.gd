extends MarginContainer
class_name EvidenceBankController

var master: Master
var sound_manager: SoundManager

@export var laptop: Control

@export_group("Evidence List")
@export var evidence_list_container: VBoxContainer

@export_group("Selected Evidence")
@export var selected_evidence_content: MarginContainer
@export var article: Label
@export var tip: Label
@export var facts_vbox_container: VBoxContainer
@export var integrity_score: Label

# Button references - will be connected via scene signals
var add_button: Button = null
var trash_button: Button = null
var refresh_button: Button = null

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
	master = get_node("/root/Master")
	
	if master == null:
		print("[Evidence_bank_controller._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	if master.sound_manager:
		sound_manager = master.sound_manager
	
	add_button = get_node_or_null("LeftButtons/Add")
	trash_button = get_node_or_null("LeftButtons/Trash")
	refresh_button = get_node_or_null("RightButtons/Refresh")
	
	# Defer loading until after scene initialization to ensure files are cleared first
	call_deferred("_initialize_evidence_bank")
	
	visible = false

func _initialize_evidence_bank() -> void:
	"""Initialize evidence bank - load data after scene is ready"""
	_load_collected_infos()
	_display_info_buttons()
	set_evidence_text()

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_load_collected_infos()
		_display_info_buttons()

func reset_for_new_game() -> void:
	"""Reset evidence bank for new game - clear stored infos and reload"""
	var json_manager = JSONManager.get_instance()
	if json_manager:
		json_manager.clear_collected_infos()
		print("[Evidence Bank] Cleared collected infos via JSONManager")
	else:
		# Fallback: clear file directly
		var file = FileAccess.open("user://collected_infos.json", FileAccess.WRITE)
		if file:
			file.store_string("[]")
			file.close()
			print("[Evidence Bank] Cleared collected infos (fallback)")
	
	stored_infos.clear()
	trashed_infos.clear()
	selected_info.clear()
	selected_button = null
	info_to_button.clear()
	
	# Clear UI
	if evidence_list_container:
		for child in evidence_list_container.get_children():
			child.queue_free()
	
	# Reload collected infos (will be empty now)
	_load_collected_infos()
	_display_info_buttons()
	set_evidence_text()
	
	print("[Evidence Bank] Reset for new game - all stored infos cleared")

func set_ai_analysis_ref(ref: Node):
	ai_analysis_ref = ref

# ---------- METHODS ----------
# ---------- UI HELPER METHODS ----------
func _setup_transparent_label(label: Label, text: String, prefix: String = "") -> void:
	"""Helper to setup transparent label with tahoma font"""
	if not label:
		return
	
	var display_text = text
	if prefix and display_text.begins_with(prefix + ": "):
		display_text = display_text.substr(prefix.length() + 2)
	label.text = display_text
	
	var tahoma_font = preload("res://Assets/Fonts/windows-xp-tahoma.otf")
	label.add_theme_font_override("font", tahoma_font)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var parent_hbox = label.get_parent()
	if parent_hbox and parent_hbox is HBoxContainer:
		parent_hbox.remove_theme_stylebox_override("panel")
		parent_hbox.remove_theme_stylebox_override("normal")
		parent_hbox.remove_theme_stylebox_override("focus")
		parent_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		parent_hbox.modulate = Color(1, 1, 1, 1)
		parent_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _clear_facts_container() -> void:
	"""Helper to clear facts container while preserving label"""
	if facts_vbox_container:
		for child in facts_vbox_container.get_children():
			if child.name != "Label":
				child.queue_free()

func _create_fact_label(fact: Dictionary) -> Label:
	"""Helper to create fact label"""
	var fact_label = Label.new()
	fact_label.text = "%s (%s): %s" % [fact.get("category", ""), fact.get("source", ""), fact.get("value", "")]
	fact_label.add_theme_color_override("font_color", Color.BLACK)
	return fact_label

func set_evidence_text() -> void:
	"""Update the selected evidence display using FRONTUI structure"""
	if selected_info.is_empty():
		if article:
			article.text = ""
		if tip:
			tip.text = ""
		if integrity_score:
			integrity_score.text = ""
		_clear_facts_container()
		return
	
	var case_data = selected_info.get("case_data", {})
	
	if article:
		_setup_transparent_label(article, case_data.get("article_text", ""), "Article")
	if tip:
		_setup_transparent_label(tip, case_data.get("tip_text", ""), "Tip")
	
	if integrity_score:
		integrity_score.text = "%.2f" % case_data.get("integrity_score", 0.0)
	
	_clear_facts_container()
	var facts = case_data.get("facts", [])
	for fact in facts:
		facts_vbox_container.add_child(_create_fact_label(fact))

func spawn_categories() -> void:
	"""Spawn buttons based on the amount of categories - already handled in _display_info_buttons"""
	_display_info_buttons()

func spawn_facts() -> void:
	"""Spawn labels based on the amount of facts - already handled in set_evidence_text"""
	set_evidence_text()

func set_game_manager(manager: Node):
	game_manager = manager

func set_laptop_ref(laptop: Node):
	"""Set reference to laptop for app switching"""
	laptop_ref = laptop

# ---------- DATA HELPER METHODS ----------
func _get_trashed_article_texts() -> Dictionary:
	"""Helper to create lookup dictionary of trashed article texts"""
	var trashed_article_texts = {}
	for trashed in trashed_infos:
		var case_data = trashed.get("case_data", {})
		if not case_data.is_empty():
			var article_text = case_data.get("article_text", "")
			if article_text != "":
				trashed_article_texts[article_text] = true
	return trashed_article_texts

func _filter_trashed_infos(infos: Array, trashed_lookup: Dictionary) -> Array:
	"""Helper to filter out trashed items from info array"""
	var filtered = []
	for info in infos:
		var case_data = info.get("case_data", {})
		var article_text = case_data.get("article_text", "")
		if article_text != "" and not trashed_lookup.has(article_text):
			filtered.append(info)
	return filtered

func _convert_cases_to_infos(cases: Array) -> Array:
	"""Helper to convert case dictionaries to info format"""
	var infos = []
	for case in cases:
		infos.append({
			"title": "Case: " + case.get("stance", "Unknown"),
			"content": _format_case_content(case),
			"case_data": case
		})
	return infos

func _load_collected_infos():
	var json_manager = JSONManager.get_instance()
	if not json_manager:
		_load_collected_infos_fallback()
		return
	
	_load_trashed_infos()
	var trashed_lookup = _get_trashed_article_texts()
	
	var saved_data = json_manager.load_collected_infos()
	if saved_data.size() > 0:
		stored_infos = _filter_trashed_infos(saved_data, trashed_lookup)
		print("Evidence Bank: Loaded %d cases from saved file (after filtering trashed)" % stored_infos.size())
		return
	
	var all_cases = json_manager.get_all_cases(true)
	stored_infos = _convert_cases_to_infos(all_cases)
	stored_infos = _filter_trashed_infos(stored_infos, trashed_lookup)
	print("Evidence Bank: Total %d cases loaded (after filtering trashed)" % stored_infos.size())

func _load_collected_infos_fallback():
	"""Fallback method using static JSONManager methods"""
	_load_trashed_infos()
	var trashed_lookup = _get_trashed_article_texts()
	
	var saved_data = JSONManager.load_json("user://collected_infos.json", [])
	if saved_data.size() > 0:
		stored_infos = _filter_trashed_infos(saved_data, trashed_lookup)
		print("Evidence Bank: Loaded %d cases from saved file (fallback)" % stored_infos.size())
		return
	
	var dataset = JSONManager.load_json("res://JSONs/dataset.json", {})
	var all_cases = []
	if typeof(dataset) == TYPE_DICTIONARY and dataset.has("cases"):
		all_cases = dataset["cases"].duplicate()
	elif typeof(dataset) == TYPE_ARRAY:
		all_cases = dataset
	
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
	
	var all_infos = _convert_cases_to_infos(all_cases)
	stored_infos = _filter_trashed_infos(all_infos, trashed_lookup)
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
	if not evidence_list_container:
		return
	
	# Ensure evidence_list_container expands properly to allow scrolling
	evidence_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence_list_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Clear existing category buttons and mappings
	for child in evidence_list_container.get_children():
		if child is Button:
			child.queue_free()
	info_to_button.clear()
	selected_button = null

	# Group infos by category/stance
	var categories = {}
	for info in stored_infos:
		var case_data = info.get("case_data", {})
		var category = case_data.get("stance", "Unknown")
		if not categories.has(category):
			categories[category] = []
		categories[category].append(info)

	# Create category buttons
	var category_index = 0
	for category_name in categories.keys():
		var btn = Button.new()
		btn.text = category_name.to_upper()
		btn.custom_minimum_size = Vector2(0, 30)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.connect("pressed", Callable(self, "_on_category_selected").bind(category_name, categories[category_name]))
		evidence_list_container.add_child(btn)
		
		# Store first info from this category for button mapping
		if categories[category_name].size() > 0:
			info_to_button[categories[category_name][0]] = btn
		
		category_index += 1
		# Remove limit to allow scrolling through all categories
		# if category_index >= 3:  # Limit to 3 categories as per UI design
		# 	break

func _on_category_selected(category_name: String, infos: Array):
	"""Handle category button press - select first info from category"""
	if infos.size() > 0:
		_on_info_selected(infos[0], info_to_button.get(infos[0], null))

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
	
	# Update display using FRONTUI structure
	set_evidence_text()

# ---------- SELECTION HELPER METHODS ----------
func _remove_info_by_article_text(article_text: String) -> bool:
	"""Helper to remove info from stored_infos by article_text"""
	if article_text == "":
		return false
	
	for i in range(stored_infos.size() - 1, -1, -1):
		var stored = stored_infos[i]
		var stored_case_data = stored.get("case_data", {})
		var stored_article_text = stored_case_data.get("article_text", "")
		if stored_article_text == article_text:
			stored_infos.remove_at(i)
			return true
	return false

func _clear_selection() -> void:
	"""Helper to clear current selection and highlight"""
	if selected_button:
		selected_button.modulate = Color.WHITE
	selected_button = null
	selected_info = {}
	set_evidence_text()

func _on_add_pressed() -> void:
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
	if selected_info.is_empty():
		return
	
	var case_data = selected_info.get("case_data", {})
	if case_data.is_empty():
		push_warning("No case data in selected info")
		return
	
	if not ai_analysis_ref or not ai_analysis_ref.has_method("add_article_to_pool"):
		push_warning("AI Analysis controller not available or missing add_article_to_pool method")
		return
	
	ai_analysis_ref.add_article_to_pool(case_data)
	var article_text = case_data.get("article_text", "")
	
	if _remove_info_by_article_text(article_text):
		_save_updated_infos()
		_display_info_buttons()
		_clear_selection()
		print("Evidence Bank: Article added to AI Analysis and removed from evidence bank")

func _on_trash_pressed() -> void:
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
	if selected_info.is_empty():
		if laptop_ref and laptop_ref.has_method("set_app") and laptop_ref.has_method("set_text"):
			laptop_ref.set_text("Trash")
			laptop_ref.set_app("trash")
		return
	
	var info_copy = selected_info.duplicate(true)
	trashed_infos.append(info_copy)
	var case_data = selected_info.get("case_data", {})
	var article_text = case_data.get("article_text", "")
	
	if not _remove_info_by_article_text(article_text):
		print("Evidence Bank: WARNING - Could not find matching entry in stored_infos to remove")
	
	_save_updated_infos()
	_save_trashed_infos()
	
	var json_manager = JSONManager.get_instance()
	if json_manager:
		if json_manager.has_method("refresh_caches"):
			json_manager.refresh_caches()
		json_manager.load_trashed_infos(true)
	
	_display_info_buttons()
	
	if trash_controller_ref:
		call_deferred("_notify_trash_refresh")
	else:
		print("Evidence Bank: WARNING - trash_controller_ref is null!")
	
	_clear_selection()

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

func _remove_from_trashed_by_article_text(article_text: String) -> bool:
	"""Helper to remove info from trashed_infos by article_text"""
	if article_text == "":
		return false
	
	for i in range(trashed_infos.size() - 1, -1, -1):
		var trashed = trashed_infos[i]
		var trashed_case_data = trashed.get("case_data", {})
		var trashed_article_text = trashed_case_data.get("article_text", "")
		if trashed_article_text == article_text:
			trashed_infos.remove_at(i)
			return true
	return false

func restore_from_trash(info: Dictionary):
	var case_data = info.get("case_data", {})
	var article_text = case_data.get("article_text", "")
	
	if _remove_from_trashed_by_article_text(article_text):
		stored_infos.append(info)
		_save_updated_infos()
		_save_trashed_infos()
		_display_info_buttons()
		print("Evidence Bank: Restored item from trash - %s" % info.get("title", "Unknown"))
	
	if trash_controller_ref:
		if trash_controller_ref.has_method("_load_trashed_infos"):
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

func _on_refresh_pressed() -> void:
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
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
	set_evidence_text()
	
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
