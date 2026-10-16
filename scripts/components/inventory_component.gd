class_name InventoryComponent extends Node

# The player's 4 item slots and what's in their hand. Every machine keeps a
# copy of every player's inventory, so everyone sees what each player holds.
# - What's in each slot: decided by the host, announced with _set_slot().
# - Which slot is equipped: decided by the player, and synced by the player's
#   MultiplayerSynchronizer like their position.

signal changed # Used by the hotbar

const SLOT_COUNT: int = 4
const NO_SLOT: int = -1 # Nothing equipped, so the fists are out

# Items are created under the camera so they aim where the player looks
@export var item_holder: Node3D
@export var fists: Item

@onready var interaction_controller: InteractionController = $"../InteractionController"

var items: Array[Item] = [null, null, null, null] # null means the slot is empty
var equipped_slot: int = NO_SLOT:
	set(value):
		equipped_slot = value
		_update_equipped_item()
var equipped_item: Item # The fists, or the item in the equipped slot
# When set, this is held instead of anything in the inventory, and the
# inventory can't be used or changed (the werewolf's claws at night)
var override_item: Item:
	set(value):
		override_item = value
		_update_equipped_item()

func _ready() -> void:
	Log.debug("InventoryComponent._ready()")
	# Only our own player reacts to our input
	set_process_unhandled_input(is_multiplayer_authority())
	_update_equipped_item()

	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)

func _unhandled_input(event: InputEvent) -> void:
	# The chat box already keeps the keys we type, but not mouse clicks
	if Chat.is_typing: return

	if event.is_action_pressed("use_item"):
		# Hands are full while carrying a prop. (The werewolf's click throws it instead, see InteractionController.)
		if not interaction_controller.is_holding():
			equipped_item.use()
	elif override_item:
		return # No switching or dropping while something else is in our hands
	elif event.is_action_pressed("next_item"):
		_cycle_slot(1)
	elif event.is_action_pressed("previous_item"):
		_cycle_slot(-1)
	elif event.is_action_pressed("drop_item"):
		if equipped_slot != NO_SLOT:
			_request_drop.rpc_id(Networking.HOST_ID, equipped_slot)
	else:
		for slot in SLOT_COUNT:
			if event.is_action_pressed("slot_%d" % (slot + 1)):
				_select_slot(slot)

# Pressing the slot you're already holding puts it away. Empty slots do nothing.
func _select_slot(slot: int) -> void:
	Log.debug("InventoryComponent._select_slot()")
	if items[slot] == null: return
	equipped_slot = NO_SLOT if equipped_slot == slot else slot

# Mouse wheel: cycles through the filled slots only. The fists are only
# reached by pressing the equipped slot's key again.
func _cycle_slot(direction: int) -> void:
	Log.debug("InventoryComponent._cycle_slot()")
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
	Log.debug("InventoryComponent.set_slot()")
	_set_slot.rpc(slot, item_data.resource_path if item_data else "")

# Host only - someone joined during the match and missed every _set_slot() so far,
# so send them what's in each of our slots. (Which slot is equipped already
# reaches them through the player's MultiplayerSynchronizer.)
func _on_peer_connected(id: int) -> void:
	Log.debug("InventoryComponent._on_peer_connected()")
	for slot in SLOT_COUNT:
		if items[slot]:
			_set_slot.rpc_id(id, slot, items[slot].data.resource_path)

#region Picking up and dropping
# The host decides these, since two players could take the same item at the
# same moment. The requests are "any_peer", but are only accepted from this
# inventory's own player.

# Called by the InteractionController when we tap interact on a pickup
func request_pickup(pickup: ItemPickup) -> void:
	Log.debug("InventoryComponent.request_pickup()")
	if override_item: return # Can't pick things up while something else is in our hands
	_request_pickup.rpc_id(Networking.HOST_ID, pickup.get_path())

# Player -> Host
@rpc("any_peer", "call_local", "reliable")
func _request_pickup(pickup_path: NodePath) -> void:
	Log.debug("InventoryComponent._request_pickup()")
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority(): return

	var pickup: ItemPickup = get_node_or_null(pickup_path)
	if pickup == null or pickup.is_queued_for_deletion(): return # Someone else already took it
	var interaction_component: InteractionComponent = pickup.get_node("InteractionComponent")
	if interaction_component.is_held_by_other(get_multiplayer_authority()): return # Someone is carrying it
	var free_slot: int = items.find(null)
	if free_slot == -1: return # Inventory is full

	set_slot(free_slot, pickup.item_data)
	pickup.queue_free() # The ItemSpawner removes it for everyone

# Player -> Host
@rpc("any_peer", "call_local", "reliable")
func _request_drop(slot: int) -> void:
	Log.debug("InventoryComponent._request_drop()")
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority(): return
	if items[slot] == null: return

	# 1m in front of the player. It then falls to the floor.
	var player: Node3D = get_parent()
	var drop_position: Vector3 = player.global_position - player.global_basis.z
	ItemSpawner.instance.spawn_pickup(items[slot].data, drop_position)
	set_slot(slot, null)

# Host only - called when the player dies, so everything they carried falls around them
func drop_all() -> void:
	Log.debug("InventoryComponent.drop_all()")
	var player: Node3D = get_parent()
	for item in items:
		if item:
			var scatter: Vector3 = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
			ItemSpawner.instance.spawn_pickup(item.data, player.global_position + scatter)
#endregion

# Host -> Everyone
# NOTE - "any_peer" because this node is owned by its player, not the host,
#        so the default "authority" mode would reject the host's call
@rpc("any_peer", "call_local", "reliable")
func _set_slot(slot: int, item_path: String) -> void:
	Log.debug("InventoryComponent._set_slot()")
	if multiplayer.get_remote_sender_id() != Networking.HOST_ID: return

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
	Log.debug("InventoryComponent._update_equipped_item()")
	if not is_node_ready(): return
	if is_instance_valid(equipped_item):
		equipped_item.hide()

	# Falls back to the fists if the slot's item hasn't arrived yet, since on
	# other machines equipped_slot and _set_slot() can arrive in either order
	equipped_item = fists
	if override_item:
		equipped_item = override_item
	elif equipped_slot != NO_SLOT and items[equipped_slot]:
		equipped_item = items[equipped_slot]
	equipped_item.show()
	changed.emit()
