extends Area2D

func _on_body_entered(body):
	if body.name == "Player":
		print("- The blade is thin -")
		body.equip_sword()      # reveal the sword in hand
		queue_free()
