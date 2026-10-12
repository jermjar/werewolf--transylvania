class_name InventoryComponent extends Node

# The player's 4 item slots and what's in their hand. Every machine keeps a
# copy of every player's inventory, so everyone sees what each player holds.
# - What's in each slot: decided by the host, announced with _set_slot().
# - Which slot is equipped: decided by the player, and synced by the player's
#   MultiplayerSynchronizer like their position.

signal changed # Used by the hotbar

const SLOT_COUNT: int = 4
const NO_SLOT: int = -1 # Nothing equipped, so the fists are out
const HOST_ID: int = 1

# Items are created under the camera so they aim where the player looks
@export var item_holder: Node3D
@export var fists: Item

var items: Array[Item] = [null, null, null, null] # null means the slot is empty
var equipped_slot: int = NO_SLOT:
	set(value):
		equipped_slot = value
		_update_equipped_item()
var equipped_item: Item # The fists, or the item in the equipped slot

func _ready() -> void:
	# Only our own player reacts to our input
	set_process_unhandled_input(is_multiplayer_authority())
	_update_equipped_item()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_item"):
		equipped_item.use()
	elif event.is_action_pressed("next_item"):
		_cycle_slot(1)
	elif event.is_action_pressed("previous_item"):
		_cycle_slot(-1)
	else:
		for slot in SLOT_COUNT:
			if event.is_action_pressed("slot_%d" % (slot + 1)):
				_select_slot(slot)

# Pressing the slot you're already holding puts it away. Empty slots do nothing.
func _select_slot(slot: int) -> void:
	if items[slot] == null: return
	equipped_slot = NO_SLOT if equipped_slot == slot else slot

# Mouse wheel: cycles through the filled slots only. The fists are only
# reached by pressing the equipped slot's key again.
func _cycle_slot(direction: int) -> void:
	var filled_slots: Array[int] = []
	for slot in SLOT_COUNT:
		if items[slot]:
			filled_slots.append(slot)
	if filled_slots.is_empty(): return

	var index: int = filled_slots.find(equipped_slot)
	if index == -1:
		# Holding the fists: start at the first item, or the last when scrolling back
		equipped_slot = filled_slots[0] if direction > 0 else filled_slots[-1]
	else:
		equipped_slot = filled_slots[posmod(index + direction, filled_slots.size())]

# Host only. Puts an item in a slot on every machine, or empties it with null.
func set_slot(slot: int, item_data: ItemData) -> void:
	_set_slot.rpc(slot, item_data.resource_path if item_data else "")

# Host -> Everyone
# NOTE - "any_peer" because this node is owned by its player, not the host,
#        so the default "authority" mode would reject the host's call
@rpc("any_peer", "call_local", "reliable")
func _set_slot(slot: int, item_path: String) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID: return

	if items[slot]:
		# remove_child() right away, instead of waiting for queue_free(), so the new item can reuse the name
		item_holder.remove_child(items[slot])
		items[slot].queue_free()
		items[slot] = null

	if item_path:
		var item_data: ItemData = load(item_path)
		var item: Item = item_data.held_scene.instantiate()
		item.data = item_data
		item.name = "Slot%d" % slot # Same name on every machine, so RPCs on the item find it
		item.hide()
		item.set_multiplayer_authority(get_multiplayer_authority()) # Nodes added later don't inherit the player's ownership
		item_holder.add_child(item)
		items[slot] = item

	# The item in our hand was removed, so go back to the fists
	if slot == equipped_slot and items[slot] == null and is_multiplayer_authority():
		equipped_slot = NO_SLOT
	_update_equipped_item()

func _update_equipped_item() -> void:
	if not is_node_ready(): return
	if is_instance_valid(equipped_item):
		equipped_item.hide()

	# Falls back to the fists if the slot's item hasn't arrived yet, since on
	# other machines equipped_slot and _set_slot() can arrive in either order
	equipped_item = fists
	if equipped_slot != NO_SLOT and items[equipped_slot]:
		equipped_item = items[equipped_slot]
	equipped_item.show()
	changed.emit()
