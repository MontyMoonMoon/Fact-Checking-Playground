extends CanvasLayer

var master: Master

@export var tutorial_visible: bool
@export var keep_notebook: bool

@export var tutorial_container: Control
@export var main_container: MarginContainer
@export var prompt_object: MarginContainer
@export var notebook: Control
@export var notebook_button: MarginContainer

@export_group("Top Bar")
@export var day_counter: Label
@export var settings_button: Button
@export var timer_label: Label
@export var integrity_meter_node: Node

@export_group("Phone")
@export var phone_button: VBoxContainer
@export var phone_button_main: Button
@export var phone_container: VBoxContainer
@export var phone: MobilePhone  

@export_group("Laptop")
@export var laptop: Laptop

var is_paused: bool = false

signal phone_opened
signal phone_closed
signal laptop_opened

# ---------- PREFABS ----------
@onready var settings: PackedScene = preload("res://Prefabs/Components/settings.tscn")

# ---------- VARIABLES ----------
var settings_instance: Control = null
var input_blocked := false
var settings_open := false
var phone_open := false
var laptop_open := false

var blink_tween: Tween
var is_blinking: bool = false

# ---------- GAME SYSTEMS ----------
var game_manager: GameManager = null
var game_timer: GameTimer = null
var lyra: Lyra = null
var day_end_panel: DayEndPanel = null

# ---------- UI VISIBILITY ----------
func set_ui(visibility: bool, target: int) -> void:
	match target:
		1:
			phone_button.visible = visibility
		2:
			phone_container.visible = visibility
		3:
			prompt_object.visible = visibility

# ---------- SETTINGS TOGGLE ----------
func _on_settings_pressed() -> void:
	set_ui(false, 3)
	if settings_open:
		_on_settings_closed()
		return
	
	if phone_open or laptop_open:
		return
	
	# Pause the game automatically when settings opens
	if not is_paused:
		toggle_pause()
	
	if settings_instance == null or not is_instance_valid(settings_instance):
		settings_instance = settings.instantiate()
		settings_instance.master = master
		
		master.sound_manager.play_sound("ui_click")
		
		settings_instance.connect("settings_closed", Callable(self, "_on_settings_closed"))
		settings_instance.connect("menu_clicked", Callable(self, "_on_settings_closed"))
		
		# Pass game timer and manager references
		if settings_instance.has_method("set_game_timer"):
			settings_instance.set_game_timer(game_timer)
		if settings_instance.has_method("set_game_manager"):
			settings_instance.set_game_manager(game_manager)
			
		main_container.add_child(settings_instance)
		settings_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
		
	settings_button.toggle_mode = true
	settings_open = true

func _on_settings_closed() -> void:
	set_ui(true, 3)
	if settings_instance and is_instance_valid(settings_instance):
		settings_instance.queue_free()
	settings_instance = null
	settings_button.toggle_mode = false
	settings_open = false
	 
	# Resume the game automatically when settings closes
	if is_paused:
		toggle_pause()

func toggle_pause() -> void:
	is_paused = !is_paused
	
	# Pause/unpause the game tree
	get_tree().paused = is_paused
	
	# Pause/unpause the timer
	if game_timer:
		if is_paused:
			game_timer.pause_timer()
		else:
			game_timer.resume_timer()

# ---------- PHONE TOGGLE ----------
func show_phone_button() -> void:
	phone_button.visible = true
	
func _on_phone_button_pressed() -> void:
	emit_signal("phone_opened")
	
	notebook_button.visible = false
	
	if keep_notebook == false:
		notebook.visible = false
	
	set_ui(false, 3)
	if phone_open:
		_on_phone_closed()
		set_ui(3, true)
		return

	if laptop_open or settings_open:
		return

	master.sound_manager.play_sound("ui_click")
	set_ui(false, 1)
	set_ui(true, 2)
	phone_open = true

func _on_phone_closed(play_sound := true) -> void:
	emit_signal("phone_closed")
	set_ui(true, 3)
	notebook.visible = true
	notebook_button.visible = true
	
	if play_sound:
		master.sound_manager.play_sound("ui_click")

	set_ui(true, 1)
	set_ui(false, 2)
	phone_open = false
	
