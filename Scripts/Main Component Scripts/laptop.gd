extends Control
class_name Laptop

var master: Master

@export_group("Laptop Containers")
@export var laptop_screen: Control
@export var home_screen: NinePatchRect
@export var app_main: MarginContainer

@export_group("Apps")
@export var app_name: Label
@export var emails: MarginContainer
@export var ai_analysis: MarginContainer
@export var evidence_bank: MarginContainer
@export var article_publisher: MarginContainer
@export var trash: MarginContainer
@export var trash_bin: MarginContainer
@export var time_label: Label = null

# ---------- VARIABLES & SIGNALS ----------
var laptop_screen_in := false
signal laptop_toggled()

var emails_controller: MarginContainer = null
var ai_analysis_controller: Node = null
var evidence_bank_controller: EvidenceBankController = null
var article_publisher_controller: ArticlePublisherController = null
var trash_controller: TrashController = null
var crash_glitch_effect: Node = null
var is_crashed: bool = false
var sound_manager: SoundManager = null
var glitch_sound_player: AudioStreamPlayer = null

signal open_emails
signal open_analysis
signal open_evidences
signal open_article_publisher

# ---------- APP CONTAINER MANAGER ----------
func set_ui(visibility: bool, target: int) -> void: 
	match target: 
		0:
			laptop_screen.visible = visibility
			home_screen.visible = visibility
		1:
			app_main.visible = visibility

func set_app(open: String) -> void:
	if emails:
		emails.visible = false
	if ai_analysis:
		ai_analysis.visible = false
	if evidence_bank:
		evidence_bank.visible = false
	if article_publisher:
		article_publisher.visible = false
	if trash:
		trash.visible = false

	if open.is_empty():
		return

	match open:
		"emails":
			if emails:
				emails.visible = true
		"ai_analysis":
			if ai_analysis:
				ai_analysis.visible = true
		"evidence_bank":
			if evidence_bank:
				evidence_bank.visible = true
		"article_publisher":
			if article_publisher:
				article_publisher.visible = true
			else:
				push_warning("Article Publisher node not found!")
		"trash":
			if trash:
				trash.visible = true
		_:
			push_warning("Unknown app: " + open)

# ---------- SET TEXT ----------
func set_text(text: String) -> void:
	app_name.text = text

# ---------- LAPTOP: BUTTON FUNCTIONS ----------
func _on_screen_pressed() -> void:
	sound_manager.play_sound("ui_click")
	laptop_screen_in = true
	set_ui(true, 0)
	emit_signal("laptop_toggled")

func _on_exit_pressed() -> void:
	sound_manager.play_sound("mouse_click")
	laptop_screen_in = false
	set_ui(false, 0)
	set_ui(false, 1)
	emit_signal("laptop_toggled")

func _on_close_app_pressed() -> void:
	sound_manager.play_sound("mouse_click")
	"""Close the currently open app and return to laptop home screen"""
	set_text("")
	set_ui(false, 1)
	set_app("")

# ---------- LAPTOP: HOMESCREEN APPS ----------
func _on_email_pressed() -> void:
	sound_manager.play_sound("mouse_click")
	set_text("Email")
	set_ui(true, 1)
	emit_signal("open_emails")
	set_app("emails")
	# Directly spawn emails when opened (similar to evidence bank refresh)
	if emails_controller and emails_controller.has_method("spawn_emails"):
		emails_controller.spawn_emails()

func _on_ai_analysis_pressed() -> void:
	sound_manager.play_sound("mouse_click")
	set_text("AI Analysis")
	set_ui(true, 1)
	emit_signal("open_analysis")
	set_app("ai_analysis")

func _on_evidence_bank_pressed() -> void:
	sound_manager.play_sound("mouse_click")
	set_text("Evidence Bank")
	set_ui(true, 1)
	emit_signal("open_evidences")
	set_app("evidence_bank")
	
	# Refresh evidence bank when opened
	if evidence_bank_controller:
		evidence_bank_controller._on_refresh_pressed()

func _on_article_publisher_pressed() -> void:
	sound_manager.play_sound("mouse_click")
	set_text("Article Publisher")
	set_ui(true, 1)
	emit_signal("open_article_publisher")
	set_app("article_publisher")
	
	# Refresh articles when opening
	if article_publisher_controller:
		article_publisher_controller.refresh_articles()

# ---------- HELPER METHODS ----------
func _try_cast_to_trash_controller(node: Node) -> TrashController:
	"""Helper to attempt casting node to TrashController"""
	if node is TrashController:
		return node as TrashController
	var as_trash = node as TrashController
	if as_trash:
		return as_trash
	var script = node.get_script()
	if script and script.resource_path.ends_with("trash_controller.gd"):
		return node as TrashController
	return null

