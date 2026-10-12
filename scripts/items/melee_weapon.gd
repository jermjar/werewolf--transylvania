class_name MeleeWeapon extends Item

# Hits whoever is in front of the camera, within reach. Used by the fists and
# by melee weapons like the bat, each with their own numbers in the inspector.
#
# The attacker's machine decides if a hit lands, since only it knows exactly
# where the player was aiming. HealthComponent.damage() then sends the damage
# to whoever owns the victim's health.

const SWING_DISTANCE: float = 0.4
const SWING_OUT_TIME: float = 0.08
const SWING_BACK_TIME: float = 0.15

@export var damage: int = 10
@export var cooldown: float = 1.0
@export var reach: float = 2.0

@onready var mesh: MeshInstance3D = $Mesh
@onready var raycast: RayCast3D = $RayCast3D
@onready var cooldown_timer: Timer = $CooldownTimer

var mesh_rest_position: Vector3

func _ready() -> void:
	mesh_rest_position = mesh.position
	raycast.target_position = Vector3(0, 0, -reach)

func use() -> void:
	if not cooldown_timer.is_stopped(): return
	cooldown_timer.start(cooldown)

	_play_swing_animation.rpc()

	# The ray is disabled in the scene so it doesn't check every frame. Instead
	# it's updated only when swinging. It starts inside our own body, which
	# rays ignore, so it can't hit ourselves.
	raycast.force_raycast_update()
	var hit_player: Player = raycast.get_collider() as Player
	if hit_player:
		Log.debug("%s.use() -> hit %s for %s" % [name, hit_player.name, damage])
		hit_player.health_component.damage(damage)

# Owner -> Everyone
# Purely visual, so "unreliable" is fine: if a packet is lost, someone
# just misses seeing one swing.
@rpc("call_local", "unreliable")
func _play_swing_animation() -> void:
	var swung_position: Vector3 = mesh_rest_position + Vector3(0, 0, -SWING_DISTANCE)
	var tween: Tween = create_tween()
	tween.tween_property(mesh, "position", swung_position, SWING_OUT_TIME)
	tween.tween_property(mesh, "position", mesh_rest_position, SWING_BACK_TIME)
