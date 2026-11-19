class_name CombatScreen
extends Control
## First-person combat scene: the player's attack phase and the slime's retaliation.
##
## The slime idles in the dark while the 3D sword and lantern, the 2D bag and the energy
## counter frame the view. The sword spends energy and ends the turn; the lantern is dragged
## into a glowing drop zone for a one-time energy boost, then returns to the hotbar dimmed;
## the bag opens an empty inventory panel. Every sword swing is answered by the slime's hurt
## animation, then its attack and a full-screen claw overlay. Five sword hits kill the slime
## and end the combat in victory. Energy is not refilled: every non-lethal exchange costs 2
## (the sword and the slime's claw), and reaching zero always ends in defeat, even on the
## killing blow.

const IDLE_DIR := "res://assets/Enemies/Slime/Idle/Idle_Slime-%d.png"
const IDLE_FRAMES := 12
const IDLE_FPS := 10.0
const HURT_DIR := "res://assets/Enemies/Slime/Hurt/Slime_hurt-%d.png"
const HURT_FRAMES := 8
const ATTACK_DIR := "res://assets/Enemies/Slime/Attack/Slime_Attack-%d.png"
const ATTACK_FRAMES := 15
const CLAW_DIR := "res://assets/Animated hits/Claw_or_Slash/Clawslice-%d.png"
const CLAW_FRAMES := 6
const ACTION_FPS := 12.0
const START_ENERGY := 8
const LANTERN_GAIN := 3
const LANTERN_DROP_RADIUS := 180.0
const LANTERN_GLOW_SECONDS := 0.35
const LANTERN_RETURN_SECONDS := 0.28
const LANTERN_HIGHLIGHT_TINT := Color(1.15, 1.15, 1.15, 1.0)
const LANTERN_SPENT_TINT := Color(0.55, 0.55, 0.55, 0.45)
const SWORD_DROP_RADIUS := 180.0
const SWORD_RETURN_SECONDS := 0.18
const SWORD_HIGHLIGHT_TINT := Color(1.15, 1.15, 1.15, 1.0)
const IDLE_BOB_SECONDS := 2.4
const IDLE_BOB_FADE_SECONDS := 0.25
const SWORD_IDLE_BOB := 0.08
const LANTERN_IDLE_BOB := 0.09
const SLIME_MAX_HP := 5
const SLIME_ATTACK_DRAIN := 1
const SLIME_TURN_DELAY := 0.2
const CLAW_START_SECONDS := 0.9
const CLAW_SECONDS := 1.0
const DEATH_HOLD_SECONDS := 0.15
const DEATH_FADE_SECONDS := 0.5
const MENU_SCENE := "res://src/scenes/menu.tscn"
const PLAYER_COLOR := Color(0.133, 0.773, 0.369)
const SLIME_COLOR := Color(0.937, 0.267, 0.267)
const CLAW_TINT := Color(0.95, 0.72, 0.72, 1.0)
const CLAW_SHADER := """
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.95, 0.72, 0.72, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float shade = max(tex.r, max(tex.g, tex.b));
	COLOR = vec4(tint.rgb * (0.65 + 0.35 * shade), tex.a * tint.a);
}
"""

enum Phase { PLAYER, SLIME, DEFEAT, VICTORY }
enum Action { SWORD, LANTERN, BAG }

signal action_started(action: int)
signal action_finished(action: int)
signal phase_changed(new_phase: int)
signal slime_hurt_started
signal slime_attack_started
signal slime_died
signal claw_marks_shown
signal claw_marks_hidden

@onready var _slime: AnimatedSprite2D = %Slime
@onready var _claw: AnimatedSprite2D = %ClawMarks
@onready var _energy_count: Label = %EnergyCount
@onready var _phase_label: Label = %PhaseLabel
@onready var _bag_panel: Control = %BagPanel
@onready var _end_overlay: Control = %EndOverlay
@onready var _end_title: Label = %EndTitle
@onready var _end_hint: Label = %EndHint
@onready var _return_button: Button = %ReturnButton
@onready var _sword: SubViewportContainer = $Sword
@onready var _lantern: SubViewportContainer = $Lantern
@onready var _bag: TextureRect = $Bag
@onready var _drop_zone: Control = %DropZone
@onready var _drop_fill: Panel = %DropFill
@onready var _drop_ring: Panel = %DropRing
@onready var _sword_drop_zone: Control = %SwordDropZone
@onready var _sword_drop_fill: Panel = %SwordDropFill
@onready var _sword_drop_ring: Panel = %SwordDropRing
@onready var _lantern_highlight: TextureRect = %LanternHighlight
@onready var _sword_pivot: Node3D = $Sword/SubViewport/SwordPivot
@onready var _sword_model: Node3D = $Sword/SubViewport/SwordPivot/SwordFlip/SwordRoll/SwordModel
@onready var _lantern_model: Node3D = $Lantern/SubViewport/LanternModel
@onready var _glow_light: OmniLight3D = $Lantern/SubViewport/GlowLight

