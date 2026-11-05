extends Jugador
class_name Lum

# ==============================================================================
# 1. CONFIGURACIÓN Y PRECARGAS
# ==============================================================================
var Especial = preload("res://Assets/Escenas/Lum/especial.tscn")
var EfectoRayo = preload("res://Assets/Codigos/RayoEfecto.gd")
var NotaMusical = preload("res://Assets/Codigos/NotaMusical.gd")
var SkinSamuel = preload("res://Assets/Escenas/Lum/Samuel.tres")
var TexturaEspecialSamuel = preload("res://Assets/Personajes/Lum/Samuel/Especial_Samuel.png")

# ==============================================================================
# 2. VARIABLES DE COMBATE Y TEMPORIZADORES
# ==============================================================================
var ataque_actual : String = ""

# Control de la secuencia F, F para el ataque encadenado (Carmesi)
var contador_f : int = 0
var tiempo_ventana_ff : float = 0.0
@export var duracion_ventana_ff : float = 0.22	

@export_category("Estocada Veloz")
@export var velocidad_estocada : float = 420.0
@export var duracion_inicio_estocada : float = 0.15
@export var duracion_activa_estocada : float = 0.133
@export var duracion_recuperacion_estocada : float = 0.034
@export var ventana_estocada : float = 0.15

@export_category("Tajo Antiaéreo")
@export var multiplicador_impulso_antiaereo : float = 0.65
@export var duracion_antiaereo : float = 0.3
@export var ventana_antiaereo : float = 0.12

@export_category("Contraataque")
@export var duracion_counter : float = 0.4
@export var duracion_pose_counter : float = 2.0
@export var cooldown_counter : float = 6.0
@export var retraso_respuesta_counter : float = 0.10
@export var stun_counter : float = 0.45
@export var hitstop_counter : float = 0.16
@export var intensidad_camara_counter : float = 1.8

@export_category("Combo Carmesí")
## Daño de cada tajo de la danza (el golpe del Carmesí usa el daño especial).
@export var daño_tajo_diagonal : int = 6
@export var daño_tajo_horizontal : int = 6
@export var daño_remate_carmesi : int = 10
## Si el Carmesí no entra (falla o se lo bloquean), Lum se queda quieto este tiempo.
@export var castigo_fallo_carmesi : float = 0.5
## Hitstun que le sobra al rival cuando llega el siguiente tajo: no se escapa a mitad de la danza.
@export var margen_hitstun_carmesi : float = 0.15
## A qué distancia de Lum queda el rival cuando llega cada tajo.
@export var distancia_tajos_carmesi : float = 26.0
## Lo más cerca que Lum avanza hacia el rival durante la danza (no lo atraviesa).
@export var distancia_minima_carmesi : float = 21.0
@export var fuerza_remate_carmesi : Vector2 = Vector2(150, 160)
@export var intensidad_camara_remate : float = 2.5

# Cuánto avanza la cadera de Lum en cada cuadro de la danza (px, desde el último cuadro
# del Carmesí), medido en la guía de LibreSprite: así los pies apoyados no patinan.
const AVANCE_DANZA_CARMESI := [0, 1, 1, 9, 12, 9, 7, 7, 7, 7, 12, 16, 17, 17, 16, 17, 23, 26, 32, 31, 28, 28, 28, 27]
# El mismo frenado de procesar_hitstun: con él se calcula cuánto retrocede el rival.
const FRENADO_HITSTUN := 800.0
const PISTA_TAJOS_CARMESI := "Col_Daño/Carmesi:disabled"

@export_category("Easter egg: Samuel")
## Segundos quieto (sin moverse ni atacar) para que Samuel saque el bafle y se ponga a cantar.
@export var tiempo_para_cantar : float = 30.0
## Tiempo máximo entre una letra y la siguiente al escribir S, A, N, T, O.
@export var tiempo_entre_letras : float = 1.0

const CODIGO_SAMUEL := [KEY_S, KEY_A, KEY_N, KEY_T, KEY_O]
# Dónde quedan el bafle (en el piso) y la boca de Samuel, en px desde su origen mirando a la derecha.
const POSICION_BAFLE := Vector2(12, 6)
const POSICION_BOCA := Vector2(6, -13)
const COLORES_NOTAS := [Color(0.36, 0.82, 1.0), Color(1.0, 0.63, 0.25), Color(0.95, 0.95, 1.0)]

