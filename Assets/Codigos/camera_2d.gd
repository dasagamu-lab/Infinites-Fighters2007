extends Camera2D

var shake_intensidad := 0.0
var shake_tiempo := 0.0

func sacudir(intensidad: float = 8.0, duracion: float = 0.2):
	shake_intensidad = intensidad
	shake_tiempo = duracion

func _process(delta):
	if shake_tiempo > 0:
		shake_tiempo -= delta
		offset = Vector2(
			randf_range(-shake_intensidad, shake_intensidad),
			randf_range(-shake_intensidad, shake_intensidad)
		)
	else:
		offset = Vector2.ZERO
