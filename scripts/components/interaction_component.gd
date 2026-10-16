class_name InteractionComponent extends Node

const SPEED: float = 5.0
# Fastest a 1 kg object can be thrown, in m/s. Heavier objects are slower (see _throw()).
const MAX_THROW_SPEED: float = 20.0
# How much each new frame changes the tracked hand speed (0-1). Lower is smoother.
const HAND_SMOOTHING: float = 0.5

enum InteractionType {
	DEFAULT
}

@export var object_reference: Node3D
@export var interaction_type: InteractionType = InteractionType.DEFAULT

var can_interact: bool = true
# True while someone holds this object. Only set on the holder's machine,
# which is also the owner that checks for impact damage.
var is_held: bool = false

var player_hand: Marker3D
# How fast the hand is moving, so letting go can throw the object (see _throw())
var hand_velocity: Vector3
var last_hand_position: Vector3

func _ready() -> void:
	Log.debug("InteractionComponent._ready()")
	_update_freeze()

	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# Runs once when the Player first clicks on an object
func pre_interact(hand: Marker3D) -> void:
	Log.debug("InteractionComponent.pre_interact()")
	is_held = true
	match interaction_type:
		InteractionType.DEFAULT:
			player_hand = hand
			hand_velocity = Vector3.ZERO
			last_hand_position = hand.global_position

	# Ask the host to make us the owner of this object
	_request_ownership.rpc_id(Networking.HOST_ID)

# Runs every physics frame when the Player is interacting with the object
func interact() -> void:
	if not can_interact: return
	# Tracked even before we're the owner, so the speed is right from the start
	if interaction_type == InteractionType.DEFAULT:
		_track_hand_velocity()
	# Only the owner moves the object. Right after grabbing, this waits
	# until the host's reply makes us the owner.
	if not object_reference.is_multiplayer_authority(): return

	match interaction_type:
		InteractionType.DEFAULT:
			_default_interact()

# Runs once when the Player stops interacting with an object
func post_interact() -> void:
	Log.debug("InteractionComponent.post_interact()")
	is_held = false
	match interaction_type:
		InteractionType.DEFAULT:
			_throw()
	# Tell the host our hands are free, so someone else can grab it
	_release.rpc_id(Networking.HOST_ID)

# Every physics frame while held. Averages the last few frames so one jittery
# frame doesn't decide the throw.
func _track_hand_velocity() -> void:
	var hand_position: Vector3 = player_hand.global_position
	var velocity_this_frame: Vector3 = (hand_position - last_hand_position) / get_physics_process_delta_time()
	hand_velocity = hand_velocity.lerp(velocity_this_frame, HAND_SMOOTHING)
	last_hand_position = hand_position

# Letting go sends the object off at the speed and direction the hand was
# moving: whip the mouse and let go to throw it, or let go while still to drop it.
# Heavier objects can't be thrown as fast: 1 kg -> 20 m/s, 4 kg -> 10 m/s, 9 kg -> ~6.7 m/s.
func _throw() -> void:
	Log.debug("InteractionComponent._throw()")
	var rb3d: RigidBody3D = object_reference as RigidBody3D
	if rb3d == null or not rb3d.is_multiplayer_authority(): return
	rb3d.linear_velocity = hand_velocity.limit_length(get_max_throw_speed())

# Lets go and throws the object in a direction at full speed.
# Used by the werewolf's left click (see InteractionController).
func throw_forward(direction: Vector3) -> void:
	Log.debug("InteractionComponent.throw_forward()")
	post_interact()
	var rb3d: RigidBody3D = object_reference as RigidBody3D
	if rb3d == null or not rb3d.is_multiplayer_authority(): return
	rb3d.linear_velocity = direction.normalized() * get_max_throw_speed()

# How fast this object can be thrown. Heavier objects are slower.
# Also used by the ImpactDamageComponent: a throw this fast does its max damage.
func get_max_throw_speed() -> float:
	Log.debug("InteractionComponent.get_max_throw_speed()")
	var rb3d: RigidBody3D = object_reference as RigidBody3D
	var mass: float = rb3d.mass if rb3d else 1.0
	return MAX_THROW_SPEED / sqrt(maxf(mass, 1.0))

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
# two players grabbing at the same time can't both win, and nobody can grab
# an object out of someone else's hands.
#
# The owner stays the last person who grabbed it, even after they let go, so
# the host keeps track of who is holding it right now separately (holder_id).

const NO_HOLDER: int = 0

# Host only - the peer holding this object right now, or NO_HOLDER
var holder_id: int = NO_HOLDER

# Grabbing player -> Host
@rpc("any_peer", "call_local", "reliable")
func _request_ownership() -> void:
	Log.debug("InteractionComponent._request_ownership()")
	if not multiplayer.is_server(): return
	var grabber_id: int = multiplayer.get_remote_sender_id()

	# Someone else is holding it. The grabber is told who owns it, which makes
	# them let go again (see _set_owner()).
	if is_held_by_other(grabber_id):
		_set_owner.rpc_id(grabber_id, object_reference.get_multiplayer_authority())
		return

	holder_id = grabber_id
	_set_owner.rpc(grabber_id)

# Host only - whether someone other than peer_id is holding this right now.
# A holder who died or left doesn't count, so the object can't get stuck.
func is_held_by_other(peer_id: int) -> bool:
	Log.debug("InteractionComponent.is_held_by_other()")
	return holder_id != NO_HOLDER and holder_id != peer_id and RoundManager.instance.is_alive(holder_id)

# Holding player -> Host
@rpc("any_peer", "call_local", "reliable")
func _release() -> void:
	Log.debug("InteractionComponent._release()")
	if not multiplayer.is_server(): return
	if multiplayer.get_remote_sender_id() == holder_id:
		holder_id = NO_HOLDER

# Host -> Everyone
# NOTE - "any_peer" because the default "authority" mode only accepts calls from
#        the current owner, and the host isn't always the owner
@rpc("any_peer", "call_local", "reliable")
func _set_owner(peer_id: int) -> void:
	Log.debug("InteractionComponent._set_owner()")
	if multiplayer.get_remote_sender_id() != Networking.HOST_ID: return

	# Recursive so the MultiplayerSynchronizer child changes owner too
	object_reference.set_multiplayer_authority(peer_id, true)
	_update_freeze()

	# We tried to grab it, but the host gave it to someone else (they were already
	# holding it). Let go, so the InteractionController frees our hands.
	if is_held and peer_id != multiplayer.get_unique_id():
		is_held = false

# Freeze the object for everyone except its owner, so their physics doesn't
# fight the positions coming in from the MultiplayerSynchronizer
func _update_freeze() -> void:
	Log.debug("InteractionComponent._update_freeze()")
	var rb3d: RigidBody3D = object_reference as RigidBody3D
	if rb3d:
		rb3d.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		rb3d.freeze = not object_reference.is_multiplayer_authority()

# Host only - someone joined during the match. Objects keep the owner of whoever
# grabbed them last, so tell the newcomer who that is. Otherwise they'd think
# the host owns it, ignore the real owner's position updates, and see it frozen.
func _on_peer_connected(id: int) -> void:
	Log.debug("InteractionComponent._on_peer_connected()")
	_set_owner.rpc_id(id, object_reference.get_multiplayer_authority())

# Host only - if the owner leaves the game, the host takes the object back
func _on_peer_disconnected(id: int) -> void:
	Log.debug("InteractionComponent._on_peer_disconnected()")
	if object_reference.get_multiplayer_authority() == id:
		_set_owner.rpc(Networking.HOST_ID)
#endregion