var progreso_codigo : int = 0
var tiempo_desde_letra : float = 0.0
var skin_samuel_activa : bool = false
var frames_lum : SpriteFrames = null
var frames_samuel : SpriteFrames = null
var tiempo_quieto : float = 0.0
var cantando : bool = false
var bafle_en_piso : bool = false
var posicion_bafle_global := Vector2.ZERO
var tiempo_nota : float = 0.0
var nota_desde_bafle : bool = true

var tiempo_estocada : float = 0.0
var tiempo_ventana_estocada : float = 0.0
var tiempo_ventana_antiaereo : float = 0.0
var tiempo_antiaereo : float = 0.0
var tiempo_counter : float = 0.0
var cooldown_counter_actual : float = 0.0
var carmesi_objetivo : Node2D = null
var avance_danza_aplicado : int = 0
var avance_danza_perdido : int = 0
var tiempo_fallo_carmesi : float = 0.0
var inicios_tajos_carmesi : Array = []

# ==============================================================================
# 3. ENTRADAS DEL JUGADOR (_input)
# ==============================================================================
func _input(event):
	revisar_codigo_samuel(event)
	if estado == EstadoFSM.MUERTO or estado == EstadoFSM.HITSTUN or estado == EstadoFSM.ESTOCADA_VELOZ or estado == EstadoFSM.ANTIAEREO or estado == EstadoFSM.COUNTER_POSE or estado == EstadoFSM.COUNTER_IMPACTO or estado == EstadoFSM.COUNTER_ATTACK or estado == EstadoFSM.CHOQUE or estado == EstadoFSM.AGARRANDO or estado == EstadoFSM.AGARRADO:
		return

	# Se lee la tecla desde el propio evento: _input corre una vez por cada evento y,
	# con Input.is_action_just_pressed, otra tecla en el mismo frame repetía la misma F.
	if event.is_action_pressed(inputs["counter"]):
		if cooldown_counter_actual <= 0 and is_on_floor() and (estado == EstadoFSM.NORMAL or estado == EstadoFSM.AGACHADO):
			iniciar_counter()
			return

	if event.is_action_pressed(inputs["ataque_debil"]):
		if tiempo_ventana_antiaereo > 0 or Input.is_action_just_pressed(inputs["salto"]):
			if estado == EstadoFSM.NORMAL and (is_on_floor() or tiempo_ventana_antiaereo > 0):
				iniciar_antiaereo()
				return
		
		# Permitimos registrar el doble F si estamos en Normal O si estamos ejecutando el Ataque_1
		var puede_hacer_f = (puede_iniciar_ataque() and estado != EstadoFSM.ESPECIAL) or (estado == EstadoFSM.ATACANDO and ataque_actual == "Ataque_1")
		
		if puede_hacer_f:
			if tiempo_ventana_ff > 0:
				contador_f += 1
			else:
				contador_f = 1
			tiempo_ventana_ff = duracion_ventana_ff

			if estado == EstadoFSM.NORMAL:
				ataque_actual = "Ataque_1"
				iniciar_ataque(ataque_actual, "debil", 1.8)

	if event.is_action_pressed(inputs["ataque_medio"]):
		if estado == EstadoFSM.DASH and tiempo_ventana_estocada > 0:
			iniciar_estocada_veloz()
			return
		
		# Durante el especial no se cancela con Ataque_2 (si no, el proyectil nunca sale).
		var puede_empezar = puede_iniciar_ataque() and estado != EstadoFSM.ESPECIAL
		var puede_cancelar = puede_cancelar_ataque_debil("Ataque_1")

		if puede_empezar or puede_cancelar:
			ataque_actual = "Ataque_2"
			iniciar_ataque(ataque_actual, "medio")

	# --- INTENCIÓN DEL ATAQUE ENCADENADO (F, F + X) ---
	if event.is_action_pressed(inputs["especial"]):
		if contador_f >= 2 and is_on_floor() and (estado == EstadoFSM.NORMAL or estado == EstadoFSM.ATACANDO):
			estado = EstadoFSM.ATACANDO
			configurar_ataque("especial")
			ataque_actual = "Carmesi"
			contador_f = 0
			tiempo_ventana_ff = 0.0
			carmesi_objetivo = null
			desactivar_hitboxes()
			ani.animation = ataque_actual
			ani.stop()
			anim_player.play(ataque_actual)
			return

		var puede_empezar = is_on_floor() and estado != EstadoFSM.ATACANDO and estado != EstadoFSM.DASH and estado != EstadoFSM.HITSTUN and estado != EstadoFSM.BLOQUEANDO and estado != EstadoFSM.BLOQUEO_IMPACTO and estado != EstadoFSM.ESPECIAL
		# El Carmesí y su danza no se cancelan con el especial.
		var puede_cancelar = estado == EstadoFSM.ATACANDO and ani.frame >= frame_cancel_especial and not ataque_actual.begins_with("Carmesi")
		
		if puede_empezar or puede_cancelar:
			estado = EstadoFSM.ESPECIAL
			configurar_ataque("especial")
			desactivar_hitboxes()
			ani.play("Especial")
			anim_player.play("Especial")

