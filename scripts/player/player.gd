class_name Player extends CharacterBody3D

@onready var health_label: Label = $HUD/HealthLabel
@onready var crosshair: Label = $HUD/Crosshair
@onready var hotbar: HBoxContainer = $HUD/Hotbar
@onready var health_label_3d: Label3D = $HealthLabel3D
@onready var steam_name_label: Label3D = $SteamName
@onready var camera_controller: CameraController = $CameraController
@onready var camera: Camera3D = $CameraController/Camera3D
@onready var model: Node3D = $Model # At the player's feet, so scaling it keeps the body on the floor
@onready var pose: Node3D = $Model/Pose # Squashed while crouching. Separate from model, which the werewolf scales.
@onready var head: MeshInstance3D = $Model/Pose/HeadMesh
@onready var body: MeshInstance3D = $Model/Pose/BodyMesh
@onready var standing_shape: CollisionShape3D = $StandingShape
@onready var crouching_shape: CollisionShape3D = $CrouchingShape
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var interaction_controller: InteractionController = $InteractionController

# Components
@export var health_component: HealthComponent
# Also handles using items and switching slots
@export var inventory_component: InventoryComponent

# The peer ID of the machine controlling this player. The player node is named after it.
var peer_id: int

# True while a dead player is watching through this player's camera
var is_spectated: bool = false

var current_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var mouse_sensitivity: float = 0.0012
var capture_mouse: bool
var mouse_input: Vector2

var input_dir: Vector2 = Vector2.ZERO

# Movement works like Garry's Mod, with the settings of Trouble in Terrorist Town:
# - velocity carries over between frames
# - friction slows you down on the ground
# - pressing a direction accelerates you towards it, until your speed in that direction reaches the max
# - in the air that max is tiny (air_speed_cap) but the push isn't. That's what makes
#   air strafing work: turning while holding A or D curves your path and can build speed.
#   Chaining that between jumps is bunny hopping.
# Values are written in Source units (1 unit = 1 inch) so they match GMod, then turned into meters.
const SOURCE_UNIT: float = 0.0254 # Meters in one Source unit
var speed: float = 220 * SOURCE_UNIT # Top running speed on the ground, ~5.6 m/s. The werewolf changes this.
var jump_velocity: float = 160 * SOURCE_UNIT # A ~0.5 m jump. Crouch jumping adds 0.8 m.
var gravity: float = 600 * SOURCE_UNIT # Only for players. Props use the project's gravity.
var friction: float = 8.0
var stop_speed: float = 10 * SOURCE_UNIT # Friction treats anything slower as this fast, so you come to a full stop
var ground_acceleration: float = 10.0
var air_acceleration: float = 10.0
var air_speed_cap: float = 30 * SOURCE_UNIT

# Fall damage, using TTT's formula (in Source units):
#   damage = (0.05 * (fall speed - 420)) ^ 1.75 * 2/3, for falls faster than 450
# 450 is a fall of about 4.3 m. 7.6 m does ~31 damage, ~13 m kills.
var safe_fall_speed: float = 450 * SOURCE_UNIT

# Crouching works like in Source games. On the ground your head comes down.
# In the air your feet come up instead (a crouch jump), which lets you reach
# higher ledges. You only stand back up if there's room.
const STANDING_HEIGHT: float = 2.0 # Must match the StandingShape capsule
const CROUCHING_HEIGHT: float = 1.2 # Must match the CrouchingShape capsule
const CROUCH_DIFFERENCE: float = STANDING_HEIGHT - CROUCHING_HEIGHT
const STANDING_CAMERA_HEIGHT: float = 0.5
const CROUCHING_CAMERA_HEIGHT: float = STANDING_CAMERA_HEIGHT - CROUCH_DIFFERENCE
var crouch_speed_multiplier: float = 0.3 # Like GMod. Used instead of changing speed, which the werewolf changes.
var camera_crouch_speed: float = 4.0 # How fast the camera moves down/up when crouching on the ground, in m/s

# Synced to everyone by the MultiplayerSynchronizer, so our hitbox and model
# shrink on their machines too
var is_crouching: bool = false:
	set = set_crouching

func _enter_tree():
	Log.debug("Player._enter_tree()")
	peer_id = name.to_int()
	set_multiplayer_authority(peer_id, true)

