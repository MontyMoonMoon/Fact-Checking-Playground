extends Control

@export var content_text: Label

func set_text(text: String) -> void:
	content_text.text = text
