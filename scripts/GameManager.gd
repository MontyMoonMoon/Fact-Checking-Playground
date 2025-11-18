extends Node
class_name GameManager

# References
@onready var game_timer: GameTimer = null
@onready var integrity_meter: Node = null
@onready var game_failed_popup: Control = null
var article_popup_scene: PackedScene = null

# Game state
var articles_analyzed = []
var articles_added = []
var articles_removed = []
var daily_quota = 10
var integrity_score = 5.0  # Start at middle
var day_over = false
var instant_death = false
var current_article_popups: Array = []
var high_overlap_comparisons = 0  # Track articles with high semantic overlap (0.90-1.0)
var integrity_breakdown = {
	"base_score": 5.0,
	"articles_analyzed_bonus": 0.0,
	"high_overlap_bonus": 0.0,
	"articles_added_bonus": 0.0,
	"articles_removed_penalty": 0.0
}

# Integrity decay
var integrity_decay_timer: Timer = null
var integrity_decay_rate: float = 0.1  # Lose 0.1 integrity every 30 seconds
var integrity_decay_interval: float = 30.0  # Decay every 30 seconds

# Signals
signal integrity_changed(new_score: float)
signal day_complete(final_score: float)
signal game_over(reason: String)

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
	print("Game started — analyze articles within time limit.")
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
	
	# Reset evidence bank for new game
	_reset_evidence_bank()
	
	if game_timer:
		game_timer.start_timer()
	
	_update_integrity_display()

func _reset_evidence_bank():
	"""Reset evidence bank when starting a new game"""
	# Clear JSON files for new game
	_reset_game_data_files()
	
	var laptop = _find_laptop()
	if laptop and laptop.has_method("get_evidence_bank_controller"):
		var evidence_controller = laptop.get_evidence_bank_controller()
		if evidence_controller and evidence_controller.has_method("reset_evidence_bank"):
			evidence_controller.reset_evidence_bank()
			print("GameManager: Evidence bank reset for new game")
		else:
			push_warning("GameManager: Evidence bank controller not found or missing reset method")
	else:
		push_warning("GameManager: Could not find laptop to reset evidence bank")

func _reset_game_data_files():
	"""Clear all game data JSON files for new game"""
	var json_manager = JSONManager.get_instance()
	if json_manager and json_manager.has_method("clear_all_game_data"):
		json_manager.clear_all_game_data()
	else:
		# Fallback if JSONManager not found
		JSONManager.clear_json_file("user://collected_infos.json")
		JSONManager.clear_json_file("user://dataset_additions.json")
		JSONManager.clear_json_file("user://trashed_infos.json")

func _start_new_day():
	articles_analyzed.clear()
	articles_added.clear()
	articles_removed.clear()
	integrity_score = 5.0
	instant_death = false
	
	# Restart integrity decay timer
	if integrity_decay_timer:
		integrity_decay_timer.start()
	
	_update_integrity_display()
	print("New day begins! Quota: %d articles" % daily_quota)

func _setup_integrity_decay():
	"""Setup timer for integrity score decay over time"""
	integrity_decay_timer = Timer.new()
	integrity_decay_timer.wait_time = integrity_decay_interval
	integrity_decay_timer.timeout.connect(_on_integrity_decay)
	integrity_decay_timer.autostart = true
	add_child(integrity_decay_timer)
	print("GameManager: Integrity decay timer set up (%.1f every %.1f seconds)" % [integrity_decay_rate, integrity_decay_interval])

func _on_integrity_decay():
	"""Called periodically to decrease integrity score"""
	if day_over:
		return  # Don't decay if day is over
	
	integrity_score = max(0.0, integrity_score - integrity_decay_rate)
	integrity_breakdown["base_score"] = integrity_score
	_update_integrity_display()
	
	# Mark as failed but let player continue until end of day
	# game_failed_popup will handle showing the failure at end of day
	if integrity_score <= 0.0 and not instant_death:
		instant_death = true
		print("GameManager: Integrity dropped to 0 - will fail at end of day")

func _on_article_spawn_requested(article_data: Dictionary):
	# Spawn article popup
	_spawn_article_popup(article_data)

func _spawn_article_popup(article_data: Dictionary):
	# Article popup is currently disabled/placeholder
	# This function is kept for compatibility but does nothing
	# TODO: Re-enable when article_popup.gd is implemented
	return
	
	# Disabled code below:
	# if not article_popup_scene:
	# 	push_error("Article popup scene not loaded")
	# 	return
	# 
	# var popup = article_popup_scene.instantiate()
	# # Add to current scene's root (should be a CanvasLayer)
	# var scene_root = get_tree().current_scene
	# if scene_root:
	# 	scene_root.add_child(popup)
	# 	current_article_popups.append(popup)
	# 	
	# 	popup.article_added.connect(_on_article_added)
	# 	popup.article_removed.connect(_on_article_removed)
	# 	popup.popup_closed.connect(_on_popup_closed)
	# 	
	# 	if popup.has_method("setup"):
	# 		popup.setup(article_data, self)
	# else:
	# 	push_error("No current scene to add popup to")

