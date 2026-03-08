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
				print("- LOADING IN PROGRESS -")
				
			ResourceLoader.THREAD_LOAD_FAILED:
				print("- LOADING FAILED -")
				changing_scenes = false
				break
				
			ResourceLoader.THREAD_LOAD_LOADED:
				print("- LOADING COMPLETE -")
				var loaded_scene: PackedScene = ResourceLoader.load_threaded_get(scene)
				get_tree().change_scene_to_packed(loaded_scene)
				changing_scenes = false
				break
	return
