extends Area2D

func _on_body_entered(body):
	if body.name == "Player":
		print("- The blade is thin -")
		queue_free()
