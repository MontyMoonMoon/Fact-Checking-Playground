extends Node
class_name GameTimer

# Signals
signal time_up
signal article_spawn_requested(article_data: Dictionary)
signal timer_updated(time_text: String)

# Timer settings
@export var time_limit: float = 500.0  # 5 minutes in seconds || CHANGE IN ACCORDANCE TO USE
@export var article_spawn_interval_min: float = 10.0  # Minimum time between articles
@export var article_spawn_interval_max: float = 20.0  # Maximum time between articles

# State
var time_remaining: float = 0.0
var is_running: bool = false
var next_spawn_time: float = 0.0
var articles_pool: Array = []
var used_articles: Array = []

@onready var timer_label: Label = null

func _ready():
	time_remaining = time_limit
	# Don't load articles in _ready() - wait until start_timer() when map is properly set
	# Timer should respect game pause state
	process_mode = Node.PROCESS_MODE_INHERIT

func _process(delta):
	if not is_running:
		return
	
	time_remaining -= delta
	next_spawn_time -= delta
	
	# Update timer display
	var minutes = int(time_remaining) / 60
	var seconds = int(time_remaining) % 60
	var time_text = "%02d:%02d" % [minutes, seconds]
	
	if timer_label:
		timer_label.text = time_text
	
	# Emit signal for other time displays (like laptop)
	emit_signal("timer_updated", time_text)
	
	
	# Check if time is up
	if time_remaining <= 0.0:
		time_remaining = 0.0
		is_running = false
		emit_signal("time_up")
		return
	
	# Spawn article if it's time
	if next_spawn_time <= 0.0:
		_spawn_article()

func start_timer():
	is_running = true
	time_remaining = time_limit
	next_spawn_time = randf_range(article_spawn_interval_min, article_spawn_interval_max)
	
	# Always reload articles when starting timer to ensure correct map
	# Clear old articles first to prevent mixing maps
	articles_pool.clear()
	used_articles.clear()
	_load_articles()
	
	# Verify all articles are for the correct map
	var current_map = _get_current_map()
	var wrong_map_count = 0
	for article in articles_pool:
		var article_map = article.get("map", "")
		if article_map != current_map:
			wrong_map_count += 1
	
	if wrong_map_count > 0:
		push_error("[GameTimer] Found %d articles from wrong map! Clearing pool." % wrong_map_count)
		articles_pool.clear()
		used_articles.clear()
	
	# If pool is still empty after reload, log warning
	if articles_pool.is_empty():
		push_warning("[GameTimer] No articles loaded for current map!")
	
	# Ensure next_spawn_time is valid
	if next_spawn_time <= 0.0:
		next_spawn_time = randf_range(article_spawn_interval_min, article_spawn_interval_max)
	
	# Emit initial time update
	var minutes = int(time_remaining) / 60
	var seconds = int(time_remaining) % 60
	var time_text = "%02d:%02d" % [minutes, seconds]
	if timer_label:
		timer_label.text = time_text
	emit_signal("timer_updated", time_text)

func stop_timer():
	is_running = false

func pause_timer():
	"""Pause the timer without resetting it"""
	is_running = false

func resume_timer():
	"""Resume the timer from where it left off"""
	if time_remaining > 0.0:
		is_running = true

func set_timer_label(label: Label):
	timer_label = label

