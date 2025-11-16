extends Control
class_name TrashPopup

signal closed
signal restore_requested(info_data: Dictionary)

@onready var list_container: VBoxContainer = $MarginContainer/ListContainer/ScrollContainer/VBoxContainer
@onready var close_button: Button = $MarginContainer/ListContainer/HBoxContainer/CloseButton
@onready var restore_all_button: Button = $MarginContainer/ListContainer/HBoxContainer/RestoreAllButton

var trashed_infos: Array = []

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	restore_all_button.pressed.connect(_on_restore_all_pressed)
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(data: Array):
	trashed_infos = data
	_refresh_list()

func _refresh_list():
	if not list_container:
		push_error("[TrashPopup] list_container is null! Cannot refresh list.")
		print("[TrashPopup] Attempting to find container manually...")
		list_container = get_node_or_null("MarginContainer/ListContainer/ScrollContainer/VBoxContainer")
		if not list_container:
			push_error("[TrashPopup] Could not find list container at expected path!")
			return
	
	for child in list_container.get_children():
		child.queue_free()

	if trashed_infos.is_empty():
		var empty = Label.new()
		empty.text = "Trash is empty."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(empty)
		return

	for info in trashed_infos:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		var label = Label.new()
		label.text = info.get("title", "Untitled")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hbox.add_child(label)

		var restore_button = Button.new()
		restore_button.text = "Restore"
		restore_button.custom_minimum_size = Vector2(100, 30)
		restore_button.pressed.connect(_on_restore_pressed.bind(info))
		hbox.add_child(restore_button)

		list_container.add_child(hbox)

func _on_restore_pressed(info: Dictionary):
	emit_signal("restore_requested", info)

func _on_restore_all_pressed():
	for info in trashed_infos:
		emit_signal("restore_requested", info)
	_on_close_pressed()

func _on_close_pressed():
	emit_signal("closed")
	hide()
