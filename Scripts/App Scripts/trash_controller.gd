extends MarginContainer
class_name TrashController

var master: Master
var sound_manager: SoundManager

@export var laptop: Control

@export_group("Trash Container")
@export var trash_container: MarginContainer
@export var trash_list_container: VBoxContainer
@export var restore_button: Button

var trashed_infos: Array = []
var evidence_bank_ref: Node = null

func _ready():
	master = get_node("/root/Master")
	
	if master == null:
		print("[Trash_controller._ready] Master is still null. Calling members from this object may cause issues.")
		return
	
	if master.sound_manager:
		sound_manager = master.sound_manager
	
	# Find trash list container - FRONTUI structure: TextsContainer/Texts/Trash/TrashContainer/ScrollContainer/VBoxContainer
	if not trash_list_container:
		trash_list_container = get_node_or_null("TextsContainer/Texts/Trash/TrashContainer/ScrollContainer/VBoxContainer")
	
	# Find restore button
	if not restore_button:
		restore_button = get_node_or_null("Restore")
	
	# Connect restore button
	if restore_button:
		restore_button.pressed.connect(_on_restore_pressed)
	
	visible = false
	# Don't refresh list on startup - wait until app is opened
	_load_trashed_infos()

func reset_for_new_game() -> void:
	"""Reset trash for new game - clear all trashed items"""
	var json_manager = JSONManager.get_instance()
	if json_manager:
		json_manager.clear_trashed_infos()
		print("[Trash Controller] Cleared trashed items via JSONManager")
	else:
		# Fallback: clear file directly
		var file = FileAccess.open("user://trashed_infos.json", FileAccess.WRITE)
		if file:
			file.store_string("[]")
			file.close()
			print("[Trash Controller] Cleared trashed items (fallback)")
	
	trashed_infos.clear()
	
	# Clear UI
	if trash_list_container:
		for child in trash_list_container.get_children():
			child.queue_free()
	
	print("[Trash Controller] Reset for new game - all trashed items cleared")

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			print("Trash Controller: Visibility changed to visible, refreshing...")
			# Load and refresh after a frame to ensure visibility propagates
			_load_trashed_infos(true)
			call_deferred("_refresh_list")
		else:
			pass

func set_evidence_bank_ref(ref: Node):
	evidence_bank_ref = ref

func _load_trashed_infos(force_reload: bool = true):
	var json_manager = JSONManager.get_instance()
	if json_manager:
		trashed_infos = json_manager.load_trashed_infos(force_reload)
		print("Trash Controller: Loaded %d trashed items from JSONManager (force_reload=%s)" % [trashed_infos.size(), force_reload])
		# Debug: print first item if exists
		if trashed_infos.size() > 0:
			var first = trashed_infos[0]
			print("Trash Controller: First item - Title: %s, Has case_data: %s" % [
				first.get("title", "No title"),
				"yes" if first.has("case_data") else "no"
			])
		else:
			print("Trash Controller: No trashed items found")
	else:
		trashed_infos = JSONManager.load_json("user://trashed_infos.json", [])
		print("Trash Controller: Loaded %d trashed items (fallback)" % trashed_infos.size())

func _refresh_list():
	"""Refresh the trash list display"""
	# Ensure we're visible before trying to refresh
	if not visible:
		print("Trash Controller: WARNING - _refresh_list called while hidden!")
		return
	
	# Try to find trash_list_container if not already set
	if not trash_list_container:
		# Try FRONTUI structure path
		trash_list_container = get_node_or_null("TextsContainer/Texts/Trash/TrashContainer/ScrollContainer/VBoxContainer")
		
		# If still not found, try old structure path
		if not trash_list_container:
			trash_list_container = get_node_or_null("ScrollableArea/ContentContainer/ListContainer/ScrollContainer/VBoxContainer")
		
		if not trash_list_container:
			print("Trash Controller: ERROR - trash_list_container not found!")
			return
	
	# Ensure container is visible
	if trash_list_container:
		trash_list_container.visible = true
		# Make sure parent containers are visible too
		var parent = trash_list_container.get_parent()
		var depth = 0
		while parent and depth < 10:  # Limit depth to avoid infinite loops
			if parent is Control:
				parent.visible = true
				parent.mouse_filter = Control.MOUSE_FILTER_STOP
			parent = parent.get_parent()
			depth += 1
	
	# Clear existing children
	for child in trash_list_container.get_children():
		child.queue_free()
	
	print("Trash Controller: Refreshing list with %d items" % trashed_infos.size())
	
	if trashed_infos.is_empty():
		var empty = Label.new()
		empty.text = "Trash is empty."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color.BLACK)
		trash_list_container.add_child(empty)
		print("Trash Controller: Displaying empty message")
		return
	
	# Display each trashed item
	for i in range(trashed_infos.size()):
		var info = trashed_infos[i]
		if not info or typeof(info) != TYPE_DICTIONARY:
			print("Trash Controller: WARNING - Invalid item at index %d, type: %s" % [i, typeof(info)])
			continue
		
		var item_title = info.get("title", "Untitled")
		
		# Create label directly (no individual restore button - use "Restore All" button instead)
		var label = Label.new()
		label.text = item_title
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color.BLACK)
		label.visible = true
		label.custom_minimum_size = Vector2(0, 30)  # Ensure minimum height
		
		# Ensure trash_list_container expands properly for layout
		trash_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trash_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		trash_list_container.add_child(label)
		print("Trash Controller: Successfully added item %d: %s (no individual restore button - use Restore All)" % [i, item_title])

func _on_restore_item_pressed(info: Dictionary):
	"""Restore a single item from trash"""
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
	if evidence_bank_ref and evidence_bank_ref.has_method("restore_from_trash"):
		evidence_bank_ref.restore_from_trash(info)
		_load_trashed_infos()
		_refresh_list()

func _on_restore_pressed():
	"""Restore all items from trash"""
	if sound_manager:
		sound_manager.play_sound("mouse_click")
	
	if evidence_bank_ref and evidence_bank_ref.has_method("restore_all_from_trash"):
		evidence_bank_ref.restore_all_from_trash()
		_load_trashed_infos()
		_refresh_list()
