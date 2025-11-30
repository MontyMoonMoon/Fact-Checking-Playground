extends MarginContainer

var master: Master
var sound_manager: SoundManager
var game_manager: GameManager = null

@export var laptop: Control
@export var container: MarginContainer   

@export_subgroup("Emails")
@export var mails_container: ScrollContainer
@export var mails_content: VBoxContainer

var evidence_bank_controller: EvidenceBankController = null

var email_news_pool: Array = []
var used_email_indices: Array = []
var spam_emails_queue: Array = []

@onready var email_prefab = preload("res://Prefabs/Components/email.tscn")
@onready var mail_prefab = preload("res://Prefabs/Components/mail.tscn")

var _has_spawned_initial: bool = false
var _spawned_emails: Array = []

const SPAM_EVIDENCE_PENALTY := -3.0
const SPAM_GLITCH_DURATION := 2.5

func _on_open_emails() -> void:
	if not visible:
		visible = true
		show()
	
	if not mails_content:
		_find_mails_content()
	
	if not mails_content:
		return
	
	if email_news_pool.is_empty():
		_load_email_news()
	
	var existing_count = mails_content.get_child_count()
	
	if not spam_emails_queue.is_empty():
		spawn_queued_spam_emails()
	
	if existing_count == 0:
		spawn_normal_emails()

func _reset_email_indices_if_needed() -> void:
	"""Helper to reset email indices when inbox is empty or all emails used"""
	var existing_count = mails_content.get_child_count() if mails_content else 0
	if existing_count == 0 or used_email_indices.size() >= email_news_pool.size():
		used_email_indices.clear()

func spawn_normal_emails() -> void:
	if email_news_pool.is_empty():
		if not _load_email_news():
			return
	
	_reset_email_indices_if_needed()
	
	var spawned_count := 0
	for i in range(5):
		var email_data = _get_random_unused_email()
		if email_data:
			var instance = _create_email_instance(email_data, false)
			if instance:
				spawned_count += 1
	
	_has_spawned_initial = true
	
	if spawned_count > 0:
		_play_new_email_sound()

func spawn_queued_spam_emails() -> void:
	if spam_emails_queue.is_empty():
		return
	
	if not mails_content:
		_find_mails_content()
	
	if not mails_content:
		return
	
	var spam_queue_copy = spam_emails_queue.duplicate()
	spam_emails_queue.clear()
	
	for spam_data in spam_queue_copy:
		_create_email_instance(spam_data, true)

func _find_mails_content() -> void:
	if not mails_content:
		mails_content = get_node_or_null("ScrollableArea/EmailsContent")
	
	if not mails_content:
		mails_content = find_child("EmailsContent", true, false)
	
	if mails_container:
		mails_container.visible = true
		mails_container.show()

func _get_random_unused_email() -> Dictionary:
	if email_news_pool.is_empty():
		return {}
	
	var available_indices = []
	for idx in range(email_news_pool.size()):
		if not used_email_indices.has(idx):
			available_indices.append(idx)
	
	if available_indices.is_empty():
		available_indices = range(email_news_pool.size())
		used_email_indices.clear()
	
	if available_indices.is_empty():
		return {}
	
	var random_idx = available_indices[randi() % available_indices.size()]
	used_email_indices.append(random_idx)
	return email_news_pool[random_idx].duplicate()

func _ensure_evidence_bank_ref() -> void:
	"""Helper to ensure evidence bank controller reference is set"""
	if not evidence_bank_controller and laptop and laptop.has_method("get_evidence_bank_controller"):
		evidence_bank_controller = laptop.get_evidence_bank_controller()

func _ensure_containers_visible() -> void:
	"""Helper to ensure email containers are visible"""
	visible = true
	show()
	if mails_content:
		mails_content.visible = true
		mails_content.show()
	if mails_container:
		mails_container.visible = true
		mails_container.show()

