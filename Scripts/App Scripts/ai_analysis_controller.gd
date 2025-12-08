extends MarginContainer
class_name AIAnalysisController

var master: Master
var sound_manager: SoundManager
var game_manager: Node = null

@export var laptop: Control

@export_group("Article Section")
@export var article_content: Label
@export var article_facts_container: VBoxContainer
@export var article_date: Button
@export var article_context: Button

@export_group("Tips Section")
@export var tips_content: Label
@export var tips_facts_container: VBoxContainer
@export var tips_date: Button
@export var tips_context: Button

@export_group("Results")
@export var stance: Label
@export var integrity: Label
@export var result_note: Label
@export var article_classification: Label
@export var tip_classification: Label
@export var keyword_overlap: Label

# HTTP Request - we'll create it dynamically if not in scene
var http_request: HTTPRequest = null

# Data
var comparisons_data: Array = []
var current_index: int = 0
var selected_article_fact_id: String = ""
var selected_tip_fact_id: String = ""
var article_fact_buttons: Dictionary = {}
var tip_fact_buttons: Dictionary = {}
var article_facts_list: Array = []
var tip_facts_list: Array = []
var fact_id_to_fact_data: Dictionary = {}
var current_article_data: Dictionary = {}
var current_article_nlp_data: Dictionary = {}
var current_tip_nlp_data: Dictionary = {}
var article_integrity_awarded: Dictionary = {}
var discrepancy_rewards_given: Dictionary = {}  # Track which articles have been rewarded for discrepancies
var article_classifications: Dictionary = {}  # Store classifications per article key
var current_article_key: String = ""
var pending_article_key: String = ""
var _is_displaying_article: bool = false  # Prevent concurrent article displays

# Panel references for highlighting (from scene structure)
var article_panel: Panel = null
var tip_panel: Panel = null

@onready var facts_button_prefab = preload("res://Prefabs/Components/facts_button.tscn")

# ---------- HELPER METHODS ----------
func _nlp_result_to_dict(result: NLPAnalyzer.AnalysisResult) -> Dictionary:
	"""Convert AnalysisResult to dictionary to avoid RefCounted storage issues"""
	var entities_data = []
	for entity in result.entities:
		entities_data.append({
			"text": entity.text,
			"type": entity.type,
			"start_pos": entity.start_pos,
			"end_pos": entity.end_pos
		})
	return {
		"entities": entities_data,
		"classification": result.classification,
		"classification_confidence": result.classification_confidence,
		"fake_news_keywords": result.fake_news_keywords,
		"fake_news_score": result.fake_news_score,
		"semantic_keywords": result.semantic_keywords,
		"invalid_dates": result.invalid_dates,
		"date_validation_score": result.date_validation_score
	}

func _get_fact_id_from_dict(fact_data: Dictionary) -> String:
	"""Generate a unique ID for a fact from dictionary data"""
	return "%s|%s|%s" % [fact_data.get("category", ""), fact_data.get("value", ""), fact_data.get("source", "")]

func _generate_article_key(entry: Dictionary) -> String:
	var article_text = entry.get("article_text", "")
	if article_text == "" and article_content:
		article_text = article_content.text
	return article_text.strip_edges().to_lower()

func _has_article_been_scored(article_key: String) -> bool:
	if article_key == "":
		return false
	return article_integrity_awarded.get(article_key, false)

func _mark_article_as_scored(article_key: String) -> void:
	if article_key == "":
		return
	article_integrity_awarded[article_key] = true

# ---------- INITIALIZATION ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[AI_analysis_controller._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	if master.sound_manager:
		sound_manager = master.sound_manager
	
	_setup_http_request()
	_setup_panel_references()
	
	# Defer loading until after scene initialization
	call_deferred("_initialize_ai_analysis")
	
	visible = false

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		# Clear cache before reloading to ensure fresh data
		var json_manager = JSONManager.get_instance()
		if json_manager:
			json_manager.dataset_additions_cache.clear()
		
		# Check if file is actually empty before loading
		var file_check = JSONManager.load_json("user://dataset_additions.json", [])
		if typeof(file_check) == TYPE_ARRAY and file_check.size() == 0:
			# File is empty - don't load, just clear display
			comparisons_data.clear()
			current_index = 0
			if article_content:
				article_content.text = ""
			if tips_content:
				tips_content.text = ""
			print("[AI Analysis] File is empty, staying empty")
			return
		
		# Reload dataset when becoming visible to show newly added articles
		_load_dataset()
		# If we have articles, display the first one
		if comparisons_data.size() > 0:
			current_index = 0
			_display_article(comparisons_data[0])
		else:
			# Clear display if no articles
			if article_content:
				article_content.text = ""
			if tips_content:
				tips_content.text = ""

func _initialize_ai_analysis() -> void:
	"""Initialize AI analysis - start empty, will be populated by reset_for_new_game"""
	# Start with empty dataset - will be populated by reset_for_new_game or when articles are added
	# Don't load here - wait for reset_for_new_game
	comparisons_data.clear()
	current_index = 0
	# Clear cache to ensure fresh start
	var json_manager = JSONManager.get_instance()
	if json_manager:
		json_manager.dataset_additions_cache.clear()
	print("[AI Analysis Controller] Initialized - starting empty")

func _setup_http_request():
	"""Setup HTTPRequest node for ML API calls"""
	http_request = get_node_or_null("HTTPRequest")
	if not http_request:
		# Create HTTPRequest as child
		http_request = HTTPRequest.new()
		http_request.name = "HTTPRequest"
		add_child(http_request)
		print("[AI Analysis] Created HTTPRequest node")
	
	if http_request:
		http_request.request_completed.connect(_on_http_request_request_completed)

