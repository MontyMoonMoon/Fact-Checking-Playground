extends Control

var master: Master
var sound_manager: SoundManager

@onready var tutorial: Control = $"."

@export var skip_text: MarginContainer
@export var text_display: Control
@export var panel: NinePatchRect
@export var instruction_label: Label
@export var input_blocker: Control
@export var laptop_blocker: Control
@export var settings: Control

@export_group("Tutorial Buttons")
@export var newspaper_main: MarginContainer
@export var phone_open: CanvasLayer
@export var laptop_open: CanvasLayer
@export var laptop_content: Control

var tutorial_steps: Array = []
var current_step_index: int = 0
var waiting_for_objective: bool = false
var current_required_input: String = "none"

var typing := false
var typing_speed := 0.04
var _full_text: String = ""

signal tutorial_done

# ---------- SHOW STEP ----------
func _show_current_step() -> void:
	var step = tutorial_steps[current_step_index]
	var required_input = step.get("required_input", "none")
	var text = step.get("text_content", "")

	print("Showing step", current_step_index, "required_input:", required_input)

	# Set state BEFORE starting typewriter so _input can behave predictably
	current_required_input = required_input
	waiting_for_objective = false
	input_blocker.visible = false  # normally visible only when waiting for objective

	# Set full text and start typewriter
	_full_text = text
	display_text(_full_text)

	if required_input != "none" and required_input != "next":
		pass

# ---------- INPUT HANDLING ----------
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("skip"):
		print("Input: skip pressed -> finishing tutorial")
		tutorial_finished()
		return

	if not tutorial.visible:
		return

	var next_pressed := (event.is_action_pressed("ui_next") or event.is_action_pressed("interact"))
	if not next_pressed:
		return

	if typing:
		print("Input: next pressed while typing -> finishing typewriter")
		typing = false
		instruction_label.text = _full_text
		return

	if waiting_for_objective:
		print("Input: next pressed but waiting_for_objective is true -> ignoring")
		return

	if current_required_input == "none":
		master.sound_manager.play_sound("ui_click")
		_next_step()
		return

	if current_required_input == "next":
		master.sound_manager.play_sound("ui_click")
		print("Input: 'next' required_input -> completing step")
		_on_objective_completed()
		return

	# Otherwise the step requires an objective; activate it.
	master.sound_manager.play_sound("ui_click")
	print("Input: activating required input:", current_required_input)
	text_display.visible = false
	input_blocker.visible = false
	waiting_for_objective = true
	_activate_required_input(current_required_input)

# ---------- ACTIVATE OBJECTIVE ----------
func _activate_required_input(objective: String) -> void:
	print("_activate_required_input:", objective)
	match objective:
		"newspaper":
			if not newspaper_main.is_connected("object_clicked", Callable(self, "_on_objective_completed")):
				newspaper_main.connect("object_clicked", Callable(self, "_on_objective_completed"))
			newspaper_main.blink()
			laptop_blocker.visible = true
			newspaper_main.prompt_button.disabled = false
		"phone":
			if not phone_open.is_connected("phone_opened", Callable(self, "_on_objective_completed")):
				phone_open.connect("phone_opened", Callable(self, "_on_objective_completed"))
			phone_open.phone_button_main.disabled = false
			panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			laptop_blocker.visible = true
			newspaper_main.prompt_button.disabled = true
		"phone_closed":
			if not phone_open.is_connected("phone_closed", Callable(self, "_on_objective_completed")):
				phone_open.connect("phone_closed", Callable(self, "_on_objective_completed"))
			phone_open.phone_button_main.disabled = false
			panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			laptop_blocker.visible = true
			newspaper_main.prompt_button.disabled = false
		"laptop":
			if not laptop_open.is_connected("laptop_opened", Callable(self, "_on_objective_completed")):
				laptop_open.connect("laptop_opened", Callable(self, "_on_objective_completed"))
			laptop_blocker.visible = false
			newspaper_main.prompt_button.disabled = true
			phone_open.phone_button_main.disabled = true
			laptop_content.exit_button.visible = false
		"email":
			if not laptop_content.is_connected("open_emails", Callable(self, "_on_objective_completed")):
				laptop_content.connect("open_emails", Callable(self, "_on_objective_completed"))
			settings.visible = false
		"exit":
			if not laptop_content.is_connected("close_app", Callable(self, "_on_objective_completed")):
				laptop_content.connect("close_app", Callable(self, "_on_objective_completed"))
		"evidence_bank":
			if not laptop_content.is_connected("open_evidences", Callable(self, "_on_objective_completed")):
				laptop_content.connect("open_evidences", Callable(self, "_on_objective_completed"))
			settings.visible = false
		"ai_analysis":
			if not laptop_content.is_connected("open_analysis", Callable(self, "_on_objective_completed")):
				laptop_content.connect("open_analysis", Callable(self, "_on_objective_completed"))
			settings.visible = false
		"article_publisher":
			if not laptop_content.is_connected("open_article_publisher", Callable(self, "_on_objective_completed")):
				laptop_content.connect("open_article_publisher", Callable(self, "_on_objective_completed"))
			settings.visible = false
		"trash_bin":
			if not laptop_content.is_connected("open_trash", Callable(self, "_on_objective_completed")):
				laptop_content.connect("open_trash", Callable(self, "_on_objective_completed"))
			settings.visible = false
		"exit_laptop":
			if not laptop_content.is_connected("close_laptop", Callable(self, "_on_objective_completed")):
				laptop_content.connect("close_laptop", Callable(self, "_on_objective_completed"))
			settings.visible = true
			laptop_content.exit_button.visible = true
		"next":
			print("_activate_required_input: got 'next' -> completing")
			_on_objective_completed()
		_:
			print("Unknown objective: ", objective)
			waiting_for_objective = false
			current_required_input = "none"
			input_blocker.visible = false