var energy := START_ENERGY
var slime_hp := SLIME_MAX_HP
var phase := Phase.PLAYER
var busy := false
var lantern_used := false

var _sword_base_position := Vector3.ZERO
var _sword_base_rotation := Vector3.ZERO
var _sword_model_base := Vector3.ZERO
var _lantern_model_base := Vector3.ZERO
var _glow_base_energy := 2.0
var _idle_time := 0.0
var _sword_idle_blend := 0.0
var _lantern_idle_blend := 0.0
var _sword_dragging := false
var _sword_home := Vector2.ZERO
var _sword_grab_offset := Vector2.ZERO
var _sword_drop_zone_hot := false
var _sword_drop_zone_tween: Tween
var _lantern_dragging := false
var _lantern_home := Vector2.ZERO
var _lantern_grab_offset := Vector2.ZERO
var _drop_zone_hot := false
var _drop_zone_tween: Tween
var _lantern_highlight_tween: Tween


func _ready() -> void:
	HandCursor.install()
	_sword_base_position = _sword_pivot.position
	_sword_base_rotation = _sword_pivot.rotation
	_sword_model_base = _sword_model.position
	_lantern_model_base = _lantern_model.position
	_glow_base_energy = _glow_light.light_energy
	_sword.gui_input.connect(_on_sword_gui_input)
	_lantern.gui_input.connect(_on_lantern_gui_input)
	_bag.gui_input.connect(_on_bag_gui_input)
	_return_button.pressed.connect(_on_return_to_menu_pressed)
	_slime.sprite_frames = _build_slime_frames()
	_slime.play("idle")
	_claw.sprite_frames = _build_claw_frames()
	_claw.material = _build_claw_material()
	_claw.hide()
	_update_hud()
	_layout_stage()
	resized.connect(_layout_stage)


## Bobs the weapons while the player idles; the spent lantern no longer hovers.
func _process(delta: float) -> void:
	var idling := phase == Phase.PLAYER and not busy
	_idle_time += delta
	_sword_idle_blend = move_toward(_sword_idle_blend, 1.0 if idling else 0.0,
		delta / IDLE_BOB_FADE_SECONDS)
	_lantern_idle_blend = move_toward(_lantern_idle_blend,
		1.0 if idling and not lantern_used else 0.0, delta / IDLE_BOB_FADE_SECONDS)
	var wave := sin(_idle_time * TAU / IDLE_BOB_SECONDS)
	var sword_parent := _sword_model.get_parent() as Node3D
	var sword_up := sword_parent.global_transform.basis.inverse() * Vector3.UP
	_sword_model.position = _sword_model_base + sword_up * (wave * SWORD_IDLE_BOB * _sword_idle_blend)
	_lantern_model.position = _lantern_model_base + Vector3.UP * (wave * LANTERN_IDLE_BOB * _lantern_idle_blend)


## Keeps the slime and the full-screen claw overlay centred as the viewport changes shape.
func _layout_stage() -> void:
	var centre := size * 0.5
	_slime.position = centre
	_claw.position = centre
	var frame := _claw.sprite_frames.get_frame_texture("claw", 0)
	if frame == null:
		return
	var frame_size := frame.get_size()
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return
	var cover := maxf(size.x / frame_size.x, size.y / frame_size.y) * 1.05
	_claw.scale = Vector2.ONE * cover


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		HandCursor.set_grabbing(event.pressed)
	if _sword_dragging:
		if event is InputEventMouseMotion:
			_follow_sword_mouse()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
				and not event.pressed:
			_release_sword()
		return
	if not _lantern_dragging:
		return
	if event is InputEventMouseMotion:
		_follow_mouse()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_release_lantern()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		HandCursor.set_grabbing(false)
		if _lantern_dragging:
			_cancel_lantern_drag()
		if _sword_dragging:
			_cancel_sword_drag()


