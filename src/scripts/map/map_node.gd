class_name MapNodeIcon
extends TextureRect
## One generated map node, drawn as its type icon.
##
## Hidden until revealed, clickable only while it is a child of the player's current node.
## Everything else is drawn dimmed and mouse-transparent so map panning keeps working.

signal pressed(node: MapNodeData)

const NODE_SIZE := Vector2(57.0, 57.0)
const BOSS_SIZE := Vector2(180.0, 180.0)
const TRAIL_ALPHA := 0.8
const INERT_ALPHA := 0.45

const ICONS := {
	MapNodeData.Type.COMBAT: preload("res://assets/map/map_icon_3_Enemy_equal-normal.png"),
	MapNodeData.Type.RANDOM: preload("res://assets/map/map_icon_2_random_encounter.png"),
	MapNodeData.Type.REST: preload("res://assets/map/map_icon_1_camp.png"),
	MapNodeData.Type.BOSS: preload("res://assets/map/map_icon_4_Enemy_equal-Boss.png"),
}

var node_data: MapNodeData = null


static func icon_size(type: int) -> Vector2:
	return BOSS_SIZE if type == MapNodeData.Type.BOSS else NODE_SIZE


func setup(node: MapNodeData) -> void:
	node_data = node
	texture = ICONS[node.type]
	size = icon_size(node.type)
	position = node.position - size / 2.0


## Applies the run's current view of this node: visible, bright, and clickable or not.
## Visited nodes stay brighter than branches the player passed up, so the walked trail reads.
func refresh(run: MapRun) -> void:
	if node_data == null:
		return
	var selectable := run.is_selectable(node_data)
	var current := run.current_id == node_data.id

	visible = run.is_visible(node_data)
	mouse_filter = Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if selectable \
		else Control.CURSOR_ARROW
	if selectable or current:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	elif run.is_visited(node_data):
		modulate = Color(1.0, 1.0, 1.0, TRAIL_ALPHA)
	else:
		modulate = Color(1.0, 1.0, 1.0, INERT_ALPHA)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	pressed.emit(node_data)
	accept_event()