func _ready() -> void:
	Log.debug("Player._ready()")
	# Signals
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	_on_health_changed(health_component.current_health, health_component.max_health)
	# The spawn may have set is_crouching before the nodes above were ready
	set_crouching(is_crouching)

	if RoundManager.instance:
		RoundManager.instance.phase_changed.connect(_on_phase_changed)

	steam_name_label.text = Networking.get_display_name(peer_id)

	if is_multiplayer_authority():
		steam_name_label.hide()
		health_label_3d.hide()
		head.hide()
		body.hide()
		health_label.show()
		crosshair.show()
		hotbar.show()

		set_process_unhandled_input(is_multiplayer_authority())
		set_process(is_multiplayer_authority())
		set_physics_process(is_multiplayer_authority())
		
		camera.current = is_multiplayer_authority()
		Input.mouse_mode = current_mouse_mode
	else:
		set_process_unhandled_input(false)
		set_process(false)
		set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	capture_mouse = event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if capture_mouse:
		mouse_input.x += -event.screen_relative.x * mouse_sensitivity
		mouse_input.y += -event.screen_relative.y * mouse_sensitivity
		camera_controller.update_camera_rotation(mouse_input)

func _process(_delta: float) -> void:
	mouse_input = Vector2.ZERO

func _physics_process(delta: float) -> void:
	var on_ground: bool = is_on_floor()

	# Movement keys are read straight from the keyboard, so they'd also fire
	# while typing in the chat. Ignore them until the message is sent.
	# Jumping needs a fresh press each time, like in Source.
	if Input.is_action_just_pressed("jump") and on_ground and not Chat.is_typing:
		velocity.y = jump_velocity
		# Leaving the ground now skips this frame's friction. Jumping again the
		# moment you land is how bunny hopping keeps its speed.
		on_ground = false

	# After the jump, so the jump's first frame falls a little too, as in Source
	if not on_ground:
		velocity.y -= gravity * delta

	if not Chat.is_typing:
		_update_crouch(Input.is_action_pressed("crouch"))

	input_dir = Vector2.ZERO if Chat.is_typing else Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish_direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var wish_speed: float = speed * crouch_speed_multiplier if is_crouching and on_ground else speed

	if on_ground:
		_apply_friction(delta)
		_accelerate(wish_direction, wish_speed, wish_speed, ground_acceleration, delta)
	else:
		_accelerate(wish_direction, wish_speed, air_speed_cap, air_acceleration, delta)

	var was_on_floor: bool = is_on_floor()
	var fall_speed: float = -velocity.y
	move_and_slide()
	if not was_on_floor and is_on_floor():
		_take_fall_damage(fall_speed)

	# Slide the camera towards the height for our stance
	var camera_height: float = CROUCHING_CAMERA_HEIGHT if is_crouching else STANDING_CAMERA_HEIGHT
	camera_controller.position.y = move_toward(camera_controller.position.y, camera_height, camera_crouch_speed * delta)

# Every physics frame on the ground. Slows us down, by at least stop_speed's
# worth of friction so slow movement still comes to a stop.
func _apply_friction(delta: float) -> void:
	var current_speed: float = Vector2(velocity.x, velocity.z).length()
	if current_speed < 0.001: return
	var control: float = maxf(current_speed, stop_speed)
	var new_speed: float = maxf(current_speed - control * friction * delta, 0.0)
	velocity.x *= new_speed / current_speed
	velocity.z *= new_speed / current_speed

# Every physics frame. Pushes us towards wish_direction, but only until our speed
# in that direction reaches speed_cap. Other directions are left alone, which
# is why turning in the air lets you go faster (see the comment at the top).
func _accelerate(wish_direction: Vector3, wish_speed: float, speed_cap: float, acceleration: float, delta: float) -> void:
	var speed_in_direction: float = velocity.dot(wish_direction)
	var missing_speed: float = minf(wish_speed, speed_cap) - speed_in_direction
	if missing_speed <= 0.0: return
	var added_speed: float = minf(acceleration * wish_speed * delta, missing_speed)
	velocity += wish_direction * added_speed

# Called when we land. Damages us if we fell fast enough (see safe_fall_speed).
func _take_fall_damage(fall_speed: float) -> void:
	Log.debug("Player._take_fall_damage()")
	if fall_speed <= safe_fall_speed: return
	var fall_speed_units: float = fall_speed / SOURCE_UNIT
	var damage: int = floori(pow(0.05 * (fall_speed_units - 420.0), 1.75) * 2.0 / 3.0)
	if damage <= 0: return
	Log.info("%s fell at %.1f m/s for %d damage" % [name, fall_speed, damage])
	health_component.damage(damage)

