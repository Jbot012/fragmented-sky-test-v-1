extends Node

func _on_map_pressed() -> void:
	get_tree().change_scene_to_file("res://src/scenes/map_screen.tscn")
