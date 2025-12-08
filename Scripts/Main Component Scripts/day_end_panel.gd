extends Control
class_name DayEndPanel

var master: Master
var sound_manager: SoundManager

@export var button: Button
@export var article_number_container: VBoxContainer

@export_group("Text Content")
@export var header: Label
@export var total: Label

# Article rows - up to 5 articles can be displayed
@export var article_rows: Array[HBoxContainer] = []

var game_failed_state: bool = false
var complete := false

# ---------- METHODS ----------
func show_breakdown(breakdown: Dictionary, stats: Dictionary):
	"""Show day end breakdown with article scores and total"""
	game_failed_state = stats.get("final_score", 0.0) < 6.0
	var final_score = stats.get("final_score", 0.0)
	complete = not game_failed_state
	
	# Update header
	if header:
		if game_failed_state:
			header.text = "GAME FAILED"
			header.add_theme_color_override("font_color", Color(0.722, 0.298, 0.298, 1))
		else:
			header.text = "DAY COMPLETE"
			header.add_theme_color_override("font_color", Color(0.353, 0.549, 0.353, 1))
	
	# Get integrity increments and decrements from breakdown
	var increments = breakdown.get("integrity_increments", {})
	var decrements = breakdown.get("integrity_decrements", {})
	
	# If increments/decrements are not dictionaries, initialize them
	if typeof(increments) != TYPE_DICTIONARY:
		increments = {}
	if typeof(decrements) != TYPE_DICTIONARY:
		decrements = {}
	
	# Extract values - ensure they're numbers
	var correct_ai_analysis = float(increments.get("correct_ai_analysis", 0.0))
	var correct_messages = float(increments.get("correct_messages", 0.0))
	var correct_articles_published = float(increments.get("correct_articles_published", 0.0))
	
	# Combine losses from spam, incorrect AI analysis, and incorrect articles
	var spam_loss = float(decrements.get("spam_emails", 0.0))
	var incorrect_ai_loss = float(decrements.get("incorrect_ai_analysis", 0.0))
	var incorrect_articles_loss = float(decrements.get("incorrect_articles_published", 0.0))
	var total_loss = spam_loss + incorrect_ai_loss + incorrect_articles_loss
	var decay_loss = float(decrements.get("decay", 0.0))
	
	# Update HBox rows (5 total: 3 increments, 2 decrements)
	var hbox_containers = []
	# Find MainText directly - it's at Content/TextsContainer/Contents/MainText
	var main_text = get_node_or_null("Content/TextsContainer/Contents/MainText")
	if not main_text:
		main_text = find_child("MainText", true, false)
	
	if main_text:
		for child in main_text.get_children():
			if child is HBoxContainer:
				hbox_containers.append(child)
	
	# Get the Total label to match its width for alignment
	var total_container = get_node_or_null("Content/TextsContainer/Contents/Total/Texts")
	var total_label = null
	if total_container:
		for child in total_container.get_children():
			if child is Label and child.name == "Label" and child.text.begins_with("TOTAL"):
				total_label = child
				break
	
	var total_label_width = 80.0  # Default width from scene (matches Total label)
	if total_label:
		total_label_width = total_label.custom_minimum_size.x if total_label.custom_minimum_size.x > 0 else 80.0
	
	# Also match the HBox separation to Total section (25 instead of 94)
	var total_separation = 25.0
	if total_container and total_container.has_theme_constant("separation"):
		total_separation = total_container.get_theme_constant("separation")
	
	# HBox 1: AI Analysis
	if hbox_containers.size() > 0:
		var hbox = hbox_containers[0]
		hbox.add_theme_constant_override("separation", total_separation)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label1 = hbox.get_child(0) if hbox.get_child_count() > 0 else null
		var label2 = hbox.get_child(1) if hbox.get_child_count() > 1 else null
		if label1 and label1 is Label:
			label1.text = "AI Analysis"
			label1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label1.custom_minimum_size.x = total_label_width
			label1.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if label2 and label2 is Label:
			var ai_value = correct_ai_analysis if typeof(correct_ai_analysis) == TYPE_FLOAT else 0.0
			label2.text = "+ %.1f" % ai_value
			label2.add_theme_color_override("font_color", Color(0.353, 0.549, 0.353, 1))
			label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label2.custom_minimum_size = Vector2(0, 0)  # Remove minimum size to allow expansion
			# Force update
			label2.queue_redraw()
	
	# HBox 2: Messages
	if hbox_containers.size() > 1:
		var hbox = hbox_containers[1]
		hbox.add_theme_constant_override("separation", total_separation)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label1 = hbox.get_child(0) if hbox.get_child_count() > 0 else null
		var label2 = hbox.get_child(1) if hbox.get_child_count() > 1 else null
		if label1 and label1 is Label:
			label1.text = "Messages"
			label1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label1.custom_minimum_size.x = total_label_width
			label1.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if label2 and label2 is Label:
			var msg_value = correct_messages if typeof(correct_messages) == TYPE_FLOAT else 0.0
			label2.text = "+ %.1f" % msg_value
			label2.add_theme_color_override("font_color", Color(0.353, 0.549, 0.353, 1))
			label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label2.custom_minimum_size = Vector2(0, 0)  # Remove minimum size to allow expansion
			# Force update
			label2.queue_redraw()
	
	# HBox 3: Articles Published
	if hbox_containers.size() > 2:
		var hbox = hbox_containers[2]
		hbox.add_theme_constant_override("separation", total_separation)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label1 = hbox.get_child(0) if hbox.get_child_count() > 0 else null
		var label2 = hbox.get_child(1) if hbox.get_child_count() > 1 else null
		if label1 and label1 is Label:
			label1.text = "Articles Published"
			label1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label1.custom_minimum_size.x = total_label_width
			label1.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if label2 and label2 is Label:
			var art_value = correct_articles_published if typeof(correct_articles_published) == TYPE_FLOAT else 0.0
			label2.text = "+ %.1f" % art_value
			label2.add_theme_color_override("font_color", Color(0.353, 0.549, 0.353, 1))
			label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label2.custom_minimum_size = Vector2(0, 0)  # Remove minimum size to allow expansion
			# Force update
			label2.queue_redraw()
	
	# HBox 4: Loss (spam + incorrect AI + incorrect articles)
	if hbox_containers.size() > 3:
		var hbox = hbox_containers[3]
		hbox.add_theme_constant_override("separation", total_separation)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label1 = hbox.get_child(0) if hbox.get_child_count() > 0 else null
		var label2 = hbox.get_child(1) if hbox.get_child_count() > 1 else null
		if label1 and label1 is Label:
			label1.text = "Loss"
			label1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label1.custom_minimum_size.x = total_label_width
			label1.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if label2 and label2 is Label:
			var loss_value = total_loss if typeof(total_loss) == TYPE_FLOAT else 0.0
			label2.text = "- %.1f" % loss_value
			label2.add_theme_color_override("font_color", Color(0.722, 0.298, 0.298, 1))
			label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label2.custom_minimum_size = Vector2(0, 0)  # Remove minimum size to allow expansion
			# Force update
			label2.queue_redraw()
	
	# HBox 5: Decay
	if hbox_containers.size() > 4:
		var hbox = hbox_containers[4]
		hbox.add_theme_constant_override("separation", total_separation)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label1 = hbox.get_child(0) if hbox.get_child_count() > 0 else null
		var label2 = hbox.get_child(1) if hbox.get_child_count() > 1 else null
		if label1 and label1 is Label:
			label1.text = "Decay"
			label1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label1.custom_minimum_size.x = total_label_width
			label1.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if label2 and label2 is Label:
			var decay_value = decay_loss if typeof(decay_loss) == TYPE_FLOAT else 0.0
			label2.text = "- %.1f" % decay_value
			label2.add_theme_color_override("font_color", Color(0.722, 0.298, 0.298, 1))
			label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label2.custom_minimum_size = Vector2(0, 0)  # Remove minimum size to allow expansion
			# Force update
			label2.queue_redraw()
	
	# Update total score
	if total:
		var score_value = final_score if typeof(final_score) == TYPE_FLOAT else 0.0
		var total_text = "%.1f" % score_value
		total.text = total_text
		# Color code total: green if passed, red if failed
		if game_failed_state:
			total.add_theme_color_override("font_color", Color(0.722, 0.298, 0.298, 1))
		else:
			total.add_theme_color_override("font_color", Color(0.353, 0.549, 0.353, 1))
	
	# Update button
	if button:
		if game_failed_state:
			button.text = "Exit"
		else:
			# Check if we're on the final map (map_03)
			var is_final_map = false
			var master = get_node_or_null("/root/Master")
			if master and master.scene_loader:
				var current_scene_id = master.scene_loader.current_scene_id
				if current_scene_id == 3:  # map_03 is ID 3
					is_final_map = true
			
			# Fallback: check scene name
			if not is_final_map:
				var scene_root = get_tree().current_scene
				if scene_root:
					var scene_name = ""
					if scene_root.scene_file_path and scene_root.scene_file_path != "":
						scene_name = scene_root.scene_file_path.get_file().get_basename()
					else:
						scene_name = scene_root.name
					if scene_name == "map_03":
						is_final_map = true
			
			if is_final_map:
				button.text = "End Game"
			else:
				button.text = "Next Day"
		if button.pressed.is_connected(_on_next_pressed):
			button.pressed.disconnect(_on_next_pressed)
		button.pressed.connect(_on_next_pressed)
	
	# Ensure popup processes when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Show panel
	visible = true
	show()
	z_index = 1000
	
	# Ensure containers are visible and properly sized after layout
	call_deferred("_ensure_panel_size")

