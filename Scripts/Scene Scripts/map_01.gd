extends CanvasLayer

var master: Master
#var sound_manager: SoundManager

@export var main_container: MarginContainer

@export_group("Top Bar")
@export var day_counter: Label
@export var settings_button: Button
@export var timer_label: Label
@export var integrity_meter_node: Node

@export_group("Phone")
@export var phone_button: VBoxContainer
@export var phone_container: VBoxContainer
@export var phone: MobilePhone  

@export_group("Laptop")
@export var laptop: Laptop

# ---------- PREFABS ----------
@onready var settings: PackedScene = preload("res://Prefabs/Components/settings.tscn")

# ---------- VARIABLES ----------
var settings_instance: Control = null 
var phone_open := false
var input_blocked: bool = false
var laptop_open := false

# ---------- GAME SYSTEMS ----------
var game_manager: GameManager = null
var game_timer: GameTimer = null
var lyra: Lyra = null
var game_failed_popup: GameFailedPopup = null

# ---------- UI VISIBILITY ----------
func set_ui(visibility: bool, target: int) -> void:
	match target:
		1:
			phone_button.visible = visibility
		2:
			phone_container.visible = visibility

# ---------- SETTINGS TOGGLE ----------
func _on_settings_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	if settings_instance == null or not is_instance_valid(settings_instance):
		settings_instance = settings.instantiate()
		settings_instance.master = master
		# Pass game timer and manager references
		if settings_instance.has_method("set_game_timer"):
			settings_instance.set_game_timer(game_timer)
		if settings_instance.has_method("set_game_manager"):
			settings_instance.set_game_manager(game_manager)
		main_container.add_child(settings_instance)
		settings_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
		settings_button.toggle_mode = true
		
		input_blocked = true;
	else:
		settings_instance.queue_free()
		settings_instance = null
		settings_button.toggle_mode = false
		
		input_blocked = false;

# ---------- PHONE ----------
func _on_phone_button_pressed() -> void:
	master.sound_manager.play_sound("ui_click")
		
	phone_open = true
	input_blocked = true;
	set_ui(false, 1)
	set_ui(true, 2)

func _on_phone_closed(play_sound := true) -> void:
	if play_sound == true:
		master.sound_manager.play_sound("ui_click")
		
	phone_open = false
	input_blocked = false;
	set_ui(true, 1)
	set_ui(false, 2)

# ---------- LAPTOP ----------
func _on_laptop_toggled(is_open: bool) -> void:
	laptop_open = is_open

# ----------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[WARN: map_1._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	if phone:
		phone.connect("closed_phone", Callable(self, "_on_phone_closed"))
	
	if laptop:
		laptop.connect("laptop_toggled", Callable(self, "_on_laptop_toggled"))
		# Ensure laptop is visible (it should be visible by default)
		laptop.visible = true
		print("[map_01._ready] Laptop is visible: %s" % laptop.visible)
	else:
		push_warning("[map_01._ready] Laptop is null! Check scene setup.")
	
	# Default UI on load
	_on_phone_closed(false)
	
	# Find GameFailedPopup
	_find_game_failed_popup()
	
	# Initialize game systems
	_setup_game_systems()

