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
var category_button_group := ButtonGroup.new()
var info_to_button: Dictionary = {}  # Map info to button for highlighting
var ai_analysis_ref: Node = null
var game_manager: Node = null
var laptop_ref: Node = null  # Reference to laptop for app switching
var trash_controller_ref: Node = null  # Reference to trash controller
var article_publisher_ref: Node = null  # Reference to article publisher controller

# ---------- PREFAB ----------
@onready var category_button_prefab: PackedScene = preload("res://Prefabs/Components/evidence_category.tscn")

func _ready():
	master = get_node("/root/Master")
	
	if master == null:
		push_warning("[Evidence_bank_controller._ready] Master is still null. Calling members from this object may cause issues.")
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
	"""Initialize evidence bank - start empty, will be populated by reset_for_new_game"""
	# Don't load data here - start empty on new game
	# Data will be loaded after reset_for_new_game or when app becomes visible
	stored_infos.clear()
	_display_info_buttons()
	set_evidence_text()

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		# Force fresh reload when becoming visible
		var json_manager = JSONManager.get_instance()
		if json_manager:
			json_manager.collected_infos_cache.clear()
		
		# Check if file is actually empty before loading
		var file_check = JSONManager.load_json("user://collected_infos.json", [])
		if typeof(file_check) == TYPE_ARRAY and file_check.size() == 0:
			# File is empty - don't load, just clear
			stored_infos.clear()
			if evidence_list_container:
				_display_info_buttons()
			set_evidence_text()
			return
		
		_load_collected_infos()
		# Only display if container is ready
		if evidence_list_container:
			_display_info_buttons()
		else:
			push_warning("[Evidence Bank] evidence_list_container is null when becoming visible!")

func reset_for_new_game() -> void:
	"""Reset evidence bank for new game - clear stored infos and reload"""
	var json_manager = JSONManager.get_instance()
	if json_manager:
		json_manager.clear_collected_infos()
		# Force clear cache
		json_manager.collected_infos_cache.clear()
	else:
		var file = FileAccess.open("user://collected_infos.json", FileAccess.WRITE)
		if file:
			file.store_string("[]")
			file.close()
	
	stored_infos.clear()
	trashed_infos.clear()
	selected_info.clear()
	selected_button = null
	info_to_button.clear()
	
	# Clear UI
	if evidence_list_container:
		for child in evidence_list_container.get_children():
			child.queue_free()
	
	# Reload collected infos (will be empty now) - force fresh read
	_load_collected_infos()
	_display_info_buttons()
	set_evidence_text()
	

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
	"""Helper to create fact label with tahoma font"""
	var fact_label = Label.new()
	fact_label.text = "%s (%s): %s" % [fact.get("category", ""), fact.get("source", ""), fact.get("value", "")]
	
	# Apply tahoma font
	var tahoma_font = preload("res://Assets/Fonts/windows-xp-tahoma.otf")
	fact_label.add_theme_font_override("font", tahoma_font)
	fact_label.add_theme_font_size_override("font_size", 32)
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
		# Apply tahoma font to integrity score
		var tahoma_font = preload("res://Assets/Fonts/windows-xp-tahoma.otf")
		integrity_score.add_theme_font_override("font", tahoma_font)
		integrity_score.add_theme_font_size_override("font_size", 32)
	
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

func _find_vbox_containers(node: Node, results: Array):
	"""Recursively find all VBoxContainer nodes"""
	if node is VBoxContainer:
		results.append(node)
	for child in node.get_children():
		_find_vbox_containers(child, results)

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
	
	# Always check collected_infos.json first (where emails save articles)
	# Force fresh reload by clearing cache and reading directly from file
	json_manager.collected_infos_cache.clear()
	# Read directly from file to bypass any stale cache
	var saved_data = JSONManager.load_json("user://collected_infos.json", [])
	if typeof(saved_data) != TYPE_ARRAY:
		saved_data = []
	
	# Update cache with fresh data
	json_manager.collected_infos_cache = saved_data.duplicate(true)
	
	# Use saved data if available (even if empty array - that's fine for new game)
	stored_infos = _filter_trashed_infos(saved_data, trashed_lookup)
	
	
	# Don't fall back to base dataset - on new game, collected_infos.json is empty and that's correct

