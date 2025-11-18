extends MarginContainer
class_name AIAnalysisController

# References
@onready var scroll_area: ScrollContainer = $ScrollableArea
@onready var content_container: VBoxContainer = $ScrollableArea/ContentContainer
@onready var papers_container: HBoxContainer = $ScrollableArea/ContentContainer/PapersContainer
@onready var article_panel: Panel = $ScrollableArea/ContentContainer/PapersContainer/ArticlePanel
@onready var article_label: RichTextLabel = $ScrollableArea/ContentContainer/PapersContainer/ArticlePanel/ArticleVBox/ArticleText
@onready var article_facts_container: VBoxContainer = $ScrollableArea/ContentContainer/PapersContainer/ArticlePanel/ArticleVBox/ArticleFactsContainer
@onready var tip_panel: Panel = $ScrollableArea/ContentContainer/PapersContainer/TipPanel
@onready var tip_label: RichTextLabel = $ScrollableArea/ContentContainer/PapersContainer/TipPanel/TipVBox/TipText
@onready var tip_facts_container: VBoxContainer = $ScrollableArea/ContentContainer/PapersContainer/TipPanel/TipVBox/TipFactsContainer
@onready var result_label: RichTextLabel = $ScrollableArea/ContentContainer/ResultSection/ResultText
@onready var next_button: Button = $ScrollableArea/ContentContainer/ButtonSection/NextButton
@onready var prev_button: Button = $ScrollableArea/ContentContainer/ButtonSection/PrevButton
@onready var analyze_button: Button = $ScrollableArea/ContentContainer/ButtonSection/AnalyzeButton

@onready var http_request: HTTPRequest = $HTTPRequest

# Data
var comparisons_data: Array = []
var current_index: int = 0
var selected_article_fact_id: String = ""  # Store fact_id instead of Fact instance
var selected_tip_fact_id: String = ""  # Store fact_id instead of Fact instance
var article_fact_buttons: Dictionary = {}  # Maps fact_id (String) to Button for article side
var tip_fact_buttons: Dictionary = {}  # Maps fact_id (String) to Button for tip side
var article_facts_list: Array = []  # Store fact dictionaries for comparison (not Fact instances)
var tip_facts_list: Array = []  # Store fact dictionaries for comparison (not Fact instances)
var fact_id_to_fact_data: Dictionary = {}  # Maps fact_id (String) to fact dictionary (not Fact instance)
var current_article_data: Dictionary = {}
# Don't store RefCounted objects directly - store as dictionaries instead
var current_article_nlp_data: Dictionary = {}  # NLP analysis data for current article (dict, not RefCounted)
var current_tip_nlp_data: Dictionary = {}  # NLP analysis data for current tip (dict, not RefCounted)
var game_manager: Node = null

# Fact class removed - we work entirely with dictionaries to avoid RefCounted issues

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

# _dict_to_nlp_result removed - we no longer create RefCounted objects from dictionaries
# All comparisons are done directly with dictionaries or by creating temporary AnalysisResult objects
# that are immediately nulled after use

func _ready():
	# Load dataset
	_load_dataset()
	
	# Connect buttons
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if prev_button:
		prev_button.pressed.connect(_on_prev_pressed)
	if analyze_button:
		analyze_button.pressed.connect(_on_analyze_pressed)
	
	# Connect HTTP request
	if http_request:
		http_request.request_completed.connect(_on_http_request_request_completed)
	
	# Enable BBCode
	if article_label:
		article_label.bbcode_enabled = true
	if tip_label:
		tip_label.bbcode_enabled = true
	if result_label:
		result_label.bbcode_enabled = true
	
	# Start hidden
	visible = false

func set_game_manager(manager: Node):
	game_manager = manager

func load_article(article_data: Dictionary):
	current_article_data = article_data
	visible = true
	
	# Reload dataset to include any new additions (from emails)
	_load_dataset()
	
	# Find matching case in dataset or use provided data
	var case_data = article_data
	if comparisons_data.size() > 0:
		# Try to find matching case
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
	# Reload dataset to ensure we have latest data
	_load_dataset()
	
	# Check if article already exists
	var article_text = article_data.get("article_text", "")
	var exists = false
	for case in comparisons_data:
		if case.get("article_text", "") == article_text:
			exists = true
			break
	
	# Add if it doesn't exist
	if not exists:
		comparisons_data.append(article_data.duplicate(true))
		print("AI Analysis: Added article to pool - %s" % article_text)
	else:
		print("AI Analysis: Article already in pool - %s" % article_text)

