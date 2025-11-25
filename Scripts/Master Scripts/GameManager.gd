extends Node
class_name GameManager

signal integrity_changed(new_score: float)
signal day_complete(final_score: float)
signal game_over(reason: String)

var game_timer: GameTimer = null
var integrity_meter: Node = null
var game_failed_popup: Node = null
var article_popup_scene: PackedScene = null

var integrity_score: float = 5.0
var _last_reported_integrity_score: float = 5.0
var integrity_breakdown: Dictionary = {}

var articles_analyzed: Array = []
var articles_added: Array = []
var articles_removed: Array = []
var high_overlap_comparisons: int = 0

var day_over: bool = false
var instant_death: bool = false

var current_article_popups: Array = []

# Integrity decay
var integrity_decay_timer: Timer = null
var integrity_decay_rate: float = 0.1  # Lose 0.1 integrity every 30 seconds
var integrity_decay_interval: float = 30.0  # Decay every 30 seconds

func _ready():
	print("GameManager initialized")
	
	# Load popup scenes
	article_popup_scene = load("res://Prefabs/Components/article_popup.tscn") as PackedScene
	
	if not article_popup_scene:
		push_warning("Could not load article_popup.tscn")
	
	# Setup integrity decay timer
	_setup_integrity_decay()
	
	# Wait a frame to ensure scene is fully loaded
	await get_tree().process_frame
	
	# Find GameFailedPopup - try multiple methods
	_find_and_hide_game_failed_popup()
	
	# Timer will be set by scene
	# AI Analysis Controller is now integrated into laptop, no need to load scene

func _find_and_hide_game_failed_popup():
	"""Find GameFailedPopup using multiple search methods"""
	var parent = get_parent()
	if not parent:
		push_error("GameManager has no parent node!")
		return
	
	# Method 1: Direct sibling lookup
	game_failed_popup = parent.get_node_or_null("GameFailedPopup")
	
	# Method 2: Search all siblings
	if not game_failed_popup:
		for child in parent.get_children():
			if child.name == "GameFailedPopup":
				game_failed_popup = child
				break
	
	# Method 3: Recursive search from parent
	if not game_failed_popup:
		game_failed_popup = parent.find_child("GameFailedPopup", true, false)
	
	# Method 4: Search by class name
	if not game_failed_popup:
		for child in parent.get_children():
			if child is GameFailedPopup:
				game_failed_popup = child
				break
	
	# Method 5: Search entire scene tree
	if not game_failed_popup:
		var scene_root = get_tree().current_scene
		if scene_root:
			game_failed_popup = scene_root.find_child("GameFailedPopup", true, false)
	
	if game_failed_popup:
		game_failed_popup.visible = false
		# Force hide immediately to prevent it showing on start
		game_failed_popup.hide()
		print("GameFailedPopup found and hidden successfully")
	else:
		# Debug: Print all children of parent
		var children_names = []
		for child in parent.get_children():
			children_names.append(child.name)
		push_error("GameFailedPopup NOT FOUND. Parent: " + str(parent.name) + " | Children: " + str(children_names))

func _process(delta):
	if day_over:
		return
	
	# Check if timer is up
	if game_timer and game_timer.is_running and game_timer.get_time_remaining() <= 0:
		_evaluate_day()

func set_game_timer(timer: GameTimer):
	game_timer = timer
	if game_timer:
		game_timer.article_spawn_requested.connect(_on_article_spawn_requested)
		game_timer.time_up.connect(_on_time_up)

func set_integrity_meter(meter: Node):
	integrity_meter = meter
	if integrity_meter and integrity_meter.has_method("update_integrity"):
		integrity_meter.update_integrity(integrity_score)

