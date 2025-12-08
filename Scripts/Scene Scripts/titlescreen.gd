extends CanvasLayer

var master: Master
var scene_loader: SceneLoader
var data_manager: DataManager
var sound_manager: SoundManager

@export_group("Container")
@export var titlescreen_container: MarginContainer
@export var continue_button_container: VBoxContainer
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
@onready var help: PackedScene = preload("res://Prefabs/Components/help_panel.tscn")
@onready var credits: PackedScene = preload("res://Prefabs/Components/credits_panel.tscn")

# ---------- BUTTON FUNCTIONS ----------
func _on_play_pressed() -> void:
	if name_edit.text.strip_edges() == "":
		var msg_instance = add_child_scene(message)
		msg_instance.master = master
		connect("show_error", Callable(msg_instance, "show_error"))
		emit_signal("show_error", "Empty_name")
		master.sound_manager.play_sound("error_sound")
	elif name_edit.text == master.data_manager.player_name:
		var msg_instance = add_child_scene(message)
		msg_instance.master = master
		connect("show_error", Callable(msg_instance, "show_error"))
		emit_signal("show_error", "Same_name")
		master.sound_manager.play_sound("error_sound")
	else:
		player_name = name_edit.text.strip_edges()
		print(" [Map_0.on_play_pressed] Player name entered: ", player_name)
		master.sound_manager.play_sound("mouse_click")
		
		get_button(6).visible = true
		master.sound_manager.play_sound("notif_sound")

func _on_mail_pressed() -> void:
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

func _on_continue_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")

	# Load existing save data
	DataManager.load_data()

	# Grab the saved player data
	var data = DataManager.player_data
	var saved_player_name = data.get("player_name", "")
	var saved_current_map = data.get("current_map", "map_01")

	# Check if a valid save exists
	if saved_player_name == "":
		print("[Map_0._on_continue_pressed] No save data found or name empty.")
		return
	
	player_name = saved_player_name
	print("[Map_0._on_continue_pressed] Loaded player:", player_name)
	print("[Map_0._on_continue_pressed] Loading saved map:", saved_current_map)
	
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

func _on_settings_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	var settings_instance = add_child_scene(settings)
	settings_instance.master = master
	
	settings_instance.buttons_container.visible = false

func _on_credits_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	var credits_instance = add_child_scene(credits)
	credits_instance.master = master

func _on_help_pressed() -> void:
	master.sound_manager.play_sound("mouse_click")
	var help_instance = add_child_scene(help)
	help_instance.master = master

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
	master.sound_manager.play_sound("mouse_click")
	DataManager.create_new_save(name_edit.text)
	master.scene_loader.load_by_id(1)

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[WARN: map_0._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	# Play main menu music
	if master.sound_manager:
		call_deferred("_play_mainmenu_music")
	
	continue_button_container.visible = false
	get_button(6).visible = false
	
	SettingsManager.load_settings()
	
	if FileAccess.file_exists("user://save_data.json"):
		print("[Map_0.ready] Save file found!")
		set_container(1).visible = true
		is_first_time = false
		name_edit.text = master.data_manager.player_name
	else:
		print("[Map_0.ready] No save file!")
		is_first_time = true
	
	if is_first_time == false:
		continue_button_container.visible = true

func _play_mainmenu_music() -> void:
	"""Play main menu music"""
	if master and master.sound_manager:
		master.sound_manager.play_music("mainmenu")
