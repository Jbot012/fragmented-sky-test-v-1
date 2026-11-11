class_name CombatScreen
extends Control
## First-person combat scene: the player's attack phase and the slime's retaliation.
##
## The slime idles in the dark while the 3D sword and lantern, the 2D bag and the energy
## counter frame the view. The sword spends energy and ends the turn; the lantern is a
## one-time energy boost; the bag opens an empty inventory panel. Every sword swing is
## answered by the slime's hurt animation, then its attack and a full-screen claw overlay.
## Five sword hits kill the slime and end the combat in victory. Energy is not refilled:
## every non-lethal exchange costs 2 (the sword and the slime's claw), and reaching zero
## always ends in defeat, even on the killing blow.

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
@onready var _sword_pivot: Node3D = $Sword/SubViewport/SwordPivot
@onready var _lantern_model: Node3D = $Lantern/SubViewport/LanternModel
@onready var _glow_light: OmniLight3D = $Lantern/SubViewport/GlowLight

var energy := START_ENERGY
var slime_hp := SLIME_MAX_HP
var phase := Phase.PLAYER
var busy := false
var lantern_used := false

var _sword_base_position := Vector3.ZERO
var _sword_base_rotation := Vector3.ZERO
var _lantern_base_position := Vector3.ZERO
var _glow_base_energy := 2.0


func _ready() -> void:
	HandCursor.install()
	_sword_base_position = _sword_pivot.position
	_sword_base_rotation = _sword_pivot.rotation
	_lantern_base_position = _lantern_model.position
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		HandCursor.set_grabbing(false)


func _exit_tree() -> void:
	HandCursor.set_grabbing(false)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _bag_panel.visible:
		_bag_panel.hide()
		return
	get_tree().change_scene_to_file(MENU_SCENE)


# --- actions -------------------------------------------------------------------------------

func _on_sword_gui_input(event: InputEvent) -> void:
	if _is_left_click(event):
		_try_action(Action.SWORD)


func _on_lantern_gui_input(event: InputEvent) -> void:
	if _is_left_click(event):
		_try_action(Action.LANTERN)


func _on_bag_gui_input(event: InputEvent) -> void:
	if _is_left_click(event):
		_toggle_bag()


func _is_left_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mouse := event as InputEventMouseButton
	return mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed


## Spends energy on the sword or lantern. The bag is free and toggles its panel instead.
func _try_action(action: Action) -> void:
	if phase != Phase.PLAYER or busy or energy <= 0:
		return
	if action == Action.LANTERN and lantern_used:
		return
	busy = true
	_bag_panel.hide()
	action_started.emit(action)
	match action:
		Action.SWORD:
			energy -= 1
			slime_hp -= 1
			_update_hud()
			await _play_sword_swing()
			await _play_slime_hurt()
			if slime_hp <= 0:
				await _play_slime_death()
				_end_combat(Phase.DEFEAT if energy <= 0 else Phase.VICTORY)
				action_finished.emit(action)
				return
			if energy <= 0:
				_end_combat(Phase.DEFEAT)
				action_finished.emit(action)
				return
			await _start_slime_turn()
		Action.LANTERN:
			energy += LANTERN_GAIN - 1
			_update_hud()
			await _play_lantern_pull()
			_spend_lantern()
	if phase == Phase.PLAYER:
		busy = false
	action_finished.emit(action)


func _toggle_bag() -> void:
	if phase != Phase.PLAYER or busy:
		return
	_bag_panel.visible = not _bag_panel.visible


## Spends the lantern for the rest of the combat: it dims and stops taking clicks.
func _spend_lantern() -> void:
	lantern_used = true
	_lantern.modulate = Color(1.0, 1.0, 1.0, 0.35)
	_lantern.mouse_filter = Control.MOUSE_FILTER_IGNORE


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
func _end_combat(outcome: int) -> void:
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

func _play_sword_swing() -> void:
	var tween := create_tween()
	tween.tween_property(_sword_pivot, "rotation:z", _sword_base_rotation.z + 0.18, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_sword_pivot, "position",
		_sword_base_position + Vector3(-0.04, -0.03, 0.0), 0.10)
	tween.tween_property(_sword_pivot, "rotation:z", _sword_base_rotation.z - 0.85, 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_sword_pivot, "position",
		_sword_base_position + Vector3(0.35, 0.18, 0.0), 0.16)
	tween.tween_property(_sword_pivot, "rotation:z", _sword_base_rotation.z, 0.28) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_sword_pivot, "position", _sword_base_position, 0.28)
	await tween.finished


func _play_lantern_pull() -> void:
	var tween := create_tween()
	tween.tween_property(_lantern_model, "position",
		_lantern_base_position + Vector3(0.0, 0.08, 0.55), 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_lantern_model, "scale", Vector3.ONE * 1.12, 0.18)
	tween.parallel().tween_property(_glow_light, "light_energy", _glow_base_energy + 1.2, 0.18)
	tween.tween_property(_lantern_model, "position", _lantern_base_position, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_lantern_model, "scale", Vector3.ONE, 0.30)
	tween.parallel().tween_property(_glow_light, "light_energy", _glow_base_energy, 0.30)
	await tween.finished


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


func _add_animation(frames: SpriteFrames, name: String, dir: String, count: int,
		fps: float, loop: bool) -> void:
	frames.add_animation(name)
	frames.set_animation_speed(name, fps)
	frames.set_animation_loop(name, loop)
	for i in range(1, count + 1):
		frames.add_frame(name, load(dir % i))


## Recolours the black claw art so it reads against the dark scene.
func _build_claw_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = CLAW_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", CLAW_TINT)
	return material
