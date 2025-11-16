extends Control

@export_group("Preview Info")
@export var contact_name: Label
@export var preview_msg: Label

# ---------- SIGNAL ----------
signal open_chat

# ---------- CHAT BUTTONS ----------
func _on_chat_pressed() -> void:
	emit_signal("open_chat")

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	pass
