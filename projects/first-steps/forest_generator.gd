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
@export var tree_count: int = 200
@export var bush_count: int = 110
@export var rock_count: int = 36
@export var extra_wolves: int = 6

@export_group("Scene wiring")
@export_node_path("TileMapLayer") var road_path: NodePath = ^"../Road"
@export_node_path("Node2D") var world_path: NodePath = ^"../World"
@export_node_path("Node2D") var player_path: NodePath = ^"../World/Player"
@export_node_path("Node2D") var pickup_sword_path: NodePath = ^"../World/Sword"
@export_node_path("Node") var bounds_parent_path: NodePath = ^".."
@export_group("")

@onready var road: TileMapLayer = get_node(road_path) as TileMapLayer
@onready var world: Node2D = get_node(world_path) as Node2D
@onready var player: Node2D = get_node(player_path) as Node2D
@onready var pickup_sword: Node2D = get_node_or_null(pickup_sword_path) as Node2D   # the Area2D pickup, if not yet taken
@onready var bounds_parent: Node = get_node(bounds_parent_path)

const SHADOW: Texture2D = preload("res://assets/shadow.png")
const WOLF_SCENE: PackedScene = preload("res://wolf.tscn")
const TREES: Array[Texture2D] = [
	preload("res://assets/tree_oak_a.png"),
	preload("res://assets/tree_oak_b.png"),
	preload("res://assets/tree_pine.png"),
]
const BUSHES: Array[Texture2D] = [preload("res://assets/bush_a.png"), preload("res://assets/bush_b.png")]
const ROCKS: Array[Texture2D] = [preload("res://assets/rock_a.png"), preload("res://assets/rock_b.png")]
const STUMP: Texture2D = preload("res://assets/stump.png")
const MUSHROOMS: Texture2D = preload("res://assets/mushroom_cluster.png")
const CAMPFIRE: Texture2D = preload("res://assets/campfire.png")
const SIGNPOST: Texture2D = preload("res://assets/signpost.png")
const SOFT_DOT: Texture2D = preload("res://assets/soft_dot.png")
const PEDESTAL: Texture2D = preload("res://assets/pedestal.png")
const CRACKLE: AudioStream = preload("res://assets/sounds/campfire_crackle.wav")

# terrain.png atlas: row 0 = grass variants, row 1 = dirt variants,
# rows 2-5 = dual-grid transitions (bit 1=TL, 2=TR, 4=BL, 8=BR is dirt).
const GRASS_TILES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const DIRT_TILES: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _noise: FastNoiseLite = FastNoiseLite.new()
var _dirt: Dictionary[Vector2i, bool] = {}        # true where the road/clearings are
var _occupied: Dictionary[Vector2i, bool] = {}    # cells already holding a prop


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
	var trees: int = _scatter(TREES, tree_count, 2, true, true)
	_scatter(BUSHES, bush_count, 1, false)
	_scatter(ROCKS, rock_count, 2, true)
	_scatter([STUMP], 18, 2, false)
	_scatter([MUSHROOMS], 40, 1, false)
	_scatter_roadside(40)
	var wolves: int = _spawn_wolves()
	_add_bounds()
	_place_story_positions()
	print("Forest generated: %dx%d cells, seed %d, %d trees, %d extra wolves"
			% [map_width, map_height, map_seed, trees, wolves])


# The road winds north→south: a sine sway plus noise jitter. ONE function,
# used by every placement rule, so "near the road" always means the same thing.
func path_x_at(y: int) -> int:
	var wind: float = sin(y * 0.18) * 3.5 + _noise.get_noise_2d(0, y) * 2.5
	return int(map_width * 0.48 + wind)


# Tile cell → world position (cell centre), respecting this layer's transform.
func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell))


func _player_start_cell() -> Vector2i:
	var start_y: int = map_height - 7
	return Vector2i(path_x_at(start_y), start_y)


func _sword_cell() -> Vector2i:
	return Vector2i(path_x_at(8) + 1, 8)


func _build_dirt_mask() -> void:
	for y: int in range(map_height):
		var path_x: int = path_x_at(y)
		var half_width: float = 0.7 + (_noise.get_noise_2d(7, y) + 1.0) * 0.5   # road half-width 0.7..1.7
		for x: int in range(map_width):
			if absf(x - path_x) <= half_width:
				_dirt[Vector2i(x, y)] = true
	# small camp clearings where the story beats happen
	for centre: Vector2i in [_player_start_cell(), _sword_cell()]:
		for dy: int in range(-2, 3):
			for dx: int in range(-2, 3):
				if Vector2(dx, dy).length() <= 2.2:
					_dirt[centre + Vector2i(dx, dy)] = true