func _exit_tree() -> void:
	HandCursor.set_grabbing(false)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _sword_dragging:
		_cancel_sword_drag()
		return
	if _lantern_dragging:
		_cancel_lantern_drag()
		return
	if _bag_panel.visible:
		_bag_panel.hide()
		return
	get_tree().change_scene_to_file(MENU_SCENE)


# --- actions -------------------------------------------------------------------------------

func _on_sword_gui_input(event: InputEvent) -> void:
	if _is_left_click(event):
		_start_sword_drag()


func _on_lantern_gui_input(event: InputEvent) -> void:
	if _is_left_click(event):
		_start_lantern_drag()


func _on_bag_gui_input(event: InputEvent) -> void:
	if _is_left_click(event):
		_toggle_bag()


func _is_left_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mouse := event as InputEventMouseButton
	return mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed


## Spends energy on the sword. The lantern is handled by its own drag-and-drop flow.
func _try_sword_swing() -> void:
	if phase != Phase.PLAYER or busy or energy <= 0:
		return
	busy = true
	_bag_panel.hide()
	action_started.emit(Action.SWORD)
	energy -= 1
	slime_hp -= 1
	_update_hud()
	await _play_sword_swing()
	await _play_slime_hurt()
	if slime_hp <= 0:
		await _play_slime_death()
		_end_combat(Phase.DEFEAT if energy <= 0 else Phase.VICTORY)
		action_finished.emit(Action.SWORD)
		return
	if energy <= 0:
		_end_combat(Phase.DEFEAT)
		action_finished.emit(Action.SWORD)
		return
	await _start_slime_turn()
	if phase == Phase.PLAYER:
		busy = false
	action_finished.emit(Action.SWORD)


func _toggle_bag() -> void:
	if phase != Phase.PLAYER or busy:
		return
	_bag_panel.visible = not _bag_panel.visible


## Spends the lantern for the rest of the combat: it greys out and stops taking clicks.
func _spend_lantern() -> void:
	lantern_used = true
	_lantern.modulate = LANTERN_SPENT_TINT
	_lantern.mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- lantern drag ---------------------------------------------------------------------------

## Picks the lantern up, highlights it and reveals the drop zone near the middle of the screen.
func _start_lantern_drag() -> void:
	if phase != Phase.PLAYER or busy or energy <= 0 or lantern_used:
		return
	busy = true
	_bag_panel.hide()
	_lantern_dragging = true
	_lantern_home = _lantern.position
	_lantern_grab_offset = get_global_mouse_position() - _lantern.global_position
	_lantern.z_index = 10
	_highlight_lantern()
	_show_drop_zone()
	_update_drop_zone_feedback()


## Keeps the grabbed point of the lantern under the mouse while the drag is active.
func _follow_mouse() -> void:
	var half := _lantern.size * 0.5
	_lantern.global_position = (get_global_mouse_position() - _lantern_grab_offset) \
		.clamp(-half, size - half)
	_update_drop_zone_feedback()


## Drops the lantern: activating it inside the circle, otherwise sending it home.
func _release_lantern() -> void:
	if not _lantern_dragging:
		return
	_lantern_dragging = false
	var in_zone := _is_lantern_over_drop_zone()
	_set_drop_zone_hot(false)
	_hide_drop_zone()
	if in_zone:
		_activate_lantern()
	else:
		_return_lantern_home()


func _cancel_lantern_drag() -> void:
	if not _lantern_dragging:
		return
	_lantern_dragging = false
	_set_drop_zone_hot(false)
	_hide_drop_zone()
	_return_lantern_home()


func _drop_zone_center() -> Vector2:
	return _drop_zone.position + _drop_zone.size * 0.5


func _is_lantern_over_drop_zone() -> bool:
	var lantern_center := _lantern.position + _lantern.size * 0.5
	return lantern_center.distance_to(_drop_zone_center()) <= LANTERN_DROP_RADIUS


