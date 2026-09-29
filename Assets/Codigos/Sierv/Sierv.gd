extends Jugador
class_name Sierv

# ==============================================================================
# 1. CONFIGURACIÓN Y PRECARGAS
# ==============================================================================
# (Reservado para futuros proyectiles o recursos de Sierv)

# ==============================================================================
# 2. VARIABLES DE COMBATE Y TEMPORIZADORES
# ==============================================================================
var ataque_actual : String = ""

# ==============================================================================
# 3. ENTRADAS DEL JUGADOR (_input)
# ==============================================================================
func _input(event):
	if estado == EstadoFSM.MUERTO or estado == EstadoFSM.HITSTUN:
		return

	if Input.is_action_just_pressed(inputs["ataque_debil"]):
		if puede_iniciar_ataque():
			ataque_actual = "Ataque_P2"
			iniciar_ataque(ataque_actual, "debil", 1.8)

	if Input.is_action_just_pressed(inputs["ataque_medio"]):
		var puede_empezar = puede_iniciar_ataque()
		var puede_cancelar = puede_cancelar_ataque_debil("Ataque_P2")

		if puede_empezar or puede_cancelar:
			ataque_actual = "Ataque_2P2"
			iniciar_ataque(ataque_actual, "medio")

	procesar_entrada_bloqueo()

# ==============================================================================
# 4. FÍSICAS Y MÁQUINA DE ESTADOS (_physics_process)
# ==============================================================================
func _physics_process(delta):
	if estado == EstadoFSM.MUERTO:
		return
	if procesar_impacto_bloqueo(delta):
		return

	if procesar_hitstun(delta):
		return

	if Input.is_action_just_pressed(inputs["especial"]):
		var puede_empezar = estado != EstadoFSM.ATACANDO and estado != EstadoFSM.DASH and estado != EstadoFSM.HITSTUN
		var puede_cancelar = estado == EstadoFSM.ATACANDO and ani.frame >= frame_cancel_especial

		if puede_empezar or puede_cancelar:
			estado = EstadoFSM.ESPECIAL
			configurar_ataque("especial")
			desactivar_hitboxes()
			
			ani.animation = "Especial_P2"
			ani.stop()
			anim_player.play("Especial_P2")

	procesar_postura()
	actualizar_direccion_entrada()
	intentar_iniciar_dash()
	procesar_movimiento_comun(delta)

# ==============================================================================
# 5. LÓGICA DE HABILIDADES EXCLUSIVAS
# ==============================================================================
# (Sierv todavía no tiene habilidades complejas como estocadas o counters. 
# Este espacio queda reservado para futuras mecánicas únicas).

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

# Sobrescribimos la señal del AnimationPlayer para que Sierv reconozca sus propias animaciones y vuelva a estado Normal
func _on_animation_player_finished(anim_name: String) -> void:
	super(anim_name)
	match anim_name:
		"Ataque_P2", "Especial_P2":
			if estado == EstadoFSM.ATACANDO or estado == EstadoFSM.ESPECIAL:
				estado = EstadoFSM.NORMAL
		"Ataque_2P2":
			if estado == EstadoFSM.ATACANDO:
				estado = EstadoFSM.NORMAL
