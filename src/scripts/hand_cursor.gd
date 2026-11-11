class_name HandCursor
extends RefCounted
## Swaps the OS cursor for the hand art in `assets/`.
##
## The open hand is the resting cursor; the fist is used while the left mouse button is held.
## Both images are downscaled with nearest-neighbour filtering so the pixel art stays crisp.

const OPEN_PATH := "res://assets/Hand_click_open.png"
const GRAB_PATH := "res://assets/Hand_click_close.png"
const CURSOR_SIZE := 96
## Index fingertip on the open hand and the matching knuckle on the fist.
const OPEN_HOTSPOT := Vector2(34, 13)
const GRAB_HOTSPOT := Vector2(34, 29)

static var _open: Texture2D
static var _grab: Texture2D
static var _installed := false
static var _grabbing := false


## Loads the art once and makes the open hand the cursor for arrow and pointing-hand controls.
static func install() -> void:
	if _installed:
		return
	_open = _load_cursor(OPEN_PATH)
	_grab = _load_cursor(GRAB_PATH)
	_installed = true
	if _is_headless():
		return
	_apply(false)


## Switches between the open hand and the fist. Safe to call every frame.
static func set_grabbing(grabbing: bool) -> void:
	if _grabbing == grabbing:
		return
	_grabbing = grabbing
	if not _installed or _is_headless():
		return
	_apply(grabbing)


## Drops the custom cursors and resets the static state. Used by tests and scene teardown.
static func restore() -> void:
	_installed = false
	_grabbing = false
	_open = null
	_grab = null
	if _is_headless():
		return
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		Input.set_custom_mouse_cursor(null, shape)


static func is_installed() -> bool:
	return _installed


static func is_grabbing() -> bool:
	return _grabbing


static func texture(grabbing: bool) -> Texture2D:
	return _grab if grabbing else _open


static func hotspot(grabbing: bool) -> Vector2:
	return GRAB_HOTSPOT if grabbing else OPEN_HOTSPOT


static func _apply(grabbing: bool) -> void:
	var image := _grab if grabbing else _open
	var spot := GRAB_HOTSPOT if grabbing else OPEN_HOTSPOT
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		Input.set_custom_mouse_cursor(image, shape, spot)


static func _load_cursor(path: String) -> Texture2D:
	var source: Texture2D = load(path)
	if source == null:
		push_error("HandCursor: missing cursor texture %s" % path)
		return null
	var image := source.get_image()
	if image == null:
		return source
	image = image.duplicate()
	image.resize(CURSOR_SIZE, CURSOR_SIZE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


static func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