func start_game():
	print("GameManager: Starting new game - resetting all systems")
	day_over = false
	instant_death = false
	articles_analyzed.clear()
	articles_added.clear()
	articles_removed.clear()
	high_overlap_comparisons = 0
	integrity_score = 5.0
	integrity_breakdown = {
		"base_score": 5.0,
		"articles_analyzed_bonus": 0.0,
		"high_overlap_bonus": 0.0,
		"articles_added_bonus": 0.0,
		"articles_removed_penalty": 0.0
	}
	
	# Reset and restart integrity decay timer
	if not integrity_decay_timer or not is_instance_valid(integrity_decay_timer):
		_setup_integrity_decay()
	
	if integrity_decay_timer:
		integrity_decay_timer.stop()
		call_deferred("_start_decay_timer")
		print("GameManager: Integrity decay timer will restart")
	
	# Reset evidence bank for new game
	_reset_evidence_bank()
	
	if game_timer:
		game_timer.start_timer()
	
	_update_integrity_display()
	print("GameManager: Game started successfully")

func _reset_evidence_bank():
	# This will be handled by evidence bank controller itself
	# Just clear any references to published articles
	pass

func _update_integrity_display():
	var previous_score := _last_reported_integrity_score
	if integrity_meter and integrity_meter.has_method("update_integrity"):
		integrity_meter.update_integrity(integrity_score)
	emit_signal("integrity_changed", integrity_score)
	_play_integrity_change_sound(integrity_score - previous_score)
	_last_reported_integrity_score = integrity_score

func _play_integrity_change_sound(delta: float) -> void:
	if absf(delta) < 0.01:
		return
	
	var sm := SoundManager.instance
	if not sm:
		var master_node := get_node_or_null("/root/Master") as Master
		if master_node and master_node.sound_manager:
			sm = master_node.sound_manager
	
	if sm:
		var sound_name := "IntegScoreIncrement" if delta > 0.0 else "IntegScoreDecrement"
		sm.play_sound(sound_name)

func _evaluate_day():
	day_over = true
	
	# Stop integrity decay timer
	if integrity_decay_timer:
		integrity_decay_timer.stop()
		print("GameManager: Integrity decay timer stopped (day over)")
	
	if instant_death:
		emit_signal("game_over", "Integrity dropped to 0")
		return
	
	var final_score = integrity_score
	emit_signal("day_complete", final_score)

func _on_time_up():
	print("GameManager: Time is up!")
	_evaluate_day()

func _on_integrity_decay():
	"""Called periodically to decrease integrity score"""
	if day_over:
		print("[Integrity Decay] Day is over, skipping decay")
		return  # Don't decay if day is over
	
	var old_score = integrity_score
	integrity_score = max(0.0, integrity_score - integrity_decay_rate)
	integrity_breakdown["base_score"] = integrity_score
	_update_integrity_display()
	
	print("[Integrity Decay] Score decreased from %.2f to %.2f (decay rate: %.2f)" % [old_score, integrity_score, integrity_decay_rate])
	
	# Mark as failed but let player continue until end of day
	# game_failed_popup will handle showing the failure at end of day
	if integrity_score <= 0.0 and not instant_death:
		instant_death = true
		print("GameManager: Integrity dropped to 0 - will fail at end of day")

func _setup_integrity_decay():
	"""Setup timer for integrity score decay over time"""
	if integrity_decay_timer and is_instance_valid(integrity_decay_timer):
		integrity_decay_timer.queue_free()
	
	integrity_decay_timer = Timer.new()
	integrity_decay_timer.name = "IntegrityDecayTimer"
	integrity_decay_timer.wait_time = integrity_decay_interval
	integrity_decay_timer.timeout.connect(_on_integrity_decay)
	integrity_decay_timer.autostart = false
	integrity_decay_timer.one_shot = false
	add_child(integrity_decay_timer)
	print("GameManager: Integrity decay timer set up (%.1f every %.1f seconds)" % [integrity_decay_rate, integrity_decay_interval])

func _start_decay_timer():
	"""Start the integrity decay timer (called via call_deferred)"""
	if integrity_decay_timer and is_instance_valid(integrity_decay_timer):
		integrity_decay_timer.start()
		print("GameManager: Integrity decay timer started")

func _on_article_spawn_requested(article_data: Dictionary):
	_spawn_article_popup(article_data)

