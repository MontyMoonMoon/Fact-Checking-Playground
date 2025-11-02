extends Node

@onready var lyra = $Lyra  # antagonist node
@onready var ui = $UI  # placeholder on UI

var articles_analyzed = []
var daily_quota = 10
var integrity_score = 0.0
var day_over = false
var instant_death = false

func _ready():
	print("Day started — analyze", daily_quota, "articles.")
	_start_new_day()

func _process(delta):
	if day_over:
		return

	lyra.maybe_sabotage(get_current_act(), delta)
	
	if articles_analyzed.size() >= daily_quota:
		_evaluate_day()


func _start_new_day():
	articles_analyzed.clear()
	integrity_score = 0.0
	instant_death = false
	
	ui.update_integrity_bar(integrity_score)
	ui.show_message("New day begins! Quota: %d articles" % daily_quota)


func add_article_result(rf_score: float, lr_score: float):
	var total = rf_score * lr_score
	articles_analyzed.append(total)
	
	_recalculate_integrity()
	
	print("Added article. RF:", rf_score, "LR:", lr_score, "→ Integrity now:", integrity_score)
	ui.update_integrity_bar(integrity_score)


func _recalculate_integrity():
	if articles_analyzed.size() == 0: return
	var sum_total = 0.0
	
	for t in articles_analyzed:
		sum_total += t
	integrity_score = (sum_total / (articles_analyzed.size() * 10.0))
	
	# bonus from minigames or info
	integrity_score += _get_bonus_from_gameplay()
	integrity_score = clamp(integrity_score, 0, 10)

	if integrity_score < 3.0:
		_trigger_instant_death()


func _get_bonus_from_gameplay() -> float:
	# Placeholder: +0.1 per bonus
	return 0.1 * randi_range(0, 3)


func _trigger_instant_death():
	if not instant_death:
		instant_death = true
		ui.show_message("Integrity collapsed! You’ve been discredited...")
		get_tree().paused = true


func _evaluate_day():
	day_over = true
	ui.show_message("Day Complete. Integrity: %.2f" % integrity_score)
	if integrity_score < 5.0:
		ui.show_message("Company terminated your contract.")
	else:
		ui.show_message("You survived another day.")


func get_current_act() -> int:
	# Placeholder for act/phase progression
	return 2