func _setup_panel(panel: Panel) -> void:
	"""Helper to setup panel with border style"""
	if not panel:
		return
	panel.add_theme_stylebox_override("panel", _get_border_style())
	panel.clip_contents = false
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var name_container = panel.get_node_or_null("Name")
	if name_container:
		name_container.clip_contents = false
		name_container.z_index = 1

func _setup_panel_references():
	"""Find article and tip panels for highlighting"""
	if has_node("ScrollContainer/TextsContainer/Article-Tips/Article"):
		article_panel = get_node("ScrollContainer/TextsContainer/Article-Tips/Article")
		_setup_panel(article_panel)
	if has_node("ScrollContainer/TextsContainer/Article-Tips/Tips"):
		tip_panel = get_node("ScrollContainer/TextsContainer/Article-Tips/Tips")
		_setup_panel(tip_panel)
	print("[AI Analysis] Found panels - Article: %s, Tip: %s" % [article_panel != null, tip_panel != null])

# ---------- DATA LOADING ----------
func _load_dataset():
	"""Load articles from dataset_additions.json only (player-added articles)"""
	# Get current map to filter articles
	var current_map = _get_current_map()
	
	# Only load articles from dataset_additions.json (player-added articles)
	# Don't load from base dataset - on new game, start empty
	var json_manager = JSONManager.get_instance()
	var all_cases = []
	
	# Load from dataset_additions.json (player-added articles only)
	# Force fresh load by clearing cache first
	if json_manager:
		json_manager.dataset_additions_cache.clear()
		# Read directly from file to bypass cache
		var file_data = JSONManager.load_json("user://dataset_additions.json", [])
		if typeof(file_data) == TYPE_ARRAY:
			all_cases = file_data.duplicate(true)
			# Update cache with what we read
			json_manager.dataset_additions_cache = file_data.duplicate(true)
			print("[AI Analysis] _load_dataset: Read %d cases directly from file" % file_data.size())
		else:
			all_cases = []
			json_manager.dataset_additions_cache = []
			print("[AI Analysis] _load_dataset: File is empty or invalid")
	else:
		# Fallback: manual loading - force fresh read
		var additions = JSONManager.load_json("user://dataset_additions.json", [])
		if typeof(additions) == TYPE_ARRAY:
			all_cases = additions.duplicate(true)
			print("[AI Analysis] _load_dataset: Read %d cases (fallback)" % additions.size())
		else:
			all_cases = []
			print("[AI Analysis] _load_dataset: File is empty (fallback)")
	
	# Filter by current map - only show articles from current map
	var filtered_cases = _filter_cases_by_map(all_cases, current_map)
	
	# Preserve any articles that were manually added but not yet in dataset_additions
	var existing_texts = {}
	for case in filtered_cases:
		var article_text = case.get("article_text", "")
		if article_text != "":
			existing_texts[article_text] = true
	
	# Add any articles from comparisons_data that aren't in the filtered list
	for case in comparisons_data:
		var article_text = case.get("article_text", "")
		if article_text != "" and not existing_texts.has(article_text):
			# Check if it matches current map
			var case_map = case.get("map", "")
			if case_map == current_map or case_map == "":
				filtered_cases.append(case)
				existing_texts[article_text] = true
	
	comparisons_data = filtered_cases
	print("AI Analysis: Loaded %d cases for %s (from dataset_additions + manual adds)" % [comparisons_data.size(), current_map])

# NEW: Filter cases by current map
func _filter_cases_by_map(all_cases: Array, current_map: String) -> Array:
	var filtered = []
	
	for case in all_cases:
		# Check if case has map information
		var email_data = case.get("email_data", {})
		var case_map = case.get("map", "")
		
		# Detect map from article content if no explicit map tag
		var detected_map = case_map
		if detected_map == "":
			detected_map = _detect_map_from_content(case)
		
		# If case has explicit map field (added via add_article_to_pool), check it
		if case_map != "":
			if case_map == current_map:
				filtered.append(case)
			continue
		
		# If detected map doesn't match current map, exclude it
		if detected_map != "" and detected_map != current_map:
			continue  # Skip articles from other maps
		
		# For email-based cases (has email_data):
		# Only include if they were explicitly added from evidence bank
		# We check this by seeing if they have a "map" field or if they're in current map's email pool
		if not email_data.is_empty():
			# Email case - only include if it has map tag (was explicitly added)
			# OR if detected map matches current map (from email pool)
			if case_map == current_map or (detected_map == current_map and case_map == ""):
				filtered.append(case)
			# If no map tag and detected map doesn't match, skip - player hasn't added it to AI analysis yet
			continue
		
		# Base dataset articles (no email_data, no map tag) - only include if they don't have map-specific content
		# OR if detected map matches current map
		if email_data.is_empty() and case_map == "":
			if detected_map == "" or detected_map == current_map:
				filtered.append(case)
	
	return filtered

