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
var current_article_key: String = ""
var pending_article_key: String = ""

# Panel references for highlighting (from scene structure)
var article_panel: Panel = null
var tip_panel: Panel = null

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
		"semantic_keywords": result.semantic_keywords
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

func _initialize_ai_analysis() -> void:
	"""Initialize AI analysis - load dataset after scene is ready"""
	_load_dataset()

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
	# Use JSONManager to get all cases (dataset + additions)
	var json_manager = JSONManager.get_instance()
	if json_manager:
		comparisons_data = json_manager.get_all_cases(false)
		print("AI Analysis: Loaded %d total cases (dataset + additions)" % comparisons_data.size())
	else:
		# Fallback: manual loading
		var dataset = JSONManager.load_json("res://JSONs/dataset.json", {})
		if typeof(dataset) == TYPE_DICTIONARY and dataset.has("cases"):
			comparisons_data = dataset["cases"].duplicate()
		elif typeof(dataset) == TYPE_ARRAY:
			comparisons_data = dataset
		else:
			comparisons_data = []
		
		# Load additions
		var additions = JSONManager.load_json("user://dataset_additions.json", [])
		if typeof(additions) == TYPE_ARRAY:
			var existing_texts = {}
			for case in comparisons_data:
				var article_text = case.get("article_text", "")
				if article_text != "":
					existing_texts[article_text] = true
			
			for addition in additions:
				var article_text = addition.get("article_text", "")
				if article_text != "" and not existing_texts.has(article_text):
					comparisons_data.append(addition)
					existing_texts[article_text] = true
		
		print("AI Analysis: Loaded %d total cases (fallback)" % comparisons_data.size())

func set_game_manager(manager: Node):
	game_manager = manager

# ---------- ARTICLE MANAGEMENT ----------
func load_article(article_data: Dictionary):
	current_article_data = article_data
	visible = true
	
	# Reload dataset to include any new additions (from emails)
	_load_dataset()
	
	# Find matching case in dataset or use provided data
	var case_data = article_data
	if comparisons_data.size() > 0:
		for case in comparisons_data:
			if case.get("article_text") == article_data.get("article_text"):
				case_data = case
				break
	
	# Update current_index to match the loaded article
	for i in range(comparisons_data.size()):
		if comparisons_data[i].get("article_text") == case_data.get("article_text"):
			current_index = i
			break
	
	_display_article(case_data)

func add_article_to_pool(article_data: Dictionary):
	"""Add article to the comparisons pool without switching to the app"""
	_load_dataset()
	
	var article_text = article_data.get("article_text", "")
	var exists = false
	for case in comparisons_data:
		if case.get("article_text", "") == article_text:
			exists = true
			break
	
	if not exists:
		comparisons_data.append(article_data.duplicate(true))
		print("AI Analysis: Added article to pool - %s" % article_text)
	else:
		print("AI Analysis: Article already in pool - %s" % article_text)

func reset_for_new_game() -> void:
	"""Reset article pool and display for new game"""
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
	
	# Reload dataset (this will repopulate comparisons_data with initial dataset)
	_load_dataset()
	
	print("[AI Analysis Controller] Reset for new game - article pool cleared")