func _load_collected_infos_fallback():
	"""Fallback method using static JSONManager methods"""
	_load_trashed_infos()
	var trashed_lookup = _get_trashed_article_texts()
	
	var saved_data = JSONManager.load_json("user://collected_infos.json", [])
	# Use saved data if available (even if empty array - that's fine for new game)
	# Don't fall back to base dataset - on new game, collected_infos.json is empty and that's correct
	if saved_data.size() > 0:
		stored_infos = _filter_trashed_infos(saved_data, trashed_lookup)
	else:
		# Empty on new game - that's correct, don't load from base dataset
		stored_infos = []

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
	# Try to find container if not assigned - search more thoroughly
	if not evidence_list_container:
		# Try the actual path from the scene structure
		evidence_list_container = get_node_or_null("ScrollContainer/TextsContainer/Texts/Evidence List/TextsContainer/Contents")
		# Try finding by name "Contents" 
		if not evidence_list_container:
			evidence_list_container = find_child("Contents", true, false)
		# Try finding any VBoxContainer that might be the list
		if not evidence_list_container:
			var vbox_containers = []
			_find_vbox_containers(self, vbox_containers)
			# Look for the one named "Contents" first
			for vbox in vbox_containers:
				if vbox.name == "Contents":
					evidence_list_container = vbox
					break
			# If still not found, use the first VBoxContainer
			if not evidence_list_container and vbox_containers.size() > 0:
				evidence_list_container = vbox_containers[0]
	
	if not evidence_list_container:
		push_warning("[Evidence Bank] evidence_list_container is null! Cannot display buttons.")
		push_warning("[Evidence Bank] Please assign evidence_list_container @export variable in the scene inspector!")
		return
	
	# Ensure evidence_list_container expands properly to allow scrolling and align to left
	evidence_list_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	evidence_list_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Clear existing category groups and mappings
	for child in evidence_list_container.get_children():
		child.queue_free()
	info_to_button.clear()
	selected_button = null

	# Group infos by category/stance
	var categories = {}
	for info in stored_infos:
		if info.is_empty():
			continue
		var case_data = info.get("case_data", {})
		if case_data.is_empty():
			# Try to use info directly if it has article_text
			if info.has("article_text"):
				case_data = info
			else:
				continue
		var category = case_data.get("stance", "Unknown")
		if category == "" or category == null:
			category = "Unknown"
		if not categories.has(category):
			categories[category] = []
		categories[category].append(info)
	

	# Load tahoma font
	var tahoma_font = preload("res://Assets/Fonts/windows-xp-tahoma.otf")

	# Create category buttons with evidence items grouped under them
	var category_index = 0
	for category_name in categories.keys():
		# Get first article text for preview
		var preview_text = ""
		if categories[category_name].size() > 0:
			var first_info = categories[category_name][0]
			var first_case_data = first_info.get("case_data", {})
			var article_text = first_case_data.get("article_text", "")
			if article_text.length() > 0:
				# Get preview (first 40 characters)
				preview_text = article_text.substr(0, min(40, article_text.length()))
				if article_text.length() > 40:
					preview_text += "..."
		
		# Create category button using email_layout (showing category name + preview)
		var email_layout_prefab = preload("res://Prefabs/Components/email_layout.tscn")
		var category_display_text = category_name.to_upper()
		if preview_text != "":
			category_display_text += " - " + preview_text
		
		# Create email_layout instance for category with wider size
		var category_email_layout = email_layout_prefab.instantiate()
		# Make it wider for evidence bank - extend to fill more space
		category_email_layout.custom_minimum_size = Vector2(800, 40)
		# Update internal components to match wider size
		var content_node = category_email_layout.get_node_or_null("Content")
		if content_node:
			content_node.offset_left = -400.0
			content_node.offset_right = 400.0
		var nine_patch = category_email_layout.get_node_or_null("Content/NinePatchRect")
		if nine_patch:
			nine_patch.custom_minimum_size = Vector2(800, 40)
		if category_email_layout and category_email_layout.has_method("_set_text"):
			category_email_layout._set_text(category_display_text)
		elif category_email_layout:
			# Fallback: try to set text via display_text export
			var display_text_node = category_email_layout.get_node_or_null("Content/TextContent/VBoxContainer/Label")
			if display_text_node and display_text_node is Label:
				display_text_node.text = category_display_text
				# Update label width to match wider layout
				display_text_node.custom_minimum_size = Vector2(770, 0)
		
		if category_button_prefab == null:
			push_warning("Category button prefab not assigned!")
			return

		# Instantiate the prefab container
		var category_btn_container = category_button_prefab.instantiate() as MarginContainer
		if category_btn_container == null:
			push_warning("Failed to instantiate category button prefab!")
			return

		# Get the Button inside the container
		var category_btn = category_btn_container.get_node("Category") as Button
		if category_btn == null:
			push_warning("Prefab does not have a Button named 'Button'!")
			return
		
		# Reuse the existing variable instead of redeclaring
		category_display_text = category_name.to_upper()
		if preview_text != "":
			category_display_text += " - " + preview_text

		category_btn.text = category_display_text
		category_btn.toggle_mode = true
		category_btn.button_group = category_button_group

		# Connect the pressed signal
		category_btn.connect("pressed", Callable(self, "_on_category_selected").bind(category_name, categories[category_name]))

		# Add the entire container to the evidence list
		evidence_list_container.add_child(category_btn_container)

		# Map all infos in this category to the category button
		for info in categories[category_name]:
			info_to_button[info] = category_btn

		category_index += 1

func _on_category_selected(category_name: String, infos: Array):
	"""Handle category button press - select first info from category"""
	master.sound_manager.play_sound("mouse_click")
	if infos.size() > 0:
		_on_info_selected(infos[0], info_to_button.get(infos[0], null))