func _highlight_lantern() -> void:
	if _lantern_highlight_tween != null and _lantern_highlight_tween.is_valid():
		_lantern_highlight_tween.kill()
	_lantern_highlight_tween = create_tween()
	_lantern_highlight_tween.set_parallel(true)
	_lantern_highlight_tween.tween_property(_lantern, "modulate", LANTERN_HIGHLIGHT_TINT, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lantern_highlight_tween.tween_property(_lantern_highlight, "modulate:a", 1.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _show_drop_zone() -> void:
	_drop_zone_hot = false
	_drop_fill.self_modulate = Color.WHITE
	_drop_ring.self_modulate = Color.WHITE
	if _drop_zone_tween != null and _drop_zone_tween.is_valid():
		_drop_zone_tween.kill()
	_drop_zone.show()
	_drop_zone.modulate.a = 0.0
	_drop_zone_tween = create_tween()
	_drop_zone_tween.tween_property(_drop_zone, "modulate:a", 1.0, 0.15)


func _hide_drop_zone() -> void:
	if _drop_zone_tween != null and _drop_zone_tween.is_valid():
		_drop_zone_tween.kill()
	if not _drop_zone.visible:
		return
	_drop_zone_tween = create_tween()
	_drop_zone_tween.tween_property(_drop_zone, "modulate:a", 0.0, 0.12)
	_drop_zone_tween.tween_callback(_drop_zone.hide)


func _update_drop_zone_feedback() -> void:
	_set_drop_zone_hot(_is_lantern_over_drop_zone())


func _set_drop_zone_hot(hot: bool) -> void:
	if _drop_zone_hot == hot:
		return
	_drop_zone_hot = hot
	var tint := Color(1.4, 1.4, 1.4, 1.0) if hot else Color.WHITE
	_drop_fill.self_modulate = tint
	_drop_ring.self_modulate = tint


## Glows at the centre for a beat, then returns home faded and spent.
func _activate_lantern() -> void:
	action_started.emit(Action.LANTERN)
	energy += LANTERN_GAIN - 1
	_update_hud()
	if _lantern_highlight_tween != null and _lantern_highlight_tween.is_valid():
		_lantern_highlight_tween.kill()
	var tween := create_tween()
	tween.tween_property(_lantern, "position", _lantern_center_position(), 0.15) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_glow_light, "light_energy", _glow_base_energy + 3.0, 0.15)
	tween.parallel().tween_property(_lantern_highlight, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(_lantern, "modulate", LANTERN_HIGHLIGHT_TINT, 0.15)
	tween.tween_interval(LANTERN_GLOW_SECONDS)
	tween.tween_property(_lantern, "position", _lantern_home, LANTERN_RETURN_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_glow_light, "light_energy", _glow_base_energy,
		LANTERN_RETURN_SECONDS)
	tween.parallel().tween_property(_lantern_highlight, "modulate:a", 0.0, LANTERN_RETURN_SECONDS)
	tween.parallel().tween_property(_lantern, "modulate", LANTERN_SPENT_TINT,
		LANTERN_RETURN_SECONDS)
	await tween.finished
	_lantern.z_index = 0
	_lantern_highlight.modulate.a = 0.0
	_spend_lantern()
	if phase == Phase.PLAYER:
		busy = false
	action_finished.emit(Action.LANTERN)


## Tweens the lantern back to its hotbar slot, clearing the drag highlight.
func _return_lantern_home() -> void:
	if _lantern_highlight_tween != null and _lantern_highlight_tween.is_valid():
		_lantern_highlight_tween.kill()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_lantern, "position", _lantern_home, LANTERN_RETURN_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_lantern, "modulate", Color.WHITE, LANTERN_RETURN_SECONDS)
	tween.tween_property(_lantern_highlight, "modulate:a", 0.0, LANTERN_RETURN_SECONDS * 0.6)
	await tween.finished
	_lantern.z_index = 0
	_lantern.modulate = Color.WHITE
	_lantern_highlight.modulate.a = 0.0
	if phase == Phase.PLAYER:
		busy = false


# --- sword drag -----------------------------------------------------------------------------

## Picks the sword up so it can be dragged onto the red strike marker.
func _start_sword_drag() -> void:
	if phase != Phase.PLAYER or busy or energy <= 0:
		return
	busy = true
	_bag_panel.hide()
	_sword_dragging = true
	_sword_home = _sword.position
	_sword_grab_offset = get_global_mouse_position() - _sword.global_position
	_sword.z_index = 10
	_sword.modulate = SWORD_HIGHLIGHT_TINT
	_show_sword_drop_zone()
	_update_sword_drop_zone_feedback()


## Keeps the grabbed point of the sword under the mouse while the drag is active.
func _follow_sword_mouse() -> void:
	var half := _sword.size * 0.5
	_sword.global_position = (get_global_mouse_position() - _sword_grab_offset) \
		.clamp(-half, size - half)
	_update_sword_drop_zone_feedback()


## Drops the sword: a hit inside the red marker triggers the swing, otherwise it goes home.
func _release_sword() -> void:
	if not _sword_dragging:
		return
	_sword_dragging = false
	var in_zone := _is_sword_over_drop_zone()
	_set_sword_drop_zone_hot(false)
	_hide_sword_drop_zone()
	await _return_sword_home()
	busy = false
	if in_zone:
		_try_sword_swing()


func _cancel_sword_drag() -> void:
	if not _sword_dragging:
		return
	_sword_dragging = false
	_set_sword_drop_zone_hot(false)
	_hide_sword_drop_zone()
	await _return_sword_home()
	busy = false


func _sword_drop_zone_center() -> Vector2:
	return _sword_drop_zone.position + _sword_drop_zone.size * 0.5


func _is_sword_over_drop_zone() -> bool:
	var sword_center := _sword.position + _sword.size * 0.5
	return sword_center.distance_to(_sword_drop_zone_center()) <= SWORD_DROP_RADIUS


func _show_sword_drop_zone() -> void:
	_sword_drop_zone_hot = false
	_sword_drop_fill.self_modulate = Color.WHITE
	_sword_drop_ring.self_modulate = Color.WHITE
	if _sword_drop_zone_tween != null and _sword_drop_zone_tween.is_valid():
		_sword_drop_zone_tween.kill()
	_sword_drop_zone.show()
	_sword_drop_zone.modulate.a = 0.0
	_sword_drop_zone_tween = create_tween()
	_sword_drop_zone_tween.tween_property(_sword_drop_zone, "modulate:a", 1.0, 0.15)


func _hide_sword_drop_zone() -> void:
	if _sword_drop_zone_tween != null and _sword_drop_zone_tween.is_valid():
		_sword_drop_zone_tween.kill()
	if not _sword_drop_zone.visible:
		return
	_sword_drop_zone_tween = create_tween()
	_sword_drop_zone_tween.tween_property(_sword_drop_zone, "modulate:a", 0.0, 0.12)
	_sword_drop_zone_tween.tween_callback(_sword_drop_zone.hide)


func _update_sword_drop_zone_feedback() -> void:
	_set_sword_drop_zone_hot(_is_sword_over_drop_zone())


func _set_sword_drop_zone_hot(hot: bool) -> void:
	if _sword_drop_zone_hot == hot:
		return
	_sword_drop_zone_hot = hot
	var tint := Color(1.4, 1.4, 1.4, 1.0) if hot else Color.WHITE
	_sword_drop_fill.self_modulate = tint
	_sword_drop_ring.self_modulate = tint


## Tweens the sword back to its hotbar slot, clearing the drag highlight.
func _return_sword_home() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sword, "position", _sword_home, SWORD_RETURN_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sword, "modulate", Color.WHITE, SWORD_RETURN_SECONDS)
	await tween.finished
	_sword.z_index = 0
	_sword.modulate = Color.WHITE


