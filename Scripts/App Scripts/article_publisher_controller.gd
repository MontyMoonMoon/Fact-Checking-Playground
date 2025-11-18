extends MarginContainer
class_name ArticlePublisherController

@onready var scroll_area: ScrollContainer = $ScrollableArea
@onready var content_container: HBoxContainer = $ScrollableArea/ContentContainer
@onready var articles_list_container: VBoxContainer = $ScrollableArea/ContentContainer/LeftPanel/ArticlesListContainer
@onready var construction_area: VBoxContainer = $ScrollableArea/ContentContainer/RightPanel/ConstructionArea
@onready var publish_button: Button = $ScrollableArea/ContentContainer/RightPanel/ButtonSection/PublishButton
@onready var clear_button: Button = $ScrollableArea/ContentContainer/RightPanel/ButtonSection/ClearButton
@onready var result_label: RichTextLabel = $ScrollableArea/ContentContainer/RightPanel/ResultSection/ResultLabel
@onready var http_request: HTTPRequest = $HTTPRequest

var articles_data: Array = []
var constructed_parts: Array = []
var max_parts: int = 4
var game_manager: Node = null

func _ready():
	visible = false
	if publish_button:
		publish_button.pressed.connect(_on_publish_pressed)
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	if http_request:
		http_request.request_completed.connect(_on_http_request_request_completed)
	if result_label:
		result_label.bbcode_enabled = true
	_load_articles()

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		call_deferred("refresh_articles")

func refresh_articles():
	# Ensure nodes are found
	if not articles_list_container:
		articles_list_container = get_node_or_null("ScrollableArea/ContentContainer/LeftPanel/ArticlesListContainer")
	if not scroll_area:
		scroll_area = get_node_or_null("ScrollableArea")
	if not content_container:
		content_container = get_node_or_null("ScrollableArea/ContentContainer")
	
	# Ensure containers are visible
	if scroll_area:
		scroll_area.visible = true
	if content_container:
		content_container.visible = true
		var left_panel = content_container.get_node_or_null("LeftPanel")
		if left_panel:
			left_panel.visible = true
	if articles_list_container:
		articles_list_container.visible = true
	
	# Load and display articles
	_load_articles()
	call_deferred("_display_articles_list")
	
	# Force layout update
	if articles_list_container:
		call_deferred("_force_layout_update")

func _load_articles():
	# Load all cases including additions (from evidence bank)
	var json_manager = JSONManager.get_instance()
	if json_manager:
		articles_data = json_manager.get_all_cases(false)  # Include all, even trashed
	else:
		var file_path = "res://dataset.json"
		var data = JSONManager.load_json(file_path, {})
		if typeof(data) == TYPE_DICTIONARY and data.has("cases"):
			articles_data = data["cases"]
		else:
			articles_data = []
		
		# Also load additions
		var additions = JSONManager.load_json("user://dataset_additions.json", [])
		if typeof(additions) == TYPE_ARRAY:
			var existing_texts = {}
			for case in articles_data:
				var article_text = case.get("article_text", "")
				if article_text != "":
					existing_texts[article_text] = true
			
			for addition in additions:
				var article_text = addition.get("article_text", "")
				if article_text != "" and not existing_texts.has(article_text):
					articles_data.append(addition)
					existing_texts[article_text] = true

func _display_articles_list():
	if not articles_list_container:
		articles_list_container = get_node_or_null("ScrollableArea/ContentContainer/LeftPanel/ArticlesListContainer")
		if not articles_list_container:
			return
	
	# Ensure container is visible
	articles_list_container.visible = true
	var left_panel = articles_list_container.get_parent()
	if left_panel:
		left_panel.visible = true
	
	# Clear existing buttons
	for child in articles_list_container.get_children():
		child.queue_free()
	
	if articles_data.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No articles loaded"
		empty_label.add_theme_color_override("font_color", Color.WHITE)
		articles_list_container.add_child(empty_label)
		return
	
	# Create buttons for each article
	for i in range(articles_data.size()):
		var article = articles_data[i]
		var btn = Button.new()
		
		# Get article text - handle different possible formats
		var article_text = ""
		if article.has("article_text"):
			article_text = article.get("article_text", "")
		elif article.has("headline"):
			article_text = article.get("headline", "")
		elif article.has("text"):
			article_text = article.get("text", "")
		
		if article_text.begins_with("Article: "):
			article_text = article_text.substr(9)
		
		var display_text = article_text if article_text.length() > 0 else "Article %d" % (i + 1)
		if display_text.length() > 50:
			display_text = display_text.substr(0, 47) + "..."
		
		btn.text = display_text
		btn.custom_minimum_size = Vector2(0, 40)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.visible = true
		btn.connect("pressed", Callable(self, "_on_article_selected").bind(i))
		articles_list_container.add_child(btn)

