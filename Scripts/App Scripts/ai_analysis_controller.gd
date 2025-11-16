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
var selected_article_fact: Fact = null
var selected_tip_fact: Fact = null
var article_fact_buttons: Dictionary = {}  # Maps Fact to Button for article side
var tip_fact_buttons: Dictionary = {}  # Maps Fact to Button for tip side
var article_facts_list: Array = []  # Store facts for comparison
var tip_facts_list: Array = []  # Store facts for comparison
var current_article_data: Dictionary = {}
var game_manager: Node = null

# Fact class
class Fact:
	var category: String
	var value: String
	var source: String
	var true_value: String

	func _init(_category: String, _value: String, _source: String, _true_value: String = ""):
		category = _category
		value = _value
		source = _source
		true_value = _true_value

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
	
	# Find matching case in dataset or use provided data
	var case_data = article_data
	if comparisons_data.size() > 0:
		# Try to find matching case
		for case in comparisons_data:
			if case.get("article_text") == article_data.get("article_text"):
				case_data = case
				break
	
	_display_article(case_data)

func _load_dataset():
	var file = FileAccess.open("res://dataset.json", FileAccess.READ)
	
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if typeof(data) == TYPE_DICTIONARY and data.has("cases"):
			comparisons_data = data["cases"]
			print("AI Analysis: Loaded %d cases" % comparisons_data.size())
		else:
			push_error("Invalid JSON format: missing 'cases' array")
		file.close()
	else:
		push_error("Could not open dataset.json")

func _display_article(entry: Dictionary):
	selected_article_fact = null
	selected_tip_fact = null
	article_fact_buttons.clear()
	tip_fact_buttons.clear()
	article_facts_list.clear()
	tip_facts_list.clear()
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
	if article_label:
		var article_text = entry.get("article_text", "Missing article")
		# Remove "Article: " prefix if present
		if article_text.begins_with("Article: "):
			article_text = article_text.substr(9)
		article_label.text = article_text
	if tip_label:
		var tip_text = entry.get("tip_text", "Missing tip")
		# Remove "Tip: " prefix if present
		if tip_text.begins_with("Tip: "):
			tip_text = tip_text.substr(5)
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
			var fact = Fact.new(
				fact_data.get("category", ""),
				fact_data.get("value", ""),
				fact_data.get("source", "Article")
			)
			article_facts_list.append(fact)
			_add_fact_button(fact, article_facts_container, "article")

	# Create fact buttons for tip side
	if tip_facts_container:
		for fact_data in tip_facts:
			var fact = Fact.new(
				fact_data.get("category", ""),
				fact_data.get("value", ""),
				fact_data.get("source", "Tip")
			)
			tip_facts_list.append(fact)
			_add_fact_button(fact, tip_facts_container, "tip")

	# Show meta info
	var stance = entry.get("stance", "Unknown")
	var integrity = str(entry.get("integrity_score", 0.0))
	if result_label:
		result_label.text = "[i]Click one fact from each side to compare them.[/i]\n\n[b]Stance:[/b] %s | [b]Integrity:[/b] %s" % [stance, integrity]

	# Send article for ML analysis
	if article_label:
		_send_article_for_analysis(article_label.text)

func _add_fact_button(fact: Fact, container: VBoxContainer, panel_type: String):
	if not container:
		return
	
	var btn = Button.new()
	btn.text = "%s: %s" % [fact.category, fact.value]
	btn.custom_minimum_size = Vector2(0, 30)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.connect("pressed", Callable(self, "_on_fact_selected").bind(fact, btn, panel_type))
	container.add_child(btn)
	
	# Store button reference
	if panel_type == "article":
		article_fact_buttons[fact] = btn
	else:
		tip_fact_buttons[fact] = btn