# ---------- BUTTON -----------
func _on_next_pressed() -> void:
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
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
		# Reset game in current scene or proceed to next day
		# Don't queue_free immediately - let the transition happen first
		_reset_game()
		# Queue free after a short delay to allow transition to complete
		call_deferred("queue_free")

func _reset_game():
	"""Reset game or proceed to next day - transitions to next map if on map scene"""
	# Get Master and SceneLoader first - this is the most reliable way
	var master = get_node_or_null("/root/Master")
	if not master or not master.scene_loader:
		print("[DayEndPanel] ERROR: Master or scene_loader not found!")
		return
	
	# Use SceneLoader's current_scene_id as the primary method (most reliable)
	var current_scene_id = master.scene_loader.current_scene_id
	print("[DayEndPanel] ===== TRANSITION DEBUG =====")
	print("[DayEndPanel] Current scene ID from SceneLoader: %d" % current_scene_id)
	print("[DayEndPanel] SceneLoader scenes array size: %d" % master.scene_loader.scenes.size())
	for i in range(master.scene_loader.scenes.size()):
		var scene = master.scene_loader.scenes[i]
		if scene:
			print("[DayEndPanel]   Scene[%d]: %s" % [i, scene.resource_path])
		else:
			print("[DayEndPanel]   Scene[%d]: NULL" % i)
	
	# Check if we're on a map scene (ID 1, 2, or 3)
	if current_scene_id >= 1 and current_scene_id <= 3:
		# If on map_03 (final map), go to main menu instead of looping back
		if current_scene_id == 3:
			print("[DayEndPanel] Final map (map_03) completed! Returning to main menu (map_0)")
			master.scene_loader.load_by_id(0)  # map_0 is ID 0
			print("[DayEndPanel] Successfully called scene_loader.load_by_id(0) - returning to main menu")
			return
		
		# Determine next map ID (only for map_01 and map_02)
		var next_map_id = 1  # Default to map_01
		match current_scene_id:
			1:
				next_map_id = 2  # map_01 -> map_02
			2:
				next_map_id = 3  # map_02 -> map_03
			# map_03 handled above - goes to map_0
		
		print("[DayEndPanel] Transitioning from scene ID %d to scene ID %d" % [current_scene_id, next_map_id])
		print("[DayEndPanel] SceneLoader scenes array size: %d" % master.scene_loader.scenes.size())
		if next_map_id < master.scene_loader.scenes.size():
			var scene_path = master.scene_loader.scenes[next_map_id].resource_path if master.scene_loader.scenes[next_map_id] else "null"
			print("[DayEndPanel] Scene at index %d exists: %s" % [next_map_id, scene_path])
		else:
			print("[DayEndPanel] ERROR: Scene ID %d is out of range! Max: %d" % [next_map_id, master.scene_loader.scenes.size() - 1])
			return
		
		# Save current map before transitioning
		var next_map_name = "map_01"
		match next_map_id:
			1:
				next_map_name = "map_01"
			2:
				next_map_name = "map_02"
			3:
				next_map_name = "map_03"
		
		DataManager.current_map = next_map_name
		DataManager.save_data()
		print("[DayEndPanel] Saved current_map: %s" % next_map_name)
		
		# Load the next map using SceneLoader
		print("[DayEndPanel] Calling scene_loader.load_by_id(%d)" % next_map_id)
		
		# IMPORTANT: Update current_scene_id BEFORE calling load_by_id to ensure it's set correctly
		# (load_by_id sets it, but we want to make sure the transition happens)
		
		master.scene_loader.load_by_id(next_map_id)
		print("[DayEndPanel] Successfully called scene_loader.load_by_id(%d) - transition initiated" % next_map_id)
		print("[DayEndPanel] SceneLoader current_scene_id after call: %d" % master.scene_loader.current_scene_id)
		# Return immediately - don't execute any reset logic
		return
	
	# Fallback: Try to detect from scene name if SceneLoader ID is not valid
	var scene_root = get_tree().current_scene
	if not scene_root:
		print("[DayEndPanel] ERROR: No current scene found!")
		return
	
	var current_scene_name = ""
	if scene_root.scene_file_path and scene_root.scene_file_path != "":
		current_scene_name = scene_root.scene_file_path.get_file().get_basename()
	else:
		current_scene_name = scene_root.name
	
	print("[DayEndPanel] Fallback: Detected scene name: %s" % current_scene_name)
	
	# Check if we're on a map scene by name
	if current_scene_name in ["map_01", "map_02", "map_03"]:
		# If on map_03 (final map), go to main menu instead of looping back
		if current_scene_name == "map_03":
			print("[DayEndPanel] Fallback: Final map (map_03) completed! Returning to main menu (map_0)")
			master.scene_loader.load_by_id(0)  # map_0 is ID 0
			return
		
		var next_map_id = 1
		match current_scene_name:
			"map_01":
				next_map_id = 2
			"map_02":
				next_map_id = 3
			# map_03 handled above - goes to map_0
		
		print("[DayEndPanel] Fallback: Transitioning from %s to map ID %d" % [current_scene_name, next_map_id])
		master.scene_loader.load_by_id(next_map_id)
		return
	
	# If not on a map scene, reset game in current scene
	print("[DayEndPanel] Not on a map scene (ID: %d, name: %s), resetting game in current scene" % [current_scene_id, current_scene_name])
	var game_manager = scene_root.find_child("GameManager", true, false)
	
	if game_manager and game_manager.has_method("start_game"):
		call_deferred("_call_start_game", game_manager)
	else:
		var scene_path = scene_root.scene_file_path
		if scene_path:
			call_deferred("_reload_scene")