# ---------- LAPTOP TOGGLE ----------
func _on_laptop_toggled() -> void:
	emit_signal("laptop_opened")
	set_ui(false, 3)
	_on_phone_closed()
	
	if tutorial_visible == true:
		tutorial_container.skip_text.visible = false
	
	notebook.visible = false
	if laptop.laptop_screen_in:
		if phone_open or settings_open:
			laptop._on_exit_pressed()
			return
		laptop_open = true
		prompt_object.visible = false
	else:
		laptop_open = false
		set_ui(true, 3)
		notebook.visible = true
		prompt_object.visible = true
		

# ---------- TOGGLE MANAGER ---------
func toggle_component(active_component: int) -> void:
	match active_component:
		1:
			_on_settings_pressed()
		2:
			_on_phone_button_pressed()
		3:
			if laptop_open:
				_on_laptop_toggled()  
			else:
				if phone_open or settings_open:
					return
				laptop._on_screen_pressed()

# ---------- TUTORIAL -----------
func _on_tutorial_finished() -> void:
	_setup_game_systems()

# ----------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master") 
	
	if tutorial_visible == true:
		tutorial_container.visible = true
		phone_button_main.disabled = true
	else:  
		tutorial_container.visible = false
		phone_button_main.disabled = false
		_on_tutorial_finished()
	
	# Detect current map - use THIS node's name (this script runs on map_01, map_02, map_03 nodes)
	var scene_name = "map_01"  # Default fallback
	var this_node = self
	
	# Use this node's name directly (most reliable - the script runs on the map node itself)
	var node_name = this_node.name
	if node_name in ["map_01", "map_02", "map_03"]:
		scene_name = node_name
	else:
		# Fallback: check root children (SceneLoader adds scenes as root children)
		var root = get_tree().root
		if root:
			# Find the LAST map node in root children (most recently added)
			var last_map_node = null
			for child in root.get_children():
				if child.name in ["map_01", "map_02", "map_03"]:
					last_map_node = child
			
			if last_map_node:
				scene_name = last_map_node.name
			else:
				# Final fallback: use current_scene
				var current_scene = get_tree().current_scene
				if current_scene and current_scene.name in ["map_01", "map_02", "map_03"]:
					scene_name = current_scene.name
	
	if master == null:
		push_warning("[map_01._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	# Only play stage music if we're on a valid map (not map_0)
	if scene_name in ["map_01", "map_02", "map_03"]:
		DataManager.current_map = scene_name
		DataManager.save_data()
		
		# Play appropriate stage music
		if master.sound_manager:
			call_deferred("_play_stage_music", scene_name)
	
	if phone:
		phone.connect("closed_phone", Callable(self, "_on_phone_closed"))
	
	if laptop:
		laptop.connect("laptop_toggled", Callable(self, "_on_laptop_toggled"))
	
	if tutorial_container:
		tutorial_container.connect("tutorial_done", Callable(self, "_on_tutorial_finished"))
		
		# Ensure laptop is visible (it should be visible by default)
		laptop.visible = true
	else:
		push_warning("[map_01._ready] Laptop is null! Check scene setup.")
	
	# Default UI on load
	_on_phone_closed(false)
	
	# Find DayEndPanel
	_find_day_end_panel()

func _play_stage_music(scene_name: String) -> void:
	"""Play appropriate stage music - called deferred to ensure sound_manager is ready"""
	if not master or not master.sound_manager:
		return
	
	match scene_name:
		"map_01":
			master.sound_manager.play_music("stage1")
		"map_02":
			master.sound_manager.play_music("stage2")
		"map_03":
			master.sound_manager.play_music("stage3")
		_:
			# Should not happen, but fallback to stage1
			master.sound_manager.play_music("stage1")


func _setup_game_systems():
	# Check if this is a new game or loading a save
	# If DataManager was just loaded via continue, it's a loaded save
	# Otherwise, it's a new game
	var is_new_game = _is_new_game()
	
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
	game_timer.article_spawn_interval_min = 15.0
	game_timer.article_spawn_interval_max = 25.0
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
			
			# Connect message app to todo section (for saving tips)
			var todo_section = phone.find_child("To-do", true, false)
			if not todo_section:
				# Try finding it as a child of notes app
				if notes_app:
					todo_section = notes_app.find_child("To-do", true, false)
					if not todo_section:
						todo_section = notes_app.find_child("To-do", true, false)
			
			if todo_section and message_app.has_method("set_todo_section_ref"):
				message_app.set_todo_section_ref(todo_section)
			else:
				push_warning("[map_01] Could not find todo section for message app!")
			
			# Connect notes app to game manager
			if notes_app and notes_app.has_method("set_game_manager"):
				notes_app.set_game_manager(game_manager)
	
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
			else:
				push_warning("[map_01] Lyra: Emails controller is null")
		else:
			push_warning("[map_01] Lyra: Laptop doesn't have get_emails_controller method")
	
	# Connect Lyra to message app
	if phone:
		await get_tree().process_frame
		var message_app = phone.find_child("MessageApp", true, false)
		if not message_app:
			# Try alternative path
			message_app = phone.get_node_or_null("AppContainers/MessageApp")
		if message_app and lyra:
			lyra.set_message_app(message_app)
		else:
			push_warning("[map_01] Lyra: Could not find MessageApp!")
	
	# Only reset systems for NEW games
	if is_new_game:
		
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
			
			# Reset article publisher
			if laptop.article_publisher_controller and laptop.article_publisher_controller.has_method("reset_for_new_game"):
				laptop.article_publisher_controller.reset_for_new_game()
		
		if phone:
			await get_tree().process_frame
			var message_app = phone.find_child("MessageApp", true, false)
			if message_app and message_app.has_method("reset_for_new_game"):
				message_app.reset_for_new_game()
	
	# Start game after a short delay (works for both new and loaded games)
	await get_tree().create_timer(1.0).timeout
	game_manager.start_game()

func _on_timer_updated(time_text: String):
	"""Update laptop and phone time when timer updates"""
	if laptop and laptop.has_method("update_time_display"):
		laptop.update_time_display(time_text)
	if phone and phone.time:
		phone.time.text = time_text

func _clear_all_game_data_files() -> void:
	"""Clear ALL game data files for a fresh new game start"""
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
			if error != OK:
				push_warning("[map_01] Failed to delete %s: error %d" % [file_name, error])
		
		# Recreate as empty file
		if file_name in ["messages.json", "notes.json", "collected_infos.json", "published_articles.json", "dataset_additions.json", "trashed_infos.json"]:
			JSONManager.save_json("user://%s" % file_name, [])
	
	# Also clear JSONManager caches
	var json_manager = JSONManager.get_instance()
	if json_manager:
		# Clear all caches explicitly
		json_manager.clear_collected_infos()
		json_manager.clear_dataset_additions()
		json_manager.messages_cache = []
		json_manager.collected_infos_cache = []
		json_manager.dataset_additions_cache = []
		json_manager.trashed_infos_cache = []

func _is_new_game() -> bool:
	"""Detect if this is a new game vs loading a save"""
	# ALWAYS treat as new game when coming from map_0
	# map_0 clears all files before loading map_01, so if we're here, it's a new game
	# The only exception is if we're continuing from a save (which would be a different code path)
	
	# Check if files exist and have data - if they do, they should have been cleared by map_0
	# If they weren't cleared, we'll clear them now and treat as new game
	var has_stale_data = false
	
	# Check dataset_additions.json
	if FileAccess.file_exists("user://dataset_additions.json"):
		var additions_file = FileAccess.open("user://dataset_additions.json", FileAccess.READ)
		if additions_file:
			var additions_text = additions_file.get_as_text().strip_edges()
			additions_file.close()
			if additions_text != "" and additions_text != "[]":
				var additions_data = JSON.parse_string(additions_text)
				if typeof(additions_data) == TYPE_ARRAY and additions_data.size() > 0:
					has_stale_data = true
	
	# Check collected_infos.json
	if FileAccess.file_exists("user://collected_infos.json"):
		var evidence_file = FileAccess.open("user://collected_infos.json", FileAccess.READ)
		if evidence_file:
			var evidence_text = evidence_file.get_as_text().strip_edges()
			evidence_file.close()
			if evidence_text != "" and evidence_text != "[]":
				var evidence_data = JSON.parse_string(evidence_text)
				if typeof(evidence_data) == TYPE_ARRAY and evidence_data.size() > 0:
					has_stale_data = true
	
	# Always treat as new game when coming from map_0
	# If there's stale data, _clear_all_game_data_files() will clear it
	return true

func _find_day_end_panel():
	"""Find DayEndPanel in the scene"""
	var found_node: Node = null
	
	# Method 1: Direct path from Contents
	var contents = get_node_or_null("Contents")
	if contents:
		found_node = contents.get_node_or_null("Day End Panel")
		if not found_node:
			found_node = contents.get_node_or_null("DayEndPanel")
	
	# Method 2: Search by class name from scene root
	if not found_node:
		var scene_root = get_tree().current_scene
		if scene_root:
			for child in scene_root.get_children():
				if child is DayEndPanel:
					found_node = child
					break
	
	# Method 3: Recursive search
	if not found_node:
		found_node = find_child("Day End Panel", true, false)
		if not found_node:
			found_node = find_child("DayEndPanel", true, false)
	
	# Method 4: Search from Contents recursively
	if not found_node and contents:
		found_node = contents.find_child("Day End Panel", true, false)
		if not found_node:
			found_node = contents.find_child("DayEndPanel", true, false)
	
	# Cast to DayEndPanel if found
	if found_node:
		# Try multiple casting methods
		if found_node is DayEndPanel:
			day_end_panel = found_node as DayEndPanel
		else:
			# Check if it has the DayEndPanel script
			var script = found_node.get_script()
			if script:
				var script_path = script.resource_path if script.resource_path else ""
				if script_path.ends_with("day_end_panel.gd"):
					# Force cast - the node should be a DayEndPanel even if type check fails
					day_end_panel = found_node as DayEndPanel
				else:
					# Try to find the script in the node's children or check by name
					if found_node.name == "Day End Panel" or found_node.name == "DayEndPanel":
						# Assume it's the right node and cast anyway
						day_end_panel = found_node as DayEndPanel
		
		if day_end_panel:
			day_end_panel.visible = false
		else:
			push_warning("[map_01] Found node but couldn't cast to DayEndPanel! Type: %s, Name: %s" % [str(found_node.get_class()), found_node.name])
	else:
		# Debug: Print available children
		if contents:
			var children_names = []
			for child in contents.get_children():
				children_names.append(child.name)
			push_warning("[map_01] DayEndPanel not found! Contents children: %s" % str(children_names))
		else:
			push_warning("[map_01] DayEndPanel not found! Contents node is null!")

func _on_integrity_changed(new_score: float):
	pass

func _on_day_complete(final_score: float):
	
	if not day_end_panel:
		_find_day_end_panel()
	
	# If still not found, try one more time with direct access
	if not day_end_panel:
		var contents = get_node_or_null("Contents")
		if contents:
			var found = contents.get_node_or_null("Day End Panel")
			if found:
				# Force cast since we know it should be DayEndPanel
				day_end_panel = found as DayEndPanel
	
	if day_end_panel and game_manager:
		# Ensure breakdown includes tracked increments and decrements
		var breakdown = game_manager.integrity_breakdown.duplicate(true)
		
		# Add integrity increments and decrements if not already present
		if not breakdown.has("integrity_increments"):
			breakdown["integrity_increments"] = game_manager.integrity_increments.duplicate()
		if not breakdown.has("integrity_decrements"):
			breakdown["integrity_decrements"] = game_manager.integrity_decrements.duplicate()
		
		var stats = {"final_score": final_score}
		day_end_panel.show_breakdown(breakdown, stats)
		get_tree().paused = true

func _on_game_over(reason: String):
	
	if not day_end_panel:
		_find_day_end_panel()
	
	if day_end_panel and game_manager:
		# Ensure breakdown includes tracked increments and decrements
		var breakdown = game_manager.integrity_breakdown.duplicate(true)
		
		# Add integrity increments and decrements if not already present
		if not breakdown.has("integrity_increments"):
			breakdown["integrity_increments"] = game_manager.integrity_increments.duplicate()
		if not breakdown.has("integrity_decrements"):
			breakdown["integrity_decrements"] = game_manager.integrity_decrements.duplicate()
		
		var stats = {"final_score": game_manager.integrity_score}
		day_end_panel.show_breakdown(breakdown, stats)
		get_tree().paused = true
	
var _p_key_pressed_last_frame: bool = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("settings"):
		toggle_component(1)
	
	if Input.is_action_just_pressed("phone"):
		toggle_component(2)
	
	# Debug: Press P to reduce 30 seconds from timer
	var p_key_pressed = Input.is_key_pressed(KEY_P)
	if p_key_pressed and not _p_key_pressed_last_frame:
		if game_timer:
			game_timer.reduce_time(30.0)
	_p_key_pressed_last_frame = p_key_pressed
