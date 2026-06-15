extends Area2D

## The sword pickup: rests on its pedestal with a gentle bob and a golden
## glint until the player walks in — then chime, burst, banner, equip.

const GameContracts = preload("res://game_contracts.gd")

@onready var sprite: Sprite2D = $Sprite2D
@onready var glint: CPUParticles2D = $Glint
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	var bob_tween: Tween = create_tween().set_loops()
	bob_tween.tween_property(sprite, "position:y", -17.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tween.tween_property(sprite, "position:y", -12.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		Sfx.play("pickup")
		GameContracts.equip_sword(body)
		GameContracts.announce(body, "Rusty Sword equipped!")
		CombatFX.sparks(global_position + Vector2(0, -14), Color(1.0, 0.85, 0.4), 14)
		sprite.visible = false
		glint.emitting = false
		collision_shape.set_deferred("disabled", true)
		get_tree().create_timer(1.5).timeout.connect(queue_free, CONNECT_ONE_SHOT)   # outlast the glint's 1.4s particles