func _setup_game_systems():
	# Check if this is a new game or loading a save
	# If DataManager was just loaded via continue, it's a loaded save
	# Otherwise, it's a new game
	var is_new_game = _is_new_game()
	print("[map_01] Detected game type: %s" % ("NEW GAME" if is_new_game else "LOADED SAVE"))
	
	# Files should already be cleared by map_0 for new games
	# But clear again here as a safety measure
	if is_new_game:
		_clear_all_game_data_files()
	
	# Create GameManager
	game_manager = GameManager.new()
	game_manager.name = "GameManager"
	add_child(game_manager)
	
	# Create GameTimer
	game_timer = GameTimer.new()
	game_timer.name = "GameTimer"
	game_timer.time_limit = 300.0  # 5 minutes (300 seconds)
	game_timer.article_spawn_interval_min = 35.0
	game_timer.article_spawn_interval_max = 35.0
	add_child(game_timer)
	
	# Connect timer to manager
	game_manager.set_game_timer(game_timer)
	
	# Set timer label if available
	if timer_label:
		game_timer.set_timer_label(timer_label)
	
	# Set integrity meter
	if integrity_meter_node:
		game_manager.set_integrity_meter(integrity_meter_node)
	
	# Sync laptop time with main timer
	if laptop:
		# Wait a frame for laptop to be fully initialized
		await get_tree().process_frame
		
		# Find laptop time label - try multiple paths
		var laptop_time_label = null
		# Try direct path first (if laptop is the root of the instance)
		if laptop.has_node("LaptopIn/HomeScreen/TaskBar/Panel/MarginContainer/Right/Time"):
			laptop_time_label = laptop.get_node("LaptopIn/HomeScreen/TaskBar/Panel/MarginContainer/Right/Time")
		# Try searching recursively
		else:
			laptop_time_label = laptop.find_child("Time", true, false)
		
		if laptop_time_label and laptop_time_label is Label:
			laptop.set_time_label(laptop_time_label)
			print("[map_01] Laptop time label connected: ", laptop_time_label.get_path())
		else:
			push_warning("[map_01] Could not find laptop time label. Laptop path: ", laptop.get_path())
		
		# Connect timer updates to laptop
		if not game_timer.timer_updated.is_connected(_on_timer_updated):
			game_timer.timer_updated.connect(_on_timer_updated)
	
	# Connect game manager signals
	game_manager.integrity_changed.connect(_on_integrity_changed)
	game_manager.day_complete.connect(_on_day_complete)
	game_manager.game_over.connect(_on_game_over)
	
	# Connect laptop controllers to game manager
	if laptop and laptop.has_method("set_game_manager"):
		laptop.set_game_manager(game_manager)
	
	# Start API starter
	var api_starter = preload("res://Scripts/API scripts/api_starter.gd").new()
	api_starter.name = "APIStarter"
	add_child(api_starter)
	
	# Connect phone apps to game systems
	if phone:
		await get_tree().process_frame  # Wait for phone apps to initialize
		
		# Find message app
		var message_app = phone.find_child("MessageApp", true, false)
		if message_app:
			# Connect message app to notes app (deprecated, but keep for compatibility)
			var notes_app = phone.find_child("NotesApp", true, false)
			if notes_app and message_app.has_method("set_notes_app_ref"):
				message_app.set_notes_app_ref(notes_app)
				print("[map_01] Message app connected to notes app")
			
			# Connect message app to todo section (for saving tips)
			var todo_section = phone.find_child("TodoSection", true, false)
			if not todo_section:
				todo_section = phone.find_child("Todo Section", true, false)
			if not todo_section:
				# Try finding it as a child of notes app
				if notes_app:
					todo_section = notes_app.find_child("TodoSection", true, false)
					if not todo_section:
						todo_section = notes_app.find_child("Todo Section", true, false)
			
			if todo_section and message_app.has_method("set_todo_section_ref"):
				message_app.set_todo_section_ref(todo_section)
				print("[map_01] Message app connected to todo section: %s" % todo_section.name)
			else:
				push_warning("[map_01] Could not find todo section for message app!")
			
			# Connect notes app to game manager
			if notes_app and notes_app.has_method("set_game_manager"):
				notes_app.set_game_manager(game_manager)
				print("[map_01] Notes app connected to game manager")
	
	# Initialize Lyra (Enemy AI)
	lyra = Lyra.new()
	lyra.name = "Lyra"
	add_child(lyra)
	lyra.set_game_timer(game_timer)
	lyra.set_game_manager(game_manager)
	if laptop:
		lyra.set_laptop(laptop)
		# Wait a frame for laptop to fully initialize controllers
		await get_tree().process_frame
		if laptop.has_method("get_emails_controller"):
			var emails_ctrl = laptop.get_emails_controller()
			if emails_ctrl:
				lyra.set_emails_controller(emails_ctrl)
				print("[map_01] Lyra: Emails controller connected")
			else:
				push_warning("[map_01] Lyra: Emails controller is null")
		else:
			push_warning("[map_01] Lyra: Laptop doesn't have get_emails_controller method")
	
	# Connect Lyra to message app
	if phone:
		await get_tree().process_frame
		var message_app = phone.find_child("MessageApp", true, false)
		if message_app and lyra:
			lyra.set_message_app(message_app)
			print("[map_01] Lyra: Message app connected")
	
	print("[map_01] Lyra AI initialized")
	
	# Only reset systems for NEW games
	if is_new_game:
		print("[map_01] Resetting all systems for NEW GAME...")
		
		# Reset controllers (files already cleared by map_0)
		if lyra and lyra.has_method("reset_for_new_game"):
			lyra.reset_for_new_game()
		
		if laptop:
			var emails_ctrl = laptop.get_emails_controller()
			if emails_ctrl and emails_ctrl.has_method("reset_for_new_game"):
				emails_ctrl.reset_for_new_game()
			
			# Access AI analysis controller directly from laptop's ai_analysis property
			if laptop.ai_analysis and laptop.ai_analysis.has_method("reset_for_new_game"):
				laptop.ai_analysis.reset_for_new_game()
			
			var evidence_bank_ctrl = laptop.get_evidence_bank_controller()
			if evidence_bank_ctrl and evidence_bank_ctrl.has_method("reset_for_new_game"):
				evidence_bank_ctrl.reset_for_new_game()
			
			var trash_ctrl = laptop.get_trash_controller()
			if trash_ctrl and trash_ctrl.has_method("reset_for_new_game"):
				trash_ctrl.reset_for_new_game()
		
		if phone:
			await get_tree().process_frame
			var message_app = phone.find_child("MessageApp", true, false)
			if message_app and message_app.has_method("reset_for_new_game"):
				message_app.reset_for_new_game()
	else:
		print("[map_01] LOADED SAVE - preserving game state")
	
	# Start game after a short delay (works for both new and loaded games)
	await get_tree().create_timer(1.0).timeout
	game_manager.start_game()
	
	print("[map_01] Game systems initialized and started")

