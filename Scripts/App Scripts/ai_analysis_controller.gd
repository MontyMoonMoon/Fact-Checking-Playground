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
	# Clear old fact buttons in article container
	if article_facts_container:
		for child in article_facts_container.get_children():
			if child.name.begins_with("FactContainer_"):
				child.queue_free()
	
	# Clear old fact buttons in tips container
	if tips_facts_container:
		for child in tips_facts_container.get_children():
			if child.name.begins_with("FactContainer_"):
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

	for fact_data in facts_list:
		var fact_id = _get_fact_id_from_dict(fact_data)
		fact_id_to_fact_data[fact_id] = fact_data

		# Instantiate the prefab
		var btn_container := facts_button_prefab.instantiate() as MarginContainer
		if not btn_container:
			push_warning("Failed to instantiate facts_button prefab!")

		# Corrected reference to the Button node
		var btn := btn_container.get_node("VBoxContainer/Fact") as Button
		if not btn:
			push_warning("Prefab has no Button node named 'Fact' inside VBoxContainer")

		# Set button text
		btn.text = "%s: %s" % [fact_data.get("category", ""), fact_data.get("value", "")]

		# Connect pressed signal with proper panel_type string
		btn.connect("pressed", Callable(self, "_on_fact_selected").bind(fact_id, btn, panel_type))

		# Give the container a unique name so it can be cleared later
		btn_container.name = "FactContainer_%s" % fact_id

		# Add to container after the first child
		if facts_container.get_child_count() > 0:
			facts_container.add_child(btn_container)
		else:
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
	
	# Reset classifications - don't analyze until Analyze button is pressed
	if article_classification:
		article_classification.text = "Unverified (50%)"
	if tip_classification:
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
		"keyword_analysis": "",
		"relationship": ""  # NEW: Clear relationship description
	}
	
	var value_a = fact_a_data.get("value", "")
	var value_b = fact_b_data.get("value", "")
	var category_a = fact_a_data.get("category", "")
	var category_b = fact_b_data.get("category", "")
	var source_a = fact_a_data.get("source", "")
	var source_b = fact_b_data.get("source", "")
	
	# Determine relationship type
	var relationship_type = _determine_fact_relationship(category_a, category_b, value_a, value_b, source_a, source_b)
	result.relationship = relationship_type
	
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
		result.reason = "⚠ CONTRADICTION DETECTED (Match: %.0f%%)" % (overall_score * 100)
		
		if fake_score_a > 0.3 or fake_score_b > 0.3:
			result.truth_status = "🚨 WARNING: Fake news patterns detected!\nThese facts contradict each other - one may be false."
		else:
			result.truth_status = "❌ Facts contradict each other.\nThe article and tip provide conflicting information.\nVerify which source is reliable."
			
	elif overall_score >= 0.4 and overall_score < 0.7:
		result.is_discrepancy = false
		result.reason = "⚠ PARTIAL MATCH (Match: %.0f%%)" % (overall_score * 100)
		result.truth_status = "⚠ Facts are similar but not identical.\nReview details carefully - there may be subtle differences."
		
	else:
		result.is_discrepancy = false
		result.reason = "✓ HIGH MATCH (Match: %.0f%%)" % (overall_score * 100)
		result.truth_status = "✓ Facts are consistent!\nThe article and tip support each other.\nThis increases credibility."
		
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
	
	# Add relationship to detailed analysis
	if result.relationship != "":
		detailed_analysis.insert(0, result.relationship)
	
	result.reason = "\n".join(detailed_analysis)
	
	comparison.clear()
	
	return result

