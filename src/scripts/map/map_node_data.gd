class_name MapNodeData
extends RefCounted
## One node in a generated map.
##
## `row` is 0 for the start, 1..10 for the grid rows, and 11 for the boss. `col` is the
## grid column (0..3) for grid rows and -1 for the fixed start/boss nodes.

enum Type { START, COMBAT, RANDOM, REST, BOSS }

var id: int = 0
var row: int = 0
var col: int = -1
var position: Vector2 = Vector2.ZERO
var type: int = Type.COMBAT
var next: PackedInt32Array = PackedInt32Array()


func _init(p_id: int = 0, p_row: int = 0, p_col: int = -1,
		p_position: Vector2 = Vector2.ZERO) -> void:
	id = p_id
	row = p_row
	col = p_col
	position = p_position
