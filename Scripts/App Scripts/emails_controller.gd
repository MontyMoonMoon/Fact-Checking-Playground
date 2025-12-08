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
var _last_loaded_map: String = ""  # Track which map's emails are currently loaded

@onready var email_prefab = preload("res://Prefabs/Components/email.tscn")
@onready var mail_prefab = preload("res://Prefabs/Components/mail.tscn")

var _has_spawned_initial: bool = false
var _spawned_emails: Array = []

const SPAM_EVIDENCE_PENALTY := -3.0
const SPAM_DISCARD_REWARD := 0.10
const SPAM_GLITCH_DURATION := 2.5

func _on_open_emails() -> void:
	if not visible:
		visible = true
		show()
	
	if not mails_content:
		_find_mails_content()
	
	if not mails_content:
		return
	
	# Check if we need to reload emails (map changed or pool is empty)
	var current_map = _get_current_map()
	if email_news_pool.is_empty() or _last_loaded_map != current_map:
		print("[Emails Controller] Reloading emails - pool empty: %s, map changed: %s (was: %s, now: %s)" % [email_news_pool.is_empty(), _last_loaded_map != current_map, _last_loaded_map, current_map])
		_load_email_news()
	
	# Count only normal emails (not spam) to determine if we need to spawn
	var normal_email_count = 0
	for child in mails_content.get_children():
		var is_spam = false
		if child.has_method("get_is_spam_email"):
			is_spam = child.get_is_spam_email()
		else:
			# Access is_spam_email property directly (it's a var in email.gd)
			# Use get() method which works on any object
			var spam_value = child.get("is_spam_email")
			if spam_value != null:
				is_spam = spam_value
		
		if not is_spam:
			normal_email_count += 1
	
	if not spam_emails_queue.is_empty():
		spawn_queued_spam_emails()
	
	# Spawn normal emails if we have none (or very few)
	if normal_email_count == 0:
		spawn_normal_emails()

func _reset_email_indices_if_needed() -> void:
	"""Helper to reset email indices when inbox is empty or all emails used"""
	var existing_count = mails_content.get_child_count() if mails_content else 0
	if existing_count == 0 or used_email_indices.size() >= email_news_pool.size():
		used_email_indices.clear()

func spawn_normal_emails() -> void:
	# Check if we need to reload emails (map changed or pool is empty)
	var current_map = _get_current_map()
	if email_news_pool.is_empty() or _last_loaded_map != current_map:
		print("[Emails Controller] Reloading emails in spawn_normal_emails - pool empty: %s, map changed: %s" % [email_news_pool.is_empty(), _last_loaded_map != current_map])
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

		# Reward integrity if this spam email gets discarded
	if email_instance.has_signal("email_discarded"):
		email_instance.connect("email_discarded", Callable(self, "_on_email_discarded"))

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
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[Emails_controller] Could not open email_news.json for reading")
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[Emails_controller] Failed to parse email_news.json: %s" % json.get_error_message())
		return false
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[Emails_controller] Invalid JSON format: expected dictionary, got %s" % typeof(data))
		return false
	
	var current_map = _get_current_map()
	print("[Emails_controller] Detected current map: %s" % current_map)
	
	# Debug: show available maps in JSON
	if typeof(data) == TYPE_DICTIONARY:
		var available_maps = data.keys()
		print("[Emails_controller] Available maps in email_news.json: %s" % str(available_maps))
		if not data.has(current_map):
			push_warning("[Emails_controller] WARNING: Current map '%s' not found in email_news.json! Available: %s" % [current_map, str(available_maps)])
	
	# Handle map_0 specially - it might not have a section, so use map_01 as fallback
	if current_map == "map_0" or current_map == "":
		current_map = "map_01"
		print("[Emails_controller] map_0 detected, using map_01 as fallback")
	
	# Try to load from current map section
	if data.has(current_map):
		var map_emails = data[current_map]
		if typeof(map_emails) == TYPE_ARRAY:
			email_news_pool = map_emails.duplicate(true)
			_last_loaded_map = current_map  # Track which map we loaded
			used_email_indices.clear()  # Clear used indices when loading new map
			print("[Emails_controller] Loaded %d email news items for %s" % [email_news_pool.size(), current_map])
			if email_news_pool.size() == 0:
				push_warning("[Emails_controller] WARNING: Loaded 0 emails for %s - check email_news.json!" % current_map)
			return true
		else:
			push_error("[Emails_controller] Invalid JSON format: '%s' section is not an array (type: %s)" % [current_map, typeof(map_emails)])
			email_news_pool = []
			_last_loaded_map = ""  # Reset tracking
			return false
	else:
		# Fallback: try to use old format with "emails" key
		if data.has("emails") and typeof(data["emails"]) == TYPE_ARRAY:
			email_news_pool = data["emails"].duplicate(true)
			_last_loaded_map = current_map  # Track which map we loaded
			used_email_indices.clear()  # Clear used indices when loading new map
			print("[Emails_controller] Loaded %d email news items from 'emails' key (fallback)" % email_news_pool.size())
			return true
		else:
			push_warning("[Emails_controller] No email news found for current map: %s" % current_map)
			email_news_pool = []
			_last_loaded_map = ""  # Reset tracking
			return false