# NEW: Determine how facts relate to each other
func _determine_fact_relationship(cat_a: String, cat_b: String, val_a: String, val_b: String, src_a: String, src_b: String) -> String:
	# Same category = direct comparison
	if cat_a == cat_b:
		return "Direct Comparison: Both facts about '%s'" % cat_a
	
	# Related categories
	if (cat_a == "Event" and cat_b == "Timeline") or (cat_b == "Event" and cat_a == "Timeline"):
		return "Related: Event and its Timeline"
	if (cat_a == "Claim" and cat_b == "Evidence") or (cat_b == "Claim" and cat_a == "Evidence"):
		return "Related: Claim vs Evidence"
	if (cat_a == "Statement" and cat_b == "Contradiction") or (cat_b == "Statement" and cat_a == "Contradiction"):
		return "Contradictory: Statement vs Contradiction"
	
	# Tip warnings/contradictions
	if src_b == "Tip" and cat_b in ["Warning", "Contradiction", "Anomaly", "Pressure"]:
		return "Tip Contradicts: Tip reveals issues with article fact"
	if src_a == "Tip" and cat_a in ["Warning", "Contradiction", "Anomaly", "Pressure"]:
		return "Tip Contradicts: Tip reveals issues with article fact"
	
	return "Different Aspects: Facts cover different aspects of the story"

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
	
	# Extract features from current article data
	var features = _extract_ml_features(current_article_data, article_text)
	
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

# NEW FUNCTION: Extract ML features from article data
func _extract_ml_features(article_data: Dictionary, article_text: String) -> Dictionary:
	var news_data = article_data.get("news_data", {})
	var sender = article_data.get("sender", "")
	var tip_text = news_data.get("tip_text", "")
	var facts = news_data.get("facts", [])
	var stance = news_data.get("stance", "Neutral")
	var integrity_score = news_data.get("integrity_score", 0.5)
	
	# 1. Evidence Count - count facts from article (not tips)
	var evidence_count = 0
	for fact in facts:
		if fact.get("source", "") == "Article":
			evidence_count += 1
	# Minimum 1, use facts count if available
	if evidence_count == 0 and facts.size() > 0:
		evidence_count = facts.size()
	if evidence_count == 0:
		evidence_count = 1  # Default minimum
	
	# 2. Sentiment Score - based on stance and NLP analysis
	var sentiment_score = _calculate_sentiment_score(article_text, stance)
	
	# 3. Contradiction Score - compare article vs tip
	var contradiction_score = _calculate_contradiction_score(article_text, tip_text, facts)
	
	# 4. Propaganda Pattern Score - based on stance, sender, and content patterns
	var propaganda_score = _calculate_propaganda_score(article_text, stance, sender, integrity_score)
	
	# 5. Source Type - infer from sender
	var source_type = _infer_source_type(sender, stance)
	
	# 6. Topic - detect from content and sender
	var topic = _detect_topic(article_text, sender)
	
	return {
		"text": article_text,
		"sentiment_score": sentiment_score,
		"evidence_count": evidence_count,
		"contradiction_score": contradiction_score,
		"propaganda_pattern_score": propaganda_score,
		"source_type": source_type,
		"topic": topic
	}

# Helper: Calculate sentiment score (-1.0 to 1.0, normalized to 0.0-1.0)
func _calculate_sentiment_score(text: String, stance: String) -> float:
	var base_score = 0.5  # Neutral
	
	# Adjust based on stance
	match stance:
		"Pro-Government", "Pro-Celebrity":
			base_score = 0.7  # Positive
		"Critical", "Skeptical", "Investigative":
			base_score = 0.3  # Negative
		"Neutral", "Concerned", "Suspicious":
			base_score = 0.5  # Neutral
	
	# Use NLP analyzer if available for text-based sentiment
	if current_article_nlp_data.has("classification"):
		var classification = current_article_nlp_data.get("classification", "Unverified")
		if classification == "True":
			base_score += 0.1
		elif classification == "False":
			base_score -= 0.1
	
	return clamp(base_score, 0.0, 1.0)

