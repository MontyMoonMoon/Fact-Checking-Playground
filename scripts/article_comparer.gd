extends Control

class_name ArticleComparer

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



@onready var http_request = $HTTPRequest
@onready var article_label = $ArticleText
@onready var tip_label = $TipText
@onready var facts_container = $FactsContainer
@onready var result_text = $ResultText
@onready var next_button = $NextButton
@onready var prev_button = $PrevButton

var comparisons_data = []
var current_index = 0
var selected_facts: Array[Fact] = []



func _ready():
	
	#JSON loading ||temporarily loaded in this scene for prototype
	var file = FileAccess.open("res://dataset.json", FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if typeof(data) == TYPE_DICTIONARY and data.has("cases"):
			comparisons_data = data["cases"]
			print("Loaded", comparisons_data.size(), "cases")
		else:
			push_error("Invalid JSON format: missing 'cases' array")
	else:
		push_error("Could not open dataset.json")

	# Button connections
	next_button.pressed.connect(_on_next_pressed)
	prev_button.pressed.connect(_on_prev_pressed)

	# BBCode formatting
	article_label.bbcode_enabled = true
	tip_label.bbcode_enabled = true
	result_text.bbcode_enabled = true

	_display_comparison(current_index)


#on click between 2 articles, compare.
func _on_analyze_pressed():
	var article_text = article_label.text
	var json_data = { "text": article_text }
	var json_str = JSON.stringify(json_data)

#API calling
	http_request.request(
		"http://127.0.0.1:8000/analyze",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		json_str
	)


#display result
func _display_comparison(index: int):
	if comparisons_data.is_empty():
		return

	if index < 0:
		current_index = comparisons_data.size() - 1
	elif index >= comparisons_data.size():
		current_index = 0
	else:
		current_index = index

	var entry = comparisons_data[current_index]
	selected_facts.clear()

	# Clear old buttons
	for child in facts_container.get_children():
		child.queue_free()

	# Update text
	article_label.text = entry.get("article_text", "Missing article")
	tip_label.text = entry.get("tip_text", "Missing tip")

	# Create fact buttons
	for fact_data in entry.get("facts", []):
		var fact = Fact.new(
			fact_data.get("category", ""),
			fact_data.get("value", ""),
			fact_data.get("source", "")
		)
		_add_fact_button(fact)

	# Show meta info
	var stance = entry.get("stance", "Unknown")
	var integrity = str(entry.get("integrity_score", 0.0))
	result_text.text = "[i]Select two facts to compare...[/i]\n\n[b]Stance:[/b] %s | [b]Integrity:[/b] %s" % [stance, integrity]

	#Send article for ML analysis
	_send_article_for_analysis(article_label.text)


#Throws Article to Backend
func _send_article_for_analysis(article_text: String):
	var json_data = { "text": article_text }
	var json_str = JSON.stringify(json_data)

	print("Sending article for ML analysis...")
	http_request.request(
		"http://127.0.0.1:8000/analyze",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		json_str
	)


#
func _add_fact_button(fact: Fact):
	var btn = Button.new()
	btn.text = "%s: %s (%s)" % [fact.category, fact.value, fact.source]
	btn.connect("pressed", Callable(self, "_on_fact_selected").bind(fact, btn))
	facts_container.add_child(btn)


#fact selection
func _on_fact_selected(fact: Fact, btn: Button):
	if selected_facts.has(fact):
		selected_facts.erase(fact)
		btn.remove_theme_color_override("font_color")
	else:
		selected_facts.append(fact)
		btn.add_theme_color_override("font_color", Color.SKY_BLUE)

	if selected_facts.size() == 2:
		var result = compare_facts(selected_facts[0], selected_facts[1])
		_show_result(result)
		selected_facts.clear()

		# Reset button highlights
		for child in facts_container.get_children():
			if child is Button:
				child.remove_theme_color_override("font_color")


#Improved NLP handling
func _word_overlap(a: String, b: String) -> float:
	var words_a = a.to_lower().split(" ")
	var words_b = b.to_lower().split(" ")
	var common = 0
	for w in words_a:
		if words_b.has(w):
			common += 1
	return float(common) / max(words_a.size(), 1)


#
func compare_facts(fact_a: ArticleComparer.Fact, fact_b: ArticleComparer.Fact) -> Dictionary:
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
	else:
		result.reason = "Different categories: cannot compare directly."
		result.truth_status = "N/A"
		

	return result


#Compare result
func _show_result(result: Dictionary):
	var text = result.reason
	if result.truth_status != "":
		text += "\n" + result.truth_status

	if result.is_discrepancy:
		result_text.text = "[color=red]%s[/color]" % text
	else:
		result_text.text = "[color=green]%s[/color]" % text


#Nav
func _on_next_pressed():
	_display_comparison(current_index + 1)

func _on_prev_pressed():
	_display_comparison(current_index - 1)


#API response handling
func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_error("ML API request failed: %s" % str(response_code))
		return

	var response = JSON.parse_string(body.get_string_from_utf8())
	if typeof(response) == TYPE_DICTIONARY:
		var rf = response.get("random_forest_score", 0)
		var log = response.get("logistic_regression_score", 0)
		var avg = response.get("average_score", 0)
		var verdict = response.get("result", "Unknown")

#returns ML backend results || shown only for debug
		result_text.text += "\n\n[b]ML Analysis:[/b]\n" + \
			"RF: %.2f | LogReg: %.2f | Avg: %.2f\nVerdict: %s" % [rf, log, avg, verdict]
