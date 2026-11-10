class_name MapSession
extends RefCounted
## Process-lifetime holder for the current map.
##
## The map is generated once and reused, so reopening the map screen does not reroll it.
## A real run state can take over `data` later without touching the view.

static var data: MapData = null
static var run: MapRun = null


static func get_data() -> MapData:
	if data == null:
		data = MapGenerator.generate(randi())
		_report(data)
	return data


## Progress over the cached map. Rebuilt whenever `data` is replaced behind our back.
static func get_run() -> MapRun:
	var current := get_data()
	if run == null or run.data != current:
		run = MapRun.new(current)
	return run


static func regenerate() -> MapData:
	data = MapGenerator.generate(randi())
	run = MapRun.new(data)
	_report(data)
	return data


## Drops the cached map. Tests use this; a new run would too.
static func reset() -> void:
	data = null
	run = null


static func _report(map: MapData) -> void:
	var counts := {
		MapNodeData.Type.COMBAT: 0,
		MapNodeData.Type.RANDOM: 0,
		MapNodeData.Type.REST: 0,
		MapNodeData.Type.BOSS: 0,
	}
	for node in map.nodes:
		if counts.has(node.type):
			counts[node.type] = int(counts[node.type]) + 1
	print("[map] seed=%d nodes=%d combat=%d random=%d rest=%d boss=%d" % [
		map.seed, map.nodes.size(),
		counts[MapNodeData.Type.COMBAT], counts[MapNodeData.Type.RANDOM],
		counts[MapNodeData.Type.REST], counts[MapNodeData.Type.BOSS]])
