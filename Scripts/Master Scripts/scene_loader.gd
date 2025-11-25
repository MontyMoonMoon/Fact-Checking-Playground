extends Node
class_name SceneLoader

@export_group("Scenes")
@export var default_map_id: int = 0
@export var scenes: Array[PackedScene]

@export_group("Nodes & Attributes")
@export var current_scene: Node
@export var current_scene_id: int = 0

@export_group("Transition")
@export var fade_duration: float = 0.5
@export var fade_overlay: ColorRect = null

var _fade_layer: CanvasLayer = null
var is_first_load: bool = true

func _ready() -> void:
	call_deferred("_setup_fade_overlay")
	await get_tree().process_frame
	load_by_id(default_map_id)

func _setup_fade_overlay() -> void:
	if fade_overlay and fade_overlay.is_inside_tree():
		return
	
	if not _fade_layer:
		_fade_layer = CanvasLayer.new()
		_fade_layer.name = "FadeLayer"
		_fade_layer.layer = 100
		get_tree().root.add_child(_fade_layer)
		await get_tree().process_frame
	
	if not _fade_layer.is_inside_tree():
		await get_tree().process_frame
	
	if not fade_overlay:
		fade_overlay = ColorRect.new()
		fade_overlay.name = "FadeOverlay"
		fade_overlay.color = Color(0, 0, 0, 1)
		fade_overlay.anchors_preset = Control.PRESET_FULL_RECT
		fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_overlay.z_index = 1000
		fade_overlay.z_as_relative = false
		fade_overlay.visible = true
		
		_fade_layer.add_child(fade_overlay)
		await get_tree().process_frame
		
		if fade_overlay.is_inside_tree():
			fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			var viewport = get_viewport()
			if viewport:
				var viewport_size = viewport.get_visible_rect().size
				fade_overlay.size = viewport_size
				fade_overlay.position = Vector2.ZERO

func load_by_id(id: int) -> void:
	if id >= scenes.size():
		push_warning("[SceneLoader] Scene ID %d out of range." % id)
		return
	
	var skip_fade = is_first_load
	load_packed_scene(scenes[id], skip_fade)
	current_scene_id = id

func load_packed_scene(scene: PackedScene, skip_fade_out: bool = false) -> void:
	await _setup_fade_overlay()
	await get_tree().process_frame
	
	if is_first_load:
		if fade_overlay and fade_overlay.is_inside_tree():
			fade_overlay.color = Color(0, 0, 0, 1)
			fade_overlay.visible = true
		is_first_load = false
	elif not skip_fade_out:
		await fade_out()
	
	var instance: Node = scene.instantiate()
	
	if current_scene:
		current_scene.queue_free()
	
	current_scene = instance
	get_tree().root.add_child(instance)
	
	if _fade_layer and _fade_layer.get_parent() == get_tree().root:
		get_tree().root.move_child(_fade_layer, get_tree().root.get_child_count() - 1)
	
	await fade_in()

func fade_out() -> void:
	await _setup_fade_overlay()
	await get_tree().process_frame
	
	if not fade_overlay or not fade_overlay.is_inside_tree():
		return
	
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var viewport = get_viewport()
	if viewport:
		var viewport_size = viewport.get_visible_rect().size
		fade_overlay.size = viewport_size
		fade_overlay.position = Vector2.ZERO
	
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.visible = true
	
	if _fade_layer:
		_fade_layer.layer = 100
		if _fade_layer.get_parent() == get_tree().root:
			get_tree().root.move_child(_fade_layer, get_tree().root.get_child_count() - 1)
	
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 1), fade_duration)
	await tween.finished

func fade_in() -> void:
	await _setup_fade_overlay()
	await get_tree().process_frame
	
	if not fade_overlay or not fade_overlay.is_inside_tree():
		return
	
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var viewport = get_viewport()
	if viewport:
		var viewport_size = viewport.get_visible_rect().size
		fade_overlay.size = viewport_size
		fade_overlay.position = Vector2.ZERO
	
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.visible = true
	
	if _fade_layer:
		_fade_layer.layer = 100
	
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 0), fade_duration)
	await tween.finished
	
	fade_overlay.visible = false
