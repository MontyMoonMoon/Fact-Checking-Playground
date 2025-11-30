extends Control

var master: Master
var sound_manager: SoundManager

@onready var credits_panel: Control = $"."

var is_dragging := false
var drag_offset := Vector2.ZERO

# ---------- MAKE DRAGGABLE ----------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = credits_panel.global_position - get_global_mouse_position()
			else:
				is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		credits_panel.global_position = get_global_mouse_position() + drag_offset

func _on_exit_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	queue_free()

func _ready() -> void:
	master = get_node("/root/Master") 
	
	if master == null:
			print("[Credits_panel._ready] Master is still null. Calling members from this object may cause issues.")
			return
