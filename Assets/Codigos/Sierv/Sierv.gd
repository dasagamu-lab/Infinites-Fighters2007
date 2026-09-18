extends Jugador
class_name Sierv

# Sierv hereda de Jugador la vida, movimiento base, colisiones, hitstun y daño.
# Este script adapta esos sistemas a las animaciones y acciones de Sierv/P2.
var counter_hit : int = 0
var ataque_actual : String = ""


func _input(event):
	# No se aceptan nuevas acciones mientras Sierv está muerto o en hitstun.
	if estado == "Muerto" or estado == "Hitstun":
		return

	# Ataque débil: su daño se toma de daño_ataque_debil en Sierv.tscn.
	if Input.is_action_just_pressed(inputs["ataque_debil"]):
		if is_on_floor() and estado != "Bloqueando" and estado != "Atacando":
			estado = "Atacando"
			configurar_ataque("debil")
			ataque_actual = "Ataque_P2"
			ani.play(ataque_actual, 1.8)
			desactivar_hitboxes()
			$AnimationPlayer.play(ataque_actual)

	# Ataque medio: puede comenzar desde reposo o cancelar el ataque débil.
	if Input.is_action_just_pressed(inputs["ataque_medio"]):
		var puede_empezar = is_on_floor() and estado != "Bloqueando" and estado != "Atacando" and estado != "Hitstun"
		var puede_cancelar = estado == "Atacando" and ataque_actual == "Ataque_P2" and ani.frame >= frame_cancel_debil

		if puede_empezar or puede_cancelar:
			estado = "Atacando"
			configurar_ataque("medio")
			ataque_actual = "Ataque_2P2"
			ani.play(ataque_actual, 1.0)
			desactivar_hitboxes()
			$AnimationPlayer.play(ataque_actual)

	# Bloqueo: solo está disponible en el suelo desde Normal o Agachado.
	if Input.is_action_pressed(inputs["bloqueo"]):
		if is_on_floor() and (estado == "Normal" or estado == "Agachado"):
			estado = "Bloqueando"

	if Input.is_action_just_released(inputs["bloqueo"]) and estado == "Bloqueando":
		estado = "Normal"


func _physics_process(delta):
	# Procesa la física, la FSM y las animaciones propias de Sierv.
	if estado == "Muerto":
		return

	if estado == "Hitstun":
		# Durante el hitstun se bloquean las acciones normales. Solo se aplica
		# el frenado del retroceso y la gravedad cuando está en el aire.
		velocity.x = move_toward(velocity.x, 0, 800 * delta)
		if not is_on_floor():
			velocity.y += 980 * delta
		move_and_slide()
		return
		
	if Input.is_action_just_pressed(inputs["especial"]):
		# El especial cambia a Especial_P2 y usa sus animaciones de P2.
		var puede_empezar = estado != "Atacando" and estado != "Dash_P2" and estado != "Hitstun"
		var puede_cancelar = estado == "Atacando" and ani.frame >= frame_cancel_especial

		if puede_empezar or puede_cancelar:
			estado = "Especial_P2"
			configurar_ataque("especial")
			desactivar_hitboxes()
#			crear_especial()

	if is_on_floor():
		Can_Dash = 1

	if Input.is_action_pressed(inputs["abajo"]) and is_on_floor() and estado == "Normal":
		estado = "Agachado"
	elif Input.is_action_just_released(inputs["abajo"]) and is_on_floor() and estado == "Agachado":
		estado = "Normal"

	# Movimiento: los estados de ataque, bloqueo, especial y hitstun no aceptan
	# entradas horizontales normales.
	if estado != "Bloqueando" and estado != "Atacando" and estado != "Especial_P2" and estado != "Hitstun":
		if Input.is_action_pressed(inputs["derecha"]):
			intMove = 1
		elif Input.is_action_pressed(inputs["izquierda"]):
			intMove = -1
		else:
			intMove = 0
	else:
		intMove = 0

	# Dash: consume una carga y desplaza a Sierv según la dirección que mira.
	if Input.is_action_just_pressed(inputs["dash"]) and Can_Dash > 0 and estado != "Bloqueando":
		estado = "Dash_P2"
		Can_Dash -= 1

	# Máquina de estados principal de Sierv.
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
			# El bloqueo permite deslizarse y frena progresivamente el retroceso.
			# Permite que el retroceso del bloqueo se deslice y frene suavemente
			velocity.x = move_toward(velocity.x, 0, 1000 * delta)
			velocity.y = 0

		"Dash_P2":
			# Desplazamiento rápido y creación de duplicados visuales.
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



	# Selección de animaciones según el estado actual.
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

		"Dash_P2":
			if is_on_floor():
				ani.play("Dash_P2", 2.5)
			else:
				ani.play("Dash_Aire")

		"Atacando":
			ani.play(ataque_actual, 1.8)

		"Bloqueando":
			ani.play("Bloqueo_P2")

		"Especial_P2":
			ani.play("Especial_P2")



#func crear_especial():
	#var proyectil = Especial.instantiate()
	#proyectil.global_position = global_position
	#if mirror.flip_h:
	#	proyectil.direction = -1
	#else:
	#	proyectil.direction = 1
	#get_parent().add_child(proyectil)


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
	# Al finalizar una acción, la animación devuelve a Sierv al estado normal.
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
			
