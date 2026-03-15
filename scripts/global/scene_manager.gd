extends Node

signal finished_loading

var changing_scenes: bool = false

func _process(_delta: float) -> void:
	if not changing_scenes: return
	print("- Changing Scenes -")

func change_scene(scene: String) -> void:
	if changing_scenes: return
	changing_scenes = true
	
	ResourceLoader.load_threaded_request(scene)
	_load_progress(scene)

func _load_progress(scene: String) -> void:
	var progress: Array = []
	while true:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(scene, progress)
		match status:
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				print("- INVALID RESOURCE BEING LOADED -")
				changing_scenes = false
				break
				
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				changing_scenes = true
				
			ResourceLoader.THREAD_LOAD_FAILED:
				print("- LOADING FAILED -")
				changing_scenes = false
				break
				
			ResourceLoader.THREAD_LOAD_LOADED:
				print("- LOADING COMPLETE -")
				var loaded_scene = ResourceLoader.load_threaded_get(scene).instantiate()
				get_tree().current_scene.queue_free()
				get_tree().root.add_child(loaded_scene)
				get_tree().current_scene = loaded_scene
				changing_scenes = false
				break
	return
