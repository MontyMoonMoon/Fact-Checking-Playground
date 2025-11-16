extends Control

@export_group("Texts")
@export var title: Label
@export var date: Label

# ---------- SIGNAL ----------
signal open_note

# ---------- NOTE BUTTONS ----------
func _on_open_pressed() -> void:
	emit_signal ("open_note")

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	pass
