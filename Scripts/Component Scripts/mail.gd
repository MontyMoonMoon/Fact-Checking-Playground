extends Control

var master: Master
var data_manager: DataManager
var receiver_name: String = "" 

@onready var mail: Control = $"."

@export_group("Mail Texts")
@export var receiver: Label
@export var sender: Label
@export var subject: Label
@export var main_text: RichTextLabel

@export_subgroup("Button")
@export var confirm_button: Button

var is_dragging := false
var drag_offset := Vector2.ZERO

func load_mail(mail_dict: Dictionary) -> void:
	print("========== [Mail.load_mail] CALLED ==========")
	print("[Mail] mail_dict keys: ", mail_dict.keys())
	
	if not is_inside_tree():
		await ready
	
	print("[Mail] After ready check")
	
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
	
	push_error("[Mail] Text content to display: " + str(text_content.length()) + " chars")
	push_error("[Mail] Text content preview: " + text_content.substr(0, min(100, text_content.length())))
	
	# Try to get main_text node
	var content_label: RichTextLabel = main_text
	
	push_error("[Mail] main_text @export is null: " + str(main_text == null))
	
	# Fallback: find node manually if @export didn't work
	if not content_label:
		push_error("[Mail] @export failed, trying manual find...")
		content_label = get_node_or_null("MarginContainer/NinePatchRect/MarginContainer/MarginContainer/Main/ScrollContainer/Mail_contents/Main/Content") as RichTextLabel
		if content_label:
			push_error("[Mail] Found Content node manually")
		else:
			push_error("[Mail] Manual find also failed!")
	
	if content_label:
		push_error("[Mail] Setting text on RichTextLabel, content length: " + str(text_content.length()))
		
		# Configure RichTextLabel BEFORE setting text
		content_label.bbcode_enabled = true
		content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_label.visible = true
		content_label.modulate = Color.WHITE  # Ensure it's not transparent
		content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Allow expansion
		
		# Ensure text color is visible (black)
		content_label.add_theme_color_override("default_color", Color.BLACK)
		
		# Check if RichTextLabel has a minimum size
		if content_label.custom_minimum_size.y == 0:
			content_label.custom_minimum_size = Vector2(490, 0)  # Allow vertical expansion
		
		# Set the text directly - RichTextLabel handles BBCode when bbcode_enabled is true
		content_label.text = text_content
		
		push_error("[Mail] Text set directly, RichTextLabel.text length: " + str(content_label.text.length()))
		push_error("[Mail] RichTextLabel visible: " + str(content_label.visible))
		push_error("[Mail] RichTextLabel size: " + str(content_label.size))
		push_error("[Mail] RichTextLabel custom_minimum_size: " + str(content_label.custom_minimum_size))
		push_error("[Mail] RichTextLabel modulate: " + str(content_label.modulate))
		push_error("[Mail] RichTextLabel bbcode_enabled: " + str(content_label.bbcode_enabled))
		push_error("[Mail] RichTextLabel text preview (first 100): " + content_label.text.substr(0, min(100, content_label.text.length())))
		
		# Force update
		content_label.queue_redraw()
		
		# Wait and verify
		await get_tree().process_frame
		push_error("[Mail] After frame - text length: " + str(content_label.text.length()))
		push_error("[Mail] After frame - size: " + str(content_label.size))
		
		# Check if text is actually visible
		if content_label.text.length() > 0:
			var parent_scroll = content_label.get_parent()
			if parent_scroll and parent_scroll is ScrollContainer:
				push_error("[Mail] Parent ScrollContainer size: " + str(parent_scroll.size))
				push_error("[Mail] Parent ScrollContainer visible: " + str(parent_scroll.visible))
		
		# Double-check: if text is set but not showing, try forcing a re-render
		if content_label.text.length() > 0 and content_label.size.y == 0:
			push_error("[Mail] WARNING: Text set but size.y is 0! Forcing minimum size...")
			content_label.custom_minimum_size = Vector2(490, 200)  # Force a height
			await get_tree().process_frame
			push_error("[Mail] After forcing size - size: " + str(content_label.size))
	else:
		push_error("[Mail.load_mail] Could not find Content RichTextLabel node!")

# ---------- BUTTONS ----------
func _on_show_confirm() -> void:
	if confirm_button:
		confirm_button.visible = true
		confirm_button.connect("pressed", Callable(get_parent(), "_on_confirm_pressed"))

func _on_exit_pressed() -> void:
	queue_free()

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	push_error("========== [Mail._ready] CALLED ==========")
	push_error("[Mail._ready] main_text @export is null: " + str(main_text == null))
	
	if receiver:
		receiver.text = receiver_name
	if subject:
		subject.text = ""
	if main_text:
		print("[Mail._ready] main_text found, setting up...")
		if main_text is RichTextLabel:
			main_text.bbcode_enabled = true
			main_text.autowrap_mode = 3
			print("[Mail._ready] RichTextLabel configured")
		else:
			print("[Mail._ready] WARNING: main_text is not a RichTextLabel!")
	else:
		print("[Mail._ready] WARNING: main_text @export is null! Will need to find manually.")
		# Try to find it manually
		var found = get_node_or_null("MarginContainer/NinePatchRect/MarginContainer/MarginContainer/Main/ScrollContainer/Mail_contents/Main/Content")
		if found:
			print("[Mail._ready] Found Content node manually: ", found.get_class())
			if found is RichTextLabel:
				main_text = found
				main_text.bbcode_enabled = true
				main_text.autowrap_mode = 3
				print("[Mail._ready] Configured manually found RichTextLabel")
	if confirm_button:
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