func _create_email_instance(email_data: Dictionary, is_spam: bool) -> Node:
	if not mails_content:
		_find_mails_content()
	
	if not mails_content:
		return null
	
	_ensure_evidence_bank_ref()
	
	var email_instance = email_prefab.instantiate()
	mails_content.add_child(email_instance)
	email_instance.visible = true
	_ensure_containers_visible()
	email_data["is_spam"] = is_spam
	
	if email_instance.has_method("setup_email"):
		email_instance.setup_email(email_data, evidence_bank_controller, self)
		email_instance.call_deferred("_update_email_display")
		_spawned_emails.append(email_instance)
		print("[Emails Controller] Created email instance with setup_email method")
		return email_instance
	elif master:
		email_instance.master = master
		email_instance.connect("open_mail", Callable(self, "_on_mail_opened"))
		_spawned_emails.append(email_instance)
		print("[Emails Controller] Created email instance with master connection")
		return email_instance
	
	push_warning("[Emails Controller] Failed to create email instance - no setup_email method and no master")
	return null

func _load_email_news() -> bool:
	var file_path = "res://JSONs/email_news.json"
	
	if not FileAccess.file_exists(file_path):
		push_error("[Emails_controller] Email news file not found at %s" % file_path)
		return false
	
	var data = JSONManager.load_json(file_path, {})
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[Emails_controller] Invalid JSON format: expected dictionary")
		email_news_pool = []
		return false
	
	# Detect current map
	var current_map = _get_current_map()
	print("[Emails_controller] Detected current map: %s" % current_map)
	
	# Load map-specific email pool
	if data.has(current_map):
		email_news_pool = data[current_map]
		print("[Emails_controller] Loaded %d email news items for %s" % [email_news_pool.size(), current_map])
		return true
	elif data.has("emails"):
		# Fallback to old format for backwards compatibility
		email_news_pool = data["emails"]
		print("[Emails_controller] Loaded %d email news items (legacy format)" % email_news_pool.size())
		return true
	else:
		push_error("[Emails_controller] Invalid JSON format: missing '%s' or 'emails' key" % current_map)
		email_news_pool = []
		return false

func _get_current_map() -> String:
	# Try to get from DataManager first
	if DataManager.current_map in ["map_01", "map_02", "map_03"]:
		return DataManager.current_map
	
	# Fallback: detect from scene path
	var scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	if scene_path:
		var scene_name = scene_path.get_file().get_basename()
		if scene_name in ["map_01", "map_02", "map_03"]:
			return scene_name
	
	# Default to map_01
	return "map_01"

func add_spam_email(spam_data: Dictionary) -> void:
	_ensure_spam_fields(spam_data)
	
	if not mails_content:
		_find_mails_content()
	
	if not mails_content or not visible:
		spam_emails_queue.append(spam_data)
		_play_new_email_sound()
		return
	
	var email_instance = _create_email_instance(spam_data, true)
	if not email_instance:
		spam_emails_queue.append(spam_data)
	else:
		_play_new_email_sound()

func _ensure_spam_fields(spam_data: Dictionary) -> void:
	if not spam_data.has("sender"):
		spam_data["sender"] = spam_data.get("from", "Unknown Sender")
	if not spam_data.has("subject"):
		spam_data["subject"] = "Spam Email"
	if not spam_data.has("content"):
		spam_data["content"] = spam_data.get("body", "Spam content")
	if not spam_data.has("timestamp"):
		spam_data["timestamp"] = Time.get_datetime_string_from_system()
	if not spam_data.has("news_data"):
		spam_data["news_data"] = {
			"article_text": spam_data.get("body", spam_data.get("content", "")),
			"tip_text": "This is spam - ignore it.",
			"facts": [],
			"stance": "spam",
			"integrity_score": 0.0
		}
	spam_data["is_spam"] = true

func _prepare_mail_data(mail_dict: Dictionary) -> Dictionary:
	"""Helper to prepare mail data with required fields"""
	var mail_data = mail_dict.duplicate()
	
	if not mail_data.has("sender"):
		mail_data["sender"] = mail_data.get("from", "Unknown Sender")
	
	# Build main_text from content and news_data
	var email_content = mail_data.get("content", "")
	var news_data = mail_data.get("news_data", {})
	
	push_error("[Emails Controller] Preparing mail data:")
	push_error("  - email_content length: " + str(email_content.length()))
	push_error("  - news_data keys: " + (str(news_data.keys()) if news_data else "none"))
	
	var main_text_parts = []
	
	if email_content != "":
		main_text_parts.append(email_content)
		push_error("  - Added email_content")
	
	if news_data and not news_data.is_empty():
		if news_data.has("article_text") and news_data.get("article_text", "") != "":
			main_text_parts.append("\n\n[b]Article:[/b] " + news_data.get("article_text", ""))
			push_error("  - Added article_text")
		
		if news_data.has("tip_text") and news_data.get("tip_text", "") != "":
			main_text_parts.append("\n\n[b]Tip:[/b] " + news_data.get("tip_text", ""))
			push_error("  - Added tip_text")
	
	mail_data["main_text"] = "".join(main_text_parts)
	
	if mail_data["main_text"] == "":
		mail_data["main_text"] = "No content available."
		push_error("  - WARNING: No content found, using default")
	
	push_error("  - Final main_text length: " + str(mail_data["main_text"].length()))
	push_error("  - First 150 chars: " + mail_data["main_text"].substr(0, 150))
	
	return mail_data

