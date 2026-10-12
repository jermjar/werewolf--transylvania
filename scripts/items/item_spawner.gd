class_name ItemSpawner extends MultiplayerSpawner

# Creates item pickups in the world. Like players, pickups are only ever added
# and removed by the host, and this spawner copies that to everyone.

const PICKUP_SCENE: PackedScene = preload("res://scenes/items/item_pickup.tscn")

# The ItemSpawner of the current match, or null when no match is loaded
static var instance: ItemSpawner

# Parent of the level's ItemSpawnPoint markers
@export var spawn_points: Node3D

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	spawn_function = _spawn_pickup

# Host only - called once every peer has loaded the level
func spawn_level_items() -> void:
	for spawn_point: ItemSpawnPoint in spawn_points.get_children():
		spawn_pickup(spawn_point.item, spawn_point.global_position)

# Host only
func spawn_pickup(item_data: ItemData, at_position: Vector3) -> void:
	spawn({ "item_path": item_data.resource_path, "position": at_position })

# Runs on every peer with the data passed to spawn(). The spawner adds the pickup.
func _spawn_pickup(data: Dictionary) -> Node:
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	pickup.item_data = load(data.item_path)
	pickup.position = data.position
	return pickup
