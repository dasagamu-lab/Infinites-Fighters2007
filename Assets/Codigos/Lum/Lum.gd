extends Jugador
class_name Lum

# Lum hereda de Jugador la vida, movimiento base, colisiones, hitstun y daño.
# Este script contiene las acciones y habilidades exclusivas de Lum.
# Recurso de la escena del proyectil que Lum crea al ejecutar su especial.
# Se carga una sola vez para poder instanciar copias sin cargar el archivo
# repetidamente durante la partida.
var Especial = preload("res://Assets/Escenas/Lum/especial.tscn")

# Cuenta los impactos consecutivos del ataque débil para permitir su ciclo
# de repetición cuando corresponde según la lógica heredada.
var counter_hit : int = 0

# Guarda el nombre de la animación de ataque que se está ejecutando. La misma
# variable permite que la FSM mantenga la animación correcta mientras el ataque
# continúa y también sirve para comprobar si se puede cancelar el ataque débil.
var ataque_actual : String = ""

@export_category("Estocada Veloz")
# Velocidad horizontal aplicada durante la fase activa de la estocada.
@export var velocidad_estocada : float = 420.0

# Tiempo inicial en el que Lum prepara la estocada. Durante esta fase no avanza
# ni puede causar daño, aunque la animación ya se está reproduciendo.
@export var duracion_inicio_estocada : float = 0.15

# Duración del desplazamiento ofensivo. La hitbox se controla desde el
# AnimationPlayer, por lo que este valor debe mantenerse sincronizado con los
# tiempos en los que la animación activa Col_Daño/Estocada.
@export var duracion_activa_estocada : float = 0.133

# Tiempo final de recuperación después del desplazamiento. Aquí Lum deja de
# avanzar y vuelve al estado Normal cuando termina la acción.
@export var duracion_recuperacion_estocada : float = 0.034

# Ventana de entrada posterior al dash. Si el jugador presiona ataque medio
# dentro de este tiempo, el dash se convierte en una estocada.
@export var ventana_estocada : float = 0.15

@export_category("Tajo Antiaéreo")
# Usa la altura del salto normal como base, pero reducida para que el corte
# suba solo lo necesario y no lance a Lum fuera del escenario.
@export var multiplicador_impulso_antiaereo : float = 0.65
@export var duracion_antiaereo : float = 0.36666667
@export var ventana_antiaereo : float = 0.12

@export_category("Contraataque")
@export var duracion_counter : float = 0.4
@export var duracion_pose_counter : float = 2.0
@export var cooldown_counter : float = 6.0
@export var retraso_respuesta_counter : float = 0.10
@export var stun_counter : float = 0.3
@export var hitstop_counter : float = 0.16
@export var intensidad_camara_counter : float = 1.8

# Cronómetro interno de la estocada actual.
var tiempo_estocada : float = 0.0

# Cronómetro de la ventana que permite transformar un dash en estocada.
var tiempo_ventana_estocada : float = 0.0

# Cronómetro de la ventana W + F y de la ejecución del antiaéreo.
var tiempo_ventana_antiaereo : float = 0.0
var tiempo_antiaereo : float = 0.0
var tiempo_counter : float = 0.0
var cooldown_counter_actual : float = 0.0