# ---------- OBJECTIVE COMPLETED ----------
func _on_objective_completed() -> void:
	print("_on_objective_completed called")
	waiting_for_objective = false
	current_required_input = "none"
	text_display.visible = true
	input_blocker.visible = true
	_next_step()

# ---------- NEXT STEp ----------
func _next_step() -> void:
	current_step_index += 1
	print("_next_step -> new index:", current_step_index, "total:", tutorial_steps.size())
	if current_step_index >= tutorial_steps.size():
		print("_next_step: reached end -> finishing")
		tutorial_finished()
	else:
		_show_current_step()

# ---------- TEXT / TYPEWRITER ----------
func display_text(text: String) -> void:
	_full_text = text
	instruction_label.text = ""
	_start_typewriter(_full_text)

func _start_typewriter(text: String) -> void:
	# Stop any ongoing typing
	typing = false
	await get_tree().process_frame

	typing = true
	instruction_label.text = ""

	for i in text.length():
		if not typing:
			# Typing cancelled; caller will set instruction_label.text to full text
			return
		instruction_label.text += text[i]
		await get_tree().create_timer(typing_speed).timeout

	# Finished typing
	typing = false
	print("Typewriter finished for step", current_step_index)

# ---------- DISCONNECT ----------
func _disconnect_all_objectives():
	if newspaper_main.is_connected("object_clicked", Callable(self, "_on_objective_completed")):
		newspaper_main.disconnect("object_clicked", Callable(self, "_on_objective_completed"))

	if phone_open.is_connected("phone_opened", Callable(self, "_on_objective_completed")):
		phone_open.disconnect("phone_opened", Callable(self, "_on_objective_completed"))

	if phone_open.is_connected("phone_closed", Callable(self, "_on_objective_completed")):
		phone_open.disconnect("phone_closed", Callable(self, "_on_objective_completed"))

	if laptop_open.is_connected("laptop_opened", Callable(self, "_on_objective_completed")):
		laptop_open.disconnect("laptop_opened", Callable(self, "_on_objective_completed"))

	if laptop_content.is_connected("open_emails", Callable(self, "_on_objective_completed")):
		laptop_content.disconnect("open_emails", Callable(self, "_on_objective_completed"))

	if laptop_content.is_connected("close_app", Callable(self, "_on_objective_completed")):
		laptop_content.disconnect("close_app", Callable(self, "_on_objective_completed"))

	if laptop_content.is_connected("open_evidences", Callable(self, "_on_objective_completed")):
		laptop_content.disconnect("open_evidences", Callable(self, "_on_objective_completed"))

	if laptop_content.is_connected("open_analysis", Callable(self, "_on_objective_completed")):
		laptop_content.disconnect("open_analysis", Callable(self, "_on_objective_completed"))

	if laptop_content.is_connected("open_article_publisher", Callable(self, "_on_objective_completed")):
		laptop_content.disconnect("open_article_publisher", Callable(self, "_on_objective_completed"))

	if laptop_content.is_connected("open_trash", Callable(self, "_on_objective_completed")):
		laptop_content.disconnect("open_trash", Callable(self, "_on_objective_completed"))

	if laptop_content.is_connected("close_laptop", Callable(self, "_on_objective_completed")):
		laptop_content.disconnect("close_laptop", Callable(self, "_on_objective_completed"))

# ---------- FINISH ----------
func tutorial_finished() -> void:
	print("Tutorial finished!")
	emit_signal("tutorial_done")
	_disconnect_all_objectives()

	tutorial.visible = false
	settings.visible = false
	newspaper_main.prompt_button.disabled = false
	phone_open.phone_button_main.disabled = false

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	text_display.visible = true
	laptop_blocker.visible = true
	input_blocker.visible = true
	settings.visible = true

	var json_mgr = JSONManager.get_instance()
	if json_mgr:
		tutorial_steps = json_mgr.load_tutorial_steps()
		print("Loaded tutorial steps:", tutorial_steps.size())

	_show_current_step()
	
