extends Control


func _on_jugar_pressed() -> void:
	AdministradorPartida.modo_entrenamiento = false
	get_tree().change_scene_to_file("res://Assets/Escenas/Selectorpersonaje/SelectorPersonajes.tscn")


func _on_entrenamiento_pressed() -> void:
	AdministradorPartida.modo_entrenamiento = true
	get_tree().change_scene_to_file("res://Assets/Escenas/Selectorpersonaje/SelectorPersonajes.tscn")


func _on_opciones_pressed() -> void:
	$OpcionesAviso.popup_centered()


func _on_salir_pressed() -> void:
	get_tree().quit()
