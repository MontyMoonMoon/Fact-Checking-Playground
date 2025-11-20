extends Control

@export var integrity_meter: VSlider

func load_integrity() -> void:
	pass
	
func save_integrity() -> void:
	pass

func update_integrity(score: float) -> void:
	if integrity_meter:
		
		# Normalize score to 0-1 range (assuming 0-10 scale)
		
		var normalized = clamp(score / 10.0, 0.0, 1.0)
		integrity_meter.value = normalized * 100.0  # VSlider uses 0-100
		print("Integrity updated: %.2f (normalized: %.2f)" % [score, normalized])

# ---------- GODOT CALLBACKS ----------
func _ready() -> void:
	if integrity_meter:
		integrity_meter.min_value = 0
		integrity_meter.max_value = 100
		integrity_meter.value = 50  # Start at middle