# NEW: Detect map from article content characteristics
func _detect_map_from_content(case: Dictionary) -> String:
	var article_text = case.get("article_text", "")
	var news_data = case.get("news_data", {})
	if article_text == "":
		article_text = news_data.get("article_text", "")
	
	if article_text == "":
		return ""  # Can't detect without content
	
	var lower_text = article_text.to_lower()
	
	# Map_03: Articles with [REDACTED] markers
	if article_text.contains("[REDACTED]") or lower_text.contains("redacted"):
		return "map_03"
	
	# Map_02: Articles with censorship hints (but not redactions)
	# Check for censorship-related keywords
	var censorship_keywords = ["censored", "restricted access", "approval required", "information ministry", "leaked senate files", "forged documents"]
	for keyword in censorship_keywords:
		if lower_text.contains(keyword):
			return "map_02"
	
	# Check sender for map-specific indicators
	var sender = case.get("sender", "")
	if sender == "":
		sender = news_data.get("sender", "")
	
	var lower_sender = sender.to_lower()
	
	# Map_03: Sovereign Council, high propaganda
	if lower_sender.contains("sovereign council") or lower_sender.contains("syndinet"):
		# Check if it's high propaganda (map_03) vs just censorship (map_02)
		if article_text.contains("[REDACTED]") or lower_text.contains("redacted"):
			return "map_03"
		# SyndiNet in map_02 is also possible, but if no redactions, it's likely map_02
		if lower_sender.contains("syndinet") and not article_text.contains("[REDACTED]"):
			return "map_02"
	
	# Map_02: Information Ministry, leaked files
	if lower_sender.contains("information ministry") or lower_sender.contains("senate"):
		return "map_02"
	
	# No map-specific characteristics detected - neutral/base article
	return ""

# NEW: Get current map (same as emails_controller)
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

func set_game_manager(manager: Node):
	game_manager = manager

# ---------- ARTICLE MANAGEMENT ----------
func load_article(article_data: Dictionary):
	current_article_data = article_data
	visible = true
	
	# Reload dataset to include any new additions (from emails)
	# _load_dataset() now preserves manually added articles
	_load_dataset()
	
	# Find matching case in dataset or use provided data
	var case_data = article_data
	if comparisons_data.size() > 0:
		for case in comparisons_data:
			if case.get("article_text") == article_data.get("article_text"):
				case_data = case
				break
	
	# If article not found in comparisons_data, add it
	if case_data == article_data:
		var current_map = _get_current_map()
		var article_with_map = article_data.duplicate(true)
		article_with_map["map"] = current_map
		comparisons_data.append(article_with_map)
		case_data = article_with_map
	
	# Update current_index to match the loaded article
	for i in range(comparisons_data.size()):
		if comparisons_data[i].get("article_text") == case_data.get("article_text"):
			current_index = i
			break
	
	_display_article(case_data)

func add_article_to_pool(article_data: Dictionary):
	"""Add article to the comparisons pool without switching to the app"""
	# Mark article with current map so it only appears in this map
	var current_map = _get_current_map()
	var article_with_map = article_data.duplicate(true)
	article_with_map["map"] = current_map  # Tag with current map
	
	var article_text = article_data.get("article_text", "")
	var exists = false
	for case in comparisons_data:
		if case.get("article_text", "") == article_text:
			exists = true
			break
	
	if not exists:
		comparisons_data.append(article_with_map)
		
		# Ensure article is saved to dataset_additions.json so it persists
		var json_manager = JSONManager.get_instance()
		if json_manager:
			# Check if already in dataset_additions
			var additions = json_manager.load_dataset_additions()
			var already_saved = false
			for addition in additions:
				if addition.get("article_text", "") == article_text:
					already_saved = true
					break
			
			if not already_saved:
				json_manager.add_to_dataset_additions(article_with_map)
		else:
			# Fallback: manual save
			var additions = JSONManager.load_json("user://dataset_additions.json", [])
			var already_saved = false
			for addition in additions:
				if addition.get("article_text", "") == article_text:
					already_saved = true
					break
			
			if not already_saved:
				additions.append(article_with_map)
				JSONManager.save_json("user://dataset_additions.json", additions)
		
		# If AI Analysis is visible, update the display
		if visible:
			# If this is the first article, display it
			if comparisons_data.size() == 1:
				current_index = 0
				_display_article(comparisons_data[0])
			# Otherwise, if we're viewing an article, stay on current one
			# (user can navigate with prev/next buttons)
		
		print("AI Analysis: Added article to pool for %s - %s (total: %d)" % [current_map, article_text, comparisons_data.size()])
	else:
		print("AI Analysis: Article already in pool - %s" % article_text)

func reset_for_new_game() -> void:
	"""Reset article pool and display for new game"""
	# Clear cache first to ensure fresh load
	var json_manager = JSONManager.get_instance()
	if json_manager:
		json_manager.dataset_additions_cache.clear()
		# Also verify file is empty
		json_manager.clear_dataset_additions()
	
	comparisons_data.clear()
	current_index = 0
	selected_article_fact_id = ""
	selected_tip_fact_id = ""
	article_fact_buttons.clear()
	tip_fact_buttons.clear()
	article_facts_list.clear()
	tip_facts_list.clear()
	fact_id_to_fact_data.clear()
	current_article_data.clear()
	current_article_nlp_data.clear()
	current_tip_nlp_data.clear()
	article_integrity_awarded.clear()
	
	# Clear display
	if article_content:
		article_content.text = ""
	if tips_content:
		tips_content.text = ""
	
	print("[AI Analysis Controller] Reset for new game - article pool cleared and empty")
	discrepancy_rewards_given.clear()
	current_article_key = ""
	pending_article_key = ""
	
	# Clear fact buttons
	if article_facts_container:
		for child in article_facts_container.get_children():
			if (child.name.begins_with("Fact_") and child is Button) or (child.has_method("_on_fact_selected") and not child.name in ["Date", "Context"]):
				child.queue_free()
	
	if tips_facts_container:
		for child in tips_facts_container.get_children():
			if (child.name.begins_with("Fact_") and child is Button) or (child.has_method("_on_fact_selected") and not child.name in ["Date", "Context"]):
				child.queue_free()
	
	# Clear content displays
	if article_content:
		article_content.text = ""
	if tips_content:
		tips_content.text = ""
	
	# Don't reload dataset on new game - start with empty pool
	# Articles will be added as player collects evidence
	print("[AI Analysis Controller] Reset for new game - article pool cleared and empty")

