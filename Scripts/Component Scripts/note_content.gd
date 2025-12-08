extends Control

@export_group("Texts")
@export var title: Label
@export var preview: Label

# ---------- SIGNAL ----------
signal open_note(note_instance: Node)

# ---------- DATA ----------
var note_data: Dictionary = {}

# ---------- NOTE BUTTONS ----------
func _on_open_pressed() -> void:
	emit_signal("open_note", note_data)
