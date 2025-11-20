extends Control

@export_group("Texts")
@export var title: Label
@export var date: Label

# ---------- SIGNAL ----------
signal open_note(note_instance: Node)

# ---------- DATA ----------
var note_data: Dictionary = {}

# ---------- NOTE BUTTONS ----------
func _on_open_pressed() -> void:
	emit_signal("open_note", self)

func setup_note(note_dict: Dictionary) -> void:
	"""Setup the note preview with data"""
	note_data = note_dict
	
	# Ensure labels are found (in case setup_note is called before _ready)
	if not title:
		title = get_node_or_null("MarginContainer/Open/MarginContainer/Title")
	if not date:
		date = get_node_or_null("MarginContainer/Open/MarginContainer/Date")
	
	# Use content as preview message instead of title
	var preview_text = note_dict.get("content", note_dict.get("title", "Untitled"))
	# Truncate if too long
	if preview_text.length() > 20:
		preview_text = preview_text.substr(0, 17) + "..."
	
	# Extract time from date string (format: "YYYY-MM-DD HH:MM:SS" or "YYYY-MM-DD")
	var note_date = note_dict.get("date", "")
	var time_text = ""
	if note_date != "":
		# Try to extract time portion
		var time_match = note_date.split(" ")
		if time_match.size() > 1:
			# Has time portion, extract HH:MM
			var time_part = time_match[1]
			var time_parts = time_part.split(":")
			if time_parts.size() >= 2:
				time_text = time_parts[0] + ":" + time_parts[1]
		# If no time portion, leave empty (date-only format)
	
	if title:
		title.text = preview_text
	else:
		push_warning("[Note] WARNING: title label not found!")
	
	if date:
		# Always set the date label, even if empty, to clear default "mm/dd/yy"
		date.text = time_text if time_text != "" else ""
	else:
		push_warning("[Note] WARNING: date label not found!")

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	# Auto-find labels if not set via export
	if not title:
		title = get_node_or_null("MarginContainer/Open/MarginContainer/Title")
	if not date:
		date = get_node_or_null("MarginContainer/Open/MarginContainer/Date")