# ==============================================================================
# 4. FÍSICAS Y MÁQUINA DE ESTADOS (_physics_process)
# ==============================================================================
func _physics_process(delta):
	tiempo_desde_letra += delta
	procesar_canto(delta)
	if estado == EstadoFSM.MUERTO:
		procesar_muerte(delta)
		return
	if procesar_impacto_bloqueo(delta):
		return

	if tiempo_ventana_estocada > 0:
		tiempo_ventana_estocada = max(tiempo_ventana_estocada - delta, 0.0)
	if tiempo_ventana_antiaereo > 0:
		tiempo_ventana_antiaereo = max(tiempo_ventana_antiaereo - delta, 0.0)
	if cooldown_counter_actual > 0:
		cooldown_counter_actual = max(cooldown_counter_actual - delta, 0.0)
	if tiempo_ventana_ff > 0:
		tiempo_ventana_ff = max(tiempo_ventana_ff - delta, 0.0)
	else:
		contador_f = 0

	if procesar_hitstun(delta):
		return

	comprobar_choque()
	if procesar_choque(delta):
		return
	if procesar_agarre(delta):
		return

	if estado == EstadoFSM.ESTOCADA_VELOZ:
		procesar_estocada_veloz(delta)
		return
	if estado == EstadoFSM.ANTIAEREO:
		procesar_antiaereo(delta)
		return
	if estado == EstadoFSM.COUNTER_POSE:
		procesar_counter_pose(delta)
		return
	if estado == EstadoFSM.COUNTER_IMPACTO:
		procesar_counter_impacto(delta)
		return
	if estado == EstadoFSM.COUNTER_ATTACK:
		procesar_counter_attack(delta)
		return
	if procesar_carmesi(delta):
		return

	if intentar_iniciar_agarre():
		return
	procesar_entrada_bloqueo()
	procesar_postura()
	actualizar_direccion_entrada()
	if intentar_iniciar_dash():
		tiempo_ventana_estocada = ventana_estocada
	if estado == EstadoFSM.NORMAL and Input.is_action_just_pressed(inputs["salto"]):
		tiempo_ventana_antiaereo = ventana_antiaereo
	procesar_movimiento_comun(delta)

# ==============================================================================
# 5. LÓGICA DE HABILIDADES EXCLUSIVAS (Mecánicas de Lum)
# ==============================================================================
func procesar_estocada_veloz(delta: float) -> void:
	tiempo_estocada += delta
	var fin_inicio = duracion_inicio_estocada
	var fin_activa = fin_inicio + duracion_activa_estocada
	var fin_total = fin_activa + duracion_recuperacion_estocada
	var direccion = sign(mirror.scale.x)
	if direccion == 0: direccion = 1

	if tiempo_estocada < fin_inicio:
		velocity.x = 0
	elif tiempo_estocada < fin_activa:
		velocity.x = velocidad_estocada * direccion
	else:
		velocity.x = move_toward(velocity.x, 0, velocidad_estocada * 8.0 * delta)

	velocity.y = 0
	move_and_slide()
	procesar_pushbox()
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)
	
	if tiempo_estocada >= fin_total:
		desactivar_hitboxes()
		anim_player.stop()
		estado = EstadoFSM.NORMAL
		ani.play("Idle")

func iniciar_estocada_veloz() -> void:
	estado = EstadoFSM.ESTOCADA_VELOZ
	tiempo_estocada = 0.0
	tiempo_ventana_estocada = 0.0
	desactivar_hitboxes()
	configurar_ataque("medio")
	ani.animation = "Estocada"
	ani.stop()
	anim_player.play("Estocada")

func procesar_antiaereo(delta: float) -> void:
	tiempo_antiaereo += delta
	velocity.x = 0
	velocity.y += intVY * delta
	move_and_slide()
	procesar_pushbox()
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)

	if tiempo_antiaereo >= duracion_antiaereo:
		desactivar_hitboxes()
		anim_player.stop()
		col_dano.get_node("Antiaereo").set_deferred("disabled", true)
		estado = EstadoFSM.NORMAL
		ani.play("Idle")