func _on_article_added(article_data: Dictionary):
	articles_added.append(article_data)
	print("Article added to queue: ", article_data.get("article_text", "").substr(0, 30))
	
	# Open article comparer if not already open
	_open_article_comparer(article_data)
	
	# Remove from current popups
	_remove_popup_from_list(article_data)

func _on_article_removed(article_data: Dictionary):
	articles_removed.append(article_data)
	# Penalize for removing articles without analysis
	integrity_score = max(0.0, integrity_score - 0.5)
	_update_integrity_display()
	print("Article removed: ", article_data.get("article_text", "").substr(0, 30))
	
	_remove_popup_from_list(article_data)

func _on_popup_closed(article_data: Dictionary):
	# Small penalty for closing without action
	integrity_score = max(0.0, integrity_score - 0.2)
	_update_integrity_display()
	print("Popup closed: ", article_data.get("article_text", "").substr(0, 30))
	
	_remove_popup_from_list(article_data)

func _remove_popup_from_list(article_data: Dictionary):
	# Remove popup from current list (will be handled by queue_free)
	for i in range(current_article_popups.size() - 1, -1, -1):
		if not is_instance_valid(current_article_popups[i]):
			current_article_popups.remove_at(i)

func _open_article_comparer(article_data: Dictionary):
	# Try to find laptop and AI Analysis Controller
	var laptop = _find_laptop()
	if laptop and laptop.has_method("get_ai_analysis_controller"):
		var ai_controller = laptop.get_ai_analysis_controller()
		if ai_controller:
			# Open laptop if not already open
			if laptop.has_method("_on_screen_pressed"):
				if not laptop.laptop_screen_in:
					laptop._on_screen_pressed()
			
			# Switch to AI Analysis app
			if laptop.has_method("set_app"):
				laptop.set_app("ai_analysis")
			
			# Load article into AI Analysis Controller
			ai_controller.load_article(article_data)
			return
	
	# Fallback: try to find existing comparer in scene
	var existing = get_tree().get_first_node_in_group("article_comparer")
	if existing and is_instance_valid(existing):
		if existing.has_method("load_article"):
			existing.load_article(article_data)
		return
	
	push_warning("Could not find AI Analysis Controller to load article")

func _find_laptop() -> Node:
	# Search for laptop in current scene
	var scene_root = get_tree().current_scene
	if scene_root:
		# Try to find laptop node - it should be in the ComponentsContainer
		var components = scene_root.get_node_or_null("Contents/ComponentsContainer/Laptop/Laptop")
		if components:
			return components
		
		# Alternative: search by checking if node has Laptop methods
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
	print("[INTEGRITY DEBUG] ===== Article Result Added =====")
	print("[INTEGRITY DEBUG] RF Score: %.4f, LR Score: %.4f" % [rf_score, lr_score])
	
	# Average the scores instead of multiplying (since they're already normalized 0-1)
	var avg_score = (rf_score + lr_score) / 2.0
	articles_analyzed.append(avg_score)
	
	print("[INTEGRITY DEBUG] Average score: %.4f" % avg_score)
	print("[INTEGRITY DEBUG] Total articles analyzed: %d" % articles_analyzed.size())
	print("[INTEGRITY DEBUG] Integrity BEFORE recalculation: %.2f" % integrity_score)
	
	_recalculate_integrity()
	
	print("[INTEGRITY DEBUG] Integrity AFTER recalculation: %.2f" % integrity_score)
	print("[INTEGRITY DEBUG] Breakdown: Base=%.2f, AnalyzedBonus=%.2f, OverlapBonus=%.2f, AddedBonus=%.2f, RemovedPenalty=%.2f" % [
		integrity_breakdown.get("base_score", 0.0),
		integrity_breakdown.get("articles_analyzed_bonus", 0.0),
		integrity_breakdown.get("high_overlap_bonus", 0.0),
		integrity_breakdown.get("articles_added_bonus", 0.0),
		integrity_breakdown.get("articles_removed_penalty", 0.0)
	])
	print("[INTEGRITY DEBUG] ==================================")
	
	_update_integrity_display()
	
#Will eventually remove debug crap
func add_high_overlap_comparison():
	"""Called when a comparison has high semantic overlap (0.90-1.0)"""
	print("[INTEGRITY DEBUG] ===== High Overlap Comparison =====")
	print("[INTEGRITY DEBUG] Integrity BEFORE: %.2f" % integrity_score)
	print("[INTEGRITY DEBUG] High overlap count BEFORE: %d" % high_overlap_comparisons)
	
	high_overlap_comparisons += 1
	integrity_score = min(10.0, integrity_score + 1.0)
	
	print("[INTEGRITY DEBUG] Integrity AFTER: %.2f" % integrity_score)
	print("[INTEGRITY DEBUG] High overlap count AFTER: %d" % high_overlap_comparisons)
	print("[INTEGRITY DEBUG] ==================================")
	
	_update_integrity_display()

