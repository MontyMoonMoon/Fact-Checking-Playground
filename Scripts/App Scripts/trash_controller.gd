extends MarginContainer
class_name TrashController

@onready var scroll_area: ScrollContainer = $ScrollableArea
@onready var content_container: VBoxContainer = $ScrollableArea/ContentContainer
@onready var list_container: VBoxContainer = $ScrollableArea/ContentContainer/ListContainer/ScrollContainer/VBoxContainer
@onready var restore_all_button: Button = $ScrollableArea/ContentContainer/ButtonSection/RestoreAllButton

var trashed_infos: Array = []
var evidence_bank_ref: Node = null

func _ready():
	visible = false
	# Set mouse filter to ignore when hidden so it doesn't block interaction
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Also ensure parent containers are hidden
	if scroll_area:
		scroll_area.visible = false
		scroll_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if content_container:
		content_container.visible = false
		content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if restore_all_button:
		restore_all_button.pressed.connect(_on_restore_all_pressed)
	# Don't refresh list on startup - wait until app is opened
	_load_trashed_infos()

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			print("Trash Controller: Visibility changed to visible, refreshing...")
			# Enable mouse input when visible
			mouse_filter = Control.MOUSE_FILTER_STOP
			# CRITICAL: Make sure all containers are visible when parent becomes visible
			if scroll_area:
				scroll_area.visible = true
				scroll_area.mouse_filter = Control.MOUSE_FILTER_STOP
			if content_container:
				content_container.visible = true
				content_container.mouse_filter = Control.MOUSE_FILTER_STOP
			# Load and refresh after a frame to ensure visibility propagates
			_load_trashed_infos(true)
			call_deferred("_refresh_list")  # Use call_deferred instead of await
		else:
			# Ensure everything is hidden and doesn't block mouse input when hidden
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			if scroll_area:
				scroll_area.visible = false
				scroll_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if content_container:
				content_container.visible = false
				content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	# Ensure we're visible before trying to refresh
	if not visible:
		print("Trash Controller: WARNING - _refresh_list called while hidden!")
		return
	
	# Try to find list_container if not already set
	if not list_container:
		# Try multiple possible paths
		list_container = get_node_or_null("ScrollableArea/ContentContainer/ListContainer/ScrollContainer/VBoxContainer")
		if not list_container:
			list_container = get_node_or_null("ScrollableArea/ContentContainer/VBoxContainer/ListContainer/ScrollContainer/VBoxContainer")
		if not list_container:
			# Try finding by searching - find the deepest VBoxContainer in ScrollContainer
			var scroll_area_node = get_node_or_null("ScrollableArea")
			if scroll_area_node:
				var scroll_containers = []
				_find_scroll_containers(scroll_area_node, scroll_containers)
				for scroll in scroll_containers:
					for child in scroll.get_children():
						if child is VBoxContainer:
							list_container = child
							break
					if list_container:
						break
		if not list_container:
			print("Trash Controller: ERROR - list_container not found! Attempting to create...")
			# Try to create a fallback container
			if scroll_area:
				var content = scroll_area.get_node_or_null("ContentContainer")
				if content:
					var list_node = VBoxContainer.new()
					list_node.name = "ListContainer"
					content.add_child(list_node)
					var scroll = ScrollContainer.new()
					list_node.add_child(scroll)
					list_container = VBoxContainer.new()
					scroll.add_child(list_container)
					print("Trash Controller: Created fallback list_container")
			if not list_container:
				print("Trash Controller: CRITICAL - Could not create list_container!")
				return
	
	# Ensure list_container and its parents are visible
	if list_container:
		list_container.visible = true
		# Make sure parent containers are visible too
		var parent = list_container.get_parent()
		var depth = 0
		while parent and depth < 5:  # Limit depth to avoid infinite loops
			parent.visible = true
			parent.mouse_filter = Control.MOUSE_FILTER_STOP
			parent = parent.get_parent()
			depth += 1
	
	# Clear existing children
	for child in list_container.get_children():
		child.queue_free()
	
	print("Trash Controller: Refreshing list with %d items" % trashed_infos.size())
	
	if trashed_infos.is_empty():
		var empty = Label.new()
		empty.text = "Trash is empty."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color.WHITE)
		list_container.add_child(empty)
		print("Trash Controller: Displaying empty message")
		return
	
	# Display each trashed item
	for i in range(trashed_infos.size()):
		var info = trashed_infos[i]
		if not info or typeof(info) != TYPE_DICTIONARY:
			print("Trash Controller: WARNING - Invalid item at index %d, type: %s" % [i, typeof(info)])
			continue
		
		var item_title = info.get("title", "Untitled")
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		hbox.visible = true
		
		var label = Label.new()
		label.text = item_title
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color.WHITE)
		label.visible = true
		hbox.add_child(label)
		
		var restore_button = Button.new()
		restore_button.text = "Restore"
		restore_button.custom_minimum_size = Vector2(100, 30)
		restore_button.visible = true
		restore_button.pressed.connect(_on_restore_pressed.bind(info))
		hbox.add_child(restore_button)
		
		list_container.add_child(hbox)
		print("Trash Controller: Successfully added item %d: %s (container visible: %s)" % [i, item_title, list_container.visible])

func _find_scroll_containers(node: Node, result: Array):
	"""Recursively find all ScrollContainer nodes"""
	if node is ScrollContainer:
		result.append(node)
	for child in node.get_children():
		_find_scroll_containers(child, result)

func _on_restore_pressed(info: Dictionary):
	if evidence_bank_ref and evidence_bank_ref.has_method("restore_from_trash"):
		evidence_bank_ref.restore_from_trash(info)
		_load_trashed_infos()
		_refresh_list()

func _on_restore_all_pressed():
	if evidence_bank_ref and evidence_bank_ref.has_method("restore_all_from_trash"):
		evidence_bank_ref.restore_all_from_trash()
		_load_trashed_infos()
		_refresh_list()

