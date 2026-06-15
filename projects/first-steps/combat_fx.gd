extends Node

## Shared combat feedback bus (autoload "CombatFX").
## Player, wolf, and pickups ask for effects; this node owns how they are built.

const DAMAGE_NUMBER = preload("res://damage_number.tscn")
const SPARK = preload("res://assets/spark.png")
const BLOOD = preload("res://assets/soft_dot.png")


func text_over(target, words: String, color: Color, font_size: int = 18):
	if not is_instance_valid(target):
		return null
	return text_at(target.global_position + Vector2(-8, -30), words, color, font_size)


func damage_number(target, amount: int, color: Color, font_size: int = 18):
	return text_over(target, str(amount), color, font_size)


func text_at(at: Vector2, words: String, color: Color, font_size: int = 18):
	var n = DAMAGE_NUMBER.instantiate()
	_world_root().add_child(n)
	n.global_position = at
	n.show_text(words, color, font_size)
	return n


func sparks(at: Vector2, color: Color, count: int):
	return _particle_burst(SPARK, at + Vector2(0, -10), color, count, 0.35, 40.0, 90.0, Vector2(0, 160), 0.5, 1.0)


func blood(at: Vector2):
	return _particle_burst(BLOOD, at + Vector2(0, -8), Color(0.72, 0.13, 0.1), 6, 0.4, 25.0, 60.0, Vector2(0, 220), 0.3, 0.6)


func _particle_burst(texture, at: Vector2, color: Color, count: int, lifetime: float, velocity_min: float, velocity_max: float, gravity: Vector2, scale_min: float, scale_max: float):
	var p = CPUParticles2D.new()
	p.texture = texture
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = lifetime
	p.initial_velocity_min = velocity_min
	p.initial_velocity_max = velocity_max
	p.gravity = gravity
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.color = color
	p.z_index = 30
	_world_root().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


func _world_root():
	var scene = get_tree().current_scene
	if scene:
		return scene
	return get_tree().root