# ---------- DISPLAY METHODS ----------
func _display_article(entry: Dictionary):
	# Clear previous selections
	selected_article_fact_id = ""
	selected_tip_fact_id = ""
	article_fact_buttons.clear()
	tip_fact_buttons.clear()
	article_facts_list.clear()
	tip_facts_list.clear()
	fact_id_to_fact_data.clear()
	current_article_nlp_data.clear()
	current_tip_nlp_data.clear()
	current_article_data = entry
	current_article_key = _generate_article_key(entry)
	
	# Clear old fact buttons (but keep "Facts:" Label, Date, Context buttons, and Control nodes)
	if article_facts_container:
		# Keep static scene elements (Label, Date, Context buttons, Control nodes)
		for child in article_facts_container.get_children():
			# Only remove dynamically created fact buttons
			if (child.name.begins_with("Fact_") and child is Button) or (child.has_method("_on_fact_selected") and not child.name in ["Date", "Context"]):
				child.queue_free()
	
	if tips_facts_container:
		# Keep static scene elements (Label, Date, Context buttons, Control nodes)
		for child in tips_facts_container.get_children():
			# Only remove dynamically created fact buttons
			if (child.name.begins_with("Fact_") and child is Button) or (child.has_method("_on_fact_selected") and not child.name in ["Date", "Context"]):
				child.queue_free()
	
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
	
	_setup_content_label(article_content, article_text, article_panel)
	_setup_content_label(tips_content, tip_text, tip_panel)
	
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
	
	# Create fact buttons for article side (add after Context button)
	# Ensure facts container doesn't overlap with content by using proper size flags
	if article_facts_container:
		article_facts_container.clip_contents = true
		article_facts_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		article_facts_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for fact_data in article_facts:
			article_facts_list.append(fact_data)
			var fact_id = _get_fact_id_from_dict(fact_data)
			fact_id_to_fact_data[fact_id] = fact_data
			_add_fact_button(fact_data, fact_id, article_facts_container, "article")
	
	if tips_facts_container:
		tips_facts_container.clip_contents = true
		tips_facts_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tips_facts_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for fact_data in tip_facts:
			tip_facts_list.append(fact_data)
			var fact_id = _get_fact_id_from_dict(fact_data)
			fact_id_to_fact_data[fact_id] = fact_data
			_add_fact_button(fact_data, fact_id, tips_facts_container, "tip")
	
	# Update result display (resets values, doesn't analyze)
	_update_result_display(entry)
	
	# DON'T send article for ML analysis here - only when Analyze button is pressed

func _setup_fact_button_style(btn: Button, container: VBoxContainer) -> void:
	"""Helper to setup fact button styling"""
	var tahoma_font = preload("res://Assets/Fonts/windows-xp-tahoma.otf")
	btn.add_theme_font_override("font", tahoma_font)
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	
	var button_texture = load("res://Assets/PNGs/UI/UI Assets.png")
	if button_texture:
		var normal_style = StyleBoxTexture.new()
		normal_style.texture = button_texture
		normal_style.expand_margin_left = 10.0
		normal_style.expand_margin_right = 10.0
		normal_style.region_rect = Rect2(656, 832, 192, 16)
		btn.add_theme_stylebox_override("normal", normal_style)
		
		var pressed_style = StyleBoxTexture.new()
		pressed_style.texture = button_texture
		pressed_style.expand_margin_left = 10.0
		pressed_style.expand_margin_right = 10.0
		pressed_style.region_rect = Rect2(656, 896, 192, 16)
		btn.add_theme_stylebox_override("pressed", pressed_style)
		btn.add_theme_stylebox_override("hover", pressed_style)
	else:
		var date_button = container.get_node_or_null("Date")
		if date_button and date_button is Button:
			btn.add_theme_stylebox_override("normal", date_button.get_theme_stylebox("normal"))
			btn.add_theme_stylebox_override("pressed", date_button.get_theme_stylebox("pressed"))
			btn.add_theme_stylebox_override("hover", date_button.get_theme_stylebox("hover"))

func _insert_fact_button_after_context(btn: Button, container: VBoxContainer) -> void:
	"""Helper to insert fact button after Context button"""
	var context_button = container.get_node_or_null("Context")
	if context_button:
		container.add_child(btn)
		container.move_child(btn, context_button.get_index() + 1)
		return
	
	var control_node = container.get_node_or_null("Control")
	if control_node:
		container.add_child(btn)
		container.move_child(btn, control_node.get_index() + 1)
	else:
		container.add_child(btn)

func _add_fact_button(fact_data: Dictionary, fact_id: String, container: VBoxContainer, panel_type: String):
	if not container:
		return
	
	var btn = Button.new()
	btn.name = "Fact_" + fact_id.replace("|", "_")
	btn.text = "%s: %s" % [fact_data.get("category", ""), fact_data.get("value", "")]
	btn.custom_minimum_size = Vector2(0, 40)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_contents = true
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	_setup_fact_button_style(btn, container)
	btn.connect("pressed", Callable(self, "_on_fact_selected").bind(fact_id, btn, panel_type))
	_insert_fact_button_after_context(btn, container)
	
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
	
	# Reset classifications - don't analyze until Analyze button is pressed
	if article_classification:
		article_classification.text = "Unverified (50%)"
	if tip_classification:
		tip_classification.text = "Unverified (50%)"
	
	# Reset keyword overlap - don't calculate until Analyze button is pressed
	if keyword_overlap:
		keyword_overlap.text = "0% - Low similarity"

