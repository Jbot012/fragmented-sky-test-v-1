extends Control
## Builds the map view from the session's run and rebuilds it on demand.

const NODE_SCENE := preload("res://src/scenes/map_node.tscn")
const MENU_SCENE := "res://src/scenes/menu.tscn"

@onready var _scroll: ScrollContainer = %ScrollContainer
@onready var _connections: Control = %Connections
@onready var _node_layer: Control = %NodeLayer
@onready var _regenerate_button: Button = %RegenerateButton


func _ready() -> void:
	HandCursor.install()
	_regenerate_button.pressed.connect(_on_regenerate_pressed)
	_build(MapSession.get_run())


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		HandCursor.set_grabbing(event.pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		HandCursor.set_grabbing(false)


func _exit_tree() -> void:
	HandCursor.set_grabbing(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE)


func _build(run: MapRun) -> void:
	for child in _node_layer.get_children():
		_node_layer.remove_child(child)
		child.free()

	for node in run.data.nodes:
		if node.type == MapNodeData.Type.START:
			continue
		var icon: MapNodeIcon = NODE_SCENE.instantiate()
		_node_layer.add_child(icon)
		icon.setup(node)
		icon.pressed.connect(_on_node_pressed)

	_refresh(run)


func _refresh(run: MapRun) -> void:
	for icon in _node_layer.get_children():
		icon.refresh(run)
	_connections.set_run(run)


func _on_node_pressed(node: MapNodeData) -> void:
	var run := MapSession.get_run()
	if not run.visit(node):
		return
	_refresh(run)
	_focus(node)


## Centres the view on `node`, clamped by the scroll range.
func _focus(node: MapNodeData) -> void:
	var bar := _scroll.get_v_scroll_bar()
	var range_max := int(maxf(bar.max_value - bar.page, 0.0))
	_scroll.scroll_vertical = clampi(int(node.position.y - _scroll.size.y / 2.0), 0, range_max)


func _on_regenerate_pressed() -> void:
	MapSession.regenerate()
	_build(MapSession.get_run())
	_scroll.call_deferred("_snap_to_bottom")
