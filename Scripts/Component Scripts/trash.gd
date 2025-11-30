extends Control

@export var display_text: Label

func _set_text(text: String) -> void:
	display_text.text = text
