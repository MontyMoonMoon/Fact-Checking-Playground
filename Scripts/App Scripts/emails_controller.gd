extends MarginContainer

@export var laptop: Control

@export_subgroup("Emails")
@export var mails_container: ScrollContainer
@export var mails_content: VBoxContainer

# References
var evidence_bank_controller: EvidenceBankController = null

# Email data
var email_news_pool: Array = []
var used_email_indices: Array = []

# ---------- PREFAB ----------
@onready var email = preload("res://Prefabs/Components/email.tscn")

# ---------- METHODS ----------
func _on_open_emails() -> void:
	print("[Emails_controller._on_open_emails] Spawning emails...")
	spawn_emails()

func spawn_emails() -> void:
	# Clear existing emails
	for child in mails_content.get_children():
		child.queue_free()
	
	# Load email news if not already loaded
	if email_news_pool.is_empty():
		_load_email_news()
	
	# Spawn emails with different news content
	var email_count = 5  # Number of emails to spawn
	
	# Reset used indices if we've used all emails
	if used_email_indices.size() >= email_news_pool.size():
		used_email_indices.clear()
	
	for i in range(email_count):
		# Get a random email news that hasn't been used recently
		var available_indices = []
		for idx in range(email_news_pool.size()):
			if not used_email_indices.has(idx):
				available_indices.append(idx)
		
		# If all emails have been used, reset and use any
		if available_indices.is_empty():
			available_indices = range(email_news_pool.size())
			used_email_indices.clear()
		
		var random_idx = available_indices[randi() % available_indices.size()]
		used_email_indices.append(random_idx)
		
		var email_data = email_news_pool[random_idx].duplicate()
		var email_instance = email.instantiate()
		
		# Add to scene tree first
		mails_content.add_child(email_instance)
		
		# Setup email with data and references after adding to tree
		if email_instance.has_method("setup_email"):
			email_instance.setup_email(email_data, evidence_bank_controller, self)

func _load_email_news() -> void:
	"""Load email news from JSON file"""
	var file_path = "res://email_news.json"
	
	if not FileAccess.file_exists(file_path):
		push_error("[Emails_controller] Email news file not found at %s" % file_path)
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[Emails_controller] Could not open email_news.json")
		return
	
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if typeof(data) == TYPE_DICTIONARY and data.has("emails"):
		email_news_pool = data["emails"]
		print("[Emails_controller] Loaded %d email news items" % email_news_pool.size())
	else:
		push_error("[Emails_controller] Invalid JSON format: missing 'emails' array")
		email_news_pool = []

func set_evidence_bank_controller(controller: EvidenceBankController) -> void:
	"""Set the evidence bank controller reference"""
	evidence_bank_controller = controller

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	if laptop:
		laptop.connect("open_emails", Callable(self, "_on_open_emails"))
		
		# Try to get evidence bank controller from laptop
		if laptop.has_method("get_evidence_bank_controller"):
			evidence_bank_controller = laptop.get_evidence_bank_controller()
	else:
		push_warning("[Emails_controller.ready] Laptop is kinda missing...")
