extends MarginContainer

var master: Master
var sound_manager: SoundManager

@onready var prompt_object: MarginContainer = $"."

@export var map_1: bool
@export var prompt_image: NinePatchRect
@export var prompt_button: Button
@export var prompt_content: MarginContainer

signal object_clicked

# ---------- BLINK ----------
var blink_tween: Tween
var is_blinking: bool = false

func blink() -> void:
	if is_blinking:
		return
	
	is_blinking = true
	blink_tween = create_tween()
	blink_tween.set_loops()
	
	blink_tween.tween_property(prompt_button, "modulate", Color(0.35, 0.35, 0.35, 1.0), 1.0)
	blink_tween.tween_property(prompt_button, "modulate", Color(1, 1, 1, 1), 1.0)

func stop_blink() -> void:
	is_blinking = false
	if blink_tween:
		blink_tween.kill()
	
	prompt_button.modulate = Color(1, 1, 1, 1)

# ---------- TOGGLE PROMPT ----------
func _on_prompt_object_pressed() -> void:
	master.sound_manager.play_sound("ui_click")
	
	if map_1 == true:
		var was_visible = prompt_content.visible
		prompt_content.visible = not was_visible

		stop_blink()

		if was_visible:
			emit_signal("object_clicked")
	else: 
		var was_visible = prompt_content.visible
		prompt_content.visible = not was_visible
		stop_blink()

func _input(event: InputEvent) -> void:
	if prompt_content.visible and event is InputEventMouseButton and event.pressed:
		var global_mouse_pos = event.position
		var rect = prompt_content.get_global_rect()
		
		if not rect.has_point(global_mouse_pos):
			prompt_content.visible = false

func _ready() -> void:
	master = get_node("/root/Master")
	
	blink()