func _on_fact_selected(fact: Fact, btn: Button, panel_type: String):
	if panel_type == "article":
		# Check if this fact is already selected (compare by value)
		var is_selected = false
		if selected_article_fact != null:
			is_selected = _facts_match(selected_article_fact, fact)
		
		if is_selected:
			# Deselect - this is the same fact, just deselect it
			selected_article_fact = null
			btn.remove_theme_color_override("font_color")
			article_panel.remove_theme_stylebox_override("panel")
		else:
			# Deselect previous article fact if any (find by value match)
			if selected_article_fact != null:
				for stored_fact in article_fact_buttons.keys():
					if _facts_match(stored_fact, selected_article_fact):
						article_fact_buttons[stored_fact].remove_theme_color_override("font_color")
						break
				article_panel.remove_theme_stylebox_override("panel")
			
			# Select this fact
			selected_article_fact = fact
			btn.add_theme_color_override("font_color", Color.YELLOW)
			
			# Highlight article panel
			var style_box = StyleBoxFlat.new()
			style_box.bg_color = Color(1.0, 1.0, 0.0, 0.15)  # Yellow tint
			article_panel.add_theme_stylebox_override("panel", style_box)
	else:  # tip
		# Check if this fact is already selected (compare by value)
		var is_selected = false
		if selected_tip_fact != null:
			is_selected = _facts_match(selected_tip_fact, fact)
		
		if is_selected:
			# Deselect - this is the same fact, just deselect it
			selected_tip_fact = null
			btn.remove_theme_color_override("font_color")
			tip_panel.remove_theme_stylebox_override("panel")
		else:
			# Deselect previous tip fact if any (find by value match)
			if selected_tip_fact != null:
				for stored_fact in tip_fact_buttons.keys():
					if _facts_match(stored_fact, selected_tip_fact):
						tip_fact_buttons[stored_fact].remove_theme_color_override("font_color")
						break
				tip_panel.remove_theme_stylebox_override("panel")
			
			# Select this fact
			selected_tip_fact = fact
			btn.add_theme_color_override("font_color", Color.YELLOW)
			
			# Highlight tip panel
			var style_box = StyleBoxFlat.new()
			style_box.bg_color = Color(1.0, 1.0, 0.0, 0.15)  # Yellow tint
			tip_panel.add_theme_stylebox_override("panel", style_box)

	# Check if we have one fact from each side and compare
	if selected_article_fact != null and selected_tip_fact != null:
		# Compare facts
		var result = compare_facts(selected_article_fact, selected_tip_fact)
		_show_result(result)
	else:
		# Update instruction text
		if result_label:
			var stance = current_article_data.get("stance", "Unknown")
			var integrity = str(current_article_data.get("integrity_score", 0.0))
			if selected_article_fact == null and selected_tip_fact == null:
				result_label.text = "[i]Click one fact from each side to compare them.[/i]\n\n[b]Stance:[/b] %s | [b]Integrity:[/b] %s" % [stance, integrity]
			elif selected_article_fact == null:
				result_label.text = "[i]Select a fact from the article side (left) to compare.[/i]\n\n[b]Stance:[/b] %s | [b]Integrity:[/b] %s" % [stance, integrity]
			else:
				result_label.text = "[i]Select a fact from the tip side (right) to compare.[/i]\n\n[b]Stance:[/b] %s | [b]Integrity:[/b] %s" % [stance, integrity]

func compare_facts(fact_a: Fact, fact_b: Fact) -> Dictionary:
	var result = {
		"is_discrepancy": false,
		"reason": "",
		"truth_status": ""
	}

	if fact_a.category == fact_b.category:
		var overlap = _word_overlap(fact_a.value, fact_b.value)
		
		if overlap < 0.5:
			result.is_discrepancy = true
			result.reason = "Low word overlap: %.2f" % overlap
			
			if fact_a.value != fact_b.value:
				result.is_discrepancy = true
				result.reason = "Discrepancy in %s: '%s' vs '%s'" % [fact_a.category, fact_a.value, fact_b.value]

			# Placeholder truth comparison
			if fact_a.true_value != "" or fact_b.true_value != "":
				var truth = fact_a.true_value if fact_a.true_value != "" else fact_b.true_value
				var a_correct = fact_a.value == truth
				var b_correct = fact_b.value == truth

				if a_correct and b_correct:
					result.truth_status = "Both are correct."
				elif a_correct:
					result.truth_status = "Article is correct, Tip is false."
				elif b_correct:
					result.truth_status = "Tip is correct, Article is false."
				else:
					result.truth_status = "Both are incorrect."
		else:
			result.reason = "Facts match: %s = %s" % [fact_a.category, fact_a.value]
			result.truth_status = "Matching facts — consistent."
			result.reason = "High semantic overlap: %.2f" % overlap
			
			# Award integrity point for high semantic overlap (0.90-1.0)
			if overlap >= 0.90 and overlap <= 1.0:
				print("[AI ANALYSIS DEBUG] High semantic overlap detected: %.4f" % overlap)
				if game_manager and game_manager.has_method("add_high_overlap_comparison"):
					game_manager.add_high_overlap_comparison()
					print("[AI ANALYSIS DEBUG] High overlap bonus awarded")
				else:
					push_warning("[AI ANALYSIS DEBUG] Game manager not available for high overlap bonus!")
	else:
		result.reason = "Different categories: cannot compare directly."
		result.truth_status = "N/A"

	return result

func _word_overlap(a: String, b: String) -> float:
	var words_a = a.to_lower().split(" ")
	var words_b = b.to_lower().split(" ")
	var common = 0
	for w in words_a:
		if words_b.has(w):
			common += 1
	return float(common) / max(words_a.size(), 1)

func _facts_match(fact_a: Fact, fact_b: Fact) -> bool:
	# Compare facts by their category and value
	return fact_a.category == fact_b.category and fact_a.value == fact_b.value

func _show_result(result: Dictionary):
	if not result_label:
		return
	
	var stance = current_article_data.get("stance", "Unknown")
	var integrity = str(current_article_data.get("integrity_score", 0.0))
	
	var text = "[b]Comparison Result:[/b]\n"
	text += result.reason
	if result.truth_status != "":
		text += "\n" + result.truth_status

	if result.is_discrepancy:
		result_label.text = "[b]Stance:[/b] %s | [b]Integrity:[/b] %s\n\n[color=red]%s[/color]" % [stance, integrity, text]
	else:
		result_label.text = "[b]Stance:[/b] %s | [b]Integrity:[/b] %s\n\n[color=green]%s[/color]" % [stance, integrity, text]

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
	if not http_request:
		return
	
	var json_data = { "text": article_text }
	var json_str = JSON.stringify(json_data)

	print("Sending article for ML analysis...")
	http_request.request(
		"http://127.0.0.1:8000/analyze",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		json_str
	)

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_error("ML API request failed: %s" % str(response_code))
		if result_label:
			result_label.text += "\n\n[color=red]ML API Error: %d[/color]" % response_code
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
