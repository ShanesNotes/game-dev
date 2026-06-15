extends SceneTree
# Locks the procedural forest's seed-level invariants without requiring a window.
# Run:
#   godot --headless --audio-driver Dummy --path projects/first-steps --script res://tests/test_forest_generator.gd

const SFX_SCRIPT: GDScript = preload("res://sfx.gd")
const COMBAT_FX_SCRIPT: GDScript = preload("res://combat_fx.gd")

var _fails: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_install_singleton("Sfx", SFX_SCRIPT)
	_install_singleton("CombatFX", COMBAT_FX_SCRIPT)
	var main_scene: PackedScene = load("res://main.tscn")
	var scene: Node = main_scene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame

	var ground: TileMapLayer = scene.get_node("Ground") as TileMapLayer
	var road: TileMapLayer = scene.get_node("Road") as TileMapLayer
	var world: Node2D = scene.get_node("World") as Node2D
	var player: Node2D = world.get_node("Player") as Node2D
	var sword: Node2D = world.get_node("Sword") as Node2D

	expect_equal("seed", int(ground.get("map_seed")), 1337)
	expect_equal("map width", int(ground.get("map_width")), 64)
	expect_equal("map height", int(ground.get("map_height")), 48)
	expect_equal("ground cells", ground.get_used_cells().size(), 3072)
	expect_equal("road cells", road.get_used_cells().size(), 219)
	expect_equal("world children", world.get_child_count(), 431)
	expect_equal("wolves", get_nodes_in_group("wolves").size(), 9)
	expect_vec("player camp position", player.global_position, Vector2(1072, 1328))
	expect_vec("sword pedestal position", sword.global_position, Vector2(1104, 272))
	expect("world y-sorts actors and props", world.y_sort_enabled)

	if _fails == 0:
		print("PASS — forest seed 1337 generates the expected world invariants")
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


func expect_equal(label: String, got: Variant, want: Variant) -> void:
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


func _install_singleton(singleton_name: StringName, script: GDScript) -> void:
	if Engine.has_singleton(singleton_name):
		return
	var node: Node = script.new()
	node.name = singleton_name
	root.add_child(node)
	Engine.register_singleton(singleton_name, node)
