class_name MapGenerator
extends RefCounted
## Seeded, layered map generator.
##
## The map is a lattice of fixed slots. Each row takes 2-4 columns, biased toward the spine
## (one node per row, wandering at most one column per step) and filtered so that every node
## stays within one column of the row below it. Edges then join only same-column and
## one-column-diagonal neighbours in the next row, which gives every node a parent and a
## child by construction -- so every node is reachable from the start and can reach the boss,
## with no rejection sampling.
##
## Boss and start are fixed; only the slots in between are random.

const ROWS := 10

const COLUMN_X: Array[float] = [149.0, 329.0, 509.0, 689.0]
const ROW_Y: Array[float] = [
	0.0,
	1575.0, 1449.0, 1324.0, 1198.0, 1073.0,
	947.0, 822.0, 696.0, 571.0, 445.0,
]
const START_POS := Vector2(419.0, 1700.0)
const BOSS_POS := Vector2(419.0, 320.0)

const NODES_PER_ROW_MIN := 2
const NODES_PER_ROW_MAX := 4
const REST_MIN_ROW := 3
## The two rows below the boss never hold a rest, so the pair in row 10 is the last stop.
const REST_FORBIDDEN_FROM_ROW := ROWS - 2

const CENTER_COLUMNS: Array[int] = [1, 2]
const ALL_COLUMNS: Array[int] = [0, 1, 2, 3]

const TYPE_WEIGHTS := {
	MapNodeData.Type.COMBAT: 60,
	MapNodeData.Type.RANDOM: 25,
	MapNodeData.Type.REST: 15,
}


static func generate(seed: int) -> MapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var data := MapData.new()
	data.seed = seed
	data.start_id = _append(data, 0, -1, START_POS, MapNodeData.Type.START).id

	# --- spine: one column per row, moving at most one column per step ----------------------
	var spine: Array[int] = []
	var col := rng.randi_range(1, 2)
	for row in range(1, ROWS + 1):
		if row == ROWS:
			col = clampi(col, 1, 2)
		spine.append(col)
		var next_allowed := _allowed_columns(row + 1)
		col = clampi(col + rng.randi_range(-1, 1), next_allowed[0], next_allowed[-1])
	
	# --- slots: the spine node plus 1-2 extras per row --------------------------------------
	var row_nodes: Array[Array] = []
	for row in range(1, ROWS + 1):
		var allowed := _allowed_columns(row)
		var previous: Array[int] = []
		if row > 1:
			previous = _columns_of(row_nodes[row - 2])
		var cols := _pick_columns(allowed, previous, spine[row - 1], rng)

		var nodes: Array[MapNodeData] = []
		for c in cols:
			nodes.append(_append(data, row, c, Vector2(COLUMN_X[c], ROW_Y[row]),
				MapNodeData.Type.COMBAT))
		row_nodes.append(nodes)

	data.boss_id = _append(data, ROWS + 1, -1, BOSS_POS, MapNodeData.Type.BOSS).id

	# --- edges ------------------------------------------------------------------------------
	# Every row was chosen so that each node has a neighbour within one column in the row
	# below, which is what makes this adjacency-only wiring leave no orphan and no dead end.
	for node in row_nodes[0]:
		_link(data.nodes[data.start_id], node)

	for r in range(0, ROWS - 1):
		for parent in row_nodes[r]:
			for child in row_nodes[r + 1]:
				if absi(child.col - parent.col) <= 1:
					_link(parent, child)

	for node in row_nodes[ROWS - 1]:
		_link(node, data.nodes[data.boss_id])

	_assign_types(row_nodes, rng)
	return data


static func _append(data: MapData, row: int, col: int, position: Vector2,
		type: int) -> MapNodeData:
	var node := MapNodeData.new(data.nodes.size(), row, col, position)
	node.type = type
	data.nodes.append(node)
	return node


static func _allowed_columns(row: int) -> Array[int]:
	if row <= 1 or row >= ROWS:
		return CENTER_COLUMNS
	return ALL_COLUMNS


