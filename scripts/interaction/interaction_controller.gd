extends Node

# Items can be picked up with a tap of interact, or grabbed like any other
# prop by holding it. Holding longer than this counts as a grab.
const HOLD_TO_GRAB_TIME: float = 0.25

@onready var interaction_hand: Marker3D = %InteractionHand
@onready var interaction_raycast: RayCast3D = %InteractionRayCast3D
@onready var inventory: InventoryComponent = $"../InventoryComponent"

var current_object: Object
var interaction_component: InteractionComponent
var hold_time: float = 0.0 # How long interact has been held while not grabbing

func _ready() -> void:
	Log.debug("InteractionController._ready()")
	# Every player on our screen has one of these, but only the one for the
	# player we control should react to our input
	set_physics_process(is_multiplayer_authority())

func _physics_process(delta: float) -> void:
	# Typing an "e" in the chat shouldn't pick things up
	var interact_held: bool = Input.is_action_pressed("interact") and not Chat.is_typing

	# If we are interacting with something
	if current_object:
		# Someone else picked up the item we were holding
		if not is_instance_valid(current_object):
			current_object = null
		elif interact_held:
			interaction_component.interact()
		else:
			interaction_component.post_interact()
			current_object = null
		return

	# If we are looking to interact with something
	var potential_object: Object = interaction_raycast.get_collider()

	if not interact_held:
		# A quick tap on an item picks it up
		if hold_time > 0.0 and hold_time < HOLD_TO_GRAB_TIME and potential_object is ItemPickup:
			inventory.request_pickup(potential_object)
		hold_time = 0.0
		return

	hold_time += delta
	# Wait to see if this is a tap before grabbing an item
	if potential_object is ItemPickup and hold_time < HOLD_TO_GRAB_TIME: return

	if potential_object is Node:
		var component: InteractionComponent = potential_object.get_node_or_null("InteractionComponent")
		if component and component.can_interact:
			current_object = potential_object
			interaction_component = component
			interaction_component.pre_interact(interaction_hand)
