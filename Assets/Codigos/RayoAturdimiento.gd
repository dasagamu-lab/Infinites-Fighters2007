extends Node2D

@export var duracion : float = 1.2

var tiempo := 0.0
var fase := 0

func _process(delta: float) -> void:
	tiempo += delta
	if tiempo >= duracion:
		queue_free()
		return
	fase = int(tiempo * 24.0) % 4
	queue_redraw()

func _draw() -> void:
	var restante = clamp(1.0 - tiempo / duracion, 0.0, 1.0)
	var alfa = 0.55 + 0.45 * abs(sin(tiempo * 33.0))
	alfa *= min(1.0, restante * 5.0)
	var verde = Color(0.05, 1.0, 0.22, alfa)
	var verde_sombra = Color(0.0, 0.55, 0.08, alfa)
	var blanco = Color(0.9, 1.0, 0.85, alfa)
	# Los trazos recorren desde la cabeza hasta los pies para que la descarga
	# se lea sobre todo el cuerpo, no como un destello pequeño en el torso.
	var rutas = [
		[Vector2(-12, -44), Vector2(-7, -34), Vector2(-11, -24), Vector2(-6, -14), Vector2(-10, -4), Vector2(-5, 7), Vector2(-9, 18), Vector2(-4, 29)],
		[Vector2(12, -42), Vector2(7, -33), Vector2(11, -23), Vector2(6, -13), Vector2(10, -3), Vector2(5, 8), Vector2(9, 19), Vector2(4, 30)],
		[Vector2(-10, -32), Vector2(-4, -25), Vector2(-8, -17), Vector2(0, -10), Vector2(7, -17), Vector2(10, -8), Vector2(4, 1), Vector2(9, 10)],
		[Vector2(9, -39), Vector2(3, -31), Vector2(8, -23), Vector2(2, -15), Vector2(-5, -8), Vector2(0, 0), Vector2(-7, 9), Vector2(-3, 20)]
	]

	for indice in 3:
		var ruta : Array = rutas[(fase + indice) % rutas.size()]
		for i in range(ruta.size() - 1):
			draw_line(ruta[i], ruta[i + 1], verde_sombra, 4.0)
			draw_line(ruta[i], ruta[i + 1], verde, 2.0)
			if i % 2 == 0:
				draw_line(ruta[i], ruta[i + 1], blanco, 1.0)
