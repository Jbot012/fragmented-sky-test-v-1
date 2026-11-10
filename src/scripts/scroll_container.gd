extends ScrollContainer
## The map texture is taller than the viewport, so the screen opens scrolled to the bottom
## of its range rather than the top.
##
## Panning itself needs no code: ScrollContainer handles mouse drag and mouse wheel
## natively, and horizontal scrolling is disabled in map_screen.tscn, so the map can only
## move vertically.

func _ready() -> void:
	# Layout is not final during _ready, so snap now and again once the bar reports a range.
	_snap_to_bottom.call_deferred()
	get_v_scroll_bar().changed.connect(_snap_to_bottom, CONNECT_ONE_SHOT)


func _snap_to_bottom() -> void:
	var bar := get_v_scroll_bar()
	scroll_vertical = int(maxf(bar.max_value - bar.page, 0.0))
