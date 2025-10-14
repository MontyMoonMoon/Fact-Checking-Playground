extends Control

@onready var info_buttons_container = $InfoListContainer/ScrollContainer/VBoxContainer
@onready var info_popup = $InfoPopup
@onready var popup_title = $InfoPopup/popup_title
@onready var popup_content = $InfoPopup/popup_content
@onready var keep_button = $InfoPopup/HBoxContainer/Keep
@onready var discard_button = $InfoPopup/HBoxContainer/Discard
@onready var close_button = $InfoPopup/HBoxContainer/Close

var available_infos = []  # Will contain dicts like { "type": "article" | "tip", "title": "X", "content": "Y" }
var selected_info = null
var comparer_scene_ref = null  #Reference to your ArticleComparer if needed

func _ready():
	info_popup.hide()
	
	#PLACEHOLDER
	available_infos = [
		{"type": "article", "title": "Vaccine Study Findings", "content": "Recent studies show..."},
		{"type": "tip", "title": "Check Sources Carefully", "content": "Always verify URLs and..."},
		{"type": "article", "title": "Political News Leak", "content": "Anonymous sources claim..."},
	]
	
	_display_info_list()
	
	keep_button.pressed.connect(_on_keep_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	close_button.pressed.connect(_on_close_popup)


func _display_info_list():
	for child in info_buttons_container.get_children():
		child.queue_free()
	
	for info in available_infos:
		var btn = Button.new()
		btn.text = "%s: %s" % [info["type"].capitalize(), info["title"]]
		btn.connect("pressed", Callable(self, "_on_info_selected").bind(info))
		info_buttons_container.add_child(btn)


func _on_info_selected(info: Dictionary):
	selected_info = info
	
	# Simulate a "camera zoom" or focus
	_zoom_to_info(info)
	
	# Show popup with details
	popup_title.text = "%s - %s" % [info["type"].capitalize(), info["title"]]
	popup_content.text = info["content"]
	info_popup.popup_centered(Vector2(400, 300))


func _on_keep_pressed():
	if selected_info:
		print("Keeping info:", selected_info["title"])
		if comparer_scene_ref:
			comparer_scene_ref.add_info(selected_info)
	info_popup.hide()


func _on_discard_pressed():
	print("Discarded info:", selected_info["title"])
	info_popup.hide()


func _on_close_popup():
	info_popup.hide()


func _zoom_to_info(info: Dictionary):
	var cam = get_tree().get_current_scene().get_node("Camera2D")
	if cam:
		var tween = get_tree().create_tween()
		tween.tween_property(cam, "zoom", Vector2(0.8, 0.8), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.6).timeout
		tween.tween_property(cam, "zoom", Vector2(1.0, 1.0), 0.4)
