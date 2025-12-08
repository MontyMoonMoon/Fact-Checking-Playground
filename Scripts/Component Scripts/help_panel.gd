extends Control

var master: Master
var sound_manager: SoundManager

@onready var help_panel: Control = $"."

@export_group("Help Panel")
@export_subgroup("Controls")
@export var control_button: Button
@export var controls_panel: MarginContainer

@export_subgroup("How to Play")
@export var htp_button: Button
@export var htp_panel: MarginContainer
@export var htp_text_label: RichTextLabel

var is_dragging := false
var drag_offset := Vector2.ZERO

# ---------- SET UI ----------
func set_visibility(target: int, visibility: bool) -> void:
	match target:
		1: controls_panel.visible = visibility
		2: htp_panel.visible = visibility

# ---------- METHODS ----------
func _on_controls_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	if control_button.is_pressed():
		set_visibility(1, true)
	else: 
		set_visibility(1, false)

func _on_how_to_play_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	if htp_button.is_pressed():
		set_visibility(2, true)
		# Ensure text is set when panel becomes visible
	else: 
		set_visibility(2, false)

func _on_exit_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	queue_free()

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[Help_panel._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	set_visibility(1, false)
	set_visibility(2, false)

# ---------- MAKE DRAGGABLE ----------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = help_panel.global_position - get_global_mouse_position()
			else:
				is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		help_panel.global_position = get_global_mouse_position() + drag_offset
