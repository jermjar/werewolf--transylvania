class_name Item extends Node3D

# Base class for anything a player can hold and use: fists for now, weapons and
# equipment later. The inventory only ever calls use() on whatever item is
# equipped, so adding new items doesn't require changing the inventory.

# Which kind of item this is. Set by the inventory when it creates the item.
# The fists aren't an inventory item, so theirs stays null.
var data: ItemData

# Called when the player presses "use_item" with this item equipped
func use() -> void:
	Log.debug("Item.use()")
	pass
