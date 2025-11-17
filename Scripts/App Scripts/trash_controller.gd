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
	if restore_all_button:
		restore_all_button.pressed.connect(_on_restore_all_pressed)
	_load_trashed_infos()
	_refresh_list()

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_load_trashed_infos()
		_refresh_list()

func set_evidence_bank_ref(ref: Node):
	evidence_bank_ref = ref

func _load_trashed_infos():
	var file_path = "user://trashed_infos.json"
	if not FileAccess.file_exists(file_path):
		trashed_infos = []
		print("Trash Controller: No trashed_infos.json file found")
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		trashed_infos = []
		print("Trash Controller: Could not open trashed_infos.json for reading")
		return
	
	var file_text = file.get_as_text()
	file.close()
	
	if file_text.strip_edges().is_empty():
		trashed_infos = []
		print("Trash Controller: trashed_infos.json is empty")
		return
	
	var data = JSON.parse_string(file_text)
	
	if typeof(data) == TYPE_ARRAY:
		trashed_infos = data
		print("Trash Controller: Loaded %d trashed items" % trashed_infos.size())
	else:
		trashed_infos = []
		print("Trash Controller: Invalid data format in trashed_infos.json")

func _refresh_list():
	if not list_container:
		list_container = get_node_or_null("ScrollableArea/ContentContainer/ListContainer/ScrollContainer/VBoxContainer")
		if not list_container:
			print("Trash Controller: list_container not found!")
			return
	
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
	
	for i in range(trashed_infos.size()):
		var info = trashed_infos[i]
		if not info or typeof(info) != TYPE_DICTIONARY:
			print("Trash Controller: WARNING - Invalid item at index %d" % i)
			continue
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		
		var label = Label.new()
		label.text = info.get("title", "Untitled")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color.WHITE)
		hbox.add_child(label)
		
		var restore_button = Button.new()
		restore_button.text = "Restore"
		restore_button.custom_minimum_size = Vector2(100, 30)
		restore_button.pressed.connect(_on_restore_pressed.bind(info))
		hbox.add_child(restore_button)
		
		list_container.add_child(hbox)
		print("Trash Controller: Added item %d: %s" % [i, info.get("title", "Untitled")])

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

