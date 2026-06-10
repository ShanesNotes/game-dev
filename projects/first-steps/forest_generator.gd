extends TileMapLayer

## Procedural Elwynn Forest generator
## Destiny-inspired lush exploration zone + WoW sword & wolves combat loop.
## Uses the 4-tile expanded tileset (0=grass, 1=dirt, 2=stone/path, 3=grass variant).
## Places trees (procedural prop) and extra wolves for a "patrol the forest" feel.

@export var map_width: int = 56
@export var map_height: int = 40
@export var seed: int = 1337  # for reproducible "dope" forest

@onready var player = get_parent().get_node("Player")
@onready var pickup_sword = get_parent().get_node_or_null("Sword")  # the Area2D pickup if present

const TREE = preload("res://assets/tree.png")
const WOLF_SCENE = preload("res://wolf.tscn")

func _ready() -> void:
	# Clear any baked static data so we own the map
	clear()
	
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.08
	noise.fractal_octaves = 3
	
	# 1. Base ground + path (Elwynn golden-green forest with winding road)
	var path_center_x := map_width * 0.48
	for y in range(map_height):
		# Winding path using sine + noise (Destiny patrol road feel)
		var wind := sin(y * 0.18) * 3.5 + noise.get_noise_2d(0, y) * 2.5
		var path_x := int(path_center_x + wind)
		
		for x in range(map_width):
			var n := noise.get_noise_2d(x, y)
			var tile := 0  # default lush grass
			
			# Path / road (stone + dirt mix for worn trail)
			var dist_to_path := abs(x - path_x)
			if dist_to_path < 2:
				tile = 2 if (x + y) % 3 == 0 else 1  # stone highlights + dirt
			elif dist_to_path < 3 and randf() < 0.6:
				tile = 1  # dirt shoulder
			
			# Undergrowth / variant grass clusters (deeper forest pockets)
			if dist_to_path > 4 and n > 0.35:
				tile = 3
			
			# A few "clearing" stone patches off path (Destiny public space vibe)
			if dist_to_path > 6 and abs(n) < 0.12:
				tile = 2
			
			set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))
	
	# 2. Trees for verticality and "dope forest" density (Destiny world dressing)
	var tree_count := 28
	var placed := 0
	var attempts := 0
	while placed < tree_count and attempts < 200:
		attempts += 1
		var tx := randi() % map_width
		var ty := randi() % map_height
		var atlas := get_cell_atlas_coords(Vector2i(tx, ty))
		if atlas.x == 0 or atlas.x == 3:  # only on grass/variant, not path
			# bias away from path a bit
			var path_dist := abs(tx - int(path_center_x + sin(ty * 0.18) * 3.5))
			if path_dist < 3 and randf() < 0.7:
				continue
			
			var t := Sprite2D.new()
			t.texture = TREE
			t.position = Vector2(tx * 32 + 16, ty * 32 + 22)  # slight base offset so trunk sits on ground
			t.scale = Vector2(randf_range(0.85, 1.25), randf_range(0.85, 1.25))
			t.rotation_degrees = randf_range(-12, 12)
			# Slight color variation for lush Destiny-like variety
			var v := randf_range(0.92, 1.08)
			t.modulate = Color(0.95 * v, 1.05 * v, 0.88 * v)
			t.z_index = -1 if randf() < 0.3 else 0  # some behind for depth
			add_child(t)
			placed += 1
	
	# 3. Extra wolves for WoW-style threat in the woods (aggro/leash already in wolf.gd)
	# Place them off the main path in "wild" grass areas
	for i in range(5):
		var wx := randi() % map_width
		var wy := randi() % map_height
		var atlas := get_cell_atlas_coords(Vector2i(wx, wy))
		if atlas.x == 0 or atlas.x == 3:
			var path_dist := abs(wx - int(path_center_x + sin(wy * 0.18) * 3.5))
			if path_dist > 4:
				var w := WOLF_SCENE.instantiate()
				w.position = Vector2(wx * 32 + 16, wy * 32 + 16)
				w.level = randi_range(1, 3)
				add_child(w)
	
	# 4. Reposition player start and pickup sword to nice spots (clearing + path goal)
	# Player starts in a southern clearing near the path
	if player:
		var start_x := int(path_center_x) - 2
		var start_y := map_height - 6
		player.global_position = Vector2(start_x * 32 + 16, start_y * 32 + 16)
	
	# Move the world pickup sword north-ish along the path as a "quest item / exploration reward"
	if pickup_sword:
		var goal_x := int(path_center_x) + 1
		var goal_y := 8
		pickup_sword.global_position = Vector2(goal_x * 32 + 16, goal_y * 32 + 16)
	
	print("Generated dope Elwynn-style forest: ", map_width, "x", map_height, " (seed ", seed, ")")
	print("Trees: ", placed, "  Extra wolves: 5  (plus the original 3 instances if present)")
