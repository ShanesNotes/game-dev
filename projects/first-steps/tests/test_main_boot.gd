extends SceneTree
# Deterministic boot smoke: instantiate the real main scene, let it run briefly,
# then tear it down explicitly instead of relying on raw --quit-after timing.
# Run:
#   godot --headless --audio-driver Dummy --path projects/first-steps --script res://tests/test_main_boot.gd

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
	for _i: int in 120:
		await process_frame

	expect("main scene instantiated", scene != null and is_instance_valid(scene))
	expect("player exists", scene.has_node("World/Player"))
	expect("effects layer exists", get_first_node_in_group("effects_layer") != null)
	expect("wolves spawned", get_nodes_in_group("wolves").size() == 9)

	_stop_audio_players(scene)
	scene.queue_free()
	for _i: int in 3:
		await process_frame

	if _fails == 0:
		print("PASS — main scene boots and tears down cleanly")
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


func _stop_audio_players(node: Node) -> void:
	if node is AudioStreamPlayer:
		var player: AudioStreamPlayer = node as AudioStreamPlayer
		player.stop()
		player.stream = null
	elif node is AudioStreamPlayer2D:
		var player_2d: AudioStreamPlayer2D = node as AudioStreamPlayer2D
		player_2d.stop()
		player_2d.stream = null
	elif node is AudioStreamPlayer3D:
		var player_3d: AudioStreamPlayer3D = node as AudioStreamPlayer3D
		player_3d.stop()
		player_3d.stream = null
	for child: Node in node.get_children():
		_stop_audio_players(child)


func _install_singleton(singleton_name: StringName, script: GDScript) -> void:
	if Engine.has_singleton(singleton_name):
		return
	var node: Node = script.new()
	node.name = singleton_name
	root.add_child(node)
	Engine.register_singleton(singleton_name, node)