# ---------- DISPLAY METHODS ----------
func _display_article(entry: Dictionary):
	# Prevent concurrent article displays
	if _is_displaying_article:
		print("[AI Analysis] Already displaying article, skipping duplicate call")
		return
	
	_is_displaying_article = true
	
	# Clear previous selections
	selected_article_fact_id = ""
	selected_tip_fact_id = ""
	article_fact_buttons.clear()
	tip_fact_buttons.clear()
	article_facts_list.clear()
	tip_facts_list.clear()
	fact_id_to_fact_data.clear()
	# Don't clear NLP data here - it will be restored from article_classifications if available
	current_article_data = entry
	current_article_key = _generate_article_key(entry)
	
	# Restore NLP data if article was already analyzed
	var article_key = _generate_article_key(entry)
	var stored_classification = article_classifications.get(article_key, {})
	if stored_classification.has("article_nlp"):
		current_article_nlp_data = stored_classification.get("article_nlp", {})
	if stored_classification.has("tip_nlp"):
		current_tip_nlp_data = stored_classification.get("tip_nlp", {})
	
	# Clear old fact buttons (but keep "Facts:" Label, Date, Context buttons, and Control nodes)
	# Clear old fact buttons in article container - remove immediately to prevent duplicates
	if article_facts_container:
		var children_to_remove = []
		for child in article_facts_container.get_children():
			if child.name.begins_with("FactContainer_"):
				children_to_remove.append(child)
		for child in children_to_remove:
			article_facts_container.remove_child(child)
			child.queue_free()
	
	# Clear old fact buttons in tips container - remove immediately to prevent duplicates
	if tips_facts_container:
		var children_to_remove = []
		for child in tips_facts_container.get_children():
			if child.name.begins_with("FactContainer_"):
				children_to_remove.append(child)
		for child in children_to_remove:
			tips_facts_container.remove_child(child)
			child.queue_free()
	
	# Process immediately to ensure old buttons are removed before spawning new ones
	# Use call_deferred instead of await to avoid making function async
	call_deferred("_spawn_facts_after_clear", entry)

func _spawn_facts_after_clear(entry: Dictionary):
	"""Helper function to spawn facts after clearing old buttons"""

	if article_panel:
		_setup_panel(article_panel)
	if tip_panel:
		_setup_panel(tip_panel)
	
	# Update text
	var article_text = entry.get("article_text", "Missing article")
	if article_text.begins_with("Article: "):
		article_text = article_text.substr(9)
	
	var tip_text = entry.get("tip_text", "Missing tip")
	if tip_text.begins_with("Tip: "):
		tip_text = tip_text.substr(5)
	
	# DON'T perform NLP analysis here - only when Analyze button is pressed
	# Clear NLP data when switching articles
	current_article_nlp_data.clear()
	current_tip_nlp_data.clear()
	
	set_content_text(article_content, article_text)
	set_content_text(tips_content, tip_text)

	# Note: article_content and tips_content are Labels, not RichTextLabels, so no BBCode
	_update_button_text(article_date, "Date", entry.get("date", ""))
	_update_button_text(article_context, "Context", entry.get("context", ""))
	_update_button_text(tips_date, "Date", entry.get("tip_date", entry.get("date", "")))
	_update_button_text(tips_context, "Context", entry.get("tip_context", entry.get("context", "")))
	
	# Separate facts by source
	var article_facts: Array = []
	var tip_facts: Array = []
	
	for fact_data in entry.get("facts", []):
		var source = fact_data.get("source", "")
		if source == "Article":
			article_facts.append(fact_data)
		elif source == "Tip":
			tip_facts.append(fact_data)
		else:
			if article_facts.size() <= tip_facts.size():
				article_facts.append(fact_data)
			else:
				tip_facts.append(fact_data)
	
	# Setup layout for both Article and Tips
	spawn_fact_buttons(article_facts, article_facts_container)
	spawn_fact_buttons(tip_facts, tips_facts_container)

	# Update result display (resets values, doesn't analyze)
	_update_result_display(entry)
	
	# Reset flag at end to allow next article display
	_is_displaying_article = false

func _setup_fact_button_style(btn: Button, container: VBoxContainer) -> void:
	# Instantiate the prefab
	var fact_btn_container := facts_button_prefab.instantiate() as MarginContainer
	if not fact_btn_container:
		push_warning("Failed to instantiate facts_button prefab!")
		return

	# Get the Button inside the prefab
	var fact_btn := fact_btn_container.get_node("VBoxContainer/Fact") as Button
	if not fact_btn:
		push_warning("Prefab has no Button node named 'Fact'")
		return
	
	# Add to container
	article_facts_container.add_child(fact_btn_container)

func _insert_fact_button_after_context(btn: Button, container: VBoxContainer) -> void:
	"""Helper to insert fact button after Context button"""
	var context_button = container.get_node_or_null("Context")
	if context_button:
		container.add_child(btn)
		container.move_child(btn, context_button.get_index() + 2)
		return
	
	var control_node = container.get_node_or_null("Control")
	if control_node:
		container.add_child(btn)
		container.move_child(btn, control_node.get_index() + 1)
	else:
		container.add_child(btn)

