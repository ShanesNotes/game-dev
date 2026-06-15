extends Node2D
# Scene-level lifecycle cleanup. The ambience and generated campfire crackle are
# looping audio nodes; stop them before headless smoke quits so shutdown logs stay
# clean and leak-free.


func _ready() -> void:
	tree_exiting.connect(_stop_all_audio)


func _stop_all_audio() -> void:
	_stop_audio_players(self)


func _stop_audio_players(node: Node) -> void:
	if node is AudioStreamPlayer:
		(node as AudioStreamPlayer).stop()
	elif node is AudioStreamPlayer2D:
		(node as AudioStreamPlayer2D).stop()
	elif node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).stop()
	for child: Node in node.get_children():
		_stop_audio_players(child)
