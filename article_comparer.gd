extends Control
class_name ArticleComparer

# --- Fact class ---
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


# --- Node references ---
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
	# Load your JSON data
	var file = FileAccess.open("res://dataset.json", FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if typeof(data) == TYPE_DICTIONARY and data.has("cases"):
			comparisons_data = data["cases"]
			print("✅ Loaded", comparisons_data.size(), "cases")
		else:
			push_error("Invalid JSON format: missing 'cases' array")
	else:
		push_error("Could not open dataset.json")

	# Button connections
	next_button.pressed.connect(_on_next_pressed)
	prev_button.pressed.connect(_on_prev_pressed)

	# Enable BBCode formatting
	article_label.bbcode_enabled = true
	tip_label.bbcode_enabled = true
	result_text.bbcode_enabled = true

	_display_comparison(current_index)


# --- Display a single case ---
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

	# Create buttons
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


# --- Create a fact button ---
func _add_fact_button(fact: Fact):
	var btn = Button.new()
	btn.text = "%s: %s (%s)" % [fact.category, fact.value, fact.source]
	btn.connect("pressed", Callable(self, "_on_fact_selected").bind(fact, btn))
	facts_container.add_child(btn)


# --- Select facts and compare when two are picked ---
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

		# reset button highlight
		for child in facts_container.get_children():
			if child is Button:
				child.remove_theme_color_override("font_color")


# --- Compare two facts (placeholder for ML integration) ---
func compare_facts(fact_a: ArticleComparer.Fact, fact_b: ArticleComparer.Fact) -> Dictionary:
	var result = {
		"is_discrepancy": false,
		"reason": "",
		"truth_status": ""
	}

	if fact_a.category == fact_b.category:
		if fact_a.value != fact_b.value:
			result.is_discrepancy = true
			result.reason = "❌ Discrepancy in %s: '%s' vs '%s'" % [fact_a.category, fact_a.value, fact_b.value]

			# Placeholder truth comparison logic
			if fact_a.true_value != "" or fact_b.true_value != "":
				var truth = fact_a.true_value if fact_a.true_value != "" else fact_b.true_value
				var a_correct = fact_a.value == truth
				var b_correct = fact_b.value == truth

				if a_correct and b_correct:
					result.truth_status = "🟩 Both are correct."
				elif a_correct:
					result.truth_status = "🟩 Article is correct, Tip is false."
				elif b_correct:
					result.truth_status = "🟩 Tip is correct, Article is false."
				else:
					result.truth_status = "🟥 Both are incorrect."
		else:
			result.reason = "✔ Facts match: %s = %s" % [fact_a.category, fact_a.value]
			result.truth_status = "🟩 Matching facts — consistent."
	else:
		result.reason = "⚠ Different categories: cannot compare directly."
		result.truth_status = "N/A"

	return result


# --- Show result on screen ---
func _show_result(result: Dictionary):
	var text = result.reason
	if result.truth_status != "":
		text += "\n" + result.truth_status

	if result.is_discrepancy:
		result_text.text = "[color=red]%s[/color]" % text
	else:
		result_text.text = "[color=green]%s[/color]" % text


# --- Navigation ---
func _on_next_pressed():
	_display_comparison(current_index + 1)

func _on_prev_pressed():
	_display_comparison(current_index - 1)