func spawn_fact_buttons(facts_list: Array, facts_container: VBoxContainer) -> void:
	if not facts_container or facts_list.size() == 0:
		return

	var panel_type: String = "article" if facts_container == article_facts_container else "tip"

	# Double-check: remove any remaining FactContainer_ nodes (safety check)
	var children_to_remove = []
	for child in facts_container.get_children():
		if child.name.begins_with("FactContainer_"):
			children_to_remove.append(child)
	for child in children_to_remove:
		facts_container.remove_child(child)
		child.queue_free()

	for fact_data in facts_list:
		var fact_id = _get_fact_id_from_dict(fact_data)
		
		# Check if this fact button already exists (prevent duplicates)
		var existing_container = facts_container.get_node_or_null("FactContainer_%s" % fact_id)
		if existing_container:
			print("[AI Analysis] Fact button already exists for %s, skipping duplicate" % fact_id)
			continue
		
		fact_id_to_fact_data[fact_id] = fact_data

		# Instantiate the prefab
		var btn_container := facts_button_prefab.instantiate() as MarginContainer
		if not btn_container:
			push_warning("Failed to instantiate facts_button prefab!")
			continue

		# Corrected reference to the Button node
		var btn := btn_container.get_node("VBoxContainer/Fact") as Button
		if not btn:
			push_warning("Prefab has no Button node named 'Fact' inside VBoxContainer")
			btn_container.queue_free()
			continue

		# Set button text
		btn.text = "%s: %s" % [fact_data.get("category", ""), fact_data.get("value", "")]

		# Connect pressed signal with proper panel_type string
		btn.connect("pressed", Callable(self, "_on_fact_selected").bind(fact_id, btn, panel_type))
		
		# Store button reference in the appropriate dictionary
		if panel_type == "article":
			article_fact_buttons[fact_id] = btn
		else:
			tip_fact_buttons[fact_id] = btn
		
		# Give the container a unique name so it can be cleared later
		btn_container.name = "FactContainer_%s" % fact_id
		
		# Add to container
		facts_container.add_child(btn_container)

func _add_fact_button(fact_data: Dictionary, fact_id: String, panel_type: String) -> void:
	var container: VBoxContainer
	if panel_type == "article":
		container = article_facts_container
	else:
		container = tips_facts_container
	
	if not container:
		push_warning("Fact container not found for panel type: %s" % panel_type)
		return
	
	# Instantiate your prefab
	var btn_container := facts_button_prefab.instantiate() as MarginContainer
	if not btn_container:
		push_warning("Failed to instantiate facts_button prefab!")
		return
	
	# Get the Button node inside prefab
	var btn := btn_container.get_node("VBoxContainer/Fact") as Button
	if not btn:
		push_warning("Prefab has no Button node named 'Fact'")
		return
	
	# Set text
	btn.text = "%s: %s" % [fact_data.get("category", ""), fact_data.get("value", "")]
	
	# Connect pressed signal
	btn.connect("pressed", Callable(self, "_on_fact_selected").bind(fact_id, btn, panel_type))
	
	# Add prefab container to the proper VBoxContainer
	container.add_child(btn_container)
	
	# Store reference if needed
	if panel_type == "article":
		article_fact_buttons[fact_id] = btn
	else:
		tip_fact_buttons[fact_id] = btn

func _update_result_display(entry: Dictionary):
	"""Update basic display info without performing analysis"""
	var stance_val = entry.get("stance", "Unknown")
	var integrity_val = str(entry.get("integrity_score", 0.0))
	
	if stance:
		stance.text = stance_val
	if integrity:
		integrity.text = integrity_val
	if result_note:
		result_note.text = "Click one fact from each side to compare them."
		result_note.modulate = Color.WHITE  # Reset color
	
	# Restore classifications if already analyzed, otherwise reset
	var article_key = _generate_article_key(entry)
	var stored_classification = article_classifications.get(article_key, {})
	
	if article_classification:
		if stored_classification.has("article"):
			article_classification.text = stored_classification.get("article", "Unverified (50%)")
		else:
			article_classification.text = "Unverified (50%)"
	
	if tip_classification:
		if stored_classification.has("tip"):
			tip_classification.text = stored_classification.get("tip", "Unverified (50%)")
		else:
			tip_classification.text = "Unverified (50%)"
	
	# Reset keyword overlap - don't calculate until Analyze button is pressed
	if keyword_overlap:
		keyword_overlap.text = "0% - Low similarity"

func set_content_text(content_label: Label, text: String) -> void:
	if not content_label:
		return
	content_label.text = text

func _update_button_text(button: Button, prefix: String, value: String) -> void:
	"""Helper to update button text with prefix"""
	if button:
		button.text = prefix + ": " + str(value) if value else prefix + ":"

func _get_border_style() -> StyleBoxFlat:
	"""Get the border-only stylebox (transparent fill, black border)"""
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.border_width_left = 2
	border_style.border_width_top = 2
	border_style.border_width_right = 2
	border_style.border_width_bottom = 2
	border_style.border_color = Color(0, 0, 0, 1)
	return border_style

func _get_highlight_style() -> StyleBoxFlat:
	"""Helper to get highlight stylebox for selected fact"""
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(1.0, 1.0, 0.0, 0.15)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0, 0, 0, 1)
	return style_box

func _handle_fact_selection(fact_id: String, btn: Button, selected_id_var: String, fact_buttons: Dictionary, panel: Panel) -> String:
	"""Helper to handle fact selection logic"""
	if selected_id_var == fact_id:
		selected_id_var = ""
		btn.remove_theme_color_override("font_color")
		if panel:
			panel.add_theme_stylebox_override("panel", _get_border_style())
	else:
		if selected_id_var != "":
			var prev_btn = fact_buttons.get(selected_id_var, null)
			if prev_btn:
				prev_btn.remove_theme_color_override("font_color")
			if panel:
				panel.add_theme_stylebox_override("panel", _get_border_style())
		selected_id_var = fact_id
		btn.add_theme_color_override("font_color", Color.YELLOW)
		if panel:
			panel.add_theme_stylebox_override("panel", _get_highlight_style())
	return selected_id_var

