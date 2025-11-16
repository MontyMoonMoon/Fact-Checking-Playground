extends Control
class_name GameFailedPopup

# References
@onready var message_label: Label = $PopupContainer/VBoxContainer/MarginContainer/MessageLabel
@onready var breakdown_label: RichTextLabel = $PopupContainer/VBoxContainer/BreakdownContainer/BreakdownLabel
@onready var close_button: Button = $PopupContainer/VBoxContainer/ButtonContainer/CloseButton

func _ready():
	# Setup button connection
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Enable BBCode for breakdown
	if breakdown_label:
		breakdown_label.bbcode_enabled = true
	
	# Set default message text
	if message_label:
		message_label.text = "Day Complete"

func show_breakdown(breakdown: Dictionary, stats: Dictionary):
	"""Show integrity breakdown in Papers Please style"""
	var game_failed = stats.get("final_score", 0.0) < 6.0
	
	# Update title
	if message_label:
		if game_failed:
			message_label.text = "GAME FAILED"
			message_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
		else:
			message_label.text = "DAY COMPLETE"
			message_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3, 1))
	
	# Build breakdown text 
	var text = "[b]INTEGRITY BREAKDOWN[/b]\n\n"
	
	text += "[b]Base Score:[/b] %.2f\n" % breakdown.get("base_score", 5.0)
	
	if breakdown.get("articles_analyzed_bonus", 0.0) != 0.0:
		var bonus = breakdown.get("articles_analyzed_bonus", 0.0)
		var sign = "+" if bonus >= 0 else ""
		text += "[b]Articles Analyzed:[/b] %s%.2f (%d articles)\n" % [sign, bonus, stats.get("articles_analyzed", 0)]
	
	if breakdown.get("high_overlap_bonus", 0.0) > 0.0:
		text += "[b]High Semantic Overlap:[/b] +%.2f (%d comparisons)\n" % [breakdown.get("high_overlap_bonus", 0.0), stats.get("high_overlap", 0)]
	
	if breakdown.get("articles_added_bonus", 0.0) > 0.0:
		text += "[b]Articles Added:[/b] +%.2f (%d articles)\n" % [breakdown.get("articles_added_bonus", 0.0), stats.get("articles_added", 0)]
	
	if breakdown.get("articles_removed_penalty", 0.0) > 0.0:
		text += "[b]Articles Removed:[/b] -%.2f (%d articles)\n" % [breakdown.get("articles_removed_penalty", 0.0), stats.get("articles_removed", 0)]
	
	text += "\n[b]────────────────────[/b]\n"
	text += "[b]FINAL INTEGRITY:[/b] %.2f / 10.0\n" % stats.get("final_score", 0.0)
	
	if game_failed:
		text += "\n[color=red]Integrity too low. Game Failed.[/color]"
	else:
		text += "\n[color=green]You survived another day.[/color]"
	
	if breakdown_label:
		breakdown_label.text = text

func _on_close_pressed():
	# Unpause the game when closing (though game is already over)
	get_tree().paused = false
	queue_free()
