class_name MapData
extends RefCounted
## The result of one MapGenerator.generate() call.
##
## Node ids are indices into `nodes`, so `nodes[node.next[i]]` is always valid.

var seed: int = 0
var nodes: Array[MapNodeData] = []
var start_id: int = 0
var boss_id: int = 0
