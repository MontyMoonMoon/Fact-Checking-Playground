extends MarginContainer
class_name ArticlePublisherController

var master: Master
var sound_manager: SoundManager
var game_manager: Node = null

@export var laptop: Control

@export_group("Available Articles")
@export var avail_art_container: VBoxContainer

@export_group("Publishing Paper")
@export var article_parts_container: MarginContainer

@export_subgroup("Article 1")
@export var article_part1: MarginContainer
@export var article_part1_label: Label

@export_subgroup("Article 2")
@export var article_part2: MarginContainer
@export var article_part2_label: Label

@export_subgroup("Article 3")
@export var article_part3: MarginContainer
@export var article_part3_label: Label

@export_subgroup("Article 4")
@export var article_part4: MarginContainer
@export var article_part4_label: Label

# HTTP Request - we'll create it dynamically if not in scene
var http_request: HTTPRequest = null

# Data
var articles_data: Array = []
var original_articles_data: Array = []  # Store original articles before removal
var constructed_parts: Array = []
var max_parts: int = 4
var published_article_texts: Array = []  # Track published articles by article_text
const PUBLISHED_ARTICLES_PATH = "user://published_articles.json"

# Part node mapping
var part_nodes: Array = []
var part_label_nodes: Array = []

@onready var avail_article_prefab: PackedScene = preload("res://Prefabs/Components/avail_article.tscn")

