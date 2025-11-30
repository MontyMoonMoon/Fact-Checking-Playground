extends CanvasLayer

var master: Master
var scene_loader: SceneLoader
var data_manager: DataManager
var sound_manager: SoundManager

@onready var mail_notif_button: Button = get_node("TitleScreenContainer/MailNotif") as Button
var mail_notif_rest_position := Vector2.ZERO
var is_mail_notif_animating := false

@export_group("Container")
@export var titlescreen_container: MarginContainer
@export_group("Buttons")
@export var buttons: Array[Button] = []
@export var buttons_containers: Array[VBoxContainer] = []
@export_group("Player")
@export var name_edit: LineEdit

var player_name: String = ""
var is_first_time := true

# ---------- SIGNALS ----------
signal show_error(error_code: String)

# ---------- PREFABS ----------
@onready var message: PackedScene = preload("res://Prefabs/Components/error_message.tscn")
@onready var settings: PackedScene = preload("res://Prefabs/Components/settings.tscn")
@onready var mail: PackedScene = preload("res://Prefabs/Components/mail.tscn")

# ---------- BUTTON FUNCTIONS ----------
func _on_play_pressed() -> void:
	if not _validate_player_name():
		return
	
	player_name = name_edit.text.strip_edges()
	print(" [Map_0.on_play_pressed] Player name entered: ", player_name)
	master.sound_manager.play_sound("mouse_click")
	
	get_button(6).visible = true
	
	# Ensure MailNotif is set up before animating
	if mail_notif_rest_position == Vector2.ZERO:
		await _setup_mail_notif()
	
	_animate_mail_notif_show()
	master.sound_manager.play_sound("notif_sound")

func _on_mail_pressed() -> void:
	_animate_mail_notif_hide()
	master.sound_manager.play_sound("mouse_click")
	_open_mail()

func _on_continue_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	_load_game()

func _on_settings_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	_open_settings()

func _on_credits_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	# TODO: make the credits here!
	pass

func _on_help_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	# TODO: open help panel here!
	pass

func _on_exit_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

# ---------- MAIL NOTIF ANIMATION ----------
func _setup_mail_notif() -> void:
	if not mail_notif_button:
		print("[MailNotif] ERROR: mail_notif_button is null!")
		return
	
	# Wait for everything to be ready
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame to ensure parent is laid out
	
	# Switch to anchors mode for manual positioning (1 = anchors mode)
	mail_notif_button.layout_mode = 1
	
	# Get viewport and parent container sizes
	var viewport_size = get_viewport().get_visible_rect().size
	var parent_container = mail_notif_button.get_parent()
	var parent_size = parent_container.size if parent_container else viewport_size
	
	print("[MailNotif Setup] Viewport size: ", viewport_size, " Parent size: ", parent_size)
	
	# Set anchors to bottom-left of parent container
	mail_notif_button.anchor_left = 0.0
	mail_notif_button.anchor_top = 1.0
	mail_notif_button.anchor_right = 0.0
	mail_notif_button.anchor_bottom = 1.0
	
	# Position at bottom-left with proper offsets
	var button_height = mail_notif_button.custom_minimum_size.y
	var button_width = mail_notif_button.custom_minimum_size.x
	
	print("[MailNotif Setup] Button size: ", Vector2(button_width, button_height))
	
	# Set offsets for bottom-left positioning
	mail_notif_button.offset_left = 0
	mail_notif_button.offset_bottom = 0  # Bottom edge at parent's bottom
	mail_notif_button.offset_top = -button_height  # Top edge is button_height above bottom
	mail_notif_button.offset_right = button_width
	
	# Force update and verify
	mail_notif_button.queue_redraw()
	await get_tree().process_frame
	
	# If anchors didn't work, position it directly at bottom-left
	var current_pos = mail_notif_button.position
	var expected_y = parent_size.y - button_height
	
	print("[MailNotif Setup] Current position: ", current_pos, " Expected Y: ", expected_y)
	
	# If position is wrong (at top), fix it manually
	if current_pos.y < parent_size.y * 0.5:  # If it's in the top half
		print("[MailNotif] Anchors didn't work, positioning manually to: ", Vector2(0, expected_y))
		mail_notif_button.position = Vector2(0, expected_y)
		await get_tree().process_frame
	
	# Cache the rest position for animation
	mail_notif_rest_position = mail_notif_button.position
	
	# Verify final position
	var final_pos = mail_notif_button.position
	print("[MailNotif Setup] Final Position: ", final_pos, " Rest position cached: ", mail_notif_rest_position)
	
	# Start hidden
	mail_notif_button.visible = false

