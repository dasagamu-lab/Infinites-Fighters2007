extends Jugador
class_name Lum

# Lum hereda de Jugador la vida, movimiento base, colisiones, hitstun y daño.
# Este script contiene las acciones y habilidades exclusivas de Lum.
var Especial = preload("res://Assets/Escenas/Lum/especial.tscn")
var counter_hit : int = 0
var ataque_actual : String = ""

# ---------------------------------------------------------
# CONTROLES Y FÍSICAS EXCLUSIVAS
# ---------------------------------------------------------
func _input(event):
	# No se aceptan nuevas acciones mientras Lum está muerta o en hitstun.
	if estado == "Muerto" or estado == "Hitstun":
		return

	if Input.is_action_just_pressed(inputs["ataque_debil"]):
		# El ataque débil solo puede iniciarse en el suelo.
		if is_on_floor() and estado != "Bloqueando" and estado != "Atacando":
			estado = "Atacando"
			configurar_ataque("debil")
			ataque_actual = "Ataque_1"
			desactivar_hitboxes()
			ani.play(ataque_actual, 1.8)
			$AnimationPlayer.play(ataque_actual)

	if Input.is_action_just_pressed(inputs["ataque_medio"]):
		# El ataque medio puede comenzar normalmente o cancelar el ataque débil.
		var puede_empezar = is_on_floor() and estado != "Bloqueando" and estado != "Atacando" and estado != "Hitstun"
		var puede_cancelar = estado == "Atacando" and ataque_actual == "Ataque_1" and ani.frame >= frame_cancel_debil

		if puede_empezar or puede_cancelar:
			estado = "Atacando"
			configurar_ataque("medio")
			ataque_actual = "Ataque_2"
			desactivar_hitboxes()
			ani.play(ataque_actual, 1.0)
			$AnimationPlayer.play(ataque_actual)

	if Input.is_action_pressed(inputs["bloqueo"]):
		# El bloqueo solo está disponible en el suelo desde Normal o Agachado.
		if is_on_floor() and (estado == "Normal" or estado == "Agachado"):
			estado = "Bloqueando"

	if Input.is_action_just_released(inputs["bloqueo"]) and estado == "Bloqueando":
		estado = "Normal"

func _physics_process(delta):
	# Procesa la física, las transiciones de la FSM y las animaciones de Lum.
	if estado == "Muerto":
		return

	# Durante Hitstun se bloquean las acciones normales y solo se procesa
	# el frenado del retroceso junto con la gravedad en el aire.
	if estado == "Hitstun":
		# Frena al personaje y le aplica gravedad, pero bloquea el resto del código
		velocity.x = move_toward(velocity.x, 0, 800 * delta)
		if not is_on_floor():
			velocity.y += 980 * delta
		move_and_slide()
		return
	# ---------------------------------

	if Input.is_action_just_pressed(inputs["especial"]):
		# El especial puede iniciar desde el suelo o cancelar un ataque.
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

	# Solo los estados libres procesan las entradas horizontales.
	if estado != "Bloqueando" and estado != "Atacando" and estado != "Especial" and estado != "Hitstun":
		if Input.is_action_pressed(inputs["derecha"]):
			intMove = 1
		elif Input.is_action_pressed(inputs["izquierda"]):
			intMove = -1
		else:
			intMove = 0
	else:
		intMove = 0

	if Input.is_action_just_pressed(inputs["dash"]) and Can_Dash > 0 and estado != "Bloqueando":
		# El dash consume una carga y cambia la FSM al estado Dash.
		estado = "Dash"
		Can_Dash -= 1

	# Cada rama de este match representa un estado de la máquina de estados.
	match estado:
		"Normal":
			# Movimiento, salto, gravedad y coyote time normales.
			if is_on_floor():
				coyote_time = max_coyote_time
				velocity.y = 0
			else:
				coyote_time -= delta
				velocity.y += intVY * delta

			velocity.x = (intVX * intMove) * delta if intMove != 0 else 0

			if Input.is_action_just_pressed(inputs["salto"]):
				if is_on_floor() or (coyote_time > 0 and velocity.y > 0.01):
					velocity.y = -Jump_Height

			if Input.is_action_just_released(inputs["salto"]) and velocity.y < 0:
				velocity.y *= 0.5

		"Agachado", "Atacando", "Especial":
			# Estas acciones detienen el movimiento normal.
			velocity.x = 0
			velocity.y = 0

		"Bloqueando":
			# El bloqueo permite retroceso, pero lo frena rápidamente.
			# Permite que el retroceso del bloqueo se deslice y frene suavemente
			velocity.x = move_toward(velocity.x, 0, 4000 * delta)
			velocity.y = 0

		"Dash":
			# Desplazamiento rápido en la dirección en la que mira Lum.
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

# Selección de animaciones y efectos visuales según el estado actual.

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
			sprite_pos_atacando = mirror.position
			if ani.animation != ataque_actual:
				ani.play(ataque_actual, 1.8)
			mirror.position = sprite_pos_atacando
		"Bloqueando":
			ani.play("Bloqueo")
		"Especial":
			ani.play("Especial")

func crear_especial():
	# Instancia el proyectil especial y le asigna la dirección de Lum.
	var proyectil = Especial.instantiate()
	proyectil.global_position = global_position
	var dir = sign(mirror.scale.x)
	proyectil.direction = dir if dir != 0 else 1
	get_parent().add_child(proyectil)

func crear_duplicado():
	# Crea una copia semitransparente durante el dash.
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
	duplicado.queue_free()

func _on_animated_sprite_2d_animation_finished() -> void:
	# Las animaciones terminadas devuelven a Lum al estado correspondiente.
	match ani.animation:
		"Dash", "Dash_Aire", "Dash_P2":
			estado = "Normal"
			
		"Ataque_1", "Ataque_P2":
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
			
