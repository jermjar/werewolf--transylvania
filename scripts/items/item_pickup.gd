class_name ItemPickup extends RigidBody3D

# An item lying in the world. It's a physics prop like any other: it blocks
# players, and holding interact grabs it (see InteractionComponent). Tapping
# interact instead asks the host to put it in your inventory
# (see InventoryComponent.request_pickup()).
#
# Pickups are created and removed by the host's ItemSpawner, which copies that
# to everyone.

var item_data: ItemData # Set by the ItemSpawner before this is added

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	Log.debug("ItemPickup._ready()")
	# Shows the item's own held model, moved so its mesh sits at the pickup's centre
	var model: Node3D = item_data.held_scene.instantiate()
	add_child(model)
	var mesh: MeshInstance3D = model.get_node("Mesh")
	model.position = -mesh.position

	# A collision box the same size and angle as the mesh
	var box: BoxShape3D = BoxShape3D.new()
	box.size = mesh.mesh.get_aabb().size
	collision_shape.shape = box
	collision_shape.basis = mesh.basis
