extends CanvasLayer

var master: Master
var scene_loader: SceneLoader
var data_manager: DataManager
var sound_manager: SoundManager

@onready var mail_notif_button: Button = get_node("TitleScreenContainer/MailNotif") as Button
var mail_notif_rest_position := Vector2.ZERO
var is_mail_notif_animating := false
var is_mail_notif_position_cached := false
const MAIL_NOTIF_POP_OFFSET := 220.0

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
	if name_edit.text.strip_edges() == "":
		var msg_instance = add_child_scene(message)
		msg_instance.master = master
		connect("show_error", Callable(msg_instance, "show_error"))
		emit_signal("show_error", "Empty_name")
		master.sound_manager.play_sound("error_sound")
	else:
		player_name = name_edit.text.strip_edges()
		print(" [Map_0.on_play_pressed] Player name entered: ", player_name)
		master.sound_manager.play_sound("mouse_click")
		
		get_button(6).visible = true
		_play_mail_notif_pop_animation(true)
		master.sound_manager.play_sound("notif_sound")

func _on_mail_pressed() -> void:
	_play_mail_notif_pop_animation()
	master.sound_manager.play_sound("mouse_click")
	var mail_instance = add_child_scene(mail)
	mail_instance.master = master
	
	mail_instance.receiver_name = player_name  
	
	var mail_info = master.json_manager.mails.get("mail_1", null)
	if mail_info != null and mail_instance.has_method("load_mail"):
		mail_instance.load_mail(mail_info)
	
	mail_instance._on_show_confirm()
	
	await get_tree().create_timer(0.2).timeout
	get_button(6).visible = false

func _play_mail_notif_pop_animation(force_reveal := false) -> void:
	if not mail_notif_button or is_mail_notif_animating:
		return
	
	if force_reveal:
		mail_notif_button.visible = true
	
	if not is_mail_notif_position_cached:
		mail_notif_rest_position = mail_notif_button.position
		is_mail_notif_position_cached = true
	
	var target_position := mail_notif_rest_position
	var start_position := target_position + Vector2(0, MAIL_NOTIF_POP_OFFSET + mail_notif_button.size.y)
	
	is_mail_notif_animating = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(mail_notif_button, "position", target_position, 0.4).from(start_position)
	tween.tween_callback(Callable(self, "_on_mail_notif_pop_animation_finished"))

func _on_mail_notif_pop_animation_finished() -> void:
	if mail_notif_button:
		mail_notif_button.position = mail_notif_rest_position
	is_mail_notif_animating = false

func _on_continue_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	DataManager.load_data()
	
	var data = DataManager.player_data
	var saved_player_name = data.get("player_name", "")
	var saved_current_act = data.get("current_act", "")
	
	if saved_player_name == "":
		print(" [Map_0._on_continue_pressed] No save data found or name empty.")
		return
	
	player_name = saved_player_name
	print(" [Map_0._on_continue_pressed] Loaded player: ", player_name)
	
	if saved_current_act != 0:
		master.scene_loader.load_by_id(saved_current_act)
	else:
		push_error(" [Map_0._on_continue_pressed] Can't load that scene. . .")

func _on_settings_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	var settings_instance = settings.instantiate()
	settings_instance.master = master
	titlescreen_container.add_child(settings_instance)
	
	settings_instance.main_button.disabled = true
	settings_instance.pause_button.disabled = true
	settings_instance.help_button.disabled = true

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
	#master.sound_manager.play_sound("mouse_click")
	DataManager.player_name = player_name
	DataManager.player_integrity = 100
	DataManager.current_act = 1
	DataManager.save_data()
	
	# CRITICAL: Clear ALL game data files BEFORE loading new game scene
	_clear_all_game_data_for_new_game()
	
	master.scene_loader.load_by_id(1)

func _clear_all_game_data_for_new_game() -> void:
	"""Clear ALL game data files and caches before starting a new game"""
	print("[map_0] Clearing all game data files for NEW GAME...")
	
	var dir = DirAccess.open("user://")
	if not dir:
		push_warning("[map_0] Failed to open user:// directory")
		return
	
	# Delete and recreate files as empty arrays/objects
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
		
		# Immediately create empty file to prevent JSONManager from auto-initializing
		if file_name == "messages.json" or file_name == "notes.json" or file_name == "collected_infos.json" or file_name == "published_articles.json" or file_name == "dataset_additions.json" or file_name == "trashed_infos.json":
			JSONManager.save_json("user://%s" % file_name, [])
			print("[map_0] Created empty: %s" % file_name)
	
	# Clear JSONManager caches to ensure fresh load
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
	
	print("[map_0] All game data files cleared and recreated as empty")

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[WARN: map_0._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	get_button(6).visible = false
	if mail_notif_button:
		mail_notif_rest_position = mail_notif_button.position
		is_mail_notif_position_cached = true
	
	if FileAccess.file_exists("user://save_data.json"):
		print("[Map_0.ready] Save file found!")
		var container = set_container(1)
		if container:
			container.visible = true
		is_first_time = false
	else:
		print("[Map_0.ready] No save file!")
		is_first_time = true
	
	if is_first_time == false:
		var container = set_container(1)
		if container:
			container.visible = true