# Every physics frame. Crouches or stands up to match the crouch key.
func _update_crouch(wants_to_crouch: bool) -> void:
	if wants_to_crouch == is_crouching: return
	var on_floor: bool = is_on_floor()

	# Standing up needs room for the taller body: above us on the ground,
	# below us in the air (where the feet come back down). Otherwise stay crouched.
	if not wants_to_crouch:
		var direction: Vector3 = Vector3.UP if on_floor else Vector3.DOWN
		if test_move(global_transform, direction * CROUCH_DIFFERENCE): return

	# In the air the body moves instead of the head: up when crouching (the
	# feet pull up), down when standing. The camera moves the other way by the
	# same amount, so the view stays exactly where it was.
	if not on_floor:
		var shift: float = CROUCH_DIFFERENCE if wants_to_crouch else -CROUCH_DIFFERENCE
		global_position.y += shift
		camera_controller.position.y = clampf(camera_controller.position.y - shift, CROUCHING_CAMERA_HEIGHT, STANDING_CAMERA_HEIGHT)

	is_crouching = wants_to_crouch

# Runs on every machine: on ours from _update_crouch(), on everyone else's
# when the MultiplayerSynchronizer delivers the new value
func set_crouching(crouching: bool) -> void:
	Log.debug("Player.set_crouching()")
	is_crouching = crouching
	if not is_node_ready(): return # _ready() calls this again
	standing_shape.disabled = crouching
	crouching_shape.disabled = not crouching
	pose.scale.y = CROUCHING_HEIGHT / STANDING_HEIGHT if crouching else 1.0
	# Our own camera slides in _physics_process(). Other players' cameras
	# (seen by spectators) just jump to the new height.
	if not is_multiplayer_authority():
		camera_controller.position.y = CROUCHING_CAMERA_HEIGHT if crouching else STANDING_CAMERA_HEIGHT

func update_rotation(rotation_input) -> void:
	global_transform.basis = Basis.from_euler(rotation_input)

func _on_health_changed(current_health: int, _max_health: int) -> void:
	Log.debug("Player._on_health_changed()")
	if is_multiplayer_authority():
		health_label.text = "HP: %s" % [ health_component.current_health ]
	health_label_3d.text = "HP: %s" % [ health_component.current_health ]

func _on_phase_changed(_phase: RoundManager.Phase) -> void:
	Log.debug("Player._on_phase_changed()")
	if not is_inside_tree(): return # Removed this frame (died or left), about to be deleted
	_update_name_tag()

# Name tags are hidden at night so nobody can tell who the werewolf is.
# Our own name tag, and the one of a player being spectated, are always hidden.
func _update_name_tag() -> void:
	Log.debug("Player._update_name_tag()")
	var is_night: bool = RoundManager.instance and RoundManager.instance.is_night()
	steam_name_label.visible = not is_multiplayer_authority() and not is_spectated and not is_night

# Called by the Spectator when a dead player starts or stops watching through
# this player's eyes. Hides everything that would block or clutter the view.
func set_spectated(spectated: bool) -> void:
	Log.debug("Player.set_spectated()")
	is_spectated = spectated
	head.visible = not spectated
	body.visible = not spectated
	health_label_3d.visible = not spectated
	camera.current = spectated
	_update_name_tag()

func _on_died():
	Log.debug("Player._on_died()")
	if is_multiplayer_authority():
		die.rpc()

@rpc("call_local", "reliable")
func die():
	Log.debug("Player.die()")
	if is_multiplayer_authority():
		var level_camera: Camera3D = get_tree().get_first_node_in_group("level_camera")
		level_camera.current = true

		# Stop sending our position. The host is about to remove this player, and
		# an update still on its way would arrive for a player that's already
		# gone (an error: Node not found ".../MultiplayerSynchronizer").
		# This runs after die() was sent, so updates sent before it arrive first.
		# The host doesn't need it: it removes its own player with no delay.
		if not multiplayer.is_server():
			synchronizer.public_visibility = false
	# Players are spawned by the host's PlayerSpawner, so only the host removes
	# them. The spawner then removes the player for everyone else.
	if multiplayer.is_server():
		inventory_component.drop_all()
		queue_free()
