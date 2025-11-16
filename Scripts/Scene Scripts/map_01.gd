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
	
	# Default UI on load
	_on_phone_closed(false)
	
	# Initialize game systems
	_setup_game_systems()

func _setup_game_systems():
	# Create GameManager
	game_manager = GameManager.new()
	game_manager.name = "GameManager"
	add_child(game_manager)
	
	# Create GameTimer
	game_timer = GameTimer.new()
	game_timer.name = "GameTimer"
	game_timer.time_limit = 10.0  # 5 minutes
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
	
	# Start game after a short delay
	await get_tree().create_timer(1.0).timeout
	game_manager.start_game()
	
	print("[map_01] Game systems initialized and started")

func _on_timer_updated(time_text: String):
	"""Update laptop time when timer updates"""
	print("[TIMER DEBUG] Timer updated signal received: %s" % time_text)
	if laptop and laptop.has_method("update_time_display"):
		laptop.update_time_display(time_text)
		print("[TIMER DEBUG] Laptop time updated")
	else:
		if not laptop:
			print("[TIMER DEBUG] WARNING: Laptop is null!")
		else:
			print("[TIMER DEBUG] WARNING: Laptop doesn't have update_time_display method!")

func _on_integrity_changed(new_score: float):
	print("Integrity changed to: %.2f" % new_score)

func _on_day_complete(final_score: float):
	print("Day complete! Final integrity: %.2f" % final_score)
	# You can show a completion screen here

func _on_game_over(reason: String):
	print("Game Over: %s" % reason)
	# You can show a game over screen here
	get_tree().paused = true
	
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