# Helper: Calculate contradiction between article and tip
func _calculate_contradiction_score(article_text: String, tip_text: String, facts: Array) -> float:
	if tip_text == "" or tip_text.begins_with("Tip: "):
		return 0.3  # Low contradiction if no meaningful tip
	
	# Check if tip contradicts article based on facts
	var contradiction_count = 0
	var total_facts = facts.size()
	
	if total_facts == 0:
		# Use NLP comparison if available
		if not current_article_nlp_data.is_empty() and not current_tip_nlp_data.is_empty():
			# If classifications differ significantly, higher contradiction
			var article_class = current_article_nlp_data.get("classification", "Unknown")
			var tip_class = current_tip_nlp_data.get("classification", "Unknown")
			if article_class != tip_class:
				return 0.7  # High contradiction
		return 0.3  # Default low
	
	# Count facts where tip contradicts article
	for fact in facts:
		var source = fact.get("source", "")
		if source == "Tip":
			# Tip facts often provide contradictory information
			var category = fact.get("category", "")
			if category in ["Warning", "Pressure", "Anomaly", "Contradiction", "Conflict"]:
				contradiction_count += 1
	
	var contradiction_ratio = float(contradiction_count) / float(max(total_facts, 1))
	return clamp(contradiction_ratio, 0.0, 1.0)

# Helper: Calculate propaganda score
func _calculate_propaganda_score(text: String, stance: String, sender: String, integrity_score: float) -> float:
	var score = 0.5  # Base
	
	# High propaganda indicators
	if stance == "Pro-Government":
		score = 0.8  # High propaganda
	elif sender.contains("Government") or sender.contains("Ministry") or sender.contains("Press Office"):
		score = 0.7
	elif sender.contains("SyndiNet"):
		score = 0.75  # SyndiNet is propaganda outlet
	
	# Low integrity score suggests propaganda
	if integrity_score < 0.5:
		score += 0.2
	
	# Check for propaganda keywords
	var lower_text = text.to_lower()
	var propaganda_keywords = ["unprecedented", "record-breaking", "overwhelming support", "historic levels", "all-time high", "redacted"]
	for keyword in propaganda_keywords:
		if lower_text.contains(keyword):
			score += 0.1
	
	return clamp(score, 0.0, 1.0)

# Helper: Infer source type from sender
func _infer_source_type(sender: String, stance: String) -> String:
	var lower_sender = sender.to_lower()
	
	if lower_sender.contains("government") or lower_sender.contains("ministry") or lower_sender.contains("press office") or lower_sender.contains("sovereign council"):
		return "state_media"
	elif lower_sender.contains("syndinet"):
		return "state_media"  # SyndiNet is state-controlled
	elif lower_sender.contains("anonymous") or lower_sender.contains("whistleblower") or lower_sender.contains("source"):
		return "anonymous_tip"
	elif lower_sender.contains("foreign") or lower_sender.contains("international"):
		return "foreign_press"
	else:
		return "independent"

# Helper: Detect topic from content and sender
func _detect_topic(text: String, sender: String) -> String:
	var lower_text = text.to_lower()
	var lower_sender = sender.to_lower()
	
	# Topic keywords
	if lower_text.contains("celebrity") or lower_text.contains("entertainment") or lower_sender.contains("entertainment"):
		return "celebrity"
	elif lower_text.contains("senate") or lower_text.contains("government") or lower_text.contains("political") or lower_text.contains("corruption"):
		return "politics"
	elif lower_text.contains("military") or lower_text.contains("defense") or lower_text.contains("war"):
		return "military"
	elif lower_text.contains("economy") or lower_text.contains("economic") or lower_text.contains("supply") or lower_text.contains("shortage"):
		return "economy"
	elif lower_text.contains("protest") or lower_text.contains("demonstration") or lower_text.contains("rally"):
		return "protest"
	elif lower_text.contains("health") or lower_text.contains("hospital") or lower_text.contains("medical"):
		return "health"
	else:
		return "politics"  # Default

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
	
	return interpretation
