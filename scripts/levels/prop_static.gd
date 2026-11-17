@tool
class_name PropStatic extends StaticBody3D

# A model that never moves (crates, furniture, ...), with collision so players
# can stand on it and bump into it.
#
# Placed in TrenchBroom as a "prop_static" entity (defined in
# trenchbroom/entities/prop_static.tres). Its "model" property is the model's
# path inside the project, e.g. "assets/models/props/Boxes/wooden_crate_2.glb",
# picked from a dropdown (filled by prop_static_model_list.gd).
# TrenchBroom shows that model, and building the map turns the entity into
# this node with the model and its collision inside it.
#
# NOTE - @tool because the map is built inside the editor, and the editor only
#        runs functions (like the one below) from @tool scripts

# Called by func_godot while it builds the map, with the entity's properties from TrenchBroom
# NOTE - No Log.debug() here. This runs in the editor, where the Log autoload doesn't exist.
func _func_godot_apply_properties(properties: Dictionary) -> void:
	# Without "res://", because TrenchBroom mangles values like "res://..." (see ENTITIES.md)
	var model_path: String = "res://" + properties["model"]
	var model_scene: PackedScene = load(model_path)
	if model_scene == null:
		push_error("%s: no model at %s. Check the model property of this prop_static in TrenchBroom." % [name, model_path])
		return

	var model: Node3D = model_scene.instantiate()
	# func_godot turns every point entity an extra 180° (so marker-style entities
	# face the right way). For a model that would make it face the opposite way
	# from TrenchBroom, so turn the model back. (See ENTITIES.md 3f.)
	model.rotation_degrees.y = 180
	add_child(model)
	# Owned by the map scene so it's saved with it (as a link to the model file, not a copy)
	model.owner = owner

	# One collision shape per mesh, wrapped tightly around it like shrink wrap.
	# Fine for boxy things like crates. Hollow shapes (like a table) get filled in.
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var collision_shape: CollisionShape3D = CollisionShape3D.new()
		collision_shape.shape = mesh_instance.mesh.create_convex_shape()
		collision_shape.transform = _transform_relative_to_self(mesh_instance)
		add_child(collision_shape)
		collision_shape.owner = owner

# Where a node inside the model sits relative to this prop, so its collision
# lines up with it. (Its global_transform isn't usable yet during the build.)
func _transform_relative_to_self(node: Node3D) -> Transform3D:
	var relative: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != self:
		relative = current.transform * relative
		current = current.get_parent()
	return relative