func _on_mail_opened(mail_dict: Dictionary) -> void:
	push_error("========== [Emails Controller._on_mail_opened] CALLED ==========")
	push_error("[Emails Controller] mail_dict keys: " + str(mail_dict.keys()))
	
	if not container:
		push_error("[Emails Controller] ERROR: container is null!")
		return
	
	# 25% chance to trigger glitch when viewing spam email content
	if mail_dict.get("is_spam", false):
		var glitch_chance = randf()
		if glitch_chance < 0.25:
			_trigger_spam_email_glitch()
	
	var mail_instance = mail_prefab.instantiate()
	container.add_child(mail_instance)
	
	push_error("[Emails Controller] Mail instance created and added to container")
	
	await get_tree().process_frame
	
	if mail_instance.has_method("load_mail"):
		push_error("[Emails Controller] Calling _prepare_mail_data...")
		var prepared_data = _prepare_mail_data(mail_dict)
		push_error("[Emails Controller] Calling load_mail on instance...")
		mail_instance.load_mail(prepared_data)
		push_error("[Emails Controller] load_mail call completed")
	else:
		push_error("[Emails Controller._on_mail_opened] Mail instance doesn't have load_mail method!")

func _trigger_spam_email_glitch() -> void:
	if laptop:
		if laptop.has_method("trigger_crash"):
			laptop.trigger_crash(SPAM_GLITCH_DURATION)
		elif laptop.has_method("add_glitch_effect"):
			laptop.add_glitch_effect(SPAM_GLITCH_DURATION)

func _apply_spam_evidence_penalty() -> void:
	if game_manager and game_manager.has_method("add_integrity_score"):
		game_manager.add_integrity_score(SPAM_EVIDENCE_PENALTY, "spam_emails")
	else:
		push_warning("[EmailsController] Unable to apply spam penalty - missing GameManager reference")

func _on_spam_email_add_attempted(_email_dict: Dictionary) -> void:
	_apply_spam_evidence_penalty()

func set_evidence_bank_controller(controller: EvidenceBankController) -> void:
	evidence_bank_controller = controller

func set_game_manager(manager: GameManager) -> void:
	game_manager = manager

func _play_new_email_sound() -> void:
	var sm: SoundManager = sound_manager
	if not sm and master and master.sound_manager:
		sm = master.sound_manager
	elif not sm:
		sm = SoundManager.instance
	
	if sm:
		sm.play_sound("NewEmail")

func _clear_inbox() -> void:
	"""Helper to clear all emails from inbox"""
	if mails_content:
		for child in mails_content.get_children():
			child.queue_free()

func reset_for_new_game() -> void:
	"""Reset email controller state for a new game run"""
	_has_spawned_initial = false
	spam_emails_queue.clear()
	used_email_indices.clear()
	_spawned_emails.clear()
	_clear_inbox()

func _ready() -> void:
	master = get_node("/root/Master")
	
	if master == null:
		print("[Emails_controller._ready] Master is null!")
		return
	
	if master and master.sound_manager:
		sound_manager = master.sound_manager
	elif SoundManager.instance:
		sound_manager = SoundManager.instance
	
	if not mails_content:
		_find_mails_content()
	
	if laptop:
		if not laptop.is_connected("open_emails", Callable(self, "_on_open_emails")):
			laptop.connect("open_emails", Callable(self, "_on_open_emails"))
		
		if laptop.has_method("get_evidence_bank_controller"):
			evidence_bank_controller = laptop.get_evidence_bank_controller()
	
	visible = false

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_ensure_containers_visible()
		if not spam_emails_queue.is_empty():
			spawn_queued_spam_emails()
