extends SceneTree
# Verifies the shared CombatFX autoload builds the same visible effect nodes that
# player.gd, wolf.gd, and sword.gd now request instead of constructing locally.
# Run:
#   godot --headless --path projects/first-steps --script res://tests/test_combat_fx.gd

const COMBAT_FX_SCRIPT = preload("res://combat_fx.gd")

var _fails := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	scene.name = "CombatFxTestScene"
	root.add_child(scene)
	current_scene = scene

	var effects_layer := Node2D.new()
	effects_layer.name = "EffectsLayer"
	scene.add_child(effects_layer)
	effects_layer.add_to_group(&"effects_layer")

	var fx = COMBAT_FX_SCRIPT.new()
	fx.name = "CombatFX"
	root.add_child(fx)

	var actor := Node2D.new()
	actor.name = "Actor"
	scene.add_child(actor)
	actor.global_position = Vector2(64, 80)

	var miss = fx.text_over(actor, "Miss", Color.GRAY)
	expect_valid("text_over returns label", miss)
	expect("text_over parent is effects layer", miss.get_parent() == effects_layer)
	expect_equal("text_over text", miss.text, "Miss")
	expect_equal("text_over size", miss.get_theme_font_size("font_size"), 18)
	expect("text_over starts above actor", miss.global_position.y < actor.global_position.y)

	var crit = fx.damage_number(actor, 8, Color.YELLOW, 28)
	expect_valid("damage_number returns label", crit)
	expect_equal("damage_number text", crit.text, "8")
	expect_equal("damage_number size", crit.get_theme_font_size("font_size"), 28)

	var sparks = fx.sparks(Vector2(10, 20), Color(1.0, 0.85, 0.3), 4)
	expect_valid("sparks returns particles", sparks)
	expect("sparks is CPUParticles2D", sparks is CPUParticles2D)
	expect("sparks parent is effects layer", sparks.get_parent() == effects_layer)
	expect_equal("sparks amount", sparks.amount, 4)
	expect("sparks one-shot", sparks.one_shot)
	expect("sparks emitting", sparks.emitting)
	expect_vec("sparks offset", sparks.global_position, Vector2(10, 10))

	var blood = fx.blood(Vector2(30, 40))
	expect_valid("blood returns particles", blood)
	expect("blood is CPUParticles2D", blood is CPUParticles2D)
	expect_equal("blood amount", blood.amount, 6)
	expect_vec("blood offset", blood.global_position, Vector2(30, 32))

	if _fails == 0:
		print("PASS — CombatFX builds shared text and particle effects")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _fails)
		quit(1)


func expect(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		printerr("  FAIL %s" % label)


func expect_valid(label: String, value) -> void:
	expect(label, value != null and is_instance_valid(value))


func expect_equal(label: String, got, want) -> void:
	if got == want:
		print("  ok   %s = %s" % [label, got])
	else:
		_fails += 1
		printerr("  FAIL %s got %s, want %s" % [label, got, want])


func expect_vec(label: String, got: Vector2, want: Vector2) -> void:
	if got.is_equal_approx(want):
		print("  ok   %s = %s" % [label, got])
	else:
		_fails += 1
		printerr("  FAIL %s got %s, want %s" % [label, got, want])
