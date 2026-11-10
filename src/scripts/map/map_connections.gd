extends Control
## Draws the revealed edges, a dot at the start, and a halo behind the current node.
##
## Lines run centre-to-centre and the icons are drawn on top, so the endpoints stay hidden.
## An edge is revealed only once the node it leaves has been visited. Edges the player walked
## are drawn as a lit trail; revealed branches they passed up stay dim.

const LINE_COLOR := Color("#4a4a55")
const LINE_WIDTH := 3.0
const TRAIL_COLOR := Color("840269ff")
const TRAIL_WIDTH := 5.0
const TRAIL_GLOW := Color(0.882, 0.114, 0.282, 0.25)
const TRAIL_GLOW_WIDTH := 12.0
const START_RADIUS := 9.0
const HALO_COLOR := Color(0.85, 0.87, 0.95, 0.16)
const HALO_PADDING := 12.0

var _run: MapRun = null


func set_run(run: MapRun) -> void:
	_run = run
	queue_redraw()


## Number of drawn edges; the view suite compares it with the revealed edge count.
func line_count() -> int:
	if _run == null:
		return 0
	var count := 0
	for node in _run.data.nodes:
		if _run.edge_visible(node):
			count += node.next.size()
	return count


## Number of edges on the walked trail. The path is a chain, so it is its length minus one.
func path_line_count() -> int:
	if _run == null:
		return 0
	return maxi(_run.path.size() - 1, 0)


func _draw() -> void:
	if _run == null:
		return
	var data := _run.data

	for node in data.nodes:
		if not _run.edge_visible(node):
			continue
		for next_id in node.next:
			var to := data.nodes[next_id]
			if _run.is_path_edge(node, to):
				draw_line(node.position, to.position, TRAIL_GLOW, TRAIL_GLOW_WIDTH, true)
				draw_line(node.position, to.position, TRAIL_COLOR, TRAIL_WIDTH, true)
			else:
				draw_line(node.position, to.position, LINE_COLOR, LINE_WIDTH, true)

	var current := data.nodes[_run.current_id]
	draw_circle(current.position, MapNodeIcon.icon_size(current.type).y / 2.0 + HALO_PADDING,
		HALO_COLOR)
	draw_circle(data.nodes[data.start_id].position, START_RADIUS, LINE_COLOR)