func add_integrity_score(increment: float):
	"""Add integrity score increment directly (used by Article Publisher)"""
	print("[INTEGRITY DEBUG] ===== Adding Integrity Score =====")
	print("[INTEGRITY DEBUG] Integrity BEFORE: %.2f" % integrity_score)
	print("[INTEGRITY DEBUG] Increment: +%.2f" % increment)
	
	integrity_score = min(10.0, integrity_score + increment)
	
	print("[INTEGRITY DEBUG] Integrity AFTER: %.2f" % integrity_score)
	print("[INTEGRITY DEBUG] ==================================")
	
	_update_integrity_display()

func _recalculate_integrity():
	# Base score - use current base_score from breakdown if it's been decayed
	var base = integrity_breakdown.get("base_score", 5.0)
	# If integrity was already at 0 from decay, keep base at 0
	if instant_death and integrity_score <= 0.0:
		base = 0.0
	
	# Calculate bonuses and penalties
	var analyzed_bonus = 0.0
	if articles_analyzed.size() > 0:
		var sum_total = 0.0
		for t in articles_analyzed:
			sum_total += t
		# Calculate average and convert to 0-10 scale, then subtract base
		var avg_score = (sum_total / articles_analyzed.size()) * 10.0
		analyzed_bonus = avg_score - base
	
	var overlap_bonus = high_overlap_comparisons * 1.0
	var added_bonus = articles_added.size() * 0.3
	var removed_penalty = articles_removed.size() * 0.5
	
	# Store breakdown
	integrity_breakdown = {
		"base_score": base,
		"articles_analyzed_bonus": analyzed_bonus,
		"high_overlap_bonus": overlap_bonus,
		"articles_added_bonus": added_bonus,
		"articles_removed_penalty": removed_penalty
	}
	
	integrity_score = base + analyzed_bonus + overlap_bonus + added_bonus - removed_penalty
	integrity_score = clamp(integrity_score, 0.0, 10.0)

	# Only trigger instant death if not already set (from decay)
	if integrity_score < 3.0 and not instant_death:
		_trigger_instant_death()

func _update_integrity_display():
	if integrity_meter and integrity_meter.has_method("update_integrity"):
		integrity_meter.update_integrity(integrity_score)
	emit_signal("integrity_changed", integrity_score)

func _get_bonus_from_gameplay() -> float:
	# Placeholder: +0.1 per bonus
	return 0.1 * randi_range(0, 3)

func _trigger_instant_death():
	if not instant_death:
		instant_death = true
		day_over = true
		if game_timer:
			game_timer.stop_timer()
		emit_signal("game_over", "Integrity collapsed! You've been discredited...")
		get_tree().paused = true

func _on_time_up():
	_evaluate_day()

func _evaluate_day():
	if day_over:
		return
	
	day_over = true
	if game_timer:
		game_timer.stop_timer()
	
	# Close all remaining popups
	for popup in current_article_popups:
		if is_instance_valid(popup):
			popup.queue_free()
	current_article_popups.clear()
	
	# Recalculate final integrity with breakdown
	# But preserve instant_death state if integrity was already at 0 from decay
	var was_instant_death_from_decay = instant_death and integrity_score <= 0.0
	_recalculate_integrity()
	# If integrity was already at 0 from decay, ensure it stays at 0
	# (don't let bonuses bring it back up)
	if was_instant_death_from_decay:
		integrity_score = 0.0
		integrity_breakdown["base_score"] = 0.0
	
	emit_signal("day_complete", integrity_score)
	print("Day Complete. Integrity: %.2f" % integrity_score)
	
	# Always show popup with integrity breakdown (Papers Please style)
	_show_integrity_breakdown_popup()

func _show_integrity_breakdown_popup():
	if not game_failed_popup:
		_find_and_hide_game_failed_popup()
	
	if game_failed_popup:
		game_failed_popup.process_mode = Node.PROCESS_MODE_ALWAYS
		game_failed_popup.show_breakdown(integrity_breakdown, {
			"articles_analyzed": articles_analyzed.size(),
			"high_overlap": high_overlap_comparisons,
			"articles_added": articles_added.size(),
			"articles_removed": articles_removed.size(),
			"final_score": integrity_score
		})
		
		var game_failed = integrity_score < 6.0
		emit_signal("game_over", "Game Has Failed" if game_failed else "You survived another day.")
		get_tree().paused = true
	else:
		push_error("GameFailedPopup node not found")
		emit_signal("game_over", "Day Complete")
		get_tree().paused = true
		
func get_current_act() -> int:
	# Placeholder for act/phase progression
	return 2

func get_articles_analyzed_count() -> int:
	return articles_analyzed.size()

func get_daily_quota() -> int:
	return daily_quota