func _ready():
	master = get_node("/root/Master")
	
	if master == null:
		print("[Article_publisher_controller._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	if master.sound_manager:
		sound_manager = master.sound_manager
	
	part_nodes = [article_part1, article_part2, article_part3, article_part4]
	part_label_nodes = [article_part1_label, article_part2_label, article_part3_label, article_part4_label]
	
	set_article("none", "")
	_setup_http_request()
	
	# Defer loading until after scene initialization
	call_deferred("_initialize_article_publisher")
	
	visible = false

func _initialize_article_publisher() -> void:
	"""Initialize article publisher - load data after scene is ready"""
	_load_published_articles()
	_load_articles()
	_display_articles_list()

func _setup_http_request():
	"""Setup HTTPRequest node for ML API calls"""
	http_request = get_node_or_null("HTTPRequest")
	if not http_request:
		# Create HTTPRequest as child
		http_request = HTTPRequest.new()
		http_request.name = "HTTPRequest"
		add_child(http_request)
		print("[Article Publisher] Created HTTPRequest node")
	
	if http_request:
		http_request.request_completed.connect(_on_http_request_request_completed)

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		call_deferred("refresh_articles")

func refresh_articles():
	"""Refresh the articles list when app becomes visible"""
	_load_published_articles()
	_load_articles()
	call_deferred("_display_articles_list")

func add_article_to_pool(article_data: Dictionary) -> void:
	"""Add an article directly to the publisher pool (called from evidence bank)"""
	if article_data.is_empty():
		return
	
	var article_text = article_data.get("article_text", "")
	if article_text == "":
		return
	
	# Check if article already exists in pool
	var already_exists = false
	for existing_article in articles_data:
		if existing_article.get("article_text", "") == article_text:
			already_exists = true
			break
	
	# Check if article is published
	var is_published = false
	for published_text in published_article_texts:
		if published_text == article_text:
			is_published = true
			break
	
	# Add to pool if not already present and not published
	if not already_exists and not is_published:
		articles_data.append(article_data.duplicate(true))
		print("Article Publisher: Added article to pool - %s" % article_text)
		
		# Refresh display if visible
		if visible:
			_display_articles_list()
	else:
		if already_exists:
			print("Article Publisher: Article already in pool - %s" % article_text)
		if is_published:
			print("Article Publisher: Article already published - %s" % article_text)

func _load_published_articles():
	"""Load list of published article texts from file"""
	var data = JSONManager.load_json(PUBLISHED_ARTICLES_PATH, [])
	if typeof(data) == TYPE_ARRAY:
		published_article_texts = data
		print("Article Publisher: Loaded %d published articles" % published_article_texts.size())
	else:
		published_article_texts = []

func _save_published_articles():
	"""Save list of published article texts to file"""
	JSONManager.save_json(PUBLISHED_ARTICLES_PATH, published_article_texts)
	print("Article Publisher: Saved %d published articles" % published_article_texts.size())

func _load_articles():
	# Load all cases including additions (from evidence bank)
	var json_manager = JSONManager.get_instance()
	if json_manager:
		articles_data = json_manager.get_all_cases(false)  # Include all, even trashed
	else:
		var file_path = "res://JSONs/dataset.json"
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
	
	# Filter out published articles
	_load_published_articles()
	if published_article_texts.size() > 0:
		var published_set = {}
		for text in published_article_texts:
			published_set[text] = true
		
		var filtered_articles = []
		for article in articles_data:
			var article_text = article.get("article_text", "")
			if article_text != "" and not published_set.has(article_text):
				filtered_articles.append(article)
		
		articles_data = filtered_articles
		# Store original articles for restoration when clearing
		original_articles_data = articles_data.duplicate(true)
		print("Article Publisher: Filtered out %d published articles, %d remaining" % [published_article_texts.size(), articles_data.size()])

func _display_articles_list():
	if not avail_art_container:
		return
	
	# Clear old buttons
	for child in avail_art_container.get_children():
		if child.name != "Control":  
			child.queue_free()
	
	if articles_data.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No articles available"
		empty_label.add_theme_color_override("font_color", Color.BLACK)
		avail_art_container.add_child(empty_label)
		return
	
	for i in range(articles_data.size()):
		var article = articles_data[i]

		# Extract text
		var article_text = article.get("article_text", article.get("headline", article.get("text", "")))
		if article_text.begins_with("Article: "):
			article_text = article_text.substr(9)

		var display_text = article_text if article_text.length() > 0 else "Article %d" % (i + 1)
		if display_text.length() > 50:
			display_text = display_text.substr(0, 47) + "..."

		# Instantiate your UI prefab
		var item_container = avail_article_prefab.instantiate()
		if not item_container:
			push_warning("Failed to instantiate article prefab!")
			continue
		
		# Get the built-in styled button
		var btn := item_container.get_node("Art1") as Button
		if not btn:
			push_warning("Prefab has no Button named 'Art1'!")
			continue
		
		btn.text = display_text
		
		# Connect press
		btn.connect("pressed", Callable(self, "_on_article_selected").bind(i))

		# Add the prefab to the list
		avail_art_container.add_child(item_container)

func _on_article_selected(article_index: int):
	if article_index < 0 or article_index >= articles_data.size():
		print("[Article Publisher] Invalid article index: %d (pool size: %d)" % [article_index, articles_data.size()])
		return
	
	if constructed_parts.size() >= max_parts:
		print("Maximum %d parts allowed! Clear or publish first." % max_parts)
		return
	
	var article = articles_data[article_index].duplicate(true)  # Make a copy
	var article_text = article.get("article_text", "")
	if article_text.begins_with("Article: "):
		article_text = article_text.substr(9)
	
	# Always start from art_1 (index 0) for proper formatting
	var part_index = constructed_parts.size()
	var part_label = ""
	if article.has("headline"):
		part_label = article.get("headline", "")
	elif article_text.length() > 0:
		part_label = article_text.substr(0, min(60, article_text.length()))
	
	# Ensure label text is set properly for Art1 button appearance
	if part_label == "":
		part_label = article_text.substr(0, min(60, article_text.length())) if article_text.length() > 0 else "Article %d" % (part_index + 1)
	
	# Store the original article data for restoration
	constructed_parts.append({
		"index": article_index,
		"text": article_text,
		"article_data": article,
		"label": part_label,
		"original_article": article.duplicate(true)  # Store original for restoration
	})
	
	# Remove the article from available list to prevent duplicate selection
	articles_data.remove_at(article_index)
	
	# Update UI to show the new part - always use art_1, art_2, art_3, art_4 format
	# part_index is 0-based, so first article (index 0) goes to art_1
	var part_key = "art_%d" % (part_index + 1)
	
	print("[Article Publisher] Adding article to part %s with label: %s" % [part_key, part_label])
	
	# Set article immediately
	set_article(part_key, part_label)
	
	# Also set it deferred to ensure it updates after layout
	call_deferred("set_article", part_key, part_label)
	
	# Refresh the articles list display to remove the selected article
	_display_articles_list()

# ---------- BUTTONS ----------
func _on_clear_pressed() -> void:
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
	# Restore articles back to the pool before clearing
	var articles_to_restore = []
	for part in constructed_parts:
		if part.has("original_article"):
			var original_article = part.get("original_article")
			articles_to_restore.append(original_article)
	
	# Clear constructed parts first
	constructed_parts.clear()
	set_article("none", "")
	
	# Reload articles from source to get fresh list
	_load_articles()
	
	# Add back the articles that were being constructed (if not already in the list)
	for article_to_restore in articles_to_restore:
		var article_text = article_to_restore.get("article_text", "")
		if article_text == "":
			continue
		
		# Check if article is already in the list
		var already_exists = false
		for existing_article in articles_data:
			if existing_article.get("article_text", "") == article_text:
				already_exists = true
				break
		
		# Only add if not already present and not published
		if not already_exists:
			var is_published = false
			for published_text in published_article_texts:
				if published_text == article_text:
					is_published = true
					break
			
			if not is_published:
				articles_data.append(article_to_restore)
	
	# Refresh the articles list to show restored articles
	_display_articles_list()
	print("Construction area cleared. %d articles restored to pool." % articles_to_restore.size())

func _on_publish_pressed() -> void:
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
	if constructed_parts.size() == 0:
		print("No parts to publish! Add at least one part.")
		return
	
	if constructed_parts.size() < 2:
		print("Add at least 2 parts to publish an article.")
		return
	
	var full_article_text = ""
	for part in constructed_parts:
		if full_article_text != "":
			full_article_text += " "
		full_article_text += part.text
	
	var overlap_scores = _calculate_semantic_overlaps()
	_send_article_for_analysis(full_article_text, overlap_scores)

# ---------- METHODS ----------
## This function will open the target article part call this function as: set_article("art_1", "wow" or smtg that stores a string)
func set_article(target: String, text: String) -> void:
	match target:
		"art_1": 
			if article_part1:
				article_part1.visible = true
				article_part1.show()
				# Ensure parent containers are visible
				var parent = article_part1.get_parent()
				var depth = 0
				while parent and depth < 5:
					if parent is Control:
						parent.visible = true
					parent = parent.get_parent()
					depth += 1
			if article_part1_label:
				article_part1_label.text = text if text != "" else ""
				article_part1_label.visible = true
				article_part1_label.show()
				print("[Article Publisher] Set art_1 label to: %s" % text)
			else:
				push_warning("[Article Publisher] article_part1_label is null! Cannot set Art1 text.")
		"art_2": 
			if article_part2:
				article_part2.visible = true
				article_part2.show()
			if article_part2_label:
				article_part2_label.text = text
				article_part2_label.visible = true
				article_part2_label.show()
		"art_3": 
			if article_part3:
				article_part3.visible = true
				article_part3.show()
			if article_part3_label:
				article_part3_label.text = text
				article_part3_label.visible = true
				article_part3_label.show()
		"art_4": 
			if article_part4:
				article_part4.visible = true
				article_part4.show()
			if article_part4_label:
				article_part4_label.text = text
				article_part4_label.visible = true
				article_part4_label.show()
		"none": 
			if article_part1:
				article_part1.visible = false
			if article_part2:
				article_part2.visible = false
			if article_part3:
				article_part3.visible = false
			if article_part4:
				article_part4.visible = false
			# Clear all labels
			if article_part1_label:
				article_part1_label.text = ""
			if article_part2_label:
				article_part2_label.text = ""
			if article_part3_label:
				article_part3_label.text = ""
			if article_part4_label:
				article_part4_label.text = ""
	
	# Update visibility based on constructed_parts
	for i in range(max_parts):
		if i < constructed_parts.size():
			# Ensure parts with data are visible
			var part_node = part_nodes[i]
			if part_node:
				part_node.visible = true
				part_node.show()
		else:
			# Hide parts without data
			var part_node = part_nodes[i]
			if part_node:
				part_node.visible = false

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
	
	print("Analyzing article...\nAverage semantic overlap: %.2f%%" % (avg_overlap * 100.0))
	
	http_request.request(
		"http://127.0.0.1:8000/analyze",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		json_str
	)

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_error("ML API request failed: %s" % str(response_code))
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
		
		# Check if verdict indicates fake news - apply penalty
		var verdict_lower = verdict.to_lower()
		var is_fake = verdict_lower.contains("fake") or verdict_lower.contains("likely fake") or verdict_lower.contains("probably fake")
		
		if is_fake:
			# Penalize for publishing fake news
			var fake_penalty = -1.5  # Balanced penalty (reduced from -2.0)
			integrity_increment = fake_penalty
			print("Article Publisher: Published fake news! Applying penalty: %.2f" % fake_penalty)
		
		print("Published Article Analysis:")
		print("Parts used: %d" % constructed_parts.size())
		print("Average semantic overlap: %.2f%%" % (avg_overlap * 100.0))
		print("ML Analysis:")
		print("Random Forest Score: %.2f/10.0" % rf)
		print("Logistic Regression: %.2f/10.0" % log)
		print("Average Score: %.2f/10.0" % avg)
		print("Verdict: %s" % verdict)
		
		if is_fake:
			print("⚠ FAKE NEWS DETECTED! Integrity Penalty: %.2f" % integrity_increment)
		else:
			print("Integrity Score Increment: +%.2f" % integrity_increment)
		
		if game_manager and game_manager.has_method("add_integrity_score"):
			var source = "incorrect_articles_published" if is_fake else "correct_articles_published"
			game_manager.add_integrity_score(integrity_increment, source)
		elif game_manager and game_manager.has_method("add_article_result"):
			var rf_normalized = rf / 10.0
			var log_normalized = log / 10.0
			game_manager.add_article_result(rf_normalized, log_normalized)
			if avg_overlap >= 0.7 and game_manager.has_method("add_high_overlap_comparison"):
				game_manager.add_high_overlap_comparison()
		
		# Mark articles as published and save to file
		var newly_published_texts = []
		for part in constructed_parts:
			if part.has("article_data"):
				var article_data = part.article_data
				var article_text = article_data.get("article_text", "")
				if article_text != "" and not published_article_texts.has(article_text):
					published_article_texts.append(article_text)
					newly_published_texts.append(article_text)
		
		if newly_published_texts.size() > 0:
			_save_published_articles()
			print("Article Publisher: Marked %d articles as published" % newly_published_texts.size())
		
		# Clear construction area
		constructed_parts.clear()
		set_article("none", "")
		
		# Refresh articles list to remove published ones
		refresh_articles()

func _calculate_integrity_increment(avg_score: float, avg_overlap: float, part_count: int) -> float:
	"""Calculate integrity score increment based on ML scores and overlap"""
	var base_score = (avg_score / 10.0) * 2.0  # Normalize to 0-2.0 range
	
	# Bonus for using multiple parts (up to +0.5)
	var part_bonus = min(part_count * 0.125, 0.5)
	
	# Bonus for high semantic overlap (up to +0.3)
	var overlap_bonus = 0.0
	if avg_overlap >= 0.5:
		overlap_bonus = min((avg_overlap - 0.5) * 0.6, 0.3)
	
	# Penalty for low overlap (indicating conflicting information)
	var overlap_penalty = 0.0
	if avg_overlap < 0.3:
		overlap_penalty = (0.3 - avg_overlap) * 0.5
	
	return base_score + part_bonus + overlap_bonus - overlap_penalty

func set_game_manager(manager: Node):
	game_manager = manager