func _animate_mail_notif_show() -> void:
	if not mail_notif_button:
		print("[MailNotif] ERROR: mail_notif_button is null in _animate_mail_notif_show!")
		return
	
	if is_mail_notif_animating:
		print("[MailNotif] Animation already in progress, skipping")
		return
	
	is_mail_notif_animating = true
	
	# Wait a frame to ensure everything is ready
	await get_tree().process_frame
	
	# Ensure setup is complete before animating
	if mail_notif_rest_position == Vector2.ZERO:
		print("[MailNotif] Rest position not cached, calling setup first")
		await _setup_mail_notif()
		await get_tree().process_frame
	
	# Get viewport and parent sizes
	var viewport_size = get_viewport().get_visible_rect().size
	var parent_container = mail_notif_button.get_parent()
	var parent_size = parent_container.size if parent_container else viewport_size
	
	# Recalculate rest position if still zero (shouldn't happen, but safety check)
	if mail_notif_rest_position == Vector2.ZERO:
		var button_height = mail_notif_button.size.y if mail_notif_button.size.y > 0 else mail_notif_button.custom_minimum_size.y
		mail_notif_rest_position = Vector2(0, parent_size.y - button_height)
		print("[MailNotif Animation] Calculated rest position as fallback: ", mail_notif_rest_position)
	
	# CRITICAL: Ensure button is positioned at rest position first (in case it's at top-left)
	# This prevents the first animation from starting from the wrong position
	mail_notif_button.position = mail_notif_rest_position
	await get_tree().process_frame  # Wait for position to be set
	
	# Calculate start position: below the screen
	# Start Y should be GREATER than rest Y (below it)
	var start_y = mail_notif_rest_position.y + viewport_size.y  # Start well below the rest position
	
	# Set start position (off-screen below, maintaining X)
	mail_notif_button.position = Vector2(mail_notif_rest_position.x, start_y)
	mail_notif_button.visible = true
	
	# Wait one more frame to ensure position is set before animating
	await get_tree().process_frame
	
	# Animate upward to rest position
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(mail_notif_button, "position", mail_notif_rest_position, 0.6)
	tween.tween_callback(Callable(self, "_on_mail_notif_show_finished"))

func _animate_mail_notif_hide() -> void:
	if not mail_notif_button or is_mail_notif_animating:
		return
	
	is_mail_notif_animating = true
	
	# Get viewport and parent sizes
	var viewport_size = get_viewport().get_visible_rect().size
	var parent_container = mail_notif_button.get_parent()
	var parent_size = parent_container.size if parent_container else viewport_size
	
	# Calculate end position: below the screen
	var button_height = mail_notif_button.size.y if mail_notif_button.size.y > 0 else mail_notif_button.custom_minimum_size.y
	var end_y = parent_size.y + button_height
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(mail_notif_button, "position", Vector2(0, end_y), 0.4)
	tween.tween_callback(Callable(self, "_on_mail_notif_hide_finished"))

func _on_mail_notif_show_finished() -> void:
	is_mail_notif_animating = false

func _on_mail_notif_hide_finished() -> void:
	if mail_notif_button:
		mail_notif_button.visible = false
	is_mail_notif_animating = false

# ---------- HELPER FUNCTIONS ----------
func _validate_player_name() -> bool:
	if name_edit.text.strip_edges() == "":
		var msg_instance = add_child_scene(message)
		msg_instance.master = master
		connect("show_error", Callable(msg_instance, "show_error"))
		emit_signal("show_error", "Empty_name")
		master.sound_manager.play_sound("error_sound")
		return false
	return true

func _open_mail() -> void:
	var mail_instance = add_child_scene(mail)
	mail_instance.master = master
	mail_instance.receiver_name = player_name
	
	var mail_info = master.json_manager.mails.get("mail_1", null)
	if mail_info != null and mail_instance.has_method("load_mail"):
		mail_instance.load_mail(mail_info)
	
	mail_instance._on_show_confirm()
	await get_tree().create_timer(0.2).timeout
	get_button(6).visible = false