func _on_timer_updated(time_text: String):
	"""Update laptop time when timer updates"""
	# print("[TIMER DEBUG] Timer updated signal received: %s" % time_text)
	if laptop and laptop.has_method("update_time_display"):
		laptop.update_time_display(time_text)
		# print("[TIMER DEBUG] Laptop time updated")
	else:
		if not laptop:
			# print("[TIMER DEBUG] WARNING: Laptop is null!")
			pass
		else:
			# print("[TIMER DEBUG] WARNING: Laptop doesn't have update_time_display method!")
			pass

func _clear_all_game_data_files() -> void:
	"""Clear ALL game data files for a fresh new game start"""
	print("[map_01] Clearing ALL game data files for new game...")
	
	var dir = DirAccess.open("user://")
	if not dir:
		push_warning("[map_01] Failed to open user:// directory for clearing files")
		return
	
	# List of all game data files to clear
	var files_to_clear = [
		"collected_infos.json",
		"messages.json",
		"published_articles.json",
		"dataset_additions.json",
		"trashed_infos.json",
		"todos_texts.json"
	]
	
	for file_name in files_to_clear:
		if dir.file_exists(file_name):
			var error = dir.remove(file_name)
			if error == OK:
				print("[map_01] Cleared: %s" % file_name)
			else:
				push_warning("[map_01] Failed to clear %s: error %d" % [file_name, error])
		else:
			print("[map_01] File doesn't exist (skipping): %s" % file_name)
	
	# Also clear JSONManager caches
	var json_manager = JSONManager.get_instance()
	if json_manager:
		# Clear all caches
		if json_manager.has_method("clear_collected_infos"):
			json_manager.clear_collected_infos()
		json_manager.messages_cache = []
		json_manager.collected_infos_cache = []
		print("[map_01] Cleared JSONManager caches")
	
	print("[map_01] All game data files cleared for new game")