func _load_dataset():
	# Use JSONManager to get all cases (dataset + additions)
	var json_manager = JSONManager.get_instance()
	if json_manager:
		comparisons_data = json_manager.get_all_cases(false)
		print("AI Analysis: Loaded %d total cases (dataset + additions)" % comparisons_data.size())
	else:
		# Fallback: manual loading
		var dataset = JSONManager.load_json("res://dataset.json", {})
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

func _display_article(entry: Dictionary):
	# Clear previous selections and references
	selected_article_fact_id = ""
	selected_tip_fact_id = ""
	
	# Clear button references
	article_fact_buttons.clear()
	tip_fact_buttons.clear()
	
	# Clear fact data lists and mappings
	article_facts_list.clear()
	tip_facts_list.clear()
	fact_id_to_fact_data.clear()
	
	# Clear NLP data
	current_article_nlp_data.clear()
	current_tip_nlp_data.clear()
	
	current_article_data = entry

	# Clear old fact buttons
	if article_facts_container:
		for child in article_facts_container.get_children():
			child.queue_free()
	if tip_facts_container:
		for child in tip_facts_container.get_children():
			child.queue_free()
	
	# Clear panel highlights
	if article_panel:
		article_panel.remove_theme_stylebox_override("panel")
	if tip_panel:
		tip_panel.remove_theme_stylebox_override("panel")

	# Update text
	var article_text = entry.get("article_text", "Missing article")
	# Remove "Article: " prefix if present
	if article_text.begins_with("Article: "):
		article_text = article_text.substr(9)
	
	var tip_text = entry.get("tip_text", "Missing tip")
	# Remove "Tip: " prefix if present
	if tip_text.begins_with("Tip: "):
		tip_text = tip_text.substr(5)
	
	# Perform NLP analysis on article and tip - convert to dictionaries immediately
	var article_nlp_result = NLPAnalyzer.analyze_text(article_text)
	var tip_nlp_result = NLPAnalyzer.analyze_text(tip_text)
	if article_nlp_result:
		current_article_nlp_data = _nlp_result_to_dict(article_nlp_result)
		# Immediately clear RefCounted object
		article_nlp_result = null
	if tip_nlp_result:
		current_tip_nlp_data = _nlp_result_to_dict(tip_nlp_result)
		# Immediately clear RefCounted object
		tip_nlp_result = null
	
	if article_label:
		article_label.text = article_text
	if tip_label:
		tip_label.text = tip_text

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
			# Default: alternate based on index
			if article_facts.size() <= tip_facts.size():
				article_facts.append(fact_data)
			else:
				tip_facts.append(fact_data)

	# Create fact buttons for article side
	if article_facts_container:
		for fact_data in article_facts:
			# Store dictionary
			article_facts_list.append(fact_data)
			var fact_id = _get_fact_id_from_dict(fact_data)
			fact_id_to_fact_data[fact_id] = fact_data
			_add_fact_button(fact_data, fact_id, article_facts_container, "article")

	# Create fact buttons for tip side
	if tip_facts_container:
		for fact_data in tip_facts:
			# Store dictionary
			tip_facts_list.append(fact_data)
			var fact_id = _get_fact_id_from_dict(fact_data)
			fact_id_to_fact_data[fact_id] = fact_data
			_add_fact_button(fact_data, fact_id, tip_facts_container, "tip")

	# Show meta info with NLP analysis
	var stance = entry.get("stance", "Unknown")
	var integrity = str(entry.get("integrity_score", 0.0))
	
	var nlp_info = ""
	if not current_article_nlp_data.is_empty():
		nlp_info += "\n\n[b]Article Classification:[/b] %s (%.0f%% confidence)" % [current_article_nlp_data.get("classification", "Unknown"), current_article_nlp_data.get("classification_confidence", 0.0) * 100]
		var fake_keywords = current_article_nlp_data.get("fake_news_keywords", [])
		if fake_keywords.size() > 0:
			nlp_info += "\n[color=yellow]⚠ Fake News Keywords Detected: %d[/color]" % fake_keywords.size()
		var entities = current_article_nlp_data.get("entities", [])
		if entities.size() > 0:
			var entity_types = {}
			for entity in entities:
				var entity_type = entity.get("type", "")
				if entity_type != "":
					if not entity_types.has(entity_type):
						entity_types[entity_type] = 0
					entity_types[entity_type] += 1
			var entity_summary = []
			for type in entity_types.keys():
				entity_summary.append("%s: %d" % [type, entity_types[type]])
			nlp_info += "\n[b]Entities:[/b] %s" % ", ".join(entity_summary)
	
	if result_label:
		result_label.text = "[i]Click one fact from each side to compare them.[/i]\n\n[b]Stance:[/b] %s | [b]Integrity:[/b] %s%s" % [stance, integrity, nlp_info]

	# Send article for ML analysis
	if article_label:
		_send_article_for_analysis(article_label.text)