func iniciar_antiaereo() -> void:
	estado = EstadoFSM.ANTIAEREO
	tiempo_antiaereo = 0.0
	tiempo_ventana_antiaereo = 0.0
	desactivar_hitboxes()
	configurar_ataque("medio")
	velocity.y = -Jump_Height * multiplicador_impulso_antiaereo
	ani.animation = "Antiaereo"
	ani.stop()
	anim_player.play("Antiaereo")

func procesar_counter_pose(delta: float) -> void:
	tiempo_counter += delta
	velocity = Vector2.ZERO
	ani.animation = "Counter"
	ani.frame = 0
	ani.stop()
	move_and_slide()
	procesar_pushbox()
	if tiempo_counter >= duracion_pose_counter:
		finalizar_counter()

func procesar_counter_attack(delta: float) -> void:
	tiempo_counter += delta
	velocity = Vector2.ZERO
	move_and_slide()
	procesar_pushbox()
	if tiempo_counter >= duracion_counter:
		finalizar_counter()

func procesar_counter_impacto(delta: float) -> void:
	tiempo_counter += delta
	velocity = Vector2.ZERO
	move_and_slide()
	procesar_pushbox()

	if tiempo_counter >= retraso_respuesta_counter:
		estado = EstadoFSM.COUNTER_ATTACK
		tiempo_counter = 0.0
		ani.animation = "Counter"
		ani.stop()
		anim_player.play("Counter")

func finalizar_counter() -> void:
	desactivar_hitboxes()
	anim_player.call_deferred("stop")
	estado = EstadoFSM.NORMAL
	ani.play("Idle")

func iniciar_counter() -> void:
	estado = EstadoFSM.COUNTER_POSE
	tiempo_counter = 0.0
	cooldown_counter_actual = cooldown_counter
	desactivar_hitboxes()
	configurar_ataque("counter")
	ani.animation = "Counter"
	ani.frame = 0
	ani.stop()

func ejecutar_counter(area: Area2D) -> void:
	estado = EstadoFSM.COUNTER_IMPACTO
	tiempo_counter = 0.0
	desactivar_hitboxes()
	configurar_ataque("counter")
	aplicar_hit_stop(hitstop_counter, 0.08)
	sacudir_camara(intensidad_camara_counter, hitstop_counter)
	ani.animation = "Counter"
	ani.frame = 0
	ani.stop()

# ==============================================================================
# COMBO CARMESÍ (F, F + X): si el Carmesí entra, sigue la danza de tres tajos;
# si falla o se lo bloquean, Lum se queda quieto un momento (castigo).
# ==============================================================================
func procesar_carmesi(delta: float) -> bool:
	if estado != EstadoFSM.ATACANDO:
		return false
	match ataque_actual:
		"Carmesi_Danza":
			avanzar_danza_carmesi()
		"Carmesi_Fallo":
			tiempo_fallo_carmesi += delta
			if tiempo_fallo_carmesi >= castigo_fallo_carmesi:
				terminar_carmesi()
				return true
		_:
			return false
	velocity = Vector2.ZERO
	move_and_slide()
	procesar_pushbox()
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)
	return true

# Al cambiar de cuadro, Lum avanza lo mismo que su cadera en el dibujo.
func avanzar_danza_carmesi() -> void:
	var cuadro = clampi(ani.frame, 0, AVANCE_DANZA_CARMESI.size() - 1)
	var paso: int = AVANCE_DANZA_CARMESI[cuadro] - avance_danza_aplicado
	if paso == 0:
		return
	avance_danza_aplicado = AVANCE_DANZA_CARMESI[cuadro]
	var direccion = 1 if mirror.scale.x >= 0 else -1
	var real = paso
	if paso > 0 and is_instance_valid(carmesi_objetivo):
		# No atraviesa al rival: si ya lo tiene encima, avanza solo hasta la distancia mínima.
		var hueco = (carmesi_objetivo.global_position.x - global_position.x) * direccion - distancia_minima_carmesi
		real = clampi(int(floor(hueco)), 0, paso)
		avance_danza_perdido += paso - real
	elif paso < 0 and avance_danza_perdido > 0:
		# Lo que no pudo avanzar tampoco lo retrocede.
		var absorbido = mini(avance_danza_perdido, -paso)
		real = paso + absorbido
		avance_danza_perdido -= absorbido
	global_position.x += real * direccion