# ---------------------------------------------------------
# CONTROLES Y FÍSICAS EXCLUSIVAS
# ---------------------------------------------------------
func _input(event):
	# Estos estados tienen prioridad sobre cualquier entrada nueva. Se ignoran
	# los botones para evitar cancelar una reacción, la muerte o la estocada.
	if estado == "Muerto" or estado == "Hitstun" or estado == "EstocadaVeloz" or estado == "Antiaereo" or estado == "CounterPose" or estado == "CounterImpacto" or estado == "CounterAttack":
		return

	if Input.is_action_just_pressed(inputs["counter"]):
		if cooldown_counter_actual <= 0 and is_on_floor() and (estado == "Normal" or estado == "Agachado"):
			iniciar_counter()
			return

	if Input.is_action_just_pressed(inputs["ataque_debil"]):
		# F convierte el salto en antiaéreo si se presiona dentro de la ventana
		# de W o si ambas teclas se presionan en el mismo frame.
		if tiempo_ventana_antiaereo > 0 or Input.is_action_just_pressed(inputs["salto"]):
			if estado == "Normal" and (is_on_floor() or tiempo_ventana_antiaereo > 0):
				iniciar_antiaereo()
				return
		# El ataque débil solo puede iniciarse en el suelo y no puede comenzar
		# mientras Lum ya está bloqueando o ejecutando otro ataque.
		if is_on_floor() and estado != "Bloqueando" and estado != "Atacando":
			estado = "Atacando"
			configurar_ataque("debil")
			ataque_actual = "Ataque_1"
			# Primero se desactivan todas las hitboxes para evitar que una anterior
			# permanezca activa al cambiar rápidamente entre acciones.
			desactivar_hitboxes()
			# AnimatedSprite2D muestra los frames y AnimationPlayer controla las
			# propiedades sincronizadas de la hitbox de este ataque.
			ani.play(ataque_actual, 1.8)
			$AnimationPlayer.play(ataque_actual)

	if Input.is_action_just_pressed(inputs["ataque_medio"]):
		# El ataque medio tiene dos usos: comenzar desde neutral o cancelar el
		# ataque débil después de que este alcanza su ventana de cancelación.
		if estado == "Dash" and tiempo_ventana_estocada > 0:
			# La combinación dash + ataque medio convierte el dash en la estocada.
			iniciar_estocada_veloz()
			return
		# Puede comenzar desde el suelo si Lum está libre.
		var puede_empezar = is_on_floor() and estado != "Bloqueando" and estado != "Atacando" and estado != "Hitstun"
		# Puede cancelar el ataque débil únicamente desde el frame permitido.
		var puede_cancelar = estado == "Atacando" and ataque_actual == "Ataque_1" and ani.frame >= frame_cancel_debil

		if puede_empezar or puede_cancelar:
			estado = "Atacando"
			configurar_ataque("medio")
			ataque_actual = "Ataque_2"
			desactivar_hitboxes()
			# La animación y el AnimationPlayer se inician juntos para que el
			# momento visual del golpe coincida con su ventana de daño.
			ani.play(ataque_actual, 1.0)
			$AnimationPlayer.play(ataque_actual)

	if Input.is_action_pressed(inputs["bloqueo"]):
		# El bloqueo solo está disponible en el suelo desde Normal o Agachado.
		# La clase padre se encarga de la reacción, retroceso y hitstop.
		if is_on_floor() and (estado == "Normal" or estado == "Agachado"):
			estado = "Bloqueando"
			iniciar_animacion_bloqueo()

	if Input.is_action_just_released(inputs["bloqueo"]) and estado == "Bloqueando":
		estado = "Normal"

