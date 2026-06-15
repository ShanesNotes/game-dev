extends Node

## Shared combat feedback bus (autoload "CombatFX").
## Player, wolf, and pickups ask for effects; this node owns how they are built.

const DAMAGE_NUMBER: PackedScene = preload("res://damage_number.tscn")
const SPARK: Texture2D = preload("res://assets/spark.png")
const BLOOD: Texture2D = preload("res://assets/soft_dot.png")


func text_over(target: Node2D, words: String, color: Color, font_size: int = 18) -> Label:
	if not is_instance_valid(target):
		return null
	return text_at(target.global_position + Vector2(-8, -30), words, color, font_size)


func damage_number(target: Node2D, amount: int, color: Color, font_size: int = 18) -> Label:
	return text_over(target, str(amount), color, font_size)


func text_at(at: Vector2, words: String, color: Color, font_size: int = 18) -> Label:
	var number: Label = DAMAGE_NUMBER.instantiate() as Label
	if number == null:
		push_error("damage_number.tscn must instantiate a Label")
		return null
	_world_root().add_child(number)
	number.global_position = at
	number.show_text(words, color, font_size)
	return number


func sparks(at: Vector2, color: Color, count: int) -> CPUParticles2D:
	return _particle_burst(SPARK, at + Vector2(0, -10), color, count, 0.35, 40.0, 90.0, Vector2(0, 160), 0.5, 1.0)


func blood(at: Vector2) -> CPUParticles2D:
	return _particle_burst(BLOOD, at + Vector2(0, -8), Color(0.72, 0.13, 0.1), 6, 0.4, 25.0, 60.0, Vector2(0, 220), 0.3, 0.6)


func _particle_burst(texture: Texture2D, at: Vector2, color: Color, count: int, lifetime: float, velocity_min: float, velocity_max: float, gravity: Vector2, scale_min: float, scale_max: float) -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.texture = texture
	particles.amount = count
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = lifetime
	particles.initial_velocity_min = velocity_min
	particles.initial_velocity_max = velocity_max
	particles.gravity = gravity
	particles.scale_amount_min = scale_min
	particles.scale_amount_max = scale_max
	particles.color = color
	particles.z_index = 30
	_world_root().add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles


func _world_root() -> Node:
	var scene: Node = get_tree().current_scene
	if scene != null:
		return scene
	return get_tree().root