func _on_article_selected(article_index: int):
	if article_index < 0 or article_index >= articles_data.size():
		return
	
	if constructed_parts.size() >= max_parts:
		if result_label:
			result_label.text = "[color=red]Maximum %d parts allowed! Clear or publish first.[/color]" % max_parts
		return
	
	var article = articles_data[article_index]
	var article_text = article.get("article_text", "")
	if article_text.begins_with("Article: "):
		article_text = article_text.substr(9)
	
	constructed_parts.append({
		"index": article_index,
		"text": article_text,
		"article_data": article
	})
	
	_update_construction_area()

func _update_construction_area():
	if not construction_area:
		return
	
	for child in construction_area.get_children():
		child.queue_free()
	
	for i in range(constructed_parts.size()):
		var part = constructed_parts[i]
		var part_panel = Panel.new()
		part_panel.custom_minimum_size = Vector2(0, 80)
		
		var vbox = VBoxContainer.new()
		part_panel.add_child(vbox)
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.offset_left = 10
		vbox.offset_top = 5
		vbox.offset_right = -10
		vbox.offset_bottom = -5
		
		var label = Label.new()
		var display_text = part.text.substr(0, min(60, part.text.length()))
		if part.text.length() > 60:
			display_text += "..."
		label.text = "Part %d: %s" % [i + 1, display_text]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(label)
		
		var remove_btn = Button.new()
		remove_btn.text = "Remove"
		remove_btn.custom_minimum_size = Vector2(0, 25)
		remove_btn.connect("pressed", Callable(self, "_on_remove_part").bind(i))
		vbox.add_child(remove_btn)
		
		construction_area.add_child(part_panel)
	
	if constructed_parts.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No parts added. Click articles on the left to add parts."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		construction_area.add_child(empty_label)

func _on_remove_part(part_index: int):
	if part_index < 0 or part_index >= constructed_parts.size():
		return
	constructed_parts.remove_at(part_index)
	_update_construction_area()

func _on_clear_pressed():
	constructed_parts.clear()
	_update_construction_area()
	if result_label:
		result_label.text = "Construction area cleared."

func _on_publish_pressed():
	if constructed_parts.size() == 0:
		if result_label:
			result_label.text = "[color=red]No parts to publish! Add at least one part.[/color]"
		return
	
	if constructed_parts.size() < 2:
		if result_label:
			result_label.text = "[color=red]Add at least 2 parts to publish an article.[/color]"
		return
	
	var full_article_text = ""
	for part in constructed_parts:
		if full_article_text != "":
			full_article_text += " "
		full_article_text += part.text
	
	var overlap_scores = _calculate_semantic_overlaps()
	_send_article_for_analysis(full_article_text, overlap_scores)

func _calculate_semantic_overlaps() -> Array:
	var overlaps = []
	for i in range(constructed_parts.size()):
		for j in range(i + 1, constructed_parts.size()):
			var part_a = constructed_parts[i].text
			var part_b = constructed_parts[j].text
			var overlap = _word_overlap(part_a, part_b)
			overlaps.append({
				"part_a": i,
				"part_b": j,
				"overlap": overlap
			})
	return overlaps

func _word_overlap(a: String, b: String) -> float:
	var words_a_raw = a.to_lower().split(" ", false)
	var words_b_raw = b.to_lower().split(" ", false)
	
	# Convert PackedStringArray to Array and filter empty strings
	var words_a: Array = []
	for w in words_a_raw:
		if w.strip_edges().length() > 0:
			words_a.append(w)
	
	var words_b: Array = []
	for w in words_b_raw:
		if w.strip_edges().length() > 0:
			words_b.append(w)
	
	if words_a.size() == 0 or words_b.size() == 0:
		return 0.0
	
	var common = 0
	var total_unique = {}
	for w in words_a:
		total_unique[w] = true
		if words_b.has(w):
			common += 1
	for w in words_b:
		total_unique[w] = true
	
	var total_words = total_unique.size()
	if total_words == 0:
		return 0.0
	
	return float(common) / float(total_words)

