extends Jugador
class_name Lum

# ==============================================================================
# 1. CONFIGURACIÓN Y PRECARGAS
# ==============================================================================
var Especial = preload("res://Assets/Escenas/Lum/especial.tscn")

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

var tiempo_estocada : float = 0.0
var tiempo_ventana_estocada : float = 0.0
var tiempo_ventana_antiaereo : float = 0.0
var tiempo_antiaereo : float = 0.0
var tiempo_counter : float = 0.0
var cooldown_counter_actual : float = 0.0

# ==============================================================================
# 3. ENTRADAS DEL JUGADOR (_input)
# ==============================================================================
func _input(event):
	if estado == EstadoFSM.MUERTO or estado == EstadoFSM.HITSTUN or estado == EstadoFSM.ESTOCADA_VELOZ or estado == EstadoFSM.ANTIAEREO or estado == EstadoFSM.COUNTER_POSE or estado == EstadoFSM.COUNTER_IMPACTO or estado == EstadoFSM.COUNTER_ATTACK:
		return

	if Input.is_action_just_pressed(inputs["counter"]):
		if cooldown_counter_actual <= 0 and is_on_floor() and (estado == EstadoFSM.NORMAL or estado == EstadoFSM.AGACHADO):
			iniciar_counter()
			return

	if Input.is_action_just_pressed(inputs["ataque_debil"]):
		if tiempo_ventana_antiaereo > 0 or Input.is_action_just_pressed(inputs["salto"]):
			if estado == EstadoFSM.NORMAL and (is_on_floor() or tiempo_ventana_antiaereo > 0):
				iniciar_antiaereo()
				return
		
		# Permitimos registrar el doble F si estamos en Normal O si estamos ejecutando el Ataque_1
		var puede_hacer_f = puede_iniciar_ataque() or (estado == EstadoFSM.ATACANDO and ataque_actual == "Ataque_1")
		
		if puede_hacer_f:
			if tiempo_ventana_ff > 0:
				contador_f += 1
			else:
				contador_f = 1
			tiempo_ventana_ff = duracion_ventana_ff

			if estado == EstadoFSM.NORMAL:
				ataque_actual = "Ataque_1"
				iniciar_ataque(ataque_actual, "debil", 1.8)

	if Input.is_action_just_pressed(inputs["ataque_medio"]):
		if estado == EstadoFSM.DASH and tiempo_ventana_estocada > 0:
			iniciar_estocada_veloz()
			return
		
		var puede_empezar = puede_iniciar_ataque()
		var puede_cancelar = puede_cancelar_ataque_debil("Ataque_1")

		if puede_empezar or puede_cancelar:
			ataque_actual = "Ataque_2"
			iniciar_ataque(ataque_actual, "medio")

	# --- INTENCIÓN DEL ATAQUE ENCADENADO (F, F + X) ---
	if Input.is_action_just_pressed(inputs["especial"]):
		if contador_f >= 2 and is_on_floor() and (estado == EstadoFSM.NORMAL or estado == EstadoFSM.ATACANDO):
			estado = EstadoFSM.ATACANDO
			configurar_ataque("especial")
			ataque_actual = "Carmesi"
			contador_f = 0
			tiempo_ventana_ff = 0.0
			desactivar_hitboxes()
			ani.animation = ataque_actual
			ani.stop()
			anim_player.play(ataque_actual)
			return

		var puede_empezar = is_on_floor() and estado != EstadoFSM.ATACANDO and estado != EstadoFSM.DASH and estado != EstadoFSM.HITSTUN
		var puede_cancelar = estado == EstadoFSM.ATACANDO and ani.frame >= frame_cancel_especial
		
		if puede_empezar or puede_cancelar:
			estado = EstadoFSM.ESPECIAL
			configurar_ataque("especial")
			desactivar_hitboxes()
			ani.play("Especial")
			anim_player.play("Especial")

	procesar_entrada_bloqueo()

# ==============================================================================
# 4. FÍSICAS Y MÁQUINA DE ESTADOS (_physics_process)
# ==============================================================================
func _physics_process(delta):
	if estado == EstadoFSM.MUERTO:
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
	if tiempo_counter >= duracion_pose_counter:
		finalizar_counter()

func procesar_counter_attack(delta: float) -> void:
	tiempo_counter += delta
	velocity = Vector2.ZERO
	move_and_slide()
	if tiempo_counter >= duracion_counter:
		finalizar_counter()

func procesar_counter_impacto(delta: float) -> void:
	tiempo_counter += delta
	velocity = Vector2.ZERO
	move_and_slide()

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
	if is_instance_valid(anim_player):
		anim_player.call_deferred("stop")
	if estado == EstadoFSM.COUNTER_POSE or estado == EstadoFSM.COUNTER_IMPACTO or estado == EstadoFSM.COUNTER_ATTACK:
		finalizar_counter()
	super.Hit(posicion_atacante, tiempo)

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
		
	get_parent().add_child(proyectil)

func _on_animated_sprite_2d_animation_finished() -> void:
	if procesar_fin_animacion_sprite(ani.animation):
		tiempo_ventana_estocada = 0.0

# Manejo de finalización de animaciones del AnimationPlayer (incluyendo Carmesi)
func _on_animation_player_finished(anim_name: String) -> void:
	super(anim_name)
	match anim_name:
		"Carmesi":
			if estado == EstadoFSM.ATACANDO and ataque_actual == "Carmesi":
				desactivar_hitboxes()
				estado = EstadoFSM.NORMAL
				ani.play("Idle")
