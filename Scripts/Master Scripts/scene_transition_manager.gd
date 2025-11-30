extends Node
class_name SceneTransitionManager

# Manages scene transitions between map levels
# Handles data passing, state saving, and transition effects between scenes
# Background texture region_rect.x serves as level cue:
# - map_01: region_rect.x = 0
# - map_02: region_rect.x = 386
# - map_03: region_rect.x = 772

signal scene_changing(from_scene: String, to_scene: String)
signal scene_changed(to_scene: String)

var transition_data: Dictionary = {}  # Store data to pass between scenes
var previous_scene: String = ""
var current_scene_name: String = ""
var scene_loader: SceneLoader = null

# Map scene paths - background serves as level cue
const MAP_SCENES = {
	"map_01": "res://Scenes/map_01.tscn",  # region_rect.x = 0
	"map_02": "res://Scenes/map_02.tscn",  # region_rect.x = 386
	"map_03": "res://Scenes/map_03.tscn"   # region_rect.x = 772
}

# Map scene IDs for SceneLoader (index in scenes array)
const MAP_SCENE_IDS = {
	"map_01": 1,  # Index 1 in scenes array (0 is map_0)
	"map_02": 2,  # Index 2 in scenes array
	"map_03": 3   # Index 3 in scenes array
}

func _ready() -> void:
	current_scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
	# Get SceneLoader from Master
	var master = get_node_or_null("/root/Master")
	if master and master.has("scene_loader"):
		scene_loader = master.scene_loader

func transition_to_scene(scene_path: String, data: Dictionary = {}) -> void:
	"""Transition to a scene with optional data"""
	previous_scene = current_scene_name
	transition_data = data
	
	var scene_name = scene_path.get_file().get_basename()
	scene_changing.emit(current_scene_name, scene_name)
	
	# Load and change scene
	var scene = load(scene_path)
	if scene:
		get_tree().change_scene_to_packed(scene)
		current_scene_name = scene_name
		scene_changed.emit(scene_name)
	else:
		push_error("[SceneTransitionManager] Failed to load scene: %s" % scene_path)

func transition_to_map(map_name: String, data: Dictionary = {}) -> void:
	"""Transition to a specific map scene (map_01, map_02, or map_03)"""
	if not MAP_SCENES.has(map_name):
		push_error("[SceneTransitionManager] Unknown map scene: %s" % map_name)
		return
	
	# Use SceneLoader if available (preferred method)
	if scene_loader and MAP_SCENE_IDS.has(map_name):
		var scene_id = MAP_SCENE_IDS[map_name]
		previous_scene = current_scene_name
		transition_data = data
		scene_changing.emit(current_scene_name, map_name)
		scene_loader.load_by_id(scene_id)
		current_scene_name = map_name
		scene_changed.emit(map_name)
	else:
		# Fallback to direct scene loading
		var scene_path = MAP_SCENES[map_name]
		transition_to_scene(scene_path, data)

func transition_to_next_map(data: Dictionary = {}) -> void:
	"""Transition to the next map in sequence"""
	var current_map = current_scene_name
	var next_map = ""
	
	match current_map:
		"map_01":
			next_map = "map_02"
		"map_02":
			next_map = "map_03"
		"map_03":
			next_map = "map_01"  # Loop back to first
		_:
			next_map = "map_01"  # Default to first
	
	transition_to_map(next_map, data)

func transition_to_previous_map(data: Dictionary = {}) -> void:
	"""Transition to the previous map in sequence"""
	var current_map = current_scene_name
	var prev_map = ""
	
	match current_map:
		"map_01":
			prev_map = "map_03"  # Loop to last
		"map_02":
			prev_map = "map_01"
		"map_03":
			prev_map = "map_02"
		_:
			prev_map = "map_01"  # Default to first
	
	transition_to_map(prev_map, data)

func get_transition_data() -> Dictionary:
	"""Get data passed during transition"""
	return transition_data.duplicate(true)

func clear_transition_data() -> void:
	"""Clear stored transition data"""
	transition_data.clear()

func save_scene_state(scene_name: String, state: Dictionary) -> void:
	"""Save state for a specific scene (placeholder)"""
	# TODO: Implement state saving system
	pass

func load_scene_state(scene_name: String) -> Dictionary:
	"""Load state for a specific scene (placeholder)"""
	# TODO: Implement state loading system
	return {}
