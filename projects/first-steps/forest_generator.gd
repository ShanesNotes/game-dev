extends TileMapLayer

## Procedural Elwynn-style forest generator.
## Runs once at scene load: paints grass on this layer, lays a winding dirt
## road on the Road layer using 16 dual-grid transition tiles (so the road
## edge is organic, not blocky), scatters trees/bushes/rocks into the
## Y-sorted World node, spawns extra wolves off the road, then places the
## player at the south end of the road and the pickup sword up north.

@export var map_width: int = 64
@export var map_height: int = 48
@export var map_seed: int = 1337   # same seed = the exact same forest
@export var tree_count: int = 170
@export var bush_count: int = 90
@export var rock_count: int = 36
@export var extra_wolves: int = 6

@onready var road: TileMapLayer = get_parent().get_node("Road")
@onready var world: Node2D = get_parent().get_node("World")
@onready var player = world.get_node("Player")
@onready var pickup_sword = world.get_node_or_null("Sword")   # the Area2D pickup, if not yet taken

const SHADOW = preload("res://assets/shadow.png")
const WOLF_SCENE = preload("res://wolf.tscn")
const TREES = [
	preload("res://assets/tree_oak_a.png"),
	preload("res://assets/tree_oak_b.png"),
	preload("res://assets/tree_pine.png"),
]
const BUSHES = [preload("res://assets/bush_a.png"), preload("res://assets/bush_b.png")]
const ROCKS = [preload("res://assets/rock_a.png"), preload("res://assets/rock_b.png")]
const STUMP = preload("res://assets/stump.png")
const MUSHROOMS = preload("res://assets/mushroom_cluster.png")
const CAMPFIRE = preload("res://assets/campfire.png")
const SIGNPOST = preload("res://assets/signpost.png")
const SOFT_DOT = preload("res://assets/soft_dot.png")

# terrain.png atlas: row 0 = grass variants, row 1 = dirt variants,
# rows 2-5 = dual-grid transitions (bit 1=TL, 2=TR, 4=BL, 8=BR is dirt).
const GRASS_TILES = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const DIRT_TILES = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _dirt := {}        # Vector2i -> true where the road/clearings are
var _occupied := {}    # cells already holding a prop

func _ready() -> void:
	clear()
	road.clear()
	_rng.seed = map_seed
	_noise.seed = map_seed
	_noise.frequency = 0.08
	_noise.fractal_octaves = 3
	_build_dirt_mask()
	_paint_ground()
	_paint_road()
	var trees := _scatter(TREES, tree_count, 2, true, true)
	_scatter(BUSHES, bush_count, 1, false)
	_scatter(ROCKS, rock_count, 2, true)
	_scatter([STUMP], 18, 2, false)
	_scatter([MUSHROOMS], 40, 1, false)
	_scatter_roadside(26)
	var wolves := _spawn_wolves()
	_add_bounds()
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
	var start_y := map_height - 7
	return Vector2i(path_x_at(start_y), start_y)

func _sword_cell() -> Vector2i:
	return Vector2i(path_x_at(8) + 1, 8)

func _build_dirt_mask() -> void:
	for y in range(map_height):
		var px := path_x_at(y)
		var half := 0.7 + (_noise.get_noise_2d(7, y) + 1.0) * 0.5   # road half-width 0.7..1.7
		for x in range(map_width):
			if absf(x - px) <= half:
				_dirt[Vector2i(x, y)] = true
	# small camp clearings where the story beats happen
	for centre in [_player_start_cell(), _sword_cell()]:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if Vector2(dx, dy).length() <= 2.2:
					_dirt[centre + Vector2i(dx, dy)] = true

func _is_dirt(cell: Vector2i) -> bool:
	return _dirt.has(cell)

