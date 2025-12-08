extends Control

var master: Master
var sound_manager: SoundManager
var data_manager: DataManager
var receiver_name: String = "" 

@onready var mail: Control = $"."

@export_group("Mail Texts")
@export var receiver: Label
@export var sender: Label
@export var subject: Label
@export var main_text: RichTextLabel

@export_subgroup("Button")
@export var container: VBoxContainer
@export var confirm_button: Button

var is_dragging := false
var drag_offset := Vector2.ZERO

func load_mail(mail_dict: Dictionary) -> void:
	if not is_inside_tree():
		await ready
	
	# Set receiver
	if receiver:
		if receiver_name != "":
			receiver.text = receiver_name
		else:
			if not master:
				master = get_node("/root/Master")
			if master and master.data_manager and master.data_manager.player_name:
				receiver.text = master.data_manager.player_name
			else:
				receiver.text = DataManager.player_name if DataManager.player_name else "Player"
	
	# Set subject
	if subject:
		subject.text = mail_dict.get("subject", "")
	
	# Set sender
	if sender:
		sender.text = mail_dict.get("sender", mail_dict.get("from", "Unknown Sender"))
	
	# Set main text content - CRITICAL: Find node if @export failed
	var text_content = mail_dict.get("main_text", "")
	
	# If main_text is empty, try to get content from other fields
	if text_content == "" or text_content == "No content available.":
		text_content = mail_dict.get("content", "")
	
	# Try to get main_text node
	var content_label: RichTextLabel = main_text
	
	# Fallback: find node manually if @export didn't work
	if not content_label:
		content_label = get_node_or_null("MarginContainer/NinePatchRect/MarginContainer/MarginContainer/Main/ScrollContainer/Mail_contents/Main/Content") as RichTextLabel
		if not content_label:
			# Try alternative path
			content_label = find_child("Content", true, false) as RichTextLabel
	
	if content_label:
		# Configure RichTextLabel BEFORE setting text
		content_label.bbcode_enabled = true
		content_label.visible = true
		content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# CRITICAL: Ensure font size is set (check if it's 0 or missing)
		var current_font_size = content_label.get_theme_font_size("normal_font_size")
		if current_font_size <= 0:
			# Font size is 0 or missing, set a default
			content_label.add_theme_font_size_override("normal_font_size", 16)
		
		# Also ensure font is loaded
		var current_font = content_label.get_theme_font("normal_font")
		if not current_font:
			var font = load("res://Assets/Fonts/BMmini.TTF")
			if font:
				content_label.add_theme_font_override("normal_font", font)
		
		# Ensure text color is visible (black)
		content_label.add_theme_color_override("default_color", Color.BLACK)
		
		# Ensure font is set
		if not content_label.has_theme_font_override("normal_font"):
			var font = load("res://Assets/Fonts/BMmini.TTF")
			if font:
				content_label.add_theme_font_override("normal_font", font)
		
		# CRITICAL: Ensure all characters are visible
		content_label.visible_characters = -1
		
		# Set the text directly - RichTextLabel handles BBCode when bbcode_enabled is true
		content_label.text = text_content
		
		# Wait for text to be processed and layout to update
		await get_tree().process_frame
		await get_tree().process_frame  # Extra frame to ensure size is calculated
		
		# CRITICAL: Calculate minimum height based on content
		# RichTextLabel needs a minimum height to display content
		var font_size = content_label.get_theme_font_size("normal_font_size")
		if font_size <= 0:
			font_size = 16  # Fallback
		
		# Estimate height: count lines (including wrapped lines)
		var line_height = font_size * 1.5  # Line height with spacing
		var text_lines = text_content.split("\n")
		var width = content_label.size.x if content_label.size.x > 0 else content_label.custom_minimum_size.x
		if width <= 0:
			width = 490  # Default width from logs
		
		# Estimate wrapped lines: divide by approximate chars per line
		var chars_per_line = int(width / (font_size * 0.6))  # Approximate
		if chars_per_line <= 0:
			chars_per_line = 50  # Fallback
		
		var total_lines = 0
		for line in text_lines:
			var line_chars = line.length()
			var wrapped_lines = max(1, int(ceil(float(line_chars) / chars_per_line)))
			total_lines += wrapped_lines
		
		var estimated_height = total_lines * line_height
		
		# Set minimum height - but be conservative to avoid pushing button too far down
		# Use a reasonable minimum that allows content to display without excessive spacing
		# For short content, use estimated height; for longer content, cap it and let scrolling handle it
		var max_visible_height = 200.0  # Maximum height before scrolling kicks in
		var min_height = min(max(estimated_height, 50.0), max_visible_height)
		content_label.custom_minimum_size = Vector2(content_label.custom_minimum_size.x, min_height)
		
		# Wait another frame for size to update
		await get_tree().process_frame
	else:
		push_error("[Mail.load_mail] ERROR: content_label is null, cannot set text!")

# ---------- BUTTONS ----------
func _on_show_confirm() -> void:
	container.visible = true
	if confirm_button:
		confirm_button.visible = true
		confirm_button.connect("pressed", Callable(get_parent(), "_on_confirm_pressed"))

func _on_exit_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	queue_free()

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	if receiver:
		receiver.text = receiver_name
	if subject:
		subject.text = ""
	if main_text:
		if main_text is RichTextLabel:
			main_text.bbcode_enabled = true
			main_text.autowrap_mode = 3
	else:
		# Try to find it manually
		var found = get_node_or_null("MarginContainer/NinePatchRect/MarginContainer/MarginContainer/Main/ScrollContainer/Mail_contents/Main/Content")
		if found:
			if found is RichTextLabel:
				main_text = found
				main_text.bbcode_enabled = true
				main_text.autowrap_mode = 3
	if confirm_button:
		container.visible = false
		confirm_button.visible = false

# ---------- MAKE DRAGGABLE ----------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = mail.global_position - get_global_mouse_position()
			else:
				is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		mail.global_position = get_global_mouse_position() + drag_offset
