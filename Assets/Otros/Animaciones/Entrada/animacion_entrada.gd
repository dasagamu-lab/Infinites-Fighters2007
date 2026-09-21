extends Node2D

func _input(event):
	if(event is InputEventKey):
		go_title_screen()

func go_title_screen():
	get_tree().change_scene_to_file("res://Assets/Otros/Animaciones/Menu/menu.tscn")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	go_title_screen()
	pass
