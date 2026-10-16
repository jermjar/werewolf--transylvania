class_name ItemData extends Resource

# Describes one kind of item. Each item has a .tres file using this script.
# Over the network an item is sent as that file's path, since every machine
# has the same files.

@export var display_name: String
# The Item that goes in the player's hand
@export var held_scene: PackedScene
# Damage when its pickup is thrown at someone at full strength (see ImpactDamageComponent)
@export var max_throw_damage: int = 10