func _is_dirt(cell: Vector2i) -> bool:
	return _dirt.has(cell)


func _near_dirt(cell: Vector2i, radius: int) -> bool:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if _is_dirt(cell + Vector2i(dx, dy)):
				return true
	return false


func _paint_ground() -> void:
	for y: int in range(map_height):
		for x: int in range(map_width):
			var roll: float = _rng.randf()
			var tile: Vector2i = GRASS_TILES[0]
			if roll > 0.95:
				tile = GRASS_TILES[3]   # flowers
			elif roll > 0.80:
				tile = GRASS_TILES[2]   # blades
			elif roll > 0.55:
				tile = GRASS_TILES[1]   # mottled
			set_cell(Vector2i(x, y), 0, tile)


# Dual grid: the Road layer is offset half a tile; each road cell picks its
# tile from which of its 4 corners (= centres of 4 ground cells) are dirt.
func _paint_road() -> void:
	for gy: int in range(map_height + 1):
		for gx: int in range(map_width + 1):
			var bits: int = 0
			if _is_dirt(Vector2i(gx - 1, gy - 1)):
				bits |= 1   # top-left
			if _is_dirt(Vector2i(gx, gy - 1)):
				bits |= 2   # top-right
			if _is_dirt(Vector2i(gx - 1, gy)):
				bits |= 4   # bottom-left
			if _is_dirt(Vector2i(gx, gy)):
				bits |= 8   # bottom-right
			if bits == 0:
				continue
			if bits == 15:   # fully inside the road: use textured dirt variants
				if gx == path_x_at(gy):
					road.set_cell(Vector2i(gx, gy), 0, DIRT_TILES[2])   # wheel ruts down the middle
				else:
					road.set_cell(Vector2i(gx, gy), 0, DIRT_TILES[_rng.randi() % DIRT_TILES.size()])
			else:
				# 3 roughness variants of each transition keep the edge organic
				var variant: int = _rng.randi() % 3
				road.set_cell(Vector2i(gx, gy), 0, Vector2i(bits % 4, 2 + variant * 4 + (bits >> 2)))


func _scatter(textures: Array[Texture2D], count: int, road_gap: int, solid: bool, grove: bool = false) -> int:
	var start: Vector2i = _player_start_cell()
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < count * 10:
		attempts += 1
		var cell: Vector2i = _random_cell()
		if _occupied.has(cell) or _near_dirt(cell, road_gap):
			continue
		if Vector2(cell - start).length() < 4.0:
			continue   # keep the spawn clearing open
		if grove and _noise.get_noise_2d(cell.x * 1.7, cell.y * 1.7) < -0.18 and _rng.randf() < 0.5:
			continue   # trees clump into groves, leaving open meadows between
		var tex: Texture2D = textures[_rng.randi() % textures.size()]
		var prop: Node2D = _make_prop(tex, solid)
		prop.position = cell_to_world(cell) + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
		world.add_child(prop)
		_occupied[cell] = true
		placed += 1
	return placed


# Rocks, stumps and mushrooms flanking the road so the traveled corridor
# isn't a sterile band.
func _scatter_roadside(count: int) -> void:
	var pool: Array[Texture2D] = [ROCKS[0], ROCKS[1], STUMP, MUSHROOMS]
	var start: Vector2i = _player_start_cell()
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < count * 12:
		attempts += 1
		var cell: Vector2i = _random_cell()
		if _occupied.has(cell) or _is_dirt(cell) or not _near_dirt(cell, 1):
			continue
		if Vector2(cell - start).length() < 4.0:
			continue
		var prop: Node2D = _make_prop(pool[_rng.randi() % pool.size()], false)
		prop.position = cell_to_world(cell) + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
		world.add_child(prop)
		_occupied[cell] = true
		placed += 1


# A prop's origin sits at its visual base so Y-sort layers it correctly.
func _make_prop(tex: Texture2D, solid: bool) -> Node2D:
	var width: int = tex.get_width()
	var height: int = tex.get_height()
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.offset = Vector2(-width / 2.0, -height + 2.0)
	var value: float = _rng.randf_range(0.94, 1.06)
	sprite.modulate = Color(0.97 * value, 1.03 * value, 0.94 * value)   # subtle per-prop variety
	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = SHADOW
	if height < 22:   # ground-hugging props: wider, lower, so the rim actually shows
		shadow.position = Vector2(0, -1)
		shadow.scale = Vector2(width / 21.0, width / 26.0)
	else:
		shadow.position = Vector2(0, -2)
		shadow.scale = Vector2(width / 25.5, width / 30.0)
	shadow.show_behind_parent = true
	var root: Node2D
	if solid:
		root = StaticBody2D.new()
		var shape: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = maxf(width * 0.18, 4.0)
		shape.shape = circle
		shape.position = Vector2(0, -4)
		root.add_child(shape)
	else:
		root = Node2D.new()
	root.add_child(shadow)
	root.add_child(sprite)
	return root


