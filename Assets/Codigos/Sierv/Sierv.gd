extends Jugador
class_name Sierv

# ==============================================================================
# 1. CONFIGURACIÓN
# ==============================================================================
var ataque_actual : String = ""

# ==============================================================================
# 3. ENTRADAS DEL JUGADOR (_input)
# ==============================================================================
func _input(event):
	if estado == EstadoFSM.MUERTO or estado == EstadoFSM.HITSTUN or estado == EstadoFSM.CHOQUE or estado == EstadoFSM.AGARRANDO or estado == EstadoFSM.AGARRADO:
		return

	if event.is_action_pressed(inputs["ataque_debil"]):
		if puede_iniciar_ataque():
			ataque_actual = "Ataque_P2"
			iniciar_ataque(ataque_actual, "debil", 1.8)

	if event.is_action_pressed(inputs["ataque_medio"]):
		var puede_empezar = puede_iniciar_ataque()
		var puede_cancelar = puede_cancelar_ataque_debil("Ataque_P2")

		if puede_empezar or puede_cancelar:
			ataque_actual = "Ataque_2P2"
			iniciar_ataque(ataque_actual, "medio")

# ==============================================================================
# 4. FÍSICAS Y MÁQUINA DE ESTADOS (_physics_process)
# ==============================================================================
func _physics_process(delta):
	if estado == EstadoFSM.MUERTO:
		procesar_muerte(delta)
		return
	if procesar_impacto_bloqueo(delta):
		return
	if procesar_hitstun(delta):
		return

	comprobar_choque()
	if procesar_choque(delta):
		return
	if procesar_agarre(delta):
		return
	if intentar_iniciar_agarre():
		return

	if Input.is_action_just_pressed(inputs["especial"]):
		var puede_empezar = estado != EstadoFSM.ATACANDO and estado != EstadoFSM.DASH and estado != EstadoFSM.HITSTUN \
			and estado != EstadoFSM.ESPECIAL and estado != EstadoFSM.CHOQUE and estado != EstadoFSM.AGARRANDO \
			and estado != EstadoFSM.AGARRADO and estado != EstadoFSM.MUERTO
		var puede_cancelar = estado == EstadoFSM.ATACANDO and ani.frame >= frame_cancel_especial

		if puede_empezar or puede_cancelar:
			iniciar_especial()
			return

	procesar_entrada_bloqueo()
	procesar_postura()
	actualizar_direccion_entrada()
	intentar_iniciar_dash()
	procesar_movimiento_comun(delta)

func iniciar_especial() -> void:
	estado = EstadoFSM.ESPECIAL
	configurar_ataque("especial")
	velocity = Vector2.ZERO
	intMove = 0
	desactivar_hitboxes()
	ani.stop()
	anim_player.stop()
	anim_player.play("Especial")

# ==============================================================================
# 6. EFECTOS VISUALES Y SEÑALES
# ==============================================================================
# Optimizamos el Dash instanciando un Sprite2D ligero en lugar de duplicar todo el árbol
func _on_animated_sprite_2d_animation_finished() -> void:
	procesar_fin_animacion_sprite(ani.animation)

func obtener_animacion_dash() -> String:
	return "Dash_P2"

func obtener_color_duplicado_dash() -> Color:
	return Color(1.0, 0.3, 0.3, 0.5)

# Pose provisional del agarre hasta que exista la animación "Agarre".
func obtener_pose_agarre(lanzando: bool) -> Array:
	return ["Ataque_2P2", 7] if lanzando else ["Bloqueo_P2", 0]

# Sobrescribimos la señal del AnimationPlayer para que Sierv reconozca sus propias animaciones y vuelva a estado Normal
func _on_animation_player_finished(anim_name: String) -> void:
	super(anim_name)
	match anim_name:
		"Ataque_P2":
			if estado == EstadoFSM.ATACANDO:
				estado = EstadoFSM.NORMAL
		"Ataque_2P2":
			if estado == EstadoFSM.ATACANDO:
				estado = EstadoFSM.NORMAL