func _on_return_to_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


# --- slime turn ----------------------------------------------------------------------------

## Plays the hurt one-shot, then returns the slime to its idle loop while it is alive.
func _play_slime_hurt() -> void:
	_slime.play("hurt")
	slime_hurt_started.emit()
	await _slime.animation_finished
	if slime_hp > 0:
		_slime.play("idle")


## Holds the last hurt frame, then fades the slime out. There is no death animation yet.
func _play_slime_death() -> void:
	_slime.stop()
	slime_died.emit()
	await get_tree().create_timer(DEATH_HOLD_SECONDS).timeout
	var tween := create_tween()
	tween.tween_property(_slime, "modulate:a", 0.0, DEATH_FADE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	_slime.hide()


## Runs the slime's retaliation: a short beat, its attack, then the claw overlay.
func _start_slime_turn() -> void:
	phase = Phase.SLIME
	_bag_panel.hide()
	_update_hud()
	phase_changed.emit(phase)
	await get_tree().create_timer(SLIME_TURN_DELAY).timeout
	_slime.play("attack")
	slime_attack_started.emit()
	await get_tree().create_timer(CLAW_START_SECONDS).timeout
	_show_claw_marks()
	await _slime.animation_finished
	_slime.play("idle")
	var claw_remaining := CLAW_SECONDS - (ATTACK_FRAMES / ACTION_FPS - CLAW_START_SECONDS)
	if claw_remaining > 0.0:
		await get_tree().create_timer(claw_remaining).timeout
	_hide_claw_marks()
	if energy <= 0:
		_end_combat(Phase.DEFEAT)
		return
	phase = Phase.PLAYER
	_update_hud()
	phase_changed.emit(phase)


## The claw landing is what drains energy; zero is checked after the overlay finishes.
func _show_claw_marks() -> void:
	energy = maxi(energy - SLIME_ATTACK_DRAIN, 0)
	_update_hud()
	_claw.show()
	_claw.play("claw")
	claw_marks_shown.emit()


func _hide_claw_marks() -> void:
	_claw.hide()
	_claw.stop()
	claw_marks_hidden.emit()


## Locks input and shows the shared end panel with the outcome's title, hint and colour.
func _end_combat(outcome: Phase) -> void:
	phase = outcome
	busy = true
	_bag_panel.hide()
	_update_hud()
	if outcome == Phase.VICTORY:
		_end_title.text = "VICTORY"
		_end_title.add_theme_color_override("font_color", PLAYER_COLOR)
		_end_hint.text = "The slime melts into the dark."
	else:
		_end_title.text = "DEFEAT"
		_end_title.add_theme_color_override("font_color", SLIME_COLOR)
		_end_hint.text = "Your energy ran out."
	_end_overlay.show()
	phase_changed.emit(phase)


func _update_hud() -> void:
	_energy_count.text = str(energy)
	var text := "YOUR TURN"
	var color := PLAYER_COLOR
	if phase == Phase.SLIME:
		text = "SLIME TURN"
		color = SLIME_COLOR
	elif phase == Phase.DEFEAT:
		text = "DEFEAT"
		color = SLIME_COLOR
	elif phase == Phase.VICTORY:
		text = "VICTORY"
		color = PLAYER_COLOR
	_phase_label.text = text
	_phase_label.add_theme_color_override("font_color", color)


# --- animations ----------------------------------------------------------------------------

## Where the whole sword winds up: above the slime, ready to chop down.
func _sword_raise_position() -> Vector2:
	return Vector2(_slime.position.x - _sword.size.x * 0.9,
		_slime.position.y - _sword.size.y)


## Where the whole sword ends its chop: below and right of the slime's centre.
func _sword_slash_position() -> Vector2:
	return Vector2(_slime.position.x - _sword.size.x * 0.1,
		_slime.position.y + _sword.size.y * 0.45)


func _play_sword_swing() -> void:
	var base := _sword.position
	var tween := create_tween()
	tween.tween_property(_sword, "position", _sword_raise_position(), 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_sword_pivot, "rotation:z", _sword_base_rotation.z + 0.18, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_sword_pivot, "position",
		_sword_base_position + Vector3(-0.04, 0.03, 0.0), 0.16)
	tween.tween_property(_sword, "position", _sword_slash_position(), 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_sword_pivot, "rotation:z", _sword_base_rotation.z - 0.85, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_sword_pivot, "position",
		_sword_base_position + Vector3(0.35, -0.18, 0.0), 0.18)
	tween.tween_property(_sword, "position", base, 0.28) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_sword_pivot, "rotation:z", _sword_base_rotation.z, 0.28) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_sword_pivot, "position", _sword_base_position, 0.28)
	await tween.finished


