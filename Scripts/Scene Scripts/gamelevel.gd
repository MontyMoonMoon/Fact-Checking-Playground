extends CanvasLayer

var master: Master

@export var main_container: MarginContainer
@export var scene_num: int

@export_group("Top Bar")
@export var day_counter: Label
@export var settings_button: Button

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
var input_blocked := false
var settings_open := false
var phone_open := false
var laptop_open := false

# ---------- UI VISIBILITY ----------
func set_ui(visibility: bool, target: int) -> void:
	match target:
		1:
			phone_button.visible = visibility
		2:
			phone_container.visible = visibility

# ---------- SETTINGS TOGGLE ----------
func _on_settings_pressed() -> void:
	if settings_open:
		_on_settings_closed()
		return
	
	if phone_open or laptop_open:
		return
	
	master.sound_manager.play_sound("ui_click")
	
	settings_instance = settings.instantiate()
	settings_instance.master = master
	main_container.add_child(settings_instance)
	settings_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	settings_instance.connect("settings_closed", Callable(self, "_on_settings_closed"))
	
	settings_button.toggle_mode = true
	settings_open = true

func _on_settings_closed() -> void:
	master.sound_manager.play_sound("ui_click")
	if settings_instance and is_instance_valid(settings_instance):
		settings_instance.queue_free()
	settings_instance = null
	settings_button.toggle_mode = false
	settings_open = false

# ---------- PHONE TOGGLE ----------
func _on_phone_button_pressed() -> void:
	if phone_open:
		_on_phone_closed()
		return
	
	if laptop_open or settings_open:
		return
	
	master.sound_manager.play_sound("ui_click")
	set_ui(false, 1)
	set_ui(true, 2)
	phone_open = true

func _on_phone_closed(play_sound := true) -> void:
	if play_sound:
		master.sound_manager.play_sound("ui_click")
	
	set_ui(true, 1)
	set_ui(false, 2)
	phone_open = false

# ---------- LAPTOP TOGGLE ----------
func _on_laptop_toggled() -> void:
	if laptop.laptop_screen_in:
		# Opening laptop
		if phone_open or settings_open:
			laptop._on_exit_pressed()
			return
		laptop_open = true
	else:
		laptop_open = false

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

func set_time_date_data() -> void:
	pass

# ----------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[WARN: map_1._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	TimeDateManager.load_days()
	
	if phone:
		phone.connect("closed_phone", Callable(self, "_on_phone_closed"))
	
	if laptop:
		laptop.connect("laptop_toggled", Callable(self, "_on_laptop_toggled"))
	
	# Default UI on load
	_on_phone_closed(false)
	
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("settings"):
		toggle_component(1)
	
	if Input.is_action_just_pressed("phone"):
		toggle_component(2)
