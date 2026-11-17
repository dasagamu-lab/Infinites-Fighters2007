extends Area2D

@export var velocidad : float = 330.0
@export var daño : int = 45
@export var duración_hitstun : float = 1.2
@export var ignora_bloqueo : bool = true
@export var altura : float = 56.0
@export var alcance_extra : float = 20.0

var owner_player : Jugador
var tiempo := 0.0
var radio := 2.0
var radio_maximo := 200.0
var cuadro_visual := 0
var victimas_afectadas := {}
var area_colision : CollisionShape2D
var rectangulo : RectangleShape2D

func _ready() -> void:
	add_to_group("P_Punch")
	collision_layer = 8 if owner_player.player_id == 1 else 16
	collision_mask = 4 if owner_player.player_id == 1 else 2
	monitoring = true

	area_colision = CollisionShape2D.new()
	rectangulo = RectangleShape2D.new()
	rectangulo.size = Vector2(radio * 2.0, altura)
	area_colision.shape = rectangulo
	add_child(area_colision)
	area_entered.connect(_on_area_entered)
	var distancia_izquierda = global_position.x - owner_player.limite_izquierdo
	var distancia_derecha = owner_player.limite_derecho - global_position.x
	radio_maximo = maxf(distancia_izquierda, distancia_derecha) + alcance_extra

func _physics_process(delta: float) -> void:
	tiempo += delta
	radio = minf(radio + velocidad * delta, radio_maximo)
	rectangulo.size = Vector2(radio * 2.0, altura)
	cuadro_visual = int(tiempo * 18.0) % 4
	queue_redraw()

	if owner_player == null or not is_instance_valid(owner_player):
		queue_free()
		return
	if radio >= radio_maximo:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var victima = area.get_parent()
	if not (victima is Jugador) or victima == owner_player:
		return
	var id_victima = victima.get_instance_id()
	if victimas_afectadas.has(id_victima):
		return
	victimas_afectadas[id_victima] = true
	var rayos = preload("res://Assets/Codigos/RayoAturdimiento.gd").new()
	rayos.duracion = duración_hitstun
	rayos.position = Vector2.ZERO
	rayos.z_index = 20
	victima.add_child(rayos)

func _draw() -> void:
	var pulso = [0.0, 1.0, 0.55, -0.5][cuadro_visual]
	var t = clampf(radio / maxf(radio_maximo, 1.0), 0.0, 1.0)
	var alfa = 1.0 - t * 0.5
	var alto_frente = altura * 0.62
	for estela in range(3):
		var radio_frente = radio - float(estela) * 9.0
		if radio_frente <= 1.0:
			continue
		var peso = 1.0 - float(estela) * 0.27
		var color_borde = Color(0.0, 0.48, 0.06, alfa * peso)
		var color_nucleo = Color(0.05, 1.0, 0.22, alfa * peso)
		var blanco = Color(0.82, 1.0, 0.77, alfa * peso)

		for lado in [-1.0, 1.0]:
			var puntos: Array[Vector2] = []
			for i in range(33):
				var u = -1.0 + float(i) / 16.0
				var frente = radio_frente * sqrt(maxf(0.0, 1.0 - u * u))
				var ondulacion = sin(u * PI * 5.0 + tiempo * 14.0 - estela * 0.7) \
					* 1.7 * sqrt(maxf(0.0, 1.0 - u * u))
				puntos.append(Vector2(lado * (frente + ondulacion), u * alto_frente))

			for i in range(puntos.size() - 1):
				draw_line(puntos[i], puntos[i + 1], color_borde, 7.0 + pulso)
				draw_line(puntos[i], puntos[i + 1], color_nucleo, 3.0 + pulso * 0.35)
				if i % 2 == 0:
					draw_line(puntos[i], puntos[i + 1], blanco, 1.0)

	if radio <= 14.0:
		draw_circle(Vector2.ZERO, 4.0 + pulso, Color(0.05, 1.0, 0.22, alfa))