func _setup_content_label(content_label: Label, text: String, panel: Panel) -> void:
	"""Helper to setup content label with transparent styling"""
	if not content_label:
		return
	
	content_label.text = text
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_label.clip_contents = true
	
	var empty_style = StyleBoxEmpty.new()
	content_label.add_theme_stylebox_override("normal", empty_style)
	content_label.add_theme_stylebox_override("panel", empty_style)
	
	var parent_vbox = content_label.get_parent()
	if parent_vbox and parent_vbox is VBoxContainer:
		parent_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		parent_vbox.clip_contents = true
	
	var scroll_container = content_label.get_parent()
	while scroll_container and not scroll_container is ScrollContainer:
		scroll_container = scroll_container.get_parent()
	if scroll_container and scroll_container is ScrollContainer:
		scroll_container.add_theme_stylebox_override("panel", empty_style)
		scroll_container.add_theme_stylebox_override("background", empty_style)
		scroll_container.clip_contents = true
	
	if panel:
		panel.add_theme_stylebox_override("panel", _get_border_style())
		panel.clip_contents = false

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
	var fact_data = fact_id_to_fact_data.get(fact_id, null)
	if not fact_data:
		return
	
	if panel_type == "article":
		selected_article_fact_id = _handle_fact_selection(fact_id, btn, selected_article_fact_id, article_fact_buttons, article_panel)
	else:
		selected_tip_fact_id = _handle_fact_selection(fact_id, btn, selected_tip_fact_id, tip_fact_buttons, tip_panel)

