extends Node
## Menu hub. Also installs the hand cursor for the whole session.

func _ready() -> void:
	HandCursor.install()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		HandCursor.set_grabbing(event.pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		HandCursor.set_grabbing(false)


func _exit_tree() -> void:
	HandCursor.set_grabbing(false)


func _on_map_pressed() -> void:
	get_tree().change_scene_to_file("res://src/scenes/map_screen.tscn")


func _on_combat_pressed() -> void:
	get_tree().change_scene_to_file("res://src/scenes/combat_screen.tscn")