func _spawn_article_popup(article_data: Dictionary):
	return

func _on_article_added(article_data: Dictionary):
	articles_added.append(article_data)
	print("Article added to queue: ", article_data.get("article_text", "").substr(0, 30))
	_open_article_comparer(article_data)
	_remove_popup_from_list(article_data)

func _on_article_removed(article_data: Dictionary):
	articles_removed.append(article_data)
	integrity_score = max(0.0, integrity_score - 0.5)
	_update_integrity_display()
	print("Article removed: ", article_data.get("article_text", "").substr(0, 30))
	_remove_popup_from_list(article_data)

func _on_popup_closed(article_data: Dictionary):
	integrity_score = max(0.0, integrity_score - 0.2)
	_update_integrity_display()
	print("Popup closed: ", article_data.get("article_text", "").substr(0, 30))
	_remove_popup_from_list(article_data)

func _remove_popup_from_list(article_data: Dictionary):
	for i in range(current_article_popups.size() - 1, -1, -1):
		if not is_instance_valid(current_article_popups[i]):
			current_article_popups.remove_at(i)

func _open_article_comparer(article_data: Dictionary):
	var laptop = _find_laptop()
	if laptop and laptop.has_method("get_ai_analysis_controller"):
		var ai_controller = laptop.get_ai_analysis_controller()
		if ai_controller:
			if laptop.has_method("_on_screen_pressed"):
				if not laptop.laptop_screen_in:
					laptop._on_screen_pressed()
			if laptop.has_method("set_app"):
				laptop.set_app("ai_analysis")
			ai_controller.load_article(article_data)
			return
	var existing = get_tree().get_first_node_in_group("article_comparer")
	if existing and is_instance_valid(existing):
		if existing.has_method("load_article"):
			existing.load_article(article_data)
		return
	push_warning("Could not find AI Analysis Controller to load article")

func _find_laptop() -> Node:
	var scene_root = get_tree().current_scene
	if scene_root:
		var components = scene_root.get_node_or_null("Contents/ComponentsContainer/Laptop/Laptop")
		if components:
			return components
		return _find_node_with_method(scene_root, "get_ai_analysis_controller")
	return null

func _find_node_with_method(node: Node, method_name: String) -> Node:
	if node.has_method(method_name):
		return node
	for child in node.get_children():
		var result = _find_node_with_method(child, method_name)
		if result:
			return result
	return null

func add_article_result(rf_score: float, lr_score: float):
	var avg_score = (rf_score + lr_score) / 2.0
	articles_analyzed.append(avg_score)
	_recalculate_integrity()
	_update_integrity_display()

func add_high_overlap_comparison():
	high_overlap_comparisons += 1
	integrity_score = min(10.0, integrity_score + 0.8)
	_update_integrity_display()

func add_integrity_score(increment: float):
	integrity_score = min(10.0, integrity_score + increment)
	_update_integrity_display()

func _recalculate_integrity():
	var base = integrity_breakdown.get("base_score", 5.0)
	if instant_death and integrity_score <= 0.0:
		base = 0.0
	var analyzed_bonus = 0.0
	if articles_analyzed.size() > 0:
		var sum_total = 0.0
		for t in articles_analyzed:
			sum_total += t
		var avg_score = (sum_total / articles_analyzed.size()) * 10.0
		analyzed_bonus = avg_score - base
	var overlap_bonus = high_overlap_comparisons * 0.8
	var added_bonus = articles_added.size() * 0.25
	var removed_penalty = articles_removed.size() * 0.5
	integrity_score = base + analyzed_bonus + overlap_bonus + added_bonus - removed_penalty
	integrity_score = clamp(integrity_score, 0.0, 10.0)
	integrity_breakdown = {
		"base_score": base,
		"articles_analyzed_bonus": analyzed_bonus,
		"high_overlap_bonus": overlap_bonus,
		"articles_added_bonus": added_bonus,
		"articles_removed_penalty": removed_penalty
	}
