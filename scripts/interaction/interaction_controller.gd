class_name InteractionController extends Node

# Pressing interact on a prop grabs it, and it stays held until interact is
# pressed again. Items can also be tapped to put them in the inventory, or
# held for a moment to grab them like any other prop.
# While holding, left click throws the prop, but only when can_throw is on
# (the werewolf at night). Otherwise the hands are just full (see InventoryComponent).

# Holding interact on an item longer than this grabs it instead of picking it up
const HOLD_TO_GRAB_TIME: float = 0.25

@onready var interaction_hand: Marker3D = %InteractionHand
@onready var interaction_raycast: RayCast3D = %InteractionRayCast3D
@onready var inventory: InventoryComponent = $"../InventoryComponent"
@onready var camera: Camera3D = $"../CameraController/Camera3D"

var current_object: Object
var interaction_component: InteractionComponent
# How long interact has been held, for a press that started while our hands
# were empty. -1 when there's no such press.
var press_time: float = -1.0
# Set by the WerewolfComponent while transformed
var can_throw: bool = false

func _ready() -> void:
	Log.debug("InteractionController._ready()")
	# Every player on our screen has one of these, but only the one for the
	# player we control should react to our input
	set_physics_process(is_multiplayer_authority())

func is_holding() -> bool:
	Log.debug("InteractionController.is_holding()")
	return current_object != null

func _physics_process(delta: float) -> void:
	# Typing in the chat shouldn't grab, drop or throw anything
	var interact_pressed: bool = Input.is_action_just_pressed("interact") and not Chat.is_typing
	var interact_held: bool = Input.is_action_pressed("interact") and not Chat.is_typing
	var throw_pressed: bool = Input.is_action_just_pressed("use_item") and not Chat.is_typing

	# Holding something: it stays held until interact is pressed again, or it's thrown
	if current_object:
		if not is_instance_valid(current_object):
			# Someone else picked up the item we were holding
			current_object = null
		elif not interaction_component.is_held:
			# Our grab was refused, someone else is already holding it
			current_object = null
		elif interact_pressed:
			# Let go. It keeps the speed of our swing, so whipping the mouse still flings it.
			interaction_component.post_interact()
			current_object = null
		elif throw_pressed and can_throw:
			interaction_component.throw_forward(-camera.global_basis.z)
			current_object = null
		else:
			interaction_component.interact()
		return

	# If we are looking to interact with something
	var potential_object: Object = interaction_raycast.get_collider()

	# Only a fresh press can grab or pick up. Otherwise the press that just let
	# go of something would grab it again on the next frame, since it's still held down.
	if interact_pressed:
		press_time = 0.0
	if press_time < 0.0: return

	if not interact_held:
		# A quick tap on an item picks it up
		if press_time < HOLD_TO_GRAB_TIME and potential_object is ItemPickup:
			inventory.request_pickup(potential_object)
		press_time = -1.0
		return

	press_time += delta
	# Wait to see if this is a tap before grabbing an item
	if potential_object is ItemPickup and press_time < HOLD_TO_GRAB_TIME: return

	if potential_object is Node:
		var component: InteractionComponent = potential_object.get_node_or_null("InteractionComponent")
		if component and component.can_interact:
			current_object = potential_object
			interaction_component = component
			interaction_component.pre_interact(interaction_hand)
			press_time = -1.0