func _get_fact_id_from_dict(fact_data: Dictionary) -> String:
	"""Generate a unique ID for a fact from dictionary data"""
	return "%s|%s|%s" % [fact_data.get("category", ""), fact_data.get("value", ""), fact_data.get("source", "")]

func _add_fact_button(fact_data: Dictionary, fact_id: String, container: VBoxContainer, panel_type: String):
	if not container:
		return
	
	var btn = Button.new()
	btn.text = "%s: %s" % [fact_data.get("category", ""), fact_data.get("value", "")]
	btn.custom_minimum_size = Vector2(0, 30)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.connect("pressed", Callable(self, "_on_fact_selected").bind(fact_id, btn, panel_type))
	container.add_child(btn)
	
	# Store button reference using fact_id as key
	if panel_type == "article":
		article_fact_buttons[fact_id] = btn
	else:
		tip_fact_buttons[fact_id] = btn

func _on_fact_selected(fact_id: String, btn: Button, panel_type: String):
	var fact_data = fact_id_to_fact_data.get(fact_id, null)
	if not fact_data:
		return
	
	if panel_type == "article":
		# Check if this fact is already selected
		if selected_article_fact_id == fact_id:
			# Deselect - this is the same fact
			selected_article_fact_id = ""
			btn.remove_theme_color_override("font_color")
			article_panel.remove_theme_stylebox_override("panel")
		else:
			# Deselect previous article fact if any
			if selected_article_fact_id != "":
				var prev_btn = article_fact_buttons.get(selected_article_fact_id, null)
				if prev_btn:
					prev_btn.remove_theme_color_override("font_color")
				article_panel.remove_theme_stylebox_override("panel")
			
			# Select this fact
			selected_article_fact_id = fact_id
			btn.add_theme_color_override("font_color", Color.YELLOW)
			
			# Highlight article panel
			var style_box = StyleBoxFlat.new()
			style_box.bg_color = Color(1.0, 1.0, 0.0, 0.15)  # Yellow tint
			article_panel.add_theme_stylebox_override("panel", style_box)
	else:  # tip
		# Check if this fact is already selected
		if selected_tip_fact_id == fact_id:
			# Deselect - this is the same fact
			selected_tip_fact_id = ""
			btn.remove_theme_color_override("font_color")
			tip_panel.remove_theme_stylebox_override("panel")
		else:
			# Deselect previous tip fact if any
			if selected_tip_fact_id != "":
				var prev_btn = tip_fact_buttons.get(selected_tip_fact_id, null)
				if prev_btn:
					prev_btn.remove_theme_color_override("font_color")
				tip_panel.remove_theme_stylebox_override("panel")
			
			# Select this fact
			selected_tip_fact_id = fact_id
			btn.add_theme_color_override("font_color", Color.YELLOW)
			
			# Highlight tip panel
			var style_box = StyleBoxFlat.new()
			style_box.bg_color = Color(1.0, 1.0, 0.0, 0.15)  # Yellow tint
			tip_panel.add_theme_stylebox_override("panel", style_box)

	# Check if we have one fact from each side and compare
	if selected_article_fact_id != "" and selected_tip_fact_id != "":
		# Get fact data and compare directly using dictionaries
		var article_fact_data = fact_id_to_fact_data.get(selected_article_fact_id, null)
		var tip_fact_data = fact_id_to_fact_data.get(selected_tip_fact_id, null)
		
		if article_fact_data and tip_fact_data:
			# Compare facts using dictionaries - no Fact instances needed
			var result = compare_facts_from_dict(article_fact_data, tip_fact_data)
			_show_result(result)
	else:
		# Update instruction text
		if result_label:
			var stance = current_article_data.get("stance", "Unknown")
			var integrity = str(current_article_data.get("integrity_score", 0.0))
			if selected_article_fact_id == "" and selected_tip_fact_id == "":
				result_label.text = "[i]Click one fact from each side to compare them.[/i]\n\n[b]Stance:[/b] %s | [b]Integrity:[/b] %s" % [stance, integrity]
			elif selected_article_fact_id == "":
				result_label.text = "[i]Select a fact from the article side (left) to compare.[/i]\n\n[b]Stance:[/b] %s | [b]Integrity:[/b] %s" % [stance, integrity]
			else:
				result_label.text = "[i]Select a fact from the tip side (right) to compare.[/i]\n\n[b]Stance:[/b] %s | [b]Integrity:[/b] %s" % [stance, integrity]

