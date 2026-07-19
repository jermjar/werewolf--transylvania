extends Node

const SPEED: float = 5.0

enum InteractionType {
	DEFAULT
}

@export var object_reference: Node3D
@export var interaction_type: InteractionType = InteractionType.DEFAULT

var can_interact: bool = true
var is_interacting: bool = false

var player_hand: Marker3D

func _ready() -> void:
	pass

func _input(_event: InputEvent) -> void:
	pass

# Runs once when the Player first clicks on an object
func pre_interact(hand: Marker3D) -> void:
	is_interacting = true
	
	match interaction_type:
		InteractionType.DEFAULT:
			player_hand = hand

# Runs every frame when the Player is interacting with the object
func interact() -> void:
	if not can_interact: return
	
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