func _physics_process(delta):
	# Procesa la física, las transiciones de la FSM y las animaciones de Lum.
	# delta representa el tiempo transcurrido desde el frame anterior y permite
	# que los temporizadores funcionen igual aunque cambien los FPS.
	if estado == "Muerto":
		return
	if procesar_impacto_bloqueo(delta):
		# Mientras dura el impacto del bloqueo, la clase padre controla el estado
		# y Lum no debe ejecutar movimiento ni ataques adicionales.
		return

	if tiempo_ventana_estocada > 0:
		# La ventana se consume progresivamente y nunca baja de cero.
		tiempo_ventana_estocada = max(tiempo_ventana_estocada - delta, 0.0)
	if tiempo_ventana_antiaereo > 0:
		tiempo_ventana_antiaereo = max(tiempo_ventana_antiaereo - delta, 0.0)
	if cooldown_counter_actual > 0:
		cooldown_counter_actual = max(cooldown_counter_actual - delta, 0.0)

	# Durante Hitstun se bloquean las acciones normales y solo se procesa
	# el frenado del retroceso junto con la gravedad en el aire.
	if estado == "Hitstun":
		# Frena al personaje y le aplica gravedad, pero bloquea el resto del código
		velocity.x = move_toward(velocity.x, 0, 800 * delta)
		if not is_on_floor():
			velocity.y += 980 * delta
		move_and_slide()
		return

	# Durante la Estocada Veloz se bloquean todas las entradas hasta terminar
	if estado == "EstocadaVeloz":
		# La estocada tiene su propio procesamiento para bloquear entradas,
		# mover a Lum y devolverla a Normal al completar sus fases.
		procesar_estocada_veloz(delta)
		return
	if estado == "Antiaereo":
		procesar_antiaereo(delta)
		return
	if estado == "CounterPose":
		procesar_counter_pose(delta)
		return
	if estado == "CounterImpacto":
		procesar_counter_impacto(delta)
		return
	if estado == "CounterAttack":
		procesar_counter_attack(delta)
		return
	# ---------------------------------

	if Input.is_action_just_pressed(inputs["especial"]):
		# El especial puede iniciar desde el suelo o cancelar un ataque cuando
		# alcanza el frame de cancelación definido en Jugador.
		var puede_empezar = is_on_floor() and estado != "Atacando" and estado != "Dash" and estado != "Hitstun"
		var puede_cancelar = estado == "Atacando" and ani.frame >= frame_cancel_especial
		
		if puede_empezar or puede_cancelar:
			estado = "Especial"
			configurar_ataque("especial")
			desactivar_hitboxes()
			ani.play("Especial")
			$AnimationPlayer.play("Especial")

	if is_on_floor():
		# Al tocar el suelo se recupera la posibilidad de hacer dash.
		Can_Dash = 1

	if Input.is_action_pressed(inputs["abajo"]) and is_on_floor() and estado == "Normal":
		# Mantiene el estado Agachado mientras se presiona abajo.
		estado = "Agachado"
	elif Input.is_action_just_released(inputs["abajo"]) and is_on_floor() and estado == "Agachado":
		estado = "Normal"

	# Solo los estados libres procesan las entradas horizontales. Durante un
	# ataque, especial, bloqueo o hitstun la velocidad horizontal no viene del
	# control del jugador sino de la acción que se está procesando.
	if estado != "Bloqueando" and estado != "Atacando" and estado != "Especial" and estado != "Hitstun" and estado != "Antiaereo":
		if Input.is_action_pressed(inputs["derecha"]):
			intMove = 1
		elif Input.is_action_pressed(inputs["izquierda"]):
			intMove = -1
		else:
			intMove = 0
	else:
		intMove = 0

	if Input.is_action_just_pressed(inputs["dash"]) and Can_Dash > 0 and estado != "Bloqueando":
		# Primero comienza el dash y se abre una ventana para convertirlo
		# en estocada si se presiona ataque medio a tiempo.
		estado = "Dash"
		tiempo_ventana_estocada = ventana_estocada
		Can_Dash -= 1
		# El dash consume una carga inmediatamente; la clase padre la repone al
		# tocar el suelo según la lógica general del personaje.

	# Cada rama de este match representa un estado de la máquina de estados.
	# Solo una rama se ejecuta por frame, lo que evita mezclar movimiento normal,
	# ataque y bloqueo al mismo tiempo.
	match estado:
		"Normal":
			# Estado neutral: permite caminar, saltar y aplicar gravedad cuando Lum
			# está en el aire. El coyote time permite saltar poco después de dejar
			# el borde de una plataforma.
			if is_on_floor():
				coyote_time = max_coyote_time
				velocity.y = 0
			else:
				coyote_time -= delta
				velocity.y += intVY * delta

			velocity.x = (intVX * intMove) * delta if intMove != 0 else 0

			if Input.is_action_just_pressed(inputs["salto"]):
				if is_on_floor() or (coyote_time > 0 and velocity.y > 0.01):
					tiempo_ventana_antiaereo = ventana_antiaereo
					velocity.y = -Jump_Height

			if Input.is_action_just_released(inputs["salto"]) and velocity.y < 0:
				velocity.y *= 0.5

		"Agachado", "Atacando", "Especial":
			# Estas acciones detienen el movimiento normal para que la animación y
			# la duración de la acción controlen el comportamiento de Lum.
			velocity.x = 0
			velocity.y = 0

		"Bloqueando":
			# El bloqueo permite retroceso, pero lo frena rápidamente.
			# Permite que el retroceso del bloqueo se deslice y frene suavemente
			velocity.x = move_toward(velocity.x, 0, frenado_bloqueo * delta)
			velocity.y = 0

		"Dash":
			# Desplazamiento rápido en la dirección en la que mira Lum. También se
			# genera el duplicado visual cuando alcanza el intervalo configurado.
			Time_Actual_Dupli += delta
			velocity.y = 0
			var dir = sign(mirror.scale.x)
			velocity.x = (intVX_Dash * dir) * delta

			if Time_Actual_Dupli >= Time_Dupli:
				Time_Actual_Dupli = 0
				crear_duplicado()


	_animaciones()
	move_and_slide()
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)

	# Selección de animaciones y efectos visuales según el estado actual. La
	# llamada _animaciones() anterior pertenece a Jugador y actualiza elementos
	# visuales comunes; este match selecciona las animaciones propias de Lum.

	match estado:
		"Normal":
			if is_on_floor():
				if velocity.x == 0:
					ani.play("Idle", 0.8)
				else:
					ani.play("Run", 1.1)
			else:
				ani.play("Jump" if velocity.y < 0 else "Fall")
		"Agachado":
			ani.play("Fase1_Agacharse")
		"Dash":
			if is_on_floor():
				ani.play("Dash", 2.5)
			else:
				ani.play("Dash_Aire")
		"Atacando":
			# Se conserva la posición del nodo gráfico durante los ataques para que
			# una animación no desplace permanentemente el cuerpo de Lum.
			sprite_pos_atacando = mirror.position
			if ani.animation != ataque_actual:
				ani.play(ataque_actual, 1.8)
			mirror.position = sprite_pos_atacando
		"EstocadaVeloz":
			# Durante la estocada el AnimationPlayer controla el frame del sprite;
			# por eso no se llama ani.play() cada frame y no se reinicia la animación.
			pass
		"Bloqueando":
			mantener_animacion_bloqueo()
		"Especial":
			ani.play("Especial")