func _on_fact_selected(fact_id: String, btn: Button, panel_type: String):
	master.sound_manager.play_sound("mouse_click")
	var fact_data = fact_id_to_fact_data.get(fact_id, null)
	if not fact_data:
		return
	
	if panel_type == "article":
		selected_article_fact_id = _handle_fact_selection(fact_id, btn, selected_article_fact_id, article_fact_buttons, article_panel)
	else:
		selected_tip_fact_id = _handle_fact_selection(fact_id, btn, selected_tip_fact_id, tip_fact_buttons, tip_panel)

func compare_facts_from_dict(fact_a_data: Dictionary, fact_b_data: Dictionary) -> Dictionary:
	"""Compare facts using dictionaries - delegates to FactComparator helper"""
	var result = FactComparator.compare_facts(fact_a_data, fact_b_data)
	
	# Check for high semantic overlap bonus (game-specific logic)
	var comparison = NLPAnalyzer.compare_analyses(
		NLPAnalyzer.analyze_text(fact_a_data.get("value", "")),
		NLPAnalyzer.analyze_text(fact_b_data.get("value", "")),
		fact_a_data.get("value", ""),
		fact_b_data.get("value", "")
	)
	var semantic_similarity = comparison.get("semantic_similarity", 0.0)
	comparison.clear()
	
	if semantic_similarity >= 0.90 and semantic_similarity <= 1.0:
		print("[AI ANALYSIS DEBUG] High semantic overlap detected: %.4f" % semantic_similarity)
		if not _has_article_been_scored(current_article_key):
			if game_manager and game_manager.has_method("add_high_overlap_comparison"):
				game_manager.add_high_overlap_comparison()
				_mark_article_as_scored(current_article_key)
				print("[AI ANALYSIS DEBUG] High overlap bonus awarded")
			else:
				push_warning("[AI ANALYSIS DEBUG] Game manager not available for high overlap bonus!")
	
	return result

func _show_result(result: Dictionary):
	if not result_note:
		return
	
	var stance_val = current_article_data.get("stance", "Unknown")
	var integrity_val = str(current_article_data.get("integrity_score", 0.0))
	
	var text = "NLP Analysis Result:\n"
	text += result.reason
	if result.truth_status != "":
		text += "\n\n" + result.truth_status
	
	# Add article-level NLP info
	if not current_article_nlp_data.is_empty() and not current_tip_nlp_data.is_empty():
		text += "\n\nArticle-Level Analysis:"
		text += "\nArticle Classification: %s (%.0f%%)" % [current_article_nlp_data.get("classification", "Unknown"), current_article_nlp_data.get("classification_confidence", 0.0) * 100]
		text += "\nTip Classification: %s (%.0f%%)" % [current_tip_nlp_data.get("classification", "Unknown"), current_tip_nlp_data.get("classification_confidence", 0.0) * 100]
		
		# Check for invalid dates (NLP supplements ML)
		var article_invalid_dates = current_article_nlp_data.get("invalid_dates", [])
		var article_date_score = current_article_nlp_data.get("date_validation_score", 1.0)
		if article_invalid_dates.size() > 0:
			text += "\n🚨 INVALID DATES DETECTED:"
			for invalid_date in article_invalid_dates:
				text += "\n  • '%s' - Date format or value is incorrect" % invalid_date
			text += "\n⚠ This suggests potential misinformation or errors in the article."
		
		var tip_invalid_dates = current_tip_nlp_data.get("invalid_dates", [])
		if tip_invalid_dates.size() > 0:
			text += "\n⚠ Tip contains %d invalid date(s) - verify carefully" % tip_invalid_dates.size()
		
		var article_fake_keywords = current_article_nlp_data.get("fake_news_keywords", [])
		var tip_fake_keywords = current_tip_nlp_data.get("fake_news_keywords", [])
		if article_fake_keywords.size() > 0:
			text += "\n⚠ Article has %d fake news indicators" % article_fake_keywords.size()
		if tip_fake_keywords.size() > 0:
			text += "\n⚠ Tip has %d fake news indicators" % tip_fake_keywords.size()
	
	# Update keyword overlap if available
	if keyword_overlap and result.has("keyword_analysis"):
		var overlap_text = result.keyword_analysis
		keyword_overlap.text = overlap_text.replace("Keyword Overlap: ", "")
	
	result_note.text = text
	
	# Update color based on result
	var color = Color.GREEN
	if result.is_discrepancy:
		color = Color.RED
		# Reward player for detecting discrepancy
		_reward_discrepancy_detection()
	elif result.truth_status.contains("Warning") or result.truth_status.contains("Review"):
		color = Color.YELLOW
	
	result_note.modulate = color

# NEW: Reward player for detecting discrepancies
func _reward_discrepancy_detection() -> void:
	"""Reward player with integrity score for detecting a discrepancy"""
	if not game_manager:
		return
	
	# Check if we've already rewarded for this article's discrepancy
	var article_key = current_article_key
	if article_key == "":
		return
	
	if discrepancy_rewards_given.has(article_key):
		return  # Already rewarded for this article
	
	# Award integrity for detecting discrepancy (small reward, encourages careful analysis)
	var reward_amount = 0.3  # Small reward for detecting discrepancies
	if game_manager.has_method("add_integrity_score"):
		game_manager.add_integrity_score(reward_amount, "correct_ai_analysis")
		print("[AI Analysis] Rewarded %.2f integrity for detecting discrepancy in article: %s" % [reward_amount, article_key])
	
	# Mark as rewarded
	discrepancy_rewards_given[article_key] = true

