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
var last_published_overlap_scores: Array = []  # Store overlap scores for ML analysis
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
	"""Initialize article publisher - start empty, will be populated by reset_for_new_game"""
	# Don't load articles here - they will be loaded after reset_for_new_game or when refresh_articles is called
	# This prevents articles from appearing on new game start
	_load_published_articles()  # Only load published list, not articles themselves
	articles_data.clear()
	# Clear cache to ensure fresh start
	var json_manager = JSONManager.get_instance()
	if json_manager:
		json_manager.dataset_additions_cache.clear()
	print("[Article Publisher Controller] Initialized - starting empty")

func _setup_http_request():
	"""Setup HTTPRequest node for ML API calls"""
	http_request = get_node_or_null("HTTPRequest")
	if not http_request:
		# Create HTTPRequest as child
		http_request = HTTPRequest.new()
		http_request.name = "HTTPRequest"
		add_child(http_request)
	
	if http_request:
		http_request.request_completed.connect(_on_http_request_request_completed)

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		# Clear cache before refreshing to ensure fresh data
		var json_manager = JSONManager.get_instance()
		if json_manager:
			json_manager.dataset_additions_cache.clear()
		
		# Check if file is actually empty before loading
		var file_check = JSONManager.load_json("user://dataset_additions.json", [])
		if typeof(file_check) == TYPE_ARRAY and file_check.size() == 0:
			# File is empty - don't load, just clear
			articles_data.clear()
			original_articles_data.clear()
			if avail_art_container:
				for child in avail_art_container.get_children():
					child.queue_free()
			print("[Article Publisher] File is empty, staying empty")
			return
		
		call_deferred("refresh_articles")

func refresh_articles():
	"""Refresh the articles list when app becomes visible"""
	_load_published_articles()
	
	# Preserve any articles that were manually added but not yet in dataset_additions
	var existing_articles = {}
	for article in articles_data:
		var article_text = article.get("article_text", "")
		if article_text != "":
			existing_articles[article_text] = article
	
	# Always reload from dataset_additions.json to get latest player-added articles
	# Don't load from base dataset - only show articles that were explicitly added
	# Force fresh load by clearing cache first
	var json_manager = JSONManager.get_instance()
	var loaded_articles = []
	if json_manager:
		json_manager.dataset_additions_cache.clear()
		# Read directly from file to bypass cache
		var file_data = JSONManager.load_json("user://dataset_additions.json", [])
		if typeof(file_data) == TYPE_ARRAY:
			loaded_articles = file_data.duplicate(true)
			# Update cache with what we read
			json_manager.dataset_additions_cache = file_data.duplicate(true)
			print("[Article Publisher] refresh_articles: Read %d articles directly from file" % file_data.size())
		else:
			loaded_articles = []
			json_manager.dataset_additions_cache = []
			print("[Article Publisher] refresh_articles: File is empty or invalid")
	else:
		# Fallback: manual loading - force fresh read
		var additions = JSONManager.load_json("user://dataset_additions.json", [])
		if typeof(additions) == TYPE_ARRAY:
			loaded_articles = additions.duplicate(true)
			print("[Article Publisher] refresh_articles: Read %d articles (fallback)" % additions.size())
		else:
			loaded_articles = []
			print("[Article Publisher] refresh_articles: File is empty (fallback)")
	
	# Merge loaded articles with existing manually added articles
	var all_articles = loaded_articles.duplicate(true)
	for article_text in existing_articles:
		var exists = false
		for article in all_articles:
			if article.get("article_text", "") == article_text:
				exists = true
				break
		if not exists:
			all_articles.append(existing_articles[article_text])
	
	articles_data = all_articles
	
	# Filter out published articles
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
		original_articles_data = articles_data.duplicate(true)
	
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
		
		# Save to dataset_additions.json so it persists
		var json_manager = JSONManager.get_instance()
		if json_manager:
			json_manager.add_to_dataset_additions(article_data)
		else:
			# Fallback: manual save
			var additions = JSONManager.load_json("user://dataset_additions.json", [])
			var exists_in_file = false
			for addition in additions:
				if addition.get("article_text", "") == article_text:
					exists_in_file = true
					break
			if not exists_in_file:
				additions.append(article_data.duplicate(true))
				JSONManager.save_json("user://dataset_additions.json", additions)
		
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
	else:
		published_article_texts = []

func _save_published_articles():
	"""Save list of published article texts to file"""
	JSONManager.save_json(PUBLISHED_ARTICLES_PATH, published_article_texts)

func reset_for_new_game() -> void:
	"""Reset article publisher for new game - clear all articles"""
	articles_data.clear()
	original_articles_data.clear()
	published_article_texts.clear()
	
	# Clear published articles file
	var file = FileAccess.open(PUBLISHED_ARTICLES_PATH, FileAccess.WRITE)
	if file:
		file.store_string("[]")
		file.close()
	
	# Clear dataset_additions.json to ensure fresh start
	var json_manager = JSONManager.get_instance()
	if json_manager:
		json_manager.clear_dataset_additions()
		# Also clear cache explicitly
		json_manager.dataset_additions_cache.clear()
	else:
		var additions_file = FileAccess.open("user://dataset_additions.json", FileAccess.WRITE)
		if additions_file:
			additions_file.store_string("[]")
			additions_file.close()
	
	# Clear UI
	if avail_art_container:
		for child in avail_art_container.get_children():
			child.queue_free()
	
	# Don't call _display_articles_list() here - it will be called when app becomes visible
	print("[Article Publisher Controller] Reset for new game - article pool cleared and empty")
	
	# Clear article parts
	for i in range(max_parts):
		if i < part_label_nodes.size() and part_label_nodes[i]:
			part_label_nodes[i].text = ""
	
	constructed_parts.clear()
	
	# Don't clear dataset_additions.json here - it's already cleared by map_0
	# Just ensure articles_data stays empty until articles are added
	print("[Article Publisher Controller] Reset for new game - article pool cleared and empty")

