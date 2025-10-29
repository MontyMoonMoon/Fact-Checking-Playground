extends Node2D

@onready var info_buttons_container = $InfoPopup/InfoListContainer/ScrollContainer/info_buttons_container
@onready var info_popup = $InfoPopup
@onready var popup_title = $InfoPopup/popup_title
@onready var popup_content = $InfoPopup/popup_content
@onready var keep_button = $InfoPopup/HBoxContainer/Keep
@onready var discard_button = $InfoPopup/HBoxContainer/Discard
@onready var close_button = $InfoPopup/HBoxContainer/Close

var available_infos: Array = []
var selected_info: Dictionary = {}
var comparer_scene_ref: Node = null  # Reference to ArticleComparer

func _ready():
	info_popup.hide()
	_load_dataset()
	_display_info_list()

	# Connect button signals
	keep_button.pressed.connect(_on_keep_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	close_button.pressed.connect(_on_close_popup)


# Load dataset.json
func _load_dataset():
	var file_path = "res://dataset.json"
	if not FileAccess.file_exists(file_path):
		push_error("Dataset not found at %s" % file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(data) == TYPE_DICTIONARY and data.has("cases"):
		for entry in data["cases"]:
			var article_info = {
				"type": "article",
				"title": entry.get("article_title", "Untitled Article"),
				"content": entry.get("article_text", "No article content."),
				"full_entry": entry
			}
			available_infos.append(article_info)
	else:
		push_error("Invalid JSON format — missing 'cases' array.")


# Display buttons in ScrollContainer
func _display_info_list():
	for child in info_buttons_container.get_children():
		child.queue_free()

	for info in available_infos:
		var btn := Button.new()
		btn.text = "📄 %s" % info["title"]
		btn.connect("pressed", Callable(self, "_on_info_selected").bind(info))
		info_buttons_container.add_child(btn)


func _on_info_selected(info: Dictionary):
	selected_info = info
	popup_title.text = info["title"]
	popup_content.text = info["content"]
	info_popup.popup_centered(Vector2(500, 400))


func _on_keep_pressed():
	if selected_info.is_empty():
		return

	print("✅ Keeping:", selected_info["title"])

	if comparer_scene_ref and comparer_scene_ref.has_method("add_info"):
		comparer_scene_ref.add_info(selected_info["full_entry"])
	else:
		push_warning("No ArticleComparer reference or add_info() missing.")

	info_popup.hide()


func _on_discard_pressed():
	print("❌ Discarded:", selected_info.get("title", "Unknown"))
	info_popup.hide()


func _on_close_popup():
	info_popup.hide()
