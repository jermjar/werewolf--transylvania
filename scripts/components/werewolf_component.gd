class_name WerewolfComponent extends Node

# Turns its player into the werewolf at night, and back at day.
#
# Every machine already knows who the werewolf is and whether it's night
# (from the RoundManager), so each machine changes its own copy of the player
# at the same moment. No extra network messages are needed. Health is the one
# exception: the player's own machine converts it and shares it, the same way
# damage works (see HealthComponent.set_max_health()).

const SPEED_MULTIPLIER: float = 1.5
const MODEL_SCALE: float = 1.2
const MAX_HEALTH: int = 200
const COLOR: Color = Color(0.2, 0.16, 0.13)

# Held instead of the inventory while transformed
@export var claws: Item

@onready var player: Player = get_parent()

var is_transformed: bool = false

var _human_speed: float
var _human_max_health: int
var _material: StandardMaterial3D = StandardMaterial3D.new()

func _ready() -> void:
	_human_speed = player.speed
	_human_max_health = player.health_component.max_health
	_material.albedo_color = COLOR

	if RoundManager.instance:
		RoundManager.instance.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: RoundManager.Phase) -> void:
	if not is_inside_tree(): return # Our player was removed this frame (died or left), about to be deleted
	var is_werewolf: bool = RoundManager.instance.werewolf_id == player.name.to_int()
	var should_transform: bool = is_werewolf and phase == RoundManager.Phase.NIGHT
	if should_transform != is_transformed:
		_set_transformed(should_transform)

func _set_transformed(transformed: bool) -> void:
	is_transformed = transformed
	Log.info("%s %s" % [player.name, "turned into the werewolf" if transformed else "turned back into a human"])

	player.speed = _human_speed * SPEED_MULTIPLIER if transformed else _human_speed
	player.model.scale = Vector3.ONE * (MODEL_SCALE if transformed else 1.0)
	player.body.material_override = _material if transformed else null
	player.head.material_override = _material if transformed else null
	player.inventory_component.override_item = claws if transformed else null
	player.health_component.set_max_health(MAX_HEALTH if transformed else _human_max_health)