func compare_facts_from_dict(fact_a_data: Dictionary, fact_b_data: Dictionary) -> Dictionary:
	"""Compare facts using dictionaries instead of Fact instances to avoid RefCounted issues"""
	var result = {
		"is_discrepancy": false,
		"reason": "",
		"truth_status": "",
		"entity_analysis": "",
		"classification_analysis": "",
		"keyword_analysis": ""
	}

	# Get fact values
	var value_a = fact_a_data.get("value", "")
	var value_b = fact_b_data.get("value", "")
	
	# Perform NLP analysis on the fact values (temporary AnalysisResult objects)
	var nlp_a = NLPAnalyzer.analyze_text(value_a)
	var nlp_b = NLPAnalyzer.analyze_text(value_b)
	
	# Extract all needed values BEFORE clearing RefCounted objects
	var classification_a = nlp_a.classification
	var classification_b = nlp_b.classification
	var fake_score_a = nlp_a.fake_news_score
	var fake_score_b = nlp_b.fake_news_score
	
	# Compare using NLP
	var comparison = NLPAnalyzer.compare_analyses(nlp_a, nlp_b, value_a, value_b)
	
	# IMMEDIATELY clear RefCounted objects after comparison
	nlp_a = null
	nlp_b = null
	
	# Convert entity_matches to dictionaries to avoid RefCounted issues
	var entity_matches_dict = []
	if comparison.has("entity_matches"):
		for match_item in comparison.entity_matches:
			# Convert to dictionary if it's not already
			if typeof(match_item) == TYPE_DICTIONARY:
				entity_matches_dict.append(match_item)
			else:
				# If it's an object, convert to dict
				entity_matches_dict.append({
					"type": match_item.get("type", "") if match_item.has_method("get") else "",
					"entity_a": match_item.get("entity_a", "") if match_item.has_method("get") else "",
					"entity_b": match_item.get("entity_b", "") if match_item.has_method("get") else "",
					"similarity": match_item.get("similarity", 0.0) if match_item.has_method("get") else 0.0
				})
	
	# Build entity analysis
	var entity_info = []
	if entity_matches_dict.size() > 0:
		entity_info.append("[b]Matching Entities:[/b]")
		for match in entity_matches_dict:
			entity_info.append("  • %s (%s): %.0f%% match" % [match.get("type", ""), match.get("entity_a", ""), match.get("similarity", 0.0) * 100])
		result.entity_analysis = "\n".join(entity_info)
	
	# Build classification analysis (using extracted values)
	if comparison.classification_match:
		result.classification_analysis = "[b]Classification:[/b] Both classified as [b]%s[/b]" % classification_a
	else:
		result.classification_analysis = "[b]Classification Mismatch:[/b] Article=%s, Tip=%s" % [classification_a, classification_b]
	
	# Build keyword analysis
	if comparison.keyword_overlap > 0.3:
		result.keyword_analysis = "[b]Keyword Overlap:[/b] %.0f%% - High semantic similarity" % (comparison.keyword_overlap * 100)
	else:
		result.keyword_analysis = "[b]Keyword Overlap:[/b] %.0f%% - Low semantic similarity" % (comparison.keyword_overlap * 100)
	
	# Determine discrepancy based on overall match score
	var overall_score = comparison.overall_match_score
	var semantic_similarity = comparison.semantic_similarity
	
	if overall_score < 0.4:  # Low overall match
		result.is_discrepancy = true
		result.reason = "Significant discrepancy detected (Match Score: %.0f%%)" % (overall_score * 100)
		
		# Check fake news indicators (using extracted values)
		if fake_score_a > 0.3 or fake_score_b > 0.3:
			result.truth_status = "[color=red]⚠ Warning: Fake news patterns detected in one or both facts[/color]"
		else:
			result.truth_status = "[color=orange]Facts show significant differences. Verify sources.[/color]"
			
	elif overall_score >= 0.4 and overall_score < 0.7:  # Moderate match
		result.is_discrepancy = false
		result.reason = "Partial match (Match Score: %.0f%%)" % (overall_score * 100)
		result.truth_status = "[color=yellow]Facts are similar but not identical. Review details.[/color]"
		
	else:  # High match
		result.is_discrepancy = false
		result.reason = "High match (Match Score: %.0f%%)" % (overall_score * 100)
		result.truth_status = "[color=green]Facts are consistent and match well.[/color]"
		
		# Award integrity point for high semantic overlap (0.90-1.0)
		if semantic_similarity >= 0.90 and semantic_similarity <= 1.0:
			print("[AI ANALYSIS DEBUG] High semantic overlap detected: %.4f" % semantic_similarity)
			if game_manager and game_manager.has_method("add_high_overlap_comparison"):
				game_manager.add_high_overlap_comparison()
				print("[AI ANALYSIS DEBUG] High overlap bonus awarded")
			else:
				push_warning("[AI ANALYSIS DEBUG] Game manager not available for high overlap bonus!")
	
	# Add detailed analysis to reason
	var detailed_analysis = []
	detailed_analysis.append(result.reason)
	if result.entity_analysis != "":
		detailed_analysis.append(result.entity_analysis)
	detailed_analysis.append(result.classification_analysis)
	detailed_analysis.append(result.keyword_analysis)
	
	result.reason = "\n".join(detailed_analysis)
	
	# Clear comparison dictionary to ensure no lingering references
	comparison.clear()
	
	return result