func _near_dirt(cell: Vector2i, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if _is_dirt(cell + Vector2i(dx, dy)):
				return true
	return false

func _paint_ground() -> void:
	for y in range(map_height):
		for x in range(map_width):
			var r := _rng.randf()
			var tile := GRASS_TILES[0]
			if r > 0.95:
				tile = GRASS_TILES[3]   # flowers
			elif r > 0.80:
				tile = GRASS_TILES[2]   # blades
			elif r > 0.55:
				tile = GRASS_TILES[1]   # mottled
			set_cell(Vector2i(x, y), 0, tile)

# Dual grid: the Road layer is offset half a tile; each road cell picks its
# tile from which of its 4 corners (= centres of 4 ground cells) are dirt.
func _paint_road() -> void:
	for gy in range(map_height + 1):
		for gx in range(map_width + 1):
			var bits := 0
			if _is_dirt(Vector2i(gx - 1, gy - 1)): bits |= 1   # top-left
			if _is_dirt(Vector2i(gx, gy - 1)):     bits |= 2   # top-right
			if _is_dirt(Vector2i(gx - 1, gy)):     bits |= 4   # bottom-left
			if _is_dirt(Vector2i(gx, gy)):         bits |= 8   # bottom-right
			if bits == 0:
				continue
			if bits == 15:   # fully inside the road: use textured dirt variants
				if gx == path_x_at(gy):
					road.set_cell(Vector2i(gx, gy), 0, DIRT_TILES[2])   # wheel ruts down the middle
				else:
					road.set_cell(Vector2i(gx, gy), 0, DIRT_TILES[_rng.randi() % 4])
			else:
				# 3 roughness variants of each transition keep the edge organic
				var v := _rng.randi() % 3
				road.set_cell(Vector2i(gx, gy), 0, Vector2i(bits % 4, 2 + v * 4 + (bits >> 2)))

func _scatter(textures: Array, count: int, road_gap: int, solid: bool, grove: bool = false) -> int:
	var start := _player_start_cell()
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 10:
		attempts += 1
		var cell := _random_cell()
		if _occupied.has(cell) or _near_dirt(cell, road_gap):
			continue
		if Vector2(cell - start).length() < 4.0:
			continue   # keep the spawn clearing open
		if grove and _noise.get_noise_2d(cell.x * 1.7, cell.y * 1.7) < -0.18 and _rng.randf() < 0.5:
			continue   # trees clump into groves, leaving open meadows between
		var tex: Texture2D = textures[_rng.randi() % textures.size()]
		var prop := _make_prop(tex, solid)
		prop.position = cell_to_world(cell) + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
		world.add_child(prop)
		_occupied[cell] = true
		placed += 1
	return placed

# Rocks, stumps and mushrooms flanking the road so the traveled corridor
# isn't a sterile band.
func _scatter_roadside(count: int) -> void:
	var pool: Array = [ROCKS[0], ROCKS[1], STUMP, MUSHROOMS]
	var start := _player_start_cell()
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 12:
		attempts += 1
		var cell := _random_cell()
		if _occupied.has(cell) or _is_dirt(cell) or not _near_dirt(cell, 1):
			continue
		if Vector2(cell - start).length() < 4.0:
			continue
		var prop := _make_prop(pool[_rng.randi() % pool.size()], false)
		prop.position = cell_to_world(cell) + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
		world.add_child(prop)
		_occupied[cell] = true
		placed += 1

# A prop's origin sits at its visual base so Y-sort layers it correctly.
func _make_prop(tex: Texture2D, solid: bool) -> Node2D:
	var w := tex.get_width()
	var h := tex.get_height()
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.offset = Vector2(-w / 2.0, -h + 2)
	var v := _rng.randf_range(0.94, 1.06)
	spr.modulate = Color(0.97 * v, 1.03 * v, 0.94 * v)   # subtle per-prop variety
	var shadow := Sprite2D.new()
	shadow.texture = SHADOW
	if h < 22:   # ground-hugging props: wider, lower, so the rim actually shows
		shadow.position = Vector2(0, -1)
		shadow.scale = Vector2(w / 18.0, w / 26.0)
	else:
		shadow.position = Vector2(0, -2)
		shadow.scale = Vector2(w / 22.0, w / 30.0)
	shadow.show_behind_parent = true
	var root: Node2D
	if solid:
		root = StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = maxf(w * 0.18, 4.0)
		shape.shape = circle
		shape.position = Vector2(0, -4)
		root.add_child(shape)
	else:
		root = Node2D.new()
	root.add_child(shadow)
	root.add_child(spr)
	return root

func _spawn_wolves() -> int:
	var start := _player_start_cell()
	var spawned := 0
	var attempts := 0
	while spawned < extra_wolves and attempts < 200:
		attempts += 1
		var cell := _random_cell()
		if _occupied.has(cell) or _near_dirt(cell, 3):
			continue
		if Vector2(cell - start).length() < 10.0:
			continue   # no ambushes on the player's doorstep
		var w := WOLF_SCENE.instantiate()
		w.position = cell_to_world(cell)
		w.level = _rng.randi_range(1, 3)
		world.add_child(w)
		_occupied[cell] = true
		spawned += 1
	return spawned

func _add_bounds() -> void:
	var body := StaticBody2D.new()
	var size := Vector2(map_width * 32, map_height * 32)
	for wall in [
		[Vector2(size.x / 2, -8), Vector2(size.x + 64, 16)],
		[Vector2(size.x / 2, size.y + 8), Vector2(size.x + 64, 16)],
		[Vector2(-8, size.y / 2), Vector2(16, size.y + 64)],
		[Vector2(size.x + 8, size.y / 2), Vector2(16, size.y + 64)],
	]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = wall[1]
		shape.shape = rect
		shape.position = wall[0]
		body.add_child(shape)
	get_parent().add_child.call_deferred(body)

func _place_story_positions() -> void:
	var start := _player_start_cell()
	_dress_camp(start)
	if player:
		player.global_position = cell_to_world(start)
		var cam: Camera2D = player.get_node("Camera2D")
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = map_width * 32
		cam.limit_bottom = map_height * 32
		cam.call_deferred("reset_smoothing")
	if pickup_sword:
		pickup_sword.global_position = cell_to_world(_sword_cell())

# The spawn clearing becomes a camp: fire with a flickering glow, a signpost
# pointing up the road, a stump for sitting.
func _dress_camp(start: Vector2i) -> void:
	var fire := _make_prop(CAMPFIRE, false)
	fire.position = cell_to_world(start + Vector2i(-2, -1))
	var glow := Sprite2D.new()
	glow.texture = SOFT_DOT
	glow.scale = Vector2(7, 5)
	glow.position = Vector2(0, -6)
	glow.modulate = Color(1.0, 0.72, 0.3, 0.3)
	glow.show_behind_parent = true
	fire.add_child(glow)
	var t := create_tween().set_loops()
	t.tween_property(glow, "modulate:a", 0.18, 0.45)
	t.tween_property(glow, "modulate:a", 0.3, 0.45)
	world.add_child(fire)
	_occupied[start + Vector2i(-2, -1)] = true
	var sign := _make_prop(SIGNPOST, false)
	sign.position = cell_to_world(start + Vector2i(2, 0))
	world.add_child(sign)
	_occupied[start + Vector2i(2, 0)] = true
	var seat := _make_prop(STUMP, false)
	seat.position = cell_to_world(start + Vector2i(-1, 1))
	world.add_child(seat)
	_occupied[start + Vector2i(-1, 1)] = true

func _random_cell() -> Vector2i:
	return Vector2i(_rng.randi_range(1, map_width - 2), _rng.randi_range(1, map_height - 2))
