""" PLACEHOLDER
extends Control
class_name ArticlePopup

# Signals
signal article_added(article_data: Dictionary)
signal article_removed(article_data: Dictionary)
signal popup_closed(article_data: Dictionary)

# References
@onready var article_label: RichTextLabel = $PopupContainer/VBoxContainer/MarginContainer/VBoxContainer2/ArticleText
@onready var tip_label: RichTextLabel = $PopupContainer/VBoxContainer/MarginContainer/VBoxContainer2/TipText
@onready var add_button: Button = $PopupContainer/VBoxContainer/ButtonContainer/AddButton
@onready var remove_button: Button = $PopupContainer/VBoxContainer/ButtonContainer/RemoveButton
@onready var close_button: Button = $PopupContainer/VBoxContainer/ButtonContainer/CloseButton

var article_data: Dictionary = {}
var game_manager: Node = null

func _ready():
	# Setup button connections
	add_button.pressed.connect(_on_add_pressed)
	remove_button.pressed.connect(_on_remove_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Enable BBCode
	article_label.bbcode_enabled = true
	tip_label.bbcode_enabled = true

func setup(article: Dictionary, manager: Node):
	article_data = article
	game_manager = manager
	
	# Display article and tip
	if article_label:
		article_label.text = article.get("article_text", "No article text")
	if tip_label:
		tip_label.text = article.get("tip_text", "No tip text")
	
	# Make visible
	visible = true

func _on_add_pressed():
	emit_signal("article_added", article_data)
	print("Article added: ", article_data.get("article_text", "").substr(0, 30))
	queue_free()

func _on_remove_pressed():
	emit_signal("article_removed", article_data)
	print("Article removed: ", article_data.get("article_text", "").substr(0, 30))
	queue_free()

func _on_close_pressed():
	emit_signal("popup_closed", article_data)
	print("Popup closed: ", article_data.get("article_text", "").substr(0, 30))
	queue_free()
"""
