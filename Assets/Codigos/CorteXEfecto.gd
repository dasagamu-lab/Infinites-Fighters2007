extends Node2D

@export var duracion : float = 0.34
@export var largo : float = 54.0

var tiempo := 0.0

func _process(delta: float) -> void:
	tiempo += delta
	if tiempo >= duracion:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t = clamp(tiempo / duracion, 0.0, 1.0)
	var apertura = lerp(0.08, 1.0, min(1.0, t * 1.8))
	var alfa = 1.0 - t
	var mitad = largo * apertura * 0.5
	var sube = mitad * 0.62
	var azul = Color(0.0, 0.55, 0.08, 0.8 * alfa)
	var verde = Color(0.05, 1.0, 0.22, alfa)
	var nucleo = Color(0.83, 1.0, 0.7, alfa)
	var grosor = 7.0 * (1.0 - t) + 1.0

	var diagonal_izquierda = Vector2(-mitad, -sube)
	var diagonal_derecha = Vector2(mitad, -sube)
	var pie_izquierdo = Vector2(-mitad, sube)
	var pie_derecho = Vector2(mitad, sube)
	for trazo in [[diagonal_izquierda, pie_derecho], [diagonal_derecha, pie_izquierdo]]:
		var inicio: Vector2 = trazo[0]
		var fin: Vector2 = trazo[1]
		var centro = (inicio + fin) * 0.5
		draw_line(inicio, fin, azul, grosor)
		draw_line(inicio, centro, verde, 3.0 * (1.0 - t) + 1.0)
		draw_line(centro, fin, verde, 3.0 * (1.0 - t) + 1.0)
		draw_line(inicio, fin, nucleo, 1.0)

	draw_circle(Vector2.ZERO, max(1.0, round(5.0 * (1.0 - t))), nucleo)