func _load_articles():
	# Load articles from email_news.json using map-specific sections (same as emails)
	# Use FileAccess directly to avoid any caching issues
	var file_path = "res://JSONs/email_news.json"
	
	if not FileAccess.file_exists(file_path):
		push_error("[GameTimer] Email news file not found at %s" % file_path)
		articles_pool = []
		return
	
	# Read file directly to avoid caching
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[GameTimer] Could not open email_news.json")
		articles_pool = []
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[GameTimer] Failed to parse email_news.json: %s" % json.get_error_message())
		articles_pool = []
		return
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[GameTimer] Invalid JSON format: expected dictionary, got %s" % typeof(data))
		articles_pool = []
		return
	
	# Get current map and load map-specific articles
	var current_map = _get_current_map()
	
	if data.has(current_map):
		var map_emails = data[current_map]
		
		# CRITICAL: Verify we're getting an array and it's the right section
		if typeof(map_emails) != TYPE_ARRAY:
			push_error("[GameTimer] %s section is not an array! Got type: %s" % [current_map, typeof(map_emails)])
			articles_pool = []
			return
		
		# Extract article data from email news_data
		articles_pool = []
		for email_item in map_emails:
			if typeof(email_item) != TYPE_DICTIONARY:
				continue
			
			var news_data = email_item.get("news_data", {})
			if news_data.is_empty():
				continue
			
			# Create article data structure from email news_data
			var article_data = {
				"article_text": news_data.get("article_text", ""),
				"tip_text": news_data.get("tip_text", ""),
				"facts": news_data.get("facts", []),
				"stance": news_data.get("stance", "Neutral"),
				"integrity_score": news_data.get("integrity_score", 0.5),
				"sender": email_item.get("sender", ""),
				"subject": email_item.get("subject", ""),
				"map": current_map  # Explicitly tag with current map
			}
			
			# Only add if it has article text
			if article_data["article_text"] != "":
				articles_pool.append(article_data)
	else:
		push_error("[GameTimer] No articles found for map '%s' in email_news.json" % current_map)
		articles_pool = []

func _get_current_map() -> String:
	# PRIORITY 1: For new games, force map_01 (articles pool empty means new game)
	if articles_pool.is_empty():
		if DataManager:
			DataManager.current_map = "map_01"
			DataManager.save_data()
		return "map_01"
	
	# PRIORITY 2: Try to detect from scene tree structure
	var scene_tree = get_tree()
	if scene_tree:
		# Check root's children for map nodes
		var root = scene_tree.root
		if root:
			for child in root.get_children():
				var child_name = child.name
				if child_name in ["map_01", "map_02", "map_03"]:
					if DataManager:
						if DataManager.current_map != child_name:
							DataManager.current_map = child_name
							DataManager.save_data()
					return child_name
	
	# PRIORITY 3: Use DataManager if it's valid
	if DataManager and DataManager.current_map in ["map_01", "map_02", "map_03"]:
		return DataManager.current_map
	else:
		# DataManager has invalid data, force map_01
		if DataManager:
			DataManager.current_map = "map_01"
			DataManager.save_data()
		return "map_01"


func _spawn_article():
	if articles_pool.is_empty():
		# Reset pool if all articles used - but verify map first!
		if not used_articles.is_empty():
			var current_map = _get_current_map()
			var valid_articles = []
			for article in used_articles:
				var article_map = article.get("map", "")
				if article_map == current_map:
					valid_articles.append(article)
				else:
					push_warning("[GameTimer] Discarding article from wrong map during reset: %s (expected %s)" % [article_map, current_map])
			
			articles_pool = valid_articles
			used_articles.clear()
	
	if articles_pool.is_empty():
		# Only warn once per timer start to avoid spam
		if not used_articles.is_empty():
			# Articles were used up, silently reset pool
			var current_map = _get_current_map()
			var valid_articles = []
			for article in used_articles:
				var article_map = article.get("map", "")
				if article_map == current_map:
					valid_articles.append(article)
			articles_pool = valid_articles
			used_articles.clear()
			if articles_pool.is_empty():
				return  # Still empty after reset, don't spam
		else:
			return  # No articles available, don't spam
	
	# Pick random article
	var index = randi() % articles_pool.size()
	var article = articles_pool[index]
	
	articles_pool.remove_at(index)
	used_articles.append(article)
	
	# Emit signal to spawn popup
	emit_signal("article_spawn_requested", article)
	
	# Schedule next spawn
	next_spawn_time = randf_range(article_spawn_interval_min, article_spawn_interval_max)

func get_time_remaining() -> float:
	return time_remaining

func get_time_elapsed() -> float:
	return time_limit - time_remaining

func reduce_time(seconds: float) -> void:
	"""Reduce time remaining by specified seconds (for debugging)"""
	if is_running:
		time_remaining = max(0.0, time_remaining - seconds)
		
		# Update display immediately
		var minutes = int(time_remaining) / 60
		var secs = int(time_remaining) % 60
		var time_text = "%02d:%02d" % [minutes, secs]
		if timer_label:
			timer_label.text = time_text
		emit_signal("timer_updated", time_text)
		
		# Check if time is up
		if time_remaining <= 0.0:
			time_remaining = 0.0
			is_running = false
			emit_signal("time_up")
