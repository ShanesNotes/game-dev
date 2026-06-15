extends Node2D

const EFFECTS_LAYER_GROUP: StringName = &"effects_layer"

@onready var world: Node2D = $World

# Scene-level lifecycle cleanup. The ambience and generated campfire crackle are
# looping audio nodes; stop them before headless smoke quits so shutdown logs stay
# clean and leak-free.


func _ready() -> void:
	world.add_to_group(EFFECTS_LAYER_GROUP)
	tree_exiting.connect(_stop_all_audio)
	if DisplayServer.get_name() == "headless":
		_stop_all_audio.call_deferred()


func _exit_tree() -> void:
	_stop_all_audio()


func _stop_all_audio() -> void:
	_stop_audio_players(self)


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