func _send_article_for_analysis(article_text: String, overlap_scores: Array):
	if not http_request:
		return
	
	var avg_overlap = 0.0
	if overlap_scores.size() > 0:
		var total = 0.0
		for overlap_data in overlap_scores:
			total += overlap_data.get("overlap", 0.0)
		avg_overlap = total / overlap_scores.size()
	
	var json_data = {
		"text": article_text,
		"sentiment_score": 0.0,
		"evidence_count": constructed_parts.size(),
		"contradiction_score": 1.0 - avg_overlap,
		"propaganda_pattern_score": 0.5,
		"source_type": "independent",
		"topic": "politics"
	}
	
	var json_str = JSON.stringify(json_data)
	
	if result_label:
		result_label.text = "Analyzing article...\nAverage semantic overlap: %.2f%%" % (avg_overlap * 100.0)
	
	http_request.request(
		"http://127.0.0.1:8000/analyze",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		json_str
	)

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_error("ML API request failed: %s" % str(response_code))
		if result_label:
			result_label.text += "\n\n[color=red]ML API Error: %d[/color]" % response_code
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if typeof(response) == TYPE_DICTIONARY:
		var rf = response.get("random_forest_score", 0.0)
		var log = response.get("logistic_regression_score", 0.0)
		var avg = response.get("average_score", 0.0)
		var verdict = response.get("result", "Unknown")
		
		var overlap_scores = _calculate_semantic_overlaps()
		var avg_overlap = 0.0
		if overlap_scores.size() > 0:
			var total = 0.0
			for overlap_data in overlap_scores:
				total += overlap_data.get("overlap", 0.0)
			avg_overlap = total / overlap_scores.size()
		
		var integrity_increment = _calculate_integrity_increment(avg, avg_overlap, constructed_parts.size())
		
		if result_label:
			var result_text = "[b]Published Article Analysis:[/b]\n\n"
			result_text += "Parts used: %d\n" % constructed_parts.size()
			result_text += "Average semantic overlap: %.2f%%\n\n" % (avg_overlap * 100.0)
			result_text += "[b]ML Analysis:[/b]\n"
			result_text += "RF Score: %.2f | LogReg: %.2f | Avg: %.2f\n" % [rf, log, avg]
			result_text += "Verdict: %s\n\n" % verdict
			result_text += "[color=green]Integrity Score Increment: +%.2f[/color]" % integrity_increment
			result_label.text = result_text
		
		if game_manager and game_manager.has_method("add_integrity_score"):
			game_manager.add_integrity_score(integrity_increment)
		elif game_manager and game_manager.has_method("add_article_result"):
			var rf_normalized = rf / 10.0
			var log_normalized = log / 10.0
			game_manager.add_article_result(rf_normalized, log_normalized)
			if avg_overlap >= 0.7 and game_manager.has_method("add_high_overlap_comparison"):
				game_manager.add_high_overlap_comparison()
		
		constructed_parts.clear()
		_update_construction_area()
	else:
		push_error("Invalid response from ML API")

func _calculate_integrity_increment(ml_avg_score: float, avg_overlap: float, num_parts: int) -> float:
	var ml_bonus = (ml_avg_score / 10.0) * 2.0
	var overlap_bonus = 0.0
	
	if avg_overlap >= 0.9:
		overlap_bonus = 1.5
	elif avg_overlap >= 0.7:
		overlap_bonus = 1.0
	elif avg_overlap >= 0.5:
		overlap_bonus = 0.5
		
	var parts_bonus = min(num_parts * 0.2, 0.8)
	return min(ml_bonus + overlap_bonus + parts_bonus, 5.0)

func set_game_manager(manager: Node):
	game_manager = manager

func _force_layout_update():
	if articles_list_container:
		articles_list_container.queue_sort()
		var left_panel = articles_list_container.get_parent()
		if left_panel:
			left_panel.queue_sort()
		if content_container:
			content_container.queue_sort()
		if scroll_area:
			scroll_area.queue_sort()