func _get_current_map() -> String:
	"""Get the current map identifier - prioritize scene detection"""
	if not DataManager:
		print("[Emails_controller] No DataManager, using default: map_01")
		return "map_01"
	
	# PRIORITY 1: Try to detect from scene path (most reliable)
	var scene_tree = get_tree()
	if scene_tree and scene_tree.current_scene:
		var scene_path = scene_tree.current_scene.scene_file_path
		if scene_path:
			var scene_name = scene_path.get_file().get_basename()
			if scene_name in ["map_01", "map_02", "map_03"]:
				print("[Emails_controller] Using scene path: %s (scene file: %s)" % [scene_name, scene_path])
				if DataManager.current_map != scene_name:
					print("[Emails_controller] Updating DataManager.current_map from %s to %s" % [DataManager.current_map, scene_name])
					DataManager.current_map = scene_name
					DataManager.save_data()
				return scene_name
			else:
				print("[Emails_controller] Scene name '%s' not recognized as valid map" % scene_name)
		else:
			print("[Emails_controller] Scene path is empty")
	else:
		print("[Emails_controller] No current scene found")
	
	# PRIORITY 2: Try to detect from scene tree structure (root children)
	if scene_tree:
		var root = scene_tree.root
		if root:
			for child in root.get_children():
				var child_name = child.name
				if child_name in ["map_01", "map_02", "map_03"]:
					print("[Emails_controller] Found map node in root children: %s" % child_name)
					if DataManager.current_map != child_name:
						print("[Emails_controller] Updating DataManager.current_map from %s to %s" % [DataManager.current_map, child_name])
						DataManager.current_map = child_name
						DataManager.save_data()
					return child_name
	
	# PRIORITY 3: Use DataManager if it's valid
	if DataManager.current_map in ["map_01", "map_02", "map_03"]:
		print("[Emails_controller] Using DataManager.current_map (fallback): %s" % DataManager.current_map)
		return DataManager.current_map
	
	# PRIORITY 4: If email pool is empty, we're likely starting a new game on map_01
	if email_news_pool.is_empty():
		print("[Emails_controller] Email pool empty - forcing map_01 for new game")
		DataManager.current_map = "map_01"
		DataManager.save_data()
		return "map_01"
	
	# Default fallback
	print("[Emails_controller] All detection methods failed, defaulting to map_01")
	DataManager.current_map = "map_01"
	DataManager.save_data()
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
	var mail_data = mail_dict.duplicate(true)  # Deep copy to preserve all fields
	
	# Debug: log what we received
	print("[Emails Controller._prepare_mail_data] mail_dict keys: ", mail_dict.keys())
	print("[Emails Controller._prepare_mail_data] content: ", mail_dict.get("content", "MISSING"))
	print("[Emails Controller._prepare_mail_data] main_text: ", mail_dict.get("main_text", "MISSING"))
	print("[Emails Controller._prepare_mail_data] news_data: ", mail_dict.get("news_data", {}))
	
	if not mail_data.has("sender"):
		mail_data["sender"] = mail_data.get("from", "Unknown Sender")
	
	# The email JSON has a "content" field that contains the email body text
	# Omit article_text and tip_text from mail popup display
	var email_content = mail_data.get("content", "")
	
	# Build the email content (without article_text and tip_text)
	var full_content = ""
	
	# Start with the email body content
	if email_content != "":
		full_content = email_content
	
	# If still empty, check if main_text was already set
	if full_content == "":
		var existing_main_text = mail_data.get("main_text", "")
		if existing_main_text != "" and existing_main_text != "No content available.":
			full_content = existing_main_text
			print("[Emails Controller._prepare_mail_data] Using existing main_text")
	
	# Build main_text - use only the email content (no article_text or tip_text)
	if full_content != "":
		mail_data["main_text"] = full_content
		print("[Emails Controller._prepare_mail_data] Final main_text set, length: ", full_content.length())
		print("[Emails Controller._prepare_mail_data] Preview: ", full_content.substr(0, min(100, full_content.length())))
	else:
		mail_data["main_text"] = "No content available."
		push_warning("[Emails Controller] WARNING: No content found in email data - all fields empty")
		print("[Emails Controller._prepare_mail_data] WARNING: Setting default 'No content available.'")
	
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
		
func _apply_spam_discard_reward() -> void:
	if game_manager and game_manager.has_method("add_integrity_score"):
		game_manager.add_integrity_score(SPAM_DISCARD_REWARD, "spam_discard")
	else:
		push_warning("[EmailsController] Unable to apply discard reward - missing GameManager reference")
		

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
	email_news_pool.clear()
	_last_loaded_map = ""  # Reset map tracking
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
			
func _on_email_discarded(email_instance) -> void:
	# Check if the discarded email was spam
	var is_spam = false
	
	if email_instance.has_method("get_is_spam_email"):
		is_spam = email_instance.get_is_spam_email()
	else:
		var val = email_instance.get("is_spam_email")
		if val != null:
			is_spam = val

	if is_spam:
		_apply_spam_discard_reward()