static func _link(from: MapNodeData, to: MapNodeData) -> void:
	if not from.next.has(to.id):
		from.next.append(to.id)


## A random column set for one row: 2-4 columns that keep every node adjacent to the row
## below, preferring to include the spine column so the map keeps its deliberate route.
##
## The adjacency filter is what lets the wiring be adjacency-only: it is applied while the
## row is built, because once a row fills all four columns no later in-row move can rescue
## a node that is stranded two columns from everything below it.
static func _pick_columns(allowed: Array[int], previous: Array[int], spine_col: int,
		rng: RandomNumberGenerator) -> Array[int]:
	var size := rng.randi_range(NODES_PER_ROW_MIN, mini(NODES_PER_ROW_MAX, allowed.size()))
	while size >= NODES_PER_ROW_MIN:
		var valid: Array[Array] = []
		var with_spine: Array[Array] = []
		for mask in range(1, 1 << allowed.size()):
			if _bit_count(mask) != size:
				continue
			var candidate: Array[int] = []
			for i in allowed.size():
				if mask & (1 << i):
					candidate.append(allowed[i])
			if not previous.is_empty() and not _pair_connected(previous, candidate):
				continue
			valid.append(candidate)
			if candidate.has(spine_col):
				with_spine.append(candidate)

		if not valid.is_empty():
			var pool: Array[Array] = with_spine if not with_spine.is_empty() else valid
			var chosen: Array[int] = []
			chosen.assign(pool[rng.randi_range(0, pool.size() - 1)])
			return chosen
		size -= 1

	# Unreachable while rows hold 2-4 nodes over 4 columns; never return an empty row.
	var fallback: Array[int] = [allowed[0]]
	return fallback


static func _columns_of(nodes: Array[MapNodeData]) -> Array[int]:
	var cols: Array[int] = []
	for node in nodes:
		cols.append(node.col)
	return cols


## True when every column in `lower` is within one of some column in `upper` and vice versa,
## i.e. wiring them adjacency-only gives every node a parent and a child.
static func _pair_connected(lower: Array[int], upper: Array[int]) -> bool:
	for l in lower:
		if not _has_close(upper, l):
			return false
	for u in upper:
		if not _has_close(lower, u):
			return false
	return true


static func _has_close(cols: Array[int], col: int) -> bool:
	for c in cols:
		if absi(c - col) <= 1:
			return true
	return false


static func _bit_count(mask: int) -> int:
	var count := 0
	while mask > 0:
		count += mask & 1
		mask >>= 1
	return count


static func _assign_types(row_nodes: Array[Array], rng: RandomNumberGenerator) -> void:
	for row in range(1, ROWS + 1):
		var rest_used := false
		for node in row_nodes[row - 1]:
			if row == 1:
				node.type = MapNodeData.Type.COMBAT
				continue
			var type := _roll_type(rng)
			if type == MapNodeData.Type.REST and (rest_used or not _rest_allowed(row)):
				type = MapNodeData.Type.COMBAT
			if type == MapNodeData.Type.REST:
				rest_used = true
			node.type = type
	_force_final_row_rests(row_nodes)


## Rests roll only in rows 3-7: never before row 3, never in the two rows below the boss.
static func _rest_allowed(row: int) -> bool:
	return row >= REST_MIN_ROW and row < REST_FORBIDDEN_FROM_ROW


static func _roll_type(rng: RandomNumberGenerator) -> int:
	var total := 0
	for weight in TYPE_WEIGHTS.values():
		total += int(weight)
	var roll := rng.randi_range(1, total)
	for type in TYPE_WEIGHTS:
		roll -= int(TYPE_WEIGHTS[type])
		if roll <= 0:
			return type
	return MapNodeData.Type.COMBAT


## Row 10 is the last stop before the boss, so every node in it is a rest site: whichever
## branch the player took, they get the same respite. Row 10 is restricted to the two centre
## columns, so this always covers exactly two nodes.
static func _force_final_row_rests(row_nodes: Array[Array]) -> void:
	for node in row_nodes[ROWS - 1]:
		node.type = MapNodeData.Type.REST
