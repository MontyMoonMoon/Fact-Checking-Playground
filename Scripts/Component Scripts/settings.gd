extends Control

var master: Master
var scene_loader: SceneLoader
var sound_manager: SoundManager

@onready var settings: Control = $"."

@export var main_button: Button
@export var pause_button: Button
@export var help_button: Button

@export_group("Sliders")
@export var master_slider: HSlider
@export var music_slider: HSlider
@export var sfx_slider: HSlider

@export_group("Toggle Buttons")
@export var master_button: Button
@export var music_button: Button
@export var sfx_button: Button

var is_dragging := false
var drag_offset := Vector2.ZERO
var game_timer: Node = null
var game_manager: Node = null
var is_paused: bool = false

@onready var help: PackedScene = preload("res://Prefabs/Components/help_panel.tscn")

signal settings_closed

# ---------- UPDATE METHODS ----------
func update_sliders() -> void:
	master_slider.value = SettingsManager.master_vol
	music_slider.value = SettingsManager.music_vol
	sfx_slider.value = SettingsManager.sfx_vol

func update_buttons(slider: HSlider, button: Button) -> void:
	if slider.value == 0.0:
		button.button_pressed = true  
	else:
		button.button_pressed = false

# ---------- VOLUME SLIDERS ----------
func _on_slider_input(event: InputEvent, _slider: HSlider) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		save_pref()

# ---------- TOGGLE BUTTONS ----------
func _on_master_button_pressed() -> void:
	_toggle_slider_value(master_slider, master_button)

func _on_music_button_pressed() -> void:
	_toggle_slider_value(music_slider, music_button)

func _on_sfx_button_pressed() -> void:
	_toggle_slider_value(sfx_slider, sfx_button)

func _toggle_slider_value(slider: HSlider, button: Button) -> void:
	var is_muted := slider.value == 0.0
	
	if is_muted:
		slider.value = 100
		button.button_pressed = false
	else:
		slider.value = 0.0
		button.button_pressed = true
	
	save_pref()

# ---------- BUTTONS ----------
func _on_help_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	var help_instance = help.instantiate()
	help_instance.master = master
	settings.add_child(help_instance)

func _on_main_menu_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	master.scene_loader.load_by_id(0)

func _on_exit_pressed() -> void:
	emit_signal("settings_closed")
	queue_free()

# ---------- SAVE DATA ----------
## Saves the settings of the player by sending it to the settings manager -> data manager
func save_pref() -> void:
	SettingsManager.save_settings({
		"master_volume": master_slider.value,
		"music_volume": music_slider.value,
		"sfx_volume": sfx_slider.value
	})

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")  
	scene_loader = master.scene_loader
	
	# Settings panel should work even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	SettingsManager.load_settings()
	update_sliders()
	update_buttons(master_slider, master_button)
	update_buttons(music_slider, music_button)
	update_buttons(sfx_slider, sfx_button)
	
	# Check slider inputs
	master_slider.gui_input.connect(_on_slider_input.bind(master_slider))
	music_slider.gui_input.connect(_on_slider_input.bind(music_slider))
	sfx_slider.gui_input.connect(_on_slider_input.bind(sfx_slider))

# ---------- MAKE DRAGGABLE ----------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = settings.global_position - get_global_mouse_position()
			else:
				is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		settings.global_position = get_global_mouse_position() + drag_offset
