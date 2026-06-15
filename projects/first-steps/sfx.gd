extends Node

## Tiny SFX bus (autoload "Sfx"). One-shot players that free themselves;
## slight pitch jitter keeps repeated sounds from feeling stamped.

const STREAMS = {
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

func play(key: String, volume_db: float = 0.0, pitch_jitter: float = 0.06):
	var p := AudioStreamPlayer.new()
	p.stream = STREAMS[key]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

# Positional one-shot (falls off with distance from the camera/player).
func play_at(key: String, pos: Vector2, volume_db: float = 0.0):
	var p := AudioStreamPlayer2D.new()
	p.stream = STREAMS[key]
	p.volume_db = volume_db
	p.max_distance = 420.0
	p.pitch_scale = 1.0 + randf_range(-0.06, 0.06)
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
