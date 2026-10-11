class_name Item extends Node3D

# Base class for anything a player can hold and use: fists for now, weapons and
# equipment later. The Player only ever calls use() on whatever item is
# equipped, so adding new items doesn't require changing the Player.

# Called when the player presses "use_item" with this item equipped
func use() -> void:
	pass
