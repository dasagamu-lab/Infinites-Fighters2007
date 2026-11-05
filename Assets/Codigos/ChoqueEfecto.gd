extends Node2D

# Destello del choque de ataques (parry): un tajo blanco en diagonal, un corte
# cruzado más corto y chispas que salen disparadas. Se dibuja por código en
# píxeles, como HitSpark, para poder cambiarlo luego por un sprite.

@export var duracion : float = 0.32
@export var largo : float = 28.0

var tiempo := 0.0
var direccion := Vector2.RIGHT
var chispas := []

func _ready():
	var angulo = deg_to_rad(randf_range(28.0, 52.0))
	if randf() < 0.5:
		angulo = -angulo
	direccion = Vector2(cos(angulo), -sin(angulo))
	for i in 9:
		var a = randf() * TAU
		chispas.append({
			"dir": Vector2(cos(a), sin(a)),
			"velocidad": randf_range(60.0, 130.0),
			"tamaño": 2.0 if randf() < 0.35 else 1.0,
		})

func _process(delta):
	tiempo += delta
	if tiempo >= duracion:
		queue_free()
		return
	queue_redraw()

func _draw():
	var t = clamp(tiempo / duracion, 0.0, 1.0)
	var alfa = 1.0 - clamp((t - 0.3) / 0.7, 0.0, 1.0)
	var mitad = largo * (0.5 + 0.08 * t)

	# Halo azulado alrededor del tajo
	var mitad_halo = mitad + 2.0
	draw_line((-direccion * mitad_halo).round(), (direccion * mitad_halo).round(),
		Color(0.72, 0.88, 1.0, 0.55 * alfa), max(1.0, round(5.0 * (1.0 - t))))

	# Tajo principal: aparece completo de golpe y se adelgaza mientras se apaga
	draw_line((-direccion * mitad).round(), (direccion * mitad).round(),
		Color(1, 1, 1, alfa), max(1.0, round(3.0 * (1.0 - t))))

	# Corte cruzado: más corto y se apaga antes
	var alfa_cruz = 1.0 - clamp(t / 0.55, 0.0, 1.0)
	if alfa_cruz > 0.0:
		var cruz = Vector2(-direccion.y, direccion.x) * largo * 0.28
		draw_line((-cruz).round(), cruz.round(), Color(1, 1, 1, alfa_cruz), max(1.0, round(2.0 * (1.0 - t))))

	# Destello central
	var radio = round(4.0 * (1.0 - t / 0.4))
	if radio >= 1.0:
		draw_circle(Vector2.ZERO, radio, Color(1, 1, 1, alfa))

	# Chispas
	for chispa in chispas:
		var recorrido = chispa["velocidad"] * tiempo * (1.0 - 0.5 * t)
		var tam = chispa["tamaño"]
		var pos = (chispa["dir"] * recorrido).round()
		draw_rect(Rect2(pos - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), Color(1, 0.97, 0.85, alfa))
