class_name ImpactDamageComponent extends Node

# Makes a physics prop hurt whatever it hits after being thrown.
# A full-strength throw does max_damage, slower throws do less, and anything
# slower than min_speed does nothing:
#   damage = max_damage * (speed - min_speed) / (full throw speed - min_speed)
# Full throw speed depends on the prop's weight (see InteractionComponent.get_max_throw_speed()).
# Speeds are in m/s. Item pickups set max_damage from their ItemData.
#
# Only the prop's owner checks for hits. The owner runs the prop's physics,
# while everyone else's copy is frozen and just follows the synced position.
# The owner is whoever grabbed it last, which is why a prop never hurts its thrower.
# The damage then reaches the victim the usual way (HealthComponent.damage()).

@export var rigid_body: RigidBody3D
@export var interaction_component: InteractionComponent # Held props don't hurt anyone, only thrown ones
@export var min_speed: float = 6.0 # Slower than this does nothing, so dropping or nudging a prop is harmless
@export var max_damage: int = 50 # Done by a full-strength throw

# How fast the prop was going when it hit something. Hits slow the prop down,
# and for small, fast props (like the flashlight) the physics engine slows them
# one frame before it reports the hit, so this is the faster of the last two frames.
var speed: float = 0.0
var previous_speed: float = 0.0

func _ready() -> void:
	Log.debug("ImpactDamageComponent._ready()")
	# The prop only reports what it touches with these on
	rigid_body.contact_monitor = true
	rigid_body.max_contacts_reported = 4
	# Fast props could otherwise pass straight through a player between two physics frames
	rigid_body.continuous_cd = true
	rigid_body.body_entered.connect(_on_body_entered)

# Runs before the physics step, so these are speeds from before any hit
func _physics_process(_delta: float) -> void:
	var current_speed: float = rigid_body.linear_velocity.length()
	speed = maxf(current_speed, previous_speed)
	previous_speed = current_speed

func _on_body_entered(body: Node) -> void:
	Log.debug("ImpactDamageComponent._on_body_entered()")
	if not rigid_body.is_multiplayer_authority(): return
	if interaction_component and interaction_component.is_held: return
	if speed < min_speed: return

	var health: HealthComponent = HealthComponent.find_on(body)
	if health == null: return
	# The thrower owns the prop, so this skips their own player
	if body is Player and body.peer_id == rigid_body.get_multiplayer_authority(): return

	# 0 at min_speed, 1 at full throw speed. Faster than that (e.g. a long fall) still counts as 1.
	# Very heavy props can't be thrown faster than min_speed, so keep a little range for them.
	var full_speed: float = maxf(interaction_component.get_max_throw_speed(), min_speed + 1.0)
	var strength: float = clampf((speed - min_speed) / (full_speed - min_speed), 0.0, 1.0)
	var damage: int = roundi(strength * max_damage)
	if damage <= 0: return
	Log.info("%s hit %s at %.1f m/s for %d damage" % [rigid_body.name, body.name, speed, damage])
	health.damage(damage)