func procesar_estocada_veloz(delta: float) -> void:
	# La duración se divide en preparación, fase activa y recuperación. El código
	# controla el desplazamiento, mientras AnimationPlayer activa la hitbox
	# Col_Daño/Estocada en los mismos tiempos de la animación.
	tiempo_estocada += delta
	var fin_inicio = duracion_inicio_estocada
	var fin_activa = fin_inicio + duracion_activa_estocada
	var fin_total = fin_activa + duracion_recuperacion_estocada
	# La dirección se obtiene del espejo visual para que la estocada avance hacia
	# el lado al que Lum está mirando, tanto a izquierda como a derecha.
	var direccion = sign(mirror.scale.x)
	if direccion == 0:
		direccion = 1

	if tiempo_estocada < fin_inicio:
		# Preparación: la estocada todavía no puede golpear.
		velocity.x = 0
	elif tiempo_estocada < fin_activa:
		# Fase activa: avanza con velocidad constante. La hitbox la controla el
		# AnimationPlayer, evitando duplicar su activación desde el script.
		velocity.x = velocidad_estocada * direccion
	else:
		# Recuperación: el personaje frena y queda vulnerable.
		velocity.x = move_toward(velocity.x, 0, velocidad_estocada * 8.0 * delta)

	velocity.y = 0
	# La estocada se mantiene en el suelo y se limita al escenario para evitar
	# que el desplazamiento atraviese los límites del nivel.
	move_and_slide()
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)
	if tiempo_estocada >= fin_total:
		# Limpieza final: se apaga cualquier hitbox, se detiene la animación de la
		# estocada y Lum vuelve a estar disponible en estado Normal.
		desactivar_hitboxes()
		$AnimationPlayer.stop()
		estado = "Normal"
		ani.play("Idle")


func iniciar_estocada_veloz() -> void:
	# Convierte el dash actual en la estocada dentro de la ventana válida.
	# Esta función prepara todos los valores antes de que _physics_process
	# comience a procesar sus fases.
	estado = "EstocadaVeloz"
	tiempo_estocada = 0.0
	tiempo_ventana_estocada = 0.0
	desactivar_hitboxes()
	configurar_ataque("medio")
	# Se conserva el tipo de daño medio, aunque la estocada tenga su propia
	# animación y hitbox.
	ani.animation = "Estocada"
	ani.stop()
	# AnimationPlayer controla los frames y la propiedad disabled de la hitbox.
	$AnimationPlayer.play("Estocada")


