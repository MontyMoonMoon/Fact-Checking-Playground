extends MarginContainer

# Node references
@onready var sender_label: Label = $TextsContainer/Text/Sender_Info/Sender
@onready var timestamp_label: Label = $TextsContainer/Text/Time_Info/Timestamp
@onready var content_label: RichTextLabel = $TextsContainer/Text/RichTextLabel
@onready var background_panel: Panel = get_node("Background Panel")
@onready var button_container: HBoxContainer = $TextsContainer/Text/ButtonContainer
@onready var add_button: Button = $TextsContainer/Text/ButtonContainer/AddButton
@onready var discard_button: Button = $TextsContainer/Text/ButtonContainer/DiscardButton

# Email data
var email_data: Dictionary = {}
var news_data: Dictionary = {}

# References
var evidence_bank_controller: EvidenceBankController = null
var emails_controller: Node = null

# Signals
signal email_added_to_evidence(news_data: Dictionary)
signal email_discarded(email_instance: Node)

# ---------- METHODS ----------
func setup_email(data: Dictionary, ev_bank_controller: EvidenceBankController = null, emails_ctrl: Node = null) -> void:
	"""Setup email with news data"""
	email_data = data
	news_data = data.get("news_data", {})
	evidence_bank_controller = ev_bank_controller
	emails_controller = emails_ctrl
	
	# Use call_deferred to ensure nodes are ready
	call_deferred("_update_email_display")
	_setup_interaction()

func _update_email_display() -> void:
	"""Update email display with data (called deferred to ensure nodes are ready)"""
	if email_data.is_empty():
		return
	
	# Display email information
	if sender_label:
		sender_label.text = email_data.get("sender", "Unknown Sender")
	
	if timestamp_label:
		timestamp_label.text = email_data.get("timestamp", "00:00")
	
	if content_label:
		var subject = email_data.get("subject", "")
		var content = email_data.get("content", "")
		content_label.text = "[b]%s[/b]\n\n%s" % [subject, content]
		print("[Email] Updated content: %s" % subject)

func _setup_interaction() -> void:
	"""Setup button handlers for the email"""
	# Use call_deferred to ensure nodes are ready
	call_deferred("_connect_buttons")

func _connect_buttons() -> void:
	"""Connect button signals (called deferred)"""
	if add_button and not add_button.pressed.is_connected(_add_to_evidence_bank):
		add_button.pressed.connect(_add_to_evidence_bank)
	
	if discard_button and not discard_button.pressed.is_connected(_discard_email):
		discard_button.pressed.connect(_discard_email)

func _add_to_evidence_bank() -> void:
	"""Add email's news data to evidence bank"""
	if news_data.is_empty():
		push_warning("Cannot add email: no news data")
		return
	
	if not evidence_bank_controller:
		push_warning("Cannot add to evidence bank: controller not available")
		return
	
	print("[Email] Adding to evidence bank: %s" % news_data.get("article_text", "Unknown"))
	
	# Format the news data similar to evidence bank format
	var info = {
		"title": "Email: " + email_data.get("subject", "Untitled"),
		"content": _format_news_content(),
		"case_data": news_data.duplicate(),
		"email_data": email_data.duplicate()
	}
	
	# Add to evidence bank's stored_infos
	if evidence_bank_controller.has_method("_add_info_directly"):
		evidence_bank_controller._add_info_directly(info)
		print("[Email] Added to evidence bank successfully")
	else:
		push_error("[Email] Evidence bank controller does not have _add_info_directly method")
	
	# Emit signal
	emit_signal("email_added_to_evidence", news_data)
	
	# Remove email from the list
	_discard_email()

func _format_news_content() -> String:
	"""Format news data as evidence bank content"""
	var content = "[b]Article:[/b] " + news_data.get("article_text", "") + "\n\n"
	content += "[b]Tip:[/b] " + news_data.get("tip_text", "") + "\n\n"
	
	var facts = news_data.get("facts", [])
	if facts.size() > 0:
		content += "[b]Facts:[/b]\n"
		for fact in facts:
			content += "- %s (%s): %s\n" % [
				fact.get("category", ""),
				fact.get("source", ""),
				fact.get("value", "")
			]
		content += "\n"
	
	content += "[b]Stance:[/b] " + news_data.get("stance", "Unknown") + "\n"
	content += "[b]Integrity Score:[/b] %.2f" % news_data.get("integrity_score", 0.0)
	
	return content

func _discard_email() -> void:
	"""Discard/delete the email"""
	print("[Email] Discarding email: %s" % email_data.get("subject", "Unknown"))
	emit_signal("email_discarded", self)
	
	# Remove from scene tree
	queue_free()

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	# Enable BBCode if using RichTextLabel
	if content_label:
		content_label.bbcode_enabled = true
	
	# Update display if email_data is already set (setup_email was called before _ready)
	if not email_data.is_empty():
		_update_email_display()
		_connect_buttons()
