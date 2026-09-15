extends Jugador
class_name Sierv

# ATAQUES
var counter_hit : int = 0
var ataque_actual : String = ""


func _input(event):
	# Si está muerto o aturdido, ignoramos los botones por completo
	if estado == "Muerto" or estado == "Hitstun":
		return

	# ... (aquí sigue tu código normal de ATAQUE DÉBIL, etc.)

	# ATAQUE DÉBIL
	if Input.is_action_just_pressed(inputs["ataque_debil"]):
		if is_on_floor() and estado != "Bloqueando" and estado != "Atacando":
			estado = "Atacando"
			ataque_actual = "Ataque_P2"
			ani.play(ataque_actual, 1.8)
			desactivar_hitboxes()
			$AnimationPlayer.play(ataque_actual)

	# ATAQUE MEDIO
	if Input.is_action_just_pressed(inputs["ataque_medio"]):
		var puede_empezar = is_on_floor() and estado != "Bloqueando" and estado != "Atacando" and estado != "Hit"
		var puede_cancelar = estado == "Atacando" and ataque_actual == "Ataque_P2" and ani.frame >= frame_cancel_debil

		if puede_empezar or puede_cancelar:
			estado = "Atacando"
			ataque_actual = "Ataque_2P2"
			ani.play(ataque_actual, 1.0)
			desactivar_hitboxes()
			$AnimationPlayer.play(ataque_actual)

	# BLOQUEO
	if Input.is_action_pressed(inputs["bloqueo"]):
		if is_on_floor() and (estado == "Normal" or estado == "Agachado"):
			estado = "Bloqueando"

	if Input.is_action_just_released(inputs["bloqueo"]) and estado == "Bloqueando":
		estado = "Normal"


func _physics_process(delta):
	if estado == "Muerto":
		return
		
	if Input.is_action_just_pressed(inputs["especial"]):
		var puede_empezar = estado != "Atacando" and estado != "Dash_P2" and estado != "Hit"
		var puede_cancelar = estado == "Atacando" and ani.frame >= frame_cancel_especial

		if puede_empezar or puede_cancelar:
			estado = "Especial_P2"
			desactivar_hitboxes()
#			crear_especial()

	if is_on_floor():
		Can_Dash = 1

	if Input.is_action_pressed(inputs["abajo"]) and is_on_floor() and estado == "Normal":
		estado = "Agachado"
	elif Input.is_action_just_released(inputs["abajo"]) and is_on_floor() and estado == "Agachado":
		estado = "Normal"

	# Movimiento
	if estado != "Bloqueando" and estado != "Atacando" and estado != "Especial_P2" and estado != "Hit":
		if Input.is_action_pressed(inputs["derecha"]):
			intMove = 1
		elif Input.is_action_pressed(inputs["izquierda"]):
			intMove = -1
		else:
			intMove = 0
	else:
		intMove = 0

	# Dash
	if Input.is_action_just_pressed(inputs["dash"]) and Can_Dash > 0 and estado != "Bloqueando":
		estado = "Dash_P2"
		Can_Dash -= 1

	# MAQUINA DE ESTADOS
	match estado:
		"Normal":
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
			velocity.x = 0
			velocity.y = 0

		"Bloqueando":
			# Permite que el retroceso del bloqueo se deslice y frene suavemente
			velocity.x = move_toward(velocity.x, 0, 1000 * delta)
			velocity.y = 0

		"Dash_P2":
			Time_Actual_Dupli += delta
			velocity.y = 0
			var dir = sign(mirror.scale.x)
			velocity.x = (intVX_Dash * dir) * delta

			if Time_Actual_Dupli >= Time_Dupli:
				Time_Actual_Dupli = 0
				crear_duplicado()
				
		"Hit":
			if not is_on_floor():
				velocity.y += intVY * delta
				if Input.is_action_just_pressed(inputs["ataque_debil"]):
					if is_on_floor() and estado != "Bloqueando" and estado != "Atacando" and estado != "Hit":
						if Input.is_action_just_pressed(inputs["ataque_medio"]):
							if is_on_floor() and estado != "Bloqueando" and estado != "Atacando" and estado != "Hit":
								pass
			else:
				velocity.y = 0

	_animaciones()
	move_and_slide()
	global_position.x = clamp(global_position.x, limite_izquierdo, limite_derecho)



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

		"Hit":
			if ani.animation != "Hit":
				ani.play("Hit")


#func crear_especial():
	#var proyectil = Especial.instantiate()
	#proyectil.global_position = global_position
	#if mirror.flip_h:
	#	proyectil.direction = -1
	#else:
	#	proyectil.direction = 1
	#get_parent().add_child(proyectil)


func crear_duplicado():
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
			
		"Hit":
			# ¡DEJAMOS ESTO EN PASS! 
			# Ya no forzamos el estado a Normal aquí.
			# El temporizador de la función Hit() en el Padre se encargará de esto.
			pass