func carmesi_conecto() -> bool:
	if not is_instance_valid(carmesi_objetivo):
		return false
	if carmesi_objetivo is Jugador:
		return carmesi_objetivo.estado == EstadoFSM.HITSTUN
	return true

func iniciar_danza_carmesi() -> void:
	ataque_actual = "Carmesi_Danza"
	configurar_ataque("carmesi")
	avance_danza_aplicado = 0
	avance_danza_perdido = 0
	desactivar_hitboxes()
	ani.animation = "Carmesi_Danza"
	ani.stop()
	anim_player.play("Carmesi_Danza")

func iniciar_fallo_carmesi() -> void:
	ataque_actual = "Carmesi_Fallo"
	tiempo_fallo_carmesi = 0.0
	carmesi_objetivo = null
	desactivar_hitboxes()

func terminar_carmesi() -> void:
	carmesi_objetivo = null
	desactivar_hitboxes()
	estado = EstadoFSM.NORMAL
	ani.play("Idle")

# Al cancelar el Ataque_1 con el Carmesí, su golpe puede entrar justo después: ese golpe
# es del Ataque_1, no del Carmesí. Del Carmesí solo es lo que entra con su hitbox activa.
func golpe_es_del_carmesi() -> bool:
	var forma = col_dano.get_node_or_null("Carmesi")
	return forma != null and not forma.disabled

# El rival (o el muñeco de entrenamiento) avisa cuando un golpe de Lum le entra.
func al_conectar_golpe(victima: Node2D) -> void:
	if estado != EstadoFSM.ATACANDO or (ataque_actual != "Carmesi" and ataque_actual != "Carmesi_Danza"):
		return
	if victima is Jugador and victima.estado == EstadoFSM.MUERTO:
		# KO: la ronda se congela, así que la danza se corta aquí.
		anim_player.call_deferred("stop")
		terminar_carmesi()
		return
	if not golpe_es_del_carmesi():
		return
	if ataque_actual == "Carmesi":
		carmesi_objetivo = victima
		acomodar_rival_carmesi(victima)
		return
	if indice_tajo_carmesi() < obtener_inicios_tajos().size() - 1:
		acomodar_rival_carmesi(victima)
		return
	# Remate: la cámara se sacude fuerte y el rival sale derribado.
	sacudir_camara(intensidad_camara_remate, 0.25)
	if victima is Jugador and victima.estado == EstadoFSM.HITSTUN:
		victima.ser_derribado(1 if mirror.scale.x >= 0 else -1, fuerza_remate_carmesi)

# El rival retrocede justo lo necesario para que el siguiente tajo lo alcance.
func acomodar_rival_carmesi(victima: Node2D) -> void:
	if not (victima is Jugador) or victima.estado != EstadoFSM.HITSTUN:
		return
	var direccion = 1 if mirror.scale.x >= 0 else -1
	var destino = global_position.x + direccion * (avance_hasta_siguiente_tajo() + distancia_tajos_carmesi)
	var recorrido = (destino - victima.global_position.x) * direccion
	victima.velocity.x = direccion * sqrt(2.0 * FRENADO_HITSTUN * maxf(recorrido, 0.0))

# Inicio de cada tajo, leído de la pista de la hitbox en el AnimationPlayer:
# si se mueven los tiempos en el editor, el combo los sigue.
func obtener_inicios_tajos() -> Array:
	if inicios_tajos_carmesi.is_empty() and anim_player.has_animation("Carmesi_Danza"):
		var animacion: Animation = anim_player.get_animation("Carmesi_Danza")
		var pista = animacion.find_track(NodePath(PISTA_TAJOS_CARMESI), Animation.TYPE_VALUE)
		if pista != -1:
			for k in animacion.track_get_key_count(pista):
				if animacion.track_get_key_value(pista, k) == false:
					inicios_tajos_carmesi.append(animacion.track_get_key_time(pista, k))
	return inicios_tajos_carmesi

# Índice del tajo que está saliendo (0 = diagonal, 1 = horizontal, 2 = remate).
func indice_tajo_carmesi() -> int:
	var t = anim_player.current_animation_position
	var indice = -1
	var inicios = obtener_inicios_tajos()
	for i in inicios.size():
		if t + 0.001 >= inicios[i]:
			indice = i
	return indice

