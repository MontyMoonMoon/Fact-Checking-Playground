extends Control


@onready var info_buttons_container = $InfoListContainer/ScrollContainer/VBoxContainer
@onready var info_popup = $InfoPopup
@onready var popup_title = $InfoPopup/popup_title
@onready var popup_content = $InfoPopup/popup_content
@onready var keep_button = $InfoPopup/HBoxContainer/Keep
@onready var discard_button = $InfoPopup/HBoxContainer/Discard
@onready var close_button = $InfoPopup/HBoxContainer/Close

var available_infos = [] # Example: [{"type":"article","title":"X","content":"Y"}]
var selected_info: Dictionary = {}
var comparer_scene_ref: Node = null # Reference to ArticleComparer

func _ready():
	info_popup.hide()

	# Temporary demo data
	available_infos = [
		{"type": "article", "title": "Vaccine Study Findings", "content": "Recent studies show..."},
		{"type": "tip", "title": "Check Sources Carefully", "content": "Always verify URLs and..."},
		{"type": "article", "title": "Political News Leak", "content": "Anonymous sources claim..."},
	]

	_display_info_list()

	# Button signals
	keep_button.pressed.connect(_on_keep_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	close_button.pressed.connect(_on_close_popup)


func _display_info_list():
	# Clear existing buttons
	for child in info_buttons_container.get_children():
		child.queue_free()

	# Add buttons dynamically
	for info in available_infos:
		var btn := Button.new()
		btn.text = "%s: %s" % [info["type"].capitalize(), info["title"]]
		btn.connect("pressed", Callable(self, "_on_info_selected").bind(info))
		info_buttons_container.add_child(btn)


func _on_info_selected(info: Dictionary):
	selected_info = info

	# Optional zoom effect
	_zoom_to_info()

	# Show popup
	popup_title.text = "%s - %s" % [info["type"].capitalize(), info["title"]]
	popup_content.text = info["content"]
	info_popup.popup_centered(Vector2(400, 300))


func _on_keep_pressed():
	if selected_info.is_empty():
		return

	print(" Keeping info:", selected_info["title"])

	if comparer_scene_ref and comparer_scene_ref.has_method("add_info"):
		comparer_scene_ref.add_info(selected_info)
	else:
		push_warning("No comparer scene connected, or add_info() missing.")

	info_popup.hide()


func _on_discard_pressed():
	if selected_info.is_empty():
		return
	print(" Discarded info:", selected_info["title"])
	info_popup.hide()


func _on_close_popup():
	info_popup.hide()


func _zoom_to_info():
	var cam = get_tree().get_current_scene().get_node_or_null("Camera2D")
	if cam:
		var tween = create_tween()
		tween.tween_property(cam, "zoom", Vector2(0.8, 0.8), 0.4)
		await get_tree().create_timer(0.6).timeout
		tween.tween_property(cam, "zoom", Vector2(1.0, 1.0), 0.4)
