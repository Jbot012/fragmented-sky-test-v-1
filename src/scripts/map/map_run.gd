class_name MapRun
extends RefCounted
## Player progress over one generated map: where they are, what they have seen, what they can
## enter next.
##
## Generation stays pure (MapGenerator knows nothing about this). The map is a one-way DAG, so
## the player has exactly one position and may only step to a child of it; everything they have
## already seen stays on screen but becomes inert. Because there is a single position, the
## visited set is always one chain: `path` is that chain in the order it was walked.

var data: MapData
var current_id: int
var path: Array[int] = []


func _init(p_data: MapData) -> void:
	data = p_data
	current_id = p_data.start_id
	path.append(p_data.start_id)


func is_visited(node: MapNodeData) -> bool:
	return path.has(node.id)


## Seen at least once: visited, or a child of something visited.
func is_visible(node: MapNodeData) -> bool:
	if is_visited(node):
		return true
	for parent_id in _parents(node.id):
		if path.has(parent_id):
			return true
	return false


## Enterable right now: a child of the current node that has not been visited.
func is_selectable(node: MapNodeData) -> bool:
	return not is_visited(node) and data.nodes[current_id].next.has(node.id)


## Draws an edge only once the node it leaves has been entered.
func edge_visible(from: MapNodeData) -> bool:
	return is_visited(from)


## True for the edge the player actually walked: `to` follows `from` in the path.
func is_path_edge(from: MapNodeData, to: MapNodeData) -> bool:
	var at := path.find(from.id)
	return at >= 0 and at + 1 < path.size() and path[at + 1] == to.id


## Moves the player. Returns false and changes nothing when the node is out of reach.
func visit(node: MapNodeData) -> bool:
	if not is_selectable(node):
		return false
	path.append(node.id)
	current_id = node.id
	return true


func _parents(node_id: int) -> Array[int]:
	var parents: Array[int] = []
	for node in data.nodes:
		if node.next.has(node_id):
			parents.append(node.id)
	return parents