# Tiempo de juego que falta para el próximo tajo (-1 si ya no queda ninguno).
func tiempo_hasta_siguiente_tajo() -> float:
	if estado != EstadoFSM.ATACANDO or not is_instance_valid(anim_player):
		return -1.0
	var inicios = obtener_inicios_tajos()
	if inicios.is_empty():
		return -1.0
	var t = anim_player.current_animation_position
	match ataque_actual:
		"Carmesi":
			return maxf(anim_player.current_animation_length - t, 0.0) + inicios[0]
		"Carmesi_Danza":
			for inicio in inicios:
				if inicio > t + 0.02:
					return inicio - t
	return -1.0

# Cuánto avanzará Lum (px) hasta el próximo tajo.
func avance_hasta_siguiente_tajo() -> int:
	var en_danza = ataque_actual == "Carmesi_Danza"
	var t = anim_player.current_animation_position if en_danza else 0.0
	for inicio in obtener_inicios_tajos():
		if inicio > t + 0.02 or (not en_danza and inicio >= t):
			var animacion: Animation = anim_player.get_animation("Carmesi_Danza")
			var pista = animacion.find_track(NodePath("AnimatedSprite2D:frame"), Animation.TYPE_VALUE)
			if pista == -1:
				return 0
			var cuadro = clampi(int(animacion.value_track_interpolate(pista, inicio)), 0, AVANCE_DANZA_CARMESI.size() - 1)
			return AVANCE_DANZA_CARMESI[cuadro] - (avance_danza_aplicado if en_danza else 0)
	return 0

func obtener_hitstun_actual(por_defecto: float) -> float:
	if not golpe_es_del_carmesi():
		return por_defecto
	var falta = tiempo_hasta_siguiente_tajo()
	if falta < 0.0:
		return por_defecto
	return maxf(por_defecto, falta + margen_hitstun_carmesi)

func obtener_daño_actual() -> int:
	if estado == EstadoFSM.ATACANDO and ataque_actual == "Carmesi" and not golpe_es_del_carmesi():
		return daño_ataque_debil
	if estado == EstadoFSM.ATACANDO and ataque_actual == "Carmesi_Danza":
		match indice_tajo_carmesi():
			0: return daño_tajo_diagonal
			1: return daño_tajo_horizontal
			_: return daño_remate_carmesi
	return super()

# ==============================================================================
# 6. EFECTOS VISUALES Y SEÑALES
# ==============================================================================
func _on_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("P_Punch") and estado == EstadoFSM.COUNTER_POSE:
		if tiempo_counter <= duracion_pose_counter:
			ejecutar_counter(area)
			return
		desactivar_hitboxes()
	if area.is_in_group("P_Punch") and (estado == EstadoFSM.COUNTER_IMPACTO or estado == EstadoFSM.COUNTER_ATTACK):
		return
	super._on_hurtbox_area_entered(area)

func Hit(posicion_atacante = null, tiempo: float = -1.0):
	desactivar_hitboxes()
	carmesi_objetivo = null
	if is_instance_valid(anim_player):
		anim_player.call_deferred("stop")
	if estado == EstadoFSM.COUNTER_POSE or estado == EstadoFSM.COUNTER_IMPACTO or estado == EstadoFSM.COUNTER_ATTACK:
		finalizar_counter()
	super.Hit(posicion_atacante, tiempo)

# Lo propio de Lum (cooldown del counter y ventanas de comandos) no pasa a la siguiente ronda.
func reiniciar_para_ronda(posicion_inicial: Vector2, direccion_inicial: int) -> void:
	quitar_skin_samuel()
	super(posicion_inicial, direccion_inicial)
	cooldown_counter_actual = 0.0
	tiempo_counter = 0.0
	contador_f = 0
	tiempo_ventana_ff = 0.0
	tiempo_ventana_estocada = 0.0
	tiempo_ventana_antiaereo = 0.0
	carmesi_objetivo = null
	avance_danza_aplicado = 0
	avance_danza_perdido = 0
	tiempo_fallo_carmesi = 0.0
	if is_instance_valid(anim_player):
		anim_player.stop()