# ---------- BUTTON HANDLERS ----------
func _on_prev_pressed() -> void:
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
	if comparisons_data.size() > 0:
		current_index = (current_index - 1 + comparisons_data.size()) % comparisons_data.size()
		_display_article(comparisons_data[current_index])

func _on_next_pressed() -> void:
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
	if comparisons_data.size() > 0:
		current_index = (current_index + 1) % comparisons_data.size()
		_display_article(comparisons_data[current_index])

func _on_analyze_pressed() -> void:
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
	# Perform NLP analysis on article and tip NOW
	if article_content and tips_content:
		var article_text = article_content.text
		var tip_text = tips_content.text
		
		# Perform NLP analysis
		var article_nlp_result = NLPAnalyzer.analyze_text(article_text)
		var tip_nlp_result = NLPAnalyzer.analyze_text(tip_text)
		
		if article_nlp_result:
			current_article_nlp_data = _nlp_result_to_dict(article_nlp_result)
			article_nlp_result = null
		if tip_nlp_result:
			current_tip_nlp_data = _nlp_result_to_dict(tip_nlp_result)
			tip_nlp_result = null
		
		# Update classifications with analyzed data
		var article_key = _generate_article_key(current_article_data)
		var classification_data = {}
		
		if not current_article_nlp_data.is_empty() and article_classification:
			var classification = current_article_nlp_data.get("classification", "Unknown")
			var confidence = current_article_nlp_data.get("classification_confidence", 0.0) * 100
			var classification_text = "%s (%.0f%%)" % [classification, confidence]
			article_classification.text = classification_text
			classification_data["article"] = classification_text
			classification_data["article_nlp"] = current_article_nlp_data.duplicate(true)
		
		if not current_tip_nlp_data.is_empty() and tip_classification:
			var classification = current_tip_nlp_data.get("classification", "Unknown")
			var confidence = current_tip_nlp_data.get("classification_confidence", 0.0) * 100
			var classification_text = "%s (%.0f%%)" % [classification, confidence]
			tip_classification.text = classification_text
			classification_data["tip"] = classification_text
			classification_data["tip_nlp"] = current_tip_nlp_data.duplicate(true)
		
		# Store classification for this article (including NLP data for restoration)
		if not classification_data.is_empty():
			article_classifications[article_key] = classification_data
		
		# Calculate and update keyword overlap
		if keyword_overlap and not current_article_nlp_data.is_empty() and not current_tip_nlp_data.is_empty():
			var article_nlp_result_temp = NLPAnalyzer.analyze_text(article_text)
			var tip_nlp_result_temp = NLPAnalyzer.analyze_text(tip_text)
			var comparison = NLPAnalyzer.compare_analyses(article_nlp_result_temp, tip_nlp_result_temp, article_text, tip_text)
			var overlap_percentage = comparison.keyword_overlap * 100
			
			if overlap_percentage > 30.0:
				keyword_overlap.text = "%.0f%% - High similarity" % overlap_percentage
			else:
				keyword_overlap.text = "%.0f%% - Low similarity" % overlap_percentage
			
			article_nlp_result_temp = null
			tip_nlp_result_temp = null
			comparison.clear()
	
	# Compare selected facts if both are selected
	if selected_article_fact_id != "" and selected_tip_fact_id != "":
		var article_fact_data = fact_id_to_fact_data.get(selected_article_fact_id, null)
		var tip_fact_data = fact_id_to_fact_data.get(selected_tip_fact_id, null)
		
		if article_fact_data and tip_fact_data:
			var result = compare_facts_from_dict(article_fact_data, tip_fact_data)
			_show_result(result)
	
	# Send article for ML analysis
	if article_content:
		_send_article_for_analysis(article_content.text)

# ---------- ML API METHODS ----------
func _send_article_for_analysis(article_text: String):
	if not http_request:
		http_request = get_node_or_null("HTTPRequest")
		if not http_request:
			push_error("HTTPRequest node not found!")
			if result_note:
				result_note.text = "HTTPRequest node not found!"
			return
	
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("HTTPRequest is busy, cancelling previous request...")
		http_request.cancel_request()
		await get_tree().process_frame
	
	# Extract features from current article data using helper class
	var nlp_data_for_ml = {
		"article_nlp": current_article_nlp_data,
		"tip_nlp": current_tip_nlp_data,
		"date_validation_score": _get_nlp_date_validation_score()
	}
	var features = MLFeatureExtractor.extract_features(current_article_data, article_text, nlp_data_for_ml)
	
	var json_str = JSON.stringify(features)
	
	pending_article_key = current_article_key
	print("Sending article for ML analysis to http://127.0.0.1:8000/analyze...")
	print("Request body: %s" % json_str)
	
	if result_note:
		result_note.text = "Analyzing article..."
	
	var error = http_request.request(
		"http://127.0.0.1:8000/analyze",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		json_str
	)
	
	if error != OK:
		push_error("Failed to send HTTP request: %d" % error)
		if result_note:
			result_note.text = "HTTP Request Error: %d" % error

