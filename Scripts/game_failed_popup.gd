extends Control
class_name GameFailedPopup

@onready var message_label: Label = $PopupContainer/VBoxContainer/MarginContainer/MessageLabel
@onready var breakdown_label: RichTextLabel = $PopupContainer/VBoxContainer/BreakdownContainer/BreakdownLabel
@onready var close_button: Button = $PopupContainer/VBoxContainer/ButtonContainer/CloseButton

var game_failed_state: bool = false

func _ready():
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if breakdown_label:
		breakdown_label.bbcode_enabled = true

func show_breakdown(breakdown: Dictionary, stats: Dictionary):
	game_failed_state = stats.get("final_score", 0.0) < 6.0
	var final_score = stats.get("final_score", 0.0)
	
	# Update title
	if message_label:
		if game_failed_state:
			message_label.text = "GAME FAILED"
			message_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
		else:
			message_label.text = "DAY COMPLETE"
			message_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3, 1))
	
	# Calculate gained and lost scores
	var gained_score = 0.0
	var lost_score = 0.0
	
	var analyzed_bonus = breakdown.get("articles_analyzed_bonus", 0.0)
	if analyzed_bonus > 0.0:
		gained_score += analyzed_bonus
	elif analyzed_bonus < 0.0:
		lost_score += abs(analyzed_bonus)
	
	gained_score += breakdown.get("high_overlap_bonus", 0.0)
	gained_score += breakdown.get("articles_added_bonus", 0.0)
	lost_score += breakdown.get("articles_removed_penalty", 0.0)
	
	# Build breakdown text
	var text = "[b]INTEGRITY BREAKDOWN[/b]\n\n"
	text += "[color=green][b]Gained:[/b] +%.2f[/color]\n" % gained_score
	text += "[color=red][b]Lost:[/b] -%.2f[/color]\n" % lost_score
	text += "\n[b]────────────────────[/b]\n"
	
	if game_failed_state:
		text += "[color=red][b]TOTAL:[/b] %.2f / 10.0[/color]\n" % final_score
	else:
		text += "[color=green][b]TOTAL:[/b] %.2f / 10.0[/color]\n" % final_score
	
	# Set breakdown text first
	if breakdown_label:
		breakdown_label.text = text
		breakdown_label.visible = true
		breakdown_label.custom_minimum_size = Vector2(700, 200)
	
	# Update button
	if close_button:
		close_button.text = "End Game" if game_failed_state else "Close"
	
	# Show popup and ensure proper sizing
	visible = true
	show()
	z_index = 1000
	
	# Ensure containers are visible and properly sized after layout
	call_deferred("_ensure_popup_size")

func _on_close_pressed():
	get_tree().paused = false
	visible = false
	
	if game_failed_state:
		# Go to main menu
		var master = get_node_or_null("/root/Master")
		if master and master.scene_loader:
			master.scene_loader.load_by_id(0)
		else:
			get_tree().change_scene_to_file("res://Scenes/map_0.tscn")
		queue_free()
	else:
		# Reset game in current scene
		_reset_game()
		queue_free()

func _reset_game():
	var scene_root = get_tree().current_scene
	if not scene_root:
		return
	
	# Find GameManager
	var game_manager = scene_root.find_child("GameManager", true, false)
	
	if game_manager and game_manager.has_method("start_game"):
		# Reset via GameManager
		call_deferred("_call_start_game", game_manager)
	else:
		# Fallback: reload scene
		var scene_path = scene_root.scene_file_path
		if scene_path:
			call_deferred("_reload_scene")

func _call_start_game(game_manager: GameManager):
	if game_manager and is_instance_valid(game_manager):
		game_manager.start_game()

func _reload_scene():
	get_tree().reload_current_scene()

func _ensure_popup_size():
	var popup_container = get_node_or_null("PopupContainer")
	if popup_container:
		popup_container.visible = true
		# Ensure proper size - set offsets for centered container
		popup_container.set_anchors_preset(Control.PRESET_CENTER)
		popup_container.offset_left = -400
		popup_container.offset_top = -250
		popup_container.offset_right = 400
		popup_container.offset_bottom = 250
	
	if breakdown_label:
		var breakdown_container = breakdown_label.get_parent()
		if breakdown_container:
			breakdown_container.visible = true
