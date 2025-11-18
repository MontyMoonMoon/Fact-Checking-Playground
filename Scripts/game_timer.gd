extends Node
class_name GameTimer

# Signals
signal time_up
signal article_spawn_requested(article_data: Dictionary)
signal timer_updated(time_text: String)

# Timer settings
@export var time_limit: float = 300.0  # 5 minutes in seconds
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
	_load_articles()
	# Make timer run even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	
	# Debug logging every second
	#if int(time_remaining) != int(time_remaining + delta):
		#print("[TIMER DEBUG] Time remaining: %.1f seconds (%.2f:%.2d)" % [time_remaining, minutes, seconds])
		#print("[TIMER DEBUG] Timer running: %s, Label set: %s" % [is_running, timer_label != null])
	
	# Check if time is up
	if time_remaining <= 0.0:
		time_remaining = 0.0
		is_running = false
		print("[TIMER DEBUG] Time is up!")
		emit_signal("time_up")
		return
	
	# Spawn article if it's time
	if next_spawn_time <= 0.0:
		_spawn_article()

func start_timer():
	is_running = true
	time_remaining = time_limit
	next_spawn_time = randf_range(article_spawn_interval_min, article_spawn_interval_max)
	
	# Emit initial time update
	var minutes = int(time_remaining) / 60
	var seconds = int(time_remaining) % 60
	var time_text = "%02d:%02d" % [minutes, seconds]
	if timer_label:
		timer_label.text = time_text
		print("[TIMER DEBUG] Timer label updated to: %s" % time_text)
	else:
		print("[TIMER DEBUG] WARNING: Timer label is null!")
	emit_signal("timer_updated", time_text)
	
	print("[TIMER DEBUG] Game timer started: %d seconds, is_running: %s, process_mode: %d" % [time_limit, is_running, process_mode])

func stop_timer():
	is_running = false
	print("Game timer stopped")

func set_timer_label(label: Label):
	timer_label = label

func _load_articles():
	var json_manager = JSONManager.get_instance()
	if json_manager:
		articles_pool = json_manager.get_dataset_cases()
		print("Loaded %d articles for game timer" % articles_pool.size())
	else:
		var data = JSONManager.load_json("res://dataset.json", {})
		if typeof(data) == TYPE_DICTIONARY and data.has("cases"):
			articles_pool = data["cases"].duplicate()
			print("Loaded %d articles for game timer (fallback)" % articles_pool.size())
		else:
			articles_pool = []

func _spawn_article():
	if articles_pool.is_empty():
		# Reset pool if all articles used
		if not used_articles.is_empty():
			articles_pool = used_articles.duplicate()
			used_articles.clear()
	
	if articles_pool.is_empty():
		push_warning("No articles available to spawn")
		return
	
	# Pick random article
	var index = randi() % articles_pool.size()
	var article = articles_pool[index]
	articles_pool.remove_at(index)
	used_articles.append(article)
	
	# Emit signal to spawn popup
	emit_signal("article_spawn_requested", article)
	
	# Schedule next spawn
	next_spawn_time = randf_range(article_spawn_interval_min, article_spawn_interval_max)
	print("Article spawned. Next in %.1f seconds" % next_spawn_time)

func get_time_remaining() -> float:
	return time_remaining

func get_time_elapsed() -> float:
	return time_limit - time_remaining