func _word_overlap(a: String, b: String) -> float:
	var words_a = a.to_lower().split(" ")
	var words_b = b.to_lower().split(" ")
	var common = 0
	for w in words_a:
		if words_b.has(w):
			common += 1
	return float(common) / max(words_a.size(), 1)


func _show_result(result: Dictionary):
	if not result_label:
		return
	
	var stance = current_article_data.get("stance", "Unknown")
	var integrity = str(current_article_data.get("integrity_score", 0.0))
	
	var text = "[b]NLP Analysis Result:[/b]\n"
	text += result.reason
	if result.truth_status != "":
		text += "\n\n" + result.truth_status
	
	# Add article-level NLP info if available
	if not current_article_nlp_data.is_empty() and not current_tip_nlp_data.is_empty():
		text += "\n\n[b]Article-Level Analysis:[/b]"
		text += "\nArticle Classification: %s (%.0f%%)" % [current_article_nlp_data.get("classification", "Unknown"), current_article_nlp_data.get("classification_confidence", 0.0) * 100]
		text += "\nTip Classification: %s (%.0f%%)" % [current_tip_nlp_data.get("classification", "Unknown"), current_tip_nlp_data.get("classification_confidence", 0.0) * 100]
		
		var article_fake_keywords = current_article_nlp_data.get("fake_news_keywords", [])
		var tip_fake_keywords = current_tip_nlp_data.get("fake_news_keywords", [])
		if article_fake_keywords.size() > 0:
			text += "\n[color=yellow]⚠ Article has %d fake news indicators[/color]" % article_fake_keywords.size()
		if tip_fake_keywords.size() > 0:
			text += "\n[color=yellow]⚠ Tip has %d fake news indicators[/color]" % tip_fake_keywords.size()

	var color = Color.GREEN
	if result.is_discrepancy:
		color = Color.RED
	elif result.truth_status.contains("Warning") or result.truth_status.contains("Review"):
		color = Color.YELLOW
	
	result_label.text = "[b]Stance:[/b] %s | [b]Integrity:[/b] %s\n\n%s" % [stance, integrity, text]

