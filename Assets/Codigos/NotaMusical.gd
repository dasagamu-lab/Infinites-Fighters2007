extends Node2D

# Nota musical que sale del bafle mientras Samuel canta: sube haciendo eses y se apaga.
# Pixel art dibujado por código (corchea o semicorchea).

@export var duracion : float = 1.4
@export var color : Color = Color(0.36, 0.82, 1.0, 1.0)

# 1 = color de la nota, 2 = brillo. Columnas x 0..4, filas y 0..6 (cabeza abajo a la izquierda).
const CORCHEA := [
	"..12.",
	"..1.1",
	"..1..",
	"..1..",
	".11..",
	"111..",
	".1...",
]
const DOBLE := [
	".1111",
	".1..1",
	".1111",
	".1..1",
	"11.11",
	"1111.",
	"1..1.",
]

var tiempo := 0.0
var forma : Array = CORCHEA
var lado := 1.0
var origen := Vector2.ZERO

func _ready():
	forma = CORCHEA if randf() < 0.65 else DOBLE
	lado = -1.0 if randf() < 0.5 else 1.0
	origen = global_position

func _process(delta):
	tiempo += delta
	if tiempo >= duracion:
		queue_free()
		return
	var t = tiempo / duracion
	global_position = (origen + Vector2(lado * 4.0 * sin(t * TAU * 1.2) + lado * 6.0 * t, -26.0 * t)).round()
	queue_redraw()

func _draw():
	var t = tiempo / duracion
	var alfa = 1.0 - clamp((t - 0.55) / 0.45, 0.0, 1.0)
	var brillo = Color(1, 1, 1, alfa)
	var base = Color(color.r, color.g, color.b, alfa)
	for y in forma.size():
		var fila: String = forma[y]
		for x in fila.length():
			var c = fila[x]
			if c == "1":
				draw_rect(Rect2(x - 2, y - 6, 1, 1), base)
			elif c == "2":
				draw_rect(Rect2(x - 2, y - 6, 1, 1), brillo)