## Top-left that centres the lantern inside the drop zone.
func _lantern_center_position() -> Vector2:
	return _drop_zone_center() - _lantern.size * 0.5


# --- sprite frames -------------------------------------------------------------------------

## Builds the slime animations at runtime so the scene file stays free of frame plumbing.
func _build_slime_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_animation(frames, "idle", IDLE_DIR, IDLE_FRAMES, IDLE_FPS, true)
	_add_animation(frames, "hurt", HURT_DIR, HURT_FRAMES, ACTION_FPS, false)
	_add_animation(frames, "attack", ATTACK_DIR, ATTACK_FRAMES, ACTION_FPS, false)
	return frames


func _build_claw_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_animation(frames, "claw", CLAW_DIR, CLAW_FRAMES, ACTION_FPS, false)
	return frames


func _add_animation(frames: SpriteFrames, _name: String, dir: String, count: int,
		fps: float, loop: bool) -> void:
	frames.add_animation(_name)
	frames.set_animation_speed(_name, fps)
	frames.set_animation_loop(_name, loop)
	for i in range(1, count + 1):
		frames.add_frame(_name, load(dir % i))


## Recolours the black claw art so it reads against the dark scene.
func _build_claw_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = CLAW_SHADER
	var _material := ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("tint", CLAW_TINT)
	return _material