func _on_next_pressed():
	if comparisons_data.size() > 0:
		current_index = (current_index + 1) % comparisons_data.size()
		_display_article(comparisons_data[current_index])

func _on_prev_pressed():
	if comparisons_data.size() > 0:
		current_index = (current_index - 1 + comparisons_data.size()) % comparisons_data.size()
		_display_article(comparisons_data[current_index])

func _on_analyze_pressed():
	if article_label:
		_send_article_for_analysis(article_label.text)

func _send_article_for_analysis(article_text: String):
	# Ensure http_request is available
	if not http_request:
		# Try to get it manually if @onready failed
		http_request = get_node_or_null("HTTPRequest")
		if not http_request:
			push_error("HTTPRequest node not found!")
			if result_label:
				result_label.text += "\n\n[color=red]HTTPRequest node not found![/color]"
			return
	
	# Ensure we're not already processing a request
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("HTTPRequest is busy, cancelling previous request...")
		http_request.cancel_request()
		await get_tree().process_frame  # Wait a frame
	
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

	print("Sending article for ML analysis to http://127.0.0.1:8000/analyze...")
	print("Request body: %s" % json_str)
	
	var error = http_request.request(
		"http://127.0.0.1:8000/analyze",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		json_str
	)
	
	if error != OK:
		push_error("Failed to send HTTP request: %d" % error)
		if result_label:
			result_label.text += "\n\n[color=red]HTTP Request Error: %d[/color]" % error

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("HTTP Request completed - Result: %d, Response Code: %d" % [result, response_code])
	
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("ML API request failed with result code: %d (Response: %d)" % [result, response_code])
		if result_label:
			result_label.text += "\n\n[color=red]ML API Request Failed: Result %d, Response %d[/color]" % [result, response_code]
		return
	
	if response_code != 200:
		var body_text = body.get_string_from_utf8()
		push_error("ML API request failed: %d\nResponse body: %s" % [response_code, body_text])
		if result_label:
			result_label.text += "\n\n[color=red]ML API Error: %d[/color]\n%s" % [response_code, body_text]
		return

	var response = JSON.parse_string(body.get_string_from_utf8())
	if typeof(response) == TYPE_DICTIONARY:
		var rf = response.get("random_forest_score", 0.5)
		var log = response.get("logistic_regression_score", 0.5)
		var avg = response.get("average_score", 0.5)
		var verdict = response.get("result", "Unknown")

		# Display ML results
		if result_label:
			var existing_text = result_label.text
			result_label.text = existing_text + "\n\n[b]ML Analysis:[/b]\n" + \
				"RF: %.2f | LogReg: %.2f | Avg: %.2f\nVerdict: %s" % [rf, log, avg, verdict]
		
		# Send results to game manager
		print("[AI ANALYSIS DEBUG] ===== ML Analysis Complete =====")
		print("[AI ANALYSIS DEBUG] RF: %.2f, LogReg: %.2f, Avg: %.2f, Verdict: %s" % [rf, log, avg, verdict])
		print("[AI ANALYSIS DEBUG] Game manager exists: %s" % (game_manager != null))
		
		if game_manager and game_manager.has_method("add_article_result"):
			# Normalize scores to 0-1 range before passing
			var rf_normalized = rf / 10.0
			var log_normalized = log / 10.0
			print("[AI ANALYSIS DEBUG] Normalized scores - RF: %.4f, LR: %.4f" % [rf_normalized, log_normalized])
			game_manager.add_article_result(rf_normalized, log_normalized)
			print("[AI ANALYSIS DEBUG] Results sent to GameManager")
		else:
			push_warning("[AI ANALYSIS DEBUG] Game manager not available or missing add_article_result method!")
		print("[AI ANALYSIS DEBUG] ==================================")
	else:
		push_error("Invalid response from ML API")
