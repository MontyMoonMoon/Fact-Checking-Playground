extends Node
class_name SceneLoader

@export_group("Scenes")
@export var default_map_id: int = 0
@export var scenes: Array[PackedScene]

@export_group("Nodes & Attributes")
@export var current_scene: Node
@export var current_scene_id: int = 0

func load_packed_scene(scene: PackedScene) -> void:
	var instance: Node = scene.instantiate()

	if current_scene:
		current_scene.queue_free()
		print("[SceneLoader] Unloaded %s" % current_scene.name)
	
	current_scene = instance
	get_tree().root.add_child(instance)
	print("[SceneLoader] Loaded %s" % instance.name)

func load_by_id(id: int) -> void:
	if id >= scenes.size():
		push_warning("[SceneLoader] Scene ID %d out of range." % id)
		return
	
	print("[SceneLoader] Loading scene ID: %d" % id)
	load_packed_scene(scenes[id])
	current_scene_id = id

# ---------- GODOT CALLBACKS -----------
func _ready() -> void:
	call_deferred("load_by_id", default_map_id)
