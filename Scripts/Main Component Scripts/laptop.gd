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
@export var article_publisher: MarginContainer
@export var trash: MarginContainer
@export var time_label: Label = null

# ---------- VARIABLES & SIGNALS ----------
var laptop_screen_in := false
var emails_controller: Node = null
var ai_analysis_controller: AIAnalysisController = null
var evidence_bank_controller: EvidenceBankController = null
var article_publisher_controller: ArticlePublisherController = null
var trash_controller: TrashController = null
signal laptop_toggled(is_open: bool)

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

func _on_article_publisher_pressed() -> void:
	set_text("Article Publisher")
	set_ui(true, 1)
	emit_signal("open_article_publisher")
	set_app("article_publisher")
	
	# Refresh articles when opening
	if article_publisher_controller:
		article_publisher_controller.refresh_articles()

func _on_trashbin_pressed() -> void:
	"""Open trash app when trashbin button is pressed"""
	set_text("Trash")
	set_ui(true, 1)
	set_app("trash")

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
	if article_publisher_controller:
		article_publisher_controller.set_game_manager(manager)

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
	if article_publisher:
		article_publisher_controller = article_publisher as ArticlePublisherController
	if trash:
		trash_controller = trash as TrashController
	
	# Connect controllers
	if ai_analysis_controller and evidence_bank_controller:
		evidence_bank_controller.set_ai_analysis_ref(ai_analysis_controller)
		# Also set laptop reference for app switching
		if evidence_bank_controller.has_method("set_laptop_ref"):
			evidence_bank_controller.set_laptop_ref(self)
	
	# Connect trash controller to evidence bank
	if trash_controller and evidence_bank_controller:
		trash_controller.set_evidence_bank_ref(evidence_bank_controller)
		if evidence_bank_controller.has_method("set_trash_controller_ref"):
			evidence_bank_controller.set_trash_controller_ref(trash_controller)
			print("Laptop: Connected trash controller to evidence bank")
		else:
			push_warning("Laptop: Evidence bank controller doesn't have set_trash_controller_ref method")
	else:
		if not trash_controller:
			push_warning("Laptop: trash_controller is null!")
		if not evidence_bank_controller:
			push_warning("Laptop: evidence_bank_controller is null!")
	
	# Connect evidence bank to article publisher (so publisher updates when articles are added)
	if evidence_bank_controller and article_publisher_controller:
		if evidence_bank_controller.has_method("set_article_publisher_ref"):
			evidence_bank_controller.set_article_publisher_ref(article_publisher_controller)
			print("Laptop: Connected evidence bank to article publisher")
	
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
	if article_publisher_controller:
		print("Laptop: Article Publisher controller found")
	else:
		push_warning("Laptop: Article Publisher controller is null!")

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
