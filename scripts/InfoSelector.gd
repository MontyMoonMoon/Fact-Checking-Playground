extends Node2D

@onready var info_list_container = $InfoSelector/InfoPopup/MarginContainer/InfoListContainer
@onready var info_popup = $InfoSelector/InfoPopup
@onready var popup_title = $InfoSelector/InfoPopup/MarginContainer/popup_title
@onready var popup_content = $InfoSelector/InfoPopup/MarginContainer/popup_content
@onready var add_button = $InfoSelector/InfoPopup/HBoxContainer/Add
@onready var trash_button = $InfoSelector/InfoPopup/HBoxContainer/Trash
@onready var close_button = $InfoSelector/InfoPopup/HBoxContainer/Close
@onready var debug_button = $DebugButton

var stored_infos: Array = []
var selected_info: Dictionary = {}
var article_comparator_ref: Node = null
var debug_cases: Array = []

func _ready():
	info_popup.hide()
	_load_collected_infos()
	_display_info_buttons()
	_load_debug_cases("res://dataset.json")

	add_button.pressed.connect(_on_add_pressed)
	trash_button.pressed.connect(_on_trash_pressed)
	close_button.pressed.connect(_on_close_popup)
	debug_button.pressed.connect(_on_debug_pressed)


#Load the player’s accumulated infos
func _load_collected_infos():
	var file_path = "res://dataset.json"
	if not FileAccess.file_exists(file_path):
		push_error("Collected infos not found at %s" % file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(data) == TYPE_ARRAY:
		stored_infos = data
	else:
		push_error("Invalid JSON format — expected an Array of info objects.")


#Load and parse debug case data
func _load_debug_cases(path: String):
	if not FileAccess.file_exists(path):
		push_warning("No debug cases found at %s" % path)
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if data and data.has("cases"):
		debug_cases = data["cases"]
		print("Loaded %d debug cases." % debug_cases.size())
	else:
		push_warning("Invalid cases.json format.")


#Display info buttons
func _display_info_buttons():
	for child in info_list_container.get_children():
		child.queue_free()

	for info in stored_infos:
		var btn = Button.new()
		btn.text = "%s" % info.get("title", "Untitled Info")
		btn.connect("pressed", Callable(self, "_on_info_selected").bind(info))
		info_list_container.add_child(btn)


#Popup window logic
func _on_info_selected(info: Dictionary):
	selected_info = info
	popup_title.text = info.get("title", "Untitled Info")
	popup_content.text = info.get("content", "No content available.")
	info_popup.popup_centered(Vector2(600, 400))


func _on_add_pressed():
	if selected_info.is_empty(): return
	print("Added to Comparator:", selected_info["title"])
	if article_comparator_ref and article_comparator_ref.has_method("add_info"):
		article_comparator_ref.add_info(selected_info)
	info_popup.hide()


func _on_trash_pressed():
	if selected_info.is_empty(): return
	print("Moved to Trash:", selected_info["title"])
	stored_infos.erase(selected_info)
	_save_updated_infos()
	_display_info_buttons()
	info_popup.hide()


func _on_close_popup():
	info_popup.hide()


func _save_updated_infos():
	var file = FileAccess.open("res://collected_infos.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(stored_infos, "\t"))
	file.close()


#Debug Button: show random case from cases.json
func _on_debug_pressed():
	if debug_cases.is_empty():
		push_warning("No debug cases loaded!")
		return

	var c = debug_cases[randi() % debug_cases.size()]
	popup_title.text = " Debug Case — " + c["stance"]
	popup_content.text = (
		"[b]Article:[/b] " + c["article_text"] + "\n\n" +
		"[b]Tip:[/b] " + c["tip_text"] + "\n\n" +
		"[b]Facts:[/b]\n" + _format_facts(c["facts"]) + "\n" +
		"[b]Integrity Score:[/b] %.2f" % c["integrity_score"]
	)
	await get_tree().process_frame
	info_popup.popup_centered(Vector2(850, 500))

	


func _format_facts(facts: Array) -> String:
	var out = ""
	for f in facts:
		out += "- %s (%s): %s\n" % [f["category"], f["source"], f["value"]]
	return out.strip_edges()
