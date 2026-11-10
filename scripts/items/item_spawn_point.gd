@tool
class_name ItemSpawnPoint extends Marker3D

# Where an item starts. The host's ItemSpawner creates a pickup of this item
# here when the round starts.
#
# Placed in TrenchBroom as an "info_item_spawn" entity (defined in
# trenchbroom/entities/info_item_spawn.tres), where its "item" property picks
# which item. Building the map turns each one into one of these nodes.
#
# NOTE - @tool because the map is built inside the editor, and the editor only
#        runs functions (like the one below) from @tool scripts

@export var item: ItemData

# Called by func_godot while it builds the map, with the entity's properties
# from TrenchBroom. "item" is the name of the item's ItemData file in
# scenes/items/, e.g. "bat" for bat.tres. (Just the name, because TrenchBroom
# mangles values like "res://..." in its dropdowns.)
# NOTE - No Log.debug() here. This runs in the editor, where the Log autoload doesn't exist.
func _func_godot_apply_properties(properties: Dictionary) -> void:
	var item_path: String = "res://scenes/items/%s.tres" % properties["item"]
	item = load(item_path)
	# Shows up in the editor's Output while building, instead of crashing later when the round starts
	if item == null:
		push_error("%s: no item at %s. Pick an item for this info_item_spawn in TrenchBroom." % [name, item_path])