func _find_trash_node() -> Node:
	"""Helper to find trash node via multiple search paths"""
	var search_paths = [
		"LaptopIn/Apps/Content/App_BG/Trash Controller",
		null  # Will use trash_bin if path fails
	]
	
	for path in search_paths:
		var node = get_node_or_null(path) if path else trash_bin
		if node:
			return node
	
	var apps_container = get_node_or_null("LaptopIn/Apps/Content/App_BG")
	if apps_container:
		return apps_container.get_node_or_null("Trash Controller")
	
	return find_child("Trash Controller", true, false)

func _on_trashbin_pressed() -> void:
	sound_manager.play_sound("mouse_click")
	"""Open trash app when trashbin button is pressed"""
	set_text("Trash")
	set_ui(true, 1)
	set_app("trash")
	
	if not trash_controller:
		var trash_node = _find_trash_node()
		if trash_node:
			trash = trash_node
			trash_bin = trash_node
			trash_controller = _try_cast_to_trash_controller(trash_node)
		else:
			_initialize_trash_controller()
	
	if trash_controller:
		_connect_trash_to_evidence_bank()
		call_deferred("_refresh_trash_controller")
	else:
		push_warning("[Laptop._on_trashbin_pressed] trash_controller is null!")

func _on_trash_bin_pressed() -> void:
	"""Open trash app when trash bin button is pressed (FRONTUI method name)"""
	_on_trashbin_pressed()

func _refresh_trash_controller():
	"""Refresh trash controller after app is opened"""
	if trash_controller:
		# Ensure trash controller is visible
		trash_controller.visible = true
		# Load and refresh
		trash_controller._load_trashed_infos(true)
		# Use call_deferred to ensure visibility has propagated
		trash_controller.call_deferred("_refresh_list")
	else:
		push_warning("[Laptop._refresh_trash_controller] trash_controller is null!")

func get_ai_analysis_controller() -> Node:
	return ai_analysis_controller

func get_evidence_bank_controller() -> EvidenceBankController:
	return evidence_bank_controller

func get_emails_controller() -> MarginContainer:
	return emails_controller

func get_trash_controller() -> TrashController:
	return trash_controller

func set_game_manager(manager: Node):
	if ai_analysis_controller:
		ai_analysis_controller.set_game_manager(manager)
	if evidence_bank_controller:
		evidence_bank_controller.set_game_manager(manager)
	if article_publisher_controller:
		article_publisher_controller.set_game_manager(manager)
	if emails_controller and emails_controller.has_method("set_game_manager"):
		emails_controller.set_game_manager(manager)

func set_evidence_bank_to_emails():
	"""Connect evidence bank controller to emails controller"""
	if emails_controller and evidence_bank_controller:
		if emails_controller.has_method("set_evidence_bank_controller"):
			emails_controller.set_evidence_bank_controller(evidence_bank_controller)
			print("Laptop: Connected evidence bank to emails controller")

func trigger_crash(duration: float):
	"""Trigger laptop crash/hang effects"""
	if is_crashed:
		return  # Already crashed, don't stack crashes
	
	is_crashed = true
	print("Laptop: CRASH! System unresponsive for %.1f seconds" % duration)
	# Disable all interactions
	_set_crash_state(true)
	# Add visual glitch effect
	_add_glitch_effect()
	# Auto-recover after duration
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(_on_crash_recover)

func _on_crash_recover():
	"""Recover from crash"""
	is_crashed = false
	_set_crash_state(false)
	remove_glitch_effect()
	print("Laptop: System recovered from crash")

func _set_crash_state(crashed: bool):
	"""Set crash state - disable/enable interactions"""
	# Disable all app buttons and interactions
	if app_main:
		if crashed:
			app_main.modulate = Color(0.3, 0.3, 0.3, 1.0)  # Darker when crashed
			app_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			app_main.modulate = Color.WHITE
			app_main.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Also disable laptop screen if available
	if laptop_screen:
		if crashed:
			laptop_screen.modulate = Color(0.4, 0.4, 0.4, 1.0)
		else:
			laptop_screen.modulate = Color.WHITE

func _ensure_sound_manager() -> void:
	if sound_manager:
		return
	var master_node := get_node_or_null("/root/Master") as Master
	if master_node and master_node.sound_manager:
		sound_manager = master_node.sound_manager
	if not sound_manager:
		sound_manager = SoundManager.instance

func _play_glitch_sound() -> void:
	_ensure_sound_manager()
	if sound_manager and (glitch_sound_player == null or not is_instance_valid(glitch_sound_player)):
		glitch_sound_player = sound_manager.play_sound("Glitch1")

func _stop_glitch_sound() -> void:
	if glitch_sound_player and is_instance_valid(glitch_sound_player):
		glitch_sound_player.stop()
		glitch_sound_player.queue_free()
	glitch_sound_player = null

var glitch_tween: Tween = null