func _load_articles():
	# Only load from dataset_additions.json (player-added articles)
	# Don't load from base dataset - on new game, start empty
	# Force fresh load by clearing cache first
	var json_manager = JSONManager.get_instance()
	var loaded_articles = []
	
	if json_manager:
		json_manager.dataset_additions_cache.clear()
		# Read directly from file to bypass cache
		var file_data = JSONManager.load_json("user://dataset_additions.json", [])
		if typeof(file_data) == TYPE_ARRAY:
			loaded_articles = file_data.duplicate(true)
			# Update cache with what we read
			json_manager.dataset_additions_cache = file_data.duplicate(true)
			print("[Article Publisher] _load_articles: Read %d articles directly from file" % file_data.size())
		else:
			loaded_articles = []
			json_manager.dataset_additions_cache = []
			print("[Article Publisher] _load_articles: File is empty or invalid")
	else:
		# Fallback: manual loading - force fresh read
		var additions = JSONManager.load_json("user://dataset_additions.json", [])
		if typeof(additions) == TYPE_ARRAY:
			loaded_articles = additions.duplicate(true)
			print("[Article Publisher] _load_articles: Read %d articles (fallback)" % additions.size())
		else:
			loaded_articles = []
			print("[Article Publisher] _load_articles: File is empty (fallback)")
	
	articles_data = loaded_articles
	
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
		original_articles_data = articles_data.duplicate(true)

func _display_articles_list():
	if not avail_art_container:
		return
	
	# Clear old buttons
	for child in avail_art_container.get_children():
		if child.name != "Control":  
			child.queue_free()
	
	var tahoma_font = preload("res://Assets/Fonts/windows-xp-tahoma.otf")
	
	if articles_data.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No articles available"
		empty_label.add_theme_color_override("font_color", Color.BLACK)
		empty_label.add_theme_font_override("font", tahoma_font)
		empty_label.add_theme_font_size_override("font_size", 32) 
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
	master.sound_manager.play_sound("mouse_click")
	if article_index < 0 or article_index >= articles_data.size():
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
	
	# Calculate overlap scores before clearing constructed_parts
	var overlap_scores = _calculate_semantic_overlaps()
	last_published_overlap_scores = overlap_scores
	
	# Immediately publish articles (don't wait for API)
	_publish_articles_immediately()
	
	# Try to get ML analysis in background (non-blocking)
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

func _publish_articles_immediately() -> void:
	"""Immediately publish articles and clear construction area - doesn't wait for API"""
	# Mark articles as published
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
		print("[Article Publisher] Published %d article(s) immediately" % newly_published_texts.size())
	
	# Clear construction area
	constructed_parts.clear()
	set_article("none", "")
	
	# Refresh articles list to remove published ones
	refresh_articles()
	
	# Give default reward immediately (will be adjusted if API responds)
	if game_manager and game_manager.has_method("add_integrity_score"):
		game_manager.add_integrity_score(1.0, "correct_articles_published")

func _send_article_for_analysis(article_text: String, overlap_scores: Array):
	if not http_request:
		# HTTP request not available - publishing already happened, just return
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
	# Articles are already published - this is just for adjusting the score based on ML analysis
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var response = JSON.parse_string(body.get_string_from_utf8())
		if typeof(response) == TYPE_DICTIONARY:
			var rf = response.get("random_forest_score", 0.0)
			var log = response.get("logistic_regression_score", 0.0)
			var avg = response.get("average_score", 0.0)
			var verdict = response.get("result", "Unknown")
			
			# Calculate average overlap from stored scores
			var avg_overlap = 0.0
			var part_count = 2  # Minimum parts required
			if last_published_overlap_scores.size() > 0:
				var total = 0.0
				for overlap_data in last_published_overlap_scores:
					total += overlap_data.get("overlap", 0.0)
				avg_overlap = total / last_published_overlap_scores.size()
				# Estimate part count from overlap scores (n parts = n*(n-1)/2 pairs)
				# Solve: n*(n-1)/2 = overlap_scores.size() for n
				var discriminant = 1.0 + 8.0 * last_published_overlap_scores.size()
				part_count = int((1.0 + sqrt(discriminant)) / 2.0)
			
			var integrity_increment = _calculate_integrity_increment(avg, avg_overlap, part_count)
			
			# Check if verdict indicates fake news - apply penalty
			var verdict_lower = verdict.to_lower()
			var is_fake = verdict_lower.contains("fake") or verdict_lower.contains("likely fake") or verdict_lower.contains("probably fake")
			
			if is_fake:
				# Adjust score: remove default reward and apply penalty
				# Since we already gave +1.0, we need to subtract that and add penalty
				var fake_penalty = -2.5  # -1.5 penalty + -1.0 to remove default reward
				if game_manager and game_manager.has_method("add_integrity_score"):
					game_manager.add_integrity_score(fake_penalty, "incorrect_articles_published")
			else:
				# Adjust score based on ML analysis (replace default +1.0 with calculated value)
				var score_adjustment = integrity_increment - 1.0  # Subtract default, add calculated
				if game_manager and game_manager.has_method("add_integrity_score"):
					game_manager.add_integrity_score(score_adjustment, "correct_articles_published")
			
			print("[Article Publisher] ML Analysis complete - Score: %.2f, Verdict: %s" % [integrity_increment, verdict])
	else:
		# API failed - default reward already applied in _publish_articles_immediately
		push_warning("ML API request failed: %s (code: %d). Using default reward." % [str(result), response_code])

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