func procesar_antiaereo(delta: float) -> void:
	# El antiaéreo bloquea otras acciones durante su ejecución. La animación
	# controla los frames y la hitbox; esta función controla el impulso vertical.
	tiempo_antiaereo += delta
	velocity.x = 0
	# El impulso inicial se aplica al comenzar la acción. Después se aplica la
	# gravedad normal para que Lum describa un arco corto en lugar de subir de
	# forma constante durante toda la animación.
	velocity.y += intVY * delta
	move_and_slide()
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)

	if tiempo_antiaereo >= duracion_antiaereo:
		desactivar_hitboxes()
		$AnimationPlayer.stop()
		$Col_Daño/Antiaereo.set_deferred("disabled", true)
		estado = "Normal"
		ani.play("Idle")


func iniciar_antiaereo() -> void:
	# Inicia el Tajo Antiaéreo a partir de la combinación W + F.
	# Se configura como ataque medio para que use su daño exportado y pueda
	# ajustarse después sin cambiar la estructura del movimiento.
	estado = "Antiaereo"
	tiempo_antiaereo = 0.0
	tiempo_ventana_antiaereo = 0.0
	desactivar_hitboxes()
	configurar_ataque("medio")
	# El impulso usa el salto normal, reducido por el multiplicador exportado.
	# Se aplica una sola vez; procesar_antiaereo() se encarga luego de la gravedad.
	velocity.y = -Jump_Height * multiplicador_impulso_antiaereo
	ani.animation = "Antiaereo"
	ani.stop()
	$AnimationPlayer.play("Antiaereo")


func procesar_counter_pose(delta: float) -> void:
	# Durante la pose Lum espera el golpe. No se reproduce el AnimationPlayer
	# porque ese recurso contiene el tajo, que solo debe salir tras un impacto.
	tiempo_counter += delta
	velocity = Vector2.ZERO
	ani.animation = "Counter"
	ani.frame = 0
	ani.stop()
	move_and_slide()

	if tiempo_counter >= duracion_pose_counter:
		finalizar_counter()


func procesar_counter_attack(delta: float) -> void:
	# Respuesta ofensiva: la animación controla los frames y activa la hitbox
	# Counter en su ventana de impacto.
	tiempo_counter += delta
	velocity = Vector2.ZERO
	move_and_slide()

	if tiempo_counter >= duracion_counter:
		finalizar_counter()


func procesar_counter_impacto(delta: float) -> void:
	# Pausa breve después de detectar el golpe. Durante este instante no se
	# reproduce el tajo ni se activa la hitbox, para que el impacto tenga peso.
	tiempo_counter += delta
	velocity = Vector2.ZERO
	$Col_Daño/Counter.set_deferred("disabled", true)
	move_and_slide()

	if tiempo_counter >= retraso_respuesta_counter:
		estado = "CounterAttack"
		tiempo_counter = 0.0
		ani.animation = "Counter"
		ani.stop()
		$AnimationPlayer.play("Counter")


func finalizar_counter() -> void:
	# Limpieza común para que el counter nunca deje su hitbox activa.
	desactivar_hitboxes()
	# El counter también puede finalizar dentro de area_entered; detener el
	# AnimationPlayer de forma diferida evita cambiar hitboxes mientras Godot
	# todavía está procesando las consultas físicas.
	$AnimationPlayer.call_deferred("stop")
	estado = "Normal"
	ani.play("Idle")


func iniciar_counter() -> void:
	# Inicia la pose defensiva y consume el cooldown desde el momento de uso.
	estado = "CounterPose"
	tiempo_counter = 0.0
	cooldown_counter_actual = cooldown_counter
	desactivar_hitboxes()
	configurar_ataque("counter")
	ani.animation = "Counter"
	ani.frame = 0
	ani.stop()


func ejecutar_counter(area: Area2D) -> void:
	# Un impacto válido congela al atacante brevemente y lanza la respuesta.
	estado = "CounterImpacto"
	tiempo_counter = 0.0
	configurar_ataque("counter")
	aplicar_hit_stop(hitstop_counter, 0.08)
	sacudir_camara(intensidad_camara_counter, hitstop_counter)
	var atacante = area.get_parent()
	if atacante != null and atacante != self and atacante.has_method("Hit"):
		atacante.Hit(global_position, stun_counter)
	ani.animation = "Counter"
	ani.frame = 0
	ani.stop()