func crear_especial():
	var proyectil = Especial.instantiate()
	proyectil.global_position = global_position
	var dir = sign(mirror.scale.x)
	proyectil.direction = dir if dir != 0 else 1
	proyectil.daño = obtener_daño_actual()
	proyectil.owner_player = self
	
	# P1 lanza hitbox en layer 8 y ataca la hurtbox de P2 (layer 4)
	# P2 lanza hitbox en layer 16 y ataca la hurtbox de P1 (layer 2)
	if player_id == 1:
		proyectil.collision_layer = 8
		proyectil.collision_mask = 4
	else:
		proyectil.collision_layer = 16
		proyectil.collision_mask = 2
	# Con la skin de Samuel el tajo del especial sale como ondas de sonido.
	if skin_samuel_activa:
		var sprite = proyectil.get_node_or_null("Sprite2D")
		if sprite:
			sprite.texture = TexturaEspecialSamuel
		var rastro = proyectil.get_node_or_null("Rastro")
		if rastro:
			rastro.color = Color(0.36, 0.82, 1.0, 1.0)
		
	get_parent().add_child(proyectil)

func _on_animated_sprite_2d_animation_finished() -> void:
	# Samuel termina de poner el bafle en el piso y empieza a cantar.
	if ani.animation == "Samuel_Saca_Bafle" and cantando:
		ani.play("Samuel_Canta")
		return
	if procesar_fin_animacion_sprite(ani.animation):
		tiempo_ventana_estocada = 0.0

# Pose provisional del agarre hasta que exista la animación "Agarre".
func obtener_pose_agarre(lanzando: bool) -> Array:
	return ["Ataque_1", 7] if lanzando else ["Ataque_1", 0]

# Manejo de finalización de animaciones del AnimationPlayer (incluyendo Carmesi)
func _on_animation_player_finished(anim_name: String) -> void:
	super(anim_name)
	match anim_name:
		"Carmesi":
			if estado == EstadoFSM.ATACANDO and ataque_actual == "Carmesi":
				desactivar_hitboxes()
				if not anim_player.has_animation("Carmesi_Danza"):
					terminar_carmesi()
				elif carmesi_conecto():
					iniciar_danza_carmesi()
				else:
					iniciar_fallo_carmesi()
		"Carmesi_Danza":
			if estado == EstadoFSM.ATACANDO and ataque_actual == "Carmesi_Danza":
				terminar_carmesi()

