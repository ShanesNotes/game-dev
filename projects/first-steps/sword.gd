extends Area2D

## The sword pickup: rests on its pedestal with a gentle bob and a golden
## glint until the player walks in — then chime, burst, banner, equip.

@onready var sprite = $Sprite2D

func _ready():
	var t = create_tween().set_loops()
	t.tween_property(sprite, "position:y", -17.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(sprite, "position:y", -12.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body):
	if body.is_in_group("player"):
		Sfx.play("pickup")
		body.equip_sword()
		body.hud.show_banner("Rusty Sword equipped!")
		body.spawn_sparks(global_position + Vector2(0, -14), Color(1.0, 0.85, 0.4), 14)
		sprite.visible = false
		$Glint.emitting = false
		$CollisionShape2D.set_deferred("disabled", true)
		get_tree().create_timer(1.5).timeout.connect(queue_free)   # outlast the glint's 1.4s particles
