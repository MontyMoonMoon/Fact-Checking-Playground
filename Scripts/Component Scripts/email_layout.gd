extends Control

@export var display_text: Label

func _set_text(text: String) -> void:
	if display_text:
		display_text.text = text