# ==============================================================================
# 7. EASTER EGG: SAMUEL
# Escribiendo S, A, N, T, O en plena pelea cae un rayo y Lum se convierte en Samuel
# hasta que termina la ronda. Si se queda quieto un rato, saca el bafle y canta.
# ==============================================================================
func revisar_codigo_samuel(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if progreso_codigo > 0 and tiempo_desde_letra > tiempo_entre_letras:
		progreso_codigo = 0
	if es_tecla(event, CODIGO_SAMUEL[progreso_codigo]):
		progreso_codigo += 1
	elif es_tecla(event, CODIGO_SAMUEL[0]):
		progreso_codigo = 1
	else:
		progreso_codigo = 0
	tiempo_desde_letra = 0.0
	if progreso_codigo >= CODIGO_SAMUEL.size():
		progreso_codigo = 0
		activar_skin_samuel()

# Vale la letra escrita o la tecla en esa posición (así funciona con cualquier distribución).
func es_tecla(event: InputEventKey, tecla: Key) -> bool:
	return event.keycode == tecla or event.physical_keycode == tecla

# Si los dos eligieron a Lum, el código solo transforma al jugador 1.
func puede_usar_codigo_samuel() -> bool:
	if player_id == 1:
		return true
	for nodo in get_tree().get_nodes_in_group("jugadores"):
		if nodo != self and nodo is Lum and nodo.player_id == 1:
			return false
	return true

func activar_skin_samuel() -> void:
	if skin_samuel_activa or estado == EstadoFSM.MUERTO or not puede_usar_codigo_samuel():
		return
	skin_samuel_activa = true
	if frames_lum == null:
		frames_lum = ani.sprite_frames
	if frames_samuel == null:
		frames_samuel = construir_frames_samuel()
	var rayo = EfectoRayo.new()
	rayo.global_position = (global_position + Vector2(0, obtener_altura_pies())).round()
	rayo.z_index = 30
	get_tree().current_scene.add_child(rayo)
	sacudir_camara(3.5, 0.35)
	aplicar_hit_stop(0.12, 0.05)
	cambiar_frames(frames_samuel)
	tiempo_quieto = 0.0

func quitar_skin_samuel() -> void:
	cantando = false
	bafle_en_piso = false
	tiempo_quieto = 0.0
	progreso_codigo = 0
	if not skin_samuel_activa:
		return
	skin_samuel_activa = false
	cambiar_frames(frames_lum)

# Copia de las animaciones de Lum con los dibujos de Samuel: conserva los tiempos y el bucle
# de Lum (los ataques siguen sincronizados) y agrega las animaciones propias de Samuel.
func construir_frames_samuel() -> SpriteFrames:
	var frames: SpriteFrames = frames_lum.duplicate()
	for nombre in SkinSamuel.get_animation_names():
		var cuadros = SkinSamuel.get_frame_count(nombre)
		if not frames.has_animation(nombre):
			frames.add_animation(nombre)
			frames.set_animation_speed(nombre, SkinSamuel.get_animation_speed(nombre))
			frames.set_animation_loop(nombre, SkinSamuel.get_animation_loop(nombre))
			for i in cuadros:
				frames.add_frame(nombre, SkinSamuel.get_frame_texture(nombre, i), SkinSamuel.get_frame_duration(nombre, i))
		elif frames.get_frame_count(nombre) == cuadros:
			for i in cuadros:
				frames.set_frame(nombre, i, SkinSamuel.get_frame_texture(nombre, i), frames.get_frame_duration(nombre, i))
	return frames

# Cambia los dibujos sin cortar lo que estaba haciendo (misma animación y mismo cuadro).
func cambiar_frames(nuevos: SpriteFrames) -> void:
	if nuevos == null or ani.sprite_frames == nuevos:
		return
	var animacion = ani.animation
	var cuadro = ani.frame
	var progreso = ani.frame_progress
	var sonando = ani.is_playing()
	var velocidad = 1.0
	if sonando and ani.speed_scale != 0.0:
		velocidad = ani.get_playing_speed() / ani.speed_scale
	ani.sprite_frames = nuevos
	if not nuevos.has_animation(animacion):
		ani.play("Idle")
		return
	ani.animation = animacion
	ani.set_frame_and_progress(cuadro, progreso)
	if sonando:
		ani.play(animacion, velocidad)

func procesar_canto(delta: float) -> void:
	if not skin_samuel_activa:
		return
	var quieto = estado == EstadoFSM.NORMAL and is_on_floor() and velocity == Vector2.ZERO and intMove == 0
	if cantando:
		if not quieto:
			dejar_de_cantar()
			return
		if not bafle_en_piso and (ani.animation == "Samuel_Canta" or (ani.animation == "Samuel_Saca_Bafle" and ani.frame >= 2)):
			bafle_en_piso = true
			var dir = 1.0 if mirror.scale.x >= 0 else -1.0
			posicion_bafle_global = global_position + Vector2(POSICION_BAFLE.x * dir, POSICION_BAFLE.y)
		if ani.animation == "Samuel_Canta":
			tiempo_nota -= delta
			if tiempo_nota <= 0.0:
				tiempo_nota = 0.45
				soltar_nota()
		return
	tiempo_quieto = tiempo_quieto + delta if quieto else 0.0
	if tiempo_quieto >= tiempo_para_cantar:
		empezar_a_cantar()

func empezar_a_cantar() -> void:
	cantando = true
	bafle_en_piso = false
	tiempo_quieto = 0.0
	tiempo_nota = 0.0
	ani.play("Samuel_Saca_Bafle")

# Al moverse, atacar o recibir un golpe deja de cantar y el bafle desaparece en un soplo.
func dejar_de_cantar() -> void:
	cantando = false
	tiempo_quieto = 0.0
	if bafle_en_piso:
		crear_hit_spark(posicion_bafle_global + Vector2(0, 3), Color(0.85, 0.87, 0.92, 1.0), 4.0)
	bafle_en_piso = false

func soltar_nota() -> void:
	var nota = NotaMusical.new()
	var dir = 1.0 if mirror.scale.x >= 0 else -1.0
	var desde = posicion_bafle_global if nota_desde_bafle else global_position + Vector2(POSICION_BOCA.x * dir, POSICION_BOCA.y)
	nota_desde_bafle = not nota_desde_bafle
	nota.global_position = desde.round()
	nota.color = COLORES_NOTAS[randi() % COLORES_NOTAS.size()]
	nota.z_index = 20
	get_tree().current_scene.add_child(nota)

# Mientras Samuel canta, la animación de cantar reemplaza al Idle.
func actualizar_animacion_comun() -> void:
	if cantando and estado == EstadoFSM.NORMAL and is_on_floor() and velocity == Vector2.ZERO:
		return
	super()

func obtener_color_duplicado_dash() -> Color:
	if skin_samuel_activa:
		return Color(1.0, 0.55, 0.15, 0.5)
	return super()
