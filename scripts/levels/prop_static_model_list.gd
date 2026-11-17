@tool
extends RefCounted

# Fills the "model" dropdown of the prop_static entity in TrenchBroom with every
# .glb file in MODELS_FOLDER, including its subfolders.
#
# Hooked up as the "Entity Extension Script" of trenchbroom/entities/prop_static.tres.
# func_godot runs it every time the TrenchBroom config is exported, so after
# adding or moving a model: export again, then reload TrenchBroom.
#
# NOTE - @tool because the export runs inside the editor, and the editor only
#        runs functions (like the one below) from @tool scripts

const MODELS_FOLDER: String = "res://assets/models/props/"

# Called by func_godot during the export, with the prop_static definition
# NOTE - No Log.debug() here. This runs in the editor, where the Log autoload doesn't exist.
func _func_godot_attach_properties(definition: FuncGodotFGDEntityClass) -> void:
	# Dropdown entries: name shown in TrenchBroom -> value saved in the map.
	# e.g. "Boxes/wooden_crate_2" -> "assets/models/props/Boxes/wooden_crate_2.glb"
	var choices: Dictionary = {}
	for model_path: String in _find_models(MODELS_FOLDER):
		var shown_name: String = model_path.trim_prefix(MODELS_FOLDER).get_basename()
		# Without "res://", because TrenchBroom mangles values like "res://..." (see ENTITIES.md)
		choices[shown_name] = model_path.trim_prefix("res://")
	definition.class_properties["model"] = choices

# Every .glb file in folder and its subfolders, in alphabetical order
func _find_models(folder: String) -> Array[String]:
	var models: Array[String] = []
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() == "glb":
			models.append(folder + file)
	for subfolder: String in DirAccess.get_directories_at(folder):
		models.append_array(_find_models(folder + subfolder + "/"))
	models.sort()
	return models
