extends Label

func setup(amount, color):
	show_text(str(amount), color)   # numbers route through show_text

func show_text(s, color, size = 18):
	text = s
	modulate = color
	add_theme_font_size_override("font_size", size)
	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector2(0, -28), 0.6)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)
