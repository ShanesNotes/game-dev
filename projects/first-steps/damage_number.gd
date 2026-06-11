extends Label

func setup(amount, color):
	show_text(str(amount), color)   # numbers route through show_text

func show_text(s, color, size = 18):
	text = s
	modulate = color
	add_theme_font_size_override("font_size", size)
	position.x += randf_range(-6, 6)   # so stacked hits don't overlap exactly
	pivot_offset = Vector2(20, 12)
	scale = Vector2(0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position", position + Vector2(0, -32), 0.7)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