func compare_facts_from_dict(fact_a_data: Dictionary, fact_b_data: Dictionary) -> Dictionary:
	"""Compare facts using dictionaries instead of Fact instances"""
	var result = {
		"is_discrepancy": false,
		"reason": "",
		"truth_status": "",
		"entity_analysis": "",
		"classification_analysis": "",
		"keyword_analysis": ""
	}
	
	var value_a = fact_a_data.get("value", "")
	var value_b = fact_b_data.get("value", "")
	
	# Perform NLP analysis
	var nlp_a = NLPAnalyzer.analyze_text(value_a)
	var nlp_b = NLPAnalyzer.analyze_text(value_b)
	
	var classification_a = nlp_a.classification
	var classification_b = nlp_b.classification
	var fake_score_a = nlp_a.fake_news_score
	var fake_score_b = nlp_b.fake_news_score
	
	var comparison = NLPAnalyzer.compare_analyses(nlp_a, nlp_b, value_a, value_b)
	
	nlp_a = null
	nlp_b = null
	
	# Convert entity_matches to dictionaries
	var entity_matches_dict = []
	if comparison.has("entity_matches"):
		for match_item in comparison.entity_matches:
			if typeof(match_item) == TYPE_DICTIONARY:
				entity_matches_dict.append(match_item)
			else:
				entity_matches_dict.append({
					"type": match_item.get("type", "") if match_item.has_method("get") else "",
					"entity_a": match_item.get("entity_a", "") if match_item.has_method("get") else "",
					"entity_b": match_item.get("entity_b", "") if match_item.has_method("get") else "",
					"similarity": match_item.get("similarity", 0.0) if match_item.has_method("get") else 0.0
				})
	
	# Build entity analysis
	var entity_info = []
	if entity_matches_dict.size() > 0:
		entity_info.append("Matching Entities:")
		for match in entity_matches_dict:
			entity_info.append("  • %s (%s): %.0f%% match" % [match.get("type", ""), match.get("entity_a", ""), match.get("similarity", 0.0) * 100])
		result.entity_analysis = "\n".join(entity_info)
	
	# Build classification analysis
	if comparison.classification_match:
		result.classification_analysis = "Classification: Both classified as %s" % classification_a
	else:
		result.classification_analysis = "Classification Mismatch: Article=%s, Tip=%s" % [classification_a, classification_b]
	
	# Build keyword analysis
	if comparison.keyword_overlap > 0.3:
		result.keyword_analysis = "Keyword Overlap: %.0f%% - High semantic similarity" % (comparison.keyword_overlap * 100)
	else:
		result.keyword_analysis = "Keyword Overlap: %.0f%% - Low semantic similarity" % (comparison.keyword_overlap * 100)
	
	# Determine discrepancy
	var overall_score = comparison.overall_match_score
	var semantic_similarity = comparison.semantic_similarity
	
	if overall_score < 0.4:
		result.is_discrepancy = true
		result.reason = "Significant discrepancy detected (Match Score: %.0f%%)" % (overall_score * 100)
		
		if fake_score_a > 0.3 or fake_score_b > 0.3:
			result.truth_status = "⚠ Warning: Fake news patterns detected in one or both facts"
		else:
			result.truth_status = "Facts show significant differences. Verify sources."
			
	elif overall_score >= 0.4 and overall_score < 0.7:
		result.is_discrepancy = false
		result.reason = "Partial match (Match Score: %.0f%%)" % (overall_score * 100)
		result.truth_status = "Facts are similar but not identical. Review details."
		
	else:
		result.is_discrepancy = false
		result.reason = "High match (Match Score: %.0f%%)" % (overall_score * 100)
		result.truth_status = "Facts are consistent and match well."
		
		if semantic_similarity >= 0.90 and semantic_similarity <= 1.0:
			print("[AI ANALYSIS DEBUG] High semantic overlap detected: %.4f" % semantic_similarity)
			if not _has_article_been_scored(current_article_key):
				if game_manager and game_manager.has_method("add_high_overlap_comparison"):
					game_manager.add_high_overlap_comparison()
					_mark_article_as_scored(current_article_key)
					print("[AI ANALYSIS DEBUG] High overlap bonus awarded")
				else:
					push_warning("[AI ANALYSIS DEBUG] Game manager not available for high overlap bonus!")
	
	# Add detailed analysis
	var detailed_analysis = []
	detailed_analysis.append(result.reason)
	if result.entity_analysis != "":
		detailed_analysis.append(result.entity_analysis)
	detailed_analysis.append(result.classification_analysis)
	detailed_analysis.append(result.keyword_analysis)
	
	result.reason = "\n".join(detailed_analysis)
	
	comparison.clear()
	
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
	elif result.truth_status.contains("Warning") or result.truth_status.contains("Review"):
		color = Color.YELLOW
	
	result_note.modulate = color

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
		if not current_article_nlp_data.is_empty() and article_classification:
			var classification = current_article_nlp_data.get("classification", "Unknown")
			var confidence = current_article_nlp_data.get("classification_confidence", 0.0) * 100
			article_classification.text = "%s (%.0f%%)" % [classification, confidence]
		
		if not current_tip_nlp_data.is_empty() and tip_classification:
			var classification = current_tip_nlp_data.get("classification", "Unknown")
			var confidence = current_tip_nlp_data.get("classification_confidence", 0.0) * 100
			tip_classification.text = "%s (%.0f%%)" % [classification, confidence]
		
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
	
	var json_data = { 
		"text": article_text,
		"sentiment_score": 0.0,
		"evidence_count": 2,
		"contradiction_score": 0.5,
		"propaganda_pattern_score": 0.5,
		"source_type": "independent",
		"topic": "politics"
	}
	var json_str = JSON.stringify(json_data)
	
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
		
		# Display ML results
		if result_note:
			var existing_text = result_note.text
			result_note.text = existing_text + "\n\nML Analysis:\n" + \
				"RF: %.2f | LogReg: %.2f | Avg: %.2f\nVerdict: %s" % [rf, log, avg, verdict]
		
		print("[AI ANALYSIS DEBUG] ===== ML Analysis Complete =====")
		print("[AI ANALYSIS DEBUG] RF: %.2f, LogReg: %.2f, Avg: %.2f, Verdict: %s" % [rf, log, avg, verdict])
		
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
