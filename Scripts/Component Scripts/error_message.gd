extends Control

var master: Master
var sound_manager: SoundManager

@export var message: MarginContainer
@export var error_message_label: Label

var is_dragging := false
var drag_offset := Vector2.ZERO

# ---------- ERROR MESSAGES ----------
var error_data := {
	"Empty_name": {
		"message": "Name field is empty"
		}
}

# ---------- BUTTON ----------
func _on_exit_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	queue_free()

# ---------- SIGNAL CALLS ----------
func show_error(error_code: String) -> void:
	if error_code in error_data:
		var data = error_data[error_code]
		error_message_label.text = data.message
	else:
		error_message_label.text = "Unknown error"

# ---------- MAKE DRAGGABLE ----------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = message.global_position - get_global_mouse_position()
			else:
				is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		message.global_position = get_global_mouse_position() + drag_offset