func _is_new_game() -> bool:
	"""Detect if this is a new game vs loading a save"""
	# Heuristic: Check if this looks like a new game based on save data
	# New game characteristics:
	# - Integrity is at default (100) or near it
	# - Current act is 1
	# - No evidence collected yet
	
	if FileAccess.file_exists("user://save_data.json"):
		var file = FileAccess.open("user://save_data.json", FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(json_text)
			if typeof(parsed) == TYPE_DICTIONARY:
				var player_dict = parsed.get("player_data", {})
				var integrity = player_dict.get("integrity", 100)
				var current_act = player_dict.get("current_act", 1)
				
				# Check for collected evidence (if exists, it's not a new game)
				var has_evidence = FileAccess.file_exists("user://collected_infos.json")
				if has_evidence:
					var evidence_file = FileAccess.open("user://collected_infos.json", FileAccess.READ)
					if evidence_file:
						var evidence_text = evidence_file.get_as_text()
						evidence_file.close()
						var evidence_data = JSON.parse_string(evidence_text)
						if typeof(evidence_data) == TYPE_ARRAY and evidence_data.size() > 0:
							print("[map_01._is_new_game] Detected LOADED SAVE (has %d collected items)" % evidence_data.size())
							return false
				
				# Check integrity - if significantly lower than 100, it's a loaded save
				if integrity < 95:
					print("[map_01._is_new_game] Detected LOADED SAVE (integrity: %.1f)" % integrity)
					return false
				
				# Check if there are messages saved (if many messages, it's a loaded save)
				if FileAccess.file_exists("user://messages.json"):
					var messages_file = FileAccess.open("user://messages.json", FileAccess.READ)
					if messages_file:
						var messages_text = messages_file.get_as_text()
						messages_file.close()
						var messages_data = JSON.parse_string(messages_text)
						if typeof(messages_data) == TYPE_ARRAY:
							var initial_count = 5  # Expected initial message count
							if messages_data.size() > initial_count + 5:  # Allow some margin
								print("[map_01._is_new_game] Detected LOADED SAVE (%d messages, expected ~%d)" % [messages_data.size(), initial_count])
								return false
	
	# Default to new game if we can't determine otherwise
	print("[map_01._is_new_game] Detected NEW GAME (default)")
	return true

func _find_game_failed_popup():
	"""Find GameFailedPopup in the scene"""
	var contents = get_node_or_null("Contents")
	if contents:
		game_failed_popup = contents.get_node_or_null("GameFailedPopup")
	
	if not game_failed_popup:
		game_failed_popup = find_child("GameFailedPopup", true, false)
	
	if game_failed_popup:
		print("[map_01] GameFailedPopup found")
		game_failed_popup.visible = false
	else:
		push_warning("[map_01] GameFailedPopup not found!")

func _on_integrity_changed(new_score: float):
	print("Integrity changed to: %.2f" % new_score)

func _on_day_complete(final_score: float):
	print("Day complete! Final integrity: %.2f" % final_score)
	
	if not game_failed_popup:
		_find_game_failed_popup()
	
	if game_failed_popup and game_manager:
		var breakdown = game_manager.integrity_breakdown
		var stats = {"final_score": final_score}
		game_failed_popup.show_breakdown(breakdown, stats)
		get_tree().paused = true
		print("[map_01] Showing day complete popup")

func _on_game_over(reason: String):
	print("Game Over: %s" % reason)
	
	if not game_failed_popup:
		_find_game_failed_popup()
	
	if game_failed_popup and game_manager:
		var breakdown = game_manager.integrity_breakdown
		var stats = {"final_score": game_manager.integrity_score}
		game_failed_popup.show_breakdown(breakdown, stats)
		get_tree().paused = true
		print("[map_01] Showing game over popup")
	
func _process(_delta: float) -> void:
	if laptop_open:
		return
	
	if input_blocked:
		if phone_open and Input.is_action_just_pressed("phone"):
			_on_phone_closed()
		elif settings_instance and Input.is_action_just_pressed("settings"):
			_on_settings_pressed()
		return

	if Input.is_action_just_pressed("settings"):
		_on_settings_pressed()

	if Input.is_action_just_pressed("phone"):
		if phone_open:
			_on_phone_closed()
		else:
			_on_phone_button_pressed()
