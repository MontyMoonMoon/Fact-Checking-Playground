extends Node

var aggression = 20
var last_sabotage_time = 0.0
var sabotage_cooldown = 30.0  # seconds

var sabotage_pool = [
	{"id": "viral_headline", "weight": 50, "acts": [1, 2]},
	{"id": "forged_doc", "weight": 30, "acts": [2, 3]},
	{"id": "deepfake", "weight": 10, "acts": [3]}
]

func maybe_sabotage(current_act: int, delta: float):
	if Time.get_unix_time_from_system() - last_sabotage_time < sabotage_cooldown:
		return
	if randi() % 100 > aggression:
		return

	var candidates = []
	for s in sabotage_pool:
		if current_act in s["acts"]:
			for i in range(s["weight"]):
				candidates.append(s)
	if candidates.is_empty():
		return

	var pick = candidates[randi() % candidates.size()]
	_execute_sabotage(pick["id"])
	last_sabotage_time = Time.get_unix_time_from_system()
	aggression += 10  # gets more hostile over time


func _execute_sabotage(id: String):
	match id:
		"viral_headline":
			print("Lyra spreads a viral disinfo headline.")
			
		"forged_doc":
			print("Lyra leaks a forged document.")
			
		"deepfake":
			print("Lyra releases a deepfake scandal.")
