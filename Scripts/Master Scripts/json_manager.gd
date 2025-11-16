extends Node
class_name JSONManager

# ---------- CALL DATA FROM JSON ----------
var mails: Dictionary = {}

# ---------- METHODS ----------
func load_mails() -> void:
	var mail_file = FileAccess.open("res://JSONs/mail_texts.json", FileAccess.READ)
	if mail_file:
		var parsed = JSON.parse_string(mail_file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			mails = parsed

# ---------- GODOT CALLBACKS ----------
func _ready():
	load_mails()
