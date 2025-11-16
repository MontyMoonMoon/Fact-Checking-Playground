extends Control
class_name MobilePhone

var master: Master
var sound_manager: SoundManager

@export_group("Time & Date")
@export var time: Label 
@export var date: Label

@export_group("Containers")
@export var phone_main: NinePatchRect
@export var app_container: MarginContainer

# ---------- SIGNALS ----------
signal closed_phone

signal open_message_app
signal open_notes_app
signal open_contacts_app
signal close_all_apps

# ---------- PHONE: HOMESCREEN APPS ----------
func _on_messages_pressed() -> void:
	emit_signal("open_message_app")
	app_container.visible = true

func _on_notes_pressed() -> void:
	emit_signal("open_notes_app")
	app_container.visible = true

func _on_contacts_pressed() -> void:
	emit_signal("open_contacts_app")
	app_container.visible = true

# ---------- PHONE EXIT ----------
func _on_exit_phone_pressed() -> void:
	emit_signal("closed_phone")
	emit_signal("close_all_apps")
	app_container.visible = false

# ---------- GODOT CALLBACKS ----------
func _ready():
	master = get_node("/root/Master")
	
	if master == null:
		print("[WARN: Mobile_phone._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	TimeDateManager.load_days()
	date.text = TimeDateManager.day1
	
	app_container.visible = false
	emit_signal("close_all_apps")
	
