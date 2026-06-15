extends Node

## Tiny SFX bus (autoload "Sfx"). One-shot players that free themselves;
## slight pitch jitter keeps repeated sounds from feeling stamped.

const STREAMS: Dictionary[String, AudioStream] = {
	"swing": preload("res://assets/sounds/swing_whoosh.wav"),
	"miss": preload("res://assets/sounds/swing_miss.wav"),
	"hit": preload("res://assets/sounds/hit_flesh.wav"),
	"crit": preload("res://assets/sounds/hit_crit.wav"),
	"hurt": preload("res://assets/sounds/hurt_player.wav"),
	"growl": preload("res://assets/sounds/wolf_growl.wav"),
	"bite": preload("res://assets/sounds/wolf_bite.wav"),
	"yelp": preload("res://assets/sounds/wolf_yelp.wav"),
	"pickup": preload("res://assets/sounds/pickup_chime.wav"),
	"ping": preload("res://assets/sounds/target_ping.wav"),
	"death": preload("res://assets/sounds/death_sting.wav"),
}


func play(key: String, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if not STREAMS.has(key):
		push_warning("Unknown SFX key: %s" % key)
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = STREAMS[key]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


# Positional one-shot (falls off with distance from the camera/player).
func play_at(key: String, pos: Vector2, volume_db: float = 0.0) -> void:
	if not STREAMS.has(key):
		push_warning("Unknown SFX key: %s" % key)
		return
	var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	player.stream = STREAMS[key]
	player.volume_db = volume_db
	player.max_distance = 420.0
	player.pitch_scale = 1.0 + randf_range(-0.06, 0.06)
	get_tree().current_scene.add_child(player)
	player.global_position = pos
	player.finished.connect(player.queue_free)
	player.play()
