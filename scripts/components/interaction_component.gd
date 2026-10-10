class_name InteractionComponent extends Node

const SPEED: float = 5.0
const HOST_ID: int = 1

enum InteractionType {
	DEFAULT
}

@export var object_reference: Node3D
@export var interaction_type: InteractionType = InteractionType.DEFAULT

var can_interact: bool = true
var is_interacting: bool = false

var player_hand: Marker3D

func _ready() -> void:
	_update_freeze()

	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# Runs once when the Player first clicks on an object
func pre_interact(hand: Marker3D) -> void:
	is_interacting = true

	match interaction_type:
		InteractionType.DEFAULT:
			player_hand = hand

	# Ask the host to make us the owner of this object
	_request_ownership.rpc_id(HOST_ID)

# Runs every physics frame when the Player is interacting with the object
func interact() -> void:
	if not can_interact: return
	# Only the owner moves the object. Right after grabbing, this waits
	# until the host's reply makes us the owner.
	if not object_reference.is_multiplayer_authority(): return

	match interaction_type:
		InteractionType.DEFAULT:
			_default_interact()

# Runs once when the Player stops interacting with an object
func post_interact() -> void:
	is_interacting = false

	match interaction_type:
		InteractionType.DEFAULT:
			pass

func _default_interact() -> void:
	var object_current_position: Vector3 = object_reference.global_transform.origin
	var hand_position: Vector3 = player_hand.global_transform.origin

	var object_distance: Vector3 = hand_position - object_current_position
	var rb3d: RigidBody3D = object_reference as RigidBody3D

	if rb3d:
		rb3d.set_linear_velocity(object_distance * (SPEED / rb3d.mass))

#region Ownership
# The owner (multiplayer authority) of an object runs its physics, and its
# MultiplayerSynchronizer sends the position to everyone else.
# Grabbing an object makes you its owner. The host makes that decision so
# two players grabbing at the same time can't both win.

# Grabbing player -> Host
@rpc("any_peer", "call_local", "reliable")
func _request_ownership() -> void:
	if not multiplayer.is_server(): return
	_set_owner.rpc(multiplayer.get_remote_sender_id())

# Host -> Everyone
# NOTE - "any_peer" because the default "authority" mode only accepts calls from
#        the current owner, and the host isn't always the owner
@rpc("any_peer", "call_local", "reliable")
func _set_owner(peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID: return

	# Recursive so the MultiplayerSynchronizer child changes owner too
	object_reference.set_multiplayer_authority(peer_id, true)
	_update_freeze()

# Freeze the object for everyone except its owner, so their physics doesn't
# fight the positions coming in from the MultiplayerSynchronizer
func _update_freeze() -> void:
	var rb3d: RigidBody3D = object_reference as RigidBody3D
	if rb3d:
		rb3d.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		rb3d.freeze = not object_reference.is_multiplayer_authority()

# Host only - if the owner leaves the game, the host takes the object back
func _on_peer_disconnected(id: int) -> void:
	if object_reference.get_multiplayer_authority() == id:
		_set_owner.rpc(HOST_ID)
#endregion
