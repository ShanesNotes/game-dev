extends TileMapLayer

## Procedural Elwynn-style forest generator.
## Runs once at scene load: paints the ground with the 4-tile atlas
## (0 = grass, 1 = dirt, 2 = stone, 3 = grass variant), scatters trees,
## spawns extra wolves off the road, then places the player at the south
## end of the road and the pickup sword up north as the first reward.

@export var map_width: int = 56
@export var map_height: int = 40
@export var map_seed: int = 1337   # same seed = the exact same forest
@export var tree_count: int = 28
@export var extra_wolves: int = 5

@onready var player = get_parent().get_node("Player")
@onready var pickup_sword = get_parent().get_node_or_null("Sword")   # the Area2D pickup, if not yet taken

const TREE = preload("res://assets/tree.png")
const WOLF_SCENE = preload("res://wolf.tscn")

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()

func _ready() -> void:
	clear()   # drop any baked tiles — this script owns the map
	_rng.seed = map_seed
	_noise.seed = map_seed
	_noise.frequency = 0.08
	_noise.fractal_octaves = 3
	_paint_ground()
	var trees := _plant_trees()
	var wolves := _spawn_wolves()
	_place_story_positions()
	print("Forest generated: %dx%d cells, seed %d, %d trees, %d extra wolves"
			% [map_width, map_height, map_seed, trees, wolves])

# The road winds north→south: a sine sway plus noise jitter. ONE function,
# used by every placement rule, so "near the road" always means the same thing.
func path_x_at(y: int) -> int:
	var wind := sin(y * 0.18) * 3.5 + _noise.get_noise_2d(0, y) * 2.5
	return int(map_width * 0.48 + wind)

# Tile cell → world position (cell centre), respecting this layer's transform.
func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell))

func _player_start_cell() -> Vector2i:
	var start_y := map_height - 6
	return Vector2i(path_x_at(start_y) - 2, start_y)   # a southern clearing beside the road

func _paint_ground() -> void:
	for y in range(map_height):
		var path_x := path_x_at(y)
		for x in range(map_width):
			var n := _noise.get_noise_2d(x, y)
			var dist_to_path := absi(x - path_x)
			var tile := 0   # lush grass by default
			if dist_to_path < 2:
				tile = 2 if (x + y) % 3 == 0 else 1   # worn road: stone flecks in dirt
			elif dist_to_path < 3 and _rng.randf() < 0.6:
				tile = 1   # dirt shoulder
			if dist_to_path > 4 and n > 0.35:
				tile = 3   # undergrowth pockets, deeper forest
			if dist_to_path > 6 and absf(n) < 0.12:
				tile = 2   # small stone clearings off the road
			set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))

func _plant_trees() -> int:
	var placed := 0
	var attempts := 0
	while placed < tree_count and attempts < 200:
		attempts += 1
		var cell := _random_cell()
		if not _is_grass(cell):
			continue   # grass only — keep the road and clearings open
		if absi(cell.x - path_x_at(cell.y)) < 3 and _rng.randf() < 0.7:
			continue   # mostly keep the road's edges clear
		var t := Sprite2D.new()
		t.texture = TREE
		t.position = map_to_local(cell) + Vector2(0, 6)   # nudge so the trunk sits on the ground
		t.scale = Vector2(_rng.randf_range(0.85, 1.25), _rng.randf_range(0.85, 1.25))
		t.rotation_degrees = _rng.randf_range(-12, 12)
		var v := _rng.randf_range(0.92, 1.08)
		t.modulate = Color(0.95 * v, 1.05 * v, 0.88 * v)   # subtle per-tree colour variety
		t.z_index = -1 if _rng.randf() < 0.3 else 0   # a few behind the actors, for depth
		add_child(t)
		placed += 1
	return placed

func _spawn_wolves() -> int:
	var start := _player_start_cell()
	var spawned := 0
	var attempts := 0
	while spawned < extra_wolves and attempts < 200:
		attempts += 1
		var cell := _random_cell()
		if not _is_grass(cell):
			continue
		if absi(cell.x - path_x_at(cell.y)) <= 4:
			continue   # wolves prowl the wild grass, not the road
		if Vector2(cell - start).length() < 8.0:
			continue   # no ambushes on the player's doorstep
		var w := WOLF_SCENE.instantiate()
		w.position = map_to_local(cell)
		w.level = _rng.randi_range(1, 3)
		add_child(w)
		spawned += 1
	return spawned

func _place_story_positions() -> void:
	if player:
		player.global_position = cell_to_world(_player_start_cell())
	if pickup_sword:
		pickup_sword.global_position = cell_to_world(Vector2i(path_x_at(8) + 1, 8))

func _random_cell() -> Vector2i:
	return Vector2i(_rng.randi_range(0, map_width - 1), _rng.randi_range(0, map_height - 1))

func _is_grass(cell: Vector2i) -> bool:
	var tile_x := get_cell_atlas_coords(cell).x
	return tile_x == 0 or tile_x == 3
