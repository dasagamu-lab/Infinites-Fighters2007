extends Jugador
class_name Sierv

# ==============================================================================
# SCRIPT DEL PERSONAJE: SIERV (JUGADOR 2 / LÓGICA DE COMBATE)
# ==============================================================================
# Sierv hereda directamente de la clase base 'Jugador', reutilizando:
# - Sistema de vida, daño y cálculo de golpes.
# - Físicas base (movimiento horizontal, salto, gravedad, límites de escenario).
# - Hurtboxes, Hitboxes y gestión de aturdimiento (Hitstun / Hitstop).
#
# Este script implementa las acciones exclusivas, animaciones, cancelaciones de
# combos (gatlings) y la máquina de estados específica de Sierv.
# ==============================================================================

# Variables de control de combate interno
var counter_hit : int = 0      # Contador utilizado para registrar repeticiones o encadenamientos de golpes.
var ataque_actual : String = "" # Almacena el nombre de la animación del ataque que se está ejecutando.


# ------------------------------------------------------------------------------
# PROCESAMIENTO DE ENTRADAS DEL JUGADOR (_input)
# ------------------------------------------------------------------------------
# Se encarga de capturar las pulsaciones directas para ataques y bloqueos.
func _input(event):
	# 1. Filtro de seguridad: Si Sierv está muerto o aturdido (Hitstun), no puede realizar acciones.
	if estado == "Muerto" or estado == "Hitstun":
		return

	# --------------------------------------------------------------------------
	# ATAQUE DÉBIL (Ataque_P2)
	# --------------------------------------------------------------------------
	if Input.is_action_just_pressed(inputs["ataque_debil"]):
		# Solo se puede iniciar desde el suelo y si no está bloqueando ni atacando previamente.
		if is_on_floor() and estado != "Bloqueando" and estado != "Atacando":
			estado = "Atacando"
			configurar_ataque("debil")             # Configura el tipo de daño en la clase Jugador.
			ataque_actual = "Ataque_P2"
			ani.play(ataque_actual, 1.8)           # Reproduce la animación en el sprite con velocidad 1.8x.
			desactivar_hitboxes()                  # Apaga hitboxes activas previas por seguridad.
			$AnimationPlayer.play(ataque_actual)   # El AnimationPlayer sincroniza la activación de la hitbox.

	# --------------------------------------------------------------------------
	# ATAQUE MEDIO (Ataque_2P2) / SISTEMA DE CANCELACIÓN (CHAIN COMBO)
	# --------------------------------------------------------------------------
	if Input.is_action_just_pressed(inputs["ataque_medio"]):
		# Condición 1: Inicio neutro (desde el suelo, libre de bloqueo, ataque o hitstun).
		var puede_empezar = is_on_floor() and estado != "Bloqueando" and estado != "Atacando" and estado != "Hitstun"
		# Condición 2: Cancelación de ataque débil (si el frame actual del ataque débil superó la ventana de cancelación).
		var puede_cancelar = estado == "Atacando" and ataque_actual == "Ataque_P2" and ani.frame >= frame_cancel_debil

		if puede_empezar or puede_cancelar:
			estado = "Atacando"
			configurar_ataque("medio")             # Asigna el multiplicador/valor de daño medio.
			ataque_actual = "Ataque_2P2"
			ani.play(ataque_actual, 1.0)
			desactivar_hitboxes()
			$AnimationPlayer.play(ataque_actual)

	# --------------------------------------------------------------------------
	# SISTEMA DE BLOQUEO (DEFENSA)
	# --------------------------------------------------------------------------
	if Input.is_action_pressed(inputs["bloqueo"]):
		# El bloqueo solo se puede activar estando en el suelo desde estado Normal o Agachado.
		if is_on_floor() and (estado == "Normal" or estado == "Agachado"):
			estado = "Bloqueando"
			iniciar_animacion_bloqueo()

	# Al soltar el botón de bloqueo, regresa inmediatamente al estado neutro (Normal).
	if Input.is_action_just_released(inputs["bloqueo"]) and estado == "Bloqueando":
		estado = "Normal"


