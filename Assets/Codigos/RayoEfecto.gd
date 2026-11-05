extends Node2D

# Rayo del código secreto (S, A, N, T, O): cae del cielo sobre el personaje, ilumina
# la pantalla y deja chispas en el piso. Se dibuja por código en píxeles, como ChoqueEfecto.
# El nodo se coloca en los pies del personaje; el rayo baja desde "altura" px más arriba.

@export var duracion : float = 0.55
@export var altura : float = 240.0

var tiempo := 0.0
var puntos := []
var ramas := []
var chispas := []
var destello : ColorRect

func _ready():
	generar_rayo()
	for i in 14:
		var a = randf_range(PI * 1.05, PI * 1.95)
		chispas.append({
			"dir": Vector2(cos(a), sin(a)),
			"velocidad": randf_range(50.0, 140.0),
			"tamaño": 2.0 if randf() < 0.35 else 1.0,
		})
	# Destello blanco de toda la pantalla (encima del escenario y de los personajes).
	var capa = CanvasLayer.new()
	capa.layer = 50
	add_child(capa)
	destello = ColorRect.new()
	destello.color = Color(1, 1, 1, 0.85)
	destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	destello.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(destello)

# Zigzag del rayo: tramos cortos con desvíos al azar, y dos ramas que se abren.
func generar_rayo() -> void:
	puntos.clear()
	ramas.clear()
	var y := -altura
	var x := randf_range(-10.0, 10.0)
	puntos.append(Vector2(x, y))
	while y < 0.0:
		y = min(y + randf_range(12.0, 24.0), 0.0)
		x = clamp(x + randf_range(-9.0, 9.0), -16.0, 16.0)
		if y >= 0.0:
			x = 0.0
		puntos.append(Vector2(x, y).round())
	for k in 2:
		var i = randi_range(2, max(2, puntos.size() - 3))
		var inicio: Vector2 = puntos[i]
		var lado = -1.0 if k == 0 else 1.0
		var rama = [inicio]
		var p = inicio
		for j in 3:
			p += Vector2(lado * randf_range(5.0, 10.0), randf_range(6.0, 12.0))
			rama.append(p.round())
		ramas.append(rama)

func _process(delta):
	tiempo += delta
	if tiempo >= duracion:
		queue_free()
		return
	# El rayo parpadea: cambia de forma un par de veces mientras cae.
	if int(tiempo / 0.08) != int((tiempo - delta) / 0.08) and tiempo < 0.25:
		generar_rayo()
	destello.color.a = 0.85 * (1.0 - clamp(tiempo / 0.22, 0.0, 1.0))
	queue_redraw()

func _draw():
	var t = clamp(tiempo / duracion, 0.0, 1.0)
	var alfa = 1.0 - clamp((t - 0.35) / 0.65, 0.0, 1.0)
	var grosor = max(1.0, round(3.0 * (1.0 - t)))
	# Halo azulado y núcleo blanco.
	for i in puntos.size() - 1:
		draw_line(puntos[i], puntos[i + 1], Color(0.55, 0.8, 1.0, 0.6 * alfa), grosor + 3.0)
	for rama in ramas:
		for i in rama.size() - 1:
			draw_line(rama[i], rama[i + 1], Color(0.55, 0.8, 1.0, 0.5 * alfa), grosor + 1.0)
	for i in puntos.size() - 1:
		draw_line(puntos[i], puntos[i + 1], Color(1, 1, 1, alfa), grosor)
	for rama in ramas:
		for i in rama.size() - 1:
			draw_line(rama[i], rama[i + 1], Color(1, 1, 1, alfa), max(1.0, grosor - 1.0))
	# Impacto en el piso: un anillo que se abre y chispas que saltan.
	var radio = round(4.0 + 22.0 * t)
	draw_arc(Vector2.ZERO, radio, PI, TAU, 16, Color(0.8, 0.93, 1.0, alfa), 1.0)
	for chispa in chispas:
		var recorrido = chispa["velocidad"] * tiempo * (1.0 - 0.5 * t)
		var pos = (chispa["dir"] * recorrido + Vector2(0, 120.0 * tiempo * tiempo)).round()
		var tam = chispa["tamaño"]
		draw_rect(Rect2(pos - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), Color(0.85, 0.95, 1.0, alfa))