func _add_glitch_effect():
	"""Add visual glitch effect during crash"""
	if not app_main:
		return
	
	_play_glitch_sound()
	
	# Create a glitch effect using tween to flicker the screen
	if glitch_tween:
		glitch_tween.kill()
	
	glitch_tween = create_tween()
	glitch_tween.set_loops()
	
	# Flicker effect - rapidly change modulate
	for i in range(10):
		glitch_tween.tween_property(app_main, "modulate", Color(0.2, 0.2, 0.8, 1.0), 0.05)
		glitch_tween.tween_property(app_main, "modulate", Color(0.3, 0.3, 0.3, 1.0), 0.05)
	
	print("Laptop: Glitch effect activated")

func add_glitch_effect(duration: float):
	"""Add visual glitch effect during crash (called from Lyra)"""
	_add_glitch_effect()

func remove_glitch_effect():
	"""Remove glitch effect"""
	if glitch_tween:
		glitch_tween.kill()
		glitch_tween = null
	_stop_glitch_sound()
	print("Laptop: Glitch effect removed")

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	_ensure_sound_manager()
	set_ui(false, 0)
	set_ui(false, 1)
	
	# Find time label if not assigned
	if not time_label:
		# Try direct path first
		if has_node("LaptopIn/TaskBar/Panel/MarginContainer/Right/Time"):
			time_label = get_node("LaptopIn/TaskBar/Panel/MarginContainer/Right/Time") as Label
		# Fallback to searching
		if not time_label:
			var time_node = find_child("Time", true, false)
			if time_node and time_node is Label:
				time_label = time_node
		if time_label:
			print("[Laptop] Found time label: ", time_label.get_path())
		else:
			push_warning("[Laptop] Could not find time label!")
	
	# Get controller references
	if emails:
		# emails is MarginContainer, emails_controller is Node - direct assignment is fine
		emails_controller = emails
		print("[Laptop] Emails controller: ", emails_controller)
	if ai_analysis:
		ai_analysis_controller = ai_analysis
		print("[Laptop] AI Analysis controller: ", ai_analysis_controller)
	if evidence_bank:
		evidence_bank_controller = evidence_bank as EvidenceBankController
		print("[Laptop] Evidence Bank controller: ", evidence_bank_controller)
	if article_publisher:
		article_publisher_controller = article_publisher as ArticlePublisherController
		print("[Laptop] Article Publisher controller: ", article_publisher_controller)
	# Try to find trash controller - use call_deferred to ensure node is ready
	call_deferred("_initialize_trash_controller")

func _initialize_trash_controller():
	"""Initialize trash controller after scene tree is ready"""
	var trash_node = _find_trash_node()
	if not trash_node:
		push_warning("[Laptop._initialize_trash_controller] Could not find trash node")
		return
	
	trash = trash_node
	trash_bin = trash_node
	
	var script = trash_node.get_script()
	if not script:
		var trash_script = load("res://Scripts/App Scripts/trash_controller.gd")
		if trash_script:
			trash_node.set_script(trash_script)
	
	trash_controller = _try_cast_to_trash_controller(trash_node)
	
	if trash_controller:
		_connect_trash_to_evidence_bank()
		call_deferred("_connect_trash_to_evidence_bank")
	else:
		push_warning("[Laptop._initialize_trash_controller] Failed to cast to TrashController")
	
	if ai_analysis_controller and evidence_bank_controller:
		evidence_bank_controller.set_ai_analysis_ref(ai_analysis_controller)
		if evidence_bank_controller.has_method("set_laptop_ref"):
			evidence_bank_controller.set_laptop_ref(self)

func _connect_trash_to_evidence_bank():
	"""Helper to connect trash controller to evidence bank"""
	if not trash_controller or not evidence_bank_controller:
		return
	
	if not trash_controller.evidence_bank_ref:
		trash_controller.set_evidence_bank_ref(evidence_bank_controller)
	if not evidence_bank_controller.trash_controller_ref:
		evidence_bank_controller.set_trash_controller_ref(trash_controller)
	
	if evidence_bank_controller and article_publisher_controller:
		if evidence_bank_controller.has_method("set_article_publisher_ref"):
			evidence_bank_controller.set_article_publisher_ref(article_publisher_controller)
	
	set_evidence_bank_to_emails()


func set_time_label(label: Label):
	time_label = label


func update_time_display(time_text: String):
	"""Update the time display on laptop to match the main timer"""
	if time_label:
		time_label.text = time_text

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("laptop"):
		if laptop_screen_in:
			_on_exit_pressed()
			emit_signal("laptop_toggled")
		else:
			_on_screen_pressed()
			emit_signal("laptop_toggled")

	if laptop_screen_in:
		if Input.is_action_just_pressed("key_1"):
			_on_email_pressed()
		elif Input.is_action_just_pressed("key_2"):
			_on_ai_analysis_pressed()
		elif Input.is_action_just_pressed("key_3"):
			_on_evidence_bank_pressed()
		elif Input.is_action_just_pressed("key_4"):
			_on_article_publisher_pressed()