# ------------------------------------------------------------------------------
# BUCLE PRINCIPAL DE FÍSICAS Y MÁQUINA DE ESTADOS (_physics_process)
# ------------------------------------------------------------------------------
func _physics_process(delta):
	# 1. Si el personaje ha muerto, se detiene cualquier procesamiento físico.
	if estado == "Muerto":
		return

	# 2. Si el personaje recibió un impacto mientras bloqueaba, procesa el retroceso y frena.
	if procesar_impacto_bloqueo(delta):
		return

	# 3. Estado de Aturdimiento (Hitstun):
	#    - Frena gradualmente la velocidad horizontal (frenado por fricción).
	#    - Aplica gravedad si el golpe lo dejó en el aire.
	#    - Bloquea cualquier otra acción hasta que expire el timer del aturdimiento.
	if estado == "Hitstun":
		velocity.x = move_toward(velocity.x, 0, 800 * delta)
		if not is_on_floor():
			velocity.y += 980 * delta
		move_and_slide()
		return

	# --------------------------------------------------------------------------
	# ATAQUE ESPECIAL (Especial_P2)
	# --------------------------------------------------------------------------
	if Input.is_action_just_pressed(inputs["especial"]):
		# Puede iniciarse neutralmente o cancelando un ataque básico tras el frame de cancelación.
		var puede_empezar = estado != "Atacando" and estado != "Dash_P2" and estado != "Hitstun"
		var puede_cancelar = estado == "Atacando" and ani.frame >= frame_cancel_especial

		if puede_empezar or puede_cancelar:
			estado = "Especial_P2"
			configurar_ataque("especial")
			desactivar_hitboxes()

	# --------------------------------------------------------------------------
	# RECUPERACIÓN DE RECURSOS AL TOCAR EL SUELO
	# --------------------------------------------------------------------------
	if is_on_floor():
		Can_Dash = 1  # Restablece la carga disponible para realizar Dash.

	# --------------------------------------------------------------------------
	# AGACHARSE (CROUCH)
	# --------------------------------------------------------------------------
	if Input.is_action_pressed(inputs["abajo"]) and is_on_floor() and estado == "Normal":
		estado = "Agachado"
	elif Input.is_action_just_released(inputs["abajo"]) and is_on_floor() and estado == "Agachado":
		estado = "Normal"

	# --------------------------------------------------------------------------
	# LECTURA DE MOVIMIENTO HORIZONTAL
	# --------------------------------------------------------------------------
	# Solo se permite ingresar movimiento horizontal si Sierv no está bloqueando,
	# atacando, ejecutando un especial o en hitstun.
	if estado != "Bloqueando" and estado != "Atacando" and estado != "Especial_P2" and estado != "Hitstun":
		if Input.is_action_pressed(inputs["derecha"]):
			intMove = 1
		elif Input.is_action_pressed(inputs["izquierda"]):
			intMove = -1
		else:
			intMove = 0
	else:
		intMove = 0

	# --------------------------------------------------------------------------
	# EJECUCIÓN DE DASH
	# --------------------------------------------------------------------------
	if Input.is_action_just_pressed(inputs["dash"]) and Can_Dash > 0 and estado != "Bloqueando":
		estado = "Dash_P2"
		Can_Dash -= 1  # Consume una carga de Dash.

	# ==========================================================================
	# MÁQUINA DE ESTADOS FINITOS (FSM) - FÍSICAS Y VELOCIDADES
	# ==========================================================================
	match estado:
		"Normal":
			# Manejo de coyote time y gravedad:
			if is_on_floor():
				coyote_time = max_coyote_time
				velocity.y = 0
			else:
				coyote_time -= delta
				velocity.y += intVY * delta

			# Movimiento horizontal en suelo/aire:
			velocity.x = (intVX * intMove) * delta if intMove != 0 else 0

			# Salto normal o con tolerancia de coyote time:
			if Input.is_action_just_pressed(inputs["salto"]):
				if is_on_floor() or (coyote_time > 0 and velocity.y > 0.01):
					velocity.y = -Jump_Height

			# Salto de altura variable: soltar el botón corta el salto a la mitad
			if Input.is_action_just_released(inputs["salto"]) and velocity.y < 0:
				velocity.y *= 0.5

		"Agachado", "Atacando", "Especial_P2":
			# Los ataques y la postura agachada fijan la velocidad horizontal y vertical a 0
			velocity.x = 0
			velocity.y = 0

		"Bloqueando":
			# Permite que el retroceso recibido al bloquear deslice suavemente al personaje
			velocity.x = move_toward(velocity.x, 0, frenado_bloqueo * delta)
			velocity.y = 0

		"Dash_P2":
			# Desplazamiento rápido en la dirección a la que mira el sprite (mirror.scale.x)
			Time_Actual_Dupli += delta
			velocity.y = 0
			var dir = sign(mirror.scale.x)
			velocity.x = (intVX_Dash * dir) * delta

			# Genera sombras residuales (clones/afterimages) a intervalos regulares
			if Time_Actual_Dupli >= Time_Dupli:
				Time_Actual_Dupli = 0
				crear_duplicado()

	# Actualiza la orientación del sprite/hitbox según la dirección
	_animaciones()
	
	# Aplica el movimiento con colisiones cinemáticas
	move_and_slide()
	
	# Mantiene al personaje dentro de los límites del ring / escenario
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)

	# ==========================================================================
	# MÁQUINA DE ESTADOS FINITOS (FSM) - SELECCIÓN DE ANIMACIONES VISUALES
	# ==========================================================================
	match estado:
		"Normal":
			if is_on_floor():
				if velocity.x == 0:
					ani.play("Idle", 0.8)   # Animación de reposo
				else:
					ani.play("Run", 1.1)    # Animación de carrera
			else:
				# Si la velocidad Y es negativa sube (Jump), si es positiva cae (Fall)
				ani.play("Jump" if velocity.y < 0 else "Fall")

		"Agachado":
			ani.play("Fase1_Agacharse")

		"Dash_P2":
			if is_on_floor():
				ani.play("Dash_P2", 2.5)
			else:
				ani.play("Dash_Aire")

		"Atacando":
			ani.play(ataque_actual, 1.8)

		"Bloqueando":
			mantener_animacion_bloqueo()

		"Especial_P2":
			ani.play("Especial_P2")


