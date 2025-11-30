extends Node
class_name LevelTransition

# Placeholder script for level transitions
# This can be extended to handle level-specific transitions, animations, and data passing

signal transition_started(from_level: int, to_level: int)
signal transition_completed(to_level: int)

var scene_loader: SceneLoader = null
var transition_type: String = "fade"  # "fade", "slide", "wipe", "instant"
var transition_duration: float = 0.5

func _ready() -> void:
	# Get reference to scene loader
	var master = get_node_or_null("/root/Master")
	if master and master.has_method("get") and master.has("scene_loader"):
		scene_loader = master.scene_loader

func transition_to_level(level_id: int, transition_type_param: String = "fade") -> void:
	"""Transition to a specific level with optional transition type"""
	transition_type = transition_type_param
	
	if scene_loader:
		var current_level = scene_loader.current_scene_id
		transition_started.emit(current_level, level_id)
		
		match transition_type:
			"fade":
				_fade_transition(level_id)
			"slide":
				_slide_transition(level_id)
			"wipe":
				_wipe_transition(level_id)
			"instant":
				_instant_transition(level_id)
			_:
				_fade_transition(level_id)  # Default to fade
	else:
		push_warning("[LevelTransition] SceneLoader not found, using instant transition")
		if scene_loader:
			scene_loader.load_by_id(level_id)
		transition_completed.emit(level_id)

func _fade_transition(level_id: int) -> void:
	"""Fade transition between levels"""
	if scene_loader:
		scene_loader.load_by_id(level_id)
		transition_completed.emit(level_id)

func _slide_transition(level_id: int) -> void:
	"""Slide transition between levels (placeholder)"""
	# TODO: Implement slide animation
	if scene_loader:
		scene_loader.load_by_id(level_id)
		transition_completed.emit(level_id)

func _wipe_transition(level_id: int) -> void:
	"""Wipe transition between levels (placeholder)"""
	# TODO: Implement wipe animation
	if scene_loader:
		scene_loader.load_by_id(level_id)
		transition_completed.emit(level_id)

func _instant_transition(level_id: int) -> void:
	"""Instant transition (no animation)"""
	if scene_loader:
		scene_loader.load_by_id(level_id)
		transition_completed.emit(level_id)

func set_transition_duration(duration: float) -> void:
	"""Set the duration for transitions"""
	transition_duration = max(0.1, duration)
	if scene_loader:
		scene_loader.fade_duration = transition_duration