func _load_game() -> void:
	DataManager.load_data()
	var data = DataManager.player_data
	var saved_player_name = data.get("player_name", "")
	var saved_current_map = data.get("current_map", "map_01")
	
	if saved_player_name == "":
		print(" [Map_0._on_continue_pressed] No save data found or name empty.")
		return
	
	player_name = saved_player_name
	print(" [Map_0._on_continue_pressed] Loaded player: ", player_name)
	print(" [Map_0._on_continue_pressed] Loading saved map: ", saved_current_map)
	
	# Map scene names to scene IDs
	var scene_id = 1  # Default to map_01
	match saved_current_map:
		"map_01":
			scene_id = 1
		"map_02":
			scene_id = 2
		"map_03":
			scene_id = 3
		_:
			scene_id = 1  # Default fallback
	
	master.scene_loader.load_by_id(scene_id)

func _open_settings() -> void:
	var settings_instance = settings.instantiate()
	settings_instance.master = master
	titlescreen_container.add_child(settings_instance)
	settings_instance.main_button.disabled = true
	settings_instance.pause_button.disabled = true
	settings_instance.help_button.disabled = true

# ---------- BUTTON MANAGER ----------
func get_button(index: int) -> Button:
	if index >= 0 and index < buttons.size():
		return buttons[index]
	return null

func set_buttons_disabled(disabled: bool) -> void:
	for button in buttons:
		if button:
			button.disabled = disabled

func set_container(index: int) -> VBoxContainer:
	if index >= 0 and index < buttons_containers.size():
		return buttons_containers[index]
	return null

# ---------- CHILD SCENE MANAGER ----------
func add_child_scene(scene: PackedScene) -> Node:
	var inst = scene.instantiate()
	add_child(inst)
	set_buttons_disabled(true)
	inst.connect("tree_exited", Callable(self, "_on_child_closed"))
	return inst

func _on_child_closed() -> void:
	set_buttons_disabled(false)

# ---------- CONFIRM PRESSED ----------
func _on_confirm_pressed() -> void:
	DataManager.player_name = player_name
	DataManager.player_integrity = 100
	DataManager.current_act = 1
	DataManager.save_data()
	_clear_all_game_data_for_new_game()
	master.scene_loader.load_by_id(1)

func _clear_all_game_data_for_new_game() -> void:
	"""Clear ALL game data files and caches before starting a new game"""
	print("[map_0] Clearing all game data files for NEW GAME...")
	
	var dir = DirAccess.open("user://")
	if not dir:
		push_warning("[map_0] Failed to open user:// directory")
		return
	
	var files_to_clear = [
		"collected_infos.json",
		"messages.json",
		"notes.json",
		"published_articles.json",
		"dataset_additions.json",
		"trashed_infos.json",
		"todos_texts.json"
	]
	
	for file_name in files_to_clear:
		if dir.file_exists(file_name):
			var error = dir.remove(file_name)
			if error == OK:
				print("[map_0] Deleted: %s" % file_name)
			else:
				push_warning("[map_0] Failed to delete %s: error %d" % [file_name, error])
		
		if file_name in ["messages.json", "notes.json", "collected_infos.json", "published_articles.json", "dataset_additions.json", "trashed_infos.json"]:
			JSONManager.save_json("user://%s" % file_name, [])
			print("[map_0] Created empty: %s" % file_name)
	
	_clear_json_manager_caches()
	print("[map_0] All game data files cleared and recreated as empty")

func _clear_json_manager_caches() -> void:
	var json_manager_singleton = JSONManager.get_instance()
	if json_manager_singleton:
		json_manager_singleton.messages_cache = []
		json_manager_singleton.collected_infos_cache = []
		json_manager_singleton.notes_cache = []
		print("[map_0] Cleared JSONManager caches (messages, collected_infos, notes)")
	elif master and master.json_manager:
		master.json_manager.messages_cache = []
		master.json_manager.collected_infos_cache = []
		master.json_manager.notes_cache = []
		print("[map_0] Cleared JSONManager caches via master")

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	if master == null:
		print("[WARN: map_0._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	get_button(6).visible = false
	
	# Reset animation state on ready
	mail_notif_rest_position = Vector2.ZERO
	is_mail_notif_animating = false
	
	# Setup MailNotif - use call_deferred to ensure it runs after everything is ready
	# This ensures the rest position is cached before the first animation
	if mail_notif_button:
		call_deferred("_setup_mail_notif")
	
	_check_save_file()

func _check_save_file() -> void:
	if FileAccess.file_exists("user://save_data.json"):
		print("[Map_0.ready] Save file found!")
		var container = set_container(1)
		if container:
			container.visible = true
		is_first_time = false
	else:
		print("[Map_0.ready] No save file!")
		is_first_time = true
	
	if not is_first_time:
		var container = set_container(1)
		if container:
			container.visible = true