func _on_info_selected(info: Dictionary, button: Button):
	selected_info = info
	selected_button = button

	# Highlight the toggled button text
	for btn in category_button_group.get_buttons():
		var color = Color(0.353, 0.549, 0.353) if btn.pressed else Color(0, 0, 0)

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
	
	# Add to AI Analysis pool
	if ai_analysis_ref and ai_analysis_ref.has_method("add_article_to_pool"):
		ai_analysis_ref.add_article_to_pool(case_data)
	else:
		push_warning("AI Analysis controller not available or missing add_article_to_pool method")
	
	if article_publisher_ref and article_publisher_ref.has_method("add_article_to_pool"):
		article_publisher_ref.add_article_to_pool(case_data)
	else:
		push_warning("Article Publisher controller not available or missing add_article_to_pool method")
	
	var article_text = case_data.get("article_text", "")
	
	if _remove_info_by_article_text(article_text):
		_save_updated_infos()
		_display_info_buttons()
		_clear_selection()

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
	
	_remove_info_by_article_text(article_text)
	
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
	
	_clear_selection()

func _notify_trash_refresh():
	"""Notify trash controller to refresh (called deferred)"""
	if trash_controller_ref:
		if trash_controller_ref.has_method("_load_trashed_infos"):
			trash_controller_ref._load_trashed_infos(true)  # Force reload
		if trash_controller_ref.has_method("_refresh_list"):
			trash_controller_ref._refresh_list()

func set_trash_controller_ref(ref: Node):
	trash_controller_ref = ref

func set_article_publisher_ref(ref: Node):
	article_publisher_ref = ref

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
	else:
		trashed_infos = JSONManager.load_json("user://trashed_infos.json", [])

func _save_trashed_infos():
	"""Save trashed articles to JSON"""
	var json_manager = JSONManager.get_instance()
	if json_manager:
		if not json_manager.save_trashed_infos(trashed_infos):
			push_error("Evidence Bank: Could not save trashed_infos.json")
	else:
		if not JSONManager.save_json("user://trashed_infos.json", trashed_infos):
			push_error("Evidence Bank: Could not save trashed_infos.json")

func _on_refresh_pressed() -> void:
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
	_load_collected_infos()
	_display_info_buttons()


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
	

func _save_updated_infos():
	# Save to a separate file if needed
	var json_manager = JSONManager.get_instance()
	if json_manager:
		json_manager.save_collected_infos(stored_infos)
	else:
		JSONManager.save_json("user://collected_infos.json", stored_infos)

func _add_info_directly(info: Dictionary, add_to_dataset: bool = false):
	"""Add info directly to evidence bank (used by emails)
	
	Args:
		info: The info dictionary to add
		add_to_dataset: If true, also adds to dataset_additions.json (for article publisher).
		               If false (default), only adds to evidence bank. Player must click Add button to add to AI analysis/Publisher.
	"""
	if info.is_empty():
		return
	
	# Add to stored_infos immediately (don't wait for reload)
	stored_infos.append(info)
	
	# Only save to dataset_additions.json if explicitly requested
	# When called from emails, this should be false so articles stay in evidence bank only
	if add_to_dataset:
		var case_data = info.get("case_data", {})
		if not case_data.is_empty():
			_save_to_dataset_json(case_data)
	
	# Save to collected_infos.json and update cache immediately
	var json_manager = JSONManager.get_instance()
	if json_manager:
		# Update cache immediately with new data
		json_manager.collected_infos_cache = stored_infos.duplicate(true)
		var save_result = json_manager.save_collected_infos(stored_infos)
		if not save_result:
			push_warning("[Evidence Bank] Failed to save collected_infos.json")
		else:
			# Verify the save by reading it back
			json_manager.collected_infos_cache.clear()
			json_manager.load_collected_infos()
	else:
		var save_result = JSONManager.save_json("user://collected_infos.json", stored_infos)
		if not save_result:
			push_warning("[Evidence Bank] Failed to save collected_infos.json")
	
	# Refresh display immediately (don't reload from file - we already have the data)
	# Only refresh display if container is ready (might not be if called before _ready completes)
	if evidence_list_container:
		_display_info_buttons()
	
	# Notify article publisher to refresh
	if article_publisher_ref and article_publisher_ref.has_method("refresh_articles"):
		article_publisher_ref.refresh_articles()

func _save_to_dataset_json(case_data: Dictionary):
	"""Append case data to dataset_additions.json (can't write to res:// at runtime)"""
	# Tag with current map so AI analysis can filter properly
	var current_map = _get_current_map()
	var tagged_case_data = case_data.duplicate(true)
	tagged_case_data["map"] = current_map
	
	var json_manager = JSONManager.get_instance()
	if json_manager:
		json_manager.add_to_dataset_additions(tagged_case_data)
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
			additions.append(tagged_case_data)
			JSONManager.save_json("user://dataset_additions.json", additions)

# Helper: Get current map
func _get_current_map() -> String:
	# Try to get from DataManager first
	if DataManager.current_map in ["map_01", "map_02", "map_03"]:
		return DataManager.current_map
	
	# Fallback: detect from scene path
	var scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	if scene_path:
		var scene_name = scene_path.get_file().get_basename()
		if scene_name in ["map_01", "map_02", "map_03"]:
			return scene_name
	
	# Default to map_01
	return "map_01"
