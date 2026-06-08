extends Label

func setup(amount, color):
	text = str(amount)
	modulate = color
	add_theme_font_size_override("font_size", 18)

	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector2(0, -28), 0.6)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)
