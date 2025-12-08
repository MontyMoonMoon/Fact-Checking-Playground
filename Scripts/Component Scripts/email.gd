extends Control

var master: Master
var sound_manager: SoundManager
var is_spam_email: bool = false

func get_is_spam_email() -> bool:
	"""Get whether this email is spam"""
	return is_spam_email

@export_group("Texts")
@export var sender: Label
@export var subject: Label
@export var timestamp: Label

# Email data
var email_data: Dictionary = {}
var news_data: Dictionary = {}
var mail_data: Dictionary = {}  # For compatibility with open_mail signal

# References
var evidence_bank_controller: EvidenceBankController = null
var emails_controller: Node = null

# Signals
signal open_mail(mail_dict: Dictionary)
signal email_added_to_evidence(news_data: Dictionary)
signal email_discarded(email_instance: Node)

# ---------- METHODS ----------
func setup_email(data: Dictionary, ev_bank_controller: EvidenceBankController = null, emails_ctrl: Node = null) -> void:
	"""Setup email with news data from JSON"""
	if data.is_empty():
		push_warning("[Email.setup_email] Received empty email data!")
		return
	
	email_data = data.duplicate(true)  # Make a deep copy to preserve all fields
	news_data = data.get("news_data", {})
	mail_data = email_data.duplicate(true)  # Ensure mail_data has all fields including content
	is_spam_email = email_data.get("is_spam", false)
	evidence_bank_controller = ev_bank_controller
	emails_controller = emails_ctrl
	
	print("[Email.setup_email] Setting up email: %s" % data.get("subject", "Unknown"))
	
	# Update display - use call_deferred to ensure @export variables are assigned
	call_deferred("_update_email_display")

func _update_email_display() -> void:
	"""Update email display with data"""
	if email_data.is_empty():
		push_warning("[Email._update_email_display] email_data is empty!")
		return
	
	# Display email information using @export variables
	if sender:
		var sender_text = email_data.get("sender", "Unknown Sender")
		sender.text = sender_text
		print("[Email] Updated sender: %s" % sender_text)
	else:
		push_warning("[Email] sender @export variable is null!")
	
	if timestamp:
		var timestamp_text = email_data.get("timestamp", "00:00")
		timestamp.text = timestamp_text
		print("[Email] Updated timestamp: %s" % timestamp_text)
	else:
		push_warning("[Email] timestamp @export variable is null!")
	
	if subject:
		var subject_text = email_data.get("subject", "No Subject")
		subject.text = subject_text
		print("[Email] Updated subject: %s" % subject_text)
	else:
		push_warning("[Email] subject @export variable is null!")

# ---------- BUTTON HANDLERS ----------
func _on_button_pressed() -> void:
	"""Open mail when email preview is clicked"""
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
	# CRITICAL: Rebuild mail_data from email_data to ensure ALL fields are present
	# This ensures content field is included
	mail_data = email_data.duplicate(true)
	
	# Debug: log what we're passing
	print("[Email._on_button_pressed] email_data keys: ", email_data.keys())
	print("[Email._on_button_pressed] email_data content: ", email_data.get("content", "MISSING"))
	print("[Email._on_button_pressed] mail_data keys: ", mail_data.keys())
	print("[Email._on_button_pressed] mail_data content: ", mail_data.get("content", "MISSING"))
	
	# Ensure main_text is set from content if not already set
	if mail_data.has("content") and mail_data.get("content", "") != "":
		mail_data["main_text"] = mail_data["content"]
		print("[Email._on_button_pressed] Set main_text from content: ", mail_data["main_text"].substr(0, min(50, mail_data["main_text"].length())))
	
	if emails_controller and emails_controller.has_method("_on_mail_opened"):
		emails_controller._on_mail_opened(mail_data)
	else:
		emit_signal("open_mail", mail_data)

func _on_add_pressed() -> void:
	"""Add email's news data to evidence bank"""
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
	if is_spam_email and emails_controller and emails_controller.has_method("_on_spam_email_add_attempted"):
		emails_controller._on_spam_email_add_attempted(email_data)
	
	if news_data.is_empty():
		push_warning("[Email] Cannot add email: no news_data found")
		return
	
	if not evidence_bank_controller:
		push_warning("[Email] Cannot add to evidence bank: controller not available")
		# Try to get it from emails_controller if available
		if emails_controller and emails_controller.has_method("get_evidence_bank_controller"):
			evidence_bank_controller = emails_controller.get_evidence_bank_controller()
		# Try to get from laptop
		if not evidence_bank_controller and master:
			var laptop = master.get_node_or_null("Laptop")
			if laptop and laptop.has_method("get_evidence_bank_controller"):
				evidence_bank_controller = laptop.get_evidence_bank_controller()
		
		if not evidence_bank_controller:
			push_error("[Email] Could not find evidence bank controller after fallback attempts")
			return
	
	# Format the news data similar to evidence bank format
	var info = {
		"title": "Email: " + email_data.get("subject", "Untitled"),
		"content": _format_news_content(),
		"case_data": news_data.duplicate(true),
		"email_data": email_data.duplicate(true)
	}
	
	# Add to evidence bank's stored_infos (but NOT to dataset_additions.json)
	# Player must click Add button in evidence bank to add to AI analysis/Publisher
	if evidence_bank_controller.has_method("_add_info_directly"):
		evidence_bank_controller._add_info_directly(info, false)  # false = don't add to dataset
	else:
		push_error("[Email] Evidence bank controller does not have _add_info_directly method")
	
	# Emit signal
	emit_signal("email_added_to_evidence", news_data)
	
	# Remove email from the list
	_discard_email()

func _on_discard_pressed() -> void:
	"""Discard/delete the email"""
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	_discard_email()

func _discard_email() -> void:
	"""Discard/delete the email"""
	print("[Email] Discarding email: %s" % email_data.get("subject", "Unknown"))
	emit_signal("email_discarded", self)
	
	# Remove from scene tree
	queue_free()

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

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[Email._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	if master.sound_manager:
		sound_manager = master.sound_manager
	
	# Check if @export variables are assigned
	if not sender:
		push_warning("[Email._ready] sender @export variable is not assigned in scene!")
	if not subject:
		push_warning("[Email._ready] subject @export variable is not assigned in scene!")
	if not timestamp:
		push_warning("[Email._ready] timestamp @export variable is not assigned in scene!")
	
	# Update display if email_data is already set (setup_email was called before _ready)
	if not email_data.is_empty():
		# Use call_deferred to ensure @export variables are ready
		call_deferred("_update_email_display")
