extends Panel

var master: Master
var sound_manager: SoundManager

@export var phone: Control

@export_group("Mesages: App")
@export var message_app: Panel
@export var chat_preview: MarginContainer
@export var chat_content: MarginContainer
@export var chats_scroll_container: VBoxContainer

# ---------- PREFAB ----------
var message_chats = preload("res://Prefabs/Components/message_chat.tscn")

# ---------- METHODS ----------
func _on_open_messages_app() -> void:
	master.sound_manager.play_sound("phone_click")
	set_ui(true, 1)
	set_ui(true, 2)

func spawn_messages_preview() -> void:
	print("[Message_app._on_open_messages_app] Spawning messages preview...")
	# TODO: Spawn the messages using data from JSONs or such.
	
	# For testing purposes!
	for i in range(5): 
		var chat_instance = message_chats.instantiate()
		chats_scroll_container.add_child(chat_instance)
		
		chat_instance.connect("open_chat", Callable(self, "_on_chat_opened"))

func _on_chat_opened() -> void:
	master.sound_manager.play_sound("phone_click")
	set_ui(false, 2)
	set_ui(true, 3)

# -------- UI HANDLER ----------
func set_ui(visibility: bool, target: int) -> void:
	match target:
		1: message_app.visible = visibility
		2: chat_preview.visible = visibility
		3: chat_content.visible = visibility

# ---------- BUTTONS ----------
func _on_messages_main_pressed() -> void:
	set_ui(false, 1)
	set_ui(false, 2)

func _on_chat_closed_pressed() -> void:
	master.sound_manager.play_sound("phone_click")
	set_ui(true, 2)
	set_ui(false, 3)

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[WARN: Message_app._ready] Master is still null. Calling members from this object may cause issues.")
		return
		
	if phone:
		phone.connect("open_message_app", Callable(self, "_on_open_messages_app"))
		phone.connect("close_all_apps", Callable(self, "_on_messages_main_pressed"))
	else:
		push_warning("[Messaging_app.ready] Phone is kinda missing...")
	
	spawn_messages_preview()
	
	# Default UI
	set_ui(false, 3)