# Helper: Get NLP date validation score (used by MLFeatureExtractor)
func _get_nlp_date_validation_score() -> float:
	if not current_article_nlp_data.is_empty():
		return current_article_nlp_data.get("date_validation_score", 1.0)
	return 1.0

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("HTTP Request completed - Result: %d, Response Code: %d" % [result, response_code])
	
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("ML API request failed with result code: %d (Response: %d)" % [result, response_code])
		if result_note:
			result_note.text = "ML API Request Failed: Result %d, Response %d" % [result, response_code]
		return
	
	if response_code != 200:
		var body_text = body.get_string_from_utf8()
		push_error("ML API request failed: %d\nResponse body: %s" % [response_code, body_text])
		if result_note:
			result_note.text = "ML API Error: %d\n%s" % [response_code, body_text]
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if typeof(response) == TYPE_DICTIONARY:
		var rf = response.get("random_forest_score", 0.5)
		var log = response.get("logistic_regression_score", 0.5)
		var avg = response.get("average_score", 0.5)
		var verdict = response.get("result", "Unknown")
		
		# Validate ML results against article data
		var validation = _validate_ml_result(response, current_article_data)
		
		# Build comprehensive feedback
		var feedback_text = "ML Analysis Results:\n"
		feedback_text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
		feedback_text += "Random Forest: %.2f/10.0\n" % rf
		feedback_text += "Logistic Regression: %.2f/10.0\n" % log
		feedback_text += "Average Score: %.2f/10.0\n" % avg
		feedback_text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
		feedback_text += "Verdict: %s\n" % verdict
		feedback_text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
		
		# Add interpretation based on article context
		var interpretation = _interpret_ml_result(avg, verdict, current_article_data)
		feedback_text += "\n%s" % interpretation
		
		# Display ML results
		if result_note:
			result_note.text = feedback_text
		
		print("[AI ANALYSIS DEBUG] ===== ML Analysis Complete =====")
		print("[AI ANALYSIS DEBUG] RF: %.2f, LogReg: %.2f, Avg: %.2f, Verdict: %s" % [rf, log, avg, verdict])
		print("[AI ANALYSIS DEBUG] Validation Accuracy: %.2f%%" % (validation.accuracy * 100))
		
		var article_key = pending_article_key
		var integrity_available = not _has_article_been_scored(article_key)
		
		if integrity_available and game_manager and game_manager.has_method("add_article_result"):
			var rf_normalized = rf / 10.0
			var log_normalized = log / 10.0
			game_manager.add_article_result(rf_normalized, log_normalized)
			_mark_article_as_scored(article_key)
			print("[AI ANALYSIS DEBUG] Results sent to GameManager")
		elif not integrity_available:
			print("[AI ANALYSIS DEBUG] Integrity already awarded for this article - skipping GameManager update")
		else:
			push_warning("[AI ANALYSIS DEBUG] Game manager not available or missing add_article_result method!")
		
		pending_article_key = ""
		print("[AI ANALYSIS DEBUG] ==================================")
	else:
		push_error("Invalid response from ML API")

# NEW: Validate ML results against expected values
func _validate_ml_result(ml_response: Dictionary, article_data: Dictionary) -> Dictionary:
	var news_data = article_data.get("news_data", {})
	var integrity_score = news_data.get("integrity_score", 0.5)
	var actual_score = ml_response.get("average_score", 0.5) / 10.0  # Normalize to 0-1
	
	# Expected score should correlate with integrity_score
	# Low integrity (0.3-0.5) = likely fake (low ML score)
	# High integrity (0.7-0.9) = likely real (high ML score)
	var expected_score = integrity_score
	
	var accuracy = 1.0 - abs(expected_score - actual_score)
	
	return {
		"accuracy": accuracy,
		"expected": expected_score,
		"actual": actual_score
	}

# NEW: Interpret ML results in context of article
func _interpret_ml_result(avg_score: float, verdict: String, article_data: Dictionary) -> String:
	var news_data = article_data.get("news_data", {})
	var stance = news_data.get("stance", "Neutral")
	var sender = article_data.get("sender", "")
	var facts = news_data.get("facts", [])
	
	var interpretation = "Analysis Interpretation:\n"
	
	# Check if verdict aligns with article characteristics
	if avg_score >= 6.5:  # Likely Real
		interpretation += "✓ Article appears credible based on ML analysis.\n"
		if stance in ["Investigative", "Neutral", "Skeptical"]:
			interpretation += "✓ Stance supports credibility.\n"
		elif stance == "Pro-Government":
			interpretation += "⚠ Pro-government stance may indicate bias.\n"
		
		# Check evidence
		var article_facts_count = 0
		for fact in facts:
			if fact.get("source") == "Article":
				article_facts_count += 1
		
		if article_facts_count >= 2:
			interpretation += "✓ Multiple supporting facts found.\n"
		else:
			interpretation += "⚠ Limited evidence in article facts.\n"
	else:  # Likely Fake
		interpretation += "⚠ Article shows signs of being unreliable.\n"
		
		# Check for red flags
		if sender.contains("SyndiNet") or sender.contains("Government"):
			interpretation += "⚠ Source may have agenda.\n"
		
		if stance == "Pro-Government":
			interpretation += "⚠ Pro-government stance suggests potential propaganda.\n"
		
		# Check for contradictions
		var contradiction_facts = 0
		for fact in facts:
			if fact.get("source") == "Tip":
				var category = fact.get("category", "")
				if category in ["Warning", "Contradiction", "Anomaly"]:
					contradiction_facts += 1
		
		if contradiction_facts > 0:
			interpretation += "⚠ Tips reveal contradictions - verify carefully.\n"
		
		# Check for invalid dates from NLP
		var invalid_dates = current_article_nlp_data.get("invalid_dates", [])
		if invalid_dates.size() > 0:
			interpretation += "🚨 INVALID DATES FOUND: Article contains %d invalid date(s).\n" % invalid_dates.size()
			interpretation += "   This is a strong indicator of misinformation or errors.\n"
	
	return interpretation
