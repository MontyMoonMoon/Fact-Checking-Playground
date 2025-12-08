extends Control

var master: Master
var sound_manager: SoundManager

@export var tutorial_visible: bool
@export var tutorial: Control

@export_group("Visuals")
@export var notebook_button: Button
@export var notebook_texture: NinePatchRect
@export var notebook_opened: MarginContainer
@export var prompt_object: MarginContainer

@export_group("Left Text")
@export var title1: Label
@export var content1: Label

@export_group("Right Text")
@export var title2: Label
@export var content2: Label

var notebook_pages: Array = []
var current_page_index: int = 0

# ---------- SET TEXT FIELDS ----------
func _show_current_page() -> void:
	if notebook_pages.size() == 0:
		return
	
	var page = notebook_pages[current_page_index]
	
	# For simplicity: alternate pages
	if current_page_index % 2 == 0:
		set_left(page.get("header", ""), page.get("text_content", ""))
		# clear right if no next page
		if current_page_index + 1 < notebook_pages.size():
			var next_page = notebook_pages[current_page_index + 1]
			set_right(next_page.get("header", ""), next_page.get("text_content", ""))
		else:
			set_right("", "")
	else:
		set_right(page.get("header", ""), page.get("text_content", ""))
		# show previous on left if exists
		if current_page_index - 1 >= 0:
			var prev_page = notebook_pages[current_page_index - 1]
			set_left(prev_page.get("header", ""), prev_page.get("text_content", ""))
		else:
			set_left("", "")

func set_left(header: String, main: String) -> void:
	title1.text = header
	content1.text = main

func set_right(header: String, main: String) -> void:
	title2.text = header
	content2.text = main

# ---------- BUTTONS ----------
func _on_button_pressed() -> void:
	master.sound_manager.play_sound("ui_click")
	notebook_button.visible = false
	notebook_opened.visible = true
	prompt_object.visible = false

func _on_next_pressed() -> void:
	master.sound_manager.play_sound("page_turn")
	if current_page_index + 2 < notebook_pages.size():
		current_page_index += 2
		_show_current_page()

func _on_prev_pressed() -> void:
	master.sound_manager.play_sound("page_turn")
	if current_page_index - 2 >= 0:
		current_page_index -= 2
		_show_current_page()

func _on_close_pressed() -> void:
	master.sound_manager.play_sound("ui_click")
	notebook_opened.visible = false
	prompt_object.visible = true
	notebook_button.visible = true  

func button_visible() -> void:
	notebook_button.visible = true

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	master = get_node("/root/Master") 
	
	if tutorial:
		tutorial.connect("tutorial_done", Callable(self, "button_visible"))
		
	if tutorial_visible == true: 
		notebook_button.visible = false
	
	notebook_opened.visible = false
	# Load notebook content
	notebook_pages = master.json_manager.load_notebook_content()
	
	# Show first page if available
	if notebook_pages.size() > 0:
		current_page_index = 0
		_show_current_page()
