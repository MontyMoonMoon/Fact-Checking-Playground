extends Control
class_name Laptop

@export_group("Laptop Containers")
@export var laptop_screen: Control
@export var home_screen: NinePatchRect
@export var app_main: MarginContainer

@export_group("Apps")
@export var app_name: Label
@export var emails: MarginContainer
@export var ai_analysis: MarginContainer
@export var evidence_bank: MarginContainer
@export var time_label: Label = null

# ---------- VARIABLES & SIGNALS ----------
var laptop_screen_in := false
var emails_controller: Node = null
var ai_analysis_controller: AIAnalysisController = null
var evidence_bank_controller: EvidenceBankController = null
signal laptop_toggled(is_open: bool)

signal open_emails
signal open_analysis
signal open_evidences

# ---------- APP CONTAINER MANAGER ----------
func set_ui(visibility: bool, target: int) -> void: 
	match target: 
		0:
			laptop_screen.visible = visibility
			home_screen.visible = visibility
		1:
			app_main.visible = visibility

func set_app(open: String) -> void:
	emails.visible = false
	ai_analysis.visible = false
	evidence_bank.visible = false

	match open:
		"emails":
			emails.visible = true
		"ai_analysis":
			ai_analysis.visible = true
		"evidence_bank":
			evidence_bank.visible = true
		_:
			push_warning("Unknown app: " + open)

# ---------- SET TEXT ----------
func set_text(text: String) -> void:
	app_name.text = text

# ---------- LAPTOP: BUTTON FUNCTIONS ----------
func _on_screen_pressed() -> void:
	laptop_screen_in = true
	set_ui(true, 0)
	emit_signal("laptop_toggled", true)

func _on_exit_pressed() -> void:
	laptop_screen_in = false
	set_ui(false, 0)
	set_ui(false, 1)
	emit_signal("laptop_toggled", false)

# ---------- LAPTOP: HOMESCREEN APPS ----------
func _on_email_pressed() -> void:
	set_text("Email")
	set_ui(true, 1)
	emit_signal("open_emails")
	set_app("emails")

func _on_ai_analysis_pressed() -> void:
	set_text("AI Analysis")
	set_ui(true, 1)
	emit_signal("open_analysis")
	set_app("ai_analysis")

func _on_evidence_bank_pressed() -> void:
	set_text("Evidence Bank")
	set_ui(true, 1)
	emit_signal("open_evidences")
	set_app("evidence_bank")
	
	# Refresh evidence bank when opened
	if evidence_bank_controller:
		evidence_bank_controller._on_refresh_pressed()

func _on_trashbin_pressed() -> void:
	"""Open trash popup when trashbin button is pressed"""
	print("[Laptop] TrashBin button pressed")
	if evidence_bank_controller:
		if evidence_bank_controller.has_method("_show_trash_popup"):
			evidence_bank_controller._show_trash_popup()
			print("[Laptop] Trash popup shown")
		else:
			push_warning("[Laptop] Evidence bank controller doesn't have _show_trash_popup method")
	else:
		push_warning("[Laptop] Evidence bank controller is null")

func get_ai_analysis_controller() -> AIAnalysisController:
	return ai_analysis_controller

func get_evidence_bank_controller() -> EvidenceBankController:
	return evidence_bank_controller

func get_emails_controller() -> Node:
	return emails_controller

func set_game_manager(manager: Node):
	if ai_analysis_controller:
		ai_analysis_controller.set_game_manager(manager)
	if evidence_bank_controller:
		evidence_bank_controller.set_game_manager(manager)

func set_evidence_bank_to_emails():
	"""Connect evidence bank controller to emails controller"""
	if emails_controller and evidence_bank_controller:
		if emails_controller.has_method("set_evidence_bank_controller"):
			emails_controller.set_evidence_bank_controller(evidence_bank_controller)
			print("Laptop: Connected evidence bank to emails controller")

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	set_ui(false, 0)
	set_ui(false, 1)
	
	# Get controller references
	if emails:
		emails_controller = emails
	if ai_analysis:
		ai_analysis_controller = ai_analysis as AIAnalysisController
	if evidence_bank:
		evidence_bank_controller = evidence_bank as EvidenceBankController
	
	# Connect controllers
	if ai_analysis_controller and evidence_bank_controller:
		evidence_bank_controller.set_ai_analysis_ref(ai_analysis_controller)
	
	# Connect evidence bank to emails controller
	set_evidence_bank_to_emails()
	
	print("Laptop: Controllers initialized")
	if evidence_bank_controller:
		print("Laptop: Evidence bank controller found")
	else:
		push_warning("Laptop: Evidence bank controller is null!")
	if emails_controller:
		print("Laptop: Emails controller found")
	else:
		push_warning("Laptop: Emails controller is null!")

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
		else:
			_on_screen_pressed()
	
	if laptop_screen_in:
		if Input.is_action_just_pressed("key_1"):
			_on_email_pressed()
		elif Input.is_action_just_pressed("key_2"):
			_on_ai_analysis_pressed()
		elif Input.is_action_just_pressed("key_3"):
			_on_evidence_bank_pressed()
