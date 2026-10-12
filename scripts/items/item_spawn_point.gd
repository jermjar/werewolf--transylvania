class_name ItemSpawnPoint extends Marker3D

# Place these in a level to choose where items start. The host's ItemSpawner
# creates a pickup of this item here when the round starts.

@export var item: ItemData
