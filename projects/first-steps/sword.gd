extends Area2D

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("- The blade is thin -")
		body.equip_sword()      # reveal the sword in hand
		queue_free()