# ------------------------------------------------------------------------------
# EFECTO VISUAL: SOMBRAS RESIDUALES DURANTE EL DASH (AFTERIMAGES)
# ------------------------------------------------------------------------------
func crear_duplicado():
	# Clona el sprite actual para dejar una estela con shader semitransparente
	var duplicado = $AnimatedSprite2D.duplicate(true)

	duplicado.material = $AnimatedSprite2D.material.duplicate(true)
	duplicado.material.set_shader_parameter("opacity", 0.3)
	duplicado.material.set_shader_parameter("b", 0.8)
	duplicado.material.set_shader_parameter("mix_color", 0.7)

	duplicado.global_position = $AnimatedSprite2D.global_position
	duplicado.global_scale = $AnimatedSprite2D.global_scale
	duplicado.z_index -= 1

	get_parent().add_child(duplicado)

	# Espera el tiempo de vida de la estela y la elimina de la memoria
	await get_tree().create_timer(Time_Life_Dupli).timeout
	duplicado.queue_free()


# ------------------------------------------------------------------------------
# CONTROL DE FIN DE ANIMACIÓN (_on_animated_sprite_2d_animation_finished)
# ------------------------------------------------------------------------------
# Señal emitida automáticamente por el AnimatedSprite2D cuando termina una acción.
func _on_animated_sprite_2d_animation_finished() -> void:
	match ani.animation:
		"Dash", "Dash_Aire", "Dash_P2":
			# Al terminar el dash, regresa a estado neutro
			estado = "Normal"
			
		"Ataque_1", "Ataque_P2":
			# Si se acumularon repeticiones en counter_hit repite el ataque, si no, vuelve a Normal
			if counter_hit > 1:
				counter_hit = 0
				ani.play(ani.animation)
			else:
				counter_hit = 0
				estado = "Normal"
				
		"Ataque_2", "Ataque_2P2":
			counter_hit = 0
			estado = "Normal"
			
		"Especial", "Especial_P2":
			estado = "Normal"

			