func _on_hurtbox_area_entered(area: Area2D):
	# Lum intercepta el golpe durante la ventana de parada antes de delegar la
	# recepción normal a Jugador.
	if area.is_in_group("P_Punch") and estado == "CounterPose":
		# Toda la duración de la pose es una ventana válida para contraatacar.
		if tiempo_counter <= duracion_pose_counter:
			ejecutar_counter(area)
			return
		desactivar_hitboxes()
	# El mismo ataque puede emitir otro evento mientras se procesa la consulta
	# física. Durante la pausa y la respuesta se ignoran esos eventos para que
	# Lum no reciba primero el golpe normal y luego el counter.
	if area.is_in_group("P_Punch") and (estado == "CounterImpacto" or estado == "CounterAttack"):
		return
	super._on_hurtbox_area_entered(area)


func Hit(posicion_atacante = null, tiempo: float = -1.0):
	# Si Lum recibe un golpe durante un ataque o estocada, se cortan de inmediato
	# sus hitboxes y cualquier animación que pudiera seguir activa.
	desactivar_hitboxes()
	if has_node("AnimationPlayer"):
		# Al detener la animación, esta puede actualizar pistas de colisión.
		# Se aplaza para no cambiar hitboxes desde la señal area_entered.
		$AnimationPlayer.call_deferred("stop")
	if estado == "CounterPose" or estado == "CounterImpacto" or estado == "CounterAttack":
		finalizar_counter()
	super.Hit(posicion_atacante, tiempo)

func crear_especial():
	# Instancia el proyectil especial, lo coloca en la posición de Lum y le
	# asigna dirección, daño y capa según el jugador que lo lanzó.
	var proyectil = Especial.instantiate()
	proyectil.global_position = global_position
	var dir = sign(mirror.scale.x)
	proyectil.direction = dir if dir != 0 else 1
	proyectil.daño = obtener_daño_actual()
	proyectil.collision_layer = $Col_Daño.collision_layer
	get_parent().add_child(proyectil)

func crear_duplicado():
	# Crea una copia semitransparente durante el dash. Es un efecto visual y no
	# tiene colisión ni lógica propia de combate.
	var duplicado = $AnimatedSprite2D.duplicate(true)
	duplicado.material = $AnimatedSprite2D.material.duplicate(true)
	duplicado.material.set_shader_parameter("opacity", 0.3)
	duplicado.material.set_shader_parameter("b", 0.8)
	duplicado.material.set_shader_parameter("mix_color", 0.7)
	duplicado.global_position = $AnimatedSprite2D.global_position
	duplicado.global_scale = $AnimatedSprite2D.global_scale
	duplicado.z_index -= 1
	get_parent().add_child(duplicado)
	await get_tree().create_timer(Time_Life_Dupli).timeout
	# La copia se elimina después de su tiempo de vida para no acumular nodos.
	duplicado.queue_free()

func _on_animated_sprite_2d_animation_finished() -> void:
	# Las animaciones terminadas devuelven a Lum al estado correspondiente. La
	# estocada queda fuera de este control porque su duración la administra la
	# FSM y no la señal de finalización del AnimatedSprite2D.
	match ani.animation:
		"Dash", "Dash_Aire", "Dash_P2":
			# Al terminar el dash se cierra la ventana de conversión a estocada.
			tiempo_ventana_estocada = 0.0
			estado = "Normal"
			
		"Ataque_1", "Ataque_P2":
			# El ataque débil puede repetirse si la lógica de impactos consecutivos
			# lo permite; de lo contrario vuelve al estado neutral.
			if counter_hit > 1:
				counter_hit = 0
				ani.play(ani.animation)
			else:
				counter_hit = 0
				estado = "Normal"
				
		"Ataque_2", "Ataque_2P2":
			# La estocada controla su propia duración y recuperación.
			if estado == "EstocadaVeloz":
				return
			counter_hit = 0
			estado = "Normal"
			
		"Especial", "Especial_P2":
			# Al terminar el especial Lum queda disponible para otra acción.
			estado = "Normal"
			