func _spawn_wolves() -> int:
	var start: Vector2i = _player_start_cell()
	var spawned: int = 0
	var attempts: int = 0
	while spawned < extra_wolves and attempts < 200:
		attempts += 1
		var cell: Vector2i = _random_cell()
		if _occupied.has(cell) or _near_dirt(cell, 3):
			continue
		if Vector2(cell - start).length() < 10.0:
			continue   # no ambushes on the player's doorstep
		var wolf: Node2D = WOLF_SCENE.instantiate() as Node2D
		wolf.position = cell_to_world(cell)
		wolf.set("level", _rng.randi_range(1, 3))
		world.add_child(wolf)
		_occupied[cell] = true
		spawned += 1
	return spawned


func _add_bounds() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	var size: Vector2 = Vector2(map_width * 32, map_height * 32)
	_add_wall(body, Vector2(size.x / 2.0, -8), Vector2(size.x + 64.0, 16.0))
	_add_wall(body, Vector2(size.x / 2.0, size.y + 8.0), Vector2(size.x + 64.0, 16.0))
	_add_wall(body, Vector2(-8, size.y / 2.0), Vector2(16.0, size.y + 64.0))
	_add_wall(body, Vector2(size.x + 8.0, size.y / 2.0), Vector2(16.0, size.y + 64.0))
	bounds_parent.add_child.call_deferred(body)


func _add_wall(body: StaticBody2D, wall_position: Vector2, wall_size: Vector2) -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = wall_size
	shape.shape = rect
	shape.position = wall_position
	body.add_child(shape)


func _place_story_positions() -> void:
	var start: Vector2i = _player_start_cell()
	_dress_camp(start)
	if player != null:
		player.global_position = cell_to_world(start)
		var camera: Camera2D = player.get_node("Camera2D") as Camera2D
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = map_width * 32
		camera.limit_bottom = map_height * 32
		camera.call_deferred("reset_smoothing")
	if pickup_sword != null:
		var spot: Vector2 = cell_to_world(_sword_cell())
		var pedestal: Node2D = _make_prop(PEDESTAL, true)   # solid: you grab the sword, you never stand in the stone
		pedestal.position = spot + Vector2(0, 4)
		world.add_child(pedestal)
		_occupied[_sword_cell()] = true
		pickup_sword.global_position = spot


# The spawn clearing becomes a camp: fire with a flickering glow, a signpost
# pointing up the road, a stump for sitting.
func _dress_camp(start: Vector2i) -> void:
	var fire: Node2D = _make_prop(CAMPFIRE, false)
	fire.position = cell_to_world(start + Vector2i(-2, -1))
	var glow: Sprite2D = Sprite2D.new()
	glow.texture = SOFT_DOT
	glow.scale = Vector2(10, 7)
	glow.position = Vector2(0, -6)
	glow.modulate = Color(1.0, 0.72, 0.3, 0.3)
	glow.show_behind_parent = true
	var glow_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # actually lights the grass
	glow.material = glow_mat
	fire.add_child(glow)
	var glow_tween: Tween = create_tween().set_loops()
	glow_tween.tween_property(glow, "modulate:a", 0.18, 0.45)
	glow_tween.tween_property(glow, "modulate:a", 0.3, 0.45)
	var crackle: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	crackle.stream = CRACKLE
	crackle.autoplay = true
	crackle.max_distance = 280.0
	crackle.volume_db = -6.0
	fire.add_child(crackle)
	world.add_child(fire)
	_occupied[start + Vector2i(-2, -1)] = true
	var signpost: Node2D = _make_prop(SIGNPOST, false)
	signpost.position = cell_to_world(start + Vector2i(2, 0))
	world.add_child(signpost)
	_occupied[start + Vector2i(2, 0)] = true
	var seat: Node2D = _make_prop(STUMP, false)
	seat.position = cell_to_world(start + Vector2i(-1, 1))
	world.add_child(seat)
	_occupied[start + Vector2i(-1, 1)] = true


func _random_cell() -> Vector2i:
	return Vector2i(_rng.randi_range(1, map_width - 2), _rng.randi_range(1, map_height - 2))