func _call_start_game(game_manager: Node):
	if game_manager and is_instance_valid(game_manager):
		game_manager.start_game()

func _reload_scene():
	get_tree().reload_current_scene()

func _ensure_panel_size():
	"""Ensure panel is properly sized and visible"""
	var content = get_node_or_null("Content")
	if content:
		content.visible = true
		content.process_mode = Node.PROCESS_MODE_ALWAYS
		content.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if button:
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.mouse_filter = Control.MOUSE_FILTER_STOP

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[Day_end_panel._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	if master.sound_manager:
		sound_manager = master.sound_manager
	
	# Connect button if it exists
	if button:
		if not button.pressed.is_connected(_on_next_pressed):
			button.pressed.connect(_on_next_pressed)
	else:
		# Try to find button by name
		var next_button = find_child("Next", true, false)
		if next_button and next_button is Button:
			button = next_button
			if not button.pressed.is_connected(_on_next_pressed):
				button.pressed.connect(_on_next_pressed)
	
	# Find header if not exported
	if not header:
		header = find_child("Header", true, false)
		if not header:
			# Try to find it in the MainText container
			var main_text = find_child("MainText", true, false)
			if main_text:
				for child in main_text.get_children():
					if child is Label and child.text.contains("DAY"):
						header = child
						break
	
	# Find total label if not exported
	if not total:
		# First try to find the Total VBoxContainer, then find the Label inside it
		var total_container = find_child("Total", true, false)
		if total_container and total_container is VBoxContainer:
			# Look for the Label named "Total" inside the VBoxContainer
			total = total_container.find_child("Total", true, false)
			# If not found, try to find any Label in the Texts container
			if not total:
				var texts_container = total_container.find_child("Texts", true, false)
				if texts_container:
					for child in texts_container.get_children():
						if child is Label and child.name == "Total":
							total = child
							break
		# Fallback: search for any Label named "Total"
		if not total:
			var all_nodes = _get_all_children_recursive(self)
			for node in all_nodes:
				if node is Label and node.name == "Total":
					total = node
					break
	
	# Find button if not exported
	if not button:
		button = find_child("Next", true, false)
	
	# Initially hide panel
	visible = false

func _get_all_children_recursive(node: Node) -> Array:
	"""Helper function to get all children recursively"""
	var result = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_children_recursive(child))
	return result
