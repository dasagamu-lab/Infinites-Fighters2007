extends Area2D

# Muñeco de entrenamiento: recibe los golpes como un rival (congelado, temblor y chispa),
# nunca muere y avisa el daño del golpe y del combo para mostrarlo en pantalla.
signal golpe_recibido(daño: int, golpes_combo: int, daño_combo: int)

# Aturdimiento tras cada golpe, en tiempo de juego como el hitstun de un jugador:
# si el siguiente golpe llega antes de que termine, cuenta dentro del mismo combo.
@export var duracion_aturdido : float = 0.35

@onready var ani = $Sprite2D/AnimationPlayer

var golpes_combo := 0
var daño_combo := 0
var tiempo_aturdido := 0.0

func _physics_process(delta):
	if tiempo_aturdido > 0.0:
		tiempo_aturdido = max(tiempo_aturdido - delta, 0.0)

func _on_area_entered(area):
	if not area.is_in_group("P_Punch"):
		return

	var daño = obtener_daño(area)
	var atacante = area.get_parent()
	if tiempo_aturdido <= 0.0:
		golpes_combo = 0
		daño_combo = 0
	golpes_combo += 1
	daño_combo += daño
	tiempo_aturdido = area.duración_hitstun if "duración_hitstun" in area else duracion_aturdido
	# Un combo con continuación (como el Carmesí) alarga el aturdimiento, igual que con un rival.
	if atacante != null and atacante.has_method("obtener_hitstun_actual"):
		tiempo_aturdido = atacante.obtener_hitstun_actual(tiempo_aturdido)
	golpe_recibido.emit(daño, golpes_combo, daño_combo)

	sentir_golpe(area)
	_ani_change()
	if atacante != null and atacante.has_method("al_conectar_golpe"):
		atacante.al_conectar_golpe(self)

# Igual que contra un rival: el proyectil trae su daño y un golpe usa el del atacante.
func obtener_daño(area) -> int:
	if "daño" in area:
		return area.daño
	var atacante = area.get_parent()
	if atacante != null and atacante.has_method("obtener_daño_actual"):
		return atacante.obtener_daño_actual()
	return 10

func sentir_golpe(area) -> void:
	var atacante = area.owner_player if "owner_player" in area else area.get_parent()
	if not (atacante is Jugador):
		return
	atacante.aplicar_hit_stop()
	atacante.sacudir_camara()
	# La chispa sale donde el golpe toca al muñeco.
	var punto = (area.global_position + global_position) * 0.5
	var propias = atacante.obtener_rects_area(self)
	for zona in atacante.obtener_rects_area(area):
		for propia in propias:
			if zona.intersects(propia, true):
				punto = zona.intersection(propia).get_center()
	atacante.crear_hit_spark(punto, Color(1, 1, 0.5, 1.0), 5.5)

func _ani_change():
	var ani_current = ani.current_animation
	if ani_current == "Hit":
		ani.play("Idle")
		ani.play("Hit")
	else:
		ani.play("Hit")

func _on_animation_player_animation_finished(anim_name):
	match anim_name:
		"Hit":
			ani.play("Idle")
